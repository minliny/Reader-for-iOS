# iOS Offline Replay Phase 4B Report

## 1. 总体结论

**IOS_OFFLINE_REPLAY_PHASE4B_READY**

## 2. 本轮目标

实装 offline replay first — 本地 fixture 驱动的离线重放。不接 live source。

## 3. Input

| 文档 | 状态 |
|---|---|
| `IOS_REAL_NETWORK_GATE_PHASE4A_REPORT.md` | 已参考 |
| `IOS_REAL_NETWORK_INTEGRATION_PLANNING.md` | 已参考 |

## 4. Offline Replay 设计

| 组件 | 说明 |
|---|---|
| `OfflineReplayFixtures` | 1 书源 + 3 搜索结果 + 5 章 TOC + 5 章 ContentPage（≥2 章正文） |
| `OfflineReplayService` | 本地 fixture 驱动的 replay service，模拟 150-200ms 延迟 |
| Provider `ServiceMode.offlineReplay` | 新增 provider mode；默认仍 mock |

**数据关系**：Search → Detail → TOC → ContentPage 按 `chapterURL` 索引，支持 5 个章节的独立内容访问。

## 5. Provider 集成

| 属性 | 值 |
|---|---|
| 默认 mode | `.mock` |
| offlineReplay mode | opt-in（`enableOfflineReplay()`） |
| real mode | 仍受 RealNetworkGate 控制 |
| 所有 dispatch 方法 | 优先级: canUseRealService → offlineReplay → mock |

## 6. Replay Coverage

| 操作 | 数据量 | 内容验证 |
|---|---|---|
| Search | 3 个结果 | 凡人修仙传/仙逆/一念永恒 + 作者 + 简介 |
| Detail | 1 条（按 bookURL 匹配） | 书名/作者/简介 |
| TOC | 5 章 | 第一章~第五章 |
| Content | 5 章正文（≥2 可独立加载） | 第一章"韩立"、第二章"修仙"均有独立内容 |

## 7. 新增/修改文件

| 文件 | 说明 |
|---|---|
| `iOS/CoreBridge/OfflineReplayFixtures.swift` | 新增 — 5 chapters + 3 search results + 1 book source |
| `iOS/CoreBridge/OfflineReplayService.swift` | 新增 — replay service |
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | 修改 — 新增 `.offlineReplay` mode + dispatch |
| `iOS/Tests/ReaderAppTests/OfflineReplayPhase4BTests.swift` | 新增 — 13 个测试 |

## 8. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（89 files, 0 violations） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 9. P0/P1/P2

- P0: 0
- P1: 0
- P2: 0

## 10. 建议进入 Phase 4C planning
