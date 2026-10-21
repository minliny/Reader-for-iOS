import SwiftUI
import UIKit
#if DEBUG
import OSLog
#endif

/// Host33f7 ReaderSettingsState keeps navigation and visual transition separate.
enum ReaderPageTransition: String, Codable, CaseIterable, Identifiable {
    case simulation, cover, slide, none
    var id: String { rawValue }
    var displayName: String {
        switch self { case .simulation: return "仿真"; case .cover: return "覆盖"; case .slide: return "滑动"; case .none: return "无动画" }
    }
}

/// TextKit's linked containers measure physical pages. UIPageViewController
/// supplies Apple's curl/slide; cover moves actual native page views over a
/// stationary neighbor. No character-count pagination or second text parser.
struct ReaderPagedTextSurface: UIViewControllerRepresentable {
    let content: ReaderChapterContent
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
    let centerTapped: () -> Void
    var selectionChanged: (UInt64, UInt64, String) -> Void = { _, _, _ in }
    var bookmarkSelectionAction: (() -> Void)? = nil
    var noteSelectionAction: (() -> Void)? = nil
    var fontName: String? = nil
    var paragraphSpacing: CGFloat = 16
    var letterSpacing: CGFloat = 0
    var firstLineIndentEm: CGFloat = 0
    var alignment: NSTextAlignment = .justified
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
    var alignPageBottom = false
    var imageAssets: ReaderChapterImageAssets = .empty
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> ReaderPagedContainerController {
        let controller = ReaderPagedContainerController()
        context.coordinator.mount(controller)
        return controller
    }
    func updateUIViewController(_ controller: ReaderPagedContainerController, context: Context) {
        context.coordinator.update(self, in: controller)
    }
    static func dismantleUIViewController(_ controller: ReaderPagedContainerController, coordinator: Coordinator) {
        coordinator.retire()
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate,
                             UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: ReaderPagedTextSurface
        private weak var host: ReaderPagedContainerController?
        private var document: ReaderNativePageDocument?
        private var pager: UIPageViewController?
        private var currentPage: ReaderNativeTextPageController?
        private var cache: [Int: ReaderNativeTextPageController] = [:]
        private var weakPages: [Int: ReaderWeakTextPage] = [:]
        private var logicalIndex = 0
        private var signature = ""
        private var size = CGSize.zero
        private var restoration: UUID?
        private var generation = UUID()
        private var scheduled = false
        private var restoring = true
        private var retired = false
        private var nativeTransitioning = false
        private var programmaticTransitioning = false
        private var nativePanIDs = Set<ObjectIdentifier>()
        private var nativePanOrigins: [ObjectIdentifier: (index: Int, generation: UUID)] = [:]
        private var nativeBoundarySent = false
        private var manualQueue: [Int] = []
        private var lastAutomaticID: UUID?
        private var queuedAutomatic: (id: UUID, chapter: String, callback: (UUID, ReaderNativePageOutcome) -> Void)?
        private var activeAutomatic: (id: UUID, callback: (UUID, ReaderNativePageOutcome) -> Void)?
        private var cover: ReaderNativeCoverTurn?
        private var displayLink: CADisplayLink?
        private weak var readingTap: UITapGestureRecognizer?
        private let paperSelectionTap = ReaderPaperSelectionTap()
        private var customPan: UIPanGestureRecognizer?
        private var panDirection = 0
        private var panStart: CGFloat = 0
        private var pendingScalar: UInt64?
        private var visibleScalar: UInt64?
        private var pendingSelection: NSRange?
#if DEBUG
        private static let gestureLog = Logger(subsystem: "io.reader.minliny", category: "reader-gestures")
        private let observedGestures = NSHashTable<UIGestureRecognizer>.weakObjects()

        /// Diagnostics contain no book, chapter, content, operation or network
        /// identifiers. Observation does not alter native gesture arbitration.
        private func traceGesture(_ event: String, recognizer: UIGestureRecognizer? = nil,
                                  accepted: Bool? = nil, center: Bool? = nil) {
            let recognizerClass = recognizer.map { NSStringFromClass(type(of: $0)) } ?? "none"
            let state = recognizer?.state.rawValue ?? -1
            let tapsRequired = (recognizer as? UITapGestureRecognizer)?.numberOfTapsRequired ?? -1
            let hasPage = currentPage != nil
            let selectionLength = currentPage?.textView?.selectedRange.length ?? -1
            let acceptedValue = accepted.map { String($0) } ?? "na"
            let centerValue = center.map { String($0) } ?? "na"
            Self.gestureLog.notice("event=\(event, privacy: .public) configuredTransition=\(self.parent.transition.rawValue, privacy: .public) transition=\(self.effectiveTransition.rawValue, privacy: .public) retired=\(self.retired, privacy: .public) restoring=\(self.restoring, privacy: .public) currentPage=\(hasPage, privacy: .public) selectionLength=\(selectionLength, privacy: .public) accepted=\(acceptedValue, privacy: .public) center=\(centerValue, privacy: .public) recognizer=\(recognizerClass, privacy: .public) state=\(state, privacy: .public) tapsRequired=\(tapsRequired, privacy: .public)")
        }

        private func observeExistingGestures(in view: UIView) {
            func observe(_ view: UIView) {
                for recognizer in view.gestureRecognizers ?? [] {
                    // Our recognizers already log their delegate decisions and
                    // tap action. Only add passive targets to existing UIKit /
                    // ancestor recognizers; never replace their delegates.
                    guard recognizer.delegate !== self, !observedGestures.contains(recognizer) else { continue }
                    observedGestures.add(recognizer)
                    recognizer.addTarget(self, action: #selector(observedGesture(_:)))
                    traceGesture("recognizer.observed", recognizer: recognizer)
                }
            }
            func descend(_ view: UIView) {
                observe(view)
                view.subviews.forEach(descend)
            }
            descend(view)
            var ancestor = view.superview
            while let current = ancestor { observe(current); ancestor = current.superview }
        }

        @objc private func observedGesture(_ recognizer: UIGestureRecognizer) {
            traceGesture("recognizer.action", recognizer: recognizer)
        }
#endif

        init(_ parent: ReaderPagedTextSurface) { self.parent = parent }
        private var chapterIdentity: String {
            "\(parent.content.sourceId)|\(parent.content.bookId)|\(parent.content.chapterIndex)|\(parent.content.bodyVersion ?? "")|\(parent.content.processingVersion ?? "")"
        }
        private var effectiveTransition: ReaderPageTransition {
            parent.reducePageMotion || parent.systemReduceMotion ? .none : parent.transition
        }
        private var navigating: Bool { nativeTransitioning || programmaticTransitioning || cover != nil }

        func mount(_ host: ReaderPagedContainerController) {
            self.host = host
            host.loadViewIfNeeded()
            host.afterLayout = { [weak self] dimensions in
                guard let self, !self.retired else { return }
#if DEBUG
                if let view = self.host?.view { self.observeExistingGestures(in: view) }
#endif
                if abs(self.size.width - dimensions.width) > 0.5 || abs(self.size.height - dimensions.height) > 0.5 {
                    self.scheduleLayout()
                }
            }
            let tap = UITapGestureRecognizer(target: self, action: #selector(tapped(_:)))
            tap.numberOfTapsRequired = 1
            tap.cancelsTouchesInView = false; tap.delegate = self
            host.view.addGestureRecognizer(tap); readingTap = tap
            let pan = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
            pan.maximumNumberOfTouches = 1; pan.delegate = self
            host.view.addGestureRecognizer(pan); customPan = pan
#if DEBUG
            traceGesture("mount", recognizer: tap)
#endif
        }

        func update(_ parent: ReaderPagedTextSurface, in host: ReaderPagedContainerController) {
            let keepScalar = restoration == parent.restorationID && document?.identity == ReaderChapterImageIdentity(parent.content)
            self.parent = parent
#if DEBUG
            traceGesture("update")
#endif
            updatePageAccessibility()
            let nextSignature = "\(parent.content.hashValue)|\(parent.fontSize)|\(parent.lineHeight)|\(parent.horizontalInset)|\(parent.safeLeft)|\(parent.safeRight)|\(parent.bottomInset)|\(parent.paper.theme.rawValue)|\(parent.dynamicTypeSize)|\(parent.fontName ?? "")|\(parent.readerFont?.fontDescriptor.hash ?? 0)|\(parent.paragraphSpacing)|\(parent.letterSpacing)|\(parent.firstLineIndentEm)|\(parent.alignment.rawValue)|\(parent.highlights.hashValue)|\(effectiveTransition.rawValue)|\(parent.alignPageBottom)|\(parent.imageAssets.revision)"
            if signature != nextSignature || restoration != parent.restorationID {
                signature = nextSignature; restoration = parent.restorationID
                scheduleLayout(restoring: keepScalar ? nil : parent.scalarOffset)
            }
            if !parent.automaticPageEnabled {
                queuedAutomatic = nil
                if activeAutomatic != nil { cancelAutomatic() }
            } else if let id = parent.pageTurnID, id != lastAutomaticID {
                lastAutomaticID = id
                queuedAutomatic = (id, chapterIdentity, parent.pageCommitted)
                DispatchQueue.main.async { [weak self] in self?.beginQueuedAutomatic() }
            }
            updateFollowHighlight()
        }

        private func scheduleLayout(restoring scalar: UInt64? = nil) {
            if let scalar { pendingScalar = scalar; pendingSelection = nil }
            else if pendingScalar == nil {
                pendingScalar = document?.identity == ReaderChapterImageIdentity(parent.content)
                    ? (visibleScalar ?? parent.scalarOffset) : parent.scalarOffset
                if let selection = currentPage?.textView.selectedRange, selection.location != NSNotFound, selection.length > 0 {
                    pendingSelection = selection
                }
            }
            guard !retired, !scheduled else { return }
            scheduled = true; restoring = true
#if DEBUG
            traceGesture("restore.begin")
#endif
            // Invalidate callbacks immediately, before a replacement chapter's
            // SwiftUI closures can receive an old native transition completion.
            cancelNavigation()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.scheduled = false
                self.rebuildDocument()
            }
        }

        private func rebuildDocument() {
            guard !retired, let host, host.view.bounds.width > 0, host.view.bounds.height > 0 else { return }
            let dimensions = host.view.bounds.size
            let next: ReaderNativePageDocument
            do { next = try ReaderNativePageDocument(parent, size: dimensions) }
            catch {
                cancelNavigation()
                size = dimensions
                let message = UIHostingController(rootView: ReaderPageState(title: "阅读空间不足", detail: "调整窗口或字号后继续阅读。"))
                removeChildren(); document = nil; cache = [:]; weakPages = [:]
                host.addChild(message); message.view.frame = host.view.bounds
                host.view.addSubview(message.view); message.didMove(toParent: host)
                return
            }
            // Keep the resident old page until its replacement has complete
            // TextKit ranges. Only then replace the platform presentation tree.
            cancelNavigation()
            removeChildren()
            document = next; size = dimensions
            let restoredScalar = pendingScalar ?? parent.scalarOffset
            logicalIndex = next.index(containing: restoredScalar)
            visibleScalar = restoredScalar
            pendingScalar = nil
            cache = [:]; weakPages = [:]
            installNavigator()
            if parent.longPressSelectText, let selection = pendingSelection,
               NSMaxRange(selection) <= next.storage.length {
                currentPage?.textView.selectedRange = selection
            }
            pendingSelection = nil
            let expected = generation
            DispatchQueue.main.async { [weak self] in
                guard let self, !self.retired, self.generation == expected else { return }
                self.currentPage?.view.layoutIfNeeded()
                self.restoring = false
#if DEBUG
                self.traceGesture("restore.end")
                if let view = self.host?.view { self.observeExistingGestures(in: view) }
#endif
                self.updateFollowHighlight()
                if self.parent.imageAssets.settled(for: self.parent.content) {
                    self.parent.layoutReady()
                    self.beginQueuedAutomatic()
                }
            }
        }

        private func installNavigator() {
            guard let host, let document else { return }
            currentPage = page(logicalIndex)
            guard let currentPage else { return }
            customPan?.isEnabled = effectiveTransition == .cover || effectiveTransition == .none
            if effectiveTransition == .cover {
                mountPage(currentPage)
            } else {
                let style: UIPageViewController.TransitionStyle = effectiveTransition == .simulation ? .pageCurl : .scroll
                let controller = UIPageViewController(transitionStyle: style, navigationOrientation: .horizontal,
                    options: style == .pageCurl ? [.spineLocation: UIPageViewController.SpineLocation.min.rawValue] : [.interPageSpacing: 0])
                controller.isDoubleSided = false
                controller.delegate = self
                controller.dataSource = effectiveTransition == .none ? nil : self
                controller.view.backgroundColor = UIColor(document.paper.paper)
                host.addChild(controller); controller.view.frame = host.view.bounds
                host.view.addSubview(controller.view); controller.didMove(toParent: host)
                pager = controller
                controller.setViewControllers([currentPage], direction: .forward, animated: false)
                configureNativeGestures(controller.view)
                for recognizer in controller.gestureRecognizers {
                    if recognizer is UITapGestureRecognizer { recognizer.isEnabled = false }
                    else if let pan = recognizer as? UIPanGestureRecognizer { observeNativePan(pan) }
                }
            }
            updatePageAccessibility()
        }

        private func configureNativeGestures(_ view: UIView) {
            if let scroll = view as? UIScrollView, !(scroll is UITextView) {
                scroll.contentInsetAdjustmentBehavior = .never
                scroll.isScrollEnabled = effectiveTransition != .none
                observeNativePan(scroll.panGestureRecognizer)
            }
            view.subviews.forEach(configureNativeGestures)
        }
        private func observeNativePan(_ recognizer: UIPanGestureRecognizer) {
            let identity = ObjectIdentifier(recognizer)
            guard nativePanIDs.insert(identity).inserted else { return }
            recognizer.addTarget(self, action: #selector(nativePanned(_:)))
        }

        private func page(_ index: Int) -> ReaderNativeTextPageController? {
            guard let document, document.ranges.indices.contains(index) else { return nil }
            if let found = cache[index] ?? weakPages[index]?.value {
                cache[index] = found
                found.setCommittedAccessibility(index == logicalIndex)
                found.textView.isSelectable = parent.longPressSelectText
                return found
            }
            let result = ReaderNativeTextPageController(document: document, index: index)
            result.loadViewIfNeeded()
            result.setCommittedAccessibility(index == logicalIndex)
            result.textView.isSelectable = parent.longPressSelectText
            result.textView.delegate = self
            result.textView.pageScroll = { [weak self] direction in self?.manualTurn(direction) }
            result.textView.accessibilityCustomActions = [UIAccessibilityCustomAction(name: "阅读控制") { [weak self] _ in
                guard let self else { return false }; self.manualBegan(); self.parent.centerTapped(); return true
            }]
            cache[index] = result; weakPages[index] = ReaderWeakTextPage(result)
            return result
        }

        private func mountPage(_ page: ReaderNativeTextPageController) {
            guard let host else { return }
            if page.parent !== host {
                page.willMove(toParent: nil); page.view.removeFromSuperview(); page.removeFromParent()
                host.addChild(page); host.view.addSubview(page.view); page.didMove(toParent: host)
            }
            page.view.frame = host.view.bounds
        }

        private func removeChildren() {
            displayLink?.invalidate(); displayLink = nil
            pager = nil; currentPage = nil; nativePanIDs = []; nativePanOrigins = [:]
            for controller in cache.values where controller.parent != nil {
                controller.willMove(toParent: nil); controller.view.removeFromSuperview(); controller.removeFromParent()
            }
            for child in host?.children ?? [] {
                child.willMove(toParent: nil); child.view.removeFromSuperview(); child.removeFromParent()
            }
        }

        func retire() {
            retired = true; scheduled = false
#if DEBUG
            traceGesture("retire")
            for recognizer in observedGestures.allObjects {
                recognizer.removeTarget(self, action: #selector(observedGesture(_:)))
            }
            observedGestures.removeAllObjects()
#endif
            cancelNavigation(); queuedAutomatic = nil; manualQueue = []
            removeChildren(); document = nil; cache = [:]; weakPages = [:]
            host?.afterLayout = nil
        }

        private func cancelNavigation() {
            generation = UUID()
            if let cover {
                cover.animator.stopAnimation(true)
                cover.moving.layer.shadowOpacity = 0
                cover.outgoing.view.transform = .identity; cover.incoming.view.transform = .identity
                cover.incoming.willMove(toParent: nil)
                cover.incoming.view.removeFromSuperview(); cover.incoming.removeFromParent()
                host?.view.bringSubviewToFront(cover.outgoing.view)
                self.cover = nil
            }
            displayLink?.invalidate(); displayLink = nil
            nativeTransitioning = false; programmaticTransitioning = false
            manualQueue = []
            finishAutomatic(.cancelled)
        }

        private func cancelAutomatic() {
            queuedAutomatic = nil
            if let cover, activeAutomatic != nil {
                guard cover.wantsCommit || !cover.animator.isReversed else { return }
                cover.wantsCommit = false
                cover.animator.pauseAnimation(); cover.animator.isReversed = true
                cover.animator.continueAnimation(withTimingParameters: nil, durationFactor: 1)
            } else if activeAutomatic != nil {
                cancelNavigation()
                removeChildren(); installNavigator()
            }
        }

        private func manualBegan(regrab: Bool = false) {
            parent.manualInteraction()
            if let queued = queuedAutomatic {
                queuedAutomatic = nil; queued.callback(queued.id, .cancelled)
            }
            if activeAutomatic != nil {
                if let cover, regrab {
                    cover.animator.pauseAnimation()
                    finishAutomatic(.cancelled)
                } else { cancelAutomatic() }
            }
        }
        private func manualTurn(_ direction: Int) { manualBegan(); turn(direction, automatic: false) }

        private func beginQueuedAutomatic() {
            guard !retired, !restoring, !navigating, parent.imageAssets.settled(for: parent.content), parent.automaticPageEnabled,
                  let queued = queuedAutomatic, queued.id == parent.pageTurnID else { return }
            queuedAutomatic = nil
            guard queued.chapter == chapterIdentity else { queued.callback(queued.id, .cancelled); return }
            activeAutomatic = (queued.id, queued.callback)
            turn(1, automatic: true)
        }
        private func finishAutomatic(_ outcome: ReaderNativePageOutcome) {
            guard let accepted = activeAutomatic else { return }
            activeAutomatic = nil
            DispatchQueue.main.async { accepted.callback(accepted.id, outcome) }
        }

        private func turn(_ direction: Int, automatic: Bool) {
            guard !retired, !restoring, let document, direction == -1 || direction == 1 else { return }
            if navigating { if !automatic { manualQueue.append(direction) }; return }
            let next = logicalIndex + direction
            guard document.ranges.indices.contains(next) else {
                manualQueue = []
                if automatic { finishAutomatic(direction > 0 ? .chapterEnd : .cancelled) }
                else { parent.pageBoundary(direction) }
                return
            }
            currentPage?.textView.selectedRange = NSRange(location: 0, length: 0)
            if effectiveTransition == .cover {
                beginCover(direction: direction, interactive: false)
            } else if let pager, let destination = page(next) {
                programmaticTransitioning = true
                pager.view.isUserInteractionEnabled = false
                let expected = generation
                pager.setViewControllers([destination], direction: direction > 0 ? .forward : .reverse,
                    animated: effectiveTransition != .none) { [weak self, weak pager] finished in
                    guard let self, !self.retired, !self.restoring, self.generation == expected, self.pager === pager else { return }
                    self.programmaticTransitioning = false
                    pager?.view.isUserInteractionEnabled = true
                    if finished { self.commit(next) } else { self.finishAutomatic(.cancelled) }
                    self.drainManualQueue()
                }
            }
        }

        private func commit(_ index: Int) {
            guard let document, document.ranges.indices.contains(index), let committed = page(index) else { return }
            logicalIndex = index; currentPage = committed
            visibleScalar = document.sourceOffset(at: index)
            updatePageAccessibility()
            cache = cache.filter { abs($0.key - index) <= 1 }
            parent.positionChanged(document.sourceOffset(at: index))
            updateFollowHighlight(); finishAutomatic(.advanced)
        }
        private func drainManualQueue() {
            guard !retired, !restoring, !navigating else { return }
            if !manualQueue.isEmpty {
                let direction = manualQueue.removeFirst()
                let expected = generation
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.generation == expected else { return }
                    self.turn(direction, automatic: false)
                }
            } else { beginQueuedAutomatic() }
        }
        private func updatePageAccessibility() {
            // UIPageViewController may retain neighbors after our strong cache
            // releases them. Project the committed state over every resident
            // page, including its text element, without changing selection.
            var residents = cache
            for (index, reference) in weakPages {
                if let controller = reference.value { residents[index] = controller }
            }
            for (index, controller) in residents {
                controller.setCommittedAccessibility(index == logicalIndex)
                controller.textView.isSelectable = parent.longPressSelectText
            }
        }

        func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard pageViewController === pager, currentPage?.textView.selectedRange.length == 0,
                  let page = viewController as? ReaderNativeTextPageController else { return nil }
            return self.page(page.index - 1)
        }
        func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard pageViewController === pager, currentPage?.textView.selectedRange.length == 0,
                  let page = viewController as? ReaderNativeTextPageController else { return nil }
            return self.page(page.index + 1)
        }
        func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
            guard pageViewController === pager, !restoring, !retired else { return }
            nativeTransitioning = true; manualBegan()
        }
        func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard pageViewController === pager, !restoring else { return }
            nativeTransitioning = false
            if completed, let page = pageViewController.viewControllers?.first as? ReaderNativeTextPageController { commit(page.index) }
            else { updatePageAccessibility() }
            drainManualQueue()
        }

        @objc private func tapped(_ gesture: UITapGestureRecognizer) {
#if DEBUG
            traceGesture("tapped.enter", recognizer: gesture)
#endif
            guard gesture === readingTap, gesture.state == .ended, !retired, !restoring, !navigating,
                  let text = currentPage?.textView else {
#if DEBUG
                traceGesture("tapped.rejected", recognizer: gesture, accepted: false)
#endif
                return
            }
            completePaperTap(at: gesture.location(in: text), in: text)
        }

        func preparePaperTap(at point: CGPoint, in text: UITextView, touchedView: UIView? = nil) -> Bool {
            guard !retired, !restoring, !navigating, text === currentPage?.textView else { return false }
            return paperSelectionTap.prepare(at: point, in: text, touchedView: touchedView, generation: generation)
        }

        func completePaperTap(at point: CGPoint, in text: UITextView) {
            guard !retired, !restoring, !navigating, text === currentPage?.textView, let view = host?.view else { return }
            switch paperSelectionTap.complete(at: point, in: text, generation: generation) {
            case .ignored: return
            case .selectionDismissed:
                manualBegan()
                parent.selectionChanged(0, 0, "")
                return
            case .activate: break
            }
            let x = text.convert(point, to: view).x
#if DEBUG
            traceGesture("tapped.accepted", recognizer: readingTap, accepted: true,
                         center: x >= view.bounds.width / 3 && x <= view.bounds.width * 2 / 3)
#endif
            if x < view.bounds.width / 3 { manualTurn(-1) }
            else if x > view.bounds.width * 2 / 3 { manualTurn(1) }
            else {
                manualBegan()
#if DEBUG
                traceGesture("tapped.center.dispatch", recognizer: readingTap, accepted: true, center: true)
#endif
                parent.centerTapped()
#if DEBUG
                traceGesture("tapped.center.return", recognizer: readingTap, accepted: true, center: true)
#endif
            }
        }
        @objc private func nativePanned(_ gesture: UIPanGestureRecognizer) {
            guard nativePanIDs.contains(ObjectIdentifier(gesture)), !retired, !restoring, let host else { return }
            let identity = ObjectIdentifier(gesture)
            if gesture.state == .began {
                nativePanOrigins[identity] = (logicalIndex, generation); nativeBoundarySent = false; manualBegan()
            }
            if gesture.state == .ended, !nativeTransitioning, !programmaticTransitioning {
                guard let origin = nativePanOrigins.removeValue(forKey: identity), origin.generation == generation else { return }
                let delta = gesture.translation(in: host.view)
                guard abs(delta.x) >= 8, abs(delta.x) >= abs(delta.y) * 1.5 else { return }
                let direction = delta.x < 0 ? 1 : -1
                if let document, !nativeBoundarySent, !document.ranges.indices.contains(origin.index + direction) {
                    nativeBoundarySent = true; parent.pageBoundary(direction)
                }
            }
            if gesture.state == .cancelled || gesture.state == .failed { nativePanOrigins.removeValue(forKey: identity) }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            let selectionPermits: Bool
            if let text = currentPage?.textView {
                selectionPermits = gestureRecognizer === readingTap
                    ? paperSelectionTap.canBegin(in: text, generation: generation) : text.selectedRange.length == 0
            } else { selectionPermits = false }
            guard !retired, !restoring, selectionPermits,
                  gestureRecognizer !== readingTap || !navigating else {
#if DEBUG
                traceGesture("shouldBegin", recognizer: gestureRecognizer, accepted: false)
#endif
                return false
            }
            if let pan = gestureRecognizer as? UIPanGestureRecognizer, pan === customPan, let view = pan.view {
                let velocity = pan.velocity(in: view)
                let accepted = (effectiveTransition == .cover || effectiveTransition == .none) && abs(velocity.x) >= abs(velocity.y) * 1.5
#if DEBUG
                traceGesture("shouldBegin", recognizer: gestureRecognizer, accepted: accepted)
#endif
                return accepted
            }
#if DEBUG
            traceGesture("shouldBegin", recognizer: gestureRecognizer, accepted: true)
#endif
            return true
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            let accepted: Bool
            if gestureRecognizer === readingTap, let text = currentPage?.textView {
                accepted = preparePaperTap(at: touch.location(in: text), in: text, touchedView: touch.view)
            } else {
                accepted = !retired && !restoring && currentPage?.textView.selectedRange.length == 0
            }
#if DEBUG
            traceGesture("shouldReceive", recognizer: gestureRecognizer, accepted: accepted)
#endif
            return accepted
        }

        /// Only the committed page's native text taps participate. Pans, long
        /// presses, ancestors and neighboring/retired pages keep UIKit's normal
        /// arbitration; no native recognizer delegate is replaced.
        private func currentTextTap(_ recognizer: UIGestureRecognizer) -> UITapGestureRecognizer? {
            guard !retired, !restoring, !navigating, let host, let readingTap,
                  readingTap.view === host.view, recognizer !== readingTap,
                  let text = currentPage?.textView,
                  text.selectedRange.length == 0 || paperSelectionTap.dismissalPending(in: text, generation: generation),
                  text.isDescendant(of: host.view), let view = recognizer.view,
                  view === text || view.isDescendant(of: text),
                  let tap = recognizer as? UITapGestureRecognizer, tap.isEnabled else { return nil }
            return tap
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            let accepted = gestureRecognizer === readingTap &&
                currentTextTap(otherGestureRecognizer).map {
                    $0.numberOfTapsRequired == 1 && $0.numberOfTouchesRequired == 1
                } == true
#if DEBUG
            traceGesture("simultaneous.current-text", recognizer: otherGestureRecognizer, accepted: accepted)
#endif
            return accepted
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            // Resolve the actual recognizer only after UIKit has built its text
            // view. Dynamic failure priority avoids accumulating dependencies
            // on every page the long-lived container has already retired.
            let required = gestureRecognizer === readingTap && parent.longPressSelectText &&
                currentTextTap(otherGestureRecognizer).map { $0.numberOfTapsRequired > 1 } == true
#if DEBUG
            traceGesture("require.current-text.multitap", recognizer: otherGestureRecognizer, accepted: required)
#endif
            return required
        }

        @objc private func panned(_ gesture: UIPanGestureRecognizer) {
            guard let host, !retired, !restoring else { return }
            let delta = gesture.translation(in: host.view)
            switch gesture.state {
            case .began:
                manualBegan(regrab: true)
                if let cover {
                    cover.animator.pauseAnimation(); cover.animator.isReversed = false
                    panDirection = cover.direction; panStart = cover.animator.fractionComplete
                } else {
                    panDirection = 0; panStart = 0
                }
            case .changed:
                if panDirection == 0, abs(delta.x) >= 16, abs(delta.x) >= abs(delta.y) * 1.5 {
                    panDirection = delta.x < 0 ? 1 : -1
                    if effectiveTransition == .cover { beginCover(direction: panDirection, interactive: true) }
                }
                if let cover { cover.animator.fractionComplete = max(0, min(1, panStart - delta.x * CGFloat(panDirection) / max(1, size.width))); updateCoverShadow() }
            case .ended, .cancelled, .failed:
                if panDirection == 0, abs(delta.x) >= 8, abs(delta.x) >= abs(delta.y) * 1.5 { panDirection = delta.x < 0 ? 1 : -1 }
                let signed = panStart * size.width - delta.x * CGFloat(panDirection)
                let qualifies = gesture.state == .ended && signed >= 8 && abs(delta.y) < max(abs(delta.x), 8) * 1.5
                if let cover {
                    cover.wantsCommit = qualifies
                    cover.animator.isReversed = !qualifies
                    let target: CGFloat = qualifies ? 1 : 0
                    let remaining = abs(target - cover.animator.fractionComplete) * size.width
                    let velocity = gesture.velocity(in: host.view).x * -CGFloat(panDirection) * (qualifies ? 1 : -1)
                    let seconds = max(0.08, min(0.32, remaining / max(size.width * 2.5, velocity)))
                    cover.animator.continueAnimation(withTimingParameters: Self.easeOut, durationFactor: seconds / 0.32)
                } else if qualifies { turn(panDirection, automatic: false) }
                panDirection = 0; panStart = 0
            default: break
            }
        }

        private static var easeOut: UICubicTimingParameters {
            UICubicTimingParameters(controlPoint1: CGPoint(x: 1.0 / 3, y: 1), controlPoint2: CGPoint(x: 2.0 / 3, y: 1))
        }
        private func beginCover(direction: Int, interactive: Bool) {
            guard let host, let outgoing = currentPage, let incoming = page(logicalIndex + direction) else { return }
            mountPage(incoming)
            if direction > 0 { host.view.insertSubview(incoming.view, belowSubview: outgoing.view) }
            else { host.view.bringSubviewToFront(incoming.view) }
            incoming.setCommittedAccessibility(false)
            let moving = direction > 0 ? outgoing.view! : incoming.view!
            let width = size.width
            moving.transform = direction > 0 ? .identity : CGAffineTransform(translationX: -width, y: 0)
            let animator = UIViewPropertyAnimator(duration: 0.32, timingParameters: Self.easeOut)
            animator.scrubsLinearly = true
            let turn = ReaderNativeCoverTurn(outgoing: outgoing, incoming: incoming, moving: moving,
                direction: direction, animator: animator, generation: generation)
            cover = turn
            moving.layer.shadowColor = UIColor.black.cgColor
            moving.layer.shadowPath = UIBezierPath(rect: moving.bounds).cgPath
            animator.addAnimations { [weak moving] in
                moving?.transform = direction > 0 ? CGAffineTransform(translationX: -width, y: 0) : .identity
            }
            animator.addCompletion { [weak self, weak turn] position in
                guard let self, let turn, self.cover === turn, self.generation == turn.generation, !self.retired else { return }
                self.finishCover(turn, committed: turn.wantsCommit && position == .end)
            }
            displayLink?.invalidate()
            displayLink = CADisplayLink(target: self, selector: #selector(updateCoverShadow))
            displayLink?.add(to: .main, forMode: .common)
            animator.startAnimation()
            if interactive { animator.pauseAnimation(); animator.fractionComplete = 0 }
        }
        @objc private func updateCoverShadow() {
            guard let cover, size.width > 0 else { return }
            let x = cover.moving.layer.presentation()?.affineTransform().tx ?? cover.moving.transform.tx
            let progress = max(0, min(1, cover.direction > 0 ? -x / size.width : (x + size.width) / size.width))
            let strength = 4 * progress * (1 - progress)
            // Frozen Host ReaderPageTurnStage: radius16, offset6, semantic
            // turnShadow black alpha 0x38 day / 0x22 night across eight papers.
            cover.moving.layer.shadowOpacity = Float(strength) * Float(parent.paper.theme.isDark ? 34.0 / 255 : 56.0 / 255)
            cover.moving.layer.shadowRadius = 16 * strength
            cover.moving.layer.shadowOffset = CGSize(width: 6 * strength, height: 0)
        }
        private func finishCover(_ turn: ReaderNativeCoverTurn, committed: Bool) {
            displayLink?.invalidate(); displayLink = nil
            cover = nil
            turn.moving.layer.shadowOpacity = 0
            turn.outgoing.view.transform = .identity; turn.incoming.view.transform = .identity
            let removed = committed ? turn.outgoing : turn.incoming
            removed.willMove(toParent: nil); removed.view.removeFromSuperview(); removed.removeFromParent()
            if committed { commit(turn.incoming.index) }
            else { updatePageAccessibility(); finishAutomatic(.cancelled) }
            drainManualQueue()
        }

        private func updateFollowHighlight() {
            cache.values.forEach { $0.setFollowHighlight(nil, color: UIColor(parent.paper.selection)) }
            guard !retired, !restoring, let document, let page = currentPage else { return }
            guard let ratio = parent.automaticHighlightProgress else { return }
            var lines: [CGRect] = []
            document.layout.enumerateLineFragments(forGlyphRange: document.glyphRanges[page.index]) { _, used, _, glyphs, _ in
                let range = document.layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
                if range.length > 0, NSMaxRange(range) > document.prefixUTF16 {
                    lines.append(used.offsetBy(dx: document.insets.left, dy: document.insets.top))
                }
            }
            guard !lines.isEmpty else { return }
            let index = min(lines.count - 1, Int(max(0, min(1, ratio)) * Double(lines.count)))
            page.setFollowHighlight(lines[index], color: UIColor(parent.paper.selection))
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !restoring, !retired, parent.longPressSelectText, textView === currentPage?.textView, let document else { return }
            let selected = textView.selectedRange
            guard selected.location != NSNotFound, selected.length > 0, NSMaxRange(selected) > document.prefixUTF16 else {
                parent.selectionChanged(0, 0, ""); return
            }
            manualBegan()
            let bodyRange = NSIntersectionRange(selected, NSRange(location: document.prefixUTF16, length: document.projection.text.utf16.count))
            let start = document.projection.sourceScalarOffset(forDisplayUTF16: max(0, bodyRange.location - document.prefixUTF16))
            let end = document.projection.sourceScalarOffset(forDisplayUTF16: max(0, NSMaxRange(bodyRange) - document.prefixUTF16))
            parent.selectionChanged(start, end, (document.storage.string as NSString).substring(with: bodyRange))
        }
        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]) -> UIMenu? {
            var actions = suggestedActions
            if range.length > 0, let document, NSMaxRange(range) > document.prefixUTF16 {
                if let action = parent.bookmarkSelectionAction { actions.append(UIAction(title: "添加书签") { _ in action() }) }
                if let action = parent.noteSelectionAction { actions.append(UIAction(title: "高亮与笔记") { _ in action() }) }
            }
            return UIMenu(children: actions)
        }
    }
}

