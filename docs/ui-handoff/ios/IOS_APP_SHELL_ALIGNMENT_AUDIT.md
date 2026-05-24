# iOS App Shell Alignment Audit

## 1. 总体结论

**IOS_APP_SHELL_ALIGNMENT_AUDIT_READY**

## 2. 本轮目标

本轮只做生产 App Shell 对齐审计与实施计划。不修改 Swift 源码，不做 GUI 操作，不实装。

## 3. 输入状态

| 文档 | 来源 | 状态 |
|---|---|---|
| `IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_CLOSURE_REPORT.md` | Reader for iOS | 已读取 |
| `IOS_SWIFTUI_PROTOTYPE_MANUAL_SCREENSHOT_REPORT.md` | Reader for iOS | 已读取 |
| `IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_INDEX.md` | Reader for iOS | 已读取 |
| `IOS_SWIFTUI_PROTOTYPE_DEBUG_ENTRY_REPORT.md` | Reader for iOS | 已读取 |
| `IOS_SWIFTUI_PROTOTYPE_BUILD_P0_FIX_REPORT.md` | Reader for iOS | 已读取 |
| `CROSS_PLATFORM_UI_BASELINE.md` | Reader-Core | 已读取 |
| `CROSS_PLATFORM_ROUTE_MATRIX.md` | Reader-Core | 已读取 |
| `CROSS_PLATFORM_STATE_MATRIX.md` | Reader-Core | 已读取 |
| `CROSS_PLATFORM_COMPONENT_MAPPING.md` | Reader-Core | 已读取 |
| `IOS_SWIFTUI_MAPPING.md` | Reader-Core | 已读取 |
| `CROSS_PLATFORM_UI_REUSE_REPORT.md` | Reader-Core | 已读取 |

## 4. 当前生产 App Shell 结构

### 4.1 定义位置

`iOS/App/ReaderApp.swift`，`RootShellView` struct（lines 63-169）。

### 4.2 当前底栏

| Tab 序号 | 标签 | SF Symbol | SwiftUI View | 备注 |
|---|---:|---|---|---|
| 0 | Home | `house` | `ReaderFlowFeatureView` (in `NavigationStack`) | 阅读流功能状态卡片，非独立页面 |
| 1 | Bookshelf | `books.vertical` | `BookshelfView()` | 书架 |
| 2 | Search | `magnifyingglass` | `NavigationStack { SearchView() }` | 搜索作为一级底栏 |
| 3 | Settings | `gearshape` | `NavigationStack { WebDAVSettingsView() }` | 设置以 WebDAV 为默认页，作为一级底栏 |

### 4.3 Debug-only toolbar 入口

在 Tab 0 (Home) 的 toolbar 中，`#if DEBUG` 包裹：
- `[DEBUG] Prototype Gallery` → `PrototypeGalleryView()`
- `WebView Harness` → `WebViewRuntimeHarnessView()`

### 4.4 当前 Route 支持

`Route.swift` 已定义 `prototypeGallery`、`bookshelf`、`bookSources`、`discover`、`settings` 等路由，但 `destinationView` switch 未覆盖全部。

### 4.5 当前缺少的 View

生产代码中不存在：
- `MineTabView`（"我的" 壳页面）
- `DiscoverHomeView`（发现首页，生产版）
- 正式 `SourceManagementView`（书源管理壳）

Prototype Gallery 中存在参考实现：
- `AppShellPrototype`（4 tab: 书架/发现/书源/我的）
- `MineTabPrototype`（含设置、WebDAV、同步、备份入口）
- `DiscoverHomePrototype`、`SourceListPrototype`

## 5. 与目标主导航的差异

### 5.1 对比表

| 维度 | 当前生产 | 跨平台基线 | 目标 (用户指定) |
|---|---|---|---|
| Tab 数量 | 4 | **5** | **4** |
| Tab 1 | Home | 书架 | 书架 |
| Tab 2 | Bookshelf | 搜索 | 发现 |
| Tab 3 | Search | 发现 | 书源 |
| Tab 4 | Settings | 书源 | 我的 |
| Tab 5 | — | 设置 | — |
| 搜索归属 | 一级底栏 | 一级底栏 | 非底栏（从书架/发现进入） |
| 设置归属 | 一级底栏 | 一级底栏 | 非底栏（归入"我的"） |

