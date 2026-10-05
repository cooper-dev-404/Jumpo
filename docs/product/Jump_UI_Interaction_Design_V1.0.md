# Jump — macOS UI / 交互设计方案

> 产品版本：V1.0；文档修订：R2（2026-10-04）  
> 对应 PRD：Jump macOS App & Window Switcher PRD V1.0 R2  
> 设计目标：直接支撑线框图、高保真原型、Design QA 与开发实现

---

## 0. 版本范围与统一约定

本文件与 PRD R2 配套。全局快速搜索按 2026-10-04 用户决定暂缓，使用 macOS 聚焦搜索；全文 Quick Search 的界面、快捷键、菜单项、HUD 提示和验收保留为未来参考，不在当前产品展示或开发。设置页用于绑定的应用筛选保留。Window Picker 及其快捷键、菜单项、偏好设置和验收均标记为 V1.1，不在 V1.0 中展示不可用入口。其他高级能力按 PRD 第 25 节安排。

本次明确：槽位固定 3 × 3 位置；空槽位不隐藏重排；长按提示 HUD 与菜单打开的可交互 HUD 分开处理；所有浮层使用第 16 节的显示器规则。英文是界面示例，正式界面根据语言设置显示，不混用中英文状态文案。

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
- Window Picker（V1.1）：打开即处于可选择状态。

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
├─ Window Picker（V1.1）
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

## 5. My Shortcuts 页面

### 5.1 页面目标

用户在 30 秒内完成：

- 看懂当前 Slot 映射；
- 调整顺序；
- 添加 App；
- 修改 Trigger；
- 发现冲突或 Missing 状态。

### 5.2 页面结构

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

设置页固定显示 1～9 的 3 × 3 网格，按行从左到右排列。上图仅示意已绑定内容，第三行和所有空槽位仍保留；窗口宽度变化不改变编号顺序。

### 5.3 Slot Card 结构

每张卡包含：

1. App Icon：32～40pt；
2. App Name：单行，超长省略；
3. Shortcut Key：数字是最强视觉元素；
4. 状态：Running / N windows / Missing；
5. Hover 控件：`…`。

#### 视觉层级

数字键不是辅助信息，而是卡片第一视觉识别点之一。

用户最终需要形成：

**3 = Figma**

而不只是记住图标位置。

### 5.4 Slot Card 状态

#### Normal

App 已安装，未运行。

#### Running

底部显示小状态点 + Running。

#### Current

建议使用轻微描边 / 背景高亮，不做强烈品牌色。

#### Multiple Windows

仅窗口数量已知时显示 `3 windows`。未授权、正在刷新或目标应用不支持枚举时不显示数字，不能把未知显示为 0。

#### Missing

- Icon 降低透明度；
- 文案 `App not found`；
- 顶部警告标记；
- 操作：Locate / Remove。

#### Empty Slot

```text
┌──────────┐
│    +     │
│          │
│    7     │
│ Add app  │
└──────────┘
```

### 5.5 拖拽交互

#### Slot → Slot

拖动 Figma 3 到 VS Code 5：

- 目标卡浮起；
- 目标位置显示交换提示，不能表现为列表插入；
- Drop 后两个 Slot 交换；
- 顶部显示轻量 Undo Toast：`Figma moved to ⌥5 · Undo`。

#### Apps List → Slot

- 空 Slot：直接放入；
- 已占用：显示 Replace / Cancel，确认后生效，提供 Undo；
- 同一 App 已在其他槽位：提示移动/交换，避免重复绑定；
- 通过菜单“移动到槽位…”提供完整键盘替代，不要求用户必须拖拽。

### 5.6 Context Menu

右键 Slot：

```text
Open App
Show Windows（V1.1）
Change App…
Rename…
Remove Shortcut
Move to Slot…
────────
Open in Finder
```

不建议把 Window Behavior 放入每个 Slot 的 Context Menu，除非后续支持 per-app override。

---

## 6. Quick HUD

### 6.1 设计定位

Quick HUD 是“快捷键记忆提示层”。

它不承担复杂配置，不显示说明性大段文字。

### 6.2 触发状态机

