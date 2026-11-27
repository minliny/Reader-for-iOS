import Foundation
import WebKit

/// A platform browser lease associated with one source. The coordinator owns
/// the intent and applies Core's source and report transitions separately.
@MainActor
public final class SourceLoginSession: NSObject, WKNavigationDelegate {
    public enum State: Sendable, Equatable {
        case loading, ready, failed, timedOut, revoked
    }

    public let sourceId: String
    public let webView: WKWebView
    public private(set) var state: State = .loading {
        didSet { onNavigationChange?() }
    }
    public var onNavigationChange: (@MainActor () -> Void)?
    private var initialNavigation: WKNavigation?
    private var deadline: Task<Void, Never>?
    private var loginURL: URL?
    private var loginTimeout: Duration = .seconds(60)

    init(sourceId: String, site: WKWebsiteDataStore) {
        self.sourceId = sourceId
        let config = WKWebViewConfiguration()
        config.websiteDataStore = site
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
    }

    func start(url: URL, timeout: Duration) {
        loginURL = url
        loginTimeout = timeout
        track(webView.load(URLRequest(url: url)))
    }

    public func reloadPage() {
        guard state != .revoked else { return }
        if webView.url != nil {
            track(webView.reload())
        } else if let loginURL {
            start(url: loginURL, timeout: loginTimeout)
        }
    }

    private func track(_ navigation: WKNavigation?) {
        deadline?.cancel()
        initialNavigation = navigation
        guard navigation != nil else { state = .failed; return }
        state = .loading
        let timeout = loginTimeout
        deadline = Task { [weak self] in
            do { try await Task.sleep(for: timeout) } catch { return }
            guard let self, self.state == .loading else { return }
            self.state = .timedOut
            self.initialNavigation = nil
            self.webView.stopLoading()
        }
    }

    func revoke() {
        deadline?.cancel()
        initialNavigation = nil
        state = .revoked
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
    }

    public func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard webView === self.webView, let url = action.request.url else { return .cancel }
        if url.absoluteString == "about:blank" { return .allow }
        guard state != .revoked, (try? hostHTTPURL(url.absoluteString)) != nil else { return .cancel }
        return .allow
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        complete(navigation, state: .ready)
        onNavigationChange?()
    }

    public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        onNavigationChange?()
    }

    public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        if state == .ready { track(navigation) }
        onNavigationChange?()
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        complete(navigation, state: .failed)
        onNavigationChange?()
    }

    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                        withError error: any Error) {
        complete(navigation, state: .failed)
        onNavigationChange?()
    }

    private func complete(_ navigation: WKNavigation?, state: State) {
        guard self.state == .loading, let initialNavigation, initialNavigation === navigation else { return }
        self.state = state
        self.initialNavigation = nil
        deadline?.cancel()
    }
}
