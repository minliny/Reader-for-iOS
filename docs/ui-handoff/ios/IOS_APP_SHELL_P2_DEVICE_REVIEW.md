# iOS App Shell P2 Device Review

## 1. 总体结论

IOS_APP_SHELL_P2_DEVICE_REVIEW_READY

## 2. 本轮目标

本轮只复测英文文案和 ReaderView Fixture，不修改 Swift 源码，不修改 Reader-Core，不接真实数据，不修 UI。

## 3. 输入状态

- 已读取：`docs/ui-handoff/ios/IOS_APP_SHELL_P2_CLEANUP_REPORT.md`
- 已读取：`docs/ui-handoff/ios/IOS_APP_SHELL_ALIGNMENT_FIX_QUEUE.md`
- 已读取：`docs/ui-handoff/ios/IOS_READER_BRIGHTNESS_LAYOUT_DEVICE_REVIEW.md`
- 已读取：`iOS/Features/Bookshelf/BookshelfView.swift`
- 已读取：`iOS/Features/BookSources/BookSourceListView.swift`
- 已读取：`iOS/Features/Mine/MineTabView.swift`
- 已读取：`iOS/Features/Reader/ReaderView.swift`
- 已读取：`iOS/Features/Reader/ReaderViewModel.swift`

## 4. 运行环境

- Xcode project：`ReaderForIOS.xcodeproj`
- Scheme：`ReaderForIOSApp`
- Simulator：`iPhone 17 Pro`
- Simulator UDID：`74B467A0-A02D-4D7B-9CE3-E10937B6A7DE`
- iOS Runtime：iOS 26.5
- 截图尺寸：1206 x 2622 px
- 实际运行方式：`xcodebuild` fresh build 成功后，通过 `simctl install` / `simctl launch` 启动，并使用 Simulator GUI 点击复测。

## 5. 英文文案复测结果

- 书架页面是否仍有英文文案：否。标题为“书架”，空态为“书架为空 / 从搜索结果添加书籍”。
- 书源页面是否仍有英文文案：否。标题为“书源”，空态为“暂无书源 / 导入书源以开始使用”，按钮为“导入书源”。
- 是否只有 Debug 技术文案保留：是。`[DEBUG] Prototype Gallery`、`WebView Harness`、`[DEBUG] ReaderView Fixture` 仅位于 Developer Tools 区域。

| 页面 | 截图路径 |
|---|---|
| 书架中文文案 | `docs/ui-handoff/ios/screenshots/app-shell-p2-device-review/001_bookshelf_chinese_copy.png` |
| 书源中文文案 | `docs/ui-handoff/ios/screenshots/app-shell-p2-device-review/002_book_sources_chinese_copy.png` |

## 6. ReaderView Fixture 复测结果

- 入口是否可见：是，位于“我的 / Developer Tools / [DEBUG] ReaderView Fixture”。
- 是否进入真实 ReaderView：是，进入后显示 `ReaderView` 阅读页面、章节标题、阅读进度、正文、Reader toolbar。
- 是否 fixture-only：是，正文为本地 fixture 内容。
- 是否无真实网络：是，不需要搜索结果、书源或真实书架数据。
- 是否隐藏主底栏：是，ReaderView 页面未显示 `书架 / 发现 / 书源 / 我的`。
- 返回后主底栏是否恢复：是，返回“我的”后主底栏恢复。
- Reader 页面是否仍显示正文和基础阅读信息：是。

| 页面 | 截图路径 |
|---|---|
| Developer Tools Reader Fixture 入口 | `docs/ui-handoff/ios/screenshots/app-shell-p2-device-review/003_mine_developer_tools_reader_fixture.png` |
| ReaderView Fixture 打开 | `docs/ui-handoff/ios/screenshots/app-shell-p2-device-review/004_reader_view_fixture_opened.png` |
| ReaderView Fixture 隐藏主底栏 | `docs/ui-handoff/ios/screenshots/app-shell-p2-device-review/005_reader_view_fixture_tabbar_hidden.png` |
| 返回后主底栏恢复 | `docs/ui-handoff/ios/screenshots/app-shell-p2-device-review/006_reader_view_fixture_return_restores_tabs.png` |

## 7. Debug Prototype Gallery 冒烟结果

- 是否可进入：是。
- entry 数量是否为 38：是。

## 8. Boundary / Safety 检查

- boundary 结果：PASS，checked_files=82，0 violations。
- 是否未修改 Swift 源码：是，本轮未修改 Swift。
- 是否未修改 Reader-Core：是。
- 是否无真实网络/WebDAV/RSS/同步：是，复测仅使用生产 shell、debug fixture 与 prototype 页面。

## 9. Fix Queue 更新

- `APP-SHELL-SIM-P2-001` 状态：`DEVICE_VERIFIED_RESOLVED`。
- `APP-SHELL-SIM-P2-002` 状态：`DEVICE_VERIFIED_RESOLVED`。
- `APP-SHELL-P1-001` 状态：`DEVICE_VERIFIED_RESOLVED`。
- `READER-P1-002` 状态：保持 `DEVICE_VERIFIED_RESOLVED`。

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. P2 问题

无。

## 13. 是否建议收口

P0/P1/P2 全部为 0，建议进入 iOS App Shell / Prototype / Reader control 阶段收口。

## 14. 命令验证结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 工作区存在既有未提交/未跟踪文件；本轮不 reset、不 stash、不清理。 |
| `git branch --show-current` | `main` |
| `git log --oneline -n 5` | 最新提交为 `8e766d9 fix: add iOS reader fixture path and polish shell copy` |
| `bash scripts/check_ios_boundary.sh` | PASS，checked_files=82，0 violations |
| `xcodebuild -project "ReaderForIOS.xcodeproj" -scheme "ReaderForIOSApp" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` | BUILD SUCCEEDED |
| `xcrun simctl install` / `xcrun simctl launch` | App 启动成功 |

clean-room 结论：本轮仅做 GUI 复测、截图和 Markdown 记录；无外部 GPL 代码搬运。
