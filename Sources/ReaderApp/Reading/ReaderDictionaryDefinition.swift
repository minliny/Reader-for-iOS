import SwiftUI
import UIKit
import WebKit

struct ReaderDictionaryDefinitionStyle: Equatable {
    let fontName: String
    let fontSize: CGFloat
    let foreground: String
    let background: String
    let link: String

    init(font: UIFont, foreground: UIColor, background: UIColor, link: UIColor) {
        fontName = font.fontName; fontSize = font.pointSize
        self.foreground = Self.css(foreground); self.background = Self.css(background); self.link = Self.css(link)
    }

    private static func css(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return "rgba(\(Int(r * 255)),\(Int(g * 255)),\(Int(b * 255)),\(a))"
    }
}

/// One dictionary result viewport. The tools panel retains its own scrolling;
/// this bounded native region scrolls long definitions without a height bridge.
struct ReaderDictionaryDefinition: View {
    let definition: String
    let displayID: UUID
    @Environment(\.colorScheme) private var scheme
    @Environment(\.openURL) private var openURL
    @ScaledMetric(relativeTo: .body) private var fontSize = ReaderTypography.style(.caption).size
    @State private var failure: String?
    private static let viewportHeight: CGFloat = 280

    var body: some View {
        let palette = ReaderPalette(scheme)
        let style = ReaderDictionaryDefinitionStyle(font: ReaderFonts.uiFont(.ui, size: fontSize),
            foreground: UIColor(palette.ink), background: UIColor(palette.card), link: UIColor(palette.green))
        VStack(alignment: .leading, spacing: 8) {
            ReaderDictionaryDefinitionNative(definition: definition, displayID: displayID, style: style,
                openURL: { openURL($0) }, failure: $failure)
                .frame(height: Self.viewportHeight)
                .background(palette.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .accessibilityIdentifier("dictionary-definition")
            if let failure { ReaderPageState(title: "字典释义暂不可展示", detail: failure) }
        }
    }
}

private struct ReaderDictionaryDefinitionNative: UIViewRepresentable {
    let definition: String
    let displayID: UUID
    let style: ReaderDictionaryDefinitionStyle
    let openURL: (URL) -> Void
    @Binding var failure: String?

    @MainActor
    final class Coordinator {
        let host = ReaderDictionaryDefinitionHost()
        var input: Input?
        var task: Task<Void, Never>?
    }
    struct Input: Equatable {
        let definition: String
        let displayID: UUID
        let style: ReaderDictionaryDefinitionStyle
    }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> WKWebView { context.coordinator.host.webView }
    func updateUIView(_ view: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.host.openURL = openURL
        let input = Input(definition: definition, displayID: displayID, style: style)
        guard coordinator.input != input else { return }
        coordinator.input = input
        coordinator.task?.cancel()
        coordinator.host.onState = { [weak coordinator] state in
            guard coordinator?.input == input else { return }
            if case .failed(let displayID) = state, displayID == input.displayID {
                failure = "当前查询结果已保留，可重新查询。"
            }
        }
        coordinator.task = Task { @MainActor [weak coordinator] in
            guard let coordinator else { return }
            failure = nil
            do { try await coordinator.host.load(definition: definition, displayID: displayID, style: style) }
            catch is CancellationError { return }
            catch {
                guard !Task.isCancelled, coordinator.input == input else { return }
                failure = "当前查询结果已保留，可重新查询。"
            }
        }
    }
    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        coordinator.task?.cancel(); coordinator.task = nil; coordinator.host.retire()
    }
}

/// Platform HTML rendering only. Core's result stays unchanged; WebKit parses
/// markup, while this owner admits text formatting and explicit external links.
@MainActor
final class ReaderDictionaryDefinitionHost: NSObject, WKNavigationDelegate, WKUIDelegate {
    enum State { case idle, loading(UUID), ready(UUID), failed(UUID), retired }
    let webView: WKWebView
    var openURL: (URL) -> Void
    var onState: ((State) -> Void)?
    private(set) var state: State = .idle { didSet { onState?(state) } }
    private(set) var loadedDisplayID: UUID?
    private var generation = UUID()
    private var initialNavigationAdmitted = false
    private var retired = false
    private var pending: (displayID: UUID, definition: String, continuation: CheckedContinuation<Void, Error>)?
    private var navigation: WKNavigation?
    private static var blockingRules: Task<WKContentRuleList, Error>?

    init(openURL: @escaping (URL) -> Void = { _ in }) {
        self.openURL = openURL
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        webView = WKWebView(frame: .zero, configuration: configuration)
        super.init()
        webView.navigationDelegate = self; webView.uiDelegate = self
        webView.isOpaque = false; webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.alwaysBounceVertical = false
        webView.accessibilityLabel = "字典释义"
    }

