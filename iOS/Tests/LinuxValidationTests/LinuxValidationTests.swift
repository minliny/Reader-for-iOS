import XCTest
@testable import ReaderIOSPlatformAdapters
@testable import ReaderShellValidation

private func nonisolatedIs<T>(_ value: Any, _ type: T.Type) -> Bool {
    return value is T
}

final class LinuxValidationTests: XCTestCase {

    func testPlatformAdaptersBuildsOnLinux() {
        let storage = IOSStorageAdapter()
        XCTAssertNotNil(storage)
    }

    func testHTTPAdapterCanBeInstantiated() {
        let adapter = IOSHTTPAdapter()
        XCTAssertNotNil(adapter)
    }

    func testLoggerAdapterCanBeInstantiated() {
        let logger = IOSLoggerAdapter(subsystem: "com.reader.test", category: "linux")
        logger.debug("debug")
        logger.info("info")
        logger.warning("warning")
        logger.error("error")
    }

    func testSnapshotStoreCanBeInstantiated() {
        let store = IOSSnapshotStore()
        XCTAssertNotNil(store)
    }

    func testKeychainAdapterThrowsUnavailableOnLinux() async throws {
        let store = IOSKeychainCredentialStore(service: "com.reader.test")
        do {
            try await store.saveCredential("test", for: "key")
            XCTFail("Expected KeychainError.unavailable on Linux")
        } catch is KeychainError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    @MainActor
    func testShellAssemblyCanBeConstructed() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        XCTAssertNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)
    }

    @MainActor
    func testShellAssemblyWiresMockServices() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        XCTAssertTrue(nonisolatedIs(coordinator.bookSourceRepository, InMemoryBookSourceRepository.self))
        XCTAssertTrue(coordinator.bookSourceDecoder is DefaultBookSourceDecoder)
        XCTAssertTrue(coordinator.searchService is MockSearchService)
        XCTAssertTrue(coordinator.tocService is MockTOCService)
        XCTAssertTrue(coordinator.contentService is MockContentService)
    }

    @MainActor
    func testReadingFlowCoordinatorReachableWithoutSource() async {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        await coordinator.search(keyword: "test")
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.currentError)
    }
}
