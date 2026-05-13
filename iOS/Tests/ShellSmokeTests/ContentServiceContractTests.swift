import Foundation
import XCTest
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderShellValidation

final class ContentServiceContractTests: XCTestCase {
    
    private var mockProvider: ReaderCoreServiceProvider!
    private var placeholderService: PlaceholderContentService!
    private var mockService: MockContentService!
    private let testSource = BookSource(
        id: "test-source",
        bookSourceName: "Test Source",
        bookSourceUrl: "https://example.com"
    )
    private let testChapterURL = "https://example.com/book/1/chapter/1"
    
    override func setUp() {
        super.setUp()
        mockProvider = ReaderCoreServiceProvider.shared
        placeholderService = PlaceholderContentService()
        mockService = MockContentService(provider: mockProvider)
    }
    
    override func tearDown() {
        mockProvider.setMode(.mock)
        mockProvider.resetMock()
        super.tearDown()
    }
    
    // MARK: - Mock Content Service Tests
    
    func testMockContentReturnsResultsOnSuccess() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let page = try await mockService.fetchContent(source: testSource, chapterURL: testChapterURL)
        
        XCTAssertFalse(page.title.isEmpty)
        XCTAssertFalse(page.content.isEmpty)
        XCTAssertEqual(page.chapterURL, testChapterURL)
    }
    
    func testMockContentThrowsOnEmptyScenario() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.empty)
        
        do {
            _ = try await mockService.fetchContent(source: testSource, chapterURL: testChapterURL)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .notFound)
        }
    }
    
    func testMockContentThrowsOnUnsupported() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.unsupported(reason: "Feature not supported"))
        
        do {
            _ = try await mockService.fetchContent(source: testSource, chapterURL: testChapterURL)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .unsupported)
        }
    }
    
    func testMockContentThrowsOnNetworkFailure() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.networkFailure)
        
        do {
            _ = try await mockService.fetchContent(source: testSource, chapterURL: testChapterURL)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .network)
        }
    }
    
    func testMockContentThrowsOnParserFailure() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.parserFailure)
        
        do {
            _ = try await mockService.fetchContent(source: testSource, chapterURL: testChapterURL)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .parser)
        }
    }
    
    func testMockContentThrowsOnLoginRequired() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.loginRequired)
        
        do {
            _ = try await mockService.fetchContent(source: testSource, chapterURL: testChapterURL)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .loginRequired)
        }
    }
    
    // MARK: - Placeholder Content Service Tests
    
    func testPlaceholderContentThrowsRealCoreNotAvailable() async throws {
        do {
            _ = try await placeholderService.fetchContent(source: testSource, chapterURL: testChapterURL)
            XCTFail("Expected error to be thrown")
        } catch PlaceholderServiceError.realCoreNotAvailable {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testPlaceholderContentDoesNotReturnMockResults() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        do {
            _ = try await placeholderService.fetchContent(source: testSource, chapterURL: testChapterURL)
            XCTFail("Expected PlaceholderServiceError to be thrown")
        } catch PlaceholderServiceError.realCoreNotAvailable {
            // Expected - Placeholder does not use mock
        }
    }
    
    // MARK: - ReaderCoreServiceProvider Mode Tests
    
    func testProviderMockModeDelegatesToMockService() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let state = await mockProvider.getChapterContent(chapterURL: testChapterURL)
        
        switch state {
        case .loaded(let page):
            XCTAssertFalse(page.content.isEmpty)
        default:
            XCTFail("Expected .loaded state, got \(state)")
        }
    }
    
    func testProviderRealModeReturnsUnsupported() async throws {
        mockProvider.setMode(.real)
        mockProvider.setMockScenario(.success)
        
        let state = await mockProvider.getChapterContent(chapterURL: testChapterURL)
        
        switch state {
        case .unsupported(let reason):
            XCTAssertTrue(reason.contains("not available"))
        default:
            XCTFail("Expected .unsupported state, got \(state)")
        }
    }
    
    func testProviderRealModeDoesNotReturnMockResults() async throws {
        mockProvider.setMockScenario(.success)
        mockProvider.setMode(.real)
        
        let state = await mockProvider.getChapterContent(chapterURL: testChapterURL)
        
        switch state {
        case .loaded:
            XCTFail("Real mode should NOT return mock results")
        case .unsupported:
            // Expected
            break
        default:
            XCTFail("Expected .unsupported state")
        }
    }
    
    // MARK: - Service Contract Tests
    
    func testContentServiceInputRequiresBookSource() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        _ = try await mockService.fetchContent(source: testSource, chapterURL: testChapterURL)
    }
    
    func testContentServiceInputRequiresChapterURL() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        _ = try await mockService.fetchContent(source: testSource, chapterURL: "")
    }
    
    func testContentServiceReturnsContentPage() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let page = try await mockService.fetchContent(source: testSource, chapterURL: testChapterURL)
        
        XCTAssertNotNil(page)
        XCTAssertFalse(page.title.isEmpty)
        XCTAssertFalse(page.content.isEmpty)
    }
    
    // MARK: - State Transition Tests
    
    func testContentStateFromIdleToSuccess() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let state = await mockProvider.getChapterContent(chapterURL: testChapterURL)
        
        switch state {
        case .loaded:
            break
        default:
            XCTFail("Expected .loaded state")
        }
    }
    
    func testContentStateFromIdleToFailed() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.networkFailure)
        
        let state = await mockProvider.getChapterContent(chapterURL: testChapterURL)
        
        switch state {
        case .failed:
            break
        default:
            XCTFail("Expected .failed state")
        }
    }
    
    func testContentStateFromIdleToUnsupported() async throws {
        mockProvider.setMode(.real)
        
        let state = await mockProvider.getChapterContent(chapterURL: testChapterURL)
        
        switch state {
        case .unsupported:
            break
        default:
            XCTFail("Expected .unsupported state")
        }
    }
    
    func testContentStateFromIdleToPartial() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.partial(warning: "Content may be incomplete"))
        
        let state = await mockProvider.getChapterContent(chapterURL: testChapterURL)
        
        switch state {
        case .partial(let page, let warning):
            XCTAssertFalse(page.content.isEmpty)
            XCTAssertTrue(warning.contains("incomplete"))
        default:
            XCTFail("Expected .partial state")
        }
    }
}

