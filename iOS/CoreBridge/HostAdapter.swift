import Foundation
import ReaderCoreProtocols
import ReaderCoreNetwork
import ReaderUIContract

#if canImport(WebKit) && canImport(UIKit)
import WebKit
import UIKit
#endif

/// HostAdapter — 平台能力执行层 facade。
///
/// 职责(CONTRACT_FIRST_NATIVE_UI_PLAN.md §7):
/// - 收敛 HTTP / WebView / Cookie / file / credential / TTS / permission /
///   background / notification / share / clipboard / device 能力
/// - 消费 contract `HostRequest`,派发到 `HostCapabilityRegistry`,返回
///   结构化 `HostCapabilityOutcome`
/// - 不直接改 Core 或 UI 状态
///
/// 设计:
/// - 本 adapter 是 **facade**:它持有一个 `HostCapabilityRegistry`,所有
///   UI/reducer 发起的 `HostRequest` 都经由 `dispatch(_:)` 派发到注册的
///   `HostCapabilityHandler`。
/// - `send(_:) -> Bool` 保留为向后兼容的薄包装,返回 `outcome.succeeded`。
///   新代码应使用 `dispatch(_:) -> HostCapabilityOutcome` 拿到完整结果。
/// - 既有 `HostRequestRouter`(Core 发起的 `host.request` 事件)与本 adapter
///   处于不同抽象层级:router 消费 `ReaderCoreNativeEvent`(C ABI),本 adapter
///   消费 `HostRequest`(contract 枚举)。两条路径并行存在。
///
/// 生产 wiring(默认 `init()`):
/// - `HostHttpCapability`(URLSessionHTTPClient)
/// - `HostWebViewCapability`(WKWebViewExecutor,iOS only;macOS 跳 notImplemented)
/// - `HostCookieCapability`(shared ScopedCookieJar)
/// - `HostFileCapability`(FileManager)
/// - `HostCredentialCapability`(Keychain / Security.framework)
/// - `HostClipboardCapability`(UIPasteboard / NSPasteboard)
/// - `HostTTSCapability`(synth provider 返回 nil —— 由 ReaderApp 注入
///   `ReaderTTSPlayer` 以避免 CoreBridge 依赖 ReaderApp target)
/// - `HostPermissionCapability`(UNUserNotificationCenter / AVFoundation / CoreLocation)
/// - `HostNotificationCapability`(UNUserNotificationCenter)
/// - `HostShareCapability`(presenter 返回 nil —— 由 ReaderApp 注入)
/// - `HostDeviceCapability`(UIImpactFeedbackGenerator / UIApplication)
@MainActor
public final class HostAdapter {
    /// 派发目标 —— 所有 capability handler 都注册在这里。
    private let registry: HostCapabilityRegistry

    /// 既有 HTTP 路由器,保留为向后兼容(Slice 1 阶段注入,Phase 4 之后由
    /// capability handler 取代)。新代码应使用 `registry`。
    private let httpRouterBox: AnyObject?

    /// 默认初始化器:注册全部 11 个 capability handler 的生产实现。
    ///
    /// TTS / Share 的 provider 返回 nil —— 这两个能力需要 ReaderApp target
    /// 中的具体类型(`ReaderTTSPlayer` / `UIActivityViewController` 包装器),
    /// 由 `HostAdapter.setTTSSynthProvider(_:)` / `setSharePresenterProvider(_:)`
    /// 在 app 启动时注入。在注入前,这两个 capability 返回 `.notImplemented`。
    public init(httpRouter: AnyObject? = nil) {
        self.httpRouterBox = httpRouter
        let registry = HostCapabilityRegistry()

        // 优先级 1:已落地的 router 能力(http/cookie/webview)。
        registry.register(HostHttpCapability(
            httpClient: URLSessionHTTPClient(cookieJar: RustCoreServiceSupport.sharedCookieJar)
        ))
        registry.register(HostCookieCapability(
            cookieJar: RustCoreServiceSupport.sharedCookieJar
        ))

        // WebView —— iOS only,macOS 注册 stub(返回 notImplemented)。
        #if canImport(WebKit) && canImport(UIKit)
        registry.register(HostWebViewCapability(executor: WKWebViewExecutor()))
        #else
        registry.register(HostWebViewCapability())
        #endif

        // 优先级 2:新落地的平台能力。
        registry.register(HostFileCapability())
        registry.register(HostCredentialCapability())
        registry.register(HostClipboardCapability())
        registry.register(HostTTSCapability(synthProvider: { nil }))
        registry.register(HostPermissionCapability())
        registry.register(HostNotificationCapability())
        registry.register(HostShareCapability(presenterProvider: { nil }))
        registry.register(HostDeviceCapability())

        self.registry = registry
    }

