import XCTest
@testable import ReaderCoreParser
import ReaderCoreModels

/// Regression tests for sample_005 (non-JS parser, CSS tag selectors: article / section / .text-block).
///
/// Each test asserts the exact output of NonJSParserEngine against fixture HTML strings
/// and expected values declared in samples/expected/. These are the XCTest-backed
/// counterpart to the Sample005NonJSSmokeRunner CLI and form the CI-verifiable layer
/// of the sample_005 closed loop.
///
/// Source assets:
///   BookSource: samples/booksources/p0_non_js/sample_005.json
///   Fixtures:   samples/fixtures/html/sample_005_{search,toc,content}.html
///   Expected:   samples/expected/{search,toc,content}/sample_005.json
final class NonJSSample005RegressionTests: XCTestCase {

    // BookSource mirrors samples/booksources/p0_non_js/sample_005.json
    private let bookSource = BookSource(
        bookSourceName: "Sample-005-Fixture",
        bookSourceUrl: "http://fixture5.local",
        searchUrl: "http://fixture5.local/search?q={{key}}",
        ruleSearch: "css:article",
        ruleToc: "css:section",
        ruleContent: "css:.text-block"
    )

    // Fixture HTML mirrors samples/fixtures/html/sample_005_search.html
    private let searchHTML = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>Search</title></head>
        <body>
        <article>失落的地平线|http://fixture5.local/book/1.html</article>
        <article>茶馆|http://fixture5.local/book/2.html</article>
        </body>
        </html>
        """

    // Fixture HTML mirrors samples/fixtures/html/sample_005_toc.html
    private let tocHTML = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>TOC</title></head>
        <body>
        <section>第一幕 开场|http://fixture5.local/ch/1.html</section>
        <section>第二幕 冲突|http://fixture5.local/ch/2.html</section>
        <section>第三幕 结局|http://fixture5.local/ch/3.html</section>
        </body>
        </html>
        """

    // Fixture HTML mirrors samples/fixtures/html/sample_005_content.html
    private let contentHTML = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>Content</title></head>
        <body>
        <div class="text-block">老舍先生以茶馆为舞台，展现了三个时代的社会变迁与人情冷暖。王利发在时代的洪流中挣扎求存，茶馆见证了历史。</div>
        </body>
        </html>
        """

    // ── Search ────────────────────────────────────────────────────────────────

    /// Contract: css:article on sample_005_search.html returns exactly 2 items,
    /// with titles and detailURLs matching samples/expected/search/sample_005.json.
    func testSearchParsesTwoItemsFromFixture() throws {
        let engine = NonJSParserEngine()
        let result = try engine.parseSearchResponse(
            Data(searchHTML.utf8),
            source: bookSource,
            query: SearchQuery(keyword: "fixture")
        )
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].title, "失落的地平线")
        XCTAssertEqual(result[0].detailURL, "http://fixture5.local/book/1.html")
        XCTAssertEqual(result[1].title, "茶馆")
        XCTAssertEqual(result[1].detailURL, "http://fixture5.local/book/2.html")
    }

    // ── TOC ───────────────────────────────────────────────────────────────────

    /// Contract: css:section on sample_005_toc.html returns exactly 3 chapters,
    /// with titles and URLs matching samples/expected/toc/sample_005.json.
    func testTOCParsesThreeChaptersFromFixture() throws {
        let engine = NonJSParserEngine()
        let result = try engine.parseTOCResponse(
            Data(tocHTML.utf8),
            source: bookSource,
            detailURL: "http://fixture5.local/book/1.html"
        )
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].chapterTitle, "第一幕 开场")
        XCTAssertEqual(result[0].chapterURL, "http://fixture5.local/ch/1.html")
        XCTAssertEqual(result[1].chapterTitle, "第二幕 冲突")
        XCTAssertEqual(result[1].chapterURL, "http://fixture5.local/ch/2.html")
        XCTAssertEqual(result[2].chapterTitle, "第三幕 结局")
        XCTAssertEqual(result[2].chapterURL, "http://fixture5.local/ch/3.html")
    }

    // ── Content ───────────────────────────────────────────────────────────────

    /// Contract: css:.text-block on sample_005_content.html returns the exact content
    /// string declared in samples/expected/content/sample_005.json.
    func testContentParsesExpectedTextFromFixture() throws {
        let engine = NonJSParserEngine()
        let page = try engine.parseContentResponse(
            Data(contentHTML.utf8),
            source: bookSource,
            chapterURL: "http://fixture5.local/ch/1.html"
        )
        XCTAssertFalse(page.content.isEmpty)
        XCTAssertEqual(
            page.content,
            "老舍先生以茶馆为舞台，展现了三个时代的社会变迁与人情冷暖。王利发在时代的洪流中挣扎求存，茶馆见证了历史。"
        )
    }
}
