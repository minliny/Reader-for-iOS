# READER_CORE_WEBVIEW_ADAPTER_INTEGRATION
## Reader-Core WebView Adapter 集成指南

**文档版本**: 1.0
**创建日期**: 2026-05-07
**关联**: WEBVIEW_RUNTIME_ADAPTER_PLAN.md, WEBVIEW_RUNTIME_SECURITY_BOUNDARY.md

---

## 一、架构概览

```
┌─────────────────────────────────────────────────────────────┐
│                      Reader for iOS                         │
│  ┌─────────────────────────────────────────────────────┐    │
│  │                    App Layer                        │    │
│  │  (Features, Navigation, Surface, Modules)          │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │              CoreIntegration Layer                   │    │
│  │  ReadingFlowCoordinator                              │    │
│  │  DefaultSearchService / TOCService / ContentService │    │
│  └─────────────────────────────────────────────────────┘    │
│                           │                                 │
│  ┌─────────────────────────────────────────────────────┐    │
│  │               ShellAssembly Layer                    │    │
│  │  (Factory wiring, concrete implementations)        │    │
│  └─────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│                      Reader-Core                            │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              ReaderCoreModels                         │   │
│  │  RuntimeWebViewExecutorProtocol                      │   │
│  │  RuntimeWebViewRequest                               │   │
│  │  RuntimeWebViewResult                                │   │
│  │  RuntimeWebViewSecurityConstraints                   │   │
│  │  iOSRuntimeWebViewExecutor (Core Logic)              │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            ReaderPlatformAdapters                    │   │
│  │  WKWebViewRuntimeAdapter ←── NEW                    │   │
│  │  (真实 iOS WKWebView 执行)                          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            ReaderCoreProtocols                       │   │
│  │  SearchService / TOCService / ContentService        │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │            ReaderCoreParser                           │   │
│  │  NonJS Parser Core (冻结)                            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

---

## 二、集成路径

### 2.1 当前状态

Reader-Core 已有：
- `RuntimeWebViewExecutorProtocol` - 执行器协议
- `RuntimeWebViewRequest` - 请求模型
- `RuntimeWebViewResult` - 结果模型
- `iOSRuntimeWebViewExecutor` - Core Layer 逻辑（安全验证、快照保存）
- `MockRuntimeWebViewExecutor` - Mock 实现

**缺失**：真实 WKWebView 执行器

### 2.2 目标状态

`WKWebViewRuntimeAdapter` 实现 `RuntimeWebViewExecutorProtocol`：
- 位置：`Reader-Core/Core/Sources/ReaderPlatformAdapters/`
- 能力：真实 iOS WKWebView 执行
- 依赖：WebKit（iOS 平台特定）

### 2.3 集成层次

```
iOSRuntimeWebViewExecutor (Core Logic)
    │
    ├── 安全验证 ✓
    ├── 脚本构建 ✓
    ├── 快照保存 ✓
    └── 审计日志 ✓
            │
            ▼
    WKWebViewRuntimeAdapter (Platform Adapter)
            │
            ├── WKWebView 生命周期管理
            ├── WKNavigationDelegate
            ├── JavaScript 执行
            └── HTML 提取
```

---

## 三、使用方式

### 3.1 初始化

```swift
import ReaderPlatformAdapters

let adapter = WKWebViewRuntimeAdapter(
    configuration: .default
)
```

### 3.2 创建请求

```swift
import ReaderCoreModels

let request = RuntimeWebViewRequest(
    sourceId: "qianfanxs_001",
    sourceName: "千帆小说",
    url: "https://www.qianfanxs.com/9/9556",
    stage: .content,
    waitPolicy: .standard(),
    snapshotRequired: true,
    snapshotPrefix: "qianfanxs_detail",
    securityRiskLevel: .high,
    authorization: RuntimeAuthorization(...)
)
```

### 3.3 执行

```swift
let result = await adapter.execute(request: request)

