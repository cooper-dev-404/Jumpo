import AppKit
import SwiftUI

@main
enum JumpoApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { application.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var model: AppModel!
    private var window: NSWindow?
    private var statusItem: NSStatusItem!
    private var hud: HUDController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        installApplicationMenu()
        model = AppModel()
        model.showWindow = { [weak self] in self?.showSettings() }
        model.onMenuChanged = { [weak self] in self?.updateStatus() }
        model.showHUD = { [weak self] in self?.showHUD() }
        hud = HUDController(model: model)
        model.onHUDSettingsChanged = { [weak self] in self?.hud?.updateConfiguration() }
        model.onWillJump = { [weak self] in self?.hud?.willJump() }
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "arrow.up.forward.app", accessibilityDescription: "Jumpo")
        statusItem.button?.image?.isTemplate = true
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        updateStatus()
        showSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) { hud?.shutdown(); model?.shutdown() }

    @objc func showSettings() {
        hud?.willJump()
        if window == nil {
            let view = SettingsView(model: model)
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 740),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.title = "Jumpo"
            window.titlebarAppearsTransparent = true
            window.toolbar = NSToolbar(identifier: "JumpoSettings")
            window.toolbarStyle = .unified
            window.contentViewController = NSHostingController(rootView: view.frame(minWidth: 810, minHeight: 660))
            window.minSize = NSSize(width: 810, height: 720)
            window.setContentSize(NSSize(width: 960, height: 740))
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("JumpoSettings")
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }

    private func updateStatus() {
        statusItem?.button?.appearsDisabled = model.paused
        statusItem?.button?.toolTip = model.paused ? "Jumpo · 快捷键已暂停" : "Jumpo · \(model.activeCount) 个快捷键"
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        let heading = NSMenuItem(title: model.paused ? "Jumpo · 已暂停" : "Jumpo", action: nil, keyEquivalent: "")
        menu.addItem(heading)
        menu.addItem(.separator())
        addItem("打开快捷提示面板", action: #selector(showHUD), to: menu)
        menu.addItem(.separator())
        for slot in model.configuration.activeSlots {
            guard let app = slot.app else { continue }
            let item = NSMenuItem(title: "\(model.configuration.modifier.symbols)\(slot.number)  \(app.name)", action: #selector(openSlot(_:)), keyEquivalent: "")
            item.tag = slot.number
            item.target = self
            let icon = model.icon(for: app).copy() as! NSImage
            icon.size = NSSize(width: 18, height: 18)
            item.image = icon
            menu.addItem(item)
        }
        if model.assignedCount == 0 {
            menu.addItem(NSMenuItem(title: "添加一个应用即可开始", action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        addItem("配置快捷键…", action: #selector(showSettings), to: menu, key: ",")
        addItem(model.paused ? "恢复快捷键" : "暂停快捷键", action: #selector(togglePause), to: menu)
        menu.addItem(.separator())
        addItem("退出 Jumpo", action: #selector(quit), to: menu, key: "q")
    }

    private func addItem(_ title: String, action: Selector, to menu: NSMenu, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func openSlot(_ sender: NSMenuItem) { model.jump(slot: sender.tag) }
    @objc private func showHUD() {
        // Let the status menu finish tracking before giving the panel keyboard focus.
        DispatchQueue.main.async { [weak self] in self?.hud?.showMenuHUD() }
    }
    @objc private func togglePause() { model.togglePause() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func installApplicationMenu() {
        let main = NSMenu()
        let app = NSMenuItem()
        let appMenu = NSMenu(title: "Jumpo")
        addItem("配置快捷键…", action: #selector(showSettings), to: appMenu, key: ",")
        appMenu.addItem(.separator())
        addItem("退出 Jumpo", action: #selector(quit), to: appMenu, key: "q")
        app.submenu = appMenu
        main.addItem(app)
        let edit = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        for (title, selector, key) in [("剪切", "cut:", "x"), ("复制", "copy:", "c"), ("粘贴", "paste:", "v"), ("全选", "selectAll:", "a")] {
            editMenu.addItem(NSMenuItem(title: title, action: Selector(selector), keyEquivalent: key))
        }
        edit.submenu = editMenu
        main.addItem(edit)
        NSApp.mainMenu = main
    }
}