// MARK: - ReadingFlowCoordinator Content Tests

final class ReadingFlowCoordinatorContentTests: XCTestCase {
    
    private var coordinator: ReadingFlowCoordinator!
    private let testSource = BookSource(
        id: "test-source",
        bookSourceName: "Test Source",
        bookSourceUrl: "https://example.com"
    )
    private let testChapter = TOCItem(
        chapterTitle: "Test Chapter",
        chapterURL: "https://example.com/book/1/chapter/1",
        chapterIndex: 0
    )
    
    override func setUp() {
        super.setUp()
        coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        coordinator.selectedSource = testSource
        coordinator.tocItems = [testChapter]
    }
    
    override func tearDown() {
        coordinator = nil
        super.tearDown()
    }
    
    func testSelectChapterUpdatesSelectedChapter() async throws {
        await coordinator.selectChapter(testChapter)
        
        XCTAssertEqual(coordinator.selectedChapter?.chapterURL, testChapter.chapterURL)
    }
    
    func testSelectChapterUpdatesContentPage() async throws {
        await coordinator.selectChapter(testChapter)
        
        XCTAssertNotNil(coordinator.contentPage)
        XCTAssertFalse(coordinator.contentPage?.content.isEmpty ?? true)
    }
    
    func testSelectChapterSetsLoadingState() async throws {
        let expectation = XCTestExpectation(description: "Loading state changes")
        
        Task {
            await coordinator.selectChapter(testChapter)
            expectation.fulfill()
        }
        
        // Check loading state during execution
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            XCTAssertTrue(self.coordinator.isLoading)
        }
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertFalse(coordinator.isLoading)
    }
    
    func testSelectChapterClearsPreviousError() async throws {
        coordinator.currentError = ReaderError(code: .network, message: "Test error")
        
        await coordinator.selectChapter(testChapter)
        
        XCTAssertNil(coordinator.currentError)
    }
    
    func testSelectChapterClearsPreviousContent() async throws {
        coordinator.contentPage = ContentPage(
            title: "Old",
            content: "Old content",
            chapterURL: "old-url",
            nextChapterURL: nil
        )
        
        await coordinator.selectChapter(testChapter)
        
        XCTAssertNotNil(coordinator.contentPage)
        XCTAssertEqual(coordinator.contentPage?.chapterURL, testChapter.chapterURL)
    }
    
    func testSelectChapterWithNoSourceDoesNothing() async throws {
        coordinator.selectedSource = nil
        
        await coordinator.selectChapter(testChapter)
        
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.selectedChapter)
    }
    
    // MARK: - Chapter Navigation Tests
    
    func testPreviousChapterReturnsNilForFirstChapter() async throws {
        coordinator.tocItems = [testChapter]
        
        let previous = coordinator.tocItems.firstIndex(where: { $0.chapterURL == testChapter.chapterURL }).flatMap { index in
            index > 0 ? coordinator.tocItems[index - 1] : nil
        }
        
        XCTAssertNil(previous)
    }
    
    func testNextChapterReturnsNilForLastChapter() async throws {
        coordinator.tocItems = [testChapter]
        
        let next = coordinator.tocItems.firstIndex(where: { $0.chapterURL == testChapter.chapterURL }).flatMap { index in
            index < coordinator.tocItems.count - 1 ? coordinator.tocItems[index + 1] : nil
        }
        
        XCTAssertNil(next)
    }
    
    func testNextChapterReturnsNextForMiddleChapter() async throws {
        let chapter1 = TOCItem(chapterTitle: "Chapter 1", chapterURL: "url1", chapterIndex: 0)
        let chapter2 = TOCItem(chapterTitle: "Chapter 2", chapterURL: "url2", chapterIndex: 1)
        coordinator.tocItems = [chapter1, chapter2]
        
        let next = coordinator.tocItems.firstIndex(where: { $0.chapterURL == chapter1.chapterURL }).flatMap { index in
            index < coordinator.tocItems.count - 1 ? coordinator.tocItems[index + 1] : nil
        }
        
        XCTAssertEqual(next?.chapterURL, chapter2.chapterURL)
    }
}

