# Jump — macOS App & Window Switcher 产品需求文档（PRD）

> 产品版本：V1.0；文档修订：R2（2026-10-04）  
> 文档状态：产品立项 / 原型设计 / 技术评审基线  
> 平台：macOS  
> 产品形态：Menu Bar App + 全局快捷键服务 + HUD + 设置中心  
> 产品代号：Jump（暂定）

---

## 0. 文档使用与本次修订

本文件定义产品行为与版本范围；UI 文档细化界面，技术文档说明实现限制。R2 在 R1 基础上调整开发范围：2026-10-04 用户确认 macOS 聚焦搜索已满足需求，全局快速搜索暂不开发，后续是否恢复另行决定。全文 Quick Search、搜索快捷键、窗口标题搜索及其验收条目保留为暂缓设计，不属于当前版本开发范围，也不展示相关入口或提示；设置页内用于绑定的应用搜索不受影响。原始文档保存在 `../archive/2026-09-30_before_review/`。

- 项目目录使用 Jumpo；分享对话中的 Jumpo 是名称候选。本文保留原代号 Jump，正式名称待确认。
- V1.0 保留固定槽位、应用启动/激活、基础窗口切换、HUD 与设置；窗口能力依赖权限和目标应用支持。
- Window Picker、Profiles、Dock 导入等仍属于 V1.1，不因 UI 原型出现而进入 V1.0；详细范围见第 25 节。
- 快捷键默认值、延迟和性能数字均为设计目标，尚无实机验证结果。先验证核心系统能力，再开发完整界面。

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

Mac 用户随着使用时间增长，通常会安装并长期使用大量应用。典型知识工作场景中，可用“同时运行 10～30 个应用”作为待验证的研究假设，不作为已有用户统计。常见应用示例：

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

macOS 已经提供了 Dock、Launchpad、Spotlight、Mission Control、`⌘Tab`、Command + 反引号等能力，但这些方式都需要用户进行不同程度的“寻找、浏览、判断或确认”。

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

默认 Cycle Timeout：1000ms，表示同一循环会话内相邻两次有效按键的最大间隔。

- 从其他 App 首次按 `⌥5`：进入 VS Code 最近窗口 A，建立窗口顺序快照 `[A, B, C]`。
- 1000ms 内再次按 `⌥5`：依次进入 B、C、A；本次激活不得立即改变快照顺序，避免只在两个窗口间往返。
- 超过 1000ms：结束旧会话。若 VS Code 仍在前台，新会话从当前窗口的下一个窗口开始；若已切到其他 App，恢复首跳最近窗口规则。
- 候选窗口未变化时，超时不改变它们的相对循环顺序。例如 `[A, B, C]` 当前为 B，即使超过 1000ms，下一次也应进入 C，避免慢速触发只在两个窗口间往返。
- 切换到其他 App、触发其他槽位、权限丢失、目标退出时结束会话。窗口关闭时跳过失效项；新窗口留到下次会话加入。
- 长按数字键产生的自动重复不算再次按键；需要释放数字键后重新按下。Option 可以持续按住。
- 只有一个可用窗口时不做可见跳转；窗口数据不可用时只尝试 App 激活。

---

### 6.6 主动打开 Window Picker（V1.1）

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
| slot_index | Int | V1.0 固定 1～9，唯一且不自动重排 |
| modifier | OptionSet（派生） | 来自全局 triggerModifier，不单独持久化到每个槽位 |
| key_code | UInt16 | 物理键位 |
| app_id | UUID? | 绑定 App；空槽位为 nil |
| enabled | Bool | 是否启用 |
| created_at | Date | 创建时间 |
| updated_at | Date | 更新时间 |

### 9.3 Runtime Window

| 字段 | 类型 | 说明 |
|---|---|---|
| window_runtime_id | UUID | 本进程会话内生成；不能跨重启识别窗口 |
| app_id | UUID | 所属应用 |
| pid | Int32 | 进程 ID |
| window_title | String? | 窗口标题 |
| window_index | Int | 应用内排序 |
| minimized | Bool? | 是否最小化；未知不等于 false |
| fullscreen | Bool? | 是否全屏 |
| visible | Bool? | 可见性提示；未知不等于不可见，也不代表所属 Space |
| last_active_at | Date? | 最近激活时间 |
| display_hint | String? | 显示器信息（如可获取） |

