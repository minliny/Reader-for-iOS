import XCTest
import ReaderCoreCache
import ReaderCoreProtocols

final class SimpleCacheRepositoryTests: XCTestCase {
    var repo: SimpleCacheRepository!

    override func setUp() {
        super.setUp()
        repo = SimpleCacheRepository()
    }

    override func tearDown() {
        repo = nil
        super.tearDown()
    }

    func testSetAndGetSearchResponse() async throws {
        let payload = "test payload".data(using: .utf8)!
        try await repo.setSearchResponse(key: "key1", payload: payload, ttlSeconds: 3600)
        let retrieved = try await repo.getSearchResponse(key: "key1")
        XCTAssertEqual(retrieved, payload)
    }

    func testSetAndGetTOCResponse() async throws {
        let payload = "toc payload".data(using: .utf8)!
        try await repo.setTOCResponse(key: "key2", payload: payload, ttlSeconds: 3600)
        let retrieved = try await repo.getTOCResponse(key: "key2")
        XCTAssertEqual(retrieved, payload)
    }

    func testSetAndGetContentResponse() async throws {
        let payload = "content payload".data(using: .utf8)!
        try await repo.setContentResponse(key: "key3", payload: payload, ttlSeconds: 3600)
        let retrieved = try await repo.getContentResponse(key: "key3")
        XCTAssertEqual(retrieved, payload)
    }

    func testExpiredEntryReturnsNil() async throws {
        let payload = "expired".data(using: .utf8)!
        let entry = CacheEntry(
            key: "expired-key",
            scope: .search,
            createdAt: Date().addingTimeInterval(-7200),
            ttlSeconds: 3600,
            payload: payload
        )
        try await repo.set(entry)
        let retrieved = try await repo.getSearchResponse(key: "expired-key")
        XCTAssertNil(retrieved)
    }

    func testRemove() async throws {
        let payload = "to remove".data(using: .utf8)!
        try await repo.setSearchResponse(key: "remove-key", payload: payload, ttlSeconds: 3600)
        try await repo.remove(scope: .search, key: "remove-key")
        let retrieved = try await repo.getSearchResponse(key: "remove-key")
        XCTAssertNil(retrieved)
    }

    func testClearScope() async throws {
        let p1 = "s1".data(using: .utf8)!
        let p2 = "t1".data(using: .utf8)!
        try await repo.setSearchResponse(key: "s1", payload: p1, ttlSeconds: 3600)
        try await repo.setTOCResponse(key: "t1", payload: p2, ttlSeconds: 3600)
        try await repo.clear(scope: .search)
        let r1 = try await repo.getSearchResponse(key: "s1")
        let r2 = try await repo.getTOCResponse(key: "t1")
        XCTAssertNil(r1)
        XCTAssertNotNil(r2)
    }

    func testClearAll() async throws {
        let p1 = "s1".data(using: .utf8)!
        let p2 = "t1".data(using: .utf8)!
        try await repo.setSearchResponse(key: "s1", payload: p1, ttlSeconds: 3600)
        try await repo.setTOCResponse(key: "t1", payload: p2, ttlSeconds: 3600)
        try await repo.clear(scope: nil)
        let r1 = try await repo.getSearchResponse(key: "s1")
        let r2 = try await repo.getTOCResponse(key: "t1")
        XCTAssertNil(r1)
        XCTAssertNil(r2)
    }
}
