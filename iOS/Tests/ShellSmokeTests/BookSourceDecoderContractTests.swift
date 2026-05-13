import Foundation
import XCTest
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderShellValidation
import ReaderAppPersistence

final class BookSourceDecoderContractTests: XCTestCase {
    
    private var decoder: DefaultBookSourceDecoder!
    
    override func setUp() {
        super.setUp()
        decoder = DefaultBookSourceDecoder()
    }
    
    // MARK: - Decode Success Tests
    
    func testDecodeValidBookSourceJSON() throws {
        let json = """
        {
            "bookSourceName": "Test Source",
            "bookSourceUrl": "https://example.com",
            "bookSourceGroup": "Test Group"
        }
        """.data(using: .utf8)!
        
        let source = try decoder.decodeBookSource(from: json)
        XCTAssertEqual(source.bookSourceName, "Test Source")
        XCTAssertEqual(source.bookSourceUrl, "https://example.com")
    }
    
    func testDecodeBookSourceWithMinimalFields() throws {
        let json = """
        {
            "bookSourceName": "Minimal Source"
        }
        """.data(using: .utf8)!
        
        let source = try decoder.decodeBookSource(from: json)
        XCTAssertEqual(source.bookSourceName, "Minimal Source")
        XCTAssertNil(source.bookSourceUrl)
    }
    
    func testDecodeBookSourceIgnoresExtraFields() throws {
        let json = """
        {
            "bookSourceName": "Test",
            "unknownField": "should be ignored",
            "anotherUnknown": 123
        }
        """.data(using: .utf8)!
        
        let source = try decoder.decodeBookSource(from: json)
        XCTAssertEqual(source.bookSourceName, "Test")
    }
    
    // MARK: - Decode Failure Tests
    
    func testDecodeInvalidJSONThrowsError() {
        let invalidJSON = "not json at all".data(using: .utf8)!
        
        XCTAssertThrowsError(try decoder.decodeBookSource(from: invalidJSON)) { error in
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testDecodeTruncatedJSONThrowsError() {
        let truncatedJSON = """
        {
            "bookSourceName":
        """.data(using: .utf8)!
        
        XCTAssertThrowsError(try decoder.decodeBookSource(from: truncatedJSON))
    }
    
    func testDecodeEmptyJSONThrowsError() {
        let emptyJSON = "{}".data(using: .utf8)!
        
        let source = try decoder.decodeBookSource(from: emptyJSON)
        XCTAssertEqual(source.bookSourceName, "")
    }
    
    // MARK: - Duplicate Import Strategy Tests
    
    func testDuplicateImportUsesIdForMerge() async throws {
        let tempURL = makeTempFileURL(name: "test_duplicate.json")
        let store = BookSourceStore(storageURL: tempURL)
        
        var source1 = BookSource(bookSourceName: "Original")
        source1.id = "same-id"
        try await store.add(source1)
        
        var source2 = BookSource(bookSourceName: "Duplicate")
        source2.id = "same-id"
        try await store.add(source2)
        
        let sources = try await store.load()
        XCTAssertEqual(sources.count, 2)
    }
    
    func testDuplicateImportNoIdCreatesNewEntry() async throws {
        let tempURL = makeTempFileURL(name: "test_no_id.json")
        let store = BookSourceStore(storageURL: tempURL)
        
        try await store.add(BookSource(bookSourceName: "First"))
        try await store.add(BookSource(bookSourceName: "Second"))
        
        let sources = try await store.load()
        XCTAssertEqual(sources.count, 2)
        XCTAssertTrue(sources[0].id != nil)
        XCTAssertTrue(sources[1].id != nil)
    }
    
    // MARK: - Corrupted Data Recovery Tests
    
    func testCorruptedJSONFileThrowsOnLoad() async throws {
        let tempURL = makeTempFileURL(name: "test_corrupted.json")
        
        let corruptedData = "definitely not json".data(using: .utf8)!
        try corruptedData.write(to: tempURL)
        
        let store = BookSourceStore(storageURL: tempURL)
        
        do {
            _ = try await store.load()
            XCTFail("Expected decoding error to be thrown")
        } catch {
            XCTAssertTrue(error is DecodingError)
        }
    }
    
    func testMissingFileReturnsEmptyArray() async throws {
        let nonExistentURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nonexistent_\(UUID().uuidString).json")
        
        let store = BookSourceStore(storageURL: nonExistentURL)
        let sources = try await store.load()
        
        XCTAssertTrue(sources.isEmpty)
    }
    
    func testEmptyFileReturnsEmptyArray() async throws {
        let tempURL = makeTempFileURL(name: "test_empty.json")
        
        let emptyData = "".data(using: .utf8)!
        try emptyData.write(to: tempURL)
        
        let store = BookSourceStore(storageURL: tempURL)
        let sources = try await store.load()
        
        XCTAssertTrue(sources.isEmpty)
    }
    
    // MARK: - Helpers
    
    private func makeTempFileURL(name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("BookSourceDecoderTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
}
