# iOS Real Network Integration Planning

## 1. 总体结论

**IOS_REAL_NETWORK_INTEGRATION_PLANNING_READY**

## 2. 本轮目标

只做 Phase 4 真实网络接入审计规划。不接 live source，不修改 Reader-Core，不执行真实网络请求。

## 3. 输入状态

| 文档 | 来源 | 状态 |
|---|---|---|
| `IOS_REAL_DATA_PHASE1_2_3_CLOSURE_REPORT.md` | Phase 1/2/3 收口 | 已读取 |
| `IOS_READERCORE_FACADE_BOUNDARY_PHASE3_REPORT.md` | Phase 3 facade boundary | 已参考 |
| `IOS_REAL_DATA_INTEGRATION_PLANNING.md` | 早期规划 | 已参考 |
| `ReaderCoreServiceProvider.swift` | iOS CoreBridge | 已审计 |
| `MockReaderCoreService.swift` | iOS CoreBridge | 已审计 |
| Phase 1/2 Fix Queues | 收口确认 | 已读取 |

## 4. 当前安全基线

| 基线项 | 状态 |
|---|---|
| Provider 默认 `ServiceMode.mock` | ✓ |
| `configureRealMode()` 从未被 UI 调用 | ✓ |
| `isRealModeAvailable` = false | ✓ |
| Features/App/Modules/CoreBridge 无 parser internals 引用 | ✓（0 matches） |
| Mock flow Search→Detail→TOC→ReaderView 设备端通过 | ✓ |
| BookSource local management 5 fixtures 设备端通过 | ✓ |
| Boundary 87 files, 0 violations | ✓ |
| Fresh iOS build BUILD SUCCEEDED | ✓ |
| Reader-Core 未修改 | ✓ |
| 无真实网络/WebDAV/RSS/Sync | ✓ |

## 5. Real Network 接入原则

1. **默认关闭**：Release build 绝不自动启用 real service。
2. **显式 opt-in**：必须通过明确 API 调用或 Debug toggle 启用。
3. **Offline replay first**：在 real 路径上，首先保存响应快照；后续优先使用本地快照验证。
4. **Rate-limit**：单书源单次请求间隔 ≥ 5s，全局并发 ≤ 1。
5. **Failure fallback**：real service 失败时自动回退到 mock/offline，不可阻塞 UI。
6. **No parser internals**：real service 接入不得在 Features/App/Modules 引入 parser 内部类型。
7. **No WebDAV/RSS/Sync mixing**：这些能力独立于 real network 接入，继续延后。
8. **No secrets in code**：书源 URL 使用 fixture 或用户手动输入，不硬编码生产 URL。

## 6. Phase 4 分层计划

### Phase 4A：Real Network Gate / Policy

**目标**：建立真实网络接入的安全门控和默认关闭策略。

| 允许 | 禁止 |
|---|---|
| 新增 `RealNetworkGate` (Debug-only) | 默认启用 real mode |
| 新增 provider mode guard tests | 移除 mock 默认 |
| 新增 no-network-in-tests guard | 在 Release 暴露 real toggle |
| 新增 `@AppStorage("realNetworkEnabled")` debug flag | 绕过 provider facade |

**退出条件**：
- `RealNetworkGate` 默认拒绝
- Release build 无 real mode 入口
- 测试环境强制 mock
- 至少 6 个 gate tests

### Phase 4B：Offline Replay First

**目标**：建立本地 snapshot/offline replay 机制，网络请求结果本地缓存。

| 允许 | 禁止 |
|---|---|
| 新增 `OfflineReplayStore` 保存 API 响应 | 请求真实网站作为默认行为 |
| Search/Detail/TOC/Content 支持 offline replay | 绕过 provider facade |
| fixture ↔ replay 兼容验证 | 保存真实用户数据 |

**退出条件**：
- 至少 1 个 offline replay test 通过
- Mock DTO 与 real DTO 结构兼容验证通过
- UI 能从 replay store 加载数据

### Phase 4C：Single Source Live Probe Planning

**目标**：选择一个候选书源进行 live probe 规划，不执行。

| 允许 | 禁止 |
|---|---|
| 候选书源评估 | 执行真实网络请求 |
| probe 参数设计（URL、timeout、限频） | 反爬/WAF bypass |
| snapshot 保存路径规划 | 暴露真实书源 URL 到日志 |
| 失败回退策略设计 | 在生产 UI 中默认展示 probe 结果 |

**退出条件**：
- 候选书源已评估（稳定性、响应格式、合规）
- probe 参数已文档化
- 快照/回退策略已文档化
- 等价于 Phase 4D 的前置 checklist 全部 ✅

### Phase 4D：Live Search Minimal Opt-in

**目标**：仅在 Debug + 手动开启条件下执行单次 live search。

| 允许 | 禁止 |
|---|---|
| Debug-only toggle 单次 live search | Release 默认 live search |
| 首次 fetch 后保存 fixture | 自动重试、分页、批量 |
| 失败时回退 mock | WebDAV/RSS/Sync |

**退出条件**：
- Debug toggle 仅 Debug 可见
- 单次 live search 成功获取结果
- 结果已保存为 fixture
- 失败时 UI 明确提示并使用 mock fallback

## 7. iOS 页面接入影响

