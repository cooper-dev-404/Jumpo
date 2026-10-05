import AppKit
import SwiftUI
import JumpoCore

// Select the property wrapper explicitly: some CLT SDKs expose a same-named
// State macro without shipping the SwiftUIMacros plugin.
private typealias ViewState<Value> = SwiftUI.State<Value>

/// Marketing version of the running bundle, shown in the sidebar and the About section.
/// Unbundled debug runs have no Info.plist, so they fall back to a development label.
enum AppVersion {
    static let display: String = {
        let value = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        guard let value, !value.isEmpty else { return "开发版本" }
        return value
    }()
}

struct SettingsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        NavigationSplitView {
            List(SettingsPage.allCases, selection: $model.page) { page in
                Label(page.rawValue, systemImage: page.symbol).tag(page)
                    .padding(.vertical, 5)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 185, max: 210)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 9) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 30, height: 30)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Jumpo").font(.headline)
                        Text(AppVersion.display).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                }.padding(18)
            }
        } detail: {
            VStack(spacing: 0) {
                if let message = model.loadError {
                    recoveryBanner(message)
                }
                if let message = model.errorMessage {
                    errorBanner(message)
                }
                switch model.page ?? .shortcuts {
                case .shortcuts: ShortcutsView(model: model)
                case .apps: AppsView(model: model)
                case .preferences: PreferencesView(model: model)
                }
            }
            .frame(minWidth: 575, maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle((model.page ?? .shortcuts).rawValue)
        }
        .tint(.primary)
        .sheet(isPresented: Binding(get: { model.pickingSlot != nil }, set: { if !$0 { model.pickingSlot = nil } })) {
            if let number = model.pickingSlot { AppPickerView(model: model, number: number) }
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
            Text(message).font(.callout).textSelection(.enabled)
            Spacer(minLength: 4)
            Button { model.errorMessage = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).help("关闭提示")
        }.padding(14).background(Color.orange.opacity(0.08))
    }

    private func recoveryBanner(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("配置无法读取，原文件已保留", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(message).font(.callout).foregroundStyle(.secondary)
            HStack {
                Button("恢复上次备份") { model.recover(useBackup: true) }
                Button("备份原文件并重新配置") { model.recover(useBackup: false) }
            }
        }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
            .background(Color.orange.opacity(0.08))
    }
}

private struct ShortcutsView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("我的快捷键").font(.system(size: 25, weight: .semibold))
                        Text("为常用应用设置固定快捷键。")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Label(model.paused ? "已暂停" : "\(model.activeCount) 个已启用",
                          systemImage: model.paused ? "pause.circle" : "checkmark.circle")
                        .font(.callout).foregroundStyle(.secondary).padding(.top, 6)
                }

                HStack {
                    Text("触发键").font(.callout).foregroundStyle(.secondary)
                    Picker("触发键", selection: Binding(get: { model.configuration.modifier }, set: model.changeModifier)) {
                        ForEach(TriggerModifier.allCases, id: \.self) { Text($0.label).tag($0) }
                    }.labelsHidden().frame(width: 195)
                    Spacer()
                    if model.canUndo {
                        Button("撤销") { model.undo() }.buttonStyle(.plain).foregroundStyle(.secondary)
                    }
                    Button(model.paused ? "恢复快捷键" : "暂停快捷键") { model.togglePause() }
                }
                .disabled(model.loadError != nil)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                    ForEach(model.configuration.slots.sorted { $0.number < $1.number }) { slot in
                        SlotCard(model: model, slot: slot)
                    }
                }.disabled(model.loadError != nil)

                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "keyboard").padding(.top, 1)
                    Text("添加后，在任意应用中按 \(model.configuration.modifier.symbols) + 数字即可打开或切换。所选组合会占用原有按键功能。")
                        .fixedSize(horizontal: false, vertical: true)
                }.font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                HStack(spacing: 7) {
                    Circle().fill(Color.secondary.opacity(0.5)).frame(width: 5, height: 5)
                    Text(model.lastActivity).lineLimit(2)
                }.font(.caption).foregroundStyle(.secondary)
            }.padding(28)
        }
    }
}

