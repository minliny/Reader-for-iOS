# iOS Real Data Integration Planning

## 1. 总体结论

**IOS_REAL_DATA_INTEGRATION_PLANNING_READY**

## 2. 本轮目标

本轮只做真实数据接入规划审计，不做代码实装。审计当前 iOS CoreBridge 可用 facade、各页面 fixture/shell 状态、Reader-Core 协议边界，规划分阶段最小闭环。

## 3. 输入状态

| 文档/代码 | 来源 | 状态 |
|---|---|---|
| `IOS_APP_SHELL_PROTOTYPE_READER_CONTROL_CLOSURE_REPORT.md` | Reader for iOS | 已读取 |
| `ReaderCoreServiceProvider.swift` | iOS CoreBridge | 已读取 |
| `MockReaderCoreService.swift` | iOS CoreBridge | 已读取 |
| `ReadingFlowCoordinator.swift` | iOS CoreIntegration | 已读取 |
| `DefaultSearchService.swift` | iOS CoreIntegration | 已读取 |
| `DefaultTOCService.swift` | iOS CoreIntegration | 已读取 |
| `DefaultContentService.swift` | iOS CoreIntegration | 已读取 |
| `Contracts.swift` (SearchService/TOCService/ContentService) | Reader-Core Protocols | 已读取 |
| `ReaderApp.swift` + 各 Feature View | iOS Features | 已读取 |

## 4. 当前 UI Shell 状态

| Tab/页面 | 当前状态 | 数据来源 | 是否 fixture-only |
|---|---|---|---|
| 书架 (BookshelfView) | Shell，空态占主导 | `BookshelfViewModel` → `BookshelfStore` (local) | 是 |
| 发现 (DiscoverHomeShellView) | 纯 shell placeholder | 无数据源，纯 List 占位 | 是 |
| 书源 (BookSourceListView) | Shell，空态占主导 | `BookSourceStore` (local JSON) | 是 |
| 我的 (MineTabView) | Shell placeholder | 无真实数据源 | 是 |
| 搜索 (SearchView) | 功能存在但无书源 | `SearchViewModel` → `ReaderCoreServiceProvider` | mock 可用 |
| 书籍详情 (BookDetailView) | 功能存在 | `SearchResultItem` 参数传入 | fixture 可用 |
| TOC (TOCView) | 功能存在 | `ReadingFlowCoordinator` | fixture 可用 |
| ReaderView | 功能存在但不可达 | `ReaderViewModel` → `ReaderCoreServiceProvider` | DEBUG fixture 可用 |
| 设置 (WebDAVSettingsView) | 功能存在但不可达 | 本地 Store | 是 |

## 5. CoreBridge / Facade 现状

### 5.1 ReaderCoreServiceProvider

`iOS/CoreBridge/ReaderCoreServiceProvider.swift` — 中心服务 facade：

| 方法 | Mock | Real | 状态 |
|---|---|---|---|
| `searchBooks(keyword:page:source:)` | MockReaderCoreService | DefaultSearchService (需 parser) | mock 就绪 |
| `getBookDetail(bookURL:source:)` | MockReaderCoreService | 占位实现 | mock 就绪 |
| `getChapterList(bookURL:)` | MockReaderCoreService | DefaultTOCService (需 parser) | mock 就绪 |
| `getChapterContent(chapterURL:)` | MockReaderCoreService | DefaultContentService (需 parser) | mock 就绪 |
| `validateBookSource(from:)` | JSON decode | JSON decode | 就绪 |

### 5.2 MockReaderCoreService

`iOS/CoreBridge/MockReaderCoreService.swift` — 全功能 mock：

- 8 个场景：success / partial / unsupported / empty / parserFailure / networkFailure / jsRequired / loginRequired
- 3 个 mock 搜索结果（凡人修仙传 / 仙逆 / 一念永恒）
- 5 个 mock TOC 章节
- 1 个 mock 章节内容（凡人修仙传第一章）
- 模拟延迟 100-300ms
- 返回 `LoadState<T>` 含所有状态变体

### 5.3 ReadingFlowCoordinator

`iOS/CoreIntegration/ReadingFlowCoordinator.swift` — 阅读流编排：

- 持有 SearchService / TOCService / ContentService
- 管理 searchResults / selectedBook / tocItems / selectedChapter / contentPage 状态
- 发布 @Published 属性供 SwiftUI 绑定

### 5.4 边界问题

`DefaultSearchService` / `DefaultTOCService` / `DefaultContentService` 直接依赖 `SearchParser` / `TOCParser` / `ContentParser`（ReaderCoreParser 内部类型）。虽然当前 boundary check PASS（因无直接 `import ReaderCoreParser` 语句），但 real mode 需要 parser internals。**生产网络接入前需评估此边界**。

## 6. 页面接入优先级

