# Alfred 5.7 偏好设置 UI 规格（REA 证据整理）

所有坐标来自 `decode-interface-builder` 的 nib 图和 Accessibility 树；颜色来自对 Alfred Preferences 窗口的像素采样。

## 外壳

| 元素 | 规格 |
| --- | --- |
| 窗口 | 1180 × 766 pt，标题栏高 38pt |
| 左侧 icon rail | 80pt 宽；底色 `#4F217A`；选中项为白色 20% 叠加 |
| 二级列表（Features） | 240pt 宽；底色 `#2F104B`；行高 42pt；选中行 `#58406F` |
| 列表图标 | 34 × 34pt，圆角约 7pt |
| 内容区 | `#ECECEC` |
| 页面标题栏 | 高 80pt，`#D9D9D9`，底部 1px 分隔线；图标 46pt、标题 20pt semibold、副标题 12.5pt |
| 表单面板 | 白色、圆角 9pt、1px `black 7%` 边框，内边距 24pt |
| 搜索框 | 标题栏右侧，约 420 × 24pt，圆角 6pt |
| Tab 条 | 圆角 7pt 的 `#E2E1E0` 底，选中段白色，段高 23pt |

## 启动器窗口

数值来自 Alfred 自带 `.alfredappearance` 主题文件的 `window` / `search` / `result` 节点（只取数值与语义，不复制主题文件）。

| 元素 | Alfred 默认主题 |
| --- | --- |
| 窗口宽度 | 559pt（Alfred Modern 700、Frosty Teal 573、Large Avenir 683） |
| 圆角 | 3pt（Modern 15、Large Avenir 5） |
| 窗口内边距 | 横向 9pt、纵向 8pt |
| 搜索字号 | 34pt System Light；Modern 36、Frosty 40、Large Avenir 46、High Contrast 38 |
| 搜索背景 | `#0000001A`；macOS 主题透明 |
| 结果标题 | 18pt；副标题 12pt；快捷键 16pt |
| 选中背景 | `#480069E4`（macOS 主题 `#016BDEFF`，Dark `#358188FF`） |
| 行高 | max(图标 40, 18+5+12) + 上下 3 + 4 ≈ 50pt |
| 图标 | 40×40，图标与文字间距约 8pt |
| 模糊 | 15（Modern 为 0） |

Jfred 的 10 套主题与此一一对应：Alfred、Alfred Dark、Alfred Modern、Alfred Modern Dark、Alfred Classic、Alfred macOS、Alfred macOS Dark、Frosty Teal、Large Avenir、High Contrast Light。旧主题 ID（modern/macos/frosty 等）会映射到新 ID，旧配置不会失效。

### Action Panel

- 打开：→ 或 ⌘K；关闭：Esc / ←。
- 导航：↑↓；执行：↩。
- 动作按结果类型生成：
  - App / 文件：Open、Reveal in Finder、Copy Path、Copy Name、Quick Look、Large Type。
  - URL：Open URL、Open in Default Browser、Copy URL、Large Type。
  - 联系人：Open Contact、Copy Email or Phone、Large Type。
  - 剪贴板：Paste、Copy、Large Type。
  - 计算/复制/片段：Paste、Copy、Large Type。
- 面板复用主题的行高、选中背景与字号，宽度不额外扩展。

## Features 列表

| # | 标题 | 副标题 |
| --- | --- | --- |
| 1 | Default Results | Scope, Types, Fallbacks |
| 2 | File Search | Search, Navigation, Buffer |
| 3 | Universal Actions | Files, Text, URLs |
| 4 | Web Search | Custom, URLs, History |
| 5 | Web Bookmarks | Safari, Chrome |
| 6 | Clipboard History | History, Merging |
| 7 | Snippets | Snippets, Clippings |
| 8 | Calculator | Standard, Advanced |
| 9 | Dictionary | Spelling, Definitions |
| 10 | Contacts | Viewer, Emailing |
| 11 | Music | Mini Player |
| 12 | 1Password | 1Click Bookmarks |
| 13 | System | Commands, Quitting, Ejecting |
| 14 | Terminal | Prefix, Custom Integration |
| 15 | Large Type | Display, Font |
| 16 | Previews | Quick Look, Preview panels |

## 页面标题与副标题（节选）

