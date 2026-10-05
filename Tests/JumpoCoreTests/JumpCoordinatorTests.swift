import Foundation
import Testing
@testable import JumpoCore

@MainActor final class FakeApplications: ApplicationClient {
    var running: [String: ApplicationProcess] = [:]
    var pending: [String: CheckedContinuation<ApplicationProcess, any Error>] = [:]
    var launched: [String] = []
    var activated: [ApplicationProcess] = []
    var frontmost: ApplicationProcess?
    var activationSucceeds = true
    var activationChangesFrontmost = true
    var defaultWindowOpens = false
    var openedDefaultWindows: [String] = []

    func runningApplication(for app: AppBinding) throws -> ApplicationProcess? { running[app.path] }
    func openDefaultWindow(_ app: AppBinding) -> Bool {
        openedDefaultWindows.append(app.path)
        return defaultWindowOpens
    }
    func launch(_ app: AppBinding) async throws -> ApplicationProcess {
        launched.append(app.path)
        return try await withCheckedThrowingContinuation { pending[app.path] = $0 }
    }
    func complete(_ app: AppBinding, process: ApplicationProcess) {
        running[app.path] = process
        pending.removeValue(forKey: app.path)?.resume(returning: process)
    }
    func activate(_ process: ApplicationProcess) -> Bool {
        activated.append(process)
        if activationSucceeds && activationChangesFrontmost { frontmost = process }
        return activationSucceeds
    }
    func isFrontmost(_ process: ApplicationProcess) -> Bool { frontmost == process }
}

@MainActor func waitUntil(_ condition: () -> Bool) async throws {
    for _ in 0..<1_000 {
        if condition() { return }
        try await Task.sleep(for: .milliseconds(1))
    }
    Issue.record("Condition did not become true within the test deadline")
}

@Test @MainActor func runningApplicationIsActivatedAndVerified() async throws {
    let client = FakeApplications(), app = testApp("A"), process = ApplicationProcess(pid: 1)
    client.running[app.path] = process
    let coordinator = JumpCoordinator(client: client)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { status == .activated("A") }
    #expect(client.activated == [process])
    #expect(client.launched.isEmpty)
}

@Test @MainActor func alreadyFrontmostDoesNotReactivate() async throws {
    let client = FakeApplications(), app = testApp("A"), process = ApplicationProcess(pid: 1)
    client.running[app.path] = process
    client.frontmost = process
    let coordinator = JumpCoordinator(client: client)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { status == .alreadyActive("A") }
    #expect(client.activated.isEmpty)
}

@Test @MainActor func apiSuccessWithoutFrontmostConfirmationIsFailure() async throws {
    let client = FakeApplications(), app = testApp("A")
    client.running[app.path] = ApplicationProcess(pid: 1)
    client.activationChangesFrontmost = false
    let coordinator = JumpCoordinator(client: client, verificationInterval: .milliseconds(1), verificationAttempts: 2)
    var failed = false
    coordinator.onStatus = { if case .failed = $0 { failed = true } }
    coordinator.jump(to: app)
    try await waitUntil { failed }
    #expect(failed)
}

@Test @MainActor func repeatedLaunchInputCoalesces() async throws {
    let client = FakeApplications(), app = testApp("A"), process = ApplicationProcess(pid: 1)
    let coordinator = JumpCoordinator(client: client)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    coordinator.jump(to: app)
    try await waitUntil { client.pending[app.path] != nil }
    coordinator.jump(to: app)
    client.complete(app, process: process)
    try await waitUntil { status == .activated("A") }
    #expect(client.launched == [app.path])
    #expect(client.activated == [process])
}

@Test @MainActor func lateLaunchCallbackCannotActivateOldTarget() async throws {
    let client = FakeApplications(), a = testApp("A"), b = testApp("B")
    let processA = ApplicationProcess(pid: 1), processB = ApplicationProcess(pid: 2)
    client.running[b.path] = processB
    let coordinator = JumpCoordinator(client: client)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: a)
    try await waitUntil { client.pending[a.path] != nil }
    coordinator.jump(to: b)
    try await waitUntil { status == .activated("B") }
    client.complete(a, process: processA)
    // Let the obsolete task consume its result before checking that focus stayed put.
    try await Task.sleep(for: .milliseconds(10))
    #expect(client.activated == [processB])
    #expect(client.frontmost == processB)
    #expect(status == .activated("B"))
}

@Test @MainActor func switchingBackReusesInFlightLaunch() async throws {
    let client = FakeApplications(), a = testApp("A"), b = testApp("B")
    let coordinator = JumpCoordinator(client: client)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: a)
    try await waitUntil { client.pending[a.path] != nil }
    coordinator.jump(to: b)
    try await waitUntil { client.pending[b.path] != nil }
    coordinator.jump(to: a)
    client.complete(a, process: ApplicationProcess(pid: 1))
    client.complete(b, process: ApplicationProcess(pid: 2))
    try await waitUntil { status == .activated("A") }
    #expect(client.launched.filter { $0 == a.path }.count == 1)
    #expect(client.activated == [ApplicationProcess(pid: 1)])
}

@Test @MainActor func userSwitchCancelsPendingActivation() async throws {
    let client = FakeApplications(), app = testApp("A")
    let coordinator = JumpCoordinator(client: client)
    var status: JumpStatus?
    coordinator.onStatus = { status = $0 }
    coordinator.jump(to: app)
    try await waitUntil { client.pending[app.path] != nil }
    coordinator.userDidActivateApplication(at: "/Applications/UserChoice.app")
    client.complete(app, process: ApplicationProcess(pid: 1))
    try await Task.sleep(for: .milliseconds(10))
    #expect(client.activated.isEmpty)
    #expect(status == .interrupted)
}

@Test @MainActor func launchTimeoutRejectsLateActivation() async throws {
    let client = FakeApplications(), app = testApp("A")
    let coordinator = JumpCoordinator(client: client, requestTimeout: .milliseconds(30))
    var failed = false
    coordinator.onStatus = { if case .failed = $0 { failed = true } }
    coordinator.jump(to: app)
    try await waitUntil { client.pending[app.path] != nil }
    try await waitUntil { failed }
    client.complete(app, process: ApplicationProcess(pid: 1))
    try await Task.sleep(for: .milliseconds(10))
    #expect(client.activated.isEmpty)
    #expect(failed)
}
