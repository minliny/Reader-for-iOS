# iOS Controlled Network Capability Planning

## 1. 总体结论

**IOS_CONTROLLED_NETWORK_CAPABILITY_PLANNING_READY**

## 2. 本轮目标

对 Phase 4 网络策略进行架构纠偏。从"真实网络等待一次性授权"调整为"真实网络是受控的一等产品能力"。

## 3. 纠偏原因

Reader for iOS 是一个需要联网获取书籍信息和章节内容的阅读工具。网络访问不是异常行为——它是产品的核心能力。

之前的 Phase 4 策略过度保守：将所有真实网络访问都视为需要特殊一次性的"用户授权"。这不符合产品目标。

**正确约束**：受控、限频、缓存、快照、回放、失败回退、可审计——而不是默认永久禁止。

## 4. 新网络能力原则

| 场景 | 策略 |
|---|---|
| 测试环境 | 默认 no-network（mock/offline replay） |
| CI | 默认 no-network |
| Debug 开发 | 可手动开启 controlled online 或 probe |
| Release 生产 | 用户配置书源后允许受控联网 |
| 首次探针 | 更严格 gate + manifest + snapshot |

**不应要求每一次正常搜索都由用户复制长授权语句。**

应改为：**用户级网络开关 + 书源级启用 + 限频 + 快照 + 审计**。

## 5. 新网络模式规划

### 5.1 RealNetworkMode 演进

```
disabled          — 完全禁网（测试、隐私模式、用户关闭）
offlineReplay     — 仅本地 snapshot/fixture（测试、回归、缓存验证）
controlledOnline  — 正常产品联网（用户启用书源后 Search/Detail/TOC/Content）
debugProbe         — 开发用单源探针（比 controlledOnline 更严格 gate）
liveProbeManual    — 手动一次性探针（开发阶段首次抓取快照）
```

### 5.2 模式对比

| 模式 | 测试 | Debug | Release | 需要 gate |
|---|---|---|---|---|
| disabled | 默认 | 可选 | 用户可关闭 | 否 |
| offlineReplay | 可用 | 可用 | 降级路径 | 否 |
| controlledOnline | 禁止 | 可开启 | 用户启用后可用 | 是（source/snapshot/rate-limit） |
| debugProbe | 禁止 | 可开启 | 禁止 | 是（更强） |
| liveProbeManual | 禁止 | 可开启 | 禁止 | 是（最强） |

## 6. 新 Policy / Controller 规划

### 6.1 UserNetworkPreference

```
allowNetworkAccess: Bool
allowCellular: Bool
preferOfflineReplay: Bool
maxRequestsPerHost: Int
cacheFirst: Bool
```

用户可在设置中控制网络偏好。

### 6.2 SourceNetworkPolicy

```
sourceId: String
isEnabled: Bool
allowSearch: Bool
allowDetail: Bool
allowTOC: Bool
allowContent: Bool
host: String
cooldownSeconds: TimeInterval
lastRequestAt: Date?
```

每个书源独立控制允许的操作和频次。

### 6.3 NetworkAccessController

```
evaluate(userPolicy:, sourcePolicy:, operation:) → AccessDecision
- allowed (with constraints)
- denied (reason)
- fallbackReplay (use snapshot)

metadata: host, operation, time, snapshotPath, auditRecord
```

替代原先过于严格的 LiveProbeGate 作为产品级网络控制。

### 6.4 Snapshot / Cache 策略

```
首次 controlledOnline fetch → 保存 snapshot
后续请求 → 优先 snapshot（未过期）
snapshot 过期 → 受控刷新
刷新失败 → 回退过期 snapshot 或 offline replay
回归测试 → 强制使用 snapshot
```

## 7. Provider / Gate 重构建议

| 当前组件 | 演进方向 |
|---|---|
| RealNetworkPolicy (.disabled/.debugOptIn/.liveProbePlanned) | 扩展为 5 级模式 |
| RealNetworkGate | 演进为 NetworkAccessController |
| LiveProbeGate | 保留用于 debugProbe/liveProbeManual |
| OfflineReplayService | 保留作为缓存/测试/降级路径 |
| ManualLiveProbeExecutor | 保留用于开发探针 |
| LiveFetchExecutor | 演进为 ControlledNetworkExecutor |
| LiveProbePolicy | 拆分：probe policy vs product network policy |

### Provider 默认建议

| 环境 | 默认 |
|---|---|
| 测试 | disabled（或 offlineReplay 用于 replay tests） |
| Debug Simulator | offlineReplay（开发安全默认） |
| Release | offlineReplay（首次使用无缓存）；用户启用书源后 controlledOnline |

## 8. UI 接入规划

| 页面 | 当前 | 修改建议 |
|---|---|---|
| Search | mock | controlledOnline（用户启用书源后） |
| BookDetail | mock | controlledOnline |
| TOC | mock | controlledOnline |
| ReaderView | mock | controlledOnline |
| BookSource | fixture | 书源启用/禁用 + SourceNetworkPolicy |
| Mine / Settings | placeholder | 网络开关 + 缓存策略 |
| Discover | shell | 延后 |
| Debug Tools | gate skeleton | probe 入口 + replay 开关 |

## 9. 需要保留的安全约束

| 约束 | 状态 |
|---|---|
| 测试默认不联网 | 保留 |
| CI 默认不联网 | 保留 |
| Release 不允许 debugProbe/liveProbeManual | 保留 |
| 任何网络访问需 source/operation/host/reason | 保留 |
| Host 限频 | 保留 |
| Snapshot/cache 优先 | 新增 |
| 不保存账号/token/cookie | 保留 |
| Parser internals 不进 UI | 保留 |
| WebDAV/RSS/Sync 独立阶段 | 保留 |
| UI 通过 provider/controller，不直接调 executor | 保留 |

## 10. 风险与防护

| 风险 | 防护 |
|---|---|
| 高频访问 | rate-limit per host |
| 反爬 | 限频 + cooldown |
| 用户隐私 | 无账号/token 保存 |
| 源站不稳定 | snapshot/cache + fallback replay |
| CI 误触网络 | test gate forced disabled |
| 默认 real service 误启 | controlledOnline 需显式 opt-in |
| 缓存污染 | snapshot TTL + metadata versioning |

## 11. Phase 5 任务队列 (Phase 5)

| ID | 任务 |
|---|---|
| CNA-001 | UserNetworkPreference model |
| CNA-002 | SourceNetworkPolicy model |
| CNA-003 | NetworkAccessController skeleton |
| CNA-004 | Provider controlledOnline mode |
| CNA-005 | RealNetworkMode 5-level expansion |
| CNA-006 | Search controlledOnline dry-run tests |
| CNA-007 | Cache/snapshot-first policy tests |
| CNA-008 | Mine network preference planning |
| CNA-009 | CI no-network guard tests |
| CNA-010 | Phase 5 report + fix queue |

下一阶段建议：`IOS_CONTROLLED_NETWORK_ACCESS_PHASE5_READY`。

## 12. Boundary / Safety

| 检查 | 结果 |
|---|---|
| 本轮未接真实网络 | PASS |
| 未执行 fetch | PASS |
| Reader-Core 未修改 | PASS |
| Parser internals 0 | PASS |
| WebDAV/RSS/Sync 未接 | PASS |
| `check_ios_boundary.sh` | PASS（92 files） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 13. P0/P1: 0/0
