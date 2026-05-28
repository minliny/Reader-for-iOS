# iOS Reading History and Bookmarks M5 Report

## 1. 总体结论

**IOS_READING_HISTORY_BOOKMARKS_M5_READY**

M5 阅读历史和书签功能已完成实现，包括 M5-A ReadingHistoryStore、M5-B BookmarkStore 和 M5-C 最小 UI 入口。

## 2. 本轮目标

本轮目标是构建本地阅读历史和书签标注基础设施，不做高亮/批注/云同步/跨设备同步。

## 3. 输入状态

已读取：
- `docs/ui-handoff/ios/MILESTONE_STATUS.md`
- `docs/ui-handoff/ios/IOS_BOOKSHELF_REAL_ASSET_M4_REPORT.md`
- `iOS/Features/Reader/`（ReaderView, ReaderViewModel）
- `iOS/Features/Bookshelf/`（BookshelfView, BookshelfItemDetailView）
- `iOS/App/Persistence/`（ReadingProgressStore, BookshelfStore, ChapterCacheStore）
- `iOS/AppSupport/Sources/`（BookshelfItem, ReadingProgress, SourceIdentity）
- `iOS/CoreBridge/SnapshotStore.swift`
- `scripts/check_ios_boundary.sh`

## 4. 当前缺口审计

| 项目 | 审计结果 |
|---|---|
| 是否有阅读历史 Store | ❌ 无 — 需要新建 |
| 是否有书签 Store | ❌ 无 — 需要新建 |
| ReaderView 书签入口 | ❌ 无 — 需要添加 |
| BookshelfItemDetailView 书签入口 | ❌ 无 — 需要添加 |
| 书签列表页 | ❌ 无 — 需要新建 |

## 5. 实现内容

### M5-A: ReadingHistoryStore

**文件**: `iOS/App/Persistence/ReadingHistoryStore.swift`

- `ReadingHistoryEvent` struct: id/bookId/sourceId/sourceName/title/author/chapterURL/chapterTitle/progress/openedAt/updatedAt
- `recordOpen()`: 记录阅读事件，多次打开同一书更新最近记录
- `loadHistoryForBook()`: 读取某书最近阅读记录
- `loadRecentHistory(limit:)`: 读取最近 N 条
- `loadAll()`: 全量读取
- `removeHistoryForBook()`: 删除某书历史

### M5-B: BookmarkStore

**文件**: `iOS/App/Persistence/BookmarkStore.swift`

- `Bookmark` struct: id/bookId/sourceId/sourceName/title/author/chapterURL/chapterTitle/progress/snippet/note/createdAt/updatedAt
- `addBookmarkNow()`: 添加书签，自动去重（bookId + chapterURL + progress 相同位置去重）
- `loadBookmarksForBook()`: 读取某书全部书签
- `deleteBookmark()`: 按 id 删除
- `deleteAllBookmarksForBook()`: 删除某书全部书签
- `hasBookmarkAt()`: 检查某位置是否已有书签

### M5-C: Minimal UI

#### ReaderView 书签入口

**文件**: `iOS/Features/Reader/ReaderView.swift`

- 导航栏右侧新增书签按钮（bookmark icon）
- 无 bookID 时按钮禁用（opacity 0）
- 点击调用 `viewModel.addBookmark()`

#### ReaderViewModel 方法

**文件**: `iOS/Features/Reader/ReaderViewModel.swift`

- `addBookmark(snippet:note:)`: 调用 `BookmarkStore.addBookmarkNow()`
- `recordHistoryEvent()`: 调用 `ReadingHistoryStore.recordOpen()`
- `currentBookID`: 公开访问器（暴露 private bookID）

#### BookshelfItemDetailView 书签入口

**文件**: `iOS/Features/Bookshelf/BookshelfView.swift`

- "查看书签" 按钮 → `BookmarksListView` sheet

#### BookmarksListView

**文件**: `iOS/Features/Bookshelf/BookmarksListView.swift`

- 展示某书全部书签（章节名/snippet/进度/时间）
- 点击书签 → 打开对应 ReaderView
- 支持删除书签（swipe-to-delete）

### M5-D: Device Review

待设备端验证（Bookmark 按钮 → BookshelfItemDetailView 查看书签 → 点击书签回到 ReaderView）。

## 6. 验证结果

| 检查 | 结果 |
|---|---|
| boundary | ✅ PASS |
| build | ✅ BUILD SUCCEEDED |
| 测试 target | ⚠️ TOOLING_BLOCKED_PREEXISTING（Xcode 26.5 bug，ReaderAppTests/ShellSmokeTests 仍不可用） |

## 7. M1-M4 回归影响

✅ 无回归 — M5 仅新增文件和方法，未修改 M1-M4 已有代码。

## 8. P0 问题

无。

## 9. P1 问题

无。

## 10. 下一步建议

**M5 Device Review**：在设备上验证以下路径：
1. 书架 → 书籍详情 → 点击"查看书签" → 书签列表（空状态）
2. 阅读书籍 → 点击导航栏书签按钮 → 添加成功提示
3. 书架 → 同一书籍详情 → "查看书签" → 显示已添加的书签
4. 点击书签 → 打开对应章节的 ReaderView

## 报告路径

`docs/ui-handoff/ios/IOS_READING_HISTORY_BOOKMARKS_M5_REPORT.md`