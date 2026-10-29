import SwiftUI
import UIKit

/// TextKit owns shaping, wrapping and scrolling. Core offsets remain Unicode scalars.
struct ReaderTextSurface: UIViewRepresentable {
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
    var paged = false
    var highlights: [ReaderHighlight] = []
    var pageTurnID: UUID? = nil
    var automaticPageEnabled = false
    var pageCommitted: (UUID, ReaderNativePageOutcome) -> Void = { _, _ in }
    var layoutReady: () -> Void = {}
    var manualInteraction: () -> Void = {}
    var reducePageMotion = false
    var automaticHighlightProgress: Double? = nil
    var longPressSelectText = true
    var readerFont: UIFont? = nil
    var imageAssets: ReaderChapterImageAssets = .empty
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextView {
        // Scalar projection uses NSLayoutManager throughout; choose TextKit 1
        // before installing text rather than falling back during restoration.
        let view = ReaderMeasuredTextView(usingTextLayoutManager: false)
        view.isEditable = false
        view.isSelectable = longPressSelectText
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.contentInsetAdjustmentBehavior = .never
        view.textContainer.lineFragmentPadding = 0
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceVertical = true
        view.delegate = context.coordinator
        context.coordinator.activeView = view
        view.accessibilityIdentifier = "reading-body"
        view.accessibilityLabel = "小说正文"
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.cancelsTouchesInView = false
        tap.delegate = context.coordinator
        view.addGestureRecognizer(tap)
        context.coordinator.readingTap = tap
        view.afterLayout = { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.layoutChanged(view)
        }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        if view.isSelectable != longPressSelectText {
            view.isSelectable = longPressSelectText
        }
        updateAttributedText(view, coordinator: coordinator)
        view.textContainerInset.bottom = bottomInset
        view.isPagingEnabled = paged
        view.decelerationRate = paged ? .fast : .normal
        coordinator.updateAutomaticPage(view)
        coordinator.updateFollowHighlight(view)
    }

    static func dismantleUIView(_ view: UITextView, coordinator: Coordinator) { coordinator.retire(view) }

    private func updateAttributedText(_ view: UITextView, coordinator: Coordinator) {
        let left = max(0, horizontalInset - safeLeft), right = max(0, horizontalInset - safeRight)
        let viewport = CGSize(width: max(0, view.bounds.width - left - right),
            height: max(0, view.bounds.height - 8 - bottomInset))
        let signature = "\(content.sourceId)|\(content.bookId)|\(content.chapterIndex)|\(content.bodyVersion ?? "")|\(content.processingVersion ?? "")|\(fontSize)|\(lineHeight)|\(horizontalInset)|\(safeLeft)|\(safeRight)|\(paper.theme.rawValue)|\(dynamicTypeSize)|\(fontName ?? "")|\(readerFont?.fontDescriptor.hash ?? 0)|\(paragraphSpacing)|\(letterSpacing)|\(firstLineIndentEm)|\(alignment.rawValue)|\(highlights.hashValue)|\(imageAssets.revision)|\(viewport.width)|\(viewport.height)"
        if coordinator.signature != signature {
            let selection = coordinator.contentIdentity == ReaderChapterImageIdentity(content) && coordinator.lastRestoration == restorationID
                ? view.selectedRange : nil
            let offset = coordinator.offsetBeforeReflow(view, identity: ReaderChapterImageIdentity(content), restoration: restorationID)
            coordinator.invalidateLayout(view)
            coordinator.signature = signature
            coordinator.contentIdentity = ReaderChapterImageIdentity(content)
            let prefix = content.chapterTitle + "\n"
            coordinator.prefixUTF16 = prefix.utf16.count
            let projection = ReaderParagraphProjection(content: content.content)
            coordinator.projection = projection
            let titleStyle = NSMutableParagraphStyle()
            let titleFont = UIFontMetrics(forTextStyle: .title2).scaledFont(for: ReaderTypography.style(.chapterTitle).uiFont)
            let titleScale = titleFont.pointSize / 23
            titleStyle.minimumLineHeight = ReaderMetrics.chapterTitleLineHeight * titleScale
            titleStyle.maximumLineHeight = ReaderMetrics.chapterTitleLineHeight * titleScale
            titleStyle.paragraphSpacing = ReaderMetrics.titleBodyGap
            titleStyle.alignment = .center
            let attributed = NSMutableAttributedString(string: prefix, attributes: [
                .font: titleFont,
                .foregroundColor: UIColor(paper.ink), .paragraphStyle: titleStyle
            ])
            attributed.append(projection.attributedBody(fontSize: fontSize, lineHeight: lineHeight, ink: UIColor(paper.ink),
                font: readerFont?.withSize(fontSize) ?? fontName.flatMap { UIFont(name: $0, size: fontSize) }, paragraphSpacing: paragraphSpacing,
                letterSpacing: letterSpacing, firstLineIndentEm: firstLineIndentEm, alignment: alignment,
                imageAssets: imageAssets, chapter: content, imageViewport: viewport))
            for mark in highlights {
                guard let scope = mark.positionScope, scope.sourceId == content.sourceId,
                      scope.bookId == content.bookId, scope.chapterIndex == content.chapterIndex,
                      scope.bodyVersion == content.bodyVersion, scope.processingVersion == content.processingVersion,
                      mark.chapterPos >= 0, mark.chapterPosEnd > mark.chapterPos,
                      UInt64(mark.chapterPosEnd) <= content.scalarCount else { continue }
                let start = projection.displayUTF16Offset(forSourceScalar: UInt64(mark.chapterPos))
                let end = projection.displayUTF16Offset(forSourceScalar: UInt64(mark.chapterPosEnd))
                let range = NSRange(location: coordinator.prefixUTF16 + start, length: max(0, end - start))
                attributed.addAttribute(.backgroundColor, value: UIColor(paper.selection), range: range)
            }
            view.attributedText = attributed
            if let selection, selection.location != NSNotFound, NSMaxRange(selection) <= attributed.length {
                view.selectedRange = selection
            }
            view.accessibilityValue = ReaderChapterImageAssets.accessibilityText(attributed)
            view.textContainerInset = UIEdgeInsets(top: 8, left: max(0, horizontalInset - safeLeft),
                bottom: bottomInset, right: max(0, horizontalInset - safeRight))
            coordinator.pendingOffset = offset
            coordinator.lastRestoration = restorationID
            coordinator.scheduleRestore(view)
        } else if coordinator.lastRestoration != restorationID {
            coordinator.invalidateLayout(view)
            coordinator.lastRestoration = restorationID
            coordinator.pendingOffset = scalarOffset
            coordinator.scheduleRestore(view)
        }
    }

