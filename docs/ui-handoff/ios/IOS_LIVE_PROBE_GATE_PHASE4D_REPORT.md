# iOS Live Probe Gate Phase 4D Report

## 1. 总体结论

**IOS_LIVE_PROBE_GATE_SKELETON_PHASE4D_READY**

## 2. 本轮目标

实装 live probe gate / manifest / snapshot / rate-limit skeleton + tests。不执行真实网络请求。

## 3. Input

| 文档 | 状态 |
|---|---|
| `IOS_SINGLE_SOURCE_LIVE_PROBE_PLANNING.md` | Phase 4C 规划 |
| `IOS_OFFLINE_REPLAY_PHASE4B_REPORT.md` | Phase 4B |
| `IOS_REAL_NETWORK_GATE_PHASE4A_REPORT.md` | Phase 4A |

## 4. LiveProbePolicy 设计

| 属性 | 默认值 |
|---|---|
| debugOnly | true |
| explicitOptInRequired | true |
| snapshotRequired | true |
| fallbackToOfflineReplayRequired | true |
| releaseDisabled | true |
| maxRequestsPerHost | 1 |
| windowSeconds | 300 |

## 5. LiveProbeGate 决策规则

| # | 条件 | 结果 |
|---|---|---|
| 1 | Release build | denied |
| 2 | 未 explicit opt-in | denied |
| 3 | Manifest 不完整 | denied |
| 4 | approvedByUser=false | denied |
| 5 | reason 为空 | denied |
| 6 | snapshot path 为空 | denied |
| 7 | riskLevel != low | denied |
| 8 | operation 不在 allowedOperations | denied |
| 9 | host 不匹配 | denied |
| 10 | rate-limit 超限 | denied |
| 11 | 全部通过 | allowed（不执行网络） |

## 6. Added Files

| 文件 | 说明 |
|---|---|
| `iOS/CoreBridge/LiveProbePolicy.swift` | Candidate, Policy, Manifest, Gate, RateLimiter |
| `iOS/CoreBridge/SnapshotStore.swift` | 路径安全 + 占位元数据，不保存真实内容 |
| `iOS/Tests/ReaderAppTests/LiveProbeGatePhase4DTests.swift` | 20 tests |

## 7. Provider / Gate Relationship

- Provider 默认仍 mock
- Offline replay 仍 opt-in
- Real mode 仍受 RealNetworkGate 控制
- LiveProbeGate allowed ≠ real service enabled

## 8. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（90 files, 0 violations） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 9. P0/P1/P2: 0/0/0

## 10. 建议进入 Phase 4D-next
