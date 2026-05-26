# iOS Manual First Fetch Snapshot Prep Phase 4D-next Report

## 1. 总体结论

**IOS_MANUAL_FIRST_FETCH_SNAPSHOT_PREP_PHASE4D_NEXT_READY**

## 2. 本轮目标

做首次手动 fetch 前的准备工作：executor skeleton、dry-run flow、snapshot metadata schema、audit log schema。不执行真实网络请求。

## 3. Input

| 文档 | 状态 |
|---|---|
| `IOS_LIVE_PROBE_GATE_PHASE4D_REPORT.md` | Phase 4D |
| `IOS_SINGLE_SOURCE_LIVE_PROBE_PLANNING.md` | Phase 4C |
| `IOS_OFFLINE_REPLAY_PHASE4B_REPORT.md` | Phase 4B |
| `IOS_REAL_NETWORK_GATE_PHASE4A_REPORT.md` | Phase 4A |

## 4. ManualLiveProbeExecutor

| 组件 | 说明 |
|---|---|
| `ManualFetchRequest` | 请求模型 — 默认 dryRunOnly=true |
| `ManualFetchDryRunResult` | 结果模型 — networkExecuted 永远 false |
| `ManualLiveProbeExecutor` | 执行器 — prepare/dryRun/execute/validateNoNetwork |
| `SnapshotMetadata` | 快照元数据 — isPlaceholder=true, networkExecuted=false |
| `LiveProbeAuditRecord` | 审计记录 — decision + deniedReason + dryRunOnly |

**execute()** 在本阶段永远 denied。错误类型 `ManualExecutorError.fetchNotAllowedInPhase4DNext` 携带 audit record，错误信息明确："Phase 4D-next 不允许真实 fetch。需用户明确授权。"

## 5. Dry-run Flow

```
ManualFetchRequest
→ prepare() → gate check → path safety → metadata path
→ dryRun() → ManualFetchDryRunResult (networkExecuted=false)
→ execute() → always .failure (Phase 4D-next guard)
```

## 6. Added Files

| 文件 | 说明 |
|---|---|
| `iOS/CoreBridge/ManualLiveProbeExecutor.swift` | Executor + Request + Result + Metadata + Audit |
| `iOS/Tests/ReaderAppTests/ManualFirstFetchSnapshotPrepTests.swift` | 18 tests |

## 7. Gate/Poly Regression

| 检查项 | 结果 |
|---|---|
| Release denied | ✓ |
| Debug default denied | ✓ |
| Explicit opt-in required | ✓ |
| Manifest required | ✓ |
| Snapshot path required | ✓ |
| Rate-limit enforced | ✓ |
| Provider default mock | ✓ |
| Offline replay opt-in | ✓ |

## 8. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（91 files） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 9. P0/P1/P2: 0/0/0

## 10. 建议进入 Phase 4E authorization decision