### 5.2 关键差异

**差异 1：Tab 数量与跨平台基线不一致**

跨平台基线 (`CROSS_PLATFORM_UI_BASELINE.md` §3.1, `CROSS_PLATFORM_ROUTE_MATRIX.md` §2) 定义 **5 tabs**: 书架/搜索/发现/书源/设置。

用户目标为 **4 tabs**: 书架/发现/书源/我的。

这不是错误——"4 tabs" 将搜索和设置从一级底栏降级，合并搜索到书架+发现，合并设置到"我的"。用户明确要求「搜索不是主底栏」「设置不是主底栏」，这与当前 iOS 生产环境 (`iOS_SWIFTUI_MAPPING.md` §3.3) 中的 5-tab 代码模板不同。

**风险**：如果后续 HarmonyOS / Android 保持 5 tabs，iOS 4 tabs 会造成跨平台不一致。需要在进入实装前明确是否接受此差异。

**差异 2：Tab 0 是 "Home" 而非 "书架"**

当前 Tab 0 是 `ReaderFlowFeatureView`（阅读流功能状态卡片），不是书架。

**差异 3：Tab 3 是 "Settings" 而非 "我的"**

当前 Tab 3 直接进入 `WebDAVSettingsView`，而非包含设置、备份、同步、关于的综合"我的"页面。

**差异 4：搜索是独立一级底栏**

当前 Search 是 Tab 2，目标将其降级为非底栏入口。

### 5.3 风险矩阵

| 差异 | 风险等级 | 说明 |
|---|---|---|
| 4-tab vs 5-tab 跨平台 | 中 | 需确认是否接受 iOS 独立决策，或需对齐跨平台基线 |
| Tab 0 从 Home 改为 书架 | 低 | 纯 UI 重组，`BookshelfView` 已存在 |
| Tab 3 从 Settings 改为 我的 | 低 | 需新增 `MineTabView`，Prototype 已有参考 |
| 搜索从一级降级 | 低 | `SearchView` 已存在，改为从其他页面 push |
| 发现、书源为新增 Tab | 中 | 需要生产级 Shell 页面 |

## 6. 目标 App Shell 内容规划

### 6.1 书架 (Tab 0)

| 项目 | 内容 |
|---|---|
| 职责 | 用户书架主视图，展示已收藏/导入的书籍 |
| 主要 View | `BookshelfView`（已存在） |
| 入口 | 书架封面/列表切换、书籍详情、阅读页 |
| 搜索入口 | 顶部 search bar 或 toolbar 搜索按钮 → push SearchView |
| 导入入口 | 添加书籍按钮 → FileImportView |
| 不允许 | 不接真实网络；不混入 WebView Harness entry |
| 后续 | 真实数据接入后对接 `BookshelfStore` / `ReadingProgressStore` |

### 6.2 发现 (Tab 1)

| 项目 | 内容 |
|---|---|
| 职责 | 内容发现：推荐、分类、排行、RSS |
| 主要 View | `DiscoverHomeView`（需新建生产 Shell，Prototype 有参考） |
| 入口 | 搜索、RSS 列表、书籍详情 |
| 搜索入口 | 顶部 search bar → push SearchView |
| 不允许 | 不接真实网络；不暴露 parser internals |
| 后续 | 真实推荐/排行 API 接入 |

### 6.3 书源 (Tab 2)

| 项目 | 内容 |
|---|---|
| 职责 | 书源管理：列表、导入、编辑、测试状态 |
| 主要 View | `SourceManagementView`（需新建 Shell，`BookSourceListView` 已存在） |
| 入口 | 书源列表、书源详情、书源导入、书源编辑、测试结果 |
| 不允许 | 不暴露 parser internals；不接真实网络验证书源 |
| 后续 | 真实书源验证结果展示 |

### 6.4 我的 (Tab 3)

