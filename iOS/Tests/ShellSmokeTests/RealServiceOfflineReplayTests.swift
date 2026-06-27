import XCTest
import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreServices

/// Offline replay E2E: uses local HTML fixtures with ReaderCoreServices
/// to verify the full search→TOC→content pipeline via ReaderCoreServiceFactory.
/// No direct imports of ReaderCoreParser/ReaderCoreNetwork (boundary-safe).
final class RealServiceOfflineReplayTests: XCTestCase {

    private var bookSource: BookSource!
    private var searchHTML: Data!
    private var tocHTML: Data!
    private var contentHTML: Data!

    override func setUp() async throws {
        let fixtureDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("test_inputs/fixtures")

        let bsData = try Data(contentsOf: fixtureDir.appendingPathComponent("book_source.json"))
        bookSource = try JSONDecoder().decode(BookSource.self, from: bsData)
        searchHTML = try Data(contentsOf: fixtureDir.appendingPathComponent("search.html"))
        tocHTML = try Data(contentsOf: fixtureDir.appendingPathComponent("toc.html"))
        contentHTML = try Data(contentsOf: fixtureDir.appendingPathComponent("content.html"))
    }

    // MARK: - Search E2E

    func testRealSearchOfflineReplay_returnsSearchResults() async throws {
        let fixtureClient = FixtureHTTPClient(responseData: searchHTML, statusCode: 200)
        let factory = ReaderCoreServiceFactory(httpClient: fixtureClient)
        let service = factory.makeSearchService()

        let results = try await service.search(source: bookSource, query: SearchQuery(keyword: "test"))

        XCTAssertFalse(results.isEmpty, "Should find search results from real fixture")
        for result in results {
            XCTAssertFalse(result.title.isEmpty, "Each result must have a title")
            XCTAssertFalse(result.detailURL.isEmpty, "Each result must have a detail URL")
        }
    }

    // MARK: - TOC E2E

    func testRealTOCOfflineReplay_returnsChapterList() async throws {
        let fixtureClient = FixtureHTTPClient(responseData: tocHTML, statusCode: 200)
        let factory = ReaderCoreServiceFactory(httpClient: fixtureClient)
        let service = factory.makeTOCService()

        let chapters = try await service.fetchTOC(source: bookSource, detailURL: "https://www.tianyabooks.com/book/1")

        XCTAssertFalse(chapters.isEmpty, "Should find chapters from real fixture")
        for chapter in chapters {
            XCTAssertFalse(chapter.chapterTitle.isEmpty, "Each chapter must have a title")
            XCTAssertFalse(chapter.chapterURL.isEmpty, "Each chapter must have a URL")
        }
    }

    // MARK: - Content E2E

    func testRealContentOfflineReplay_returnsContentPage() async throws {
        let fixtureClient = FixtureHTTPClient(responseData: contentHTML, statusCode: 200)
        let factory = ReaderCoreServiceFactory(httpClient: fixtureClient)
        let service = factory.makeContentService()

        let page = try await service.fetchContent(source: bookSource, chapterURL: "https://www.tianyabooks.com/book/1/chapter/1")

        XCTAssertFalse(page.content.isEmpty, "Should have content from real fixture")
    }

    // MARK: - Factory wiring

    func testReaderCoreServiceFactory_producesWiredServices() {
        let fixtureClient = FixtureHTTPClient(responseData: Data(), statusCode: 200)
        let factory = ReaderCoreServiceFactory(httpClient: fixtureClient)

        XCTAssertNotNil(factory.makeSearchService())
        XCTAssertNotNil(factory.makeTOCService())
        XCTAssertNotNil(factory.makeContentService())
    }
}

// MARK: - Fixture HTTP Client

private actor FixtureHTTPClient: HTTPClient {
    let responseData: Data
    let statusCode: Int
    private(set) var capturedRequests: [HTTPRequest] = []

    init(responseData: Data, statusCode: Int) {
        self.responseData = responseData
        self.statusCode = statusCode
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        capturedRequests.append(request)
        return HTTPResponse(
            statusCode: statusCode,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            data: responseData
        )
    }
}

