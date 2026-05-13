# Reader-iOS Code Wiki

> **文档版本**: 1.1.0
> **更新日期**: 2026-05-13
> **维护者**: Reader-iOS Team
> **审计状态**: 已基于真实代码审计

---

## 1. 项目定位

### 1.1 当前仓库角色

- **仓库名称**: Reader-iOS
- **仓库角色**: Reader-iOS 主仓（反向拆仓后）
- **仓库路径**: `/workspace`

### 1.2 与 Reader-Core 的关系

| 关系类型 | 说明 |
|---------|------|
| 上游仓库 | `github.com/minliny/Reader-Core` |
| 依赖方式 | 通过 `iOS/Package.swift` 依赖 Reader-Core 的公开 package/products |
| 路径策略 | 本地开发：`../Reader-Core`；CI：`https://github.com/minliny/Reader-Core.git` exact:0.1.0 |
| 边界约束 | 仅 `iOS/Shell/**` 可 import Core internal modules |

### 1.3 当前开发范围

- iOS App shell / UX / features / integration
- Persistence 层本地存储
- Navigation / Route 导航系统
- Core public API 边界适配
- Shell Assembly 依赖注入

### 1.4 不属于当前仓库的内容

以下内容属于 Reader-Core，不在本仓库实现范围内：

| 内容 | 说明 |
|------|------|
| `ReaderCoreParser` | Parser 内部实现 |
| `ReaderCoreJSRenderer` | JS 渲染引擎 |
| `ReaderCoreNetwork` | 网络请求实现 |
| `ReaderCoreCache` | 缓存实现 |
| `NonJSRuleScheduler` | 非 JS 规则调度器（Core internal） |
| `NonJSParserEngine` | 非 JS 解析引擎（Core internal） |
| `SelectorEngine` | 选择器引擎（Core internal） |

---

## 2. 目录结构总览

```
/workspace/
├── .github/
│   ├── workflows/
│   │   └── ios-shell-ci.yml           # iOS Shell CI 工作流
│   └── agents/                         # AI Agent 配置
│
├── .trae/
│   ├── Agents/                         # AI Agent 定义
│   └── rules/                          # 项目规则
│
├── docs/                               # 项目文档
│   ├── AI_HANDOFF/                     # AI 交接文档
│   ├── PLANNING/                       # 规划文档
│   └── CODE_WIKI.md                    # 本文档
│
├── iOS/
│   ├── App/                            # App 入口与持久化层
│   │   ├── AppEntry.swift              # 应用入口配置
│   │   ├── ReaderApp.swift             # App 主文件
│   │   └── Persistence/                # 持久化存储（ReaderAppPersistence target）
│   │       ├── BookSourceStore.swift
│   │       ├── BookshelfStore.swift
│   │       ├── ChapterCacheStore.swift
│   │       ├── ReaderSettingsStore.swift
│   │       └── ReadingProgressStore.swift
│   │
│   ├── AppSupport/                     # 应用支撑模型（ReaderAppSupport target，无依赖）
│   │   └── Sources/
│   │       ├── BookshelfItem.swift
│   │       ├── ChapterCacheEntry.swift
│   │       ├── ReaderDisplaySettings.swift
│   │       ├── ReadingProgress.swift
│   │       ├── SourceIdentity.swift
│   │       └── ReaderAppSupportMarker.swift
│   │
│   ├── CoreBridge/                     # Core 桥接层（Shell target）
│   │   ├── ReaderCoreServiceProvider.swift
│   │   ├── MockReaderCoreService.swift
│   │   ├── LoadState.swift
│   │   ├── AppReaderError.swift
│   │   └── SourceIdentityFactory.swift
│   │
│   ├── CoreIntegration/                # Core 集成层（Shell target）
│   │   ├── ReadingFlowCoordinator.swift
│   │   ├── DefaultBookSourceDecoder.swift
│   │   └── InMemoryBookSourceRepository.swift
│   │
│   ├── Shell/                          # Shell 装配层（唯一可 import Core internal）
│   │   ├── ShellAssembly.swift
│   │   └── ReaderShellEnvironment.swift
│   │
│   ├── Features/                       # 功能模块 UI（ReaderApp target）
│   │   ├── BookSources/
│   │   ├── Search/
│   │   ├── BookDetail/
│   │   ├── ChapterList/
│   │   ├── Reader/
│   │   ├── Bookshelf/
│   │   ├── Common/
│   │   ├── TOC/
│   │   ├── Content/
│   │   └── Debug/
│   │
│   ├── Navigation/                     # 导航（ReaderApp target）
│   │   ├── Route.swift
│   │   └── AppNavigationState.swift
│   │
│   ├── Surface/                        # 统一状态展示（ReaderApp target）
│   │   ├── AppEmptySurface.swift
│   │   ├── AppErrorSurface.swift
│   │   └── AppLoadingSurface.swift
│   │
│   ├── Modules/                       # 平台兼容性模块
│   │   └── Reader/
│   │       ├── ReaderModuleBoundary.swift
│   │       └── Color+PlatformCompat.swift
│   │
│   ├── Tests/                          # 测试
│   │   ├── ShellSmokeTests/           # Shell 冒烟测试
│   │   ├── ReaderAppPersistenceTests/  # 持久化测试
│   │   ├── ReaderAppPersistenceTestRunner/ # 独立测试运行器
│   │   └── ReaderAppTests/            # App 测试（占位）
│   │
│   ├── Info.plist                      # iOS 配置
│   └── Package.swift                   # Swift Package 配置
│
└── scripts/
    └── check_ios_boundary.sh           # iOS 边界检查脚本
```

