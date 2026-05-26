# iOS Pending Device Reviews Report

## 1. 总体结论

IOS_PENDING_DEVICE_REVIEWS_BLOCKED

## 2. 本轮目标

本轮由 Codex 复测 Phase 1 P2 和 Phase 2 书源管理，不修改源码，不修改 Reader-Core，不接真实网络，不 push。

## 3. 输入状态

- 已读取：`docs/ui-handoff/ios/IOS_READERCORE_FACADE_BOUNDARY_PHASE3_REPORT.md`
- 已读取：`docs/ui-handoff/ios/IOS_MOCK_DATA_FLOW_PHASE1_CODE_READY_REPORT.md`
- 已读取：`docs/ui-handoff/ios/IOS_MOCK_DATA_FLOW_PHASE1_DETAIL_P2_REPORT.md`
- 已读取：`docs/ui-handoff/ios/IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_REPORT.md`
- 已读取：`docs/ui-handoff/ios/IOS_MOCK_DATA_FLOW_PHASE1_FIX_QUEUE.md`
- 已读取：`docs/ui-handoff/ios/IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_FIX_QUEUE.md`

## 4. 运行环境

- Xcode project：`ReaderForIOS.xcodeproj`
- Scheme：`ReaderForIOSApp`
- Simulator：`iPhone 17 Pro`
- Simulator UDID：`74B467A0-A02D-4D7B-9CE3-E10937B6A7DE`
- iOS Runtime：iOS 26.5
- 截图尺寸：1206 x 2622 px
- 实际运行方式：`xcodebuild` fresh build 成功后，通过 `simctl install` / `simctl launch` 启动，并使用 Simulator GUI 复测。

## 5. Mock Flow Detail P2 复测结果

- Book Detail 是否显示简介：是。
- 是否显示来源：是，`来源：Mock 书源`。
- 是否显示最新章节：是，`最新章节：第一章 山村少年`。
- 是否显示开始阅读：是，点击后进入 ReaderView 第一章。
- 是否显示查看目录：是，`查看目录（5 章）` 可打开 TOC sheet。
- 开始阅读是否进入 ReaderView：是。
- 查看目录是否进入 TOC：是，TOC 显示 5 章。
- TOC 点击章节是否进入 ReaderView：是。
- ReaderView 是否隐藏主底栏：是。
- 返回后主底栏是否恢复：是。

| 截图 | 路径 |
|---|---|
| Book Detail 完整信息 | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1-p2-review/001_book_detail_full_info.png` |
| 开始阅读入口 | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1-p2-review/002_book_detail_start_reading_entry.png` |
| 开始阅读进入 ReaderView | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1-p2-review/003_reader_from_start_reading.png` |
| 查看目录入口 | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1-p2-review/004_book_detail_toc_entry.png` |
| TOC 5 章 | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1-p2-review/005_toc_from_detail.png` |
| TOC 第一章进入 ReaderView | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1-p2-review/006_reader_from_toc.png` |
| 返回后主底栏恢复 | `docs/ui-handoff/ios/screenshots/mock-data-flow-phase1-p2-review/007_return_restores_main_tabs.png` |

结论：`MOCK-FLOW-P2-001` 设备端通过，标记 `DEVICE_VERIFIED_RESOLVED`。

## 6. BookSource Phase 2 复测结果

- fixture 列表是否可见：是。设备端在书源列表中看到 5 个 fixture 书源：
  - `笔趣阁`
  - `全本书屋`
  - `千帆小说`
  - `起点中文`
  - `本地书源示例`
- 5 个书源是否可见：是。
- 启用/禁用是否可操作：未观察到可确认的状态变化，仍需复核。
- 详情是否可打开：是，sheet 可打开且详情内容可见。
- 本地模拟测试是否可触发且无网络：是，出现 `测试中...` 后进入成功态，且页面说明为离线 fixture 模式。
- 导入模拟入口是否可见：是。
- 导入页面是否中文文案：是，已确认中文文案。
- 是否无 parser internals：是，未观察到 parser internals 文案。
- 是否无真实网络：未观察到真实网络请求、账号、token、WebDAV/RSS/Sync 行为。

| 截图 | 路径 |
|---|---|
| 书源列表 5 个 fixture | `docs/ui-handoff/ios/screenshots/booksource-local-management-phase2/001_booksource_list_5_fixtures_interaction_fix.png` |
| 详情 sheet 可见 | `docs/ui-handoff/ios/screenshots/booksource-local-management-phase2/004_booksource_detail_sheet_visible.png` |
| 本地模拟测试成功态 | `docs/ui-handoff/ios/screenshots/booksource-local-management-phase2/005_booksource_local_test_success.png` |
| 导入书源页面 | `docs/ui-handoff/ios/screenshots/booksource-local-management-phase2/006_booksource_import_entry_after_fix.png` |

结论：BookSource local management Phase 2 仅剩开关状态切换待复核，当前新增 1 个 P1。

## 7. Boundary / Safety 检查

- boundary 结果：PASS，checked_files=86，0 violations。
- 是否未修改 Swift 源码：是，本轮未修改 Swift。
- 是否未修改 Reader-Core：是。
- 是否无真实网络/WebDAV/RSS/Sync：是，未观察到真实网络、WebDAV、RSS、Sync、账号或 token 行为。
- clean-room：PASS，无外部 GPL 代码搬运。

## 8. Fix Queue 更新

- `MOCK-FLOW-P2-001` 状态：DEVICE_VERIFIED_RESOLVED。
- Phase 2 BookSource device review 状态：DEVICE_REVIEW_BLOCKED。
- P0 数量：0
- P1 数量：1
- P2 数量：0
- P3 数量：0

## 9. P0 问题

无。

## 10. P1 问题

| Issue ID | 问题 |
|---|---|
| BOOKSOURCE-P2-P1-004 | 启用/禁用开关未观察到状态切换。 |

## 11. P2 问题

无。

## 12. 是否建议收口

不建议进入 Phase 1/2/3 统一收口。Phase 1 Detail P2 与 BookSource 详情 / 本地测试已设备端解决；Phase 2 仍有开关状态切换待复核，应先交回 Claude Code 继续处理或补充证据。

## 13. 命令验证结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 工作区存在既有未提交/未跟踪文件；本轮不 reset、不 stash、不清理、不 push。 |
| `git branch --show-current` | `main` |
| `git log --oneline -n 8` | 最新提交为 `f31fbd3 test: harden iOS ReaderCore facade boundaries` |
| `bash scripts/check_ios_boundary.sh` | PASS，checked_files=86，0 violations |
| `xcodebuild -project "ReaderForIOS.xcodeproj" -scheme "ReaderForIOSApp" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` | BUILD SUCCEEDED |
| `xcrun simctl install` / `xcrun simctl launch` | App 启动成功 |

clean-room 结论：本轮仅做 GUI 复测、截图和 Markdown 记录；无外部 GPL 代码搬运。
