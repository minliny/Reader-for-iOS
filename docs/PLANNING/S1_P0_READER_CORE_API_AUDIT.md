# S1.P0 Reader-Core Public API 接入现状审计

## 审计信息

| 属性 | 值 |
|------|-----|
| 审计批次 | S1.P0-001 |
| 审计日期 | 2026-05-13 |
| 仓库 | Reader-iOS |
| 审计范围 | Mock/Real Core 切换能力评估 |

---

## 1. 审计结论

**结论**: `READY_WITH_GAPS`

**理由**:
- 架构具备 Mock/Real 切换的基础结构
- 协议边界清晰（SearchService/TOCService/ContentService）
- 但 `makeDefaultReadingFlowCoordinator()` 未实现真实 Core 适配
- Default*Service 缺少必要的依赖注入
- 需要 P0 缺口补充后进入 S1.P1

---

## 2. 已审计文件（真实路径）

| 文件 | 状态 |
|------|------|
| `iOS/Shell/ShellAssembly.swift` | ✅ 已审计 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | ✅ 已审计 |
| `iOS/CoreBridge/MockReaderCoreService.swift` | ✅ 已审计 |
| `iOS/CoreBridge/LoadState.swift` | ✅ 已审计 |
| `iOS/CoreBridge/AppReaderError.swift` | ✅ 已审计 |
| `iOS/CoreBridge/SourceIdentityFactory.swift` | ✅ 已审计 |
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | ✅ 已审计 |
| `iOS/CoreIntegration/DefaultSearchService.swift` | ✅ 已审计 |
| `iOS/CoreIntegration/DefaultTOCService.swift` | ✅ 已审计 |
| `iOS/CoreIntegration/DefaultContentService.swift` | ✅ 已审计 |
| `iOS/CoreIntegration/InMemoryBookSourceRepository.swift` | ✅ 未深入审计 |
| `iOS/CoreIntegration/DefaultBookSourceDecoder.swift` | ✅ 未深入审计 |
| `iOS/Shell/ReaderShellEnvironment.swift` | ✅ 已审计 |
| `iOS/Modules/Reader/ReaderModuleBoundary.swift` | ✅ 已审计 |
| `iOS/Package.swift` | ✅ 已审计 |
| `scripts/check_ios_boundary.sh` | ✅ 已审计 |

---

## 3. Package.swift 依赖审计

### 3.1 依赖来源

| 类型 | 值 |
|------|-----|
| 依赖模式 | 本地 path 依赖 |
| 路径 | `../Reader-Core` |
| Canonical (CI) | `https://github.com/minliny/Reader-Core.git` exact:0.1.0 |

### 3.2 Target 与依赖

| Target | 依赖 Target | 依赖 Reader-Core Products |
|--------|------------|--------------------------|
| `ReaderShellValidation` | ReaderAppSupport | ReaderCoreFoundation, ReaderCoreModels, ReaderCoreProtocols, **ReaderCoreParser**, **ReaderCoreNetwork**, ReaderPlatformAdapters |
| `ReaderAppPersistence` | ReaderAppSupport | ReaderCoreModels |
| `ReaderApp` | ReaderShellValidation, ReaderAppSupport, ReaderAppPersistence | 无 |
| `ShellSmokeTests` | ReaderShellValidation, ReaderAppSupport | ReaderCoreModels, ReaderCoreProtocols |
| `ReaderAppPersistenceTests` | ReaderAppPersistence, ReaderAppSupport | 无 |
| `ReaderAppPersistenceTestRunner` | ReaderAppPersistence, ReaderAppSupport | 无 |

### 3.3 边界合规性

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 仅 Shell 层导入 Core internal | ⚠️ 部分合规 | ReaderShellValidation 可导入 Parser/Network，但 App 层未直接导入 |
| 无 Core 内部路径引用 | ✅ 合规 | Package.swift 使用 `../Reader-Core` path，未引用 Core/ 内部路径 |
| 禁止模块检查 | ✅ 合规 | 边界脚本已配置 |

### 3.4 风险点

| 风险 | 描述 | 缓解 |
|------|------|------|
| ReaderCoreParser/Network 仅限 Shell 层导入 | 边界脚本已限制 | ✅ |
| App 层可访问 Shell 层公开类型 | 正常架构设计 | ✅ |

