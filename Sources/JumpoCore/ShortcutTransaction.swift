import Foundation

public struct Shortcut: Equatable, Sendable {
    public let slot: Int
    public let keyCode: UInt32
    public let modifier: TriggerModifier

    public init(slot: Int, keyCode: UInt32, modifier: TriggerModifier) {
        self.slot = slot
        self.keyCode = keyCode
        self.modifier = modifier
    }

    public static func plan(for configuration: Configuration) -> [Shortcut] {
        let keyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        return configuration.activeSlots.compactMap { slot in
            guard (1...9).contains(slot.number) else { return nil }
            return Shortcut(slot: slot.number, keyCode: keyCodes[slot.number - 1], modifier: configuration.modifier)
        }
    }
}

@MainActor
public protocol ShortcutBackend: AnyObject {
    func register(_ shortcut: Shortcut) throws
    func unregisterAll()
}

public struct ShortcutUpdateError: LocalizedError {
    public let cause: String
    public let rollbackFailed: Bool

    public var errorDescription: String? {
        rollbackFailed
            ? "\(cause) 旧快捷键也未能恢复，已暂停全部快捷键，请更换组合后重试。"
            : "\(cause) 已保留之前的设置。"
    }
}

@MainActor
public final class ShortcutTransaction {
    private let backend: any ShortcutBackend
    public private(set) var active: [Shortcut] = []

    public init(backend: any ShortcutBackend) { self.backend = backend }

    public func replace(with proposed: [Shortcut]) throws {
        guard proposed != active else { return }
        let previous = active
        backend.unregisterAll()
        active = []
        do {
            for shortcut in proposed { try backend.register(shortcut) }
            active = proposed
        } catch {
            let cause = error.localizedDescription
            backend.unregisterAll()
            do {
                for shortcut in previous { try backend.register(shortcut) }
                active = previous
            } catch {
                backend.unregisterAll()
                throw ShortcutUpdateError(cause: cause, rollbackFailed: true)
            }
            throw ShortcutUpdateError(cause: cause, rollbackFailed: false)
        }
    }

    public func stop() {
        backend.unregisterAll()
        active = []
    }
}
