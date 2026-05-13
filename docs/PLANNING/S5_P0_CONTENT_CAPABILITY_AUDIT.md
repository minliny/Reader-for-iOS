# S5.P0 Content 正文流程能力层审计

## 1. 本轮结论

**结论**: `READY_WITH_GAPS + ENV_COMPILE_UNVERIFIED`

**说明**:
- 正文能力层已形成本仓 Mock 闭环
- ContentService 接口契约清晰
- MockContentService / PlaceholderContentService / DefaultContentService 三条路径已定义
- ReadingFlowCoordinator 正文流程完整
- TOC → Content 连接已确认
- 上一章/下一章导航能力已实现
- **当前 real mode 是 PlaceholderContentService，不代表真实 Reader-Core 正文能力**
- **DefaultContentService 存在但未装配**
- **ContentService 测试缺失，因此不能宣称完全 READY**
- **ChapterCacheStore 仅为缓存能力边界，是否接入正文加载流程需后续测试确认**
- **正文加载职责归属 ContentService / ReadingFlowCoordinator，TOCService 负责目录加载**
- Swift 编译在 Trae 环境未验证

## 2. 审计范围

| 范围 | 内容 |
|------|------|
| 正文能力入口 | ContentView + ReadingFlowCoordinator.selectChapter() |
| ContentService 协议 | ContentService (Reader-Core public API) |
| Mock 实现 | MockContentService + MockReaderCoreService.getChapterContent() |
| Placeholder 实现 | PlaceholderContentService |
| Default 实现 | DefaultContentService |
| 章节缓存 | ChapterCacheStore |
| 阅读进度 | ReadingProgressStore |
| 路由 | ShellAssembly.makeDefaultReadingFlowCoordinator() |

## 3. 真实文件路径

| 文件 | 状态 | 用途 |
|------|------|------|
| `iOS/Features/Content/ContentView.swift` | ✅ | 正文视图 |
| `iOS/CoreIntegration/DefaultContentService.swift` | ✅ | 真实正文服务（未装配） |
| `iOS/CoreIntegration/PlaceholderServices.swift` | ✅ | Placeholder 正文服务 |
| `iOS/Shell/ShellAssembly.swift` | ✅ | Shell 组装 + Mock 正文服务 |
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | ✅ | 阅读流程协调 + 正文入口 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | ✅ | 服务提供者 |
| `iOS/CoreBridge/MockReaderCoreService.swift` | ✅ | Mock 核心服务 |
| `iOS/CoreBridge/LoadState.swift` | ✅ | 加载状态 |
| `iOS/CoreBridge/AppReaderError.swift` | ✅ | 应用错误 |
| `iOS/App/Persistence/ChapterCacheStore.swift` | ✅ | 章节缓存 |
| `iOS/App/Persistence/ReadingProgressStore.swift` | ✅ | 阅读进度 |

## 4. 正文能力状态表

| 能力项 | 状态 | 说明 |
|--------|------|------|
| 正文加载 | ✅ Mock 实现 | ReadingFlowCoordinator.selectChapter() |
| ContentService 接口 | ✅ 静态审计确认 | Reader-Core public API |
| MockContentService | ✅ Mock 实现 | ShellAssembly.makeMockReadingFlowCoordinator() |
| PlaceholderContentService | ✅ Placeholder 实现 | 抛出 realCoreNotAvailable |
| DefaultContentService | ⚠️ 未装配 | 存在但未传入 ShellAssembly |
| Mock/Placeholder 可区分 | ✅ 静态审计确认 | via ReaderCoreServiceProvider.mode |
| real mode 真实正文 | ❌ 未实现 | 当前返回 unsupported |
| 正文状态流 | ✅ 静态审计确认 | contentPage + isLoading + currentError |
| 空正文处理 | ✅ Mock 实现 | MockScenario.empty |
| 正文失败处理 | ✅ Mock 实现 | MockScenario.networkFailure/parserFailure |
| unsupported 处理 | ✅ Mock 实现 | MockScenario.unsupported |
| TOC → Content 连接 | ✅ 静态审计确认 | TOCView → ContentView |
| 上一章/下一章导航 | ✅ 静态审计确认 | ContentView 导航方法 |
| 章节缓存 | ✅ 静态审计确认 | ChapterCacheStore |
| 阅读进度 | ✅ 静态审计确认 | ReadingProgressStore |

## 5. ContentService 契约

### 协议定义

```swift
public protocol ContentService {
    func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage
}
```

| 契约项 | 说明 |
|--------|------|
| 输入 | BookSource + chapterURL (章节 URL) |
| 输出 | ContentPage |
| 错误 | throws ReaderError |

