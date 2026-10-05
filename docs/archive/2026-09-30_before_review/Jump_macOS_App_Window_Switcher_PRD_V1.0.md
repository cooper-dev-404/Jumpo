# Jump — macOS App & Window Switcher 产品需求文档（PRD）

> 版本：V1.0  
> 文档状态：产品立项 / 原型设计 / 技术评审基线  
> 平台：macOS  
> 产品形态：Menu Bar App + 全局快捷键服务 + HUD + Quick Search + 设置中心  
> 产品代号：Jump（暂定）

---

## 1. 产品概述

### 1.1 一句话定义

**Jump 是一款面向中重度 Mac 用户的 Keyboard-first App & Window Switcher，通过固定快捷键建立肌肉记忆，将“启动应用、切换应用、切换应用窗口”统一为一次 Jump 操作。**

用户无需再通过 Dock、Launchpad、访达、Spotlight 或 `⌘Tab` 寻找目标应用，而是通过稳定映射直接到达目标工作界面。

### 1.2 核心理念

产品不解决“如何搜索更多东西”，而解决：

> **当用户已经知道自己要去哪时，如何不经过寻找过程直接到达目标。**

核心公式：

**One App = One Shortcut = One Destination**

产品演进方向：

**App → Window → Destination**

最终体验目标：

> **Don't Find. Just Jump.**

---

## 2. 背景与问题

### 2.1 用户现状

Mac 用户随着使用时间增长，通常会安装并长期使用大量应用。典型知识工作场景中，用户每天可能同时运行 10～30 个应用，例如：

- Finder
- Chrome / Safari / Arc
- Figma
- VS Code / Xcode
- Terminal
- WeChat / Slack / Teams
- Notion
- ChatGPT
- Mail
- Excel / PowerPoint
- Preview
- Photoshop
- Postman
- TablePlus

