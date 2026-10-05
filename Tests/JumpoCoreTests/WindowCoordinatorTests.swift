import Foundation
import Testing
@testable import JumpoCore

@MainActor private final class FakeWindows: WindowClient {
    var hasPermission = true
    var value: WindowSnapshot
    var failure: WindowAccessError?
    var snapshots = 0
    var clears = 0
    var writes: [UUID] = []
    var attempts: [UUID] = []
    var holdNextFocus = false
    var heldFocus: CheckedContinuation<Void, Never>?
    var afterFocus: (() -> Void)?

    init(_ value: WindowSnapshot) { self.value = value }
    func clearCache() { clears += 1 }
    func snapshot(for process: ApplicationProcess, request: WindowRequest) async throws -> WindowSnapshot {
        snapshots += 1
        try request.check()
        if let failure { throw failure }
        return value
    }
    func focus(_ window: UUID, process: ApplicationProcess, restoreMinimized: Bool, request: WindowRequest) async throws -> Bool {
        attempts.append(window)
        if holdNextFocus {
            holdNextFocus = false
            await withCheckedContinuation { heldFocus = $0 }
        }
        try request.check()
        guard hasPermission else { throw WindowAccessError.permissionDenied }
        writes.append(window)
        let restored = value.windows.first { $0.id == window }?.minimized == true
        value = WindowSnapshot(windows: value.windows, focusedID: window)
        afterFocus?()
        return restored
    }
}

@Test @MainActor func missingPermissionFallsBackWithoutWindowReads() async throws {
    let apps = FakeApplications(), windows = FakeWindows(WindowSnapshot(windows: [])), app = testApp("A")
    windows.hasPermission = false
    apps.running[app.path] = ApplicationProcess(pid: 1)
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { if case .applicationFallback = status { true } else { false } }
    #expect(apps.frontmost == ApplicationProcess(pid: 1))
    #expect(windows.snapshots == 0)
    #expect(windows.writes.isEmpty)
}

@Test @MainActor func onlyChosenMinimizedWindowIsRestored() async throws {
    let a = WindowRecord(id: UUID(), minimized: true), b = WindowRecord(id: UUID(), minimized: true)
    let apps = FakeApplications(), windows = FakeWindows(WindowSnapshot(windows: [a, b], mainID: b.id)), app = testApp("A")
    apps.running[app.path] = ApplicationProcess(pid: 1)
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { status == .windowActivated("A", restored: true) }
    #expect(windows.writes == [b.id])
}

@Test @MainActor func rapidWindowInputsCoalesceToLatestCursor() async throws {
    let a = WindowRecord(id: UUID()), b = WindowRecord(id: UUID()), c = WindowRecord(id: UUID())
    let apps = FakeApplications(), windows = FakeWindows(WindowSnapshot(windows: [a, b, c], focusedID: a.id)), app = testApp("A")
    apps.running[app.path] = ApplicationProcess(pid: 1)
    apps.frontmost = ApplicationProcess(pid: 1)
    windows.holdNextFocus = true
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { windows.heldFocus != nil }
    coordinator.jump(to: app)
    coordinator.jump(to: app)
    windows.heldFocus?.resume()
    windows.heldFocus = nil
    try await waitUntil { status == .windowActivated("A", restored: false) }
    #expect(windows.attempts == [b.id, a.id])
    #expect(windows.writes == [a.id])
}

@Test @MainActor func manualAppSwitchInvalidatesPendingWindowWrite() async throws {
    let apps = FakeApplications(), windows = FakeWindows(WindowSnapshot(windows: [WindowRecord(id: UUID())])), app = testApp("A")
    apps.running[app.path] = ApplicationProcess(pid: 1)
    windows.holdNextFocus = true
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { windows.heldFocus != nil }
    coordinator.userDidActivateApplication(at: "/Applications/UserChoice.app")
    windows.heldFocus?.resume()
    windows.heldFocus = nil
    try await Task.sleep(for: .milliseconds(10))
    #expect(windows.writes.isEmpty)
    #expect(status == .interrupted)
}

@Test @MainActor func windowFailureDoesNotClaimWindowSuccess() async throws {
    let apps = FakeApplications(), windows = FakeWindows(WindowSnapshot(windows: [])), app = testApp("A")
    apps.running[app.path] = ApplicationProcess(pid: 1)
    windows.failure = .timedOut
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { if case .applicationFallback = status { true } else { false } }
    #expect(status == .applicationFallback("A", reason: WindowAccessError.timedOut.explanation))
}

@Test @MainActor func windowSuccessStillRequiresFrontmostApplication() async throws {
    let apps = FakeApplications(), windows = FakeWindows(WindowSnapshot(windows: [WindowRecord(id: UUID())])), app = testApp("A")
    apps.running[app.path] = ApplicationProcess(pid: 1)
    windows.afterFocus = { apps.frontmost = nil }
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    var failed = false
    coordinator.onStatus = { if case .failed = $0 { failed = true } }
    coordinator.jump(to: app)
    try await waitUntil { failed }
    #expect(failed)
}

@Test @MainActor func disabledWindowManagementKeepsApplicationBehavior() async throws {
    let apps = FakeApplications(), windows = FakeWindows(WindowSnapshot(windows: [])), app = testApp("A")
    apps.running[app.path] = ApplicationProcess(pid: 1)
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    coordinator.configureWindows(enabled: false, restoreMinimized: false)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { status == .activated("A") }
    #expect(windows.snapshots == 0)
    #expect(apps.openedDefaultWindows.isEmpty)
}

@Test @MainActor func confirmedWindowlessAppGetsItsDefaultWindow() async throws {
    let apps = FakeApplications(), windows = FakeWindows(WindowSnapshot(windows: [])), app = testApp("Finder")
    apps.running[app.path] = ApplicationProcess(pid: 1)
    apps.defaultWindowOpens = true
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { status == .windowOpened("Finder") }
    #expect(apps.openedDefaultWindows == [app.path])
}

@Test @MainActor func appWithoutDefaultWindowStillFallsBack() async throws {
    let apps = FakeApplications(), windows = FakeWindows(WindowSnapshot(windows: [])), app = testApp("A")
    apps.running[app.path] = ApplicationProcess(pid: 1)
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { if case .applicationFallback = status { true } else { false } }
    #expect(status == .applicationFallback("A", reason: "没有可控制的标准窗口。"))
}

@Test @MainActor func minimizedWindowsAreNeverDuplicated() async throws {
    let apps = FakeApplications(), app = testApp("Finder")
    let windows = FakeWindows(WindowSnapshot(windows: [WindowRecord(id: UUID(), minimized: true)]))
    apps.running[app.path] = ApplicationProcess(pid: 1)
    apps.defaultWindowOpens = true
    let coordinator = JumpCoordinator(client: apps, windows: windows)
    coordinator.configureWindows(enabled: true, restoreMinimized: false)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { if case .applicationFallback = status { true } else { false } }
    #expect(apps.openedDefaultWindows.isEmpty)
    #expect(status == .applicationFallback("Finder", reason: "已保留最小化窗口状态。"))
}
