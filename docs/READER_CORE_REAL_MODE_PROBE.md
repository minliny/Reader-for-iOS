# Reader-Core Real Mode 接入探测报告

> 生成时间: 2026-05-11
> 探测目标: Reader-Core public API 可见性与 Reader-iOS 真实接入可行性
> 约束: 不依赖 parser 内部实现，不调用网络，不读取真实书源

## 1. iOS/Package.swift 可见的 Reader-Core Products

```swift
.package(path: "../Reader-Core")
```

当前依赖的 public products:

| Product | 用途 | 状态 |
|---------|------|------|
| ReaderCoreModels | DTO / 核心模型 | ✅ 可用 |
| ReaderCoreProtocols | 协议 / Facade 契约 | ✅ 可用 |
| ReaderCoreFoundation | Foundation 扩展 / 工具 | ✅ 可用 |
| ReaderCoreNetwork | 网络层协议 | ✅ 可用 |

## 2. iOS 侧已就绪的组件

| 组件 | 状态 | 说明 |
|------|------|------|
| `ReaderCoreServiceProvider` + `ServiceMode` | ✅ 就绪 | 入口已预留 `.real` 模式 |
| `BookSourceRepository` | ✅ 已实现 | `InMemoryBookSourceRepository` (actor) |
| `BookSourceDecoder` | ✅ 已实现 | `DefaultBookSourceDecoder` |
| PlatformAdapters | ✅ 已实现 | HTTP/Storage/Keychain/Logger/Snapshot |
| `ShellAssembly` DI | ✅ 已就绪 | 可根据 `ServiceMode` 装配 |

## 3. iOS 侧禁止依赖（强制约束）

以下模块禁止在 iOS 源码中直接 import 或依赖：

| 禁止模块 | 原因 |
|----------|------|
| `CSSExecutor` | Reader-Core internal，不公开 |
| `SelectorEngine` | Reader-Core internal，不公开 |
| `NonJSParserEngine` | Reader-Core internal，不公开 |
| `ReaderCoreParser` internal types | 非 public facade |
| `JavaScriptCore` | 动态 JS Runtime，Phase 1 OUT_OF_SCOPE |
| `QuickJS` / `Hermes` | 动态 JS Runtime，Phase 1 OUT_OF_SCOPE |
| `WKWebView` | 动态书源运行时，Phase 1 OUT_OF_SCOPE |
| `WebDAV` production sync | Phase 1 OUT_OF_SCOPE |

边界检查入口: `scripts/check_ios_boundary.sh`

## 4. Reader-Core 需要提供的最小 Public API

### 4.1 Protocol / Facade 清单

```swift
// 1. BookSource 加载
public protocol BookSourceLoader {
    func loadBookSource(from url: String) async throws -> BookSource
}

// 2. 搜索编排
public protocol SearchPipeline {
    func execute(query: SearchQuery, source: BookSource) async throws -> [SearchResultItem]
}

// 3. 书籍详情编排
public protocol BookDetailPipeline {
    func execute(url: String, source: BookSource) async throws -> SearchResultItem
}

// 4. 目录编排
public protocol TOCPipeline {
    func execute(detailURL: String, source: BookSource) async throws -> [TOCItem]
}

// 5. 正文编排
public protocol ContentPipeline {
    func execute(chapterURL: String, source: BookSource) async throws -> ContentPage
}

// 6. 错误映射扩展（Reader-Core ErrorMapper 已部分支持）
public protocol BookErrorMapper: ErrorMapper {
    // 需扩展为支持书源解析特有错误
}
```

### 4.2 DTO 清单（已有，不需要额外提供）

| 类型 | 用途 | 来源 |
|------|------|------|
| `BookSource` | 书源定义 | ReaderCoreModels |
| `SearchQuery` | 搜索查询 | ReaderCoreModels |
| `SearchResultItem` | 搜索结果 | ReaderCoreModels |
| `TOCItem` | 目录项 | ReaderCoreModels |
| `ContentPage` | 正文页 | ReaderCoreModels |
| `ReaderError` | 错误模型 | ReaderCoreModels |
| `FailureRecord` | 失败记录 | ReaderCoreModels |
| `CompatibilityMark` | 兼容标记 | ReaderCoreModels |
| `HTTPRequest` | 网络请求 DTO | ReaderCoreModels |
| `HTTPResponse` | 网络响应 DTO | ReaderCoreModels |
| `CacheEntry` | 缓存条目 | ReaderCoreModels |
| `CacheScope` | 缓存作用域 | ReaderCoreModels |
| `BookSourceRepository` | 书源存储 | ReaderCoreProtocols |
| `BookSourceDecoder` | 书源 JSON 解码 | ReaderCoreProtocols |
| `HTTPClient` | HTTP 客户端 | ReaderCoreProtocols |
| `RequestBuilder` | 请求构建 | ReaderCoreProtocols |
| `CacheStore` | 缓存存储 | ReaderCoreProtocols |
| `CacheRepository` | 缓存仓库 | ReaderCoreProtocols |
| `ErrorMapper` | 错误映射 | ReaderCoreProtocols |
| `PlatformAdapter` | 平台适配器基协议 | ReaderCoreProtocols |

## 5. Compile Probe 结果

探测文件: `iOS/CoreIntegration/ReaderCoreRealModeProbe.swift`

| 验证内容 | 结果 |
|----------|------|
| `BookSource` 可构造 | ✅ |
| `SearchQuery` / `SearchResultItem` 可构造 | ✅ |
| `TOCItem` / `ContentPage` 可构造 | ✅ |
| `BookSourceRepository` 协议可实现 | ✅ |
| `BookSourceDecoder` 协议可实现 | ✅ |
| `HTTPClient` / `RequestBuilder` 协议可实现 | ✅ |
| `CacheStore` / `CacheRepository` 协议可实现 | ✅ |
| `ErrorMapper` 相关类型可见 | ✅ |
| `ReaderPlatformAdapters` 类型满足本地协议 | ✅ |

## 6. 接入路线图

### 阶段 A: Facade 对齐（当前，iOS 侧已完成）
- `ReaderCoreServiceProvider` 作为唯一入口
- `ServiceMode` 已预留 `.real`，待 Core facade 后切换

### 阶段 B: Parser Public Facade（依赖 Reader-Core upstream）
- Reader-Core 提供 `BookSourceLoader` / `SearchPipeline` / `TOCPipeline` / `ContentPipeline` public protocols
- iOS 侧实现 `ReaderCoreService` real mode wiring

### 阶段 C: Real Mode 切换
- `ShellAssembly` 根据 `ServiceMode` 装配 real services
- 保留 mock mode 用于 UI 开发和测试

## 7. Clean-Room 声明

本探测文档及配套代码基于 Reader-Core public headers / Package.swift products 和公开协议设计，未复制、翻译或改写 Legado Android 源码。所有类型引用均来自 Reader-Core 已发布的 public API。
