import CoreText
import ReaderDesign
import UIKit

@MainActor
struct CoreTextLayout {
    struct Page {
        let frame: CTFrame
        let scalars: Range<Int>
    }

    let coordinates: ScalarCoordinates
    let viewport: CGSize
    let pages: [Page]

    init(coordinates: ScalarCoordinates, style: TextLayoutStyle, viewport: CGSize) {
        self.coordinates = coordinates
        self.viewport = viewport
        guard viewport.width > 1, viewport.height > 1, coordinates.scalarCount > 0 else { pages = []; return }
        let attributed = style.content(coordinates.text)
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        let path = CGPath(rect: CGRect(origin: .zero, size: viewport), transform: nil)
        var frames = [Page]()
        var start = 0
        while start < coordinates.utf16Count {
            let frame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), path, nil)
            let range = CTFrameGetVisibleStringRange(frame)
            let end = range.location + range.length
            guard end > start, let first = coordinates.scalar(at: start),
                  let last = coordinates.scalar(at: end), first < last else { break }
            frames.append(Page(frame: frame, scalars: first..<last))
            start = end
        }
        pages = frames
    }

    func page(containing scalar: Int) -> Int? {
        var lower = 0
        var upper = pages.count
        while lower < upper {
            let mid = lower + (upper - lower) / 2
            let range = pages[mid].scalars
            if scalar < range.lowerBound { upper = mid }
            else if scalar >= range.upperBound { lower = mid + 1 }
            else { return mid }
        }
        return nil
    }

    func scalar(in page: Int, at point: CGPoint) -> Int? {
        guard pages.indices.contains(page) else { return nil }
        let (lines, origins) = lineInfo(page)
        let y = viewport.height - point.y
        guard let lineIndex = origins.indices.min(by: {
            abs(origins[$0].y - y) < abs(origins[$1].y - y)
        }) else { return nil }
        let line = lines[lineIndex]
        let position = CGPoint(x: point.x - origins[lineIndex].x, y: y - origins[lineIndex].y)
        let raw = CTLineGetStringIndexForPosition(line, position)
        guard raw != kCFNotFound else { return nil }
        let range = pages[page].scalars
        return min(range.upperBound - 1, max(range.lowerBound, coordinates.precedingScalar(utf16: raw)))
    }

    func baselines(in page: Int) -> [(Int, CGFloat)] {
        guard pages.indices.contains(page) else { return [] }
        let (lines, origins) = lineInfo(page)
        return zip(lines, origins).map {
            (coordinates.precedingScalar(utf16: CTLineGetStringRange($0.0).location), viewport.height - $0.1.y)
        }
    }

    func draw(page: Int, selected: Range<Int>?, in context: CGContext, selectionColor: CGColor) {
        guard pages.indices.contains(page) else { return }
        context.saveGState()
        context.textMatrix = .identity
        context.translateBy(x: 0, y: viewport.height)
        context.scaleBy(x: 1, y: -1)
        if let selected, let start = coordinates.utf16(at: selected.lowerBound),
           let end = coordinates.utf16(at: selected.upperBound) {
            drawSelection(page: page, start: start, end: end, context: context, color: selectionColor)
        }
        CTFrameDraw(pages[page].frame, context)
        context.restoreGState()
    }

    private func lineInfo(_ page: Int) -> ([CTLine], [CGPoint]) {
        let frame = pages[page].frame
        let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
        var origins = Array(repeating: CGPoint.zero, count: lines.count)
        if !origins.isEmpty { CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins) }
        return (lines, origins)
    }

    private func drawSelection(page: Int, start: Int, end: Int, context: CGContext, color: CGColor) {
        let (lines, origins) = lineInfo(page)
        context.setFillColor(color)
        for (line, origin) in zip(lines, origins) {
            let span = CTLineGetStringRange(line)
            let lower = max(start, span.location)
            let upper = min(end, span.location + span.length)
            guard lower < upper else { continue }
            let first = CTLineGetOffsetForStringIndex(line, lower, nil)
            let last = CTLineGetOffsetForStringIndex(line, upper, nil)
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            CTLineGetTypographicBounds(line, &ascent, &descent, nil)
            context.fill(CGRect(x: origin.x + min(first, last), y: origin.y - descent,
                                width: max(1, abs(last - first)), height: ascent + descent))
        }
    }
}

@MainActor
struct TextLayoutStyle {
    let preferences: ReadingPreferences

    func content(_ text: String) -> NSAttributedString {
        let font = ReaderTypography.nativeFont(ReaderDesignMetrics.readerBody, size: preferences.fontSize)
        let paragraph = NSMutableParagraphStyle()
        paragraph.minimumLineHeight = preferences.fontSize * preferences.lineSpacing
        paragraph.maximumLineHeight = paragraph.minimumLineHeight
        paragraph.paragraphSpacing = CGFloat(ReaderDesignMetrics.readerParagraphSpacing)
        paragraph.lineBreakMode = .byWordWrapping
        return NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: preferences.paper.uiForeground,
            .kern: preferences.letterSpacing,
            .paragraphStyle: paragraph
        ])
    }
}
