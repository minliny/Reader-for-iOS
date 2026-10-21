import SwiftUI
import UIKit
import WebKit
import CoreText
import OSLog

#if DEBUG
private let readerEbookSurfaceLogger = Logger(subsystem: "io.reader.minliny", category: "reader-ebook")
#endif

/// Original EPUB/MOBI XHTML and CSS are rendered by system WebKit. Core owns
/// the original entry, chapter window, versions and one scalar position space.
struct ReaderEbookSurface: UIViewRepresentable {
    let document: ReaderEbookDocument
    let content: ReaderChapterContent
    let archiveReader: ReaderEbookArchiveReader
    let scalarOffset: UInt64
    let restorationID: UUID
    let fontSize: CGFloat
    let lineHeight: CGFloat
    let horizontalInset: CGFloat
    var safeLeft: CGFloat = 0
    var safeRight: CGFloat = 0
    let bottomInset: CGFloat
    let paper: ReaderPaperPalette
    let positionChanged: (UInt64) -> Void
    let selectionChanged: (UInt64, UInt64, String) -> Void
    let centerTapped: () -> Void
    let failed: (ReaderEbookError) -> Void
    var bookmarkSelectionAction: (() -> Void)? = nil
    var noteSelectionAction: (() -> Void)? = nil
    var fontName: String? = nil
    var paragraphSpacing: CGFloat = 16
    var letterSpacing: CGFloat = 0
    var firstLineIndentEm: CGFloat = 0
    var alignment: NSTextAlignment = .justified
    var paged = false
    var highlights: [ReaderHighlight] = []
    var pageTurnID: UUID? = nil
    var automaticPageEnabled = false
    var pageCommitted: (UUID, ReaderNativePageOutcome) -> Void = { _, _ in }
    var layoutReady: () -> Void = {}
    var manualInteraction: () -> Void = {}
    var reducePageMotion = false
    var automaticHighlightProgress: Double? = nil
    var transition: ReaderPageTransition = .slide
    var pageBoundary: (Int) -> Void = { _ in }
    var longPressSelectText = true
    var readerFont: UIFont? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> ReaderEbookContainer { ReaderEbookContainer() }

    func updateUIView(_ container: ReaderEbookContainer, context: Context) {
        let owner = context.coordinator
        owner.parent = self
        if owner.documentIdentity != document.identity {
            owner.install(in: container)
        } else if let webView = container.webView {
            owner.configure(webView)
            if owner.restorationID != restorationID {
                owner.restorationID = restorationID
                owner.restore(webView)
            }
            owner.updatePageRequest(webView)
        }
    }

