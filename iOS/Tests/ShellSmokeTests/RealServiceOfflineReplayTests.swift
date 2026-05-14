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
