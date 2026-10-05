import Foundation
import Testing
@testable import JumpoCore

@Test func minimizedDocumentWindowCanRemainEligibleWhenReportedAsDialog() {
    #expect(WindowAccessPolicy.canRestoreMinimizedDialog(minimized: true, modal: false, hasMinimizeButton: true))
}

@Test func visibleModalAndUncertainDialogsCannotUseMinimizedWindowException() {
    #expect(!WindowAccessPolicy.canRestoreMinimizedDialog(minimized: false, modal: false, hasMinimizeButton: true))
    #expect(!WindowAccessPolicy.canRestoreMinimizedDialog(minimized: nil, modal: false, hasMinimizeButton: true))
    #expect(!WindowAccessPolicy.canRestoreMinimizedDialog(minimized: true, modal: true, hasMinimizeButton: true))
    #expect(!WindowAccessPolicy.canRestoreMinimizedDialog(minimized: true, modal: nil, hasMinimizeButton: true))
    #expect(!WindowAccessPolicy.canRestoreMinimizedDialog(minimized: true, modal: false, hasMinimizeButton: false))
}

@Test func desktopSizedWindowIsNotAnActivationTarget() {
    let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
    // Finder's desktop covers the whole display and has no window controls.
    #expect(WindowAccessPolicy.isFinderDesktopWindow(primary, displays: [primary], hasCloseButton: false))
    // A window constrained to the visible frame (menu bar and Dock excluded) is real.
    #expect(!WindowAccessPolicy.isFinderDesktopWindow(CGRect(x: 0, y: 25, width: 1440, height: 850), displays: [primary], hasCloseButton: false))
    // Ordinary windows stay selectable.
    #expect(!WindowAccessPolicy.isFinderDesktopWindow(CGRect(x: 240, y: 90, width: 960, height: 746), displays: [primary], hasCloseButton: false))
    #expect(!WindowAccessPolicy.isFinderDesktopWindow(.zero, displays: [primary], hasCloseButton: false))
}

@Test func zoomedWindowFillingADisplayStaysSelectable() {
    let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
    // Menu bar and Dock can be hidden, so a zoomed Finder window also fills the display:
    // it keeps its close button and must keep cycling (regression seen on a real setup).
    #expect(!WindowAccessPolicy.isFinderDesktopWindow(primary, displays: [primary], hasCloseButton: true))
    #expect(!WindowAccessPolicy.isFinderDesktopWindow(CGRect(x: 0, y: 25, width: 1440, height: 875), displays: [primary], hasCloseButton: true))
}

@Test func secondaryDisplayDesktopIsRecognised() {
    let primary = CGRect(x: 0, y: 0, width: 1440, height: 900)
    let secondary = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
    #expect(WindowAccessPolicy.isFinderDesktopWindow(secondary, displays: [primary, secondary], hasCloseButton: false))
    // A same-sized window on the wrong origin is not a desktop.
    #expect(!WindowAccessPolicy.isFinderDesktopWindow(CGRect(x: 1440, y: 200, width: 1920, height: 1080), displays: [primary, secondary], hasCloseButton: false))
    // Apps other than Finder are never checked, so an empty display list excludes nothing.
    #expect(!WindowAccessPolicy.isFinderDesktopWindow(secondary, displays: [], hasCloseButton: false))
}

@Test func threeWindowsCycleWithoutRecentOrderOscillation() {
    let a = WindowRecord(id: UUID()), b = WindowRecord(id: UUID()), c = WindowRecord(id: UUID())
    let process = ApplicationProcess(pid: 1)
    var cycle = WindowCycle()
    #expect(cycle.select(from: WindowSnapshot(windows: [a, b, c], focusedID: a.id), process: process, advances: 0)?.id == a.id)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, b, c], focusedID: a.id), process: process, advances: 1)?.id == b.id)
    #expect(cycle.select(from: WindowSnapshot(windows: [b, a, c], focusedID: b.id), process: process, advances: 1)?.id == c.id)
    #expect(cycle.select(from: WindowSnapshot(windows: [c, b, a], focusedID: c.id), process: process, advances: 1)?.id == a.id)
}

@Test func slowTriggersStillReachEveryWindowAfterSessionTimeout() {
    let a = WindowRecord(id: UUID()), b = WindowRecord(id: UUID()), c = WindowRecord(id: UUID())
    let process = ApplicationProcess(pid: 1), now = ContinuousClock.now
    var cycle = WindowCycle()
    _ = cycle.select(from: WindowSnapshot(windows: [a, b, c], focusedID: a.id), process: process, advances: 1, now: now)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, b, c], focusedID: b.id), process: process, advances: 1, now: now.advanced(by: .seconds(2)))?.id == c.id)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, b, c], focusedID: c.id), process: process, advances: 1, now: now.advanced(by: .seconds(4)))?.id == a.id)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, b, c], focusedID: a.id), process: process, advances: 1, now: now.advanced(by: .seconds(6)))?.id == b.id)
}

