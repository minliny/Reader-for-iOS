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

/// These tests delay an actual Core terminal event. Reads may observe the
/// committed state, but only release of the original request's reply can settle
/// its mutation owner. No success payload or business result is synthesized.
@MainActor
final class ReaderLateMutationTests: XCTestCase {
    func testLatePersistACKResumesTheOriginalImportWithoutDispatchingPersistAgain() async throws {
        let fixture = try LateMutationFixture(heldMethod: "import.persist")
        defer { fixture.cleanUp() }
        do {
            _ = try await fixture.service.importBook(at: fixture.input)
            XCTFail("The held original persist ACK must surface an unresolved import")
        } catch ReaderLibraryError.operationPending(_) {}

        let journal = try fixture.onlyJournal()
        XCTAssertEqual(journal["phase"] as? String, "persistAwaiting")
        XCTAssertNil(journal["rollbackToken"])
        XCTAssertNotNil(fixture.client.heldTerminalData)
        let before = try await fixture.service.pendingImports()
        XCTAssertEqual(before.count, 1)
        XCTAssertTrue(try XCTUnwrap(before.first).requiresReconciliation)
        let stillPending = try await fixture.service.recoverPendingImports()
        XCTAssertEqual(stillPending.count, 1)
        XCTAssertEqual(fixture.client.dispatchCount("import.persist"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("bookshelf.add"), 0)
        XCTAssertEqual(fixture.client.dispatchCount("import.rollback"), 0)

        fixture.client.releaseOriginalReply()
        let recovered = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(recovered.isEmpty)
        XCTAssertTrue(try fixture.journalURLs().isEmpty)
        XCTAssertEqual(fixture.client.dispatchCount("import.persist"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("bookshelf.add"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("import.finalize"), 1)
        try await assertRecoveredBookIsReadable(fixture)
        try await fixture.service.close()
    }

    func testShelfReadCannotReplaceTheHeldAddACKAndRecoveryDoesNotAddTwice() async throws {
        let fixture = try LateMutationFixture(heldMethod: "bookshelf.add")
        defer { fixture.cleanUp() }
        do {
            _ = try await fixture.service.importBook(at: fixture.input)
            XCTFail("The original shelf ACK is still held")
        } catch ReaderLibraryError.operationPending(_) {}

        // The real Core already committed the shelf row. This is intentionally
        // stronger than an empty read: it must still not stand in for the ACK.
        let visibleShelf = try await fixture.service.listBooks()
        XCTAssertEqual(visibleShelf.count, 1)
        let pending = try await fixture.service.recoverPendingImports()
        XCTAssertEqual(pending.count, 1)
        XCTAssertTrue(try XCTUnwrap(pending.first).requiresReconciliation)
        XCTAssertEqual(try fixture.onlyJournal()["phase"] as? String, "shelfAwaiting")
        XCTAssertEqual(fixture.client.dispatchCount("bookshelf.add"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("import.finalize"), 0)
        XCTAssertEqual(fixture.client.dispatchCount("import.rollback"), 0)

        fixture.client.releaseOriginalReply()
        let recovered = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(recovered.isEmpty)
        XCTAssertEqual(fixture.client.dispatchCount("bookshelf.add"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("import.persist"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("import.finalize"), 1)
        try await assertRecoveredBookIsReadable(fixture)
        try await fixture.service.close()
    }

    func testLateFinalizeACKRemovesItsHostJournalWithoutFinalizingTwice() async throws {
        let fixture = try LateMutationFixture(heldMethod: "import.finalize")
        defer { fixture.cleanUp() }
        let imported = try await fixture.service.importBook(at: fixture.input)
        XCTAssertTrue(imported.created)
        XCTAssertTrue(imported.finalizationPending)
        let pending = try await fixture.service.pendingImports()
        XCTAssertEqual(pending.count, 1)
        XCTAssertFalse(try XCTUnwrap(pending.first).requiresReconciliation,
                       "Shelf acknowledgement is already authoritative; only cleanup remains")
        let stillPending = try await fixture.service.recoverPendingImports()
        XCTAssertEqual(stillPending.count, 1)
        XCTAssertEqual(fixture.client.dispatchCount("import.finalize"), 1)
        XCTAssertEqual(try fixture.onlyJournal()["phase"] as? String, "finalize")

        fixture.client.releaseOriginalReply()
        let recovered = try await fixture.service.recoverPendingImports()
        XCTAssertTrue(recovered.isEmpty)
        XCTAssertTrue(try fixture.journalURLs().isEmpty)
        XCTAssertEqual(fixture.client.dispatchCount("import.finalize"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("bookshelf.add"), 1)
        try await assertRecoveredBookIsReadable(fixture)
        try await fixture.service.close()
    }

    func testLateRollbackACKAppliesTheFrozenCoreResultShapeWithoutDispatchingRollbackAgain() async throws {
        let fixture = try LateMutationFixture(heldMethod: "import.rollback")
        defer { fixture.cleanUp() }
        // A conflicting Host asset makes placement fail after real persist,
        // exercising the production compensation path without altering any Core
        // command. This pre-existing directory must remain untouched by recovery.
        let sourceBytes = try Data(contentsOf: fixture.input)
        let hash = SHA256.hash(data: sourceBytes).map { String(format: "%02x", $0) }.joined()
        let conflictingSource = fixture.sources.appendingPathComponent(hash + ".source")
        try FileManager.default.createDirectory(at: conflictingSource, withIntermediateDirectories: true)
        let protectedFile = conflictingSource.appendingPathComponent("keep.txt")
        let protectedBytes = Data("pre-existing conflicting Host bytes".utf8)
        try protectedBytes.write(to: protectedFile)
        do {
            _ = try await fixture.service.importBook(at: fixture.input)
            XCTFail("Compensation is awaiting its original rollback ACK")
        } catch ReaderLibraryError.operationPending(_) {}
        let journal = try fixture.onlyJournal()
        XCTAssertEqual(journal["phase"] as? String, "rollback")
        let operationID = try XCTUnwrap(journal["id"] as? String)
        let rawACK = try XCTUnwrap(fixture.client.heldTerminalData)
        let originalACK = try ReaderCoreEvent(data: rawACK)
        let result = try XCTUnwrap(originalACK.data)
        let rollback = try XCTUnwrap(result["data"] as? [String: Any])
        XCTAssertEqual(result["kind"] as? String, "localBook")
        XCTAssertEqual(rollback["book_id"] as? String, "local:" + hash,
                       "Frozen Core ImportRollbackData has snake_case struct-variant fields")
        XCTAssertEqual(rollback["restored"] as? Bool, true)
        let pending = try await fixture.service.recoverPendingImports()
        XCTAssertEqual(pending.count, 1)
        XCTAssertEqual(fixture.client.dispatchCount("import.rollback"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("bookshelf.add"), 0)

        fixture.client.releaseOriginalReply()
        var completion: ReaderImportRollbackCompletion?
        do {
            _ = try await fixture.service.recoverPendingImports()
            XCTFail("The original compensation ACK must project a confirmed import failure")
        } catch let failure as ReaderImportRollbackCompletion {
            completion = failure
        }
        let rolledBack = try XCTUnwrap(completion)
        XCTAssertEqual(rolledBack.operationId, operationID)
        XCTAssertNotNil(rolledBack.originalFailure)
        let recovered = try await fixture.service.pendingImports()
        XCTAssertTrue(recovered.isEmpty)
        XCTAssertTrue(try fixture.journalURLs().isEmpty)
        XCTAssertEqual(fixture.client.dispatchCount("import.persist"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("import.rollback"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("bookshelf.add"), 0)
        XCTAssertEqual(try Data(contentsOf: protectedFile), protectedBytes)
        let shelf = try await fixture.service.listBooks()
        XCTAssertTrue(shelf.isEmpty)
        try await fixture.service.close()
    }

    func testLateProgressACKPreservesItsRevisionAndFreshReadDoesNotSettleIt() async throws {
        let fixture = try LateMutationFixture()
        defer { fixture.cleanUp() }
        let imported = try await fixture.service.importBook(at: fixture.input)
        let chapters = try await fixture.service.chapters(for: imported.book)
        let first = try XCTUnwrap(chapters.first)
        let body = try await fixture.service.content(for: imported.book, chapterIndex: first.index)
        let initial = try await fixture.service.progress(for: imported.book)
        let emojiEnd = try XCTUnwrap(body.content.range(of: "🙂")).upperBound.utf16Offset(in: body.content)
        let originalOffset = ReaderTextCoordinates.scalarOffset(in: body.content, utf16Offset: emojiEnd)
        XCTAssertLessThan(originalOffset, body.scalarCount)
        fixture.client.holdFirstReply(for: "reading.progress.update")

        do {
            _ = try await fixture.service.saveProgress(for: imported.book, content: body,
                scalarOffset: originalOffset, expectedRevision: initial.progressRevision)
            XCTFail("The exact progress mutation ACK is held")
        } catch ReaderLibraryError.operationPending(_) {}
        let rawACK = try XCTUnwrap(fixture.client.heldTerminalData)
        let originalACK = try ReaderCoreEvent(data: rawACK)
        let originalRevision = try XCTUnwrap(originalACK.data?["progressRevision"] as? String)
        XCTAssertNotEqual(originalRevision, initial.progressRevision)

        let freshRead = try await fixture.service.progress(for: imported.book)
        XCTAssertEqual(freshRead.progress?.chapterOffset, originalOffset)
        XCTAssertEqual(freshRead.progressRevision, originalRevision)
        let readCount = fixture.client.dispatchCount("reading.progress.get")
        do {
            _ = try await fixture.service.reconcilePendingProgress(for: imported.book)
            XCTFail("A successful fresh read does not acknowledge the original write")
        } catch ReaderLibraryError.operationPending(_) {}
        do {
            _ = try await fixture.service.saveProgress(for: imported.book, content: body,
                scalarOffset: body.scalarCount, expectedRevision: initial.progressRevision)
            XCTFail("A new location must wait for the original update receipt")
        } catch ReaderLibraryError.operationPending(_) {}
        XCTAssertEqual(fixture.client.dispatchCount("reading.progress.update"), 1)
        XCTAssertEqual(fixture.client.dispatchCount("reading.progress.get"), readCount)

        fixture.client.releaseOriginalReply()
        let recoveredReceipt = try await fixture.service.reconcilePendingProgress(for: imported.book)
        let originalReceipt = try XCTUnwrap(recoveredReceipt)
        XCTAssertEqual(originalReceipt.progressRevision, originalRevision)
        XCTAssertEqual(originalReceipt.progress?.chapterOffset, originalOffset)
        XCTAssertEqual(fixture.client.dispatchCount("reading.progress.get"), readCount,
                       "Reconciliation must consume the held reply rather than query a new observation")
        let consumed = try await fixture.service.reconcilePendingProgress(for: imported.book)
        XCTAssertNil(consumed)

        let next = try await fixture.service.saveProgress(for: imported.book, content: body,
            scalarOffset: body.scalarCount, expectedRevision: originalReceipt.progressRevision)
        XCTAssertEqual(next.progress?.chapterOffset, body.scalarCount)
        XCTAssertNotEqual(next.progressRevision, originalRevision)
        XCTAssertEqual(fixture.client.dispatchCount("reading.progress.update"), 2)
        let confirmed = try await fixture.service.progress(for: imported.book)
        XCTAssertEqual(confirmed, next)
        try await fixture.service.close()
    }

    func testLateOriginalProgressRejectionIsDeliveredAsFailureRatherThanAcknowledgedByFreshRead() async throws {
        let fixture = try LateMutationFixture()
        defer { fixture.cleanUp() }
        let imported = try await fixture.service.importBook(at: fixture.input)
        let chapters = try await fixture.service.chapters(for: imported.book)
        let chapter = try XCTUnwrap(chapters.first)
        let body = try await fixture.service.content(for: imported.book, chapterIndex: chapter.index)
        let oldObservation = try await fixture.service.progress(for: imported.book)
        let emojiEnd = try XCTUnwrap(body.content.range(of: "🙂")).upperBound.utf16Offset(in: body.content)
        let acceptedOffset = ReaderTextCoordinates.scalarOffset(in: body.content, utf16Offset: emojiEnd)
        let accepted = try await fixture.service.saveProgress(for: imported.book, content: body,
            scalarOffset: acceptedOffset, expectedRevision: oldObservation.progressRevision)
        fixture.client.holdFirstReply(for: "reading.progress.update")

        // Core itself rejects this stale CAS. The decorator only delays that
        // actual error event; it does not manufacture a failure response.
        do {
            _ = try await fixture.service.saveProgress(for: imported.book, content: body,
                scalarOffset: body.scalarCount, expectedRevision: oldObservation.progressRevision)
            XCTFail("The held original error cannot be inferred before its reply is released")
        } catch ReaderLibraryError.operationPending(_) {}
        let rawReply = try XCTUnwrap(fixture.client.heldTerminalData)
        let originalError = try ReaderCoreEvent(data: rawReply)
        XCTAssertEqual(originalError.type, "error")
        XCTAssertEqual(originalError.coreError?.code, "INVALID_PARAMS")
        let freshRead = try await fixture.service.progress(for: imported.book)
        XCTAssertEqual(freshRead, accepted)
        do {
            _ = try await fixture.service.reconcilePendingProgress(for: imported.book)
            XCTFail("The current valid position does not resolve the separate rejected write")
        } catch ReaderLibraryError.operationPending(_) {}
        do {
            _ = try await fixture.service.saveProgress(for: imported.book, content: body,
                scalarOffset: body.scalarCount, expectedRevision: oldObservation.progressRevision)
            XCTFail("The pending original error still owns this progress operation")
        } catch ReaderLibraryError.operationPending(_) {}
        XCTAssertEqual(fixture.client.dispatchCount("reading.progress.update"), 2)

        fixture.client.releaseOriginalReply()
        var delivered: ReaderLibraryError?
        do {
            _ = try await fixture.service.reconcilePendingProgress(for: imported.book)
            XCTFail("The original Core rejection must be delivered as an error")
        } catch let failure as ReaderLibraryError {
            delivered = failure
        }
        let failure = try XCTUnwrap(delivered)
        guard case .core(let code, _, _, let reason) = failure else {
            XCTFail("Expected the original structured Core error")
            throw failure
        }
        XCTAssertEqual(code, "INVALID_PARAMS")
        XCTAssertEqual(reason, "READING_PROGRESS_CHANGED")
        XCTAssertTrue(ReaderLibraryService.isDefiniteMutationRejection(failure))
        XCTAssertFalse(ReaderLibraryService.isDefiniteMutationRejection(
            ReaderLibraryError.core(code: "INTERNAL", message: "Uncertain outcome", retryable: true, reason: nil)))
        XCTAssertFalse(ReaderLibraryService.isDefiniteMutationRejection(ReaderLibraryError.operationPending("original")))
        let consumed = try await fixture.service.reconcilePendingProgress(for: imported.book)
        XCTAssertNil(consumed)
        let retained = try await fixture.service.progress(for: imported.book)
        XCTAssertEqual(retained, accepted)
        XCTAssertEqual(fixture.client.dispatchCount("reading.progress.update"), 2)
        try await fixture.service.close()
    }

    private func assertRecoveredBookIsReadable(_ fixture: LateMutationFixture) async throws {
        let shelf = try await fixture.service.listBooks()
        XCTAssertEqual(shelf.count, 1)
        let book = try XCTUnwrap(shelf.first)
        let chapters = try await fixture.service.chapters(for: book)
        XCTAssertGreaterThanOrEqual(chapters.count, 2)
        let chapter = try XCTUnwrap(chapters.first)
        let body = try await fixture.service.content(for: book, chapterIndex: chapter.index)
        XCTAssertTrue(body.content.contains("🙂"))
        let sources = try FileManager.default.contentsOfDirectory(at: fixture.sources, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "source" }
        XCTAssertEqual(sources.count, 1)
    }
}

private struct LateMutationFixture {
    let root: URL
    let sources: URL
    let input: URL
    let client: DelayedOriginalReplyClient
    let service: ReaderLibraryService

    init(heldMethod: String? = nil) throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderLateMutation-" + UUID().uuidString)
        let storage = root.appendingPathComponent("Core", isDirectory: true)
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        try manager.createDirectory(at: storage, withIntermediateDirectories: true)
        let input = root.appendingPathComponent("原回复阅读验证.txt")
        let text = """
        第一章 初见
        甲🙂é乙。这些正文来自真实 TXT 导入，用于验证原请求回复晚到之后的目录、正文和进度。
        第二章 重逢
        原操作的回执必须继续属于原操作。新的读取结果不能替代旧写入的确认。
        """
        try Data(text.utf8).write(to: input)
        let clock = LateMutationClock()
        let config = try JSONSerialization.data(withJSONObject: ["dataDirectory": storage.path])
        let client = DelayedOriginalReplyClient(base: try ReaderCoreClient(configJSON: config), clock: clock)
        if let heldMethod { client.holdFirstReply(for: heldMethod) }
        let timing = ReaderRequestTiming(now: { clock.now }, suspend: { await Task.yield() })
        self.root = root
        self.sources = sources
        self.input = input
        self.client = client
        self.service = try ReaderLibraryService(storageURL: storage, sourceURL: sources, client: client, timing: timing)
    }

    func journalURLs() throws -> [URL] {
        try FileManager.default.contentsOfDirectory(at: sources.appendingPathComponent(".operations"), includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
    }

    func onlyJournal() throws -> [String: Any] {
        let paths = try journalURLs()
        XCTAssertEqual(paths.count, 1)
        let path = try XCTUnwrap(paths.first)
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: path)) as? [String: Any])
    }

    func cleanUp() {
        client.destroy()
        try? FileManager.default.removeItem(at: root)
    }
}

private final class LateMutationClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value: TimeInterval = 0
    var now: TimeInterval { lock.lock(); defer { lock.unlock() }; return value }
    func advancePastDeadline() { lock.lock(); defer { lock.unlock() }; value += 200 }
}

/// Only scheduling changes: the original Core client still executes every
/// production command with unchanged params and produces every terminal payload.
private final class DelayedOriginalReplyClient: ReaderCoreEventClient, @unchecked Sendable {
    private let base: ReaderCoreClient
    private let clock: LateMutationClock
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var heldMethod: String?
    private var heldID: UInt64?
    private var heldReply: Result<ReaderCoreEvent, ReaderCoreClientError>?
    private var released = false

    init(base: ReaderCoreClient, clock: LateMutationClock) { self.base = base; self.clock = clock }

    func holdFirstReply(for method: String) {
        lock.lock(); defer { lock.unlock() }
        precondition(heldID == nil && heldReply == nil)
        heldMethod = method
        released = false
    }

    func releaseOriginalReply() {
        lock.lock(); defer { lock.unlock() }
        precondition(heldReply != nil, "The test must first capture an actual terminal reply")
        released = true
    }

    var heldTerminalData: Data? {
        lock.lock(); defer { lock.unlock() }
        if case .success(let event)? = heldReply { return event.rawData }
        return nil
    }

    func dispatchCount(_ method: String) -> Int {
        lock.lock(); defer { lock.unlock() }
        return counts[method, default: 0]
    }

    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        let result = try base.send(method: method, requestId: requestId, params: params)
        counts[method, default: 0] += 1
        if method == heldMethod && heldID == nil { heldID = requestId }
        return result
    }

    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        guard requestId == heldID else { return base.pollEvent(requestId: requestId) }
        if heldReply == nil, let reply = base.pollEvent(requestId: requestId) {
            if case .success(let event) = reply, ["result", "error"].contains(event.type) {
                heldReply = reply
                // This occurs only after Core has produced its real reply. The
                // original request observes a soft deadline before seeing it.
                clock.advancePastDeadline()
            } else {
                return reply
            }
        }
        guard released, let reply = heldReply else { return nil }
        heldReply = nil
        heldID = nil
        heldMethod = nil
        released = false
        return reply
    }

    func cancel(requestId: UInt64) throws {
        lock.lock(); defer { lock.unlock() }
        try base.cancel(requestId: requestId)
    }

    func destroy() {
        lock.lock(); defer { lock.unlock() }
        base.destroy()
    }
}
