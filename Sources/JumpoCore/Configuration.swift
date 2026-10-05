import Foundation

public struct AppBinding: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var bundleIdentifier: String
    public var path: String
    public var name: String

    public init(id: UUID = UUID(), bundleIdentifier: String, path: String, name: String) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.path = URL(fileURLWithPath: path).standardizedFileURL.path
        self.name = name
    }
}

public enum TriggerModifier: String, Codable, CaseIterable, Sendable {
    case option, controlOption, commandOption

    public var label: String {
        switch self {
        case .option: "⌥ Option"
        case .controlOption: "⌃⌥ Control + Option"
        case .commandOption: "⌥⌘ Option + Command"
        }
    }

    public var symbols: String {
        switch self {
        case .option: "⌥"
        case .controlOption: "⌃⌥"
        case .commandOption: "⌥⌘"
        }
    }
}

public struct Slot: Codable, Equatable, Identifiable, Sendable {
    public var number: Int
    public var app: AppBinding?
    public var enabled: Bool
    public var id: Int { number }

    public init(number: Int, app: AppBinding? = nil, enabled: Bool = true) {
        self.number = number
        self.app = app
        self.enabled = enabled
    }
}

public enum ConfigurationError: LocalizedError {
    case unsupportedVersion, invalidSlots, duplicateApp, invalidApp, invalidSlot, invalidHUDDelay

    public var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "配置版本不兼容，请保留文件并使用对应版本的 Jumpo。"
        case .invalidSlots: "配置中的槽位无效，应包含编号 1 至 9 的九个槽位。"
        case .duplicateApp: "同一应用不能重复绑定到多个槽位。"
        case .invalidApp: "应用配置不完整。"
        case .invalidSlot: "槽位编号无效。"
        case .invalidHUDDelay: "长按提示延迟应为 100 至 1000 毫秒。"
        }
    }
}

public struct Configuration: Codable, Equatable, Sendable {
    public var schemaVersion = 1
    public var modifier: TriggerModifier = .option
    public var slots: [Slot] = (1...9).map { Slot(number: $0) }
    public var windowManagementEnabled = true
    public var restoreMinimizedWindows = true
    public var holdHUDEnabled = true
    public var hudHoldDelayMilliseconds = 220

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, modifier, slots, windowManagementEnabled, restoreMinimizedWindows
        case holdHUDEnabled, hudHoldDelayMilliseconds
    }

    public init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try values.decode(Int.self, forKey: .schemaVersion)
        modifier = try values.decode(TriggerModifier.self, forKey: .modifier)
        slots = try values.decode([Slot].self, forKey: .slots)
        windowManagementEnabled = try values.decodeIfPresent(Bool.self, forKey: .windowManagementEnabled) ?? true
        restoreMinimizedWindows = try values.decodeIfPresent(Bool.self, forKey: .restoreMinimizedWindows) ?? true
        holdHUDEnabled = try values.decodeIfPresent(Bool.self, forKey: .holdHUDEnabled) ?? true
        hudHoldDelayMilliseconds = try values.decodeIfPresent(Int.self, forKey: .hudHoldDelayMilliseconds) ?? 220
    }

    public var activeSlots: [Slot] {
        slots.filter { $0.enabled && $0.app != nil }.sorted { $0.number < $1.number }
    }

    public func validate() throws {
        guard schemaVersion == 1 else { throw ConfigurationError.unsupportedVersion }
        guard (100...1000).contains(hudHoldDelayMilliseconds) else { throw ConfigurationError.invalidHUDDelay }
        guard slots.count == 9, Set(slots.map(\.number)) == Set(1...9) else {
            throw ConfigurationError.invalidSlots
        }
        let apps = slots.compactMap(\.app)
        guard Set(apps.map { URL(fileURLWithPath: $0.path).standardizedFileURL.path }).count == apps.count else {
            throw ConfigurationError.duplicateApp
        }
        guard apps.allSatisfy({ !$0.bundleIdentifier.isEmpty && !$0.name.isEmpty && $0.path.hasPrefix("/") }) else {
            throw ConfigurationError.invalidApp
        }
    }

    /// Moving an existing binding swaps with the destination; adding a new one replaces it.
    public mutating func assign(_ app: AppBinding, to number: Int) throws {
        guard let destination = slots.firstIndex(where: { $0.number == number }) else {
            throw ConfigurationError.invalidSlot
        }
        if let source = slots.firstIndex(where: { $0.app?.path == app.path }) {
            guard source != destination else { return }
            let old = slots[destination].app
            slots[destination].app = slots[source].app
            slots[source].app = old
        } else {
            slots[destination].app = app
        }
        slots[destination].enabled = true
        try validate()
    }

    public mutating func remove(slot number: Int) {
        guard let index = slots.firstIndex(where: { $0.number == number }) else { return }
        slots[index].app = nil
        slots[index].enabled = true
    }
}
