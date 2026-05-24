# iOS SwiftUI Prototype Audit

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_AUDIT_BLOCKED**

阻塞原因：`swift test` 编译失败（`RuntimeContractMapping.swift` 参数顺序错误），存在 1 个 P0 编译错误需先修复。

## 2. 审计范围

本轮只读审计，判断 Reader for iOS 是否具备进入 SwiftUI Prototype Gallery 阶段的条件。

审计内容：
- Reader for iOS 项目结构读取
- 现有 SwiftUI UI 能力评估
- Core / Facade / Boundary 合规性检查
- 跨平台 UI 基线文档对照
- 测试编译状态验证
- Prototype Gallery 可落地性判断

**未执行的操作**：未修改源码、未新增 Swift 文件、未实现 Prototype Gallery、未接真实网络/WebDAV/RSS。

## 3. 读取的跨平台 UI 基线文档

所有文档均位于 `/Users/minliny/Documents/Reader-Core/docs/cross-platform-ui/`，通过 iOS 项目的 `Reader-Core` symlink 可访问：

| # | 文档 | 路径 | 状态 |
|---|---|---|---|
| 1 | Cross Platform UI Baseline | `Reader-Core/docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md` | READ |
| 2 | Cross Platform Route Matrix | `Reader-Core/docs/cross-platform-ui/CROSS_PLATFORM_ROUTE_MATRIX.md` | READ |
| 3 | Cross Platform State Matrix | `Reader-Core/docs/cross-platform-ui/CROSS_PLATFORM_STATE_MATRIX.md` | READ |
| 4 | Cross Platform Reader Control Spec | `Reader-Core/docs/cross-platform-ui/CROSS_PLATFORM_READER_CONTROL_SPEC.md` | READ |
| 5 | Cross Platform Component Mapping | `Reader-Core/docs/cross-platform-ui/CROSS_PLATFORM_COMPONENT_MAPPING.md` | READ |
| 6 | iOS SwiftUI Mapping | `Reader-Core/docs/cross-platform-ui/IOS_SWIFTUI_MAPPING.md` | READ |
| 7 | Cross Platform UI Reuse Report | `Reader-Core/docs/cross-platform-ui/CROSS_PLATFORM_UI_REUSE_REPORT.md` | READ |

结论：跨平台基线完整、就绪，可直接作为 iOS SwiftUI Prototype Gallery 的唯一真源。

## 4. Reader for iOS 项目结构读取结果

### 4.1 已发现的关键目录/文件

| 路径 | 类型 | 状态 |
|---|---|---|
| `iOS/Package.swift` | SPM 配置 | 存在，4 target + 4 testTarget |
| `iOS/App/ReaderApp.swift` | App 入口 | 存在，`@main` + TabView + NavigationStack |
| `iOS/App/AppEntry.swift` | App 元数据 | 存在 |
| `iOS/App/Persistence/` | 持久化层 | 存在，5 个 Store 类 |
| `iOS/AppSupport/Sources/` | DTO/模型 | 存在，7 个类型 |
| `iOS/CoreBridge/` | Core 桥接层 | 存在，8 个文件（facade + mock + error + state） |
| `iOS/CoreIntegration/` | Core 集成 | 存在，6 个文件（service adapters + coordinator + repository） |
| `iOS/Shell/` | Shell 组装 | 存在，ShellAssembly + ReaderShellEnvironment |
| `iOS/Navigation/` | 导航 | 存在，Route enum (9 routes) + AppNavigationState |
| `iOS/Surface/` | 状态页 | 存在，AppLoadingSurface + AppErrorSurface + AppEmptySurface |
| `iOS/Modules/Reader/` | 模块边界 | 存在，ReaderModuleBoundary |
| `iOS/Features/Bookshelf/` | 书架 | 存在，View + ViewModel + RowView |
| `iOS/Features/Search/` | 搜索 | 存在，View + ViewModel + RowView |
| `iOS/Features/BookDetail/` | 书籍详情 | 存在，View + ViewModel |
| `iOS/Features/Reader/` | 阅读页 | 存在，10 个文件（View + ViewModel + 子组件） |
| `iOS/Features/BookSources/` | 书源管理 | 存在，View + ViewModel + ImportView + RowView |
| `iOS/Features/TOC/` | 目录 | 存在，TOCView |
| `iOS/Features/WebDAV/` | WebDAV | 存在，View + ViewModel + Keychain + Exporter |
| `iOS/Features/FileImporter/` | 文件导入 | 存在，View + ViewModel |
| `iOS/Features/Debug/` | Debug 工具 | 存在，WebView Harness |
| `iOS/Tests/ReaderAppTests/` | App 测试 | 存在 |
| `iOS/Tests/ShellSmokeTests/` | Shell 冒烟测试 | 存在，6 个测试文件 |
| `iOS/Tests/ReaderAppPersistenceTests/` | 持久化测试 | 存在 |
| `iOS/Tests/Fixtures/` | 测试 fixture | 存在 |
| `scripts/check_ios_boundary.sh` | 边界检查 | 存在 |
| `docs/PLANNING/READER_IOS_CORE_BOUNDARY_RULES.md` | 边界规则文档 | 存在 |