final class ReaderPagedContainerController: UIViewController {
    var afterLayout: ((CGSize) -> Void)?
    override func loadView() { view = UIView(); view.backgroundColor = .clear; view.clipsToBounds = true }
    override func viewDidLayoutSubviews() { super.viewDidLayoutSubviews(); afterLayout?(view.bounds.size) }
}

@MainActor
private final class ReaderNativePageDocument {
    let storage: NSTextStorage
    let layout: NSLayoutManager
    let projection: ReaderParagraphProjection
    let prefixUTF16: Int
    let paper: ReaderPaperPalette
    let insets: UIEdgeInsets
    let size: CGSize
    let viewport: CGSize
    let identity: ReaderChapterImageIdentity
    // NSLayoutManager's delegate is weak. One document owns the adapter for
    // every native container, including later UITextView geometry updates.
    private let bottomAlignment: ReaderNativePageBottomAlignment
    var containers: [NSTextContainer] = []
    var ranges: [NSRange] = []
    var glyphRanges: [NSRange] = []

    init(_ parent: ReaderPagedTextSurface, size: CGSize) throws {
        let projection = ReaderParagraphProjection(content: parent.content.content)
        let insets = UIEdgeInsets(top: 8, left: max(0, parent.horizontalInset - parent.safeLeft),
            bottom: max(0, parent.bottomInset), right: max(0, parent.horizontalInset - parent.safeRight))
        let viewport = CGSize(width: size.width - insets.left - insets.right, height: size.height - insets.top - insets.bottom)
        let prefix = parent.content.chapterTitle + "\n"
        let prefixUTF16 = prefix.utf16.count
        let title = NSMutableParagraphStyle()
        let font = UIFontMetrics(forTextStyle: .title2).scaledFont(for: ReaderTypography.style(.chapterTitle).uiFont)
        title.minimumLineHeight = ReaderMetrics.chapterTitleLineHeight * font.pointSize / 23
        title.maximumLineHeight = title.minimumLineHeight; title.paragraphSpacing = ReaderMetrics.titleBodyGap; title.alignment = .center
        let attributed = NSMutableAttributedString(string: prefix, attributes: [.font: font, .foregroundColor: UIColor(parent.paper.ink), .paragraphStyle: title])
        attributed.append(projection.attributedBody(fontSize: parent.fontSize, lineHeight: parent.lineHeight,
            ink: UIColor(parent.paper.ink), font: parent.readerFont?.withSize(parent.fontSize) ?? parent.fontName.flatMap { UIFont(name: $0, size: parent.fontSize) },
            paragraphSpacing: parent.paragraphSpacing, letterSpacing: parent.letterSpacing,
            firstLineIndentEm: parent.firstLineIndentEm, alignment: parent.alignment,
            imageAssets: parent.imageAssets, chapter: parent.content, imageViewport: viewport))
        for mark in parent.highlights {
            guard let scope = mark.positionScope, scope.sourceId == parent.content.sourceId, scope.bookId == parent.content.bookId,
                  scope.chapterIndex == parent.content.chapterIndex, scope.bodyVersion == parent.content.bodyVersion,
                  scope.processingVersion == parent.content.processingVersion, mark.chapterPos >= 0,
                  mark.chapterPosEnd > mark.chapterPos, UInt64(mark.chapterPosEnd) <= parent.content.scalarCount else { continue }
            let start = projection.displayUTF16Offset(forSourceScalar: UInt64(mark.chapterPos))
            let end = projection.displayUTF16Offset(forSourceScalar: UInt64(mark.chapterPosEnd))
            attributed.addAttribute(.backgroundColor, value: UIColor(parent.paper.selection), range: NSRange(location: prefixUTF16 + start, length: max(0, end - start)))
        }
        let storage = NSTextStorage(attributedString: attributed)
        let layout = NSLayoutManager()
        let bottomAlignment = ReaderNativePageBottomAlignment(enabled: parent.alignPageBottom, prefixUTF16: prefixUTF16)
        layout.delegate = bottomAlignment
        storage.addLayoutManager(layout)
        self.projection = projection; self.insets = insets; self.prefixUTF16 = prefixUTF16
        self.storage = storage; self.layout = layout; self.viewport = viewport; self.size = size; self.paper = parent.paper
        self.identity = ReaderChapterImageIdentity(parent.content)
        self.bottomAlignment = bottomAlignment
        guard viewport.width > 0, viewport.height > 0 else { throw ReaderNativePageLayoutError.insufficientViewport }
        var last = 0
        repeat {
            let container = NSTextContainer(size: viewport)
            container.lineFragmentPadding = 0; container.widthTracksTextView = false; container.heightTracksTextView = false
            layout.addTextContainer(container); layout.ensureLayout(for: container)
            let glyphs = layout.glyphRange(for: container)
            guard glyphs.length > 0, NSMaxRange(glyphs) > last else { throw ReaderNativePageLayoutError.insufficientViewport }
            containers.append(container); glyphRanges.append(glyphs)
            ranges.append(layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil))
            last = NSMaxRange(glyphs)
        } while last < layout.numberOfGlyphs
    }
    func index(containing scalar: UInt64) -> Int {
        if scalar == 0 { return 0 }
        let utf16 = prefixUTF16 + projection.displayUTF16Offset(forSourceScalar: scalar)
        return ranges.firstIndex { NSLocationInRange(utf16, $0) } ?? max(0, ranges.count - 1)
    }
    func sourceOffset(at index: Int) -> UInt64 {
        if index == 0 { return 0 }
        return projection.sourceScalarOffset(forDisplayUTF16: max(0, ranges[index].location - prefixUTF16))
    }
}

