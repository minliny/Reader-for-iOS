# S4.P0 目录 (TOC) 流程能力层契约审计

## 1. 本轮结论

**结论**: `TOC_CAPABILITY_READY_WITH_GAPS`

**说明**:
- TOC 流程能力层已形成本仓 Mock 闭环
- TOCService 接口契约清晰
- Mock/Placeholder 路由已实现
- TOCView → ReadingFlowCoordinator → MockTOCService → MockReaderCoreService 链路完整
- **当前 real mode 是 PlaceholderTOCService，不代表真实 Reader-Core TOC 能力**
- **DefaultTOCService 存在，但真实 Core 依赖未验证、未装配**
- Swift 编译在 Trae 环境未验证

## 2. 审计范围

| 范围 | 内容 |
|------|------|
| TOC 能力入口 | TOCView + ReadingFlowCoordinator.selectBook() |
| TOCService 协议 | TOCService (Reader-Core public API) |
| Mock 实现 | MockTOCService + MockReaderCoreService.getChapterList() |
| Placeholder 实现 | PlaceholderTOCService |
| Default 实现 | DefaultTOCService |
| 独立 ViewModel | ChapterListViewModel |
| 路由 | ShellAssembly.makeDefaultReadingFlowCoordinator() |

## 3. 真实文件路径

| 文件 | 状态 | 用途 |
|------|------|------|
| `iOS/Features/TOC/TOCView.swift` | ✅ | 目录视图 |
| `iOS/Features/ChapterList/ChapterListViewModel.swift` | ✅ | 章节列表 ViewModel |
| `iOS/Features/ChapterList/ChapterListView.swift` | ✅ | 章节列表视图 |
| `iOS/CoreIntegration/DefaultTOCService.swift` | ✅ | 真实 TOC 服务（未装配） |
| `iOS/CoreIntegration/PlaceholderServices.swift` | ✅ | Placeholder TOC 服务 |
| `iOS/Shell/ShellAssembly.swift` | ✅ | Shell 组装 + Mock TOC 服务 |
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | ✅ | 阅读流程协调 + TOC 入口 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | ✅ | 服务提供者 |
| `iOS/CoreBridge/MockReaderCoreService.swift` | ✅ | Mock 核心服务 |

## 4. TOC 能力状态表

| 能力项 | 状态 | 说明 |
|--------|------|------|
| 目录加载 | ✅ 已实现 | ReadingFlowCoordinator.selectBook() |
| TOCService 接口 | ✅ 已实现 | Reader-Core public API |
| MockTOCService | ✅ 已实现 | ShellAssembly.makeMockReadingFlowCoordinator() |
| PlaceholderTOCService | ✅ 已实现 | ShellAssembly.makePlaceholderReadingFlowCoordinator() |
| DefaultTOCService | ⚠️ 未装配 | 存在但未传入 ShellAssembly |
| Mock/Placeholder 可区分 | ✅ 已实现 | via ReaderCoreServiceProvider.mode |
| real mode 真实 TOC | ❌ 未实现 | 当前返回 unsupported |
| TOC 状态流 | ✅ 已实现 | tocItems + isLoading + currentError |
| 无书源处理 | ✅ 已实现 | ReadingFlowCoordinator |
| 空目录处理 | ✅ 已实现 | TOCView.emptyState |
| 目录 → 正文连接 | ✅ 已实现 | TOCView → ContentView |
| TOC 测试覆盖 | ⚠️ 部分 | ChapterListViewModel 有测试，无独立 TOC 契约测试 |

## 5. TOCService 契约

### 协议定义

```swift
public protocol TOCService {
    func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem]
}
```

| 契约项 | 说明 |
|--------|------|
| 输入 | BookSource + detailURL (书籍详情 URL) |
| 输出 | [TOCItem] |
| 错误 | throws ReaderError |
| 空目录 | 返回空数组 [] |

### 三条实现路径

| 路径 | 依赖 | 行为 | 状态 |
|------|------|------|------|
| Mock | ReaderCoreServiceProvider | 委托给 provider.getChapterList() | ✅ 已验证 |
| Placeholder | 无 | 抛出 unavailable | ✅ 已验证 |
| Default | HTTPClient/RequestBuilder/TOCParser | 构造真实请求 | ❌ 未验证 |