---

## 3. Swift Package / Target 架构

### 3.1 Package.swift 读取结果

**位置**: `iOS/Package.swift`

```swift
// swift-tools-version: 5.9
name: "ReaderApp"
platforms: [.iOS(.v15), .macOS(.v13)]

dependencies: [
    .package(path: "../Reader-Core")  // 本地开发依赖
]

targets: [
    ReaderShellValidation,   // Shell 组合验证
    ReaderAppSupport,        // 纯数据模型
    ReaderAppPersistence,    // 持久化存储
    ReaderApp,               // 主应用
    ShellSmokeTests,         // Shell 测试
    ReaderAppPersistenceTests,  // 持久化测试
    ReaderAppPersistenceTestRunner  // 测试运行器
]
```

### 3.2 Target 依赖关系

| Target 名称 | 依赖 Target | 依赖外部 Package | 职责 |
|------------|------------|-----------------|------|
| `ReaderAppSupport` | 无 | 无 | 纯数据模型，无任何外部依赖 |
| `ReaderAppPersistence` | `ReaderAppSupport` | `ReaderCoreModels` | 持久化存储层 |
| `ReaderShellValidation` | `ReaderAppSupport` | `ReaderCoreFoundation`, `ReaderCoreModels`, `ReaderCoreProtocols`, `ReaderCoreParser`, `ReaderCoreNetwork`, `ReaderPlatformAdapters` | Shell 组合验证，唯一可 import Core internal 的 target |
| `ReaderApp` | `ReaderShellValidation`, `ReaderAppSupport`, `ReaderAppPersistence` | 无 | 主应用入口，Feature UI 层 |
| `ShellSmokeTests` | `ReaderShellValidation`, `ReaderAppSupport` | `ReaderCoreModels`, `ReaderCoreProtocols` | Shell 冒烟测试 |
| `ReaderAppPersistenceTests` | `ReaderAppPersistence`, `ReaderAppSupport` | 无 | 持久化层测试 |
| `ReaderAppPersistenceTestRunner` | `ReaderAppPersistence`, `ReaderAppSupport` | 无 | 独立测试运行器 |

### 3.3 外部 Reader-Core Package 依赖

| Product | 用途 | 导入限制 |
|---------|------|---------|
| `ReaderCoreFoundation` | 核心基础设施类型 | 允许 |
| `ReaderCoreModels` | 数据模型 | 允许 |
| `ReaderCoreProtocols` | 协议定义 | 允许 |
| `ReaderCoreParser` | Parser 实现 | **仅 Shell 层可用** |
| `ReaderCoreNetwork` | 网络请求 | **仅 Shell 层可用** |
| `ReaderPlatformAdapters` | 平台适配器 | 允许 |

---

## 4. App 层架构

### 4.1 ReaderApp Target 入口

- **主文件**: `iOS/App/ReaderApp.swift`
- **入口配置**: `iOS/App/AppEntry.swift`
- **导航状态**: `iOS/Navigation/AppNavigationState.swift`

### 4.2 模块职责