> Window 数据仅在内存维护；不持久化窗口标题、AX 引用、运行时 ID 或完整窗口历史。App 的 running / installed 是派生状态；last_used_at / jump_count 为本地成功操作记录。

> app_id 是内部身份，bundle_id 用于系统解析；同 Bundle ID 的多个安装副本不保证等价。优先保留用户选择的路径，重定位时若存在歧义，应让用户选择，不能静默启动另一副本。

### 9.4 Preferences

包含：

- launchAtLogin
- showMenuBarIcon
- showDockIcon
- triggerModifier
- holdHUDEnabled
- hudDelay
- searchShortcut
- windowPickerModifier（V1.1）
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

V1.0 的 1～9 槽位共用一组 Trigger Modifier。默认 Option；可改为 Control、Command 或组合修饰键，冲突与输入干扰须在保存前试用。使用组合修饰键时，单独长按 HUD 仅支持经 POC 验证的组合；不支持的组合关闭长按入口，保留菜单入口。

只注册已绑定且启用的槽位；空槽位/禁用槽位不占用系统快捷键。Missing 槽位保留绑定和错误提示。一个 App 默认只绑定一个槽位；重复添加时定位已有槽位，移动时清空原位置或交换，不能悄悄产生重复映射。

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

默认行为：显示 Replace / Cancel，确认后替换；取消不改变配置。提供 Undo，恢复原绑定。添加已绑定 App 时按第 10.2 节处理。

### 10.4 快捷键冲突

冲突类型：

1. 与 Jump 内部 Shortcut 冲突；
2. 与 Search Shortcut 冲突；
3. 与 Window Picker 组合冲突（V1.1 引入时）；
4. 与系统保留组合明显冲突；
5. 与其他第三方 App 冲突（只能检测部分情况）。

规则：

- Jump 内部确定性冲突：禁止保存；
- 已知不可用组合或实际注册失败：禁止启用，保留旧配置；提示更换组合键；
- 系统/第三方潜在冲突：警告后允许试用，但不能宣称已覆盖其他应用；
- Option + 数字可能占用原有字符输入，Command / Control 组合也可能覆盖应用命令；首次配置必须允许实际试按和更换；
- 修改 Trigger / Search Shortcut 要统一校验与注册；任一失败回滚到旧配置，不能出现设置已保存但快捷键未生效；
- 菜单栏提供“暂停快捷键 / 恢复快捷键”，暂停时注销快捷键并停止长按监听。重新启动后默认恢复已保存配置；
- UI 必须明确显示“可能被 macOS 或其他应用占用”。

---

## 11. Jump Engine 决策规则

按下快捷键时记录来源 App / Window，先解析目标 App，再根据权限和运行状态处理。隐藏与最小化分别处理，不能以“没有可见窗口”推断“没有窗口”。

下表描述默认 Recent / Cycle 行为。用户选择 Do Nothing 时，目标 App 已前台或重复触发均不进入循环；从其他 App 首跳仍正常激活。Main 优先有效 main window，First 使用当前会话的稳定枚举顺序，候选无效时回退到最近可用窗口。

| 条件 | 默认处理 | 成功判定 / 降级 |
|---|---|---|
| 路径失效且无法重新定位 | 保留 Missing 槽位，提供 Locate / Remove | 不尝试启动其他同名 App |
| 未运行 | 异步启动；同一 App 启动中再次触发合并请求 | 前台状态确认；启动失败或等待超时单独记录 |
| 已运行、窗口权限不可用 | 尝试取消隐藏并激活 App | App 已前台算应用级成功；不算窗口级成功 |
| 已运行、标准窗口数未知 | 尝试 App 激活，不擅自新建窗口 | 未知与 0 个窗口必须区分 |
| 已运行、确认无标准窗口 | 激活 App；由 App 自身决定是否展示窗口 | 不承诺任意 App 都能新建主窗口 |
| 单个窗口 | 取消隐藏/激活 App → 按策略恢复最小化 → Raise / Focus | 检查目标焦点；失败退回应用级结果 |
| 多窗口、来源为其他 App | 按第 12.2 节取最近可用窗口 | 建立循环快照 |
| 目标 App 已前台且有多个窗口 | 按第 6.5 节进入下一窗口 | 超时只结束会话，不取消此规则 |
| 目标 App 已前台且只有一个窗口 | No-op | 计为无需切换，不重复累计成功次数 |

### 11.1 最小化与对话框