## 6. MockTOCService 契约

| 契约项 | 说明 |
|--------|------|
| 依赖 | ReaderCoreServiceProvider |
| 行为 | 委托给 provider.getChapterList() |
| 错误映射 | LoadState → AppReaderError |
| 支持场景 | 8 种 MockScenario |

**MockScenario TOC 支持**:

| Scenario | TOC 行为 |
|----------|----------|
| .success | 返回 5 个 mock 章节 |
| .partial | 返回 5 个章节 + warning |
| .unsupported | 抛出 unsupported |
| .empty | 返回 [] |
| .parserFailure | 抛出 AppReaderError.parser |
| .networkFailure | 抛出 AppReaderError.network |
| .jsRequired | 抛出 AppReaderError.jsRequired |
| .loginRequired | 抛出 AppReaderError.loginRequired |

## 7. PlaceholderTOCService 契约

| 契约项 | 说明 |
|--------|------|
| 依赖 | 无 |
| 行为 | 始终抛出 PlaceholderServiceError.realCoreNotAvailable |
| 错误类型 | PlaceholderServiceError |

## 8. ReadingFlowCoordinator TOC 流程

### TOC 入口

```swift
public func selectBook(_ book: SearchResultItem) async {
    selectedBook = book
    resetChapterSelectionState()
    tocItems.removeAll()

    guard let source = selectedSource else { return }
    let detailURL = book.detailURL

    isLoading = true
    currentError = nil
    defer { isLoading = false }

    do {
        tocItems = try await tocService.fetchTOC(source: source, detailURL: detailURL)
    } catch let error as ReaderError {
        currentError = error
        await logError(error, stage: "TOC")
    } catch {
        let readerError = ReaderError(...)
        currentError = readerError
        await logError(readerError, stage: "TOC")
    }
}
```

### 流程连接

| 步骤 | 连接 |
|------|------|
| 搜索 | SearchViewModel → ReadingFlowCoordinator.search() |
| 书籍详情 | 搜索结果 → selectBook() |
| 目录 | selectBook() → tocService.fetchTOC() → tocItems |
| 正文 | TOCView → ContentView → selectChapter() |

### 状态流

| 状态 | 说明 |
|------|------|
| tocItems: [TOCItem] | 目录列表 |
| selectedBook: SearchResultItem? | 选中书籍 |
| selectedChapter: TOCItem? | 选中章节 |
| isLoading | 加载状态 |
| currentError | 当前错误 |

## 9. TOCView 当前实现

### 架构

TOCView 直接使用 ReadingFlowCoordinator 作为数据源，与 SearchViewModel 不同：

```swift
public struct TOCView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    public let book: SearchResultItem
    // ...
}
```

### 与 SearchViewModel 的差异

| 特性 | SearchViewModel | TOCView |
|------|-----------------|---------|
| 独立 ViewModel | ✅ | ❌ 直接用 Coordinator |
| 状态枚举 | SearchState | 使用 Coordinator 属性 |
| 书源选择 | loadSources() | selectedSource (来自 Coordinator) |
| 持久化 selectedSourceId | ✅ S3.P2 已实现 | ❌ 依赖 Coordinator |

### TOCView 行为

1. `.task` 中自动加载：`await coordinator.selectBook(book)`
2. 空目录显示 emptyState
3. 错误显示 ErrorView + 重试按钮
4. 目录列表点击进入 ContentView

## 10. ChapterListViewModel 当前实现

### 架构

ChapterListViewModel 使用独立的 provider.getChapterList()：

```swift
public func loadChapters() async {
    listState = .loading
    do {
        let state = await provider.getChapterList(bookURL: bookURL)
        // 状态映射...
    }
}
```

### 与 ReadingFlowCoordinator 的差异

| 特性 | ReadingFlowCoordinator | ChapterListViewModel |
|------|------------------------|----------------------|
| 书源 | selectedSource | 无书源参数 |
| detailURL | book.detailURL | bookURL 参数 |
| provider 路由 | 通过 MockTOCService | 直接调用 provider |
| 状态枚举 | Coordinator 属性 | ChapterListState |

**问题**: ChapterListViewModel 直接调用 `provider.getChapterList()` 而不是通过 tocService，存在不一致性。

## 11. Mock/Placeholder/Real 路由契约