---

## 4. Target 与边界审计

### 4.1 当前架构分层

```
┌─────────────────────────────────────────────────────┐
│ ReaderApp (Feature UI 层)                           │
│ - Features/* (View/ViewModel)                      │
│ - Surface/* (状态展示)                              │
│ - Navigation/* (路由)                              │
│ - Modules/* (平台适配)                              │
└─────────────────────────────────────────────────────┘
                          ↓ 依赖
┌─────────────────────────────────────────────────────┐
│ ReaderShellValidation (Shell 层)                   │
│ - CoreBridge/* (服务入口)                           │
│ - CoreIntegration/* (流程协调)                      │
│ - Shell/* (装配入口)                               │
│ ✅ 可导入: ReaderCoreParser, ReaderCoreNetwork      │
└─────────────────────────────────────────────────────┘
                          ↓ 依赖 (仅 public products)
┌─────────────────────────────────────────────────────┐
│ Reader-Core (External)                              │
│ - ReaderCoreFoundation (公开)                       │
│ - ReaderCoreModels (公开)                           │
│ - ReaderCoreProtocols (公开)                        │
│ - ReaderCoreParser (Shell 层可用)                   │
│ - ReaderCoreNetwork (Shell 层可用)                  │
│ - ReaderPlatformAdapters (公开)                     │
└─────────────────────────────────────────────────────┘
```

### 4.2 边界评估

| 评估项 | 状态 | 说明 |
|--------|------|------|
| App 层未直接导入 Core internal | ✅ | Feature 层不直接依赖 Parser/Network |
| Shell 层隔离 Core 内部实现 | ✅ | 通过 ShellAssembly 统一入口 |
| Feature 层访问 Shell 层公开 API | ✅ | 通过协议 (SearchService/TOCService/ContentService) |

---

## 5. ReaderCoreServiceProvider 审计

### 5.1 服务入口结构

```swift
public final class ReaderCoreServiceProvider: @unchecked Sendable {
    public static let shared = ReaderCoreServiceProvider()
    private var mode: ServiceMode = .mock
    private let lock = NSLock()
    private let mockService: MockReaderCoreService
}
```

### 5.2 模式切换能力

| 能力 | 状态 | 说明 |
|------|------|------|
| Singleton 模式 | ✅ | `shared` 单例 |
| 模式切换 | ⚠️ 形式存在 | `setMode(_:)` 方法存在 |
| 真实服务注入 | ❌ 缺失 | 总是调用 `mockService`，不根据 mode 切换 |
| Mock 场景控制 | ✅ | `setMockScenario(_:)` 可控制 Mock 行为 |

### 5.3 问题分析

**问题**: `setMode()` 方法存在但未被使用

```swift
public func validateBookSource(from data: Data) async -> LoadState<BookSource> {
    // 总是调用 mockService，忽略 mode 设置
    await mockService.validateBookSource(from: data)
}
```

**影响**: 无法通过 mode 切换真实 Core 服务

---

## 6. ShellAssembly 审计

### 6.1 当前实现

```swift
public enum ShellAssembly {
    public static func makeMockReadingFlowCoordinator() -> ReadingFlowCoordinator {
        let serviceProvider = ReaderCoreServiceProvider.shared
        return ReadingFlowCoordinator(
            searchService: MockSearchService(provider: serviceProvider),
            tocService: MockTOCService(provider: serviceProvider),
            contentService: MockContentService(provider: serviceProvider),
            // ...
        )
    }

    public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator {
        // 直接调用 Mock 版本，未实现真实 Core 适配
        let coordinator = makeMockReadingFlowCoordinator()
        return coordinator
    }
}
```

### 6.2 问题分析

| 问题 | 严重性 | 说明 |
|------|--------|------|
| `makeDefaultReadingFlowCoordinator()` 未实现 | P0 | 直接返回 Mock coordinator |
| Default*Service 缺少依赖注入 | P0 | HTTPClient/RequestBuilder/Parser 未注入 |
| 无真实服务构造入口 | P0 | 无法切换到真实 Core |

