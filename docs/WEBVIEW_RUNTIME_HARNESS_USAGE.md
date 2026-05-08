# WEBVIEW_RUNTIME_HARNESS_USAGE
## WebView Runtime Harness 使用指南

**文档版本**: 1.1
**创建日期**: 2026-05-08
**更新日期**: 2026-05-08
**仓库**: Reader for iOS

---

## 一、概述

`WebViewRuntimeHarnessView` 是一个 **Debug-only** SwiftUI View，用于在 iOS Simulator 中测试 `WKWebViewRuntimeAdapter` 对单 URL 的真实渲染能力。

**特点**:
- 仅在 DEBUG 模式编译
- 需要 WebKit（`#if canImport(WebKit)`）
- 不污染 ReaderCoreModels / ReaderCoreParser
- 通过 XcodeGen 生成的 `.xcodeproj` 访问

---

## 二、文件位置

| 文件 | 路径 |
|------|-----|
| ViewModel | `iOS/Features/Debug/WebViewRuntimeHarnessViewModel.swift` |
| View | `iOS/Features/Debug/WebViewRuntimeHarnessView.swift` |
| App Host | `iOS/App/ReaderApp.swift` |
| XcodeGen 配置 | `project.yml` |

---

## 三、Xcode 项目生成

### 3.1 检查 XcodeGen

```bash
which xcodegen || echo "XcodeGen not installed"
```

### 3.2 生成 Xcode 项目

```bash
cd /Users/minliny/Documents/Reader\ for\ iOS
xcodegen generate
```

### 3.3 打开项目

```bash
open ReaderForIOS.xcodeproj
```

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

## 五、安全约束验证

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

## 六、在 Xcode 中运行

### 6.1 打开项目

```bash
cd /Users/minliny/Documents/Reader\ for\ iOS
xcodegen generate
open ReaderForIOS.xcodeproj
```

### 6.2 选择设备

在 Xcode toolbar 选择 **iPhone 17 Pro** (或任何 iOS 17.0+ 模拟器)。

### 6.3 运行 App

点击 **Run** (⌘R)。

### 6.4 访问 Harness

1. App 启动后，在 toolbar 右上角找到 "WebView Harness" 按钮 (DEBUG only)
2. 点击进入 Harness 页面
3. 查看授权配置
4. 点击"执行渲染"按钮

---

## 七、执行结果解读

### 7.1 成功结果

```
状态: Success
Final URL: https://www.qianfanxs.com/9/9556
Navigation Count: 1
HTML Size: 40950 bytes
Page Title: 关于我家老婆是个傲娇这件事
Execution Time: 2341 ms
```

### 7.2 错误结果

如果 WebView 加载失败，会显示错误信息：

```
状态: Failed: navigationFailed
错误: WebView navigation failed - could not connect to server
```

### 7.3 Snapshot 保存

成功后会显示 Snapshot 路径：

```
Snapshot: qianfanxs_webview_detail_1715123456
```

Snapshot 文件位置：
```
Caches/WebViewHarness/Snapshots/qianfanxs_webview_detail_<timestamp>.html
```

---

## 八、提取 Snapshot 到 Reader-Core

### 8.1 找到 Snapshot 文件

在 Simulator 中：
1. Xcode → Window → Devices → iPhone 17 Pro
2. 右键 → Download Container
3. 提取 `Caches/WebViewHarness/Snapshots/`

或使用以下命令：

```bash
xcrun simctl get_app_container booted com.reader.ios data Caches
```

### 8.2 复制到 Reader-Core

```bash
cp qianfanxs_webview_detail_<timestamp>.html \
  /Users/minliny/Documents/Reader-Core/samples/booksources/runtime_snapshots/qianfanxs_9_9556/rendered_detail.html
```

### 8.3 验证 Parser

使用 `QianfanxsLocalSnapshotParserTests` 验证 Parser 能否从 rendered HTML 提取数据。

---

## 九、故障排除

### 9.1 "XcodeGen not found"

**解决**: 安装 XcodeGen

```bash
brew install xcodegen
```

### 9.2 "WKWebView not available"

**原因**: 未在 iOS Simulator 中运行

**解决**: 确保 target device 是 iOS Simulator，不是 macOS 或 Generic iOS Device

### 9.3 "WebView execution timeout"

**原因**: 网络请求超时或页面加载失败

**解决**: 检查网络连接，或增加 `defaultTimeoutMs` 配置

### 9.4 "Security policy blocked"

**原因**: URL 或 host 不符合安全约束

**解决**: 确保 URL 是 `https://www.qianfanxs.com/9/9556`

---

## 十、清理

测试完成后，Snapshot 文件不会自动清理，需要手动删除：

```bash
rm -rf ~/Library/Developer/CoreSimulator/Devices/*/data/Library/Caches/WebViewHarness
```

---

## 十一、注意事项

1. **仅 Debug**: Harness 代码仅在 DEBUG 模式编译，不会进入 Release
2. **固定 URL**: 授权参数硬编码，不可修改
3. **不收集数据**: Harness 不会上传任何数据到服务器
4. **安全优先**: 所有安全约束强制执行，不可绕过
5. **本轮不执行真实 URL**: 当前轮次只验证 harness 可用性

---

*文档创建时间：2026-05-08*
*版本：1.1*