import XCTest
@testable import ReaderApp

/// ReaderCore facade 边界测试 — 验证 UI 不引用 parser internals，默认 mock，no network
@MainActor
final class ReaderCoreFacadeBoundaryTests: XCTestCase {

    // MARK: - Provider defaults

    func testProviderDefaultsToMockMode() {
        let provider = ReaderCoreServiceProvider.shared
        XCTAssertEqual(provider.currentMode, .mock, "默认模式应为 mock，不能默认启用 real service")
    }

    func testProviderMockIsAvailableWithoutConfiguration() {
        let provider = ReaderCoreServiceProvider.shared
        // mock 模式无需调用 configureRealMode
        XCTAssertEqual(provider.currentMode, .mock)
    }

    func testRealModeRequiresExplicitConfiguration() {
        let provider = ReaderCoreServiceProvider.shared
        // real 模式不应自动启用
        XCTAssertFalse(provider.isRealModeAvailable, "Real mode 不应在未配置时可用")
    }

    // MARK: - Mock flow maintains provider boundary

    func testSearchUsesMockProvider() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.searchBooks(keyword: "test", page: 1, source: nil)
        if case .loaded(let results) = state {
            XCTAssertFalse(results.isEmpty)
        } else {
            XCTFail("Mock search should return results")
        }
        provider.resetMock()
    }

    func testDetailUsesMockProvider() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.getBookDetail(bookURL: "https://example.com/book/1")
        if case .loaded(let detail) = state {
            XCTAssertFalse(detail.title.isEmpty)
        } else {
            XCTFail("Mock detail should return data")
        }
        provider.resetMock()
    }

    func testTOCUsesMockProvider() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.getChapterList(bookURL: "https://example.com/book/1")
        if case .loaded(let chapters) = state {
            XCTAssertEqual(chapters.count, 5)
        } else {
            XCTFail("Mock TOC should return 5 chapters")
        }
        provider.resetMock()
    }

    func testContentUsesMockProvider() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.getChapterContent(chapterURL: "https://example.com/book/1/chapter/1")
        if case .loaded(let page) = state {
            XCTAssertTrue(page.content.contains("韩立"))
        } else {
            XCTFail("Mock content should return page")
        }
        provider.resetMock()
    }

    // MARK: - BookSource uses mock provider

    func testBookSourceValidationUsesMockProvider() async {
        let provider = ReaderCoreServiceProvider.shared
        let json = """
        {"bookSourceName": "Test", "bookSourceUrl": "https://test.com"}
        """
        let data = json.data(using: .utf8)!
        let state = await provider.validateBookSource(from: data)
        if case .loaded(let source) = state {
            XCTAssertEqual(source.bookSourceName, "Test")
        } else {
            XCTFail("Mock validation should return decoded source")
        }
    }

    // MARK: - No real network

    func testMockFlowDoesNotRequireNetwork() async {
        // Mock provider 应在无网络环境下仍然正常工作
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let content = await provider.getChapterContent(chapterURL: "any-url")
        if case .loaded = content {
            // pass — mock works without network
        } else {
            XCTFail("Mock content should load without network")
        }
        provider.resetMock()
    }

    // MARK: - Scenario coverage

    func testMockScenarioSuccess() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)

        let state = await provider.searchBooks(keyword: "x", page: 1)
        guard case .loaded(let results) = state else {
            XCTFail("success scenario should return .loaded")
            return
        }
        XCTAssertEqual(results.count, 3)
        provider.resetMock()
    }

    func testMockScenarioEmpty() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.empty)

        let state = await provider.searchBooks(keyword: "x", page: 1)
        guard case .empty = state else {
            XCTFail("empty scenario should return .empty, got \(state)")
            return
        }
        provider.resetMock()
    }

    func testMockScenarioFailure() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.networkFailure)

        let state = await provider.searchBooks(keyword: "x", page: 1)
        guard case .failed = state else {
            XCTFail("networkFailure scenario should return .failed, got \(state)")
            return
        }
        provider.resetMock()
    }

    // MARK: - Debug-only entries

    func testPrototypeGalleryExists() {
        let _ = PrototypeGalleryView()
        // 编译时确认：PrototypeGalleryView 不 crash
    }

    func testMineTabViewExists() {
        let _ = MineTabView()
        // 编译时确认：MineTabView 可初始化
    }

    // MARK: - Provider reset after tests

    func testProviderResetsAfterScenarioChange() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.empty)
        provider.resetMock()

        let state = await provider.searchBooks(keyword: "x", page: 1)
        // After reset, should be back to default success → loaded
        if case .loaded(let results) = state {
            XCTAssertEqual(results.count, 3)
        } else {
            XCTFail("Expected .loaded after resetMock, got \(state)")
        }
    }
}
