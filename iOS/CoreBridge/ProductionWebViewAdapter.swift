import Foundation
import ReaderCoreModels

#if canImport(WebKit) && canImport(UIKit)
import WebKit
import UIKit

/// Production WKWebView adapter conforming to RuntimeWebViewExecutorProtocol.
/// Wraps WKWebView lifecycle; execute returns error until security gate is configured.
@MainActor
public final class ProductionWebViewAdapter: RuntimeWebViewExecutorProtocol, @unchecked Sendable {

    public let executorId = "ios.production.webview"
    public let executorName = "Production WKWebView Adapter"

    private var webView: WKWebView?

    public init() {
        if Thread.isMainThread {
            let config = WKWebViewConfiguration()
            config.websiteDataStore = .nonPersistent()
            self.webView = WKWebView(frame: .zero, configuration: config)
        } else {
            self.webView = nil
        }
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
        RuntimeWebViewResult(
            requestId: request.requestId,
            sourceId: request.sourceId,
            sourceName: request.sourceName,
            originalUrl: request.url,
            finalUrl: request.url,
            stage: request.stage,
            success: false,
            errorMessage: "Production adapter initialized; security gate pending",
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
