# Reader-iOS Code Wiki

## 项目概述

**项目名称**: Reader-iOS
**仓库角色**: Reader-iOS 主仓（反向拆仓后）
**上游仓库**: Reader-Core (github.com/minliny/Reader-Core)
**项目定义**: 兼容 Legado 书源 JSON 主流字段结构与主流程行为的多端本地客户端项目
**开发阶段**: Phase 0-7 正式开发中
**Clean Room**: 严格遵循 clean-room 原则，禁止复制/翻译/改写 Legado Android 源码

---

## 目录结构

```
/workspace/
├── iOS/
│   ├── App/                          # App 入口与主视图
│   │   ├── AppEntry.swift            # 应用入口配置
│   │   ├── ReaderApp.swift          # App 主文件
│   │   └── Persistence/             # 持久化存储层
│   │       ├── BookSourceStore.swift
│   │       ├── BookshelfStore.swift
│   │       ├── ChapterCacheStore.swift
│   │       ├── ReaderSettingsStore.swift
│   │       └── ReadingProgressStore.swift
│   │
│   ├── AppSupport/                   # 应用支撑模型层（无依赖）
│   │   └── Sources/
│   │       ├── BookshelfItem.swift
│   │       ├── ChapterCacheEntry.swift
│   │       ├── ReaderDisplaySettings.swift
│   │       ├── ReadingProgress.swift
│   │       ├── SourceIdentity.swift
│   │       └── ReaderAppSupportMarker.swift
│   │
│   ├── CoreBridge/                   # Core 桥接层
│   │   ├── ReaderCoreServiceProvider.swift  # Core 服务提供者
│   │   ├── MockReaderCoreService.swift      # Mock 服务实现
│   │   ├── LoadState.swift                  # 统一加载状态
│   │   ├── AppReaderError.swift             # 应用级错误
│   │   └── SourceIdentityFactory.swift
│   │
│   ├── CoreIntegration/              # Core 集成层
│   │   ├── ReadingFlowCoordinator.swift     # 阅读流程协调器
│   │   ├── DefaultBookSourceDecoder.swift   # 书源解码器
│   │   ├── DefaultSearchService.swift       # 搜索服务
│   │   ├── DefaultTOCService.swift          # 目录服务
│   │   ├── DefaultContentService.swift      # 正文服务
│   │   └── InMemoryBookSourceRepository.swift
│   │
│   ├── Shell/                        # Shell 装配层（唯一可 import Core internal）
│   │   ├── ShellAssembly.swift       # 依赖注入入口
│   │   └── ReaderShellEnvironment.swift
│   │
│   ├── Features/                     # 功能模块
│   │   ├── BookSources/             # 书源管理
│   │   ├── Search/                  # 搜索
│   │   ├── BookDetail/             # 书籍详情
│   │   ├── ChapterList/            # 目录
│   │   ├── Reader/                  # 阅读
│   │   ├── Bookshelf/              # 书架
│   │   ├── Common/                  # 通用组件
│   │   ├── TOC/                     # 目录页
│   │   ├── Content/                 # 内容页
│   │   └── Debug/                   # 调试功能
│   │
│   ├── Navigation/                  # 导航
│   │   ├── Route.swift              # 路由定义
│   │   └── AppNavigationState.swift
│   │
│   ├── Surface/                      # 统一状态展示
│   │   ├── AppEmptySurface.swift
│   │   ├── AppErrorSurface.swift
│   │   └── AppLoadingSurface.swift
│   │
│   ├── Modules/                      # 平台兼容性模块
│   │   └── Reader/
│   │       └── ReaderModuleBoundary.swift
│   │
│   ├── Tests/                        # 测试
│   │   ├── ShellSmokeTests/
│   │   ├── ReaderAppPersistenceTests/
│   │   └── ReaderAppTests/
│   │
│   └── Package.swift                 # Swift Package 配置
│
├── scripts/
│   └── check_ios_boundary.sh         # iOS 边界检查脚本
│
└── docs/                              # 文档
    ├── AI_HANDOFF/                   # AI 交接文档
    ├── PLANNING/                     # 规划文档
    └── PROJECT_STATE_SNAPSHOT.yaml   # 项目状态快照
```

---

## 核心架构设计

### 分层架构图

