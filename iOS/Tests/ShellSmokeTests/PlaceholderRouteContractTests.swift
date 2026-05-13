import XCTest
@testable import ReaderShellValidation
import ReaderCoreModels

final class PlaceholderRouteContractTests: XCTestCase {
    
    override func setUp() async throws {
        ReaderCoreServiceProvider.shared.setMode(.mock)
        ReaderCoreServiceProvider.shared.resetMock()
    }
    
    func testProviderDefaultsToMockMode() {
        let provider = ReaderCoreServiceProvider.shared
        XCTAssertEqual(provider.currentMode, .mock)
    }
    
    func testProviderSetModeToMock() {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        XCTAssertEqual(provider.currentMode, .mock)
    }
    
    func testProviderSetModeToReal() {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.real)
        XCTAssertEqual(provider.currentMode, .real)
    }
    
    @MainActor
    func testDefaultCoordinatorInMockModeUsesMockServices() {
        ReaderCoreServiceProvider.shared.setMode(.mock)
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        
        XCTAssertTrue(coordinator.searchService is MockSearchService)
        XCTAssertTrue(coordinator.tocService is MockTOCService)
        XCTAssertTrue(coordinator.contentService is MockContentService)
    }
    
    @MainActor
    func testDefaultCoordinatorInRealModeUsesPlaceholderServices() {
        ReaderCoreServiceProvider.shared.setMode(.real)
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        
        XCTAssertTrue(coordinator.searchService is PlaceholderSearchService)
        XCTAssertTrue(coordinator.tocService is PlaceholderTOCService)
        XCTAssertTrue(coordinator.contentService is PlaceholderContentService)
    }
    
    func testRealModeReturnsUnsupportedStateInProvider() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.real)
        
        let result = await provider.searchBooks(keyword: "test", page: 1)
        if case .unsupported(let reason) = result {
            XCTAssertTrue(reason.contains("placeholder"))
        } else {
            XCTFail("Expected .unsupported in real mode, got \(result)")
        }
    }
    
    @MainActor
    func testMockModeStillReturnsMockResults() async {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMode(.mock)
        
        let result = await provider.searchBooks(keyword: "test", page: 1)
        if case .loaded = result {
            // Mock mode expected
        } else {
            XCTFail("Expected .loaded in mock mode, got \(result)")
        }
    }
}
