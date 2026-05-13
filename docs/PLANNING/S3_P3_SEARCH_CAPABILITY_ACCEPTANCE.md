# S3.P3 搜索能力层综合验收

## 1. 本轮结论

**结论**: `SEARCH_CAPABILITY_ACCEPTED_ENV_UNVERIFIED`

**说明**:
- S3.P0-S3.P2 文档一致性已确认
- 搜索能力层已形成本仓 Mock 闭环
- Mock/Placeholder 路由契约清晰
- selectedSourceId 与搜索流程连接已实现
- 状态流与错误映射完整
- 边界检查通过
- **real mode 仍为 Placeholder，不代表真实搜索能力**
- Swift 编译在 Trae 环境未验证
- S3 阶段可以关闭，等待本地编译验证

## 2. S3.P0-S3.P2 文档一致性确认

| 文档 | 结论 | 一致性 |
|------|------|--------|
| S3.P0 | READY_WITH_GAPS | ✅ |
| S3.P1 | SEARCH_CONTRACT_READY_ENV_UNVERIFIED | ✅ |
| S3.P2 | SEARCH_SELECTED_SOURCE_READY_ENV_UNVERIFIED | ✅ |

**一致性确认**:
- ✅ real mode 当前是 PlaceholderSearchService
- ✅ DefaultSearchService 存在但未真实装配
- ✅ selectedSourceId 连接已实现（S3.P2）
- ✅ 不把 Placeholder 写成真实 Core 能力
- ✅ 不把 ENV_COMPILE_UNVERIFIED 写成完全 READY

## 3. 真实文件路径

| 文件 | 状态 | 用途 |
|------|------|------|
| `iOS/Features/Search/SearchViewModel.swift` | ✅ | 搜索 ViewModel |
| `iOS/Features/Search/SearchView.swift` | ✅ | 搜索视图 |
| `iOS/CoreIntegration/DefaultSearchService.swift` | ✅ | 真实搜索服务（未装配） |
| `iOS/CoreIntegration/PlaceholderServices.swift` | ✅ | Placeholder 服务 |
| `iOS/Shell/ShellAssembly.swift` | ✅ | Shell 组装 |
| `iOS/CoreIntegration/ReadingFlowCoordinator.swift` | ✅ | 阅读流程协调 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | ✅ | 服务提供者 |
| `iOS/CoreBridge/MockReaderCoreService.swift` | ✅ | Mock 核心服务 |
| `iOS/CoreBridge/LoadState.swift` | ✅ | 加载状态 |
| `iOS/CoreBridge/AppReaderError.swift` | ✅ | 应用错误 |
| `iOS/App/Persistence/BookSourceStore.swift` | ✅ | 书源持久化 |
| `iOS/Tests/ShellSmokeTests/SearchServiceContractTests.swift` | ✅ | 搜索契约测试 |
| `iOS/Tests/ReaderAppPersistenceTests/SearchViewModelSelectedSourceTests.swift` | ✅ | selectedSource 连接测试 |

## 4. S3 能力验收矩阵

| 能力项 | 状态 | 测试覆盖 |
|--------|------|----------|
| Mock 搜索成功 | ✅ 已实现 | ✅ SearchServiceContractTests |
| Mock 搜索空结果 | ✅ 已实现 | ✅ SearchServiceContractTests |
| Mock 搜索失败 | ✅ 已实现 | ✅ SearchServiceContractTests |
| Mock 搜索 unsupported | ✅ 已实现 | ✅ SearchServiceContractTests |
| Placeholder 搜索 unavailable/unsupported | ✅ 已实现 | ✅ SearchServiceContractTests |
| Real mode 不静默回退 Mock | ✅ 已实现 | ✅ SearchServiceContractTests |
| DefaultSearchService 存在但未装配 | ✅ 已确认 | - |
| SearchViewModel 状态流 | ✅ 已实现 | ✅ SearchServiceContractTests |
| 空关键词处理 | ✅ 已实现 | ✅ SearchViewModel |
| 无书源处理 | ✅ 已实现 | ✅ SearchViewModel |
| selectedSourceId 有效时用于搜索 | ✅ 已实现 | ✅ SearchViewModelSelectedSourceTests |
| selectedSourceId 无效时降级策略 | ✅ 已实现 | ✅ SearchViewModelSelectedSourceTests |
| selectedSourceId 为空时降级策略 | ✅ 已实现 | ✅ SearchViewModelSelectedSourceTests |
| 无书源时失败状态 | ✅ 已实现 | ✅ SearchViewModel |
| 搜索结果进入详情/目录连接点 | ✅ 已确认 | - |
| 旧结果覆盖风险 | ⚠️ 可接受风险 | - |
| 搜索取消 | ❌ 未实现 | - |
| 搜索分页 | ❌ 未实现 | - |
| 多书源聚合 | ❌ 未实现 | - |
| 与 Reader-Core 边界 | ✅ 清晰 | ✅ 边界检查 |

## 5. SearchService 当前契约