| 页面 | 当前数据源 | Phase 4A | Phase 4B | Phase 4C/D |
|---|---|---|---|---|
| Search | MockReaderCoreService | 不变 | offline replay opt-in | live probe Debug-only |
| BookDetail | MockReaderCoreService | 不变 | offline replay opt-in | 随 Search |
| TOC | MockReaderCoreService | 不变 | offline replay opt-in | 随 Search |
| ReaderView | MockReaderCoreService | 不变 | offline replay opt-in | 随 Search |
| BookSource List | Local fixtureSources | 不变 | 不变 | offline validation |
| Discover | Shell placeholder | 不变 | 不变 | 延后 |
| Mine | Shell placeholder | 不变 | 不变 | 延后 |
| Prototype Gallery | 38 entries fixture | 不变 | 不变 | 不变 |
| Debug ReaderView Fixture | fixtureContent | 不变 | 不变 | 不变 |

## 8. Reader-Core / CoreBridge 边界审计

### 当前可用 Public API

| API | 类型 | 状态 |
|---|---|---|
| `SearchService` protocol | ReaderCoreProtocols | public |
| `TOCService` protocol | ReaderCoreProtocols | public |
| `ContentService` protocol | ReaderCoreProtocols | public |
| `SearchResultItem` | ReaderCoreModels DTO | public |
| `TOCItem` | ReaderCoreModels DTO | public |
| `ContentPage` | ReaderCoreModels DTO | public |
| `BookSource` | ReaderCoreModels DTO | public |
| `ReaderError` | ReaderCoreModels DTO | public |
| `LoadState<T>` | iOS CoreBridge | internal |

### 当前 Real Service 风险

`DefaultSearchService` / `DefaultTOCService` / `DefaultContentService` 依赖 `SearchParser` / `TOCParser` / `ContentParser`（ReaderCoreParser 内部类型）。这些 real service 不在 UI 层引用，但通过 `ReaderCoreServiceFactory` 创建。

**结论**：在 Phase 4D 之前，需要在 `ReaderCoreServiceFactory` 和 real service 之间增加 adapter 层，确保 parser 类型不泄漏到 UI 层。当前 boundary script 已覆盖此约束。

## 9. 风险清单

| # | 风险 | 严重度 | 缓解 |
|---|---|---|---|
| 1 | 真实网络误触发 | P0 | `RealNetworkGate` 默认拒绝 + guard tests |
| 2 | Parser internals 边界泄漏 | P0 | boundary script + facade-only 接入 |
| 3 | Live source 不稳定 | P1 | offline replay first + snapshot |
| 4 | 反爬/WAF/DDOS | P1 | rate-limit + single source + 限频 |
| 5 | Source URL/token 泄露 | P0 | 不硬编码；用户手动输入 |
| 6 | App Store 审核 | P1 | real mode Debug-only |
| 7 | 测试环境污染 | P1 | 强制 mock in tests |
| 8 | Fixture ↔ live 不一致 | P2 | DTO 兼容性验证 |
| 9 | WebView 被误用于业务 | P0 | boundary 已覆盖 |
| 10 | Provider 被误切 real | P0 | `#if DEBUG` guard + no Release entry |

## 10. 下一阶段任务队列

| ID | 阶段 | 任务 |
|---|---|---|
| RN-P4A-001 | 4A | 新增 `RealNetworkGate` struct (Debug-only) |
| RN-P4A-002 | 4A | `ReaderCoreServiceProvider` 增加 gate 检查 |
| RN-P4A-003 | 4A | 新增 `testProviderDefaultsToMock` (已有) |
| RN-P4A-004 | 4A | 新增 `testRealModeRequiresExplicitOptIn` |
| RN-P4A-005 | 4A | 新增 `testNoLiveNetworkInTests` |
| RN-P4A-006 | 4A | 新增 `testRealGateDisabledByDefault` |
| RN-P4B-001 | 4B | 新增 `OfflineReplayStore` |
| RN-P4B-002 | 4B | 新增 `testOfflineReplaySearch` |
| RN-P4B-003 | 4B | Mock DTO ↔ real DTO 兼容性测试 |
| RN-P4C-001 | 4C | 候选书源评估文档 |
| RN-P4C-002 | 4C | 单书源 probe checklist |
| RN-P4D-001 | 4D | Debug live search toggle |
| RN-P4D-002 | 4D | 首次 fetch → fixture 保存 |
| RN-P4D-003 | 4D | 失败 fallback mock |

## 11. 测试规划

| # | 测试 | 阶段 |
|---|---|---|
| 1 | Provider default mock (已有) | 4A |
| 2 | `RealNetworkGate` disabled by default | 4A |
| 3 | Real mode requires explicit opt-in | 4A |
| 4 | No live network in test bundle | 4A |
| 5 | No parser internals in UI (已有 boundary) | 4A |
| 6 | Offline replay Search returns fixture | 4B |
| 7 | Offline replay Detail returns fixture | 4B |
| 8 | Offline replay TOC returns fixture | 4B |
| 9 | Offline replay Content returns fixture | 4B |
| 10 | Real gate blocks network in default mode | 4A |
| 11 | Debug toggle only visible in DEBUG (编译时) | 4A |
| 12 | Failure fallback to mock | 4D |

## 12. Boundary / Safety

| 检查项 | 结果 |
|---|---|
| 本轮是否未修改 Reader-Core | PASS |
| 本轮是否未接真实网络 | PASS |
| 本轮是否未接 WebDAV/RSS/Sync | PASS |
| 本轮是否 clean-room | PASS |
| `check_ios_boundary.sh` | PASS（87 files, 0 violations） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 13. P0 问题

无。

## 14. P1 问题

无。

## 15. 是否建议进入 Phase 4A 实装

建议进入 **Phase 4A Real Network Gate / Policy** 实装。

前提已满足：Phase 1/2/3 已收口、boundary/build 通过、P0/P1 为 0、基线安全。
