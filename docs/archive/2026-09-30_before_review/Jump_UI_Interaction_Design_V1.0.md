# Jump — macOS UI / 交互设计方案

> 版本：V1.0  
> 对应 PRD：Jump macOS App & Window Switcher PRD V1.0  
> 设计目标：直接支撑线框图、高保真原型、Design QA 与开发实现

---

## 1. 设计目标

Jump 的 UI 设计必须服从一个与传统桌面应用不同的原则：

> **用户越熟练，看到的 UI 越少。**

因此产品不是“围绕主窗口使用”，而是由三层界面组成：

1. **Zero-UI Layer**：固定快捷键直接 Jump；
2. **Assistive Layer**：HUD / Window Picker / Quick Search；
3. **Configuration Layer**：My Shortcuts / Apps / Preferences / Onboarding。

UI 不应成为每次跳转的必经步骤。

---

## 2. 体验原则

### 2.1 Keyboard-first

任何核心操作都必须可纯键盘完成。

鼠标承担：

- 首次配置；
- 拖拽排序；
- 浏览设置；
- 长尾调整。

### 2.2 Immediate

核心交互反馈目标：

- Direct Jump：无过渡面板；
- HUD：轻量、瞬时；
- Search：打开即聚焦输入；
- Window Picker：打开即处于可选择状态。

### 2.3 Stable Mapping

Slot 位置与数字必须在视觉和交互上高度稳定。

禁止让 App Card 因运行状态自动重新排序。

### 2.4 Native macOS

视觉基调：

- 使用 macOS 原生层级、圆角、材质、阴影逻辑；
- 不做“未来感 AI 面板”；
- 不做复杂渐变；
- 不做大面积高饱和配色；
- 不使用游戏化动效。

### 2.5 Progressive Disclosure

默认只展示完成任务所需信息。

高级行为放在：

- Context Menu；
- Detail Sheet；
- Preferences；
- Advanced。

---

## 3. 整体界面地图

```text
Zero-UI
└─ Direct Jump

Transient UI
├─ Quick HUD
├─ Quick Search
├─ Window Picker
└─ Error / Status Toast

Configuration UI
├─ Onboarding
├─ My Shortcuts
├─ Apps
├─ Preferences
│  ├─ General
│  ├─ Shortcuts
│  ├─ Windows
│  ├─ Appearance
│  └─ Permissions
└─ About

Menu Bar
└─ Compact Control Menu
```

---

## 4. 主设置窗口框架

### 4.1 Window Size

建议初始尺寸：约 760 × 560 pt。

最小尺寸：约 680 × 500 pt。

不建议默认全屏。

### 4.2 Sidebar

左侧边栏宽度建议 180～210pt。

菜单：

```text
Jump

My Shortcuts
Apps

Preferences
  General
  Shortcuts
  Windows
  Appearance
  Permissions

About
```

V1 可将 Preferences 内页放到顶部 Tab，进一步压缩 Sidebar。

### 4.3 Toolbar

右上角最多保留：

- Search（仅 Apps 页）
- Help

不放多余快捷按钮。

---

# 5. My Shortcuts 页面

## 5.1 页面目标

用户在 30 秒内完成：

- 看懂当前 Slot 映射；
- 调整顺序；
- 添加 App；
- 修改 Trigger；
- 发现冲突或 Missing 状态。

## 5.2 页面结构

```text
┌─────────────────────────────────────────────────────────┐
│ My Shortcuts                               Trigger: ⌥    │
│ Jump to your most-used apps with one keystroke.         │
│                                                         │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐                  │
│ │  Finder  │ │  Chrome  │ │  Figma   │                  │
│ │   icon   │ │   icon   │ │   icon   │                  │
│ │    1     │ │    2     │ │    3     │                  │
│ │ Running  │ │ Running  │ │ 3 windows│                  │
│ └──────────┘ └──────────┘ └──────────┘                  │
│                                                         │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐                  │
│ │ WeChat   │ │ VS Code  │ │ Terminal │                  │
│ │   icon   │ │   icon   │ │   icon   │                  │
│ │    4     │ │    5     │ │    6     │                  │
│ └──────────┘ └──────────┘ └──────────┘                  │
│                                                         │
│ [+ Add App]                                             │
└─────────────────────────────────────────────────────────┘
```

