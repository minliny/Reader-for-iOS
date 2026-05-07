# WEBVIEW_RUNTIME_ADAPTER_PLAN
## iOS WebView Runtime Adapter 集成计划

**任务代码**: DESIGN_IOS_WEBVIEW_RUNTIME_ADAPTER_INTEGRATION_PLAN
**执行日期**: 2026-05-07
**更新日期**: 2026-05-07（方案 A 确认 + 实现）
**当前仓库**: Reader for iOS (`/Users/minliny/Documents/Reader for iOS`)
**当前 HEAD**: `11bb5e678948f0fb9d74639b2cb6ba3e593a048f`

---

## 方案确认

**选择方案 A**：在 `ReaderPlatformAdapters` 模块中实现 `WKWebViewRuntimeAdapter`

**理由**：
1. `ReaderPlatformAdapters` 本身就是平台特定实现的集合
2. HTTP adapter 已经有 platform-specific 代码
3. 可以被多个 iOS App（Reader for iOS、TestApp 等）复用
4. WebKit import 通过 `#if canImport(WebKit)` 条件编译隔离

**平台边界**：
- ReaderCoreModels 不得 import WebKit/UIKit ✅
- ReaderCoreParser 不得 import WebKit/UIKit ✅
- WKWebViewRuntimeAdapter 只在 ReaderPlatformAdapters target ✅
- 非 Apple 平台构建不因 WebKit 缺失失败（unavailable stub）✅

---

## 一、目标

在 Reader for iOS 中实现 `WKWebViewRuntimeAdapter`，通过平台 adapter 使 Reader-Core 的 `RuntimeWebViewExecutorProtocol` 能够执行真实 WKWebView 渲染。

**约束**：
- 不修改 Reader-Core NonJS Parser Core
- 不在 Reader-Core Core 模块中 import WebKit/UIKit
- 在 iOS 层实现 WebView 加载、等待、HTML 提取、snapshot 返回
- 与 Reader-Core 的 `RuntimeWebViewExecutorProtocol` 完全对齐

---

## 二、Reader-Core 现状分析

### 2.1 已有 Protocol 定义

**文件**: `Reader-Core/Core/Sources/ReaderCoreModels/RuntimeWebViewExecutorProtocol.swift`

核心方法：
```swift
public protocol RuntimeWebViewExecutorProtocol: Sendable {
    var executorId: String { get }
    var executorName: String { get }

    func supportsFeature(_ feature: RuntimeWebViewFeature) -> Bool
    func capabilities() -> RuntimeWebViewExecutorCapabilities

    func execute(request: RuntimeWebViewRequest) async -> RuntimeWebViewResult
    func executeInteractionSteps(
        request: RuntimeWebViewRequest,
        scripts: [RuntimeWebViewScript]
    ) async -> [RuntimeWebViewInteractionResult]

    func release() async
}
```

### 2.2 已有 Request/Result 模型

**文件**: `Reader-Core/Core/Sources/ReaderCoreModels/RuntimeWebViewRequest.swift`

关键字段：
- `requestId`, `sourceId`, `sourceName`
- `url`, `stage`
- `waitPolicy`: `RuntimeWebViewWaitPolicy`
- `scriptPolicy`: `RuntimeWebViewScriptPolicy`
- `snapshotRequired`, `snapshotPrefix`
- `securityRiskLevel`, `authorization`

### 2.3 iOS Executor 现状

**文件**: `Reader-Core/Core/Sources/ReaderCoreModels/iOSRuntimeWebViewExecutor.swift`

- 实现 `RuntimeWebViewExecutorProtocol`
- 在 macOS 环境返回 `configurationError`（因为无 UIKit/WKWebView）
- 在 iOS 环境返回 `configurationError`（TODO: 真实执行未实现）
- 包含安全验证、脚本构建、快照保存等 Core Layer 逻辑
- **真实 WKWebView 执行需要在 iOS App Layer 实现**

### 2.4 Platform Adapters 模块

**文件**: `Reader-Core/Core/Sources/ReaderPlatformAdapters/`

现有 adapter：
- `HTTPAdapterFactory`
- `MinimalHTTPAdapter`
- `URLSessionHTTPClient`
- `TraceInspector`
- `AdapterIntegrationTestHarness`

**问题**: 无 WebView adapter

