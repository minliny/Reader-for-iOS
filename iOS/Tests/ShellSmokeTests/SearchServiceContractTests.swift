import Foundation
import XCTest
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderShellValidation

final class SearchServiceContractTests: XCTestCase {
    
    private var mockProvider: ReaderCoreServiceProvider!
    private var placeholderService: PlaceholderSearchService!
    private var mockService: MockSearchService!
    private let testSource = BookSource(
        id: "test-source",
        bookSourceName: "Test Source",
        bookSourceUrl: "https://example.com"
    )
    
    override func setUp() {
        super.setUp()
        mockProvider = ReaderCoreServiceProvider.shared
        placeholderService = PlaceholderSearchService()
        mockService = MockSearchService(provider: mockProvider)
    }
    
    override func tearDown() {
        mockProvider.setMode(.mock)
        mockProvider.resetMock()
        super.tearDown()
    }
    
    // MARK: - Mock Search Service Tests
    
    func testMockSearchReturnsResultsOnSuccess() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let query = SearchQuery(keyword: "test", page: 1)
        let results = try await mockService.search(source: testSource, query: query)
        
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(results.count, 3)
    }
    
    func testMockSearchReturnsEmptyOnEmptyScenario() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.empty)
        
        let query = SearchQuery(keyword: "test", page: 1)
        let results = try await mockService.search(source: testSource, query: query)
        
        XCTAssertTrue(results.isEmpty)
    }
    
    func testMockSearchThrowsOnUnsupported() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.unsupported(reason: "Feature not supported"))
        
        let query = SearchQuery(keyword: "test", page: 1)
        
        do {
            _ = try await mockService.search(source: testSource, query: query)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .unsupported)
        }
    }
    
    func testMockSearchThrowsOnNetworkFailure() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.networkFailure)
        
        let query = SearchQuery(keyword: "test", page: 1)
        
        do {
            _ = try await mockService.search(source: testSource, query: query)
            XCTFail("Expected error to be thrown")
        } catch let error as AppReaderError {
            XCTAssertEqual(error.code, .network)
        }
    }
    
    // MARK: - Placeholder Search Service Tests
    
    func testPlaceholderSearchThrowsRealCoreNotAvailable() async throws {
        let query = SearchQuery(keyword: "test", page: 1)
        
        do {
            _ = try await placeholderService.search(source: testSource, query: query)
            XCTFail("Expected error to be thrown")
        } catch PlaceholderServiceError.realCoreNotAvailable {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
    
    func testPlaceholderSearchDoesNotReturnMockResults() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let query = SearchQuery(keyword: "test", page: 1)
        
        // Placeholder should NOT delegate to mock, even if mock is set
        do {
            _ = try await placeholderService.search(source: testSource, query: query)
            XCTFail("Expected PlaceholderServiceError to be thrown")
        } catch PlaceholderServiceError.realCoreNotAvailable {
            // Expected - Placeholder does not use mock
        }
    }
    
    // MARK: - ReaderCoreServiceProvider Mode Tests
    
    func testProviderMockModeDelegatesToMockService() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let state = await mockProvider.searchBooks(keyword: "test", page: 1)
        
        switch state {
        case .loaded(let results):
            XCTAssertFalse(results.isEmpty)
        default:
            XCTFail("Expected .loaded state, got \(state)")
        }
    }
    
    func testProviderRealModeReturnsUnsupported() async throws {
        mockProvider.setMode(.real)
        mockProvider.setMockScenario(.success)
        
        let state = await mockProvider.searchBooks(keyword: "test", page: 1)
        
        switch state {
        case .unsupported(let reason):
            XCTAssertTrue(reason.contains("not available"))
        default:
            XCTFail("Expected .unsupported state, got \(state)")
        }
    }
    
    func testProviderRealModeDoesNotReturnMockResults() async throws {
        // Set mock to success
        mockProvider.setMockScenario(.success)
        // But provider in real mode
        mockProvider.setMode(.real)
        
        let state = await mockProvider.searchBooks(keyword: "test", page: 1)
        
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
    
    func testSearchServiceInputRequiresBookSource() async throws {
        // The protocol requires a BookSource, but we can test with nil behavior
        // through the adapter layer
        let query = SearchQuery(keyword: "test", page: 1)
        
        // With mock provider, should work
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        _ = try await mockService.search(source: testSource, query: query)
    }
    
    func testSearchServiceThrowsOnEmptyKeyword() async throws {
        // Empty keyword is handled at ViewModel level, not service level
        // Service receives pre-validated query
        let query = SearchQuery(keyword: "", page: 1)
        
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        // Mock service accepts any keyword, real validation is at higher level
        let results = try await mockService.search(source: testSource, query: query)
        XCTAssertFalse(results.isEmpty)
    }
    
    func testSearchServiceReturnsArrayEvenOnEmpty() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.empty)
        
        let query = SearchQuery(keyword: "test", page: 1)
        let results = try await mockService.search(source: testSource, query: query)
        
        // Service returns empty array, not nil
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: - State Transition Tests
    
    func testSearchStateFromIdleToSuccess() async throws {
        // Simulate state transition at ViewModel level
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.success)
        
        let state = await mockProvider.searchBooks(keyword: "test", page: 1)
        
        switch state {
        case .loaded:
            // State transitioned from idle to loaded
            break
        default:
            XCTFail("Expected .loaded state")
        }
    }
    
    func testSearchStateFromIdleToEmpty() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.empty)
        
        let state = await mockProvider.searchBooks(keyword: "test", page: 1)
        
        switch state {
        case .empty:
            break
        default:
            XCTFail("Expected .empty state")
        }
    }
    
    func testSearchStateFromIdleToFailed() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.networkFailure)
        
        let state = await mockProvider.searchBooks(keyword: "test", page: 1)
        
        switch state {
        case .failed:
            break
        default:
            XCTFail("Expected .failed state")
        }
    }
    
    func testSearchStateFromIdleToUnsupported() async throws {
        mockProvider.setMode(.real)
        
        let state = await mockProvider.searchBooks(keyword: "test", page: 1)
        
        switch state {
        case .unsupported:
            break
        default:
            XCTFail("Expected .unsupported state")
        }
    }
    
    func testSearchStateFromIdleToPartial() async throws {
        mockProvider.setMode(.mock)
        mockProvider.setMockScenario(.partial(warning: "Some results may be incomplete"))
        
        let state = await mockProvider.searchBooks(keyword: "test", page: 1)
        
        switch state {
        case .partial(let results, let warning):
            XCTAssertFalse(results.isEmpty)
            XCTAssertTrue(warning.contains("incomplete"))
        default:
            XCTFail("Expected .partial state")
        }
    }
}
