import XCTest
@testable import ReaderCoreParser
import ReaderCoreProtocols

final class FixtureTocParserTests: XCTestCase {
    // Minimal naming entry reserved for later samples/metadata/expected mapping.
    private enum RegressionSampleID {
        static let titleMiss = "fixture_toc_title_rule_miss"
        static let urlMiss = "fixture_toc_url_rule_miss"
        static let countMismatch = "fixture_toc_count_mismatch"
        static let nonSelectorError = "fixture_toc_non_selector_error"
    }

    private var parser: FixtureTocParser!
    
    override func setUp() {
        super.setUp()
        parser = FixtureTocParser()
    }
    
    override func tearDown() {
        parser = nil
        super.tearDown()
    }

    // MARK: - Real Executor Contract Tests

    func testTitleExtraction() throws {
        let html = TocFixtures.simpleLinks
        let items = try parser.parse(
            html: html,
            titleRule: "a@text",
            urlRule: "a@href",
            baseURL: nil
        )
        
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].title, "第一章")
        XCTAssertEqual(items[1].title, "第二章")
        XCTAssertEqual(items[2].title, "第三章")
    }
    
    func testURLExtraction() throws {
        let html = TocFixtures.simpleLinks
        let items = try parser.parse(
            html: html,
            titleRule: "a@text",
            urlRule: "a@href",
            baseURL: nil
        )
        
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].url, "/chapter1.html")
        XCTAssertEqual(items[1].url, "/chapter2.html")
        XCTAssertEqual(items[2].url, "/chapter3.html")
    }
    
    func testRelativeURLToAbsoluteWithBaseURL() throws {
        let html = TocFixtures.relativeURLs
        let items = try parser.parse(
            html: html,
            titleRule: "a@text",
            urlRule: "a@href",
            baseURL: "https://example.com/book/"
        )
        
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].url, "https://example.com/book/ch1.html")
        XCTAssertEqual(items[1].url, "https://example.com/book/ch2.html")
        XCTAssertEqual(items[2].url, "https://example.com/book/ch3.html")
    }
    
    func testRelativeURLWithoutBaseURL() throws {
        let html = TocFixtures.relativeURLs
        let items = try parser.parse(
            html: html,
            titleRule: "a@text",
            urlRule: "a@href",
            baseURL: nil
        )
        
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].url, "ch1.html")
        XCTAssertEqual(items[1].url, "ch2.html")
        XCTAssertEqual(items[2].url, "../book/ch3.html")
    }
    
    func testEmptyResult() throws {
        let html = TocFixtures.emptyResult
        let items = try parser.parse(
            html: html,
            titleRule: "a@text",
            urlRule: "a@href",
            baseURL: nil
        )
        
        XCTAssertEqual(items.count, 0)
    }
    
    func testTitlePostProcessing() throws {
        let html = TocFixtures.mixedTitles
        let items = try parser.parse(
            html: html,
            titleRule: "a@text",
            urlRule: "a@href",
            baseURL: nil
        )
        
        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].title, "第一章")
        XCTAssertEqual(items[1].title, "第二章")
        XCTAssertEqual(items[2].title, "第三章")
    }
    
    func testSelectorMiss() throws {
        let html = TocFixtures.selectorMiss
        let items = try parser.parse(
            html: html,
            titleRule: "a@text",
            urlRule: "a@href",
            baseURL: nil
        )
        
        XCTAssertEqual(items.count, 0)
    }

    func testTitleRuleMissReturnsEmpty() throws {
        XCTAssertEqual(RegressionSampleID.titleMiss, "fixture_toc_title_rule_miss")

        let html = TocFixtures.simpleLinks
        let items = try parser.parse(
            html: html,
            titleRule: ".missing@text",
            urlRule: "a@href",
            baseURL: nil
        )

        XCTAssertEqual(items.count, 0)
    }

    func testURLRuleMissReturnsEmpty() throws {
        XCTAssertEqual(RegressionSampleID.urlMiss, "fixture_toc_url_rule_miss")

        let html = TocFixtures.simpleLinks
        let items = try parser.parse(
            html: html,
            titleRule: "a@text",
            urlRule: ".missing@href",
            baseURL: nil
        )

        XCTAssertEqual(items.count, 0)
    }

    func testCountMismatchReturnsEmpty() throws {
        XCTAssertEqual(RegressionSampleID.countMismatch, "fixture_toc_count_mismatch")

        let html = TocFixtures.simpleLinks
        let items = try parser.parse(
            html: html,
            titleRule: "ul@text",
            urlRule: "a@href",
            baseURL: nil
        )

        XCTAssertEqual(items.count, 0)
    }

    // MARK: - Stubbed Error Propagation Tests

    func testNonSelectorMissErrorIsRethrown() {
        XCTAssertEqual(RegressionSampleID.nonSelectorError, "fixture_toc_non_selector_error")

        let parser = FixtureTocParser(
            cssExecutor: StubFixtureTocRuleExecutor(
                result: .failure(.invalidSelector("["))
            )
        )

        XCTAssertThrowsError(
            try parser.parse(
                html: TocFixtures.simpleLinks,
                titleRule: "a@text",
                urlRule: "a@href",
                baseURL: nil
            )
        ) { error in
            XCTAssertEqual(error as? CSSExecutorError, .invalidSelector("["))
        }
    }
}

private struct StubFixtureTocRuleExecutor: FixtureTocRuleExecuting {
    let result: Result<[String], CSSExecutorError>

    func execute(_ rule: String, from html: String) throws -> [String] {
        try result.get()
    }
}
