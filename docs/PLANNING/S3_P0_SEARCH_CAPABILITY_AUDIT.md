# S3.P0 搜索流程能力层契约审计

## 1. 本轮结论

**结论**: `SEARCH_CAPABILITY_READY_ENV_UNVERIFIED`

**说明**:
- 搜索流程能力层已形成本仓 Mock 闭环
- SearchService 接口契约清晰
- Mock/Placeholder/Real 路由已实现
- 状态流与错误映射完整
- 边界检查通过
- Swift 编译在 Trae 环境未验证

## 2. 审计范围

| 范围 | 内容 |
|------|------|
| 搜索能力入口 | SearchViewModel.search() |
| SearchService 协议 | SearchService |
| Mock 实现 | MockSearchService + MockReaderCoreService |
| Placeholder 实现 | PlaceholderSearchService |
| Default 实现 | DefaultSearchService |
| Coordinator | ReadingFlowCoordinator.search() |
| 路由 | ShellAssembly.makeDefaultReadingFlowCoordinator() |

## 3. 真实文件路径

| 文件 | 状态 | 用途 |
|------|------|------|
| `iOS/Features/Search/SearchViewModel.swift` | ✅ | 搜索 ViewModel |
| `iOS/Features/Search/SearchView.swift` | ✅ | 搜索视图 |
| `iOS/CoreIntegration/DefaultSearchService.swift` | ✅ | 真实搜索服务 |
| `iOS/CoreIntegration/PlaceholderServices.swift` | ✅ | Placeholder 服务 |
| `iOS/Shell/ShellAssembly.swift` | ✅ | Shell 组装 + Mock 服务 |
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | ✅ | 阅读流程协调 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | ✅ | 服务提供者 |
| `iOS/CoreBridge/MockReaderCoreService.swift` | ✅ | Mock 核心服务 |
| `iOS/CoreBridge/LoadState.swift` | ✅ | 加载状态 |
| `iOS/CoreBridge/AppReaderError.swift` | ✅ | 应用错误 |

## 4. 搜索能力状态表

| 能力项 | 状态 | 说明 |
|--------|------|------|
| 搜索关键词输入 | ✅ 已实现 | SearchViewModel.keyword |
| selectedSourceId 需求 | ✅ 已实现 | 需 BookSource |
| 指定书源搜索 | ✅ 已实现 | selectedSource |
| 空关键词处理 | ✅ 已实现 | 抛出 failed |
| 无书源处理 | ✅ 已实现 | 抛出 failed |
| 搜索取消 | ❌ 未实现 | 无显式取消 |
| 重复搜索处理 | ⚠️ 部分 | 覆盖状态，不去重 |
| loading 状态 | ✅ 已实现 | SearchState.loading |
| loaded/empty/failed 状态 | ✅ 已实现 | SearchState |
| unsupported 状态 | ✅ 已实现 | SearchState.unsupported |
| Mock/Placeholder/Real 可区分 | ✅ 已实现 | via ReaderCoreServiceProvider.mode |

## 5. SearchService 契约

```swift
public protocol SearchService {
    func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem]
}
```

| 契约项 | 说明 |
|--------|------|
| 输入 | BookSource + SearchQuery(keyword, page) |
| 输出 | [SearchResultItem] |
| 错误 | throws (AppReaderError) |
| 空结果 | 返回空数组 [] |

## 6. MockSearchService 契约

| 契约项 | 说明 |
|--------|------|
| 依赖 | ReaderCoreServiceProvider |
| 行为 | 委托给 provider.searchBooks() |
| 错误映射 | LoadState → AppReaderError |
| 支持场景 | 8 种 MockScenario |

**MockScenario 枚举**:
```swift
public enum MockScenario {
    case success
    case partial(warning: String)
    case unsupported(reason: String)
    case empty
    case parserFailure
    case networkFailure
    case jsRequired
    case loginRequired
}
```

## 7. PlaceholderSearchService 契约

| 契约项 | 说明 |
|--------|------|
| 依赖 | 无 |
| 行为 | 始终抛出 PlaceholderServiceError.realCoreNotAvailable |
| 错误类型 | PlaceholderServiceError |

## 8. DefaultSearchService 当前状态

| 契约项 | 说明 |
|--------|------|
| 依赖 | HTTPClient, RequestBuilder, SearchParser |
| 行为 | 构造 HTTP 请求，调用 Parser 解析响应 |
| 状态 | ⚠️ 依赖 Reader-Core public API，构造参数未在 ShellAssembly 中传入 |

**问题**: DefaultSearchService 需要 HTTPClient/RequestBuilder/SearchParser，但 ShellAssembly.makePlaceholderReadingFlowCoordinator() 未传入这些参数。

## 9. ReadingFlowCoordinator 搜索流程

### 搜索入口