### 4.2 未发现的关键目录/文件

| 路径 | 预期用途 | 状态 |
|---|---|---|
| `docs/ui-handoff/` | UI handoff 文档 | **不存在**（本轮已创建 `docs/ui-handoff/ios/`） |
| `iOS/Features/Discover/` | 发现页 | **不存在** |
| `iOS/Features/RSS/` | RSS 页 | **不存在** |
| `iOS/Features/Settings/` | 全局设置页 | **不存在** |
| `iOS/Features/Prototype/` | Prototype Gallery | **不存在** |
| `iOS/Theme/` | Theme/Token 系统 | **不存在** |
| `iOS/App/Preview Content/` | SwiftUI Preview | **不存在** |
| `iOS/Tests/PrototypeTests/` | Prototype 测试 | **不存在** |

## 5. 当前 iOS UI 能力现状

### 5.1 SwiftUI View 覆盖

| 模块 | 现有 View | 完整度 | 备注 |
|---|---|---|---|
| App Shell | `ReaderApp` + `RootShellView` | 70% | 有 TabView + NavigationStack，但仅 3 tab |
| Bookshelf | `BookshelfView` + `BookshelfItemRowView` | 60% | 仅列表模式，无封面模式、空状态组件化、分组管理 |
| Search | `SearchView` + `SearchResultRowView` | 50% | 基础搜索，无首页/loading/empty/error 状态分离 |
| Book Detail | `BookDetailView` | 40% | 基础详情，无 TOC 预览、换源结果 |
| Reader | `ReaderView` + 6 个子组件 | 30% | 有基础阅读，但**无 9 控制层状态、无 overlay 系统** |
| Source Management | `BookSourceListView` + `BookSourceImportView` | 50% | 基础列表+导入，无详情/编辑/测试 |
| TOC | `TOCView` | 40% | 基础目录，无书签/分级/右侧进度条 |
| WebDAV | `WebDAVSettingsView` | 30% | 基础配置，无远程书籍/备份/同步进度 |
| Discover | — | 0% | **未实现** |
| RSS | — | 0% | **未实现** |
| Global Settings | — | 0% | **未实现** |
| State Pages | `AppLoadingSurface` + `AppErrorSurface` + `AppEmptySurface` | 40% | 有 3 个 Surface，但无 offline/permission |
| Debug | `WebViewRuntimeHarnessView` | 100% | 已有，Prototype Gallery 可复用此模式 |

### 5.2 Theme / Token 现状

| 项目 | 状态 |
|---|---|
| ReaderColors token | **不存在**，使用 ad-hoc `Color(hex:)` 和 `UIColor.secondarySystemGroupedBackground` |
| ReaderTypography | **不存在**，使用 `.font(.subheadline)` 等语义字体 |
| ReaderSpacing | **不存在**，使用硬编码 padding 值 |
| ReaderShapes | **不存在**，使用内联 `RoundedRectangle(cornerRadius:)` |
| Color+PlatformCompat | 存在，仅 `Color(hex:)` 扩展 |
| ReaderDisplaySettings (AppSupport) | 存在，字体/间距/背景色等阅读显示设置 |

