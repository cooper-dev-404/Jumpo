import Foundation

public struct ConfigurationStore: Sendable {
    public let directory: URL
    public var fileURL: URL { directory.appendingPathComponent("configuration.json") }
    public var backupURL: URL { directory.appendingPathComponent("configuration.backup.json") }

    public init(directory: URL) { self.directory = directory }

    public func load() throws -> Configuration {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return Configuration() }
        return try decode(Data(contentsOf: fileURL))
    }

    public func save(_ configuration: Configuration) throws {
        try configuration.validate()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let old = try Data(contentsOf: fileURL)
            // Never overwrite an unreadable configuration as a side effect of an ordinary edit.
            _ = try decode(old)
            try old.write(to: backupURL, options: .atomic)
        }
        try data.write(to: fileURL, options: .atomic)
    }

    public func recover(useBackup: Bool) throws -> Configuration {
        let configuration = useBackup ? try decode(Data(contentsOf: backupURL)) : Configuration()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(configuration)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let preserved = directory.appendingPathComponent("configuration.unreadable-\(UUID().uuidString).json")
            try FileManager.default.copyItem(at: fileURL, to: preserved)
        }
        try data.write(to: fileURL, options: .atomic)
        return configuration
    }

    private func decode(_ data: Data) throws -> Configuration {
        let configuration = try JSONDecoder().decode(Configuration.self, from: data)
        try configuration.validate()
        return configuration
    }
}