    final class Coordinator: NSObject, UITextViewDelegate, UIGestureRecognizerDelegate {
        var parent: ReaderTextSurface
        var signature = ""
        var prefixUTF16 = 0
        var projection: ReaderParagraphProjection?
        var contentIdentity: ReaderChapterImageIdentity?
        weak var activeView: UITextView?
        weak var readingTap: UITapGestureRecognizer?
        private let paperSelectionTap = ReaderPaperSelectionTap()
        private var visibleAnchor: ReaderParagraphProjection.Anchor?
        var lastRestoration: UUID?
        var pendingOffset: UInt64?
        var restoring = true
        private var restorationGeneration = UUID()
        private var lastPageTurn: UUID?
        private var queuedPageTurn: (id: UUID, identity: ReaderChapterImageIdentity, callback: (UUID, ReaderNativePageOutcome) -> Void)?
        private var activePageTurn: UUID?
        private var activePageCallback: ((UUID, ReaderNativePageOutcome) -> Void)?
        private var retired = false
        private let followHighlightLayer = CALayer()
        init(_ parent: ReaderTextSurface) { self.parent = parent }

        func layoutChanged(_ view: UITextView) {
            guard !retired, view === activeView, view.bounds.width > 0 else { return }
            parent.updateAttributedText(view, coordinator: self)
        }

        func offsetBeforeReflow(_ view: UITextView, identity: ReaderChapterImageIdentity, restoration: UUID) -> UInt64 {
            guard contentIdentity == identity, lastRestoration == restoration else { return parent.scalarOffset }
            if let pendingOffset { return pendingOffset }
            guard !restoring, let projection, view.textStorage.length > 0 else { return parent.scalarOffset }
            if let visibleAnchor { return visibleAnchor.sourceScalarOffset }
            if view.contentOffset.y <= 0 { return 0 }
            let point = CGPoint(x: 1, y: max(0, view.contentOffset.y - view.textContainerInset.top))
            let glyph = view.layoutManager.glyphIndex(for: point, in: view.textContainer)
            let index = max(0, view.layoutManager.characterIndexForGlyph(at: glyph) - prefixUTF16)
            return projection.sourceScalarOffset(forDisplayUTF16: index, preserving: visibleAnchor)
        }

        func invalidateLayout(_ view: UITextView) {
            restorationGeneration = UUID(); restoring = true
            if let id = activePageTurn {
                let callback = activePageCallback
                activePageTurn = nil; activePageCallback = nil
                view.setContentOffset(view.contentOffset, animated: false)
                DispatchQueue.main.async { callback?(id, .cancelled) }
            }
        }

