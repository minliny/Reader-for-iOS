import Foundation
import CryptoKit
import XCTest
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

@MainActor
final class ReaderFeatureMutationTests: XCTestCase {
    func testLateOriginalRemoveACKProtectsSourceUntilConsumedAndNeverDeletesTheExternalFile() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let input = documents.appendingPathComponent("仙子请听我解释.txt")
        let original = try Data(contentsOf: input)
        let digest = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderFeatureACK-" + UUID().uuidString)
        let core = root.appendingPathComponent("Core")
        let sources = root.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let gate = try FeatureReplyGate(storage: core)
        defer { gate.destroy() }
        let library = try ReaderLibraryService(storageURL: core, sourceURL: sources, client: gate,
            timing: ReaderRequestTiming(now: { gate.now }, suspend: { await Task.yield() }))
        let book = try await library.importBook(at: input).book
        let source = try await library.retainedSourceURL(for: book)
        let operation = UUID().uuidString
        gate.hold("bookshelf.management.mutation.apply")
        do {
            _ = try await library.removeBooks([book], operationID: operation)
            XCTFail("The original deletion terminal is held")
        } catch ReaderLibraryError.operationPending(_) {}
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        let currentShelf = try await library.listBooks()
        XCTAssertTrue(currentShelf.isEmpty, "A fresh read may already observe the committed delete; it is still not the ACK")
        do {
            _ = try await library.removeBooks([book], operationID: operation)
            XCTFail("Unknown original delete must not be redispatched or clean assets")
        } catch ReaderLibraryError.operationPending(_) {}
        XCTAssertEqual(gate.count("bookshelf.management.mutation.apply"), 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))
        gate.release()
        let receipt = try await library.removeBooks([book], operationID: operation)
        XCTAssertEqual(receipt.removedTargets, [ReaderBookIdentity(book)])
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: input), original)
        let repeated = try await library.removeBooks([book], operationID: operation)
        XCTAssertEqual(repeated, receipt)
        XCTAssertEqual(gate.count("bookshelf.management.mutation.apply"), 1)
        try await library.close()
    }

    func testColdReopenResolvesTheExactGroupReceiptWithoutCreatingAnotherGroup() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderColdFeatureACK-" + UUID().uuidString)
        let core = root.appendingPathComponent("Core")
        let sources = root.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let firstGate = try FeatureReplyGate(storage: core)
        let first = try ReaderLibraryService(storageURL: core, sourceURL: sources, client: firstGate,
            timing: ReaderRequestTiming(now: { firstGate.now }, suspend: { await Task.yield() }))
        let operation = UUID().uuidString
        firstGate.hold("bookshelf.management.mutation.apply")
        do {
            _ = try await first.createGroup(name: "原回执分组", operationID: operation)
            XCTFail("Original group allocation ACK is held")
        } catch ReaderLibraryError.operationPending(_) {}
        XCTAssertEqual(firstGate.count("bookshelf.management.mutation.apply"), 1)
        let originalTerminal = try XCTUnwrap(firstGate.terminal)
        let originalObject = try XCTUnwrap(originalTerminal.data?["data"] as? [String: Any])
        let originalGroup = try XCTUnwrap(originalObject["group"] as? [String: Any])
        let originalID = try XCTUnwrap(originalGroup["groupId"] as? NSNumber).int64Value
        // Simulates the old process disappearing after Core committed, before
        // Host got its terminal event. The durable Host journal stays unknown.
        firstGate.destroy()
        let reopenedGate = try FeatureReplyGate(storage: core)
        defer { reopenedGate.destroy() }
        let reopened = try ReaderLibraryService(storageURL: core, sourceURL: sources, client: reopenedGate,
            timing: ReaderRequestTiming(now: { reopenedGate.now }, suspend: { await Task.yield() }))
        let restored = try await reopened.createGroup(name: "原回执分组", operationID: operation)
        XCTAssertEqual(restored.groupId, originalID)
        XCTAssertEqual(reopenedGate.count("bookshelf.management.mutation.apply"), 0)
        let groups = try await reopened.groups()
        XCTAssertEqual(groups.map(\.groupId), [originalID])
        let pending = try await reopened.pendingCoreCommands()
        XCTAssertTrue(pending.isEmpty)
        try await reopened.close()
    }
}

/// Changes scheduling only, retaining a real terminal payload produced by Core.
private final class FeatureReplyGate: ReaderHeldTerminalClient, @unchecked Sendable {
    init(storage: URL) throws {
        super.init(base: try ReaderCoreClient(configJSON: JSONSerialization.data(withJSONObject: ["dataDirectory": storage.path])))
    }
}
