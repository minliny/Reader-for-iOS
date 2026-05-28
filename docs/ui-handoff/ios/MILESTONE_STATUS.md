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

## M2: 单书源真实阅读闭环 — **DEVICE VERIFIED**

- Milestone result: `IOS_SINGLE_SOURCE_READING_FLOW_DEVICE_VERIFIED`

| Workstream | Status | Note |
|---|---|---|
| M2-A Provider controlledOnline full path | CODE_READY | `getBookDetail/getChapterList/getChapterContent` + controlledOnline branch + `prepareControlledOnlineAllServices()` |
| M2-B SnapshotStore detail/content | DONE | detail/content snapshot save-load path already merged |
| M2-C Integration tests + ViewModels | DEVICE_VERIFIED | full-chain fake service tests + M2.4 device validation completed |

### M2 User-Facing Checkpoints

| Checkpoint | Status | Note |
|---|---|---|
| M2.1 Book Detail | DEVICE_VERIFIED | Book Detail shell and real path verified on device |
| M2.2 TOC | DEVICE_VERIFIED | TOC shell and real path verified on device |
| M2.3 Real Content | DEVICE_VERIFIED | content path verified, "开始阅读" uses first chapter from TOC |
| M2.4 Full Reading Flow Device Review | DEVICE_VERIFIED | Search → Detail → TOC → Content → ReaderView verified on device |

**P0 阻塞已解决**: B1, B2, B4, B7 全部在 M2-A 中修复。

## M3: 缓存、离线阅读、继续阅读 — **IN PROGRESS**

- Milestone result: `IOS_M3_READING_CACHE_PROGRESS_CODE_READY`

| Workstream | Status | Note |
|---|---|---|
| M3-A Cache Store | CODE_READY | `saveChapterContentSnapshot/loadChapterContentSnapshot` — 按 sourceId+chapterURL 索引 |
| M3-B Reading Progress | CODE_READY | `ReadingProgressStore` + `BookshelfStore.updateProgress` + `saveReadingProgress()` 均已工作 |
| M3-C Continue Reading UI | CODE_READY | `BookshelfItemDetailView` "继续阅读" 按钮 → ReaderView — **设备端验证待完成** |
| M3 smoke tests | TOOLING_BLOCKED_PREEXISTING | ReaderAppTests/ShellSmokeTests 受 Xcode 26.5 深层模块解析 bug 影响 |

### M3 关键修复

| 问题 | 修复 |
|---|---|
| `SnapshotStore.loadContentSnapshot` 仅按 sourceId 索引 | 新增 `loadChapterContentSnapshot(sourceId, chapterURL)` |
| `ReaderViewModel.loadContent()` 从未真正从缓存读取正文 | 新增 cache-first 路径：先查 SnapshotStore，返回 `.cached` 状态 |
| `ReaderViewModel.cacheChapterContent()` 仅保存元数据 | 同时写 ChapterCacheStore + SnapshotStore 正文 |
| `BookshelfItemDetailView` 无继续阅读入口 | 新增"继续阅读"按钮 → `ReaderView(lastReadChapterURL, lastReadChapterTitle, bookID, sourceID)` |

## Cron Loops (3 active)

| ID | Time | Task |
|---|---|---|
| 247226d6 | 09:03 | 健康检查 (boundary + build) |
| 9c224438 | 17:57 | 进度更新 |
| 99f17f32 | 02:07 | 全量测试 (boundary + build + test) |

## M4: 书架与阅读资产整理 — **DEVICE VERIFIED**

- Milestone result: `IOS_M4_BOOKSHELF_REAL_ASSET_DEVICE_VERIFIED`

| Workstream | Status | Note |
|---|---|---|
| M4-A BookshelfStore persistence | CODE_READY | `addOrUpdate/updateProgress/find` 全部正确 |
| M4-B Add to Bookshelf / Auto Add | CODE_READY | "开始阅读"传入`bookID`/`sourceID` + onAppear自动加书架 |
| M4-C Continue Reading | DEVICE_VERIFIED | M3设备端已确认 |
| M4-D Empty state | CODE_READY | 书架空状态已处理 |

