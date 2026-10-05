import Foundation

public struct HUDModifiers: OptionSet, Sendable, Equatable {
    public let rawValue: UInt8
    public init(rawValue: UInt8) { self.rawValue = rawValue }
    public static let option = Self(rawValue: 1 << 0)
    public static let control = Self(rawValue: 1 << 1)
    public static let command = Self(rawValue: 1 << 2)
    public static let shift = Self(rawValue: 1 << 3)
    public static let function = Self(rawValue: 1 << 4)

    public init(trigger: TriggerModifier) {
        switch trigger {
        case .option: self = .option
        case .controlOption: self = [.control, .option]
        case .commandOption: self = [.command, .option]
        }
    }
}

/// A cancelled hold stays suppressed until every configured modifier is released.
/// Timers carry a ticket so a callback from an older hold cannot show the HUD.
public struct HUDHoldState: Sendable {
    public enum Phase: Equatable, Sendable {
        case idle, pending(UUID), visible, suppressed
    }

    public private(set) var phase: Phase = .idle
    private let trigger: HUDModifiers
    private var modifiers: HUDModifiers = []

    public init(trigger: TriggerModifier) { self.trigger = HUDModifiers(trigger: trigger) }

    public var pendingTicket: UUID? {
        if case .pending(let ticket) = phase { return ticket }
        return nil
    }

    public mutating func flagsChanged(_ modifiers: HUDModifiers) {
        self.modifiers = modifiers
        if modifiers.intersection(trigger).isEmpty {
            phase = .idle
        } else if modifiers == trigger {
            if phase == .idle { phase = .pending(UUID()) }
        } else if phase != .idle || !modifiers.subtracting(trigger).isEmpty {
            phase = .suppressed
        }
    }

    public mutating func cancelHold() {
        phase = modifiers.intersection(trigger).isEmpty ? .idle : .suppressed
    }

    /// Enabling, waking, or changing settings must not arm an already-held key.
    public mutating func synchronize(_ modifiers: HUDModifiers) {
        self.modifiers = modifiers
        phase = modifiers.intersection(trigger).isEmpty ? .idle : .suppressed
    }

    @discardableResult
    public mutating func timerElapsed(ticket: UUID) -> Bool {
        guard phase == .pending(ticket), modifiers == trigger else { return false }
        phase = .visible
        return true
    }
}
