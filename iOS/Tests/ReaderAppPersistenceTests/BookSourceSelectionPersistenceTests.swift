import Foundation
import XCTest
import ReaderCoreModels
import ReaderAppPersistence

final class BookSourceSelectionPersistenceTests: XCTestCase {
    
    private var store: BookSourceStore!
    private var storageURL: URL!
    private var selectionURL: URL!
    
    override func setUp() async throws {
        storageURL = makeTempFileURL(name: "sources_\(UUID().uuidString).json")
        selectionURL = makeTempFileURL(name: "selection_\(UUID().uuidString).json")
        store = BookSourceStore(storageURL: storageURL, selectionURL: selectionURL)
    }
    
    // MARK: - Initial State Tests
    
    func testInitialSelectedSourceIdIsNil() async throws {
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertNil(selectedId)
    }
    
    func testClearSelectedSourceIdWhenAlreadyNil() async throws {
        try await store.clearSelectedSourceId()
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertNil(selectedId)
    }
    
    // MARK: - Save and Load Tests
    
    func testSaveSelectedSourceIdThenLoad() async throws {
        try await store.saveSelectedSourceId("test-source-id")
        
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertEqual(selectedId, "test-source-id")
    }
    
    func testClearSelectedSourceIdAfterSave() async throws {
        try await store.saveSelectedSourceId("test-source-id")
        try await store.clearSelectedSourceId()
        
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertNil(selectedId)
    }
    
    // MARK: - Delete Consistency Tests
    
    func testDeleteNonSelectedSourceDoesNotAffectSelection() async throws {
        var source1 = BookSource(bookSourceName: "Source 1")
        source1.id = "source-1"
        try await store.add(source1)
        
        var source2 = BookSource(bookSourceName: "Source 2")
        source2.id = "source-2"
        try await store.add(source2)
        
        try await store.saveSelectedSourceId("source-2")
        try await store.delete(id: "source-1")
        
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertEqual(selectedId, "source-2")
    }
    
    func testDeleteSelectedSourceClearsSelection() async throws {
        var source = BookSource(bookSourceName: "Test Source")
        source.id = "test-source"
        try await store.add(source)
        
        try await store.saveSelectedSourceId("test-source")
        try await store.delete(id: "test-source")
        
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertNil(selectedId)
    }
    
    // MARK: - Resolve Tests
    
    func testResolveSelectedSourceReturnsMatchingSource() async throws {
        var source = BookSource(bookSourceName: "Test Source")
        source.id = "test-source"
        try await store.add(source)
        
        try await store.saveSelectedSourceId("test-source")
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNotNil(resolved)
        XCTAssertEqual(resolved?.id, "test-source")
        XCTAssertEqual(resolved?.bookSourceName, "Test Source")
    }
    
    func testResolveSelectedSourceReturnsNilWhenNoSelection() async throws {
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNil(resolved)
    }
    
    func testResolveSelectedSourceReturnsNilWhenSourceDeleted() async throws {
        var source = BookSource(bookSourceName: "Test Source")
        source.id = "test-source"
        try await store.add(source)
        
        try await store.saveSelectedSourceId("test-source")
        try await store.delete(id: "test-source")
        
        let sources = try await store.load()
        let resolved = await store.resolveSelectedSource(from: sources)
        
        XCTAssertNil(resolved)
    }
    
    // MARK: - Cache Tests
    
    func testClearCacheClearsSelectionCache() async throws {
        try await store.saveSelectedSourceId("test-source-id")
        store.clearCache()
        
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertEqual(selectedId, "test-source-id")
    }
    
    // MARK: - Helpers
    
    private func makeTempFileURL(name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookSourceSelectionTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
}
