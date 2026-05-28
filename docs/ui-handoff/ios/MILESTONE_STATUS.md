# Milestone Status

Last updated: 2026-05-28

## M1: 单书源真实搜索 MVP — **CLOSED**

## M2: 单书源真实阅读闭环 — IN PROGRESS (0/3)

| Task | Status | Blocked By |
|---|---|---|
| M2-A Provider controlledOnline detail/toc/content path | PENDING | — |
| M2-B SnapshotStore detail/content + BookSource JSON 补全 | PENDING | M2-A |
| M2-C Integration tests + ViewModel verification | PENDING | M2-A, M2-B |

**阻塞分析**:
- B1: detail/toc/content dispatcher 缺 controlledOnline branch → M2-A 解决
- B2: 只创建 SearchService → M2-A 解决
- B3: ruleBookInfo 为空 → 接受（搜索结果数据够用）
- B4: canUseRealService 走 RealNetworkGate → controlledOnline 走 NetworkAccessController

**Cron Loops**: 健康检查 (daily 9:03) + 进度更新 (daily 17:57) + 全量测试 (daily 2:07)

## M3-M8: PENDING