| 模块 | 路径 | 职责 |
|------|------|------|
| `App/` | `iOS/App/` | App 入口、ReaderApp 主文件 |
| `Features/` | `iOS/Features/` | 页面 UI 和 ViewModel |
| `Navigation/` | `iOS/Navigation/` | 路由和导航状态管理 |
| `Surface/` | `iOS/Surface/` | 统一状态展示组件（Empty/Error/Loading） |

### 4.3 主要页面和 ViewModel

| 页面 | ViewModel | 状态类型 |
|------|-----------|----------|
| 书源管理 | `BookSourceViewModel` | `BookSourceImportState` |
| 搜索 | `SearchViewModel` | `SearchState` |
| 书籍详情 | (内嵌) | - |
| 目录 | `ChapterListViewModel` | `ChapterListState` |
| 阅读 | `ReaderViewModel` | `ReaderState` |
| 书架 | `BookshelfViewModel` | `BookshelfState` |

### 4.4 当前 UI 实现状态

**现状**: UI 层通过 `MockReaderCoreService` 驱动，未接入真实 Core 解析能力。

---

## 5. Shell 与依赖注入

### 5.1 ShellAssembly

**位置**: `iOS/Shell/ShellAssembly.swift`

**职责**: 依赖注入入口，组合 `ReadingFlowCoordinator` 所需的所有依赖。

```swift
@MainActor
public enum ShellAssembly {
    // 当前实现：返回 Mock 模式
    public static func makeMockReadingFlowCoordinator() -> ReadingFlowCoordinator
    public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator
}
```

**组合的服务**:
- `MockSearchService`: 包装 `ReaderCoreServiceProvider.searchBooks`
- `MockTOCService`: 包装 `ReaderCoreServiceProvider.getChapterList`
- `MockContentService`: 包装 `ReaderCoreServiceProvider.getChapterContent`

### 5.2 ReaderShellEnvironment

**位置**: `iOS/Shell/ReaderShellEnvironment.swift`

```swift
public struct ReaderShellEnvironment {
    public var supportsDebugOverlay: Bool
}
```

### 5.3 ReaderModuleBoundary

**位置**: `iOS/Modules/Reader/ReaderModuleBoundary.swift`

```swift
public struct ReaderModuleBoundary {
    public var canImportBookSource: Bool
    public var canSearch: Bool
    public var canReadContent: Bool
}
```

### 5.4 App 如何获得 Core 服务

```
App 层
    ↓
ShellAssembly.makeMockReadingFlowCoordinator()
    ↓
ReadingFlowCoordinator (持有 MockSearchService/MockTOCService/MockContentService)
    ↓
ReaderCoreServiceProvider
    ↓
MockReaderCoreService (当前) / 未来: Real Core
```

### 5.5 Mock 和 Real Core 切换关系

**当前状态**: `ReaderCoreServiceProvider` 默认使用 `MockReaderCoreService`

```swift
public final class ReaderCoreServiceProvider: @unchecked Sendable {
    private var mode: ServiceMode = .mock  // .mock 或 .real
}
```

**切换方式**: 通过 `setMode(_:)` 方法切换（需后续实现真实 Core 接入）

---

## 6. CoreBridge / CoreIntegration

### 6.1 ReaderCoreServiceProvider

**位置**: `iOS/CoreBridge/ReaderCoreServiceProvider.swift`

**职责**: iOS 与 Reader-Core 之间的唯一服务入口，统一管理 Mock/Real 服务。

```swift
public final class ReaderCoreServiceProvider: @unchecked Sendable {
    public static let shared = ReaderCoreServiceProvider()

    // 核心方法
    func validateBookSource(from data: Data) async -> LoadState<BookSource>
    func searchBooks(keyword: String, page: Int) async -> LoadState<[SearchResultItem]>
    func getBookDetail(bookURL: String) async -> LoadState<SearchResultItem>
    func getChapterList(bookURL: String) async -> LoadState<[TOCItem]>
    func getChapterContent(chapterURL: String) async -> LoadState<ContentPage>
}
```

### 6.2 MockReaderCoreService

**位置**: `iOS/CoreBridge/MockReaderCoreService.swift`

**职责**: 提供 Mock 数据，支持 UI 在 Core 未完成时独立开发。

**Mock 场景**:

