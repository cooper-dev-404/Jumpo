# Jump — macOS 技术可行性说明

> 产品版本：V1.0；文档修订：R2（2026-10-04）  
> 目标：验证 Jump 核心产品能力是否能基于 macOS 公共 API 稳定实现，并明确权限、Sandbox、Spaces、多窗口和分发风险。  
> 技术建议基线：Swift + SwiftUI + AppKit；优先支持较新的 macOS 主版本，最终最低系统版本由开发阶段 POC 确定。

---

## 0. 证据与开发前基线

R2 范围调整：全局快速搜索按 2026-10-04 用户决定暂缓，当前使用 macOS 聚焦搜索。本文涉及 Search 快捷键、窗口标题索引、搜索面板和搜索验收的设计均为暂缓参考，不纳入当前开发或权限用途。HUD 继续开发，窗口标题仍不读取。

评审依据：本地 PRD / UI 文档、用户分享对话、Apple 官方文档与当前本机 macOS SDK 头文件。文档评审阶段仅完成 API 声明核对；随后已建立原型并进入实机 POC，最新证据见 [原型验证记录](../validation/Prototype_Validation.md)。API 存在不代表所有目标 App 都能稳定响应。

- Swift + SwiftUI + AppKit 作为原生实现方案；第三方依赖、最低系统版本、Intel 支持范围在 POC 后明确，不用“最新两代”代替最终版本号。
- 完整窗口功能先按非沙盒应用开发验证；正式官网分发使用 Developer ID、Hardened Runtime 与公证。Mac App Store 不进入首版并行开发，原因见第 20 节。
- Window Picker / Profiles / Dock 导入 / 云同步等属于后续版本；原型与建议模块树不代表首版实现范围。
- 业务规则以 PRD R2 为准：固定槽位、窗口循环快照、权限降级与成功判定必须同步实现。

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

> **Accessibility 不可用时仍保留应用级操作路径；具体激活仍受系统和目标 App 状态影响，失败必须如实反馈。Window Jump 是有权限且目标 App 支持时提供的增强能力。**

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
- 固定组合键优先验证 Carbon `RegisterEventHotKey`；`NSEvent` 用于独立的长按观察，不作为全局拦截器
- ServiceManagement / `SMAppService`
- `NSStatusItem`

### 2.3 数据

V1 推荐：

- `UserDefaults`：轻量 Preferences；
- JSON / Codable：V1.0 的 App 绑定、Slots 与少量本地使用记录；不同时引入多套数据库；
- 配置包含 schemaVersion，原子写入，保留最近可读备份；损坏时保留原文件并提示恢复，不静默清空；
- 通过系统 Application Support URL 保存配置，不硬编码用户名；Profiles / iCloud / 完整统计留待后续；
- Runtime Window Index：内存维护，不持久化全文标题历史。

---

## 3. 能力可行性矩阵

| 能力 | 可行性 | 推荐路径 | 权限 | 风险 |
|---|---|---|---|---|
| Menu Bar | 高 | NSStatusItem | 无 | 低 |
| App 定位 | 高 | NSWorkspace / Bundle ID | 无 | 低 |
| App 启动 | 高 | NSWorkspace.openApplication | 无 | 低 |
| App 激活 | 高 | NSRunningApplication.activate | 无 | 中低 |
| Running Apps | 高 | NSWorkspace / NSRunningApplication | 无 | 低 |
| 全局快捷键 | 待 POC | RegisterEventHotKey 注册明确组合 | 验证无 AX / Input Monitoring 时的行为 | 中 |
| 长按 Option HUD | 待 POC | 独立事件观察 + 可取消状态机 | 取决于实现和系统 | 高 |
| Window 枚举 | 中高 | AXUIElement + CGWindowList 辅助 | Accessibility | 中 |
| Window Title | 中高 | AX attributes | Accessibility | 中 |
| Focus Window | 中高 | AXRaise / focused window | Accessibility | 中 |
| Restore Minimized | 中高 | AXMinimized attribute | Accessibility | 中 |
| Window Cycle | 中高 | Window Index + AX | Accessibility | 中 |
| Spaces 直接管理 | 低 | 不建议 | — | 高 |
| Full Screen 跳转 | 中 | App/window activate + 系统行为 | Accessibility 部分 | 中 |
| Stage Manager | 中 | 遵循系统激活 | 无额外 | 中 |
| Login at Startup | 高 | SMAppService | 用户设置 | 低 |
| 完整功能 Mac App Store 版 | 当前不纳入 | AX 辅助控制与 Sandbox 存在明确限制 | 另行设计产品范围 | 高 |
| 官网 DMG | 高 | Developer ID + Notarization | — | 中 |

