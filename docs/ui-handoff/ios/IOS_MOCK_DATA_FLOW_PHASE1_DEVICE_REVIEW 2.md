# iOS Mock Data Flow Phase 1 Device Review

## 1. 总体结论

IOS_MOCK_DATA_FLOW_PHASE1_DEVICE_REVIEW_BLOCKED

## 2. 本轮目标

本轮只复测 Search → Detail → TOC → ReaderView mock data flow，不修改源码，不接真实网络。

## 3. 输入状态

- 已读取：`docs/ui-handoff/ios/IOS_MOCK_DATA_FLOW_PHASE1_REPORT.md`
- 已读取：`docs/ui-handoff/ios/IOS_MOCK_DATA_FLOW_PHASE1_FIX_QUEUE.md`
- 已读取：`iOS/Features/Search/SearchViewModel.swift`
- 已读取：`iOS/Features/Search/SearchView.swift`
- 已读取：`iOS/Features/ChapterList/ChapterListView.swift`
- 已读取：`iOS/Tests/ReaderAppTests/MockDataFlowTests.swift`

## 4. 运行环境

- Xcode project：`ReaderForIOS.xcodeproj`
- Scheme：`ReaderForIOSApp`
- Simulator：`iPhone 17 Pro`
- Simulator UDID：`74B467A0-A02D-4D7B-9CE3-E10937B6A7DE`
- iOS Runtime：iOS 26.5
- 截图尺寸：1206 x 2622 px
- 实际运行方式：`xcodebuild` fresh build 成功后，通过 `simctl install` / `simctl launch` 启动，并使用 Simulator GUI 从书架搜索入口复测。

## 5. Search 复测结果

- 入口来源：书架 toolbar 搜索入口。
- query：`Changyeyuhuo`（由 `长夜余火` 拼音输入，mock provider 不依赖真实网络查询）。
- 是否出现 3 个 mock results：是，显示 `凡人修仙传`、`仙逆`、`一念永恒`。
- 是否不要求真实 BookSource：是，Book Source 显示 `None` 时仍返回 mock results。
- 是否无真实网络错误：是，未出现真实网络错误或 `No book source selected`。

| 截图 | 路径 |
|---|---|
| 搜索入口 | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1/001_search_entry_from_bookshelf.png` |
| 3 个 mock results | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1/002_search_mock_results.png` |

## 6. Detail 复测结果

- 是否可从 Search result 进入：否。
- 观察结果：点击第一个结果后进入空白页面，仅保留返回按钮和主底栏；等待超过 2 秒仍未显示 Book Detail。
- 是否显示 mock detail：否。
- 是否有开始阅读 / 目录入口：否。
- 阻塞等级：P1。

| 截图 | 路径 |
|---|---|
| Detail 空白阻塞 | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1/900_mock_flow_blocked_detail_blank.png` |

## 7. TOC 复测结果

- 是否显示 5 章：未能复测。
- 原因：Search → Detail 阶段空白，无法进入 TOC。
- 章节点击是否可进入 ReaderView：未能复测。

## 8. ReaderView 复测结果

- 是否显示“第一章 山村少年”：未能复测。
- 是否显示 mock 正文：未能复测。
- 是否隐藏主底栏：未能通过本轮 mock flow 复测。
- 返回后主底栏是否恢复：从空白页返回后主底栏恢复。

## 9. Boundary / Safety 检查

- boundary 结果：PASS，checked_files=83，0 violations。
- 是否未修改 Swift 源码：是，本轮未修改 Swift。
- 是否未修改 Reader-Core：是。
- 是否无真实网络/WebDAV/RSS/Sync：是，复测仅触发 mock UI path，未观察到真实网络错误或账号/同步行为。

## 10. Fix Queue 更新

- P0 数量：0
- P1 数量：1
- P2 数量：0
- P3 数量：0
- fix queue 路径：`docs/ui-handoff/ios/IOS_MOCK_DATA_FLOW_PHASE1_FIX_QUEUE.md`

## 11. P0 问题

无。

## 12. P1 问题

| Issue ID | 问题 |
|---|---|
| MOCK-FLOW-P1-001 | Search mock results 可出现，但点击结果后 Book Detail 为空白，阻断 TOC 与 ReaderView。 |

## 13. P2 问题

无。

## 14. 是否建议收口

不建议收口。需先修复 `MOCK-FLOW-P1-001`，再重新执行 Search → Detail → TOC → ReaderView 设备端复测。

## 15. 命令验证结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 工作区存在既有未提交/未跟踪文件；本轮不 reset、不 stash、不清理。 |
| `git branch --show-current` | `main` |
| `git log --oneline -n 5` | 最新提交为 `0457619 feat: add iOS mock reader data flow` |
| `bash scripts/check_ios_boundary.sh` | PASS，checked_files=83，0 violations |
| `xcodebuild -project "ReaderForIOS.xcodeproj" -scheme "ReaderForIOSApp" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` | BUILD SUCCEEDED |
| `xcrun simctl install` / `xcrun simctl launch` | App 启动成功 |

clean-room 结论：本轮仅做 GUI 复测、截图和 Markdown 记录；无外部 GPL 代码搬运。