    static func dismantleUIView(_ container: ReaderEbookContainer, coordinator: Coordinator) {
        coordinator.retire()
        container.replace(with: nil)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        var parent: ReaderEbookSurface
        var documentIdentity: String?
        var restorationID: UUID?
        private var session = ""
        private var bridge: ReaderEbookResourceBridge?
        private var activeView: WKWebView?
        private var appearance = ""
        private var layoutAppearance = ""
        private var layoutToken = UUID().uuidString
        private var retired = false
        private var initialNavigationAdmitted = false
        private var fontName = ""
        private var fontURL = ""
        private var fontReady = false
        private var fontTask: Task<Void, Never>?
        private var layoutIsReady = false
        private var lastPageTurn: UUID?
        private var activePageTurn: UUID?
        private var manualPage = false
        private var hasSelection = false
        private weak var container: ReaderEbookContainer?
        private var pageGeneration = UUID()
        private var pageEpoch = 0
        private var pageCallback: ((UUID, ReaderNativePageOutcome) -> Void)?
        private var pageStartOffset: CGPoint?
        private var pageAnimation: ReaderEbookPageTurn?
        private var snapshotTask: Task<Void, Never>?
        private var snapshotGeneration: UUID?
        private var nativeSnapshotRequest: ReaderEbookSnapshotRequest?
        private let pageJavaScript = ReaderEbookJavaScriptGate()
        private var snapshotShield: UIImageView?
        private var queuedManualDirection: (direction: Int, interactive: Bool, drag: UUID?)?
        private var pagePan: UIPanGestureRecognizer?
        private var pageStyle = ""
        private var pageDirection = 0
        private var panIdentity: UUID?
        private var panTracking = false
        private var panDirection = 0
        private var panStart: CGFloat = 0
        private var panDelta = CGPoint.zero
        private var panRelease: Bool?
        private var panVelocity: CGFloat = 0
        private var panBoundary: Int?
        private var curlPager: ReaderEbookCurlPager?
        private var curlDestinations: [Int: CurlDestination] = [:]
        private var curlPreparedKey: String?
        private var curlTurnIdentity: UUID?
        private var curlFinished: Bool?
        private var curlArmed = false
        private var curlDirection = 0
        private var curlPreparationOffset: CGPoint?
        private var curlPreparationSuspended = false
        private var curlPaper: UIColor?
        private struct CurlDestination {
            let offset: CGPoint
            let scalar: UInt64
            let geometry: String
        }

        init(_ parent: ReaderEbookSurface) { self.parent = parent }

        func install(in container: ReaderEbookContainer) {
            retire()
            self.container = container
            retired = false
            initialNavigationAdmitted = false
            layoutIsReady = false
            lastPageTurn = nil
            fontName = ""
            fontURL = ""
            fontReady = false
            appearance = ""
            layoutAppearance = ""
            layoutToken = UUID().uuidString
            pageStyle = ""
            curlPreparationSuspended = false
            documentIdentity = parent.document.identity
            restorationID = parent.restorationID
            let bridge = ReaderEbookResourceBridge(reader: parent.archiveReader)
            self.bridge = bridge
            session = bridge.origin
            do {
                try parent.document.validate(content: parent.content)
                let sourceScalars = parent.document.documentCanonicalContent.unicodeScalars
                let lower = sourceScalars.index(sourceScalars.startIndex, offsetBy: Int(parent.document.chapterStartScalar))
                let upper = sourceScalars.index(sourceScalars.startIndex, offsetBy: Int(parent.document.chapterEndScalar))
                let original = String(sourceScalars[lower..<upper])
                let edits = try ReaderEbookTextEdits.changes(original: original, processed: parent.content.content)
                let encodedEdits = try JSONSerialization.jsonObject(with: JSONEncoder().encode(edits))
                var options = metrics()
                options["session"] = session
                options["canonical"] = parent.document.documentCanonicalContent
                options["start"] = parent.document.chapterStartScalar
                options["end"] = parent.document.chapterEndScalar
                options["content"] = parent.content.content
                options["original"] = original
                options["scalarCount"] = parent.content.scalarCount
                options["edits"] = encodedEdits
                options["offset"] = min(parent.scalarOffset, parent.content.scalarCount)
                let source = try ReaderEbookScript.bootstrap(configuration: options)
                let configuration = WKWebViewConfiguration()
                configuration.websiteDataStore = .nonPersistent()
                configuration.defaultWebpagePreferences.allowsContentJavaScript = false
                configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
                configuration.setURLSchemeHandler(bridge, forURLScheme: "reader-ebook")
                configuration.userContentController.add(ReaderEbookWeakMessageHandler(self),
                    contentWorld: .defaultClient, name: "readerEbook")
                configuration.userContentController.addUserScript(WKUserScript(source: ReaderEbookScript.viewport,
                    injectionTime: .atDocumentStart, forMainFrameOnly: true, in: .defaultClient))
                configuration.userContentController.addUserScript(WKUserScript(source: source,
                    injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
                let webView = ReaderEbookWebView(frame: .zero, configuration: configuration)
                let menuSession = session
                webView.bookmarkAction = { [weak self, weak webView] in
                    guard let self, let webView, !self.retired, self.session == menuSession,
                          self.activeView === webView, self.hasSelection else { return }
                    self.parent.bookmarkSelectionAction?()
                }
                webView.noteAction = { [weak self, weak webView] in
                    guard let self, let webView, !self.retired, self.session == menuSession,
                          self.activeView === webView, self.hasSelection else { return }
                    self.parent.noteSelectionAction?()
                }
                activeView = webView
                webView.navigationDelegate = self
                webView.isOpaque = false
                webView.backgroundColor = .clear
                webView.scrollView.backgroundColor = .clear
                webView.scrollView.contentInsetAdjustmentBehavior = .never
                webView.scrollView.delegate = self
                webView.scrollView.showsVerticalScrollIndicator = false
                webView.scrollView.alwaysBounceVertical = true
                webView.accessibilityIdentifier = "reading-ebook-body"
                webView.accessibilityLabel = "电子书正文"
                container.replace(with: webView)
                let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
                pan.maximumNumberOfTouches = 1
                pan.delegate = self
                container.addGestureRecognizer(pan)
                pagePan = pan
                container.viewportChanged = { [weak self, weak webView] in
                    guard let self, let webView, self.activeView === webView else { return }
                    self.layoutIsReady = false
                    self.curlPreparationSuspended = false
                    self.cancelPage(webView)
                }
                (webView as? ReaderEbookWebView)?.pageScroll = { [weak self, weak webView] direction in
                    guard let self, let webView, self.activeView === webView, self.parent.paged else { return false }
                    self.parent.manualInteraction()
                    self.advancePage(webView, direction: direction, request: nil)
                    return true
                }
                configure(webView)
                updateFont(webView)
                let url = try ReaderEbookResourcePath.url(entry: parent.document.entryPath, origin: session)
                let expectedSession = session
                // Install a compiled network block list before opening the
                // original document. A source book cannot request HTTP assets,
                // submit forms, run scripts, or borrow the online-source session.
                WKContentRuleListStore.default().compileContentRuleList(
                    forIdentifier: "reader-local-ebook-network-v2",
                    // WebKit's content-rule regular-expression subset rejects
                    // alternation. Independent literal prefixes retain the
                    // policy without preventing original-entry navigation.
                    encodedContentRuleList: #"[{"trigger":{"url-filter":"^http:"},"action":{"type":"block"}},{"trigger":{"url-filter":"^https:"},"action":{"type":"block"}},{"trigger":{"url-filter":"^ws:"},"action":{"type":"block"}},{"trigger":{"url-filter":"^wss:"},"action":{"type":"block"}},{"trigger":{"url-filter":"^ftp:"},"action":{"type":"block"}},{"trigger":{"url-filter":"^file:"},"action":{"type":"block"}}]"#
                ) { [weak self, weak webView] rule, error in
                    guard let self, let webView, !self.retired,
                          self.session == expectedSession, self.activeView === webView else { return }
                    guard error == nil, let rule else {
                        let native = error as NSError?
                        self.fail(.networkPolicyCompilation(domain: native?.domain ?? "WebKit", code: native?.code ?? -1))
                        return
                    }
                    webView.configuration.userContentController.add(rule)
                    webView.load(URLRequest(url: url))
                }
            } catch let error as ReaderEbookError {
                fail(error)
            } catch {
                fail(.invalidDocument)
            }
        }

        func configure(_ webView: WKWebView) {
            guard !retired else { return }
            let style = "\(parent.paged)|\(parent.transition.rawValue)|\(parent.reduceMotion || parent.reducePageMotion)"
            if pageStyle != style {
                if !pageStyle.isEmpty { cancelPage(webView) }
                pageStyle = style
            }
            // Physical page destinations come from WebKit caret/viewport
            // geometry. Its vertical scroll paging is a different behavior.
            webView.scrollView.isPagingEnabled = false
            webView.scrollView.isScrollEnabled = !parent.paged
            webView.scrollView.decelerationRate = .normal
            // The original HTML is transparent by Host policy. Give the actual
            // WK viewport its paper before snapshotting; no extra bitmap copy
            // is needed to flatten a transparent snapshot against a fake white.
            webView.isOpaque = true
            webView.backgroundColor = UIColor(parent.paper.paper)
            webView.scrollView.backgroundColor = UIColor(parent.paper.paper)
            pagePan?.isEnabled = parent.paged && !hasSelection
            if !usesNativeCurl { retireCurl(webView) }
            if !parent.longPressSelectText && hasSelection {
                hasSelection = false
                parent.selectionChanged(0, 0, "")
            }
            (webView as? ReaderEbookWebView)?.bookmarkEnabled = parent.bookmarkSelectionAction != nil && hasSelection
            (webView as? ReaderEbookWebView)?.noteEnabled = parent.noteSelectionAction != nil && hasSelection
            updateFont(webView)
            var options = metrics()
            var layoutOptions = options
            layoutOptions.removeValue(forKey: "highlights")
            layoutOptions.removeValue(forKey: "automaticHighlightProgress")
            layoutOptions.removeValue(forKey: "paged")
            layoutOptions.removeValue(forKey: "layoutToken")
            if let layoutData = try? JSONSerialization.data(withJSONObject: layoutOptions, options: [.sortedKeys]),
               let layoutSignature = String(data: layoutData, encoding: .utf8), layoutSignature != layoutAppearance {
                if !layoutAppearance.isEmpty {
                    cancelPage(webView)
                    layoutToken = UUID().uuidString
                    options["layoutToken"] = layoutToken
                }
                layoutAppearance = layoutSignature
                layoutIsReady = false
                curlPreparationSuspended = false
            }
            if layoutIsReady, usesNativeCurl { prepareCurl(webView) }
            guard let data = try? JSONSerialization.data(withJSONObject: options, options: [.sortedKeys]),
                  let signature = String(data: data, encoding: .utf8), signature != appearance else { return }
            appearance = signature
            webView.callAsyncJavaScript("window.__readerEbook?.configure(options)", arguments: ["options": options],
                in: nil, in: .defaultClient, completionHandler: nil)
        }

        private func updateFont(_ webView: WKWebView) {
            let requested = parent.readerFont?.fontName ?? parent.fontName ?? ReaderTypography.readingFont(size: parent.fontSize).fontName
            guard requested != fontName, let bridge else { return }
            layoutIsReady = false
            cancelPage(webView)
            fontName = requested
            fontReady = false
            fontTask?.cancel()
            if requested == UIFont.systemFont(ofSize: parent.fontSize).fontName {
                // The system face already exists in the WebKit process. Its
                // platform CSS family preserves system fallback and does not
                // extract Apple's private system font collections.
                fontURL = ""
                fontReady = true
                appearance = ""
                return
            }
            let expectedSession = session
            fontTask = Task { [weak self, weak webView] in
                do {
                    let url = try await bridge.registerFont(postScriptName: requested)
                    guard let self, let webView, !Task.isCancelled, !self.retired,
                          self.session == expectedSession, self.fontName == requested,
                          self.activeView === webView else { return }
                    self.fontURL = url.absoluteString
                    self.fontReady = true
                    self.appearance = ""
                    self.configure(webView)
                } catch is CancellationError {} catch {
                    guard let self, !Task.isCancelled, self.session == expectedSession else { return }
                    let native = error as NSError
                    self.fail(.fontResourceFailure(domain: native.domain, code: native.code))
                }
            }
        }

        func updatePageRequest(_ webView: WKWebView) {
            if !parent.automaticPageEnabled {
                if activePageTurn != nil { cancelPage(webView) }
                return
            }
            guard layoutIsReady, let id = parent.pageTurnID, id != lastPageTurn else { return }
            lastPageTurn = id
            advancePage(webView, direction: 1, request: id)
        }

        private var usesNativeCurl: Bool {
            parent.paged && parent.transition == .simulation && !(parent.reduceMotion || parent.reducePageMotion)
        }

        private var curlKey: String {
            "\(parent.document.identity)|\(parent.content.bodyVersion)|\(parent.content.processingVersion)|\(layoutToken)|\(container?.bounds.size ?? .zero)|\(layoutAppearance)"
        }

        /// No parser or second document is involved. These are actual WebKit
        /// layout facts, excluding temporary scroll position and the JS epoch.
        private func curlGeometry(_ webView: WKWebView) async throws -> String {
            let value = try await pageJavaScript.call(webView, script:
                "if(document.images.length>2048)return null;return JSON.stringify([innerWidth,innerHeight,document.documentElement.scrollHeight,visualViewport?.scale||1,document.fonts?.status||'',Array.from(document.images).map(i=>[i.complete,i.naturalWidth,i.naturalHeight])])")
            guard let result = value as? String else { throw ReaderEbookError.invalidDocument }
            return result
        }

        private func ensureCurl(_ webView: WKWebView) -> ReaderEbookCurlPager? {
            let paper = UIColor(parent.paper.paper)
            if let curlPager, curlPaper?.isEqual(paper) == true { return curlPager }
            if curlPager != nil { retireCurl(webView) }
            guard usesNativeCurl, let container else { return nil }
            let pager = ReaderEbookCurlPager(in: container, webView: webView, paper: paper)
            pager.began = { [weak self, weak webView, weak pager] token, direction in
                guard let self, let webView, let pager, self.curlPager === pager else { return }
                self.curlBegan(webView, pager: pager, token: token, direction: direction)
            }
            pager.ended = { [weak self, weak webView, weak pager] token, direction, completed in
                guard let self, let webView, let pager, self.curlPager === pager else { return }
                guard self.curlTurnIdentity == token else {
                    pager.settled(committed: false, token: token)
                    DispatchQueue.main.async { [weak self, weak webView] in
                        guard let self, let webView else { return }; self.prepareCurl(webView)
                    }
                    return
                }
                self.curlFinished = completed
                self.finishCurlIfArmed(webView, pager: pager, token: token, direction: direction)
            }
            pager.manualBegan = { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.parent.manualInteraction()
                if self.activePageTurn != nil { self.cancelPage(webView) }
            }
            pager.memoryPressure = { [weak self, weak webView] in
                guard let self, let webView else { return }
                self.curlPreparationSuspended = true; self.cancelPage(webView)
            }
            guard pager.attach() else { return nil }
            curlPager = pager; curlPaper = paper
            return pager
        }

        private func prepareCurl(_ webView: WKWebView) {
            guard usesNativeCurl, layoutIsReady, !retired, activeView === webView, !hasSelection,
                  !curlPreparationSuspended,
                  activePageTurn == nil, !manualPage, snapshotTask == nil, nativeSnapshotRequest == nil,
                  !pageJavaScript.hasPendingCall(for: webView),
                  let pager = ensureCurl(webView), pager.canPrepare else { return }
            let key = curlKey
            guard curlPreparedKey != key else { return }
            pager.discardPrepared()
            let generation = UUID(); pageGeneration = generation; snapshotGeneration = generation
            let origin = webView.scrollView.contentOffset
            curlPreparationOffset = origin
            let expectedSession = session
            snapshotTask = Task { [weak self, weak webView, weak pager] in
                guard let self, let webView, let pager else { return }
                defer {
                    if self.snapshotGeneration == generation {
                        self.snapshotTask = nil; self.snapshotGeneration = nil
                        self.curlPreparationOffset = nil
                        self.drainQueuedManual(webView)
                    }
                }
                do {
                    let current = try await self.snapshot(webView)
                    try Task.checkCancellation()
                    guard self.validCurl(webView, pager: pager, generation: generation, key: key, session: expectedSession) else { return }
                    pager.coverCurrent(current)
                    let geometry = try await self.curlGeometry(webView)
                    var neighbours: [Int: UIImage] = [:]
                    var destinations: [Int: CurlDestination] = [:]
                    for direction in [-1, 1] {
                        let value = try await self.pageJavaScript.call(webView, script: "return window.__readerEbook.pageTarget(direction)",
                            arguments: ["direction": direction])
                        try Task.checkCancellation()
                        guard self.validCurl(webView, pager: pager, generation: generation, key: key, session: expectedSession),
                              let target = value as? [String: Any], let epoch = target["epoch"] as? NSNumber,
                              let y = target["y"] as? NSNumber, y.doubleValue.isFinite else { throw ReaderEbookError.invalidDocument }
                        if target["end"] as? Bool != true {
                            let offset = CGPoint(x: 0, y: CGFloat(y.doubleValue))
                            webView.scrollView.setContentOffset(offset, animated: false)
                            try await self.curlFrames(webView)
                            let image = try await self.snapshot(webView)
                            let value = try await self.pageJavaScript.call(webView, script: "return await window.__readerEbook.commitPage(epoch)",
                                arguments: ["epoch": epoch])
                            guard let scalar = value as? NSNumber, scalar.doubleValue.isFinite, scalar.doubleValue >= 0,
                                  scalar.uint64Value <= self.parent.content.scalarCount,
                                  try await self.curlGeometry(webView) == geometry else { throw ReaderEbookError.invalidDocument }
                            neighbours[direction] = image
                            destinations[direction] = CurlDestination(offset: offset, scalar: scalar.uint64Value, geometry: geometry)
                        }
                        // pageTurning gates native temporary scrolling. Restore
                        // before cancelling it; never acknowledge a preparation.
                        webView.scrollView.setContentOffset(origin, animated: false)
                        try await self.curlFrames(webView)
                        _ = try await self.pageJavaScript.call(webView, script: "window.__readerEbook.cancelPage()")
                        try Task.checkCancellation()
                    }
                    guard self.validCurl(webView, pager: pager, generation: generation, key: key, session: expectedSession),
                          try await self.curlGeometry(webView) == geometry,
                          pager.prepared(current: current, previous: neighbours[-1], next: neighbours[1]) else { throw ReaderEbookError.invalidDocument }
                    self.curlDestinations = destinations; self.curlPreparedKey = key
                    self.parent.layoutReady()
                } catch {
                    guard self.pageGeneration == generation, self.curlPager === pager else { return }
                    webView.scrollView.setContentOffset(origin, animated: false)
                    webView.callAsyncJavaScript("window.__readerEbook?.cancelPage()", arguments: [:],
                        in: nil, in: .defaultClient, completionHandler: nil)
                    pager.discardPrepared()
                    self.curlPreparedKey = nil; self.curlDestinations = [:]
                    self.curlPreparationSuspended = true; self.queuedManualDirection = nil
                    // Real body/selection remain available. Failure to prepare
                    // a neighbour is never a scalar advance or an auto ACK.
                }
            }
        }

        private func validCurl(_ webView: WKWebView, pager: ReaderEbookCurlPager, generation: UUID, key: String, session: String) -> Bool {
            !retired && activeView === webView && curlPager === pager && pageGeneration == generation
                && self.session == session && usesNativeCurl && key == curlKey && !hasSelection
        }

        private func requestCurl(_ webView: WKWebView, direction: Int, request: UUID?) {
            guard !pageJavaScript.hasPendingCall(for: webView) else {
                if let request { parent.pageCommitted(request, .cancelled) }; return
            }
            guard layoutIsReady, !hasSelection, let pager = ensureCurl(webView),
                  activePageTurn == nil, !manualPage, !pager.isTurning else {
                if let request { parent.pageCommitted(request, .cancelled) }; return
            }
            guard curlPreparedKey == curlKey, pager.isReady else {
                if let request { parent.pageCommitted(request, .cancelled) }
                else { queuedManualDirection = (direction, false, nil); curlPreparationSuspended = false }
                prepareCurl(webView); return
            }
            guard pager.contains(direction) else {
                if let request { parent.pageCommitted(request, .chapterEnd) } else { parent.pageBoundary(direction) }
                return
            }
            activePageTurn = request; manualPage = request == nil; pageCallback = parent.pageCommitted
            if !pager.turn(direction) { cancelPage(webView) }
        }

        private func curlBegan(_ webView: WKWebView, pager: ReaderEbookCurlPager, token: UUID, direction: Int) {
            guard !retired, activeView === webView, curlPreparedKey == curlKey,
                  let target = curlDestinations[direction] else { pager.cancel(); return }
            pageGeneration = UUID(); let generation = pageGeneration
            pageStartOffset = webView.scrollView.contentOffset
            if activePageTurn == nil { manualPage = true; pageCallback = parent.pageCommitted; parent.manualInteraction() }
            curlTurnIdentity = token; curlFinished = nil; curlArmed = false; curlDirection = direction
            traceCurl("began", webView: webView)
            let key = curlKey, expectedSession = session
            webView.callAsyncJavaScript("return window.__readerEbook.pageTarget(direction)", arguments: ["direction": direction],
                in: nil, in: .defaultClient) { [weak self, weak webView, weak pager] result in
                    guard let self, let webView, let pager,
                          self.validCurl(webView, pager: pager, generation: generation, key: key, session: expectedSession),
                          self.curlTurnIdentity == token else { return }
                    guard case let .success(value) = result, let raw = value as? [String: Any], raw["end"] as? Bool != true,
                          let y = raw["y"] as? NSNumber, y.doubleValue.isFinite,
                          abs(CGFloat(y.doubleValue) - target.offset.y) <= 0.5,
                          let epoch = raw["epoch"] as? NSNumber else { self.cancelPage(webView); return }
                    self.pageEpoch = epoch.intValue; self.curlArmed = true
                    self.finishCurlIfArmed(webView, pager: pager, token: token, direction: direction)
                }
        }

        private func finishCurlIfArmed(_ webView: WKWebView, pager: ReaderEbookCurlPager, token: UUID, direction: Int) {
            guard curlTurnIdentity == token, let completed = curlFinished else { return }
            if !completed { cancelPage(webView); return }
            guard curlArmed, snapshotTask == nil, let target = curlDestinations[direction] else { return }
            // UIKit has completed and its old child may be off-window. Keep
            // the target snapshot above the sole live WK while WebKit settles;
            // no source position or automatic acknowledgement changes here.
            guard pager.stageSettlement(token) else { cancelPage(webView); return }
            traceCurl("settling-live", webView: webView)
            let generation = pageGeneration, key = curlKey, expectedSession = session, epoch = pageEpoch
            snapshotGeneration = generation
            snapshotTask = Task { [weak self, weak webView, weak pager] in
                guard let self, let webView, let pager else { return }
                defer {
                    if self.snapshotGeneration == generation {
                        self.snapshotTask = nil; self.snapshotGeneration = nil
                        self.prepareCurl(webView)
                    }
                }
                do {
                    guard try await self.curlGeometry(webView) == target.geometry else { throw ReaderEbookError.invalidDocument }
                    webView.scrollView.setContentOffset(target.offset, animated: false)
                    try await self.curlFrames(webView)
                    let value = try await self.pageJavaScript.call(webView, script: "return await window.__readerEbook.commitPage(epoch)",
                        arguments: ["epoch": epoch])
                    let actualGeometry = try await self.curlGeometry(webView)
                    try Task.checkCancellation()
                    guard self.validCurl(webView, pager: pager, generation: generation, key: key, session: expectedSession),
                          self.curlTurnIdentity == token, pager.stageSettlement(token), let scalar = value as? NSNumber,
                          scalar.doubleValue.isFinite, scalar.doubleValue >= 0, scalar.uint64Value == target.scalar,
                          actualGeometry == target.geometry else { throw ReaderEbookError.invalidDocument }
                    let request = self.activePageTurn, callback = self.pageCallback
                    self.activePageTurn = nil; self.manualPage = false; self.pageCallback = nil; self.pageStartOffset = nil
                    self.curlTurnIdentity = nil; self.curlFinished = nil; self.curlArmed = false
                    self.curlPreparedKey = nil; self.curlDestinations = [:]
                    pager.settled(committed: true, token: token)
                    self.traceCurl("settled-validated", webView: webView)
                    webView.callAsyncJavaScript("window.__readerEbook.acknowledgePage(epoch,scalar)",
                        arguments: ["epoch": epoch, "scalar": scalar], in: nil, in: .defaultClient, completionHandler: nil)
                    self.parent.positionChanged(scalar.uint64Value)
                    if let request { callback?(request, .advanced) }
                } catch {
                    if self.pageGeneration == generation { self.cancelPage(webView) }
                }
            }
        }

        private func curlFrames(_ webView: WKWebView) async throws {
            _ = try await pageJavaScript.call(webView,
                script: "await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))")
            try Task.checkCancellation()
        }

        private func traceCurl(_ event: String, webView: WKWebView) {
            #if DEBUG
            let generation = pageGeneration
            let geometry = "\(event) generation=\(generation) token=\(String(describing: curlTurnIdentity)) epoch=\(pageEpoch) window=\(webView.window != nil) offset=\(webView.scrollView.contentOffset) start=\(String(describing: pageStartOffset)) bounds=\(webView.bounds) zoom=\(webView.scrollView.zoomScale) layout=\(layoutToken)"
            readerEbookSurfaceLogger.info("\(geometry, privacy: .public)")
            webView.callAsyncJavaScript("return JSON.stringify({y:scrollY,top:document.scrollingElement?.scrollTop,width:innerWidth,height:innerHeight,scale:visualViewport?.scale,visibility:document.visibilityState})",
                arguments: [:], in: nil, in: .defaultClient) { result in
                    if case let .success(value) = result, let geometry = value as? String {
                        let message = "\(event)-dom generation=\(generation) geometry=\(geometry)"
                        readerEbookSurfaceLogger.info("\(message, privacy: .public)")
                    } else {
                        let message = "\(event)-dom generation=\(generation) geometry=unavailable"
                        readerEbookSurfaceLogger.info("\(message, privacy: .public)")
                    }
                }
            #endif
        }

        private func retireCurl(_ webView: WKWebView) {
            guard let pager = curlPager else { return }
            curlPager = nil; curlPaper = nil; curlPreparedKey = nil; curlDestinations = [:]
            pager.retire()
            container?.mount(webView)
        }

        private func advancePage(_ webView: WKWebView, direction: Int, request: UUID?, interactive: Bool = false) {
            if usesNativeCurl {
                requestCurl(webView, direction: direction < 0 ? -1 : 1, request: request)
                return
            }
            guard !pageJavaScript.hasPendingCall(for: webView) else {
                if let request { parent.pageCommitted(request, .cancelled) }; return
            }
            if snapshotTask != nil || nativeSnapshotRequest != nil {
                if let request { parent.pageCommitted(request, .cancelled) }
                else { queuedManualDirection = (direction, interactive, interactive ? panIdentity : nil) }
                return
            }
            guard layoutIsReady, !hasSelection, activePageTurn == nil, !manualPage else {
                if let request { parent.pageCommitted(request, .cancelled) }
                return
            }
            pageGeneration = UUID()
            let generation = pageGeneration
            activePageTurn = request
            manualPage = request == nil
            pageCallback = parent.pageCommitted
            pageStartOffset = webView.scrollView.contentOffset
            pageDirection = direction
            let expectedSession = session
            webView.callAsyncJavaScript("return window.__readerEbook.pageTarget(direction)", arguments: ["direction": direction],
                in: nil, in: .defaultClient) { [weak self, weak webView] result in
                guard let self, let webView, !self.retired, self.session == expectedSession,
                      self.activeView === webView, self.pageGeneration == generation else { return }
                guard case let .success(value) = result, let target = value as? [String: Any],
                      let y = target["y"] as? NSNumber, y.doubleValue.isFinite,
                      let epoch = target["epoch"] as? NSNumber else {
                    self.cancelPage(webView); return
                }
                self.pageEpoch = epoch.intValue
                if target["end"] as? Bool == true {
                    let callback = self.pageCallback
                    self.activePageTurn = nil; self.manualPage = false
                    self.pageCallback = nil; self.pageStartOffset = nil
                    if let request { callback?(request, .chapterEnd) }
                    else if interactive {
                        self.panBoundary = direction
                        if !self.panTracking, self.panRelease == true { self.parent.pageBoundary(direction); self.panBoundary = nil }
                    } else { self.parent.pageBoundary(direction) }
                    return
                }
                let destination = CGPoint(x: 0, y: CGFloat(y.doubleValue))
                if !self.parent.paged {
                    webView.scrollView.setContentOffset(destination,
                        animated: !(self.parent.reducePageMotion || self.parent.reduceMotion))
                    if self.parent.reducePageMotion || self.parent.reduceMotion {
                        self.commitPage(webView, generation: generation)
                    }
                } else if self.parent.reducePageMotion || self.parent.reduceMotion || self.parent.transition == .none {
                    webView.scrollView.setContentOffset(destination, animated: false)
                    self.commitPage(webView, generation: generation)
                } else {
                    self.animatePage(webView, destination: destination, direction: direction, generation: generation, interactive: interactive)
                }
            }
        }

        private func animatePage(_ webView: WKWebView, destination: CGPoint, direction: Int, generation: UUID, interactive: Bool) {
            guard let container, snapshotTask == nil else { cancelPage(webView); return }
            let transition = parent.transition
            let paper = UIColor(parent.paper.paper)
            snapshotGeneration = generation
            snapshotTask = Task { [weak self, weak webView, weak container] in
                guard let self, let webView, let container else { return }
                defer {
                    if self.snapshotGeneration == generation {
                        self.snapshotTask = nil; self.snapshotGeneration = nil
                        self.drainQueuedManual(webView)
                    }
                }
                do {
                    let before = try await self.snapshot(webView)
                    try Task.checkCancellation()
                    guard !self.retired, self.activeView === webView, self.pageGeneration == generation else { return }
                    let shield = UIImageView(image: before)
                    shield.frame = container.bounds; shield.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                    shield.contentMode = .scaleToFill; shield.backgroundColor = paper
                    shield.accessibilityElementsHidden = true
                    container.addSubview(shield); self.snapshotShield = shield
                    webView.scrollView.setContentOffset(destination, animated: false)
                    try await self.curlFrames(webView)
                    try Task.checkCancellation()
                    guard !self.retired, self.activeView === webView, self.pageGeneration == generation else { return }
                    let after = try await self.snapshot(webView)
                    try Task.checkCancellation()
                    guard !self.retired, self.activeView === webView, self.pageGeneration == generation else { return }
                    let animation = ReaderEbookPageTurn(in: container, before: before, after: after,
                        direction: direction, transition: transition, paper: paper, interactive: interactive) { [weak self, weak webView] committed in
                            guard let self, let webView, self.activeView === webView,
                                  self.pageGeneration == generation else { return }
                            self.pageAnimation = nil
                            if committed { self.commitPage(webView, generation: generation) }
                            else { self.cancelPage(webView) }
                        }
                    guard let animation else { self.cancelPage(webView); return }
                    self.pageAnimation = animation
                    if interactive {
                        animation.updateProgress(self.dragProgress(width: container.bounds.width))
                        if let released = self.panRelease { animation.release(commit: released, velocity: self.panVelocity) }
                    }
                    self.snapshotShield?.image = nil
                    self.snapshotShield?.removeFromSuperview(); self.snapshotShield = nil
                } catch {
                    if self.pageGeneration == generation { self.cancelPage(webView) }
                }
            }
        }

        private func snapshot(_ webView: WKWebView) async throws -> UIImage {
            try Task.checkCancellation()
            guard nativeSnapshotRequest == nil else { throw CancellationError() }
            let rect = webView.bounds
            guard rect.width > 0, rect.height > 0 else { throw ReaderEbookError.invalidDocument }
            let maximum = CGFloat(ReaderEbookPageTurn.maximumSnapshotPixels)
            let scale = min(webView.window?.screen.scale ?? 2, sqrt(maximum / (rect.width * rect.height)))
            let config = WKSnapshotConfiguration()
            config.rect = rect
            // WK snapshotWidth uses points and the result uses display scale.
            let displayScale = webView.window?.screen.scale ?? 2
            config.snapshotWidth = NSNumber(value: Double(floor(rect.width * scale / displayScale)))
            config.afterScreenUpdates = true
            let request = ReaderEbookSnapshotRequest { [weak self, weak webView] finished in
                guard let self, self.nativeSnapshotRequest === finished else { return }
                self.nativeSnapshotRequest = nil
                DispatchQueue.main.async { [weak self, weak webView] in
                    guard let self, let webView else { return }
                    self.drainQueuedManual(webView)
                }
            }
            nativeSnapshotRequest = request
            return try await request.capture(webView, configuration: config)
        }

        private func drainQueuedManual(_ webView: WKWebView) {
            guard !retired, activeView === webView, snapshotTask == nil, nativeSnapshotRequest == nil,
                  activePageTurn == nil, !manualPage, let queued = queuedManualDirection else { return }
            queuedManualDirection = nil
            guard !queued.interactive || queued.drag == panIdentity else { return }
            advancePage(webView, direction: queued.direction, request: nil, interactive: queued.interactive)
        }

        private func commitPage(_ webView: WKWebView, generation: UUID) {
            guard !retired, activeView === webView, pageGeneration == generation else { return }
            let epoch = pageEpoch
            webView.callAsyncJavaScript("return await window.__readerEbook.commitPage(epoch)", arguments: ["epoch": epoch],
                in: nil, in: .defaultClient) { [weak self, weak webView] result in
                    guard let self, let webView, !self.retired, self.activeView === webView,
                          self.pageGeneration == generation else { return }
                    guard case let .success(value) = result, let scalar = value as? NSNumber,
                          scalar.doubleValue.isFinite, scalar.doubleValue >= 0,
                          scalar.uint64Value <= self.parent.content.scalarCount else { self.cancelPage(webView); return }
                    let completed = self.activePageTurn, callback = self.pageCallback
                    self.activePageTurn = nil; self.manualPage = false
                    self.pageCallback = nil; self.pageStartOffset = nil
                    webView.callAsyncJavaScript("window.__readerEbook.acknowledgePage(epoch,scalar)",
                        arguments: ["epoch": epoch, "scalar": scalar], in: nil, in: .defaultClient, completionHandler: nil)
                    self.parent.positionChanged(scalar.uint64Value)
                    if let completed { callback?(completed, .advanced) }
                    self.drainQueuedManual(webView)
                }
        }

        private func cancelPage(_ webView: WKWebView) {
            if curlPager?.isTurning == true || curlTurnIdentity != nil { traceCurl("cancel-before", webView: webView) }
            let previous = activePageTurn
            let wasManual = manualPage
            let callback = pageCallback
            activePageTurn = nil; manualPage = false
            pageGeneration = UUID()
            pageCallback = nil
            queuedManualDirection = nil
            panTracking = false; panIdentity = nil; panRelease = nil; panBoundary = nil
            snapshotGeneration = nil
            snapshotTask?.cancel(); snapshotTask = nil
            nativeSnapshotRequest?.cancel()
            // Reader stops waiting immediately. The existing fire-and-forget
            // epoch cancellation below deliberately bypasses the drain fence.
            pageJavaScript.cancel()
            curlTurnIdentity = nil; curlFinished = nil; curlArmed = false
            curlPreparedKey = nil; curlDestinations = [:]
            curlPager?.cancel()
            pageAnimation?.cancel(); pageAnimation = nil
            snapshotShield?.image = nil
            snapshotShield?.removeFromSuperview(); snapshotShield = nil
            if previous != nil || wasManual || curlPreparationOffset != nil {
                webView.scrollView.setContentOffset(pageStartOffset ?? curlPreparationOffset ?? webView.scrollView.contentOffset, animated: false)
                webView.callAsyncJavaScript("window.__readerEbook?.cancelPage()", arguments: [:],
                    in: nil, in: .defaultClient, completionHandler: nil)
            }
            pageStartOffset = nil
            curlPreparationOffset = nil
            if usesNativeCurl { traceCurl("cancel-restored", webView: webView) }
            if let previous { callback?(previous, .cancelled) }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === pagePan, parent.paged, !hasSelection, layoutIsReady,
                  let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = pan.velocity(in: pan.view)
            if usesNativeCurl {
                // A missing chapter neighbour has no native page to curl.
                // Reuse only the boundary release gesture; all real page turns
                // remain owned by UIKit's own pan recognizer/data source.
                guard curlPreparedKey == curlKey, let curlPager, curlPager.isReady,
                      !curlPager.contains(velocity.x < 0 ? 1 : -1) else { return false }
            }
            return abs(velocity.x) > abs(velocity.y) && abs(velocity.x) > 1
        }

        @objc private func panned(_ pan: UIPanGestureRecognizer) {
            guard parent.paged, let webView = activeView, !retired else { return }
            let delta = pan.translation(in: pan.view)
            if usesNativeCurl {
                switch pan.state {
                case .began:
                    parent.manualInteraction(); panTracking = true
                    panDirection = pan.velocity(in: pan.view).x < 0 ? 1 : -1
                case .ended, .cancelled, .failed:
                    guard panTracking else { return }; panTracking = false
                    guard pan.state == .ended, -delta.x * CGFloat(panDirection) >= 8,
                          abs(delta.x) >= abs(delta.y) * 1.5, curlPreparedKey == curlKey,
                          curlPager?.contains(panDirection) == false else { return }
                    parent.pageBoundary(panDirection)
                default: break
                }
                return
            }
            let followsFinger = !(parent.reduceMotion || parent.reducePageMotion)
                && (parent.transition == .cover || parent.transition == .slide)
            switch pan.state {
            case .began:
                parent.manualInteraction()
                if followsFinger, let animation = pageAnimation, animation.canRegrab {
                    let original = activePageTurn, callback = pageCallback
                    activePageTurn = nil; pageCallback = nil; manualPage = true
                    if let original { callback?(original, .cancelled) }
                    panDirection = pageDirection; panStart = animation.pauseForInteraction()
                } else {
                    cancelPage(webView); panDirection = 0; panStart = 0
                }
                panIdentity = UUID(); panTracking = true; panRelease = nil; panBoundary = nil
                panDelta = .zero; panVelocity = 0; pan.setTranslation(.zero, in: pan.view)
            case .changed:
                guard panTracking else { return }
                panDelta = delta
                if followsFinger, panDirection == 0, abs(delta.x) >= 16, abs(delta.x) >= abs(delta.y) * 1.5 {
                    panDirection = delta.x < 0 ? 1 : -1
                    advancePage(webView, direction: panDirection, request: nil, interactive: true)
                }
                if followsFinger, panStart == 0, panDirection != 0,
                   delta.x * CGFloat(panDirection) > 16, abs(delta.x) >= abs(delta.y) * 1.5 {
                    cancelPage(webView)
                    panIdentity = UUID(); panTracking = true; panDelta = delta; panStart = 0
                    panDirection = delta.x < 0 ? 1 : -1
                    advancePage(webView, direction: panDirection, request: nil, interactive: true)
                }
                pageAnimation?.updateProgress(dragProgress(width: pan.view?.bounds.width ?? 0))
            case .ended, .cancelled, .failed:
                guard panTracking else { return }
                panTracking = false; panDelta = delta
                if panDirection == 0 { panDirection = delta.x < 0 ? 1 : -1 }
                let signed = panStart * (pan.view?.bounds.width ?? 0) - delta.x * CGFloat(panDirection)
                let qualifies = pan.state == .ended && signed >= 8 && abs(delta.y) < max(abs(delta.x), 8) * 1.5
                panRelease = qualifies
                panVelocity = pan.velocity(in: pan.view).x * -CGFloat(panDirection)
                if let boundary = panBoundary {
                    panBoundary = nil
                    if qualifies { parent.pageBoundary(boundary) } else { cancelPage(webView) }
                } else if let animation = pageAnimation, animation.canRegrab {
                    animation.release(commit: qualifies, velocity: panVelocity)
                } else if !qualifies { cancelPage(webView) }
                else if !manualPage && activePageTurn == nil {
                    advancePage(webView, direction: panDirection, request: nil)
                }
            default: break
            }
        }

        private func dragProgress(width: CGFloat) -> CGFloat {
            max(0, min(1, panStart - panDelta.x * CGFloat(panDirection) / max(1, width)))
        }

        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard !parent.paged, let webView = activeView, webView.scrollView === scrollView else { return }
            parent.manualInteraction(); cancelPage(webView)
        }

        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            // Paged transitions acknowledge only their exact native animator.
            // A late UIScrollView completion must not commit a new finger drag.
            guard !parent.paged, activePageTurn != nil || manualPage, let webView = activeView,
                  webView.scrollView === scrollView else { return }
            commitPage(webView, generation: pageGeneration)
        }

        func restore(_ webView: WKWebView) {
            guard !retired else { return }
            cancelPage(webView)
            webView.callAsyncJavaScript("window.__readerEbook?.restore(offset)",
                arguments: ["offset": min(parent.scalarOffset, parent.content.scalarCount)],
                in: nil, in: .defaultClient, completionHandler: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard !retired, message.frameInfo.isMainFrame,
                  let body = message.body as? [String: Any], body["session"] as? String == session,
                  let kind = body["kind"] as? String else { return }
            switch kind {
            case "ready":
                guard fontReady else { return }
                // Font preparation may finish before the original entry runs
                // its initial user script. Require that entry's actual layout
                // to report the current font; an earlier native configure call
                // against an empty page cannot count as applying the font.
                guard let value = body["value"] as? [String: Any], value["fontURL"] as? String == fontURL,
                      value["systemFont"] as? Bool == usesSystemFont,
                      value["layoutToken"] as? String == layoutToken else {
                    appearance = ""
                    if let activeView { configure(activeView) }
                    return
                }
                layoutIsReady = true
                if let webView = activeView { configure(webView); updatePageRequest(webView) }
                if !usesNativeCurl { parent.layoutReady() }
            case "manual":
                parent.manualInteraction()
                // The matching native pan owns this paged touch stream. Its
                // earlier JS touchstart can arrive after native .began.
                if usesNativeCurl, curlPager?.isTurning == true { break }
                if usesNativeCurl, snapshotTask == nil { break }
                if !panTracking, let activeView { cancelPage(activeView) }
            case "page":
                guard parent.paged, let number = body["value"] as? NSNumber, let webView = activeView else { return }
                parent.manualInteraction()
                advancePage(webView, direction: number.intValue < 0 ? -1 : 1, request: nil)
            case "inlineImage":
                guard let value = body["value"] as? [String: Any],
                      let id = value["id"] as? String, let ordinal = Int(id), ordinal >= 0, ordinal < 512,
                      let source = value["source"] as? String, let bridge, let webView = activeView else { return }
                let expectedSession = session
                Task { [weak self, weak webView] in
                    guard let self, let webView else { return }
                    do {
                        let url = try await bridge.registerInlineImage(source)
                        guard !self.retired, self.session == expectedSession, self.activeView === webView else { return }
                        webView.callAsyncJavaScript("window.__readerEbook?.inlineImage(id,url)",
                            arguments: ["id": id, "url": url.absoluteString], in: nil, in: .defaultClient, completionHandler: nil)
                    } catch {
                        // This image keeps its original, geometry-preserving
                        // missing-illustration state; the chapter stays usable.
                    }
                }
            case "position":
                guard curlPreparationOffset == nil, curlTurnIdentity == nil else { return }
                guard let number = body["value"] as? NSNumber, number.doubleValue.isFinite,
                      number.doubleValue >= 0, number.uint64Value <= parent.content.scalarCount else { return }
                parent.positionChanged(number.uint64Value)
            case "selection":
                guard !(body["value"] is NSNull) else {
                    hasSelection = false
                    parent.selectionChanged(0, 0, "")
                    if let activeView { configure(activeView) }
                    return
                }
                guard parent.longPressSelectText, let selection = body["value"] as? [String: Any],
                      let start = selection["start"] as? NSNumber, let end = selection["end"] as? NSNumber,
                      start.doubleValue.isFinite, end.doubleValue.isFinite, start.doubleValue >= 0,
                      start.uint64Value < end.uint64Value, end.uint64Value <= parent.content.scalarCount else { return }
                hasSelection = true
                if let activeView { cancelPage(activeView) }
                parent.manualInteraction()
                // The selected string is derived from current Core content,
                // never accepted as an independently authoritative DOM value.
                let scalars = parent.content.content.unicodeScalars
                let lower = scalars.index(scalars.startIndex, offsetBy: Int(start.uint64Value))
                let upper = scalars.index(scalars.startIndex, offsetBy: Int(end.uint64Value))
                parent.selectionChanged(start.uint64Value, end.uint64Value, String(scalars[lower..<upper]))
                if let activeView { configure(activeView) }
            case "center": parent.centerTapped()
            case "failure":
                let value = body["value"] as? [String: Any]
                let stage = value?["stage"] as? String ?? "script"
                let reason = value?["reason"] as? String ?? body["value"] as? String ?? "unknown"
                fail(.scriptFailure(stage: String(stage.prefix(64)), reason: String(reason.prefix(256))))
            default: break
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                     decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            guard !retired, let url = navigationAction.request.url,
                  (try? ReaderEbookResourcePath.entry(url: url, origin: session)) != nil else {
                decisionHandler(.cancel)
                return
            }
            if navigationAction.navigationType == .linkActivated {
                // Fragment links in this exact original entry remain native.
                // Cross-entry links require Core's directory target contract.
                let allowed = (try? ReaderEbookResourcePath.entry(url: url, origin: session)) == parent.document.entryPath
                decisionHandler(allowed ? .allow : .cancel)
            } else {
                let currentEntry = (try? ReaderEbookResourcePath.entry(url: url, origin: session)) == parent.document.entryPath
                let allowed = currentEntry && !initialNavigationAdmitted
                    && navigationAction.targetFrame?.isMainFrame != false && navigationAction.navigationType == .other
                if allowed { initialNavigationAdmitted = true }
                decisionHandler(allowed ? .allow : .cancel)
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            guard activeView === webView else { return }
            let native = error as NSError
            if native.code != NSURLErrorCancelled {
                fail(.navigationFailure(domain: native.domain, code: native.code, provisional: false))
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            guard activeView === webView else { return }
            let native = error as NSError
            if native.code != NSURLErrorCancelled {
                fail(.navigationFailure(domain: native.domain, code: native.code, provisional: true))
            }
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            if activeView === webView { fail(.resourceLimit) }
        }

        func retire() {
            if let activeView { cancelPage(activeView) }
            if let activeView { retireCurl(activeView) }
            retired = true
            fontTask?.cancel(); fontTask = nil
            activePageTurn = nil; manualPage = false; hasSelection = false
            if let pagePan { pagePan.view?.removeGestureRecognizer(pagePan) }
            pagePan = nil
            container?.viewportChanged = nil
            container = nil
            bridge?.retire()
            bridge = nil
            activeView?.stopLoading()
            pageJavaScript.retire()
            activeView?.navigationDelegate = nil
            activeView?.scrollView.delegate = nil
            activeView?.configuration.userContentController.removeScriptMessageHandler(forName: "readerEbook", contentWorld: .defaultClient)
            activeView?.configuration.userContentController.removeAllUserScripts()
            activeView = nil
        }

        private func fail(_ error: ReaderEbookError) {
            guard !retired else { return }
            let callback = parent.failed
            let expectedSession = session
            retire()
            DispatchQueue.main.async { [weak self] in
                guard self?.session == expectedSession else { return }
                callback(error)
            }
        }

        private func metrics() -> [String: Any] {
            let ranges = parent.highlights.compactMap { mark -> [String: Int]? in
                guard let scope = mark.positionScope, scope.sourceId == parent.content.sourceId,
                      scope.bookId == parent.content.bookId, scope.chapterIndex == parent.content.chapterIndex,
                      scope.bodyVersion == parent.content.bodyVersion, scope.processingVersion == parent.content.processingVersion,
                      mark.chapterPos >= 0, mark.chapterPosEnd > mark.chapterPos,
                      UInt64(mark.chapterPosEnd) <= parent.content.scalarCount else { return nil }
                return ["start": Int(mark.chapterPos), "end": Int(mark.chapterPosEnd)]
            }
            return ["fontSize": parent.fontSize, "lineHeight": parent.lineHeight,
             "horizontalInset": parent.horizontalInset, "leftInset": max(0, parent.horizontalInset - parent.safeLeft),
             "rightInset": max(0, parent.horizontalInset - parent.safeRight), "topInset": 8,
             "fontURL": fontURL, "paragraphSpacing": parent.paragraphSpacing,
             "fontVariations": Self.variations(parent.readerFont),
             "systemFont": usesSystemFont,
             "layoutToken": layoutToken,
             "letterSpacing": parent.letterSpacing, "firstLineIndentEm": parent.firstLineIndentEm,
             "alignment": parent.alignment == .justified ? "justify" : "left", "paged": parent.paged,
             "longPressSelectText": parent.longPressSelectText,
             "highlights": ranges, "automaticHighlightProgress": parent.automaticHighlightProgress as Any? ?? NSNull(),
             "bottomInset": parent.bottomInset, "dark": parent.paper.theme.isDark,
             "ink": Self.hex(UIColor(parent.paper.ink)), "meta": Self.hex(UIColor(parent.paper.meta)),
             "selection": Self.hex(UIColor(parent.paper.selection)), "reduceMotion": parent.reduceMotion || parent.reducePageMotion]
        }

        private static func hex(_ color: UIColor) -> String {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
        }

        private var usesSystemFont: Bool {
            let requested = parent.readerFont?.fontName ?? parent.fontName ?? ReaderTypography.readingFont(size: parent.fontSize).fontName
            return requested == UIFont.systemFont(ofSize: parent.fontSize).fontName
        }

        private static func variations(_ font: UIFont?) -> [String: Double] {
            guard let font, let values = CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber] else { return [:] }
            var result: [String: Double] = [:]
            for (axis, number) in values where number.doubleValue.isFinite {
                let code = axis.uint32Value
                let bytes = [UInt8((code >> 24) & 255), UInt8((code >> 16) & 255), UInt8((code >> 8) & 255), UInt8(code & 255)]
                guard bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }), let tag = String(bytes: bytes, encoding: .ascii) else { continue }
                result[tag] = number.doubleValue
            }
            return result
        }
    }
}

@MainActor
private final class ReaderEbookWebView: WKWebView {
    var bookmarkAction: (() -> Void)?
    var noteAction: (() -> Void)?
    var bookmarkEnabled = false
    var noteEnabled = false
    var pageScroll: ((Int) -> Bool)?

    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        if direction == .left, pageScroll?(1) == true { return true }
        if direction == .right, pageScroll?(-1) == true { return true }
        return super.accessibilityScroll(direction)
    }