```
┌─────────────────────────────────────────────────────────────┐
│                     ReaderApp Target                         │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐  │
│  │  Features   │  │ Navigation  │  │      Surface        │  │
│  │   (UI)      │  │   (Route)   │  │ (Empty/Error/Load)  │  │
│  └──────┬──────┘  └──────┬──────┘  └─────────────────────┘  │
│         │                │                                   │
│  ┌──────┴────────────────┴──────┐                           │
│  │         App/Persistence       │                           │
│  │  (BookSourceStore, Bookshelf) │                           │
│  └──────────────┬────────────────┘                           │
└─────────────────┼───────────────────────────────────────────┘
                  │
┌─────────────────┼───────────────────────────────────────────┐
│    ReaderShellValidation Target                              │
│  ┌──────────────┴────────────────┐  ┌──────────────────┐   │
│  │        CoreBridge              │  │   Shell          │   │
│  │  (ServiceProvider, MockService)│  │ (ShellAssembly)  │   │
│  └──────────────┬────────────────┘  └──────────────────┘   │
│  ┌──────────────┴────────────────┐                          │
│  │      CoreIntegration          │                          │
│  │  (ReadingFlowCoordinator)     │                          │
│  └──────────────┬────────────────┘                          │
└─────────────────┼───────────────────────────────────────────┘
                  │ (仅依赖 public products)
┌─────────────────┼───────────────────────────────────────────┐
│              Reader-Core                                     │
│  ┌──────────────┴────────────────┐                          │
│  │  ReaderCoreModels             │                          │
│  │  ReaderCoreProtocols          │                          │
│  │  ReaderCoreFoundation         │                          │
│  │  ReaderCoreParser             │                          │
│  │  ReaderCoreNetwork            │                          │
│  └────────────────────────────────┘                          │
└─────────────────────────────────────────────────────────────┘
```

### Target 依赖关系

| Target | 依赖 | 用途 |
|--------|------|------|
| `ReaderApp` | Shell + AppSupport + Persistence | 主应用入口 |
| `ReaderShellValidation` | Core public products + AppSupport | Shell 验证 |
| `ReaderAppSupport` | 无 | 纯数据模型 |
| `ReaderAppPersistence` | AppSupport + CoreModels | 持久化存储 |

---

## 主要模块详解

### 1. CoreBridge 层

#### ReaderCoreServiceProvider

**位置**: `iOS/CoreBridge/ReaderCoreServiceProvider.swift`

**职责**: 作为 iOS 与 Reader-Core 之间的唯一服务入口，统一管理 Mock/Real 服务切换。

```swift
public final class ReaderCoreServiceProvider: @unchecked Sendable {
    public static let shared = ReaderCoreServiceProvider()
    private var mode: ServiceMode = .mock
    private let mockService: MockReaderCoreService

    // 核心方法
    func validateBookSource(from data: Data) async -> LoadState<BookSource>
    func searchBooks(keyword: String, page: Int) async -> LoadState<[SearchResultItem]>
    func getBookDetail(bookURL: String) async -> LoadState<SearchResultItem>
    func getChapterList(bookURL: String) async -> LoadState<[TOCItem]>
    func getChapterContent(chapterURL: String) async -> LoadState<ContentPage>
}
```

**设计要点**:
- 单例模式，确保全局唯一入口
- `@unchecked Sendable` 支持跨 actor 使用
- `NSLock` 保护 mode 切换
- 支持 Mock 场景注入（测试用）

---

#### MockReaderCoreService

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

---

#### LoadState

**位置**: `iOS/CoreBridge/LoadState.swift`

**职责**: 统一加载状态抽象，覆盖所有 UI 状态需求。

```swift
public enum LoadState<Value> {
    case idle                           // 初始状态
    case loading                        // 加载中
    case loaded(Value)                  // 加载成功
    case empty                          // 空结果
    case failed(AppReaderError)         // 加载失败
    case unsupported(String)            // 不支持
    case partial(Value, warning: String) // 部分成功
}
```

**计算属性**:
```swift
var isLoading: Bool
var value: Value?
var error: AppReaderError?
var isEmpty: Bool
var isUnsupported: Bool
var isPartial: Bool
var warningMessage: String?
```

---

#### AppReaderError

**位置**: `iOS/CoreBridge/AppReaderError.swift`

**职责**: 应用级错误定义，与 UI 展示层解耦。

```swift
public struct AppReaderError: Error, Sendable {
    public enum Code: Sendable {
        case unknown
        case network
        case parser
        case jsRequired
        case loginRequired
        case unsupported
        case partial
        case timeout
        case notFound
        case invalidResponse
    }

    public let code: Code
    public let message: String
    public let stage: String?          // 发生阶段：SEARCH/DETAIL/TOC/CONTENT
    public let underlyingError: Error?
}
```

---

### 2. Shell 层

#### ShellAssembly

**位置**: `iOS/Shell/ShellAssembly.swift`

**职责**: 依赖注入入口，组合 ReadingFlowCoordinator 所需的所有依赖。

```swift
@MainActor
public enum ShellAssembly {
    // Mock 模式（当前默认）
    public static func makeMockReadingFlowCoordinator() -> ReadingFlowCoordinator

    // Real Core 模式（未来）
    public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator
}
```

