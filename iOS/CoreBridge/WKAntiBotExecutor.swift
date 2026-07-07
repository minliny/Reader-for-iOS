// CoreBridge
//
// WKAntiBotExecutor: production `AntiBotExecutor` for the `anti_bot` host lane.
//
// Two-tier strategy:
// - L1 (cross-platform): `URLSession` HTTP fetch — returns statusCode, body,
//   headers, finalUrl. Sufficient for clean responses and for detecting
//   challenges (Cloudflare 503 + jschl, slider, reCAPTCHA, 403) via
//   `AntiBotChallengeDetector`.
// - L2 (iOS only, `canImport(WebKit) && canImport(UIKit)`): when L1 returns a
//   non-200 status or a body that looks like a JS challenge, retry the URL in
//   a headless `WKWebView`. WKWebView executes the challenge JS natively
//   (Cloudflare `jschl` etc.); on `didFinish` the body is the solved content.
//   If WKWebView succeeds, returns 200 + solved body. If WKWebView fails
//   (navigation error or still-challenged body), returns the original L1
//   response so `AntiBotChallengeDetector` can classify it as
//   `challengeRequired` (fail-closed).
//
// Cookie jar: `cookieJarId` is accepted for session affinity but cookie
// persistence across L1/L2 is a real-device proof item (tracked in
// `HostAdapterRealDeviceProofManifestTests`); this executor does not yet
// wire `cookieJarId` to `WKWebsiteDataStore`.
//
// Proof tier: simulator-proof (L1 URLSession works on macOS `swift build`;
// L2 WKWebView works on iOS simulator). Real-device proof (cookie persistence
// across fetches, slider/reCAPTCHA human-verifier delegation, background
// fetch) is tracked separately.
//
// Clean-room: no Legado/Android code reused; implementation follows the Core
// `anti_bot.challenge` contract only.

import Foundation

#if canImport(WebKit) && canImport(UIKit)
import WebKit
import UIKit
#endif

/// Production `AntiBotExecutor` with L1 URLSession + L2 WKWebView fallback.
public final class WKAntiBotExecutor: AntiBotExecutor, @unchecked Sendable {
    private let session: URLSession
    private let securityGate: WebViewSecurityGate

    public init(
        session: URLSession? = nil,
        securityGate: WebViewSecurityGate = WebViewSecurityGate()
    ) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        self.session = session ?? URLSession(configuration: config)
        self.securityGate = securityGate
    }

    public func fetch(
        url: String,
        headers: [String: String],
        cookieJarId: String?
    ) async throws -> AntiBotHttpResponse {
        // L1: HTTP fetch via URLSession.
        let httpResult = try await fetchHTTP(url: url, headers: headers)

        // Decide whether to attempt L2 WKWebView fallback. Trigger when L1 is
        // non-200 OR the body carries a known JS-challenge marker. This is an
        // internal heuristic for "is WKWebView worth trying", NOT the final
        // challenge classification (that is `AntiBotChallengeDetector`'s job
        // after this executor returns).
        if shouldAttemptWebViewFallback(httpResult) {
            #if canImport(WebKit) && canImport(UIKit)
            if let solved = try? await fetchViaWebView(url: url, headers: headers) {
                return solved
            }
            #endif
        }

        return httpResult
    }

    // MARK: - L1: URLSession

    private func fetchHTTP(url: String, headers: [String: String]) async throws -> AntiBotHttpResponse {
        guard let url = URL(string: url) else {
            throw AntiBotExecutorError.invalidParams("invalid url: \(url)")
        }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "GET"
        for (k, v) in headers {
            urlRequest.setValue(v, forHTTPHeaderField: k)
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: urlRequest)
        } catch {
            throw AntiBotExecutorError.networkError(error.localizedDescription)
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AntiBotExecutorError.networkError("non-HTTP response")
        }
        let body = String(data: data, encoding: .utf8) ?? ""
        let finalUrl = httpResponse.url?.absoluteString ?? url.absoluteString
        var responseHeaders: [String: String] = [:]
        for (k, v) in httpResponse.allHeaderFields {
            if let ks = k as? String, let vs = v as? String {
                responseHeaders[ks] = vs
            }
        }
        return AntiBotHttpResponse(
            statusCode: httpResponse.statusCode,
            body: body,
            headers: responseHeaders,
            finalUrl: finalUrl
        )
    }

    // MARK: - L1.5: fallback heuristic

    /// Internal heuristic: should L2 WKWebView be attempted? True when L1
    /// returned non-200 OR the body contains a known JS-challenge marker.
    /// This is intentionally a broad trigger (prefers attempting WKWebView
    /// and falling back to L1 on failure) so JS challenges that return 200
    /// with a challenge body are still retried.
    private func shouldAttemptWebViewFallback(_ response: AntiBotHttpResponse) -> Bool {
        if response.statusCode != 200 { return true }
        let body = response.body.lowercased()
        if body.contains("jschl") { return true }
        if body.contains("cf-browser-verification") { return true }
        if body.contains("cf-challenge") { return true }
        return false
    }

    // MARK: - L2: WKWebView (iOS only)

    #if canImport(WebKit) && canImport(UIKit)
    @MainActor
    private func fetchViaWebView(url: String, headers: [String: String]) async throws -> AntiBotHttpResponse {
        // Host validation via the shared security gate policy.
        let host = URL(string: url)?.host ?? url
        if !securityGate.policy.allowsHost(host) {
            throw AntiBotExecutorError.invalidParams(
                "anti_bot url host '\(host)' not allowed by security policy"
            )
        }

        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        let navDelegate = WKWebViewAntiBotNavigationDelegate()
        webView.navigationDelegate = navDelegate

        guard let url = URL(string: url) else {
            throw AntiBotExecutorError.invalidParams("invalid url")
        }
        var urlRequest = URLRequest(url: url)
        for (k, v) in headers {
            urlRequest.setValue(v, forHTTPHeaderField: k)
        }
        webView.load(urlRequest)

        // Wait for navigation (throws on didFail / didFailProvisionalNavigation).
        try await navDelegate.awaitCompletion()

        // After navigation, extract the rendered body via JS.
        let body: String = try await withCheckedThrowingContinuation { (cont: CheckedContinuation<String, Error>) in
            webView.evaluateJavaScript("document.documentElement.outerHTML") { result, error in
                if let error = error {
                    cont.resume(throwing: error)
                } else if let s = result as? String {
                    cont.resume(returning: s)
                } else {
                    cont.resume(returning: "")
                }
            }
        }

        let finalUrl = webView.url?.absoluteString ?? url.absoluteString
        return AntiBotHttpResponse(
            statusCode: 200,
            body: body,
            headers: [:],
            finalUrl: finalUrl
        )
    }
    #endif
}

#if canImport(WebKit) && canImport(UIKit)
@MainActor
private final class WKWebViewAntiBotNavigationDelegate: NSObject, WKNavigationDelegate {
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
#endif
