# S1.P1 Real Core Assembly Spike

## 1. 本轮结论

**结论**: `READY_WITH_CORE_API_GAPS`

**说明**: 
- 已建立 Mock ↔ Real Core 切换的完整架构路径
- Real 模式当前使用 Placeholder 实现，明确返回 `.unsupported` 状态而非静默降级
- 真实 Core 接入需要在具备 Reader-Core 的环境中执行

## 2. 当前环境说明

- Trae 云端环境未拉取 Reader-Core。
- Reader-Core 缺失是预期限制，不是 Reader-iOS 项目失败。
- 真实 Core 接入必须在具备 ../Reader-Core 或可解析 Reader-Core package 的环境中执行。
- 当前成果仅证明 Reader-iOS shell 具备 Mock / Real 路由分离结构，不证明真实 Core 能力。

## 3. 修改范围

### 新增文件
- `iOS/CoreIntegration/PlaceholderServices.swift`: 包含 PlaceholderSearchService, PlaceholderTOCService, PlaceholderContentService

### 修改文件
- `iOS/Shell/ShellAssembly.swift`: 新增 `makePlaceholderReadingFlowCoordinator()`, 修改 `makeDefaultReadingFlowCoordinator()`
- `iOS/CoreBridge/ReaderCoreServiceProvider.swift`: 实现了真实的 mode 路由逻辑

## 4. ReaderCoreServiceProvider mode 路由结果

| Mode | Behavior |
|------|----------|
| `.mock` | 使用原有 `mockService` (保持兼容) |
| `.real` | 返回明确的 `.unsupported(reason:)` 状态 |

**改进**: `setMode()` 现在真正影响后续 service 创建，不再无条件调用 `mockService`

## 5. ShellAssembly real assembly 结果

| Method | Result |
|--------|--------|
| `makeMockReadingFlowCoordinator()` | 原样返回 Mock Coordinator (未改变) |
| `makePlaceholderReadingFlowCoordinator()` | 返回基于 PlaceholderServices 的 Coordinator |
| `makeDefaultReadingFlowCoordinator()` | 根据 `currentMode` 路由到 Mock 或 Placeholder |

**改进**: `makeDefaultReadingFlowCoordinator()` 不再直接等价于 `makeMockReadingFlowCoordinator()`

## 6. DefaultSearchService / DefaultTOCService / DefaultContentService 装配结果

**状态**: 存在但未在当前 Spike 中装配

**原因**: 缺少 Reader-Core 的 public API (HTTPClient, RequestBuilder, Parsers)，无法构造真实依赖

**方案**: 保留 Default*Service 源码，待 Reader-Core 可用时再装配

## 7. Reader-Core public API 缺口

| Type | Source | Status |
|------|--------|--------|
| `HTTPClient` | Reader-Core | 未确认 public initializer |
| `RequestBuilder` | Reader-Core | 未确认 public initializer |
| `SearchParser` | Reader-Core | 未确认 public initializer |
| `TOCParser` | Reader-Core | 未确认 public initializer |
| `ContentParser` | Reader-Core | 未确认 public initializer |

**影响**: 无法在 ShellAssembly 中构造真实 Default*Service

## 8. 测试与边界检查结果

| Check | Result |
|-------|--------|
| Boundary Script | ✅ PASS (checked_files=57) |
| Swift Build | ⚠️ ENV_COMPILE_UNVERIFIED (Trae 环境限制) |

## 9. 剩余风险

| Risk | Impact |
|------|--------|
| Reader-Core API not available | 无法实现真实接入 |
| Placeholder 模式容易被混淆为真实接入 | 已在代码中明确标记为 placeholder |

## 10. 是否允许进入真实 Core 接入

- 当前 Trae 环境下：否。
- 可进入 Reader-iOS 本仓内部功能完善任务。
- 真实 Core 接入等待本地或具备 Reader-Core 的环境。