| 页面 | 当前状态 | 是否可接 mock | 是否可接真实数据 | 推荐数据源 | 风险等级 | 下阶段 |
|---|---|---|---|---|---|---|
| 搜索 | 壳存在，缺书源 | 是 | 否（需 parser） | MockReaderCoreService | 低 | Phase 1 |
| 书籍详情 | 壳存在 | 是 | 否 | SearchResultItem 传入 | 低 | Phase 1 |
| TOC | 壳存在 | 是 | 否 | MockReaderCoreService | 低 | Phase 1 |
| ReaderView | 壳存在/DEBUG 可达 | 是 | 否 | MockReaderCoreService | 低 | Phase 1 |
| 书架 | 空壳 | 是（mock items） | 否 | BookshelfStore + mock | 低 | Phase 1 |
| 书源列表 | 空壳 | 是（mock sources） | 否 | InMemoryBookSourceRepository | 低 | Phase 2 |
| 书源导入 | 壳存在 | 是（JSON validate） | 否 | validateBookSource | 低 | Phase 2 |
| 发现 | 纯占位 | 否 | 否 | 无 | 中 | 延后 |
| RSS | 无实现 | 否 | 否 | 无 | 高 | 延后 |
| WebDAV | 壳存在，不可达 | 否 | 否 | 无 | 高 | 延后 |
| Sync | 无实现 | 否 | 否 | 无 | 高 | 延后 |
| 我的（设置外） | 占位 | 否 | 否 | 无 | 中 | 延后 |

## 7. 最小真实数据闭环规划

### 目标：Search → Detail → TOC → ReaderView fixture 闭环

使用 MockReaderCoreService 在不接真实网络/parser 的前提下，打通四个核心页面的数据流。

### 流程

```
书架/发现搜索入口
    → SearchView（MockReaderCoreService.searchBooks）
    → BookDetailView（SearchResultItem 传入）
    → TOCView（MockReaderCoreService.getChapterList）
    → ReaderView（MockReaderCoreService.getChapterContent）
```

### 关键依赖

| 依赖 | 当前状态 | 需要补充 |
|---|---|---|
| 书源选择 | SearchViewModel 需要 source | 预置 1 个 mock BookSource 或让搜索不强制 source |
| SearchViewModel → SearchView | 存在 | 无需变更 |
| BookDetail → TOC | 存在 Route + Coordinator | 需确保 coordinator 有 book |
| TOC → ReaderView | 存在 Route | 需确保 chapterURL 传递 |

### 不在此闭环

- 真实网络请求
- 真实书源执行
- WebDAV / RSS / Sync
- 发现页内容
- 书源测试/导入（真实 rule engine）

## 8. Boundary / Safety 规划

### 必须保留的检查

| 检查项 | 当前状态 | 下阶段要求 |
|---|---|---|
| no parser internals in iOS/Features | PASS | 保持 |
| no live network in ReaderView | PASS (mock only) | 保持 mock 默认 |
| no WebView UI in App Shell | PASS | 保持 |
| no WebDAV/RSS/Sync in reader settings | PASS | 保持 |
| Reader-Core public API only | PASS | 保持 |
| boundary script PASS | 82 files, 0 violations | 保持 |

### 下阶段新增 boundary 测试

1. `testSearchUsesMockOrFacadeOnly` — 搜索不直接访问 parser
2. `testReaderContentUsesMockByDefault` — 阅读页默认 mock
3. `testNoDirectParserImportInFeatures` — Features 目录不 import ReaderCoreParser
4. `testAppShellDoesNotContainWebView` — App Shell 不含 WebView UI

## 9. 测试规划

### Phase 1 测试（Search → Reader 闭环）

| # | 测试 | 说明 |
|---|---|---|
| 1 | `testMockSearchReturnsResults` | MockReaderCoreService 返回 3 个结果 |
| 2 | `testMockTOCReturnsItems` | Mock TOC 返回 5 章 |
| 3 | `testMockContentReturnsPage` | Mock 内容返回非空正文 |
| 4 | `testSearchToDetailNavigation` | 搜索结果可进入详情 |
| 5 | `testDetailToTOCNavigation` | 详情可进入 TOC |
| 6 | `testTOCToReaderNavigation` | TOC 可进入 ReaderView |
| 7 | `testReaderViewHidesTabBar` | ReaderView 隐藏主底栏 |
| 8 | `testMockScenarios` | 所有 8 个 mock 场景产生正确 LoadState |
| 9 | `testAppShellRoutesExist` | 关键 Route 可实例化 |
| 10 | `testNoSearchInTabBar` | 搜索不在底栏 |
| 11 | `testNoSettingsInTabBar` | 设置不在底栏 |
| 12 | `testNoReaderInTabBar` | 阅读不在底栏 |

### Phase 2 测试（书源管理）

| # | 测试 | 说明 |
|---|---|---|
| 13 | `testBookSourceValidation` | JSON 验证正确/错误 |
| 14 | `testBookSourceListLoads` | 书源列表可从 store 加载 |
| 15 | `testBookSourceToggleEnabled` | 启用/禁用切换 |
| 16 | `testBookSourceImportFlow` | 导入流程（fixture JSON） |

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. 是否建议进入真实数据最小闭环实装

建议进入 **iOS Search → Detail → TOC → ReaderView fixture/offline replay 最小闭环实装**（Phase 1）。

下一阶段目标：
- 使用 MockReaderCoreService（已有）打通 4 个核心页面数据流
- 预置 1 个 mock BookSource 使搜索可用
- 从书架/发现搜索入口 → SearchView → BookDetail → TOC → ReaderView 形成完整用户路径
- 不接真实网络、不引入 parser internals、不修改 Reader-Core
- 完成后由 Codex 设备端闭环验证