### 6.3 Mock*Service vs Default*Service

| 服务 | Mock 版本 | Default 版本 | 状态 |
|------|-----------|--------------|------|
| SearchService | ✅ MockSearchService | DefaultSearchService | Default 未被实例化 |
| TOCService | ✅ MockTOCService | DefaultTOCService | Default 未被实例化 |
| ContentService | ✅ MockContentService | DefaultContentService | Default 未被实例化 |

---

## 7. ReadingFlowCoordinator 审计

### 7.1 流程覆盖

| 步骤 | 方法 | 服务 |
|------|------|------|
| 书源导入 | `importBookSource()` | bookSourceDecoder |
| 搜索 | `search()` | searchService |
| 选择书籍 | `selectBook()` | tocService |
| 选择章节 | `selectChapter()` | contentService |

### 7.2 依赖注入

```swift
public let bookSourceRepository: BookSourceRepository
public let bookSourceDecoder: BookSourceDecoder
public let searchService: SearchService
public let tocService: TOCService
public let contentService: ContentService
public let errorLogger: ErrorLogger
```

### 7.3 评估

| 评估项 | 状态 | 说明 |
|--------|------|------|
| 统一流程协调 | ✅ | 完整链路覆盖 |
| 协议边界清晰 | ✅ | SearchService/TOCService/ContentService |
| 错误传播 | ✅ | 使用 ReaderError |
| LoadState 映射 | ✅ | MockService → LoadState → AppReaderError |
| 真实 Core 接入准备 | ⚠️ | 协议支持，但实现为空 |

---

## 8. Search / TOC / Content 服务审计

### 8.1 DefaultSearchService

```swift
public final class DefaultSearchService: SearchService {
    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder
    private let searchParser: SearchParser

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        let request = try requestBuilder.makeSearchRequest(source: source, query: query)
        let response = try await httpClient.send(request)
        return try searchParser.parseSearchResponse(response.data, source: source, query: query)
    }
}
```

**评估**:
- ✅ 协议边界清晰
- ✅ 依赖 HTTPClient/RequestBuilder/Parser
- ❌ 依赖注入缺失（ShellAssembly 未实例化）
- ❌ 未接入 Reader-Core Parser

### 8.2 DefaultTOCService

```swift
public final class DefaultTOCService: TOCService {
    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder
    private let tocParser: TOCParser
}
```

**评估**: 同上

### 8.3 DefaultContentService

```swift
public final class DefaultContentService: ContentService {
    private let httpClient: HTTPClient
    private let requestBuilder: RequestBuilder
    private let contentParser: ContentParser
}
```

**评估**: 同上

### 8.4 共同缺口

| 缺口 | 类型 | 说明 |
|------|------|------|
| HTTPClient | P0 | 需要 Reader-Core 的 HTTPClient 实现 |
| RequestBuilder | P0 | 需要 Reader-Core 的 RequestBuilder 实现 |
| SearchParser/TOCParser/ContentParser | P0 | 需要 Reader-Core 的 Parser 实现 |
| 依赖注入机制 | P0 | ShellAssembly 需要构造这些依赖 |

---

## 9. MockReaderCoreService 审计

### 9.1 Mock 场景覆盖

| 场景 | 状态 | 说明 |
|------|------|------|
| .success | ✅ | 正常成功 |
| .partial | ✅ | 部分成功带警告 |
| .unsupported | ✅ | 不支持 |
| .empty | ✅ | 空结果 |
| .parserFailure | ✅ | 解析失败 |
| .networkFailure | ✅ | 网络失败 |
| .jsRequired | ✅ | JS 必需 |
| .loginRequired | ✅ | 需要登录 |

### 9.2 Mock 数据

| 数据 | 内容 |
|------|------|
| 搜索结果 | 3 本书（凡人修仙传、仙逆、一念永恒） |
| 目录 | 5 章 |
| 正文 | 一段完整章节 |

### 9.3 Mock 行为掩盖问题

| 问题 | 描述 |
|------|------|
| 静态数据 | 无法验证真实书源解析 |
| 固定 URL | 无法验证网络请求 |
| 无异步时序 | 无法验证并发/竞态 |
| 无真实解析 | 无法验证选择器规则 |