private enum ReaderNativePageLayoutError: Error { case insufficientViewport }

/// Thin consumption of Host33f7 ReaderPageBottomJustify.ts:7–25. TextKit
/// still chooses every page and line. Only a full page's residual space is
/// distributed between its body lines, after native pagination completes.
/// Updating both native rectangles keeps drawing, selection, hit testing and
/// attributed highlights in the same layout manager coordinate system.
@MainActor
private final class ReaderNativePageBottomAlignment: NSObject, NSLayoutManagerDelegate {
    private let enabled: Bool
    private let prefixUTF16: Int
    private var adjusting = false

    init(enabled: Bool, prefixUTF16: Int) {
        self.enabled = enabled; self.prefixUTF16 = prefixUTF16
        super.init()
    }

    func layoutManager(_ layoutManager: NSLayoutManager, didCompleteLayoutFor textContainer: NSTextContainer?, atEnd layoutFinishedFlag: Bool) {
        guard enabled, !adjusting, let textContainer, let storage = layoutManager.textStorage else { return }
        adjusting = true
        defer { adjusting = false }
        let pageRange = layoutManager.glyphRange(for: textContainer)
        guard pageRange.length > 0 else { return }
        var body: [(rect: CGRect, used: CGRect, glyphs: NSRange, characters: NSRange)] = []
        layoutManager.enumerateLineFragments(forGlyphRange: pageRange) { rect, used, container, glyphs, _ in
            guard container === textContainer, glyphs.length > 0 else { return }
            let characters = layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            // The chapter title is outside the Host's body capacity. Its
            // original line height and title/body gap never acquire this gap.
            guard characters.location >= self.prefixUTF16, characters.length > 0 else { return }
            body.append((rect, used, glyphs, characters))
        }
        guard body.count > 1, let first = body.first, let last = body.last,
              last.rect.height > 0, last.rect.height.isFinite else { return }
        var lastIsImage = false
        storage.enumerateAttribute(.attachment, in: last.characters) { value, _, stop in
            if value != nil { lastIsImage = true; stop.pointee = true }
        }
        guard !lastIsImage else { return }
        let capacity = textContainer.size.height - first.rect.minY
        let contentHeight = last.rect.maxY - first.rect.minY
        let surplus = capacity - contentHeight
        guard surplus.isFinite, surplus > 0, surplus < last.rect.height else { return }
        let gap = surplus / CGFloat(body.count - 1)
        for (index, fragment) in body.enumerated() where index > 0 {
            let offset = CGFloat(index) * gap
            layoutManager.setLineFragmentRect(fragment.rect.offsetBy(dx: 0, dy: offset),
                forGlyphRange: fragment.glyphs, usedRect: fragment.used.offsetBy(dx: 0, dy: offset))
        }
        layoutManager.invalidateDisplay(forGlyphRange: pageRange)
    }
}

