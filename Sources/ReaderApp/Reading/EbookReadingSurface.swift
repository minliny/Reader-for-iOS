import Foundation
import UIKit
import WebKit

@MainActor
final class EbookReadingSurface: NSObject, ReadingSurface, WKNavigationDelegate, WKScriptMessageHandler {
    private struct Configuration: Encodable {
        let session: String
        let documentId: String
        let layoutGeneration: Int
        let entryPath: String
        let xhtml: String
        let documentCanonicalContent: String
        let chapterStartScalar: Int64
        let chapterEndScalar: Int64
        let content: String
        let scalarCount: Int
        let anchor: Int
        let style: EbookStyle
    }

    let webView: WKWebView
    private let schemeHandler: EbookSchemeHandler
    private let world = WKContentWorld.world(name: "ReaderEbookRuntime")
    private static let messageName = "readerEbook"
    private var identity: EbookRenderIdentity?
    private var didLoadShell = false
    private var shellWaiter: CheckedContinuation<Void, any Error>?
    private var readyWaiter: CheckedContinuation<EbookScriptEvent.Value, any Error>?
    private var readiness: Result<EbookScriptEvent.Value, any Error>?
    private var readyDeadline: Task<Void, Never>?
    var onEvent: ((EbookScriptEvent) -> Void)?

    init(bundle: Bundle = .main) throws {
        guard let directory = bundle.resourceURL?.appendingPathComponent("reader_ebook_runtime") else {
            throw EbookSurfaceFailure.missingResources
        }
        let files = directory.appendingPathComponent("shell.html")
        let schemeHandler = EbookSchemeHandler(shellHTML: try Data(contentsOf: files))
        self.schemeHandler = schemeHandler
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        config.setURLSchemeHandler(schemeHandler, forURLScheme: EbookSchemeHandler.scheme)
        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        let controller = webView.configuration.userContentController
        for file in ["reader-ebook-dom.js", "reader-ebook-runtime.js"] {
            let source = try String(contentsOf: directory.appendingPathComponent(file), encoding: .utf8)
            controller.addUserScript(WKUserScript(
                source: source, injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: world
            ))
        }
        controller.add(EbookMessageReceiver(surface: self), contentWorld: world, name: Self.messageName)
        webView.navigationDelegate = self
    }

    func open(
        _ document: EbookDocument, session: String, anchor: Int, style: EbookStyle = EbookStyle()
    ) async throws -> EbookScriptEvent.Value {
        try await loadShell()
        let current = EbookRenderIdentity(session: session, documentId: UUID().uuidString, layoutGeneration: 0)
        resetReadiness()
        identity = current
        schemeHandler.authorize(document.source, documentId: current.documentId)
        let projection = document.descriptor
        let configuration = Configuration(
            session: current.session, documentId: current.documentId, layoutGeneration: current.layoutGeneration,
            entryPath: projection.entryPath, xhtml: document.xhtml,
            documentCanonicalContent: projection.documentCanonicalContent,
            chapterStartScalar: projection.chapterStartScalar, chapterEndScalar: projection.chapterEndScalar,
            content: document.chapter.content, scalarCount: document.chapter.content.unicodeScalars.count,
            anchor: anchor, style: style
        )
        _ = try await webView.callAsyncJavaScript(Self.openScript, arguments: [
            "configuration": Self.jsonObject(configuration),
            "resourceOrigin": "\(EbookSchemeHandler.scheme)://\(EbookSchemeHandler.host)",
            "resourceCSP": "\(EbookSchemeHandler.scheme):"
        ], contentWorld: world)
        return try await waitForReadiness(current)
    }

    func reflow(style: EbookStyle, anchor: Int? = nil) async throws -> EbookScriptEvent.Value {
        guard let previous = identity else { throw EbookSurfaceFailure.retired }
        let current = EbookRenderIdentity(session: previous.session, documentId: previous.documentId,
                                          layoutGeneration: previous.layoutGeneration + 1)
        var args: [String: Any] = [
            "session": current.session, "documentId": current.documentId,
            "generation": current.layoutGeneration, "style": try Self.jsonObject(style)
        ]
        if let anchor { args["anchor"] = anchor }
        resetReadiness()
        identity = current
        _ = try await webView.callAsyncJavaScript(
            "await ReaderEbookRuntime.reflow(session, documentId, generation, style, \(anchor == nil ? "undefined" : "anchor"));",
            arguments: args, contentWorld: world
        )
        return try await waitForReadiness(current)
    }

    func select(start: Int, end: Int) async throws -> EbookScriptEvent.Value? {
        try await readValue("return ReaderEbookRuntime.select(start, end);", args: ["start": start, "end": end])
    }

    func selection() async throws -> EbookScriptEvent.Value? {
        try await readValue("return ReaderEbookRuntime.selection();")
    }

    func position() async throws -> EbookScriptEvent.Value? {
        try await readValue("return ReaderEbookRuntime.position();")
    }

