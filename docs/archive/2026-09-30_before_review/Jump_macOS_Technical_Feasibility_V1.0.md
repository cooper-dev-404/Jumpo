# Jump — macOS 技术可行性说明

> 版本：V1.0  
> 目标：验证 Jump 核心产品能力是否能基于 macOS 公共 API 稳定实现，并明确权限、Sandbox、Spaces、多窗口和分发风险。  
> 技术建议基线：Swift + SwiftUI + AppKit；优先支持较新的 macOS 主版本，最终最低系统版本由开发阶段 POC 确定。

---

## 1. 结论摘要

从 macOS 公共 API 能力看，Jump 的核心方向**整体可行**，但必须把能力分成三层：

### A. 高可行、低风险

- Menu Bar App；
- 扫描 / 定位 App；
- 判断 App 是否运行；
- 启动 App；
- 激活 App；
- Launch at Login；
- SwiftUI 设置页；
- App 图标与 Bundle ID 管理；
- 本地搜索；
- HUD / Search Panel / Window Picker 自有窗口。

### B. 可行，但依赖 Accessibility / 行为兼容性

- 获取其他 App 的窗口列表；
- 获取窗口标题；
- 判断 focused / main / minimized window；
- Raise / Focus 指定窗口；
- Restore 最小化窗口；
- 应用内多窗口循环。

### C. 不建议承诺过度控制

- 精确枚举和管理所有 Spaces；
- 使用稳定公开 API 将任意第三方窗口移动到指定 Space；
- 依赖私有 CoreGraphics / CGS Space API；
- 假设所有 App 都完整实现 Accessibility；
- 假设所有第三方快捷键冲突都可检测。

因此产品层面应该坚持：

> **App 切换必须始终可用；Window Jump 是增强能力，Accessibility 不可用时要优雅降级。**

---

## 2. 推荐技术栈

### 2.1 UI

- **SwiftUI**：Onboarding、Settings、Apps、My Shortcuts；
- **AppKit**：NSPanel、NSStatusItem、窗口层级、快捷键/事件、部分生命周期；
- SwiftUI 与 AppKit 混合，而不是纯 SwiftUI。

### 2.2 系统能力

- AppKit / `NSWorkspace`
- `NSRunningApplication`
- ApplicationServices Accessibility / `AXUIElement`
- CoreGraphics / Quartz Window Services
- `NSEvent` 或其他公开 Hotkey 路径
- ServiceManagement / `SMAppService`
- `NSStatusItem`

### 2.3 数据

V1 推荐：

- `UserDefaults`：轻量 Preferences；
- JSON / Codable 或 SQLite / SwiftData：Slots、Profiles、Usage；
- Runtime Window Index：内存维护，不持久化全文标题历史。

---

# 3. 能力可行性矩阵

| 能力 | 可行性 | 推荐路径 | 权限 | 风险 |
|---|---|---|---|---|
| Menu Bar | 高 | NSStatusItem | 无 | 低 |
| App 定位 | 高 | NSWorkspace / Bundle ID | 无 | 低 |
| App 启动 | 高 | NSWorkspace.openApplication | 无 | 低 |
| App 激活 | 高 | NSRunningApplication.activate | 无 | 中低 |
| Running Apps | 高 | NSWorkspace / NSRunningApplication | 无 | 低 |
| 全局快捷键 | 高 | 公共 Hotkey / Event 方案 | 视实现 | 中 |
| 长按 Option HUD | 高 | Global flags/key event | Accessibility 可能需要 | 中 |
| Window 枚举 | 中高 | AXUIElement + CGWindowList 辅助 | Accessibility | 中 |
| Window Title | 中高 | AX attributes | Accessibility | 中 |
| Focus Window | 中高 | AXRaise / focused window | Accessibility | 中 |
| Restore Minimized | 中高 | AXMinimized attribute | Accessibility | 中 |
| Window Cycle | 中高 | Window Index + AX | Accessibility | 中 |
| Spaces 直接管理 | 低 | 不建议 | — | 高 |
| Full Screen 跳转 | 中 | App/window activate + 系统行为 | Accessibility 部分 | 中 |
| Stage Manager | 中 | 遵循系统激活 | 无额外 | 中 |
| Login at Startup | 高 | SMAppService | 用户设置 | 低 |
| Mac App Store | 有条件 | Sandbox + Review 验证 | — | 中高 |
| 官网 DMG | 高 | Developer ID + Notarization | — | 中 |

