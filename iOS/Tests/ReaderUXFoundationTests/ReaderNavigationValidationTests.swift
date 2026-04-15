import XCTest
import Foundation
@testable import ReaderApp
import ReaderShellValidation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreParser
import ReaderCoreNetwork

final class ReaderNavigationValidationTests: XCTestCase {
    
    @MainActor
    func testContentStateProvidesAccurateProgressInformation() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)
        
        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook: SearchResultItem = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        
        // Setup multiple chapters
        let chapters = [
            TOCItem(chapterTitle: "Chapter 1", chapterURL: "url1", chapterIndex: 0),
            TOCItem(chapterTitle: "Chapter 2", chapterURL: fixture.expectedTOC.expected.chapters[0].chapterURL, chapterIndex: 1),
            TOCItem(chapterTitle: "Chapter 3", chapterURL: "url3", chapterIndex: 2),
            TOCItem(chapterTitle: "Chapter 4", chapterURL: "url4", chapterIndex: 3)
        ]
        coordinator.tocItems = chapters
        
        let secondChapter = chapters[1]
        await coordinator.selectChapter(secondChapter)
        
        let uxState = ReaderUXFoundationState(coordinator: coordinator, chapter: secondChapter)
        
        XCTAssertEqual(uxState.chapterCount, 4)
        XCTAssertEqual(uxState.chapterIndex, 1)
        XCTAssertEqual(uxState.progressPercentage, 2.0 / 4.0)
    }

    @MainActor
    func testNavigationAwarenessWhenNoTOCIsAvailable() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)
        
        await coordinator.importBookSource(from: fixture.bookSourceData)
        
        let chapter = TOCItem(chapterTitle: "Unknown", chapterURL: "unknown", chapterIndex: 0)
        let uxState = ReaderUXFoundationState(coordinator: coordinator, chapter: chapter)
        
        XCTAssertEqual(uxState.chapterCount, 0)
        XCTAssertNil(uxState.chapterIndex)
        XCTAssertNil(uxState.progressPercentage)
    }
}

private extension ReaderNavigationValidationTests {
    @MainActor
    func makeCoordinator(for fixture: FunctionalFixtureSample) -> ReadingFlowCoordinator {
        let httpClient = NavigationFixtureHTTPClient(
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

private actor NavigationFixtureHTTPClient: HTTPClient {
    private let searchURLPrefix: String
    private let searchRoute: NavigationFixtureRoute
    private let routes: [String: NavigationFixtureRoute]

    init(
        searchURLPrefix: String,
        searchRoute: NavigationFixtureRoute,
        routes: [String: NavigationFixtureRoute]
    ) {
        self.searchURLPrefix = searchURLPrefix
        self.searchRoute = searchRoute
        self.routes = routes
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let route: NavigationFixtureRoute?
        if request.url.hasPrefix(searchURLPrefix) {
            route = searchRoute
        } else {
            route = routes[request.url]
        }

        guard let route else {
            throw ReaderError(
                code: .networkFailed,
                message: "Missing Navigation fixture route for \(request.url)"
            )
        }

        return HTTPResponse(
            statusCode: route.statusCode,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            data: route.data
        )
    }
}

private struct NavigationFixtureRoute {
    let statusCode: Int
    let data: Data

    static func ok(data: Data) -> NavigationFixtureRoute {
        NavigationFixtureRoute(statusCode: 200, data: data)
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
    // Post-split: samples live in the sibling Reader-Core repository.
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()  // ReaderUXFoundationTests/
        .deletingLastPathComponent()  // Tests/
        .deletingLastPathComponent()  // iOS/
        .deletingLastPathComponent()  // Reader-iOS repo root
        .deletingLastPathComponent()  // parent directory
        .appendingPathComponent("Reader-Core")
}