```text
Idle
 ↓ 完整 Trigger Modifier 按下，且监听可用
等待 220ms
 ├─ 已注册 Slot → 取消计时 → 执行
 ├─ 普通字符 / 额外修饰键 / 鼠标操作 / Esc → 本次取消，原输入正常传递
 ├─ Modifier 松开 → Idle
 └─ 到期 → 显示提示 HUD
              ├─ 有效 Slot → 隐藏 → Jump
              └─ Esc / 普通输入 / 外部点击 / 松开 → 隐藏
```

取消或执行后，在本次修饰键持续按住期间不再自动显示 HUD；松开后才重新计时。再次主动按数字仍可循环窗口，自动键盘重复忽略。输入监听失效、锁屏、睡眠或权限撤销时清除所有待触发状态。

Option 同时承担字符输入和编辑命令。HUD 不截取未注册组合；空/禁用槽位不占用全局快捷键。设置中提供长按 HUD 开关；无法可靠观察完整输入状态时关闭此入口，用菜单 HUD 替代。

### 6.3 HUD 位置

按第 16 节选定显示器，默认位于该屏幕可用区域中心略上方，不固定使用主屏。

建议宽度 520～680pt，九个位置保持 3 × 3；随可用空间缩小间距或图标尺寸，不能隐藏中间槽位或改变数字位置。使用可用屏幕区域约束边界，避免越过菜单栏或 Dock。

### 6.4 HUD Layout

```text
┌───────────────────────────────────────┐
│ Quick Switch                          │
│ 1 Finder     2 Chrome     3 Figma      │
│ 4 WeChat     5 VS Code    6 Terminal   │
│ 7 Notion     8 ChatGPT    9 Add app    │
│                    松开 ⌥ 关闭提示    │
└───────────────────────────────────────┘
```

每个位置显示数字、Icon、App 名和必要状态。实际渲染图标，不使用设置页大卡片。长按模式提示松开当前配置的修饰键关闭；菜单模式提示数字选择和 Esc 关闭。当前 HUD 不展示搜索入口。

### 6.5 动效

出现：80～120ms opacity + 极小 scale（例如 0.98 → 1）。

消失：60～80ms。

禁止：

- 大幅滑入；
- 弹跳；
- 卡片逐个动画；
- 延迟消失。

### 6.6 HUD Focus

- **长按提示模式**：不激活 Jump，不成为 Key Window；已注册组合键执行跳转，Esc 只负责关闭提示，不承诺拦截前台应用收到的 Esc。
- **菜单打开模式**：菜单关闭后打开可交互面板，获得数字选择所需焦点；不要求按住 Modifier，支持数字、点击、Esc 和外部点击，供权限不足或不使用长按的用户使用。
- Search / Picker 需要输入焦点；同一时刻最多显示一种浮层。Esc 取消时，仅当焦点仍由 Jump 持有才尝试恢复打开前 App；外部点击、用户切换 App 或成功 Jump 后不再执行旧焦点恢复。
- 浮层内的 Current 状态使用打开前的目标应用/窗口快照，不把 Jump 自身标成用户当前目标。

### 6.7 Running 与 Current

Running：小圆点。

Current：卡片背景轻高亮。

Multiple Windows：`3` 窗口徽标，不显示完整文案也可。

### 6.8 Empty Slots

始终保留 1～9 的位置。空槽位显示淡化数字和 `Add app`，不随使用时长自动隐藏。在长按提示模式中空槽位不触发全局动作；菜单模式下选择空槽位可打开对应配置位置。禁用槽位标记 Disabled，点击可进入配置。

---

## 7. Quick Search（暂缓，非当前版本范围）

### 7.1 目标

处理两类长尾目标：

- 未固定 App；
- 特定 Window。

不扩展成通用 Launcher。

### 7.2 Window 形态

建议使用悬浮 `NSPanel` 风格视觉：

- 宽度约 620pt；
- 默认高度 80pt；
- 有结果时扩展至 420～520pt；
- 顶部输入框 48～56pt；
- 内容列表按 PRD 第 14.3 节统一排序，用副标题区分应用与窗口。

### 7.3 初始态

```text
┌───────────────────────────────────────────────┐
│ 🔍 Jump to an app or window…                 │
├───────────────────────────────────────────────┤
│ Pinned apps / recent targets                  │
│  Chrome                                 ⌥2    │
│  Figma                                  ⌥3    │
│                                               │
│                                               │
│  VS Code — Data-Agent                        │
│  Finder — Downloads                          │
└───────────────────────────────────────────────┘
```