---

# 4. App 扫描与识别

## 4.1 不要把 App Path 当唯一标识

App 更新、移动、重复安装都可能导致路径变化。

主键建议：

`bundleIdentifier`

辅助：

- App URL；
- Display Name；
- Version；
- Icon；
- Code signature 信息（必要时）。

## 4.2 App 定位

优先使用 `NSWorkspace` 的 Bundle Identifier 解析能力，而不是依赖已废弃的旧 Launch Services API。

`NSWorkspace.urlForApplication(withBundleIdentifier:)` 可根据 Bundle ID 返回系统认为最合适的 App URL。

用途：

- Missing App 自动修复；
- App 更新后路径重新解析；
- 避免写死 `/Applications/Figma.app`。

## 4.3 App 列表来源

可组合：

1. `/Applications`
2. `~/Applications`
3. 系统 Application 路径
4. 当前 Running Apps
5. 用户手动选择 `.app`

注意 Sandbox 下对任意文件系统扫描能力有约束，因此分发模式需要结合 Sandbox 验证。

---

# 5. App Launch

## 5.1 推荐 API

`NSWorkspace.openApplication(at:configuration:completionHandler:)`

优点：

- 公共 API；
- 异步；
- 能返回 `NSRunningApplication`；
- 可处理 App 启动失败。

## 5.2 状态机

```text
Resolve URL
 ↓
Already Running?
 ├─ No → openApplication
 └─ Yes → activate
```

## 5.3 性能

不要在主线程同步等待 App 完整启动。

触发后：

- 立即返回 Hotkey Handler；
- Completion 更新状态；
- 必要时做一次 Activate。

---

# 6. App Activate

## 6.1 推荐 API

`NSRunningApplication.activate(options:)`

Apple 公共 API 明确提供应用激活能力。

## 6.2 限制

激活结果不是 100% 由 Jump 控制：

- App 可能已经退出；
- App activation policy 可能不适合前台激活；
- App 自身状态或系统窗口管理会影响结果。

因此 API 返回 `Bool` 需要真正检查，不要假设成功。

## 6.3 降级

如果指定 Window 无法 Focus：

1. Activate App；
2. 尝试 main/focused window；
3. 仍失败则完成 App-level Jump。

---

# 7. Window Detection

## 7.1 核心路线

建议：

**AXUIElement 为主，CGWindowList 为辅。**

原因：

- AX 更适合操作 UI 元素和窗口属性；
- Quartz Window Services 更适合获取 Window Server 层面的窗口信息；
- 单纯依靠 CGWindowList 不适合完成 Focus / Restore 等交互。

## 7.2 AXUIElement

`AXUIElementCreateApplication(pid)` 获取某 App 顶层 Accessibility Element。

随后读取：

- `kAXWindowsAttribute`
- `kAXFocusedWindowAttribute`
- `kAXMainWindowAttribute`
- `kAXTitleAttribute`
- `kAXMinimizedAttribute`
- Position / Size 等（按需）

可执行：

- Raise；
- 设置部分可写属性；
- 恢复最小化。

## 7.3 Quartz Window Services

`CGWindowListCopyWindowInfo` 可以返回当前用户会话中的窗口信息，例如 window ID、bounds 等。

但 Apple 文档也提示：生成系统窗口字典相对昂贵。

因此不要 10ms/16ms 高频轮询。

推荐用途：

- 按需补充窗口可见性 / Window Server 信息；
- Debug；
- 建立 AX 与实际 onscreen window 的关联辅助。

---

# 8. Accessibility 权限

