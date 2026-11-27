import Foundation
import ReaderCoreBridge
import WebKit

@MainActor
final class BackgroundWebEvaluator: NSObject, WKNavigationDelegate {
    private enum Document {
        case html(String, URL?)
        case request(URLRequest)
    }

    private let params: M2HostWebViewEvaluateJavaScriptRequest
    private let view: WKWebView
    private var navigation: WKNavigation?
    private var navigationGeneration = UUID()
    private var terminal: CheckedContinuation<M2HostWebViewEvaluateJavaScriptResponse, any Error>?
    private var timeout: Task<Void, Never>?
    private var settling: Task<Void, Never>?

    init(params: M2HostWebViewEvaluateJavaScriptRequest) {
        self.params = params
        let config = WKWebViewConfiguration()
        // This store is private to this evaluation. Profile cookies, when
        // requested, are copied in through the Host and never mirror out.
        config.websiteDataStore = .nonPersistent()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        view = WKWebView(frame: .zero, configuration: config)
        super.init()
        view.navigationDelegate = self
    }

    func run(cookies: [HTTPCookie]) async throws -> M2HostWebViewEvaluateJavaScriptResponse {
        let document = try preparedDocument()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                terminal = continuation
                timeout = Task { [weak self] in
                    do {
                        try await Task.sleep(for: .milliseconds(max(1, min(120_000, self?.params.timeoutMillis ?? 15_000))))
                    } catch { return }
                    self?.finish(.failure(NetworkHostFailure(code: .timeout, phase: .transport,
                                                             message: "WebView evaluation timed out", retryable: true)))
                }
                settling = Task { [weak self] in
                    guard let self else { return }
                    for cookie in cookies {
                        if Task.isCancelled { return }
                        await self.view.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
                    }
                    guard !Task.isCancelled, self.terminal != nil else { return }
                    self.load(document)
                }
            }
        } onCancel: {
            Task { @MainActor in self.finish(.failure(CancellationError())) }
        }
    }

    private func preparedDocument() throws -> Document {
        switch params.document {
        case .html(let html):
            return .html(html.body, try html.baseUrl.map(hostHTTPURL))
        case .url(let url):
            var request = URLRequest(url: try hostHTTPURL(url.url), cachePolicy: .reloadIgnoringLocalCacheData)
            for (header, value) in params.headers ?? [:] {
                request.setValue(try hostHeaderValue(value), forHTTPHeaderField: header)
            }
            return .request(request)
        }
    }

    private func load(_ document: Document) {
        switch document {
        case .html(let body, let base): navigation = view.loadHTMLString(body, baseURL: base)
        case .request(let request): navigation = view.load(request)
        }
        if navigation == nil { finish(.failure(NetworkHostFailure.invalid("WebView navigation unavailable"))) }
    }

    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard terminal != nil, webView === view,
              let url = action.request.url,
              url.absoluteString == "about:blank" || (try? hostHTTPURL(url.absoluteString)) != nil else {
            return .cancel
        }
        return .allow
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard terminal != nil, self.navigation === navigation, webView === view else { return }
        let delay = max(0, min(600_000, params.settleDelayMillis ?? 0))
        let generation = navigationGeneration
        settling = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(delay)) } catch { return }
            self?.evaluate(generation: generation)
        }
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        guard terminal != nil, webView === view else { return }
        settling?.cancel()
        self.navigation = navigation
        navigationGeneration = UUID()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        fail(navigation, error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        fail(navigation, error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        finish(.failure(NetworkHostFailure.invalid("Web content process exited")))
    }

    private func fail(_ navigation: WKNavigation?, _ error: any Error) {
        guard self.navigation === navigation else { return }
        finish(.failure(NetworkHostFailure.classified(error)))
    }

    private func evaluate(generation: UUID) {
        guard terminal != nil, generation == navigationGeneration else { return }
        let arguments = ["program": params.javaScript]
        if let matcher = params.resourceUrlMatcherJavaScript {
            let script = """
                const matches = (\(matcher));
                const existing = performance.getEntriesByType('resource').find(entry => matches(entry.name));
                if (existing) return existing.name;
                const observation = new Promise(resolve => {
                    const observer = new PerformanceObserver(list => {
                        const entry = list.getEntries().find(entry => matches(entry.name));
                        if (entry) {
                            observer.disconnect();
                            resolve(entry.name);
                        }
                    });
                    observer.observe({entryTypes: ['resource']});
                });
                const programFailure = Promise.resolve().then(() => (0, eval)(program)).then(() => new Promise(() => {}));
                return await Promise.race([observation, programFailure]);
                """
            view.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page) { [weak self] result in
                guard let self, self.navigationGeneration == generation else { return }
                switch result {
                case .success(let value):
                    guard let url = value as? String, (try? hostHTTPURL(url)) != nil else {
                        self.finish(.failure(NetworkHostFailure.invalid("WebView resource observation unavailable")))
                        return
                    }
                    self.finish(.success(.init(resourceUrl: url, value: .string(url),
                                               finalUrl: self.view.url?.absoluteString, title: self.view.title)))
                case .failure:
                    self.finish(.failure(NetworkHostFailure(code: .invalidResponse, phase: .decode,
                                                            message: "WebView resource matcher failed")))
                }
            }
            return
        }
        view.callAsyncJavaScript("return await (0, eval)(program);", arguments: arguments, in: nil, in: .page) { [weak self] result in
            guard let self, self.navigationGeneration == generation else { return }
            guard case .success(let value) = result else {
                self.finish(.failure(NetworkHostFailure(code: .invalidResponse, phase: .decode,
                                                        message: "WebView JavaScript evaluation failed")))
                return
            }
            do {
                let data = try JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed)
                let projected = try JSONDecoder().decode(ReaderM1JSONValue.self, from: data)
                self.finish(.success(.init(value: projected, finalUrl: self.view.url?.absoluteString, title: self.view.title)))
            } catch {
                self.finish(.failure(NetworkHostFailure.invalid("WebView JavaScript returned a non-JSON value")))
            }
        }
    }

    private func finish(_ result: Result<M2HostWebViewEvaluateJavaScriptResponse, any Error>) {
        guard let continuation = terminal else { return }
        terminal = nil
        timeout?.cancel()
        settling?.cancel()
        navigation = nil
        view.navigationDelegate = nil
        view.stopLoading()
        continuation.resume(with: result)
    }
}
