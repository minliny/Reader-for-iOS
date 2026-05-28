# iOS Reading Cache and Progress M3 Plan

## 1. 总体结论

**IOS_READING_CACHE_AND_PROGRESS_M3_PLAN_READY**

## 2. 审计结果

### 已有的基础设施

| 组件 | 状态 | 说明 |
|---|---|---|
| `ChapterCacheStore` | ✅ 存在 | 元数据缓存（ChapterCacheEntry），不含正文内容 |
| `SnapshotStore` | ✅ 存在 | search/detail/toc/content 快照存储 |
| `ReadingProgressStore` | ✅ 存在 | 按 bookID 存储阅读进度 |
| `BookshelfStore.updateProgress` | ✅ 存在 | 更新 lastReadChapterTitle/URL + readingProgress |
| `ReaderViewModel.saveReadingProgress()` | ✅ 存在 | 加载成功后自动保存进度 |
| `ReaderViewModel.restoreReadingProgress()` | ✅ 存在 | init 时按 chapterURL 匹配恢复 |

### 发现的关键缺口

1. **`SnapshotStore.loadContentSnapshot` 仅按 `sourceId` 索引**：只返回最近一次缓存的内容，无法按 `chapterURL` 查询特定章节缓存。
2. **`ReaderViewModel.loadContent()` 从未真正从缓存读取正文**：只检查 `ChapterCacheStore` 元数据（有 status=cached 标记），但从未从 `SnapshotStore` 加载实际文本。
3. **`ReaderViewModel.cacheChapterContent()` 仅保存元数据**：`ChapterCacheEntry` 只有 `sourceID/bookURL/chapterURL/chapterTitle/cachedAt`，没有正文内容。
4. **`BookshelfItemDetailView` 无"继续阅读"按钮**：详情页显示进度但不能直接跳转。

### 无需修改 Reader-Core

- `ContentPage` 模型已有 `title/content/chapterURL/nextChapterURL`
- `ReadingProgress` DTO 已有完整字段
- `BookshelfItem` 已有 `lastReadChapterTitle/URL` + `readingProgress`
- 所有 persistence 逻辑在 iOS 层实现

## 3. M3 开发计划

### M3-A: Cache Store — 统一缓存读写

**目标**：content snapshot 按 chapter 级别读写，支持离线阅读

**实现**：
- `SnapshotStore.saveChapterContentSnapshot(sourceId, chapterURL, ...)` — 按 `sourceId/chapter/chapterURL` 路径存储
- `SnapshotStore.loadChapterContentSnapshot(sourceId, chapterURL)` — 按相同路径读取
- `ReaderViewModel.loadContent()` — 先查 SnapshotStore，返回 `.cached` 状态
- `ReaderViewModel.cacheChapterContent()` — 同时写 ChapterCacheStore（元数据）和 SnapshotStore（正文）
- `ReaderView` — 渲染 `.cached` 状态（与 `.loaded` 相同）

**输出**：`IOS_M3_A_READING_CACHE_STORE_READY`

### M3-B: Reading Progress — 进度记录与恢复

**目标**：退出后重新进入能恢复上次阅读位置

**实现**：
- `ReadingProgressStore` + `BookshelfStore.updateProgress()` 已存在并正确工作
- `ReaderViewModel.saveReadingProgress()` 在内容加载成功后自动调用
- `ReaderViewModel.restoreReadingProgress()` 在 init 时恢复 scroll ratio
- `BookshelfItem.lastReadChapterTitle/URL` 已正确更新

**输出**：`IOS_M3_B_READING_PROGRESS_READY`

### M3-C: Continue Reading UI — 继续阅读入口

**目标**：书架/书籍详情能显示并恢复阅读

**实现**：
- `BookshelfItemDetailView` 新增"继续阅读"按钮 → `NavigationLink` 推送到 `ReaderView`
- `ReaderView` 使用 `lastReadChapterURL/lastReadChapterTitle/item.id/sourceID` 参数

**输出**：`IOS_M3_C_OFFLINE_CONTINUE_READING_READY`

## 4. 本轮实际完成内容

### 代码修改（4 个文件）

1. **`iOS/CoreBridge/SnapshotStore.swift`** — 新增 `saveChapterContentSnapshot`/`loadChapterContentSnapshot`（按 sourceId+chapterURL 索引）
2. **`iOS/Features/Reader/ReaderViewModel.swift`** — 缓存优先加载（`.cached` 状态）、`cacheChapterContent` 同时写 SnapshotStore、新增 `snapshotStore` 依赖
3. **`iOS/Features/Reader/ReaderView.swift`** — `.cached` 状态渲染（与 `.loaded` 相同）、`actionBar` 支持 `.cached`
4. **`iOS/Features/Bookshelf/BookshelfView.swift`** — `BookshelfItemDetailView` 新增"继续阅读"按钮

### 测试覆盖

- `iOS/Tests/ReaderAppTests/ReadingCacheAndProgressM3Tests.swift`（12 个测试）
  - 注：`ReaderAppTests` target 有模块依赖问题（M2 已存在），测试文件已写入待后续修复
- `ShellSmokeTests`：M1/M2 回归全部通过

## 5. 数据流

### Content Cache Flow

```
ReaderView.onAppear
  → viewModel.loadContent()
  → snapshotStore.loadChapterContentSnapshot(sourceId, chapterURL)
  → [cache HIT] → readerState = .cached(page) → loadedContentView
  → [cache MISS] → provider.getChapterContent()
  → [success] cacheChapterContent()
    → ChapterCacheStore.saveEntry(metadata)
    → SnapshotStore.saveChapterContentSnapshot(content text)
  → readerState = .loaded / .partial / .failed
```

### Continue Reading Flow

```
BookshelfItemDetailView "继续阅读"
  → ReaderView(lastReadChapterURL, lastReadChapterTitle, bookID, sourceID)
  → loadContent()
  → [cache HIT] → 显示缓存正文 + 恢复阅读进度
  → [cache MISS] → provider.getChapterContent()
```

## 6. 验证结果

| 指标 | 结果 |
|---|---|
| boundary | PASS |
| build | BUILD SUCCEEDED |
| M2 regression | 全部通过 |
| P0 | 0 |
| P1 | 0（代码侧修复完成）|

## 7. 下一步建议

1. **M3-C 设备端验证**：书架"继续阅读"按钮 → ReaderView 缓存恢复
2. **ReaderAppTests target 修复**：模块依赖问题（`@testable import ReaderApp` 无法解析）
3. **M3-C UI 增强**：书架页顶部"最近阅读"分区（items with readingProgress > 0）