## 5.3 Slot Card 结构

每张卡包含：

1. App Icon：32～40pt；
2. App Name：单行，超长省略；
3. Shortcut Key：数字是最强视觉元素；
4. 状态：Running / N windows / Missing；
5. Hover 控件：`…`。

### 视觉层级

数字键不是辅助信息，而是卡片第一视觉识别点之一。

用户最终需要形成：

**3 = Figma**

而不只是记住图标位置。

## 5.4 Slot Card 状态

### Normal

App 已安装，未运行。

### Running

底部显示小状态点 + Running。

### Current

建议使用轻微描边 / 背景高亮，不做强烈品牌色。

### Multiple Windows

显示：`3 windows`。

### Missing

- Icon 降低透明度；
- 文案 `App not found`；
- 顶部警告标记；
- 操作：Locate / Remove。

### Empty Slot

```text
┌──────────┐
│    +     │
│          │
│    7     │
│ Add app  │
└──────────┘
```

## 5.5 拖拽交互

### Slot → Slot

拖动 Figma 3 到 VS Code 5：

- 目标卡浮起；
- 目标位置显示插入态；
- Drop 后两个 Slot 交换；
- 顶部显示轻量 Undo Toast：`Figma moved to ⌥5 · Undo`。

### Apps List → Slot

- 空 Slot：直接放入；
- 已占用：Replace；
- Drop 结束后立即生效。

## 5.6 Context Menu

右键 Slot：

```text
Open App
Show Windows
Change App…
Rename…
Remove Shortcut
────────
Open in Finder
```

不建议把 Window Behavior 放入每个 Slot 的 Context Menu，除非后续支持 per-app override。

---

# 6. Quick HUD

## 6.1 设计定位

Quick HUD 是“快捷键记忆提示层”。

它不承担复杂配置，不显示说明性大段文字。

## 6.2 触发状态机

```text
Idle
 ↓
Option Down
 ↓
Start 220ms timer
 ├─ Number pressed before timeout → Direct Jump, HUD never appears
 └─ Timeout → Show HUD
                 ↓
          Number / Esc / Modifier Up
```

这是产品最关键的交互。

## 6.3 HUD 位置

默认：主显示器视觉中心略上方。

建议：

- 宽度 520～680pt；
- 高度根据 Slot 数量自适应；
- 不超过两行主要 Slot；
- 多显示器时显示在当前鼠标所在或前台窗口所在显示器（策略需统一）。

## 6.4 HUD Layout

```text
┌──────────────────────────────────────────────────┐
│ Quick Switch                                     │
│                                                  │
│  1          2          3          4              │
│ [Finder]   [Chrome]   [Figma]    [WeChat]        │
│                                                  │
│  5          6          7          8              │
│ [VSCode]   [Terminal] [Notion]   [ChatGPT]       │
│                                                  │
│  9 Mail                          Space  Search    │
└──────────────────────────────────────────────────┘
```

建议不要复制设置页大卡片。HUD 中 Slot 更紧凑：

- 数字；
- Icon；
- App 名；
- 小状态。

## 6.5 动效

出现：80～120ms opacity + 极小 scale（例如 0.98 → 1）。

消失：60～80ms。

禁止：

- 大幅滑入；
- 弹跳；
- 卡片逐个动画；
- 延迟消失。

## 6.6 HUD Focus

HUD 本身尽量不成为 Key Window，避免抢走当前 App 的输入状态。

若技术实现需要 Key Window，必须在关闭时可靠恢复前台应用状态。

## 6.7 Running 与 Current

Running：小圆点。

Current：卡片背景轻高亮。

Multiple Windows：`3` 窗口徽标，不显示完整文案也可。

## 6.8 Empty Slots

HUD 默认可：

- 不展示空 Slot；或
- 展示数字 + `+`，帮助新用户建立 1～9 的映射。

建议 Onboarding 早期展示空 Slot；成熟后隐藏空 Slot。

---

# 7. Quick Search

## 7.1 目标

处理两类长尾目标：

- 未固定 App；
- 特定 Window。

不扩展成通用 Launcher。

## 7.2 Window 形态

建议使用悬浮 `NSPanel` 风格视觉：

