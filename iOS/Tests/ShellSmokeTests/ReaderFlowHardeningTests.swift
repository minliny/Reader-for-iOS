import XCTest
import Foundation
@testable import ReaderShellValidation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderCoreParser
import ReaderCoreNetwork
import ReaderCoreFacade

@MainActor
final class ReaderFlowHardeningTests: XCTestCase {
    func testRepeatedSearchClearsStaleBookTOCChapterAndContentState() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        XCTAssertNotNil(coordinator.selectedBook)
        XCTAssertNotNil(coordinator.selectedChapter)
        XCTAssertNotNil(coordinator.contentPage)

        await coordinator.search(keyword: "斗破苍穹")

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertEqual(coordinator.searchResults.map(\.title), fixture.expectedSearch.expected.items.map(\.title))
    }

    func testSwitchingBooksReplacesTOCAndClearsSelectedChapterAndContent() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(for: fixture)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")

        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        let secondBook = try XCTUnwrap(coordinator.searchResults.dropFirst().first)

        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        await coordinator.selectBook(secondBook)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedBook, secondBook)
        XCTAssertEqual(coordinator.tocItems.map(\.chapterTitle), secondBookTOCTitles)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func testSwitchingChaptersReplacesContentAndClearsError() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(
            for: fixture,
            customRoutes: [
                fixture.expectedTOC.expected.chapters[1].chapterURL: HardeningFixtureRoute.ok(
                    data: Data(#"<div id="story">第二章正文替换成功。</div>"#.utf8)
                )
            ]
        )

        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)

        let chapterA = try XCTUnwrap(coordinator.tocItems.first)
        let chapterB = try XCTUnwrap(coordinator.tocItems.dropFirst().first)

        await coordinator.selectChapter(chapterA)
        let firstContent = coordinator.contentPage

        coordinator.currentError = ReaderError(code: .unknown, message: "stale")
        await coordinator.selectChapter(chapterB)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedChapter, chapterB)
        XCTAssertNotEqual(firstContent?.chapterURL, coordinator.contentPage?.chapterURL)
        XCTAssertEqual(coordinator.contentPage?.content, "第二章正文替换成功。")
    }

    func testContentFailureCanRecoverBySelectingAnotherChapter() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let failingChapterURL = fixture.expectedTOC.expected.chapters[0].chapterURL
        let recoveryChapterURL = fixture.expectedTOC.expected.chapters[1].chapterURL
        let coordinator = makeCoordinator(
            for: fixture,
            customRoutes: [
                failingChapterURL: HardeningFixtureRoute(statusCode: 404, data: fixture.contentFixtureData),
                recoveryChapterURL: HardeningFixtureRoute.ok(
                    data: Data(#"<div id="story">恢复后的章节正文。</div>"#.utf8)
                )
            ]
        )

        await coordinator.importBookSource(from: fixture.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)

        let failedChapter = try XCTUnwrap(coordinator.tocItems.first)
        let recoveredChapter = try XCTUnwrap(coordinator.tocItems.dropFirst().first)

        await coordinator.selectChapter(failedChapter)
        XCTAssertNotNil(coordinator.currentError)
        XCTAssertNil(coordinator.contentPage)

        await coordinator.selectChapter(recoveredChapter)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedChapter, recoveredChapter)
        XCTAssertEqual(coordinator.contentPage?.content, "恢复后的章节正文。")
    }

    func testImportingNewSourceReplacesSelectedSourceAndClearsReaderState() async throws {
        let sourceA = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let sourceB = try FunctionalFixtureSample.load(sampleId: "sample_005")
        let coordinator = makeCoordinator(for: sourceA)

        await coordinator.importBookSource(from: sourceA.bookSourceData)
        await coordinator.search(keyword: "三体")
        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)

        await coordinator.importBookSource(from: sourceB.bookSourceData)

        XCTAssertFalse(coordinator.isLoading)
        XCTAssertNil(coordinator.currentError)
        XCTAssertEqual(coordinator.selectedSource?.bookSourceName, sourceB.bookSource.bookSourceName)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    func testCoordinatorStateReflectsEmptyLoadedAndErrorTransitions() async throws {
        let fixture = try FunctionalFixtureSample.load(sampleId: "sample_004")
        let coordinator = makeCoordinator(
            for: fixture,
            customRoutes: [
                fixture.expectedTOC.expected.chapters[0].chapterURL: HardeningFixtureRoute(statusCode: 404, data: fixture.contentFixtureData)
            ]
        )

        XCTAssertNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)

        await coordinator.importBookSource(from: fixture.bookSourceData)
        XCTAssertNotNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.currentError)

        await coordinator.search(keyword: "三体")
        XCTAssertFalse(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.currentError)

        let firstBook = try XCTUnwrap(coordinator.searchResults.first)
        await coordinator.selectBook(firstBook)
        XCTAssertEqual(coordinator.selectedBook, firstBook)
        XCTAssertFalse(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.currentError)

        let firstChapter = try XCTUnwrap(coordinator.tocItems.first)
        await coordinator.selectChapter(firstChapter)
        XCTAssertEqual(coordinator.selectedChapter, firstChapter)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNotNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isLoading)
    }
}