    /// Completion means both the local document and its platform-parsed result
    /// are installed. Superseding or retiring the display cancels this waiter.
    func load(definition: String, displayID: UUID, style: ReaderDictionaryDefinitionStyle) async throws {
        guard !retired else { throw CancellationError() }
        cancelPending()
        let ticket = UUID(); generation = ticket; loadedDisplayID = nil
        state = .loading(displayID)
        do {
            let rules = try await Self.externalResourceRules()
            try Task.checkCancellation()
            guard !retired, generation == ticket else { throw CancellationError() }
            webView.configuration.userContentController.removeAllContentRuleLists()
            webView.configuration.userContentController.add(rules)
            initialNavigationAdmitted = false
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    pending = (displayID, definition, continuation)
                    navigation = webView.loadHTMLString(Self.document(style: style), baseURL: nil)
                    if navigation == nil { finish(.failure(ReaderLibraryError.invalidResponse("dictionary document"))) }
                }
            } onCancel: {
                Task { @MainActor [weak self] in
                    guard let self, self.generation == ticket else { return }
                    self.cancelPending()
                }
            }
        } catch {
            if !retired, generation == ticket, !(error is CancellationError) { state = .failed(displayID) }
            throw error
        }
    }

    func retire() {
        guard !retired else { return }
        retired = true; generation = UUID(); cancelPending(); loadedDisplayID = nil
        webView.navigationDelegate = nil; webView.uiDelegate = nil; openURL = { _ in }; state = .retired
    }

    private func cancelPending() {
        let continuation = pending?.continuation; pending = nil
        navigation = nil; webView.stopLoading()
        continuation?.resume(throwing: CancellationError())
    }
    private func finish(_ result: Result<Void, Error>) {
        guard let original = pending else { return }
        pending = nil; navigation = nil
        if case .success = result { loadedDisplayID = original.displayID; state = .ready(original.displayID) }
        original.continuation.resume(with: result)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !retired, webView === self.webView, navigation === self.navigation, let pending else { return }
        let ticket = generation
        webView.callAsyncJavaScript(Self.installDefinition, arguments: ["definition": pending.definition],
            in: nil, in: .defaultClient) { [weak self] result in
                guard let self, !self.retired, self.generation == ticket else { return }
                self.finish(result.map { _ in () })
            }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard navigation === self.navigation else { return }; finish(.failure(error))
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard navigation === self.navigation else { return }; finish(.failure(error))
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        if let displayID = loadedDisplayID {
            loadedDisplayID = nil; state = .failed(displayID)
        } else { finish(.failure(ReaderLibraryError.invalidResponse("dictionary renderer terminated"))) }
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard !retired, let url = action.request.url else { decisionHandler(.cancel); return }
        if action.navigationType == .linkActivated, loadedDisplayID != nil,
           ["http", "https"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
            openURL(url)
            decisionHandler(.cancel)
        } else if !initialNavigationAdmitted, pending != nil, action.navigationType == .other,
                  action.targetFrame?.isMainFrame != false, url.absoluteString == "about:blank" {
            initialNavigationAdmitted = true
            decisionHandler(.allow)
        } else { decisionHandler(.cancel) }
    }
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? { nil }

    private static func externalResourceRules() async throws -> WKContentRuleList {
        if let blockingRules { return try await blockingRules.value }
        let task = Task { @MainActor in
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<WKContentRuleList, Error>) in
                WKContentRuleListStore.default().compileContentRuleList(forIdentifier: "ReaderDictionaryDefinition-NoHTTP-v1",
                    encodedContentRuleList: #"[{"trigger":{"url-filter":"^https?://"},"action":{"type":"block"}}]"#) { rules, error in
                        if let rules { continuation.resume(returning: rules) }
                        else { continuation.resume(throwing: error ?? ReaderLibraryError.invalidResponse("dictionary resource policy")) }
                    }
            }
        }
        blockingRules = task
        do { return try await task.value }
        catch { blockingRules = nil; throw error }
    }

    private static func document(style: ReaderDictionaryDefinitionStyle) -> String {
        let font = style.fontName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'none'; img-src 'none'; font-src 'none'; connect-src 'none'; media-src 'none'; frame-src 'none'; object-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        html,body{margin:0;padding:0;background:\(style.background);color:\(style.foreground);font-family:"\(font)",-apple-system,system-ui,sans-serif;font-size:\(style.fontSize)px;line-height:1.55;overflow-wrap:anywhere}
        #reader-dictionary-definition{padding:12px}p,div,ul,ol{margin-block:0.5em}a{color:\(style.link);text-decoration:underline}em,i{font-style:italic}strong,b{font-weight:700}
        </style></head><body><div id="reader-dictionary-definition"></div></body></html>
        """
    }

    /// WebKit's inert template parser handles both full documents and fragments.
    /// This is an admission policy over its DOM, not a second HTML parser.
    private static let installDefinition = """
    const container=document.getElementById('reader-dictionary-definition');
    const template=document.createElement('template');
    template.innerHTML=definition;
    const hasMarkup=template.content.querySelector('*')!==null;
    if(!hasMarkup){container.textContent=template.content.textContent;container.style.whiteSpace='pre-wrap';container.dataset.kind='text';return;}
    template.content.querySelectorAll('script,style,link,meta,base,title,iframe,frame,frameset,object,embed,img,picture,source,video,audio,track,svg,canvas,input,button,select,textarea').forEach(node=>node.remove());
    template.content.querySelectorAll('form').forEach(node=>node.replaceWith(...node.childNodes));
    template.content.querySelectorAll('*').forEach(node=>{
      for(const attribute of [...node.attributes]){
        if(!['href','title','lang','dir'].includes(attribute.name)||attribute.name==='href'&&node.tagName!=='A')node.removeAttribute(attribute.name);
      }
      if(node.tagName==='A'){
        const href=node.getAttribute('href')||'';
        try{const url=new URL(href);if(!/^https?:\\/\\//i.test(href)||!['http:','https:'].includes(url.protocol)||!url.hostname)node.removeAttribute('href');}
        catch{node.removeAttribute('href');}
      }
    });
    container.replaceChildren(template.content);container.style.whiteSpace='normal';container.dataset.kind='html';
    """
}
