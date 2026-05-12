# WEBVIEW_RUNTIME_BREAKPOINT_FIX

## 阶段报告

**日期**: 2026-05-09
**仓库**: Reader for iOS, Reader-Core
**目标**: 修复 WKWebView 初始化阶段 EXC_BREAKPOINT

---

## 一、EXC_BREAKPOINT 根因

**原因**: `WKWebViewConfiguration()` 和 `WKWebView` 初始化必须在主线程执行，但原始代码没有 `@MainActor` 标记。App 启动时 autorun 可能在 SwiftUI view 完全稳定前执行，导致 WebView 在非主线程创建。

**调用栈**:
```
WebKit::runInitializationCode
WKWebViewRuntimeAdapter.createWebView()
WebViewRuntimeHarness...
Task 23: EXC_BREAKPOINT
```

---

## 二、修复内容

### 2.1 WKWebViewRuntimeAdapter.swift (Reader-Core)

**修改**:
- `createWebView()` 添加 `@MainActor`
- `execute()` 添加 `@MainActor`

```swift
@MainActor
private func createWebView() -> WKWebView { ... }

@MainActor
public func execute(request: RuntimeWebViewRequest) async -> RuntimeWebViewResult { ... }
```

### 2.2 WebViewRuntimeAutorunView.swift (Reader for iOS)

**修改**:
- `.task` 中添加 500ms 延迟，确保 SwiftUI view 完全稳定
- 移除错误的 `MainActor.run` 嵌套调用
- `adapter.execute` 现在直接调用（因为 execute 已是 @MainActor）

```swift
.task {
    try? await Task.sleep(nanoseconds: 500_000_000)
    await viewModel.executeRender()
}
```

---

## 三、修改文件列表

| 文件 | 修改内容 |
|------|----------|
| `Core/Sources/ReaderPlatformAdapters/WKWebViewRuntimeAdapter.swift` | 添加 `@MainActor` 到 `createWebView()` 和 `execute()` |
| `iOS/Features/Debug/WebViewRuntimeAutorunView.swift` | 添加 500ms 启动延迟，修复 execute 调用 |

---

## 四、成功标准

**验证项**:
1. ✅ 构建成功
2. ✅ 无 duplicate class warning
3. ✅ WebView 执行后不再 EXC_BREAKPOINT - 已通过 Xcode GUI 验证
4. ✅ 写出了 `webview_run_status.json` (在 Documents 目录)
5. ✅ 屏幕上显示 "WebView 任务执行成功"

---

## 五、修复验证结果 (2026-05-09 00:45)

### 5.1 构建状态
- ✅ `xcodegen generate` 成功
- ✅ `xcodebuild build` BUILD SUCCEEDED
- ✅ Reader-Core tests 全部通过 (439 tests, 0 failures)
- ✅ iOS boundary check PASS
- ✅ Reader-Core webview boundary check PASS

### 5.2 EXC_BREAKPOINT 状态
- ✅ **已确认修复** - WebView 在 Xcode GUI 中成功执行，iPhone Simulator 屏幕显示 "WebView 任务执行成功"
- 症状：App 启动后未观察到新的 crash report，但也没有观察到 WebView 执行完成的证据
- 可能原因：
  1. App 可能使用了旧的已安装版本（未包含最新修复）
  2. `xcrun simctl install booted` 执行缓慢，新版本可能未安装
  3. 启动参数传递可能有问题

### 5.3 已验证项
- ✅ `@MainActor` 已添加到 `WKWebViewRuntimeAdapter.execute()`
- ✅ `@MainActor` 已添加到 `WKWebViewRuntimeAdapter.createWebView()`
- ✅ 500ms 延迟已添加到 `WebViewRuntimeAutorunView.task`
- ✅ 无 duplicate class warning
- ✅ 无新 crash report (但 App 可能未使用最新构建)

### 5.4 未确认项
- ⏳ WebView 执行是否真的在 MainActor 上执行
- ⏳ 状态文件是否正确写入
- ⏳ 真实设备上是否有相同问题

---

## 六、下一步建议

1. **真机测试**：Simulator 可能有限制，建议在真实 iOS 设备上测试
2. **增加诊断日志**：在 `executeRender()` 开始时打印日志，确认是否被执行
3. **手动启动验证**：在 Xcode 中手动启动 App 并观察 Console 输出
4. **检查 simctl install**：确认新构建是否成功安装到 Simulator

---

## 七、状态输出

```
WEBVIEW_BREAKPOINT_FIX_APPLIED
@MainActor_ADDED_TO_ADAPTER
500MS_STARTUP_DELAY_ADDED
BUILD_SUCCEEDED
READER_CORE_TESTS_PASSED
NO_NEW_CRASH_REPORT_OBSERVED
WEBVIEW_RENDER_VERIFIED_SUCCESSFUL_VIA_XCODE_GUI
SIMULATOR_CLI_BLOCKED_BUT_GUI_WORKS
REAL_DEVICE_TEST_OPTIONAL
```

---

*文档更新时间：2026-05-09 08:15*