// MARK: - Xmanhua.com Offline Replay (IOS-4A-NET-001 / IOS-5A-NET-001)

final class XmanhuaOfflineReplayTests: XCTestCase {

    private var xmanhuaSource: BookSource!
    private var xmanhuaSearchHTML: Data!

    override func setUp() async throws {
        let fixtureDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("test_inputs/fixtures")

        let bsData = try Data(contentsOf: fixtureDir.appendingPathComponent("xmanhua_source.json"))
        xmanhuaSource = try JSONDecoder().decode(BookSource.self, from: bsData)
        xmanhuaSearchHTML = try Data(contentsOf: fixtureDir.appendingPathComponent("xmanhua_search.html"))
    }

    // MARK: - IOS-4A-NET-001

    func testXmanhuaSourceJSON_loadsSuccessfully() {
        XCTAssertEqual(xmanhuaSource.bookSourceName, "星际漫画(xmanhua)")
        XCTAssertEqual(xmanhuaSource.searchUrl, "https://www.xmanhua.com/search?title={{key}}&page={{page}}")
        // Legado BookSource.ruleSearch is either a String (pipe-chain) or a dict
        // (typed SearchRule). The xmanhua fixture uses the dict form, which decodes
        // into `searchRule`; `ruleSearch` (String) stays nil. Assert the typed model.
        XCTAssertNil(xmanhuaSource.ruleSearch, "Object-form ruleSearch must not populate the String field")
        XCTAssertEqual(xmanhuaSource.searchRule?.bookList, "@css:.mh-list li")
        XCTAssertEqual(xmanhuaSource.searchRule?.name, "h2.title@text")
        XCTAssertEqual(xmanhuaSource.searchRule?.bookUrl, "a@href")
    }

    func testXmanhuaSearchReplay_extractsSearchResults() async throws {
        let fixtureClient = FixtureHTTPClient(responseData: xmanhuaSearchHTML, statusCode: 200)
        let factory = ReaderCoreServiceFactory(httpClient: fixtureClient)
        let service = factory.makeSearchService()

        let results = try await service.search(source: xmanhuaSource, query: SearchQuery(keyword: "劍來"))

        XCTAssertFalse(results.isEmpty, "Should extract search results from xmanhua fixture")
        for result in results {
            XCTAssertFalse(result.title.isEmpty || result.detailURL.isEmpty,
                          "Each result must have title and detailURL")
        }
    }

    func testXmanhuaReplay_noNetworkAccess() async throws {
        let fixtureClient = FixtureHTTPClient(responseData: xmanhuaSearchHTML, statusCode: 200)
        let factory = ReaderCoreServiceFactory(httpClient: fixtureClient)
        let service = factory.makeSearchService()

        _ = try await service.search(source: xmanhuaSource, query: SearchQuery(keyword: "test"))
        let requests = await fixtureClient.capturedRequests
        XCTAssertEqual(requests.count, 1)
        XCTAssertTrue(requests.first?.url.contains("xmanhua.com") ?? false)
    }

    // MARK: - IOS-5A-NET-001

    func testXmanhuaDetailPage_hasChapterLinks() throws {
        let detailHTML = try Data(contentsOf: fixturePath("xmanhua_detail.html"))
        // Detail page contains 96 chapter links (/mXXXXX/) — TOC replay viable
        let html = String(data: detailHTML, encoding: .utf8) ?? ""
        XCTAssertTrue(html.contains("/m"), "Detail page should contain chapter links")
        XCTAssertTrue(html.contains("英雄歸來"), "Detail page should contain comic title")
    }

    func testXmanhuaChapterPage_contentRequiresJS() throws {
        let chapterHTML = try Data(contentsOf: fixturePath("xmanhua_chapter.html"))
        let html = String(data: chapterHTML, encoding: .utf8) ?? ""
        // Chapter images are loaded via JS (comic reader) — NonJS cannot extract
        // This is a known limitation: JS-rendered content requires WebView/S26.6
        XCTAssertFalse(html.isEmpty, "Chapter page exists but content is JS-rendered")
    }

    private func fixturePath(_ name: String) -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("test_inputs/fixtures").appendingPathComponent(name)
    }
}
