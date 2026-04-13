import XCTest
import Foundation
@testable import ReaderApp
import ReaderShellValidation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreParser
import ReaderCoreNetwork

final class ReaderUXFoundationStateTests: XCTestCase {
    @MainActor
    func testLoadingSurfaceIsExposedForContentStage() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        coordinator.isLoading = true

        let state = ReaderUXFoundationState(coordinator: coordinator, chapter: firstChapter)
        XCTAssertEqual(state.surfaceKind, .loading)
        XCTAssertEqual(state.chapterTitle, firstChapter.chapterTitle)
        XCTAssertEqual(state.stageTitle, "正文加载中")
    }

    @MainActor
    func testEmptySurfaceIsExposedBeforeContentArrives() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)

        let state = ReaderUXFoundationState(coordinator: coordinator, chapter: firstChapter)
        XCTAssertEqual(state.surfaceKind, .empty)
        XCTAssertEqual(state.bookTitle, firstBook.title)
        XCTAssertEqual(state.chapterTitle, firstChapter.chapterTitle)
    }

    @MainActor
    func testErrorSurfaceDoesNotMixWithLoadedContent() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)

        coordinator.contentPage = ContentPage(
            title: "旧正文",
            content: "旧内容",
            chapterURL: firstChapter.chapterURL
        )
        coordinator.currentError = ReaderError(code: .networkFailed, message: "正文加载失败")

        let state = ReaderUXFoundationState(coordinator: coordinator, chapter: firstChapter)
        XCTAssertEqual(state.surfaceKind, .error)
        XCTAssertNil(state.contentBody)
        XCTAssertEqual(state.errorMessage, "正文加载失败")
    }

    @MainActor
    func testContentSurfaceCarriesChapterContextAndReadableBody() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        let state = ReaderUXFoundationState(coordinator: coordinator, chapter: firstChapter)
        XCTAssertEqual(state.surfaceKind, .content)
        XCTAssertEqual(state.bookTitle, firstBook.title)
        XCTAssertEqual(state.chapterTitle, firstChapter.chapterTitle)
        XCTAssertEqual(state.contentTitle, coordinator.contentPage?.title)
        XCTAssertEqual(state.contentBody, fixture.expectedContent.expected.content)
    }

    @MainActor
    func testFeatureStateStillDrivesStageFeedbackAcrossSearchTOCAndContent() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)

        let initial = ReaderFlowFeatureState(coordinator: coordinator)
        XCTAssertEqual(initial.currentStageTitle, "等待导入书源")

        await coordinator.importBookSource(from: fixture.bookSourceData)
        let imported = ReaderFlowFeatureState(coordinator: coordinator)
        XCTAssertEqual(imported.currentStageTitle, "可开始搜索")

        await coordinator.search(keyword: "三体")
        let searched = ReaderFlowFeatureState(coordinator: coordinator)
        XCTAssertEqual(searched.currentStageTitle, "搜索结果已就绪")

        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let toced = ReaderFlowFeatureState(coordinator: coordinator)
        XCTAssertEqual(toced.currentStageTitle, "目录已加载")

        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)
        let contentLoaded = ReaderFlowFeatureState(coordinator: coordinator)
        XCTAssertEqual(contentLoaded.currentStageTitle, "正文已加载")
    }
}

private extension ReaderUXFoundationStateTests {
    @MainActor
    func makeCoordinator(for fixture: FunctionalFixtureSample) -> ReadingFlowCoordinator {
        let httpClient = UXFixtureHTTPClient(
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

private actor UXFixtureHTTPClient: HTTPClient {
    private let searchURLPrefix: String
    private let searchRoute: UXFixtureRoute
    private let routes: [String: UXFixtureRoute]

    init(
        searchURLPrefix: String,
        searchRoute: UXFixtureRoute,
        routes: [String: UXFixtureRoute]
    ) {
        self.searchURLPrefix = searchURLPrefix
        self.searchRoute = searchRoute
        self.routes = routes
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let route: UXFixtureRoute?
        if request.url.hasPrefix(searchURLPrefix) {
            route = searchRoute
        } else {
            route = routes[request.url]
        }

        guard let route else {
            throw ReaderError.network(
                failureType: .NETWORK_POLICY_MISMATCH,
                stage: "HTTP",
                message: "Missing UX fixture route for \(request.url)",
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

private struct UXFixtureRoute {
    let statusCode: Int
    let data: Data

    static func ok(data: Data) -> UXFixtureRoute {
        UXFixtureRoute(statusCode: 200, data: data)
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
