# Milestone Status

Last updated: 2026-05-28

## M1: 单书源真实搜索 MVP — **CLOSED**

- Milestone result: `IOS_M1_SINGLE_SOURCE_SEARCH_MVP_CLOSED`
- Device review result: `IOS_M1_SINGLE_SOURCE_SEARCH_DEVICE_REVIEW_READY`
- DevTools real-search review: `IOS_XINGXINGXSW_REAL_SEARCH_DEVTOOLS_VERIFIED`

| Task | Status | Note |
|---|---|---|
| M1.1 候选源选择 + SourceNetworkPolicy | CODE_READY | search-only candidate source wired to 星星小说网 |
| M1.2 controlledOnline 接真实 SearchService | CODE_READY | `prepareControlledOnlineSearchService()` → `ReaderCoreServiceFactory` → `makeSearchService()` |
| M1.3 保存搜索结果到 SnapshotStore | CODE_READY | search snapshot write/read path exists |
| M1.4 Search UI 展示真实结果 | CODE_READY | Search UI displays title/author/sourceName/results |
| M1.5 Codex 设备端验证 | DEVICE_VERIFIED | 星星小说网真实搜索 UI 结果已设备端确认 |

## M2: 单书源真实阅读闭环 — **IN PROGRESS (2/3)**

| Workstream | Status | Note |
|---|---|---|
| M2-A Provider controlledOnline full path | CODE_READY | `getBookDetail/getChapterList/getChapterContent` + controlledOnline branch + `prepareControlledOnlineAllServices()` |
| M2-B SnapshotStore detail/content | DONE | detail/content snapshot save-load path already merged |
| M2-C Integration tests + ViewModels | READY | full-chain fake service tests / device follow-up ready |

### M2 User-Facing Checkpoints

| Checkpoint | Status | Note |
|---|---|---|
| M2.1 Book Detail | CODE_READY | Book Detail shell and real path ready |
| M2.2 TOC | CODE_READY | TOC shell and real path ready |
| M2.3 Real Content | NEXT | content path is next validation focus |
| M2.4 Full Reading Flow Device Review | PENDING | Search → Detail → TOC → Content → ReaderView device validation |

**P0 阻塞已解决**: B1, B2, B4, B7 全部在 M2-A 中修复。

## Cron Loops (3 active)

| ID | Time | Task |
|---|---|---|
| 247226d6 | 09:03 | 健康检查 (boundary + build) |
| 9c224438 | 17:57 | 进度更新 |
| 99f17f32 | 02:07 | 全量测试 (boundary + build + test) |

## M3-M8: PENDING
