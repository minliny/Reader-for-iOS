# WEBVIEW_RUNTIME_AUTH_UI_PLAN
## WebView Runtime 授权 UI 方案

**文档版本**: 1.0
**创建日期**: 2026-05-08
**仓库**: Reader for iOS (`/Users/minliny/Documents/Reader for iOS`)
**当前 HEAD**: `8de22ef894424c097ff1db7abd977fca4b49acdb`

---

## 一、为什么需要显式授权

### 1.1 风险来源

WebView Runtime 执行涉及以下风险：

| 风险类型 | 说明 | 缓解措施 |
|----------|------|----------|
| XSS | 执行任意 JS 可能导致跨站脚本攻击 | 沙箱化、脚本白名单 |
| 钓鱼 | 渲染恶意页面模拟登录界面 | HTTPS 要求、host 白名单 |
| 数据泄露 | 页面可访问 localStorage/Cookie | 禁止 localStorage、snapshot 不含敏感数据 |
| 资源滥用 | 批量抓取、递归导航 | maxNavigationCount 限制 |
| 隐私 | 执行外部网页可能收集用户信息 | 用户知情同意 |

### 1.2 默认拒绝原则

根据安全门禁原则：
- **默认禁用**：WebView 运行时能力默认关闭
- **显式授权**：用户必须明确授权才能启用
- **最小权限**：只授权必要的 host 和能力
- **可撤销**：用户可随时撤销授权

---

## 二、授权 UI 字段

### 2.1 来源信息

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| source_id | String | 书源唯一 ID | `qianfanxs_001` |
| source_name | String | 书源显示名称 | `千帆小说` |

### 2.2 目标信息

| 字段 | 类型 | 说明 | 示例 |
|------|------|------|------|
| url | String | 目标 URL | `https://www.qianfanxs.com/9/9556` |
| allowed_host | String | 授权的 host | `www.qianfanxs.com` |

### 2.3 执行约束

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| stage | RuntimeStage | `.content` | 执行阶段 |
| maxNavigationCount | Int | `1` | 最大导航次数 |
| requireHttps | Bool | `true` | 是否要求 HTTPS |
| allowExternalNavigation | Bool | `false` | 是否允许外部导航 |
| allowPopup | Bool | `false` | 是否允许弹窗 |
| allowDownload | Bool | `false` | 是否允许下载 |
| requireSnapshot | Bool | `true` | 是否需要快照 |
| requireAudit | Bool | `true` | 是否需要审计 |

### 2.4 RuntimeAuthorization 构造

```swift
import ReaderCoreModels

let authorization = RuntimeAuthorization(
    authorizationId: UUID().uuidString,
    capabilityAllowlist: [.webView],
    allowedHosts: [allowedHost],
    grantedBy: "user",
    grantedAt: Date(),
    expiresAt: Date().addingTimeInterval(3600), // 1小时
    revoked: false
)
```

---

## 三、授权 UI 设计

### 3.1 UI 组件结构

```
WebViewAuthorizationView
├── SourceInfoSection: sourceId, sourceName
├── TargetInfoSection: url, allowedHost
├── RiskWarningSection: 风险提示
├── ConstraintsSection: 执行约束
└── ConfirmButton: 授权并执行
```

### 3.2 核心视图

```swift
import SwiftUI

struct WebViewAuthorizationView: View {
    let sourceId: String
    let sourceName: String
    let targetUrl: String
    let onAuthorize: (RuntimeAuthorization) -> Void
    let onCancel: () -> Void

    @State private var isLoading = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    sourceInfoSection
                    targetInfoSection
                    riskWarningSection
                    constraintsSection
                    confirmButton
                }
                .padding()
            }
            .navigationTitle("WebView 授权")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { onCancel() }
                }
            }
        }
    }
}
```

### 3.3 来源信息区

| 字段 | 用户可见 |
|------|----------|
| 书源名称 | ✅ |
| 书源 ID | ✅（内部） |

### 3.4 目标信息区

| 字段 | 用户可见 |
|------|----------|
| URL | ✅ |
| 授权 Host | ✅ |

### 3.5 风险提示区

**WebView 将执行**：
- 加载并渲染目标网页
- 执行页面中的 JavaScript
- 提取页面 HTML 内容
- 保存页面快照用于后续离线阅读

**WebView 不会执行**：
- 任意导航到其他网站
- 访问 localStorage 或 Cookie
- 下载文件或打开弹窗

### 3.6 约束配置区

| 约束项 | 值 | 用户可见 |
|--------|-----|----------|
| maxNavigationCount | 1 | ✅ |
| requireHttps | true | ✅ |
| allowExternalNavigation | false | ✅ |
| allowPopup | false | ✅ |
| allowDownload | false | ✅ |
| requireSnapshot | true | ✅ |
| requireAudit | true | ❌（内部） |

---

## 四、授权数据流

### 4.1 授权流程

```
1. 用户进入书源详情页
2. 点击需要 WebView 的功能（如 SPA 内容加载）
3. 显示 WebViewAuthorizationView
4. 用户查看来源、目标、风险、约束
5. 用户点击"授权并执行"
6. 创建 RuntimeAuthorization
7. 回调 onAuthorize(authorization)
8. WebViewHostVC 使用授权执行
```

### 4.2 数据存储

授权信息不持久化存储，每次使用需要用户重新授权。

```swift
final class WebViewAuthorizationStore: ObservableObject {
    @Published var currentAuthorization: RuntimeAuthorization?

    func authorize(sourceId: String, url: String) -> RuntimeAuthorization {
        let host = URL(string: url)?.host ?? ""
        let authorization = RuntimeAuthorization(
            authorizationId: UUID().uuidString,
            capabilityAllowlist: [.webView],
            allowedHosts: [host],
            grantedBy: "user",
            grantedAt: Date(),
            expiresAt: Date().addingTimeInterval(3600),
            revoked: false
        )
        self.currentAuthorization = authorization
        return authorization
    }

    func revoke() {
        currentAuthorization?.revoked = true
        currentAuthorization = nil
    }
}
```

---

## 五、约束确认清单

| 约束项 | 值 | 用户可见 |
|--------|-----|----------|
| maxNavigationCount | 1 | ✅ |
| requireHttps | true | ✅ |
| allowExternalNavigation | false | ✅ |
| allowPopup | false | ✅ |
| allowDownload | false | ✅ |
| requireSnapshot | true | ✅ |
| requireAudit | true | ❌（内部） |

---

## 六、实现检查清单

| 任务 | 状态 | 说明 |
|------|------|------|
| WebViewAuthorizationView | ⏳ 待开发 | 授权 UI |
| WebViewAuthorizationStore | ⏳ 待开发 | 授权状态管理 |
| RuntimeAuthorization 构造 | ✅ 已有 | WebViewRuntimeHarnessViewModel |
| 约束验证 | ✅ 已有 | WebViewRuntimeHarnessViewModel.validateSecurityConstraints() |
| 撤销功能 | ⏳ 待开发 | 设置中撤销授权 |

---

## 七、下一步

1. **实现 WebViewAuthorizationView**：参考本文档设计
2. **实现 WebViewAuthorizationStore**：管理当前授权状态
3. **集成到导航流程**：从书源详情 → 授权 → WebView 执行
4. **测试**：验证授权 UI 和执行流程

---

*文档创建时间：2026-05-08*
*版本：1.0*
*关联文档：WEBVIEW_RUNTIME_DEBUG_HARNESS_PLAN.md, WEBVIEW_RUNTIME_READER_CORE_INTEGRATION_PLAN.md*
