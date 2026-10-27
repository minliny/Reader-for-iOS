import CryptoKit
import Foundation
import XCTest
@testable import Reader

/// Scripted transport tests cover Host ownership only. The real frozen-Core
/// exported-snapshot differential is separate; these are not source/device QA.
final class ReaderOnlineAdmissionContinuationTests: XCTestCase {
    func testExplicitChildACKKeepsOriginalUnknownAndReleasesOnlyVerifiedScope() async throws {
        let fixture = try AdmissionContinuationFixture()
        defer { fixture.cleanUp() }
        let original = try Data(contentsOf: fixture.commandURL(fixture.operation))
        let observed = try await fixture.service.resumePendingFeatureOperation(fixture.operation)
        XCTAssertEqual(observed.status, .pending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        let result = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(result.status, .continued, result.message ?? "")
        XCTAssertFalse(result.remaining)
        XCTAssertTrue(result.message?.contains("原操作回执仍未知") == true)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        XCTAssertEqual(try fixture.client.lastParameters("bookshelf.add"), fixture.parameters)
        XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation)), original)
        let admission = try fixture.admission()
        XCTAssertEqual(admission["completionKind"] as? String, "continued")
        XCTAssertNil(admission["addAcknowledged"])
        let child = fixture.operation + ":continuation:v1"
        let owner = try await fixture.service.onlineAdmissionOwnerID(forCoreOperationID: child)
        XCTAssertEqual(owner, fixture.operation)
        let pending = try await fixture.service.pendingCoreCommands()
        XCTAssertTrue(pending.contains { $0.id == fixture.operation && !$0.acknowledged })
        XCTAssertFalse(pending.contains { $0.id == child })
        let repeated = try await fixture.service.resumePendingFeatureOperation(child)
        XCTAssertEqual(repeated.status, .continued)
        _ = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        // The historical original stays unknown while a later genuine intent
        // can reserve its ordinary scope after the child ACK was verified.
        _ = try await fixture.service.coreMutation("bookshelf.add", try fixture.parameterObject(),
            operationID: "later-explicit-intent", scope: "shelf-add:" + fixture.book.id)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 2)
        XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation)), original)
    }

    func testChangedPreparationSourceCatalogShelfOrReadinessNeverDispatchesChild() async throws {
        for failure in ["preparation", "source", "chapter", "shelf", "cache", "ready"] {
            let fixture = try AdmissionContinuationFixture()
            defer { fixture.cleanUp() }
            fixture.client.failure = failure
            let original = try Data(contentsOf: fixture.commandURL(fixture.operation))
            let result = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
            XCTAssertEqual(result.status, .pending, failure)
            XCTAssertEqual(fixture.client.count("bookshelf.add"), 0, failure)
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.commandURL(fixture.operation + ":continuation:v1").path), failure)
            XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation)), original, failure)
        }
    }

    func testUnknownDispatchedChildIsNeverReplayedAfterTapOrColdRestart() async throws {
        let fixture = try AdmissionContinuationFixture()
        defer { fixture.cleanUp() }
        fixture.client.holdAdd = true
        let first = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(first.status, .pending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        let preparations = fixture.client.count("reading.entry.prepare")
        _ = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        XCTAssertEqual(fixture.client.count("reading.entry.prepare"), preparations)
        try fixture.reopen()
        let observed = try await fixture.service.resumePendingFeatureOperation(fixture.operation)
        XCTAssertEqual(observed.status, .pending)
        let cold = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(cold.status, .pending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        XCTAssertEqual(fixture.client.count("reading.entry.prepare"), 0)
        XCTAssertEqual(fixture.client.count("chapter.content"), 0)
        let pending = try await fixture.service.pendingFeatureOperations()
        XCTAssertEqual(pending.filter { $0.method == "online.admission" }.map(\.id), [fixture.operation])
    }

    func testMarkerOnlyColdRetryRevalidatesFrozenBodyBeforeAnyChildSend() async throws {
        for changeBody in [true, false] {
            let fixture = try AdmissionContinuationFixture()
            defer { fixture.cleanUp() }
            fixture.client.failure = "ready"
            let first = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
            XCTAssertEqual(first.status, .pending)
            XCTAssertNotNil(try fixture.admission()["continuation"])
            XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
            try fixture.reopen()
            if changeBody { fixture.client.bodyVersion = "changed-body" }
            let result = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
            XCTAssertEqual(result.status, changeBody ? .pending : .continued)
            XCTAssertEqual(fixture.client.count("bookshelf.add"), changeBody ? 0 : 1)
            if changeBody { XCTAssertEqual(fixture.client.count("reading.entry.prepare"), 0) }
        }
    }

    func testTimedOutOriginalOwnerBlocksContinuationEvenWithoutActiveObserver() async throws {
        let fixture = try AdmissionContinuationFixture()
        defer { fixture.cleanUp() }
        try FileManager.default.removeItem(at: fixture.commandURL(fixture.operation))
        fixture.client.holdAdd = true
        do {
            _ = try await fixture.service.coreMutation("bookshelf.add", try fixture.parameterObject(),
                operationID: fixture.operation, scope: "shelf-add:" + fixture.book.id, timeout: 0)
            XCTFail("The original reply is deliberately unknown")
        } catch ReaderLibraryError.operationPending(_) {}
        let original = try Data(contentsOf: fixture.commandURL(fixture.operation))
        let result = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(result.status, .pending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1, "Only the original send occurred")
        XCTAssertEqual(fixture.client.count("reading.entry.prepare"), 0)
        XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation)), original)
        XCTAssertNil(try fixture.admission()["continuation"])
    }

    func testExistingOtherSameBookCommandBlocksPrivateContinuationScope() async throws {
        let fixture = try AdmissionContinuationFixture()
        defer { fixture.cleanUp() }
        try fixture.seedCommand("competing-owner", method: "bookshelf.add", scope: "another-private-scope", parameters: fixture.parameters)
        let result = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(result.status, .pending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        XCTAssertNil(try fixture.admission()["continuation"])
    }

    func testPreAddColdRecoveryConsumesOriginalPreparationACKEvenBeforeCompletedWrite() async throws {
        for completed in [false, true] {
            let fixture = try AdmissionContinuationFixture(beforeFirstAdd: true, preparationCompleted: completed, entryChapterIndex: 7)
            defer { fixture.cleanUp() }
            let originalPreparation = try fixture.command(fixture.operation + ":preparation")
            try fixture.reopen()
            let observed = try await fixture.service.resumePendingFeatureOperation(fixture.operation)
            XCTAssertEqual(observed.status, .pending)
            XCTAssertEqual(fixture.client.count("reading.preparation"), 0)
            XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)

            let result = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
            XCTAssertEqual(result.status, .completed, result.message ?? "")
            XCTAssertEqual(fixture.client.count("reading.preparation"), 1, "Only the read-only status is sent; begin uses its retained ACK")
            XCTAssertEqual(fixture.client.count("reading.entry.prepare"), 1)
            XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
            XCTAssertEqual(try fixture.client.lastParameters("bookshelf.add"), fixture.parameters)
            XCTAssertEqual(try fixture.command(fixture.operation)["scope"] as? String, "shelf-add:" + fixture.book.id)
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.commandURL(fixture.operation + ":continuation:v1").path))
            let preparation = try fixture.command(fixture.operation + ":preparation")
            XCTAssertEqual(preparation["parameters"] as? String, originalPreparation["parameters"] as? String)
            XCTAssertEqual(preparation["result"] as? String, originalPreparation["result"] as? String)
            XCTAssertEqual(preparation["completed"] as? Bool, true)
            XCTAssertEqual(try fixture.admission()["addAcknowledged"] as? Bool, true)
            XCTAssertNil(try fixture.admission()["continuation"])

            try fixture.reopen()
            let cold = try await fixture.service.resumePendingFeatureOperation(fixture.operation)
            XCTAssertEqual(cold.status, .completed)
            XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
            XCTAssertEqual(fixture.client.count("reading.preparation"), 0)
        }
    }

    func testPreAddUnknownPreparationNeverDispatchesOnTapOrColdRestart() async throws {
        let fixture = try AdmissionContinuationFixture(beforeFirstAdd: true)
        defer { fixture.cleanUp() }
        try fixture.seedCommand(fixture.operation + ":preparation", method: "reading.preparation",
            scope: "online-preparation:" + fixture.book.id, parameters: fixture.preparationParameters)
        let original = try Data(contentsOf: fixture.commandURL(fixture.operation + ":preparation"))
        for _ in 0..<2 {
            let observed = try await fixture.service.resumePendingFeatureOperation(fixture.operation)
            let continued = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
            XCTAssertEqual(observed.status, .pending)
            XCTAssertEqual(continued.status, .pending)
            XCTAssertEqual(fixture.client.count("reading.preparation"), 0)
            XCTAssertEqual(fixture.client.count("reading.entry.prepare"), 0)
            XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.commandURL(fixture.operation).path))
            XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation + ":preparation")), original)
            try fixture.reopen()
        }
    }

    func testPreAddInterruptedDocumentPreparationResumesSameOwnerAfterColdRestart() async throws {
        let fixture = try AdmissionContinuationFixture(beforeFirstAdd: true)
        defer { fixture.cleanUp() }
        let preparation = try Data(contentsOf: fixture.commandURL(fixture.operation + ":preparation"))
        fixture.client.failure = "ready"
        let interrupted = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(interrupted.status, .pending)
        XCTAssertEqual(fixture.client.count("reading.entry.prepare"), 1)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.commandURL(fixture.operation).path))
        XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation + ":preparation")), preparation)
        try fixture.reopen()
        let resumed = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(resumed.status, .completed, resumed.message ?? "")
        XCTAssertEqual(fixture.client.count("reading.preparation"), 1, "Only the current status read is sent")
        XCTAssertEqual(fixture.client.count("reading.entry.prepare"), 1)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        XCTAssertNil(try fixture.admission()["continuation"])
        XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation + ":preparation")), preparation)
    }

    func testPreAddDefinitePreparationRejectionAgreesAcrossRecoveryEntrypoints() async throws {
        for observeFirst in [false, true] {
            let fixture = try AdmissionContinuationFixture(beforeFirstAdd: true)
            defer { fixture.cleanUp() }
            try fixture.seedCommand(fixture.operation + ":preparation", method: "reading.preparation",
                scope: "online-preparation:" + fixture.book.id, parameters: fixture.preparationParameters,
                completed: true, failure: ["code": "INVALID_PARAMS", "message": "Preparation rejected", "retryable": false])
            let original = try Data(contentsOf: fixture.commandURL(fixture.operation + ":preparation"))
            if observeFirst {
                let observed = try await fixture.service.resumePendingFeatureOperation(fixture.operation)
                XCTAssertEqual(observed.status, .rejected)
            }
            let first = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
            XCTAssertEqual(first.status, .rejected)
            try fixture.reopen()
            let observed = try await fixture.service.resumePendingFeatureOperation(fixture.operation)
            let repeated = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
            XCTAssertEqual(observed.status, .rejected)
            XCTAssertEqual(repeated.status, .rejected)
            XCTAssertEqual(fixture.client.count("reading.preparation"), 0)
            XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.commandURL(fixture.operation).path))
            XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation + ":preparation")), original)
        }
    }

    func testPreAddChangedIntentSourceShelfOrCompetingOwnerNeverDispatches() async throws {
        for failure in ["preparation", "pendingAdd", "entryChapter", "source", "shelf", "competing-owner"] {
            let fixture = try AdmissionContinuationFixture(beforeFirstAdd: true, entryChapterIndex: 7)
            defer { fixture.cleanUp() }
            fixture.client.failure = failure
            if failure == "competing-owner" {
                try fixture.seedCommand("competing-owner", method: "bookshelf.add", scope: "another-private-scope", parameters: fixture.parameters)
            }
            let result = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
            XCTAssertEqual(result.status, .pending, failure)
            XCTAssertEqual(fixture.client.count("reading.entry.prepare"), 0, failure)
            XCTAssertEqual(fixture.client.count("bookshelf.add"), 0, failure)
            XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.commandURL(fixture.operation).path), failure)
            XCTAssertNil(try fixture.admission()["continuation"], failure)
        }
    }

    func testPreAddUnknownFirstAddRetainsOriginalAndColdContinuationUsesOnlySeparateChild() async throws {
        let fixture = try AdmissionContinuationFixture(beforeFirstAdd: true)
        defer { fixture.cleanUp() }
        fixture.client.holdAdd = true
        let first = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(first.status, .pending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        let original = try Data(contentsOf: fixture.commandURL(fixture.operation))
        _ = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1, "The live original owner cannot be continued or replayed")
        try fixture.reopen()
        let observed = try await fixture.service.resumePendingFeatureOperation(fixture.operation)
        XCTAssertEqual(observed.status, .pending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)

        fixture.client.holdAdd = true
        let child = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(child.status, .pending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        XCTAssertEqual(try fixture.command(fixture.operation + ":continuation:v1")["scope"] as? String,
            "online-admission-continuation:" + fixture.operation)
        XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation)), original)
        try fixture.reopen()
        _ = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0, "A journaled unknown child is only reconciled")
        XCTAssertEqual(try Data(contentsOf: fixture.commandURL(fixture.operation)), original)
    }

    func testPreAddConcurrentContinuationReservesOneOriginalOwnerDuringDocumentPreparation() async throws {
        let fixture = try AdmissionContinuationFixture(beforeFirstAdd: true)
        defer { fixture.cleanUp() }
        let reached = expectation(description: "Original continuation is suspended at document preparation")
        fixture.client.holdEntryPreparation = true
        fixture.client.onEntryPreparation = { reached.fulfill() }
        let first = Task { try await fixture.service.continuePendingOnlineAdmission(fixture.operation) }
        await fulfillment(of: [reached], timeout: 2)
        let duplicate = try await fixture.service.continuePendingOnlineAdmission(fixture.operation)
        XCTAssertEqual(duplicate.status, .pending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 0)
        fixture.client.holdEntryPreparation = false
        await fixture.pause.release()
        let result = try await first.value
        XCTAssertEqual(result.status, .completed, result.message ?? "")
        XCTAssertEqual(fixture.client.count("reading.entry.prepare"), 1)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), 1)
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.commandURL(fixture.operation + ":continuation:v1").path))
    }
}

