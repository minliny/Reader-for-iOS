import Foundation
import ReaderCoreModels

#if canImport(WebKit) && canImport(UIKit)
import WebKit
import UIKit

/// Production WKWebView adapter conforming to RuntimeWebViewExecutorProtocol.
/// Execution is gated by WebViewSecurityGate; defaults to disabled (safe).
@MainActor
public final class ProductionWebViewAdapter: RuntimeWebViewExecutorProtocol, @unchecked Sendable {

    public let executorId = "ios.production.webview"
    public let executorName = "Production WKWebView Adapter"

    let securityGate: WebViewSecurityGate
    private var webView: WKWebView?
    private(set) var lastSnapshot: WebViewExecutionSnapshot?

    public init(securityGate: WebViewSecurityGate = WebViewSecurityGate()) {
        self.securityGate = securityGate
        if Thread.isMainThread {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            self.webView = WKWebView(frame: .zero, configuration: config)
        }
    }

    // MARK: - Policy

    public func updatePolicy(_ policy: WebViewSecurityPolicy) {
        securityGate.updatePolicy(policy)
    }

    public var webViewPolicy: WebViewSecurityPolicy {
        securityGate.policy
    }

    // MARK: - RuntimeWebViewExecutorProtocol

    public func supportsFeature(_ feature: RuntimeWebViewFeature) -> Bool {
        switch feature {
        case .pageSnapshot, .customUserAgent: return true
        default: return false
        }
    }

    public func capabilities() -> RuntimeWebViewExecutorCapabilities {
        RuntimeWebViewExecutorCapabilities(
            supportedFeatures: [.pageSnapshot, .customUserAgent],
            maxConcurrentExecutions: 1,
            supportsSnapshot: true,
            supportsOfflineMode: false,
            supportsLoginFlow: false,
            version: "0.1.0"
        )
    }

    public func execute(request: RuntimeWebViewRequest) async -> RuntimeWebViewResult {
        if let rejection = securityGate.validate(request: request) {
            lastSnapshot = rejection
            return RuntimeWebViewResult(
                requestId: request.requestId,
                sourceId: request.sourceId,
                sourceName: request.sourceName,
                originalUrl: request.url,
                finalUrl: request.url,
                stage: request.stage,
                success: false,
                errorMessage: rejection.errorMessage ?? "Security policy rejected",
                errorType: .authorizationMissing,
                html: "",
                title: nil,
                metadata: RuntimeWebViewMetadata(),
                snapshotId: nil,
                snapshotFilePath: nil
            )
        }

        lastSnapshot = securityGate.allowedSnapshot(for: request)
        return RuntimeWebViewResult(
            requestId: request.requestId,
            sourceId: request.sourceId,
            sourceName: request.sourceName,
            originalUrl: request.url,
            finalUrl: request.url,
            stage: request.stage,
            success: false,
            errorMessage: "Execution not yet implemented; security gate passed",
            errorType: .configurationError,
            html: "",
            title: nil,
            metadata: RuntimeWebViewMetadata(),
            snapshotId: nil,
            snapshotFilePath: nil
        )
    }

    public func executeInteractionSteps(
        request: RuntimeWebViewRequest,
        scripts: [RuntimeWebViewScript]
    ) async -> [RuntimeWebViewInteractionResult] {
        []
    }

    public func release() async {
        webView = nil
    }
}
#endif