@MainActor
private final class ReaderNativeTextPageController: UIViewController {
    let document: ReaderNativePageDocument
    let index: Int
    private(set) var textView: ReaderNativePagedTextView!
    private var background: UIHostingController<ReaderPaperBackground>?
    private let followHighlight = CAShapeLayer()
    init(document: ReaderNativePageDocument, index: Int) { self.document = document; self.index = index; super.init(nibName: nil, bundle: nil) }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadView() {
        view = UIView(frame: CGRect(origin: .zero, size: document.size)); view.backgroundColor = UIColor(document.paper.paper); view.isOpaque = true
        let paper = UIHostingController(rootView: ReaderPaperBackground(theme: document.paper.theme))
        addChild(paper); paper.view.backgroundColor = .clear; view.addSubview(paper.view); paper.didMove(toParent: self); background = paper
        let text = ReaderNativePagedTextView(frame: view.bounds, textContainer: document.containers[index])
        text.isEditable = false; text.isSelectable = true; text.isScrollEnabled = false
        text.backgroundColor = .clear; text.clipsToBounds = true; text.contentInsetAdjustmentBehavior = .never
        text.textContainerInset = document.insets
        text.textContainer.widthTracksTextView = false; text.textContainer.heightTracksTextView = false
        text.textContainer.size = document.viewport
        document.layout.ensureLayout(for: text.textContainer)
        text.accessibilityIdentifier = "reading-body"; text.accessibilityLabel = "小说正文"
        text.accessibilityValue = ReaderChapterImageAssets.accessibilityText(document.storage, range: document.ranges[index])
        view.addSubview(text); textView = text
        // A UIKit layer behind the text preserves saved highlight attributes
        // and the native selection. AppKit temporary-attribute APIs are absent.
        view.layer.insertSublayer(followHighlight, below: text.layer)
        followHighlight.isHidden = true
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews(); background?.view.frame = view.bounds; textView.frame = view.bounds
        followHighlight.frame = view.bounds
    }
    func setCommittedAccessibility(_ committed: Bool) {
        view.accessibilityElementsHidden = !committed
        textView.accessibilityElementsHidden = !committed
        textView.isAccessibilityElement = committed
        textView.accessibilityIdentifier = committed ? "reading-body" : nil
    }
    func setFollowHighlight(_ rect: CGRect?, color: UIColor) {
        CATransaction.begin(); CATransaction.setDisableActions(true)
        followHighlight.isHidden = rect == nil
        followHighlight.fillColor = color.cgColor
        followHighlight.path = rect.map { UIBezierPath(rect: $0).cgPath }
        CATransaction.commit()
    }
}

private final class ReaderNativePagedTextView: UITextView {
    var pageScroll: ((Int) -> Void)?
    override func accessibilityScroll(_ direction: UIAccessibilityScrollDirection) -> Bool {
        if direction == .left { pageScroll?(1); return pageScroll != nil }
        if direction == .right { pageScroll?(-1); return pageScroll != nil }
        return super.accessibilityScroll(direction)
    }
}

@MainActor
private final class ReaderWeakTextPage {
    weak var value: ReaderNativeTextPageController?
    init(_ value: ReaderNativeTextPageController) { self.value = value }
}

@MainActor
private final class ReaderNativeCoverTurn {
    let outgoing: ReaderNativeTextPageController
    let incoming: ReaderNativeTextPageController
    let moving: UIView
    let direction: Int
    let animator: UIViewPropertyAnimator
    let generation: UUID
    var wantsCommit = true
    init(outgoing: ReaderNativeTextPageController, incoming: ReaderNativeTextPageController, moving: UIView,
         direction: Int, animator: UIViewPropertyAnimator, generation: UUID) {
        self.outgoing = outgoing; self.incoming = incoming; self.moving = moving
        self.direction = direction; self.animator = animator; self.generation = generation
    }
}
