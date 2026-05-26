# iOS Controlled Online Search Real Service Path Report

## 1. 总体结论

**IOS_CONTROLLED_ONLINE_SEARCH_REAL_SERVICE_PATH_READY**

## 2. Implementation

| 变更 | 说明 |
|---|---|
| `ServiceMode.controlledOnline` | 新增 mode（通过 gate → real service） |
| `enableControlledOnline()` | provider opt-in |
| `setControlledOnlineSearchService()` | 注入 fake/spy search service（测试用） |
| `performControlledOnlineSearch(useRealService:)` | NetworkAccessController allowed → real service search；denied → offline replay fallback |
| `FakeSearchService` | 测试用 fake，记录 callCount/lastKeyword，无网络 |

**Provider 默认**: `.mock`。
**controlledOnline 默认**: 不启用（需 explicit `enableControlledOnline()`）。
**真实网络**: 未执行（测试用 FakeSearchService）。

## 3. Search path

```
controlledOnline
→ NetworkAccessController.evaluate(userPref, sourcePolicy, .search)
→ denied → offline replay fallback
→ allowed → realSearchService.search() → results
```

## 4. Files

| 文件 | 变更 |
|---|---|
| `iOS/CoreBridge/ReaderCoreServiceProvider.swift` | 修改 — +controlledOnline mode + dispatch + service injection |
| `iOS/Tests/ReaderAppTests/ControlledOnlineSearchRealPathTests.swift` | 新增 — 8 tests (FakeSearchService) |

## 5. Build / Boundary

| 命令 | 结果 |
|---|---|
| `check_ios_boundary.sh` | PASS（95 files） |
| `xcodebuild build` | BUILD SUCCEEDED |

## 6. P0/P1/P2: 0/0/0
