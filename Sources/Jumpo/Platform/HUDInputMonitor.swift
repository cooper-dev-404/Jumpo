import AppKit
import ApplicationServices
import Carbon
import JumpoCore

extension HUDModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self = []
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.control) { insert(.control) }
        if flags.contains(.command) { insert(.command) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.function) { insert(.function) }
        // Caps Lock, numericPad and device-dependent left/right bits do not alter the trigger.
    }
}

/// Observes input only. Registered slot shortcuts remain owned by HotkeyRegistry.
@MainActor
final class HUDInputMonitor {
    var onPending: (() -> Void)?
    var onShow: (() -> Void)?
    var onHide: (() -> Void)?
    var onAvailability: ((String) -> Void)?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var timer: Task<Void, Never>?
    private var healthCheck: Task<Void, Never>?
    private var state = HUDHoldState(trigger: .option)
    private var modifier: TriggerModifier = .option
    private var enabled = false
    private var paused = false
    private var suspended = false
    private var delay = 220
    private var status = ""

    init() {
        healthCheck = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
                self?.refreshAvailability()
            }
        }
    }

    func configure(enabled: Bool, paused: Bool, modifier: TriggerModifier, delay: Int) {
        if self.enabled != enabled || self.paused != paused || self.modifier != modifier || self.delay != delay {
            stopObserving()
            self.enabled = enabled
            self.paused = paused
            self.modifier = modifier
            self.delay = delay
            state = HUDHoldState(trigger: modifier)
        }
        refreshAvailability()
    }

    func setSuspended(_ suspended: Bool) {
        self.suspended = suspended
        stopObserving()
        refreshAvailability()
    }

    func cancelHold() {
        timer?.cancel()
        timer = nil
        state.synchronize(HUDModifiers(NSEvent.modifierFlags))
        state.cancelHold()
        onHide?()
    }

    private var unavailableReason: String? {
        if paused { return "快捷键已暂停，可从菜单打开提示面板。" }
        if !enabled { return "长按提示已关闭，可从菜单打开提示面板。" }
        if suspended { return "系统会话已暂停，长按提示暂不可用。" }
        if IsSecureEventInputEnabled() { return "系统正在保护键盘输入，长按提示暂不可用。" }
        if !AXIsProcessTrusted() { return "长按提示需要辅助功能授权，可先从菜单打开提示面板。" }
        return nil
    }

    func refreshAvailability() {
        if let reason = unavailableReason {
            if globalMonitor != nil || localMonitor != nil { stopObserving() }
            publish(reason)
            return
        }
        if globalMonitor == nil {
            let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown, .leftMouseDown, .rightMouseDown,
                                              .otherMouseDown, .leftMouseDragged, .rightMouseDragged,
                                              .otherMouseDragged, .scrollWheel]
            globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
                MainActor.assumeIsolated { self?.receive(event) }
            }
            localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
                MainActor.assumeIsolated { self?.receive(event) }
                return event
            }
            guard globalMonitor != nil, localMonitor != nil else {
                stopObserving()
                publish("无法建立长按监听，请从菜单打开提示面板。")
                return
            }
            state.synchronize(HUDModifiers(NSEvent.modifierFlags))
        }
        publish("长按监听已开启。")
    }

    private func receive(_ event: NSEvent) {
        guard unavailableReason == nil else { refreshAvailability(); return }
        if event.type == .flagsChanged {
            let previous = state.pendingTicket
            state.flagsChanged(HUDModifiers(event.modifierFlags))
            if NSEvent.pressedMouseButtons != 0 || otherKeyIsDown { state.cancelHold() }
            if let ticket = state.pendingTicket, previous != ticket {
                timer?.cancel()
                onPending?()
                timer = Task { [weak self, delay] in
                    do { try await Task.sleep(for: .milliseconds(delay)) } catch { return }
                    guard let self, unavailableReason == nil else { self?.cancelHold(); return }
                    state.flagsChanged(HUDModifiers(NSEvent.modifierFlags))
                    if NSEvent.pressedMouseButtons != 0 || otherKeyIsDown { state.cancelHold() }
                    if state.timerElapsed(ticket: ticket) { onShow?() }
                }
            }
            if state.pendingTicket == nil { timer?.cancel(); timer = nil }
            if state.phase != .visible { onHide?() }
        } else {
            cancelHold()
        }
    }

    private var otherKeyIsDown: Bool {
        // Covers keys held before Option, including a keyDown consumed by a registered hotkey.
        let modifiers: Set<CGKeyCode> = [54, 55, 56, 57, 58, 59, 60, 61, 62, 63]
        return (CGKeyCode(0)...127).contains {
            !modifiers.contains($0) && CGEventSource.keyState(.combinedSessionState, key: $0)
        }
    }

    private func publish(_ value: String) {
        guard value != status else { return }
        status = value
        onAvailability?(value)
    }

    private func stopObserving() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        cancelHold()
    }

    func shutdown() {
        healthCheck?.cancel()
        stopObserving()
    }
}