| Scenario | 用途 |
|----------|------|
| `.success` | 正常成功 |
| `.partial(warning)` | 部分成功带警告 |
| `.unsupported(reason)` | 不支持 |
| `.empty` | 空结果 |
| `.parserFailure` | 解析失败 |
| `.networkFailure` | 网络失败 |
| `.jsRequired` | 需要 JS |
| `.loginRequired` | 需要登录 |

**Mock 数据**:
- 3 本搜索结果（凡人修仙传、仙逆、一念永恒）
- 5 章目录
- 一段完整章节正文

### 6.3 LoadState

**位置**: `iOS/CoreBridge/LoadState.swift`

**职责**: 统一加载状态抽象。

```swift
public enum LoadState<Value> {
    case idle
    case loading
    case loaded(Value)
    case empty
    case failed(AppReaderError)
    case unsupported(String)
    case partial(Value, warning: String)
}
```

### 6.4 AppReaderError

**位置**: `iOS/CoreBridge/AppReaderError.swift`

**职责**: iOS App 层错误定义。

```swift
public struct AppReaderError: Error, Sendable {
    public enum Code: Sendable {
        case unknown, network, parser, jsRequired, loginRequired
        case unsupported, partial, timeout, notFound, invalidResponse
    }
    public let code: Code
    public let message: String
    public let stage: String?
    public let underlyingError: Error?
}
```

### 6.5 ReadingFlowCoordinator

**位置**: `iOS/CoreIntegration/ReadingFlowCoordinator.swift`

**职责**: 阅读流程协调器，管理完整阅读链路的状态流转。

**核心流程**:

```
importBookSource → search → selectBook → selectChapter → (Reading)
```

**依赖注入**:

```swift
public init(
    bookSourceRepository: BookSourceRepository,
    bookSourceDecoder: BookSourceDecoder,
    searchService: SearchService,
    tocService: TOCService,
    contentService: ContentService,
    errorLogger: ErrorLogger
)
```

### 6.6 DefaultBookSourceDecoder

**位置**: `iOS/CoreIntegration/DefaultBookSourceDecoder.swift`

**职责**: 书源 JSON 解码实现。

```swift
public final class DefaultBookSourceDecoder: BookSourceDecoder {
    public func decodeBookSource(from data: Data) throws -> BookSource
}
```

### 6.7 InMemoryBookSourceRepository

**位置**: `iOS/CoreIntegration/InMemoryBookSourceRepository.swift`

**职责**: 内存书源仓储实现。

```swift
public final class InMemoryBookSourceRepository: BookSourceRepository, @unchecked Sendable
```

### 6.8 SourceIdentityFactory

**位置**: `iOS/CoreBridge/SourceIdentityFactory.swift`

**职责**: SourceIdentity 工厂方法。

```swift
public enum SourceIdentityFactory {
    public static func from(searchResult: SearchResultItem) -> SourceIdentity
}
```

---

## 7. Persistence

### 7.1 BookSourceStore

**位置**: `iOS/App/Persistence/BookSourceStore.swift`

| 属性 | 值 |
|------|-----|
| Target | `ReaderAppPersistence` |
| 存储路径 | `ApplicationSupport/ReaderApp/book_sources.json` |
| 线程安全 | `NSLock` 保护 |
| 序列化 | JSON / Codable |

**核心方法**:

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `load() async` | `[BookSource]` | 加载所有书源 |
| `save([BookSource]) async` | `Void` | 保存书源列表 |
| `add(BookSource) async` | `Void` | 添加书源 |
| `delete(id:) async` | `Void` | 删除书源 |
| `update(BookSource) async` | `Void` | 更新书源 |
| `toggleEnabled(id:) async` | `Void` | 切换启用状态 |

---

### 7.2 BookshelfStore

**位置**: `iOS/App/Persistence/BookshelfStore.swift`

| 属性 | 值 |
|------|-----|
| Target | `ReaderAppPersistence` |
| 存储路径 | `Documents/bookshelf.json` |
| 线程安全 | `NSLock` 保护 |
| 序列化 | JSON / Codable |

**核心方法**:

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `loadItems()` | `[BookshelfItem]` | 加载书架项 |
| `saveItems([BookshelfItem])` | `Void` | 保存书架 |
| `addOrUpdate(BookshelfItem)` | `Void` | 添加或更新 |
| `remove(id:)` | `Void` | 删除 |
| `updateProgress(...)` | `Void` | 更新阅读进度 |
| `find(bookURL:sourceID:)` | `BookshelfItem?` | 查找 |

