import AppKit
import Combine
import JumpoCore
import UniformTypeIdentifiers

enum SettingsPage: String, CaseIterable, Identifiable {
    case shortcuts = "我的快捷键", apps = "应用", preferences = "设置"
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .shortcuts: "square.grid.3x3"
        case .apps: "app.dashed"
        case .preferences: "slider.horizontal.3"
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var configuration = Configuration()
    @Published private(set) var catalog: [AppBinding] = []
    @Published private(set) var scanning = false
    @Published private(set) var paused = false
    @Published private(set) var loadError: String?
    @Published var errorMessage: String?
    @Published private(set) var lastActivity = "选择一个常用应用，为它设置快捷键。"
    @Published private(set) var runningPaths: Set<String> = []
    @Published private(set) var frontmostPath: String?
    @Published private(set) var accessibilityGranted = false
    @Published var hudAvailability = "正在检查长按监听…"
    @Published var page: SettingsPage? = .shortcuts
    @Published var pickingSlot: Int?
    private var undoConfiguration: Configuration?
    @Published private(set) var canUndo = false
    private var iconCache: [String: NSImage] = [:]
    private var observers: [NSObjectProtocol] = []
    private var permissionMonitor: Task<Void, Never>?
    let store: ConfigurationStore
    let registry = HotkeyRegistry()
    private lazy var shortcuts = ShortcutTransaction(backend: registry)
    private let windowService = AccessibilityWindowService()
    private lazy var jumper = JumpCoordinator(client: ApplicationService(), windows: windowService)
    var onMenuChanged: (() -> Void)?
    var showWindow: (() -> Void)?
    var showHUD: (() -> Void)?
    var onHUDSettingsChanged: (() -> Void)?
    var onWillJump: (() -> Void)?

    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        store = ConfigurationStore(directory: support.appendingPathComponent("Jumpo", isDirectory: true))
        do { configuration = try store.load() }
        catch { loadError = error.localizedDescription; paused = true }
        applyWindowPreferences()
        registry.onPress = { [weak self] number in self?.jump(slot: number) }
        jumper.onStatus = { [weak self] status in
            guard let self else { return }
            switch status {
            case .working(let name): lastActivity = "正在打开 \(name)…"
            case .activated(let name): lastActivity = "已切换到 \(name)"
            case .alreadyActive(let name): lastActivity = "\(name) 已在前台"
            case .windowActivated(let name, let restored):
                lastActivity = restored ? "已恢复并切换到 \(name) 的窗口" : "已切换到 \(name) 的窗口"
            case .windowOpened(let name):
                lastActivity = "已打开 \(name) 窗口"
            case .applicationFallback(let name, let reason): lastActivity = "\(name) 已在前台。\(reason)"
            case .failed(let message):
                lastActivity = message
                errorMessage = message
                showWindow?()
            case .interrupted: lastActivity = "已停止上一次切换。"
            }
        }
        if loadError == nil {
            do { try shortcuts.replace(with: Shortcut.plan(for: configuration)) }
            catch { errorMessage = error.localizedDescription; paused = true }
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
                     NSWorkspace.didActivateApplicationNotification, NSWorkspace.didUnhideApplicationNotification,
                     NSWorkspace.didHideApplicationNotification] {
            let token = center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let activatedPath = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                    .bundleURL?.standardizedFileURL.path
                MainActor.assumeIsolated {
                    guard let self else { return }
                    if name == NSWorkspace.didActivateApplicationNotification {
                        self.jumper.userDidActivateApplication(at: activatedPath)
                        self.refreshAccessibility()
                    } else if name == NSWorkspace.didTerminateApplicationNotification {
                        self.windowService.clearCache()
                    }
                    self.refreshRunningApps()
                }
            }
            observers.append(token)
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.registry.resetPressedKeys()
                    self?.jumper.cancel()
                }
            })
        }
        refreshRunningApps()
        refreshCatalog()
        refreshAccessibility()
        permissionMonitor = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .seconds(2)) } catch { return }
                self?.refreshAccessibility()
            }
        }
    }

    var assignedCount: Int { configuration.slots.filter { $0.app != nil }.count }
    var activeCount: Int { shortcuts.active.count }

    func icon(for app: AppBinding) -> NSImage {
        if let image = iconCache[app.path] { return image }
        let image = NSWorkspace.shared.icon(forFile: app.path)
        iconCache[app.path] = image
        return image
    }

    func isMissing(_ app: AppBinding) -> Bool { !FileManager.default.fileExists(atPath: app.path) }

    func refreshCatalog() {
        guard !scanning else { return }
        scanning = true
        Task {
            let apps = await Task.detached(priority: .utility) { AppCatalog.scan() }.value
            catalog = apps
            scanning = false
        }
    }

    private func refreshRunningApps() {
        runningPaths = Set(NSWorkspace.shared.runningApplications.compactMap { $0.bundleURL?.standardizedFileURL.path })
        let current = NSWorkspace.shared.frontmostApplication
        if current?.bundleIdentifier != Bundle.main.bundleIdentifier {
            frontmostPath = current?.bundleURL?.standardizedFileURL.path
        }
        onMenuChanged?()
    }

    func commit(_ proposed: Configuration) {
        guard loadError == nil else { return }
        let old = configuration
        let oldPlan = shortcuts.active
        do {
            try proposed.validate()
            if !paused { try shortcuts.replace(with: Shortcut.plan(for: proposed)) }
            do { try store.save(proposed) }
            catch {
                // Saving is part of the same transaction as registration.
                do { try shortcuts.replace(with: oldPlan) }
                catch { shortcuts.stop(); paused = true }
                throw error
            }
            configuration = proposed
            if old.windowManagementEnabled != proposed.windowManagementEnabled || old.restoreMinimizedWindows != proposed.restoreMinimizedWindows {
                applyWindowPreferences()
            }
            undoConfiguration = old
            canUndo = true
            errorMessage = nil
            onMenuChanged?()
        } catch {
            if let update = error as? ShortcutUpdateError, update.rollbackFailed { paused = true }
            errorMessage = error.localizedDescription
            onMenuChanged?()
        }
        onHUDSettingsChanged?()
    }

    func assign(_ app: AppBinding, to number: Int) {
        guard let destination = configuration.slots.first(where: { $0.number == number }) else { return }
        if let old = destination.app, old.path != app.path {
            let alreadyBound = configuration.slots.contains { $0.app?.path == app.path }
            let alert = NSAlert()
            alert.messageText = alreadyBound ? "交换两个应用的位置？" : "替换槽位 \(number) 的应用？"
            alert.informativeText = alreadyBound
                ? "\(app.name) 与 \(old.name) 将交换快捷键。"
                : "\(app.name) 将使用 \(configuration.modifier.symbols)\(number)。\(old.name) 的绑定将被移除。"
            alert.addButton(withTitle: alreadyBound ? "交换" : "替换")
            alert.addButton(withTitle: "取消")
            guard alert.runModal() == .alertFirstButtonReturn else { return }
        }
        do {
            var proposed = configuration
            try proposed.assign(app, to: number)
            commit(proposed)
        } catch { errorMessage = error.localizedDescription }
    }

    func remove(slot number: Int) {
        var proposed = configuration
        proposed.remove(slot: number)
        commit(proposed)
    }

    func setEnabled(_ enabled: Bool, slot number: Int) {
        var proposed = configuration
        guard let index = proposed.slots.firstIndex(where: { $0.number == number }) else { return }
        proposed.slots[index].enabled = enabled
        commit(proposed)
    }

    func changeModifier(_ modifier: TriggerModifier) {
        var proposed = configuration
        proposed.modifier = modifier
        commit(proposed)
    }

    private func applyWindowPreferences() {
        jumper.configureWindows(enabled: configuration.windowManagementEnabled,
                                restoreMinimized: configuration.restoreMinimizedWindows)
    }

    func setWindowManagement(_ enabled: Bool) {
        var proposed = configuration
        proposed.windowManagementEnabled = enabled
        commit(proposed)
    }

    func setRestoreMinimized(_ enabled: Bool) {
        var proposed = configuration
        proposed.restoreMinimizedWindows = enabled
        commit(proposed)
    }

    func setHoldHUD(_ enabled: Bool) {
        var proposed = configuration
        proposed.holdHUDEnabled = enabled
        commit(proposed)
    }

    func setHUDDelay(_ milliseconds: Int) {
        var proposed = configuration
        proposed.hudHoldDelayMilliseconds = milliseconds
        commit(proposed)
    }

    func refreshAccessibility() {
        let granted = windowService.hasPermission
        let changed = accessibilityGranted != granted
        if accessibilityGranted && !granted {
            jumper.cancel()
            windowService.clearCache()
            lastActivity = "窗口访问权限已关闭，应用启动与切换仍可使用。"
        }
        accessibilityGranted = granted
        if changed { onHUDSettingsChanged?() }
    }

    func requestAccessibility() { windowService.requestPermission(); refreshAccessibility() }

    func undo() {
        guard let previous = undoConfiguration else { return }
        commit(previous)
        if configuration == previous { undoConfiguration = nil; canUndo = false }
    }

    func chooseApplication(slot number: Int) {
        let panel = NSOpenPanel()
        panel.title = "选择本地应用"
        panel.message = "为槽位 \(number) 选择一个 macOS 应用。"
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let app = try AppCatalog.binding(at: url)
            guard app.bundleIdentifier != Bundle.main.bundleIdentifier else { throw AppError.invalidApplication }
            assign(app, to: number)
        } catch { errorMessage = error.localizedDescription }
    }

    func jump(slot number: Int) {
        guard let slot = configuration.slots.first(where: { $0.number == number }),
              slot.enabled, let app = slot.app else { return }
        onWillJump?()
        jumper.jump(to: app)
    }

    func open(_ app: AppBinding) { onWillJump?(); jumper.jump(to: app) }

    func togglePause() {
        guard loadError == nil else { return }
        if paused {
            do {
                try shortcuts.replace(with: Shortcut.plan(for: configuration))
                paused = false
                errorMessage = nil
            } catch { errorMessage = error.localizedDescription }
        } else {
            shortcuts.stop()
            jumper.cancel()
            paused = true
        }
        onMenuChanged?()
        onHUDSettingsChanged?()
    }

    func recover(useBackup: Bool) {
        do {
            configuration = try store.recover(useBackup: useBackup)
            applyWindowPreferences()
            loadError = nil
            paused = true
            togglePause()
        } catch { errorMessage = error.localizedDescription }
    }

    func shutdown() {
        permissionMonitor?.cancel()
        jumper.cancel()
        windowService.clearCache()
        registry.shutdown()
        for token in observers { NSWorkspace.shared.notificationCenter.removeObserver(token) }
    }
}