### ContentPage 数据结构

```swift
public struct ContentPage {
    public let title: String
    public let content: String
    public let chapterURL: String
    public let nextChapterURL: String?
}
```

## 6. MockContentService 契约

### 实现路径

```swift
// ShellAssembly.MockContentService
public final class MockContentService: ContentService {
    private let provider: ReaderCoreServiceProvider
    
    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        let state = await provider.getChapterContent(chapterURL: chapterURL)
        switch state {
        case .loaded(let page): return page
        case .empty: throw AppReaderError(...)
        case .failed(let error): throw error
        case .unsupported(let reason): throw AppReaderError(...)
        case .partial(let page, _): return page
        }
    }
}
```

### MockReaderCoreService.getChapterContent()

| MockScenario | 行为 |
|--------------|------|
| .success | 返回 mockContentPage |
| .partial | 返回 mockContentPage + warning |
| .unsupported | 返回 .unsupported |
| .empty | 返回 .empty |
| .parserFailure | 返回 .failed(AppReaderError.parser) |
| .networkFailure | 返回 .failed(AppReaderError.network) |
| .jsRequired | 返回 .failed(AppReaderError.jsRequired) |
| .loginRequired | 返回 .failed(AppReaderError.loginRequired) |

### MockContentPage 结构

```swift
public static let mockContentPage: ContentPage = ContentPage(
    title: "第一章 山村少年",
    content: "夕阳西下，余晖洒落在这个偏僻的小山村里...",
    chapterURL: "https://example.com/book/1/chapter/1",
    nextChapterURL: "https://example.com/book/1/chapter/2"
)
```

## 7. PlaceholderContentService 契约

### 实现路径

```swift
// PlaceholderServices.swift
public final class PlaceholderContentService: ContentService {
    public init() {}
    
    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        throw PlaceholderServiceError.realCoreNotAvailable
    }
}
```

| 契约项 | 说明 |
|--------|------|
| 依赖 | 无 |
| 行为 | 始终抛出 PlaceholderServiceError.realCoreNotAvailable |
| 错误类型 | PlaceholderServiceError |

## 8. DefaultContentService 当前状态

### 实现路径

```swift
// DefaultContentService.swift
public final class DefaultContentService: ContentService {
    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder
    private let contentParser: ContentParser
    
    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        let request = try requestBuilder.makeContentRequest(source: source, chapterURL: chapterURL)
        let response = try await httpClient.send(request)
        
        guard response.statusCode >= 200 && response.statusCode < 300 else {
            throw ReaderError.network(...)
        }
        
        return try contentParser.parseContentResponse(response.data, source: source, chapterURL: chapterURL)
    }
}
```

### 当前状态

| 契约项 | 说明 |
|--------|------|
| 依赖 | HTTPClient, RequestBuilder, ContentParser |
| 行为 | 构造 HTTP 请求，调用 Parser 解析响应 |
| 状态 | ⚠️ 依赖 Reader-Core public API，构造参数未在 ShellAssembly 中传入 |

**问题**: DefaultContentService 需要 HTTPClient/RequestBuilder/ContentParser，但 ShellAssembly.makePlaceholderReadingFlowCoordinator() 未传入这些参数。

## 9. ReadingFlowCoordinator 正文流程

### 正文入口

```swift
public func selectChapter(_ chapter: TOCItem) async {
    selectedChapter = chapter
    contentPage = nil
    
    guard let source = selectedSource else { return }
    
    isLoading = true
    currentError = nil
    defer { isLoading = false }
    
    do {
        contentPage = try await contentService.fetchContent(source: source, chapterURL: chapter.chapterURL)
    } catch let error as ReaderError {
        currentError = error
        await logError(error, stage: "CONTENT")
    } catch {
        let readerError = ReaderError(...)
        currentError = readerError
        await logError(readerError, stage: "CONTENT")
    }
}
```

### 状态维护

| 状态 | 说明 |
|------|------|
| contentPage: ContentPage? | 正文内容 |
| selectedChapter: TOCItem? | 选中章节 |
| isLoading | 加载状态 |
| currentError: ReaderError? | 当前错误 |

### 流程连接

| 步骤 | 连接 |
|------|------|
| TOC → Content | TOCView → ContentView(chapter: TOCItem) |
| Content → 上一章 | previousChapterAction → selectChapter(previous) |
| Content → 下一章 | nextChapterAction → selectChapter(next) |

## 10. 章节缓存边界

### ChapterCacheStore 实现