---

### 7.3 ChapterCacheStore

**位置**: `iOS/App/Persistence/ChapterCacheStore.swift`

| 属性 | 值 |
|------|-----|
| Target | `ReaderAppPersistence` |
| 存储路径 | `Documents/chapter_cache.json` |
| 线程安全 | `NSLock` 保护 |
| 序列化 | JSON / Codable |
| 缓存策略 | 仅记录元数据（章节 URL、标题、状态），不含正文内容 |

**核心方法**:

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `loadEntry(chapterURL:sourceID:)` | `ChapterCacheEntry?` | 加载缓存条目 |
| `saveEntry(ChapterCacheEntry)` | `Void` | 保存缓存条目 |
| `removeEntry(chapterURL:sourceID:)` | `Void` | 删除缓存条目 |

**注意**: 当前实现仅存储元数据，不含正文内容。完整离线缓存待后续实现。

---

### 7.4 ReaderSettingsStore

**位置**: `iOS/App/Persistence/ReaderSettingsStore.swift`

| 属性 | 值 |
|------|-----|
| Target | `ReaderAppPersistence` |
| 存储路径 | `Documents/reader_settings.json` |
| 线程安全 | `NSLock` 保护 |
| 序列化 | JSON / Codable |

**核心方法**:

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `loadSettings()` | `ReaderDisplaySettings` | 加载设置（文件不存在返回 default） |
| `saveSettings(ReaderDisplaySettings)` | `Void` | 保存设置 |
| `resetToDefaults()` | `Void` | 重置为默认 |

---

### 7.5 ReadingProgressStore

**位置**: `iOS/App/Persistence/ReadingProgressStore.swift`

| 属性 | 值 |
|------|-----|
| Target | `ReaderAppPersistence` |
| 存储路径 | `Documents/reading_progress.json` |
| 线程安全 | `NSLock` 保护 |
| 序列化 | JSON / Codable |

**核心方法**:

| 方法 | 返回类型 | 描述 |
|------|---------|------|
| `loadProgress(bookID:)` | `ReadingProgress?` | 加载进度 |
| `saveProgress(ReadingProgress)` | `Void` | 保存进度 |
| `removeProgress(bookID:)` | `Void` | 删除进度 |

---

## 8. AppSupport 数据模型

### 8.1 BookshelfItem

**位置**: `iOS/AppSupport/Sources/BookshelfItem.swift`

```swift
public struct BookshelfItem: Codable, Identifiable, Equatable {
    public let id: String
    public let sourceID: String
    public let sourceName: String?
    public let bookURL: String
    public let title: String
    public let author: String?
    public let coverURL: String?
    public let latestChapter: String?
    public let addedAt: Date
    public var updatedAt: Date
    public var lastReadChapterTitle: String?
    public var lastReadChapterURL: String?
    public var readingProgress: Double
}
```

### 8.2 ChapterCacheEntry

**位置**: `iOS/AppSupport/Sources/ChapterCacheEntry.swift`

```swift
public enum ChapterCacheStatus: String, Codable {
    case notCached, cached, failed
}

public struct ChapterCacheEntry: Codable, Equatable {
    public let sourceID: String
    public let bookURL: String
    public let chapterURL: String
    public let chapterTitle: String
    public let cachedAt: Date
    public var status: ChapterCacheStatus
}
```

### 8.3 ReaderDisplaySettings

**位置**: `iOS/AppSupport/Sources/ReaderDisplaySettings.swift`

```swift
public enum ReaderBackgroundMode: String, Codable, CaseIterable {
    case light, sepia, dark
}

public struct ReaderDisplaySettings: Codable, Equatable {
    public var fontSize: Int              // 默认 18
    public var fontFamily: String         // 默认 "SF Pro Display"
    public var lineSpacing: Double        // 默认 8.0
    public var paragraphSpacing: Double   // 默认 16.0
    public var horizontalPadding: Double  // 默认 16.0
    public var verticalPadding: Double    // 默认 16.0
    public var backgroundMode: ReaderBackgroundMode  // 默认 light
}
```

### 8.4 ReadingProgress

**位置**: `iOS/AppSupport/Sources/ReadingProgress.swift`

```swift
public struct ReadingProgress: Codable, Equatable {
    public let bookID: String
    public let sourceID: String
    public let bookURL: String
    public let chapterURL: String
    public let chapterTitle: String
    public var progressRatio: Double
    public var updatedAt: Date
}
```