---

## 三、Reader for iOS 现状分析

### 3.1 依赖结构

**Package.swift** 依赖：
```
ReaderApp
  ├── ReaderShellValidation
  │     ├── ReaderCoreModels
  │     ├── ReaderCoreProtocols
  │     ├── ReaderCoreParser
  │     ├── ReaderCoreNetwork
  │     └── ReaderPlatformAdapters ← WebView adapter 应放此处
  ├── ReaderAppSupport
  └── ReaderAppPersistence
```

### 3.2 CoreIntegration 层

现有文件：
- `DefaultBookSourceDecoder.swift`
- `DefaultContentService.swift`
- `DefaultSearchService.swift`
- `DefaultTOCService.swift`
- `InMemoryBookSourceRepository.swift`
- `ReadingFlowCoordinator.swift`

### 3.3 架构边界

根据 `ios_architecture_remediation_plan.yml`：
- Shell → CoreIntegration → ReaderCoreProtocols + ReaderCoreModels（仅协议类型）
- Shell → ShellAssembly → ReaderCoreNetwork + ReaderCoreParser（具体接线，允许）

---

## 四、WKWebViewRuntimeAdapter 设计

### 4.1 目标位置

**方案 A（推荐）**: `ReaderPlatformAdapters` 模块
- 路径: `Reader-Core/Core/Sources/ReaderPlatformAdapters/WKWebViewRuntimeAdapter.swift`
- 优点: 复用现有 Platform Adapter 架构，可被 Reader for iOS 直接使用
- 缺点: 需要在 Reader-Core 中 import WebKit

**方案 B**: Reader for iOS 的 CoreIntegration 层
- 路径: `Reader for iOS/iOS/CoreIntegration/WKWebViewRuntimeAdapter.swift`
- 优点: 不影响 Reader-Core 架构
- 缺点: 难以被其他 iOS App 复用

**推荐方案 A**，因为：
1. `ReaderPlatformAdapters` 已有 HTTP adapter 先例
2. Platform Adapter 的目的就是封装平台特定实现
3. 可以被多个 iOS App（Reader for iOS、TestApp 等）复用

### 4.2 核心接口

```swift
import Foundation
import WebKit
import ReaderCoreModels

/// WKWebView Runtime Adapter
/// 实现 RuntimeWebViewExecutorProtocol，提供真实 iOS WKWebView 执行能力
public final class WKWebViewRuntimeAdapter: NSObject, RuntimeWebViewExecutorProtocol {

    public let executorId: String
    public let executorName: String

    private let configuration: Configuration
    private weak var webView: WKWebView?
    private let executionQueue = DispatchQueue(label: "com.readerplatformadapters.webview")

    public struct Configuration {
        public let snapshotRootDirectory: String
        public let maxConcurrentExecutions: Int
        public let defaultTimeoutMs: Int
        public let enableAuditLogging: Bool

        public static let `default` = Configuration(
            snapshotRootDirectory: "...",
            maxConcurrentExecutions: 1,
            defaultTimeoutMs: 30000,
            enableAuditLogging: true
        )
    }

    public init(configuration: Configuration = .default) {
        self.executorId = UUID().uuidString
        self.executorName = "WKWebViewRuntimeAdapter"
        self.configuration = configuration
        super.init()
    }

    // MARK: - RuntimeWebViewExecutorProtocol

    public func supportsFeature(_ feature: RuntimeWebViewFeature) -> Bool {
        switch feature {
        case .javascriptExecution, .pageSnapshot, .interactionSupport,
             .customUserAgent, .navigationHistory:
            return true
        default:
            return false
        }
    }

    public func capabilities() -> RuntimeWebViewExecutorCapabilities {
        RuntimeWebViewExecutorCapabilities(
            supportedFeatures: [.javascriptExecution, .pageSnapshot, .interactionSupport],
            maxConcurrentExecutions: configuration.maxConcurrentExecutions,
            supportsSnapshot: true,
            supportsOfflineMode: false,
            supportsLoginFlow: true,
            version: "1.0.0-wkwebview"
        )
    }

    public func execute(request: RuntimeWebViewRequest) async -> RuntimeWebViewResult {
        // 1. 安全验证（复用 iOSRuntimeWebViewExecutor 的 validator）
        // 2. 创建 WKWebView
        // 3. 配置 WKNavigationDelegate
        // 4. 加载 URL
        // 5. 等待策略执行（waitPolicy）
        // 6. 提取 HTML（document.documentElement.outerHTML）
        // 7. 保存快照
        // 8. 返回结果
    }

    public func executeInteractionSteps(
        request: RuntimeWebViewRequest,
        scripts: [RuntimeWebViewScript]
    ) async -> [RuntimeWebViewInteractionResult] {
        // 通过 WKWebView.evaluateJavaScript 执行交互脚本
    }

    public func release() async {
        webView?.stopLoading()
    }
}
```