- 宽度约 620pt；
- 默认高度 80pt；
- 有结果时扩展至 420～520pt；
- 顶部输入框 48～56pt；
- 内容列表按组显示。

## 7.3 初始态

```text
┌───────────────────────────────────────────────┐
│ 🔍 Jump to an app or window…                 │
├───────────────────────────────────────────────┤
│ Pinned                                        │
│  Figma                                  ⌥3   │
│  Chrome                                 ⌥2   │
│                                               │
│ Recent                                        │
│  VS Code — Data-Agent                        │
│  Finder — Downloads                          │
└───────────────────────────────────────────────┘
```

## 7.4 输入后

```text
> data

WINDOWS
VS Code        Data-Agent
Chrome         Data dashboard — Analytics

APPLICATIONS
DataGrip
```

每一行左侧显示 App Icon，窗口结果显示 App + Window Title 两级信息。

## 7.5 结果信息优先级

App Result：

- Icon
- App Name
- Pinned Shortcut（若有）
- Running 状态

Window Result：

- Icon
- Window Title（主）
- App Name（次）
- Minimized / Current 状态

## 7.6 Keyboard

- `↑↓`：选择；
- `Enter`：Jump；
- `Esc`：Close；
- `⌘1～9`：快速选结果，可作为 P1；
- 鼠标 Hover 同步选中，但不抢键盘焦点。

## 7.7 空结果

不要做“搜索 Web”。

显示：

```text
No apps or windows found for “xxxx”.
```

可提供：`Open Apps Settings`，不扩展搜索范围。

---

# 8. Window Picker

## 8.1 目标

当用户明确知道目标 App，但该 App 有多个窗口时，提供第二层快速定位。

## 8.2 触发

例如：`⌥⇧5`。

## 8.3 Layout

```text
┌───────────────────────────────────────────────┐
│ VS Code                              ⌥5       │
├───────────────────────────────────────────────┤
│ 1  AI-Perfume                         ●       │
│ 2  Data-Agent                                 │
│ 3  Digital-Xiaohe                     –       │
└───────────────────────────────────────────────┘
```

图例：

- `●` 当前窗口；
- `–` 最小化；
- 数字为临时选择键。

## 8.4 行为

Window Picker 打开后：

- 1～9：直接跳对应窗口；
- ↑↓ + Enter：选择；
- 再按同一 Slot Key：下一窗口；
- Esc：关闭。

## 8.5 超过 9 个窗口

显示滚动列表。

1～9 仅对应当前可见前 9 项；不建议做 0 / 两位数复杂快捷选择。

---

# 9. Menu Bar

## 9.1 状态栏 Icon

建议：单色 Template Image。

图标方向：

- Jump / Arrow / Switch 的抽象符号；
- 避免火箭、闪电等过度效率工具陈词。

## 9.2 菜单结构

```text
Open HUD                         ⌥ hold
Search Apps & Windows            ⌥Space
────────────
1 Finder
2 Chrome
3 Figma
4 WeChat
5 VS Code
────────────
Configure Shortcuts…
Preferences…
────────────
About Jump
Quit Jump
```

Menu Bar Item 可在设置中隐藏。

---

# 10. Apps 页面

## 10.1 目标

用于浏览、搜索并将已安装应用加入 Slot。

## 10.2 Layout

推荐列表形式而非 App Store 网格。

```text
Apps                                   Search…

Icon   Name                 Status      Shortcut
●      Arc                  Running     —
●      Chrome               Running     ⌥2
       Figma                Running     ⌥3
       Keynote              Installed   —
       Postman              Installed   —
```

## 10.3 行操作

Hover：

- `Assign Shortcut`
- `Open`

右键：

- Open
- Assign to Slot…
- Reveal in Finder
- Rename Display Name

---

# 11. Preferences

## 11.1 General

Mac 原生 Form 结构。

```text
Launch at Login         [On]
Show Menu Bar Icon      [On]
Show Dock Icon          [Off]
Language                [System ▾]
```

## 11.2 Shortcuts

```text
Trigger Modifier        [Option ▾]
Search                   [⌥ Space]
Window Picker Modifier   [Shift ▾]
HUD Hold Delay           [220 ms ─────]
```

