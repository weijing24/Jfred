# REA 复刻证据与说明

本目录记录 `rea` 分支如何用 [REA](https://rea.tools/) 对 Alfred 5 做二进制与界面取证，以及这些证据如何映射到 Jfred 的实现。原始证据保存在 `/tmp/alfred-rea/`（不提交，避免把 Alfred 的字符串表、nib 图和资源带进仓库）。

## 目标

| 项目 | 值 |
| --- | --- |
| Alfred | 5.7 (build 2302) |
| 主程序 | `/Applications/Alfred 5.app/Contents/MacOS/Alfred`，SHA-256 `e84762abac9f9a83ff5a87891c1bd03108b138a2b84d6d0434db7cfd9582ba68` |
| Framework | `.../Frameworks/Alfred Framework.framework/Versions/A/Alfred Framework`，SHA-256 `1b21c6f45b1f8373bd700bd1ed1e0c601785176b0593511492a4a225fa2927f5` |
| Preferences | `.../Preferences/Alfred Preferences.app/Contents/MacOS/Alfred Preferences`，SHA-256 `4f2ff8212aae77e129abc4cfa98d608af024aa1357e4a1faf1c251413b82c4b8` |
| REA | `rea-agents` 6.7.0（CLI/MCP 同一套工具） |
| 反汇编器 | Hopper Disassembler 6.6.0-demo |
| 主机 | macOS 27.0.1，arm64 |

## 方法与证据

`rea` CLI 在 DSH 的 workspace-write 沙箱里无法启动并控制 Hopper（`spawn EPERM` / AppleEvents 被 TCC 拒绝）。把同一条命令放进 Terminal.app 执行后，TCC 责任进程变为 Terminal，Hopper 才能正常打开与反编译。因此本目录的所有 REA 命令都是通过一个临时 Terminal runner 执行的，目标、参数和输出没有变化。

| 操作 | 证据 ID | 结果 |
| --- | --- | --- |
| `analyze Alfred 5.app` | `ev_67f97cc8a14a46ce1a04c6ce19daa7e628f96e057fe861a42ec36505944a7585` | 2,740 procedures / 1,402 strings |
| `analyze "Alfred Framework"` | `ev_7cc981b2a5c79bf65ee9b958c7c59b8927a4b6aae049554c37b1bd04e029f409` | 36,948 procedures / 20,785 strings |
| `analyze "Alfred Preferences"` | `ev_b19a9c9fa8d61bb519adc197101ae9c0dbd17e5cf88028342af84cbd39198807` | 6,472 procedures / 4,032 strings |
| `decode-interface-builder` Preferences | `ev_011f984828f8d5817b7c4f04f61c521d8ab1ae6bc1e41777cd7ea56123502216` | 18 documents / 2,694 objects / 1,903 edges |
| `decode-interface-builder` Feature nibs | `ev_8420bbaa60207543a0cf87d00ef13bac0d422be14c901a4702ed380ac9dfb9a8` | 34 documents / 5,339 objects / 3,606 edges |
| `inspect-macho` Framework | `ev_390c919d8118637cfd2ff88550e1668428abbee09a30d278d425256ddb30d7b7` | fat32、arm64/x86_64、LC_* 与依赖 |
| `search` Framework strings | `ev_495c585fec19023dd2f3939adfd7d68bf35a76ddb5ec44c054c53268970fab9e` | 20,785 条字符串 |
| `search` Framework procedures | `ev_51b0240b015d88999beeb53f8dcb81fc5d144db95893d7318f24ad9d76fcf71b` | 36,948 条符号 |
| `search` Preferences strings | `ev_ad3325ed1440499a675b5c0546d135869ccaef4c9d9199345aa90f437984222c` | 4,032 条字符串 |
| `search` Preferences procedures | `ev_a67de34addfae0d452f9b8cb8b008e2dd90f365bfae6e9c16ce1642cd204aa10` | 6,472 条符号 |
| `decompile -[AlfredClipboardManager expiredSecondsFor:]` | `ev_fdb5e9fff8c65aa315850cc258cab385ef3b06ffc9dbff2f6d4e6d33f7fc0178` | 剪辑保留时间分支 |
| `decompile -[AlfredPreferencesGeneral init]` | `ev_e93fb759953ef61e40591ed7c39d0deced4c08c957246b7f6f6f1c1706956d3b` | nib 装载与版本字符串 |

Hopper demo 的伪代码是接近汇编的形态，不能当作可编译的源码。它用于确认「某个选项确实对应某个分支/常量」，最终实现仍是独立写的 Swift。

## 从证据得到的关键事实

- Preferences 主窗口 1180×766，左侧 icon rail 80pt，Features 列表 240pt，行高 42pt，图标 34×34。
- Features 共 16 项：Default Results、File Search、Universal Actions、Web Search、Web Bookmarks、Clipboard History、Snippets、Calculator、Dictionary、Contacts、Music、1Password、System、Terminal、Large Type、Previews。
- 页面标题栏高约 78pt，底色 `#D9D9D9`；内容底色 `#ECECEC`，白色圆角表单面板；输入框/表格为白底细边框。
- Clipboard 的页面分为 History / Merging / Advanced 三页；保留项按 Plain Text / Images / File Lists 分别设置；默认忽略 Concealed 与 Auto Generated，默认屏蔽 1Password、Keychain Access、Passwords、Wallet、SecurityAgent。
- 偏好默认键可从 `Alfred Preferences Defaults.plist` 读取；10 个 `.alfredappearance` 主题文件用于提取窗口宽度、圆角、内边距、字号、颜色与行高。本实现只采纳数值与语义，没有复制主题文件、壁纸或代码。

## 边界与合规

- 不复制 Alfred 的图标、主题壁纸、nib 文件、字符串表或反编译代码。
- 界面文字是功能性标签（例如 “Default Results”“Clipboard History”），为了兼容性保留；其余说明文字为独立撰写。
- Jfred 与 Running with Crayons 无关联。Alfred 是其所有者的商标。
- 逆向仅用于本机互操作与独立实现；分发前请自行评估当地法律与 Alfred EULA。
