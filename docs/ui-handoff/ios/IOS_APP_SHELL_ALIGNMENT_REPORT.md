# iOS App Shell Alignment Report

## 1. 总体结论

**IOS_APP_SHELL_ALIGNMENT_READY**

## 2. 本轮目标

本轮是生产 App Shell 四主底栏最小对齐实装，将底栏从 Home / Bookshelf / Search / Settings 改为 书架 / 发现 / 书源 / 我的。不接真实数据，不做生产 UI 精装。

## 3. 输入状态

| 文档 | 来源 | 状态 |
|---|---|---|
| `IOS_APP_SHELL_ALIGNMENT_AUDIT.md` | Reader for iOS | 已读取 |
| `IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_CLOSURE_REPORT.md` | Reader for iOS | 已读取 |
| `IOS_SWIFTUI_PROTOTYPE_DEBUG_ENTRY_REPORT.md` | Reader for iOS | 已读取 |
| `CROSS_PLATFORM_UI_BASELINE.md` | Reader-Core | 已参考 |
| `CROSS_PLATFORM_ROUTE_MATRIX.md` | Reader-Core | 已参考 |
| `IOS_SWIFTUI_MAPPING.md` | Reader-Core | 已参考 |

## 4. 修改范围

### 新增文件

| 文件 | 说明 |
|---|---|
| `iOS/Features/Discover/DiscoverHomeShellView.swift` | 发现 Tab 最小生产 Shell（推荐/分类/排行/搜索入口） |
| `iOS/Features/Mine/MineTabView.swift` | 我的 Tab Shell（设置/WebDAV/备份/同步/关于 + Debug section） |
| `iOS/Tests/ReaderAppTests/AppShellAlignmentTests.swift` | 生产 App Shell 对齐验证测试 |

### 修改文件

| 文件 | 说明 |
|---|---|
| `iOS/App/ReaderApp.swift` | RootShellView TabView 改为四主底栏：书架/发现/书源/我的；移除旧 Home toolbar Debug 入口（已迁移到 MineTabView） |

## 5. 生产主底栏结果

| Tab | 标签 | SF Symbol | SwiftUI View |
|---|---:|---|---|
| 0 | 书架 | `books.vertical` | `BookshelfView` (in `NavigationStack`, with search toolbar button) |
| 1 | 发现 | `safari` | `DiscoverHomeShellView` |
| 2 | 书源 | `doc.text.magnifyingglass` | `BookSourceListView` (in `NavigationStack`) |
| 3 | 我的 | `person.circle` | `MineTabView` |

### 确认清单

| 检查项 | 结果 |
|---|---|
| 底栏共 4 项 | PASS |
| 不包含 Home | PASS |
| 不包含 Bookshelf | PASS |
| 不包含 Search | PASS |
| 不包含 Settings | PASS |
| 不包含 Reader | PASS |
| 不包含 WebView Harness | PASS |
| 阅读不是底栏 | PASS |

## 6. 搜索 / 阅读 / 设置归属结果

| 功能 | 新归属 | 方式 |
|---|---|---|
| 搜索 | 书架 Tab toolbar | `NavigationLink(destination: SearchView())`, magnifyingglass icon |
| 搜索 | 发现 Tab | `DiscoverHomeShellView` 内 Section 首行 |
| 阅读 | 非底栏 | 从书架书籍/搜索详情进入（route 保留，本轮不接真实阅读流） |
| 设置 | 我的 Tab | `MineTabView` 内 "个人" Section 首行 |
| WebDAV | 我的 Tab | `MineTabView` 内 "备份与同步" Section |
| 备份/同步 | 我的 Tab | `MineTabView` 内 "备份与同步" Section |

## 7. Debug / Release 边界

| 入口 | Debug | Release | 位置 |
|---|---|---|---|
| `[DEBUG] Prototype Gallery` | 可见 | 不可见 | MineTabView "Developer Tools" Section |
| WebView Harness | 可见 | 不可见 | MineTabView "Developer Tools" Section |

- 两个 Debug 入口均在 `#if DEBUG` 包裹下 ✓
- Release 编译不包含 Debug Section ✓
- 生产主底栏四项不含任何 Debug 入口 ✓
- 无 WebView UI 承载 App Shell ✓

## 8. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | PASS |
| 是否无 WebView UI 承载生产主导航 | PASS |
| 是否无真实网络 | PASS |
| 是否未接真实 WebDAV/RSS/同步 | PASS |
| 是否未修改 Reader-Core | PASS |
| Prototype entry 仍为 38 | PASS |
| 是否只使用 fixture/placeholder | PASS |
| clean-room | PASS，无外部 GPL 代码搬运 |

## 9. 测试 / Build 结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 已执行 |
| `bash scripts/check_ios_boundary.sh` | PASS（82 files, 0 violations） |
| `xcodegen generate` | 成功 |
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | **BUILD SUCCEEDED** |

新增测试文件 `AppShellAlignmentTests.swift` 包含：
- Shell View 实例化 smoke test
- Prototype entry 38 不变验证
- Route 语义验证（搜索/设置/阅读 route 存在但非底栏）

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. 是否建议交给 Codex 做 Simulator 校对

建议交给 Codex 做 Simulator 校对。

条件全部满足：
- boundary PASS
- fresh iOS build BUILD SUCCEEDED
- P0/P1 为 0
- 主底栏已是 书架 / 发现 / 书源 / 我的
- 搜索/设置/阅读 不在底栏
- Debug entry 仅 Debug 可见
