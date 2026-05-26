# iOS Real Network Gate Phase 4A Report

## 1. 总体结论

**IOS_REAL_NETWORK_GATE_PHASE4A_READY**

## 2. 本轮目标

实装真实网络门禁和防误触测试。不接 live source，不执行真实网络请求。

## 3. 输入状态

| 文档 | 状态 |
|---|---|
| `IOS_REAL_NETWORK_INTEGRATION_PLANNING.md` | 已参考 |
| `IOS_REAL_DATA_PHASE1_2_3_CLOSURE_REPORT.md` | 已参考 |
| `IOS_READERCORE_FACADE_BOUNDARY_PHASE3_REPORT.md` | 已参考 |

## 4. RealNetworkPolicy / Gate 设计

| 组件 | 说明 |
|---|---|
| `RealNetworkMode` | `.disabled` / `.debugOptIn` / `.liveProbePlanned` |
| `RealNetworkPolicy` | policy 状态：mode、denialReason、requiresExplicitUserAction、isDebugOnly |
| `RealNetworkGateDecision` | `.allowed` / `.denied(reason:)` |
| `DefaultRealNetworkGate` | 仅允许 debugOptIn + DEBUG 构建；Release 永久拒绝 |
| `RealNetworkPolicyStore` | 线程安全全局 policy；Release 下 setMode 忽略 |

**默认**: `.disabled` — Debug 和 Release 均默认禁用。
**Release 保护**: `#else` 分支下 `setMode()` 被忽略，policy 永为 `.disabled`。
**Gate 检查**: `configureRealMode()` + 所有 real dispatch 路径均检查 gate。

## 5. Provider 集成

| 修改 | 说明 |
|---|---|
| `configureRealMode()` | 增加 gate 检查；denied 时返回 false |
| `canUseRealService` | 新增 private 属性，检查 mode==real + gate allowed |
| 所有 dispatch 方法 | `mode == .real` → `canUseRealService` |

默认仍为 mock，real service 未启用。

## 6. 新增文件

| 文件 | 说明 |
|---|---|
| `iOS/CoreBridge/RealNetworkPolicy.swift` | RealNetworkMode/Policy/Gate/Store |
| `iOS/Tests/ReaderAppTests/RealNetworkGateTests.swift` | 13 个 gate 测试 |

## 7. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | gate 集成：configureRealMode + dispatch guard |

## 8. Phase 1/2/3 回归

| 检查项 | 结果 |
|---|---|
| Mock flow 仍工作 | ✓（testMockSearchStillWorks, testMockContentStillWorks） |
| provider 仍默认 mock | ✓ |
| BookSource fixture-only | ✓ |
| Boundary | PASS（88 files, 0 violations） |

## 9. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（88 files, 0 violations） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 10. P0/P1/P2

- P0: 0
- P1: 0
- P2: 0

## 11. 建议进入 Phase 4B Offline Replay