macOS 已经提供了 Dock、Launchpad、Spotlight、Mission Control、`⌘Tab`、`⌘`` 等能力，但这些方式都需要用户进行不同程度的“寻找、浏览、判断或确认”。

### 2.2 核心痛点

#### 痛点 A：打开未运行 App 仍然需要寻找

用户已经知道要打开 Figma，却仍然需要：

- 看 Dock 找图标；
- 打开 Spotlight 输入 Figma；
- 打开 Launchpad 浏览；
- 从 Finder Applications 中查找。

问题并不是“不知道 Figma 是什么”，而是系统仍然要求用户进行一次导航。

#### 痛点 B：已运行 App 越多，`⌘Tab` 越低效

当后台运行十几个应用时，`⌘Tab` 的实际过程是：

1. 唤起应用切换器；
2. 视觉扫描；
3. 连续按 Tab；
4. 判断是否已到目标；
5. 松开完成切换。

它是一种动态顺序选择，而不是固定映射。

#### 痛点 C：切到 App 后还没有真正到达目标

同一 App 可能有多个窗口：

- Chrome：工作账号 / 个人账号 / Debug；
- VS Code：项目 A / 项目 B / 项目 C；
- Finder：多个目录窗口；
- Figma：多个设计文件；
- Xcode：多个工程。

用户先切到 App，再找窗口，形成二次导航。

#### 痛点 D：搜索型 Launcher 不适合最高频确定性动作

Spotlight、Raycast、Alfred 很适合“长尾命令和模糊目标”，但对于每天几十次执行的确定目标，仍然存在：

**唤起 → 输入 → 搜索 → 选择 → 回车**

Jump 的目标是压缩为：

**快捷键 → 到达**

---

## 3. 产品目标与非目标

### 3.1 产品目标

1. 用固定快捷键替代高频 App 查找与切换。
2. 同一个快捷键统一处理 Launch / Activate / Restore / Window Switch。
3. 让高频用户逐步形成长期稳定的肌肉记忆。
4. 将 App 与 Window 纳入统一 Destination 模型。
5. 高频操作默认无 UI，辅助 UI 仅在需要时出现。
6. 保持常驻工具低资源占用、低延迟、低打扰。
7. 首版聚焦 macOS 原生体验，不做跨平台泛化。

### 3.2 非目标

V1/V1.1 明确不做：

- 文件搜索；
- 剪贴板管理；
- 计算器；
- AI Chat；
- Shell Command；
- Browser Search；
- 插件市场；
- Workflow 自动化；
- MCP；
- 通用 Command Palette；
- Everything Launcher。

产品边界必须保持为：

> **App / Window 的即时跳转。**

---

## 4. 产品设计原则

### 4.1 固定映射优先于动态智能

数字槽位一旦配置，不随以下因素变化：

- App 最近使用顺序；
- App 当前是否运行；
- 当前上下文；
- AI 推荐；
- 用户当天使用频次。

原因：肌肉记忆依赖稳定映射。

### 4.2 启动和切换统一

用户不需要判断 App 当前状态。

例如 `⌥3 = Figma`，则：

- Figma 未运行 → 启动；
- 已运行 → 激活；
- 窗口最小化 → 恢复；
- 多窗口 → 最近窗口；
- 当前已经在 Figma → 可进入窗口循环。

### 4.3 高频行为不依赖 UI

熟练用户按 `⌥3` 后直接到达 Figma。

禁止默认流程：

`⌥3 → 面板 → 选择 → Enter`

### 4.4 UI 是学习层与长尾层

HUD、Quick Search、Window Picker 的定位是：

- 帮助新用户记忆；
- 处理多窗口；
- 处理未绑定 App；
- 处理低频目标。

随着用户熟练度提高，UI 出现频率应下降。

### 4.5 Destination 高于 App

系统最终跳转单位不是“应用图标”，而是“用户想进入的工作界面”。

因此数据模型从 App 扩展到：

**App + Window + 状态 + 最近使用上下文**

### 4.6 尊重 macOS 原生窗口管理

Jump 不主动接管：

- 窗口布局；
- Stage Manager 分组；
- Space 编排；
- 多显示器窗口位置。

Jump 只负责“到达”，而非“重新组织桌面”。

---

## 5. 目标用户

### 5.1 核心用户画像

#### A. 产品 / 设计人员

高频 App：Figma、Chrome、Notion、ChatGPT、WeChat、Finder、Preview。

特点：频繁跨应用查资料、沟通、设计、写文档。

#### B. 开发者

高频 App：VS Code、Xcode、Terminal、Chrome、Postman、TablePlus、Finder。

特点：多窗口、多项目、多显示器切换明显。

#### C. 重度办公用户

高频 App：Chrome、WeChat、Teams、Mail、Excel、PowerPoint、Finder。

特点：每天切换次数高，但不一定是效率工具发烧友。

#### D. Mac Power User

可能已有 Raycast、Alfred、BetterTouchTool、Keyboard Maestro、Manico、Karabiner 使用经验。

特点：愿意学习快捷键，并能感知毫秒级响应与交互摩擦。

---

## 6. 核心用户场景

### 6.1 快速启动未运行应用

前置：Figma 未运行；Figma 绑定 `⌥3`。

操作：用户按 `⌥3`。

结果：

1. 系统解析 Slot 3；
2. 检测 Figma 未运行；
3. 启动 Figma；
4. 应用完成启动后前置；
5. 不显示中间选择 UI。

### 6.2 快速切换已运行应用

前置：Figma 已运行，Chrome 当前前台。

操作：`⌥3`。

结果：Figma 最近使用窗口直接前置。

### 6.3 恢复最小化窗口

前置：WeChat 已运行，主窗口最小化。

操作：`⌥4`。

结果：激活 WeChat 并恢复最近最小化窗口。

### 6.4 当前已经位于目标 App

前置：当前 App 为 VS Code，VS Code 存在多个窗口。

操作：再次按 `⌥5`。

结果：切换到下一个 VS Code 窗口。

若只有一个窗口：默认不进行可见跳转，可给极轻量状态反馈或无反馈。

### 6.5 连续按相同快捷键循环窗口

默认 Cycle Timeout：1000ms。

行为：

- 第一次 `⌥5` → 最近 VS Code 窗口；
- 1000ms 内再次 `⌥5` → 下一个窗口；
- 再次 `⌥5` → 继续循环；
- 超过 1000ms → 下次重新从最近窗口逻辑开始。

### 6.6 主动打开 Window Picker

快捷键：`⌥⇧5`。

展示该 App 当前可用窗口列表：

1. AI-Perfume
2. Data-Agent
3. Digital-Xiaohe

按数字或方向键选择，Enter 跳转。

### 6.7 忘记快捷键

用户按住 Option 超过 HUD Delay（默认 220ms）。

HUD 出现，展示已固定 Slot。

用户继续按 3：

- HUD 立即消失；
- 跳到 Figma。

### 6.8 搜索未固定应用

用户按 `⌥Space` → 输入 `post` → 选择 Postman → Enter。

如果 Postman 未运行则启动；已运行则激活。

### 6.9 搜索窗口

用户按 `⌥Space` → 输入 `data`。

结果可能包含：

- App：DataGrip
- Window：VS Code — Data-Agent
- Window：Chrome — Data Dashboard

窗口结果可直接到达对应窗口，无需先进入 App。

---

## 7. 产品总体架构

```text
Global Shortcut / Search / HUD Trigger
                 ↓
             Input Router
                 ↓
              Jump Engine
                 ↓
     ┌───────────┼────────────┐
     ↓           ↓            ↓
 App Resolver  Window Index  State Resolver
     ↓           ↓            ↓
     └───────────┼────────────┘
                 ↓
        Destination Decision
                 ↓
 Launch / Activate / Restore / Focus / Cycle
                 ↓
     HUD / Toast / Error Feedback