默认 Restore；只恢复被选中的目标窗口，不恢复全部窗口。Keep Minimized 模式排除最小化窗口；如果剩余窗口为空，只尝试 App 激活，并保留最小化状态。Search 中显式选择最小化窗口时，Restore 模式恢复；Keep Minimized 模式提供“恢复并打开”操作，不能默默违背设置。

默认循环标准顶层窗口，排除桌面、菜单、提示浮层与工具面板；模态对话框或 Sheet 不可被绕过，应交由所属 App 正常处理。窗口过滤规则须按应用验证。

### 11.2 并发与超时

不同 App 的新请求替代旧请求的后续激活动作；旧启动操作可能无法撤销，但其回调不能继续主动抢焦点。同一 App 的有效连续输入合并为循环意图。用户手动切到其他 App 后，不再执行迟到的恢复焦点操作。

每次操作区分：请求已提交、应用级成功、窗口级成功、降级、失败、超时。启动成功回调或 API 返回成功都不能直接证明目标窗口已前台。重试最多一次且有总等待上限，具体时间由 POC 标定。

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

1. 目标 App 当前有效 focused window（优先反映用户在 Jump 之外的操作）；
2. 通过焦点通知和成功 Jump 共同维护的最近窗口记录；
3. 有效 main window；
4. 其他符合最小化策略的标准窗口，采用会话内稳定顺序。

进入循环后使用冻结的顺序快照，不随最近记录更新而重排；精确规则见第 6.5 节。

### 12.3 Window Title 清洗

示例：

`AI-Perfume — Visual Studio Code`

显示为：

`AI-Perfume`

但底层保留原始标题。

针对 App 适配可维护轻量 Formatter，不应使用脆弱硬编码作为核心逻辑。

### 12.4 Finder 特殊逻辑

Finder 按系统应用处理，但仍检测实际运行状态。

- 有标准窗口：使用最近窗口；最小化时遵循恢复策略，不因窗口不可见而重复创建。
- 经权限允许且确认无标准窗口：通过公共 NSWorkspace 能力打开用户主目录，目标是提供可操作的 Finder 窗口；是否复用现有窗口由系统决定。
- 窗口枚举不可用：只请求 Finder 激活/打开，不声称已确认窗口数量，不默认开启 Automation 权限。
- 多个 Finder 窗口：支持循环，排除桌面窗口。

### 12.5 浏览器

Chrome / Edge / Safari / Arc 多窗口优先作为 V1 验证对象。

标签页不属于 V1 Window Jump 范围。

---

## 13. Quick HUD

### 13.1 定位

快捷键记忆辅助层，而非主要操作界面。

### 13.2 触发

默认：Option 按住 220ms。

只有完整配置修饰键处于按下状态、且本次按住期间没有其他输入时才开始计时。若在 220ms 内触发已注册 Slot / Search，立即取消 HUD 计时并执行对应动作。

普通字符、额外修饰键、鼠标按下/拖拽、Esc、会话锁定或监听失效均取消本次长按提示，直到松开修饰键后才重新计时。未被注册的输入正常交给前台 App；不能吞掉 Option 输入或编辑快捷键。无法可靠识别输入状态时关闭长按入口，保留菜单 HUD。

HUD 已显示时触发有效槽位，先隐藏再执行；Esc 关闭且本次按住不再弹出。释放数字键后再次按下可继续循环，长按自动重复不触发循环。

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
- 打开 Search / Picker（Picker 为 V1.1）。

菜单栏“Open HUD”进入可交互模式：不要求按住修饰键，数字/点击直接选择，Esc/外部点击关闭。该模式与不抢焦点的长按提示模式分开实现。

---

## 14. Quick Search（暂缓，非当前版本范围）

### 14.1 定位

只搜索：

1. Applications
2. Running Windows

### 14.2 唤起

默认 `⌥Space`。

### 14.3 搜索排序

先按匹配程度分层，再用使用状态做同层排序：精确匹配 → 前缀匹配 → 子串匹配 → 模糊匹配。固定、运行中、最近使用、频次只能影响同一匹配层，不能让无关的常用 App 排到精确结果之前。

V1.0 搜索应用显示名称、用户别名以及已授权窗口标题；中文应用按名称/别名匹配，不承诺拼音或拼音首字母。App 与 Window 采用统一列表，以图标和副标题区分，避免分组顺序破坏匹配优先级。同分按固定槽位顺序、显示名称和会话内 ID 稳定排序。

