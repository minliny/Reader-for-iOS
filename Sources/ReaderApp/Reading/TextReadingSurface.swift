import ReaderDesign
import UIKit

@MainActor
final class TextReadingSurface: NSObject, ReadingSurface, UIScrollViewDelegate {
    struct Document: Sendable {
        let content: String
    }

    let view = UIScrollView()
    private let canvas = TextSurfaceCanvas()
    private var coordinates = ScalarCoordinates("")
    private var preferences = ReadingPreferences()
    private var viewport = CGSize(width: 320, height: 540)
    private(set) var layout: CoreTextLayout?
    private var anchor = 0
    private var currentPage = 0
    private var selected: Range<Int>?
    private var selectionOrigin: Int?
    private var programmaticScroll = false
    var onPosition: ((Int) -> Void)?
    var onTap: (() -> Void)?

    override init() {
        super.init()
        view.delegate = self
        view.contentInsetAdjustmentBehavior = .never
        view.scrollsToTop = false
        view.showsVerticalScrollIndicator = false
        view.accessibilityIdentifier = "reader-text-surface"
        view.addSubview(canvas)
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapped))
        let select = UILongPressGestureRecognizer(target: self, action: #selector(selectText(_:)))
        tap.require(toFail: select)
        canvas.addGestureRecognizer(tap)
        canvas.addGestureRecognizer(select)
    }

    func prepare(preferences: ReadingPreferences, viewport: CGSize) {
        guard viewport.width > 1, viewport.height > 1 else { return }
        let changed = self.preferences != preferences || self.viewport != viewport
        self.preferences = preferences
        self.viewport = viewport
        if changed, layout != nil { rebuild() }
    }

    func open(_ document: Document, session: String, anchor: Int, style: EbookStyle) async throws -> EbookScriptEvent.Value {
        load(document, anchor: anchor)
    }

    @discardableResult
    func load(_ document: Document, anchor: Int) -> EbookScriptEvent.Value {
        coordinates = ScalarCoordinates(document.content)
        self.anchor = bounded(anchor)
        selected = nil
        rebuild()
        return snapshot()
    }

    func reflow(style: EbookStyle, anchor: Int?) async throws -> EbookScriptEvent.Value {
        if let anchor { self.anchor = bounded(anchor) }
        preferences.fontSize = style.fontSize
        preferences.lineSpacing = style.lineHeight / style.fontSize
        rebuild()
        return snapshot()
    }

    func turn(_ direction: Int) -> Bool {
        guard let layout, direction != 0, layout.pages.indices.contains(currentPage + direction) else { return false }
        place(layout.pages[currentPage + direction].scalars.lowerBound)
        onPosition?(anchor)
        return true
    }

    func select(start: Int, end: Int) async throws -> EbookScriptEvent.Value? {
        guard start < end, coordinates.utf16(at: start) != nil, coordinates.utf16(at: end) != nil else { return nil }
        selected = start..<end
        canvas.selected = selected
        return selectionSnapshot()
    }

    func selection() async throws -> EbookScriptEvent.Value? { selectionSnapshot() }
    func position() async throws -> EbookScriptEvent.Value? { layout.map { _ in snapshot() } }

    func restore(_ scalar: Int) async throws -> EbookScriptEvent.Value? {
        guard layout != nil, scalar == bounded(scalar) else { return nil }
        place(scalar)
        onPosition?(anchor)
        return snapshot()
    }

    func retire() async {
        layout = nil
        canvas.layout = nil
        canvas.selected = nil
        selected = nil
        selectionOrigin = nil
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard preferences.mode == .scroll, !programmaticScroll, let layout, !layout.pages.isEmpty else { return }
        let offset = max(0, scrollView.contentOffset.y)
        setCanvasOrigin(offset)
        let page = min(layout.pages.count - 1, Int(offset / layout.viewport.height))
        let y = offset - CGFloat(page) * layout.viewport.height
        let start = layout.baselines(in: page).first(where: { $0.1 >= y })?.0 ?? layout.pages[page].scalars.lowerBound
        currentPage = page
        if start != anchor {
            anchor = bounded(start)
            onPosition?(anchor)
        }
    }

    @objc private func tapped() { onTap?() }

    @objc private func selectText(_ gesture: UILongPressGestureRecognizer) {
        guard let layout else { return }
        let point = gesture.location(in: canvas)
        let contentY = point.y + canvas.offset
        let page = preferences.mode == .scroll ? Int(max(0, contentY) / layout.viewport.height) : currentPage
        let y = preferences.mode == .scroll ? contentY - CGFloat(page) * layout.viewport.height : point.y
        guard let pointScalar = layout.scalar(in: page, at: CGPoint(x: point.x, y: y)) else { return }
        if gesture.state == .began { selectionOrigin = pointScalar }
        if let origin = selectionOrigin {
            let lower = min(origin, pointScalar)
            let upper = min(coordinates.scalarCount, max(origin, pointScalar) + 1)
            if let lowerUTF16 = coordinates.utf16(at: lower), let upperUTF16 = coordinates.utf16(at: upper),
               upperUTF16 > lowerUTF16 {
                let range = (coordinates.text as NSString).rangeOfComposedCharacterSequences(
                    for: NSRange(location: lowerUTF16, length: upperUTF16 - lowerUTF16))
                if let first = coordinates.scalar(at: range.location),
                   let last = coordinates.scalar(at: NSMaxRange(range)) { selected = first..<last }
            }
            canvas.selected = selected
        }
        if gesture.state == .ended || gesture.state == .cancelled { selectionOrigin = nil }
    }

    private func rebuild() {
        programmaticScroll = true
        let layout = CoreTextLayout(coordinates: coordinates, style: .init(preferences: preferences), viewport: viewport)
        self.layout = layout
        let scroll = preferences.mode == .scroll
        let height = scroll ? max(viewport.height, CGFloat(layout.pages.count) * viewport.height) : viewport.height
        view.isScrollEnabled = scroll
        canvas.frame = CGRect(origin: .zero, size: viewport)
        canvas.layout = layout
        canvas.scroll = scroll
        canvas.selected = selected
        canvas.selectionColor = UIColor(preferences.paper.selection).withAlphaComponent(0.5).cgColor
        view.contentSize = CGSize(width: viewport.width, height: height)
        place(anchor)
        programmaticScroll = false
    }

    private func place(_ scalar: Int) {
        guard let layout else { return }
        anchor = bounded(scalar)
        currentPage = layout.page(containing: anchor) ?? 0
        canvas.page = currentPage
        if layout.pages.indices.contains(currentPage) {
            canvas.accessibilityLabel = coordinates.string(layout.pages[currentPage].scalars)
        }
        guard preferences.mode == .scroll else {
            view.setContentOffset(.zero, animated: false)
            setCanvasOrigin(0)
            return
        }
        let saved = programmaticScroll
        programmaticScroll = true
        let previousLine = layout.baselines(in: currentPage).last(where: { $0.0 <= anchor })
        let top = CGFloat(currentPage) * layout.viewport.height + max(0, (previousLine?.1 ?? 10) - 16)
        let offset = min(max(0, view.contentSize.height - viewport.height), top)
        view.setContentOffset(CGPoint(x: 0, y: offset), animated: false)
        setCanvasOrigin(offset)
        programmaticScroll = saved
    }

    private func setCanvasOrigin(_ offset: CGFloat) {
        // Draw only the blocks intersecting the viewport without allocating a chapter-height backing layer.
        canvas.frame = CGRect(origin: CGPoint(x: 0, y: offset), size: viewport)
        canvas.offset = offset
    }

    private func bounded(_ scalar: Int) -> Int { min(max(0, coordinates.scalarCount - 1), max(0, scalar)) }

    private func snapshot() -> EbookScriptEvent.Value {
        let end = min(coordinates.scalarCount, anchor + 1)
        return EbookScriptEvent.Value(scalar: anchor, text: coordinates.string(anchor..<end))
    }

    private func selectionSnapshot() -> EbookScriptEvent.Value? {
        selected.map {
            EbookScriptEvent.Value(text: coordinates.string($0), startScalar: $0.lowerBound, endScalar: $0.upperBound)
        }
    }
}