## 8.1 必要性

要稳定控制其他应用窗口，Accessibility 基本是核心依赖。

Apple 的 AX API 就是为受信任 Accessibility Client 与其他应用可访问元素通信和控制而设计。

## 8.2 检测

使用：

- `AXIsProcessTrusted()`
- `AXIsProcessTrustedWithOptions()`

后者可以通过 `kAXTrustedCheckOptionPrompt` 触发系统提示，但提示是异步的。

## 8.3 产品策略

不能把整个产品绑定在 Accessibility 上。

### 未授权

仍然允许：

- App Launch；
- App Activate；
- Quick Search App；
- Slots；
- Menu Bar。

限制：

- 精确 Window Picker；
- 指定窗口 Focus；
- Restore 某个窗口；
- Window Title 级 Search。

### 已授权

开放完整 Window Jump。

## 8.4 权限体验

不要 App Launch 就强制请求。

等用户真正体验到“多窗口切换”价值时再请求，权限转化率更合理。

---

# 9. 全局快捷键

这是 V1 最需要 POC 的模块之一。

## 9.1 需求拆分

产品实际上有两类键盘需求：

### A. 固定组合键

例如：

- `⌥1`
- `⌥2`
- `⌥Space`

### B. Modifier Long Press

例如：

- 单独按住 Option 220ms 显示 HUD；
- 松开关闭；
- Option + 数字快速触发时不显示 HUD。

B 比 A 更复杂。

## 9.2 NSEvent Global Monitor

`NSEvent.addGlobalMonitorForEvents(matching:handler:)` 可以系统级观察其他应用收到的事件，但只能观察，不能拦截或修改。

Apple 文档明确说明：键盘相关事件只有在 Accessibility 已启用或进程被信任时才能监控。

这意味着如果 HUD 的“单独长按 Option”基于全局键盘/flags 监听实现，很可能与 Accessibility 授权体验有关。

## 9.3 推荐架构

### Hotkey Dispatcher

用于明确的 `modifier + key` 组合。

要求：

- 注册/注销；
- 冲突处理；
- 支持物理 KeyCode；
- 不阻塞主线程。

### Modifier State Monitor

单独负责：

- Option down；
- 220ms timer；
- number key arrived；
- modifier up。

这两个模块分开，不要把所有逻辑塞进一个 Event Tap。

## 9.4 Accessibility 与 Input Monitoring

不同监听实现路径可能引发不同 TCC 权限表现，因此必须在真实签名 App 上做 POC，至少验证：

- Accessibility only；
- 未授权 Accessibility；
- App Sandbox on/off；
- Intel / Apple Silicon（如需支持）；
- 最新两代 macOS。

产品文案不要在开发验证完成前写死“只需要某一个权限”。

---

# 10. Direct Jump 与 HUD 的竞争条件

这是核心状态机。

```text
Option Down
   ↓
start 220ms timer
   ↓
┌───────────────────────┐
│ number before timeout │──→ cancel HUD → Jump
└───────────────────────┘
   ↓ timeout
show HUD
   ↓
number → Jump + dismiss
option up → dismiss
```

关键工程点：

- Timer 要可取消；
- 不能因 HUD 创建导致首个数字事件丢失；
- 键盘重复事件要过滤；
- modifier flags 切换要处理 caps lock / fn / 左右 Option 等边界；
- 输入法不应影响物理数字快捷键。

建议 Shortcut 以 KeyCode 存储，不以字符字符串作为底层唯一依据。

---

# 11. Window Focus / Raise

## 11.1 目标

Jump 到指定窗口通常需要：

1. App Activate；
2. 如果窗口最小化，Restore；
3. Raise / Focus Window；
4. 记录 recent order。

## 11.2 异步问题

App Activate 与 Window Raise 不一定同步完成。

不能简单：

```text
activate()
raise()
```

然后假定成功。

推荐：

- 先 Activate；
- 在短暂异步窗口内检查 focused state；
- 必要时 retry 1 次；
- 总重试时间要有上限。

