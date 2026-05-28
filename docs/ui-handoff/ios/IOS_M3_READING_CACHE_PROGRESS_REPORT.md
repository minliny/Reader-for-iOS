# iOS M3 Reading Cache and Progress Report

## 1. 总体结论

**IOS_M3_READING_CACHE_PROGRESS_CODE_READY**

## 2. Implementation

| 变更 | 说明 |
|---|---|
| `SnapshotStore.saveChapterContentSnapshot` | 按 sourceId+chapterURL 存储章节正文 |
| `SnapshotStore.loadChapterContentSnapshot` | 按 sourceId+chapterURL 读取章节正文 |
| `ReaderViewModel.loadContent()` | 缓存优先；命中返回 `.cached` 状态 |
| `ReaderViewModel.cacheChapterContent()` | 同时写 ChapterCacheStore + SnapshotStore |
| `ReaderView.readerStateView` | `.cached` 与 `.loaded` 渲染相同 |
| `BookshelfItemDetailView` | 新增"继续阅读" NavigationLink |

## 3. M3-A Cache Store

### Content Cache 读写

| 操作 | 方法 | 索引键 |
|---|---|---|
| 保存 | `saveChapterContentSnapshot(...)` | `sourceId/chapter/{chapterURL}` |
| 读取 | `loadChapterContentSnapshot(sourceId, chapterURL)` | 同上 |

### ReaderViewModel Cache-First Flow

```
loadContent()
  1. snapshotStore.loadChapterContentSnapshot(sourceId, chapterURL)
     → [HIT] → readerState = .cached(page)
     → restore readingProgress from ReadingProgressStore
     → return
  2. [MISS] → provider.getChapterContent()
     → [success] cacheChapterContent()
       - ChapterCacheStore: metadata entry
       - SnapshotStore: actual content text
     → readerState = .loaded / .partial
```

## 4. M3-B Reading Progress

所有组件已存在并正确工作：

| 组件 | 方法 |
|---|---|
| 保存进度 | `ReaderViewModel.saveReadingProgress()` (加载成功后) |
| 恢复进度 | `ReaderViewModel.restoreReadingProgress()` (init 时) |
| 按 bookID 存储 | `ReadingProgressStore.saveProgress(progress)` |
| 书架进度更新 | `BookshelfStore.updateProgress(bookID, progressRatio, chapterTitle, chapterURL)` |

## 5. M3-C Continue Reading UI

- `BookshelfItemDetailView` 新增"继续阅读"按钮 → `ReaderView(lastReadChapterURL, lastReadChapterTitle, bookID, sourceID)`
- 点击后 ReaderView 优先从 SnapshotStore 读取缓存，支持断网恢复

## 6. Safety

| 检查 | 结果 |
|---|---|
| Provider 默认 mock | ✓ |
| 真实网络未执行 | ✓ |
| M1 Search 保持 | ✓ |
| M2.1 Detail 保持 | ✓ |
| M2.2 TOC 保持 | ✓ |
| M2.3 Content 保持 | ✓ |
| Boundary | PASS |
| Build | BUILD SUCCEEDED |

## 7. Test Coverage

`iOS/Tests/ReaderAppTests/ReadingCacheAndProgressM3Tests.swift` — 12 个测试（待 ReaderAppTests target 修复后运行）

预覆盖：
- `ShellSmokeTests.RealServiceOfflineReplayTests` — content path ✓
- `ShellSmokeTests.PublicSurfaceFunctionalSmokeTests` — coordinator search ✓
- M2 `SingleSource*` — M2 回归覆盖 ✓

## 8. 文件改动

| 文件 | 改动 |
|---|---|
| `iOS/CoreBridge/SnapshotStore.swift` | +2 方法（save/loadChapterContentSnapshot） |
| `iOS/Features/Reader/ReaderViewModel.swift` | cache-first load, cache-on-success save, `.cached` state |
| `iOS/Features/Reader/ReaderView.swift` | `.cached` 渲染, actionBar 支持 |
| `iOS/Features/Bookshelf/BookshelfView.swift` | "继续阅读"按钮 |
| `iOS/Tests/ReaderAppTests/ReadingCacheAndProgressM3Tests.swift` | 新增 12 个测试 |

## 9. Next: M3-C Device Verification + ReaderAppTests Fix
