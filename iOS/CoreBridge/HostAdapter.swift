import Foundation
import ReaderUIContract

/// HostAdapter — 平台能力执行层 facade。
///
/// 职责（CONTRACT_FIRST_NATIVE_UI_PLAN.md §7）：
/// - 收敛 HTTP / WebView / Cookie / file / credential / TTS / permission / background / notification / share
/// - 消费 contract `HostRequest`，返回结构化结果
/// - 不直接改 Core 或 UI 状态
///
/// 设计：
/// - 本 adapter 是 **facade**，不重写既有 `HostRequestRouter` / `URLSessionHTTPClient` 等。
/// - Slice 1：仅作为骨架，不实际执行（AppShell + main tabs 不依赖 Host 能力）。
/// - 后续 Phase 4（Host Adapter 补齐）按优先级落地：HTTP → Cookie → WebView → ...
///
/// 既有平台能力（被 facade 包装，Phase 4 落地时注入）：
/// - `HostRequestRouter` — Core host.request (http.execute) 路由
/// - `URLSessionHTTPClient` — HTTP 实际执行
/// - `ProductionWebViewAdapter` — WebView 登录/captcha/Cookie/DOM
/// - `WebDAVKeychainStore` — 凭证存储
/// - `ReaderTTSPlayer` — 系统 TTS
@MainActor
public final class HostAdapter {
    /// 既有 HTTP 路由器。Slice 1 阶段可为 nil（不依赖 HTTP 的场景）。
    /// Phase 4 落地时由外部注入（类型擦除为 Any）。
    private let httpRouterBox: AnyObject?

    /// 类型擦除初始化器，避免在 Slice 1 阶段绑定具体 `HostRequestRouter` 类型
    /// （该类型在 `ReaderCoreNativeAdapter` target 中，跨 target 引用留给 Phase 4 落地）。
    public init(httpRouter: AnyObject? = nil) {
        self.httpRouterBox = httpRouter
    }

    // MARK: - Slice 1 占位（不依赖 Host，slice 1 不调用）

    /// 派发 contract `HostRequest`。
    ///
    /// Slice 1：仅作为骨架。Phase 4 按优先级落地各能力。
    /// 返回值为 `true` 表示已派发（骨架阶段不实际执行），`false` 表示能力未落地。
    @discardableResult
    public func send(_ request: HostRequest) async -> Bool {
        switch request.type {
        case .http_execute, .http_cancel:
            // Phase 4 优先级 1：HTTP
            return false
        case .webview_open, .webview_close, .webview_evaluate:
            // Phase 4 优先级 3：WebView
            return false
        case .cookie_get, .cookie_set, .cookie_clear:
            // Phase 4 优先级 2：Cookie
            return false
        case .file_read, .file_write, .file_delete, .storage_path:
            // Phase 4 优先级 4：File/storage
            return false
        case .credential_get, .credential_set, .credential_delete:
            // Phase 4 优先级 5：Credential
            return false
        case .tts_system_start, .tts_system_stop, .tts_system_pause, .tts_system_resume:
            // Phase 4 优先级 6：TTS
            return false
        case .permission_request, .permission_check:
            // Phase 4 优先级 7：Permission
            return false
        case .background_schedule, .background_cancel:
            return false
        case .notification_show, .notification_cancel, .share_invoke,
             .clipboard_copy, .clipboard_paste,
             .device_vibrate, .device_screen_keep_on, .device_screen_release:
            // Phase 4 优先级 8：Notification / share / clipboard / device
            return false
        }
    }
}