**组合的 Mock 服务**:
- `MockSearchService`: 包装 `ReaderCoreServiceProvider.searchBooks`
- `MockTOCService`: 包装 `ReaderCoreServiceProvider.getChapterList`
- `MockContentService`: 包装 `ReaderCoreServiceProvider.getChapterContent`

---

### 3. CoreIntegration 层

#### ReadingFlowCoordinator

**位置**: `iOS/CoreIntegration/ReadingFlowCoordinator.swift`

**职责**: 阅读流程协调器，管理完整阅读链路的状态流转。

**核心流程**:

```
importBookSource → search → selectBook → selectChapter → (Reading)
     │                  │           │           │
     └──────────────────┴───────────┴───────────┘
                    (书源选择)
```

**核心方法**:

| 方法 | 触发 | 副作用 |
|------|------|--------|
| `importBookSource(from:)` | 导入书源 | 保存 + 选为当前书源 |
| `search(keyword:)` | 搜索 | 清空书籍/目录/章节选择 |
| `selectBook(_:)` | 选择书籍 | 获取 TOC |
| `selectChapter(_:)` | 选择章节 | 获取正文 |

**依赖注入**:
```swift
public init(
    bookSourceRepository: BookSourceRepository,   // 书源仓储
    bookSourceDecoder: BookSourceDecoder,         // 书源解码
    searchService: SearchService,                 // 搜索服务
    tocService: TOCService,                        // 目录服务
    contentService: ContentService,                // 正文服务
    errorLogger: ErrorLogger                       // 错误日志
)
```

---

### 4. Persistence 层

#### BookSourceStore

**位置**: `iOS/App/Persistence/BookSourceStore.swift`

**职责**: 书源本地持久化存储。

**存储路径**: `ApplicationSupport/ReaderApp/book_sources.json`

**核心方法**:

| 方法 | 描述 |
|------|------|
| `load() async` | 加载所有书源 |
| `save([BookSource]) async` | 保存书源列表 |
| `add(BookSource) async` | 添加书源 |
| `delete(id:) async` | 删除书源 |
| `update(BookSource) async` | 更新书源 |
| `toggleEnabled(id:) async` | 切换启用状态 |

**线程安全**: `NSLock` 保护读写操作

---

#### BookshelfStore

**职责**: 书架数据持久化（CRUD 操作）

#### ReaderSettingsStore

**职责**: 阅读设置持久化

#### ReadingProgressStore

**职责**: 阅读进度持久化

#### ChapterCacheStore

**职责**: 章节缓存管理（占位设计）

---

### 5. AppSupport 层

#### BookshelfItem

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

---

#### ReaderDisplaySettings

**位置**: `iOS/AppSupport/Sources/ReaderDisplaySettings.swift`

```swift
public struct ReaderDisplaySettings: Codable, Equatable {
    public var fontSize: Int              // 默认 18
    public var fontFamily: String          // 默认 "SF Pro Display"
    public var lineSpacing: Double         // 默认 8.0
    public var paragraphSpacing: Double    // 默认 16.0
    public var horizontalPadding: Double  // 默认 16.0
    public var verticalPadding: Double     // 默认 16.0
    public var backgroundMode: ReaderBackgroundMode  // light/sepia/dark
}
```

---

#### SourceIdentity

**位置**: `iOS/AppSupport/Sources/SourceIdentity.swift`

```swift
public struct SourceIdentity: Codable, Equatable, Hashable {
    public let id: String
    public let name: String?
    public let baseURL: String?

    public static let unknown = SourceIdentity(id: "unknown", name: nil, baseURL: nil)
}
```

---

### 6. Features 层

#### BookSourceViewModel

**位置**: `iOS/Features/BookSources/BookSourceViewModel.swift`

**状态机**:

```swift
public enum BookSourceImportState: Equatable {
    case idle
    case loading
    case success(source: BookSource)
    case failed(message: String)
    case unsupported(reason: String)
    case partial(source: BookSource, warnings: [String])
}
```

---

#### SearchViewModel

**位置**: `iOS/Features/Search/SearchViewModel.swift`

**状态机**:

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

---

#### ReaderViewModel

**位置**: `iOS/Features/Reader/ReaderViewModel.swift`

**状态机**:

```swift
public enum ReaderState: Equatable {
    case idle
    case loading
    case loaded(content: ContentPage)
    case empty
    case failed(message: String)
    case unsupported(reason: String)
    case partial(content: ContentPage, warnings: [String])
}
```

**阅读设置操作**:
```swift
func increaseFontSize()
func decreaseFontSize()
```

---

#### ChapterListViewModel

**位置**: `iOS/Features/ChapterList/ChapterListViewModel.swift`

**状态机**:

```swift
public enum ChapterListState: Equatable {
    case idle
    case loading
    case loaded(chapters: [TOCItem])
    case empty
    case failed(message: String)
    case unsupported(reason: String)
    case partial(chapters: [TOCItem], warnings: [String])
}
```