### 4.3 安全策略

**RuntimeWebViewSecurityConstraints**（已有）:
- `allowedHosts`: 白名单 host
- `blockedHosts`: 黑名单 host
- `maxNavigationCount`: 最大导航次数
- `allowExternalNavigation`: 是否允许外部跳转
- `allowPopup`: 是否允许弹窗
- `allowDownload`: 是否允许下载

**Adapter 额外约束**:
```swift
// 禁止行为
- 任意外部 host 跳转（只能在 allowedHosts 内）
- 自动翻页/批量章节
- 批量导航
- WAF 绕过
```

### 4.4 等待策略实现

```swift
// RuntimeWebViewWaitPolicy 等待策略
public enum InitialWaitStrategy {
    case domContentLoaded   // DOMContentLoaded 事件
    case load               // window.load 事件
    case networkIdle        // networkidle 2 秒
    case elementExists       // querySelector 等待
    case javascriptExpression // JS 表达式为真
    case customScript       // 自定义脚本
}

// 实现
switch waitPolicy.initialWaitStrategy {
case .domContentLoaded:
    await webView.evaluateJavaScript("document.readyState")
case .networkIdle:
    await waitForNetworkIdle(timeoutMs: waitPolicy.networkIdleTimeoutMs)
case .elementExists:
    await waitForElement(selector: waitPolicy.elementSelector)
}
```

### 4.5 HTML 提取

```swift
func extractRenderedHTML() async -> String? {
    let script = "document.documentElement.outerHTML"
    let result = await webView.evaluateJavaScript(script)
    return result as? String
}
```

### 4.6 快照保存

```swift
func saveSnapshot(request: RuntimeWebViewRequest, html: String) async throws -> String {
    let snapshotId = "\(request.sourceId)_\(request.stage.rawValue)_\(Date().timeIntervalSince1970)"
    let filePath = "\(configuration.snapshotRootDirectory)/\(snapshotId).html"
    try Data(html.utf8).write(to: URL(fileURLWithPath: filePath))
    return filePath
}
```

---

## 五、实现计划

### 阶段 1: 基础框架（1 天）

**文件**: `Reader-Core/Core/Sources/ReaderPlatformAdapters/WKWebViewRuntimeAdapter.swift`

- [ ] 创建 `WKWebViewRuntimeAdapter` 类
- [ ] 实现 `RuntimeWebViewExecutorProtocol`
- [ ] 实现 `supportsFeature` / `capabilities`
- [ ] 实现基础 `execute` 框架

### 阶段 2: WKWebView 生命周期（1 天）

- [ ] 创建/配置 `WKWebView`
- [ ] 实现 `WKNavigationDelegate`
- [ ] 处理页面加载事件
- [ ] 处理导航限制（allowedHosts, maxNavigationCount）
- [ ] 实现 `release()` 清理

### 阶段 3: 等待策略（1 天）

- [ ] 实现 `InitialWaitStrategy` 各变体
- [ ] 实现网络空闲检测
- [ ] 实现元素等待
- [ ] 实现 JS 表达式等待

### 阶段 4: HTML 提取与快照（0.5 天）

- [ ] 实现 `document.documentElement.outerHTML` 提取
- [ ] 实现快照保存
- [ ] 实现 `executeInteractionSteps`

### 阶段 5: 安全与审计（0.5 天）

- [ ] 集成 `RuntimeWebViewSecurityValidator`
- [ ] 实现审计日志
- [ ] 实现错误处理

### 阶段 6: 测试（1 天）

- [ ] 创建 `WKWebViewRuntimeAdapterTests`
- [ ] 使用本地 HTML fixture 测试
- [ ] Mock WKWebView 测试协议对齐

---

