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
3. ⏳ WebView 执行后不再 EXC_BREAKPOINT
4. ⏳ 写出了 `webview_run_status.json`
5. ⏳ `status = success`

---

## 五、状态输出

```
WEBVIEW_BREAKPOINT_FIX_APPLIED
@MainActor_ADDED_TO_ADAPTER
500MS_STARTUP_DELAY_ADDED
BUILD_SUCCEEDED
WEBVIEW_RENDER_VERIFICATION_PENDING
```

---

*文档更新时间：2026-05-09*
