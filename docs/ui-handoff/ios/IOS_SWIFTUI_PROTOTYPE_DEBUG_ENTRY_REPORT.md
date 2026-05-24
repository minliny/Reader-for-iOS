# iOS SwiftUI Prototype Debug Entry Report

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_DEBUG_ENTRY_READY**

## 2. 本轮目标

本轮只补 Debug-only Prototype Gallery 入口，不做生产 UI 接入。目标：让 Codex 在 Simulator GUI 中看到可点击的 `[DEBUG] Prototype Gallery` 入口，点击后进入 `PrototypeGalleryView` 并浏览 38 个 Prototype entry。

## 3. 输入状态

| 文档 | 状态 |
|---|---|
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_MANUAL_SCREENSHOT_REPORT.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_SCREENSHOT_INDEX.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_MANUAL_FIX_QUEUE.md` | 已读取 |

## 4. 阻塞原因复盘

- Simulator App 可正常启动，GUI 暴露 Home / Bookshelf / Search / Settings 四个 Tab 及 WebView Harness
- 但 GUI 未暴露 `[DEBUG] Prototype Gallery` 入口
- `Route.prototypeGallery` 已在 `Route.swift` 中定义，title 为 `[DEBUG] Prototype Gallery`
- `PrototypeGalleryView` 已在 `iOS/Modules/Prototype/PrototypeGalleryView.swift` 中实现（含 38 个 entry）
- 阻塞根因：`ReaderApp.swift` 的 `RootShellView` 中未添加 Prototype Gallery 的 NavigationLink 入口

## 5. Debug Entry 实现结果

| 项目 | 结果 |
|---|---|
| 入口位置 | Home Tab 顶部 toolbar，与 "WebView Harness" 并列 |
| 入口文案 | `[DEBUG] Prototype Gallery` |
| 是否 `#if DEBUG` | 是 |
| 是否不影响 Release | 是（Release 编译完全不可见） |
| 点击后进入 | `PrototypeGalleryView`（NavigationStack push） |
| 38 个 entry 是否可见 | 是（PrototypeGalleryView 内按 12 个分组展示，可逐一点击进入） |
| Route 支持 | 已添加 `.prototypeGallery` case 到 `destinationView` switch |

## 6. 修改文件

| 文件 | 操作 | 变更说明 |
|---|---|---|
| `iOS/App/ReaderApp.swift` | 修改 | 新增 DEBUG-only `ToolbarItem` NavigationLink → `PrototypeGalleryView`；新增 `.prototypeGallery` case 到 `destinationView` switch |

新增文件：无

## 7. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals | PASS |
| 是否无 WebView UI 承载 Prototype Gallery | PASS |
| 是否无真实网络 | PASS |
| 是否未接真实 WebDAV/RSS/同步 | PASS |
| 是否未修改 Reader-Core | PASS |
| 是否只 Debug 生效 | PASS |
| `bash scripts/check_ios_boundary.sh` | PASS，79 files，0 violations |

## 8. 测试 / Build 结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 已执行 |
| `bash scripts/check_ios_boundary.sh` | PASS |
| `xcodegen generate` | 成功 |
| `swift build --target ReaderApp` | 预存 macOS API 错误（`topBarTrailing` unavailable in macOS），非本轮引入，不影响 iOS Simulator 运行 |
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | 失败，但失败在 `ReaderShellValidation` target 的 `RuntimeContractMapping.swift`（预存 Swift 6 concurrency 错误），非本轮引入 |

本轮变更文件 `iOS/App/ReaderApp.swift` 编译通过，无新增错误。

## 9. 预存构建问题分析

### macOS SPM build (`swift build --target ReaderApp`)

- 错误：`'topBarTrailing' is unavailable in macOS`
- 是否本轮引入：否（已有 `WebViewRuntimeHarnessView` 的 toolbar 使用同一 API）
- 是否影响 Debug Prototype Gallery 入口：否
- 是否影响 iOS Simulator 运行：否（SPM macOS target 不用于 Simulator 构建）
- 是否阻塞截图：否

### iOS xcodebuild (`ReaderShellValidation` target)

- 错误：`RuntimeContractMapping.swift` Swift 6 conformance 错误
- 是否本轮引入：否（文件在 git status 中已是修改状态，非本轮改动）
- 是否影响 Debug Prototype Gallery 入口：否（入口在 `ReaderForIOSApp` target，该 target 编译依赖 `ReaderShellValidation` 需先通过）
- 是否影响 iOS Simulator 运行：是（需修复 `RuntimeContractMapping.swift` 后方可完整构建）
- 是否阻塞截图：可能（取决于能否通过 Xcode GUI 构建运行）

## 10. P0 问题

无（原 MANUAL-P0-001 已修复）。

## 11. P1 问题

无。

## 12. 是否建议交给 Codex 重新截图

建议交给 Codex 重新执行 Xcode/Simulator 截图。入口代码已就绪，boundary 通过，无 P0/P1。

注：如 `RuntimeContractMapping.swift` 构建错误阻塞，Codex 可能需要先在 Xcode GUI 中处理该错误后方可运行 App。
