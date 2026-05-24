# iOS SwiftUI Prototype Visual Audit

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_VISUAL_AUDIT_READY**

---

## 2. 本轮目标

人工校对前视觉审计——逐项检查 38 个 Prototype entry 的页面完整性、可校对性、规则合规性。不修改 Swift 源码，仅产出审计报告和修复队列。

---

## 3. 输入基线

| 文档 | 状态 |
|---|---|
| IOS_SWIFTUI_PROTOTYPE_GALLERY_REPORT.md | READY |
| IOS_SWIFTUI_PROTOTYPE_PREREQ_REPORT.md | READY |
| CROSS_PLATFORM_UI_BASELINE.md | 已读取 |
| CROSS_PLATFORM_ROUTE_MATRIX.md | 已读取 |
| CROSS_PLATFORM_STATE_MATRIX.md | 已读取 |
| CROSS_PLATFORM_READER_CONTROL_SPEC.md | 已读取 |

---

## 4. Prototype Gallery 读取结果

| 项目 | 值 |
|---|---|
| Prototype 文件数 | 3（Entry + GalleryView + Fixtures） |
| Entry 数量 | 38 |
| 分组数量 | 12（appShell / bookshelf / searchDetail / reader / sourceMgmt / discover / rss / webdav / sync / settings / states / debug） |
| Fixture 类型 | 15 个 model struct/enum |
| Theme token 使用 | ReaderColors / ReaderTypography / ReaderSpacing / ReaderShapes / ReaderControlMetrics |

---

## 5. App 主导航审计

| 检查项 | 结果 |
|---|---|
| 主底栏 4 个：书架 / 发现 / 书源 / 我的 | PASS |
| 阅读不在底栏 | PASS |
| 设置不在底栏（归入「我的」） | PASS |
| 搜索不在底栏 | PASS |
| App Shell 有 content switching | PASS |
| 「我的」Tab 包含：设置 / 阅读记录 / 阅读统计 / 收藏 / WebDAV / 同步 / 备份 | PASS |

---

## 6. 38 个 Entry 人工校对清单