```

---

## 8. 信息架构

V1 设置中心建议保持克制：

```text
My Shortcuts
Apps
Preferences
  ├─ General
  ├─ Shortcuts
  ├─ Windows
  ├─ Appearance
  └─ Permissions
About
```

Menu Bar：

```text
Jump
├─ Open HUD
├─ Search Apps & Windows
├─ Pinned Apps
├─ Configure Shortcuts
├─ Preferences
├─ About
└─ Quit
```

V1.1 后增加 Profiles。

---

## 9. 核心数据对象

### 9.1 App

| 字段 | 类型 | 说明 |
|---|---|---|
| app_id | UUID | 内部唯一 ID |
| bundle_id | String | macOS Bundle Identifier |
| name | String | 原始 App 名称 |
| alias | String? | 用户别名 |
| app_url | URL | App 路径 |
| icon_ref | Data/Cache | 图标引用 |
| installed | Bool | 当前是否可解析 |
| running | Bool | 当前是否运行 |
| last_used_at | Date? | 最近 Jump 时间 |
| jump_count | Int | Jump 次数 |

### 9.2 Slot

| 字段 | 类型 | 说明 |
|---|---|---|
| slot_id | UUID | 唯一 ID |
| slot_index | Int | 1～9 或扩展槽位 |
| modifier | Enum | Option / Control / Command / Combo |
| key_code | UInt16 | 物理键位 |
| app_id | UUID | 绑定 App |
| enabled | Bool | 是否启用 |
| created_at | Date | 创建时间 |
| updated_at | Date | 更新时间 |

### 9.3 Runtime Window

| 字段 | 类型 | 说明 |
|---|---|---|
| window_runtime_id | String | 运行时标识 |
| app_id | UUID | 所属应用 |
| pid | Int32 | 进程 ID |
| window_title | String? | 窗口标题 |
| window_index | Int | 应用内排序 |
| minimized | Bool | 是否最小化 |
| fullscreen | Bool? | 是否全屏 |
| visible | Bool | 是否可见 |
| last_active_at | Date? | 最近激活时间 |
| display_hint | String? | 显示器信息（如可获取） |

> Window 数据主要作为运行时索引，不要求全部长期持久化。

### 9.4 Preferences

包含：

- launchAtLogin
- showMenuBarIcon
- showDockIcon
- triggerModifier
- hudDelay
- searchShortcut
- windowPickerModifier
- repeatedShortcutBehavior
- cycleTimeout
- minimizedWindowBehavior
- theme
- hudSize
- hudPosition
- animationsEnabled

---

## 10. 功能需求：Quick Slots

### 10.1 默认槽位

建议 V1 默认支持数字 1～9。

示例：

| Shortcut | App |
|---|---|
| ⌥1 | Finder |
| ⌥2 | Chrome |
| ⌥3 | Figma |
| ⌥4 | WeChat |
| ⌥5 | VS Code |
| ⌥6 | Terminal |
| ⌥7 | Notion |
| ⌥8 | ChatGPT |
| ⌥9 | Mail |

### 10.2 Slot 配置

支持：

- 从 App 列表添加；
- 搜索 App；
- 拖拽 App 到 Slot；
- 从 Finder 拖入 `.app`；
- 删除绑定；
- 交换 Slot；
- 修改快捷键修饰键；
- 设置 App Alias。

### 10.3 拖拽规则

从 Slot A 拖到已占用 Slot B：

默认行为：**Swap**。

从 Apps 列表拖到已占用 Slot：

默认行为：显示 Replace / Cancel；V1 可直接 Replace 并支持 Undo。

### 10.4 快捷键冲突

冲突类型：

1. 与 Jump 内部 Shortcut 冲突；
2. 与 Search Shortcut 冲突；
3. 与 Window Picker 组合冲突；
4. 与系统保留组合明显冲突；
5. 与其他第三方 App 冲突（只能检测部分情况）。

规则：

- Jump 内部确定性冲突：禁止保存；
- 系统/第三方潜在冲突：警告但允许用户覆盖；
- UI 必须明确显示“可能被其他应用占用”。

---

## 11. Jump Engine 决策规则

```text
Trigger Slot
   ↓