### 5.3 Route 现状

| 项目 | 已有 | 基线需求 | 差距 |
|---|---|---|---|
| Route enum cases | 9 | 30 | -21 |
| NavigationStack | 有 | 有 | 满足 |
| TabView tabs | 3 (Home/Bookshelf/Search) + Settings | 5 (书架/搜索/发现/书源/设置) | -2 tab |
| Deep link | 无 | 3 patterns | 缺失 |

### 5.4 State 模型现状

| 项目 | 已有 | 基线需求 | 差距 |
|---|---|---|---|
| LoadState enum | 有 (7 cases: idle/loading/loaded/empty/failed/unsupported/partial) | 12 states | 基线上比现有多了 5 种专门 state |
| AppReaderError | 有 (10 codes) | — | 良好 |
| ReaderControlState | **不存在** | 9 states | **完全缺失** |
| QuickActionType | **不存在** | 3 types | **完全缺失** |
| BottomFunctionType | **不存在** | 4 types | **完全缺失** |
| BrightnessDock | **不存在** | 2 positions | **完全缺失** |

### 5.5 Fixture / Mock / Preview 现状

| 项目 | 状态 |
|---|---|
| MockReaderCoreService | 存在，8 种 scenario + 3 组 fixture 数据 |
| MockSearchService / MockTOCService / MockContentService | 存在（ShellAssembly 中） |
| ReaderPrototypeFixtures (Android 对应) | **不存在** |
| SwiftUI Preview | **不存在**（无 Preview Content 目录） |
| Debug-only entry | 存在（WebView Harness toolbar item），可复用模式 |

## 6. Core / Facade / Boundary 现状

### 6.1 架构合规

| 检查项 | 结果 |
|---|---|
| 是否通过 `ReaderCoreServiceProvider` facade 访问 Core | **是** |
| 是否直接 import `ReaderCoreParser` | **否**（边界检查 PASS） |
| 是否直接 import `ReaderCoreNetwork` | **否**（边界检查 PASS） |
| 是否直接引用 `NonJSRuleScheduler` / `NonJSParserEngine` / `SelectorEngine` | **否** |
| 是否复制 Legado Android 代码 | **否** |
| 是否通过 SPM package dependency 引入 Reader-Core | **是** |
| 是否在 App target 中重复编译 Core Sources | **否** |

### 6.2 边界检查执行结果

```
命令: bash scripts/check_ios_boundary.sh
结果: PASS
checked_files: 67
violations: 0
```

### 6.3 Facade 能力

`ReaderCoreServiceProvider` 提供：
- `searchBooks(keyword:page:source:)` → `LoadState<[SearchResultItem]>`
- `getBookDetail(bookURL:source:)` → `LoadState<SearchResultItem>`
- `getChapterList(bookURL:)` → `LoadState<[TOCItem]>`
- `getChapterContent(chapterURL:)` → `LoadState<ContentPage>`
- `validateBookSource(from:)` → `LoadState<BookSource>`
- Mock/Real 模式切换

对于 Prototype Gallery 阶段，现有 facade 能力**已足够**（所有 prototype entry 使用 mock mode + fixture 数据）。

## 7. Prototype Gallery 可落地性判断

### 7.1 有利条件

1. **Core bridge facade 成熟**：`ReaderCoreServiceProvider` + `MockReaderCoreService` 已实现 mock/real 切换
2. **Surface 组件已有**：`AppLoadingSurface`, `AppErrorSurface`, `AppEmptySurface` 可直接复用
3. **NavigationStack 已就绪**：`Route` enum + `AppNavigationState` + `NavigationStack` path
4. **Debug entry 模式已有**：`WebViewRuntimeHarnessView` 通过 `#if DEBUG` toolbar item 入口
5. **边界检查通过**：0 violations，Core internals 无泄漏
6. **现有 screen 可直接作为基线**：BookshelfView, ReaderView, SearchView 等已实现基础骨架
7. **跨平台基线完整**：7 份文档覆盖所有 token/route/state/component/control/交互/无障碍

### 7.2 需要先补充的基础层