避免忙等。

## 11.3 App 兼容性

部分 Electron、Java、跨平台 App 的 AX 行为可能不同。

V1 建议建立兼容测试矩阵：

- Finder
- Safari
- Chrome
- Arc
- Figma
- VS Code
- Xcode
- Terminal
- iTerm2
- WeChat
- Slack
- Microsoft Office
- Adobe Photoshop

---

# 12. Window Cycle

## 12.1 不建议每次重新完整扫描

建立 Runtime Window Index。

事件来源：

- App launch/terminate；
- AX notifications（可用时）；
- Jump 前按需刷新；
- Search/Picker 打开时刷新。

## 12.2 Recent Order

Jump 自己记录每次成功 Focus 的窗口。

这样“最近窗口”不完全依赖系统不可预测顺序。

## 12.3 Window Destroyed

当 Window ID / AX Element 已失效：

- 移除缓存；
- refresh；
- 重试一次。

---

# 13. CGWindowList 性能策略

Apple 文档明确提醒生成系统窗口描述是相对昂贵操作。

因此：

### 不要

- 每帧扫描；
- 50ms 定时扫描；
- 常驻全系统所有 Window 详情轮询。

### 建议

- HUD 展开时轻量刷新；
- Search 打开时刷新；
- 目标 App Jump 前刷新目标 App；
- App lifecycle 事件驱动更新。

---

# 14. Menu Bar

## 14.1 API

`NSStatusItem` 是标准公共 API。

可通过 `NSStatusBar.system.statusItem(withLength:)` 创建。

## 14.2 注意

Apple 文档指出 Menu Bar 空间有限，状态项不应成为唯一入口，也应提供隐藏状态项的偏好设置。

Jump 本身仍然可以通过快捷键运行，因此即使 Menu Bar Icon 隐藏，产品仍可工作。

---

# 15. HUD / Search / Picker Window

## 15.1 AppKit NSPanel

建议核心浮层使用 `NSPanel`，原因：

- 可实现非传统主窗口；
- 可控制成为/不成为 key；
- 可设置 floating level；
- 更适合瞬时工具 UI。

SwiftUI View 可嵌入 Panel。

## 15.2 Spaces / Full Screen 上的自有 HUD

Jump 自己的 HUD 可通过 `NSWindow.CollectionBehavior` 配置，例如与 Spaces / Full Screen 相关的行为。

Apple 提供 `canJoinAllSpaces`、`moveToActiveSpace`、`fullScreenAuxiliary` 等公共行为选项。

需要通过真实体验验证最终组合，尤其避免 HUD 在全屏 App 中消失或错误切换 Space。

---

# 16. Spaces 能力边界

这是一个必须在产品上收敛的点。

## 16.1 公共 API 能做什么

Apple 对**自身窗口**提供 `NSWindow.CollectionBehavior`，可以指定：

- canJoinAllSpaces；
- moveToActiveSpace；
- fullScreenAuxiliary；
- Stage Manager 相关行为。

## 16.2 不应承诺什么

不要依赖私有 CGS / Space APIs 实现：

- 获取系统所有 Space 的稳定 ID；
- 把其他 App 窗口搬到任意 Space；
- 重排 Mission Control Spaces。

原因：

- 公开 API 覆盖有限；
- 私有 API 不稳定；
- App Store / 签名 / 系统版本兼容风险高；
- Apple Developer Agreement 要求 App Store 应用使用文档化 API。

## 16.3 产品层正确表述

应表述为：

> Jump 激活目标 App/Window，并尽量让 macOS 按原生窗口管理逻辑切换到它所在的 Space。

而不是：

> Jump 完全控制 macOS Spaces。

---

# 17. Full Screen

目标窗口在 Full Screen Space 时：

- App Activate；
- Window Focus；
- 让 macOS 执行对应 Space 切换。

风险：

- Animation 时间较长；
- App 自身 full screen implementation 差异；
- Stage Manager + Full Screen 边界。

因此性能指标中应区分：

