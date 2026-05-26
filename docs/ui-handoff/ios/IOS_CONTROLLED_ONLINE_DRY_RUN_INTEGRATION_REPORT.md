# iOS Controlled Online Dry-Run Integration Report

## 1. 总体结论

**IOS_CONTROLLED_ONLINE_DRY_RUN_INTEGRATION_READY**

## 2. Implementation

| 变更 | 说明 |
|---|---|
| `ServiceMode.controlledOnlineDryRun` | 新增 mode |
| `enableControlledOnlineDryRun()` | provider opt-in |
| `performControlledOnlineSearch()` | NetworkAccessController → allowed/denied → offline replay 返回 |
| Detail/TOC/Content dispatch | controlledOnlineDryRun 路由到 offlineReplayService |

**Provider 默认**: `.mock`（不变）。
**真实网络**: 未执行。
**搜索结果**: 来自 OfflineReplayService（3 results，5 chapters）。

## 3. Files

| 文件 | 变更 |
|---|---|
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | 修改 — +controlledOnlineDryRun mode + dispatch |
| `iOS/Tests/ReaderAppTests/ControlledOnlineDryRunIntegrationTests.swift` | 新增 — 7 tests |

## 4. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（94 files） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 5. P0/P1/P2: 0/0/0
