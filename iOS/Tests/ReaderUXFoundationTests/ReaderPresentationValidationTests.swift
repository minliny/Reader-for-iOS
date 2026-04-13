import XCTest
import Foundation
@testable import ReaderApp
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreParser
import ReaderCoreNetwork

final class ReaderPresentationValidationTests: XCTestCase {
    
    @MainActor
    func testPresentationSurfacesAreConsistentWithUXState() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)
        
        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook: SearchResultItem = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        
        // Setup multiple chapters
        let chapters = [
            TOCItem(chapterTitle: "Chapter 1", chapterURL: fixture.expectedTOC.expected.chapters[0].chapterURL, chapterIndex: 0)
        ]
        coordinator.tocItems = chapters
        
        let firstChapter = chapters[0]
        await coordinator.selectChapter(firstChapter)
        
        let uxState = ReaderUXFoundationState(coordinator: coordinator, chapter: firstChapter)
        
        XCTAssertEqual(uxState.surfaceKind, .content)
        XCTAssertNotNil(uxState.contentTitle)
        XCTAssertNotNil(uxState.contentBody)
        XCTAssertEqual(uxState.chapterCount, 1)
        XCTAssertEqual(uxState.chapterIndex, 0)
        
        // Error presentation
        coordinator.currentError = ReaderError(code: .networkFailed, message: "Network failed during presentation")
        let errorState = ReaderUXFoundationState(coordinator: coordinator, chapter: nil)
        XCTAssertEqual(errorState.surfaceKind, .error)
        XCTAssertEqual(errorState.errorMessage, "Network failed during presentation")
    }
}

private extension ReaderPresentationValidationTests {
    @MainActor
    func makeCoordinator(for fixture: FunctionalFixtureSample) -> ReadingFlowCoordinator {
        let httpClient = PresentationFixtureHTTPClient(
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

private actor PresentationFixtureHTTPClient: HTTPClient {
    private let searchURLPrefix: String
    private let searchRoute: PresentationFixtureRoute
    private let routes: [String: PresentationFixtureRoute]

    init(
        searchURLPrefix: String,
        searchRoute: PresentationFixtureRoute,
        routes: [String: PresentationFixtureRoute]
    ) {
        self.searchURLPrefix = searchURLPrefix
        self.searchRoute = searchRoute
        self.routes = routes
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let route: PresentationFixtureRoute?
        if request.url.hasPrefix(searchURLPrefix) {
            route = searchRoute
        } else {
            route = routes[request.url]
        }

        guard let route else {
            throw ReaderError(
                code: .networkFailed,
                message: "Missing Presentation fixture route for \(request.url)"
            )
        }

        return HTTPResponse(
            statusCode: route.statusCode,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            data: route.data
        )
    }
}

private struct PresentationFixtureRoute {
    let statusCode: Int
    let data: Data

    static func ok(data: Data) -> PresentationFixtureRoute {
        PresentationFixtureRoute(statusCode: 200, data: data)
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
