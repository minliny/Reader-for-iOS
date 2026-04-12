import XCTest
@testable import ReaderShellValidation

@MainActor
final class ShellAssemblySmokeTests: XCTestCase {
    func testShellAssemblyBuildsDefaultCoordinator() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        XCTAssertNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)
    }

    func testShellAssemblyWiresExpectedCoreIntegrationTypes() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()

        XCTAssertTrue(coordinator.bookSourceRepository is InMemoryBookSourceRepository)
        XCTAssertTrue(coordinator.bookSourceDecoder is DefaultBookSourceDecoder)
        XCTAssertTrue(coordinator.searchService is DefaultSearchService)
        XCTAssertTrue(coordinator.tocService is DefaultTOCService)
        XCTAssertTrue(coordinator.contentService is DefaultContentService)
    }
}
