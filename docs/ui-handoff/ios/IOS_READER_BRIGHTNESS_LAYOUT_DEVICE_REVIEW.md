# iOS Reader Brightness Layout Device Review

## 1. 总体结论

IOS_READER_BRIGHTNESS_LAYOUT_DEVICE_REVIEW_READY

## 2. 本轮目标

本轮只复测 `READER-P1-002` 亮度条布局，不修改 Swift 源码，不修改 Reader-Core，不接真实数据，不修 UI。

## 3. 输入状态

- 已读取：`docs/ui-handoff/ios/IOS_READER_BRIGHTNESS_LAYOUT_REFIX_REPORT.md`
- 已读取：`docs/ui-handoff/ios/IOS_APP_SHELL_ALIGNMENT_FIX_QUEUE.md`
- 已读取：`docs/ui-handoff/ios/IOS_APP_SHELL_VISUAL_BEHAVIOR_DEVICE_REVIEW.md`
- 已读取：`iOS/Modules/Prototype/PrototypeGalleryView.swift`

## 4. 运行环境

- Xcode project：`ReaderForIOS.xcodeproj`
- Scheme：`ReaderForIOSApp`
- Simulator：`iPhone 17 Pro`
- Simulator UDID：`74B467A0-A02D-4D7B-9CE3-E10937B6A7DE`
- iOS Runtime：iOS 26.5
- 截图尺寸：1206 x 2622 px
- 实际运行方式：`xcodebuild` fresh build 成功后，通过 `simctl install` / `simctl launch` 启动，并使用 Simulator GUI 进入 Debug Prototype Gallery 复测。

## 5. Debug Prototype Gallery 进入结果

- App 是否启动成功：是。
- 生产主底栏是否仍为 4 项：是，书架 / 发现 / 书源 / 我的。
- Prototype Gallery 是否可进入：是，路径为“我的 / Developer Tools / [DEBUG] Prototype Gallery”。
- entry 数量是否为 38：是。
- Reader Base Controls 是否可打开：是，实际 entry 名称为“阅读页基础控制层”。

## 6. 亮度条复测结果

- 是否横向控制行：是。
- 是否显示 sun.min / Slider / sun.max / “系统”：是，辅助树中分别可见 `sun.min`、slider value 0.6、`sun.max.fill`、`系统`。
- 是否高度受限：是，视觉表现为约 44pt 高横向行。
- 是否仍占据大量空间：否。
- 是否位于 top bar 和 meta row 下方：是。
- 是否覆盖四角信息：否；左上书名、右上电量、左下章节、右下时间均可见。
- 是否覆盖底部控制层：否；底部 Reader 控制仍可见。
- 是否覆盖快捷按钮区：否；快捷按钮区仍可见。
- 是否遮挡大面积正文：否；正文仍可读。
- 页面其他 Reader 控制是否仍可见：是。
- 是否仍存在全屏 VStack / 大面积背景覆盖视觉效果：否。
- 是否符合“只占据控制层局部空间”要求：是。

结论：`READER-P1-002` 可标记为 `DEVICE_VERIFIED_RESOLVED`。

## 7. 截图结果

| 序号 | 截图路径 |
|---:|---|
| 001 | `docs/ui-handoff/ios/screenshots/reader-brightness-layout-refix/001_reader_base_controls_brightness_row.png` |
| 002 | `docs/ui-handoff/ios/screenshots/reader-brightness-layout-refix/002_reader_brightness_row_context.png` |
| 003 | `docs/ui-handoff/ios/screenshots/reader-brightness-layout-refix/003_reader_controls_bottom_area_visible.png` |

## 8. Boundary / Safety 检查

- boundary 结果：PASS，checked_files=82，0 violations。
- 是否未修改 Swift 源码：是，本轮未修改 Swift。
- 是否未修改 Reader-Core：是。
- 是否无真实网络/WebDAV/RSS/同步：是，复测仅使用 debug fixture/prototype 页面。

## 9. Fix Queue 更新

- `READER-P1-002` 状态：`DEVICE_VERIFIED_RESOLVED`。
- `APP-SHELL-SIM-P2-001` 状态：保留，英文文案待处理。
- `APP-SHELL-SIM-P2-002` 状态：保留，生产 ReaderView 路径待补。

## 10. P0 问题

无。

## 11. P1 问题

无。

## 12. P2 问题

- `APP-SHELL-SIM-P2-001`：书架 / 书源英文文案。
- `APP-SHELL-SIM-P2-002`：生产 ReaderView 路径待补。

## 13. 是否建议进入下一阶段

`READER-P1-002` 设备端复测通过，建议交回 Claude Code 处理剩余 P2 或进入真实数据接入规划。

## 14. 命令验证结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 工作区存在既有未提交/未跟踪文件；本轮不 reset、不 stash、不清理。 |
| `git branch --show-current` | `main` |
| `git log --oneline -n 5` | 最新提交为 `414c5a6 fix: constrain iOS reader brightness controls` |
| `bash scripts/check_ios_boundary.sh` | PASS，checked_files=82，0 violations |
| `xcodebuild -project "ReaderForIOS.xcodeproj" -scheme "ReaderForIOSApp" -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build` | BUILD SUCCEEDED |
| `xcrun simctl install` / `xcrun simctl launch` | App 启动成功 |

clean-room 结论：本轮仅做 GUI 复测、截图和 Markdown 记录；无外部 GPL 代码搬运。
