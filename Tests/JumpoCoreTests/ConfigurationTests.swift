import Foundation
import Testing
@testable import JumpoCore

func testApp(_ name: String) -> AppBinding {
    AppBinding(bundleIdentifier: "test.\(name)", path: "/Applications/\(name).app", name: name)
}

@Test func emptyAndDisabledSlotsDoNotRegister() throws {
    var configuration = Configuration()
    #expect(Shortcut.plan(for: configuration).isEmpty)
    try configuration.assign(testApp("A"), to: 1)
    try configuration.assign(testApp("B"), to: 6)
    configuration.slots[0].enabled = false
    configuration.modifier = .commandOption
    #expect(Shortcut.plan(for: configuration) == [Shortcut(slot: 6, keyCode: 22, modifier: .commandOption)])
}

@Test func existingBindingMovesAndSwapsWithoutDuplication() throws {
    var configuration = Configuration()
    let a = testApp("A"), b = testApp("B")
    try configuration.assign(a, to: 1)
    try configuration.assign(a, to: 3)
    #expect(configuration.slots[0].app == nil)
    #expect(configuration.slots[2].app == a)
    try configuration.assign(b, to: 2)
    try configuration.assign(a, to: 2)
    #expect(configuration.slots[1].app == a)
    #expect(configuration.slots[2].app == b)
    #expect(configuration.activeSlots.count == 2)
    try configuration.validate()
}

@Test func invalidConfigurationIsRejected() throws {
    var configuration = Configuration()
    configuration.slots[8].number = 1
    #expect(throws: ConfigurationError.self) { try configuration.validate() }
    configuration = Configuration()
    configuration.schemaVersion = 2
    #expect(throws: ConfigurationError.self) { try configuration.validate() }
    configuration = Configuration()
    let app = testApp("A")
    configuration.slots[0].app = app
    configuration.slots[1].app = app
    #expect(throws: ConfigurationError.self) { try configuration.validate() }
}

@Test func storeRoundTripAndBackup() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ConfigurationStore(directory: directory)
    #expect(try store.load() == Configuration())
    var configuration = Configuration()
    try configuration.assign(testApp("A"), to: 9)
    try store.save(configuration)
    #expect(try store.load() == configuration)
    let previous = configuration
    configuration.modifier = .controlOption
    try store.save(configuration)
    #expect(try store.load() == configuration)
    let backup = try JSONDecoder().decode(Configuration.self, from: Data(contentsOf: store.backupURL))
    #expect(backup == previous)
}

@Test func corruptConfigurationIsPreservedDuringRecovery() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = ConfigurationStore(directory: directory)
    var original = Configuration()
    try original.assign(testApp("A"), to: 1)
    try store.save(original)
    try store.save(Configuration())
    let corrupted = Data("invalid JSON".utf8)
    try corrupted.write(to: store.fileURL)
    #expect(throws: (any Error).self) { try store.load() }
    #expect(throws: (any Error).self) { try store.save(Configuration()) }
    #expect(try Data(contentsOf: store.fileURL) == corrupted)
    #expect(try store.recover(useBackup: true) == original)
    #expect(try store.load() == original)
    let preserved = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        .filter { $0.lastPathComponent.hasPrefix("configuration.unreadable-") }
    #expect(preserved.count == 1)
    #expect(try Data(contentsOf: #require(preserved.first)) == corrupted)
}