### 8.5 SourceIdentity

**位置**: `iOS/AppSupport/Sources/SourceIdentity.swift`

```swift
public struct SourceIdentity: Codable, Equatable, Hashable {
    public let id: String
    public let name: String?
    public let baseURL: String?

    public static let unknown = SourceIdentity(id: "unknown", name: nil, baseURL: nil)
}
```

### 8.6 ReaderAppSupportMarker

**位置**: `iOS/AppSupport/Sources/ReaderAppSupportMarker.swift`

```swift
public enum ReaderAppSupportMarker {
    public static let version: String
}
```

### 8.7 为什么放在 ReaderAppSupport？

**设计原则**:
- `ReaderAppSupport` 是一个无外部依赖的 target
- 数据模型可被 `ReaderApp` 和 `ReaderAppPersistence` 同时依赖
- 避免循环依赖：Persistence ↔ App

---

## 9. Navigation / Route

### 9.1 AppNavigationState

**位置**: `iOS/Navigation/AppNavigationState.swift`

```swift
@MainActor
public final class AppNavigationState: ObservableObject {
    @Published public var currentRoute: Route = .home
    @Published public var navigationPath: [Route] = []

    public func navigate(to route: Route)
    public func push(_ route: Route)
    public func goBack()
    public func popToRoot()
}
```

### 9.2 Route

**位置**: `iOS/Navigation/Route.swift`

```swift
public enum Route: Hashable {
    case home
    case bookSourceImport
    case search
    case toc(bookTitle: String, bookAuthor: String?)
    case content(chapterTitle: String)
}
```

### 9.3 页面跳转路径

```
Home
  ├── 书源导入 → Home
  └── 搜索 → 书籍详情/TOC → 阅读
```

### 9.4 Deep Link 支持

**当前状态**: 内部导航，无 deep link 支持。

---

## 10. 边界约束

### 10.1 Reader-iOS 可以依赖什么

| 类型 | 示例 |
|------|------|
| Reader-Core public products | `ReaderCoreModels`, `ReaderCoreProtocols`, `ReaderCoreFoundation`, `ReaderPlatformAdapters` |
| 本仓 Target | `ReaderAppSupport`, `ReaderAppPersistence`, `ReaderShellValidation` |
| 系统框架 | Foundation, SwiftUI, Combine |

### 10.2 Reader-iOS 禁止依赖什么

| 类型 | 示例 |
|------|------|
| Core internal modules | `ReaderCoreParser`, `ReaderCoreNetwork`, `ReaderCoreCache`, `ReaderCoreExecution` |
| Core internal engines | `NonJSRuleScheduler`, `NonJSParserEngine`, `SelectorEngine` |
| Core 内部路径 | `Core/`, `samples/`, `tools/`, `Adapters/`, `Platforms/` |
| Core workflows | `core-swift-tests.yml`, `fixture-toc-regression-macos.yml` 等 |
| Core docs | `docs/API_SNAPSHOT`, `docs/architecture` 等 |

### 10.3 边界检查脚本规则

**位置**: `scripts/check_ios_boundary.sh`

**禁止的模块**（在 restricted_paths 下）:
```bash
readonly forbidden_modules=(
  "ReaderCoreNetwork"
  "ReaderCoreParser"
  "ReaderCoreCache"
  "ReaderCoreExecution"
)
```

**禁止的路径**:
```bash
readonly forbidden_root_paths=(
  "Core"
  "samples"
  "tools"
  "Adapters"
  "Platforms"
  "Package.swift"
)
```

**受限路径**（需检查 import）:
```bash
readonly restricted_paths=(
  "iOS/App"
  "iOS/CoreIntegration"
  "iOS/Features"
  "iOS/Modules"
  "iOS/Shell"
  "iOS/Tests"
)
```

### 10.4 如何运行边界检查

```bash
chmod +x scripts/check_ios_boundary.sh
./scripts/check_ios_boundary.sh
```

**输出**: `result=PASS` 或 `result=FAIL` + 违规列表

---

## 11. 运行方式

### 11.1 配置依赖

**前置条件**: Reader-Core 必须在同级目录

```bash
# 方法 1: 本地开发
cd ..
git clone https://github.com/minliny/Reader-Core.git
# 确保路径为: ../Reader-Core

# 方法 2: CI 自动 clone（见 ios-shell-ci.yml）
```