### ShellAssembly 路由

```swift
public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator {
    let provider = ReaderCoreServiceProvider.shared
    switch provider.currentMode {
    case .mock:
        return makeMockReadingFlowCoordinator() // MockTOCService
    case .real:
        return makePlaceholderReadingFlowCoordinator() // PlaceholderTOCService
    }
}
```

### ReaderCoreServiceProvider 路由

```swift
public func getChapterList(bookURL: String) async -> LoadState<[TOCItem]> {
    switch currentMode {
    case .mock:
        return await mockService.getChapterList(bookURL: bookURL)
    case .real:
        return .unsupported(reason: "Real Core service not available...")
    }
}
```

### 契约保证

| 模式 | MockTOCService | 不做 |
|------|----------------|------|
| mock | 返回 .loaded / .empty / .failed | - |
| real | PlaceholderTOCService 抛出 | 静默回退 mock |

## 12. TOC 能力验收矩阵

| 能力项 | 状态 | 测试覆盖 |
|--------|------|----------|
| Mock TOC 成功 | ✅ 已实现 | MockReaderCoreService |
| Mock TOC 空结果 | ✅ 已实现 | MockScenario.empty |
| Mock TOC 失败 | ✅ 已实现 | MockScenario.parserFailure |
| Mock TOC unsupported | ✅ 已实现 | MockScenario.unsupported |
| Placeholder TOC unavailable/unsupported | ✅ 已实现 | PlaceholderTOCService |
| Real mode 不静默回退 Mock | ✅ 已实现 | 路由隔离 |
| DefaultTOCService 存在但未装配 | ✅ 已确认 | - |
| ReadingFlowCoordinator 状态流 | ✅ 已实现 | - |
| TOCView 空目录处理 | ✅ 已实现 | - |
| TOCView 错误处理 + 重试 | ✅ 已实现 | - |
| 目录 → 正文连接点 | ✅ 已实现 | TOCView → ContentView |
| 目录排序/翻转 | ❌ 未实现 | - |
| 目录翻页 | ❌ 未实现 | - |
| 与 Reader-Core 边界 | ✅ 清晰 | 边界检查 |

## 13. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | ChapterListViewModel 与 Coordinator 不一致 | 中 | ChapterListViewModel 直接调用 provider，不走 tocService |
| P1-2 | TOC 契约测试缺失 | 中 | 需添加 TOCService 契约测试 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 目录排序/翻转 | 低 |
| P2-2 | 目录翻页 | 中 |
| P2-3 | 章节缓存 | 低 |

### 不属于当前 S4 的任务

| 任务 | 归属 | 说明 |
|------|------|------|
| 真实 Reader-Core TOC 接入 | S1.P2 | 需 Reader-Core 可用环境 |
| DefaultTOCService 真实装配 | S1.P2 | 需 Reader-Core API 验证 |

## 14. 与 Reader-Core 的边界说明

| 边界项 | 说明 |
|--------|------|
| TOCService 协议 | ✅ public API (ReaderCoreProtocols) |
| TOCItem | ✅ public API (ReaderCoreModels) |
| BookSource | ✅ public API (ReaderCoreModels) |
| HTTPClient | ✅ public API |
| RequestBuilder | ✅ public API |
| TOCParser | ✅ public API |
| MockTOCService | ⚠️ 本仓实现，不依赖 Reader-Core 内部 |

**边界保证**: TOC 流程使用 Reader-Core public API，不直接依赖 Parser/Runtime 内部实现。

## 15. S4.P1 推荐能力建设任务

**任务 ID**: S4.P1
**任务名称**: TOCService 契约测试与架构一致性补强

**任务内容**:
1. 添加 TOCService 契约测试
2. 验证 Mock/Placeholder/Real 路由
3. 解决 ChapterListViewModel 与 Coordinator 不一致问题
4. 验证 TOC → Content 流程

**前提条件**: 无需 Reader-Core

## 16. 本轮未做事项

| 事项 | 原因 |
|------|------|
| TOC 契约测试 | 待 S4.P1 实现 |
| ChapterListViewModel 重构 | 不一致性存在但不影响 Mock 闭环 |
| DefaultTOCService 装配 | 需 Reader-Core API 验证 |
| 目录排序/翻转 | P2 优化项 |
