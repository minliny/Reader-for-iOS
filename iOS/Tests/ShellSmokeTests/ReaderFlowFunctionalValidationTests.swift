import XCTest
import Foundation
@testable import ReaderShellValidation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreParser
import ReaderCoreNetwork
import ReaderCoreFacade

@MainActor
final class ReaderFlowFunctionalValidationTests: XCTestCase {
    func testSample004ImportSearchTOCContentFlowPasses() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture, contentStatusCode: 200)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        assertImportState(coordinator, expectedSourceName: fixture.bookSource.bookSourceName)

        await coordinator.search(keyword: "三体")
        assertSearchState(coordinator, expectedItems: fixture.expectedSearch.expected.items)

        let selectedBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(selectedBook)
        assertTOCState(coordinator, expectedChapters: fixture.expectedTOC.expected.chapters, selectedBook: selectedBook)

        let selectedChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(selectedChapter)
        assertContentState(coordinator, expectedContent: fixture.expectedContent.expected.content, selectedChapter: selectedChapter)
    }

    func testSample005ImportSearchTOCContentFlowPasses() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_005")
        let coordinator = makeCoordinator(for: fixture, contentStatusCode: 200)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        assertImportState(coordinator, expectedSourceName: fixture.bookSource.bookSourceName)

        await coordinator.search(keyword: "茶馆")
        assertSearchState(coordinator, expectedItems: fixture.expectedSearch.expected.items)

        let selectedBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(selectedBook)
        assertTOCState(coordinator, expectedChapters: fixture.expectedTOC.expected.chapters, selectedBook: selectedBook)

        let selectedChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(selectedChapter)
        assertContentState(coordinator, expectedContent: fixture.expectedContent.expected.content, selectedChapter: selectedChapter)
    }

    func testContentStageReturnsControlledErrorWhenFixtureResponds404() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture, contentStatusCode: 404)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")

        let selectedBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(selectedBook)

        let selectedChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(selectedChapter)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertEqual(coordinator.selectedChapter, selectedChapter)
        XCTAssertNil(coordinator.contentPage)

        let currentError = try XCTUnwrap(coordinator.currentError)
        XCTAssertEqual(currentError.code, .networkFailed)
        XCTAssertEqual(currentError.failure?.type, .CONTENT_FAILED)
        XCTAssertEqual(currentError.failure?.reason, "error_mapping")
    }
}

private extension ReaderFlowFunctionalValidationTests {
    func makeCoordinator(
        for fixture: FunctionalFixtureSample,
        contentStatusCode: Int
    ) -> ReadingFlowCoordinator {
        let httpClient = FixtureHTTPClient(
            searchURLPrefix: (fixture.bookSource.bookSourceUrl ?? "") + "/search",
            searchRoute: .ok(data: fixture.searchFixtureData),
            routes: [
            fixture.expectedSearch.expected.items[0].detailURL: .ok(data: fixture.tocFixtureData),
            fixture.expectedTOC.expected.chapters[0].chapterURL: FixtureRoute(
                statusCode: contentStatusCode,
                data: fixture.contentFixtureData
            )
        ])
        let coreFacade = ReaderFlowCoreFacade(httpClient: httpClient)

        return ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            searchService: DefaultSearchService(
                facade: coreFacade
            ),
            tocService: DefaultTOCService(
                facade: coreFacade
            ),
            contentService: DefaultContentService(
                facade: coreFacade
            ),
            errorLogger: InMemoryErrorLogger()
        )
    }

    func assertImportState(_ coordinator: ReadingFlowCoordinator, expectedSourceName: String) {
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertNotNil(coordinator.selectedSource)
        XCTAssertEqual(coordinator.selectedSource?.bookSourceName, expectedSourceName)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func assertSearchState(_ coordinator: ReadingFlowCoordinator, expectedItems: [ExpectedSearchItem]) {
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.searchResults.count, expectedItems.count)
        XCTAssertEqual(
            coordinator.searchResults.map { ExpectedSearchItem(title: $0.title, detailURL: $0.detailURL) },
            expectedItems
        )
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func assertTOCState(
        _ coordinator: ReadingFlowCoordinator,
        expectedChapters: [ExpectedTOCChapter],
        selectedBook: SearchResultItem
    ) {
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedBook, selectedBook)
        XCTAssertEqual(coordinator.tocItems.count, expectedChapters.count)
        XCTAssertEqual(
            coordinator.tocItems.map { ExpectedTOCChapter(chapterTitle: $0.chapterTitle, chapterURL: $0.chapterURL, chapterIndex: $0.chapterIndex) },
            expectedChapters
        )
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func assertContentState(
        _ coordinator: ReadingFlowCoordinator,
        expectedContent: String,
        selectedChapter: TOCItem
    ) {
        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedChapter, selectedChapter)
        XCTAssertEqual(coordinator.contentPage?.chapterURL, selectedChapter.chapterURL)
        XCTAssertEqual(coordinator.contentPage?.content, expectedContent)
    }
}