- Jump Engine 响应；
- macOS Space animation 完成。

不能把系统动画时间算成 Jump 自身延迟缺陷。

---

# 18. Stage Manager

V1 原则：

**不主动管理 Stage Set。**

只做：

- App Activate；
- Window Raise/Focus。

Jump 自己的 Settings / HUD Window 可以通过公开 collection behavior 做适配。

需要测试：

- Stage Manager On / Off；
- 多显示器；
- Full Screen；
- HUD 是否错误加入用户工作组。

---

# 19. Launch at Login

## 19.1 推荐 API

macOS 13+ 使用 `SMAppService`。

Apple 文档明确说明它用于注册和控制 Login Items / Launch Agents / Launch Daemons，`mainApp` 对应主应用 Login Item。

## 19.2 UI

Preferences → Launch at Login。

状态需要读取 `SMAppService.status`，不能只保存 UserDefaults 假状态。

---

# 20. App Sandbox

## 20.1 核心风险

Apple 官方 Sandbox 文档说明，Sandbox 会限制文件系统和其他受保护资源访问；并明确列出某些活动在 Sandbox 下受限制，其中包括 assistive app 的 Accessibility API 使用以及向任意 App 发送 Apple Events 等。

因此 Jump 若依赖深度 Accessibility 控制，**Mac App Store Sandbox 路线必须单独做审核/能力 POC，不能假定“代码能跑就能上架”。**

## 20.2 推荐决策

### 官网 DMG / Direct Distribution

技术自由度更高：

- Developer ID 签名；
- Hardened Runtime；
- Notarization；
- Accessibility TCC。

建议作为 V1 第一优先分发路线。

### Mac App Store

作为并行验证路线：

- 开启 Sandbox；
- 实测 AX 能力；
- 检查 Entitlements；
- 提前准备 Review 说明；
- 若核心 Window Jump 受限，则不要为了 MAS 牺牲产品主价值。

---

# 21. Apple Events

V1 不建议依赖 AppleScript / Apple Events 作为通用窗口控制主路径。

原因：

- 不同 App 支持不一致；
- Automation 权限弹窗复杂；
- Sandbox 下向任意 App 发送 Apple Events 有额外限制；
- 无法覆盖所有 App。

可在未来作为“特定 App 增强适配器”，而不是核心架构。

---

# 22. App Missing / Path Change

Slot 保存 Bundle ID。

Jump 时：

1. 检查缓存 URL；
2. 缓存失效 → `NSWorkspace.urlForApplication(withBundleIdentifier:)`；
3. 找到 → 更新 URL；
4. 未找到 → Missing；
5. 用户可手动 Locate `.app`。

避免因 App 自动更新或移动导致 Slot 永久失效。

---

# 23. Multiple Instances

同一 Bundle ID 可能出现多个 Running Process。

策略：

V1：

- 默认 Last Active PID；
- App-level Jump 激活最近实例；
- Window Picker 聚合显示所有实例窗口。

V1.1：

- 增加“固定到某实例/路径”的高级设置（仅确有需求时）。

---

# 24. Search Index

## 24.1 App Index

字段：

- name
- alias
- bundle id
- running
- pinned shortcut
- last used

## 24.2 Window Index

仅当前会话：

- title
- app name
- pid
- last active
- minimized

## 24.3 Fuzzy Search

完全本地实现。

可用：

- prefix/exact 优先；
- subsequence / fuzzy score；
- usage score；
- pinned boost。

不需要大模型。

---

# 25. 数据安全

## 25.1 Window Title

Window Title 可能包含：

- 项目名；
- 文件名；
- 客户名称；
- 私人聊天信息。

因此：

- 默认只保存在内存；
- 不写遥测；
- 不上传；
- crash log 不打印完整标题；
- debug build 也应谨慎。

## 25.2 Usage

长期统计只保存 App-level ID / Count 即可。

如需“最近 Window”，可仅保存短期哈希/会话内记录。

---

# 26. 线程模型

建议：

### Main Thread

