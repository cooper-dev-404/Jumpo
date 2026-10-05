import AppKit
import JumpoCore

enum AppError: LocalizedError {
    case missing(String), invalidApplication, wrongApplication, launchFailed

    var errorDescription: String? {
        switch self {
        case .missing(let name): "找不到 \(name)。请在对应槽位重新选择应用。"
        case .invalidApplication: "请选择可运行的 macOS 应用（.app）。"
        case .wrongApplication: "此路径的应用身份已改变，请重新选择应用。"
        case .launchFailed: "应用未能启动，请从访达检查它是否可以正常打开。"
        }
    }
}

enum AppCatalog {
    static func binding(at url: URL) throws -> AppBinding {
        guard url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier,
              bundle.executableURL != nil,
              bundle.object(forInfoDictionaryKey: "LSBackgroundOnly") as? Bool != true else {
            throw AppError.invalidApplication
        }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        return AppBinding(bundleIdentifier: identifier, path: url.path, name: name)
    }

    static func scan() -> [AppBinding] {
        let directories = ["/Applications", "/System/Applications", NSHomeDirectory() + "/Applications"]
        var apps: [String: AppBinding] = [:]
        if let finder = try? binding(at: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")) {
            apps[finder.path] = finder
        }
        for directory in directories {
            guard let files = FileManager.default.enumerator(
                at: URL(fileURLWithPath: directory), includingPropertiesForKeys: [.isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }
            for case let url as URL in files where url.pathExtension.lowercased() == "app" {
                guard let app = try? binding(at: url), app.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
                apps[app.path] = app
            }
        }
        return apps.values.sorted {
            let comparison = $0.name.localizedStandardCompare($1.name)
            return comparison == .orderedSame ? $0.path < $1.path : comparison == .orderedAscending
        }
    }
}

@MainActor
final class ApplicationService: ApplicationClient {
    private func verifiedURL(_ app: AppBinding) throws -> URL {
        let url = URL(fileURLWithPath: app.path)
        guard FileManager.default.fileExists(atPath: app.path) else { throw AppError.missing(app.name) }
        guard (try AppCatalog.binding(at: url)).bundleIdentifier == app.bundleIdentifier else {
            throw AppError.wrongApplication
        }
        return url
    }

    func runningApplication(for app: AppBinding) throws -> ApplicationProcess? {
        _ = try verifiedURL(app)
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleIdentifier)
            .filter { $0.bundleURL?.standardizedFileURL.path == app.path && !$0.isTerminated }
        let preferred = running.first(where: \.isActive) ?? running.first
        return preferred.map { ApplicationProcess(pid: $0.processIdentifier, launchedAt: $0.launchDate?.timeIntervalSince1970) }
    }

    func launch(_ app: AppBinding) async throws -> ApplicationProcess {
        let url = try verifiedURL(app)
        let configuration = NSWorkspace.OpenConfiguration()
        // Activate only after checking the current request generation in the coordinator.
        configuration.activates = false
        configuration.createsNewApplicationInstance = false
        configuration.promptsUserIfNeeded = false
        return try await withCheckedThrowingContinuation { continuation in
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { running, error in
                if let error { continuation.resume(throwing: error) }
                else if let running { continuation.resume(returning: ApplicationProcess(pid: running.processIdentifier, launchedAt: running.launchDate?.timeIntervalSince1970)) }
                else { continuation.resume(throwing: AppError.launchFailed) }
            }
        }
    }

    func activate(_ process: ApplicationProcess) -> Bool {
        guard let app = NSRunningApplication(processIdentifier: process.pid), !app.isTerminated,
              app.launchDate?.timeIntervalSince1970 == process.launchedAt else { return false }
        if app.isHidden { _ = app.unhide() }
        if NSApp.isActive { NSApp.yieldActivation(to: app) }
        return app.activate(options: [])
    }

    func isFrontmost(_ process: ApplicationProcess) -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        return app.processIdentifier == process.pid && app.launchDate?.timeIntervalSince1970 == process.launchedAt
    }

    /// PRD 12.4: Finder always runs, so a Finder without windows can only be reached by
    /// asking the system to open a location; whether an existing window is reused is the
    /// system's decision. Other apps get no window here — activating them is the fallback.
    func openDefaultWindow(_ app: AppBinding) -> Bool {
        guard app.bundleIdentifier == "com.apple.finder" else { return false }
        return NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
    }
}
