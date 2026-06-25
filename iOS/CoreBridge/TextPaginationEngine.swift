import Foundation

/// Metrics describing the render surface and typography for pagination.
///
/// Foundation-only (no UIKit/SwiftUI) so it can be unit-tested on the macOS host
/// via `ReaderShellValidation`. The iOS view layer converts these `Double` values
/// to `CGFloat` when measuring with `UIFont` / `UIFontDescriptor`.
public struct PaginationMetrics: Equatable, Sendable {
    public var fontSize: Int
    public var lineSpacing: Double
    public var paragraphSpacing: Double
    public var horizontalPadding: Double
    public var verticalPadding: Double
    public var availableWidth: Double
    public var availableHeight: Double

    public init(
        fontSize: Int,
        lineSpacing: Double,
        paragraphSpacing: Double,
        horizontalPadding: Double,
        verticalPadding: Double,
        availableWidth: Double,
        availableHeight: Double
    ) {
        self.fontSize = fontSize
        self.lineSpacing = lineSpacing
        self.paragraphSpacing = paragraphSpacing
        self.horizontalPadding = horizontalPadding
        self.verticalPadding = verticalPadding
        self.availableWidth = availableWidth
        self.availableHeight = availableHeight
    }
}

/// A single page's character range within the source text.
public struct PageRange: Equatable, Sendable {
    public var index: Int
    public var start: String.Index
    public var end: String.Index
    public var characterCount: Int

    public init(index: Int, start: String.Index, end: String.Index, characterCount: Int) {
        self.index = index
        self.start = start
        self.end = end
        self.characterCount = characterCount
    }
}

/// Estimates how text should be split into pages for paginated reading mode.
///
/// This is a **character-budget estimator**, not a pixel-perfect typesetter.
/// Real pixel measurement happens in the iOS view layer with `UIFont` /
/// `NSString.boundingRect`. The estimator gives a stable, deterministic
/// page breakdown that the view layer can refine.
///
/// Algorithm:
/// 1. Derive content width/height by subtracting paddings.
/// 2. Estimate average character width (Latin ~0.55×fontSize, CJK ~1.0×fontSize;
///    we use a blended 0.6× factor as a conservative middle ground).
/// 3. Estimate line height = fontSize × 1.2 + lineSpacing.
/// 4. chars-per-line × lines-per-page = target characters per page.
/// 5. Walk the text; when the running count approaches the target, prefer
///    splitting at the next `\n` (paragraph boundary). If no newline is
///    found within a small look-ahead window, split at the target offset.
public struct TextPaginationEngine: Sendable {
    public init() {}

    public func paginate(_ text: String, metrics: PaginationMetrics) -> [PageRange] {
        guard !text.isEmpty else { return [] }

        let contentWidth = max(1, metrics.availableWidth - 2 * metrics.horizontalPadding)
        let contentHeight = max(1, metrics.availableHeight - 2 * metrics.verticalPadding)

        let fontSizeDouble = Double(metrics.fontSize)
        let avgCharWidth = fontSizeDouble * 0.6
        let lineHeight = fontSizeDouble * 1.2 + metrics.lineSpacing

        let charsPerLine = max(1, Int(contentWidth / avgCharWidth))
        let linesPerPage = max(1, Int(contentHeight / lineHeight))
        let targetCharsPerPage = max(1, charsPerLine * linesPerPage)

        var pages: [PageRange] = []
        var currentIndex = text.startIndex
        var pageIndex = 0

        while currentIndex < text.endIndex {
            let remaining = text.distance(from: currentIndex, to: text.endIndex)
            if remaining <= targetCharsPerPage {
                let count = remaining
                pages.append(PageRange(
                    index: pageIndex,
                    start: currentIndex,
                    end: text.endIndex,
                    characterCount: count
                ))
                break
            }

            let targetOffset = targetCharsPerPage
            let targetIndex = text.index(currentIndex, offsetBy: targetOffset)

            // Look for a paragraph boundary within a look-ahead window
            // (up to 15% of target, but at least 20 chars) after the target.
            let lookAheadChars = max(20, targetCharsPerPage / 7)
            let lookAheadLimit = text.index(
                targetIndex,
                offsetBy: min(lookAheadChars, text.distance(from: targetIndex, to: text.endIndex))
            )

            var splitIndex: String.Index
            if let newlineRange = text.range(of: "\n", range: targetIndex..<lookAheadLimit) {
                // Split after the newline (include the newline in the current page)
                splitIndex = newlineRange.upperBound
            } else {
                // No paragraph boundary nearby — split at the target offset
                splitIndex = targetIndex
            }

            // Guard against zero-length pages (can happen if splitIndex == currentIndex)
            if splitIndex <= currentIndex {
                splitIndex = targetIndex
            }
            if splitIndex > text.endIndex {
                splitIndex = text.endIndex
            }

            let pageCharCount = text.distance(from: currentIndex, to: splitIndex)
            pages.append(PageRange(
                index: pageIndex,
                start: currentIndex,
                end: splitIndex,
                characterCount: pageCharCount
            ))

            currentIndex = splitIndex
            pageIndex += 1
        }

        return pages
    }
}