缓存应用结果先显示，窗口结果异步补充。新查询取消旧查询结果；保留已选结果身份，已删除窗口不可跳到同编号的另一个窗口。未授权时仅显示应用结果及非阻断说明。

---

### 14.4 键盘行为

- ↑ / ↓：选择；
- Enter：Jump；
- ESC：关闭；
- `⌘1…9`：快速选择前 9 个结果（V1.1）；
- Tab：App / Window 分组跳转（V1.1）。

### 14.5 空搜索

未输入关键词时默认展示：

- 先按槽位顺序显示 Pinned Apps；
- 再显示本次会话内最近成功跳转目标，去重；
- Running Apps 去重后补足列表。

这不包含跨会话窗口历史或 V1.1 的独立 Recent Apps 功能。

---

## 15. Window Picker（V1.1，非 V1.0 验收项）

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

松开触发组合键后，按无修饰数字直接进入对应窗口；不再把同一个裸数字解释为循环命令。数字对应本次打开时列表的前 9 项，滚动不重新编号；其余窗口用方向键或鼠标选择。

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
- Import from Dock（V1.1，不出现在 V1.0 引导）。

### Step 4 — Build Slots

至少选择 1 个即可开始，最多 9 个；推荐先配置 3～5 个。候选列表来自已安装/正在运行的应用，不宣称已了解用户的长期使用频次。

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

- Launch at Login：默认 Off，首次引导可由用户主动开启；实际状态以系统为准
- Show Menu Bar Icon：默认 On
- Show Dock Icon：默认 Off
- Check for Updates：正式官网发布时提供；更新方式另行确定，原型不实现自动更新
- Language：System / English / 简体中文

### 18.2 Shortcuts

- Trigger Modifier
- Search Shortcut
- Hold to Show HUD：可开关；监听不可用时说明原因，保留菜单入口
- Window Picker Modifier（V1.1）
- HUD Hold Delay：100～1000ms，默认 220ms

### 18.3 Windows

- Activate Behavior：Recent / Main / First
- Repeated Shortcut：Cycle / Do Nothing（Picker 选项为 V1.1）
- Cycle Timeout：300～2000ms，默认 1000ms
- Minimized Window：Restore（默认）/ Keep Minimized，规则见第 11.1 节

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

