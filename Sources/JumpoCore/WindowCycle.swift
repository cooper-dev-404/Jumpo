import CoreGraphics
import Foundation

public enum WindowAccessPolicy {
    /// AppKit can report AXDialog for minimized document windows. Unknown
    /// modality or a missing minimize control is insufficient evidence to restore.
    public static func canRestoreMinimizedDialog(minimized: Bool?, modal: Bool?, hasMinimizeButton: Bool) -> Bool {
        minimized == true && modal == false && hasMinimizeButton
    }

    /// Finder's desktop covers a whole display and owns no window controls. Frame size
    /// alone cannot decide: with the menu bar and Dock hidden, an ordinary zoomed window
    /// also fills a display, so a real window is recognised by keeping its close button.
    /// (PRD 12.4: 排除桌面窗口.)
    public static func isFinderDesktopWindow(_ frame: CGRect, displays: [CGRect], hasCloseButton: Bool, tolerance: CGFloat = 2) -> Bool {
        guard !hasCloseButton, frame.width > 0, frame.height > 0 else { return false }
        return displays.contains { display in
            abs(display.minX - frame.minX) <= tolerance && abs(display.minY - frame.minY) <= tolerance
                && abs(display.width - frame.width) <= tolerance && abs(display.height - frame.height) <= tolerance
        }
    }
}

public struct WindowRecord: Equatable, Sendable {
    public let id: UUID
    public let minimized: Bool?
    public init(id: UUID, minimized: Bool? = false) { self.id = id; self.minimized = minimized }
}

public struct WindowSnapshot: Sendable {
    public let windows: [WindowRecord]
    public let focusedID: UUID?
    public let mainID: UUID?
    public let hasModalWindow: Bool

    public init(windows: [WindowRecord], focusedID: UUID? = nil, mainID: UUID? = nil, hasModalWindow: Bool = false) {
        self.windows = windows
        self.focusedID = focusedID
        self.mainID = mainID
        self.hasModalWindow = hasModalWindow
    }
}

public enum WindowAccessError: Error, Equatable, Sendable {
    case permissionDenied, unsupported, unavailable, timedOut, cancelled, missing, modalWindow, busy

    public var explanation: String {
        switch self {
        case .permissionDenied: "辅助功能未授权，已使用应用切换。"
        case .unsupported: "应用未提供可控制的标准窗口。"
        case .unavailable: "未能确认目标窗口，已保留应用切换。"
        case .timedOut: "窗口响应超时，已保留应用切换。"
        case .cancelled: "窗口操作已取消。"
        case .missing: "目标窗口已关闭，请再次尝试。"
        case .modalWindow: "请先处理应用中的对话框。"
        case .busy: "窗口服务仍在处理上一次请求，已保留应用切换。"
        }
    }
}

/// Cancellation can invalidate the next AX call; it cannot interrupt an IPC already in progress.
public final class WindowRequest: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    private let deadline: ContinuousClock.Instant

    public init(timeout: Duration = .seconds(2)) { deadline = .now.advanced(by: timeout) }
    public func cancel() { lock.lock(); cancelled = true; lock.unlock() }
    public func check() throws {
        lock.lock(); let stopped = cancelled; lock.unlock()
        if stopped { throw WindowAccessError.cancelled }
        if ContinuousClock.now >= deadline { throw WindowAccessError.timedOut }
    }
    public func messagingTimeout() throws -> Float {
        try check()
        let remaining = ContinuousClock.now.duration(to: deadline).components
        return Float(min(0.2, max(0.001, Double(remaining.seconds) + Double(remaining.attoseconds) / 1e18)))
    }
}

@MainActor
public protocol WindowClient: AnyObject {
    var hasPermission: Bool { get }
    func snapshot(for process: ApplicationProcess, request: WindowRequest) async throws -> WindowSnapshot
    func focus(_ window: UUID, process: ApplicationProcess, restoreMinimized: Bool, request: WindowRequest) async throws -> Bool
    func clearCache()
}

/// The cursor represents the latest intent; failed/abandoned operations reset the session.
public struct WindowCycle: Sendable {
    private var process: ApplicationProcess?
    private var order: [UUID] = []
    private var cursor: UUID?
    private var lastTrigger: ContinuousClock.Instant?
    public init() {}
    public mutating func reset() { self = WindowCycle() }

    public mutating func select(
        from snapshot: WindowSnapshot, process: ApplicationProcess, advances: Int,
        restoreMinimized: Bool = true, timeout: Duration = .seconds(1),
        now: ContinuousClock.Instant = .now, checkExternalFocus: Bool = true
    ) -> WindowRecord? {
        guard !snapshot.hasModalWindow else { reset(); return nil }
        let eligible = snapshot.windows.filter { restoreMinimized || $0.minimized != true }
        let valid = Set(eligible.map(\.id))
        guard !eligible.isEmpty else { reset(); return nil }
        let expired = lastTrigger.map { $0.duration(to: now) > timeout } ?? true
        let externalFocus = checkExternalFocus && snapshot.focusedID != nil && cursor != nil && snapshot.focusedID != cursor
        if self.process != process || expired || externalFocus || order.allSatisfy({ !valid.contains($0) }) {
            self.process = process
            let anchor = [snapshot.focusedID, snapshot.mainID].compactMap { $0 }.first { valid.contains($0) }
                ?? eligible[0].id
            // Rotate the stable order so a new session continues after the current
            // window instead of repeatedly jumping back to the first discovered one.
            let ids = eligible.map(\.id)
            let anchorIndex = ids.firstIndex(of: anchor) ?? 0
            order = Array(ids[anchorIndex...]) + Array(ids[..<anchorIndex])
            cursor = anchor
        }
        // Keep closed IDs until selection so the cursor still has a position; new windows wait for the next session.
        let start = cursor.flatMap { order.firstIndex(of: $0) } ?? 0
        var index = start
        if advances == 0, !valid.contains(order[index]) {
            repeat { index = (index + 1) % order.count } while !valid.contains(order[index])
        }
        let liveCount = max(1, order.filter { valid.contains($0) }.count)
        let steps = valid.contains(order[start]) ? max(0, advances % liveCount)
            : (advances > 0 ? (advances - 1) % liveCount + 1 : 0)
        for _ in 0..<steps {
            repeat { index = (index + 1) % order.count } while !valid.contains(order[index])
        }
        // A full loop with a destroyed cursor must still land on a live window.
        if !valid.contains(order[index]) {
            repeat { index = (index + 1) % order.count } while !valid.contains(order[index])
        }
        cursor = order[index]
        lastTrigger = now
        return eligible.first { $0.id == cursor }
    }
}