    /// 测试初始化器:接受外部注入的 registry(不注册默认 handler)。
    public init(registry: HostCapabilityRegistry) {
        self.registry = registry
        self.httpRouterBox = nil
    }

    // MARK: - Capability set

    /// 返回本 host 已通过 `HostCapabilityRegistry` 注册的全部能力对应的
    /// `HostRequestType`。
    ///
    /// 注意:UI contract 使用 `webview.evaluate`,router 使用
    /// `webview.evaluateJavaScript`,两者指代同一能力(Core/Host 边界的
    /// 历史命名差异)。本方法返回 contract 名义。
    public static func supportedCapabilities() -> [HostRequestType] {
        // 返回所有 31 个已注册 type 的名义列表(实际是否可用取决于平台
        // 与 provider 注入)。供 capability 检查 / 诊断 / 文档使用。
        return HostRequestType.allCases
    }

    /// 当前已注册(可派发)的 `HostRequestType` 集合。
    public func registeredTypes() -> Set<HostRequestType> {
        registry.registeredTypes()
    }

    /// 已注册 type 的 tier(simulator-proof / real-device-proof /
    /// cross-platform)。未注册返回 nil。
    public func tier(for type: HostRequestType) -> HostCapabilityTier? {
        registry.tier(for: type)
    }

    // MARK: - Dispatch

    /// 派发 contract `HostRequest` 到匹配的 capability handler,返回完整的
    /// `HostCapabilityOutcome`(包含 succeeded / result / error)。
    ///
    /// 这是 UI/reducer → Host 能力的主路径。返回值为 `.failure(.notConfigured(type))`
    /// 表示该能力未注册;为 `.failure(.notImplemented(type, message))` 表示
    /// handler 已注册但平台不支持(如 macOS swift build 下的 webview)。
    public func dispatch(_ request: HostRequest) async -> HostCapabilityOutcome {
        await registry.dispatch(request)
    }

    /// 向后兼容的薄包装:返回 `dispatch(request).succeeded`。
    ///
    /// 保留 `Bool` 返回值是因为 Slice 1 阶段的调用方期望此签名。新代码
    /// 应使用 `dispatch(_:)` 拿到完整结果。
    @discardableResult
    public func send(_ request: HostRequest) async -> Bool {
        let outcome = await dispatch(request)
        return outcome.succeeded
    }

    // MARK: - Provider injection (ReaderApp target)

    /// 注入 TTS synth provider。由 ReaderApp 在启动时调用,传入包装
    /// `ReaderTTSPlayer` 的 provider。注入前 `tts.system.*` 返回
    /// `.notImplemented`。
    public func setTTSSynthProvider(_ provider: @escaping @Sendable () async -> HostTTSSynth?) {
        // Re-register the TTS capability with the real provider.
        registry.register(HostTTSCapability(synthProvider: provider))
    }

    /// 注入 share presenter provider。由 ReaderApp 在启动时调用,传入包装
    /// `UIActivityViewController` 的 provider。注入前 `share.invoke` 返回
    /// `.notImplemented`。
    public func setSharePresenterProvider(_ provider: @escaping @Sendable () async -> HostSharePresenter?) {
        registry.register(HostShareCapability(presenterProvider: provider))
    }
}
