# WEBVIEW_RUNTIME_SECURITY_BOUNDARY
## WebView Runtime 安全边界规范

**文档版本**: 1.0
**创建日期**: 2026-05-07
**关联**: WEBVIEW_RUNTIME_ADAPTER_PLAN.md

---

## 一、安全原则

1. **最小权限**: WebView adapter 只授权必要的能力
2. **白名单优先**: 默认拒绝，只允许明确声明的 host
3. **强制审计**: 所有操作必须生成 audit event
4. **可禁用开关**: 全局 + per-source 开关

---

## 二、强制禁止行为

| 行为 | 原因 |
|------|------|
| 任意 JS 执行 | XSS 风险 |
| 任意文件访问 | 读取本地文件 |
| 任意外部 host 跳转 | 安全边界突破 |
| 自动批量抓取 | 资源滥用 |
| 自动翻页 | 资源滥用 |
| 批量章节获取 | 资源滥用 |
| WAF 绕过 | 合规问题 |
| 自动重试 | 资源滥用 |
| 下载文件 | 安全风险 |
| 打开 popup | 安全风险 |

---

## 三、允许行为

| 行为 | 条件 |
|------|------|
| 加载 allowedHosts 内的 URL | 必须通过 SecurityGate |
| 提取 rendered HTML | 只允许 document.documentElement.outerHTML |
| 执行 user-provided interaction scripts | 只允许 pre-approved script types |
| 保存 snapshot | 必须通过 SnapshotGate |
| 生成 audit event | 所有操作必须 |

---

## 四、RuntimeWebViewSecurityConstraints（已有）

```swift
public struct RuntimeWebViewSecurityConstraints: Codable, Equatable, Sendable {
    let allowedHosts: [String]          // 白名单 host
    let blockedHosts: [String]          // 黑名单 host
    let maxNavigationCount: Int          // 最大导航次数（默认 1）
    let allowExternalNavigation: Bool   // 是否允许外部跳转（默认 false）
    let allowPopup: Bool                 // 是否允许弹窗（默认 false）
    let allowDownload: Bool              // 是否允许下载（默认 false）
    let requireHttps: Bool               // 是否要求 HTTPS（默认 true）
    let userAgent: String?               // 自定义 User-Agent
}
```

---

## 五、Adapter 实现要求

### 5.1 导航限制

```swift
// 伪代码
func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) {
    guard let url = navigationAction.request.url,
          let host = url.host else {
        decisionHandler(.cancel)
        return
    }

    // 检查 host 是否在白名单
    guard constraints.allowedHosts.contains(host) else {
        auditEvent(.blockedHost, host: host)
        decisionHandler(.cancel)
        return
    }

    // 检查是否超过最大导航次数
    guard currentNavigationCount < constraints.maxNavigationCount else {
        auditEvent(.navigationLimitExceeded)
        decisionHandler(.cancel)
        return
    }

    decisionHandler(.allow)
}
```

### 5.2 弹窗限制

```swift
func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction) {
    // 禁止弹窗
    if !constraints.allowPopup {
        auditEvent(.popupBlocked)
        return nil
    }
    // ...
}
```

### 5.3 下载限制

```swift
func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) {
    if let mimeType = navigationResponse.response.mimeType,
       mimeType.contains("application/") ||
       mimeType.contains("image/") && !mimeType.contains("image/html") {
        if !constraints.allowDownload {
            auditEvent(.downloadBlocked, mimeType: mimeType)
            decisionHandler(.cancel)
            return
        }
    }
    decisionHandler(.allow)
}
```

### 5.4 HTTPS 要求

```swift
if constraints.requireHttps {
    guard url.scheme == "https" else {
        auditEvent(.httpNotAllowed, url: url)
        decisionHandler(.cancel)
        return
    }
}
```

---

## 六、Audit Event 规范

### 6.1 必须记录的事件

| 事件 | 触发条件 |
|------|----------|
| `webViewExecutionStarted` | 开始执行 |
| `webViewNavigationAllowed` | 导航允许 |
| `webViewNavigationBlocked` | 导航被阻止 |
| `webViewHostBlocked` | host 不在白名单 |
| `webViewExternalNavigationBlocked` | 外部导航被阻止 |
| `webViewPopupBlocked` | 弹窗被阻止 |
| `webViewDownloadBlocked` | 下载被阻止 |
| `webViewHttpsRequired` | HTTP 被拒绝 |
| `webViewNavigationLimitExceeded` | 超过最大导航次数 |
| `webViewHtmlExtracted` | HTML 提取成功 |
| `webViewSnapshotSaved` | 快照保存成功 |
| `webViewExecutionCompleted` | 执行完成 |
| `webViewExecutionFailed` | 执行失败 |

### 6.2 Audit Event 格式

```swift
struct RuntimeAuditEvent {
    let requestId: String
    let sourceId: String
    let eventType: RuntimeAuditEventType
    let actor: String  // "WKWebViewRuntimeAdapter"
    let allowed: Bool
    let reason: String
    let targetHost: String?
    let method: String
    let requestUrl: String
    let securityRiskLevel: RuntimeSecurityRiskLevel
    let capabilityRequirements: CapabilityRequirement
    let details: [String: String]
}
```

---

## 七、快照安全

### 7.1 快照内容

- 只保存 `document.documentElement.outerHTML`
- 不保存 localStorage / sessionStorage
- 不保存 Cookie
- 不保存 cache

### 7.2 快照路径

- 默认路径: `Caches/ReaderCore/Snapshots/`
- 路径格式: `{sourceId}_{stage}_{timestamp}.html`
- 命名不允许包含敏感信息

### 7.3 快照元数据

```swift
struct WebViewSnapshotMetadata {
    let snapshotId: String
    let sourceId: String
    let requestId: String
    let stage: RuntimeStage
    let requestUrl: String
    let finalUrl: String
    let charset: String
    let bodySizeBytes: Int
    let fetchedAt: Date
    let securityConstraintsUsed: RuntimeWebViewSecurityConstraints
}
```

---

## 八、测试要求

### 8.1 本地测试

- 使用本地 HTML fixture
- 验证 HTML 提取正确
- 验证安全约束生效

### 8.2 Mock 测试

- Mock WKWebView 行为
- 验证协议对齐
- 验证错误处理

### 8.3 真实 URL 测试

**必须用户单独授权**，格式：
```
AUTHORIZE_WEBVIEW_RUNTIME_REAL_URL
URL: https://example.com/book
Scope: single_url_single_request
Valid: 24 hours
```

---

## 九、合规检查

Adapter 实现必须通过以下检查：

- [ ] 所有导航通过 `allowedHosts` 白名单验证
- [ ] `maxNavigationCount` 限制生效
- [ ] `allowExternalNavigation=false` 时外部跳转被阻止
- [ ] `allowPopup=false` 时弹窗被阻止
- [ ] `allowDownload=false` 时下载被阻止
- [ ] HTTP URL 在 `requireHttps=true` 时被拒绝
- [ ] 所有操作生成 audit event
- [ ] 快照不包含 localStorage/sessionStorage/Cookie

---

*文档创建时间：2026-05-07*
*版本：1.0*