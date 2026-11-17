# Alfred Workflows 逆向与 Jfred 对齐

本轮目标是把 Jfred 的 Workflows 从“线性动作列表”改成 Alfred 的对象图：读取真实的 `info.plist`，在画布上显示对象与连线，按连接执行 Script Filter、Run Script、Arg and Vars、Conditional、Junction 和输出动作。

## 目标与方法

本机 Alfred 为 5.8.1 (build 2349)。本轮使用 REA 6.7.0 的以下只读操作：

| 操作 | 目标 | 证据 ID | 用途 |
| --- | --- | --- | --- |
| `inspect-macho` | Alfred Framework | `ev_cc8f3498ab6677c79774b2144b1a733d7375ca63ab3d236d42fafc1cba89d51d` | 确认 Framework 架构、符号规模与版本基线 |
| `decode-interface-builder` | Alfred Preferences | `ev_6e2bcbeb753d052bab72f7f29fccf621b102037d9a545832a5dcbc6169eebdf3` | 解出 18 个 nib；其中 Workflows nib 241 objects / 86 connections |
| `inspect-plist` | 已导入的 uicli workflow | `ev_b0d507c8b7da226438e69b771830c923eb59c471a3ba01753f27fbde7a48655c` | 验证 `objects` / `connections` / `sourceoutputuid` / `scriptfile` 的真实结构 |

Hopper 的 Apple Events 在本轮 DSH 上下文中被 TCC 拒绝，因此 `decompile` 类操作没有作为本轮依据；对象图与脚本语义由真实 workflow plist、官方 Script Filter JSON/XML 文档和可执行回归测试交叉验证。这是有意收窄的证据边界，不把字符串猜测当成反编译结论。

## 从 Workflows nib 得到的外壳事实

`AlfredPreferencesWorkflows.nib` 的关键 frame：

- 左侧工作流列表宽 253pt；搜索框约 213×22pt，列表滚动区 253×576pt。
- 右侧编辑区域 846×640pt；标题/详情 sheet 宽约 468pt。
- 空画布使用 `AlfredWorkflowCanvasNoWorkflow.nib`，信息条位于 873×40pt 区域。
- 编辑区按钮为 26–32pt 高；底部工具栏包含 Alfred Gallery、Help、新建/删除/导入。

Jfred 没有复制 nib 或图标，只采用尺寸、层级和交互语义；画布节点使用 SF Symbols 与平色块。

## 从真实 workflow 得到的对象图事实

以本机 uicli workflow（`com.tru2dagame.uicli`）和公开的 GitHub workflow 为例：

- 顶层键：`bundleid`、`name`、`createdby`、`description`、`webaddress`、`version`、`disabled`、`variables`、`objects`、`connections`、`uidata`。
- 对象：`uid`、`type`、`version`、`config`。`type` 决定对象类别，`config` 保留该对象的全部选项。
- 连接：源 uid → 数组；每项包含 `destinationuid`、`modifiers`、`modifiersubtext`、`vitoclose`，条件分支额外有 `sourceoutputuid`。
- 条件对象：`config.conditions` 是数组，每项有 `uid`、`inputstring`、`matchstring`、`matchmode`、`matchcasesensitive`、`outputlabel`；连线用 `sourceoutputuid` 指向条件 uid，没有该字段的连线是 otherwise 分支。
- 脚本字段：`script`、`scriptfile`、`type`、`scriptargtype`、`escaping`。`scriptargtype = 1` 时脚本通过 argv 接收参数；否则 Alfred 在脚本文本中替换 `{query}`。`scriptfile` 非空时执行 workflow 目录内的外部脚本。
- 画布位置：`uidata[uid].xpos/ypos`，另有 `note`、`colorindex`。

这些事实直接映射到 `Sources/JfredCore/WorkflowGraph.swift` 的 `WorkflowObject` / `WorkflowConnection` 和 `WorkflowImporter`。

## Jfred 实现