---

#### BookshelfViewModel

**位置**: `iOS/Features/Bookshelf/BookshelfViewModel.swift`

**状态机**:

```swift
public enum BookshelfState: Equatable {
    case idle
    case loading
    case loaded(items: [BookshelfItem])
    case empty
    case failed(message: String)
}
```

---

### 7. Navigation 层

#### Route

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

---

## 依赖管理

### Swift Package.swift 配置

**位置**: `iOS/Package.swift`

```swift
// 仅依赖 Reader-Core public products
dependencies: [
    .package(path: "../Reader-Core")  // 本地开发
    // 或
    .package(url: "https://github.com/minliny/Reader-Core.git", exact: "0.1.0")
]
```

### 禁止导入（边界约束）

```swift
// 禁止 iOS App 层直接导入
import ReaderCoreParser       // ❌
import ReaderCoreJSRenderer    // ❌
import ReaderCoreNetwork      // ❌
```

### 允许导入

```swift
// 允许
import ReaderCoreModels        // ✅
import ReaderCoreProtocols     // ✅
import ReaderCoreFoundation    // ✅
import ReaderPlatformAdapters  // ✅
```

---

## 开发阶段

| Phase | 名称 | 状态 |
|-------|------|------|
| Phase 0 | Core 接入准备 | ✅ 完成 |
| Phase 1 | 书源管理 | ✅ 完成 |
| Phase 2 | 搜索流程 | ✅ 完成 |
| Phase 3 | 书籍详情 | ✅ 完成 |
| Phase 4 | 目录页 | ✅ 完成 |
| Phase 5 | 阅读页 | ✅ 完成 |
| Phase 6 | 本地书架 | ✅ 完成 |
| Phase 7 | 稳定化 | 🔄 进行中 |

---

## 核心设计原则

### 1. Facade 模式
- `ShellAssembly` 作为唯一入口
- 对外隐藏 Core 内部复杂度

### 2. Mock 驱动开发
- `MockReaderCoreService` 支撑 UI 并行开发
- 不等待真实 Parser 完成

### 3. 状态驱动 UI
- 所有页面使用 `LoadState<T>`
- 统一处理 loading/empty/failed/unsupported/partial

### 4. 错误分类
- `AppReaderError.Code` 覆盖所有错误类型
- `stage` 字段标识发生阶段

### 5. 线程安全
- `@MainActor` 标记 ViewModel
- `NSLock` 保护共享状态

---

## 测试策略

### 测试 Targets

| Target | 测试内容 |
|--------|----------|
| `ShellSmokeTests` | Shell 组合根验证 |
| `ReaderAppPersistenceTests` | 持久化层测试 |
| `ReaderAppPersistenceTestRunner` | 独立运行器 |

### 运行测试

```bash
cd iOS
swift test
# 或
swift run ReaderAppPersistenceTestRunner
```

---

## 边界检查

### iOS Boundary Script

**位置**: `scripts/check_ios_boundary.sh`

**检查项**:
- `iOS/Shell/**` 外部代码禁止直接 import Core internal
- 仅 `ShellAssembly` 可访问 ReaderCoreParser/Network

---

## 快速入门

### 1. 配置依赖

确保 Reader-Core 在同级目录：

```bash
cd ..
git clone https://github.com/minliny/Reader-Core.git
```

### 2. 构建项目

```bash
cd Reader-iOS/iOS
swift build
```

### 3. 运行测试

```bash
swift test
```

### 4. 查看构建状态

```bash
swift build --build-tests
```

---

## 关键文件索引

| 功能 | 文件路径 |
|------|----------|
| 服务入口 | `iOS/CoreBridge/ReaderCoreServiceProvider.swift` |
| Mock 服务 | `iOS/CoreBridge/MockReaderCoreService.swift` |
| 状态定义 | `iOS/CoreBridge/LoadState.swift` |
| 错误定义 | `iOS/CoreBridge/AppReaderError.swift` |
| 依赖注入 | `iOS/Shell/ShellAssembly.swift` |
| 流程协调 | `iOS/CoreIntegration/ReadingFlowCoordinator.swift` |
| 书源存储 | `iOS/App/Persistence/BookSourceStore.swift` |
| 书架存储 | `iOS/App/Persistence/BookshelfStore.swift` |
| 书源 ViewModel | `iOS/Features/BookSources/BookSourceViewModel.swift` |
| 搜索 ViewModel | `iOS/Features/Search/SearchViewModel.swift` |
| 阅读 ViewModel | `iOS/Features/Reader/ReaderViewModel.swift` |
| 路由定义 | `iOS/Navigation/Route.swift` |

---

## 文档版本

- **版本**: 1.0.0
- **更新日期**: 2026-05-13
- **维护者**: Reader-iOS Team
