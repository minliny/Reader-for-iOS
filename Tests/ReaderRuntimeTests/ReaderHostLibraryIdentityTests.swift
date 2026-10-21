import Foundation
import XCTest
@testable import Reader

final class ReaderHostLibraryIdentityTests: XCTestCase {
    func testHostNamespaceSurvivesPreservedLibraryDirectoryMove() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderHostIdentity-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let before = root.appendingPathComponent("Before/LocalSources/.operations", isDirectory: true)
        let first = try ReaderHostLibraryIdentity.loadOrCreate(in: before)
        XCTAssertEqual(try ReaderHostLibraryIdentity.loadOrCreate(in: before), first)
        let originalJournal = Data("{\"originalOperation\":\"retained\"}".utf8)
        try originalJournal.write(to: before.appendingPathComponent("original-operation.json"))
        try FileManager.default.moveItem(at: root.appendingPathComponent("Before"), to: root.appendingPathComponent("After"))
        let moved = root.appendingPathComponent("After/LocalSources/.operations", isDirectory: true)
        XCTAssertEqual(try ReaderHostLibraryIdentity.loadOrCreate(in: moved), first,
            "Preserve-data installation may relocate the container without changing its Keychain service")
        XCTAssertEqual(try Data(contentsOf: moved.appendingPathComponent("original-operation.json")), originalJournal)
        XCTAssertFalse(ReaderHostLibraryIdentity.fileName.hasSuffix(".json"), "Identity is not an operation journal")
        let independent = try ReaderHostLibraryIdentity.loadOrCreate(in: root.appendingPathComponent("Other/LocalSources/.operations"))
        XCTAssertNotEqual(independent, first, "Distinct libraries retain isolated credential namespaces")
        let identity = moved.appendingPathComponent(ReaderHostLibraryIdentity.fileName)
        let corrupted = Data("preserved-invalid-identity".utf8)
        try corrupted.write(to: identity)
        XCTAssertThrowsError(try ReaderHostLibraryIdentity.loadOrCreate(in: moved))
        XCTAssertEqual(try Data(contentsOf: identity), corrupted, "Corruption must not silently select a new credential namespace")
    }
}