| 优先级 | 项目 | 说明 |
|---|---|---|
| **P0** | 修复 `RuntimeContractMapping.swift` 编译错误 | `swift test` 当前无法通过 |
| **P0** | 创建 `ReaderTheme` / `ReaderColors` / `ReaderTypography` / `ReaderSpacing` / `ReaderShapes` | Prototype Gallery 依赖统一 token |
| **P0** | 扩展 `Route` enum + `AppNavigationState` 以匹配 30 条跨平台路由 | 新 screen 需要路由 |
| **P0** | 创建 `ReaderControlState` / `QuickActionType` / `BottomFunctionType` 枚举 | Reader screen 控制层基础 |
| P1 | 创建 `iOS/Features/Prototype/` 目录 + `ReaderPrototypeGallery.swift` | Gallery 入口 |
| P1 | 创建 `ReaderPrototypeFixtures.swift` | 38 个 entry 的 fixture 数据 |
| P1 | 创建 `iOS/Features/Discover/`, `iOS/Features/RSS/`, `iOS/Features/Settings/` | 新模块目录 |
| P1 | 扩展 `ReaderView` 为 ZStack overlay 层叠结构 | 9 控制状态 |
| P1 | 创建 8 个 reader overlay View | 搜索/自动翻页/替换/目录/朗读/界面/设置/夜间 |

## 8. 38 个 Prototype Entry 覆盖准备度

| # | 分组 | 页面 | 现有基础 | 需新增的 SwiftUI 类型 | 风险 | 备注 |
|---|---|---|---|---|---|---|
| 1 | App/Nav | App Shell / Main Tabs | `ReaderApp` + `RootShellView` | 扩展 TabView 到 5 tabs | 低 | 改现有文件 |
| 2 | Bookshelf | 书架封面模式 | `BookshelfView` (仅列表) | `BookshelfCoverGrid` | 低 | 新增 View |
| 3 | Bookshelf | 书架列表模式 | `BookshelfView` | 提取 `BookshelfListView` | 低 | 重构现有 |
| 4 | Bookshelf | 书架空状态 | `BookshelfView` 内联空状态 | 使用 `AppEmptySurface` | 低 | 复用现有 |
| 5 | Search | 搜索首页 | `SearchView` | `SearchHomeView` | 低 | 重构现有 |
| 6 | Search | 搜索结果 | `SearchView` 当前实现 | `SearchResultsView` | 低 | 重构现有 |
| 7 | Search | 搜索空状态 | 无 | `SearchEmptyView` / `AppEmptySurface` | 低 | 复用 Surface |
| 8 | Search | 搜索错误状态 | 无 | `SearchErrorView` / `AppErrorSurface` | 低 | 复用 Surface |
| 9 | Search | 书籍详情 | `BookDetailView` | 扩展 TOC 预览 + 换源 | 中 | 扩展现有 |
| 10 | Search | 书籍详情 TOC 预览 | `TOCView` | 内嵌 TOC 预览 | 低 | 复用现有 |
| 11 | Reader | 基础控制层 | `ReaderView` (完全不同结构) | 全新 `ReaderScreen` ZStack 层叠 | **高** | Reader 重构最大 |
| 12 | Reader | 搜索 overlay | 无 | `ReaderSearchOverlay` | 中 | 新增 overlay |
| 13 | Reader | 自动翻页 overlay | 无 | `ReaderAutoScrollOverlay` | 中 | 新增 overlay |
| 14 | Reader | 内容替换 overlay | 无 | `ReaderReplaceOverlay` | 中 | 新增 overlay |
| 15 | Reader | 夜间状态 | `ReaderDisplaySettings.backgroundMode` | `NightState` token 切换 | 低 | 非 overlay |
| 16 | Reader | 目录/书签 overlay | `TOCView` | `ReaderDirectoryOverlay` + 书签 tab | 中 | 需扩展 |
| 17 | Reader | 朗读 overlay | `ReaderTTSControlView` | `ReaderTtsOverlay` | 中 | 需重构 |
| 18 | Reader | 界面 overlay | `ReaderSettingsPanel` | `ReaderAppearanceOverlay` | 低 | 可复用 |
| 19 | Reader | 设置 overlay | 无 | `ReaderSettingsOverlay` | 低 | 新增 overlay |
| 20 | Source | 书源管理列表 | `BookSourceListView` | 扩展状态行 | 低 | 扩展现有 |
| 21 | Source | 书源详情 | 无 | `SourceDetailView` | 低 | 新增 View |
| 22 | Source | 书源编辑/导入 | `BookSourceImportView` | `SourceEditView` | 低 | 扩展现有 |
| 23 | Source | 书源测试/禁用/错误 | 无 | `SourceTestResultView` + `SourceDisabledErrorView` | 低 | 新增 View |
| 24 | Discover | 发现首页 | **无** | `DiscoverHomeView` | 低 | 新增模块 |
| 25 | RSS | RSS 列表 | **无** | `RssListView` | 低 | 新增模块 |
| 26 | RSS | RSS 详情 | **无** | `RssDetailView` | 低 | 新增模块 |
| 27 | RSS | RSS 订阅管理 | **无** | `RssSubscriptionManagementView` | 低 | 新增模块 |
| 28 | WebDAV | WebDAV 配置 | `WebDAVSettingsView` | 扩展状态卡片 | 低 | 扩展现有 |
| 29 | WebDAV | 备份设置 | 无 | `BackupSettingsView` | 低 | 新增 View |
| 30 | WebDAV | 阅读进度同步状态 | 无 | `ProgressSyncStatusView` | 低 | 新增 View |
| 31 | WebDAV | 远程 WebDAV 书籍 | 无 | `RemoteWebDavBooksView` | 低 | 新增 View |
| 32 | WebDAV | 同步错误/WebDAV auth error | 无 | `SyncErrorView` / `AppErrorSurface` | 低 | 复用 Surface |
| 33 | Settings | 全局设置 | **无** | `GlobalSettingsView` | 低 | 新增模块 |
| 34 | States | loading 状态页 | `AppLoadingSurface` | 直接复用 | 低 | 已有 |
| 35 | States | empty 状态页 | `AppEmptySurface` | 直接复用 | 低 | 已有 |
| 36 | States | error 状态页 | `AppErrorSurface` (依赖 ReaderError) | 泛化为 `ReaderUiState` | 低 | 扩展现有 |
| 37 | States | offline 状态页 | 无 | `OfflineStateView` | 低 | 新增 Surface |
| 38 | States | permission required | 无 | `PermissionRequiredView` | 低 | 新增 Surface |