private extension ReaderFlowHardeningTests {
    var secondBookTOCTitles: [String] {
        ["第二册 第一章", "第二册 第二章"]
    }

    func makeCoordinator(
        for fixture: FunctionalFixtureSample,
        customRoutes: [String: HardeningFixtureRoute] = [:]
    ) -> ReadingFlowCoordinator {
        var routes: [String: HardeningFixtureRoute] = [
            fixture.expectedSearch.expected.items[0].detailURL: .ok(data: fixture.tocFixtureData),
            fixture.expectedTOC.expected.chapters[0].chapterURL: .ok(data: fixture.contentFixtureData)
        ]

        if fixture.expectedSearch.expected.items.count > 1 {
            routes[fixture.expectedSearch.expected.items[1].detailURL] = .ok(
                data: Data(secondBookTOCHTML.utf8)
            )
        }

        if fixture.expectedTOC.expected.chapters.count > 1 {
            routes[fixture.expectedTOC.expected.chapters[1].chapterURL] = .ok(
                data: Data(#"<div id="story">第二章正文默认成功。</div>"#.utf8)
            )
        }

        for (key, value) in customRoutes {
            routes[key] = value
        }

        let httpClient = HardeningFixtureHTTPClient(
            searchURLPrefix: (fixture.bookSource.bookSourceUrl ?? "") + "/search",
            searchRoute: .ok(data: fixture.searchFixtureData),
            routes: routes
        )
        let coreFacade = ReaderFlowCoreFacade(httpClient: httpClient)

        return ReadingFlowCoordinator(
            bookSourceRepository: InMemoryBookSourceRepository(),
            bookSourceDecoder: DefaultBookSourceDecoder(),
            readingFlowFacade: coreFacade,
            errorLogger: InMemoryErrorLogger()
        )
    }

    var secondBookTOCHTML: String {
        """
        <!DOCTYPE html>
        <html>
        <body>
        <div class="ep">第二册 第一章|http://fixture4.local/ch/second-1.html</div>
        <div class="ep">第二册 第二章|http://fixture4.local/ch/second-2.html</div>
        </body>
        </html>
        """
    }
}

private actor HardeningFixtureHTTPClient: HTTPClient {
    private let searchURLPrefix: String
    private let searchRoute: HardeningFixtureRoute
    private let routes: [String: HardeningFixtureRoute]

    init(
        searchURLPrefix: String,
        searchRoute: HardeningFixtureRoute,
        routes: [String: HardeningFixtureRoute]
    ) {
        self.searchURLPrefix = searchURLPrefix
        self.searchRoute = searchRoute
        self.routes = routes
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let route: HardeningFixtureRoute?
        if request.url.hasPrefix(searchURLPrefix) {
            route = searchRoute
        } else {
            route = routes[request.url]
        }

        guard let route else {
            throw ReaderError.network(
                failureType: .NETWORK_POLICY_MISMATCH,
                stage: "HTTP",
                message: "Missing hardening fixture route for \(request.url)",
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

private struct HardeningFixtureRoute {
    let statusCode: Int
    let data: Data

    static func ok(data: Data) -> HardeningFixtureRoute {
        HardeningFixtureRoute(statusCode: 200, data: data)
    }
}

private struct FunctionalFixtureSample {
    let sampleId: String
    let bookSourceData: Data
    let bookSource: BookSource
    let searchFixtureData: Data
    let tocFixtureData: Data
    let contentFixtureData: Data
    let expectedSearch: HardeningExpectedSearchFile
    let expectedTOC: HardeningExpectedTOCFile
    let expectedContent: HardeningExpectedContentFile

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
            expectedSearch: try decoder.decode(HardeningExpectedSearchFile.self, from: Data(contentsOf: searchExpectedPath)),
            expectedTOC: try decoder.decode(HardeningExpectedTOCFile.self, from: Data(contentsOf: tocExpectedPath)),
            expectedContent: try decoder.decode(HardeningExpectedContentFile.self, from: Data(contentsOf: contentExpectedPath))
        )
    }
}

private struct HardeningExpectedSearchFile: Decodable {
    let expected: HardeningExpectedSearchPayload
}

private struct HardeningExpectedSearchPayload: Decodable {
    let success: Bool
    let resultCount: Int
    let items: [HardeningExpectedSearchItem]
}

private struct HardeningExpectedSearchItem: Decodable, Equatable {
    let title: String
    let detailURL: String
}

private struct HardeningExpectedTOCFile: Decodable {
    let expected: HardeningExpectedTOCPayload
}

private struct HardeningExpectedTOCPayload: Decodable {
    let success: Bool
    let chapterCount: Int
    let chapters: [HardeningExpectedTOCChapter]
}

private struct HardeningExpectedTOCChapter: Decodable, Equatable {
    let chapterTitle: String
    let chapterURL: String
    let chapterIndex: Int
}

private struct HardeningExpectedContentFile: Decodable {
    let expected: HardeningExpectedContentPayload
}

private struct HardeningExpectedContentPayload: Decodable {
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