## 六、测试策略

### 6.1 本地 HTML Fixture 测试

```swift
// 测试用例
func testExtractHTMLFromLocalFixture() async {
    let adapter = WKWebViewRuntimeAdapter()
    let html = """
    <html><body><h1>Test</h1></body></html>
    """
    // 使用 WKWebView 加载本地 HTML
    // 验证 HTML 提取正确
}
```

### 6.2 Mock 测试

由于无法在 macOS 上测试真实 WKWebView，使用 Mock：
```swift
final class MockWKWebViewRuntimeAdapter: RuntimeWebViewExecutorProtocol {
    var executeCallCount = 0
    var lastRequest: RuntimeWebViewRequest?

    func execute(request: RuntimeWebViewRequest) async -> RuntimeWebViewResult {
        executeCallCount += 1
        lastRequest = request
        return RuntimeWebViewResult.success(...)
    }
}
```

### 6.3 真实 URL 测试

**必须用户单独授权**，且只能单 URL、单次请求。

---

## 七、文件清单

### 新增文件

| 文件 | 说明 |
|------|------|
| `Reader-Core/Core/Sources/ReaderPlatformAdapters/WKWebViewRuntimeAdapter.swift` | 核心 adapter 实现 |
| `Reader-Core/Core/Tests/ReaderPlatformAdaptersTests/WKWebViewRuntimeAdapterTests.swift` | 测试 |
| `docs/WEBVIEW_RUNTIME_ADAPTER_PLAN.md` | 本文档 |
| `docs/WEBVIEW_RUNTIME_SECURITY_BOUNDARY.md` | 安全边界文档 |
| `docs/READER_CORE_WEBVIEW_ADAPTER_INTEGRATION.md` | 集成文档 |

### 修改文件

| 文件 | 说明 |
|------|------|
| `Reader-Core/Core/Sources/ReaderPlatformAdapters/ReaderPlatformAdapters.swift` | 导出新 adapter |
| `Reader-Core/Core/Sources/ReaderPlatformAdapters/Package.swift` | 添加 WebKit 依赖 |

---

## 八、约束确认

| 约束 | 状态 |
|------|------|
| 不修改 NonJS Parser Core | ✅ 确认 |
| 不在 Core 模块 import WebKit/UIKit | ⚠️ 需要讨论（方案 A 会违反） |
| 在 iOS 层实现真实 WKWebView | ✅ 确认 |
| 与 RuntimeWebViewExecutorProtocol 对齐 | ✅ 确认 |
| 支持 allowedHost 校验 | ✅ 确认 |
| 支持 maxNavigationCount | ✅ 确认 |
| 禁止外部跳转 | ✅ 确认 |
| 禁止 popup | ✅ 确认 |
| 禁止下载 | ✅ 确认 |
| 支持 timeout | ✅ 确认 |
| 支持 DOM ready / delay wait | ✅ 确认 |
| 提取 document.documentElement.outerHTML | ✅ 确认 |
| 返回 rendered HTML | ✅ 确认 |
| 保存 snapshot | ✅ 确认 |
| 生成 audit event | ✅ 确认 |

---

## 九、决策点

### Decision 1: WebKit import 位置

**问题**: 如果将 adapter 放在 `ReaderPlatformAdapters` 模块，需要在该模块中 import WebKit。

**选项**:
1. **方案 A（推荐）**: 在 `ReaderPlatformAdapters` 中 import WebKit，通过条件编译（`#if canImport(WebKit)`）隔离 macOS 不支持
2. **方案 B**: 在 `Reader for iOS` 的 `CoreIntegration` 层实现 adapter，不影响 Reader-Core

**推荐**: 方案 A，因为：
- `ReaderPlatformAdapters` 本身就是平台特定实现的集合
- HTTP adapter 已经有 platform-specific 代码
- 可以被多个 iOS App 复用

---

## 十、下一步

1. **确认方案**: 用户确认采用方案 A（放在 `ReaderPlatformAdapters`）还是方案 B（放在 Reader for iOS）
2. **授权**: 用户授权后，开始实现
3. **真实 URL 测试**: 需要用户单独授权

---

*文档创建时间：2026-05-07*
*任务代码：DESIGN_IOS_WEBVIEW_RUNTIME_ADAPTER_INTEGRATION_PLAN*