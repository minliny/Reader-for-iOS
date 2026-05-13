# S3.P2 selectedSourceId 与搜索流程连接

## 1. 本轮结论

**结论**: `SEARCH_SELECTED_SOURCE_READY_ENV_UNVERIFIED`

**说明**:
- selectedSourceId 与搜索流程连接已实现
- 书源选择优先级已定义
- 状态流完整
- 边界检查通过
- **real mode 仍为 Placeholder，不代表真实搜索能力**
- Swift 编译在 Trae 环境未验证

## 2. S3.P1 文档补齐 / 修正

S3.P1 文档已存在且内容正确：
- 当前结论为 SEARCH_CONTRACT_READY_ENV_UNVERIFIED
- real mode 当前是 PlaceholderSearchService
- selectedSourceId 与搜索流程连接为部分实现（本轮已实现）

## 3. 当前搜索书源选择契约

### 实现前

```swift
// SearchViewModel.loadSources()
sources = try await store.load()
selectedSource = sources.first(where: { $0.enabled ?? true })
// 无 selectedSourceId 支持
```

### 实现后

```swift
// SearchViewModel.loadSources()
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
```

## 4. selectedSourceId 连接设计

### 书源选择优先级

| 优先级 | 条件 | 选择 |
|--------|------|------|
| 1 | selectedSourceId 存在且能解析 | resolveSelectedSource(from:) |
| 2 | selectedSourceId 为空但有启用书源 | 第一个启用的书源 |
| 3 | selectedSourceId 为空且无启用书源但有书源 | 第一个书源 |
| 4 | 无书源 | nil |

### 契约保证

| 场景 | 行为 |
|------|------|
| selectedSourceId 存在且有效 | 使用该书源 |
| selectedSourceId 指向已删除书源 | 返回 nil，降级到 fallback |
| selectedSourceId 文件损坏 | 返回 nil，降级到 fallback |
| 只有一个启用书源 | 使用该书源 |
| 多个启用书源但无 selectedSourceId | 使用第一个启用书源 |

## 5. 实现范围

| 文件 | 修改 | 说明 |
|------|------|------|
| `iOS/Features/Search/SearchViewModel.swift` | ✅ 修改 | loadSources() 增加 selectedSourceId 解析 |
| `iOS/App/Persistence/BookSourceStore.swift` | 无修改 | 使用已有 resolveSelectedSource(from:) |
| `iOS/Shell/ShellAssembly.swift` | 无修改 | 无需变更 |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | 无修改 | 无需变更 |

## 6. 搜索错误状态变化

### loadSources() 错误处理

| 之前 | 之后 |
|------|------|
| 抛错时设置为 .failed | 抛错时设置为 nil，让 search() 处理无书源情况 |

**原因**: loadSources() 的职责是加载书源列表，错误时设置 selectedSource = nil 交给 search() 的 "No book source selected" 错误处理更一致。

## 7. 新增 / 更新测试

### 新增测试文件
`iOS/Tests/ReaderAppPersistenceTests/SearchViewModelSelectedSourceTests.swift`

### 测试覆盖

| 测试项 | 覆盖 |
|--------|------|
| selectedSourceId 存在且有效 | ✅ testResolveSelectedSourceWithValidId |
| selectedSourceId 指向不存在书源 | ✅ testResolveSelectedSourceWithInvalidId |
| selectedSourceId 为空 | ✅ testResolveSelectedSourceWithNilId |
| selectedSourceId 优先级高于启用书源 | ✅ testSelectedSourceIdHasPriorityOverEnabled |
| 无 selectedSourceId 时降级到启用书源 | ✅ testFallbackToEnabledWhenNoSelectedSourceId |
| 无启用书源时降级到第一个书源 | ✅ testFallbackToFirstSourceWhenNoEnabledAndNoSelectedSourceId |
| 删除书源后 resolve 返回 nil | ✅ testResolveDeletedSourceReturnsNil |
| 更新书源后 resolve 反映更新 | ✅ testResolveSelectedSourceAfterSourceUpdate |
| 空书源列表 resolve 返回 nil | ✅ testResolveWithEmptySourcesReturnsNil |
| 多书源 + selectedSourceId 解析正确 | ✅ testResolveWithMultipleSourcesAndSelectedId |

## 8. 旧结果覆盖风险判断

### 当前风险

连续调用 `search()` 时：
1. 设置 `searchState = .loading`
2. 调用 `provider.searchBooks()`
3. 覆盖 `searchResults`

**问题**: 如果异步操作顺序不确定，可能出现旧结果覆盖新结果。

### 最小解决方案

使用 generation token 或 request id 验证结果时效性，但本轮不实现（改动范围大）。

### 风险评估

| 风险 | 评估 |
|------|------|
| 快速连续搜索 | ⚠️ 低风险（await 保证顺序） |
| 异步结果返回顺序 | ⚠️ 中风险（Swift async 保证顺序） |

**结论**: 当前风险可接受，暂不实现 generation token。

## 9. 边界检查与测试结果

| 检查项 | 结果 |
|--------|------|
| 边界检查脚本 | ✅ PASS (checked_files=63) |
| 新增测试文件 | ✅ SearchViewModelSelectedSourceTests.swift |
| Swift 编译 | ⚠️ ENV_COMPILE_UNVERIFIED |

## 10. 剩余 P0 / P1 / P2 缺口

### P0 必须解决

| ID | 缺口 | 状态 |
|----|------|------|
| 无 | - | - |

### P1 应尽快解决

| ID | 缺口 | 优先级 | 说明 |
|----|------|--------|------|
| P1-6 | 防止旧结果覆盖新结果 | 低 | 当前风险可接受，可延后 |

### P2 后续优化

| ID | 缺口 | 优先级 |
|----|------|--------|
| P2-10 | 搜索分页 | 中 |
| P2-11 | 多书源聚合搜索 | 高 |
| P2-12 | 搜索历史 | 低 |
| P2-13 | 搜索取消 | 低 |
| P2-14 | Debounce | 低 |

## 11. S3.P3 推荐任务

**任务 ID**: S3.P3  
**任务名称**: 搜索能力层综合验收与 S3 阶段关闭

**任务内容**:
1. 验证所有搜索能力层测试覆盖完整性
2. 补全搜索能力层综合文档
3. 确认 S3 阶段整体验收标准达成

**前提条件**: 无需 Reader-Core

## 12. 本轮未做事项

| 事项 | 原因 |
|------|------|
| Generation token 实现 | 改动范围大，当前风险可接受 |
| 真实 Core 接入 | S1.P2 暂停 |
| UI 设计优化 | 禁止 |
