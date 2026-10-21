import Foundation
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
final class ReaderDownloadReceiptTests: XCTestCase {
    func testOriginalPendingTerminalPreservesTheCommandAndConsumesExactReceiptWithoutRedispatch() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderOriginalPending-" + UUID().uuidString)
        let storage = root.appendingPathComponent("Core")
        let sources = root.appendingPathComponent("Sources")
        try FileManager.default.createDirectory(at: storage, withIntermediateDirectories: true)
        let client = try OriginalPendingReplyDecorator(storage: storage)
        defer {
            client.destroy()
            try? FileManager.default.removeItem(at: root)
        }
        let service = try ReaderLibraryService(storageURL: storage, sourceURL: sources, client: client, timing: .live)
        let operationID = UUID().uuidString
        do {
            _ = try await service.createGroup(name: "保留原请求", operationID: operationID)
            XCTFail("A terminal describing the retained original job cannot confirm or reject that job")
        } catch ReaderLibraryError.operationPending(let originalID) {
            XCTAssertEqual(originalID, operationID)
        }
        XCTAssertEqual(client.replacementCount, 1)
        XCTAssertEqual(client.count("bookshelf.management.mutation.apply"), 1)
        let originalACK = try XCTUnwrap(client.originalACK)
        XCTAssertEqual(originalACK.type, "result", "The decorator replaces only a successful real Core terminal")
        XCTAssertEqual(originalACK.data?["outcome"] as? String, "applied")
        let originalData = try XCTUnwrap(originalACK.data?["data"] as? [String: Any])
        let originalGroup = try XCTUnwrap(originalData["group"] as? [String: Any])
        let groupID = try XCTUnwrap(originalGroup["groupId"] as? NSNumber).int64Value

        let pending = try await service.pendingCoreCommands()
        XCTAssertEqual(pending.map(\.id), [operationID])
        XCTAssertEqual(pending.first?.acknowledged, false)
        let completedBeforeRecovery = try await service.isCoreOperationCompleted(operationID)
        XCTAssertFalse(completedBeforeRecovery)
        let commandDirectory = sources.appendingPathComponent(".operations/commands", isDirectory: true)
        let commandFiles = try FileManager.default.contentsOfDirectory(at: commandDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertEqual(commandFiles.count, 1)
        let journalFile = try XCTUnwrap(commandFiles.first)
        let journalObject = try JSONSerialization.jsonObject(with: Data(contentsOf: journalFile))
        let journal = try XCTUnwrap(journalObject as? [String: Any])
        XCTAssertEqual(journal["id"] as? String, operationID)
        XCTAssertEqual(journal["completed"] as? Bool, false)
        XCTAssertNil(journal["failure"], "The durable original intent must not become a rejected tombstone")
        XCTAssertNil(journal["result"])
        XCTAssertEqual(client.count("book-group.list"), 0, "No fresh business projection may acknowledge this write")

        let queriesBeforeRecovery = client.count("bookshelf.management.mutation.query")
        let recovered = try await service.resumePendingFeatureOperation(operationID)
        XCTAssertEqual(recovered.status, .completed, recovered.message ?? "The real exact receipt must resolve the retained original")
        XCTAssertFalse(recovered.remaining)
        XCTAssertEqual(client.count("bookshelf.management.mutation.apply"), 1)
        XCTAssertGreaterThan(client.count("bookshelf.management.mutation.query"), queriesBeforeRecovery)
        let originalParameters = try XCTUnwrap(client.originalParameters)
        let exactQuery = try XCTUnwrap(client.exactQuery)
        XCTAssertEqual(exactQuery["operationId"] as? String, originalParameters["operationId"] as? String)
        let expected = try XCTUnwrap(exactQuery["expected"] as? [String: Any])
        XCTAssertEqual(try JSONSerialization.data(withJSONObject: expected, options: [.sortedKeys]),
                       try JSONSerialization.data(withJSONObject: originalParameters, options: [.sortedKeys]))
        XCTAssertEqual(client.count("book-group.list"), 0)
        let afterRecovery = try await service.pendingCoreCommands()
        XCTAssertTrue(afterRecovery.isEmpty)
        let replayed = try await service.createGroup(name: "保留原请求", operationID: operationID)
        XCTAssertEqual(replayed.groupId, groupID)
        XCTAssertEqual(client.count("bookshelf.management.mutation.apply"), 1)
        // Only after the original exact receipt completed, inspect the real
        // business projection. This list is never used to settle the write.
        let groups = try await service.groups()
        XCTAssertEqual(groups.map(\.groupId), [groupID])
        XCTAssertEqual(groups.map(\.groupName), ["保留原请求"])

        let flagged = try downloadReceiptErrorEvent(requestID: 9_001, code: "INVALID_PARAMS", originalPending: true)
        do {
            _ = try await service.responseData(.success(flagged), method: "cache.book.prefetch", requestID: 9_001)
            XCTFail("originalPending must take precedence over the transport error code")
        } catch {
            XCTAssertTrue(error is ReaderCoreOriginalOperationPending)
            XCTAssertFalse(ReaderLibraryService.isDefiniteMutationRejection(error))
        }
        let validation = try downloadReceiptErrorEvent(requestID: 9_002, code: "INVALID_PARAMS", originalPending: nil)
        do {
            _ = try await service.responseData(.success(validation), method: "cache.book.prefetch", requestID: 9_002)
            XCTFail("A genuine validation rejection must remain an error")
        } catch {
            XCTAssertFalse(error is ReaderCoreOriginalOperationPending)
            XCTAssertTrue(ReaderLibraryService.isDefiniteMutationRejection(error))
        }
        try await service.close()
    }
}

