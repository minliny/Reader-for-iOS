# iOS Product Experience Polish M7 Device Review

## 1. 总体结论

IOS_PRODUCT_EXPERIENCE_POLISH_M7_DEVICE_REVIEW_READY

## 2. 本轮目标

本轮只做 M7 设备端体验校验，不修改 Swift 源码，不修改 Reader-Core，不修 UI，不接 WebDAV/RSS/Sync。

## 3. 输入状态

已读取：
- [IOS_PRODUCT_EXPERIENCE_POLISH_M7_REPORT.md](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_PRODUCT_EXPERIENCE_POLISH_M7_REPORT.md)
- [IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_DEVICE_REVIEW.md](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_DEVICE_REVIEW.md)
- [MILESTONE_STATUS.md](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/MILESTONE_STATUS.md)
- `iOS/Features/BookSources/BookSourceDetailSheet.swift`
- `iOS/Features/Mine/M6BookSourceImportVerificationView.swift`
- `iOS/Features/Mine/MineTabView.swift`

## 4. 运行环境

- Xcode project: `ReaderForIOS.xcodeproj`
- Scheme: `ReaderForIOSApp`
- Simulator: `iPhone 17 Pro`
- iOS Runtime: `iOS 26.5`
- Bundle ID: `com.reader.ios`
- 启动方式: `xcodebuild` fresh build + `simctl uninstall/install/launch`
- App path: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/Debug-iphonesimulator/ReaderForIOSApp.app`
- 截图尺寸: `1320 x 2868`

## 5. 书源详情体验验证

- 进入路径: 书源 Tab -> 本地导入的 `星星小说网` -> 详情 sheet
- 本地导入标签: 可见，显示 `本地导入`
- capability 详情: 可见
- search/detail/toc/content 状态: 可见，`search=ready`，`detail/toc/content=missing`
- hint 文案: 可见，显示 `支持搜索`、`详情功能不可用`、`目录功能不可用`、`正文功能不可用`
- 手动测试入口: 可见，显示 `本地模拟测试`
- 用户理解性: 通过，不再只有技术字段；正式书源详情以中文状态和 hint 解释能力边界

截图路径：
- [002_booksource_tab.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m7-product-experience-polish-device-review/002_booksource_tab.png)
- [003_imported_source_detail.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m7-product-experience-polish-device-review/003_imported_source_detail.png)
- [004_local_import_badge.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m7-product-experience-polish-device-review/004_local_import_badge.png)
- [005_capability_hint.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m7-product-experience-polish-device-review/005_capability_hint.png)

## 6. 网络策略提示验证

- 是否触发手动测试: 是，在 Debug harness 中点击 `测试搜索（controlledOnline）`
- 是否显示友好文案: 是，显示 `网络访问未启用（受 NetworkAccessController 控制）`
- 是否有行动提示: 是，显示 `提示：需要在设置中开启受控联网以执行真实搜索`
- 是否仍裸露技术错误: 否，未再显示裸露的 `NetworkAccessController denied`
- 是否自动联网: 否，只有手动点击后才出现受控联网测试反馈

截图路径：
- [006_manual_test_entry.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m7-product-experience-polish-device-review/006_manual_test_entry.png)
- [007_m6_debug_harness.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m7-product-experience-polish-device-review/007_m6_debug_harness.png)
- [008_manual_test_friendly_error.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m7-product-experience-polish-device-review/008_manual_test_friendly_error.png)

## 7. Debug-only 边界验证

- Debug harness 是否只在 Developer Tools: 是
- 正式书源页面是否无验证入口: 是，正式书源 Tab 未显示 `[验证]` 类 Debug 入口
- `#if DEBUG` 边界是否保持: 代码侧入口位于 `MineTabView` Developer Tools，设备端也仅在“我的 / Developer Tools”可见

截图路径：
- [001_app_shell.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m7-product-experience-polish-device-review/001_app_shell.png)
- [009_debug_tools_boundary.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m7-product-experience-polish-device-review/009_debug_tools_boundary.png)

## 8. Safety / Scope

- 是否未修改源码: 是
- 是否未修改 Reader-Core: 是
- 是否未接 WebDAV/RSS/Sync: 是
- 是否无 parser internals 文案: 是
- 是否无外部 GPL 代码搬运: 是。本轮仅做设备端观察、截图与报告记录，clean-room 边界保持。

## 9. M7 状态更新

- M7-A Import Experience: `DEVICE_VERIFIED`
- M7-B Network Policy Messaging: `DEVICE_VERIFIED`
- M7-C Search/Bookshelf/Reader Feedback: `DEVICE_VERIFIED`
- M7-D Debug Tools Boundary: `DEVICE_VERIFIED`
- M7-E Bookmark P2 Follow-up: `DEFERRED`
- M7-F Device Review: `DEVICE_VERIFIED`
- M7 overall: `IOS_PRODUCT_EXPERIENCE_POLISH_M7_DEVICE_VERIFIED`

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. 是否建议进入 M8

建议进入 M8。M8 方向需要产品决策：
- A. 多书源聚合搜索
- B. WebDAV/RSS/Sync
- C. 继续打磨单源阅读体验
