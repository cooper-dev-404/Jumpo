import AppKit

/// Disposable, content-free windows for manual AX integration checks.
@main
enum WindowFixture {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = FixtureDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
private final class FixtureDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var windows: [NSWindow] = []
    private var statusLabels: [NSTextField] = []
    private let logURL = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("window-fixture-events.jsonl")

    func applicationDidFinishLaunching(_ notification: Notification) {
        try? Data().write(to: logURL)
        let menu = NSMenu()
        let item = NSMenuItem()
        let submenu = NSMenu(title: "Jumpo Window Fixture")
        let restore = NSMenuItem(title: "恢复所有测试窗口", action: #selector(restoreAll), keyEquivalent: "r")
        restore.target = self
        submenu.addItem(restore)
        let minimize = NSMenuItem(title: "最小化所有测试窗口", action: #selector(minimizeAll), keyEquivalent: "m")
        minimize.target = self
        submenu.addItem(minimize)
        submenu.addItem(.separator())
        submenu.addItem(NSMenuItem(title: "退出测试应用", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        item.submenu = submenu
        menu.addItem(item)
        NSApp.mainMenu = menu
        for (index, name) in ["A", "B", "C"].enumerated() {
            let window = NSWindow(contentRect: NSRect(x: 200 + index * 35, y: 250 - index * 35, width: 460, height: 270),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            window.title = "Jumpo 测试窗口 \(name)"
            window.isReleasedWhenClosed = false
            window.delegate = self
            let heading = NSTextField(labelWithString: "窗口 \(name)")
            heading.font = .systemFont(ofSize: 32, weight: .semibold)
            let detail = NSTextField(labelWithString: "只用于验证窗口切换，不含用户数据。")
            let minimize = NSButton(title: "最小化此窗口", target: self, action: #selector(minimizeOne(_:)))
            minimize.tag = index
            let dialog = NSButton(title: "打开测试对话框", target: self, action: #selector(showDialog(_:)))
            dialog.tag = index
            let status = NSTextField(labelWithString: "")
            status.font = .systemFont(ofSize: 12)
            statusLabels.append(status)
            let stack = NSStackView(views: [heading, detail, minimize, dialog, status])
            stack.orientation = .vertical
            stack.spacing = 16
            stack.translatesAutoresizingMaskIntoConstraints = false
            window.contentView?.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.centerXAnchor.constraint(equalTo: window.contentView!.centerXAnchor),
                stack.centerYAnchor.constraint(equalTo: window.contentView!.centerYAnchor)
            ])
            windows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
        updateStatus()
        windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        record("launched")
    }

    func applicationDidBecomeActive(_ notification: Notification) { record("appActive") }
    func applicationDidResignActive(_ notification: Notification) { record("appInactive") }
    func windowDidBecomeKey(_ notification: Notification) { record("keyWindowChanged") }
    func windowDidMiniaturize(_ notification: Notification) { updateStatus(); record("minimized") }
    func windowDidDeminiaturize(_ notification: Notification) { updateStatus(); record("restored") }

    // Diagnostics only for these content-free fixture windows, never for other apps.
    private func record(_ event: String) {
        let state: [String: Any] = [
            "event": event, "time": Date().timeIntervalSince1970, "active": NSApp.isActive,
            "windows": zip(["A", "B", "C"], windows).map { name, window -> [String: Any] in
                ["name": name, "minimized": window.isMiniaturized, "key": window.isKeyWindow,
                 "subrole": String(describing: window.accessibilitySubrole()),
                 "modal": window.isAccessibilityModal(), "hasMinimizeButton": window.accessibilityMinimizeButton() != nil]
            }
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: state, options: [.sortedKeys]),
              let handle = try? FileHandle(forWritingTo: logURL) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: data + Data([0x0a]))
    }

    private func updateStatus() {
        let text = zip(["A", "B", "C"], windows).map { name, window in
            "\(name)：\(window.isMiniaturized ? "最小化" : "未最小化")"
        }.joined(separator: "；")
        for label in statusLabels { label.stringValue = text }
    }

    @objc private func minimizeOne(_ sender: NSButton) { windows[sender.tag].miniaturize(nil) }
    @objc private func minimizeAll() {
        for window in windows { window.miniaturize(nil) }
        record("minimizeAllRequested")
    }
    @objc private func restoreAll() {
        for window in windows { window.deminiaturize(nil); window.makeKeyAndOrderFront(nil) }
        windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
    @objc private func showDialog(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = "窗口切换测试"
        alert.informativeText = "保持此对话框打开，验证 Jumpo 不会绕过它强行切换窗口。"
        alert.addButton(withTitle: "关闭测试对话框")
        alert.beginSheetModal(for: windows[sender.tag])
    }
}