        func retire(_ view: UITextView) {
            retired = true; invalidateLayout(view)
            if let queued = queuedPageTurn {
                queuedPageTurn = nil
                DispatchQueue.main.async { queued.callback(queued.id, .cancelled) }
            }
            (view as? ReaderMeasuredTextView)?.afterLayout = nil
            view.delegate = nil; activeView = nil
        }

        func scheduleRestore(_ view: UITextView) {
            restoring = true
            let generation = UUID()
            restorationGeneration = generation
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view, !self.retired, view === self.activeView,
                      self.restorationGeneration == generation,
                      view.bounds.width > 0, view.bounds.height > 0 else { return }
                view.layoutManager.ensureLayout(for: view.textContainer)
                // TextKit layout does not finish UITextView's scroll geometry.
                // afterLayout can replace text after super.layoutSubviews, so
                // flush the native layout before clamping to its contentSize.
                view.setNeedsLayout()
                view.layoutIfNeeded()
                guard !self.retired, view === self.activeView,
                      self.restorationGeneration == generation, let projection = self.projection,
                      view.bounds.width > 0, view.bounds.height > 0 else { return }
                let offset = self.pendingOffset ?? self.parent.scalarOffset
                let anchor = projection.anchor(forSourceScalar: offset)
                self.visibleAnchor = anchor
                if offset == 0 { view.setContentOffset(.zero, animated: false) }
                else {
                    let index = self.prefixUTF16 + anchor.displayUTF16Offset
                    let range = NSRange(location: min(max(0, index), max(0, view.textStorage.length - 1)), length: 1)
                    let glyphs = view.layoutManager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                    let rect = view.layoutManager.boundingRect(forGlyphRange: glyphs, in: view.textContainer)
                    let y = min(max(0, rect.minY + view.textContainerInset.top), max(0, view.contentSize.height - view.bounds.height))
                    view.setContentOffset(CGPoint(x: 0, y: y), animated: false)
                }
                self.pendingOffset = nil
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view, !self.retired, view === self.activeView,
                          self.restorationGeneration == generation,
                          view.bounds.width > 0, view.bounds.height > 0 else { return }
                    self.restoring = false
                    if self.parent.imageAssets.settled(for: self.parent.content) {
                        self.parent.layoutReady()
                        self.beginQueuedPage(view)
                    }
                }
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !retired, !restoring, let view = scrollView as? UITextView, view === activeView,
                  let projection, view.textStorage.length > 0,
                  view.isDragging || view.isDecelerating || activePageTurn != nil else { return }
            let y = max(0, view.contentOffset.y - view.textContainerInset.top)
            let glyph = view.layoutManager.glyphIndex(for: CGPoint(x: 1, y: y), in: view.textContainer)
            let utf16 = max(0, view.layoutManager.characterIndexForGlyph(at: glyph) - prefixUTF16)
            let offset = projection.sourceScalarOffset(forDisplayUTF16: utf16, preserving: visibleAnchor)
            if visibleAnchor?.displayUTF16Offset != utf16 { visibleAnchor = nil }
            parent.positionChanged(offset)
        }