private final class AdmissionContinuationFixture {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderAdmissionHostOwnership-" + UUID().uuidString)
    let operation = "0ad35be2-67cd-43a0-b4b4-34e98814e40d"
    let book = ReaderBook(sourceId: "host-ownership-source", bookId: "host-ownership-book", title: "Host ownership", author: "")
    let parameters: Data
    let preparationParameters: Data
    let intent: [String: Any]
    let beforeFirstAdd: Bool
    let pause = AdmissionContinuationPause()
    var client: AdmissionContinuationClient
    var service: ReaderLibraryService
    var operations: URL { root.appendingPathComponent("Sources/.operations") }
    init(beforeFirstAdd: Bool = false, preparationCompleted: Bool = true, entryChapterIndex: Int? = nil) throws {
        self.beforeFirstAdd = beforeFirstAdd
        let pending: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId, "title": book.title, "author": "", "requireReadable": true]
        var add = pending; add["preparationRevision"] = 1
        parameters = try JSONSerialization.data(withJSONObject: add, options: [.sortedKeys])
        var normalized = pending; normalized["sortIndex"] = 0
        var preparationIntent: [String: Any] = ["schemaVersion": 1, "sourceId": book.sourceId, "bookId": book.bookId, "revision": 1,
            "sourceVersion": "frozen-source-version", "reason": "add", "state": "active", "updatedAt": 1, "pendingAdd": normalized]
        if let entryChapterIndex { preparationIntent["entryChapterIndex"] = entryChapterIndex }
        intent = preparationIntent
        preparationParameters = try JSONSerialization.data(withJSONObject: ["action": "begin", "reason": "add", "sourceId": book.sourceId,
            "bookId": book.bookId, "pendingAdd": pending], options: [.sortedKeys])
        client = AdmissionContinuationClient(book: book, intent: intent, beforeFirstAdd: beforeFirstAdd)
        let gate = client
        let suspension = self.pause
        service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"),
            client: gate, timing: .init(now: { gate.now }, suspend: {
                if gate.holdEntryPreparation { await suspension.suspend() } else { await Task.yield() }
            }))
        if !beforeFirstAdd { try seedCommand(operation, method: "bookshelf.add", scope: "shelf-add:" + book.id, parameters: parameters) }
        try seedCommand(operation + ":preparation", method: "reading.preparation", scope: "online-preparation:" + book.id,
            parameters: preparationParameters, result: JSONSerialization.data(withJSONObject: ["intents": [intent]]), completed: preparationCompleted)
        let owner: [String: Any] = ["operationID": operation, "book": try JSONSerialization.jsonObject(with: JSONEncoder().encode(book)),
            "chapterIndex": 0, "chapterURL": "host-ownership-chapter", "chapterTitle": "Host chapter", "preparationOperationID": operation + ":preparation"]
        let directory = operations.appendingPathComponent("online-admissions")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: owner, options: [.sortedKeys]).write(to: directory.appendingPathComponent(hash(operation) + ".json"))
    }
    func reopen() throws {
        client = AdmissionContinuationClient(book: book, intent: intent, beforeFirstAdd: beforeFirstAdd)
        let gate = client
        service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"),
            client: gate, timing: .init(now: { gate.now }, suspend: { await Task.yield() }))
    }
    func seedCommand(_ id: String, method: String, scope: String, parameters: Data, result: Data? = nil,
                     completed: Bool = false, failure: [String: Any]? = nil) throws {
        var row: [String: Any] = ["id": id, "method": method, "scope": scope, "parameters": parameters.base64EncodedString(), "completed": completed]
        if let result { row["result"] = result.base64EncodedString() }
        if let failure { row["failure"] = failure }
        try FileManager.default.createDirectory(at: operations.appendingPathComponent("commands"), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: row, options: [.sortedKeys]).write(to: commandURL(id), options: .atomic)
    }
    func parameterObject() throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: parameters) as? [String: Any]) }
    func commandURL(_ id: String) -> URL { operations.appendingPathComponent("commands/" + hash(id) + ".json") }
    func command(_ id: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: commandURL(id))) as? [String: Any])
    }
    func admission() throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: operations.appendingPathComponent("online-admissions/" + hash(operation) + ".json"))) as? [String: Any])
    }
    private func hash(_ id: String) -> String { SHA256.hash(data: Data(id.utf8)).map { String(format: "%02x", $0) }.joined() }
    func cleanUp() { try? FileManager.default.removeItem(at: root) }
}

