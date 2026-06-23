# iOS M3 Continue Reading Device Review

## 1. 总体结论

IOS_M3_CONTINUE_READING_DEVICE_REVIEW_READY

## 2. 本轮目标

本轮只做 M3-C 设备端验证，确认“继续阅读”是否能从书架/书籍详情进入 ReaderView，并显示已缓存或已记录章节；不修改源码，不接真实网络。

## 3. 输入状态

已读取：
- [MILESTONE_STATUS.md](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/MILESTONE_STATUS.md)
- [IOS_M3_READING_CACHE_PROGRESS_REPORT.md](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_M3_READING_CACHE_PROGRESS_REPORT.md)
- [IOS_M2_SINGLE_SOURCE_READING_FLOW_DEVICE_REVIEW.md](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_M2_SINGLE_SOURCE_READING_FLOW_DEVICE_REVIEW.md)
- `iOS/Features/Bookshelf/`
- `iOS/Features/Reader/`
- `iOS/CoreBridge/SnapshotStore.swift`
- `iOS/Tests/ReaderAppTests/ReadingCacheAndProgressM3Tests.swift`

## 4. 运行环境

- Xcode project: `ReaderForIOS.xcodeproj`
- Scheme: `ReaderForIOSApp`
- Simulator: `iPhone 17 Pro`
- iOS Runtime: `iOS 26.5`
- 启动方式: fresh `xcodebuild` + fresh `simctl uninstall/install/launch`
- Bundle ID: `com.reader.ios`
- 截图尺寸: `1206 x 2622`
- 备注: fresh install 后模拟器容器被清空，随后在 Simulator app container 中重建了 M3 继续阅读所需的 bookshelf / reading_progress 测试数据，以完成设备端复测。

## 5. Continue Reading 路径验证

实际采用路径 A。

1. 启动 App。
2. 进入“书架”。
3. 找到已存在书籍条目“凡人修仙传 / 忘语”。
4. 打开书籍详情。
5. 确认“继续阅读”入口可见并可点击。
6. 点击“继续阅读”后进入 ReaderView。
7. ReaderView 显示已记录章节内容，并保留阅读进度。

Path B 未单独走搜索造进度链路，因为路径 A 已在设备端稳定命中并完成验证。

截图路径：
- [001_app_shell.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m3-continue-reading-device-review/001_app_shell.png)
- [003_book_item_or_detail.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m3-continue-reading-device-review/003_book_item_or_detail.png)
- [005_reader_from_continue_reading.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m3-continue-reading-device-review/005_reader_from_continue_reading.png)
- [007_back_restores_tabs.png](file:///Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m3-continue-reading-device-review/007_back_restores_tabs.png)

## 6. ReaderView 验证

- 是否显示章节标题: 是
- 是否显示正文: 是
- 是否隐藏主底栏: 是
- 是否非 warning-only: 是
- 是否非空白页: 是
- 观察到的章节内容: `第一章 山村少年`
- 观察到的进度: `42%`

## 7. Progress / Cache 观察

- 书架条目显示 `Last: 第一章 山村少年` 与 `Value: 42%`
- 详情页显示 `进度 42%` 与 `最后阅读 第一章 山村少年`
- 点击“继续阅读”后 ReaderView 回到已记录章节
- 设备端无法直接证明内部缓存实现细节，但 UI 行为与已记录进度一致

## 8. Safety / Scope

- 是否未修改源码: 是
- 是否未修改 Reader-Core: 是
- 是否未接 WebDAV/RSS/Sync: 是
- 是否无 parser internals 文案: 是

## 9. M3 状态更新

- M3-A Cache Store: `CODE_READY`
- M3-B Reading Progress: `CODE_READY`
- M3-C Continue Reading UI: `DEVICE_VERIFIED`
- M3 overall: `IOS_READING_CACHE_AND_PROGRESS_DEVICE_VERIFIED`

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. 是否建议进入 M4

建议进入 M4：书架与阅读资产整理，或多书源前的书架真实资产整理。
