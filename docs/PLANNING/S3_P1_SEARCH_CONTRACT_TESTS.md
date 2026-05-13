# S3.P1 搜索能力层契约测试与状态流补强

## 1. 本轮结论

**结论**: `SEARCH_CONTRACT_READY_ENV_UNVERIFIED`

**说明**:
- Mock/Placeholder 路由契约已验证
- 状态流转换已测试覆盖
- 边界检查通过
- **real mode 仍为 Placeholder，不代表真实搜索能力**
- **selectedSourceId 与搜索流程连接仍为部分实现**
- Swift 编译在 Trae 环境未验证

## 2. S3.P0 结论修正

| S3.P0 原结论 | S3.P1 修正结论 | 修正原因 |
|-------------|---------------|---------|
| SEARCH_CAPABILITY_READY_ENV_UNVERIFIED | READY_WITH_GAPS | real mode 是 Placeholder |
| selectedSourceId 需求 "已实现" | "部分实现" | 未从 BookSourceStore.loadSelectedSourceId() 读取 |
| Mock/Placeholder/Real 可区分 | Mock/Placeholder 可区分 | real mode 返回 unsupported |
| DefaultSearchService 已可真实搜索 | 真实 Core 依赖未验证 | 需 Reader-Core API 验证 |

## 3. SearchService 契约

### 协议定义

```swift
public protocol SearchService {
    func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem]
}
```

### 三条实现路径

| 路径 | 依赖 | 行为 | 状态 |
|------|------|------|------|
| Mock | ReaderCoreServiceProvider | 委托给 mockService | ✅ 已验证 |
| Placeholder | 无 | 抛出 unavailable | ✅ 已验证 |
| Default | HTTPClient/RequestBuilder/Parser | 构造真实请求 | ❌ 未验证 |

### 契约语义

| 契约项 | 说明 |
|--------|------|
| 输入 | BookSource + SearchQuery(keyword, page) |
| 输出 | [SearchResultItem] (可为空数组) |
| 错误 | throws AppReaderError / PlaceholderServiceError |
| 空结果 | 返回空数组 []，不是 nil |

## 4. MockSearchService 测试结果

| 测试项 | 结果 | 说明 |
|--------|------|------|
| 搜索成功返回结果 | ✅ | 返回 3 个 mock 结果 |
| 搜索空场景 | ✅ | 返回空数组 [] |
| 搜索 unsupported 场景 | ✅ | 抛出 AppReaderError.unsupported |
| 搜索网络失败场景 | ✅ | 抛出 AppReaderError.network |
| 服务层返回数组而非 nil | ✅ | 空结果返回 [] |

## 5. PlaceholderSearchService 测试结果

| 测试项 | 结果 | 说明 |
|--------|------|------|
| 抛出 realCoreNotAvailable | ✅ | 抛出 PlaceholderServiceError |
| 不返回 Mock 结果 | ✅ | Placeholder 不委托 mock |
| 独立于 provider.mockScenario | ✅ | 始终 unavailable |

## 6. ReaderCoreServiceProvider 搜索路由结果

| 测试项 | 结果 | 说明 |
|--------|------|------|
| mock mode 委托 mockService | ✅ | 返回 .loaded |
| real mode 返回 unsupported | ✅ | 不委托 mock |
| real mode 不返回 mock 结果 | ✅ | 隔离验证通过 |

### 路由语义确认

```swift
// ReaderCoreServiceProvider.searchBooks()
switch currentMode {
case .mock:
    return await mockService.searchBooks(keyword: keyword, page: page)
case .real:
    return .unsupported(reason: "Real Core service not available...")
}
```

**确认**: real mode 不会静默回退到 mock。

## 7. selectedSourceId 与搜索流程连接状态

### 当前架构

```swift
// SearchViewModel
@Published public var selectedSource: BookSource?

public func loadSources() async {
    sources = try await store.load()
    selectedSource = sources.first(where: { $0.enabled ?? true })
}
```

### 连接缺口

| 检查项 | 状态 | 说明 |
|--------|------|------|
| 从 BookSourceStore.load() 获取书源 | ✅ 已实现 | loadSources() |
| 从 BookSourceStore.loadSelectedSourceId() 获取选中 ID | ❌ 未实现 | 未调用 |
| resolveSelectedSource(from:) | ❌ 未实现 | 未调用 |
| selectedSource 持久化 | ❌ 未实现 | 仅内存状态 |
| 搜索使用 selectedSource | ✅ 已实现 | 搜索时检查 |

**缺口**: SearchViewModel.loadSources() 只取第一个启用的书源，未使用 selectedSourceId 持久化。

## 8. 状态流与错误映射

### 状态转换测试

| 转换 | 测试覆盖 |
|------|----------|
| idle → loaded | ✅ |
| idle → empty | ✅ |
| idle → failed | ✅ |
| idle → unsupported | ✅ |
| idle → partial | ✅ |

### 错误映射

| 错误来源 | 映射到 |
|----------|--------|
| AppReaderError.network | SearchState.failed |
| AppReaderError.parser | SearchState.failed |
| AppReaderError.unsupported | SearchState.unsupported |
| PlaceholderServiceError | SearchState.unsupported |
| 空结果 | SearchState.empty |

## 9. 重复搜索 / 取消能力判断

### 当前实现

```swift
public func search() async {
    searchState = .loading
    // 直接覆盖 searchResults
    // 无 Task 取消
    // 无 generation 防止旧结果覆盖
}
```

### 缺口

| 能力 | 状态 | 优先级 |
|------|------|--------|
| 搜索取消 | ❌ 未实现 | P2 |
| 防止旧结果覆盖新结果 | ⚠️ 部分风险 | P1 |
| Debounce | ❌ 未实现 | P2 |
| Request ID | ❌ 未实现 | P2 |

**风险**: 快速连续搜索可能导致结果顺序不确定。

## 10. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=62) |
| 新增测试文件 | ✅ SearchServiceContractTests.swift |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 11. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-5 | selectedSourceId 与搜索连接 | 中 | 搜索应使用持久化的 selectedSourceId |
| P1-6 | 防止旧结果覆盖新结果 | 低 | 快速连续搜索风险 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-6 | 搜索取消能力 | 低 |
| P2-7 | Debounce | 低 |
| P2-8 | Request ID | 低 |
| P2-9 | 搜索历史 | 低 |
| P2-10 | 搜索分页 | 中 |
| P2-11 | 多书源聚合搜索 | 高 |

## 12. S3.P2 推荐任务

**任务 ID**: S3.P2  
**任务名称**: selectedSourceId 与搜索流程连接

**任务内容**:
1. 修改 SearchViewModel.loadSources() 使用 BookSourceStore.loadSelectedSourceId()
2. 调用 resolveSelectedSource(from:) 解析选中书源
3. 测试 selectedSourceId 持久化影响搜索

**前提条件**: 无需 Reader-Core

## 13. 本轮未做事项

| 事项 | 原因 |
|------|------|
| selectedSourceId 连接实现 | P1-5 待实现 |
| 搜索取消能力 | P2-6 优化项 |
| 防止旧结果覆盖实现 | P1-6 优化项 |
| 真实 Core 接入 | S1.P2 暂停 |
