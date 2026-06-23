# iOS M1 Single Source Search Device Review

## 1. 总体结论

IOS_M1_SINGLE_SOURCE_SEARCH_DEVICE_REVIEW_READY

## 2. 本轮目标

本轮只做 M1.5 设备端验证，不修改源码，不做 Detail/TOC/Content。

## 3. 输入状态

- `docs/ui-handoff/ios/IOS_M1_2_CONTROLLED_ONLINE_REAL_SEARCH_SERVICE_REPORT.md`
- `docs/ui-handoff/ios/IOS_M1_3_SEARCH_SNAPSHOT_STORE_REPORT.md`
- `docs/ui-handoff/ios/IOS_M1_4_SEARCH_UI_CONTROLLED_RESULTS_REPORT.md`
- `docs/ui-handoff/ios/MILESTONE_STATUS.md`

## 4. 运行环境

- Xcode project: `ReaderForIOS.xcodeproj`
- Scheme: `ReaderForIOSApp`
- Simulator: `iPhone 17 Pro`
- iOS Runtime: `iOS 26.5`
- 启动方式: `xcodebuild build` 后 `simctl uninstall/install/launch` fresh install
- 截图尺寸: `393 x 852 pt`

## 5. Search 入口验证

- 从书架页右上角搜索按钮进入 Search
- Search 页面可见
- 默认书源初始显示为 `None`，但可通过下拉选择切换到 `⭐ 星星小说网`

## 6. Search 查询验证

- query: `凡人`
- 可执行搜索：是
- 搜索后出现结果列表：是

## 7. Search Results UI 验证

- 结果数量: 3
- 结果行显示 `title / author / sourceName`：是
- 结果条目：
  - `凡人修仙传` / `忘语` / `⭐ 星星小说网`
  - `仙逆` / `耳根` / `⭐ 星星小说网`
  - `一念永恒` / `耳根` / `⭐ 星星小说网`

截图路径：
- `docs/ui-handoff/ios/screenshots/m1-single-source-search-device-review/001_app_shell.png`
- `docs/ui-handoff/ios/screenshots/m1-single-source-search-device-review/002_search_entry.png`
- `docs/ui-handoff/ios/screenshots/m1-single-source-search-device-review/003_search_page_before_query.png`
- `docs/ui-handoff/ios/screenshots/m1-single-source-search-device-review/004_search_query_input.png`
- `docs/ui-handoff/ios/screenshots/m1-single-source-search-device-review/005_search_results_list.png`

## 8. Safety / Scope

- 是否未修改源码：是
- 是否未修改 Reader-Core：是
- 是否未做 Detail/TOC/Content：是
- 是否未接 WebDAV/RSS/Sync：是
- 是否无 parser internals 文案：是

## 9. M1 状态更新

- M1.1：CODE_READY
- M1.2：CODE_READY
- M1.3：CODE_READY
- M1.4：CODE_READY
- M1.5：DEVICE_VERIFIED
- M1 overall：`M1_SINGLE_SOURCE_SEARCH_MVP_DEVICE_VERIFIED`

## 10. P0 问题

无

## 11. P1 问题

无

## 12. 是否建议进入 M2

建议进入 M2：单书源 Detail / TOC / Content 真实阅读闭环。
