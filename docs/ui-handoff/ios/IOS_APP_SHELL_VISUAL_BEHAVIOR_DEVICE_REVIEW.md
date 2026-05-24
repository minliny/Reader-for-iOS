# iOS App Shell Visual Behavior Device Review

## 1. 总体结论

IOS_APP_SHELL_VISUAL_BEHAVIOR_DEVICE_REVIEW_READY

## 2. 本轮目标

本轮由 Codex 执行真实 iOS Simulator GUI 复测，确认生产主底栏、Debug Prototype Gallery、Reader 控制层亮度条修复结果；本轮不修改 Swift 源码，不修改 Reader-Core，不接真实数据，不修 UI。

## 3. 输入状态

- 已读取：`docs/ui-handoff/ios/IOS_APP_SHELL_VISUAL_BEHAVIOR_FIX_REPORT.md`
- 已读取：`docs/ui-handoff/ios/IOS_APP_SHELL_ALIGNMENT_FIX_QUEUE.md`
- 已读取：`docs/ui-handoff/ios/IOS_APP_SHELL_ALIGNMENT_SIMULATOR_REVIEW.md`
- 已读取：`iOS/Features/Reader/ReaderView.swift`
- 已读取：`iOS/Modules/Prototype/PrototypeGalleryView.swift`

## 4. 运行环境

- Xcode project：`ReaderForIOS.xcodeproj`
- Scheme：`ReaderForIOSApp`
- Simulator：`iPhone 17 Pro`
- Simulator UDID：`74B467A0-A02D-4D7B-9CE3-E10937B6A7DE`
- iOS Runtime：iOS 26.5
- 截图尺寸：1206 x 2622 px
- 实际运行方式：`xcodebuild` fresh build 成功后，通过 `simctl install` / `simctl launch` 启动，并使用 Simulator GUI 点击复测。

## 5. 生产主底栏复测结果

- tab 数量：4
- tab 名称：书架 / 发现 / 书源 / 我的
- tab 顺序：书架 / 发现 / 书源 / 我的
- 搜索是否不在底栏：是，搜索入口位于书架 toolbar 与发现页内容内。
- 设置是否不在底栏：是，设置入口位于“我的”内。
- 阅读是否不在底栏：是。
- WebView Harness 是否不是正式底栏：是，仅在 Debug Developer Tools 区域可见。

| 页面 | 截图路径 |
|---|---|
| 书架 | `docs/ui-handoff/ios/screenshots/app-shell-visual-behavior/001_main_tabs_bookshelf_after_fix.png` |
| 发现 | `docs/ui-handoff/ios/screenshots/app-shell-visual-behavior/002_main_tabs_discover_after_fix.png` |
| 书源 | `docs/ui-handoff/ios/screenshots/app-shell-visual-behavior/003_main_tabs_sources_after_fix.png` |
| 我的 | `docs/ui-handoff/ios/screenshots/app-shell-visual-behavior/004_main_tabs_mine_after_fix.png` |

## 6. 阅读页主导航泄漏复测结果

- 是否能进入生产 ReaderView：否。
- 原因：生产书架为空；通过书架 toolbar 搜索进入 Search 后，Book Source 为 `None`，搜索触发 `No book source selected`，没有可用生产 UI 路径进入 Book Detail / TOC / ReaderView。
- 是否判 P0：否。
- 是否判 P1 REOPENED：否；未观察到生产 ReaderView 中主导航泄漏。
- 替代验证路径：进入“我的 / Developer Tools / [DEBUG] Prototype Gallery / Reader Base Controls”复测 Reader 控制层视觉行为。
- Prototype Reader Base 观察：作为 Gallery 内部页面时仍嵌套在主 TabView 下，因此底部生产 tab bar 仍可见；该现象与生产 ReaderView `.toolbar(.hidden, for: .tabBar)` 设备端验证不同，记录为 P2 后续复测项。
- 返回 App Shell 后主底栏是否恢复：是，主底栏在 App Shell 中正常可见。

