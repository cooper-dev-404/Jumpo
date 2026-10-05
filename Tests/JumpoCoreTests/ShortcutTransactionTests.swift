import Testing
@testable import JumpoCore

private enum RegistrationFailure: Error { case conflict }

@MainActor private final class FakeShortcuts: ShortcutBackend {
    var registered: [Shortcut] = []
    var failSlot: Int?
    var failEverythingAfterConflict = false
    private var hasFailed = false

    func register(_ shortcut: Shortcut) throws {
        if shortcut.slot == failSlot || (hasFailed && failEverythingAfterConflict) {
            hasFailed = true
            throw RegistrationFailure.conflict
        }
        registered.append(shortcut)
    }
    func unregisterAll() { registered = [] }
}

@Test @MainActor func failedRegistrationRestoresPreviousShortcuts() throws {
    let backend = FakeShortcuts()
    let transaction = ShortcutTransaction(backend: backend)
    let old = [Shortcut(slot: 1, keyCode: 18, modifier: .option)]
    try transaction.replace(with: old)
    backend.failSlot = 2
    let proposed = old + [Shortcut(slot: 2, keyCode: 19, modifier: .option)]
    do {
        try transaction.replace(with: proposed)
        Issue.record("Expected a registration error")
    } catch let error as ShortcutUpdateError {
        #expect(!error.rollbackFailed)
    }
    #expect(transaction.active == old)
    #expect(backend.registered == old)
}

@Test @MainActor func failedRollbackUnregistersEverything() throws {
    let backend = FakeShortcuts()
    let transaction = ShortcutTransaction(backend: backend)
    let old = [Shortcut(slot: 1, keyCode: 18, modifier: .option)]
    try transaction.replace(with: old)
    backend.failSlot = 2
    backend.failEverythingAfterConflict = true
    do {
        try transaction.replace(with: [Shortcut(slot: 2, keyCode: 19, modifier: .option)])
        Issue.record("Expected a registration error")
    } catch let error as ShortcutUpdateError {
        #expect(error.rollbackFailed)
    }
    #expect(transaction.active.isEmpty)
    #expect(backend.registered.isEmpty)
}

@Test @MainActor func pauseUnregistersAllShortcuts() throws {
    let backend = FakeShortcuts()
    let transaction = ShortcutTransaction(backend: backend)
    try transaction.replace(with: [Shortcut(slot: 9, keyCode: 25, modifier: .option)])
    transaction.stop()
    #expect(backend.registered.isEmpty)
    #expect(transaction.active.isEmpty)
}
