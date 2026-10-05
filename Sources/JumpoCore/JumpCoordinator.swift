import Foundation

public struct ApplicationProcess: Equatable, Sendable {
    public let pid: Int32
    public let launchedAt: TimeInterval?
    public init(pid: Int32, launchedAt: TimeInterval? = nil) { self.pid = pid; self.launchedAt = launchedAt }
}

@MainActor
public protocol ApplicationClient: AnyObject {
    func runningApplication(for app: AppBinding) throws -> ApplicationProcess?
    func launch(_ app: AppBinding) async throws -> ApplicationProcess
    func activate(_ process: ApplicationProcess) -> Bool
    func isFrontmost(_ process: ApplicationProcess) -> Bool
    /// Opens the app's default location as a window. Only apps that always run without
    /// windows expose one (Finder: the home directory, PRD 12.4).
    func openDefaultWindow(_ app: AppBinding) -> Bool
}

public extension ApplicationClient {
    func openDefaultWindow(_ app: AppBinding) -> Bool { false }
}

public enum JumpStatus: Equatable, Sendable {
    case working(String)
    case activated(String)
    case alreadyActive(String)
    case windowActivated(String, restored: Bool)
    case windowOpened(String)
    case applicationFallback(String, reason: String)
    case failed(String)
    case interrupted
}

@MainActor
public final class JumpCoordinator {
    private let client: any ApplicationClient
    private let windows: (any WindowClient)?
    private let verificationInterval: Duration
    private let verificationAttempts: Int
    private let requestTimeout: Duration
    private var generation = UUID()
    private var worker: Task<Void, Never>?
    private var deadline: Task<Void, Never>?
    private var launches: [String: (UUID, Task<ApplicationProcess, Error>)] = [:]
    private var target: AppBinding?
    private var windowRequest: WindowRequest?
    private var cycle = WindowCycle()
    private var cycleAppPath: String?
    private var windowPhase = false
    private var pendingCycles = 0
    private var windowsEnabled = true
    private var restoreMinimized = true
    private var lastInputAt: ContinuousClock.Instant = .now
    public var onStatus: ((JumpStatus) -> Void)?

    public init(client: any ApplicationClient, windows: (any WindowClient)? = nil, verificationInterval: Duration = .milliseconds(50), verificationAttempts: Int = 40, requestTimeout: Duration = .seconds(20)) {
        self.client = client
        self.windows = windows
        self.verificationInterval = verificationInterval
        self.verificationAttempts = verificationAttempts
        self.requestTimeout = requestTimeout
    }

    public func jump(to app: AppBinding) {
        lastInputAt = .now
        // Repeated input while this app is launching/activating is one request.
        if target?.path == app.path {
            if windowPhase { pendingCycles += 1; windowRequest?.cancel() }
            return
        }
        cancelWork(resetCycle: cycleAppPath != app.path)
        let request = generation
        target = app
        onStatus?(.working(app.name))
        deadline = Task { [weak self, requestTimeout] in
            do { try await Task.sleep(for: requestTimeout) }
            catch { return }
            guard let self, generation == request else { return }
            cancel()
            onStatus?(.failed("打开 \(app.name) 超时，请检查应用后重试。"))
        }
        worker = Task { [weak self] in
            guard let self else { return }
            do {
                let process: ApplicationProcess
                if let running = try client.runningApplication(for: app) {
                    process = running
                } else {
                    process = try await launchOnce(app)
                }
                guard !Task.isCancelled, generation == request else { return }
                let wasFrontmost = client.isFrontmost(process)
                if !wasFrontmost && !client.activate(process) {
                    finish(.failed("无法激活 \(app.name)，应用可能已退出。"), request: request)
                    return
                }
                for _ in 0..<verificationAttempts {
                    guard !Task.isCancelled, generation == request else { return }
                    if client.isFrontmost(process) {
                        if let windows, windowsEnabled {
                            await focusWindow(app, process: process, wasFrontmost: wasFrontmost, windows: windows, request: request)
                        } else {
                            finish(wasFrontmost ? .alreadyActive(app.name) : .activated(app.name), request: request)
                        }
                        return
                    }
                    try await Task.sleep(for: verificationInterval)
                }
                finish(.failed("已请求打开 \(app.name)，但未确认它已切到前台。请重试。"), request: request)
            } catch is CancellationError {
                // An obsolete request must not publish a result or activate anything.
            } catch {
                finish(.failed(error.localizedDescription), request: request)
            }
        }
    }