private struct SlotCard: View {
    @ObservedObject var model: AppModel
    let slot: Slot
    @ViewState private var hovered = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button {
                if slot.app == nil { model.pickingSlot = slot.number }
                else { model.jump(slot: slot.number) }
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        if let app = slot.app {
                            Image(nsImage: model.icon(for: app)).resizable().frame(width: 38, height: 38)
                        } else {
                            Image(systemName: "plus.app").font(.system(size: 30, weight: .light))
                                .foregroundStyle(.tertiary).frame(width: 38, height: 38)
                        }
                        Spacer()
                    }
                    Text(slot.app?.name ?? "添加应用").font(.system(size: 13, weight: .medium)).lineLimit(1)
                    HStack(alignment: .lastTextBaseline) {
                        Text("\(model.configuration.modifier.symbols)\(slot.number)")
                            .font(.system(size: 21, weight: .medium, design: .rounded))
                            .foregroundStyle(slot.app == nil ? .secondary : .primary)
                        Spacer(minLength: 3)
                        Text(stateLabel).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                }.padding(16).frame(maxWidth: .infinity, minHeight: 139, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(slot.app == nil ? "为槽位 \(slot.number) 添加应用" : "槽位 \(slot.number)，\(slot.app!.name)，\(stateLabel)，快捷键 \(model.configuration.modifier.symbols)\(slot.number)")

            if let app = slot.app {
                Menu {
                    Button("打开应用") { model.open(app) }
                    Button("更换应用…") { model.pickingSlot = slot.number }
                    Button(slot.enabled ? "停用此快捷键" : "启用此快捷键") {
                        model.setEnabled(!slot.enabled, slot: slot.number)
                    }
                    Menu("移动到槽位") {
                        ForEach(1...9, id: \.self) { number in
                            Button("\(number)") { model.assign(app, to: number) }.disabled(number == slot.number)
                        }
                    }
                    Divider()
                    Button("在访达中显示") { NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: app.path)]) }
                    Button("移除快捷键", role: .destructive) { model.remove(slot: slot.number) }
                } label: { Image(systemName: "ellipsis").frame(width: 18, height: 18) }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize()
                .padding(13).help("槽位 \(slot.number) 的操作")
            }
        }
        .background(hovered ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .textBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.primary.opacity(hovered ? 0.2 : 0.09)))
        .opacity(slot.enabled ? 1 : 0.55)
        .onHover { hovered = $0 }
    }

    private var stateLabel: String {
        guard let app = slot.app else { return "未绑定" }
        if model.isMissing(app) { return "未找到" }
        if !slot.enabled { return "已停用" }
        if model.frontmostPath == app.path { return "当前应用" }
        return model.runningPaths.contains(app.path) ? "运行中" : "未运行"
    }
}

private struct AppsView: View {
    @ObservedObject var model: AppModel
    @ViewState private var query = ""
    private var filtered: [AppBinding] {
        model.catalog.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("应用").font(.system(size: 25, weight: .semibold))
                Spacer()
                Button { model.refreshCatalog() } label: { Image(systemName: "arrow.clockwise") }
                    .help("刷新应用列表").disabled(model.scanning)
            }
            TextField("搜索已安装应用", text: $query).textFieldStyle(.roundedBorder)
            if model.scanning {
                HStack { ProgressView().controlSize(.small); Text("正在读取应用…").foregroundStyle(.secondary) }
            }
            List(filtered) { app in
                HStack(spacing: 12) {
                    Image(nsImage: model.icon(for: app)).resizable().frame(width: 32, height: 32)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(app.name)
                        Text(app.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                    if let slot = model.configuration.slots.first(where: { $0.app?.path == app.path }) {
                        Text("\(model.configuration.modifier.symbols)\(slot.number)").foregroundStyle(.secondary)
                    }
                    Menu("绑定") {
                        ForEach(1...9, id: \.self) { number in
                            Button("槽位 \(number)") { model.assign(app, to: number) }
                        }
                    }.fixedSize().disabled(model.loadError != nil)
                    Button("打开") { model.open(app) }
                }.padding(.vertical, 5)
            }.listStyle(.inset)
            if filtered.isEmpty && !model.scanning {
                Text("没有找到应用，可从“我的快捷键”手动选择 .app。")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }.padding(28)
    }
}