| # | 分组 | 页面 | Entry ID | 校对重点 | 预期正确表现 | 风险 |
|---|---|---|---|---|---|---|
| 1 | App/Nav | App Shell / Main Tabs | app-shell | 底栏 4 项是否正确；点击切换内容；阅读/设置/搜索不在底栏 | 书架/发现/书源/我的 4 tab | P0 |
| 2 | Bookshelf | 书架封面模式 | bookshelf-cover | 3 列封面网格、书名、作者、进度条 | 网格布局，每项有封面+书名+作者+进度% | P1 |
| 3 | Bookshelf | 书架列表模式 | bookshelf-list | 列表行、封面缩略图、书名、作者、分组 chip、进度条、最新章节 | 每行含缩略图+书名+分组+进度+最新章节+% | P1 |
| 4 | Bookshelf | 书架空状态 | bookshelf-empty | 空书架图标、引导文案、添加书籍/导入书源按钮 | 居中空状态，两个操作按钮 | P2 |
| 5 | Search/Detail | 搜索首页 | search-home | 搜索框、历史搜索列表 | 搜索框+历史搜索条目 | P1 |
| 6 | Search/Detail | 搜索结果 | search-results | 多来源结果、来源数、作者、简介、加入书架 | 每项显示书名/作者/简介/来源/书源数/加入书架按钮 | P1 |
| 7 | Search/Detail | 搜索空状态 | search-empty | 空结果图标、提示文案、引导换关键词/检查书源 | 居中空状态+换关键词提示+检查书源提示 | P2 |
| 8 | Search/Detail | 搜索错误状态 | search-error | 错误图标、错误信息、重试按钮、书源异常提示 | 错误状态+错误原因+重试+书源异常提示 | P2 |
| 9 | Search/Detail | 书籍详情 | book-detail | 封面、书名、作者、简介、来源、操作按钮 | 封面+书名+作者+来源+更新+简介+开始阅读/加入书架 | P1 |
| 10 | Search/Detail | TOC 预览 | book-detail-toc | 章节列表、当前章节标识、书签标识、目录数量、正序/倒序 | 章节列表+当前指示+书签+章数+排序 | P2 |
| 11 | Reader | 阅读页基础控制层 | reader-base | 正文 fixture、顶栏、亮度条、快捷按钮（无文字标签）、页内控制（本章内语义）、底栏（目录/朗读/界面/设置） | 9 个控制区完整渲染 | P0 |
| 12 | Reader | 搜索 overlay | reader-search | 搜索框、匹配数、匹配列表、上/下一个导航 | 搜索弹窗+结果导航 | P1 |
| 13 | Reader | 自动翻页 overlay | reader-autoscroll | 速度 slider、开始/暂停按钮、模式选择 | 翻页速度控制+模式 | P1 |
| 14 | Reader | 内容替换 overlay | reader-replace | 只显示当前书籍规则、不显示全局规则库、启用/禁用 toggle | 当前书籍规则列表+toggle | P1 |
| 15 | Reader | 夜间状态 | reader-night | 非弹窗、仅状态切换、toast 提示 | ReaderBasePrototype(isNight:true) + toast | P1 |
| 16 | Reader | 目录/书签 overlay | reader-directory | 目录/书签 tab、分级缩进、右侧进度条、书签标识、当前阅读标识 | TOC tab+分级缩进+右侧进度条 | P1 |
| 17 | Reader | 朗读 overlay | reader-tts | 播放/暂停、语速、不使用章节跳转语义 | 朗读控制+明确标注不使用章节跳转 | P2 |
| 18 | Reader | 界面 overlay | reader-appearance | 字体选择、字号 slider、行间距 | 字体/字号/间距控制 | P2 |
| 19 | Reader | 设置 overlay | reader-settings | 不含 WebDAV/书源/RSS、只含阅读行为设置 | 阅读行为设置+明确标注不含 WebDAV/书源/RSS | P1 |
| 20 | Source Mgmt | 书源管理列表 | source-list | 启用/禁用状态、测试状态、分组、搜索 | 列表+启用/禁用+测试状态+分组 | P1 |
| 21 | Source Mgmt | 书源详情 | source-detail | 基本信息、规则摘要（不暴露 parser internals）、测试/编辑/启用操作 | 详情+规则摘要+操作按钮 | P2 |
| 22 | Source Mgmt | 书源编辑/导入 | source-edit-import | 导入成功/失败状态、编辑字段、校验提示 | 成功/失败状态+编辑表单 | P2 |
| 23 | Source Mgmt | 书源测试/禁用/错误 | source-test-error | 测试中、成功、失败、禁用状态 | 多状态展示 | P2 |
| 24 | Discover | 发现首页 | discover-home | 推荐分区、分类/排行、作为主底栏第二项 | 分区标题+横向滚动列表 | P1 |
| 25 | RSS | RSS 列表 | rss-list | 源列表、更新时间、未读数量、启用状态 | RSS 源列表+未读数+状态 | P2 |
| 26 | RSS | RSS 详情 | rss-detail | 文章列表、标题、摘要、时间、已读/未读 | 文章列表+元信息 | P2 |
| 27 | RSS | RSS 订阅管理 | rss-subscriptions | 添加/编辑订阅、启用/禁用 toggle | 订阅列表+启用/禁用+添加 | P2 |
| 28 | WebDAV | WebDAV 配置 | webdav-config | 服务器地址占位、用户名占位、连接状态、不保存真实账号 | 配置表单+连接状态+明确标注不保存真实账号 | P2 |
| 29 | Sync | 备份设置 | backup-settings | 备份范围、手动备份、自动备份开关、最近备份状态 | 备份设置列表+开关+状态 | P2 |
| 30 | Sync | 阅读进度同步 | sync-progress | 本地进度、云端进度、冲突提示 | 本地/云端进度对比+冲突处理 | P2 |
| 31 | WebDAV | 远程 WebDAV 书籍 | remote-webdav-books | 远程目录、书籍列表、下载状态、不接真实 WebDAV | 书籍列表+下载状态 | P2 |
| 32 | Sync | 同步错误/WebDAV auth | sync-error | 认证失败、网络不可达、重试入口 | 错误状态+重试 | P2 |
| 33 | Settings | 全局设置 | global-settings | 归入「我的」、外观/阅读/书架/备份与同步/关于 | 设置列表在 MineTabPrototype 内 | P1 |
| 34 | States | loading 状态页 | state-loading | ProgressView + 加载中文案 | 居中加载指示器 | P2 |
| 35 | States | empty 状态页 | state-empty | 空图标 + 引导操作 | 居中空状态+引导按钮 | P2 |
| 36 | States | error 状态页 | state-error | 错误标题 + 说明 + 重试入口 | 错误状态+重试 | P2 |
| 37 | States | offline 状态页 | state-offline | 离线提示 + 本地缓存提示 | 离线状态+缓存提示 | P2 |
| 38 | States | permission required | state-permission | 权限说明 + 去设置入口 | 权限状态+去设置按钮 | P2 |

