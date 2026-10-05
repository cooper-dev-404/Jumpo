import AppKit
import SwiftUI
import JumpoCore

private final class HUDPanel: NSPanel {
    var interactive = false
    override var canBecomeKey: Bool { interactive }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class HUDController: NSObject, NSWindowDelegate {
    /// Matches the rounded shape drawn by `HUDView`'s `clipShape`.
    private static let cornerRadius: CGFloat = 20

    private let model: AppModel
    private let input = HUDInputMonitor()
    // Separate worker: HUD metadata must not invalidate the switcher's live window identities.
    private let metadata = AccessibilityWindowService()
    private var panel: HUDPanel?
    private var presentation: HUDPresentation?
    private var sourceApplication: NSRunningApplication?
    private var preparedFrame: CGRect?
    private var preparedPath: String?
    private var prepareID = UUID()
    private var presentationID = UUID()
    private var frameTask: Task<Void, Never>?
    private var countTask: Task<Void, Never>?
    private var frameRequest: WindowRequest?
    private var countRequest: WindowRequest?
    private var localMonitor: Any?
    private var mouseMonitor: Any?
    private var observers: [(NotificationCenter, NSObjectProtocol)] = []

    init(model: AppModel) {
        self.model = model
        super.init()
        input.onPending = { [weak self] in self?.prepareHold() }
        input.onShow = { [weak self] in self?.showHold() }
        input.onHide = { [weak self] in
            guard let self, presentation?.interactive == false else { return }
            dismiss(restoreSource: false)
        }
        input.onAvailability = { [weak model] in model?.hudAvailability = $0 }
        installObservers()
        updateConfiguration()
    }

    func updateConfiguration() {
        dismiss(restoreSource: false)
        input.configure(enabled: model.configuration.holdHUDEnabled, paused: model.paused,
                        modifier: model.configuration.modifier, delay: model.configuration.hudHoldDelayMilliseconds)
    }

    func willJump() {
        input.cancelHold()
        dismiss(restoreSource: false)
    }

    func showMenuHUD() {
        input.cancelHold()
        dismiss(restoreSource: false)
        sourceApplication = externalFrontmostApplication
        preparedPath = sourceApplication?.bundleURL?.standardizedFileURL.path ?? model.frontmostPath
        let id = presentationID
        let source = sourceApplication
        frameTask = Task { [weak self] in
            guard let self else { return }
            let frame = await focusedFrame(source)
            guard !Task.isCancelled, presentationID == id else { return }
            present(interactive: true, currentPath: preparedPath, frame: frame)
        }
    }

    private var externalFrontmostApplication: NSRunningApplication? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        return app
    }

    private func prepareHold() {
        guard presentation?.interactive != true else { input.cancelHold(); return }
        frameTask?.cancel()
        frameRequest?.cancel()
        preparedFrame = nil
        sourceApplication = externalFrontmostApplication
        preparedPath = sourceApplication?.bundleURL?.standardizedFileURL.path ?? model.frontmostPath
        prepareID = UUID()
        let id = prepareID
        let source = sourceApplication
        frameTask = Task { [weak self] in
            guard let self else { return }
            let frame = await focusedFrame(source)
            guard !Task.isCancelled, prepareID == id else { return }
            preparedFrame = frame
        }
    }

    private func focusedFrame(_ source: NSRunningApplication?) async -> CGRect? {
        guard model.configuration.windowManagementEnabled, metadata.hasPermission, let source else { return nil }
        let request = WindowRequest(timeout: .milliseconds(150))
        frameRequest = request
        let process = ApplicationProcess(pid: source.processIdentifier, launchedAt: source.launchDate?.timeIntervalSince1970)
        return try? await metadata.focusedWindowFrame(for: process, request: request)
    }

    private func showHold() {
        guard presentation?.interactive != true else { return }
        present(interactive: false, currentPath: preparedPath, frame: preparedFrame)
    }