    override func buildMenu(with builder: any UIMenuBuilder) {
        super.buildMenu(with: builder)
        var actions: [UIMenuElement] = []
        if bookmarkEnabled { actions.append(UIAction(title: "添加书签") { [weak self] _ in self?.bookmarkAction?() }) }
        if noteEnabled { actions.append(UIAction(title: "高亮与笔记") { [weak self] _ in self?.noteAction?() }) }
        if !actions.isEmpty {
            builder.insertSibling(UIMenu(title: "", options: .displayInline, children: actions), afterMenu: .standardEdit)
        }
    }
}

@MainActor
final class ReaderEbookContainer: UIView {
    private(set) var webView: WKWebView?
    var viewportChanged: (() -> Void)?
    private var measuredSize = CGSize.zero

    override func layoutSubviews() {
        super.layoutSubviews()
        if measuredSize != bounds.size {
            let previous = measuredSize
            measuredSize = bounds.size
            if previous != .zero { viewportChanged?() }
        }
    }
    func replace(with view: WKWebView?) {
        webView?.removeFromSuperview()
        webView = view
        guard let view else { return }
        mount(view)
    }
    func mount(_ view: WKWebView) {
        view.removeFromSuperview()
        view.translatesAutoresizingMaskIntoConstraints = true
        view.frame = bounds; view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(view)
    }
}