| 项目 | 内容 |
|---|---|
| 职责 | 个人中心：设置、备份、同步、WebDAV、关于、调试入口 |
| 主要 View | `MineTabView`（需新建生产版，Prototype `MineTabPrototype` 有参考） |
| 个人区 | 设置、阅读记录、阅读统计、收藏/书签 |
| 备份区 | WebDAV 配置、备份设置、同步进度 |
| Debug 区 | `#if DEBUG`: `[DEBUG] Prototype Gallery`、WebView Harness |
| 不允许 | 不将设置作为一级底栏；不保存真实账号/token |
| 后续 | 真实 WebDAV 连接、同步 |

## 7. 搜索 / 阅读 / 设置归属规划

### 7.1 搜索

**不作为一级底栏。**

| 入口位置 | 方式 |
|---|---|
| 书架顶部 | Toolbar search button / search bar |
| 发现顶部 | Toolbar search button / search bar |
| 全局 | `.searchable()` modifier 或 NavigationLink → SearchView |

`SearchView`（已存在）作为 push destination，不从 TabView 直接进入。

### 7.2 阅读

**不作为一级底栏。**

| 入口位置 | 方式 |
|---|---|
| 书架 → 书籍点击 | `NavigationLink` → ReaderView |
| 搜索 → 书籍详情 → 开始阅读 | push ReaderView |
| 最近阅读 | 从"我的"阅读记录 → ReaderView |
| 远程书籍 | WebDAV 书籍 → ReaderView |

### 7.3 设置

**不作为一级底栏。归入"我的" Tab。**

| 入口位置 | 方式 |
|---|---|
| 我的 → 设置 | NavigationLink → GlobalSettingsView |
| 我的 → WebDAV 备份 | NavigationLink → WebDAVSettingsView |
| 我的 → 备份设置 | NavigationLink → BackupSettingsView |
| 我的 → 同步进度 | NavigationLink → SyncProgressView |

## 8. WebDAV / RSS / Sync 归属规划

| 功能 | 归属 | 入口路径 |
|---|---|---|
| WebDAV 配置 | 我的 | 我的 → 备份与同步 → WebDAV 备份 |
| 备份设置 | 我的 | 我的 → 备份与同步 → 备份设置 |
| 阅读进度同步 | 我的 | 我的 → 备份与同步 → 同步进度 |
| 远程 WebDAV 书籍 | 我的 | WebDAV 配置 → 远程书籍列表 |
| RSS 订阅管理 | 发现 | 发现 → RSS 列表 → 订阅管理 |
| RSS 列表/详情 | 发现 | 发现 → RSS 列表 → RSS 详情 |

**不允许**：WebDAV / RSS / 书源混入阅读页设置。此规则在 Prototype Gallery 中已验证 PASS（Reader 10 条规则第 6 条）。

## 9. Debug / Release 边界

| 入口 | Debug | Release |
|---|---|---|
| `[DEBUG] Prototype Gallery` | 可见（我的 Tab 或 toolbar） | 不可见 |
| WebView Harness | 可见（我的 Tab 或 toolbar） | 不可见 |
| 书架 / 发现 / 书源 / 我的 | 可见 | 可见 |
| 搜索入口 | 可见 | 可见 |
| 设置入口 | 可见（在"我的"内） | 可见 |

当前实现：
- `[DEBUG] Prototype Gallery` 已在 `#if DEBUG` 中 ✓
- `WebViewRuntimeHarnessView` 已在 `#if DEBUG` 中 ✓
- Release 不受影响 ✓

建议下一轮：将两个 Debug 入口从 Home Tab toolbar 迁移到"我的" Tab 的 Debug Section（保持 `#if DEBUG`）。

## 10. 下一轮实装计划

### Phase 1：最小生产主底栏对齐（低风险，~30 行变更）

**目标**：TabView 4 tabs 改为 书架/发现/书源/我的。

**变更**：
- `ReaderApp.swift` `RootShellView.body`：修改 4 个 tab 的 label 和内容
- Tab 0: Home → 书架 (`BookshelfView` + search toolbar button)
- Tab 1: Bookshelf → 发现（新建 `DiscoverHomeShellView` 或暂用 placeholder）
- Tab 2: Search → 书源（`BookSourceListView` 包裹 NavigationStack）
- Tab 3: Settings → 我的（新建 `MineTabView`，参考 `MineTabPrototype`）
- Debug entries 移到 Tab 3 toolbar 或 section

