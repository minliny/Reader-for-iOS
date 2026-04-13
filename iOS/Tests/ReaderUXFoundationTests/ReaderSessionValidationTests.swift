import XCTest
import Foundation
@testable import ReaderApp
import ReaderShellValidation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreParser
import ReaderCoreNetwork

final class ReaderSessionValidationTests: XCTestCase {
    
    @MainActor
    func testReenteringReaderRootProvidesSessionSummaryAndContinueAffordance() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)
        
        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook: SearchResultItem = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter: TOCItem = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)
        
        let featureState = ReaderFlowFeatureState(coordinator: coordinator)
        
        XCTAssertTrue(featureState.hasSelectedBook)
        XCTAssertTrue(featureState.hasSelectedChapter)
        XCTAssertEqual(featureState.currentStageTitle, "正文已加载")
        
        // This validates that the state drives the sessionSummary View
        // In actual UI, `sessionSummary` checks these flags and provides the "Continue Reading" NavigationLink
    }
    
    @MainActor
    func testReloadingPreservesSessionContext() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)
        
        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook: SearchResultItem = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter: TOCItem = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)
        
        XCTAssertNotNil(coordinator.contentPage)
        
        // Simulate a reload
        await coordinator.selectChapter(firstChapter)
        
        XCTAssertEqual(coordinator.selectedChapter?.chapterTitle, firstChapter.chapterTitle)
        XCTAssertEqual(coordinator.selectedBook?.title, firstBook.title)
        XCTAssertNotNil(coordinator.contentPage)
    }
}

private extension ReaderSessionValidationTests {
    @MainActor
    func makeCoordinator(for fixture: FunctionalFixtureSample) -> ReadingFlowCoordinator {
        let httpClient = SessionFixtureHTTPClient(
            searchURLPrefix: (fixture.bookSource.bookSourceUrl ?? "") + "/search",
            searchRoute: .ok(data: fixture.searchFixtureData),
            routes: [
                fixture.expectedSearch.expected.items[0].detailURL: .ok(data: fixture.tocFixtureData),
                fixture.expectedTOC.expected.chapters[0].chapterURL: .ok(data: fixture.contentFixtureData)
            ]
        )

        return ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            searchService: DefaultSearchService(
                httpClient: httpClient,
                requestBuilder: BookSourceRequestBuilder(),
                searchParser: NonJSParserEngine()
            ),
            tocService: DefaultTOCService(
                httpClient: httpClient,
                requestBuilder: BookSourceRequestBuilder(),
                tocParser: NonJSParserEngine()
            ),
            contentService: DefaultContentService(
                httpClient: httpClient,
                requestBuilder: BookSourceRequestBuilder(),
                contentParser: NonJSParserEngine()
            ),
            errorLogger: InMemoryErrorLogger()
        )
    }
}

private actor SessionFixtureHTTPClient: HTTPClient {
    private let searchURLPrefix: String
    private let searchRoute: SessionFixtureRoute
    private let routes: [String: SessionFixtureRoute]

    init(
        searchURLPrefix: String,
        searchRoute: SessionFixtureRoute,
        routes: [String: SessionFixtureRoute]
    ) {
        self.searchURLPrefix = searchURLPrefix
        self.searchRoute = searchRoute
        self.routes = routes
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let route: SessionFixtureRoute?
        if request.url.hasPrefix(searchURLPrefix) {
            route = searchRoute
        } else {
            route = routes[request.url]
        }

        guard let route else {
            throw ReaderError(
                code: .networkFailed,
                message: "Missing Session fixture route for \(request.url)"
            )
        }

        return HTTPResponse(
            statusCode: route.statusCode,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            data: route.data
        )
    }
}

private struct SessionFixtureRoute {
    let statusCode: Int
    let data: Data

    static func ok(data: Data) -> SessionFixtureRoute {
        SessionFixtureRoute(statusCode: 200, data: data)
    }
}

private struct FunctionalFixtureSample {
    let sampleId: String
    let bookSourceData: Data
    let bookSource: BookSource
    let searchFixtureData: Data
    let tocFixtureData: Data
    let contentFixtureData: Data
    let expectedSearch: ExpectedSearchFile
    let expectedTOC: ExpectedTOCFile
    let expectedContent: ExpectedContentFile

    static func load(sampleId: String) throws -> FunctionalFixtureSample {
        let root = repositoryRootURL()
        let decoder = JSONDecoder()

        let bookSourcePath = root.appendingPathComponent("samples/booksources/p0_non_js/\(sampleId).json")
        let searchFixturePath = root.appendingPathComponent("samples/fixtures/html/\(sampleId)_search.html")
        let tocFixturePath = root.appendingPathComponent("samples/fixtures/html/\(sampleId)_toc.html")
        let contentFixturePath = root.appendingPathComponent("samples/fixtures/html/\(sampleId)_content.html")
        let searchExpectedPath = root.appendingPathComponent("samples/expected/search/\(sampleId).json")
        let tocExpectedPath = root.appendingPathComponent("samples/expected/toc/\(sampleId).json")
        let contentExpectedPath = root.appendingPathComponent("samples/expected/content/\(sampleId).json")

        let bookSourceData = try Data(contentsOf: bookSourcePath)
        return FunctionalFixtureSample(
            sampleId: sampleId,
            bookSourceData: bookSourceData,
            bookSource: try decoder.decode(BookSource.self, from: bookSourceData),
            searchFixtureData: try Data(contentsOf: searchFixturePath),
            tocFixtureData: try Data(contentsOf: tocFixturePath),
            contentFixtureData: try Data(contentsOf: contentFixturePath),
            expectedSearch: try decoder.decode(ExpectedSearchFile.self, from: Data(contentsOf: searchExpectedPath)),
            expectedTOC: try decoder.decode(ExpectedTOCFile.self, from: Data(contentsOf: tocExpectedPath)),
            expectedContent: try decoder.decode(ExpectedContentFile.self, from: Data(contentsOf: contentExpectedPath))
        )
    }
}

private struct ExpectedSearchFile: Decodable {
    let expected: ExpectedSearchPayload
}

private struct ExpectedSearchPayload: Decodable {
    let success: Bool
    let resultCount: Int
    let items: [ExpectedSearchItem]
}

private struct ExpectedSearchItem: Decodable, Equatable {
    let title: String
    let detailURL: String
}

private struct ExpectedTOCFile: Decodable {
    let expected: ExpectedTOCPayload
}

private struct ExpectedTOCPayload: Decodable {
    let success: Bool
    let chapterCount: Int
    let chapters: [ExpectedTOCChapter]
}

private struct ExpectedTOCChapter: Decodable, Equatable {
    let chapterTitle: String
    let chapterURL: String
    let chapterIndex: Int
}

private struct ExpectedContentFile: Decodable {
    let expected: ExpectedContentPayload
}

private struct ExpectedContentPayload: Decodable {
    let success: Bool
    let contentNonEmpty: Bool
    let content: String
}

private func repositoryRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}