    func restore(_ scalar: Int) async throws -> EbookScriptEvent.Value? {
        try await readValue("return ReaderEbookRuntime.restore(scalar);", args: ["scalar": scalar])
    }

    func retire() async {
        guard let previous = identity else { return }
        identity = nil
        resetReadiness()
        schemeHandler.retire()
        _ = try? await webView.callAsyncJavaScript(
            "ReaderEbookRuntime.retire(session, documentId);",
            arguments: ["session": previous.session, "documentId": previous.documentId], contentWorld: world
        )
    }

    private func readValue(_ script: String, args: [String: Any] = [:]) async throws -> EbookScriptEvent.Value? {
        guard let observed = identity else { throw EbookSurfaceFailure.retired }
        let output = try await webView.callAsyncJavaScript(script, arguments: args, contentWorld: world)
        guard observed == identity else { throw EbookSurfaceFailure.retired }
        guard let output, !(output is NSNull) else { return nil }
        let bytes = try JSONSerialization.data(withJSONObject: output)
        return try JSONDecoder().decode(EbookScriptEvent.Value.self, from: bytes)
    }

    private func loadShell() async throws {
        if didLoadShell { return }
        guard shellWaiter == nil else { throw EbookSurfaceFailure.shellLoad }
        try await withCheckedThrowingContinuation { continuation in
            shellWaiter = continuation
            webView.load(URLRequest(url: EbookSchemeHandler.shell))
        }
    }

    private func waitForReadiness(_ observed: EbookRenderIdentity) async throws -> EbookScriptEvent.Value {
        guard identity == observed else { throw EbookSurfaceFailure.retired }
        if let readiness { return try readiness.get() }
        return try await withCheckedThrowingContinuation { continuation in
            readyWaiter = continuation
            readyDeadline = Task { [weak self] in
                do { try await Task.sleep(for: .seconds(5)) } catch { return }
                guard self?.identity == observed else { return }
                self?.finish(.failure(EbookSurfaceFailure.unavailable("RENDERER_MESSAGE_TIMEOUT")))
            }
        }
    }

    private func finish(_ result: Result<EbookScriptEvent.Value, any Error>) {
        readiness = result
        readyDeadline?.cancel()
        readyDeadline = nil
        readyWaiter?.resume(with: result)
        readyWaiter = nil
    }

    private func resetReadiness() {
        finish(.failure(EbookSurfaceFailure.retired))
        readiness = nil
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        let origin = message.frameInfo.securityOrigin
        guard message.name == Self.messageName, message.webView === webView, message.frameInfo.isMainFrame,
              message.frameInfo.request.url == EbookSchemeHandler.shell,
              origin.protocol == EbookSchemeHandler.scheme, origin.host == EbookSchemeHandler.host,
              let text = message.body as? String,
              let event = try? JSONDecoder().decode(EbookScriptEvent.self, from: Data(text.utf8)),
              event.version == 1, identity == event.identity else { return }
        switch event.kind {
        case "ready":
            if let value = event.value { finish(.success(value)) }
        case "failure":
            finish(.failure(EbookSurfaceFailure.unavailable(event.value?.code ?? "EBOOK_UNAVAILABLE")))
        case "position", "selection", "link", "turn": break
        default: return
        }
        onEvent?(event)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView.url == EbookSchemeHandler.shell else { return }
        didLoadShell = true
        shellWaiter?.resume()
        shellWaiter = nil
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: any Error) {
        shellWaiter?.resume(throwing: error)
        shellWaiter = nil
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        shellWaiter?.resume(throwing: error)
        shellWaiter = nil
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        didLoadShell = false
        identity = nil
        schemeHandler.retire()
        shellWaiter?.resume(throwing: EbookSurfaceFailure.shellLoad)
        shellWaiter = nil
        finish(.failure(EbookSurfaceFailure.shellLoad))
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async
        -> WKNavigationActionPolicy {
        guard let target = navigationAction.targetFrame, let url = navigationAction.request.url else {
            return .cancel
        }
        if target.isMainFrame { return url == EbookSchemeHandler.shell ? .allow : .cancel }
        return url.absoluteString == "about:srcdoc" || url.absoluteString == "about:blank" ? .allow : .cancel
    }

    private static func jsonObject<T: Encodable>(_ value: T) throws -> Any {
        try JSONSerialization.jsonObject(with: JSONEncoder().encode(value))
    }

    private static let openScript = """
        await ReaderEbookRuntime.open(configuration, {
          resourceCSPSource: resourceCSP,
          resourceURL: path => resourceOrigin + '/archive/' + configuration.documentId + '/' +
            path.split('/').map(encodeURIComponent).join('/'),
          postMessage: event => window.webkit.messageHandlers.readerEbook.postMessage(JSON.stringify(event))
        });
        """
}

@MainActor
private final class EbookMessageReceiver: NSObject, WKScriptMessageHandler {
    private weak var surface: EbookReadingSurface?
    init(surface: EbookReadingSurface) { self.surface = surface }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        surface?.userContentController(userContentController, didReceive: message)
    }
}
