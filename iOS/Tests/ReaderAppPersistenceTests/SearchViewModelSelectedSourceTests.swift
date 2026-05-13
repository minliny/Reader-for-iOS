import Foundation
import XCTest
import ReaderCoreModels
import ReaderAppPersistence

final class SearchViewModelSelectedSourceTests: XCTestCase {
    
    private var store: BookSourceStore!
    private var storageURL: URL!
    private var selectionURL: URL!
    
    override func setUp() async throws {
        storageURL = makeTempFileURL(name: "sources_\(UUID().uuidString).json")
        selectionURL = makeTempFileURL(name: "selection_\(UUID().uuidString).json")
        store = BookSourceStore(storageURL: storageURL, selectionURL: selectionURL)
    }
    
    // MARK: - Selected Source Resolution Tests
    
    func testResolveSelectedSourceWithValidId() async throws {
        var source = BookSource(bookSourceName: "Test Source")
        source.id = "test-id"
        try await store.add(source)
        try await store.saveSelectedSourceId("test-id")
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.id, "test-id")
    }
    
    func testResolveSelectedSourceWithInvalidId() async throws {
        var source = BookSource(bookSourceName: "Test Source")
        source.id = "test-id"
        try await store.add(source)
        try await store.saveSelectedSourceId("non-existent-id")
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNil(resolved)
    }
    
    func testResolveSelectedSourceWithNilId() async throws {
        var source = BookSource(bookSourceName: "Test Source")
        source.id = "test-id"
        try await store.add(source)
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNil(resolved)
    }
    
    // MARK: - Source Selection Priority Tests
    
    func testSelectedSourceIdHasPriorityOverEnabled() async throws {
        var source1 = BookSource(bookSourceName: "Source 1")
        source1.id = "id-1"
        source1.enabled = false
        try await store.add(source1)
        
        var source2 = BookSource(bookSourceName: "Source 2")
        source2.id = "id-2"
        source2.enabled = true
        try await store.add(source2)
        
        try await store.saveSelectedSourceId("id-1")
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.id, "id-1")
        XCTAssertEqual(resolved?.bookSourceName, "Source 1")
    }
    
    func testFallbackToEnabledWhenNoSelectedSourceId() async throws {
        var source1 = BookSource(bookSourceName: "Source 1")
        source1.id = "id-1"
        source1.enabled = false
        try await store.add(source1)
        
        var source2 = BookSource(bookSourceName: "Source 2")
        source2.id = "id-2"
        source2.enabled = true
        try await store.add(source2)
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNil(resolved)
    }
    
    func testFallbackToFirstSourceWhenNoEnabledAndNoSelectedSourceId() async throws {
        var source1 = BookSource(bookSourceName: "Source 1")
        source1.id = "id-1"
        source1.enabled = false
        try await store.add(source1)
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNil(resolved)
    }
    
    // MARK: - Deleted Source Resolution Tests
    
    func testResolveDeletedSourceReturnsNil() async throws {
        var source = BookSource(bookSourceName: "Test Source")
        source.id = "test-id"
        try await store.add(source)
        try await store.saveSelectedSourceId("test-id")
        try await store.delete(id: "test-id")
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNil(resolved)
        XCTAssertTrue(sources.isEmpty)
    }
    
    func testResolveSelectedSourceAfterSourceUpdate() async throws {
        var source = BookSource(bookSourceName: "Original Name")
        source.id = "test-id"
        try await store.add(source)
        try await store.saveSelectedSourceId("test-id")
        
        var updated = BookSource(bookSourceName: "Updated Name")
        updated.id = "test-id"
        try await store.update(updated)
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.bookSourceName, "Updated Name")
    }
    
    // MARK: - Empty Sources Tests
    
    func testResolveWithEmptySourcesReturnsNil() async throws {
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNil(resolved)
        XCTAssertTrue(sources.isEmpty)
    }
    
    func testResolveWithMultipleSourcesAndSelectedId() async throws {
        for i in 1...5 {
            var source = BookSource(bookSourceName: "Source \(i)")
            source.id = "id-\(i)"
            try await store.add(source)
        }
        
        try await store.saveSelectedSourceId("id-3")
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.id, "id-3")
        XCTAssertEqual(resolved?.bookSourceName, "Source 3")
    }
    
    // MARK: - Helpers
    
    private func makeTempFileURL(name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SearchSelectedSourceTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
}
