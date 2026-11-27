import UIKit

@MainActor
final class TextSurfaceCanvas: UIView {
    var layout: CoreTextLayout? { didSet { setNeedsDisplay() } }
    var page = 0 { didSet { setNeedsDisplay() } }
    var scroll = false { didSet { setNeedsDisplay() } }
    var offset: CGFloat = 0 { didSet { setNeedsDisplay() } }
    var selected: Range<Int>? { didSet { setNeedsDisplay() } }
    var selectionColor = UIColor.clear.cgColor

    init() {
        super.init(frame: .zero)
        isOpaque = false
        backgroundColor = .clear
        contentMode = .redraw
        isAccessibilityElement = true
        accessibilityTraits = .staticText
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let layout, let context = UIGraphicsGetCurrentContext(), !layout.pages.isEmpty else { return }
        if !scroll {
            layout.draw(page: page, selected: selected, in: context, selectionColor: selectionColor)
            return
        }
        let height = layout.viewport.height
        let lower = max(0, Int((offset + rect.minY) / height))
        let upper = min(layout.pages.count - 1, Int((offset + rect.maxY) / height))
        guard upper >= lower else { return }
        for page in lower...upper {
            context.saveGState()
            context.translateBy(x: 0, y: CGFloat(page) * height - offset)
            layout.draw(page: page, selected: selected, in: context, selectionColor: selectionColor)
            context.restoreGState()
        }
    }
}