| 文件 | 职责 |
| --- | --- |
| `Sources/JfredCore/WorkflowGraph.swift` | 可编码的 `WorkflowValue`、对象/连接/画布模型、旧版线性 Workflow 迁移、Alfred `info.plist` 解析、稳定 UUID |
| `Sources/JfredCore/WorkflowEngine.swift` | keyword 匹配、Script Filter/List Filter 结果、JSON/XML 解析、节点执行、条件分支、modifier 连线、模板变量、效果列表 |
| `Sources/JfredCore/WorkflowProcessRunner.swift` | 在 workflow 目录中运行 bash/zsh/php/ruby/python/perl/osascript/swift/外部脚本，注入 `alfred_workflow_*` 环境变量 |
| `Sources/Jfred/WorkflowRuntime.swift` | 把 workflow 结果映射成启动器行、执行效果、解析选中项 |
| `Sources/Jfred/PaneWorkflows.swift` | 253pt 工作流列表、66pt 标题栏、对象画布、右侧 220pt 对象库、深色对象配置 sheet、底部调试器 |
| `Sources/Jfred/JfredStore.swift` | 导入/重载 `.alfredworkflow`、读取完整对象图、保留本地启用状态 |

### 执行顺序

1. 启动器命中 keyword（支持带空格的 keyword 和 `withspace`）。
2. Script Filter 在 workflow 目录执行；stdout 优先按 JSON `items` 解析，兼容旧 XML。
3. 选中项后从 Script Filter 的出边开始，按 `sourceoutputuid` / modifier 选择分支。
4. 每个对象产出一个效果（打开 URL、复制、Large Type、通知、写文件、终端等）并继续沿默认连接执行。
5. Run Script 的 stdout 成为下一个对象的参数；Arg and Vars 写入 `{var:name}` 与环境变量。
6. Conditional/Filter 决定走向；Junction 向所有默认出边分发。

### 已覆盖的对象

Keyword、Script Filter、List Filter、Run Script、AppleScript、Open URL、Open File、Reveal in Finder、Copy to Clipboard、Large Type、Notification、Play Sound、Speak、Arg and Vars、Conditional、Filter、Junction、Delay、Debug、Write File、External Trigger、Hotkey。

### 明确未做

- Alfred 私有 Automation Task（`alfred.workflow.automation.task`）只保留对象和连线，执行时记录 unsupported，不伪造行为。
- Alfred 私有 remote/iOS 协议、UI Grid/PDF 等展示对象不做执行。
- 节点连线当前通过对象配置 sheet 的目标 Picker 编辑，不实现 Alfred 的端口拖拽画线；节点本身可拖动。
- 对象库采用 Alfred 的右侧面板布局与分组（Favourites/Triggers/Inputs/Actions/Automations/User Interface/Utilities/Outputs），但尚未实现 Alfred 的 prefab、拖拽到画布和收藏排序。
- Script Filter / List Filter 节点默认继承 workflow 目录的 `icon.png`，与 Alfred 一致；其余动作对象继续使用 SF Symbols。启动器结果没有自带 icon 时也会回退到 workflow logo。
- Arg and Vars 对象按 Alfred 渲染为 40×40 的 `>` 紧凑块，而不是完整卡片；这是 uicli 流程图之前看起来“挤在一起”的主要原因。完整配置仍可双击该块打开。
- 不复制 Alfred 的 nib、图标、主题或字符串表；所有界面为独立 SwiftUI 实现。

## 验证

- `./scripts/test.sh`：36 个测试全部通过；新增 WorkflowGraphTests 覆盖导入、Script Filter、条件分支、旧版迁移、模板、真实已安装 workflow 导入和进程运行器。
- `swift build`：通过。
- 实机回归：导入本机 uicli workflow 后，输入 `uicli login`，Script Filter 返回真实的 AWS profile 行；结果行由 JSON `items` 生成，说明 keyword→脚本→JSON→启动器链路已打通。


## 画布 UI 对齐（第二轮）