### 11.2 构建项目

```bash
cd iOS
swift build
```

### 11.3 运行测试

```bash
# 所有测试
swift test

# 仅 Shell 冒烟测试
swift test --filter ShellAssemblySmokeTests

# 仅持久化测试
swift test --filter PersistencePublicSurfaceTests

# 独立测试运行器
swift run ReaderAppPersistenceTestRunner
```

### 11.4 iOS Shell CI

```bash
# 边界检查
./scripts/check_ios_boundary.sh

# Shell 组合编译
swift build --package-path iOS --target ReaderShellValidation

# ReaderApp 诊断编译（非必须）
swift build --package-path iOS --target ReaderApp
```

### 11.5 已知环境风险

| 风险 | 描述 | 缓解 |
|------|------|------|
| Reader-Core 相对路径 | `../Reader-Core` 必须在正确位置 | CI 使用 git clone |
| Xcode 限制 | macOS 编译需要 Xcode | CI 使用 macOS runner |
| Swift 版本 | 需 Swift 5.9+ | CI 显示 toolchain 版本 |
| sandbox-exec 限制 | 沙箱环境限制 shell | CI 提供完整环境 |

---

## 12. 测试策略

### 12.1 测试 Targets

| Target | 文件 | 验证内容 |
|--------|------|----------|
| `ShellSmokeTests` | `ShellAssemblySmokeTests.swift` | ShellAssembly 组合根验证 |
| `ShellSmokeTests` | `PublicSurfaceFunctionalSmokeTests.swift` | 公共 API 功能验证 |
| `ShellSmokeTests` | `ReaderAppSupportSkeletonTests.swift` | AppSupport 骨架验证 |
| `ReaderAppPersistenceTests` | `PersistencePublicSurfaceTests.swift` | 持久化层全面测试 |
| `ReaderAppPersistenceTestRunner` | `main.swift` | 独立测试运行器 |
| `ReaderAppTests` | `SmokeTests.swift` | 占位测试 |

### 12.2 测试覆盖

| 测试项 | 覆盖状态 |
|--------|----------|
| ShellAssembly 组合 | ✅ 完整 |
| ReadingFlowCoordinator | ✅ 完整 |
| LoadState 状态转换 | ✅ 完整 |
| 所有 Store CRUD | ✅ 完整 |
| BookSource/BookshelfItem 模型 | ✅ 完整 |
| Settings/Progress 模型 | ✅ 完整 |
| Mock 服务场景 | ✅ 部分 |
| 真实 Core 集成 | ❌ 待实现 |

### 12.3 推荐本地验证命令

```bash
cd iOS

# 1. 边界检查
../scripts/check_ios_boundary.sh

# 2. Shell 编译
swift build --target ReaderShellValidation

# 3. 所有测试
swift test

# 4. 独立测试运行器
swift run ReaderAppPersistenceTestRunner
```

### 12.4 当前缺失的测试覆盖

- 真实 Core 书源解析集成测试
- UI 交互测试
- 网络失败场景测试
- 多书源切换测试
- 阅读进度同步测试

---

## 13. 当前实现状态

| 功能 | 状态 | 说明 |
|------|------|------|
| 书源导入 | ✅ 已实现 | JSON 导入，支持 partial/unsupported |
| 书源管理 | ✅ 已实现 | 增删改查、启用/禁用 |
| 书源存储 | ✅ 已实现 | BookSourceStore → JSON 文件 |
| 搜索 UI | ✅ 已实现 | Mock 实现，未接真实 Core |
| 搜索结果展示 | ✅ 已实现 | Mock 数据驱动 |
| 书籍详情 | ✅ 部分实现 | Mock 数据，真实解析待接入 |
| 目录页 | ✅ 部分实现 | Mock 数据，真实解析待接入 |
| 阅读页 | ✅ 部分实现 | Mock 正文，字体/背景设置已实现 |
| 书架 | ✅ 已实现 | 本地持久化，支持阅读进度 |
| 章节缓存 | ⚠️ 部分实现 | 仅元数据存储，正文缓存待实现 |
| 阅读进度 | ✅ 已实现 | ReadingProgressStore + BookshelfStore |
| 阅读设置 | ✅ 已实现 | 字体大小、背景模式等 |
| 导航 | ✅ 已实现 | Route + AppNavigationState |
| 错误处理 | ✅ 已实现 | AppReaderError + LoadState |
| Mock 服务 | ✅ 已实现 | 8 种场景覆盖 |
| 真实 Core 接入 | 🔄 规划中 | 需 Reader-Core 稳定 |