每项包含：状态、用途、打开系统设置。窗口授权状态与长按 HUD 的监听可用性分别显示；前者已授权不等于后者一定可用。V1.0 不做截图/缩略图，不为核心功能要求屏幕录制或 Automation 权限。

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
Pause Shortcuts / Resume Shortcuts
Quit Jump
```

默认不显示 Dock Icon。关闭设置窗口不退出后台服务；退出必须使用 Quit。菜单图标隐藏时，再次从 Finder / Spotlight 打开 Jump 应显示设置窗口；必须验证这一恢复入口。

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
- Window Recent 索引（仅会话内存，退出时清除）；
- Preferences。

### 21.2 不上传内容

默认禁止遥测上传：

- Window Title；
- 文件名；
- 项目名称；
- 用户 App 内部文档名称。

### 21.3 可选匿名遥测（后续评估，V1.0 不接入）

V1.0 无账号、云服务或远程埋点依赖；仅保留本地必要记录和用户主动导出的诊断信息。后续如启用遥测，需要单独定义开关、字段与保留周期。以下仅为候选事件：

- setup_completed
- slot_created
- direct_jump
- window_cycle
- search_opened
- permission_granted

不得携带敏感文本内容。

---

## 22. 性能指标

以下为待 POC 校准的目标，不代表已测性能。必须记录 Mac 型号、芯片、内存、macOS / App 版本、权限状态、应用/窗口数量和冷/热状态。

| 指标 | 起止点 | 初始目标 |
|---|---|---|
| 输入处理 | 收到有效快捷键事件 → Jump Engine 接收请求 | p95 < 50ms |
| HUD 首帧 | 长按 220ms 到期 → 首帧可见 | p95 < 100ms；总时间需另计 220ms |
| Search 打开 | 收到搜索快捷键 → 输入框可输入 | p95 < 150ms |
| 应用搜索 | 输入变化 → 已缓存应用结果更新 | p95 < 50ms；AX 刷新另计 |
| 到达目标 | 收到快捷键 → 确认 App / Window 前台 | 分别记录热切换、冷启动、跨 Space；POC 后定门槛 |
| 空闲资源 | 预热后 10 分钟无操作 | CPU 接近 0%，内存初始预算 < 100MB，报告平均值和峰值 |

每个主要热路径至少采样 100 次，报告 p50、p95、最大值与失败次数；不可仅报告平均值。冷启动与系统 Space 动画单列，但仍保留用户看到的端到端耗时。8 小时稳定性测试检查持续增长、监听失效与恢复，不将正常缓存增长直接判为泄漏。

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
| 快捷键冲突 | 内部冲突/注册失败禁止启用；潜在冲突允许试用并可暂停 |
| Window 已销毁 | 刷新并重试一次；显式选择的窗口失效时不切到另一个同名窗口 |
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

暂不采用缺少样本依据的 `> 99.9%` 承诺。应用成功率与指定窗口成功率分别统计：确认目标前台的次数 / 对应有效用户请求数。降级到 App 不算指定窗口成功，No-op 与合并请求单列；超时和外部失败保留分类，不静默剔除。POC 后确定各兼容场景的发布门槛。

### 24.2 激活指标

首次会话：

- 完成至少 1 个 Slot，并观察用户是否继续配置常用应用；
- 成功 Direct Jump ≥ 3 次；
- Accessibility 权限解释页到授权完成率。

### 24.3 留存指标（后续研究，不作为 V1.0 埋点开发要求）

- D1 / D7 / D30；
- 人均每日 Jump 数；
- Direct Jump Ratio；
- 每周活跃槽位数。

---

## 25. MVP 范围

当前实现方案：原生 Swift / SwiftUI / AppKit，先按非沙盒应用验证完整功能，正式分发采用 Developer ID 签名与公证；不以 Mac App Store 兼容作为首版前提。详见技术文档第 20、35 节。

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

- Long-press Trigger（监听可用时；不可用时提供菜单 HUD 并明确状态）；
- Slot Grid；
- Running / Current / Missing 状态。

#### Search（2026-10-04 移出当前 P0）

全局应用/窗口搜索及其键盘导航暂缓，由 macOS 聚焦搜索满足当前需求。设置页的应用选择和名称筛选保留。

#### System

- Menu Bar；
- Launch at Login；
- Preferences；
- Onboarding；
- Local Settings Storage、配置损坏恢复、暂停快捷键、再次打开 App 恢复设置入口。

### P1 — V1.1 候选，单独评审后排期

- Window Picker；
- Profiles；
- Import Dock；
- Recent Apps；
- Usage Statistics；
- Smart Slot Suggestion；
- iCloud Sync。

### P2 — V2 候选，非承诺范围

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
- 未授权 Accessibility 时仍能从已成功注册的快捷键、菜单和应用搜索请求 App 激活；
- 隐藏/最小化分别验证；窗口级降级不能被记录为窗口级成功；
- `A → B → C → A` 循环可覆盖所有窗口；超时、关窗、切走 App 后规则一致；
- 快速触发 A 后 B，A 的迟到回调不再主动抢回焦点。

### 26.2 HUD

- 快速 `Modifier + Number` 不闪现 HUD；
- 长按达到阈值后 HUD 出现；
- 按数字后 HUD 立即消失并执行 Jump；
- ESC / 松开 Modifier 正常关闭，保持按住时不再次弹出；
- Option + 普通字符、Option + 方向键、组合修饰键、鼠标拖拽不被 HUD 干扰；
- 空/禁用槽位不占用按键，Missing 槽位提示明确；
- 菜单 HUD 不依赖长按权限，数字与鼠标都能选择；
- 系统限制或监听失效时如实降级，不模拟成功。

### 26.3 Search（暂缓，不执行当前版本验收）

- 能检索已安装 App；
- 能检索可解析运行窗口；
- Enter 可直接 Jump；
- 全流程可纯键盘完成；
- 旧查询结果不覆盖新输入，窗口失效不误选其他窗口；
- 权限撤销后立即清除窗口标题/结果，保留应用搜索。

### 26.4 Stability

- 后台运行 8 小时以上无明显内存持续增长；
- App 频繁启动/退出后 Window Index 可恢复；
- 显示器插拔后不崩溃；
- Accessibility 权限被用户撤销后能实时降级或下次操作正确提示；
- 快捷键修改失败回滚，配置损坏保留备份并提供恢复入口；
- 菜单图标与 Dock 图标同时隐藏时，重新打开 App 可回到设置；
- 睡眠唤醒、锁屏解锁、输入法/键盘布局切换后无残留 HUD 或意外按键。

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