@MainActor
private final class ReaderEbookWeakMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: (any WKScriptMessageHandler)?
    init(_ target: any WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

/// A cancelled native JS call can still be awaiting a WebKit Promise. Keep one
/// small drain fence per active WK, without retaining the Reader owner or WK.
/// A different WK supersedes an already cancelled old document's fence; its
/// late callback cannot clear the new document's request or replay any action.
@MainActor
final class ReaderEbookJavaScriptGate {
    private(set) var pendingRequest: ReaderEbookJavaScriptRequest?

    func hasPendingCall(for web: WKWebView) -> Bool { pendingRequest?.belongs(to: web) == true }

    func call(_ web: WKWebView, script: String, arguments: [String: Any] = [:]) async throws -> Any? {
        try Task.checkCancellation()
        if let pendingRequest {
            guard !pendingRequest.belongs(to: web), pendingRequest.isCancelled else { throw ReaderEbookError.resourceLimit }
        }
        let request = ReaderEbookJavaScriptRequest(webView: web) { [weak self] finished in
            guard self?.pendingRequest === finished else { return }
            self?.pendingRequest = nil // Drain metadata only; never replay a turn.
        }
        pendingRequest = request
        let value = try await request.call(web, script: script, arguments: arguments)
        try Task.checkCancellation()
        return value
    }

    func cancel() { pendingRequest?.cancel() }
    func retire() { pendingRequest?.cancel(); pendingRequest = nil }
}

/// Cancelling resumes Reader's waiter, not WebKit's internal Promise. The
/// native completion captures only this request weakly. Once its continuation
/// is released, it cannot keep a suspended Reader Task/owner/WK/image alive.
@MainActor
final class ReaderEbookJavaScriptRequest {
    private weak var webView: WKWebView?
    private var continuation: CheckedContinuation<Any?, Error>?
    private var cancelled = false
    var isCancelled: Bool { cancelled }
    private var started = false
    private(set) var isDrained = false
    private let didFinishNative: (ReaderEbookJavaScriptRequest) -> Void

    init(webView: WKWebView, didFinishNative: @escaping (ReaderEbookJavaScriptRequest) -> Void = { _ in }) {
        self.webView = webView; self.didFinishNative = didFinishNative
    }

    func belongs(to web: WKWebView) -> Bool { webView === web }

    func call(_ web: WKWebView, script: String, arguments: [String: Any]) async throws -> Any? {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (waiting: CheckedContinuation<Any?, Error>) in
                guard !cancelled, !Task.isCancelled, !started, belongs(to: web) else {
                    cancel(); waiting.resume(throwing: CancellationError()); return
                }
                continuation = waiting; started = true
                web.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .defaultClient) { [weak self] result in
                    guard let self else { return }
                    let waiting = self.continuation; self.continuation = nil
                    self.finishNative()
                    guard !self.cancelled else { return }
                    switch result {
                    case let .success(value): waiting?.resume(returning: value)
                    case let .failure(error): waiting?.resume(throwing: error)
                    }
                }
            }
        }, onCancel: { Task { @MainActor [weak self] in self?.cancel() } })
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        let waiting = continuation; continuation = nil
        waiting?.resume(throwing: CancellationError())
        if !started { finishNative() }
    }

    private func finishNative() {
        guard !isDrained else { return }
        isDrained = true
        didFinishNative(self)
    }
}

