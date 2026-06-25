# WEBVIEW_RUNTIME_READER_CORE_INTEGRATION_PLAN
## WebView Runtime Reader-Core 集成方案

**文档版本**: 1.0
**创建日期**: 2026-05-08
**仓库**: Reader for iOS (`/Users/minliny/Documents/Reader for iOS`)
**当前 HEAD**: `8de22ef894424c097ff1db7abd977fca4b49acdb`

---

## 一、架构概览

```
┌─────────────────────────────────────────────────────────────────┐
│                         Reader for iOS                            │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │                     App Layer                               │  │
│  │  (Features, Navigation, Surface, Modules)                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                            │                                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              CoreIntegration Layer                          │  │
│  │  ReadingFlowCoordinator                                    │  │
│  │  DefaultSearchService / TOCService / ContentService      │  │
│  └───────────────────────────────────────────────────────────┘  │
│                            │                                     │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │               ShellAssembly Layer                          │  │
│  │  (Factory wiring, concrete implementations)              │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                           Reader-Core                            │
│                                                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              ReaderCoreModels                               │  │
│  │  RuntimeWebViewExecutorProtocol                           │  │
│  │  RuntimeWebViewRequest                                    │  │
│  │  RuntimeWebViewResult                                     │  │
│  │  RuntimeWebViewSecurityConstraints                       │  │
│  │  iOSRuntimeWebViewExecutor (Core Logic)                 │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │            ReaderPlatformAdapters                           │  │
│  │  WKWebViewRuntimeAdapter ←── 真实 WebKit 执行            │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │            ReaderCoreProtocols                              │  │
│  │  SearchService / TOCService / ContentService             │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │            ReaderCoreParser                                 │  │
│  │  NonJS Parser Core (冻结)                                 │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 二、Reader for iOS 职责边界

### 2.1 应该做的

| 职责 | 说明 |
|------|------|
| WebView UI 宿主 | 提供 UIViewController 承载 WKWebView |
| 生命周期管理 | 管理 WebView 的创建、销毁、状态 |
| 授权 UI | 用户授权 WebView 运行时能力的 UI |
| Debug Harness | 调试和诊断 WebView 执行 |
| 调用 adapter | 调用 WKWebViewRuntimeAdapter |
| 展示结果 | 展示渲染后的 HTML 快照 |

### 2.2 不应该做的

| 职责 | 说明 | 原因 |
|------|------|------|
| 重复实现 WebView 业务逻辑 | 应委托给 adapter | 避免代码重复 |
| 重复实现安全验证 | 由 Core 负责 | 保持一致性 |
| 重复实现脚本构建 | 由 Core 负责 | 保持一致性 |
| 修改 Reader-Core | 应通过 PR/RFC | 保持 Core 冻结 |

---

## 三、如何依赖 ReaderPlatformAdapters

### 3.1 Package.swift 依赖

Reader for iOS 已经依赖 Reader-Core：

```swift
// iOS/Package.swift
dependencies: [
    // ... existing dependencies ...
    .package(
        name: "Reader-Core",
        path: "/Users/minliny/Documents/Reader-Core"
    )
]

targets: [
    .target(
        name: "ReaderApp",
        dependencies: [
            // ... existing dependencies ...
            "ReaderCoreModels",
            "ReaderPlatformAdapters"  // ← WebView adapter
        ]
    )
]
```

### 3.2 导入模块

```swift
import ReaderCoreModels    // DTO, Protocol
import ReaderPlatformAdapters  // WKWebViewRuntimeAdapter
```

---

## 四、如何调用 RuntimeWebViewExecutorProtocol

### 4.1 初始化 adapter

```swift
import ReaderPlatformAdapters

let adapter = WKWebViewRuntimeAdapter.strict(
    rootDirectory: snapshotDirectory,
    allowedHosts: [allowedHost],
    requireHttps: true
)
```

### 4.2 创建请求

```swift
import ReaderCoreModels

let request = RuntimeWebViewRequest(
    sourceId: "qianfanxs_001",
    sourceName: "千帆小说",
    url: "https://www.qianfanxs.com/9/9556",
    stage: .detail,
    waitPolicy: .standard(),
    scriptPolicy: .default(),
    snapshotRequired: true,
    snapshotPrefix: "qianfanxs_webview",
    securityRiskLevel: .high,
    authorization: authorization
)
```

### 4.3 执行

```swift
let result = await adapter.execute(request: request)

switch result {
case .success(let page):
    print("HTML length: \(page.html.count)")
    print("Final URL: \(page.finalUrl)")
case .failure(let error):
    print("Error: \(error.errorMessage)")
}
```

### 4.4 清理

```swift
await adapter.release()
```

---

## 五、WebView 生命周期管理

### 5.1 宿主视图控制器

```swift
import UIKit
import WebKit

final class WebViewHostViewController: UIViewController {

    private var webView: WKWebView?
    private let adapter: WKWebViewRuntimeAdapter

