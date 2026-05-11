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

## 2. 当前可 import 的 Public Modules

从 Reader-iOS 侧可安全 import:

- `ReaderCoreModels`
- `ReaderCoreProtocols`
- `ReaderCoreFoundation`
- `ReaderCoreNetwork`

## 3. ReaderCoreService Real Mode 需要的 Public API

### 3.1 模型层 (ReaderCoreModels)

| 类型 | 用途 | 当前状态 |
|------|------|----------|
| `BookSource` | 书源定义 | ✅ 可用 |
| `SearchQuery` | 搜索查询 | ✅ 可用 |
| `SearchResultItem` | 搜索结果 | ✅ 可用 |
| `TOCItem` | 目录项 | ✅ 可用 |
| `ContentPage` | 正文页 | ✅ 可用 |
| `ReaderError` | 错误模型 | ✅ 可用 |
| `FailureRecord` | 失败记录 | ✅ 可用 |
| `CompatibilityMark` | 兼容标记 | ✅ 可用 |
| `HTTPRequest` | 网络请求 DTO | ✅ 可用 |
| `HTTPResponse` | 网络响应 DTO | ✅ 可用 |
| `CacheEntry` | 缓存条目 | ✅ 可用 |
| `CacheScope` | 缓存作用域 | ✅ 可用 |

### 3.2 协议层 (ReaderCoreProtocols)

| 协议 | 用途 | 当前状态 |
|------|------|----------|
| `BookSourceRepository` | 书源存储 | ✅ 可用 |
| `BookSourceDecoder` | 书源 JSON 解码 | ✅ 可用 |
| `HTTPClient` | HTTP 客户端 | ✅ 可用 |
| `RequestBuilder` | 请求构建 | ✅ 可用 |
| `CacheStore` | 缓存存储 | ✅ 可用 |
| `CacheRepository` | 缓存仓库 | ✅ 可用 |
| `ErrorMapper` | 错误映射 | ✅ 可用 |
| `PlatformAdapter` | 平台适配器基协议 | ✅ 可用 |

### 3.3 Reader-iOS 侧已实现的适配器

| 适配器 | 协议 | 状态 |
|--------|------|------|
| `IOSHTTPAdapter` | `HTTPClientProtocol` / `HTTPClient` | ✅ 已实现 |
| `IOSStorageAdapter` | `LocalStorageProtocol` | ✅ 已实现 |
| `IOSKeychainCredentialStore` | `CredentialStoreProtocol` | ✅ 已实现 (Apple-only) |
| `IOSLoggerAdapter` | `AppLoggerProtocol` | ✅ 已实现 |
| `IOSSnapshotStore` | `SnapshotStoreProtocol` | ✅ 已实现 |

## 4. 当前缺失或不确定的 API

| 需求 | 说明 | 风险等级 |
|------|------|----------|
| `ReaderCoreParser` public facade | 当前 Reader-Core 无独立 Parser public product | 🔴 高 |
| Search / TOC / Content 编排 Service | Reader-Core 是否提供高层 pipeline service？ | 🟡 中 |
| Capability Matrix 查询 API | 书源能力矩阵如何在 iOS 侧查询？ | 🟡 中 |
| Cookie 管理公共协议 | 当前为内部实现，iOS 侧需适配 | 🟡 中 |
| JS Runtime 公共协议 | 当前 OUT_OF_SCOPE，但未来需协议占位 | 🟢 低 |

## 5. Compile Probe 结果

探测文件: `iOS/CoreIntegration/ReaderCoreRealModeProbe.swift`

验证内容:
- ✅ `BookSource` 可构造
- ✅ `SearchQuery` / `SearchResultItem` 可构造
- ✅ `TOCItem` / `ContentPage` 可构造
- ✅ `BookSourceRepository` / `BookSourceDecoder` 协议可实现
- ✅ `HTTPClient` / `RequestBuilder` 协议可实现
- ✅ `CacheStore` / `CacheRepository` 协议可实现
- ✅ `ErrorMapper` 相关类型可见
- ✅ `ReaderPlatformAdapters` 中类型可满足 `HTTPClientProtocol` 等本地协议

## 6. 下一步真实接入建议

### 阶段 A: Facade 对齐 (当前)
- 保持 `ReaderCoreServiceProvider` 作为唯一入口
- `ServiceMode` 已预留 `.real`，待 Reader-Core 提供 public pipeline service 后切换

### 阶段 B: Parser Public Facade (依赖 Reader-Core)
- 需要 Reader-Core 提供 `ReaderCoreParser` public product 或等效 facade
- iOS 侧不得直接依赖 `CSSExecutor` / `SelectorEngine` / `NonJSParserEngine`

### 阶段 C: Pipeline Service (依赖 Reader-Core)
- 需要 Reader-Core 提供高层编排服务:
  - `SearchPipeline.execute(query:source:)`
  - `TOCPipeline.execute(detailURL:source:)`
  - `ContentPipeline.execute(chapterURL:source:)`
- iOS 侧通过 `ReaderCoreService` 调用，不直接调用 pipeline 内部

### 阶段 D: Real Mode 切换
- 在 `ShellAssembly` 中根据 `ServiceMode` 装配 real services
- 保留 mock mode 用于 UI 开发和测试

## 7. Clean-Room 声明

本探测文档及配套代码基于 Reader-Core public headers / Package.swift products 和公开协议设计，未复制、翻译或改写 Legado Android 源码。所有类型引用均来自 Reader-Core 已发布的 public API。
