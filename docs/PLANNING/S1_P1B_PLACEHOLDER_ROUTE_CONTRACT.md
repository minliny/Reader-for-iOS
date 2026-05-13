# S1.P1B Placeholder / Mock / Real 路由契约固化

## 1. 本轮结论

**结论**: `PLACEHOLDER_ROUTE_CONTRACT_READY_ENV_UNVERIFIED`

**说明**:
- Mock / Real / Placeholder 路由契约已固化
- 边界检查通过
- 新增最小契约测试
- Swift 编译在 Trae 环境未验证

## 2. 当前环境说明

- Trae 云端环境未拉取 Reader-Core。
- Reader-Core 缺失是预期限制，不是 Reader-iOS 项目失败。
- 真实 Core 接入必须在具备 ../Reader-Core 或可解析 Reader-Core package 的环境中执行。
- 当前成果仅证明 Reader-iOS shell 具备 Mock / Real 路由分离结构，不证明真实 Core 能力。

## 3. Mock / Real / Placeholder 路由语义

| Component | Mock Mode | Real Mode |
|-----------|-----------|-----------|
| `ReaderCoreServiceProvider` | 使用 `MockReaderCoreService` | 返回 `.unsupported` |
| `ShellAssembly.makeDefaultReadingFlowCoordinator()` | `makeMockReadingFlowCoordinator()` | `makePlaceholderReadingFlowCoordinator()` |
| `SearchService` | `MockSearchService` | `PlaceholderSearchService` |
| `TOCService` | `MockTOCService` | `PlaceholderTOCService` |
| `ContentService` | `MockContentService` | `PlaceholderContentService` |
| **Default Mode** | `.mock` | `.mock` (需显式 `setMode(.real)`) |

**契约保证**:
- Mock 模式保持向后兼容，原有行为不变
- Real 模式不会静默回退到 Mock，必须明确标记为 unavailable
- Default 模式始终为 mock，除非显式设置 real

## 4. ReaderCoreServiceProvider 检查结果

| Feature | Status |
|---------|--------|
| Default mode is `.mock` | ✅ Yes |
| `setMode(.mock)` works | ✅ Yes |
| `setMode(.real)` works | ✅ Yes |
| Mock mode uses `mockService` | ✅ Yes |
| Real mode returns `.unsupported` | ✅ Yes |
| No silent fallback | ✅ Yes |

## 5. ShellAssembly 检查结果

| Feature | Status |
|---------|--------|
| `makeMockReadingFlowCoordinator()` unchanged | ✅ Yes |
| `makePlaceholderReadingFlowCoordinator()` returns placeholders | ✅ Yes |
| `makeDefaultReadingFlowCoordinator()` routes by mode | ✅ Yes |
| No silent fallback in real mode | ✅ Yes |

## 6. PlaceholderServices 检查结果

| Feature | Status |
|---------|--------|
| `PlaceholderSearchService` throws | ✅ Yes |
| `PlaceholderTOCService` throws | ✅ Yes |
| `PlaceholderContentService` throws | ✅ Yes |
| No fake success data | ✅ Yes |

## 7. 测试与边界检查结果

| Check | Result |
|-------|--------|
| Boundary Script | ✅ PASS (checked_files=58) |
| Contract Tests Added | ✅ Yes |
| Swift Build | ⚠️ ENV_COMPILE_UNVERIFIED |

## 8. 是否允许进入真实 Core 接入

- **当前 Trae 环境下**: 否。
- **具备 Reader-Core 的本地环境下**: 可以进入 Reader-Core public API 审计和真实接入。
- **Reader-iOS 本仓任务**: 可以进入，无需 Reader-Core。

## 9. 推荐下一步

**任务 ID**: S2.P0  
**任务名称**: 书源管理 UI / Persistence 契约审计

**前提条件**:
- 无需 Reader-Core
- 仅涉及 Reader-iOS 本仓

**任务内容**:
1. 审计书源管理现有功能
2. 固化书源导入、保存、启用/禁用契约
3. 验证 BookshelfStore, BookSourceStore 持久化逻辑
4. 无需真实 Core 能力