除 nib frame 外，本轮用 Alfred 官方 [Workflow Editor and Palette](https://www.alfredapp.com/help/workflows/getting-started/editor-and-palette/) 的 `workflow-canvas.png`、`palette-search.png` 和 `workflow-canvas-hints.png` 作为视觉基准（只参考布局、尺寸、颜色和层级，不复制图片资源）。

| 区域 | Alfred 参考 | Jfred 实现 |
| --- | --- | --- |
| 标题栏 | 46pt 工作流图标、约 20pt 名称、Configure Workflow、右侧工具图标 | 66pt 高，46pt 图标，19pt 名称，Configure Workflow + 键盘/导出/调试/对象库/菜单 |
| 工作流列表 | 253pt 宽，42pt 行，34pt 图标，深紫底，底部 Help/+/- | 同宽同行高，读取 workflow 目录 `icon.png`，底栏 Help/+/- |
| 画布 | `#1B1B1B`，浅色对象卡，灰色管道连线，中点圆点 | 150×104pt 浅色卡，类型色，2.2pt 连线 + 中点圆点 |
| 对象库 | 右侧 220pt，搜索、Getting Started/Prefabs、Favourites（紫色）、Triggers/Inputs/Actions/Utilities/Outputs | 同结构；对象项 50pt 行高，星标与说明 |
| 对象配置 | 深色 sheet | 580×660pt 深色 sheet，Cancel/Save，字段深色底 |
| 调试器 | 底部工具栏 + 日志 | 32pt 工具栏 + 76pt 日志区，Test query/Run/Step/Copy/Clear/Close |

已知差异：对象图标仍用 SF Symbols，不复制 Alfred 的手绘对象图标；窗口字体渲染与 Alfred 的 AppKit 控件存在 1–2pt 级差异。


## 5.8.1 实机取样（Alfred Powerpack 已启用）

在 Alfred Powerpack 启用后直接对 Alfred Preferences 的 Workflows 窗口取样（窗口 1422×860，截图为 2x Retina），把下面这些值写进 Jfred：

| 项目 | 实测值 |
| --- | --- |
| 左侧列表 | 253pt；底色 `#2F104B`；行高 42pt；图标 34pt；搜索框白底 `#F6F6F6` |
| 选中行 | 青色 `#4B809C`，不是深紫 |
| 右侧对象库 | 243pt；底色 `#282828`；搜索条/分组条 `#3F3F3F`；Favourites 为紫→青渐变 |
| 对象库行 | 分组 27pt、条目 27pt，条目只有图标和标题，没有副标题 |
| 标题栏 | 90pt；底色 `#161616`；46pt 工作流图标；20pt 名称；`Configure Workflow...` 按钮 |
| 画布 | `#1E1E1E`；对象卡约 132×94pt；卡片底色 `#E5E5E5`；连线约 2.4pt 灰色 |
| 调试器 | 28pt 高的 “Debugger Stopped” 常驻条；展开后为工具栏 + 日志 |
| 禁用工作流 | 列表行内容约 55% 不透明度并去饱和；标题追加 ` - disabled`；选中行仍是青色 |

### 对象配置面板

对象配置按 Alfred 的浅色大面板实现：

- 约 980×700pt，浅灰底 `#F2F2F2`，底部左侧帮助/文件夹按钮，右侧 Cancel/Save。
- 顶部不显示 “Object” 标题或内部 type 字符串，也不把连接编辑器塞进配置面板。
- Run Script 顶部为 `Language`、输入方式、`running instances` 三段；`External Script` 显示 `Script File`、`Open File`，以及工作流目录里该文件的灰色只读预览，不能在面板里改脚本正文。
- Script Filter 额外显示 Keyword/Placeholder、Alfred filters results、Match mode 和 Argument requirement。

### Configure 行为

`Configure Workflow...` 在 Alfred 中不是“编辑工作流详情”，而是打开 User Configuration / Readme 的配置入口：

- 没有 `userconfigurationconfig` 和 Readme 时，显示浅色 “No Workflow Configuration” 对话框，说明如何用编辑器右上角的 `[x]` 配置 workflow，并只有 `Close` 按钮。
- Jfred 现在按此行为显示同样的对话框；工作流元数据编辑移到对象库右侧的 `...` → `Workflow Details...`，避免把两个入口混在一起。

实机取样也修正了之前的空态卡片：Alfred 的引导卡片约 650pt 宽、90pt 高，Jfred 已按此调整。


## 兼容性实测：Epoch Converter

用本机 Alfred 的真实 Epoch Converter workflow（3 objects）直接走 Jfred 的导入/执行链验证：

- 顶层 Script Filter：`ts`，`/usr/bin/python3 epoch.py "{query}"`，`scriptargtype = 0`，相对路径脚本。
- 两个默认输出：Copy to Clipboard 和 Post Notification。
- 旧版 Alfred-Workflow 库会打印一个错误 XML 并让进程退出 1，但 stdout 里第一份 `<items>` 是有效结果。
- Jfred 的 XML 解析器现在只取第一份 `<items>`，并支持 `<arg>` 子元素；Script Filter 即使退出码非 0，只要 stdout 有有效 items 就使用它。
- 默认连线不再只取第一条，因此 clipboard 和 notification 会同时执行。

用 `ts 1700000000` 实测得到 6 条结果（本地时间、UTC、当前时间等），第一条 arg 为 `2023-11-15T06:13:20`，效果为复制该时间和发送 `Time: 2023-11-15T06:13:20` 通知。因此 Epoch Converter 这类“相对路径脚本 + XML 输出 + 多输出”的 workflow 可以导入使用。
