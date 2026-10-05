import AppKit
import SwiftUI
import JumpoCore

private typealias HUDViewState<Value> = SwiftUI.State<Value>

@MainActor
final class HUDPresentation: ObservableObject {
    let interactive: Bool
    let currentPath: String?
    @Published var windowCounts: [Int: Int] = [:]

    init(interactive: Bool, currentPath: String?) {
        self.interactive = interactive
        self.currentPath = currentPath
    }
}

struct HUDView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var presentation: HUDPresentation
    let select: (Int) -> Void
    let configure: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "arrow.up.forward.app").font(.system(size: 17, weight: .medium))
                Text("快捷切换").font(.system(size: 17, weight: .semibold))
                Spacer()
                Text(model.configuration.modifier.symbols)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                ForEach(model.configuration.slots.sorted { $0.number < $1.number }) { slot in
                    HUDSlotView(model: model, presentation: presentation, slot: slot) { select(slot.number) }
                }
            }
            HStack {
                Text(presentation.interactive ? "按数字选择 · Esc 关闭" : "松开 \(model.configuration.modifier.symbols) 关闭")
                    .foregroundStyle(.secondary)
                Spacer()
                if presentation.interactive {
                    Button("配置快捷键…", action: configure).buttonStyle(.plain).foregroundStyle(.secondary)
                }
            }.font(.system(size: 11))
        }
        .padding(20)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.35))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.10)))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct HUDSlotView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var presentation: HUDPresentation
    let slot: Slot
    let action: () -> Void
    @HUDViewState private var hovered = false

    private var current: Bool { slot.app != nil && slot.app?.path == presentation.currentPath && slot.enabled }
    private var status: String {
        guard let app = slot.app else { return "未绑定" }
        if model.isMissing(app) { return "未找到" }
        if !slot.enabled { return "已停用" }
        if current { return "当前应用" }
        return model.runningPaths.contains(app.path) ? "运行中" : "未运行"
    }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    if let app = slot.app {
                        Image(nsImage: model.icon(for: app)).resizable().frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "plus.app").font(.system(size: 26, weight: .light))
                            .foregroundStyle(.tertiary).frame(width: 32, height: 32)
                    }
                    Text(slot.app?.name ?? "添加应用").font(.system(size: 12, weight: .medium)).lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(slot.number)").font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                HStack(spacing: 5) {
                    if let app = slot.app, model.runningPaths.contains(app.path), slot.enabled, !model.isMissing(app) {
                        Circle().fill(current ? Color.accentColor : Color.secondary).frame(width: 4, height: 4)
                    }
                    Text(status)
                    Spacer(minLength: 0)
                    if let count = presentation.windowCounts[slot.number], count > 1 {
                        Text("\(count) 窗口")
                    }
                }.font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 86, maxHeight: 86)
            .background(current ? Color.accentColor.opacity(0.10) : Color.primary.opacity(hovered ? 0.08 : 0.035))
            .clipShape(RoundedRectangle(cornerRadius: 11))
            .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(current ? Color.accentColor.opacity(0.30) : Color.primary.opacity(0.05)))
            .opacity(slot.enabled ? 1 : 0.5)
            .contentShape(RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 && presentation.interactive }
        .accessibilityLabel("槽位 \(slot.number)，\(slot.app?.name ?? "添加应用")，\(status)")
        .accessibilityHint(presentation.interactive ? "按数字 \(slot.number) 或点击选择" : "快捷键 \(model.configuration.modifier.symbols)\(slot.number)")
    }
}