Resolve App
   ↓
Installed?
 ┌─┴──────────────┐
No                Yes
↓                  ↓
Missing Feedback  Running?
               ┌──┴───────────┐
              No              Yes
              ↓                ↓
            Launch      Build Window State
                               ↓
                         Windows Count
                     ┌──────┬───────┐
                     0      1      >1
                     ↓      ↓       ↓
                 Activate  Focus   Recent Window
```

### 11.1 App 未运行

执行 Launch。

若启动过程超过阈值，不锁死主线程，不阻塞键盘监听。

### 11.2 App 已运行但无标准窗口

例如 Menu Bar 工具：

只执行 Activate，不强制构造窗口。

### 11.3 单窗口

优先：

1. Restore（若最小化）；
2. Raise / Focus；
3. Activate App。

### 11.4 多窗口

首跳：最近窗口。

重复快捷键：Cycle。

### 11.5 当前 App 为目标 App

- 多窗口：Cycle；
- 单窗口：No-op；
- 用户可在设置中改为“跳回上一个 App”（V1.1 候选，不建议默认）。

---

## 12. Window Jump

### 12.1 Window Index 构建

目标：为运行中的应用建立可快速查询的窗口索引。

至少保存：

- App；
- PID；
- 标题；
- 是否最小化；
- 最近激活顺序。

### 12.2 最近窗口排序

优先级：

1. Jump 自身记录的最近激活窗口；
2. Accessibility 可解析的 focused/main window；
3. 当前可见窗口；
4. 其他窗口。

### 12.3 Window Title 清洗

示例：

`AI-Perfume — Visual Studio Code`

显示为：

`AI-Perfume`

但底层保留原始标题。

针对 App 适配可维护轻量 Formatter，不应使用脆弱硬编码作为核心逻辑。

### 12.4 Finder 特殊逻辑

Finder 视为长期运行。

- 有窗口 → 最近 Finder 窗口；
- 无窗口 → 新开 Finder Window；
- 多 Finder 窗口 → 支持循环。

### 12.5 浏览器

Chrome / Edge / Safari / Arc 多窗口优先作为 V1 验证对象。

标签页不属于 V1 Window Jump 范围。

---

## 13. Quick HUD

### 13.1 定位

快捷键记忆辅助层，而非主要操作界面。

### 13.2 触发

默认：Option 按住 220ms。

如果在 220ms 内按下 Slot Key，直接执行 Jump，HUD 不出现。

### 13.3 HUD 内容

每个 Slot 展示：

- App Icon；
- App Name / Alias；
- Key；
- Running 状态；
- Window Count（有多个时）；
- Missing 状态。

### 13.4 HUD 状态

- Normal
- Running
- Current
- Multiple Windows
- Missing
- Disabled

### 13.5 关闭

- Modifier 松开；
- 完成 Jump；
- ESC；
- 点击外部；
- 打开 Search / Picker。

---

## 14. Quick Search

### 14.1 定位

只搜索：

1. Applications
2. Running Windows

### 14.2 唤起

默认 `⌥Space`。

### 14.3 搜索排序

推荐综合分：

1. Exact Match
2. Prefix Match
3. Pinned App
4. Running App
5. Recent Destination
6. Usage Frequency
7. Fuzzy Score

### 14.4 键盘行为

- ↑ / ↓：选择；
- Enter：Jump；
- ESC：关闭；
- `⌘1…9`：快速选择前 9 个结果（可选）；
- Tab：App / Window 分组跳转（V1.1）。

### 14.5 空搜索

未输入关键词时默认展示：

- Pinned Apps；
- Recent Destinations；
- Running Apps。

---

## 15. Window Picker

### 15.1 唤起

默认：`Trigger Modifier + Shift + Slot Key`。

### 15.2 内容

- App Header；
- 当前窗口列表；
- 最小化状态；
- 当前窗口标记；
- 数字快速键。

### 15.3 排序

1. 当前窗口；
2. 最近使用；
3. 其他窗口；
4. 最小化窗口。

### 15.4 直接选择

若窗口 ≤ 9 个，可显示 1～9。

用户继续按数字直接进入目标窗口。

---

## 16. App Manager / My Shortcuts

### 16.1 主页面

产品设置窗口默认进入 `My Shortcuts`，而不是 Dashboard。

页面内容：

- Trigger Modifier；
- Slot Grid；
- Add App；
- Search Apps；
- Import from Dock（P1）；
- Running Apps 推荐（P1）。

### 16.2 Apps 页面

展示：

- 已安装 App；
- 已固定状态；
- 当前运行状态；
- Bundle ID（详情层）；
- App 路径（详情层）。

支持搜索、排序与添加。

### 16.3 Missing App

当 App 被删除或路径失效：

- Slot 不自动删除；
- 显示 Missing；
- 触发时显示轻量错误；
- 提供 Locate App / Remove Shortcut。

通过 Bundle ID 尝试重新解析新路径。

---

## 17. 首次引导

### Step 1 — Welcome

标题：**Switch apps without searching.**

说明：固定一个快捷键，随时跳到目标 App。

### Step 2 — Choose Trigger

默认推荐 Option。

展示 Option + 1…9 的视觉示意。

### Step 3 — Add Apps

入口：

- Choose from Installed Apps；
- Use Running Apps；
- Import from Dock（如技术方案验证通过）。

### Step 4 — Build Slots

用户确认 5～9 个常用 App。

### Step 5 — Learn One Shortcut

例如：

`Press ⌥3 anytime to jump to Figma.`

### Step 6 — Accessibility

只有当用户启用 Window Switching 或需要相关能力时解释权限用途。

### Step 7 — Done

直接提示用户试一次真实 Jump。

---

## 18. Preferences

### 18.1 General

- Launch at Login：默认 On
- Show Menu Bar Icon：默认 On
- Show Dock Icon：默认 Off
- Check for Updates：官网版可用
- Language：System / English / 简体中文

### 18.2 Shortcuts

- Trigger Modifier
- Search Shortcut
- Window Picker Modifier
- HUD Hold Delay：100～1000ms，默认 220ms

### 18.3 Windows

- Activate Behavior：Recent / Main / First
- Repeated Shortcut：Cycle / Do Nothing / Picker
- Cycle Timeout：300～2000ms，默认 1000ms
- Minimized Window：Restore / Keep Minimized

### 18.4 Appearance

- Theme：System / Light / Dark
- HUD Size：Compact / Standard / Large
- HUD Position：Center / Top Center
- Animation：Off / Fast / Normal

### 18.5 Permissions

状态卡：

- Accessibility
- Login Item
- Input / Keyboard related permission（仅在实现路径需要时展示）

每项包含：状态、用途、打开系统设置。

---

## 19. Menu Bar

Menu Bar 是管理入口，不是核心操作入口。

菜单：

```text
Jump
────────────
Open HUD
Search Apps & Windows
────────────
1  Finder
2  Chrome
3  Figma
4  WeChat
...
────────────
Configure Shortcuts…
Preferences…
About Jump
Quit Jump
```

默认不显示 Dock Icon。

---

## 20. Multi-display / Spaces / Full Screen / Stage Manager

### 20.1 多显示器

Jump 默认进入目标窗口所在显示器，不移动目标窗口。

### 20.2 Spaces

目标原则：激活目标窗口，由系统完成必要的 Space 切换。

V1 不承诺：

- 枚举所有 Space；
- 自定义 Space ID；
- 把其他 App 的窗口强行搬到指定 Space。

### 20.3 Full Screen

若目标窗口位于全屏空间：尝试激活该 App / Window，并遵循 macOS 原生切换行为。

### 20.4 Stage Manager

不重组 Stage Manager 分组，只执行目标激活。

---

## 21. 权限与隐私

### 21.1 Local-first

默认本地保存：

- Slot 配置；
- App 使用统计；
- Window Recent 索引；
- Preferences。

### 21.2 不上传内容

默认禁止遥测上传：

- Window Title；
- 文件名；
- 项目名称；
- 用户 App 内部文档名称。

### 21.3 可选匿名遥测

事件示例：

- setup_completed
- slot_created
- direct_jump
- window_cycle
- search_opened
- permission_granted

不得携带敏感文本内容。

---

## 22. 性能指标

### 22.1 输入响应

Shortcut Trigger 到 Jump Engine 开始处理：目标 `< 50ms`。

### 22.2 HUD

首帧目标 `< 100ms`。

### 22.3 Search

打开目标 `< 150ms`；输入后本地结果更新 `< 50ms`。

### 22.4 常驻资源

目标：

- Idle CPU 接近 0%；
- 内存原则上 `< 100MB`；
- 不做高频全局 Window Polling；
- 使用事件驱动 + 按需刷新。

---

## 23. 错误与降级

| 场景 | 行为 |
|---|---|
| App 不存在 | Slot 保留 Missing，提示 Locate / Remove |
| App 启动失败 | Toast + Retry |
| App 无法激活 | 保持当前应用，提示失败 |
| Accessibility 未授权 | 降级到 App Activate，窗口级能力不可用 |
| Window 无法解析 | 降级到最近可用 App 激活 |
| 标题为空 | 展示 App Name + Window #N |
| 快捷键冲突 | 明确警告，内部冲突禁止保存 |
| Window 已销毁 | 刷新索引后重试一次 |
| App 卡死 | 不阻塞 Jump 主循环，给非阻塞错误反馈 |

---

## 24. 数据与埋点

### 24.1 产品核心指标

#### Direct Jump Ratio

```text
固定 Slot 直接 Jump 次数 / 全部 Jump 次数
```

长期用户目标：持续提升。

#### Search Dependency

```text
Search Jump / Total Jump
```

长期应下降，代表肌肉记忆形成。

#### Time to Destination

从快捷键识别到目标 App/Window 成为前台的时间。

#### Jump Success Rate

目标：`> 99.9%`（排除目标 App 自身无法响应等外部因素时）。

### 24.2 激活指标

首次会话：

- 完成 ≥ 5 个 Slot；
- 成功 Direct Jump ≥ 3 次；
- Accessibility 权限解释页到授权完成率。

### 24.3 留存指标

- D1 / D7 / D30；
- 人均每日 Jump 数；
- Direct Jump Ratio；
- 每周活跃槽位数。

---

## 25. MVP 范围

### P0 — V1.0 必须完成

#### App

- 安装 App 识别；
- Bundle ID / App URL 解析；
- Launch；
- Activate；
- Missing App。

#### Shortcut

- Global Shortcut；
- 1～9 Slot；
- Modifier 配置；
- 内部冲突检测。

#### Window

- Window Detection；
- Recent Window；
- Restore Minimized；
- Repeated Shortcut Cycle；
- Accessibility 授权 / 降级。

#### HUD

- Long-press Trigger；
- Slot Grid；
- Running / Current / Missing 状态。

#### Search

- App Search；
- Window Search；
- Keyboard Navigation。

#### System

- Menu Bar；
- Launch at Login；
- Preferences；
- Onboarding；
- Local Settings Storage。

### P1 — V1.1

- Window Picker；
- Profiles；
- Import Dock；
- Recent Apps；
- Usage Statistics；
- Smart Slot Suggestion；
- iCloud Sync。

### P2 — V2

- Smart Groups；
- Context Recommendations；
- Workspace；
- Advanced Window Rules；
- 自定义动作；
- 高级多实例规则。

---

## 26. 验收标准

### 26.1 Direct Jump

- 绑定 App 未运行时，Shortcut 能启动 App；
- 已运行时能前置 App；
- 最小化时可按策略恢复；
- 目标 App 已前台且存在多窗口时能按策略循环；
- 未授权 Accessibility 时功能有明确降级而非失败。

### 26.2 HUD

- 快速 `Modifier + Number` 不闪现 HUD；
- 长按达到阈值后 HUD 出现；
- 按数字后 HUD 立即消失并执行 Jump；
- ESC / 松开 Modifier 正常关闭。

### 26.3 Search

- 能检索已安装 App；
- 能检索可解析运行窗口；
- Enter 可直接 Jump；
- 全流程可纯键盘完成。

### 26.4 Stability

- 后台运行 8 小时以上无明显内存持续增长；
- App 频繁启动/退出后 Window Index 可恢复；
- 显示器插拔后不崩溃；
- Accessibility 权限被用户撤销后能实时降级或下次操作正确提示。

---

## 27. 产品差异化

Jump 不追求成为 Raycast / Alfred 的替代品。

对比逻辑：

```text
搜索型 Launcher：
Invoke → Search → Choose → Execute

Jump：
Shortcut → Destination
```

产品竞争维度是：

- 操作路径长度；
- 稳定肌肉记忆；
- App + Window 一体化；
- 多窗口切换效率；
- 高频行为的零 UI 化。

---

## 28. 产品价值表达

英文主标题候选：

- **Jump to any app instantly.**
- **Your apps. One keystroke away.**
- **Don't find. Just jump.**

中文：

> **一个快捷键，立即进入你想去的 App 或窗口。**

辅助表达：

> 无需 Dock，无需 `⌘Tab`，无需搜索。

---

## 29. V1 成功判断

V1 是否成功，不以功能数量判断，而看用户行为是否发生改变：

- 第一天：理解固定 Slot；
- 第一周：记住 3～5 个 App 快捷键；
- 第二周：主动减少 Dock / `⌘Tab`；
- 长期：不思考即可完成 App Jump。

一旦用户形成：

```text
Chrome = ⌥2
Figma = ⌥3
WeChat = ⌥4
VS Code = ⌥5
```

产品就形成了真正的路径依赖和长期价值。
