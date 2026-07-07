// CoreBridge
//
// WKWebViewExecutor: production `WebViewExecutor` backed by `WKWebView`.
//
// Implements the `webview.evaluateJavaScript` host lane:
// - `kind: "html"` → `WKWebView.loadHTMLString(_:baseURL:)` then evaluate JS.
// - `kind: "url"` → `WKWebView.load(_:URLRequest)` then evaluate JS.
// - `finalUrl` from `WKWebView.url`, `title` from `WKWebView.title`.
// - `timeoutMillis` enforced via a parallel `Task.sleep` that cancels the
//   navigation group.
// - Host validation via the shared `WebViewSecurityGate.policy.allowsHost`
//   (same policy type that gates `ProductionWebViewAdapter`).
//
// Relationship to `ProductionWebViewAdapter`:
// `ProductionWebViewAdapter` serves the reader-runtime system
// (`RuntimeWebViewRequest` → `RuntimeWebViewResult`, returning page HTML +
// interaction results). The host lane `webview.evaluateJavaScript` needs the
// JS evaluation *value*, which `ProductionWebViewAdapter.execute` does not
// expose. This executor therefore drives `WKWebView` directly but reuses
// `WebViewSecurityGate`'s policy type for host validation so the security
// posture stays consistent across both entry points. If a future host lane
// needs login flow / captcha interaction, it can layer on
// `ProductionWebViewAdapter.executeInteractionSteps`.
//
// Proof tier: simulator-proof. WKWebView works on the iOS simulator without
// a view hierarchy (load + evaluateJavaScript succeed headless). Real-device
// proof (login cookie persistence, captcha delegation, snapshot capture) is
// tracked in `HostAdapterRealDeviceProofManifestTests`.
//
// Guard: `canImport(WebKit) && canImport(UIKit)` — WKWebView is available on
// macOS but the host lane is iOS-only here, so macOS `swift build` skips this
// file and `RustCoreServiceSupport.makeRouter` leaves the webView executor
// nil (host.request for webview.evaluateJavaScript then fails closed with
// `webViewExecutorNotConfigured`, which is the correct macOS-CI behavior).

#if canImport(WebKit) && canImport(UIKit)
import Foundation
import WebKit
import UIKit

@MainActor
private final class WKWebViewNavigationDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    func awaitCompletion() async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            self.continuation = cont
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        resume(.success(()))
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        resume(.failure(error))
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        resume(.failure(error))
    }

    private func resume(_ result: Result<Void, Error>) {
        guard let cont = continuation else { return }
        continuation = nil
        switch result {
        case .success: cont.resume(returning: ())
        case .failure(let e): cont.resume(throwing: e)
        }
    }
}

/// Production `WebViewExecutor` backed by `WKWebView`.
///
/// Host validation reuses `WebViewSecurityGate`'s `WebViewSecurityPolicy` so
/// the same allow-list governs both this executor and `ProductionWebViewAdapter`.
public final class WKWebViewExecutor: WebViewExecutor, @unchecked Sendable {
    private let securityGate: WebViewSecurityGate

    public init(securityGate: WebViewSecurityGate = WebViewSecurityGate()) {
        self.securityGate = securityGate
    }

    public func evaluate(request: WebViewEvaluationRequest) async throws -> WebViewEvaluationResult {
        // Host validation via the shared security gate policy.
        if case .url = request.document.kind, let urlStr = request.document.url {
            let host = URL(string: urlStr)?.host ?? urlStr
            if !securityGate.policy.allowsHost(host) {
                throw WebViewExecutorError.invalidParams(
                    "webview url host '\(host)' not allowed by security policy"
                )
            }
        }

        let timeoutSeconds: TimeInterval = request.timeoutMillis.map { Double($0) / 1000.0 } ?? 30

        return try await withThrowingTaskGroup(of: WebViewEvaluationResult.self) { group in
            group.addTask { [self] in
                try await self.performEvaluate(request: request)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeoutSeconds * 1_000_000_000))
                throw WebViewExecutorError.timeout(
                    timeoutMillis: UInt64(timeoutSeconds * 1000)
                )
            }
            guard let first = try await group.next() else {
                throw WebViewExecutorError.executionFailed("no result from evaluate")
            }
            group.cancelAll()
            return first
        }
    }

    @MainActor
    private func performEvaluate(request: WebViewEvaluationRequest) async throws -> WebViewEvaluationResult {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let navDelegate = WKWebViewNavigationDelegate()
        webView.navigationDelegate = navDelegate

        // Load the document.
        switch request.document.kind {
        case .html:
            let baseURL = request.document.baseUrl.flatMap { URL(string: $0) }
            webView.loadHTMLString(request.document.body ?? "", baseURL: baseURL)
        case .url:
            guard let url = URL(string: request.document.url ?? "") else {
                throw WebViewExecutorError.invalidParams(
                    "webview url document has invalid url"
                )
            }
            webView.load(URLRequest(url: url))
        }

        // Wait for navigation completion (throws on navigation failure).
        try await navDelegate.awaitCompletion()

        // Evaluate the JS expression.
        let value: Any? = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Any?, Error>) in
            webView.evaluateJavaScript(request.javaScript) { result, error in
                if let error = error {
                    cont.resume(throwing: WebViewExecutorError.executionFailed(error.localizedDescription))
                } else {
                    cont.resume(returning: result)
                }
            }
        }

        let finalUrl = webView.url?.absoluteString
        let title = webView.title
        return WebViewEvaluationResult(
            value: value ?? NSNull(),
            finalUrl: finalUrl,
            title: title?.isEmpty == false ? title : nil
        )
    }
}
#endif