/// Payload strings are non-content placeholders; only owner transitions,
/// method counts and immutable journals are under test.
private final class AdmissionContinuationClient: ReaderCoreEventClient, @unchecked Sendable {
    let book: ReaderBook
    let intent: [String: Any]
    let beforeFirstAdd: Bool
    private var counts: [String: Int] = [:]
    private var parameters: [String: Data] = [:]
    private var replies: [UInt64: ReaderCoreEvent] = [:]
    var failure = ""
    var bodyVersion = "frozen-body"
    var holdAdd = false
    var holdEntryPreparation = false
    var onEntryPreparation: (() -> Void)?
    private var heldEntryRequestID: UInt64?
    private var added = false
    private var clock: TimeInterval = 0
    var now: TimeInterval { clock }
    init(book: ReaderBook, intent: [String: Any], beforeFirstAdd: Bool) {
        self.book = book; self.intent = intent; self.beforeFirstAdd = beforeFirstAdd
    }
    func count(_ method: String) -> Int { counts[method, default: 0] }
    func lastParameters(_ method: String) throws -> Data? { parameters[method] }
    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        counts[method, default: 0] += 1
        parameters[method] = try JSONSerialization.data(withJSONObject: params, options: [.sortedKeys])
        var data: [String: Any]
        switch method {
        case "reading.preparation":
            XCTAssertEqual(params["action"] as? String, "status", "A retained preparation ACK must never be sent again")
            var current = intent; if failure == "preparation" { current["revision"] = 2 }
            if failure == "pendingAdd", var pending = current["pendingAdd"] as? [String: Any] {
                pending["title"] = "Changed owner"; current["pendingAdd"] = pending
            }
            if failure == "entryChapter" { current["entryChapterIndex"] = 8 }
            data = ["intents": [current]]
        case "source.list": data = ["sources": [["sourceId": book.sourceId, "enabled": true,
            "sourceVersion": failure == "source" ? "changed-source" : "frozen-source-version"]]]
        case "cache.book.status": data = ["sourceId": book.sourceId, "bookId": book.bookId, "sourceVersion": "frozen-source-version", "tocAvailable": true,
            "chapterCount": 1, "cachedCount": 1, "queuedCount": 0, "inProgressCount": 0, "completedCount": 0,
            "failedCount": 0, "cancelledCount": 0, "missingCount": 0,
            "catalogVersion": "frozen-catalog", "chapters": [["chapterIndex": 0, "title": "Host chapter", "url": failure == "chapter" ? "changed" : "host-ownership-chapter",
            "navigable": true, "state": failure == "cache" ? "missing" : "cached", "cachedBytes": 1]]]
        case "bookshelf.get": data = ["book": failure == "shelf" ? ["sourceId": book.sourceId, "bookId": book.bookId] : NSNull()]
        case "bookshelf.list": data = ["books": added ? [["sourceId": book.sourceId, "bookId": book.bookId, "title": book.title, "author": book.author]] : [],
            "total": added ? 1 : 0]
        case "reading.directory.view.open.v2": data = ["sourceId": book.sourceId, "bookId": book.bookId, "status": "ready",
            "viewId": "host-view", "catalogRevision": "host-catalog", "structureRevision": "host-structure",
            "nodes": [["nodeId": "host-chapter", "depth": 0, "title": "Host chapter", "kind": "target",
                "chapterIndex": 0, "hasChildren": false, "expanded": false]]]
        case "reading.directory.target.resolve.v2": data = ["sourceId": book.sourceId, "bookId": book.bookId,
            "viewId": "host-view", "catalogRevision": "host-catalog", "structureRevision": "host-structure",
            "nodeId": "host-chapter", "kind": "chapter", "chapterIndex": 0,
            "directoryTargetProof": ["sourceId": book.sourceId, "bookId": book.bookId,
                "catalogRevision": "host-catalog", "structureRevision": "host-structure", "nodeId": "host-chapter",
                "chapterIndex": 0, "url": "host-ownership-chapter"]]
        case "chapter.content":
            if !beforeFirstAdd { XCTAssertEqual(params["cacheOnly"] as? Bool, true) }
            data = ["sourceId": book.sourceId, "bookId": book.bookId, "chapterTitle": "Host chapter", "content": "Host owner token",
                "via": "cache", "bodyVersion": bodyVersion, "processingVersion": "frozen-processing", "contentRefreshRequired": false, "sourceCorrectionRequired": false]
        case "reading.entry.prepare":
            data = ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": 0, "kind": failure == "ready" ? "deferred" : "ready"]
            if holdEntryPreparation { heldEntryRequestID = requestId; onEntryPreparation?() }
        case "bookshelf.add":
            if holdAdd { return requestId }
            added = true
            data = ["sourceId": book.sourceId, "bookId": book.bookId, "created": true, "addedAt": 1]
        default:
            XCTFail("Unexpected method: \(method)")
            data = [:]
        }
        replies[requestId] = try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: ["protocolVersion": 1, "type": "result", "requestId": requestId, "data": data]))
        return requestId
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        if holdEntryPreparation, heldEntryRequestID == requestId { return nil }
        guard let reply = replies.removeValue(forKey: requestId) else { clock += 31; return nil }
        return .success(reply)
    }
    func cancel(requestId: UInt64) throws {}
    func destroy() {}
}

/// A deterministic suspension of one scripted reply tests actor reentrancy;
/// no timer, network delay or real upstream behavior is represented.
private actor AdmissionContinuationPause {
    private var released = false
    private var waiter: CheckedContinuation<Void, Never>?
    func suspend() async {
        guard !released else { return }
        await withCheckedContinuation { waiter = $0 }
    }
    func release() {
        released = true
        waiter?.resume()
        waiter = nil
    }
}