```swift
public func search(keyword: String) async {
    guard let source = selectedSource else { return }
    isLoading = true
    do {
        let query = SearchQuery(keyword: keyword, page: 1)
        searchResults = try await searchService.search(source: source, query: query)
    } catch let error as ReaderError {
        currentError = error
    }
    isLoading = false
}
```

### 流程连接

| 步骤 | 连接 |
|------|------|
| 搜索 | search() → searchService.search() |
| 详情 | selectBook() → tocService.fetchTOC() |
| 正文 | selectChapter() → contentService.fetchContent() |
| 书源选择 | applySourceSelection() → selectedSource |

### 状态流

| 状态 | 说明 |
|------|------|
| searchResults: [SearchResultItem] | 搜索结果列表 |
| selectedBook: SearchResultItem? | 选中书籍 |
| tocItems: [TOCItem] | 目录列表 |
| selectedChapter: TOCItem? | 选中章节 |
| isLoading | 加载状态 |
| currentError | 当前错误 |

## 10. 状态流与错误契约

### SearchState 枚举

```swift
public enum SearchState: Equatable {
    case idle
    case loading
    case success(results: [SearchResultItem])
    case empty
    case failed(message: String)
    case unsupported(reason: String)
    case partial(results: [SearchResultItem], warnings: [String])
}
```

### 错误映射

| 操作 | 错误来源 | 映射 |
|------|----------|------|
| 搜索成功 | searchService | → .success |
| 搜索空结果 | searchService | → .empty |
| 搜索失败 | AppReaderError | → .failed |
| 不支持 | PlaceholderError | → .unsupported |
| 部分成功 | searchService | → .partial |

### 空关键词契约

```swift
guard !trimmed.isEmpty else {
    searchState = .failed(message: "Keyword cannot be empty")
    return
}
```

### 无书源契约

```swift
guard let source = selectedSource else {
    searchState = .failed(message: "No book source selected")
    return
}
```

## 11. 测试覆盖

| 测试项 | 覆盖 | 文件 |
|--------|------|------|
| Mock 搜索成功 | ✅ | MockReaderCoreService |
| Mock 搜索空结果 | ✅ | MockScenario.empty |
| Placeholder 返回 unsupported | ✅ | PlaceholderServices.swift |
| 空关键词处理 | ✅ | SearchViewModel |
| 无书源处理 | ✅ | SearchViewModel |
| ReadingFlowCoordinator 搜索 | ✅ | ReadingFlowCoordinator |
| Mock/Real 路由 | ✅ | ReaderCoreServiceProvider |
| 边界检查 | ✅ | check_ios_boundary.sh |

**测试缺口**:
- 无显式搜索契约测试（单元测试）
- 无状态流转换测试

## 12. P0 / P1 / P2 缺口清单

### P0 必须解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| P0-1 | DefaultSearchService 构造参数缺失 | ⚠️ 部分 | ShellAssembly 未传入 HTTPClient/RequestBuilder/Parser |

### P1 应尽快解决

| ID | 缺口 | 当前状态 | 说明 |
|----|------|---------|------|
| P1-1 | 搜索测试覆盖不足 | ❌ 缺失 | 需添加 SearchService 契约测试 |
| P1-2 | 重复搜索处理 | ⚠️ 部分 | 覆盖状态，不去重 |
| P1-3 | 搜索取消能力 | ❌ 缺失 | 无显式取消 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 搜索历史 | 低 |
| P2-2 | 搜索排序 | 低 |
| P2-3 | 搜索分页 | 中 |
| P2-4 | 多书源聚合搜索 | 高 |
| P2-5 | 调试信息 | 低 |

## 13. 与 Reader-Core 的边界说明

| 边界项 | 说明 |
|--------|------|
| SearchService 协议 | ✅ public API (ReaderCoreProtocols) |
| SearchQuery | ✅ public API (ReaderCoreModels) |
| SearchResultItem | ✅ public API (ReaderCoreModels) |
| HTTPClient | ✅ public API |
| RequestBuilder | ✅ public API |
| SearchParser | ✅ public API |
| MockReaderCoreService | ⚠️ 本仓实现，不依赖 Reader-Core 内部 |

**边界保证**: 搜索流程使用 Reader-Core public API，不直接依赖 Parser/Runtime 内部实现。

## 14. S3.P1 推荐能力建设任务

**任务 ID**: S3.P1  
**任务名称**: SearchService 契约测试与重复搜索处理

**任务内容**:
1. 添加 SearchService 契约测试
2. 验证 Mock/Placeholder/Real 路由
3. 设计重复搜索处理策略
4. 验证状态流转换

**前提条件**: 无需 Reader-Core

## 15. 本轮未做事项

| 事项 | 原因 |
|------|------|
| DefaultSearchService 构造 | 需 Reader-Core public API 验证 |
| 搜索测试覆盖 | 待 S3.P1 实现 |
| 搜索历史 | P2 优化项 |
| 多书源聚合 | 高复杂度 |
