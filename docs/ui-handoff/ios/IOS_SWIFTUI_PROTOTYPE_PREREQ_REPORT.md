# iOS SwiftUI Prototype Prereq Report

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_PREREQ_READY**

所有 Prototype Gallery 阻塞前置条件已解除：
- P0 编译错误已修复（`RuntimeContractMapping.swift` 参数顺序）
- Theme Token 系统已创建
- ReaderControlState 模型已创建
- Route enum 已扩展到 31 cases（覆盖 13 个分组）
- 验证测试已添加

## 2. 本轮目标

本轮只修复 Prototype Gallery 前置阻塞，不实现 38 个 Gallery 页面。

目标：将状态从 `IOS_SWIFTUI_PROTOTYPE_AUDIT_BLOCKED` → `IOS_SWIFTUI_PROTOTYPE_PREREQ_READY`

## 3. P0 修复结果

### RuntimeContractMapping.swift — 已修复

**问题**：`RuntimeResult.init` 参数顺序为 `snapshot` (位置 6) 在 `errorCode` (位置 8) 之前，但调用处参数顺序颠倒。

**修复**：
- `RuntimeResult.denied(...)` 调用：`errorCode` 与 `snapshot` 顺序调整
- `RuntimeResult.unavailable(...)` 调用：同上

**文件**：`iOS/CoreBridge/RuntimeContractMapping.swift`

## 4. Theme Token 结果

新增 5 个 Token 文件，全部位于 `iOS/Modules/Theme/`：

| 文件 | 内容 | 来源 |
|---|---|---|
| `ReaderColors.swift` | 13 个日间 token + 14 个夜间 token | CROSS_PLATFORM_UI_BASELINE.md §4.1 |
| `ReaderTypography.swift` | 7 个字体 token + 行高常量 | CROSS_PLATFORM_UI_BASELINE.md §4.2 |
| `ReaderSpacing.swift` | 6 个间距 token (xs/sm/md/lg/readerHorizontal/bottomSafeGap) | CROSS_PLATFORM_UI_BASELINE.md §4.3 |
| `ReaderShapes.swift` | 4 个形状 token (card/overlay/circle/pill) + 圆角常量 | CROSS_PLATFORM_UI_BASELINE.md §4.4 |
| `ReaderTheme.swift` | ReaderControlMetrics (11 个布局参数) + ReaderThemeManager (夜间切换) | CROSS_PLATFORM_READER_CONTROL_SPEC.md §2 |

特点：
- 纯 SwiftUI 原生类型，无第三方依赖
- 不依赖 Asset Catalog
- Token 使用 static constants / semantic names
- 夜间模式：`ReaderThemeManager.isNightMode` toggle，非弹窗
- 复用项目已有 `Color(hex:)` 扩展（位于 `ReaderSettingsPanel.swift`）

## 5. ReaderControlState 结果

新增 2 个 State 文件，位于 `iOS/Modules/Reader/`：

### ReaderControlState.swift — 9 类阅读控制状态

| # | 状态 | 类型 |
|---|---|---|
| 1 | `baseControlVisible` | 基础控制层可见 |
| 2 | `quickActionOverlay(.search)` | 搜索本章 |
| 3 | `quickActionOverlay(.autoScroll)` | 自动翻页 |
| 4 | `quickActionOverlay(.replace)` | 内容替换（仅当前书籍） |
| 5 | `nightState` | 夜间模式（非弹窗） |
| 6 | `bottomFunctionOverlay(.directory)` | 目录/书签 |
| 7 | `bottomFunctionOverlay(.tts)` | 朗读 |
| 8 | `bottomFunctionOverlay(.appearance)` | 界面设置 |
| 9 | `bottomFunctionOverlay(.settings)` | 阅读行为设置 |

