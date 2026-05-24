# iOS SwiftUI Prototype Build P0 Fix Report

## 1. 总体结论

**IOS_SWIFTUI_PROTOTYPE_BUILD_P0_FIXED**

## 2. 本轮目标

本轮只修 fresh Debug/iOS build P0（MANUAL-P0-002），使 `ReaderForIOSApp` scheme 能通过 `xcodebuild` 完整构建。不做截图、不做 UI 视觉修复、不接真实数据。

## 3. 输入状态

| 文档 | 状态 |
|---|---|
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_DEBUG_ENTRY_REPORT.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_MANUAL_SCREENSHOT_REPORT.md` | 已读取 |
| `docs/ui-handoff/ios/IOS_SWIFTUI_PROTOTYPE_MANUAL_FIX_QUEUE.md` | 已读取 |

## 4. P0 复现结果

| 项目 | 值 |
|---|---|
| 构建命令 | `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` |
| 原始错误数 | 4 errors + 1 warning-as-error (Swift 6) |
| 涉及文件 | `iOS/CoreBridge/RuntimeContractMapping.swift`, `iOS/CoreBridge/ProductionWebViewAdapter.swift` |
| 涉及 target | `ReaderShellValidation` |
| 是否与 SPM macOS 预存错误不同 | 是 — iOS build 错误是 protocol conformance / access control / extra argument，SPM macOS 错误是 API unavailability |

### 原始错误详情

1. `ProductionWebViewAdapter` does not conform to protocol `RuntimeExecutorProtocol` (line 83)
2. `'securityGate' is inaccessible due to 'private' protection level` (line 91)
3. `extra argument 'timestamp' in call` (line 101)
4. `method must be declared fileprivate because its result uses a private type` (line 155)
5. `conformance of 'ProductionWebViewAdapter' to protocol 'RuntimeExecutorProtocol' crosses into main actor-isolated code` (Swift 6 warning-as-error)

## 5. 根因分析

### 5.1 `securityGate` private access (line 91)

`ProductionWebViewAdapter.securityGate` 声明为 `private`，导致 `RuntimeContractMapping.swift` 的 extension 无法访问。

### 5.2 `timestamp` extra argument (line 101)

`WebViewExecutionSnapshot` init 不接受 `timestamp:` 参数（该参数在 init 内部自动设为 `Date()`），调用处多传了 `timestamp: Date()`。

### 5.3 `GateEvaluation` private type (line 149-155)

`GateEvaluation` 声明为 `private struct`，但 `WebViewSecurityGate.evaluate()` 返回该类型。内部方法返回私有类型允许，但需 `fileprivate` 访问级别。实际错误是方法默认 `internal` 但返回 `private` 类型。

### 5.4 Swift 6 concurrency (line 83)

`ProductionWebViewAdapter` 是 `@MainActor` class，`RuntimeExecutorProtocol` 继承自 `Sendable`。在 Swift 6 语言模式下，`@MainActor` 类型 conform to `Sendable` 协议产生 data race 警告升级为 error。

### 5.5 `currentPolicy` type mismatch

`RuntimeExecutorProtocol` 要求 `var currentPolicy: RuntimePolicy { get }`，但 `ProductionWebViewAdapter` 已有 `var currentPolicy: WebViewSecurityPolicy`。两个同名属性不同类型，Swift 无法共存。

### 是否本轮引入

否。`RuntimeContractMapping.swift` 和 `ProductionWebViewAdapter.swift` 在 git status 中已是修改状态（本轮前已存在）。

## 6. 修复内容

### 修改文件

| 文件 | 操作 | 变更说明 |
|---|---|---|
| `iOS/CoreBridge/ProductionWebViewAdapter.swift` | 修改 | `private let securityGate` → `let securityGate`（internal）；`currentPolicy` → `webViewPolicy`（避免与 `RuntimeExecutorProtocol.currentPolicy: RuntimePolicy` 类型冲突） |
| `iOS/CoreBridge/RuntimeContractMapping.swift` | 修改 | (1) 删除 `timestamp: Date()` extra argument; (2) `private struct GateEvaluation` → `struct GateEvaluation`; (3) 添加 `@preconcurrency` 到 protocol conformance; (4) `currentPolicy.allowsHost` → `webViewPolicy.allowsHost`; (5) 新增 `var currentPolicy: RuntimePolicy` computed property |
| `iOS/Tests/ShellSmokeTests/WebViewAdapterSmokeTests.swift` | 修改 | `adapter.currentPolicy` → `adapter.webViewPolicy`（适配属性重命名） |

### 为什么是最小修复

- 每个修改点只解决对应的编译错误，不扩展范围
- 未删除任何功能逻辑
- 未新增类型或抽象层
- 属性重命名只涉及 3 处引用

### 影响范围

- 不影响 Release（修复仅在 `ReaderShellValidation` target 内部）
- 不影响 Reader-Core（未修改 Reader-Core 任何文件）
- 不影响 Prototype Gallery entry（入口代码未再变动）

## 7. 验证结果

| 命令 | 结果 |
|---|---|
| `git status --short` | 已执行 |
| `bash scripts/check_ios_boundary.sh` | PASS（79 files, 0 violations） |
| `xcodegen generate` | 成功 |
| `xcodebuild build -project ReaderForIOS.xcodeproj -scheme ReaderForIOSApp -destination 'platform=iOS Simulator,name=iPhone 17 Pro'` | **BUILD SUCCEEDED** |
| `swift build --target ReaderApp` | 预存 macOS API 错误（`topBarTrailing`/`navigationBarTitleDisplayMode`/`CGColor.systemGray6` unavailable），非本轮引入，不影响 iOS Simulator |

## 8. Boundary / Safety 检查

| 检查项 | 结果 |
|---|---|
| 是否未引用 parser internals（NonJSRuleScheduler 等） | PASS |
| 是否无 WebView UI 承载 Prototype | PASS |
| 是否无真实网络 | PASS |
| 是否未接真实 WebDAV/RSS/同步 | PASS |
| 是否未修改 Reader-Core | PASS |
| 是否未删除 RuntimeContractMapping / ProductionWebViewAdapter 功能 | PASS |

## 9. 修改文件

| 文件 | 操作 |
|---|---|
| `iOS/CoreBridge/ProductionWebViewAdapter.swift` | 修改 |
| `iOS/CoreBridge/RuntimeContractMapping.swift` | 修改 |
| `iOS/Tests/ShellSmokeTests/WebViewAdapterSmokeTests.swift` | 修改 |

新增文件：0

## 10. P0 问题

无（MANUAL-P0-002 已修复）。

## 11. P1 问题

无。

## 12. 是否建议交回 Codex 截图

建议交回 Codex 重新执行 Xcode/Simulator 截图。iOS fresh build 已通过，boundary 通过，无 P0/P1。
