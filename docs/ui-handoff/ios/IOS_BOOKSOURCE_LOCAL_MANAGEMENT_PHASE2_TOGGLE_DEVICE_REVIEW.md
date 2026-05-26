# iOS BookSource Local Management Phase 2 Toggle Device Review

## 1. 总体结论

IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_TOGGLE_DEVICE_REVIEW_BLOCKED

## 2. 本轮目标

本轮只复测书源启用/禁用状态切换，不修改源码，不接真实网络。

## 3. 输入状态

- IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_TOGGLE_BUTTON_FIX_REPORT.md
- IOS_BOOKSOURCE_LOCAL_MANAGEMENT_PHASE2_FIX_QUEUE.md

## 4. 运行环境

- Xcode project: `ReaderForIOS.xcodeproj`
- Scheme: `ReaderForIOSApp`
- Simulator: `iPhone 17 Pro`
- iOS Runtime: `iOS 26.5`
- 截图尺寸: `393 x 852 pt`（iPhone 17 Pro 设备屏）
- 实际运行方式: `xcodebuild` 通过后，使用 `xcrun simctl launch booted com.reader.ios` 启动，再在 Simulator 内直接操作

## 5. 启用/停用按钮复测结果

- 入口命中路径：从生产底栏进入“书源”页；复用点击热区约为 `x=450, y=1360`（从书架/发现页均可命中）
- 初始状态文案：第一条 `笔趣阁` 为 `当前状态：已启用`，Accessibility `switch Value: 1`
- 初始按钮文案：页面仍呈现为开关样式，未出现可确认的 `启用/停用` 文案切换
- 第一次点击后状态文案：仍为 `当前状态：已启用`
- 第一次点击后按钮文案：仍未观察到可确认的状态变化
- 第二次点击后状态文案：仍为 `当前状态：已启用`
- 第二次点击后按钮文案：仍未观察到可确认的状态变化
- 其他触发方式：点击 switch 区域、点击更靠左的开关区域、`space`、`Right`、拖动轨道均未改变 `Value`
- Toggle 视觉状态：未观察到可确认的启用/禁用翻转
- 是否误打开详情 sheet：否，点击开关区域未打开详情 sheet
- 截图路径：
  - `docs/ui-handoff/ios/screenshots/booksource-navigation-hit-review/007_booksource_page_reached_if_success.png`

## 6. Boundary / Safety 检查

- boundary 结果：PASS，87 files, 0 violations
- 是否未修改 Swift 源码：是
- 是否未修改 Reader-Core：是
- 是否无真实网络/WebDAV/RSS/Sync：是
- 是否无 parser internals 文案：是
- 是否 clean-room：是

## 7. Fix Queue 更新

- BOOKSOURCE-P2-P1-001 状态：DEVICE_VERIFIED_RESOLVED
- BOOKSOURCE-P2-P1-002 状态：DEVICE_VERIFIED_RESOLVED
- BOOKSOURCE-P2-P1-003 状态：DEVICE_VERIFIED_RESOLVED
- BOOKSOURCE-P2-P1-004 状态：REOPENED
- P0/P1/P2/P3 数量：0 / 1 / 0 / 0

## 8. P0 问题

无

## 9. P1 问题

- `BOOKSOURCE-P2-P1-004`：BookSource 启用/禁用控件在 Simulator 中可见，但点击、拖动、键盘触发后 `switch Value` 仍未变化，状态文案也未切换

## 10. P2 问题

无

## 11. 是否建议收口

不建议收口；需要先把 `BOOKSOURCE-P2-P1-004` 的状态切换在设备端真正验证到位。
