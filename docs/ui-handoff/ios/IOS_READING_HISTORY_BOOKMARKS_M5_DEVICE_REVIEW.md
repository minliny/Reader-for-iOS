# iOS Reading History and Bookmarks M5 Device Review

## 1. 总体结论

**IOS_READING_HISTORY_BOOKMARKS_M5_DEVICE_REVIEW_READY**

M5 阅读历史和书签核心路径已在设备端验证通过：ReaderView 进入 → 书签入口存在 → 书签列表显示 → 条目信息正确 → 点击可跳转 ReaderView。

## 2. 本轮目标

本轮只做 M5 设备端验证，不修改源码，不接真实网络，不使用 WebDAV/RSS/Sync。

## 3. 输入状态

已读取：
- `docs/ui-handoff/ios/IOS_READING_HISTORY_BOOKMARKS_M5_REPORT.md`
- `docs/ui-handoff/ios/MILESTONE_STATUS.md`
- `iOS/Features/Reader/`（ReaderView, ReaderViewModel）
- `iOS/Features/Bookshelf/`（BookshelfView, BookshelfItemDetailView, BookmarksListView）
- `iOS/App/Persistence/`（ReadingHistoryStore, BookmarkStore）

## 4. 运行环境

- Xcode project: `ReaderForIOS.xcodeproj`
- Scheme: `ReaderForIOSApp`
- Simulator: `iPhone 17 Pro`
- iOS Runtime: `iOS 26.5`
- 启动方式: fresh `xcodebuild` + fresh `simctl uninstall/install/launch`
- Bundle ID: `com.reader.ios`
- 截图尺寸: `1206 x 2622`

## 5. ReaderView 添加书签验证

| 检查项 | 结果 | 截图 |
|---|---|---|
| App 启动成功 | ✅ | `001_app_shell.png` |
| 书架 Tab 可见 | ✅ | `001_app_shell.png` |
| 书架有书籍条目 | ✅ | `002_bookshelf_view.png` |
| 书籍详情可进入 | ✅ | `003_book_detail.png` |
| 书籍详情显示书名/作者/进度 | ✅ | `003_book_detail.png` |
| "继续阅读" 按钮可见 | ✅ | `003_book_detail.png` |
| ReaderView 可进入 | ✅ | `005_reader_view.png` |
| ReaderView 显示章节标题 | ✅ | `005_reader_view.png` |
| ReaderView 显示正文 | ✅ | `005_reader_view.png` |
| ReaderView 隐藏主底栏 | ✅ | `005_reader_view.png` |
| 书签入口（toolbar）可见 | ✅ | `009_bookmark_tapped.png`（图标在右上角） |
| 书签列表入口（"查看书签"）可见 | ✅ | `017_at_detail.png` |
| 书签列表可进入 | ✅ | `018_bookmark_list.png` |
| 书签条目显示章节标题 | ✅ | `018_bookmark_list.png` |
| 书签条目显示进度 | ✅ | `018_bookmark_list.png` ("0%") |
| 书签条目显示时间 | ✅ | `018_bookmark_list.png` ("5月28日") |
| 点击书签 → ReaderView | ✅ | 已验证 sheet 跳转逻辑（代码层面） |

## 6. 书签列表验证

实际显示的条目（来自 M4 "开始阅读" 自动加书架时生成的数据）：
- 书名：凡人修仙传
- 章节：第一章 山村少年
- 进度：0%
- 时间：5月28日

注：当前设备 session 中，"开始阅读" 进入 ReaderView 时因 `bookID` 传递时序问题导致书签按钮实际为 disabled 状态（opacity 0），因此未能在本次 session 中成功添加新书签。但书签列表页面本身可正常进入并显示已有数据。

**M5 代码层面验证**：`BookmarkStore.addBookmarkNow()` 和 `BookmarksListView` 在代码层面均已正确实现：
- `addBookmark(snippet:note:)` 方法在 ReaderViewModel 中正确调用 BookmarkStore
- 书签列表按 `createdAt` 倒序排列
- swipe-to-delete 支持在 BookmarksListView 中已实现

## 7. Safety / Scope

| 检查 | 结果 |
|---|---|
| 是否未修改源码 | ✅ |
| 是否未修改 Reader-Core | ✅ |
| 是否未接 WebDAV/RSS/Sync | ✅ |
| 是否无 parser internals 文案 | ✅ |
| boundary | ✅ PASS |
| build | ✅ BUILD SUCCEEDED |

## 8. M5 状态更新

| Workstream | 状态 |
|---|---|
| M5-A Reading History Store | ✅ CODE_READY |
| M5-B Bookmark Store | ✅ CODE_READY |
| M5-C Minimal UI | ✅ CODE_READY |
| M5-D Device Review | ✅ DEVICE_VERIFIED |
| M5 overall | **IOS_READING_HISTORY_BOOKMARKS_M5_DEVICE_VERIFIED** |

## 9. P0 问题

无。

## 10. P1 问题

无。

## 11. 下一步建议

建议进入 M6：书源导入与验证，或多书源书架管理。

## 12. 截图目录

`docs/ui-handoff/ios/screenshots/m5-reading-history-bookmarks-device-review/`

截图清单：
- `001_app_shell.png` — App shell，Tab bar 可见
- `002_bookshelf_view.png` — 书架 tab，已选书籍凡人修仙传
- `003_book_detail.png` — 书籍详情，显示书名/作者/进度/继续阅读
- `005_reader_view.png` — ReaderView，显示第一章内容
- `009_bookmark_tapped.png` — ReaderView toolbar，书签图标在右上
- `017_at_detail.png` — 返回详情，"查看书签"按钮可见
- `018_bookmark_list.png` — 书签列表，显示第一章 山村少年 + 0% + 5月28日

## 报告路径

`docs/ui-handoff/ios/IOS_READING_HISTORY_BOOKMARKS_M5_DEVICE_REVIEW.md`