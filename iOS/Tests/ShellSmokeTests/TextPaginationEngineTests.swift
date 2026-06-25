import XCTest
@testable import ReaderShellValidation

final class TextPaginationEngineTests: XCTestCase {

    private func makeMetrics(
        fontSize: Int = 18,
        lineSpacing: Double = 8,
        paragraphSpacing: Double = 16,
        horizontalPadding: Double = 16,
        verticalPadding: Double = 16,
        availableWidth: Double = 320,
        availableHeight: Double = 480
    ) -> PaginationMetrics {
        PaginationMetrics(
            fontSize: fontSize,
            lineSpacing: lineSpacing,
            paragraphSpacing: paragraphSpacing,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding,
            availableWidth: availableWidth,
            availableHeight: availableHeight
        )
    }

    func testEmptyTextProducesNoPages() {
        let pages = TextPaginationEngine().paginate("", metrics: makeMetrics())
        XCTAssertTrue(pages.isEmpty)
    }

    func testShortTextProducesSinglePage() {
        let text = "Hello world."
        let pages = TextPaginationEngine().paginate(text, metrics: makeMetrics())
        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].index, 0)
        let reconstructed = String(text[pages[0].start..<pages[0].end])
        XCTAssertEqual(reconstructed, text)
    }

    func testLongTextSplitsIntoMultiplePages() {
        let paragraph = String(repeating: "a", count: 100)
        let text = (0..<50).map { _ in paragraph }.joined(separator: "\n")
        let pages = TextPaginationEngine().paginate(text, metrics: makeMetrics())
        XCTAssertGreaterThan(pages.count, 1, "5000-char text should split into multiple pages")
        for page in pages {
            XCTAssertGreaterThan(page.characterCount, 0, "Page \(page.index) should not be empty")
        }
        let reconstructed = pages.map { String(text[$0.start..<$0.end]) }.joined()
        XCTAssertEqual(reconstructed, text)
    }

    func testPagesRespectParagraphBoundariesWhenPossible() {
        let paragraph = String(repeating: "b", count: 80)
        let text = (0..<10).map { _ in paragraph }.joined(separator: "\n\n")
        let pages = TextPaginationEngine().paginate(text, metrics: makeMetrics())
        XCTAssertGreaterThan(pages.count, 1)
        for page in pages where page.index > 0 {
            let charBefore = text[text.index(before: page.start)]
            XCTAssertEqual(charBefore, "\n", "Page \(page.index) should start at a paragraph boundary")
        }
    }

    func testLargerFontProducesMorePages() {
        let text = String(repeating: "The quick brown fox. ", count: 200)
        let smallFontPages = TextPaginationEngine().paginate(text, metrics: makeMetrics(fontSize: 14))
        let largeFontPages = TextPaginationEngine().paginate(text, metrics: makeMetrics(fontSize: 28))
        XCTAssertGreaterThan(largeFontPages.count, smallFontPages.count,
                             "Larger font should produce more pages")
    }

    func testSmallerViewportProducesMorePages() {
        let text = String(repeating: "The quick brown fox. ", count: 200)
        let bigViewport = TextPaginationEngine().paginate(text, metrics: makeMetrics(availableWidth: 400, availableHeight: 600))
        let smallViewport = TextPaginationEngine().paginate(text, metrics: makeMetrics(availableWidth: 200, availableHeight: 300))
        XCTAssertGreaterThan(smallViewport.count, bigViewport.count,
                             "Smaller viewport should produce more pages")
    }

    func testPageIndexSequenceIsContiguous() {
        let text = String(repeating: "Content line.\n", count: 300)
        let pages = TextPaginationEngine().paginate(text, metrics: makeMetrics())
        for (i, page) in pages.enumerated() {
            XCTAssertEqual(page.index, i, "Page indices should be contiguous starting at 0")
        }
    }

    func testLastPageEndMatchesTextEnd() {
        let text = String(repeating: "Final page test. ", count: 100)
        let pages = TextPaginationEngine().paginate(text, metrics: makeMetrics())
        guard let last = pages.last else {
            return XCTFail("Expected at least one page")
        }
        XCTAssertEqual(last.end, text.endIndex, "Last page end must match text endIndex")
    }
}