```swift
public protocol SearchService {
    func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem]
}
```

| 路径 | 依赖 | 行为 |
|------|------|------|
| Mock | ReaderCoreServiceProvider | 委托 mockService，返回 .loaded |
| Placeholder | 无 | 抛出 unavailable，返回 .unsupported |
| Default | HTTPClient/RequestBuilder/Parser | 构造真实请求（未装配） |

## 6. Mock / Placeholder / Real 路由当前契约

### 路由语义

```swift
// ReaderCoreServiceProvider.searchBooks()
switch currentMode {
case .mock:
    return await mockService.searchBooks(keyword: keyword, page: page)
case .real:
    return .unsupported(reason: "Real Core service not available...")
}
```

### 契约保证

| 模式 | 返回 | 不会 |
|------|------|------|
| mock | .loaded / .empty / .failed | - |
| real | .unsupported | 静默回退 mock |

## 7. selectedSourceId 搜索连接当前契约

### loadSources() 实现

```swift
public func loadSources() async {
    sources = try await store.load()
    
    if let resolved = await store.resolveSelectedSource(from: sources) {
        selectedSource = resolved
    } else if let firstEnabled = sources.first(where: { $0.enabled ?? true }) {
        selectedSource = firstEnabled
    } else if let first = sources.first {
        selectedSource = first
    } else {
        selectedSource = nil
    }
}
```

### 书源选择优先级

| 优先级 | 条件 | 选择 |
|--------|------|------|
| 1 | selectedSourceId 存在且能解析 | resolveSelectedSource(from:) |
| 2 | selectedSourceId 无效但有启用书源 | 第一个启用的书源 |
| 3 | 无启用书源但有书源 | 第一个书源 |
| 4 | 无书源 | nil |

## 8. 状态流与错误处理当前契约

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

| 错误来源 | 映射到 |
|----------|--------|
| AppReaderError.network | SearchState.failed |
| AppReaderError.parser | SearchState.failed |
| AppReaderError.unsupported | SearchState.unsupported |
| PlaceholderServiceError | SearchState.unsupported |
| 空关键词 | SearchState.failed |
| 无书源 | SearchState.failed |
| 空结果 | SearchState.empty |

## 9. 测试覆盖与环境限制

### 测试文件清单

| 文件 | 测试数 | 覆盖 |
|------|--------|------|
| SearchServiceContractTests.swift | 15 | Mock/Placeholder/Real 路由、状态转换 |
| SearchViewModelSelectedSourceTests.swift | 10 | selectedSourceId 解析、降级策略 |

### 环境限制

| 限制 | 说明 |
|------|------|
| Trae 无 Swift/Xcode | 无法执行 swift build/test |
| Trae 无 Reader-Core | 无法解析 package 依赖 |
| 边界检查 | ✅ PASS (checked_files=63) |
| 本地编译验证 | 待执行 |

### TEST_TARGET 编译验证

⚠️ **TEST_TARGET_COMPILE_UNVERIFIED**: 由于 Trae 环境限制，无法验证测试 target 编译是否正确。但测试文件结构遵循现有测试模式。

## 10. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| 无 | - | - | S3.P2 已实现主要功能 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-6 | 搜索取消能力 | 低 |
| P2-7 | Debounce | 低 |
| P2-8 | 旧结果覆盖防护（generation token） | 低 |
| P2-9 | 搜索历史 | 低 |
| P2-10 | 搜索分页 | 中 |
| P2-11 | 多书源聚合搜索 | 高 |

### 不属于当前 S3 的任务

| 任务 | 归属 | 说明 |
|------|------|------|
| 真实 Reader-Core 搜索接入 | S1.P2 | 需 Reader-Core 可用环境 |
| DefaultSearchService 真实装配 | S1.P2 | 需 Reader-Core API 验证 |

## 11. 是否允许关闭 S3 阶段

**结论**: 可以关闭，但需本地编译验证

**理由**:
- 搜索能力层已形成本仓 Mock 闭环
- selectedSourceId 与搜索流程连接已实现
- 核心契约已测试覆盖（除编译验证外）
- 边界检查通过
- 无阻断性问题
- Swift 编译待本地验证

**本地验证清单**:
- [ ] `cd iOS && swift package resolve`
- [ ] `cd iOS && swift build`
- [ ] `cd iOS && swift test`
- [ ] 所有新增测试通过
- [ ] TEST_TARGET 编译验证

## 12. S4 推荐任务

**任务 ID**: S4.P0  
**任务名称**: 目录 (TOC) 流程能力层 Mock / Real / Placeholder 路由契约与能力审计

**任务内容**:
1. 审计当前 TOC 流程 Mock 实现状态
2. 确认 TOCService 接口契约
3. 验证目录结果与书籍详情的连接点
4. 设计从 Mock 切换到 Real Core 的最小路径

**前提条件**: 无需 Reader-Core（可在 Mock 模式下进行）

**注意**: S4 目录流程将使用 S2 的书源选择能力