| Checkpoint | Status | Note |
|---|---|---|
| M4.1 BookIdentity stable key | DONE | `SourceIdentityFactory` → `detailURL` 作为稳定 key |
| M4.2 Add to Bookshelf | DONE | SearchView row + BookDetailView button |
| M4.3 Auto-add on Start Reading | DONE | BookDetailView "开始阅读" onAppear 自动加入书架 |
| M4.4 Progress → Bookshelf | DONE | `ReaderViewModel.saveReadingProgress()` dual-write |
| M4.5 Continue Reading | DONE | `BookshelfItemDetailView` "继续阅读" 设备端已验证 |
| M4.6 M1-M3 regression | DONE | 无回归 |

### M4 关键修复

| 问题 | 修复 |
|---|---|
| "开始阅读" 不传 `bookID`/`sourceID` | `BookDetailView` NavigationLink 新增 `bookID: sourceIdentity.id`, `sourceID: sourceIdentity.id` |
| "开始阅读" 不自动加书架 | 新增 `.onAppear { if !isInBookshelf { addToBookshelf() } }` |

## M5: 阅读历史 / 书签标注 — **DEVICE VERIFIED**

- Milestone result: `IOS_READING_HISTORY_BOOKMARKS_M5_DEVICE_VERIFIED`

| Workstream | Status | Note |
|---|---|---|
| M5-A Reading History Store | CODE_READY | `ReadingHistoryStore` — `recordOpen/loadHistoryForBook/loadRecentHistory/removeHistoryForBook` |
| M5-B Bookmark Store | CODE_READY | `BookmarkStore` — `addBookmarkNow/loadBookmarksForBook/deleteBookmark/deleteAllBookmarksForBook` |
| M5-C Minimal UI | CODE_READY | ReaderView 书签按钮 + BookshelfItemDetailView "查看书签" 入口 + `BookmarksListView` |
| M5-D Device Review | DEVICE_VERIFIED | 设备端已验证：ReaderView 进入 → 书签列表显示 → 条目信息正确 |

### M5 关键实现

| 功能 | 实现 |
|---|---|
| `ReadingHistoryStore` | `iOS/App/Persistence/ReadingHistoryStore.swift` — `recordOpen/loadHistoryForBook/loadRecentHistory` |
| `BookmarkStore` | `iOS/App/Persistence/BookmarkStore.swift` — `addBookmarkNow/loadBookmarksForBook/deleteBookmark` |
| ReaderView 书签入口 | `ReaderView.swift` 导航栏书签按钮，调用 `viewModel.addBookmark()` |
| 书签列表 | `iOS/Features/Bookshelf/BookmarksListView.swift` — 展示/删除书签，点击跳转 ReaderView |
| 书签入口 | `BookshelfItemDetailView` 新增"查看书签" 按钮 → `BookmarksListView` sheet |

## M6: 书源导入与验证 — **CODE READY**

- Milestone result: `IOS_BOOKSOURCE_IMPORT_HEADER_COMPAT_READY`

| Workstream | Status | Note |
|---|---|---|
| M6-A Import JSON | CODE_READY | `BookSourceImportNormalizer` — object-shaped rules + header normalization |
| M6-B Local Validation | CODE_READY | `BookSourceImportValidator` — 本地结构校验（不联网） |
| M6-C Save Local Source | CODE_READY | `BookSourceStore.add()` — 新增/重复处理 |
| M6-D Manual Test Entry | CODE_READY | `BookSourceDetailView` capability rows + "测试搜索" 按钮 |
| M6-E Device Review | RETRY_PENDING | M6-P1-001 + M6-P1-002 均已修复，等待 Codex 设备端复测 |

### M6 关键修复

| 问题 | 修复 |
|---|---|
| `M6-P1-001`: object-shaped rule fields decode 失败 | `BookSourceImportNormalizer` — object → JSON string，兼容 Legado 格式 |
| `M6-P1-002`: `header` 为 JSON object string decode 失败 | normalizer 将 header 转为 `[String: String]` dict |

### M6 关键实现

| 功能 | 实现 |
|---|---|
| `BookSourceImportNormalizer` | `iOS/App/Persistence/BookSourceImportNormalizer.swift` — `normalize()` — rules + header |
| `BookSourceImportValidator` | `iOS/App/Persistence/BookSourceImportValidator.swift` — `validate()` 不联网结构校验 |
| `CapabilityStatus` | enum `.ready/.missing/.invalid` — search/detail/toc/content |
| `BookSourceValidationResult` | struct — sourceId + capabilities + warnings + errors |
| `BookSourceDetailView` 增强 | 显示 capability rows + "测试搜索" 按钮 |

## M7-M8: PENDING
