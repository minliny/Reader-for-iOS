# iOS Controlled Network Access Phase 5 Report

## 1. 总体结论

**IOS_CONTROLLED_NETWORK_ACCESS_PHASE5_READY**

## 2. 本轮目标

实装产品级受控网络访问基础模型。网络是产品一等能力，受控、限频、缓存、快照、审计。不执行真实网络请求。

## 3. Input

| 文档 | 状态 |
|---|---|
| `IOS_CONTROLLED_NETWORK_CAPABILITY_PLANNING.md` | 架构纠偏规划 |
| `IOS_REAL_NETWORK_INFRASTRUCTURE_PHASE4_CLOSURE_REPORT.md` | Phase 4 closure |
| Phase 4 gate/executor/replay files | 已审计 |

## 4. 新增组件

| 组件 | 说明 |
|---|---|
| `UserNetworkPreference` | 用户级网络偏好：allowNetworkAccess/allowCellular/preferOfflineReplay/cacheFirst/auditEnabled/maxRequestsPerHost/cooldownSeconds |
| `SourceNetworkPolicy` | 书源级网络策略：sourceId/isEnabled/allowSearch/allowDetail/allowTOC/allowContent/host/cooldown/riskLevel |
| `ControlledNetworkOperation` | search/detail/toc/content |
| `ControlledNetworkDecision` | allowed(reason + audit) / denied(reason + fallback) / fallbackToCache |
| `NetworkAuditEntry` | sourceId/operation/host/decision/timestamp/cacheHit/networkTriggered |
| `NetworkAccessController` | 8 项检查：用户允许 → 书源启用 → 操作允许 → cacheFirst → preferOfflineReplay → rate-limit → record → allowed |

## 5. Defaults

| 默认 | 值 |
|---|---|
| `UserNetworkPreference.safeDefault` | allowNetworkAccess=false, preferOfflineReplay=true, cacheFirst=true |
| `UserNetworkPreference.productDefault` | allowNetworkAccess=true, cacheFirst=true |
| Provider mode | `.mock`（不变） |
| controlledOnline | opt-in（不默认启用） |

## 6. Gate 关系

| Gate | 用途 | 状态 |
|---|---|---|
| RealNetworkGate | 底层总闸 | 保持 |
| LiveProbeGate | 探针/候选源 | 保持（不用于产品搜索） |
| OfflineReplayService | 缓存/测试/回归/降级 | 保持 |
| NetworkAccessController | 产品级受控网络 | **新增** |

## 7. Files

| 文件 | 变更 |
|---|---|
| `iOS/CoreBridge/ControlledNetworkPolicy.swift` | 新增 |
| `iOS/Tests/ReaderAppTests/ControlledNetworkAccessPhase5Tests.swift` | 新增 — 15 tests |

## 8. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（93 files, 0 violations） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 9. P0/P1/P2: 0/0/0

## 10. 建议进入 Phase 5B dry-run integration