```swift
public final class ChapterCacheStore: @unchecked Sendable {
    public func loadEntry(chapterURL: String, sourceID: String) throws -> ChapterCacheEntry?
    public func saveEntry(_ entry: ChapterCacheEntry) throws
    public func removeEntry(chapterURL: String, sourceID: String) throws
}
```

### 缓存结构

| 契约项 | 说明 |
|--------|------|
| 缓存 Key | "\(sourceID)_\(chapterURL)" |
| 存储格式 | JSON 文件 (chapter_cache.json) |
| 缓存内容 | ChapterCacheEntry (元数据 + 正文) |
| 线程安全 | NSLock |

### 缓存边界

| 检查项 | 状态 |
|--------|------|
| 是否缓存正文 | ✅ | ChapterCacheEntry 包含正文内容 |
| 是否绑定书源 | ✅ | Key 包含 sourceID |
| 是否有测试覆盖 | ❌ | 无专门测试 |
| 是否依赖 Reader-Core | ❌ | 本仓实现 |

## 11. 状态流与错误契约

### ContentView 状态映射

| 状态 | 来源 |
|------|------|
| .loading | coordinator.isLoading |
| .error | coordinator.currentError != nil |
| .content | coordinator.contentPage != nil |
| .empty | 其他情况 |

### 错误映射

| 错误来源 | 映射到 |
|----------|--------|
| AppReaderError.network | currentError |
| AppReaderError.parser | currentError |
| AppReaderError.unsupported | currentError |
| PlaceholderServiceError | currentError |

### 章节导航边界

```swift
// 上一章边界
guard currentIndex > 0 else { return nil }

// 下一章边界
guard currentIndex < coordinator.tocItems.count - 1 else { return nil }
```

## 12. 测试覆盖

### 当前测试覆盖

| 测试项 | 覆盖 | 文件 |
|--------|------|------|
| Mock 正文成功 | ⚠️ 间接覆盖 | MockReaderCoreService |
| Mock 正文失败 | ⚠️ 间接覆盖 | MockReaderCoreService |
| Placeholder 返回 unsupported | ❌ | 无测试 |
| TOC → Content 连接 | ❌ | 无测试 |
| 上一章/下一章 | ❌ | 无测试 |
| ChapterCacheStore | ❌ | 无测试 |

### 边界检查结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=64) |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 13. P0 / P1 / P2 缺口清单

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-1 | ContentService 契约测试 | 中 | 需添加 ContentService 契约测试 |
| P1-2 | TOC → Content 连接测试 | 中 | 确认导航流程 |
| P1-3 | 上一章/下一章边界测试 | 低 | 边界状态验证 |
| P1-4 | ChapterCacheStore 测试 | 低 | 缓存行为验证 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 正文缓存精细控制 | 低 |
| P2-2 | 缓存迁移版本 | 低 |
| P2-3 | 预加载 | 中 |
| P2-4 | 离线阅读 | 中 |
| P2-5 | 阅读位置精细恢复 | 低 |
| P2-6 | 多源正文 fallback | 高 |

### 不属于当前 S5 的任务

| 任务 | 归属 | 说明 |
|------|------|------|
| 真实 Reader-Core 正文接入 | S1.P2 | 需 Reader-Core 可用环境 |
| DefaultContentService 真实装配 | S1.P2 | 需 Reader-Core API 验证 |

## 14. 与 Reader-Core 的边界说明

| 边界项 | 说明 |
|--------|------|
| ContentService 协议 | ✅ public API (ReaderCoreProtocols) |
| ContentPage | ✅ public API (ReaderCoreModels) |
| BookSource | ✅ public API (ReaderCoreModels) |
| HTTPClient | ✅ public API |
| RequestBuilder | ✅ public API |
| ContentParser | ✅ public API |
| MockContentService | ⚠️ 本仓实现，不依赖 Reader-Core 内部 |

**边界保证**: 正文流程使用 Reader-Core public API，不直接依赖 Parser/Runtime 内部实现。

## 15. S5.P1 推荐能力建设任务

**任务 ID**: S5.P1
**任务名称**: ContentService 契约测试与状态流补强

**任务内容**:
1. 添加 ContentService 契约测试
2. 验证 Mock/Placeholder/Real 路由
3. 验证 TOC → Content 流程连接
4. 验证上一章/下一章边界

**前提条件**: 无需 Reader-Core

## 16. 本轮未做事项

| 事项 | 原因 |
|------|------|
| ContentService 契约测试 | 待 S5.P1 实现 |
| TOC → Content 连接测试 | 待 S5.P1 实现 |
| 真实 Core 接入 | S1.P2 暂停 |
| 正文缓存精细控制 | P2 优化项 |
