# S1.P1 Real Core Assembly Spike

## 1. 本轮结论

**结论**: `READY_WITH_CORE_API_GAPS`

**说明**: 
- 已建立 Mock ↔ Real Core 切换的完整架构路径
- Real 模式当前使用 Placeholder 实现，明确返回 `.unsupported` 状态而非静默降级
- 需要 Reader-Core 的 public API (HTTPClient, RequestBuilder, SearchParser/TOCParser/ContentParser) 才能实现真实接入

## 2. 修改范围

### 新增文件
- `iOS/CoreIntegration/PlaceholderServices.swift`: 包含 PlaceholderSearchService, PlaceholderTOCService, PlaceholderContentService

### 修改文件
- `iOS/Shell/ShellAssembly.swift`: 新增 `makePlaceholderReadingFlowCoordinator()`, 修改 `makeDefaultReadingFlowCoordinator()`
- `iOS/CoreBridge/ReaderCoreServiceProvider.swift`: 实现了真实的 mode 路由逻辑

## 3. ReaderCoreServiceProvider mode 路由结果

| Mode | Behavior |
|------|----------|
| `.mock` | 使用原有 `mockService` (保持兼容) |
| `.real` | 返回明确的 `.unsupported(reason:)` 状态 |

**改进**: `setMode()` 现在真正影响后续 service 创建，不再无条件调用 `mockService`

## 4. ShellAssembly real assembly 结果

| Method | Result |
|--------|--------|
| `makeMockReadingFlowCoordinator()` | 原样返回 Mock Coordinator (未改变) |
| `makePlaceholderReadingFlowCoordinator()` | 返回基于 PlaceholderServices 的 Coordinator |
| `makeDefaultReadingFlowCoordinator()` | 根据 `currentMode` 路由到 Mock 或 Placeholder |

**改进**: `makeDefaultReadingFlowCoordinator()` 不再直接等价于 `makeMockReadingFlowCoordinator()`

## 5. DefaultSearchService / DefaultTOCService / DefaultContentService 装配结果

**状态**: 存在但未在当前 Spike 中装配

**原因**: 缺少 Reader-Core 的 public API (HTTPClient, RequestBuilder, Parsers)，无法构造真实依赖

**方案**: 保留 Default*Service 源码，待 Reader-Core 可用时再装配

## 6. Reader-Core public API 缺口

| Type | Source | Status |
|------|--------|--------|
| `HTTPClient` | Reader-Core | 未确认 public initializer |
| `RequestBuilder` | Reader-Core | 未确认 public initializer |
| `SearchParser` | Reader-Core | 未确认 public initializer |
| `TOCParser` | Reader-Core | 未确认 public initializer |
| `ContentParser` | Reader-Core | 未确认 public initializer |

**影响**: 无法在 ShellAssembly 中构造真实 Default*Service

## 7. 测试与边界检查结果

| Check | Result |
|-------|--------|
| Boundary Script | ✅ PASS (checked_files=57) |
| Swift Build | ⚠️ ENV_COMPILE_UNVERIFIED (Trae 环境限制) |

## 8. 剩余风险

| Risk | Impact |
|------|--------|
| Reader-Core API not available | 无法实现真实接入 |
| Placeholder 模式容易被混淆为真实接入 | 已在代码中明确标记为 placeholder |

## 9. S1.P2 推荐任务

**任务 ID**: S1.P2  
**任务名称**: 接入 Reader-Core public API 实现真实服务

**前提条件**:
- Reader-Core 仓库可用
- HTTPClient, RequestBuilder, Parsers 有 public initializer

**任务内容**:
1. 确认 Reader-Core public API 可见性
2. 在 ShellAssembly 中构造真实 HTTPClient/RequestBuilder/Parsers
3. 装配 DefaultSearchService/DefaultTOCService/DefaultContentService
4. 替换 Placeholder 为真实实现