    init(adapter: WKWebViewRuntimeAdapter) {
        self.adapter = adapter
        super.init(nibName: nil, bundle: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
    }

    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: view.bounds, configuration: configuration)
        webView?.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(webView!)
    }

    deinit {
        Task {
            await adapter.release()
        }
    }
}
```

### 5.2 生命周期由 iOS 管理

```
┌─────────────────────────────────────────────┐
│           iOS App Lifecycle                 │
│  ┌─────────────────────────────────────┐  │
│  │ WebViewHostViewController            │  │
│  │  ├── viewDidLoad: setupWebView()    │  │
│  │  ├── viewWillDisappear: pause()     │  │
│  │  └── deinit: adapter.release()      │  │
│  └─────────────────────────────────────┘  │
└─────────────────────────────────────────────┘
```

---

## 六、如何回灌 Snapshot 到 Reader-Core Fixtures

### 6.1 执行流程

```
1. WebView 执行成功
2. 获取 rendered HTML
3. 保存 Snapshot
4. 提取到 Reader-Core fixtures
5. 运行 Parser 验证
```

### 6.2 Snapshot 结构

```
runtime_snapshots/
└── qianfanxs_9_9556/
    ├── response.html          # HTTP response snapshot
    └── rendered_detail.html   # WebView rendered snapshot
```

### 6.3 Fixture 格式

```json
{
  "sourceId": "qianfanxs_001",
  "stage": "detail",
  "url": "https://www.qianfanxs.com/9/9556",
  "renderedAt": "2026-05-08T10:00:00Z",
  "htmlSize": 40950,
  "title": "关于我家老婆是个傲娇这件事"
}
```

### 6.4 复制到 Reader-Core

```bash
cp Caches/WebViewHarness/Snapshots/qianfanxs_webview_detail_*.html \
  /Users/minliny/Documents/Reader-Core/samples/booksources/runtime_snapshots/qianfanxs_9_9556/rendered_detail.html
```

---

## 七、与 Security Gate 集成

### 7.1 SecurityGate 检查

```swift
import ReaderCoreModels

func executeWebView(sourceId: String, url: String, authorization: RuntimeAuthorization) async {
    // Security Gate 检查
    guard securityGate.isAuthorized(
        capability: .webView,
        authorization: authorization
    ) else {
        throw WebViewError.notAuthorized
    }

    // 执行
    let result = await adapter.execute(request: request)
}
```

### 7.2 授权验证

```swift
extension RuntimeAuthorization {
    var isValid: Bool {
        !revoked && expiresAt > Date()
    }

    var canExecuteWebView: Bool {
        isValid && capabilityAllowlist.contains(.webView)
    }
}
```

---

## 八、Debug Harness 与生产代码的关系

### 8.1 Debug Harness

| 文件 | 用途 | 编译条件 |
|------|------|----------|
| WebViewRuntimeHarnessView.swift | DEBUG-only UI | `#if DEBUG && canImport(WebKit)` |
| WebViewRuntimeHarnessViewModel.swift | DEBUG-only VM | `#if DEBUG && canImport(WebKit)` |

### 8.2 生产代码

| 文件 | 用途 | 编译条件 |
|------|------|----------|
| WebViewHostViewController | 生产 UI | 无条件 |
| WebViewAuthorizationView | 生产授权 UI | 无条件 |
| WebViewAuthorizationStore | 授权状态管理 | 无条件 |

### 8.3 代码复用

Debug Harness 和生产代码复用：
- `WKWebViewRuntimeAdapter` ✅
- `RuntimeWebViewRequest` ✅
- `RuntimeWebViewResult` ✅
- `RuntimeAuthorization` ✅

---

## 九、架构决策

### 9.1 为什么 adapter 放在 Reader-Core

| 理由 | 说明 |
|------|------|
| 复用性 | 可被多个 iOS App 复用 |
| 架构一致性 | 与 HTTP adapter 保持一致 |
| 边界清晰 | Core 业务逻辑 vs Platform 实现分离 |

### 9.2 为什么 iOS 层负责 UI 宿主

| 理由 | 说明 |
|------|------|
| UI 框架绑定 | 需要 UIKit/SwiftUI |
| 生命周期管理 | App 进程管理 |
| 授权 UI | 用户交互必须由 App 提供 |

---

## 十、实现检查清单

| 任务 | 状态 | 说明 |
|------|------|------|
| 依赖 ReaderPlatformAdapters | ✅ 已有 | Package.swift 已配置 |
| 调用 RuntimeWebViewExecutorProtocol | ✅ 已有 | WebViewRuntimeHarnessViewModel |
| WebView UI 宿主 | ⏳ 待开发 | WebViewHostViewController |
| 授权 UI | ⏳ 待开发 | WebViewAuthorizationView |
| Snapshot 回灌 | ⏳ 待开发 | 手动复制到 fixtures |
| Security Gate 集成 | ⏳ 待开发 | 集成到生产流程 |

---

## 十一、下一步

1. **实现 WebViewHostViewController**：iOS UI 宿主
2. **实现 WebViewAuthorizationView**：授权 UI
3. **集成 Security Gate**：生产流程中的安全检查
4. **实现 Snapshot 回灌**：自动化或手动复制到 fixtures
5. **测试 E2E**：完整流程测试

---

*文档创建时间：2026-05-08*
*版本：1.0*
*关联文档：WEBVIEW_RUNTIME_AUTH_UI_PLAN.md, WEBVIEW_RUNTIME_DEBUG_HARNESS_PLAN.md*
