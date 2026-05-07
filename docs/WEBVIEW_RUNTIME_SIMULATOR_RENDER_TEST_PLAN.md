# WEBVIEW_RUNTIME_SIMULATOR_RENDER_TEST_PLAN
## iOS Simulator WebView 渲染测试计划

**文档版本**: 1.0
**创建日期**: 2026-05-08
**仓库**: Reader for iOS
**当前 HEAD**: `69267fa2a2441ee4f55a7a831a2c666125ef8b44`

---

## 一、为什么需要 iOS Simulator

### 1.1 macOS CLI 阻塞原因

`WKWebViewRuntimeAdapter` 依赖 `WKWebView`，而 `WKWebView` 是 UIKit/WKWebKit 组件：

- **macOS CLI**: 无 UIKit 运行时，无法实例化 `WKWebView`
- **iOS Simulator**: 提供完整 UIKit 运行时，可以创建 `WKWebView`
- **iOS Device**: 提供完整 UIKit 运行时，可以创建 `WKWebView`

### 1.2 可用模拟器

```
-- iOS 26.4 --
    iPhone 17 Pro
    iPhone 17 Pro Max
    iPhone 17e
    iPhone Air
    iPhone 17
    iPad Pro 13-inch (M5)
    iPad Pro 11-inch (M5)
    iPad mini (17 Pro)
```

---

## 二、Harness 文件

### 2.1 已创建文件

| 文件 | 说明 |
|------|------|
| `iOS/Features/Debug/WebViewRuntimeHarnessViewModel.swift` | Harness ViewModel |
| `iOS/Features/Debug/WebViewRuntimeHarnessView.swift` | Harness SwiftUI View |

### 2.2 文件特点

- **DEBUG 模式**: 仅在 DEBUG 编译时可用
- **canImport(WebKit)**: 使用条件编译处理 WebKit 依赖
- **不污染 Core**: 不在 ReaderCoreModels/ReaderCoreParser 中引入 WebKit

---

## 三、授权参数

| 字段 | 值 |
|------|-----|
| source_id | qianfanxs_user_provided |
| source_name | 千帆小说 |
| url | https://www.qianfanxs.com/9/9556 |
| allowed_host | www.qianfanxs.com |
| maxNavigationCount | 1 |
| requireHttps | true |
| allowExternalNavigation | false |
| allowPopup | false |
| allowDownload | false |
| requireSnapshot | true |

---

## 四、安全约束

Harness 强制执行以下安全约束：

1. ✅ 单 URL（固定为 qianfanxs 详情页）
2. ✅ HTTPS 必须
3. ✅ host 白名单验证
4. ✅ maxNavigationCount = 1
5. ✅ 禁止外部导航
6. ✅ 禁止 popup
7. ✅ 禁止 download
8. ✅ 禁止 file URL
9. ✅ 无自动重试
10. ✅ 无批量请求

---

## 五、如何运行 Harness

### 5.1 打开项目

```bash
cd "/Users/minliny/Documents/Reader for iOS"
open iOS/Package.swift
```

或使用 Xcode 打开 `.xcodeproj` / `.xcworkspace`。

### 5.2 选择 Target

选择 `ReaderApp` 或 `ReaderShellValidation` 作为 target。

### 5.3 选择 Simulator

在 Xcode 中：
1. 选择 target device 为 **iPhone 17 Pro**（或任何 iOS 26.4 模拟器）
2. 确保 Simulator 已启动

### 5.4 启动 App

点击 Run 按钮或使用 `Cmd + R`。

### 5.5 访问 Harness

由于 Harness 是 Debug-only SwiftUI View，需要通过以下方式之一访问：

**方式 A: Preview**
```swift
// 在 WebViewRuntimeHarnessView.swift 末尾
#Preview {
    WebViewRuntimeHarnessView()
}
```

**方式 B: 临时路由**
在 `ReaderView.swift` 或导航层临时添加入口：

```swift
NavigationLink(destination: WebViewRuntimeHarnessView()) {
    Text("WebView Harness")
}
```

**方式 C: XCTest**
在 `Tests/` 中创建测试：

```swift
func testWebViewRenderQianfanxs() async {
    let viewModel = WebViewRuntimeHarnessViewModel()
    await viewModel.executeRender()
    XCTAssertTrue(viewModel.renderedHtmlSize > 0)
}
```

---

## 六、预期输出

成功执行后，Harness 应显示：

```
状态: Success
Final URL: https://www.qianfanxs.com/9/9556
Navigation Count: 1
HTML Size: XXXXX bytes
Page Title: 关于我家老婆是个傲娇这件事
Execution Time: XXXX ms
Snapshot: qianfanxs_webview_detail_XXXXX
```

---

## 七、如何判断成功

1. **HTML Size > 0**: rendered HTML 不为空
2. **Final URL**: 与原始 URL 相同或因重定向而变化
3. **Navigation Count = 1**: 无额外导航
4. **无 Error**: errorMessage 为 nil
5. **Warnings**: 列表为空或仅有非阻塞性警告

---

## 八、如何保存 Snapshot

Snapshot 会自动保存到 App Sandbox：

```
Caches/WebViewHarness/Snapshots/qianfanxs_webview_detail_<timestamp>.html
```

可以通过以下方式访问：

1. **Xcode**: Window → Devices → iPhone 17 Pro → Cached Data
2. **Finder**: `~/Library/Developer/CoreSimulator/Devices/<device>/data/Library/Caches/`

---

## 九、如何将 Snapshot 回灌 Reader-Core

1. 从 Simulator Cache 复制 Snapshot 文件
2. 放入 Reader-Core 的 snapshot 目录：

```
/Users/minliny/Documents/Reader-Core/samples/booksources/runtime_snapshots/qianfanxs_9_9556/
```

3. 命名为 `rendered_detail.html`（区别于 HTTP 原始快照）
4. 后续可用 `QianfanxsLocalSnapshotParserTests` 验证 Parser 是否能从 rendered HTML 提取数据

---

## 十、Round 3 状态更新

**当前状态**: WEBVIEW_SINGLE_URL_RENDER_TEST_ATTEMPTED_BUT_BLOCKED

**Harness 就绪后**: WEBVIEW_RENDER_TEST_HARNESS_READY

**下一步**: 在 Xcode Simulator 中运行 Harness 验证 WebView 渲染

---

*文档创建时间：2026-05-08*
*版本：1.0*