---

## 4. App 扫描与识别

### 4.1 不要把 App Path 当唯一标识

App 更新、移动、重复安装都可能导致路径变化。

业务主键使用内部 `app_id: UUID`；`bundleIdentifier` 用于系统查找，不视为安装副本或运行进程的唯一标识。

辅助：

- App URL；
- Display Name；
- Version；
- Icon；
- Code signature 信息（必要时）。

### 4.2 App 定位

优先使用 `NSWorkspace` 的 Bundle Identifier 解析能力，而不是依赖已废弃的旧 Launch Services API。

`NSWorkspace.urlForApplication(withBundleIdentifier:)` 可根据 Bundle ID 返回系统认为最合适的 App URL。

用途：

- Missing App 自动修复；
- App 更新后路径重新解析；
- 避免写死 `/Applications/Figma.app`。

### 4.3 App 列表来源

可组合：

1. `/Applications`
2. `~/Applications`
3. `/System/Applications`（包含 Utilities 等应用目录）
4. 当前 Running Apps
5. 用户手动选择 `.app`

扫描可访问的标准应用目录，发现 `.app` 后停止进入该包，不遍历整个磁盘。合并当前可启动的运行应用和用户手动选择项，过滤 Helper / XPC / 后台代理；安装在非标准目录的应用可手动添加。

同 Bundle ID 有多个安装副本时保留路径信息，优先用户指定 URL；自动重定位存在歧义时让用户选择。以可读应用元数据确认对象，不只检查 `.app` 后缀。扫描异步执行，索引增量刷新，应用图标缓存。

---

## 5. App Launch

### 5.1 推荐 API

`NSWorkspace.openApplication(at:configuration:completionHandler:)`

优点：

- 公共 API；
- 异步；
- 能返回 `NSRunningApplication`；
- 可处理 App 启动失败。

### 5.2 状态机

```text
Resolve URL
 ↓
Already Running?
 ├─ No → openApplication
 └─ Yes → activate
```

### 5.3 性能

不要在主线程同步等待 App 完整启动。

触发后：

- 立即返回 Hotkey Handler；
- Completion 更新状态；
- 必要时做一次 Activate；
- 同 App 启动中的重复输入合并，不重复启动；
- 回调携带 requestID，旧请求已被替代时不得继续激活；
- NSWorkspace 已提交的启动动作未必可取消，记录迟到结果但不主动抢回焦点。

---

## 6. App Activate

### 6.1 推荐 API

`NSRunningApplication.activate(options:)`

Apple 公共 API 明确提供应用激活能力。

### 6.2 限制

激活结果不是 100% 由 Jump 控制：

- App 可能已经退出；
- App activation policy 可能不适合前台激活；
- App 自身状态或系统窗口管理会影响结果。

因此 API 返回 `Bool` 需要检查，但不能仅凭返回值计为用户已到达。当前本机 SDK 的 `activateWithOptions:` 注释将成功描述为请求成功发送；Apple 网页的描述更简略。本产品以 `NSWorkspace` 前台应用 / `isActive` 和目标窗口焦点的后续观察作为完成依据。