/// WK has no public cancellation API for takeSnapshot. Cancelling the Swift
/// waiter resumes it immediately, releases its continuation and ignores late
/// pixels. The owner retains only this small native fence until WK calls back,
/// preventing a cancelled operation from starting overlapping snapshot work.
@MainActor
final class ReaderEbookSnapshotRequest {
    private var continuation: CheckedContinuation<UIImage, Error>?
    private var cancelled = false
    private var started = false
    private var nativeFinished = false
    private let didFinishNative: (ReaderEbookSnapshotRequest) -> Void

    init(didFinishNative: @escaping (ReaderEbookSnapshotRequest) -> Void = { _ in }) {
        self.didFinishNative = didFinishNative
    }

    func capture(_ web: WKWebView, configuration: WKSnapshotConfiguration) async throws -> UIImage {
        try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
                guard !cancelled, !Task.isCancelled else {
                    cancel(); continuation.resume(throwing: CancellationError()); return
                }
                self.continuation = continuation
                started = true
                web.takeSnapshot(with: configuration) { [weak self] image, error in
                    guard let self else { return }
                    let waiting = self.continuation; self.continuation = nil
                    self.finishNative()
                    guard !self.cancelled else { return }
                    if let error { waiting?.resume(throwing: error) }
                    else if let image, ReaderEbookPageTurn.accepts(image) { waiting?.resume(returning: image) }
                    else { waiting?.resume(throwing: ReaderEbookError.resourceLimit) }
                }
            }
        }, onCancel: { Task { @MainActor [weak self] in self?.cancel() } })
    }

    func cancel() {
        guard !cancelled else { return }
        cancelled = true
        let waiting = continuation; continuation = nil
        waiting?.resume(throwing: CancellationError())
        if !started { finishNative() }
    }

    private func finishNative() {
        guard !nativeFinished else { return }
        nativeFinished = true
        didFinishNative(self)
    }
}