private func downloadReceiptErrorEvent(requestID: UInt64, code: String, originalPending: Bool?) throws -> ReaderCoreEvent {
    var details: [String: Any] = ["reason": originalPending == true ? "original_job_retained" : "invalid_fixture_parameter"]
    if let originalPending { details["originalPending"] = originalPending }
    return try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: [
        "protocolVersion": ReaderCoreClient.protocolVersion, "type": "error", "requestId": requestID,
        "error": ["code": code, "message": "Exact original operation status probe", "retryable": false, "details": details]
    ]))
}

/// Real Core performs the group mutation. Only that one delivered terminal is
/// replaced; the immutable original receipt and its query remain Core-owned.
private final class OriginalPendingReplyDecorator: ReaderCoreEventClient, @unchecked Sendable {
    private let native: ReaderCoreClient
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var selectedRequestID: UInt64?
    private var savedOriginalACK: ReaderCoreEvent?
    private var savedParameters: [String: Any]?
    private var savedExactQuery: [String: Any]?
    private var replacements = 0

    init(storage: URL) throws {
        native = try ReaderCoreClient(configJSON: JSONSerialization.data(withJSONObject: ["dataDirectory": storage.path]))
    }
    var replacementCount: Int { lock.lock(); defer { lock.unlock() }; return replacements }
    var originalACK: ReaderCoreEvent? { lock.lock(); defer { lock.unlock() }; return savedOriginalACK }
    var originalParameters: [String: Any]? { lock.lock(); defer { lock.unlock() }; return savedParameters }
    var exactQuery: [String: Any]? { lock.lock(); defer { lock.unlock() }; return savedExactQuery }
    func count(_ method: String) -> Int { lock.lock(); defer { lock.unlock() }; return counts[method, default: 0] }

    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        let id = try native.send(method: method, requestId: requestId, params: params)
        counts[method, default: 0] += 1
        if method == "bookshelf.management.mutation.apply", selectedRequestID == nil,
           (params["mutation"] as? [String: Any])?["method"] as? String == "book-group.create" {
            selectedRequestID = requestId
            savedParameters = params
        }
        if method == "bookshelf.management.mutation.query", params["expected"] != nil { savedExactQuery = params }
        return id
    }

    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        guard let reply = native.pollEvent(requestId: requestId) else { return nil }
        guard requestId == selectedRequestID, replacements == 0,
              case .success(let event) = reply, event.type == "result" else { return reply }
        do {
            let replacement = try downloadReceiptErrorEvent(requestID: requestId, code: "BUSY", originalPending: true)
            savedOriginalACK = event
            replacements += 1
            return .success(replacement)
        } catch { return .failure(.invalidEventJSON) }
    }

    func cancel(requestId: UInt64) throws { lock.lock(); defer { lock.unlock() }; try native.cancel(requestId: requestId) }
    func retireReadRequest(requestId: UInt64) { lock.lock(); defer { lock.unlock() }; native.retireReadRequest(requestId: requestId) }
    func destroy() { lock.lock(); defer { lock.unlock() }; native.destroy() }
}