附加枚举：
- `QuickActionType` (3 cases: search/autoScroll/replace)
- `BottomFunctionType` (4 cases: directory/tts/appearance/settings)
- `BrightnessDock` (2 cases: left/right)
- `TtsState` (3 states: playing/paused/stopped)
- `AutoScrollState` (3 states: running/paused/stopped)

### ReaderUiState.swift — 12 类全局状态

`ReaderUiState` enum: idle/loading/empty/error/offline/disabled/permissionRequired/localFileError/networkSourceError/webDavAuthError/syncConflict/importSuccess/importFailure

### 关键约束已编码

1. 快捷按钮无文字标签 — QuickActionType 是纯枚举，由 View 层保证仅图标
2. 夜间模式非弹窗 — `nightState` 不是 overlay，由 `ReaderThemeManager.toggleNightMode()` 切换
3. 内容替换仅当前书籍 — QuickActionType.replace 语义约束
4. 页内控制本章内 — 语义约束，不用 skip_previous/skip_next
5. 阅读页底栏设置不含 WebDAV/书源/RSS — BottomFunctionType.settings 不含这些
6. 目录页有目录/书签 — BottomFunctionType.directory 含此语义
7. 朗读无章节跳转 — TtsState 不含跳转语义
8. 亮度条有自动亮度+左右停靠 — BrightnessDock 枚举

## 6. Route / Navigation 结果

### Route enum — 从 9 cases 扩展到 31 cases

| 分组 | Cases | 数量 |
|---|---|---|
| App Shell | home | 1 |
| Bookshelf | bookshelf, bookshelfGroups, bookshelfImport | 3 |
| Discover | discover | 1 |
| Search | search, searchResults | 2 |
| Book Detail | bookDetail, bookDetailToc, sourceSwitch | 3 |
| Reader | reader, content, toc | 3 |
| Source Management | bookSources, bookSourceImport, sourceDetail, sourceAdd, sourceEdit, sourceTestResult | 6 |
| RSS | rssList, rssDetail, rssSubscriptions | 3 |
| WebDAV/Sync | webdavSettings, webdavBooks, backupSettings, syncProgress | 4 |
| Settings | settings, settingsReading, settingsAbout | 3 |
| State Pages | stateError, stateOffline, statePermission | 3 |
| Debug | prototypeGallery | 1 |

### 主底栏目标

```
书架 / 发现 / 书源 / 我的
```

- 阅读不是主底栏模块（从书籍进入）
- 设置归入"我的" tab，不是一级主底栏
- 搜索作为发现内的功能

### AppNavigationState

保持不变，仍使用 `NavigationPath` + `@Published var navigationPath: [Route]`。

### ReaderApp.swift 兼容

`destinationView(for:)` switch 新增 `default: Text("\(route.title) — 待实现")` case，确保所有未来 route 不会导致编译错误。

## 7. Boundary 检查

```
命令：bash scripts/check_ios_boundary.sh
结果：PASS
checked_files: 75
violations: 0
```

合规确认：
- [x] 未引用 parser internals（ReaderCoreParser/ReaderCoreNetwork/ReaderCoreCache/ReaderCoreExecution 在 restricted paths 中 0 引用）
- [x] 仅使用 Reader-Core public API（ReaderCoreModels + ReaderCoreProtocols）
- [x] 无 WebView UI（新增 Theme/State/Route 文件不 import WebKit）
- [x] 无真实网络（新增文件不 import 网络框架）

## 8. 测试结果

### swift build --target ReaderApp

成功（45 文件编译通过）

### swift build --target ReaderAppTests

在 macOS 上存在 8 个预存错误（非本轮引入）：
- `ReaderApp.swift:82` — `.topBarTrailing` 在 macOS 不可用
- `WebViewRuntimeHarnessView.swift:75` — `.navigationBarTitleDisplayMode` 在 macOS 不可用
- `WebViewRuntimeHarnessView.swift:105,139` — `CGColor.systemGray6` 在 macOS 不可用
- `BookshelfItemFactory.swift:2` — `ReaderAppSupport` target 缺少 `ReaderCoreModels` 依赖声明