- UI；
- NSWindow / NSPanel；
- 必须主线程调用的 AppKit。

### Background / Actor

- App Index；
- Search；
- Window metadata 构建；
- Usage persistence。

### Jump Coordinator

使用单独 Actor / Serial Queue，避免：

- 用户快速连续按快捷键导致竞争；
- 上一个 Window Focus 还未完成，下一个又启动；
- recent order 写乱。

---

# 27. Jump Coordinator 状态

建议：

```text
Idle
Resolving
Launching
Activating
FocusingWindow
Cycling
Completed
Failed
```

但用户连续输入时不能全部排队执行。

例如 `⌥5` 连按三次应该被解释为 Window Cycle，而不是排三个独立 Activate Job。

因此需要 Shortcut Session：

```text
Session(appID, startedAt, lastTriggerAt, cycleIndex)
```

---

# 28. 事件驱动缓存

监听 Workspace 生命周期事件：

- App launched；
- App terminated；
- App activated；
- App hidden/unhidden（按需）。

配合 AX Observer：

- Window created；
- Window focused；
- Window destroyed（具体通知支持需逐 App 验证）。

不要求所有 App 都完整发通知，因此仍保留按需 refresh。

---

# 29. 错误码建议

统一业务层错误：

```text
appNotFound
appLaunchFailed
appActivationFailed
accessibilityDenied
windowListUnavailable
windowInvalid
windowRaiseFailed
shortcutConflict
shortcutRegistrationFailed
permissionChanged
```

UI 不直接展示 AXError 原始错误码。

日志层保留详细码。

---

# 30. 日志与诊断

需要一套本地 Debug Log：

- Shortcut event；
- App resolve；
- launch/activate result；
- AX permission state；
- window count；
- focus result；
- latency。

隐私处理：

- Window title 默认 redacted；
- Bundle ID 可以保留；
- 用户可手动导出诊断包。

---

# 31. 性能策略

## 31.1 Idle

- 不扫描 Window；
- 不做高频 Timer；
- Hotkey listener + Workspace notification 为主。

## 31.2 Trigger

只解析目标 App 的状态，不扫描全系统。

## 31.3 Search Open

此时才刷新 Running Window Index。

## 31.4 HUD

只需要 Pinned Apps 状态；Window Count 可来自缓存，避免为 HUD 强制全量 AX 扫描。

---

# 32. 建议模块划分

```text
JumpApp
├─ AppLifecycle
├─ MenuBarController
├─ ShortcutEngine
│  ├─ HotkeyRegistry
│  ├─ ModifierMonitor
│  └─ ShortcutSession
├─ JumpEngine
│  ├─ AppResolver
│  ├─ AppActivator
│  ├─ WindowResolver
│  └─ WindowActivator
├─ AccessibilityService
├─ WindowIndex
├─ AppIndex
├─ SearchEngine
├─ HUDController
├─ SearchPanelController
├─ WindowPickerController
├─ SettingsStore
├─ UsageStore
└─ Diagnostics
```

---

# 33. POC 优先级

开发正式 UI 前，建议先做 5 个独立技术 POC。

## POC-1：全局快捷键

验证：

- `⌥1…9`；
- `⌥Space`；
- 长按 Option；
- 快速 Option+数字不弹 HUD；
- Permission 行为。

**这是最高优先级。**

## POC-2：App Launch / Activate

目标 App：Finder、Chrome、Figma、VS Code、WeChat。

## POC-3：AX Window List / Focus

验证：

- Window title；
- focused window；
- minimized；
- restore；
- raise；
- cycle。

## POC-4：Spaces / Full Screen / Multi-display

测试矩阵：

- 同 Space；
- 不同 Space；
- Full Screen；
- 外接屏；
- Stage Manager。

## POC-5：Sandbox / Distribution

分别验证：

- Unsandboxed Developer ID build；
- Sandboxed build；
- Accessibility permission；
- App scan；
- Hotkey；
- AX window control。

完成后再最终决定 MAS 是否首发。

