# WEBVIEW_RUNTIME_SINGLE_URL_RENDER_TEST_REPORT

## WebView Runtime 单 URL 渲染测试报告

**任务代码**: FIX_WEBVIEW_AUTORUN_WKWEBVIEW_MAINACTOR_CRASH
**执行日期**: 2026-05-09
**当前仓库**: Reader for iOS, Reader-Core
**当前 HEAD**: Reader for iOS `729b3234c3131cccd1d7723aadd8d146507d1f8b`, Reader-Core `0486a9d2ff385a7781ed918a506b7baf02d3c712`

---

## 一、测试授权

| 字段 | 值 |
|------|-----|
| source_id | qianfanxs_user_provided |
| source_name | 千帆小说 |
| url | https://www.qianfanxs.com/9/9556 |
| allowed_host | www.qianfanxs.com |
| requireHttps | true |
| maxNavigationCount | 1 |
| allowExternalNavigation | false |

---

## 二、EXC_BREAKPOINT 问题修复

### 2.1 问题描述

**原始崩溃**:
- App 启动后执行 WebView 时崩溃
- `exception = EXC_BREAKPOINT / SIGTRAP`
- `faultingThread = 3`
- 崩溃位置：`WebKit::runInitializationCode` -> `WKWebViewConfiguration.init()`

### 2.2 根因分析

`WKWebViewConfiguration()` 和 `WKWebView` 初始化必须在主线程执行，但原始代码没有 `@MainActor` 标记。App 启动时 autorun 可能在 SwiftUI view 完全稳定前执行，导致 WebView 在非主线程创建。

### 2.3 修复内容

**Reader-Core/Core/Sources/ReaderPlatformAdapters/WKWebViewRuntimeAdapter.swift**:
```swift
@MainActor
private func createWebView() -> WKWebView {
    let configuration = WKWebViewConfiguration()
    // ...
}

@MainActor
public func execute(request: RuntimeWebViewRequest) async -> RuntimeWebViewResult {
    // ...
}
```

**Reader for iOS/iOS/Features/Debug/WebViewRuntimeAutorunView.swift**:
```swift
.task {
    // 延迟启动，确保 SwiftUI view 完全稳定
    try? await Task.sleep(nanoseconds: 500_000_000)
    await viewModel.executeRender()
}
```

---

## 三、执行结果

**状态**: ⚠️ PARTIALLY_VERIFIED

**本轮结果**:
- ✅ `@MainActor` 已添加到 `WKWebViewRuntimeAdapter.execute()`
- ✅ `@MainActor` 已添加到 `WKWebViewRuntimeAdapter.createWebView()`
- ✅ 500ms 延迟已添加到 `WebViewRuntimeAutorunView.task`
- ✅ 构建成功 (`BUILD SUCCEEDED`)
- ✅ Reader-Core tests 全部通过 (439 tests, 0 failures)
- ✅ iOS boundary check PASS
- ✅ Reader-Core webview boundary check PASS
- ⚠️ App 在 Simulator 中启动，但未观察到明确的 WebView 执行完成证据
- ⚠️ 未观察到新 crash report，但 App 可能使用旧版本

**Simulator 测试观察**:
- App 进程 (PID 55409) 在 Simulator 中持续运行
- 未观察到新的 `.ips` crash report
- `webview_run_status.json` 状态仍为 "crashed_or_interrupted"（旧运行）
- 新运行未产生新的结果文件

**可能原因**:
1. `xcrun simctl install booted` 执行缓慢，新构建可能未安装
2. 启动参数传递可能有问题
3. Simulator 可能有限制，真实设备测试更可靠

---

## 四、Reader-Core 状态

| 仓库 | HEAD |
|------|------|
| Reader-Core | `0486a9d2ff385a7781ed918a506b7baf02d3c712` |

**Reader-Core 最新提交**:
```
0486a9d fix: add @MainActor to WKWebViewRuntimeAdapter
```

---

## 五、平台边界确认

| 检查项 | 状态 |
|--------|------|
| ReaderCoreModels 无 WebKit/UIKit | ✅ |
| ReaderCoreParser 无 WebKit/UIKit | ✅ |
| check_webview_adapter_boundary.sh | ✅ PASS |
| check_ios_boundary.sh | ✅ PASS |
| 新增 case_031 | ❌ 未新增 |
| baseline promotion | ❌ 未执行 |

---

## 六、修改文件列表

| 文件 | 修改内容 |
|------|----------|
| `Core/Sources/ReaderPlatformAdapters/WKWebViewRuntimeAdapter.swift` | 添加 `@MainActor` 到 `createWebView()` 和 `execute()` |
| `iOS/Features/Debug/WebViewRuntimeAutorunView.swift` | 添加 500ms 启动延迟 |
| `docs/WEBVIEW_RUNTIME_BREAKPOINT_FIX.md` | 更新修复报告 |

---

## 七、下一步

### 7.1 真机测试建议

Simulator 可能有限制，建议在真实 iOS 设备上测试：
1. 在 Xcode 中连接真机
2. 选择真机作为目标设备
3. 运行 App 并观察 Console 输出

### 7.2 手动验证

在 Xcode 中：
1. 打开 `ReaderForIOS.xcodeproj`
2. 选择 iPhone 17 Pro Simulator
3. 运行 App (⌘R)
4. 点击 "WebView Harness" 按钮
5. 观察 Console 日志

### 7.3 诊断日志

如果需要进一步诊断，可以在 `WebViewRuntimeAutorunViewModel.executeRender()` 开始处添加：
```swift
print("executeRender mainThread=\(Thread.isMainThread)")
```

---

## 八、本轮约束遵守情况

| 约束 | 状态 |
|------|------|
| 禁止批量请求 | ✅ 未执行 |
| 禁止递归 | ✅ 未执行 |
| 禁止翻页 | ✅ 未执行 |
| 禁止批量章节 | ✅ 未执行 |
| 禁止 WAF/anti-bot 绕过 | ✅ 未执行 |
| 禁止自动重试 | ✅ 未执行 |
| 禁止 Cookie/Login 自动流程 | ✅ 未执行 |
| 禁止修改 Reader-Core Parser | ✅ 未修改 |
| 禁止在 CoreModels/Parser 引入 WebKit | ✅ 未引入 |
| 禁止新增 case_031 | ✅ 未新增 |
| 禁止 baseline promotion | ✅ 未执行 |

---

## 九、状态输出

```
WEBVIEW_WKWEBVIEW_INITIALIZATION_MAINACTOR_FIXED ✅
WEBVIEW_AUTORUN_NO_LONGER_CRASHES_AT_CONFIGURATION_INIT ⚠️ (未完全确认)
WEBVIEW_HARNESS_WRITES_FAILURE_OR_SUCCESS_STATUS ⚠️ (待验证)
NO_BATCH_REQUEST ✅
NO_RECURSION ✅
NO_BASELINE_PROMOTION ✅
BUILD_SUCCEEDED ✅
READER_CORE_TESTS_PASSED ✅
REAL_DEVICE_TEST_RECOMMENDED ⚠️
```

---

*文档更新时间：2026-05-09*
*任务代码：FIX_WEBVIEW_AUTORUN_WKWEBVIEW_MAINACTOR_CRASH*
*执行结果：PARTIALLY_VERIFIED_SIMULATOR_MAY_USE_OLD_BUILD*