| 页面 | 标题 | 副标题 |
| --- | --- | --- |
| Default Results | Default Results | These are the main results Alfred presents by default, and where he looks for them. |
| File Search | File Search | Using the file search keywords is the best way to find files; it keeps the default results both fast and focused. |
| Clipboard History | Clipboard History | Automatically store copied items in a searchable clipboard history. |
| Contacts | Contacts | Search and view your Apple Address Book. |
| Music | Music | Take control of Music.app to find and play your favourite music, or let Alfred pick for you. |
| Dictionary | Dictionary | Look up words in Alfred or macOS's dictionary and paste them into another application. |
| Terminal | Terminal | Quickly open the terminal and run shell commands. |
| Large Type | Large Type | Show text and results in large characters across your screen. |
| Previews | Previews | Customise usage of macOS Quick Look, and how Alfred displays file previews. |

## 已对齐的页面结构

- **Default Results**：Applications / Essentials（Contacts、System Settings）/ Extras / Unintelligent / Search Scope / Fallbacks。
- **File Search**：Search / Navigation / Buffer / Advanced 四个 tab；Opening、Revealing、Inside、File Tags 关键词；Don't Show 列表；Result Limit。
- **Clipboard**：History / Merging / Advanced 三个 tab；三类保留项（Text/Images/File Lists 各自时长）；Viewer Hotkey/Keyword；Clear Keyword；Snippets；Universal；Merging 的 Fast append、分隔符、声音、回写剪贴板；Advanced 的 Max Clip Size、Concealed/Auto Generated、Unicode 匹配、Used 置顶、PNG、退出清空。
- **Calculator**：Standard / Advanced（`=` 前缀）/ Input / Output / 千分位。
- **Dictionary**：Define / Spell / Language / Paste on action / Only show dictionary words。
- **File Search**：Navigation 的 ←/→、↩ 打开 Finder、Previous Path；Buffer 的启用、清理、⇧⌥；Advanced 的 Home Folder、Copy Path、AppleScript、外置盘图标、Touch folders/aliases。
- **Contacts**：Contacts / Email / Advanced 三个 tab；Open Contacts / Display / Maps / URL handler / 权限状态。
- **Music**：General / Keywords / Advanced 三个 tab；Mini Player 开关与 keyword、Playback、Now Playing、Play/Pause/Previous/Next。
- **System**：每个命令的 enable + confirm + keyword；Eject / Eject All / 排除卷。
- **Universal Actions**：General / Actions 两 tab；Show Actions 的 →/fn/ctrl/⌘ 开关、Selection Hotkey、Action Ordering；全局 ⌥⌘\ 读取选中文本/Finder 文件并弹出动作面板。
- **Appearance**：290pt 主题列表、80×50 缩略图、实时预览；支持 `.alfredappearance` 导入/导出、自定义主题与 Options 编辑器（宽度/圆角/内边距/字号/颜色）。
- **Help**：版本/诊断、权限与支持目录、可搜索的排障主题列表、Copy Diagnostics。
- **1Password**：绿色 “1Password 8 Integration” 卡片 + 获取工作流按钮、集成开关、加载状态。
- **Clipboard Advanced**：Ignore Apps 可编辑列表；File Buffer 支持超时/动作后清空；Clear Keyword 支持全部/5/15 分钟；Viewer 可整合 Snippets。
- **Snippets**：Viewer Hotkey、Snippet Keyword、Show Keyword in Result、Matching + Word based、右侧 Auto Expansion 卡与 Options 面板、Collection 列表 + Name/Keyword/Snippet 表。
- **Workflows**：Inspector 支持 Hotkey 录制/清除；深色空态（Alfred Gallery / Getting Started / Create / Template / Documentation 五卡）；选中后内嵌画布，左侧 Objects 调色板，Keyword → Action 节点链，节点可拖拽重排，右侧 Inspector，底部 Add Action / Test query / Run / Step / Cancel / Save；Debugger 面板记录顺序执行结果与单步输出；Inspector 可设断点，节点右上显示红点。
- **Terminal**：Application、Prefix、Custom AppleScript。
- **System**：系统命令关键词、确认、Eject、Eject All、排除卷。
- **Previews**：Quick Look、rich previews、No Previews For/In。

## 已知未对齐

- Music Mini Player 已有独立暗色面板（420×560）与当前曲目专辑封面；还没有播放列表/专辑浏览。
- Remote 已有本地 URL 的 QR 配对面板；Alfred 的私有 iOS 配对协议未实现。
- Appearance 的实时主题预览、Workflows 的画布/调试器、Remote 的 iOS 配对协议、Powerpack/Help 的营销与诊断内容只做了结构级对齐。
- Alfred 的部分图标为手绘位图，Jfred 使用 SF Symbols + 同色块，形状不同。
