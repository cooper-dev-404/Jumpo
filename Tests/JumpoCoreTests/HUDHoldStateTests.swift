import Foundation
import Testing
@testable import JumpoCore

@Test func holdShowsOnlyAfterItsOwnDelayAndClosesOnRelease() throws {
    var state = HUDHoldState(trigger: .option)
    state.flagsChanged(.option)
    let ticket = try #require(state.pendingTicket)
    #expect(state.phase == .pending(ticket))
    let shown = state.timerElapsed(ticket: ticket)
    #expect(shown)
    #expect(state.phase == .visible)
    state.flagsChanged([])
    #expect(state.phase == .idle)
}

@Test func directJumpAndOrdinaryInputSuppressHUDUntilRelease() throws {
    var state = HUDHoldState(trigger: .option)
    state.flagsChanged(.option)
    let ticket = try #require(state.pendingTicket)
    state.cancelHold()
    let shown = state.timerElapsed(ticket: ticket)
    #expect(!shown)
    state.flagsChanged(.option)
    #expect(state.pendingTicket == nil)
    state.flagsChanged([])
    state.flagsChanged(.option)
    #expect(state.pendingTicket != nil)
}

@Test func escapeDismissesVisibleHUDWithoutRearmingHeldModifier() throws {
    var state = HUDHoldState(trigger: .option)
    state.flagsChanged(.option)
    let shown = state.timerElapsed(ticket: try #require(state.pendingTicket))
    #expect(shown)
    state.cancelHold()
    state.flagsChanged(.option)
    #expect(state.phase == .suppressed)
}

@Test func oldTimerCannotDisplayANewerHold() throws {
    var state = HUDHoldState(trigger: .option)
    state.flagsChanged(.option)
    let old = try #require(state.pendingTicket)
    state.flagsChanged([])
    state.flagsChanged(.option)
    let new = try #require(state.pendingTicket)
    #expect(old != new)
    let oldShown = state.timerElapsed(ticket: old)
    let newShown = state.timerElapsed(ticket: new)
    #expect(!oldShown)
    #expect(newShown)
}

@Test func extraModifierCancelsEvenWhenRemovedBeforeDeadline() throws {
    var state = HUDHoldState(trigger: .option)
    state.flagsChanged(.option)
    let ticket = try #require(state.pendingTicket)
    state.flagsChanged([.option, .shift])
    state.flagsChanged(.option)
    #expect(state.phase == .suppressed)
    let shown = state.timerElapsed(ticket: ticket)
    #expect(!shown)
}

@Test func combinationWaitsForBothKeysAndRequiresCompleteReleaseAfterCancellation() throws {
    var state = HUDHoldState(trigger: .commandOption)
    state.flagsChanged(.command)
    #expect(state.pendingTicket == nil)
    state.flagsChanged([.command, .option])
    let shown = state.timerElapsed(ticket: try #require(state.pendingTicket))
    #expect(shown)
    state.flagsChanged(.option)
    state.flagsChanged([.command, .option])
    #expect(state.phase == .suppressed)
    state.flagsChanged([])
    state.flagsChanged([.command, .option])
    #expect(state.pendingTicket != nil)
}

@Test func enablingOrWakingWithHeldKeysCannotOpenHUD() {
    var state = HUDHoldState(trigger: .controlOption)
    state.synchronize([.control, .option])
    state.flagsChanged([.control, .option])
    #expect(state.phase == .suppressed)
    state.flagsChanged([])
    state.flagsChanged([.control, .option])
    #expect(state.pendingTicket != nil)
}

@Test func functionKeyAndPreexistingExtraModifiersPreventHold() {
    var state = HUDHoldState(trigger: .option)
    state.flagsChanged([.option, .function])
    state.flagsChanged(.option)
    #expect(state.phase == .suppressed)
}

@Test func ordinaryTypingWithoutTriggerDoesNotDisableTheNextHold() {
    var state = HUDHoldState(trigger: .option)
    state.cancelHold()
    #expect(state.phase == .idle)
    state.flagsChanged(.option)
    #expect(state.pendingTicket != nil)
}

@Test func oldConfigurationGetsHUDDefaultsAndNewPreferencesRoundTrip() throws {
    let old = """
    {"schemaVersion":1,"modifier":"option","slots":[\( (1...9).map { "{\"number\":\($0),\"enabled\":true}" }.joined(separator: ",") )]}
    """
    var configuration = try JSONDecoder().decode(Configuration.self, from: Data(old.utf8))
    #expect(configuration.holdHUDEnabled)
    #expect(configuration.hudHoldDelayMilliseconds == 220)
    configuration.holdHUDEnabled = false
    configuration.hudHoldDelayMilliseconds = 450
    #expect(try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(configuration)) == configuration)
    configuration.hudHoldDelayMilliseconds = 0
    #expect(throws: ConfigurationError.invalidHUDDelay) { try configuration.validate() }
}