private actor FixtureHTTPClient: HTTPClient {
    private let searchURLPrefix: String
    private let searchRoute: FixtureRoute
    private let routes: [String: FixtureRoute]

    init(
        searchURLPrefix: String,
        searchRoute: FixtureRoute,
        routes: [String: FixtureRoute]
    ) {
        self.searchURLPrefix = searchURLPrefix
        self.searchRoute = searchRoute
        self.routes = routes
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let route: FixtureRoute?
        if request.url.hasPrefix(searchURLPrefix) {
            route = searchRoute
        } else {
            route = routes[request.url]
        }

        guard let route else {
            throw ReaderError.network(
                failureType: .NETWORK_POLICY_MISMATCH,
                stage: "HTTP",
                message: "Missing fixture route for \(request.url)",
                underlyingError: nil
            )
        }

        return HTTPResponse(
            statusCode: route.statusCode,
            headers: ["Content-Type": "text/html; charset=utf-8"],
            data: route.data
        )
    }
}

private struct FixtureRoute {
    let statusCode: Int
    let data: Data

    static func ok(data: Data) -> FixtureRoute {
        FixtureRoute(statusCode: 200, data: data)
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

        let bookSourcePath = root
            .appendingPathComponent("samples")
            .appendingPathComponent("booksources")
            .appendingPathComponent("p0_non_js")
            .appendingPathComponent("\(sampleId).json")
        let searchFixturePath = root
            .appendingPathComponent("samples")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("html")
            .appendingPathComponent("\(sampleId)_search.html")
        let tocFixturePath = root
            .appendingPathComponent("samples")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("html")
            .appendingPathComponent("\(sampleId)_toc.html")
        let contentFixturePath = root
            .appendingPathComponent("samples")
            .appendingPathComponent("fixtures")
            .appendingPathComponent("html")
            .appendingPathComponent("\(sampleId)_content.html")
        let searchExpectedPath = root
            .appendingPathComponent("samples")
            .appendingPathComponent("expected")
            .appendingPathComponent("search")
            .appendingPathComponent("\(sampleId).json")
        let tocExpectedPath = root
            .appendingPathComponent("samples")
            .appendingPathComponent("expected")
            .appendingPathComponent("toc")
            .appendingPathComponent("\(sampleId).json")
        let contentExpectedPath = root
            .appendingPathComponent("samples")
            .appendingPathComponent("expected")
            .appendingPathComponent("content")
            .appendingPathComponent("\(sampleId).json")

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
    let root = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()

    let fileManager = FileManager.default
    if fileManager.fileExists(atPath: root.appendingPathComponent("samples").path) {
        return root
    }

    let readerCoreRoot = root.appendingPathComponent("Reader-Core")
    if fileManager.fileExists(atPath: readerCoreRoot.appendingPathComponent("samples").path) {
        return readerCoreRoot
    }

    return root
}