**状态说明**:
- ✅ 已实现: 代码完整，测试通过
- ⚠️ 部分实现: 基础功能可用，部分能力待完善
- 🔄 规划中: 尚未开始

---

## 14. 风险点

### 14.1 Mock 与真实行为不一致风险

**风险**: Mock 数据行为可能与 Reader-Core 真实实现不同步。
**影响**: UI 开发完成但真实接入时需调整。
**缓解**: 保持 `LoadState` 状态机一致，确保 UI 对任何 `LoadState` 都能正确处理。

### 14.2 iOS 直接引用 Core 内部类型风险

**风险**: 开发者可能绕过 Shell 层直接 import Core internal。
**影响**: 边界破坏，后续迁移困难。
**缓解**: `check_ios_boundary.sh` 检查 + Code Review。

### 14.3 Reader-Core 相对路径依赖风险

**风险**: `../Reader-Core` 路径在某些环境可能失效。
**影响**: 本地构建失败。
**缓解**: CI 使用 git clone canonical URL。

### 14.4 文档与真实代码漂移风险

**风险**: 代码变更后文档未同步更新。
**影响**: 文档失去参考价值。
**缓解**: 定期审计 + 变更时强制更新文档。

### 14.5 规划能力误写为已实现风险

**风险**: 将规划中的功能描述为已完成。
**影响**: 误导后续开发者。
**缓解**: 本次审计已逐一核实，标记清晰。

### 14.6 持久化数据结构后续迁移风险

**风险**: 当前 JSON 文件结构可能在 Reader-Core 接入后需要调整。
**影响**: 数据迁移成本。
**缓解**: 保持模型与 Reader-Core Models 兼容。

---

## 15. 验收清单

### 15.1 文档存在性

- [x] `docs/CODE_WIKI.md` 存在于 `/workspace/docs/`
- [x] 文档版本: 1.1.0
- [x] 审计日期: 2026-05-13

### 15.2 文件准确性

- [x] 所有列出的文件路径均已验证存在
- [x] 所有 Target 名称与 `iOS/Package.swift` 一致
- [x] 所有 Store 职责描述与实现一致
- [x] 所有数据模型字段与实现一致

### 15.3 边界规则

- [x] 禁止依赖列表与 `scripts/check_ios_boundary.sh` 一致
- [x] Shell 层定义清晰（唯一可 import Core internal）
- [x] 允许依赖列表完整

### 15.4 内容准确性

- [x] 未将 Reader-Core 内部实现写成 Reader-iOS 本仓实现
- [x] 未将规划能力写成当前能力
- [x] 所有代码示例基于真实源码
- [x] 所有命令基于仓库真实路径

### 15.5 可维护性

- [x] 文档结构清晰，易于更新
- [x] 每个章节都有明确范围
- [x] 风险点已识别
- [x] 验收清单可操作

---

## 附录: 关键文件索引

| 功能 | 文件路径 | Target |
|------|----------|--------|
| Package 配置 | `iOS/Package.swift` | - |
| 服务入口 | `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | Shell |
| Mock 服务 | `iOS/CoreBridge/MockReaderCoreService.swift` | Shell |
| 状态定义 | `iOS/CoreBridge/LoadState.swift` | Shell |
| 错误定义 | `iOS/CoreBridge/AppReaderError.swift` | Shell |
| 依赖注入 | `iOS/Shell/ShellAssembly.swift` | Shell |
| 流程协调 | `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | Shell |
| 书源存储 | `iOS/App/Persistence/BookSourceStore.swift` | Persistence |
| 书架存储 | `iOS/App/Persistence/BookshelfStore.swift` | Persistence |
| 设置存储 | `iOS/App/Persistence/ReaderSettingsStore.swift` | Persistence |
| 进度存储 | `iOS/App/Persistence/ReadingProgressStore.swift` | Persistence |
| 缓存存储 | `iOS/App/Persistence/ChapterCacheStore.swift` | Persistence |
| 边界检查 | `scripts/check_ios_boundary.sh` | - |
| CI 配置 | `.github/workflows/ios-shell-ci.yml` | - |