| 复测项 | 截图路径 |
|---|---|
| Prototype Reader Base 上下文 | `docs/ui-handoff/ios/screenshots/app-shell-visual-behavior/005_prototype_reader_base_main_tabs_context.png` |

## 7. 亮度条复测结果

- 亮度条是否仍全屏：否。
- 当前尺寸/位置观察：亮度条位于阅读区域左侧，为局部垂直 overlay；视觉宽度约 40pt，滑轨高度受限，没有铺满全屏。
- 是否阻塞阅读内容：否，正文、顶部控制、底部控制仍可见。
- 是否出现全屏 VStack 背景覆盖：否。
- READER-P1-002 状态：DEVICE_VERIFIED_RESOLVED。

| 复测项 | 截图路径 |
|---|---|
| 亮度条修复 | `docs/ui-handoff/ios/screenshots/app-shell-visual-behavior/007_reader_brightness_overlay_fixed.png` |
| 亮度条上下文 | `docs/ui-handoff/ios/screenshots/app-shell-visual-behavior/008_reader_brightness_overlay_context.png` |

## 8. Debug Prototype Gallery 复测结果

- 入口是否可见：是，位于“我的 / Developer Tools”。
- 是否可进入：是。
- entry 数量：38。
- Reader Base Controls 是否可打开：是。
- Prototype Gallery 是否作为主底栏：否。
- WebView Harness 是否仅 Debug Developer Tools 区域：是。

| 页面 | 截图路径 |
|---|---|
| 我的 / Developer Tools | `docs/ui-handoff/ios/screenshots/app-shell-visual-behavior/009_mine_developer_tools_after_fix.png` |
| Prototype Gallery | `docs/ui-handoff/ios/screenshots/app-shell-visual-behavior/010_debug_prototype_gallery_after_fix.png` |

## 9. Boundary / Safety 检查

- boundary 结果：PASS，checked_files=82，0 violations。
- 是否未修改 Swift 源码：是，本轮未修改 Swift。
- 是否未修改 Reader-Core：是。
- 是否无真实网络/WebDAV/RSS/同步：是，复测仅使用生产 shell 与 debug fixture/prototype 页面。

## 10. Fix Queue 更新

- APP-SHELL-P1-001 状态：RESOLVED / DEVICE_REVIEW_PENDING_PRODUCTION_PATH；生产 ReaderView 路径不可达，未判 REOPENED，新增 P2 后续复测项。
- READER-P1-002 状态：DEVICE_VERIFIED_RESOLVED。
- APP-SHELL-SIM-P2-001 状态：保留，英文文案仍存在。
- APP-SHELL-SIM-P2-002 状态：新增，生产 ReaderView 设备端路径待补。

## 11. P0 问题

无。

## 12. P1 问题

无。

## 13. P2 问题

| Issue ID | 问题 |
|---|---|
| APP-SHELL-SIM-P2-001 | 书架 / 书源仍存在英文标题、空态、按钮文案。 |
| APP-SHELL-SIM-P2-002 | 生产 ReaderView 设备端路径不可达，需后续补 fixture-only 复测入口。 |

## 14. 是否建议进入下一阶段

P0/P1 为 0，建议进入 P2 英文文案清理或真实数据接入规划阶段；同时建议补充不接真实网络的生产 ReaderView fixture-only 复测路径，便于后续设备端闭环验证。

## 15. 命令验证结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 工作区存在既有未提交/未跟踪文件；本轮不 reset、不 stash、不清理。 |
| `git branch --show-current` | `main` |
| `git log --oneline -n 5` | 最新提交为 `5c96a4a fix: correct iOS app shell and reader controls layout` |
| `bash scripts/check_ios_boundary.sh` | PASS，checked_files=82，0 violations |
| `xcodebuild -project "ReaderForIOS.xcodeproj" -scheme "ReaderForIOSApp" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` | BUILD SUCCEEDED |
| `xcrun simctl install` / `xcrun simctl launch` | App 启动成功 |

clean-room 结论：本轮仅做 GUI 复测、截图和 Markdown 记录；无外部 GPL 代码搬运。