### 7.4 输入后

```text
> data

DataGrip       Application
VS Code        Data-Agent · Window
Chrome         Data dashboard — Analytics · Window
```

每一行左侧显示 App Icon，窗口结果显示 App + Window Title 两级信息。上例为同一匹配层的示意，实际顺序按 PRD 的匹配规则稳定排序。缓存应用结果先出现，窗口结果可异步补充；窗口结果刷新不改变用户已选目标身份。

### 7.5 结果信息优先级

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

### 7.6 Keyboard

- `↑↓`：选择；
- `Enter`：Jump；
- `Esc`：Close；
- `⌘1～9`：快速选结果，可作为 P1；
- 鼠标主动移动到行上时选中，不抢输入框焦点；列表重排不能使静止鼠标覆盖键盘选择；
- 中文输入法组合输入时，Enter 优先确认候选，不直接执行 Jump；非组合输入状态才触发结果；
- 未授权时提示“可搜索应用；开启窗口访问后可搜索窗口”，不展示失效窗口标题；
- Keep Minimized 模式下选择最小化窗口，提供“恢复并打开”操作；取消则保留原状态。

### 7.7 空结果

不要做“搜索 Web”。

显示：

```text
No apps or windows found for “xxxx”.
```

可提供：`Open Apps Settings`，不扩展搜索范围。

---

## 8. Window Picker（V1.1）

### 8.1 目标

当用户明确知道目标 App，但该 App 有多个窗口时，提供第二层快速定位。

### 8.2 触发

例如：`⌥⇧5`。

### 8.3 Layout

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

### 8.4 行为

Window Picker 打开后：

- 等触发组合键全部释放后，1～9 裸数字直接跳对应窗口；
- ↑↓ + Enter：选择；
- 数字固定表示行号，不同时承担“再按 Slot Key 循环”；
- Esc：关闭；
- 打开时冻结编号；窗口关闭后标记不可用，避免其他窗口悄悄顶替该编号。

### 8.5 超过 9 个窗口

显示滚动列表。

1～9 对应本次打开时列表的前 9 项，滚动不改编号；其余窗口用方向键或鼠标选择。

---

## 9. Menu Bar

### 9.1 状态栏 Icon

建议：单色 Template Image。

图标方向：

- Jump / Arrow / Switch 的抽象符号；
- 避免火箭、闪电等过度效率工具陈词。

### 9.2 菜单结构

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
Pause Shortcuts / Resume Shortcuts
Quit Jump
```

Menu Bar Item 可在设置中隐藏。暂停时显示明确状态并注销快捷键/停止长按监听；恢复若失败，应显示具体失败项。关闭设置窗口保持后台运行；Quit 才退出。隐藏菜单和 Dock 图标后，重新打开 `.app` 必须显示设置，避免用户失去入口。

---

## 10. Apps 页面

### 10.1 目标

用于浏览、搜索并将已安装应用加入 Slot。

### 10.2 Layout

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

### 10.3 行操作

Hover：

- `Assign Shortcut`
- `Open`

右键：

- Open
- Assign to Slot…
- Reveal in Finder
- Rename Display Name

---

## 11. Preferences

### 11.1 General

Mac 原生 Form 结构。

```text
Launch at Login         [Off]
Show Menu Bar Icon      [On]
Show Dock Icon          [Off]
Language                [System ▾]
```

### 11.2 Shortcuts

```text
Trigger Modifier        [Option ▾]
Search                   [⌥ Space]
Hold to Show HUD         [On / Unavailable]
Window Picker Modifier   [Shift ▾]  (V1.1)
HUD Hold Delay           [220 ms ─────]
```

修改 Trigger 时，右侧实时预览：

`⌥1 … ⌥9`

统一校验所有启用槽位与 Search；注册失败时不保存新值，并恢复旧快捷键。未测试组合提示输入影响；提供试按和恢复默认值。组合修饰键不支持长按时明确说明，并保留菜单 HUD。

### 11.3 Windows

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

### 11.4 Appearance

```text
Theme       System / Light / Dark
HUD Size    Compact / Standard / Large
Position    Center / Top Center
Animation   Off / Fast / Normal
```

### 11.5 Permissions

采用状态卡：

```text
Accessibility
Used to read and switch app windows; hold-to-show shortcuts may also require access.
[Enabled ✓]