---

## 7. 阅读页 10 条规则审计

| # | 规则 | 代码验证 | 结果 |
|---|---|---|---|
| 1 | 快捷按钮无文字标签 | QuickButton struct 只有 Image + accessibilityLabel，无 Text() | PASS |
| 2 | 夜间模式不是弹窗 | ReaderNightStatePrototype 用 ReaderBasePrototype(isNight:true) + toast，无 .sheet/.alert/Dialog | PASS |
| 3 | 内容替换只显示当前书籍规则 | ReaderReplaceOverlayPrototype 标注「仅显示当前书籍匹配规则」 | PASS |
| 4 | 页内控制使用本章内上一页/下一页 | .accessibilityLabel("本章内上一页") / ("本章内下一页") | PASS |
| 5 | 不使用 skip_previous/skip_next | 代码搜索：0 处出现 | PASS |
| 6 | 阅读页底栏设置不包含 WebDAV/书源/RSS | ReaderSettingsOverlayPrototype 标注「不含 WebDAV/书源/RSS」 | PASS |
| 7 | 目录页有分级小字+右侧进度条+书签+当前标识 | ReaderDirectoryOverlayPrototype 含 level 缩进、右侧 Capsule 进度条、bookmark 图标、isCurrent 标识 | PASS |
| 8 | 朗读不使用章节跳转语义 | ReaderTTSOverlayPrototype 标注「不使用章节跳转语义」 | PASS |
| 9 | 亮度条有自动亮度图标+左右停靠箭头 | Brightness bar 含 "circle.lefthalf.filled" + "chevron.right"/"chevron.left" | PASS |
| 10 | 内容替换不能显示全局规则库 | replace overlay 无全局规则列表，仅当前书籍规则 | PASS |

---

## 8. 页面内容完整性审计

### 通过项（信息密度充足）
- App Shell：4 tab + 内容切换 + MineTab 完整
- Bookshelf cover/list/empty：完整 fixture 数据
- Search home/results/empty/error：完整交互
- Book detail + TOC preview：完整内容
- Reader base + 8 overlays：完整控制层
- Source management 4 entries：完整状态覆盖
- Discover home：分区+横向滚动
- State pages 5 entries：完整状态矩阵

### 需改进项（P2）
- **Reader 四角信息**：跨平台基线要求「左上书名、右上电量、左下章节、右下时间」。当前 ReaderBasePrototype 的四角信息分散在 top bar（居中书名）和 meta row（章节名），缺少明确的电量指示和时间显示。建议在 ReaderBasePrototype 的 ZStack 四角添加独立 Text overlay。
- **自动翻页 overlay**：自动翻页图标使用了 "play.fill" 而非阅读规范的 "auto_mode" 语义。建议 quick button icon 使用更明确的自动翻页语义图标。

---

## 9. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| check_ios_boundary.sh | PASS（79 files, 0 violations） |
| 未引用 parser internals | PASS |
| 无 WebView UI | PASS |
| 无真实网络 | PASS |
| 未接真实 WebDAV/RSS/同步 | PASS |
| 未修改 Reader-Core | PASS |

---

## 10. 测试结果

| 命令 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS（79 files, 0 violations） |
| `swift build --target ReaderApp` | 预存 macOS API 错误（非本轮引入） |

---

## 11. 修复队列摘要

| 风险等级 | 数量 |
|---|---|
| P0 | 0 |
| P1 | 0 |
| P2 | 2 |
| P3 | 0 |

详见 `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_FIX_QUEUE.md`

---

## 12. P0 问题

无。

## 13. P1 问题

无。

## 14. 是否建议人工校对

建议进入人工校对。无 P0/P1 阻塞项，38 entries 全部可校对。
