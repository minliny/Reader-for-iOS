# iOS Manual First Fetch Authorization Decision

## 1. 总体结论

**IOS_MANUAL_FIRST_FETCH_AUTHORIZATION_DECISION_READY**

**当前决策：不执行首次真实 fetch。等待用户明确授权。**

## 2. 本轮目标

做首次真实 fetch 授权决策。不执行真实网络请求，不修改 Reader-Core。

## 3. 输入状态

| 文档 | 阶段 | 状态 |
|---|---|---|
| `IOS_REAL_NETWORK_GATE_PHASE4A_REPORT.md` | 4A Gate | 已参考 |
| `IOS_OFFLINE_REPLAY_PHASE4B_REPORT.md` | 4B Replay | 已参考 |
| `IOS_SINGLE_SOURCE_LIVE_PROBE_PLANNING.md` | 4C Plan | 已参考 |
| `IOS_LIVE_PROBE_GATE_PHASE4D_REPORT.md` | 4D Gate | 已参考 |
| `IOS_MANUAL_FIRST_FETCH_SNAPSHOT_PREP_PHASE4D_NEXT_REPORT.md` | 4D-next Prep | 已参考 |

## 4. 当前安全基线

| 基线 | 状态 |
|---|---|
| Provider 默认 `ServiceMode.mock` | ✓ |
| Offline replay opt-in (`enableOfflineReplay()`) | ✓ |
| Real service 未启用 | ✓ |
| `RealNetworkGate` 默认 denied | ✓ |
| `LiveProbeGate` 默认 denied | ✓ |
| `ManualLiveProbeExecutor.execute()` 拒绝真实网络 | ✓ |
| 所有 `networkExecuted` 为 false | ✓ |
| Release 永不可触发 live probe | ✓ |
| Debug 也默认 deny | ✓ |
| Boundary 91 files, 0 violations | ✓ |
| BUILD SUCCEEDED | ✓ |

## 5. 是否建议立即执行首次真实 fetch

**不建议立即执行。**

理由：
1. 当前用户未给出明确授权。
2. 候选源尚未选定。
3. 首次 fetch 的 snapshot path + audit log path 尚未确认。
4. 线上环境风险未评估（IP 封禁、反爬、合规）。
5. 优先保持 no-network 安全基线。

**如果未来用户明确授权，可在满足前置条件后执行单次控制性 fetch。**

## 6. 首次 fetch 前置条件

| # | 条件 | 当前状态 |
|---|---|---|
| 1 | 用户明确授权 | 待确认 |
| 2 | 候选源选定（low risk only） | 待选定 |
| 3 | 候选源 operation 限定（单次单 operation） | 待确认 |
| 4 | Snapshot path 已确认且安全 | 已 skeleton |
| 5 | Manifest 已填写并 approvedByUser=true | 待填写 |
| 6 | Gate 全部通过（12 项检查） | 代码就绪 |
| 7 | Rate-limit 窗口内无重复请求 | 代码就绪 |
| 8 | Fallback offline replay 已配置 | ✓（OfflineReplayFixtures） |
| 9 | Audit log 路径已确认 | skeleton 就绪 |
| 10 | Release 构建不受影响 | ✓ |
| 11 | Real service 不设默认 | ✓ |
| 12 | Executor execute 移除 Phase 4D-next guard | 待 Phase 4E-next |

## 7. 候选源选择标准

| 字段 | 要求 |
|---|---|
| candidateId | 唯一标识 |
| displayName | 中文名称 |
| host | 精确 host（不含路径） |
| baseURL | 书源根 URL |
| operation | 首次仅允许 `.search` |
| reason | 必须填写选择原因 |
| riskLevel | 必须 `.low` |
| expectedSnapshotPath | 必须合法且无路径穿越 |
| maxRequests | 必须 = 1 |
| cooldownWindow | 必须 ≥ 300s |
| fallbackReplayScenario | 必须指向已有 fixtures |

## 8. 单次 fetch 执行边界

| 允许 | 禁止 |
|---|---|
| 一次请求一个 URL | 连续请求、分页 |
| 请求后立即保存 snapshot | 不保存直接消费 |
| 请求后立即停止 | 自动进入下一操作 |
| 记录 audit log | 跳过 audit |
| 失败 fallback offline replay | 失败时静默 |
| Debug-only | Release 可见 |
| 用户显式确认 | 后台自动执行 |

## 9. 用户授权模板

当用户决定授权时，可复制以下模板并交给执行者：

```
=== 首次真实 Fetch 授权 ===

我明确授权执行一次真实网络请求，条件如下：

1. 候选源 ID：<填写 candidateId>
2. 候选源名称：<填写 displayName>
3. Host：<填写 host>
4. 操作：仅限 search
5. URL：<填写目标 URL>
6. 最大请求次数：1
7. Snapshot 路径：<填写路径，必须在 snapshotRoot 内>
8. 冷却窗口：≥ 300 秒
9. Fallback：OfflineReplayFixtures

约束：
- 请求后立即保存 snapshot。
- 不得连续请求。
- 不得保存账号/token。
- 不得启用 real service 为默认。
- 不得在 Release 构建中执行。
- 不得绕过 RealNetworkGate / LiveProbeGate。
- 失败后回退 offline replay。
- 完成后输出 audit log 和 snapshot path。

授权人：（用户签署）
授权时间：（填写）
=== 授权结束 ===
```

## 10. 风险与缓解

| # | 风险 | 级别 | 缓解 |
|---|---|---|---|
| 1 | 首次 fetch 被误认为生产接入 | P1 | UI 标注 "Debug only" + gate guard |
| 2 | 源站 IP 封禁 | P1 | 单次 1 req，间隔 ≥ 5min |
| 3 | Snapshot 包含意外内容 | P1 | metadata 标注 placeholder→real transition |
| 4 | 测试误触真实网络 | P1 | 测试 gate 强制 denied |
| 5 | Executor guard 被意外移除 | P0 | Phase 4E-next 显式移除 + audit |
| 6 | Release 可触发 | P0 | `#if !DEBUG` + gate releaseDisabled |

## 11. 下一阶段建议

| 场景 | 建议 |
|---|---|
| 用户未授权 | 保持 no-network，等待授权 |
| 用户授权 | 进入 Phase 4E-next：Manual Single Fetch and Save Snapshot |

Phase 4E-next 任务队列（用户授权后）：
1. 选定候选源并填写 manifest
2. 移除 executor Phase 4D-next guard
3. 执行单次 search
4. 保存 snapshot 到 SnapshotStore
5. 记录 audit log
6. 重置 executor guard

## 12. Boundary / Safety

| 检查项 | 结果 |
|---|---|
| 本轮未修改 Reader-Core | PASS |
| 本轮未接真实网络 | PASS |
| 本轮未接 WebDAV/RSS/Sync | PASS |
| clean-room | PASS |
| `check_ios_boundary.sh` | PASS（91 files） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 13. P0/P1

- P0: 0
- P1: 0