Launch at Login
Start Jump automatically after you sign in.
[Enabled ✓]
```

状态必须来自系统检测：未授权、已授权、不可用、需要用户批准；不能在点击按钮后直接显示 Enabled。长按监听是否可用单独展示；仅在所选实现需要时显示 Input Monitoring，不为文字窗口列表请求屏幕录制。

未授权：

- `Open System Settings`；
- 明确说明“不授权仍然可以使用 App 启动/切换，窗口级能力会受限”。

---

## 12. Onboarding

### 12.1 原则

首次引导不超过 5～7 个步骤，不一次性讲完全部功能。

核心只让用户学会一件事：

> **给 App 一个数字，然后随时按 Trigger + 数字。**

### 12.2 Step 1 — Welcome

主视觉：一个非常简单的快捷键到 App 动效。

文案：

**Your apps. One keystroke away.**

`Assign a shortcut once. Jump to that app from anywhere.`

CTA：Get Started

### 12.3 Step 2 — Trigger

展示键帽：

```text
⌥ + 1   ⌥ + 2   ⌥ + 3
```

默认推荐 Option，并说明会占用所选数字组合原本的输入；提供试按与更换入口。

### 12.4 Step 3 — Pick Apps

展示推荐 App，可基于运行列表或常见应用。

至少选择 1 个即可继续，最多 9 个；推荐先选 3～5 个，其他槽位以后添加。不得将候选列表标为已识别的“最常用 App”。

支持 Drag reorder，以及键盘“移动到槽位…”操作。

### 12.5 Step 4 — Your Shortcuts

即时生成 Slot Grid。

重点让用户确认：

`⌥3 → Figma`

### 12.6 Step 5 — Try It

真实交互任务：

`Press ⌥3 now.`

只有确认目标应用已前台才记为成功；尝试指定窗口时还需确认窗口焦点。引导不自动抢回焦点，用户主动返回后显示结果。无论是否尝试，都可从菜单“Configure Shortcuts…”继续配置。

比播放教学视频更有效。

### 12.7 Step 6 — Window Access

说明：

- 仅 App Jump：不需要完整窗口权限；
- 想直接切换 Figma / VS Code 多个窗口：需要 Accessibility，且受目标应用支持情况限制；
- 长按提示所需权限按最终实现单独解释，不能宣称窗口权限是唯一授权原因。

CTA：Enable Accessibility / Not Now

### 12.8 Step 7 — Done

根据实际配置和权限最多显示 3 条提示：

- 监听可用时：Hold Option to see shortcuts；否则提示从菜单 Open HUD 查看。
- 显示用户实际配置的 Search Shortcut。
- 窗口权限可用时提示重复按键循环；否则提示应用快捷键已可使用，并保留稍后授权入口。

---

## 13. 权限交互

### 13.1 不要启动即弹系统权限

先解释价值，再请求。

错误方式：

App 第一次启动立刻系统弹窗。

正确方式：

1. 用户看到 Window Switching 能力；
2. Jump 解释为什么需要；
3. 用户点击 Enable；
4. 再触发系统权限流程。

### 13.2 Permission Lost

用户在系统设置中撤销后：

立即取消窗口相关任务，清除标题与结果，关闭不可用提示 HUD；保留应用快捷键、菜单与应用搜索。下一次窗口级操作时：

```text
Window switching is unavailable.
Jump can still activate apps. Re-enable Accessibility for window-level switching.
[Open Settings]
```

不应频繁弹模态框。

---

## 14. Toast / Feedback

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

普通状态 Toast 建议 1.5～2.5 秒自动消失。带 Undo / Retry / Open Settings 的反馈应停留至少 5 秒，悬停或键盘聚焦时暂停消失，并在设置中保留对应操作；不能让错误处理依赖一次短暂提示。

---

## 15. 快捷键冲突交互

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
[Try Shortcut] [Cancel]
```

不能假装可以可靠检测所有第三方快捷键。实际注册失败时显示“无法启用此快捷键，请更换”，禁止将失败状态保存为已启用。提示 Option 字符输入、Control / Command 应用快捷键可能受影响。

