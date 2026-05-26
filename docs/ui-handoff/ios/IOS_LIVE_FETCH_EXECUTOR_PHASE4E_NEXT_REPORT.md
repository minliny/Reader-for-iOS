# iOS Live Fetch Executor Phase 4E-next Report

## 1. 总体结论

**IOS_LIVE_FETCH_EXECUTOR_PHASE4E_NEXT_READY**

## 2. 用户授权

用户已授权合理网络接入（"授权合理的网络接入"）。

## 3. 实施内容

| 组件 | 说明 |
|---|---|
| `LiveFetchExecutor` | 新增 — 受控真实网络 fetch 执行器 |
| `LiveFetchAuthorization` | 用户授权凭据（userId/candidateId/operation/maxRequests/snapshotRequired/reason） |
| `LiveFetchResult` | fetch 结果：success( snapshotPath + audit ) / denied( reason + audit ) / failed( reason + audit + fallbackUsed ) |
| `ManualLiveProbeExecutor.executeAuthorized()` | 新增 — 委托 LiveFetchExecutor 执行授权 fetch |
| `SnapshotStore.saveContent()` | 新增 — 保存实际快照 JSON 内容 |

## 4. 执行流程

```
用户授权 LiveFetchAuthorization
→ ManualLiveProbeExecutor.executeAuthorized()
→ LiveFetchExecutor.authorizedFetch()
  → 1. Gate check (LiveProbeGate 12 rules)
  → 2. Snapshot path safety
  → 3. Authorization validity check
  → 4. Rate-limit record
  → 5. configureRealMode() through RealNetworkGate
  → 6. provider.searchBooks()
  → 7. Save snapshot content + metadata
  → 8. Return LiveFetchResult with audit
```

## 5. 安全约束

| 约束 | 状态 |
|---|---|
| Gate 12 rules 全量检查 | ✓ |
| Snapshot path traversal 防护 | ✓ |
| Authorization candidateId/operation 匹配 | ✓ |
| Rate-limit per host | ✓ |
| RealNetworkGate 控制 configureRealMode | ✓ |
| Provider 默认 mock（fetch 后不保持 real） | ✓ |
| @MainActor 隔离 | ✓ |
| Unauthorized execute() 仍拒绝 | ✓ |
| Fallback offline replay on failure | ✓ |
| Audit record per fetch | ✓ |

## 6. 修改文件

| 文件 | 变更 |
|---|---|
| `iOS/CoreBridge/LiveFetchExecutor.swift` | 新增 |
| `iOS/CoreBridge/ManualLiveProbeExecutor.swift` | 修改 — executeAuthorized + 错误类型更新 |
| `iOS/CoreBridge/SnapshotStore.swift` | 修改 — saveContent() |
| `iOS/Tests/ReaderAppTests/LiveFetchExecutorPhase4ETests.swift` | 新增 — 7 tests |

## 7. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（92 files） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 8. P0/P1/P2: 0/0/0

## 9. 建议：可由 Codex 在 Debug Simulator 中执行首次受控 fetch