修改 Trigger 时，右侧实时预览：

`⌥1 … ⌥9`

## 11.3 Windows

```text
When jumping to an app with multiple windows
[Recent Window ▾]

Press the same shortcut again
[Cycle Windows ▾]

Cycle timeout
[1000 ms ─────]

Minimized windows
[Restore ▾]
```

## 11.4 Appearance

```text
Theme       System / Light / Dark
HUD Size    Compact / Standard / Large
Position    Center / Top Center
Animation   Off / Fast / Normal
```

## 11.5 Permissions

采用状态卡：

```text
Accessibility
Required for switching individual app windows.
[Enabled ✓]

Launch at Login
Start Jump automatically after you sign in.
[Enabled ✓]
```

未授权：

- `Open System Settings`；
- 明确说明“不授权仍然可以使用 App 启动/切换，窗口级能力会受限”。

---

# 12. Onboarding

## 12.1 原则

首次引导不超过 5～7 个步骤，不一次性讲完全部功能。

核心只让用户学会一件事：

> **给 App 一个数字，然后随时按 Trigger + 数字。**

## 12.2 Step 1 — Welcome

主视觉：一个非常简单的快捷键到 App 动效。

文案：

**Your apps. One keystroke away.**

`Assign a shortcut once. Jump to that app from anywhere.`

CTA：Get Started

## 12.3 Step 2 — Trigger

展示键帽：

```text
⌥ + 1   ⌥ + 2   ⌥ + 3
```

默认推荐 Option。

## 12.4 Step 3 — Pick Apps

展示推荐 App，可基于运行列表或常见应用。

用户勾选 5～9 个。

支持 Drag reorder。

## 12.5 Step 4 — Your Shortcuts

即时生成 Slot Grid。

重点让用户确认：

`⌥3 → Figma`

## 12.6 Step 5 — Try It

真实交互任务：

`Press ⌥3 now.`

如果成功切到 Figma，再回到 Jump 后显示成功状态。

比播放教学视频更有效。

## 12.7 Step 6 — Window Access

说明：

- 仅 App Jump：不需要完整窗口权限；
- 想直接切换 Figma / VS Code 多个窗口：需要 Accessibility。

CTA：Enable Accessibility / Not Now

## 12.8 Step 7 — Done

显示 3 条提示即可：

- Hold Option to see shortcuts.
- Press Option + Space to search.
- Press the same shortcut again to cycle windows.

---

# 13. 权限交互

## 13.1 不要启动即弹系统权限

先解释价值，再请求。

错误方式：

App 第一次启动立刻系统弹窗。

正确方式：

1. 用户看到 Window Switching 能力；
2. Jump 解释为什么需要；
3. 用户点击 Enable；
4. 再触发系统权限流程。

## 13.2 Permission Lost

用户在系统设置中撤销后：

下一次窗口级操作时：

```text
Window switching is unavailable.
Jump can still activate apps. Re-enable Accessibility for window-level switching.
[Open Settings]
```

不应频繁弹模态框。

---

# 14. Toast / Feedback

Jump 的 Toast 必须少。

### 应显示

- Shortcut conflict
- App not found
- Permission required
- App launch failed
- Slot moved + Undo

### 不应显示

- 每次成功 Jump
- 每次 App 已运行
- 每次窗口循环

成功本身就是反馈。

Toast 建议 1.5～2.5 秒自动消失。

---

# 15. 快捷键冲突交互

当用户设置组合键时：

### 内部冲突

```text
⌥Space is already used by Quick Search.
Choose another shortcut.
```

阻止保存。

### 潜在系统冲突

```text
This shortcut may already be used by macOS or another app.
[Use Anyway] [Cancel]
```

不能假装可以可靠检测所有第三方快捷键。

---

# 16. 多显示器交互

### HUD / Search / Picker 出现在哪块屏幕？

推荐策略：

1. 前台 Key Window 所在屏幕；
2. 无 Key Window 时使用鼠标所在屏幕；
3. 再降级主屏。

三类浮层使用同一规则，避免随机感。

### Jump 到另一显示器窗口

直接进入该窗口所在显示器，不移动窗口。

---

# 17. Dark Mode

必须原生支持。

UI 色彩建议全部来自系统语义色：