---

## 10. 边界脚本审计

### 10.1 脚本位置
`scripts/check_ios_boundary.sh`

### 10.2 检查规则

| 规则类型 | 内容 |
|---------|------|
| 禁止模块 | ReaderCoreNetwork, ReaderCoreParser, ReaderCoreCache, ReaderCoreExecution |
| 禁止路径 | Core, samples, tools, Adapters, Platforms, Package.swift |
| 禁止工作流 | 10 个 Core 工作流 |
| 禁止文档 | 6 个 Core docs |
| 受限路径 | iOS/App, iOS/CoreIntegration, iOS/Features, iOS/Modules, iOS/Shell, iOS/Tests |

### 10.3 执行结果

```
iOS boundary gate
checked_files=56
result=PASS
```

### 10.4 评估

| 评估项 | 状态 | 说明 |
|--------|------|------|
| 禁止模块覆盖 | ✅ | 4 个核心内部模块 |
| 禁止路径覆盖 | ✅ | Core 相关路径 |
| 受限路径检查 | ✅ | 6 个 iOS 路径 |
| 脚本执行 | ✅ | PASS |

---

## 11. 真实 Core 接入缺口清单

### P0 必须解决

| ID | 缺口 | 当前状态 | 建议方案 |
|----|------|---------|---------|
| P0-1 | `makeDefaultReadingFlowCoordinator()` 未实现 | 直接返回 Mock | 实现真实 Core 适配 |
| P0-2 | Default*Service 依赖未注入 | HTTPClient/RequestBuilder/Parser 未构造 | 在 ShellAssembly 中构造 |
| P0-3 | ReaderCoreServiceProvider 不切换模式 | 总是调用 mockService | 根据 mode 路由到真实服务 |

**P0 缺口代码位置**:

```swift
// iOS/Shell/ShellAssembly.swift - Line 21-24
public static func makeDefaultReadingFlowCoordinator() -> ReadingFlowCoordinator {
    // ❌ 直接返回 Mock，未实现真实 Core 适配
    let coordinator = makeMockReadingFlowCoordinator()
    return coordinator
}
```

### P1 应尽快解决

| ID | 缺口 | 当前状态 | 建议方案 |
|----|------|---------|---------|
| P1-1 | 无集成测试 | 只有单元测试 | 添加 Search/TOC/Content 集成测试 |
| P1-2 | Mock 掩盖真实问题 | 静态数据 | 添加真实书源样本测试 |
| P1-3 | HTTPClient/RequestBuilder 来源不明 | 依赖 Reader-Core | 确认 Reader-Core public API |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-1 | 日志/debug 面板 | 低 |
| P2-2 | 错误文案国际化 | 低 |
| P2-3 | 缓存策略 | 中 |

---

## 12. S1.P1 推荐任务

**任务 ID**: S1.P1  
**任务名称**: 实现 ShellAssembly.makeDefaultReadingFlowCoordinator() 真实 Core 适配

### 输入文件
- `iOS/Shell/ShellAssembly.swift`
- `iOS/CoreIntegration/DefaultSearchService.swift`
- `iOS/CoreIntegration/DefaultTOCService.swift`
- `iOS/CoreIntegration/DefaultContentService.swift`

### 修改范围
- 实现 `makeDefaultReadingFlowCoordinator()`
- 构造 HTTPClient/RequestBuilder/Parser 依赖
- 在 `ReaderCoreServiceProvider` 中实现模式路由

### 验收标准
- [ ] ShellAssembly 可返回真实 Core 适配的 Coordinator
- [ ] Default*Service 可被正确实例化
- [ ] 边界检查通过

---

## 13. 本轮未做事项

| 事项 | 原因 |
|------|------|
| Swift/Xcode 编译验证 | 环境受限 |
| Reader-Core public API 详细审计 | 需要 Reader-Core 仓库访问 |
| 集成测试编写 | 等待 P0 缺口解决 |
| HTTPClient/RequestBuilder/Parser 来源确认 | 需要 Reader-Core API 文档 |

---

## 14. 审计签字

| 角色 | 状态 | 日期 |
|------|------|------|
| 审计员 | ✅ 完成 | 2026-05-13 |
