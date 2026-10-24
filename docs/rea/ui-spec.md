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
| 页面标题栏 | 高 78pt，`#D9D9D9`，底部 1px 分隔线；图标 46pt、标题 20pt semibold、副标题 12.5pt |
| 表单面板 | 白色、圆角 9pt、1px `black 7%` 边框，内边距 24pt |
| 搜索框 | 标题栏右侧，约 220 × 26pt，圆角 6pt |
| Tab 条 | 圆角 7pt 的 `#E2E1E0` 底，选中段白色，段高 23pt |

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
- **Clipboard**：History / Merging / Advanced 三个 tab；三类保留项；Viewer Hotkey/Keyword；Clear Keyword；Snippets；Universal；Merging 的 Fast append、分隔符、声音、回写剪贴板；Advanced 的 Max Clip Size、Concealed/Auto Generated、Unicode 匹配、Used 置顶、PNG、退出清空。
- **Calculator**：Standard / Advanced（`=` 前缀）/ Input / Output / 千分位。
- **Dictionary**：Define / Spell / Language / Paste on action / Only show dictionary words。
- **File Search**：Navigation 的 ←/→、↩ 打开 Finder、Previous Path；Buffer 的启用、清理、⇧⌥；Advanced 的 Home Folder、Copy Path、AppleScript、外置盘图标、Touch folders/aliases。
- **Contacts**：Contacts / Email / Advanced 三个 tab；Open Contacts / Display / Maps / URL handler / 权限状态。
- **Music**：General / Keywords / Advanced 三个 tab；Mini Player 开关与 keyword、Playback、Now Playing、Play/Pause/Previous/Next。
- **System**：每个命令的 enable + confirm + keyword；Eject / Eject All / 排除卷。
- **Terminal**：Application、Prefix、Custom AppleScript。
- **System**：系统命令关键词、确认、Eject、Eject All、排除卷。
- **Previews**：Quick Look、rich previews、No Previews For/In。

## 已知未对齐

- Music 还没有真正的 Mini Player 窗口，只有命令与状态。
- Appearance 的实时主题预览、Workflows 的画布/调试器、Remote 的 iOS 配对协议、Powerpack/Help 的营销与诊断内容只做了结构级对齐。
- Alfred 的部分图标为手绘位图，Jfred 使用 SF Symbols + 同色块，形状不同。
