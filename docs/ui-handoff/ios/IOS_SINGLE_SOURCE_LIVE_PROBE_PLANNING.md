# iOS Single Source Live Probe Planning

## 1. 总体结论

**IOS_SINGLE_SOURCE_LIVE_PROBE_PLANNING_READY**

## 2. 本轮目标

只做单书源 live probe 的安全规划。不执行任何真实网络请求，不修改 Reader-Core。

## 3. 输入状态

| 文档 | 阶段 | 状态 |
|---|---|---|
| `IOS_REAL_NETWORK_GATE_PHASE4A_REPORT.md` | Phase 4A gate | 已参考 |
| `IOS_OFFLINE_REPLAY_PHASE4B_REPORT.md` | Phase 4B replay | 已参考 |
| `IOS_REAL_NETWORK_INTEGRATION_PLANNING.md` | Phase 4 顶层规划 | 已参考 |
| `RealNetworkPolicy.swift` | gate 实现 | 已审计 |
| `OfflineReplayFixtures.swift` | replay 数据 | 已审计 |
| `OfflineReplayService.swift` | replay 服务 | 已审计 |
| `ReaderCoreServiceProvider.swift` | provider | 已审计 |
| `DefaultSearchService.swift` | real service | 已审计（含 parser internals 风险） |

## 4. 当前安全基线

| 基线 | 状态 |
|---|---|
| Provider 默认 `ServiceMode.mock` | ✓ |
| Offline replay opt-in (`enableOfflineReplay()`) | ✓ |
| `RealNetworkGate` 默认 denied | ✓ |
| `configureRealMode()` 受 gate 保护 | ✓ |
| Release 下 `RealNetworkPolicyStore.setMode()` 被忽略 | ✓ |
| Debug 默认 `.disabled` | ✓ |
| Parser internals 0 引用（UI 层） | ✓ |
| 无真实网络请求 | ✓ |
| Boundary 89 files, 0 violations | ✓ |
| Build BUILD SUCCEEDED | ✓ |

## 5. Single Source Live Probe 原则

1. **Debug-only**：Release 构建不可达任何 live probe 路径。
2. **Explicit opt-in**：需两次确认 — 用户手动 toggle + manifest 审批。
3. **Manifest required**：每次 live probe 必须记录目的、来源、时间、快照路径。
4. **Snapshot required**：fetch 结果必须保存为本地快照，后续优先回放。
5. **Rate-limit**：同一 host 在时间窗口内只能 fetch 1 次。
6. **Failure fallback**：失败时自动回退 offline replay / mock。
7. **No repeated fetch**：同一 URL 已有未过期快照时不重复 fetch。
8. **Offline replay first**：优先使用已有快照/offline replay 数据。

## 6. 候选源选择策略

### 评估标准

| 维度 | 标准 |
|---|---|
| 稳定性 | URL 可访问、无频繁 50x/40x |
| 格式兼容 | 返回 SearchResultItem/TOCItem/ContentPage 兼容结构 |
| 合规 | 非盗版、非需登录、非需反爬 |
| 频控友好 | 单个 search 请求量 ≤ 10KB |
| 快照友好 | 响应可被序列化为本地 fixture |

### 风险等级

| 等级 | 条件 | 允许操作 |
|---|---|---|
| Low | 稳定 + 兼容 + 合规 + 公开 | 单次 search + detail + TOC + content |
| Medium | 任一维度有轻微风险 | 仅单次 search |
| High | 需登录/反爬/不稳定 | 不允许 live probe |
| Banned | 盗版/违法/需破解 | 永久禁止 |

### Phase 4D 默认候选

建议优先选择 **Low** 风险等级的公开书源进行首次 live probe。候选书源在 Phase 4D 实装时选定，本轮只规划选择标准。

## 7. Phase 4C 允许 vs 禁止

| 允许 | 禁止 |
|---|---|
| 文档规划 | live search |
| 候选源风险评估标准 | live detail fetch |
| snapshot 路径规划 | live TOC fetch |
| rate-limit 策略规划 | live content fetch |
| tests 规划 | 真实 parser/runtime |
| 组件 skeleton 设计 | 真实网站请求 |
| | WebDAV/RSS/Sync 接入 |

## 8. Phase 4D 执行边界

Phase 4D 的允许范围（下一阶段规划）：

| 允许 | 禁止 |
|---|---|
| LiveProbePolicy skeleton | Release 可见 |
| LiveProbeManifest tests | 自动重复 fetch |
| SnapshotStore local path | 绕过 gate |
| Single candidate risk audit | 未保存 snapshot 就丢弃响应 |
| Debug-only manual probe gate | 多 host 并发 |
| No repeated fetch tests | 高频轮询 |
| **首次 fetch 后立即保存 snapshot** | 不保存直接消费 |

## 9. 建议组件设计

### LiveProbeCandidate

```
id: String
name: String
baseURL: String
riskLevel: RiskLevel (low/medium/high/banned)
allowedOperations: Set<ProbeOperation>
requiresManualApproval: Bool
```

### LiveProbePolicy