@Test func newWindowsWaitForNextSession() {
    let a = WindowRecord(id: UUID()), b = WindowRecord(id: UUID()), c = WindowRecord(id: UUID())
    let process = ApplicationProcess(pid: 1), now = ContinuousClock.now
    var cycle = WindowCycle()
    _ = cycle.select(from: WindowSnapshot(windows: [a, b], focusedID: a.id), process: process, advances: 0, now: now)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, c, b], focusedID: a.id), process: process, advances: 1, now: now)?.id == b.id)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, c, b], focusedID: b.id), process: process, advances: 1, now: now)?.id == a.id)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, c, b], focusedID: a.id), process: process, advances: 1, now: now.advanced(by: .seconds(2)))?.id == c.id)
}

@Test func closedCursorAndCandidatesAreSkipped() {
    let a = WindowRecord(id: UUID()), b = WindowRecord(id: UUID()), c = WindowRecord(id: UUID())
    let process = ApplicationProcess(pid: 1)
    var cycle = WindowCycle()
    _ = cycle.select(from: WindowSnapshot(windows: [a, b, c], focusedID: a.id), process: process, advances: 1)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, c]), process: process, advances: 2)?.id == a.id)
}

@Test func manualFocusChangeRestartsFromObservedWindow() {
    let a = WindowRecord(id: UUID()), b = WindowRecord(id: UUID()), c = WindowRecord(id: UUID())
    let process = ApplicationProcess(pid: 1)
    var cycle = WindowCycle()
    _ = cycle.select(from: WindowSnapshot(windows: [a, b, c], focusedID: a.id), process: process, advances: 1)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, b, c], focusedID: c.id), process: process, advances: 1)?.id == a.id)
}

@Test func processRelaunchInvalidatesWindowSession() {
    let a = WindowRecord(id: UUID()), b = WindowRecord(id: UUID()), c = WindowRecord(id: UUID())
    var cycle = WindowCycle()
    _ = cycle.select(from: WindowSnapshot(windows: [a, b], focusedID: a.id), process: ApplicationProcess(pid: 1, launchedAt: 1), advances: 0)
    #expect(cycle.select(from: WindowSnapshot(windows: [a, c, b], focusedID: a.id), process: ApplicationProcess(pid: 1, launchedAt: 2), advances: 1)?.id == c.id)
}

@Test func keepMinimizedExcludesOnlyMinimizedCandidates() {
    let a = WindowRecord(id: UUID(), minimized: true), b = WindowRecord(id: UUID(), minimized: false)
    var cycle = WindowCycle()
    #expect(cycle.select(from: WindowSnapshot(windows: [a, b], focusedID: a.id), process: ApplicationProcess(pid: 1), advances: 0, restoreMinimized: false)?.id == b.id)
    #expect(cycle.select(from: WindowSnapshot(windows: [a]), process: ApplicationProcess(pid: 1), advances: 0, restoreMinimized: false) == nil)
}

@Test func modalWindowsPreventCycling() {
    var cycle = WindowCycle()
    #expect(cycle.select(from: WindowSnapshot(windows: [WindowRecord(id: UUID())], hasModalWindow: true), process: ApplicationProcess(pid: 1), advances: 1) == nil)
}

@Test func windowTicketsRejectCancellationAndTimeout() {
    let cancelled = WindowRequest()
    cancelled.cancel()
    #expect(throws: WindowAccessError.cancelled) { try cancelled.check() }
    let expired = WindowRequest(timeout: .zero)
    #expect(throws: WindowAccessError.timedOut) { try expired.check() }
}

@Test func oldConfigurationLoadsWithWindowDefaults() throws {
    var old = Configuration()
    try old.assign(testApp("A"), to: 1)
    let encoded = try JSONEncoder().encode(old)
    var dictionary = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
    dictionary.removeValue(forKey: "windowManagementEnabled")
    dictionary.removeValue(forKey: "restoreMinimizedWindows")
    let decoded = try JSONDecoder().decode(Configuration.self, from: JSONSerialization.data(withJSONObject: dictionary))
    #expect(decoded.slots == old.slots)
    #expect(decoded.windowManagementEnabled)
    #expect(decoded.restoreMinimizedWindows)
    var updated = decoded
    updated.restoreMinimizedWindows = false
    #expect(try JSONDecoder().decode(Configuration.self, from: JSONEncoder().encode(updated)) == updated)
}
