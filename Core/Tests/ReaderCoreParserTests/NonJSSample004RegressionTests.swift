import XCTest
@testable import ReaderCoreParser
import ReaderCoreModels

/// Regression tests for sample_004 (non-JS parser, CSS selectors: .entry / .ep / #story).
///
/// Each test asserts the exact output of NonJSParserEngine against fixture HTML strings
/// and expected values declared in samples/expected/. These are the XCTest-backed
/// counterpart to the Sample004NonJSSmokeRunner CLI and form the CI-verifiable layer
/// of the sample_004 closed loop.
///
/// Source assets:
///   BookSource: samples/booksources/p0_non_js/sample_004.json
///   Fixtures:   samples/fixtures/html/sample_004_{search,toc,content}.html
///   Expected:   samples/expected/{search,toc,content}/sample_004.json
final class NonJSSample004RegressionTests: XCTestCase {

    // BookSource mirrors samples/booksources/p0_non_js/sample_004.json
    private let bookSource = BookSource(
        bookSourceName: "Sample-004-Fixture",
        bookSourceUrl: "http://fixture4.local",
        searchUrl: "http://fixture4.local/search?q={{key}}",
        ruleSearch: "css:.entry",
        ruleToc: "css:.ep",
        ruleContent: "css:#story"
    )

    // Fixture HTML mirrors samples/fixtures/html/sample_004_search.html
    private let searchHTML = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>Search</title></head>
        <body>
        <div class="entry">三体|http://fixture4.local/book/1.html</div>
        <div class="entry">斗破苍穹|http://fixture4.local/book/2.html</div>
        <div class="entry">完美世界|http://fixture4.local/book/3.html</div>
        </body>
        </html>
        """

    // Fixture HTML mirrors samples/fixtures/html/sample_004_toc.html
    private let tocHTML = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>TOC</title></head>
        <body>
        <div class="ep">第一章 科学边界|http://fixture4.local/ch/1.html</div>
        <div class="ep">第二章 黑暗森林|http://fixture4.local/ch/2.html</div>
        <div class="ep">第三章 死亡终章|http://fixture4.local/ch/3.html</div>
        <div class="ep">第四章 星际远征|http://fixture4.local/ch/4.html</div>
        </body>
        </html>
        """

    // Fixture HTML mirrors samples/fixtures/html/sample_004_content.html
    private let contentHTML = """
        <!DOCTYPE html>
        <html>
        <head><meta charset="UTF-8"><title>Content</title></head>
        <body>
        <div id="story">宇宙中有无数文明，地球只是其中微不足道的一粒尘埃。叶文洁仰望星空，心中充满了对宇宙真相的渴望与恐惧。</div>
        </body>
        </html>
        """

    // ── Search ────────────────────────────────────────────────────────────────

    /// Contract: css:.entry on sample_004_search.html returns exactly 3 items,
    /// with titles and detailURLs matching samples/expected/search/sample_004.json.
    func testSearchParsesThreeItemsFromFixture() throws {
        let engine = NonJSParserEngine()
        let result = try engine.parseSearchResponse(
            Data(searchHTML.utf8),
            source: bookSource,
            query: SearchQuery(keyword: "fixture")
        )
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0].title, "三体")
        XCTAssertEqual(result[0].detailURL, "http://fixture4.local/book/1.html")
        XCTAssertEqual(result[1].title, "斗破苍穹")
        XCTAssertEqual(result[1].detailURL, "http://fixture4.local/book/2.html")
        XCTAssertEqual(result[2].title, "完美世界")
        XCTAssertEqual(result[2].detailURL, "http://fixture4.local/book/3.html")
    }

    // ── TOC ───────────────────────────────────────────────────────────────────

    /// Contract: css:.ep on sample_004_toc.html returns exactly 4 chapters,
    /// with titles and URLs matching samples/expected/toc/sample_004.json.
    func testTOCParsesFourChaptersFromFixture() throws {
        let engine = NonJSParserEngine()
        let result = try engine.parseTOCResponse(
            Data(tocHTML.utf8),
            source: bookSource,
            detailURL: "http://fixture4.local/book/1.html"
        )
        XCTAssertEqual(result.count, 4)
        XCTAssertEqual(result[0].chapterTitle, "第一章 科学边界")
        XCTAssertEqual(result[0].chapterURL, "http://fixture4.local/ch/1.html")
        XCTAssertEqual(result[1].chapterTitle, "第二章 黑暗森林")
        XCTAssertEqual(result[1].chapterURL, "http://fixture4.local/ch/2.html")
        XCTAssertEqual(result[2].chapterTitle, "第三章 死亡终章")
        XCTAssertEqual(result[2].chapterURL, "http://fixture4.local/ch/3.html")
        XCTAssertEqual(result[3].chapterTitle, "第四章 星际远征")
        XCTAssertEqual(result[3].chapterURL, "http://fixture4.local/ch/4.html")
    }

    // ── Content ───────────────────────────────────────────────────────────────

    /// Contract: css:#story on sample_004_content.html returns the exact content
    /// string declared in samples/expected/content/sample_004.json.
    func testContentParsesExpectedTextFromFixture() throws {
        let engine = NonJSParserEngine()
        let page = try engine.parseContentResponse(
            Data(contentHTML.utf8),
            source: bookSource,
            chapterURL: "http://fixture4.local/ch/1.html"
        )
        XCTAssertFalse(page.content.isEmpty)
        XCTAssertEqual(
            page.content,
            "宇宙中有无数文明，地球只是其中微不足道的一粒尘埃。叶文洁仰望星空，心中充满了对宇宙真相的渴望与恐惧。"
        )
    }
}