// MARK: - ChapterCacheStore Tests

final class ChapterCacheStoreTests: XCTestCase {
    
    private var store: ChapterCacheStore!
    private let testEntry = ChapterCacheEntry(
        chapterURL: "https://example.com/chapter/1",
        sourceID: "source-1",
        content: "Test content",
        title: "Test Chapter",
        lastModified: Date()
    )
    
    override func setUp() {
        super.setUp()
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_chapter_cache.json")
        store = ChapterCacheStore(storageURL: tempURL)
    }
    
    override func tearDown() {
        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: store.fileURL.path) {
            try? fileManager.removeItem(at: store.fileURL)
        }
        store = nil
        super.tearDown()
    }
    
    func testSaveAndLoadEntry() async throws {
        try store.saveEntry(testEntry)
        
        let loaded = try store.loadEntry(chapterURL: testEntry.chapterURL, sourceID: testEntry.sourceID)
        
        XCTAssertEqual(loaded?.chapterURL, testEntry.chapterURL)
        XCTAssertEqual(loaded?.sourceID, testEntry.sourceID)
        XCTAssertEqual(loaded?.content, testEntry.content)
        XCTAssertEqual(loaded?.title, testEntry.title)
    }
    
    func testLoadEntryReturnsNilWhenNotFound() async throws {
        let loaded = try store.loadEntry(chapterURL: "unknown", sourceID: "unknown")
        
        XCTAssertNil(loaded)
    }
    
    func testRemoveEntry() async throws {
        try store.saveEntry(testEntry)
        
        let loadedBefore = try store.loadEntry(chapterURL: testEntry.chapterURL, sourceID: testEntry.sourceID)
        XCTAssertNotNil(loadedBefore)
        
        try store.removeEntry(chapterURL: testEntry.chapterURL, sourceID: testEntry.sourceID)
        
        let loadedAfter = try store.loadEntry(chapterURL: testEntry.chapterURL, sourceID: testEntry.sourceID)
        XCTAssertNil(loadedAfter)
    }
    
    func testLoadEntryWithEmptyStore() async throws {
        let loaded = try store.loadEntry(chapterURL: "test", sourceID: "test")
        
        XCTAssertNil(loaded)
    }
    
    func testMultipleEntries() async throws {
        let entry1 = ChapterCacheEntry(
            chapterURL: "url1",
            sourceID: "source1",
            content: "content1",
            title: "title1",
            lastModified: Date()
        )
        let entry2 = ChapterCacheEntry(
            chapterURL: "url2",
            sourceID: "source1",
            content: "content2",
            title: "title2",
            lastModified: Date()
        )
        
        try store.saveEntry(entry1)
        try store.saveEntry(entry2)
        
        let loaded1 = try store.loadEntry(chapterURL: "url1", sourceID: "source1")
        let loaded2 = try store.loadEntry(chapterURL: "url2", sourceID: "source1")
        
        XCTAssertEqual(loaded1?.content, "content1")
        XCTAssertEqual(loaded2?.content, "content2")
    }
}