统计：
- 无需新增（直接复用）：3 (loading/empty/error)
- 低风险：25
- 中风险：9
- **高风险：1 (Reader screen 重构)**

## 9. 阅读页 10 条规则映射审计

| # | 规则 | 基线中存在 | iOS 是否可映射 | 是否存在歧义 | 是否阻塞 |
|---|---|---|---|---|---|
| 1 | 快捷按钮无文字标签 | 是 (CROSS_PLATFORM_READER_CONTROL_SPEC.md §7) | 是 — 仅 Image + `.accessibilityLabel()` | 否 | 否 |
| 2 | 夜间模式不是弹窗，只切换日/夜状态 | 是 (§5) | 是 — `@EnvironmentObject theme.isNightMode.toggle()` | 否 | 否 |
| 3 | 内容替换只显示当前书籍匹配规则 | 是 (§12) | 是 — fixture 限定当前书籍 | 否 | 否 |
| 4 | 浮动页内控制是本章内上一页/下一页 | 是 (§6) | 是 — `onPreviousPage()` / `onNextPage()` 限定本章 | 否 | 否 |
| 5 | 不使用 skip_previous/skip_next 语义 | 是 (§6) | 是 — 语义层面约束 | 否 | 否 |
| 6 | 阅读页底栏设置不包含 WebDAV/书源/RSS | 是 (§8) | 是 — 底栏 4 按钮不含这些 | 否 | 否 |
| 7 | 目录页有目录/书签、分级小字、右侧常驻进度条、书签标识、当前阅读标识 | 是 (§13) | 是 — SegmentedControl + 自定义缩进 + overlay 进度条 | `reader-toc-level-1~4` 缩进值需精确映射 | 否 |
| 8 | 朗读内部不使用章节跳转语义 | 是 (§14) | 是 — 语义层面约束 | 否 | 否 |
| 9 | 亮度条有自动亮度图标和左右停靠箭头 | 是 (§5) | 是 — SF Symbol `circle.lefthalf.filled` + `chevron.left/right` | 垂直 slider 需自定义实现 | 否 |
| 10 | 内容替换不能显示全局规则库 | 是 (BASELINE §5.3) | 是 — fixture 仅含当前书籍规则 | 否 | 否 |