private struct PreferencesView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        Form {
            Section("快捷键") {
                Picker("触发键", selection: Binding(get: { model.configuration.modifier }, set: model.changeModifier)) {
                    ForEach(TriggerModifier.allCases, id: \.self) { Text($0.label).tag($0) }
                }.disabled(model.loadError != nil)
                Text("Option 数字组合可能与字符输入冲突；Control + Option 也可能与 VoiceOver 冲突。请按自己的使用习惯选择并试用。")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Text(model.paused ? "全局快捷键已暂停" : "已注册 \(model.activeCount) 个快捷键")
                    Spacer()
                    Button(model.paused ? "恢复" : "暂停") { model.togglePause() }.disabled(model.loadError != nil)
                }
            }
            Section("本地数据") {
                Text("应用绑定保存在这台 Mac 上，关闭窗口后仍可使用快捷键。退出 Jumpo 才会停止服务。")
                    .foregroundStyle(.secondary)
                Button("在访达中查看配置") {
                    NSWorkspace.shared.activateFileViewerSelecting([model.store.fileURL])
                }.disabled(!FileManager.default.fileExists(atPath: model.store.fileURL.path))
            }
            Section("快捷提示面板") {
                Toggle("长按触发键显示提示", isOn: Binding(get: { model.configuration.holdHUDEnabled }, set: model.setHoldHUD))
                    .disabled(model.loadError != nil)
                Stepper(value: Binding(get: { model.configuration.hudHoldDelayMilliseconds }, set: model.setHUDDelay), in: 100...1000, step: 20) {
                    LabeledContent("显示延迟", value: "\(model.configuration.hudHoldDelayMilliseconds) 毫秒")
                }.disabled(model.loadError != nil || !model.configuration.holdHUDEnabled)
                Text(model.hudAvailability).font(.callout).foregroundStyle(.secondary)
                Text("按住 \(model.configuration.modifier.symbols) 查看 1～9 快捷键，松开关闭。直接按快捷键时不弹出提示；输入其他按键或操作鼠标会取消本次提示。")
                    .font(.callout).foregroundStyle(.secondary)
                Button("打开快捷提示面板") { model.showHUD?() }
                Text("从菜单或此处打开后，可直接按数字或点击选择应用，无需按住触发键。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("窗口切换") {
                Toggle("恢复并循环应用窗口", isOn: Binding(get: { model.configuration.windowManagementEnabled }, set: model.setWindowManagement))
                    .disabled(model.loadError != nil)
                Text("重复按同一个快捷键可循环应用窗口；相邻按键超过 1 秒后重新确定窗口顺序。窗口不响应时保留应用级切换。")
                    .font(.callout).foregroundStyle(.secondary)
                Toggle("恢复最小化窗口", isOn: Binding(get: { model.configuration.restoreMinimizedWindows }, set: model.setRestoreMinimized))
                    .disabled(model.loadError != nil || !model.configuration.windowManagementEnabled)
                Text("关闭后跳过最小化窗口；只恢复本次选中的窗口。对话框需要在目标应用中处理。")
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    Label(model.accessibilityGranted ? "辅助功能已授权" : "辅助功能未授权", systemImage: model.accessibilityGranted ? "checkmark.shield" : "lock.shield")
                    Spacer()
                    Button("刷新状态") { model.refreshAccessibility() }
                }
                if !model.accessibilityGranted {
                    Text("长按提示需要辅助功能授权来观察按键状态；窗口恢复与循环也使用此权限。Jumpo 不记录输入内容、不读取窗口标题、不录屏。未授权时，应用快捷键和菜单提示面板仍可使用。")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("打开辅助功能设置…") { model.requestAccessibility() }
                }
            }
            Section("关于") {
                LabeledContent("Jumpo", value: AppVersion.display)
                Text("应用切换、窗口恢复与循环，以及九宫格快捷提示。")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}

private struct AppPickerView: View {
    @ObservedObject var model: AppModel
    let number: Int
    @ViewState private var query = ""
    @Environment(\.dismiss) private var dismiss

    private var filtered: [AppBinding] {
        model.catalog.filter { query.isEmpty || $0.name.localizedStandardContains(query) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("选择应用").font(.title2.weight(.semibold))
                    Text("绑定到 \(model.configuration.modifier.symbols)\(number)").foregroundStyle(.secondary)
                }
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
            }
            TextField("搜索应用名称", text: $query).textFieldStyle(.roundedBorder)
            List(filtered) { app in
                Button {
                    model.assign(app, to: number)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(nsImage: model.icon(for: app)).resizable().frame(width: 32, height: 32)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(app.name).foregroundStyle(.primary)
                            Text(app.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                        }
                        Spacer()
                        if model.runningPaths.contains(app.path) {
                            Text("运行中").font(.caption).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 5).contentShape(Rectangle())
                }.buttonStyle(.plain)
            }.listStyle(.inset)
            HStack {
                if model.scanning { ProgressView().controlSize(.small) }
                Text(model.scanning ? "正在读取应用…" : "也可以选择其他位置的应用。")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("从访达选择…") {
                    dismiss()
                    Task { @MainActor in
                        // Wait for sheet dismissal before presenting the native open panel.
                        try? await Task.sleep(for: .milliseconds(250))
                        model.chooseApplication(slot: number)
                    }
                }
            }
        }.padding(24).frame(width: 520, height: 480)
    }
}