**风险**：极低。不删除任何 View，只重组 TabView。

### Phase 2：四个 Tab Shell 页面占位（~100 行新增）

**目标**：每个 Tab 有正确的生产 Shell。

**新增**：
- `iOS/Features/Discover/DiscoverHomeShellView.swift`（参考 `DiscoverHomePrototype`）
- `iOS/Features/Mine/MineTabView.swift`（参考 `MineTabPrototype`）
- `iOS/Features/Sources/SourceManagementShellView.swift`（包裹 `BookSourceListView`）

**特性**：全部使用 fixture/placeholder 数据，无真实网络。

### Phase 3：搜索 / 设置 / 阅读入口迁移（~50 行变更）

**目标**：
- 搜索入口从 TabView 移出，改为 书架/发现 的 toolbar button
- 设置从 TabView 移出，归入"我的"
- 阅读入口从 Home 移出，从 书架/搜索详情 进入

### Phase 4：测试与 boundary（~30 行新增/变更）

**目标**：新增测试验证 4-tab 结构。

**测试清单**：
1. 生产主底栏正好 4 项
2. 主底栏名称为：书架 / 发现 / 书源 / 我的
3. 主底栏不包含：Home / Search / Settings / Reader / WebView Harness
4. Debug-only Prototype Gallery 仅 Debug 可见
5. Release 不显示 Prototype Gallery
6. 搜索不是主底栏
7. 设置不是主底栏
8. 阅读不是主底栏
9. boundary 仍 PASS
10. fresh iOS build 仍 BUILD SUCCEEDED

### Phase 5：Codex Simulator 校对

截图校对 4 个 Tab 的主页 + 关键子页面。

## 11. 测试计划

### 11.1 自动化测试

| # | 测试 | 类型 | 新增/更新 |
|---|---|---|---|
| 1 | `testMainTabsExactlyFour` | 单元 | 新增 |
| 2 | `testMainTabNamesAreBookshelfDiscoverSourcesMine` | 单元 | 新增 |
| 3 | `testMainTabsDoNotContainHomeSearchSettingsReader` | 单元 | 新增 |
| 4 | `testPrototypeGalleryOnlyVisibleInDebug` | 编译时 | 已有（`#if DEBUG` 保证） |
| 5 | `testSearchNotInTabBar` | 单元 | 新增 |
| 6 | `testSettingsNotInTabBar` | 单元 | 新增 |
| 7 | `testReaderNotInTabBar` | 单元 | 新增 |
| 8 | boundary check | 脚本 | 已有，需保持 PASS |
| 9 | iOS xcodebuild | 构建 | 已有，需保持 BUILD SUCCEEDED |

### 11.2 人工截图校对

| # | 页面 | 内容 |
|---|---|---|
| 1 | 书架 Tab | 封面/列表、搜索入口 |
| 2 | 发现 Tab | 发现首页 Shell |
| 3 | 书源 Tab | 书源列表 |
| 4 | 我的 Tab | 设置/Sync/WebDAV/Debug section |

## 12. 跨平台 4-tab vs 5-tab 决策记录

跨平台基线定义 5 tabs（书架/搜索/发现/书源/设置），用户目标为 4 tabs（书架/发现/书源/我的）。

**4-tab 优势**：
- 搜索和设置降级后底栏更简洁
- "我的"语义比"设置"更丰富，可承载更多个人中心功能

**5-tab 优势**：
- 与 Android Compose / HarmonyOS 基线一致
- 搜索、设置独立可达，减少导航层级

**建议**：先在 iOS 实施 4-tab 方案（用户明确要求），后续如跨平台对齐要求，可重新评估是否统一为 5-tab。

## 13. P0 问题

无。

## 14. P1 问题

无。

## 15. 是否建议进入生产 App Shell 对齐实装

建议进入生产 App Shell 对齐实装。

前提已全部满足：
- Prototype Gallery 38 张截图全部完成并 PASS
- boundary PASS
- fresh iOS build BUILD SUCCEEDED
- P0/P1 为 0
- Debug entry 已隔离
- clean-room 成立
- 实施计划已规划 5 个 Phase，风险可控
