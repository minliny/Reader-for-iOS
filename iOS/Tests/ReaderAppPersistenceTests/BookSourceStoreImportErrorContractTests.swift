import Foundation
import XCTest
import ReaderCoreModels
import ReaderAppPersistence

final class BookSourceStoreImportErrorContractTests: XCTestCase {
    
    private var store: BookSourceStore!
    private var storageURL: URL!
    private var selectionURL: URL!
    
    override func setUp() async throws {
        storageURL = makeTempFileURL(name: "sources_\(UUID().uuidString).json")
        selectionURL = makeTempFileURL(name: "selection_\(UUID().uuidString).json")
        store = BookSourceStore(storageURL: storageURL, selectionURL: selectionURL)
    }
    
    // MARK: - Duplicate Import Strategy Tests
    
    func testAddWithSameIdReplacesExisting() async throws {
        var source1 = BookSource(bookSourceName: "Original")
        source1.id = "same-id"
        try await store.add(source1)
        
        var source2 = BookSource(bookSourceName: "Updated")
        source2.id = "same-id"
        try await store.add(source2)
        
        let sources = try await store.load()
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.bookSourceName, "Updated")
    }
    
    func testAddWithDifferentIdsCreatesNew() async throws {
        var source1 = BookSource(bookSourceName: "Source 1")
        source1.id = "id-1"
        try await store.add(source1)
        
        var source2 = BookSource(bookSourceName: "Source 2")
        source2.id = "id-2"
        try await store.add(source2)
        
        let sources = try await store.load()
        XCTAssertEqual(sources.count, 2)
    }
    
    func testAddWithoutIdGeneratesNewId() async throws {
        let source = BookSource(bookSourceName: "No ID")
        try await store.add(source)
        
        let sources = try await store.load()
        XCTAssertEqual(sources.count, 1)
        XCTAssertNotNil(sources.first?.id)
    }
    
    func testAddWithoutIdTwiceCreatesTwoEntries() async throws {
        try await store.add(BookSource(bookSourceName: "First"))
        try await store.add(BookSource(bookSourceName: "Second"))
        
        let sources = try await store.load()
        XCTAssertEqual(sources.count, 2)
        XCTAssertNotEqual(sources[0].id, sources[1].id)
    }
    
    // MARK: - Delete Non-Existent Tests
    
    func testDeleteNonExistentIdThrowsNoError() async throws {
        do {
            try await store.delete(id: "non-existent-id")
        } catch {
            XCTFail("delete should not throw for non-existent id: \(error)")
        }
        
        let sources = try await store.load()
        XCTAssertTrue(sources.isEmpty)
    }
    
    // MARK: - Delete / Selection Consistency Tests
    
    func testDeleteSelectedSourceClearsSelection() async throws {
        var source = BookSource(bookSourceName: "Selected")
        source.id = "selected-id"
        try await store.add(source)
        
        try await store.saveSelectedSourceId("selected-id")
        try await store.delete(id: "selected-id")
        
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertNil(selectedId)
    }
    
    func testDeleteNonSelectedSourcePreservesSelection() async throws {
        var source1 = BookSource(bookSourceName: "Source 1")
        source1.id = "id-1"
        try await store.add(source1)
        
        var source2 = BookSource(bookSourceName: "Source 2")
        source2.id = "id-2"
        try await store.add(source2)
        
        try await store.saveSelectedSourceId("id-1")
        try await store.delete(id: "id-2")
        
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertEqual(selectedId, "id-1")
    }
    
    // MARK: - Corrupted Data Tests
    
    func testCorruptedBookSourcesJSONThrowsOnLoad() async throws {
        let corruptedData = "definitely not json".data(using: .utf8)!
        try corruptedData.write(to: storageURL)
        
        do {
            _ = try await store.load()
            XCTFail("Expected decoding error to be thrown")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testCorruptedSelectionJSONReturnsNil() async throws {
        let corruptedData = "definitely not json".data(using: .utf8)!
        try corruptedData.write(to: selectionURL)
        
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertNil(selectedId)
    }
    
    func testEmptySelectionFileReturnsNil() async throws {
        let emptyData = "".data(using: .utf8)!
        try emptyData.write(to: selectionURL)
        
        let selectedId = await store.loadSelectedSourceId()
        XCTAssertNil(selectedId)
    }
    
    // MARK: - Update Tests
    
    func testUpdateNonExistentIdDoesNothing() async throws {
        try await store.update(BookSource(bookSourceName: "Update"))
        
        let sources = try await store.load()
        XCTAssertTrue(sources.isEmpty)
    }
    
    func testUpdateExistingIdReplacesSource() async throws {
        var source = BookSource(bookSourceName: "Original")
        source.id = "test-id"
        try await store.add(source)
        
        var updated = BookSource(bookSourceName: "Updated")
        updated.id = "test-id"
        try await store.update(updated)
        
        let sources = try await store.load()
        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources.first?.bookSourceName, "Updated")
    }
    
    // MARK: - Helpers
    
    private func makeTempFileURL(name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookSourceImportErrorTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
}
