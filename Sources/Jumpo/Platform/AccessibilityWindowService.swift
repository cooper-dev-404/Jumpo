import AppKit
@preconcurrency import ApplicationServices
import JumpoCore

@MainActor
final class AccessibilityWindowService: WindowClient {
    private let queue = DispatchQueue(label: "local.jumpo.accessibility", qos: .userInitiated)
    private let worker = AXWindowWorker()
    private var busy = false
    var hasPermission: Bool { AXIsProcessTrusted() }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func snapshot(for process: ApplicationProcess, request: WindowRequest) async throws -> WindowSnapshot {
        guard hasPermission else { throw WindowAccessError.permissionDenied }
        guard !busy else { throw WindowAccessError.busy }
        busy = true
        defer { busy = false }
        // Screen geometry is main-actor state; resolve it before handing work to the worker.
        // Only Finder owns a desktop window, so only Finder pays for the check: a zoomed
        // window of any other app can legitimately fill a display (PRD 12.4).
        let isFinder = NSRunningApplication(processIdentifier: process.pid)?.bundleIdentifier == "com.apple.finder"
        let displays = isFinder ? Self.displayFrames() : []
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [worker] in
                do { continuation.resume(returning: try worker.snapshot(process, displays: displays, request: request)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    /// Display frames in Accessibility coordinates (top-left origin, primary display anchored).
    static func displayFrames() -> [CGRect] {
        let screens = NSScreen.screens
        guard let primary = screens.first else { return [] }
        return screens.map { screen in
            let frame = screen.frame
            return CGRect(x: frame.minX, y: primary.frame.maxY - frame.maxY,
                          width: frame.width, height: frame.height)
        }
    }

    func focus(_ window: UUID, process: ApplicationProcess, restoreMinimized: Bool, request: WindowRequest) async throws -> Bool {
        guard hasPermission else { throw WindowAccessError.permissionDenied }
        guard !busy else { throw WindowAccessError.busy }
        busy = true
        defer { busy = false }
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [worker] in
                do { continuation.resume(returning: try worker.focus(window, process: process, restore: restoreMinimized, request: request)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    func clearCache() { queue.async { [worker] in worker.clear() } }

    func focusedWindowFrame(for process: ApplicationProcess, request: WindowRequest) async throws -> CGRect? {
        guard hasPermission else { throw WindowAccessError.permissionDenied }
        return try await withCheckedThrowingContinuation { continuation in
            queue.async { [worker] in
                do { continuation.resume(returning: try worker.focusedFrame(process, request: request)) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }
}

/// AX references and mutable caches never leave this service's dedicated serial queue.
private final class AXWindowWorker: @unchecked Sendable {
    private var process: ApplicationProcess?
    private var application: AXUIElement?
    private var elements: [UUID: AXUIElement] = [:]
    private var order: [UUID] = []

    func clear() { process = nil; application = nil; elements = [:]; order = [] }

    func focusedFrame(_ process: ApplicationProcess, request: WindowRequest) throws -> CGRect? {
        try verifyProcess(process, request: request)
        let app = AXUIElementCreateApplication(process.pid)
        guard let window = element(try read(app, kAXFocusedWindowAttribute, request: request)),
              let position = try read(window, kAXPositionAttribute, request: request),
              let size = try read(window, kAXSizeAttribute, request: request),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return nil }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &dimensions),
              dimensions.width > 0, dimensions.height > 0 else { return nil }
        try request.check()
        return CGRect(origin: point, size: dimensions)
    }

    func snapshot(_ process: ApplicationProcess, displays: [CGRect], request: WindowRequest) throws -> WindowSnapshot {
        try verifyProcess(process, request: request)
        if self.process != process {
            clear()
            self.process = process
            application = AXUIElementCreateApplication(process.pid)
        }
        guard let app = application else { throw WindowAccessError.unavailable }
        let focused = element(try read(app, kAXFocusedWindowAttribute, request: request))
        let main = element(try read(app, kAXMainWindowAttribute, request: request))
        if let focused, try hasModal(focused, request: request) {
            return WindowSnapshot(windows: [], hasModalWindow: true)
        }
        try prepare(app, request: request)
        var count: CFIndex = 0
        try check(AXUIElementGetAttributeValueCount(app, kAXWindowsAttribute as CFString, &count))
        guard count <= 64 else { throw WindowAccessError.unsupported }
        var values: CFArray?
        if count > 0 {
            try prepare(app, request: request)
            try check(AXUIElementCopyAttributeValues(app, kAXWindowsAttribute as CFString, 0, count, &values))
        }
        let windows = (values as? [AXUIElement]) ?? []
        var current: [UUID: AXUIElement] = [:]
        var records: [UUID: WindowRecord] = [:]
        var discovered: [UUID] = []
        for window in windows {
            do {
                let role = try read(window, kAXRoleAttribute, request: request) as? String
                let subrole = try read(window, kAXSubroleAttribute, request: request) as? String
                guard role == kAXWindowRole else { continue }
                let minimized = try read(window, kAXMinimizedAttribute, request: request) as? Bool
                let restorableDialog = subrole == kAXDialogSubrole
                    ? try canRestoreMinimizedDialog(window, minimized: minimized, request: request) : false
                guard subrole == kAXStandardWindowSubrole || restorableDialog else { continue }
                // PRD 12.4: Finder owns a full-display desktop window. It is a window but
                // never a usable target, so it must not be selected by the cycle.
                if try isDesktopWindow(window, displays: displays, request: request) { continue }
                if try hasModal(window, request: request) {
                    return WindowSnapshot(windows: [], hasModalWindow: true)
                }
                let id = elements.first(where: { CFEqual($0.value, window) })?.key ?? UUID()
                current[id] = window
                records[id] = WindowRecord(id: id, minimized: minimized)
                discovered.append(id)
            } catch WindowAccessError.missing { continue }
        }
        try request.check()
        order = order.filter { current[$0] != nil } + discovered.filter { !order.contains($0) }
        elements = current
        return WindowSnapshot(windows: order.compactMap { records[$0] },
                              focusedID: focused.flatMap { focus in current.first { CFEqual($0.value, focus) }?.key },
                              mainID: main.flatMap { main in current.first { CFEqual($0.value, main) }?.key })
    }

    func focus(_ id: UUID, process: ApplicationProcess, restore: Bool, request: WindowRequest) throws -> Bool {
        try verifyProcess(process, request: request)
        guard self.process == process, let app = application, let window = elements[id] else { throw WindowAccessError.missing }
        if let focused = element(try read(app, kAXFocusedWindowAttribute, request: request)),
           try hasModal(focused, request: request) { throw WindowAccessError.modalWindow }
        if try hasModal(window, request: request) { throw WindowAccessError.modalWindow }
        let minimized = try read(window, kAXMinimizedAttribute, request: request) as? Bool
        var restored = false
        if minimized == true {
            guard restore else { throw WindowAccessError.unsupported }
            try write(window, kAXMinimizedAttribute, value: kCFBooleanFalse, process: process, request: request)
            // AppKit's restore animation is asynchronous. Wait on this worker
            // within the original request budget before attempting focus writes.
            for _ in 0..<30 {
                try verifyProcess(process, request: request)
                do {
                    if try read(window, kAXMinimizedAttribute, request: request) as? Bool == false {
                        restored = true
                        break
                    }
                } catch WindowAccessError.timedOut {
                    // The target may be servicing its restore animation. A single
                    // IPC timeout is not the deadline of the whole request.
                    try request.check()
                }
                Thread.sleep(forTimeInterval: 0.03)
            }
            guard restored else { throw WindowAccessError.timedOut }
            if try hasModal(window, request: request) { throw WindowAccessError.modalWindow }
        }
        for attempt in 0..<2 {
            if try isFocused(window, app: app, request: request) { return restored }
            // A stale request must never issue a new focus/raise operation.
            try verifyProcess(process, request: request)
            try prepare(window, request: request)
            try checkMutation(AXUIElementPerformAction(window, kAXRaiseAction as CFString), request: request)
            try writeIfSupported(window, kAXMainAttribute, value: kCFBooleanTrue, process: process, request: request)
            try writeIfSupported(app, kAXFocusedWindowAttribute, value: window, process: process, request: request)
            for _ in 0..<5 {
                try verifyProcess(process, request: request)
                if try isFocused(window, app: app, request: request) { return restored }
                // Sleep only on this serial worker, never on MainActor or the cooperative executor.
                Thread.sleep(forTimeInterval: 0.03)
            }
            if attempt == 0, try hasModal(window, request: request) { throw WindowAccessError.modalWindow }
        }
        throw WindowAccessError.unavailable
    }

    private func verifyProcess(_ process: ApplicationProcess, request: WindowRequest) throws {
        try request.check()
        guard AXIsProcessTrusted() else { clear(); throw WindowAccessError.permissionDenied }
        guard let running = NSRunningApplication(processIdentifier: process.pid), !running.isTerminated,
              running.launchDate?.timeIntervalSince1970 == process.launchedAt else { clear(); throw WindowAccessError.missing }
        guard running.isActive else { throw WindowAccessError.cancelled }
    }

    private func prepare(_ element: AXUIElement, request: WindowRequest) throws {
        guard AXIsProcessTrusted() else { clear(); throw WindowAccessError.permissionDenied }
        try check(AXUIElementSetMessagingTimeout(element, try request.messagingTimeout()))
    }

    private func read(_ element: AXUIElement, _ attribute: String, request: WindowRequest) throws -> CFTypeRef? {
        try prepare(element, request: request)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        if result == .attributeUnsupported || result == .noValue { return nil }
        try check(result)
        try request.check()
        return value
    }

    private func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    private func isDesktopWindow(_ window: AXUIElement, displays: [CGRect], request: WindowRequest) throws -> Bool {
        guard !displays.isEmpty,
              let position = try read(window, kAXPositionAttribute, request: request),
              let size = try read(window, kAXSizeAttribute, request: request),
              CFGetTypeID(position) == AXValueGetTypeID(), CFGetTypeID(size) == AXValueGetTypeID() else { return false }
        var point = CGPoint.zero
        var dimensions = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &point),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &dimensions) else { return false }
        // Missing attributes must not fail a whole snapshot: absence already means "no control".
        let closeButton = (try? read(window, kAXCloseButtonAttribute, request: request)) ?? nil
        return WindowAccessPolicy.isFinderDesktopWindow(CGRect(origin: point, size: dimensions),
                                                        displays: displays,
                                                        hasCloseButton: element(closeButton) != nil)
    }

    private func hasModal(_ window: AXUIElement, request: WindowRequest) throws -> Bool {
        if try read(window, kAXModalAttribute, request: request) as? Bool == true { return true }
        let subrole = try read(window, kAXSubroleAttribute, request: request) as? String
        if subrole == kAXSystemDialogSubrole { return true }
        if subrole == kAXDialogSubrole {
            let minimized = try read(window, kAXMinimizedAttribute, request: request) as? Bool
            if try !canRestoreMinimizedDialog(window, minimized: minimized, request: request) { return true }
        }
        if try read(window, kAXRoleAttribute, request: request) as? String == kAXSheetRole { return true }
        let children = try read(window, kAXChildrenAttribute, request: request) as? [AXUIElement] ?? []
        guard children.count <= 64 else { throw WindowAccessError.unsupported }
        for child in children {
            if try read(child, kAXRoleAttribute, request: request) as? String == kAXSheetRole { return true }
        }
        return false
    }

    private func canRestoreMinimizedDialog(_ window: AXUIElement, minimized: Bool?, request: WindowRequest) throws -> Bool {
        guard minimized == true else { return false }
        let modal = try read(window, kAXModalAttribute, request: request) as? Bool
        let hasButton = element(try read(window, kAXMinimizeButtonAttribute, request: request)) != nil
        return WindowAccessPolicy.canRestoreMinimizedDialog(minimized: minimized, modal: modal, hasMinimizeButton: hasButton)
    }

    private func isFocused(_ window: AXUIElement, app: AXUIElement, request: WindowRequest) throws -> Bool {
        let focused = element(try read(app, kAXFocusedWindowAttribute, request: request))
        let minimized = try read(window, kAXMinimizedAttribute, request: request) as? Bool
        return focused.map { CFEqual($0, window) } == true && minimized == false
    }

    private func write(_ element: AXUIElement, _ attribute: String, value: CFTypeRef, process: ApplicationProcess, request: WindowRequest) throws {
        try verifyProcess(process, request: request)
        try prepare(element, request: request)
        var settable: DarwinBoolean = false
        try check(AXUIElementIsAttributeSettable(element, attribute as CFString, &settable))
        guard settable.boolValue else { throw WindowAccessError.unsupported }
        try verifyProcess(process, request: request)
        try prepare(element, request: request)
        try checkMutation(AXUIElementSetAttributeValue(element, attribute as CFString, value), request: request)
    }

    private func writeIfSupported(_ element: AXUIElement, _ attribute: String, value: CFTypeRef, process: ApplicationProcess, request: WindowRequest) throws {
        do { try write(element, attribute, value: value, process: process, request: request) }
        catch WindowAccessError.unsupported { /* Raising can work without a writable focus attribute. */ }
    }

    private func check(_ error: AXError) throws {
        switch error {
        case .success: return
        case .apiDisabled: clear(); throw WindowAccessError.permissionDenied
        case .invalidUIElement: throw WindowAccessError.missing
        case .attributeUnsupported, .actionUnsupported, .notImplemented: throw WindowAccessError.unsupported
        case .cannotComplete: throw WindowAccessError.timedOut
        default: throw WindowAccessError.unavailable
        }
    }

    private func checkMutation(_ error: AXError, request: WindowRequest) throws {
        if error == .cannotComplete {
            // The write can finish after the IPC reply times out. Its caller must
            // verify minimized/focused state; do not reissue this write blindly.
            try request.check()
            return
        }
        try check(error)
    }
}