switch result {
case .success(let page):
    print("HTML length: \(page.html.count)")
    print("Final URL: \(page.finalURL)")
case .failure(let error):
    print("Error: \(error.errorMessage)")
}
```

### 3.4 资源清理

```swift
await adapter.release()
```

---

## 四、与现有组件的关系

### 4.1 与 iOSRuntimeWebViewExecutor 的关系

`iOSRuntimeWebViewExecutor` 包含 Core Layer 逻辑：
- 安全验证（`RuntimeWebViewSecurityValidator`）
- 脚本构建（`buildInteractionScriptContent`）
- 快照写入（`RuntimeSnapshotWriter`）

`WKWebViewRuntimeAdapter` 负责：
- 真实 WKWebView 生命周期管理
- URL 加载
- JavaScript 执行
- HTML 提取

**设计决策**：`WKWebViewRuntimeAdapter` 可以：
1. **组合 iOSRuntimeWebViewExecutor**：复用安全验证、快照保存逻辑
2. **独立实现**：直接实现 `RuntimeWebViewExecutorProtocol`

**推荐**：方案 1（组合），因为：
- 复用经过验证的安全验证逻辑
- 减少代码重复
- 保持一致的行为

### 4.2 与 ShellAssembly 的集成

在 `ShellAssembly` 中注册 adapter：

```swift
// ShellAssembly.swift
import ReaderPlatformAdapters
import ReaderCoreModels

final class ShellAssembly {
    func makeWebViewExecutor() -> RuntimeWebViewExecutorProtocol {
        WKWebViewRuntimeAdapter(configuration: .default)
    }
}
```

### 4.3 与 SecurityGate 的集成

`WKWebViewRuntimeAdapter` 必须通过 `SecurityGate` 授权：

```swift
// 使用前必须授权
let authorization = try await securityGate.authorize(
    capability: .webView,
    sourceId: source.id,
    requestUrl: url
)

let request = RuntimeWebViewRequest(
    sourceId: source.id,
    sourceName: source.name,
    url: url,
    authorization: authorization,
    // ...
)

let result = await adapter.execute(request: request)
```

---

## 五、适配 Rust API

如果 Reader-Core 最终需要 Rust 实现：

```
Swift: WKWebViewRuntimeAdapter
  └── Protocol: RuntimeWebViewExecutorProtocol
        └── Core Logic: iOSRuntimeWebViewExecutor (Swift)

Rust: WkWebViewExecutor
  └── Protocol: RuntimeWebViewExecutorProtocol (CXX)
        └── Core Logic: iOSRuntimeWebViewExecutor (Swift)
```

---

## 六、测试策略

### 6.1 单元测试

```swift
func testWKWebViewRuntimeAdapterProtocolConformance() {
    let adapter = WKWebViewRuntimeAdapter()
    XCTAssertTrue(adapter is RuntimeWebViewExecutorProtocol)
    XCTAssertEqual(adapter.executorName, "WKWebViewRuntimeAdapter")
}
```

### 6.2 集成测试

```swift
func testWebViewLoadLocalHTML() async {
    let adapter = WKWebViewRuntimeAdapter()
    let html = "<html><body><h1>Test</h1></body></html>"

    // 加载本地 HTML
    let result = await adapter.execute(request: request)

    XCTAssertTrue(result.isSuccess)
}
```

### 6.3 安全测试

```swift
func testExternalNavigationBlocked() async {
    let adapter = WKWebViewRuntimeAdapter()
    let request = RuntimeWebViewRequest(
        sourceId: "test",
        sourceName: "Test",
        url: "https://allowed.example.com",
        securityConstraints: RuntimeWebViewSecurityConstraints(
            allowedHosts: ["allowed.example.com"],
            allowExternalNavigation: false
        )
    )

    // 尝试导航到外部 URL 应该被阻止
    // ...
}
```

---

## 七、部署注意事项

### 7.1 WebKit 依赖

`WKWebViewRuntimeAdapter` 需要 `import WebKit`：
- iOS 15+ 支持
- macOS 11+ 支持（通过 Mac Catalyst 或 macOS 版 WKWebView）

### 7.2 条件编译

```swift
#if canImport(WebKit)
import WebKit
#endif

public final class WKWebViewRuntimeAdapter: RuntimeWebViewExecutorProtocol {
    // ...
}
```

### 7.3 后台执行限制

- WKWebView 在后台会被暂停
- 需要注意 `UIApplication.shared.isIdleTimerDisabled`

---

## 八、版本兼容性

| iOS 版本 | WKWebViewRuntimeAdapter 支持 |
|----------|------------------------------|
| iOS 15+  | ✅ 完全支持 |
| iOS 14   | ⚠️ 部分功能受限 |
| iOS 13   | ❌ 不支持（无 `WKWebView.websiteDataRecord`） |

---

*文档创建时间：2026-05-07*
*版本：1.0*