**结论**：10 条规则全部可在 iOS SwiftUI 中映射，无阻塞项。

## 10. 测试 / Boundary 命令审计

### 10.1 已执行命令

| 命令 | 结果 | 备注 |
|---|---|---|
| `bash scripts/check_ios_boundary.sh` | **PASS** | 67 files, 0 violations |
| `cd iOS && swift test` | **FAIL (编译错误)** | `RuntimeContractMapping.swift:66:13` 参数顺序错误 |
| `git status --short` | 干净（仅 settings.local.json 修改 + 2 未跟踪文件） | 无未分类 diff |
| `git log --oneline -5` | 最近提交为 WebView runtime 相关 | 正常 |

### 10.2 可用但未执行的命令

| 命令 | 用途 |
|---|---|
| `xcodebuild -list -project ReaderForIOS.xcodeproj` | 列出 scheme |
| `xcodebuild build -project ... -scheme ReaderForIOSApp -destination '...'` | iOS 构建验证 |
| `swift test --list-tests` | 列出所有测试 |

### 10.3 编译错误详情

```
iOS/CoreBridge/RuntimeContractMapping.swift:66:13:
error: argument 'snapshot' must precede argument 'errorCode'

iOS/CoreBridge/RuntimeContractMapping.swift:74:47:
error: argument 'snapshot' must precede argument 'errorCode'
```

原因：`RuntimeResult` 初始化器中 `snapshot` 参数必须在 `errorCode` 之前，但调用处参数顺序相反。此为 Swift 6 语言模式下参数顺序检查。

## 11. P0 问题

| # | 问题 | 影响 | 修复方式 |
|---|---|---|---|
| 1 | `swift test` 编译失败 (`RuntimeContractMapping.swift`) | 阻塞所有测试运行，阻塞 CI | 调整 `RuntimeResult` 初始化参数顺序，将 `snapshot` 移到 `errorCode` 之前 |

## 12. P1 问题

| # | 问题 | 影响 | 修复方式 |
|---|---|---|---|
| 1 | 无 `ReaderTheme`/`ReaderColors`/`ReaderTypography`/`ReaderSpacing` token 系统 | Prototype Gallery 无法使用统一设计 token | 创建 `iOS/Theme/` 目录，按 `IOS_SWIFTUI_MAPPING.md` §2 实现 |
| 2 | 无 `ReaderControlState` 模型 | Reader screen 控制层无法实现 | 按 `CROSS_PLATFORM_STATE_MATRIX.md` §4.1 创建 |
| 3 | `Route` enum 仅 9 条路由（基线 30 条） | Discover/RSS/Settings 等新模块无法导航 | 扩展 Route enum |
| 4 | `ReaderView` 结构与跨平台基线不匹配 | 阅读页控制层 9 状态无法实现 | 重构为 ZStack overlay 层叠（见 `CROSS_PLATFORM_READER_CONTROL_SPEC.md` §1） |
| 5 | 无 `docs/ui-handoff/` 目录 | 无 iOS 侧 UI handoff 文档位置 | 已创建 `docs/ui-handoff/ios/` |

## 13. P2 / P3 建议

| # | 建议 | 说明 |
|---|---|---|
| 1 | 创建 `iOS/Features/Prototype/` 目录 | 仿 Android `ReaderPrototypeGallery` 模式 |
| 2 | 添加 SwiftUI Preview 支持 | `Preview Content` + `#Preview` macro，加速 UI 校对 |
| 3 | 创建 `ReaderPrototypeFixtures` | 38 个 entry 的 fixture 数据集 |
| 4 | 添加 `prototype` scheme/target | debug-only，不进入 release |
| 5 | 添加 static rendering test | 每个 prototype entry 验证不崩溃 |
| 6 | 添加 no-network / no-WebView guard test | 确保 prototype 不触发网络或 WebView |
| 7 | 将 Surface 组件泛化为 `ReaderUiState` 驱动 | 统一 error/empty/loading/offline/permission 状态渲染 |