不要将已弃用的 `.activateIgnoringOtherApps` 作为强制抢前台手段；macOS 14 起该选项已弃用。本机 SDK 明确提示它不再生效。`activateAllWindows` 会带出全部窗口，不用于默认精确跳转。参见 [ActivationOptions](https://developer.apple.com/documentation/appkit/nsapplication/activationoptions)。

### 6.3 降级

如果指定 Window 无法 Focus：

1. Activate App；
2. 尝试 main/focused window；
3. 仅 App 确认已前台时记录应用级降级成功；否则记录失败或超时，不宣称完成 Jump。

---

## 7. Window Detection

### 7.1 核心路线

建议：

**AXUIElement 为主，CGWindowList 为辅。**

原因：

- AX 更适合操作 UI 元素和窗口属性；
- Quartz Window Services 更适合获取 Window Server 层面的窗口信息；
- 单纯依靠 CGWindowList 不适合完成 Focus / Restore 等交互。

### 7.2 AXUIElement

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

### 7.3 Quartz Window Services

`CGWindowListCopyWindowInfo` 可以返回当前用户会话中的窗口信息，例如 window ID、bounds 等。

但 Apple 文档也提示：生成系统窗口字典相对昂贵。

因此不要 10ms/16ms 高频轮询。

推荐用途：

- 按需补充窗口可见性 / Window Server 信息；
- Debug；
- 可选的 AX / Window Server 信息匹配提示；不能以标题或 bounds 推定可靠的一一对应关系。

CG 窗口元数据可能因权限/系统版本缺失；不通过字段是否为 nil 推断授权状态。不为补齐标题或数量请求屏幕录制：V1.0 标题来自有授权的 AX，CG 不可用时仍可走 AX / App 路径。不调用私有 `_AXUIElementGetWindow` 建立映射。参见 [Apple 对窗口元数据权限的说明](https://developer.apple.com/videos/play/wwdc2019/701/)，具体字段可用性仍须逐版本验证。

### 7.4 窗口身份与可操作性

内部 UUID + 进程会话 + AX 元素引用构成运行时记录；PID 可能复用，窗口标题会变化且可重名。窗口重建、进程退出或 AX 对象失效后清除原记录；不按标题把新窗口当成旧窗口。枚举状态区分 unknown / available / unsupported / permissionDenied。

默认处理标准顶层窗口，排除桌面、菜单、工具浮层和 Jump 自身；标题为空使用当前会话内名称 `App — Window N`。属性/操作逐一检查支持情况；模态窗口/Sheet 尊重目标 App 焦点约束，不能绕过对话框。窗口过滤与应用兼容情况纳入 POC。

---

## 8. Accessibility 权限

### 8.1 必要性

要稳定控制其他应用窗口，Accessibility 基本是核心依赖。

Apple 的 AX API 就是为受信任 Accessibility Client 与其他应用可访问元素通信和控制而设计。

### 8.2 检测

使用：

- `AXIsProcessTrusted()`
- `AXIsProcessTrustedWithOptions()`

后者可以通过 `kAXTrustedCheckOptionPrompt` 触发系统提示，但提示是异步的。

### 8.3 产品策略

不能把整个产品绑定在 Accessibility 上。

#### 未授权

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

#### 已授权

允许尝试 Window Jump；每个 App 的属性、动作和通知支持仍需检测，授权不等于目标窗口可控。

### 8.4 权限体验

不要 App Launch 就强制请求。

在用户启用窗口访问或需要长按提示时解释实际用途，再由用户决定授权；不对授权转化率作未经测试的判断。返回前台、执行窗口操作前和权限状态变化时重新检查；撤销后清空标题/AX 缓存、取消相关任务，保留应用级功能。

窗口访问与长按监听分开建能力状态：前者有权限不代表后者可用；Input Monitoring 仅在采用的路径实际需要时解释。V1.0 不采集屏幕图像，不要求 Screen Recording / Automation。

---

## 9. 全局快捷键

这是 V1 最需要 POC 的模块之一。

### 9.1 需求拆分

产品实际上有两类键盘需求：

#### A. 固定组合键

例如：

- `⌥1`
- `⌥2`
- `⌥Space`

#### B. Modifier Long Press

例如：

- 单独按住 Option 220ms 显示 HUD；
- 松开关闭；
- Option + 数字快速触发时不显示 HUD。

B 比 A 更复杂。

### 9.2 NSEvent Global Monitor

`NSEvent.addGlobalMonitorForEvents(matching:handler:)` 可以系统级观察其他应用收到的事件，但只能观察，不能拦截或修改。

Apple 文档明确说明：键盘相关事件只有在 Accessibility 已启用或进程被信任时才能监控。

全局 monitor 不接收发给 Jump 自身的事件；需要与 local monitor 协调，并避免重复分发。不能用观察回调实现“按下快捷键后吞掉原字符”；它也不能保证 Esc 不继续传给原 App。键盘事件权限、flagsChanged、Secure Input 及所选事件路径的组合必须实测。

依据：[NSEvent 全局监听文档](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:))，以及本机 SDK `AppKit.framework/Headers/NSEvent.h`。

### 9.3 推荐架构

#### Hotkey Dispatcher

用于明确的 `modifier + key` 组合。首选 POC 候选是公开 Carbon `RegisterEventHotKey` / `UnregisterEventHotKey`，单独验证无窗口访问权限时的 App Jump；不把此候选的权限表现写成已验证保证。

当前 SDK `CarbonEvents.h` 声明：非独占注册可能让多个应用收到同一组合；可使用 `kEventHotKeyExclusive` 请求独占注册并处理失败。这不是枚举所有系统/第三方快捷键的接口，注册成功仍需实际试按。注册/注销非线程安全，集中在主线程管理。

要求：

- 注册/注销；
- 冲突处理；
- 支持物理 KeyCode；
- 回调仅提交请求，不做 AX 查询或磁盘扫描；
- 只注册已绑定且启用的槽位和 Search；空槽位不占用输入；
- 配置更新采用一次校验、注册、提交；部分失败注销新增项并恢复旧集合，明确报告无法恢复的注册项；
- 暂停时注销全部注册并停用长按观察，恢复时重新验证；
- POC 验证命中后原 App 不收到多余字符，同一次按下不会重复启动。

#### Modifier State Monitor

单独负责：

- Option down；
- 220ms timer；
- number key arrived；
- modifier up；
- 任意其他按键、额外修饰键、鼠标按下与监听失效导致的本次取消；
- Direct Jump 后锁定本次 HUD 计时，修饰键释放后才重新待命。

已被 hotkey 注册消耗的事件可能不会出现在观察器中，Dispatcher 必须直接通知状态机取消 HUD，不能只等 monitor 回调。

这两个模块分开，不要把所有逻辑塞进一个 Event Tap。

### 9.4 Accessibility 与 Input Monitoring

不同监听实现路径可能引发不同 TCC 权限表现，因此必须在真实签名 App 上做 POC，至少验证：

- AX 与 Input Monitoring 均未授权、仅 AX、仅 Input Monitoring、两者已授权；
- 权限撤销、重新授权、签名或安装路径变化后的状态；
- 记录当前非沙盒构建及实际 entitlements，不把沙盒版列入首版验证前提；
- Intel / Apple Silicon（如需支持）；
- 候选最低版本与开发机当前稳定系统，记录精确版本号；
- ANSI / ISO / JIS 键盘、中英文输入法、Option 字符输入、常用编辑组合；
- Secure Input、登录/锁屏、睡眠唤醒、远程会话（如纳入支持范围）。

产品文案不要在开发验证完成前写死“只需要某一个权限”。

---

## 10. Direct Jump 与 HUD 的竞争条件

```text
Idle
 → 完整 Trigger Modifier 按下 → PendingHUD（220ms）
   → 有效 Slot / Search：取消计时，执行，标记本次已使用
   → 其他按键 / 额外修饰键 / 鼠标 / Esc：本次取消，原事件正常传递
   → 松开：Idle
   → 到期且条件仍有效：HUDVisible
      → 有效 Slot：先隐藏，再 Jump
      → Search：先隐藏，再取得输入焦点
      → Esc / 普通输入 / 外部点击 / 松开：隐藏
```

实现要求：

- 每次计时携带 sessionID；失效 timer 不得打开新 HUD。同一次修饰键持续按住期间，取消或执行后不再次显示。
- 过滤自动 key repeat；同一数字释放后重新按下才是新的循环意图。
- 规范化左右修饰键与 Caps Lock / Fn 等标志；只在配置组合满足时待命，不把所有包含 Option 的事件都视为 Trigger。
- 裸数字仅在已取得焦点的菜单 HUD / Search / Picker 内处理，不注册成全局数字键。
- 监听不可用、Secure Input、睡眠/锁屏时取消状态；恢复时确认真实修饰键状态，不能执行残留动作。
- 使用 keyCode 保存绑定，显示标签随键盘布局校验。顶部数字行与数字小键盘不默认等价，非美式布局必须单独测试；中文组合输入的 Enter 优先确认候选。

无可靠输入观察时关闭长按提示，菜单 HUD 与固定快捷键保持独立。非激活 HUD 不负责全局拦截 Esc 或普通字符。

---

## 11. Window Focus / Raise

### 11.1 目标

Jump 到指定窗口通常需要：

1. App Activate；
2. 如果窗口最小化，Restore；
3. Raise / Focus Window；
4. 检查实际目标焦点后记录 recent order；仅请求成功不更新为窗口成功。

### 11.2 异步问题

App Activate 与 Window Raise 不一定同步完成。

不能简单：

```text
activate()
raise()
```

然后假定成功。

推荐：

- 先 Activate；
- Restore 后等待最小化属性实际变为 false，再进行焦点操作；恢复动画同样消耗本次请求预算；
- 在短暂异步窗口内检查 focused state；
- 必要时 retry 1 次；
- 总重试时间要有上限，并且读、写、重试共同消耗同一预算；
- `AXUIElementCopyAttributeValue` / `PerformAction` 是可能阻塞的跨进程调用，放到专用串行工作队列，不阻塞 MainActor 或 Swift 协作线程池；
- 用 `AXUIElementSetMessagingTimeout` 设置有限的调用超时。对单个 AX 元素设置不自动传播到其他元素，须覆盖实际调用对象；
- Task cancellation 不能中断已进入的同步 AX 调用；用 requestID 丢弃过期结果，并避免无限堆积任务；
- 超时不能一概等于操作没发生，重试前检查可观察状态，避免重复 Restore / Raise。

以上 AX 行为依据本机 SDK `HIServices.framework/Headers/AXUIElement.h`。具体超时预算待 POC 标定。

避免忙等。

### 11.3 App 兼容性

部分 Electron、Java、跨平台 App 的 AX 行为可能不同。

2026-10-01 本机 AppKit 测试窗口在最小化后由 `AXStandardWindow` 变为 `AXDialog`，不能仅凭 subrole 排除。0.2.2 加入受限兼容规则：窗口必须明确已最小化、`AXModal=false` 且具有最小化按钮；恢复后重新检查模态状态与实际焦点。可见对话框、模态状态未知、系统对话框和 Sheet 不适用此例外。详见原型验证记录，不能据此推断所有第三方应用都兼容。

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

## 12. Window Cycle

### 12.1 不建议每次重新完整扫描

建立 Runtime Window Index。

事件来源：

- App launch/terminate；
- AX notifications（可用时）；
- Jump 前按需刷新；
- Search/Picker 打开时刷新。

### 12.2 Recent Order

同时使用 AX focused/main window、可用的焦点通知与 Jump 成功记录，反映用户通过鼠标/系统切换器做出的选择；只记录 Jump 会得到过时的“最近窗口”。

循环开始时冻结候选顺序与起始下标；后续 Focus 只更新会话游标，不重排快照。会话结束后再把成功结果合并到全局最近记录。新建窗口下次会话加入，已销毁项跳过，规则与 PRD 第 6.5 节一致。

最近窗口记录用于从其他 App 进入时选择首个窗口，不应重排仍在前台的稳定循环顺序。超时后的会话以当前窗口为起点旋转稳定列表，保留其他窗口的相对顺序；不要简单把当前窗口移到列表头，否则慢速输入可能只在两个窗口间往返。

### 12.3 Window Destroyed

当 Window ID / AX Element 已失效：

- 移除缓存；
- refresh；
- 重试一次；若用户在 Search / Picker 显式选定的窗口失效，反馈失效，不按相同标题切到另一窗口。

---

## 13. CGWindowList 性能策略

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

## 14. Menu Bar

### 14.1 API

`NSStatusItem` 是标准公共 API。

可通过 `NSStatusBar.system.statusItem(withLength:)` 创建。

### 14.2 注意

Apple 文档指出 Menu Bar 空间有限，状态项不应成为唯一入口，也应提供隐藏状态项的偏好设置。

菜单图标隐藏时，已注册快捷键仍可使用，但它们也可能失败。必须实现再次打开应用时显示设置的恢复入口；关闭设置窗口不退出后台服务，显式 Quit 才退出。不能让菜单图标和 Dock 图标同时隐藏后无路返回。

---

## 15. HUD / Search / Picker Window

### 15.1 AppKit NSPanel

建议核心浮层使用 `NSPanel`，原因：

- 可实现非传统主窗口；
- 可控制成为/不成为 key；
- 可设置 floating level；
- 更适合瞬时工具 UI。

SwiftUI View 可嵌入 Panel。分开实现不激活的长按提示 HUD 与可接受键盘焦点的菜单 HUD / Search；同一时刻最多一种浮层。取消时仅在 Jump 仍拥有焦点且用户未转向其他 App 的情况下恢复原 App；成功跳转时不执行旧焦点恢复。

显示器规则：触发前通过有权限的 AX 读取外部 focused window bounds，取相交面积最大的屏幕；不可用时取鼠标所在屏幕，再主屏。`NSApp.keyWindow` 不是其他应用的窗口。

### 15.2 Spaces / Full Screen 上的自有 HUD

Jump 自己的 HUD 可通过 `NSWindow.CollectionBehavior` 配置，例如与 Spaces / Full Screen 相关的行为。

Apple 提供 `canJoinAllSpaces`、`moveToActiveSpace`、`fullScreenAuxiliary` 等公共行为选项；前两者是不同的策略，不能不加区分地叠加。

需要通过真实体验验证最终组合，尤其避免 HUD 在全屏 App 中消失或错误切换 Space。

---

## 16. Spaces 能力边界

这是一个必须在产品上收敛的点。

### 16.1 公共 API 能做什么

Apple 对**自身窗口**提供 `NSWindow.CollectionBehavior`，可以指定：

- canJoinAllSpaces；
- moveToActiveSpace；
- fullScreenAuxiliary；
- Stage Manager 相关行为。

### 16.2 不应承诺什么

不要依赖私有 CGS / Space APIs 实现：

- 获取系统所有 Space 的稳定 ID；
- 把其他 App 窗口搬到任意 Space；
- 重排 Mission Control Spaces。

原因：

- 公开 API 覆盖有限；
- 私有 API 不稳定；
- App Store / 签名 / 系统版本兼容风险高；
- Apple Developer Agreement 要求 App Store 应用使用文档化 API。

### 16.3 产品层正确表述

应表述为：

> Jump 激活目标 App/Window，并尽量让 macOS 按原生窗口管理逻辑切换到它所在的 Space。

而不是：

> Jump 完全控制 macOS Spaces。

---

## 17. Full Screen

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

## 18. Stage Manager

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

## 19. Launch at Login

### 19.1 推荐 API

macOS 13+ 使用 `SMAppService`。

Apple 文档明确说明它用于注册和控制 Login Items / Launch Agents / Launch Daemons，`mainApp` 对应主应用 Login Item。

### 19.2 UI

Preferences → Launch at Login。

默认关闭，用户主动开启后调用注册。状态读取 `SMAppService.status`，区分已启用、未注册、需要批准及不可用；不能只保存 UserDefaults 假状态。注册失败和用户在系统设置关闭时同步更新 UI。

---

## 20. App Sandbox

### 20.1 已知限制

Apple 的 [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox) 将辅助应用使用 Accessibility API 列为与 App Sandbox 不兼容的活动。不能把用户授予 AX 权限等同于沙盒已允许跨应用窗口控制，也不能将完整能力的 Mac App Store 版写成普通兼容性测试即可解决的问题。

### 20.2 当前实现方案

完整 V1.0 以非沙盒 App 为开发验证方案，正式分发使用 Developer ID 签名、Hardened Runtime 与公证。AX 访问仍需用户授权；非沙盒不意味着取消 macOS 的隐私控制。Hardened Runtime 与 App Sandbox 是不同机制，不因 AX 需求而一并关闭前者。

Mac App Store 若后续立项，必须先说明可保留的功能、公开合规实现路径及其与完整版本的差异；不得依赖私有 entitlement 或辅助进程绕过沙盒。该渠道不列为首版开发依赖，也不作当前可行性保证。

---

## 21. Apple Events

V1 不建议依赖 AppleScript / Apple Events 作为通用窗口控制主路径。

原因：

- 不同 App 支持不一致；
- Automation 权限弹窗复杂；
- Sandbox 下向任意 App 发送 Apple Events 有额外限制；
- 无法覆盖所有 App。

可在未来作为“特定 App 增强适配器”，而不是核心架构。

---

## 22. App Missing / Path Change

Slot 保存 Bundle ID。

Jump 时：

1. 检查用户选择的缓存 URL 及 Bundle ID 是否仍匹配；
2. 缓存失效 → `NSWorkspace.urlForApplication(withBundleIdentifier:)`；
3. 唯一且匹配 → 更新 URL；存在多个副本/身份不匹配 → 提供重新选择，不静默替换；
4. 未找到 → Missing；
5. 用户可手动 Locate `.app`。

避免因 App 自动更新或移动导致 Slot 永久失效。

---

## 23. Multiple Instances

同一 Bundle ID 可能出现多个 Running Process。

策略：

V1：

- 默认 Last Active PID；
- App-level Jump 激活最近实例；
- 窗口索引区分 PID/进程会话；Search 显示能识别的实例信息，不能混用 AX 引用。

V1.1：

- Window Picker 可聚合实例窗口；高级实例固定规则另行评审，不把临时 PID 当持久身份。

---

## 24. Search Index（暂缓，非当前版本范围）

### 24.1 App Index

字段：

- name
- alias
- bundle id
- running
- pinned shortcut
- last used

### 24.2 Window Index

仅当前会话：

- title
- app name
- pid
- last active
- minimized

### 24.3 Fuzzy Search

完全本地实现。

可用：

- prefix/exact 优先；
- subsequence / fuzzy score；
- usage score；
- pinned boost（仅同一匹配层）。

与 PRD 一致：精确 → 前缀 → 子串 → 模糊；运行、固定、使用频次不越过匹配层。V1.0 名称/别名支持中文，拼音扩展不默认纳入。查询携带 generation，丢弃旧结果；应用缓存先返回，AX 窗口补充使用有上限的后台任务，不能为每个按键全系统扫描。

不需要大模型。

---

## 25. 数据安全

### 25.1 Window Title

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

### 25.2 Usage

长期统计只保存 App-level ID / Count 即可。

窗口最近记录仅保留会话内存，不落盘；对标题做普通哈希不等于匿名化，不以哈希为由上传或长期保留。

---

## 26. 线程模型

建议：

### Main Thread

- UI；
- NSWindow / NSPanel；
- 必须主线程调用的 AppKit。

### 后台任务与专用队列

- App Index；
- Search；
- Window metadata 构建；
- Usage persistence；
- 阻塞 AX 调用单独进入有界串行工作队列，向协调器返回不可变结果；
- AXObserver 的 run-loop source 在明确的长期运行 run loop 上注册和移除。Actor 不自动提供 run loop。

### Jump Coordinator

使用单独 Actor / Serial Queue，避免：

- 用户快速连续按快捷键导致竞争；
- 上一个 Window Focus 还未完成，下一个又启动；
- recent order 写乱。

---

## 27. Jump Coordinator 状态

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
Session(appID, processSession, orderedWindowIDs, cycleIndex, lastTriggerAt, generation)
```

用单调时钟计算 1000ms 间隔。切到不同目标或用户手动离开时终止会话；同 App 快速输入合并为目标游标，不能排队执行每次过时的中间焦点动作。协调 Actor 管理意图和状态，AX 阻塞调用交给独立工作队列。

---

## 28. 事件驱动缓存

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

## 29. 错误码建议

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

## 30. 日志与诊断

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

## 31. 性能策略

### 31.1 Idle

- 不扫描 Window；
- 不做高频 Timer；
- Hotkey listener + Workspace notification 为主。

### 31.2 Trigger

只解析目标 App 的状态，不扫描全系统。

### 31.3 Search Open

此时才刷新 Running Window Index。

### 31.4 HUD

只需要 Pinned Apps 状态；Window Count 可来自缓存，避免为 HUD 强制全量 AX 扫描。

---

## 32. 建议模块划分

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
├─ WindowPickerController（V1.1）
├─ SettingsStore
├─ UsageStore
└─ Diagnostics
```

---

## 33. POC 优先级

以下为技术 POC 验收计划。每项输出：最小可复现程序、OS/硬件/SDK/签名信息、权限矩阵、操作步骤、预期/实际结果、耗时与失败分类。阶段性执行结果单独记录在 [原型验证记录](../validation/Prototype_Validation.md)，不以局部通过替代整项验收。

顺序：POC-1 + POC-2 验证基础应用切换 → POC-3 窗口增强 → POC-4 系统场景 → POC-5 安装分发。先完成一条“绑定一个 App → 快捷键启动/切换”的可运行路径，再扩展 UI。

### POC-1：全局快捷键

验证：

- `⌥1…9`；
- `⌥Space`；
- 长按 Option；
- 快速 Option+数字不弹 HUD；
- Permission 行为。

**这是最高优先级。**

通过条件：无 AX / Input Monitoring 时验证明确注册组合的实际表现；命中不向原 App 输入字符；非命中组合不受干扰；长按、按键重复、取消/释放、暂停恢复和注册失败回滚均符合 PRD。若长按不能稳定满足条件，只关闭长按入口，不能拖累基础 App Jump。

### POC-2：App Launch / Activate

目标 App：Finder、Chrome、Figma、VS Code、WeChat。

通过条件：未运行/已运行/隐藏/无窗口/路径变化/多个安装副本分别可复现；异步启动不阻塞输入；快速触发 A 再 B 时旧回调不主动抢焦点；API 返回值与真实前台结果分别记录。

### POC-3：AX Window List / Focus

验证：

- Window title；
- focused window；
- minimized；
- restore；
- raise；
- cycle；
- 三窗口稳定循环快照、用户在 Jump 外改变焦点、空标题/重名窗口；
- 权限撤销、AX 超时、不支持动作、窗口销毁与模态对话框。

通过条件：指定窗口成功与 App 级降级分别可见；无错误窗口误选；卡死目标不阻塞 UI 和后续应用级请求。

### POC-4：Spaces / Full Screen / Multi-display

测试矩阵：

- 同 Space；
- 不同 Space；
- Full Screen；
- 外接屏；
- Stage Manager。

### POC-5：安装与分发

验证当前非沙盒完整版本：

- 稳定 Bundle ID 与开发签名，在固定安装路径测试权限申请/撤销；
- 有 Developer ID 条件时完成签名、公证和干净机器首次打开；无证书时如实记录阻塞，不将本机运行等同于通过分发；
- 替换新版本后配置仍可读、登录项状态正确、TCC 行为可解释；
- 不携带多余 entitlement；不因窗口切换引入 Screen Recording / Automation。

不以尝试私有 entitlement 或绕过 Sandbox 作为 POC 成果。

---

## 34. 兼容性测试矩阵

为每条场景标注通过 / 降级 / 失败 / 未测。首轮优先 Finder、Safari 或 Chrome、VS Code、Figma、WeChat；其他应用按可获得环境扩展，未测应用不宣称兼容。

至少覆盖：

### 系统

- 开发机与候选最低 macOS 的精确版本；
- Apple Silicon；
- Intel 如计划发布，则必须取得独立编译/运行证据；缺少设备时标记未测。

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

## 35. 分发建议

### 35.1 V1 推荐

**官网 DMG 首发 + Developer ID + Notarization**。

理由：

- 产品核心依赖 Accessibility / 全局快捷键 / 跨 App 窗口行为；
- 先保证核心体验稳定；
- 避免 Sandbox 对 V1 造成不必要产品妥协。

### 35.2 Mac App Store

不作为完整 V1.0 的开发或分发目标。依据第 20 节的 Sandbox 限制，后续若探索仅应用级功能版本，应另立范围与验证计划，不能假定当前完整方案可直接迁移。

---

## 36. 主要技术风险

### 风险 1：长按 Modifier 监听权限体验

等级：高。

措施：

- POC 提前验证；
- 如必须 Accessibility，则在产品 Onboarding 透明说明；
- 仍保留不依赖 HUD 的配置入口。

### 风险 2：不同 App AX 实现差异

等级：中高。

措施：

- App-level Activate 作为可尝试的降级路径；失败仍需反馈；
- 建兼容矩阵；
- 核心逻辑不依赖 Window Title 格式。

### 风险 3：Spaces 不可完全控制

等级：中。

措施：

- 产品不承诺 Space 管理；
- 依赖系统原生激活；
- 不用私有 API。

### 风险 4：Sandbox / MAS

等级：高。

措施：

- 完整版采用非沙盒官网分发；
- 首版不安排 MAS 并行实现；
- 后续沙盒版需另行明确能力范围。

### 风险 5：快捷键冲突无法全局可靠枚举

等级：中。

措施：

- Jump 内部冲突 100% 检测；
- 系统已知冲突提示；
- 第三方冲突通过注册失败、实际试按和用户反馈处理；注册成功不证明没有冲突。

---

## 37. 最终技术结论

Jump 的主链路有公开 API 候选，具备进入 POC 的依据；以下是待验证实现路径：

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
3. **窗口级失败尝试 App 激活，分别记录降级或失败；**
4. **Spaces 只顺应系统，不主动管理；**
5. **不依赖私有 API；**
6. **先做技术 POC，再做完整高保真 UI；**
7. **完整 V1 采用官网分发方案，MAS 不列为并行首发路线。**

整体判断：**技术上值得进入 POC / MVP 开发阶段。**

---

## 38. Apple 官方参考

以下为本说明涉及的主要官方文档：

1. [NSWorkspace](https://developer.apple.com/documentation/appkit/nsworkspace)

2. [NSRunningApplication](https://developer.apple.com/documentation/appkit/nsrunningapplication)

3. [AXUIElement](https://developer.apple.com/documentation/applicationservices/axuielement_h)

4. [AXIsProcessTrustedWithOptions](https://developer.apple.com/documentation/applicationservices/1459186-axisprocesstrustedwithoptions)

5. [CGWindowListCopyWindowInfo](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:))

6. [NSEvent Global Monitor](https://developer.apple.com/documentation/appkit/nsevent/addglobalmonitorforevents(matching:handler:))

7. [NSStatusItem](https://developer.apple.com/documentation/appkit/nsstatusitem)

8. [NSWindow.CollectionBehavior](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct)

9. [SMAppService](https://developer.apple.com/documentation/servicemanagement/smappservice)

10. [Configuring the macOS App Sandbox](https://developer.apple.com/documentation/xcode/configuring-the-macos-app-sandbox)

11. [Protecting user data with App Sandbox](https://developer.apple.com/documentation/security/protecting-user-data-with-app-sandbox)

12. [Apple Developer Program License Agreement](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)


13. [NSApplication.ActivationOptions](https://developer.apple.com/documentation/appkit/nsapplication/activationoptions) — 区分普通激活与已弃用选项。

14. [Advances in macOS Security, WWDC19](https://developer.apple.com/videos/play/wwdc2019/701/) — 窗口元数据和屏幕录制权限背景；不是对新系统所有字段的保证。

15. 本机 SDK 核对（2026-09-30）：相对 `xcrun --show-sdk-path` 返回目录，读取 `System/Library/Frameworks` 下的 `Carbon.framework/.../HIToolbox.framework/.../Headers/CarbonEvents.h`、`AppKit.framework/.../Headers/NSEvent.h`、`NSRunningApplication.h`、`ApplicationServices.framework/.../HIServices.framework/.../Headers/AXUIElement.h`。开发时以实际 SDK 声明和编译器诊断为准。
