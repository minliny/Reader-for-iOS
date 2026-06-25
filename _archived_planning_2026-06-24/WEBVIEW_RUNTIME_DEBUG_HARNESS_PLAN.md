# WEBVIEW_RUNTIME_DEBUG_HARNESS_PLAN
## WebView Runtime Debug Harness 方案

**文档版本**: 1.0
**创建日期**: 2026-05-08
**仓库**: Reader for iOS (`/Users/minliny/Documents/Reader for iOS`)
**当前 HEAD**: `8de22ef894424c097ff1db7abd977fca4b49acdb`

---

## 一、概述

Debug Harness 是一个 **DEBUG-only** 的 SwiftUI View，用于在 iOS Simulator 中测试 `WKWebViewRuntimeAdapter` 对单 URL 的真实渲染能力。

**特点**：
- 仅在 DEBUG 模式编译
- 需要 WebKit（`#if canImport(WebKit)`）
- 不污染 ReaderCoreModels / ReaderCoreParser
- 固定授权参数，不可修改

---

## 二、文件位置

| 文件 | 路径 |
|------|------|
| ViewModel | `iOS/Features/Debug/WebViewRuntimeHarnessViewModel.swift` |
| View | `iOS/Features/Debug/WebViewRuntimeHarnessView.swift` |

---

## 三、入口位置

### 3.1 当前状态

Harness 已有骨架代码，但需要临时添加入口才能在 App 中访问。

### 3.2 临时入口（测试用）

在 `ReaderView.swift` 中添加：

```swift
NavigationLink(destination: WebViewRuntimeHarnessView()) {
    Label("WebView Harness", systemImage: "globe")
}
```

**注意**：测试完成后必须删除此临时入口。

### 3.3 Xcode Preview

使用 Preview 快速查看 Harness：

```swift
#Preview {
    WebViewRuntimeHarnessView()
}
```

在 Xcode 中打开 Preview canvas 即可。

---

## 四、授权参数（固定）

| 字段 | 值 |
|------|-----|
| URL | https://www.qianfanxs.com/9/9556 |
| Allowed Host | www.qianfanxs.com |
| Source ID | qianfanxs_user_provided |
| Source Name | 千帆小说 |
| Stage | detail |
| maxNavigationCount | 1 |
| requireHttps | true |
| allowExternalNavigation | false |
| allowPopup | false |
| allowDownload | false |
| requireSnapshot | true |

---

## 五、执行结果

### 5.1 成功结果

```
状态: Success
Final URL: https://www.qianfanxs.com/9/9556
Navigation Count: 1
HTML Size: 40950 bytes
Page Title: 关于我家老婆是个傲娇这件事
Execution Time: 2341 ms
Snapshot: qianfanxs_webview_detail_1715123456
```

### 5.2 错误结果

如果 WebView 加载失败：

```
状态: Failed: navigationFailed
错误: WebView navigation failed - could not connect to server
```

### 5.3 Snapshot 保存

成功后会显示 Snapshot 路径：

```
Caches/WebViewHarness/Snapshots/qianfanxs_webview_detail_<timestamp>.html
```

---

## 六、如何使用 Harness

### 6.1 在 Xcode 中运行

1. 打开 `iOS/Package.swift`
2. 选择 iPhone 模拟器
3. 点击 Run (⌘R)

### 6.2 添加临时入口

在 `ReaderView.swift` 中临时添加：

```swift
NavigationLink(destination: WebViewRuntimeHarnessView()) {
    Label("WebView Harness", systemImage: "globe")
}
```

### 6.3 验证安全约束

Harness 会在执行前验证约束：

- URL 必须使用 HTTPS
- URL host 必须匹配 allowedHost
- maxNavigationCount 必须为 1
- allowExternalNavigation 必须为 false
- allowPopup 必须为 false
- allowDownload 必须为 false

### 6.4 查看结果

执行后显示：
- 状态（Success/Failed）
- Final URL
- Navigation Count
- HTML Size
- Page Title
- Execution Time
- Snapshot Path
- 审计事件列表

---

## 七、提取 Snapshot 到 Reader-Core

### 7.1 找到 Snapshot 文件

1. Xcode → Window → Devices → iPhone 模拟器
2. 右键 → Download Container
3. 提取 `Caches/WebViewHarness/Snapshots/`

或使用命令：

```bash
xcrun simctl get_app_container booted com.example.ReaderApp data Caches
```

### 7.2 复制到 Reader-Core

```bash
cp qianfanxs_webview_detail_<timestamp>.html \
  /Users/minliny/Documents/Reader-Core/samples/booksources/runtime_snapshots/qianfanxs_9_9556/rendered_detail.html
```

### 7.3 验证 Parser

使用 `QianfanxsLocalSnapshotParserTests` 验证 Parser 能否从 rendered HTML 提取数据。

---

## 八、故障排除

| 问题 | 原因 | 解决 |
|------|------|------|
| "WKWebView not available" | 未在 iOS Simulator 中运行 | 确保 target device 是 iOS Simulator |
| "WebView execution timeout" | 网络请求超时 | 检查网络连接 |
| "Security policy blocked" | URL 不符合安全约束 | 确保 URL 是 `https://www.qianfanxs.com/9/9556` |
| SwiftUI Preview 不显示 | 条件不满足 | 在 iOS Simulator 设备上打开 Preview canvas |

---

## 九、清理

测试完成后：
1. 删除临时添加的导航入口
2. 手动删除 Snapshot 文件：

```bash
rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches/WebViewHarness
```

---

## 十、约束确认

| 约束 | 值 | 验证 |
|------|-----|------|
| maxNavigationCount | 1 | ✅ |
| requireHttps | true | ✅ |
| allowExternalNavigation | false | ✅ |
| allowPopup | false | ✅ |
| allowDownload | false | ✅ |
| requireSnapshot | true | ✅ |
| requireAudit | true | ✅ |

---

## 十一、与授权 UI 的关系

Harness 使用固定授权参数，用于开发/测试。

授权 UI（WebViewAuthorizationView）用于生产环境，允许用户自定义授权。

| 组件 | 用途 | 授权来源 |
|------|------|----------|
| WebViewRuntimeHarnessView | 开发/测试 | 硬编码 |
| WebViewAuthorizationView | 生产 | 用户输入 |

---

*文档创建时间：2026-05-08*
*版本：1.0*
*关联文档：WEBVIEW_RUNTIME_AUTH_UI_PLAN.md, WEBVIEW_RUNTIME_READER_CORE_INTEGRATION_PLAN.md*