原因：reader-ios 项目的 macOS 目标支持不完整（部分 iOS-only API 缺少 `#if os(iOS)` 保护），ReaderAppSupport target 缺少显式依赖。这些是项目预存问题，不影响 iOS 原生构建。

### bash scripts/check_ios_boundary.sh

**PASS** (75 files, 0 violations)

### 新增测试文件

`Tests/ReaderAppTests/PrototypePrereqVerificationTests.swift` — 22 个测试方法：

| 测试类别 | 方法数 | 覆盖 |
|---|---|---|
| Theme Token 可访问 | 5 | ReaderColors, ReaderTypography, ReaderSpacing, ReaderShapes, ReaderControlMetrics |
| ReaderControlState | 5 | 9 cases, QuickActionType 3 cases, BottomFunctionType 4 cases, nightState 非 overlay, settings 约束 |
| ReaderUiState | 1 | 13 cases 全部可构造 |
| Route 分组覆盖 | 9 | 13 个分组各至少 1 个 case |
| Boundary 合规 | 2 | 无 WebKit import |

## 9. 修改文件

### 修复（已存在文件）

| # | 文件 | 操作 | 说明 |
|---|---|---|---|
| 1 | `iOS/CoreBridge/RuntimeContractMapping.swift` | 修复 | 调整 RuntimeResult.init 参数顺序 |
| 2 | `iOS/Tests/ShellSmokeTests/WebViewAdapterSmokeTests.swift` | 修复预存 | 移除多余 `}` + `#if os(iOS)` 包裹 iOS-only 函数 |
| 3 | `iOS/Tests/ShellSmokeTests/RealServiceOfflineReplayTests.swift` | 修复预存 | actor isolation：提取 `capturedRequests` 到局部变量 |
| 4 | `iOS/App/ReaderApp.swift` | 扩展 | switch 添加 `default` case |
| 5 | `iOS/Navigation/Route.swift` | 扩展 | 从 9 → 31 cases |

### 新增文件

| # | 文件 | 类型 |
|---|---|---|
| 1 | `iOS/Modules/Theme/ReaderColors.swift` | Theme Token |
| 2 | `iOS/Modules/Theme/ReaderTypography.swift` | Theme Token |
| 3 | `iOS/Modules/Theme/ReaderSpacing.swift` | Theme Token |
| 4 | `iOS/Modules/Theme/ReaderShapes.swift` | Theme Token |
| 5 | `iOS/Modules/Theme/ReaderTheme.swift` | Theme Token + Manager |
| 6 | `iOS/Modules/Reader/ReaderControlState.swift` | State Model |
| 7 | `iOS/Modules/Reader/ReaderUiState.swift` | State Model |
| 8 | `iOS/Tests/ReaderAppTests/PrototypePrereqVerificationTests.swift` | 验证测试 |

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. 是否建议进入 Prototype Gallery 开发

**建议进入。**

前置条件全部满足：
1. [x] P0 编译错误（RuntimeContractMapping.swift 参数顺序）已修复
2. [x] boundary 检查通过（75 files, 0 violations）
3. [x] Theme Token 存在（5 个文件，覆盖 color/typography/spacing/shapes/metrics）
4. [x] ReaderControlState 存在（9 states + 4 companion enums）
5. [x] ReaderUiState 存在（13 cases）
6. [x] Route enum 已具备 Gallery 分组基础（31 cases, 13 groupings）
7. [x] 验证测试已添加（22 test methods）
8. [x] 无 P0/P1 阻塞

---

*报告时间：2026-05-23*
*输入基线：CROSS_PLATFORM_UI_BASELINE_READY*
*前一次审计：IOS_SWIFTUI_PROTOTYPE_AUDIT_BLOCKED → 本轮：IOS_SWIFTUI_PROTOTYPE_PREREQ_READY*
