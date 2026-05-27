# iOS M1.2 Controlled Online Real Search Service Report

## 1. 总体结论

**IOS_M1_2_CONTROLLED_ONLINE_REAL_SEARCH_SERVICE_READY**

## 2. Implementation

| 变更 | 说明 |
|---|---|
| `xingxingxsw.search-only.json` | 星星小说网 BookSource JSON — searchUrl + ruleSearch（CSS selector）+ ruleToc/ruleContent/ruleExplore placeholder |
| `prepareControlledOnlineSearchService()` | 新增 — 通过 NetworkAccessController evaluate + ReaderCoreServiceFactory 创建 SearchService；不走 RealNetworkGate |
| `ControlledOnlineRealBookSourceFactoryTests` | 8 tests — candidate policy / controller integration / provider defaults |

## 3. Factory Path

```
enableControlledOnline()
→ searchBooks()
→ performControlledOnlineSearch(useRealService: true)
→ NetworkAccessController.evaluate(m1Candidate, productDefault, .search)
→ allowed → prepareControlledOnlineSearchService()
→ ReaderCoreServiceFactory(httpClient:) → makeSearchService() → realSearchService
→ realSearchService.search(source, query) → results
→ denied → offlineReplayService fallback
```

## 4. Safety

| 检查 | 结果 |
|---|---|
| Provider 默认 mock | ✓ |
| controlledOnline 不默认启用 | ✓ |
| NetworkAccessController 参与 | ✓ |
| OfflineReplay fallback | ✓ |
| Parser internals 未进入 UI | ✓ |
| Boundary | PASS（96 files） |
| Build | BUILD SUCCEEDED |

## 5. Next: M1.3 SnapshotStore
