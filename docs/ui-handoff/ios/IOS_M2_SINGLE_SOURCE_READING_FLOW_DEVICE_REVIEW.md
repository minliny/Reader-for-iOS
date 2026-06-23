# iOS M2 Single Source Reading Flow Device Review

## 1. 总体结论

IOS_M2_SINGLE_SOURCE_READING_FLOW_DEVICE_REVIEW_READY

## 2. 本轮目标

本轮只做 M2.4 设备端全链路验证，不修改源码，不做 Detail/TOC/Content 之外的扩展，也不接 WebDAV/RSS/Sync。

## 3. 输入状态

已读取：
- [IOS_M2_3_REAL_CONTENT_REPORT.md](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_M2_3_REAL_CONTENT_REPORT.md)
- [IOS_M2_2_SINGLE_SOURCE_TOC_REPORT.md](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_M2_2_SINGLE_SOURCE_TOC_REPORT.md)
- [IOS_M2_1_SINGLE_SOURCE_BOOK_DETAIL_REPORT.md](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_M2_1_SINGLE_SOURCE_BOOK_DETAIL_REPORT.md)
- [IOS_M1_SINGLE_SOURCE_SEARCH_MVP_CLOSURE_REPORT.md](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_M1_SINGLE_SOURCE_SEARCH_MVP_CLOSURE_REPORT.md)
- [MILESTONE_STATUS.md](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/MILESTONE_STATUS.md)

## 4. 运行环境

- Xcode project: `ReaderForIOS.xcodeproj`
- Scheme: `ReaderForIOSApp`
- Simulator: `iPhone 17 Pro`
- iOS Runtime: `iOS 26.5`
- 启动方式: `xcodebuild` fresh build + `simctl uninstall/install/launch` fresh install
- Bundle id: `com.reader.ios`
- 截图尺寸: Simulator device screenshot, full phone frame

## 5. Path A：Search → Detail → TOC → ReaderView

1. 从书架页右上角进入 Search。
2. 默认书源初始为 `None`，手动切换到 `⭐ 星星小说网`。
3. 输入 query `凡人`。
4. Search 结果出现后，点击第一条 `凡人修仙传 / 忘语 / ⭐ 星星小说网`。
5. 进入 Book Detail，页面显示书名、作者、来源、简介、`查看目录（5 章）` 与 `开始阅读`。
6. 点击 `查看目录（5 章）`，进入 TOC sheet。
7. TOC 显示 5 章。
8. 点击第一章 `第一章 山村少年`，进入 ReaderView。
9. ReaderView 显示章节标题与正文，非 warning-only，非空白页，主底栏隐藏。

截图路径：
- [001_app_shell.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/001_app_shell.png)
- [002_search_page.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/002_search_page.png)
- [003_search_results.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/003_search_results.png)
- [004_book_detail.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/004_book_detail.png)
- [005_toc_sheet_or_page.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/005_toc_sheet_or_page.png)
- [006_reader_from_toc.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/006_reader_from_toc.png)
- [007_reader_tabbar_hidden_from_toc.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/007_reader_tabbar_hidden_from_toc.png)
- [008_back_to_detail.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/008_back_to_detail.png)

## 6. Path B：Search → Detail → Start Reading → ReaderView

1. 从 Book Detail 点击 `开始阅读`。
2. 进入 ReaderView，显示章节标题 `第一章 山村少年` 与正文。
3. 没有出现 example.com 假 URL 读取结果。
4. 主底栏隐藏，返回后恢复到 Book Detail。

截图路径：
- [009_reader_from_start_reading.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/009_reader_from_start_reading.png)
- [010_reader_start_reading_content.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/010_reader_start_reading_content.png)
- [011_back_restores_tabs.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m2-single-source-reading-flow-device-review/011_back_restores_tabs.png)

## 7. ReaderView 验证

- 是否显示章节标题: 是
- 是否显示正文: 是
- 是否隐藏主底栏: 是
- 是否非 warning-only: 是
- 是否非空白页: 是

## 8. Safety / Scope

- 是否未修改源码: 是
- 是否未修改 Reader-Core: 是
- 是否未做 WebDAV/RSS/Sync: 是
- 是否无 parser internals 文案: 是

## 9. M2 状态更新

- M2.1 Book Detail: `DEVICE_VERIFIED`
- M2.2 TOC: `DEVICE_VERIFIED`
- M2.3 Real Content: `DEVICE_VERIFIED`
- M2.4 Full Reading Flow Device Review: `DEVICE_VERIFIED`
- M2 overall: `IOS_SINGLE_SOURCE_READING_FLOW_DEVICE_VERIFIED`

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. 是否建议进入 M3

建议进入 M3：缓存、离线阅读、继续阅读。
