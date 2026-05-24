# iOS App Shell Alignment Simulator Review

## 1. 总体结论

IOS_APP_SHELL_ALIGNMENT_SIMULATOR_REVIEW_READY

## 2. 本轮目标

本轮由 Codex 执行真实 Simulator GUI 校对，确认生产 App Shell 主底栏、搜索/设置/阅读归属、Debug Prototype Gallery 入口位置；本轮不修改 Swift 源码，不接真实数据，不做生产 UI 修复。

## 3. 输入状态

- 已读取：`docs/ui-handoff/ios/IOS_APP_SHELL_ALIGNMENT_REPORT.md`
- 已读取：`docs/ui-handoff/ios/IOS_APP_SHELL_ALIGNMENT_FIX_QUEUE.md`
- 已读取：`iOS/App/ReaderApp.swift`
- 已读取：`iOS/Features/Discover/DiscoverHomeShellView.swift`
- 已读取：`iOS/Features/Mine/MineTabView.swift`

## 4. 运行环境

- Xcode project：`ReaderForIOS.xcodeproj`
- Scheme：`ReaderForIOSApp`
- Simulator：`iPhone 17 Pro`
- Simulator UDID：`74B467A0-A02D-4D7B-9CE3-E10937B6A7DE`
- iOS Runtime：iOS 26.5
- 截图尺寸：1206 x 2622 px
- 实际运行方式：`xcodebuild` fresh build 成功后，通过 `simctl install` / `simctl launch` 启动，并使用 Simulator GUI 点击校对；同时打开 Xcode 项目供 GUI 环境确认。

## 5. 主底栏校对结果

- tab 数量：4
- tab 顺序：书架 / 发现 / 书源 / 我的
- tab 名称：均为中文目标名称
- 生产底栏未出现：Home / Bookshelf / Search / Settings / Reader / WebView Harness
- 四个 tab 均可点击，点击后页面正常显示，未发生崩溃。

## 6. 四个 Tab 校对结果

| Tab | 是否可点击 | 是否显示正确内容 | 是否发现问题 | 截图路径 |
|---|---|---|---|---|
| 书架 | 是 | 是，显示书架空态与 toolbar 搜索入口 | P2：页面标题/空态仍有英文文案 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/001_main_tabs_bookshelf.png` |
| 发现 | 是 | 是，显示搜索入口、推荐、分类、排行 shell | 无 P0/P1 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/002_main_tabs_discover.png` |
| 书源 | 是 | 是，显示书源空态与导入入口 | P2：页面标题/空态/按钮仍有英文文案 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/003_main_tabs_sources.png` |
| 我的 | 是 | 是，包含设置、WebDAV 备份、备份设置、同步进度、关于、Developer Tools | 无 P0/P1 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/004_main_tabs_mine.png` |

## 7. 搜索 / 设置 / 阅读归属校对

- 搜索是否不在底栏：是。搜索入口位于书架 toolbar 与发现页内容内。
- 设置是否不在底栏：是。设置入口位于“我的”tab 内。
- 阅读是否不在底栏：是。生产底栏未出现阅读 tab。

## 8. Debug / Developer Tools 校对

- `[DEBUG] Prototype Gallery` 是否在“我的 / Developer Tools”：是。
- 是否可进入 Gallery：是。
- Prototype entry 数量：38。
- 冒烟打开 entry：`App Shell / Main Tabs (4 tabs)`、`阅读页基础控制层`。
- WebView Harness 是否仅 Debug 区域可见：是，位于“我的 / Developer Tools”内，未作为正式底栏入口出现。
- Release 可见性：本轮未跑 Release GUI；代码报告与源码读取确认入口受 `#if DEBUG` 包裹。

## 9. Boundary / Safety 检查

- boundary 结果：PASS，checked_files=82，0 violations。
- 无真实网络/WebDAV/RSS/同步触发迹象。
- 未修改 Reader-Core。
- 未修改 Swift 源码。

## 10. 截图结果

| 序号 | 截图文件 |
|---:|---|
| 001 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/001_main_tabs_bookshelf.png` |
| 002 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/002_main_tabs_discover.png` |
| 003 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/003_main_tabs_sources.png` |
| 004 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/004_main_tabs_mine.png` |
| 005 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/005_mine_developer_tools.png` |
| 006 | `docs/ui-handoff/ios/screenshots/app-shell-alignment/006_debug_prototype_gallery_entry.png` |

## 11. Fix Queue 摘要

- P0 数量：0
- P1 数量：0
- P2 数量：1
- P3 数量：0
- fix queue 路径：`docs/ui-handoff/ios/IOS_APP_SHELL_ALIGNMENT_FIX_QUEUE.md`

## 12. P0 问题

无。

## 13. P1 问题

无。

## 14. 是否建议进入下一阶段

P0/P1 为 0，建议进入生产 App Shell 视觉细化或真实数据接入规划阶段。当前仅有 P2 文案本地化问题，可在视觉细化阶段处理。

## 15. 命令验证结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 工作区存在既有未提交/未跟踪文件；本轮不 reset、不 stash、不清理。 |
| `git branch --show-current` | `main` |
| `git log --oneline -n 5` | 最新提交为 `768546f feat: align iOS app shell main tabs` |
| `bash scripts/check_ios_boundary.sh` | PASS，checked_files=82，0 violations |
| `xcodebuild -project "ReaderForIOS.xcodeproj" -scheme "ReaderForIOSApp" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` | BUILD SUCCEEDED |
| `xcrun simctl install` / `xcrun simctl launch` | App 启动成功 |

clean-room 结论：本轮仅做 GUI 校对、截图和 Markdown 记录；无外部 GPL 代码搬运。