## 14. 下一阶段实施计划

按低风险顺序排列：

### Phase 0 — 修复 P0 编译错误（必须先完成）

1. 修复 `RuntimeContractMapping.swift` 中 `RuntimeResult` 参数顺序
2. 验证 `swift test` 全部通过（预期 ~40+ tests）

### Phase 1 — Theme Token 基础

1. 创建 `iOS/Theme/` 目录
2. `ReaderColors.swift` — 14 个 light token + 14 个 night token
3. `ReaderTypography.swift` — 6 个 font token
4. `ReaderSpacing.swift` — 6 个 spacing token
5. `ReaderShapes.swift` — 4 个 shape token
6. `ReaderThemeManager.swift` — `@Observable` class + `@Environment` 注入

### Phase 2 — State Model 基础

1. 创建 `ReaderUiState` enum（12 cases）
2. 创建 `ReaderControlState` + `QuickActionType` + `BottomFunctionType` + `BrightnessDock`
3. 扩展 `Route` enum 到 30 cases
4. 更新 `AppNavigationState` 支持新路由

### Phase 3 — Fixture 模型

1. 创建 `ReaderPrototypeFixtures` — 38 个 entry 的 fixture 数据集
2. 为每个 screen 创建独立 fixture struct
3. 确保 fixture 不含真实 URL/token/secret

### Phase 4 — Component Skeleton

1. 创建通用组件：`ReaderCard`, `ReaderListRow`, `ReaderSearchBox`, `ReaderSettingsRow`, `ReaderSwitchRow`, `ReaderSourceChip`
2. 所有组件使用 ReaderTheme token，不接受 ad-hoc 颜色
3. 所有图标使用语义 token 名

### Phase 5 — Prototype Gallery Entry

1. 创建 `iOS/Features/Prototype/ReaderPrototypeGallery.swift` — debug-only 入口
2. 创建 `iOS/Features/Prototype/ReaderPrototypeCatalog.swift` — 可滚动 catalog
3. 逐个接入 38 个 entry，每个 entry 使用 fixture 数据
4. Reader screen 优先实现（最高风险）

### Phase 6 — Static Rendering Test

1. 创建 `iOS/Tests/PrototypeTests/` 目录
2. 每个 prototype entry 的 static rendering smoke test
3. 验证不崩溃、关键元素存在

### Phase 7 — Boundary / No-Network / No-WebView 检查

1. 创建 `scripts/check_ios_prototype_boundary.sh`
2. 检查 prototype 目录无 `import WebKit`
3. 检查 prototype 目录无 `URLSession` / 网络调用
4. 检查 prototype 目录无真实 WebDAV/RSS URL

### Phase 8 — 报告生成

1. 输出 `IOS_PROTOTYPE_GALLERY_REPORT.md`
2. 覆盖 38 个 entry 的通过状态
3. Accessibility 检查结果

## 15. 是否建议进入 SwiftUI Prototype Gallery 开发

**暂不建议进入。**

原因：
1. **P0 编译错误**：`swift test` 当前无法通过，需先修复 `RuntimeContractMapping.swift`
2. **Theme Token 系统完全缺失**：Prototype Gallery 依赖统一 token，当前全部是 ad-hoc 样式
3. **ReaderControlState 完全缺失**：38 个 entry 中最核心的阅读页控制层（11 个 entry）需要此模型

建议：完成 Phase 0（修复编译错误）+ Phase 1（Theme Token）+ Phase 2（State Model）后，再正式进入 Prototype Gallery 开发。这三个 Phase 预计工作量小（<10 个新文件），完成后 `IOS_SWIFTUI_PROTOTYPE_AUDIT` 可升级为 `READY`。

---

*审计时间：2026-05-23*
*审计类型：只读审计（未修改源码）*
*跨平台基线状态：CROSS_PLATFORM_UI_BASELINE_READY*