- labelColor
- secondaryLabelColor
- separatorColor
- controlBackgroundColor
- windowBackgroundColor

尽量避免自定义固定 RGB。

App Icon 是界面中主要自然色彩来源。

---

# 18. 动画规范

| 场景 | 建议 |
|---|---|
| HUD appear | 80–120ms fade + 0.98→1 scale |
| HUD dismiss | 60–80ms fade |
| Search appear | 100–140ms |
| Picker appear | 100ms |
| Slot reorder | 120–180ms layout animation |
| Toast | 100ms in / 100ms out |

Respect Reduce Motion。

---

# 19. Accessibility 设计

设置主窗口应支持 VoiceOver。

Slot Card Accessibility Label 示例：

`Slot 3, Figma, running, three windows, shortcut Option 3.`

不要只依赖颜色表达：

- Running；
- Missing；
- Current。

Window Picker 每行必须可聚焦。

---

# 20. 空状态

### My Shortcuts 无 App

```text
Your shortcuts will appear here.
Add the apps you switch to most often.
[Add Your First App]
```

### Apps 未扫描到

优先显示重试和选择 `.app`，不要显示技术错误堆栈。

### Search 无结果

简单一句，没有“联网搜索”。

---

# 21. UI 状态矩阵

| 界面 | Idle | Loading | Empty | Error | Permission Limited |
|---|---|---|---|---|---|
| My Shortcuts | ✓ | 极少 | ✓ | ✓ | Banner |
| Apps | ✓ | ✓ | ✓ | ✓ | 无 |
| HUD | ✓ | 不应出现 | 隐藏空卡 | Missing card | 降级状态 |
| Search | ✓ | 本地无需明显 loading | ✓ | ✓ | Window 结果减少 |
| Window Picker | ✓ | 瞬时 | No windows | ✓ | Permission CTA |

---

# 22. 关键原型清单

设计阶段至少输出以下高保真页面/状态：

1. Onboarding — Welcome
2. Onboarding — Select Trigger
3. Onboarding — Choose Apps
4. Onboarding — Generated Slots
5. Onboarding — Accessibility
6. My Shortcuts — Default
7. My Shortcuts — Dragging
8. My Shortcuts — Missing App
9. Apps — List
10. Quick HUD — Normal
11. Quick HUD — Current App
12. Quick HUD — Multiple Windows
13. Quick Search — Initial
14. Quick Search — Search Results
15. Quick Search — No Result
16. Window Picker
17. Preferences — General
18. Preferences — Shortcuts
19. Preferences — Windows
20. Preferences — Permissions
21. Shortcut Conflict Alert
22. Permission Limited State
23. Menu Bar Menu

---

# 23. Figma Component 建议

### Foundations

- Typography
- Spacing
- Radius
- Material / Background
- System semantic colors

### Components

- AppIcon
- ShortcutKeycap
- SlotCard
- AppRow
- WindowRow
- StatusDot
- PermissionCard
- Toast
- SearchField
- SidebarItem
- SegmentedControl
- EmptyState

### Variants

SlotCard：

- state = normal / running / current / missing / empty
- size = settings / hud
- windows = single / multiple

AppRow：

- running true/false
- pinned true/false
- selected true/false

---

# 24. 核心交互验收

设计验收时必须实际走通：

### Flow A：熟练用户

当前 Chrome → `⌥3` → Figma

要求：无 UI。

### Flow B：忘记快捷键

Hold `⌥` → HUD → `3` → Figma

要求：一套动作连续完成。

### Flow C：多窗口

当前 Chrome → `⌥5` → VS Code Recent → `⌥5` → Next Window

要求：不打开 Picker 也能完成。

### Flow D：明确窗口

`⌥⇧5` → Window Picker → `2`

要求：两步内到达。

### Flow E：长尾 App

`⌥Space` → `post` → Enter

要求：不出现文件/网页等干扰结果。

---

# 25. 设计最终判断标准

每一个新增界面都需要问：

> **这个 UI 是否真的减少用户到达目标的操作？**

如果答案是否定的，就不应进入主流程。

Jump 最成熟的状态不是“界面越来越丰富”，而是：

> **用户知道目标后，几乎感觉不到 Jump 本身的存在。**
