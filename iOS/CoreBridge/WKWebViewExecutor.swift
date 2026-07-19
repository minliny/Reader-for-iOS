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
    private let policy: WebViewSecurityPolicy
    private var continuation: CheckedContinuation<Void, Error>?
    private var terminalResult: Result<Void, Error>?

    init(policy: WebViewSecurityPolicy) {
        self.policy = policy
    }

    func awaitCompletion(webView: WKWebView) async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                if let terminalResult {
                    self.terminalResult = nil
                    cont.resume(with: terminalResult)
                } else {
                    self.continuation = cont
                }
            }
        } onCancel: {
            Task { @MainActor [weak self, weak webView] in
                webView?.stopLoading()
                self?.resume(.failure(CancellationError()))
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url,
              WebViewEvaluationPolicyAdmission.admitsNavigation(url, policy: policy) else {
            decisionHandler(.cancel)
            resume(.failure(WebViewExecutorError.invalidParams(
                "webview navigation was rejected by security policy"
            )))
            return
        }
        decisionHandler(.allow)
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
        if let cont = continuation {
            continuation = nil
            cont.resume(with: result)
        } else if terminalResult == nil {
            terminalResult = result
        }
    }
}

@MainActor
private final class WKJavaScriptEvaluation {
    private var continuation: CheckedContinuation<Any?, Error>?
    private var completed = false

    func run(_ javaScript: String, in webView: WKWebView) async throws -> Any? {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Any?, Error>) in
                continuation = cont
                webView.evaluateJavaScript(javaScript) { [weak self] result, error in
                    Task { @MainActor in
                        if let error {
                            self?.finish(.failure(WebViewExecutorError.executionFailed(error.localizedDescription)))
                        } else {
                            self?.finish(.success(result))
                        }
                    }
                }
            }
        } onCancel: {
            Task { @MainActor [weak self, weak webView] in
                webView?.stopLoading()
                self?.finish(.failure(CancellationError()))
            }
        }
    }

    private func finish(_ result: Result<Any?, Error>) {
        guard !completed, let continuation else { return }
        completed = true
        self.continuation = nil
        continuation.resume(with: result)
    }
}

/// Process-local profile registry. Each opaque profile id receives its own
/// non-persistent WebsiteDataStore and WKProcessPool, so cookies, DOM storage,
/// and renderer state cannot cross profiles. Reusing the same id intentionally
/// preserves state for subsequent evaluations in the same app process.
@MainActor
private final class WKWebViewProfileStore {
    static let shared = WKWebViewProfileStore()

    private struct Profile {
        let dataStore: WKWebsiteDataStore
        let processPool: WKProcessPool
    }

    private enum ProfileKey: Hashable {
        case implicit
        case explicit(String)
    }

    private var profiles: [ProfileKey: Profile] = [:]
    private let maximumProfiles = 64

    func configuration(profileID: String?) throws -> WKWebViewConfiguration {
        let key = profileID.map(ProfileKey.explicit) ?? .implicit
        let profile: Profile
        if let existing = profiles[key] {
            profile = existing
        } else {
            guard profiles.count < maximumProfiles else {
                throw WebViewExecutorError.invalidParams(
                    "webview profile limit exceeded; close/reuse an existing profile"
                )
            }
            let created = Profile(
                dataStore: WKWebsiteDataStore.nonPersistent(),
                processPool: WKProcessPool()
            )
            profiles[key] = created
            profile = created
        }
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = profile.dataStore
        configuration.processPool = profile.processPool
        return configuration
    }
}

/// Compiles the pure policy rule list before a `WKWebView` is created. Rule
/// compilation is itself fail-closed: an invalid/unavailable rule list aborts
/// the evaluation instead of silently creating an unrestricted WebView.
@MainActor
private enum WKWebViewSubresourceRuleCompiler {
    static func compile(policy: WebViewSecurityPolicy) async throws -> WKContentRuleList? {
        guard let encoded = try WebViewEvaluationPolicyAdmission
            .encodedSubresourceRuleList(policy: policy) else {
            return nil
        }
        let identifier = "reader.webview.network-boundary.\(stableHash(encoded))"
        return try await withCheckedThrowingContinuation { continuation in
            WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: identifier,
                encodedContentRuleList: encoded
            ) { ruleList, error in
                if let ruleList {
                    continuation.resume(returning: ruleList)
                } else {
                    continuation.resume(throwing: WebViewExecutorError.executionFailed(
                        "failed to compile WebKit subresource security rules: "
                            + (error?.localizedDescription ?? "unknown error")
                    ))
                }
            }
        }
    }

    private static func stableHash(_ value: String) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        return String(hash, radix: 16)
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
        let policy = securityGate.policy
        try WebViewEvaluationPolicyAdmission.validate(request: request, policy: policy)
        let timeoutSeconds = WebViewEvaluationPolicyAdmission.effectiveTimeoutSeconds(
            request: request,
            policy: policy
        )

        return try await withThrowingTaskGroup(of: WebViewEvaluationResult.self) { group in
            group.addTask { [self] in
                try await self.performEvaluate(request: request, policy: policy)
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
    private func performEvaluate(
        request: WebViewEvaluationRequest,
        policy: WebViewSecurityPolicy
    ) async throws -> WebViewEvaluationResult {
        let configuration = try WKWebViewProfileStore.shared.configuration(
            profileID: request.profileId
        )
        configuration.defaultWebpagePreferences.allowsContentJavaScript = policy.allowJavaScriptExecution
        if let subresourceRules = try await WKWebViewSubresourceRuleCompiler.compile(policy: policy) {
            configuration.userContentController.add(subresourceRules)
        }
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = policy.userAgent
        let navDelegate = WKWebViewNavigationDelegate(policy: policy)
        webView.navigationDelegate = navDelegate

        // Load the document.
        switch request.document.kind {
        case .html:
            let baseURL = request.document.baseUrl.flatMap { URL(string: $0) }
            let body = policy.allowNetworkNavigation && !policy.allowLocalSnapshotOnly
                ? (request.document.body ?? "")
                : Self.networkDisabledHTML(request.document.body ?? "")
            webView.loadHTMLString(body, baseURL: baseURL)
        case .url:
            guard let url = URL(string: request.document.url ?? "") else {
                throw WebViewExecutorError.invalidParams(
                    "webview url document has invalid url"
                )
            }
            webView.load(URLRequest(url: url))
        }

        // Wait for navigation completion (throws on navigation failure).
        try await navDelegate.awaitCompletion(webView: webView)

        // Evaluate the JS expression.
        let value = try await WKJavaScriptEvaluation().run(request.javaScript, in: webView)

        let finalUrl = webView.url?.absoluteString
        let title = webView.title
        return WebViewEvaluationResult(
            value: value ?? NSNull(),
            finalUrl: finalUrl,
            title: title?.isEmpty == false ? title : nil
        )
    }

    private static func networkDisabledHTML(_ html: String) -> String {
        let meta = #"<meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src data: blob:; font-src data:">"#
        if let head = html.range(of: "<head", options: .caseInsensitive),
           let close = html[head.lowerBound...].firstIndex(of: ">") {
            var result = html
            result.insert(contentsOf: meta, at: result.index(after: close))
            return result
        }
        return "<head>\(meta)</head>\(html)"
    }
}
#endif