---

# 34. 兼容性测试矩阵

至少覆盖：

### 系统

- 当前稳定版 macOS；
- 上一主要版本；
- Apple Silicon。

### Apple Apps

- Finder
- Safari
- Terminal
- Mail
- Preview

### Chromium / Electron

- Chrome
- Arc
- VS Code
- Slack
- Figma Desktop

### 开发

- Xcode
- iTerm2

### Office / Heavy Apps

- Word
- Excel
- PowerPoint
- Photoshop

### 窗口状态

- normal
- minimized
- hidden app
- multiple windows
- full screen
- different Space
- second monitor
- Stage Manager

---

# 35. 分发建议

## 35.1 V1 推荐

**官网 DMG 首发 + Developer ID + Notarization**。

理由：

- 产品核心依赖 Accessibility / 全局快捷键 / 跨 App 窗口行为；
- 先保证核心体验稳定；
- 避免 Sandbox 对 V1 造成不必要产品妥协。

## 35.2 Mac App Store

并行技术验证，不承诺首发。

如果验证后核心窗口能力和快捷键能力都能满足，再考虑双渠道。

---

# 36. 主要技术风险

## 风险 1：长按 Modifier 监听权限体验

等级：高。

措施：

- POC 提前验证；
- 如必须 Accessibility，则在产品 Onboarding 透明说明；
- 仍保留不依赖 HUD 的配置入口。

## 风险 2：不同 App AX 实现差异

等级：中高。

措施：

- App-level Activate 永远作为降级；
- 建兼容矩阵；
- 核心逻辑不依赖 Window Title 格式。

## 风险 3：Spaces 不可完全控制

等级：中。

措施：

- 产品不承诺 Space 管理；
- 依赖系统原生激活；
- 不用私有 API。

## 风险 4：Sandbox / MAS

等级：高。

措施：

- 官网版优先；
- 单独 POC；
- 不为上架牺牲核心体验。

## 风险 5：快捷键冲突无法全局可靠枚举

等级：中。

措施：

- Jump 内部冲突 100% 检测；
- 系统已知冲突提示；
- 第三方冲突通过注册失败/用户反馈处理。

---

# 37. 最终技术结论

Jump 的产品主链路可以用 macOS 公共 API 实现：

```text
Global Shortcut
   ↓
Resolve App
   ↓
NSRunningApplication / NSWorkspace
   ↓
AXUIElement Window Resolution
   ↓
Activate / Restore / Raise
   ↓
Destination
```

建议架构原则：

1. **App-level Jump 是强基线；**
2. **Window-level Jump 是 Accessibility 增强；**
3. **所有窗口级失败都必须能降级到 App 激活；**
4. **Spaces 只顺应系统，不主动管理；**
5. **不依赖私有 API；**
6. **先做技术 POC，再做完整高保真 UI；**
7. **V1 首选官网分发，MAS 并行验证。**

整体判断：**技术上值得进入 POC / MVP 开发阶段。**

---

# 38. Apple 官方参考

以下为本说明涉及的主要官方文档：

1. NSWorkspace  
   https://developer.apple.com/documentation/appkit/nsworkspace

2. NSRunningApplication  
   https://developer.apple.com/documentation/appkit/nsrunningapplication

3. AXUIElement  
   https://developer.apple.com/documentation/applicationservices/axuielement_h

4. AXIsProcessTrustedWithOptions  
   https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions

5. CGWindowListCopyWindowInfo  
   https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:)

6. NSEvent Global Monitor  
   https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:)

7. NSStatusItem  
   https://developer.apple.com/documentation/appkit/nsstatusitem

8. NSWindow.CollectionBehavior  
   https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct

9. SMAppService  
   https://developer.apple.com/documentation/servicemanagement/smappservice

10. Configuring the macOS App Sandbox  
    https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox

11. Protecting user data with App Sandbox  
    https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox

12. Apple Developer Program License Agreement  
    https://developer.apple.com/support/terms/apple-developer-program-license-agreement/
