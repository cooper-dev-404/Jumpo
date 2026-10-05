import AppKit
import Carbon
import JumpoCore

struct HotkeyError: LocalizedError {
    let description: String
    var errorDescription: String? { description }
}

@MainActor
final class HotkeyRegistry: ShortcutBackend {
    private var handler: EventHandlerRef?
    private var references: [Int: EventHotKeyRef] = [:]
    private var heldSlots: Set<Int> = []
    var onPress: ((Int) -> Void)?

    private func installHandler() throws {
        guard handler == nil else { return }
        let events = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject),
                                          EventParamType(typeEventHotKeyID), nil,
                                          MemoryLayout<EventHotKeyID>.size, nil, &identifier)
            guard status == noErr, identifier.signature == 0x4A4D504F else { return OSStatus(eventNotHandledErr) }
            let kind = GetEventKind(event)
            let slot = Int(identifier.id)
            MainActor.assumeIsolated {
                let registry = Unmanaged<HotkeyRegistry>.fromOpaque(context).takeUnretainedValue()
                if kind == UInt32(kEventHotKeyReleased) {
                    registry.heldSlots.remove(slot)
                } else if registry.heldSlots.insert(slot).inserted {
                    registry.onPress?(slot)
                }
            }
            return noErr
        }, events.count, events, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else { throw HotkeyError(description: "无法建立快捷键服务（\(result)）。") }
    }

    func register(_ shortcut: Shortcut) throws {
        try installHandler()
        let modifiers: UInt32
        switch shortcut.modifier {
        case .option: modifiers = UInt32(optionKey)
        case .controlOption: modifiers = UInt32(controlKey | optionKey)
        case .commandOption: modifiers = UInt32(cmdKey | optionKey)
        }
        var reference: EventHotKeyRef?
        let status = RegisterEventHotKey(shortcut.keyCode, modifiers,
                                        EventHotKeyID(signature: 0x4A4D504F, id: UInt32(shortcut.slot)),
                                        GetApplicationEventTarget(), OptionBits(kEventHotKeyExclusive), &reference)
        guard status == noErr, let reference else {
            throw HotkeyError(description: "无法注册 \(shortcut.modifier.symbols)\(shortcut.slot)（\(status)），可能已被占用。")
        }
        references[shortcut.slot] = reference
    }

    func unregisterAll() {
        for reference in references.values { UnregisterEventHotKey(reference) }
        references.removeAll()
        heldSlots.removeAll()
    }

    func resetPressedKeys() { heldSlots.removeAll() }

    func shutdown() {
        unregisterAll()
        if let handler { RemoveEventHandler(handler) }
        handler = nil
    }
}