        func updateAutomaticPage(_ view: UITextView) {
            if !parent.automaticPageEnabled {
                queuedPageTurn = nil
                if let id = activePageTurn {
                    let callback = activePageCallback
                    activePageTurn = nil; activePageCallback = nil
                    view.setContentOffset(view.contentOffset, animated: false)
                    DispatchQueue.main.async { callback?(id, .cancelled) }
                }
                return
            }
            guard let id = parent.pageTurnID, lastPageTurn != id else { return }
            lastPageTurn = id
            queuedPageTurn = (id, ReaderChapterImageIdentity(parent.content), parent.pageCommitted)
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view else { return }
                self.beginQueuedPage(view)
            }
        }
        func updateFollowHighlight(_ view: UITextView) {
            if followHighlightLayer.superlayer !== view.layer { view.layer.insertSublayer(followHighlightLayer, at: 0) }
            followHighlightLayer.isHidden = true
            guard !restoring, let ratio = parent.automaticHighlightProgress else { return }
            let viewport = CGRect(x: 0, y: view.contentOffset.y - view.textContainerInset.top,
                                  width: view.bounds.width, height: view.bounds.height)
            let visibleGlyphs = view.layoutManager.glyphRange(forBoundingRect: viewport, in: view.textContainer)
            var lines: [CGRect] = []
            view.layoutManager.enumerateLineFragments(forGlyphRange: visibleGlyphs) { rect, _, _, glyphs, _ in
                guard rect.intersects(viewport) else { return }
                let range = view.layoutManager.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
                if range.length > 0, NSMaxRange(range) > self.prefixUTF16 { lines.append(rect) }
            }
            guard !lines.isEmpty else { return }
            let index = min(lines.count - 1, Int(max(0, min(1, ratio)) * Double(lines.count)))
            // UIKit owns each measured line rectangle. A non-interactive layer
            // behind its text canvas leaves attributed note backgrounds and
            // native selection untouched; no macOS temporary-attribute API.
            CATransaction.begin(); CATransaction.setDisableActions(true)
            followHighlightLayer.frame = lines[index].offsetBy(dx: view.textContainerInset.left, dy: view.textContainerInset.top)
            followHighlightLayer.backgroundColor = UIColor(parent.paper.selection).cgColor
            followHighlightLayer.isHidden = false
            CATransaction.commit()
        }
        private func beginQueuedPage(_ view: UITextView) {
            guard !retired, !restoring, view === activeView, parent.imageAssets.settled(for: parent.content),
                  parent.automaticPageEnabled, let queued = queuedPageTurn,
                  queued.id == parent.pageTurnID else { return }
            queuedPageTurn = nil
            guard queued.identity == ReaderChapterImageIdentity(parent.content) else {
                queued.callback(queued.id, .cancelled); return
            }
            let id = queued.id
            let last = max(0, view.contentSize.height - view.bounds.height)
            if view.contentOffset.y >= last - 0.5 { queued.callback(id, .chapterEnd); return }
            activePageTurn = id
            activePageCallback = queued.callback
            view.setContentOffset(CGPoint(x: 0, y: min(last, view.contentOffset.y + max(1, view.bounds.height - 16))), animated: !parent.reducePageMotion)
            if parent.reducePageMotion {
                DispatchQueue.main.async { [weak self, weak view] in
                    guard let self, let view, self.activePageTurn == id else { return }
                    self.scrollViewDidEndScrollingAnimation(view)
                }
            }
        }
        func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
            guard !retired, !restoring, let id = activePageTurn, let view = scrollView as? UITextView,
                  view === activeView else { return }
            scrollViewDidScroll(view)
            activePageTurn = nil
            let callback = activePageCallback; activePageCallback = nil
            callback?(id, .advanced)
        }
        func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
            guard !retired, scrollView === activeView else { return }
            parent.manualInteraction()
            if let id = activePageTurn {
                let callback = activePageCallback; activePageCallback = nil; activePageTurn = nil
                callback?(id, .cancelled)
            }
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            guard !retired, textView === activeView, !restoring, parent.longPressSelectText, let projection else { return }
            let selected = textView.selectedRange
            guard selected.location != NSNotFound, selected.length > 0,
                  NSMaxRange(selected) > prefixUTF16 else {
                parent.selectionChanged(0, 0, ""); return
            }
            let start = max(0, selected.location - prefixUTF16)
            let end = max(start, NSMaxRange(selected) - prefixUTF16)
            let sourceStart = projection.sourceScalarOffset(forDisplayUTF16: start)
            let sourceEnd = projection.sourceScalarOffset(forDisplayUTF16: end)
            let safeRange = NSIntersectionRange(selected, NSRange(location: prefixUTF16, length: projection.text.utf16.count))
            let text = (textView.text as NSString).substring(with: safeRange)
            parent.selectionChanged(sourceStart, sourceEnd, text)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
            guard gestureRecognizer === readingTap, let view = gestureRecognizer.view as? UITextView else { return false }
            return preparePaperTap(at: touch.location(in: view), in: view, touchedView: touch.view)
        }

        func preparePaperTap(at point: CGPoint, in view: UITextView, touchedView: UIView? = nil) -> Bool {
            guard !retired, !restoring, view === activeView else { return false }
            return paperSelectionTap.prepare(at: point, in: view, touchedView: touchedView,
                                              generation: restorationGeneration)
        }

        func completePaperTap(at point: CGPoint, in view: UITextView) {
            guard !retired, !restoring, view === activeView else { return }
            switch paperSelectionTap.complete(at: point, in: view, generation: restorationGeneration) {
            case .ignored: return
            case .selectionDismissed:
                parent.manualInteraction()
                parent.selectionChanged(0, 0, "")
            case .activate:
                parent.manualInteraction()
                if point.x > view.bounds.width / 3, point.x < view.bounds.width * 2 / 3 { parent.centerTapped() }
            }
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === readingTap, !retired, !restoring, let view = activeView else { return false }
            return paperSelectionTap.canBegin(in: view, generation: restorationGeneration)
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === readingTap, let view = activeView,
                  paperSelectionTap.dismissalPending(in: view, generation: restorationGeneration),
                  let tap = ReaderPaperSelectionTap.nativeTap(otherGestureRecognizer, in: view) else { return false }
            return tap.numberOfTapsRequired == 1 && tap.numberOfTouchesRequired == 1
        }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            guard gestureRecognizer === readingTap, let view = activeView,
                  paperSelectionTap.dismissalPending(in: view, generation: restorationGeneration),
                  let tap = ReaderPaperSelectionTap.nativeTap(otherGestureRecognizer, in: view) else { return false }
            return tap.numberOfTapsRequired > 1
        }

        func textView(_ textView: UITextView, editMenuForTextIn range: NSRange,
                      suggestedActions: [UIMenuElement]) -> UIMenu? {
            var actions = suggestedActions
            if let bookmark = parent.bookmarkSelectionAction, range.length > 0,
               NSMaxRange(range) > prefixUTF16 {
                actions.append(UIAction(title: "添加书签") { _ in bookmark() })
            }
            if let note = parent.noteSelectionAction, range.length > 0, NSMaxRange(range) > prefixUTF16 {
                actions.append(UIAction(title: "高亮与笔记") { _ in note() })
            }
            return UIMenu(children: actions)
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard gesture === readingTap, let view = gesture.view as? UITextView, gesture.state == .ended else { return }
            completePaperTap(at: gesture.location(in: view), in: view)
        }
    }
}

