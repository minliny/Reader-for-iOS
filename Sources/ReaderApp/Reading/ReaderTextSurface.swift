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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UITextView {
        let view = ReaderMeasuredTextView()
        view.isEditable = false
        view.isSelectable = false
        view.backgroundColor = .clear
        view.clipsToBounds = true
        view.contentInsetAdjustmentBehavior = .never
        view.textContainer.lineFragmentPadding = 0
        view.showsVerticalScrollIndicator = false
        view.alwaysBounceVertical = true
        view.delegate = context.coordinator
        view.accessibilityIdentifier = "reading-body"
        view.accessibilityLabel = "小说正文"
        let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.tapped(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
        view.afterLayout = { [weak coordinator = context.coordinator, weak view] in
            guard let view else { return }
            coordinator?.layoutChanged(view)
        }
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        let signature = "\(content.bookId)|\(content.chapterIndex)|\(content.bodyVersion ?? "")|\(fontSize)|\(lineHeight)|\(horizontalInset)|\(safeLeft)|\(safeRight)|\(paper.theme.rawValue)|\(dynamicTypeSize)"
        if coordinator.signature != signature {
            coordinator.restoring = true
            coordinator.signature = signature
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
            attributed.append(projection.attributedBody(fontSize: fontSize, lineHeight: lineHeight, ink: UIColor(paper.ink)))
            view.attributedText = attributed
            view.textContainerInset = UIEdgeInsets(top: 8, left: max(0, horizontalInset - safeLeft),
                bottom: bottomInset, right: max(0, horizontalInset - safeRight))
            coordinator.pendingOffset = scalarOffset
            coordinator.lastRestoration = restorationID
            coordinator.scheduleRestore(view)
        } else if coordinator.lastRestoration != restorationID {
            coordinator.lastRestoration = restorationID
            coordinator.pendingOffset = scalarOffset
            coordinator.scheduleRestore(view)
        }
        view.textContainerInset.bottom = bottomInset
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ReaderTextSurface
        var signature = ""
        var prefixUTF16 = 0
        var projection: ReaderParagraphProjection?
        private var visibleAnchor: ReaderParagraphProjection.Anchor?
        var lastRestoration: UUID?
        var pendingOffset: UInt64?
        var restoring = true
        var previousWidth: CGFloat = 0
        private var restorationGeneration = UUID()
        init(_ parent: ReaderTextSurface) { self.parent = parent }

        func layoutChanged(_ view: UITextView) {
            guard view.bounds.width > 0 else { return }
            if abs(view.bounds.width - previousWidth) > 0.5 {
                previousWidth = view.bounds.width
                pendingOffset = pendingOffset ?? parent.scalarOffset
                scheduleRestore(view)
            }
        }

        func scheduleRestore(_ view: UITextView) {
            restoring = true
            let generation = UUID()
            restorationGeneration = generation
            DispatchQueue.main.async { [weak self, weak view] in
                guard let self, let view, let projection = self.projection, self.restorationGeneration == generation,
                      view.bounds.width > 0 else { return }
                view.layoutManager.ensureLayout(for: view.textContainer)
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
                DispatchQueue.main.async { [weak self] in
                    guard self?.restorationGeneration == generation else { return }
                    self?.restoring = false
                }
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard !restoring, let view = scrollView as? UITextView, let projection, view.textStorage.length > 0,
                  view.isDragging || view.isDecelerating else { return }
            let y = max(0, view.contentOffset.y - view.textContainerInset.top)
            let glyph = view.layoutManager.glyphIndex(for: CGPoint(x: 1, y: y), in: view.textContainer)
            let utf16 = max(0, view.layoutManager.characterIndexForGlyph(at: glyph) - prefixUTF16)
            let offset = projection.sourceScalarOffset(forDisplayUTF16: utf16, preserving: visibleAnchor)
            if visibleAnchor?.displayUTF16Offset != utf16 { visibleAnchor = nil }
            parent.positionChanged(offset)
        }

        @objc func tapped(_ gesture: UITapGestureRecognizer) {
            guard let view = gesture.view, gesture.state == .ended else { return }
            let x = gesture.location(in: view).x
            if x > view.bounds.width / 3, x < view.bounds.width * 2 / 3 { parent.centerTapped() }
        }
    }
}

private final class ReaderMeasuredTextView: UITextView {
    var afterLayout: (() -> Void)?
    override func layoutSubviews() { super.layoutSubviews(); afterLayout?() }
}
