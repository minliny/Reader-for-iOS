# WEBVIEW_RUNTIME_HARNESS_USAGE
## WebView Runtime Harness 使用指南

**文档版本**: 1.0
**创建日期**: 2026-05-08
**仓库**: Reader for iOS

---

## 一、概述

`WebViewRuntimeHarnessView` 是一个 **Debug-only** SwiftUI View，用于在 iOS Simulator 中测试 `WKWebViewRuntimeAdapter` 对单 URL 的真实渲染能力。

**特点**:
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

## 三、授权参数（固定）

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

## 四、安全约束验证

Harness 会在执行前验证以下约束：

```swift
public func validateSecurityConstraints() -> [String] {
    var violations: [String] = []

    if configuration.requireHttps && !authorizedUrl.lowercased().hasPrefix("https://") {
        violations.append("URL must use HTTPS")
    }

    if let url = URL(string: authorizedUrl), url.host != allowedHost {
        violations.append("URL host must match allowedHost")
    }

    if configuration.maxNavigationCount != 1 {
        violations.append("maxNavigationCount must be 1")
    }

    if configuration.allowExternalNavigation {
        violations.append("allowExternalNavigation must be false")
    }

    if configuration.allowPopup {
        violations.append("allowPopup must be false")
    }

    if configuration.allowDownload {
        violations.append("allowDownload must be false")
    }

    return violations
}
```

---

## 五、在 Xcode 中运行

### 5.1 打开 Package.swift

```bash
cd "/Users/minliny/Documents/Reader for iOS"
open iOS/Package.swift
```

### 5.2 选择设备

在 Xcode toolbar 选择 **iPhone 17 Pro** (或任何 iOS 26.4 模拟器)。

### 5.3 运行 App

点击 **Run** (⌘R)。

### 5.4 访问 Harness

由于 Harness 是 Debug-only，需要临时添加导航入口或使用 Preview。

**临时添加入口**（在 `ReaderView.swift` 中）:

```swift
import SwiftUI

struct ReaderView: View {
    var body: some View {
        NavigationStack {
            // ... existing content ...
            NavigationLink(destination: WebViewRuntimeHarnessView()) {
                Text("WebView Harness")
            }
        }
    }
}
```

**使用 Preview**:

在 `WebViewRuntimeHarnessView.swift` 底部已有：

```swift
#Preview {
    WebViewRuntimeHarnessView()
}
```

在 Xcode 中打开 Preview canvas 即可查看。

---

## 六、执行结果解读

### 6.1 成功结果

```
状态: Success
Final URL: https://www.qianfanxs.com/9/9556
Navigation Count: 1
HTML Size: 40950 bytes
Page Title: 关于我家老婆是个傲娇这件事
Execution Time: 2341 ms
```

### 6.2 错误结果

如果 WebView 加载失败，会显示错误信息：

```
状态: Failed: navigationFailed
错误: WebView navigation failed - could not connect to server
```

### 6.3 Snapshot 保存

成功后会显示 Snapshot 路径：

```
Snapshot: qianfanxs_webview_detail_1715123456
```

Snapshot 文件位置：
```
Caches/WebViewHarness/Snapshots/qianfanxs_webview_detail_<timestamp>.html
```

---

## 七、提取 Snapshot 到 Reader-Core

### 7.1 找到 Snapshot 文件

在 Simulator 中：
1. Xcode → Window → Devices → iPhone 17 Pro
2. 右键 → Download Container
3. 提取 `Caches/WebViewHarness/Snapshots/`

或使用以下命令：

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

### 8.1 "WKWebView not available"

**原因**: 未在 iOS Simulator 中运行

**解决**: 确保 target device 是 iOS Simulator，不是 macOS 或 Generic iOS Device

### 8.2 "WebView execution timeout"

**原因**: 网络请求超时或页面加载失败

**解决**: 检查网络连接，或增加 `defaultTimeoutMs` 配置

### 8.3 "Security policy blocked"

**原因**: URL 或 host 不符合安全约束

**解决**: 确保 URL 是 `https://www.qianfanxs.com/9/9556`

### 8.4 SwiftUI Preview 不显示

**原因**: `#if DEBUG && canImport(WebKit)` 条件不满足

**解决**: 在 iOS Simulator 设备上打开 Preview canvas

---

## 九、清理

测试完成后，删除临时添加的导航入口。

Snapshot 文件不会自动清理，需要手动删除：

```bash
rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches/WebViewHarness
```

---

## 十、注意事项

1. **仅 Debug**: Harness 代码仅在 DEBUG 模式编译，不会进入 Release
2. **固定 URL**: 授权参数硬编码，不可修改
3. **不收集数据**: Harness 不会上传任何数据到服务器
4. **安全优先**: 所有安全约束强制执行，不可绕过

---

*文档创建时间：2026-05-08*
*版本：1.0*