```
debugOnly: Bool (= true)
explicitOptIn: Bool (= true)
maxRequestsPerHostPerWindow: Int (= 1)
windowSeconds: TimeInterval (= 300)
snapshotRequired: Bool (= true)
fallbackToOfflineReplay: Bool (= true)
releaseDisabled: Bool (= true)
```

### LiveProbeManifest

```
candidateId: String
operation: ProbeOperation
requestedAt: Date
approvedByUser: Bool
reason: String
expectedSnapshotPath: String
```

### SnapshotStore

```
saveSearchSnapshot(candidateId:, query:, results:)
saveDetailSnapshot(candidateId:, bookURL:, detail:)
saveTOCSnapshot(candidateId:, bookURL:, items:)
saveContentSnapshot(candidateId:, chapterURL:, page:)
loadSearchSnapshot(candidateId:, query:) -> [SearchResultItem]?
loadDetailSnapshot(candidateId:, bookURL:) -> SearchResultItem?
loadTOCSnapshot(candidateId:, bookURL:) -> [TOCItem]?
loadContentSnapshot(candidateId:, chapterURL:) -> ContentPage?
hasFreshSnapshot(candidateId:, key:, maxAge:) -> Bool
```

### LiveProbeGate

```
evaluate(candidate:, operation:, policy:) -> GateDecision
deny reasons: riskLevel, rate-limit, no manifest, Release
rate-limit: check last fetch time per host
snapshot precondition: require snapshot path before fetch
```

## 10. iOS 页面接入影响

| 页面 | Phase 4C (规划) | Phase 4D (skeleton) |
|---|---|---|
| Search | 不接入 | 不接入 |
| BookDetail | 不接入 | 不接入 |
| TOC | 不接入 | 不接入 |
| ReaderView | 不接入 | 不接入 |
| BookSource | 候选源评估 | 候选源列表 |
| Discover | 不接入 | 不接入 |
| Mine / Developer Tools | 规划入口 | Debug gate toggle + manifest viewer |

## 11. Reader-Core / CoreBridge 边界

| 问题 | 回答 |
|---|---|
| 是否需要新 adapter | 是 — SnapshotStore adapter |
| 是否需要 snapshot/replay adapter | 是 — 与 OfflineReplayService 协同 |
| 是否继续禁止 parser internals | 是 |
| 是否需要在 iOS 层继续 gate | 是 |

## 12. 风险清单

| # | 风险 | 级别 | 缓解 |
|---|---|---|---|
| 1 | 真实网络误触发 | P0 | gate + Release disabled |
| 2 | 高频访问/DDOS | P0 | rate-limit 1 req/5min/host |
| 3 | 反爬/验证码/IP 封禁 | P1 | Low risk 候选 only |
| 4 | 源站结构变化 | P1 | snapshot + fallback offline replay |
| 5 | Snapshot 与 live 不一致 | P2 | metadata versioning |
| 6 | Parser internals 边界泄漏 | P0 | boundary script |
| 7 | Release 误暴露 live probe | P0 | #if DEBUG |
| 8 | Debug 工具误触发 | P1 | explicit double opt-in |
| 9 | Secrets/token/URL 泄露 | P0 | 不硬编码 |
| 10 | WebView 被误用于业务 | P0 | boundary gate |
| 11 | 测试误触真实网络 | P1 | test gate forced disabled |
| 12 | 用户以为已接真实书源 | P2 | UI 明确标注 "Debug only" |

## 13. 下一阶段任务队列 (Phase 4D)

| ID | 任务 |
|---|---|
| RN-P4D-001 | LiveProbePolicy 结构 skeleton |
| RN-P4D-002 | LiveProbeManifest 结构 + tests |
| RN-P4D-003 | SnapshotStore 本地路径规划 |
| RN-P4D-004 | 单候选源风险审计 |
| RN-P4D-005 | Debug-only manual probe gate skeleton |
| RN-P4D-006 | LiveProbeGate rate-limit tests |
| RN-P4D-007 | No repeated fetch tests |
| RN-P4D-008 | Phase 4D report |

## 14. 测试规划 (Phase 4D)

| # | 测试 |
|---|---|
| 1 | LiveProbePolicy default disabled |
| 2 | Release live probe always denied |
| 3 | Debug live probe requires explicit opt-in |
| 4 | Live probe requires manifest |
| 5 | Live probe requires snapshot path |
| 6 | Repeated host fetch within window denied |
| 7 | No live network in unit tests |
| 8 | Offline replay fallback required |
| 9 | Mock/offline replay default unchanged |
| 10 | No parser internals in iOS UI |
| 11 | Candidate risk level required |
| 12 | Denial reason recorded |

## 15. Boundary / Safety

| 检查项 | 结果 |
|---|---|
| 本轮未修改 Reader-Core | PASS |
| 本轮未接真实网络 | PASS |
| 本轮未接 WebDAV/RSS/Sync | PASS |
| 本轮 clean-room | PASS |
| `check_ios_boundary.sh` | PASS（89 files） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 16. P0/P1

- P0: 0
- P1: 0

## 17. 建议进入 Phase 4D

建议进入 **Phase 4D Debug-only Single Live Probe Gate Skeleton**。初始任务：gate / manifest / snapshot skeleton + tests，不执行真实 fetch。