    public func userDidActivateApplication(at path: String?) {
        if let path, path != cycleAppPath { cycle.reset(); cycleAppPath = nil }
        guard let target, let path, path != target.path else { return }
        cancel()
        onStatus?(.interrupted)
    }

    public func cancel() {
        cancelWork(resetCycle: true)
    }

    public func configureWindows(enabled: Bool, restoreMinimized: Bool) {
        cancel()
        windowsEnabled = enabled
        self.restoreMinimized = restoreMinimized
        windows?.clearCache()
    }

    private func cancelWork(resetCycle: Bool) {
        generation = UUID()
        worker?.cancel()
        worker = nil
        deadline?.cancel()
        deadline = nil
        target = nil
        windowRequest?.cancel()
        windowRequest = nil
        windowPhase = false
        pendingCycles = 0
        if resetCycle { cycle.reset(); cycleAppPath = nil }
    }

    private func focusWindow(_ app: AppBinding, process: ApplicationProcess, wasFrontmost: Bool, windows: any WindowClient, request: UUID) async {
        windowPhase = true
        cycleAppPath = app.path
        var first = true
        while generation == request && !Task.isCancelled {
            guard windows.hasPermission else {
                windows.clearCache()
                fallback(app, process: process, reason: WindowAccessError.permissionDenied.explanation, request: request)
                return
            }
            let ticket = WindowRequest()
            windowRequest = ticket
            do {
                let snapshot = try await windows.snapshot(for: process, request: ticket)
                try ticket.check()
                guard generation == request, !Task.isCancelled else { return }
                if snapshot.hasModalWindow { throw WindowAccessError.modalWindow }
                let advances = first ? (wasFrontmost ? 1 : 0) + pendingCycles : max(1, pendingCycles)
                pendingCycles = 0
                let selected = cycle.select(from: snapshot, process: process, advances: advances,
                                            restoreMinimized: restoreMinimized, now: lastInputAt, checkExternalFocus: first)
                first = false
                guard let selected else {
                    // PRD 12.4: once permission allows enumeration and no standard window is
                    // confirmed, the app itself is asked for a usable window instead of
                    // silently reporting an app-level switch. Only a confirmed empty window
                    // list qualifies, so minimized windows are never duplicated.
                    if snapshot.windows.isEmpty, client.openDefaultWindow(app) {
                        finish(client.isFrontmost(process) ? .windowOpened(app.name)
                                                           : .failed("已打开 \(app.name)，但未确认它已切到前台。请重试。"), request: request)
                        return
                    }
                    fallback(app, process: process, reason: snapshot.windows.isEmpty ? "没有可控制的标准窗口。" : "已保留最小化窗口状态。", request: request)
                    return
                }
                let restored = try await windows.focus(selected.id, process: process, restoreMinimized: restoreMinimized, request: ticket)
                try ticket.check()
                guard generation == request, !Task.isCancelled else { return }
                if pendingCycles > 0 { continue }
                guard client.isFrontmost(process) else { throw WindowAccessError.unavailable }
                finish(.windowActivated(app.name, restored: restored), request: request)
                return
            } catch {
                guard generation == request, !Task.isCancelled else { return }
                if error as? WindowAccessError == .cancelled, pendingCycles > 0 { continue }
                fallback(app, process: process, reason: (error as? WindowAccessError ?? .unavailable).explanation, request: request)
                return
            }
        }
    }

    private func fallback(_ app: AppBinding, process: ApplicationProcess, reason: String, request: UUID) {
        cycle.reset()
        if client.isFrontmost(process) {
            finish(.applicationFallback(app.name, reason: reason), request: request)
        } else {
            finish(.failed("未确认 \(app.name) 已切到前台。\(reason)"), request: request)
        }
    }

    private func launchOnce(_ app: AppBinding) async throws -> ApplicationProcess {
        if let (_, task) = launches[app.path] { return try await task.value }
        let id = UUID()
        let task = Task { try await client.launch(app) }
        launches[app.path] = (id, task)
        defer {
            if launches[app.path]?.0 == id { launches[app.path] = nil }
        }
        return try await task.value
    }

    private func finish(_ status: JumpStatus, request: UUID) {
        guard generation == request, !Task.isCancelled else { return }
        target = nil
        worker = nil
        deadline?.cancel()
        deadline = nil
        windowRequest?.cancel()
        windowRequest = nil
        windowPhase = false
        onStatus?(status)
    }
}