---

## 16. 多显示器交互

### HUD / Search / Picker 出现在哪块屏幕？

推荐策略：

1. 触发前记录外部前台窗口；授权可用且能读取其 bounds 时，取与该窗口相交面积最大的显示器；
2. 不能取得窗口位置时使用鼠标所在屏幕；
3. 再降级到主屏。

`NSApp.keyWindow` 仅表示 Jump 自身窗口，不能用于读取其他应用的前台窗口。显示位置在每次打开前选定；显示器断开时重新计算，不移动用户目标窗口。

三类浮层使用同一规则，避免随机感。

### Jump 到另一显示器窗口

直接进入该窗口所在显示器，不移动窗口。

---

## 17. Dark Mode

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

## 18. 动画规范

| 场景 | 建议 |
|---|---|
| HUD appear | 80–120ms fade + 0.98→1 scale |
| HUD dismiss | 60–80ms fade |
| Search appear | 100–140ms |
| Picker appear（V1.1） | 100ms |
| Slot reorder | 120–180ms layout animation |
| Toast | 100ms in / 100ms out |

Respect Reduce Motion。

---

## 19. Accessibility 设计

设置主窗口应支持 VoiceOver。

Slot Card Accessibility Label 示例：

`Slot 3, Figma, running, three windows, shortcut Option 3.`

不要只依赖颜色表达：

- Running；
- Missing；
- Current。

Window Picker（V1.1）每行必须可聚焦。My Shortcuts 的添加、替换、移动、删除都提供键盘操作；菜单打开的可交互 HUD 应支持 VoiceOver。长按提示 HUD 不抢 VoiceOver 焦点，不将其作为唯一无障碍入口。

---

## 20. 空状态

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

## 21. UI 状态矩阵

| 界面 | Idle | Loading | Empty | Error | Permission Limited |
|---|---|---|---|---|---|
| My Shortcuts | ✓ | 极少 | ✓ | ✓ | Banner |
| Apps | ✓ | ✓ | ✓ | ✓ | 无 |
| HUD | ✓ | 使用缓存，不等待 AX | 保留空槽位 | Missing card | 菜单 HUD 可用，长按按能力降级 |
| Search | ✓ | 先显示应用，窗口异步补充 | ✓ | ✓ | 仅应用结果及授权说明 |
| Window Picker（V1.1） | ✓ | 瞬时 | No windows | ✓ | Permission CTA |

---

## 22. 关键原型清单

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
16. Window Picker（V1.1，不计入首版）
17. Preferences — General
18. Preferences — Shortcuts
19. Preferences — Windows
20. Preferences — Permissions
21. Shortcut Conflict Alert
22. Permission Limited State
23. Menu Bar Menu

---

## 23. Figma Component 建议

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

## 24. 核心交互验收

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

### Flow D：明确窗口（V1.1）

`⌥⇧5` → Window Picker → `2`

要求：两步内到达。

### Flow E：长尾 App

`⌥Space` → `post` → Enter

要求：不出现文件/网页等干扰结果；中文输入法确认候选时不能误跳转。

### Flow F：不会干扰原操作

Option + 方向键 / 普通字符 / 鼠标拖拽 → 原 App 正常处理，HUD 取消；快捷键暂停后恢复原输入。验证空槽位与禁用槽位不占用按键。

### Flow G：权限与恢复

未授权 → 配置 1 个 App → 快捷键激活 → 菜单 HUD 查看映射；撤销权限后窗口结果清除。菜单与 Dock 图标隐藏 → 再次打开 App → 进入设置。

### Flow H：稳定窗口循环

三个窗口 A / B / C → 连续按同一快捷键 → A、B、C、A；超过 1000ms 且目标仍在前台 → 从当前窗口的下一项继续新的循环会话。窗口集合不变时，慢速触发也应遍历全部窗口，例如当前 B 的下一项仍为 C。

---

## 25. 设计最终判断标准

每一个新增界面都需要问：

> **这个 UI 是否真的减少用户到达目标的操作？**

如果答案是否定的，就不应进入主流程。

Jump 最成熟的状态不是“界面越来越丰富”，而是：

> **用户知道目标后，几乎感觉不到 Jump 本身的存在。**
