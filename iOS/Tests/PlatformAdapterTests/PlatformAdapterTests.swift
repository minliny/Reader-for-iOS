import XCTest
@testable import ReaderIOSPlatformAdapters

final class PlatformAdapterTests: XCTestCase {

    private var tempDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    func testStorageAdapterSaveLoadDelete() async throws {
        let baseURL = tempDirectory
        let adapter = IOSStorageAdapter(baseURL: baseURL)
        let filename = "test_\(UUID().uuidString).txt"
        let data = Data("hello storage".utf8)

        try await adapter.save(data, to: filename)
        let exists = await adapter.exists(filename: filename)
        XCTAssertTrue(exists)

        let loaded = try await adapter.load(from: filename)
        XCTAssertEqual(loaded, data)

        try await adapter.delete(filename: filename)
        let notExists = await adapter.exists(filename: filename)
        XCTAssertFalse(notExists)
    }

    func testSnapshotStoreSaveLoadDeleteList() async throws {
        let baseURL = tempDirectory
        let store = IOSSnapshotStore(baseURL: baseURL)
        let identifier = UUID().uuidString
        let data = Data("snapshot data".utf8)

        try await store.saveSnapshot(data, identifier: identifier)
        let loaded = try await store.loadSnapshot(identifier: identifier)
        XCTAssertEqual(loaded, data)

        let list = await store.listSnapshots()
        XCTAssertTrue(list.contains(identifier))

        try await store.deleteSnapshot(identifier: identifier)
        let afterDelete = try await store.loadSnapshot(identifier: identifier)
        XCTAssertNil(afterDelete)
    }

    func testLoggerAdapterCanInstantiate() {
        let logger = IOSLoggerAdapter(subsystem: "com.reader.test", category: "test")
        logger.debug("debug message")
        logger.info("info message")
        logger.warning("warning message")
        logger.error("error message")
    }

    func testKeychainAdapterUnavailableOnLinux() async {
        let store = IOSKeychainCredentialStore(service: "com.reader.test")
        do {
            try await store.saveCredential("secret", for: "key")
            #if canImport(Security)
            // On Apple platforms this may succeed or fail depending on environment
            #else
            XCTFail("Expected unavailable on non-Apple platforms")
            #endif
        } catch let error as KeychainError {
            #if canImport(Security)
            // Acceptable on Apple platforms if keychain is not mockable
            #else
            if case .unavailable = error {
                // Expected on Linux
            } else {
                XCTFail("Unexpected keychain error: \(error)")
            }
            #endif
        } catch {
            // Other errors acceptable in test environment
        }
    }

    func testHTTPAdapterCanInstantiate() {
        let adapter = IOSHTTPAdapter()
        XCTAssertNotNil(adapter)
    }
}
