# iOS SwiftUI Prototype Screenshot Review

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_MANUAL_SCREENSHOTS_BLOCKED**

## 2. 本轮目标

本轮是 Codex 电脑操作截图校对准备：使用 Xcode / iOS Simulator 打开 debug-only Prototype Gallery，并逐页截图。不是生产 UI 接入，不修改 Swift UI，不接真实数据。

## 3. 实际结构检查

| 请求路径 | 实际结果 |
|---|---|
| `iOS/Modules/Prototype/` | 存在 |
| `iOS/Modules/Prototype/PrototypeGallery.swift` | 不存在 |
| `iOS/Modules/Prototype/PrototypeEntry.swift` | 存在 |
| `iOS/Modules/Prototype/PrototypeFixtures.swift` | 存在 |
| `iOS/Modules/Prototype/PrototypeGalleryView.swift` | 存在 |
| `iOS/App/ReaderApp.swift` | 存在 |
| `iOS/Navigation/Route.swift` | 存在 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_INDEX.md` | 存在，已更新为阻塞状态 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_REVIEW.md` | 存在，已更新为阻塞状态 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_VISUAL_FIX_REPORT.md` | 存在 |
| `scripts/check_ios_boundary.sh` | 存在 |

## 4. GUI 运行结果

| 项目 | 结果 |
|---|---|
| Xcode project（用户指定） | `ReaderForIOS 7.xcodeproj` 可打开 |
| Xcode GUI 状态 | Active scheme 为 `ReaderForIOSApp`，Run destination 显示 `No Destinations` |
| Simulator | `iPhone 17 Pro` iOS 26.5 已启动 |
| App 启动 | 已启动 `com.reader.ios` |
| App 可见入口 | Home / Bookshelf / Search / Settings；toolbar 有 `WebView Harness` |
| `[DEBUG] Prototype Gallery` | GUI 中不可见 |
| 代码入口 | `Route.prototypeGallery` 已定义，`PrototypeGalleryView` 存在，但 `ReaderApp.swift` 没有可点击入口接线 |

## 5. 截图结果

| 项目 | 值 |
|---|---|
| 目标 entry 数量 | 38 |
| 成功截图数量 | 0 |
| 未截图数量 | 38 |
| 截图目录 | `docs/ui-handoff/ios/screenshots/prototype-gallery/` |
| 截图索引 | `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_INDEX.md` |
| 未截图原因 | Prototype Gallery 无法通过当前 GUI 入口进入；本轮禁止修改 Swift 入口 |

## 6. 主导航校对

当前运行的生产主界面仍显示 `Home / Bookshelf / Search / Settings`，不等同于 Prototype Gallery 中待校对的目标底栏 `书架 / 发现 / 书源 / 我的`。由于 Prototype Gallery 无法进入，本轮不能把目标底栏标记为人工截图 PASS。

## 7. Reader 10 条规则校对

代码级既有报告显示 10/10 PASS，但本轮未能进入 Prototype Gallery 进行人工截图校对。因此本轮人工截图结论为：**未校对 / BLOCKED**。

## 8. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| `bash scripts/check_ios_boundary.sh` | PASS，79 files，0 violations |
| 是否修改 Reader-Core | 否 |
| 是否修改 Swift 源码 | 否 |
| 是否接真实网络/WebDAV/RSS/同步 | 否 |
| 是否使用 WebView UI 进行 Prototype 截图 | 否 |
| clean-room 结论 | 本轮仅读取本仓代码、运行本地 App、更新截图文档；无外部 GPL 代码搬运 |

## 9. 阻塞结论

P0：Prototype Gallery 无法通过当前 debug GUI 入口打开。建议下一轮以最小 debug-only 入口暴露方式修复，例如在 `ReaderApp.swift` 的 DEBUG toolbar 或 debug menu 中接入 `PrototypeGalleryView()`，不得替换生产主入口。
