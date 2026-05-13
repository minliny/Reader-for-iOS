import Foundation
import XCTest
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderShellValidation

final class TOCServiceContractTests: XCTestCase {
    
    private var mockProvider: ReaderCoreServiceProvider!
    private var placeholderService: PlaceholderTOCService!
    private var mockService: MockTOCService!
    private let testSource = BookSource(
        id: "test-source",
        bookSourceName: "Test Source",
        bookSourceUrl: "https://example.com"
    )
    private let testDetailURL = "https://example.com/book/1"
    
    override func setUp() {
        super.setUp()
        mockProvider = ReaderCoreServiceProvider.shared
        placeholderService = PlaceholderTOCService()
        mockService = MockTOCService(provider: mockProvider)
    }
    
    override func tearDown() {
        mockProvider.setMode(.mock)
        mockProvider.resetMock()
        super.tearDown()
    }
    
    // MARK: - Mock TOC Service Tests
    
    func testMockTOCReturnsResultsOnSuccess() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let items = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
        
        XCTAssertFalse(items.isEmpty)
        XCTAssertEqual(items.count, 5)
    }
    
    func testMockTOCReturnsEmptyOnEmptyScenario() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.empty)
        
        let items = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
        
        XCTAssertTrue(items.isEmpty)
    }
    
    func testMockTOCThrowsOnUnsupported() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.unsupported(reason: "Feature not supported"))
        
        do {
            _ = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .unsupported)
        }
    }
    
    func testMockTOCThrowsOnNetworkFailure() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.networkFailure)
        
        do {
            _ = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .network)
        }
    }
    
    func testMockTOCThrowsOnParserFailure() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.parserFailure)
        
        do {
            _ = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .parser)
        }
    }
    
    func testMockTOCThrowsOnLoginRequired() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.loginRequired)
        
        do {
            _ = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .loginRequired)
        }
    }
    
    // MARK: - Placeholder TOC Service Tests
    
    func testPlaceholderTOCThrowsRealCoreNotAvailable() async throws {
        do {
            _ = try await placeholderService.fetchTOC(source: testSource, detailURL: testDetailURL)
            XCTFail("Expected error to be thrown")
        } catch PlaceholderServiceError.realCoreNotAvailable {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testPlaceholderTOCDoesNotReturnMockResults() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        do {
            _ = try await placeholderService.fetchTOC(source: testSource, detailURL: testDetailURL)
            XCTFail("Expected PlaceholderServiceError to be thrown")
        } catch PlaceholderServiceError.realCoreNotAvailable {
            // Expected - Placeholder does not use mock
        }
    }
    
    // MARK: - ReaderCoreServiceProvider Mode Tests
    
    func testProviderMockModeDelegatesToMockService() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let state = await mockProvider.getChapterList(bookURL: testDetailURL)
        
        switch state {
        case .loaded(let items):
            XCTAssertFalse(items.isEmpty)
        default:
            XCTFail("Expected .loaded state, got \(state)")
        }
    }
    
    func testProviderRealModeReturnsUnsupported() async throws {
        mockProvider.setMode(.real)
        mockProvider.setMockScenario(.success)
        
        let state = await mockProvider.getChapterList(bookURL: testDetailURL)
        
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
        
        let state = await mockProvider.getChapterList(bookURL: testDetailURL)
        
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
    
    func testTOCServiceInputRequiresBookSource() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        _ = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
    }
    
    func testTOCServiceReturnsArrayEvenOnEmpty() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.empty)
        
        let items = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
        
        XCTAssertTrue(items.isEmpty)
    }
    
    // MARK: - State Transition Tests
    
    func testTOCStateFromIdleToSuccess() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let state = await mockProvider.getChapterList(bookURL: testDetailURL)
        
        switch state {
        case .loaded:
            break
        default:
            XCTFail("Expected .loaded state")
        }
    }
    
    func testTOCStateFromIdleToEmpty() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.empty)
        
        let state = await mockProvider.getChapterList(bookURL: testDetailURL)
        
        switch state {
        case .empty:
            break
        default:
            XCTFail("Expected .empty state")
        }
    }
    
    func testTOCStateFromIdleToFailed() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.networkFailure)
        
        let state = await mockProvider.getChapterList(bookURL: testDetailURL)
        
        switch state {
        case .failed:
            break
        default:
            XCTFail("Expected .failed state")
        }
    }
    
    func testTOCStateFromIdleToUnsupported() async throws {
        mockProvider.setMode(.real)
        
        let state = await mockProvider.getChapterList(bookURL: testDetailURL)
        
        switch state {
        case .unsupported:
            break
        default:
            XCTFail("Expected .unsupported state")
        }
    }
    
    func testTOCStateFromIdleToPartial() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.partial(warning: "Some chapters may be incomplete"))
        
        let state = await mockProvider.getChapterList(bookURL: testDetailURL)
        
        switch state {
        case .partial(let items, let warning):
            XCTAssertFalse(items.isEmpty)
            XCTAssertTrue(warning.contains("incomplete"))
        default:
            XCTFail("Expected .partial state")
        }
    }
    
    // MARK: - TOCItem Content Tests
    
    func testMockTOCItemsHaveValidStructure() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let items = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
        
        XCTAssertEqual(items.count, 5)
        
        for (index, item) in items.enumerated() {
            XCTAssertFalse(item.chapterTitle.isEmpty, "Chapter \(index) title should not be empty")
            XCTAssertFalse(item.chapterURL.isEmpty, "Chapter \(index) URL should not be empty")
            XCTAssertEqual(item.chapterIndex, index, "Chapter \(index) index should be \(index)")
        }
    }
    
    func testMockTOCItemsHaveCorrectOrder() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let items = try await mockService.fetchTOC(source: testSource, detailURL: testDetailURL)
        
        for (index, item) in items.enumerated() {
            XCTAssertEqual(item.chapterIndex, index)
        }
    }
    
    // MARK: - ChapterListViewModel Tests
    
    func testChapterListViewModelLoadsSuccessfully() async throws {
        let viewModel = ChapterListViewModel(bookURL: testDetailURL, bookTitle: "Test Book")
        
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        await viewModel.loadChapters()
        
        switch viewModel.listState {
        case .loaded(let chapters):
            XCTAssertFalse(chapters.isEmpty)
        case .empty:
            XCTFail("Expected .loaded state, got .empty")
        default:
            XCTFail("Expected .loaded state, got different state")
        }
    }
    
    func testChapterListViewModelHandlesEmpty() async throws {
        let viewModel = ChapterListViewModel(bookURL: testDetailURL, bookTitle: "Test Book")
        
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.empty)
        
        await viewModel.loadChapters()
        
        switch viewModel.listState {
        case .empty:
            // Expected
            break
        default:
            XCTFail("Expected .empty state")
        }
    }
    
    func testChapterListViewModelHandlesUnsupported() async throws {
        let viewModel = ChapterListViewModel(bookURL: testDetailURL, bookTitle: "Test Book")
        
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.unsupported(reason: "JS required"))
        
        await viewModel.loadChapters()
        
        switch viewModel.listState {
        case .unsupported(let reason):
            XCTAssertTrue(reason.contains("JS"))
        default:
            XCTFail("Expected .unsupported state")
        }
    }
    
    func testChapterListViewModelHandlesFailure() async throws {
        let viewModel = ChapterListViewModel(bookURL: testDetailURL, bookTitle: "Test Book")
        
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.networkFailure)
        
        await viewModel.loadChapters()
        
        switch viewModel.listState {
        case .failed:
            // Expected
            break
        default:
            XCTFail("Expected .failed state")
        }
    }
}
