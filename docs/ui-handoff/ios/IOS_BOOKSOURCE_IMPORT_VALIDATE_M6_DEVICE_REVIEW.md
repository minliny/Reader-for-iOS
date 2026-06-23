# iOS BookSource Import and Validate M6 Device Review

## 1. 总体结论

IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_DEVICE_REVIEW_READY

## 2. 本轮目标

本轮通过 Debug-only verification harness 复测 M6 导入、校验、保存、导入源详情与手动测试入口链路；不修改 Swift 源码，不修改 Reader-Core，不修 UI，不接 WebDAV/RSS/Sync。

## 3. 输入状态

已读取：
- [IOS_M6_HARNESS_JSON_INPUT_FIX_REPORT.md](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_M6_HARNESS_JSON_INPUT_FIX_REPORT.md)
- [IOS_M6_DEVICE_REVIEW_AUTOMATION_READY_REPORT.md](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_M6_DEVICE_REVIEW_AUTOMATION_READY_REPORT.md)
- [IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_DEVICE_REVIEW.md](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/IOS_BOOKSOURCE_IMPORT_VALIDATE_M6_DEVICE_REVIEW.md)
- [MILESTONE_STATUS.md](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/MILESTONE_STATUS.md)
- `iOS/Features/Mine/M6BookSourceImportVerificationView.swift`
- `iOS/Features/Mine/MineTabView.swift`
- `iOS/AppSupport/Sources/xingxingxsw.search-only.json`

## 4. 运行环境

- Xcode project: `ReaderForIOS.xcodeproj`
- Scheme: `ReaderForIOSApp`
- Simulator: `iPhone 17 Pro`
- iOS Runtime: `iOS 26.5`
- Bundle ID: `com.reader.ios`
- 启动方式: `xcodebuild` fresh build + `simctl uninstall/install/launch`
- App path: `/Users/minliny/Library/Developer/Xcode/DerivedData/ReaderForIOS-bgqxngblwfowatgnunsccnabgetr/Build/Products/Debug-iphonesimulator/ReaderForIOSApp.app`
- 截图尺寸: Simulator full device screenshot

## 5. Debug Harness 入口验证

- App 是否启动成功: 是
- 我的 Tab 是否可进入: 是
- Developer Tools 是否可见: 是
- `[验证] M6 书源导入链路` 是否可见: 是
- M6 verification view 是否可进入: 是
- 执行按钮是否可点击: 是

截图路径：
- [001_app_shell.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/001_app_shell.png)
- [002_mine_developer_tools.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/002_mine_developer_tools.png)
- [003_m6_verification_entry.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/003_m6_verification_entry.png)
- [004_m6_verification_view_initial.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/004_m6_verification_view_initial.png)

## 6. 自动步骤验证

| Step | 设备端状态 | 备注 |
|---|---|---|
| bundled JSON load | PASS | `1. 查找 bundled xingxingxsw JSON` 绿色 |
| JSON source | PASS | `bundled: xingxingxsw.search-only.json (root)` |
| JSON text -> Data | PASS | `1b. JSON text → Data 编码` 绿色 |
| JSON parse / Decode | PASS | `3. Decode BookSource` 绿色 |
| normalize | PASS | `2. Normalize (object rules + header)` 绿色 |
| object-shaped rule compatibility | PASS | object-shaped `ruleSearch/ruleToc/ruleContent` 不再阻塞导入 |
| header compatibility | PASS | header string/object 兼容路径未阻塞 normalize/decode |
| local validation | PASS | `4e. validation errors = 0` |
| capability | PASS | search `ready`; detail/toc/content `missing` |
| save imported source | PASS | `BookSourceStore` 中出现导入源 |
| reload/list | PASS | reload 后列表包含导入源 |
| imported source distinguishable | PASS | 导入源无 `⭐` 前缀，可与预置源区分 |
| imported source detail path | PASS | 生产书源列表中导入源详情 sheet 可打开 |
| manual test entry | PASS | `测试搜索（controlledOnline）` 可见 |

截图路径：
- [005_m6_verification_running.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/005_m6_verification_running.png)
- [006_m6_verification_steps_passed.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/006_m6_verification_steps_passed.png)
- [007_m6_bundled_json_step.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/007_m6_bundled_json_step.png)
- [008_m6_imported_source_list_step.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/008_m6_imported_source_list_step.png)
- [009_source_detail.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/009_source_detail.png)
- [010_m6_manual_test_entry.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/010_m6_manual_test_entry.png)
- [012_enable_disable_state.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/012_enable_disable_state.png)

## 7. 手动搜索测试验证

- 是否点击: 是
- 是否只手动触发: 是，入口为独立按钮 `测试搜索（controlledOnline）`
- 搜索测试结果: 显示明确错误 `无法创建 real services（NetworkAccessController denied）`
- resultCount / error: `NetworkAccessController denied`
- 是否显示 source health: 显示手动测试反馈；未出现自动批量测试

该结果确认手动测试入口可见且可触发；本次环境下受 `NetworkAccessController` 控制而拒绝 real service 创建，未作为 M6 导入/校验链路阻塞。

截图路径：
- [011_m6_manual_search_result.png](/Users/minliny/Documents/Reader%20for%20iOS/docs/ui-handoff/ios/screenshots/m6-booksource-import-validate-device-review/011_m6_manual_search_result.png)

## 8. Safety / Scope

- 是否未修改源码: 是
- 是否未修改 Reader-Core: 是
- 导入/校验是否不自动联网: 是
- 是否未接 WebDAV/RSS/Sync: 是
- 是否无 parser internals 文案: 是
- Debug harness 是否 `#if DEBUG`: 是，`MineTabView` 中入口位于 `#if DEBUG`，`M6BookSourceImportVerificationView.swift` 也由 `#if DEBUG` 包裹。
- Clean-room 结论: 本轮仅基于仓库内 Debug harness、设备端 UI 结果、项目报告和 public app behavior 记录，无外部 GPL 代码搬运。

## 9. M6 状态更新

- M6-P1-001: `DEVICE_VERIFIED_RESOLVED`
- M6-P1-002: `DEVICE_VERIFIED_RESOLVED`
- M6-P1-003: `DEVICE_VERIFIED_RESOLVED`
- M6-HARNESS-P1-004: `DEVICE_VERIFIED_RESOLVED`
- M6-A Import JSON: `DEVICE_VERIFIED`
- M6-B Local Validation: `DEVICE_VERIFIED`
- M6-C Save Local Source: `DEVICE_VERIFIED`
- M6-D Manual Test Entry: `DEVICE_VERIFIED`
- M6-E Device Review: `DEVICE_VERIFIED`
- M6 overall: `IOS_BOOKSOURCE_IMPORT_AND_VALIDATE_M6_DEVICE_VERIFIED`

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. 是否建议进入 M7

建议进入 M7：产品体验打磨，优先优化真实书源导入后的搜索、书架、阅读体验。