    private func present(interactive: Bool, currentPath: String?, frame: CGRect?) {
        guard panel == nil else { return }
        let presentation = HUDPresentation(interactive: interactive, currentPath: currentPath)
        self.presentation = presentation
        let mask: NSWindow.StyleMask = interactive ? [.borderless] : [.borderless, .nonactivatingPanel]
        let panel = HUDPanel(contentRect: .zero, styleMask: mask, backing: .buffered, defer: false)
        panel.interactive = interactive
        panel.title = "Jumpo 快捷切换"
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isReleasedWhenClosed = false
        panel.ignoresMouseEvents = !interactive
        panel.isMovable = false
        panel.delegate = self

        let material = NSVisualEffectView()
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .active
        // A behind-window material is composited by the window server, which ignores a
        // layer's corner radius: the opaque material then covers the window as a square
        // and shows white right-angle corners around the rounded content. Masking the
        // effect view itself also masks the composited material.
        material.maskImage = Self.roundedMaskImage(radius: Self.cornerRadius)
        material.wantsLayer = true
        material.layer?.cornerRadius = Self.cornerRadius
        material.layer?.masksToBounds = true
        let hosting = NSHostingView(rootView: HUDView(model: model, presentation: presentation,
            select: { [weak self] in self?.select($0) }, configure: { [weak self] in self?.configure() }))
        hosting.translatesAutoresizingMaskIntoConstraints = false
        material.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: material.topAnchor), hosting.bottomAnchor.constraint(equalTo: material.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: material.leadingAnchor), hosting.trailingAnchor.constraint(equalTo: material.trailingAnchor)
        ])
        panel.contentView = material
        self.panel = panel
        position(frame: frame)
        installPresentationMonitors()
        if interactive {
            NSApp.activate()
            panel.makeKeyAndOrderFront(nil)
        } else {
            panel.orderFrontRegardless()
        }
        if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            panel.alphaValue = 0
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.09
                panel.animator().alphaValue = 1
            }
        }
        loadWindowCounts(presentation)
    }

    /// Resizable rounded-rectangle mask: the effect view stretches it around the panel
    /// while keeping the corners at their drawn radius.
    private static func roundedMaskImage(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    private func position(frame: CGRect?) {
        let screens = NSScreen.screens
        guard let first = screens.first, let panel else { return }
        // Accessibility uses a top-left origin anchored to the primary display.
        let cocoaFrame = frame.map { CGRect(x: $0.minX, y: first.frame.maxY - $0.maxY, width: $0.width, height: $0.height) }
        let byWindow = cocoaFrame.flatMap { target -> NSScreen? in
            let intersecting = screens.filter { $0.frame.intersects(target) }
            return intersecting.max { a, b in
                let x = a.frame.intersection(target), y = b.frame.intersection(target)
                return x.width * x.height < y.width * y.height
            }
        }
        let screen = byWindow ?? screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main ?? first
        let area = screen.visibleFrame.insetBy(dx: 16, dy: 16)
        let size = NSSize(width: min(620, area.width), height: min(392, area.height))
        let x = max(area.minX, min(area.midX - size.width / 2, area.maxX - size.width))
        let y = max(area.minY, min(area.midY - size.height / 2 + area.height * 0.05, area.maxY - size.height))
        panel.setFrame(NSRect(origin: NSPoint(x: x, y: y), size: size), display: true)
    }

    private func loadWindowCounts(_ presentation: HUDPresentation) {
        guard model.configuration.windowManagementEnabled, metadata.hasPermission else { return }
        let slots = model.configuration.activeSlots
        let id = presentationID
        let request = WindowRequest(timeout: .seconds(2))
        countRequest = request
        countTask = Task { [weak self] in
            guard let self else { return }
            for slot in slots {
                guard !Task.isCancelled, presentationID == id, let app = slot.app,
                      let running = NSWorkspace.shared.runningApplications.first(where: {
                          $0.bundleURL?.standardizedFileURL.path == app.path && !$0.isTerminated
                      }) else { continue }
                let process = ApplicationProcess(pid: running.processIdentifier, launchedAt: running.launchDate?.timeIntervalSince1970)
                if let snapshot = try? await metadata.snapshot(for: process, request: request), !snapshot.hasModalWindow {
                    guard !Task.isCancelled, presentationID == id, metadata.hasPermission else { return }
                    presentation.windowCounts[slot.number] = snapshot.windows.count
                }
                if (try? request.check()) == nil { return }
            }
        }
    }

    private func installPresentationMonitors() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            let consumed = MainActor.assumeIsolated {
                guard let self else { return false }
                return self.localEvent(event) == nil
            }
            return consumed ? nil : event
        }
        mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.input.cancelHold()
                self?.dismiss(restoreSource: false)
            }
        }
    }

    private func localEvent(_ event: NSEvent) -> NSEvent? {
        guard let panel else { return event }
        if event.type != .keyDown {
            if event.window !== panel { input.cancelHold(); dismiss(restoreSource: false) }
            return event
        }
        guard panel.interactive, panel.isKeyWindow else { return event }
        if event.keyCode == 53 { dismiss(restoreSource: true); return nil }
        let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
        guard modifiers.isEmpty else { return event }
        let codes: [UInt16] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        if let index = codes.firstIndex(of: event.keyCode) {
            if !event.isARepeat { select(index + 1) }
            return nil
        }
        return event
    }

    private func select(_ number: Int) {
        guard let slot = model.configuration.slots.first(where: { $0.number == number }) else { return }
        willJump()
        if let app = slot.app, slot.enabled, !model.isMissing(app) {
            model.jump(slot: number)
        } else {
            model.page = .shortcuts
            model.showWindow?()
            if slot.app == nil || slot.app.map(model.isMissing) == true { model.pickingSlot = number }
        }
    }

    private func configure() {
        willJump()
        model.page = .shortcuts
        model.showWindow?()
    }

    func dismiss(restoreSource: Bool) {
        let restore = restoreSource && presentation?.interactive == true && NSApp.isActive
        let source = sourceApplication
        presentationID = UUID()
        prepareID = UUID()
        frameTask?.cancel()
        countTask?.cancel()
        frameRequest?.cancel()
        countRequest?.cancel()
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor) }
        localMonitor = nil
        mouseMonitor = nil
        let previous = panel
        panel = nil
        presentation = nil
        previous?.orderOut(nil)
        previous?.contentView = nil
        metadata.clearCache()
        sourceApplication = nil
        if restore, let source, !source.isTerminated {
            NSApp.yieldActivation(to: source)
            _ = source.activate(options: [])
        }
    }

    func windowDidResignKey(_ notification: Notification) {
        guard (notification.object as? NSWindow) === panel else { return }
        dismiss(restoreSource: false)
    }

    private func installObservers() {
        let workspace = NSWorkspace.shared.notificationCenter
        observe(workspace, NSWorkspace.didActivateApplicationNotification) { [weak self] in
            guard let self, let app = NSWorkspace.shared.frontmostApplication,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return }
            input.cancelHold()
            dismiss(restoreSource: false)
        }
        for name in [NSWorkspace.willSleepNotification, NSWorkspace.sessionDidResignActiveNotification] {
            observe(workspace, name) { [weak self] in self?.input.setSuspended(true); self?.dismiss(restoreSource: false) }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.sessionDidBecomeActiveNotification] {
            observe(workspace, name) { [weak self] in self?.input.setSuspended(false) }
        }
        observe(.default, NSApplication.didResignActiveNotification) { [weak self] in
            if self?.presentation?.interactive == true { self?.dismiss(restoreSource: false) }
        }
        observe(.default, NSApplication.didChangeScreenParametersNotification) { [weak self] in
            self?.position(frame: nil)
        }
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name, handler: @escaping @MainActor () -> Void) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { handler() }
        }
        observers.append((center, token))
    }

    func shutdown() {
        input.shutdown()
        dismiss(restoreSource: false)
        for (center, token) in observers { center.removeObserver(token) }
        observers.removeAll()
    }
}