/// One ordinary paper tap may end a native selection, but must not also route
/// to reading controls or a page turn. UIKit owns selection geometry, handles,
/// menu gestures and long presses; no private selection view is inspected.
@MainActor
final class ReaderPaperSelectionTap {
    enum Result { case ignored, selectionDismissed, activate }
    private weak var view: UITextView?
    private var generation: UUID?
    private var beganWithSelection = false

    func prepare(at point: CGPoint, in view: UITextView, touchedView: UIView?, generation: UUID) -> Bool {
        self.view = nil; self.generation = nil; beganWithSelection = false
        guard view.bounds.contains(point), !view.isDragging, !view.isDecelerating else { return false }
        // System menu / embedded controls are not paper. Selection handle
        // protection below uses only UITextInput's public geometry.
        var ancestor = touchedView
        while let current = ancestor, current !== view {
            if current is UIControl { return false }
            ancestor = current.superview
        }
        let selected = view.selectedRange.length > 0
        if selected {
            guard let range = view.selectedTextRange else { return false }
            let rects = view.selectionRects(for: range).map(\.rect).filter { !$0.isEmpty && !$0.isNull }
            let carets = [view.caretRect(for: range.start), view.caretRect(for: range.end)]
                .filter { !$0.isEmpty && !$0.isNull }
            guard !rects.isEmpty || !carets.isEmpty else { return false }
            // A standard 44pt touch region around each insertion endpoint also
            // protects the native handle knob beyond its thin caret rectangle.
            guard !rects.contains(where: { $0.contains(point) }),
                  !carets.contains(where: { $0.insetBy(dx: -22, dy: -22).contains(point) }) else { return false }
        }
        self.view = view; self.generation = generation; beganWithSelection = selected
        return true
    }

    func canBegin(in view: UITextView, generation: UUID) -> Bool {
        self.view === view && self.generation == generation && !view.isDragging && !view.isDecelerating &&
            (beganWithSelection || view.selectedRange.length == 0)
    }

    func dismissalPending(in view: UITextView, generation: UUID) -> Bool {
        self.view === view && self.generation == generation && beganWithSelection
    }

    func complete(at point: CGPoint, in view: UITextView, generation: UUID) -> Result {
        defer { self.view = nil; self.generation = nil; beganWithSelection = false }
        guard canBegin(in: view, generation: generation), view.bounds.contains(point) else { return .ignored }
        guard beganWithSelection else { return view.selectedRange.length == 0 ? .activate : .ignored }
        let offset = view.contentOffset
        view.selectedTextRange = nil
        view.resignFirstResponder()
        if view.contentOffset != offset { view.setContentOffset(offset, animated: false) }
        return .selectionDismissed
    }

    static func nativeTap(_ recognizer: UIGestureRecognizer, in text: UITextView) -> UITapGestureRecognizer? {
        guard let owner = recognizer.view, owner === text || owner.isDescendant(of: text),
              let tap = recognizer as? UITapGestureRecognizer, tap.isEnabled else { return nil }
        return tap
    }
}

private final class ReaderMeasuredTextView: UITextView {
    var afterLayout: (() -> Void)?
    override func layoutSubviews() { super.layoutSubviews(); afterLayout?() }
}
