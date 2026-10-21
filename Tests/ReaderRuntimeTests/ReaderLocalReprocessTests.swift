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
final class ReaderLocalReprocessTests: XCTestCase {
    func testRealOriginalReprocessChangesCoreTOCAndPreservesMetadataAndProtectedPositions() async throws {
        let fixture = try ReprocessFixture()
        defer { fixture.cleanUp() }
        // Core accepts sortIndex on first admission; an existing book's add
        // preserves its old sort. Seed the real import transaction before its
        // first shelf admission instead of pretending an upsert changes sort.
        func object(_ data: Data) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        let hash = SHA256.hash(data: fixture.original).map { String(format: "%02x", $0) }.joined()
        let source = await fixture.service.stableSource(hash)
        try fixture.original.write(to: source, options: .atomic)
        let bookID = "local:" + hash
        let parsed = try object(await fixture.service.coreRead("import.parse", ["kind": "localBook", "input": [
            "bookId": bookID, "fileName": fixture.input.lastPathComponent, "filePath": source.path,
            "title": fixture.input.deletingPathExtension().lastPathComponent
        ]]))
        let persisted = try object(await fixture.service.coreMutation("import.persist", [
            "transactionId": "reprocess-sort-fixture-" + UUID().uuidString, "parsed": parsed
        ], operationID: "persist-setup", scope: "reprocess-test-setup"))
        try await fixture.service.finishCoreOperation("persist-setup")
        let local = try XCTUnwrap((persisted["persisted"] as? [String: Any])?["data"] as? [String: Any])
        let metadata = try XCTUnwrap(local["book"] as? [String: Any])
        let token = try XCTUnwrap(persisted["rollbackToken"] as? [String: Any])
        let imported = ReaderBook(bookId: bookID, title: metadata["title"] as? String ?? "",
            author: metadata["author"] as? String ?? "")
        let admitted = try object(await fixture.service.coreMutation("bookshelf.add", ["sourceId": "local", "bookId": imported.bookId,
            "title": imported.title, "author": imported.author, "group": "保留的分组", "sortIndex": 37, "requireReadable": true],
            operationID: "shelf-setup", scope: "reprocess-test-setup"))
        XCTAssertEqual(admitted["created"] as? Bool, true)
        try await fixture.service.finishCoreOperation("shelf-setup")
        _ = try await fixture.service.coreMutation("import.finalize", ["rollbackToken": token],
            operationID: "finalize-setup", scope: "reprocess-test-setup")
        try await fixture.service.finishCoreOperation("finalize-setup")
        _ = try await fixture.service.coreMutation("bookshelf.book.update", ["sourceId": "local", "bookId": imported.bookId,
            "title": "手动编辑的书名", "author": "手动编辑的作者", "intro": "需要保留的元数据"],
            operationID: "metadata-setup", scope: "reprocess-test-setup")
        try await fixture.service.finishCoreOperation("metadata-setup")
        let beforeValue = try await fixture.service.bookDetails(for: imported)
        let before = try XCTUnwrap(beforeValue)
        XCTAssertEqual(before.sortIndex, 37, "The preservation test must start from a real non-default Core sort index")
        let chapters = try await fixture.service.chapters(for: before)
        XCTAssertEqual(chapters.count, 948)
        let first = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
        let body = try await fixture.service.content(for: before, chapterIndex: first.index)
        let observation = try await fixture.service.progress(for: before)
        _ = try await fixture.service.saveProgress(for: before, content: body, scalarOffset: 20,
            expectedRevision: observation.progressRevision)
        let bookmark = try await fixture.service.createBookmark(for: before, content: body, scalarOffset: 20,
            text: String(body.content.unicodeScalars.prefix(60)), note: "保留位置", operationID: UUID().uuidString)
        let highlight = try await fixture.service.createHighlight(for: before, content: body,
            range: .init(lowerBound: 20, upperBound: 30), style: "underline", note: "保留选文", operationID: UUID().uuidString)
        // The rule is built from genuine Core-owned TOC titles. Removing one
        // middle boundary exercises a real reparse without invented novel text.
        let occurrences = Dictionary(grouping: chapters, by: \.title)
        let omitted = try XCTUnwrap(chapters.dropFirst(20).first { occurrences[$0.title]?.count == 1 }).index
        let titles = chapters.filter { $0.index != omitted && $0.title != imported.title }.map(\.title)
        let pattern = "^(?:" + titles.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|") + ")$"
        _ = try await fixture.service.createTXTTOCRule(.init(name: "真实目录边界合并", rule: pattern), operationID: UUID().uuidString)
        let shelfDispatches = fixture.client.count("bookshelf.add")
        let operation = UUID().uuidString
        let result = try await fixture.service.reprocessLocalBook(before, operationID: operation)
        XCTAssertFalse(result.created)
        XCTAssertFalse(result.finalizationPending)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), shelfDispatches)
        let afterValue = try await fixture.service.bookDetails(for: before)
        let after = try XCTUnwrap(afterValue)
        XCTAssertEqual(after.group, before.group)
        XCTAssertEqual(after.sortIndex, 37)
        XCTAssertEqual(after.addedAt, before.addedAt)
        XCTAssertEqual(after.title, before.title)
        XCTAssertEqual(after.author, before.author)
        XCTAssertEqual(after.intro, before.intro)
        let reparsed = try await fixture.service.chapters(for: after)
        XCTAssertLessThan(reparsed.count, chapters.count)
        let progress = try await fixture.service.progress(for: after)
        let position = try XCTUnwrap(progress.progress)
        let restored = try await fixture.service.content(for: after, chapterIndex: position.chapterIndex)
        XCTAssertEqual(position.chapterOffset, 20)
        XCTAssertEqual(restored.content, body.content)
        XCTAssertEqual(position.bodyVersion, restored.bodyVersion)
        XCTAssertEqual(position.processingVersion, restored.processingVersion)
        let marks = try await fixture.service.bookmarks(for: after)
        let preservedMark = try XCTUnwrap(marks.first { $0.time == bookmark.time })
        XCTAssertEqual(preservedMark.scalarOffset, 20)
        XCTAssertEqual(preservedMark.positionScope, try ReaderContentPositionScope(book: after, content: restored))
        let highlights = try await fixture.service.highlights(for: after)
        let preservedHighlight = try XCTUnwrap(highlights.first { $0.time == highlight.time })
        XCTAssertEqual(try preservedHighlight.scalarRange(for: after, content: restored), .init(lowerBound: 20, upperBound: 30))
        let persistCount = fixture.client.count("import.persist")
        let repeated = try await fixture.service.reprocessLocalBook(before, operationID: operation)
        XCTAssertEqual(repeated, result)
        XCTAssertEqual(fixture.client.count("import.persist"), persistCount)
        let presentation = try await fixture.service.localPresentationKind(for: after)
        XCTAssertEqual(presentation.sourceId, "local")
        XCTAssertEqual(presentation.bookId, after.bookId)
        XCTAssertEqual(presentation.kind, .text)
        XCTAssertEqual(presentation.format, "txt")
        XCTAssertFalse(presentation.reimportRequired)
        try await fixture.assertSourcePreserved(for: after)
        try await fixture.service.close()
    }

    func testLateReprocessPersistACKNeverAddsShelfOrDispatchesPersistAgain() async throws {
        let fixture = try ReprocessFixture()
        defer { fixture.cleanUp() }
        let book = try await fixture.service.importBook(at: fixture.input).book
        let operation = UUID().uuidString
        let initialPersist = fixture.client.count("import.persist")
        let initialShelf = fixture.client.count("bookshelf.add")
        fixture.client.hold("import.persist")
        do { _ = try await fixture.service.reprocessLocalBook(book, operationID: operation); XCTFail("Original persist terminal is held") }
        catch ReaderLibraryError.operationPending(_) {}
        _ = try await fixture.service.bookDetails(for: book)
        do { _ = try await fixture.service.reprocessLocalBook(book, operationID: operation); XCTFail("A fresh shelf read is not the original persist ACK") }
        catch ReaderLibraryError.operationPending(_) {}
        XCTAssertEqual(fixture.client.count("import.persist"), initialPersist + 1)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), initialShelf)
        let pending = try await fixture.service.pendingFeatureOperations()
        XCTAssertEqual(pending.filter { $0.id == operation }.count, 1)
        XCTAssertFalse(try XCTUnwrap(pending.first { $0.id == operation }).acknowledged)
        fixture.client.release()
        let result = try await fixture.service.reprocessLocalBook(book, operationID: operation)
        XCTAssertFalse(result.created)
        XCTAssertEqual(fixture.client.count("import.persist"), initialPersist + 1)
        XCTAssertEqual(fixture.client.count("bookshelf.add"), initialShelf)
        let remaining = try await fixture.service.pendingFeatureOperations()
        XCTAssertFalse(remaining.contains { $0.id == operation })
        try await fixture.assertSourcePreserved(for: book)
        try await fixture.service.close()
    }

    func testLateReprocessFinalizeACKCompletesItsTombstoneWithoutRefinalizing() async throws {
        let fixture = try ReprocessFixture()
        defer { fixture.cleanUp() }
        let book = try await fixture.service.importBook(at: fixture.input).book
        let initialFinalize = fixture.client.count("import.finalize")
        let operation = UUID().uuidString
        fixture.client.hold("import.finalize")
        do { _ = try await fixture.service.reprocessLocalBook(book, operationID: operation); XCTFail("Original finalize terminal is held") }
        catch ReaderLibraryError.operationPending(_) {}
        do { _ = try await fixture.service.reprocessLocalBook(book, operationID: operation); XCTFail("The original finalize must not be dispatched twice") }
        catch ReaderLibraryError.operationPending(_) {}
        XCTAssertEqual(fixture.client.count("import.finalize"), initialFinalize + 1)
        fixture.client.release()
        let result = try await fixture.service.reprocessLocalBook(book, operationID: operation)
        let repeated = try await fixture.service.reprocessLocalBook(book, operationID: operation)
        XCTAssertEqual(repeated, result)
        XCTAssertEqual(fixture.client.count("import.finalize"), initialFinalize + 1)
        try await fixture.assertSourcePreserved(for: book)
        try await fixture.service.close()
    }

    func testOriginalCorePersistRejectionIsRetainedAndCannotRedispatchTheSameReprocessID() async throws {
        let fixture = try ReprocessFixture()
        defer { fixture.cleanUp() }
        let book = try await fixture.service.importBook(at: fixture.input).book
        let oldChapters = try await fixture.service.chapters(for: book)
        let originalCount = fixture.client.count("import.persist")
        // Fault injection changes only this request's transaction identity.
        // The real Core validator supplies the actual terminal rejection; the
        // protected original and the book's real parse corpus stay unchanged.
        fixture.client.rejectNextPersistIdentity()
        let operation = UUID().uuidString
        for _ in 0..<2 {
            do { _ = try await fixture.service.reprocessLocalBook(book, operationID: operation); XCTFail("Core must reject the invalid transport identity") }
            catch ReaderLibraryError.core(let code, _, _, _) { XCTAssertEqual(code, "INVALID_PARAMS") }
        }
        XCTAssertEqual(fixture.client.count("import.persist"), originalCount + 1)
        let chapters = try await fixture.service.chapters(for: book)
        XCTAssertEqual(chapters, oldChapters)
        let pending = try await fixture.service.pendingFeatureOperations()
        XCTAssertFalse(pending.contains { $0.id == operation })
        try await fixture.assertSourcePreserved(for: book)
        try await fixture.service.close()
    }

    func testColdUnknownPersistKeepsTheOriginalOperationAndNeverRedispatches() async throws {
        let fixture = try ReprocessFixture()
        defer { fixture.cleanUp() }
        let book = try await fixture.service.importBook(at: fixture.input).book
        let operation = UUID().uuidString
        fixture.client.hold("import.persist")
        do { _ = try await fixture.service.reprocessLocalBook(book, operationID: operation); XCTFail("Original persist terminal is held") }
        catch ReaderLibraryError.operationPending(_) {}
        fixture.client.destroy()
        let reopenedClient = try ReprocessCoreReplyGate(storage: fixture.root.appendingPathComponent("Core"))
        defer { reopenedClient.destroy() }
        let reopened = try ReaderLibraryService(storageURL: fixture.root.appendingPathComponent("Core"),
            sourceURL: fixture.root.appendingPathComponent("Sources"), client: reopenedClient,
            timing: ReaderRequestTiming(now: { reopenedClient.now }, suspend: { await Task.yield() }))
        do { _ = try await reopened.reprocessLocalBook(book, operationID: operation); XCTFail("A cold read cannot recover the missing original persist ACK") }
        catch ReaderLibraryError.operationPending(_) {}
        XCTAssertEqual(reopenedClient.count("import.parse"), 0)
        XCTAssertEqual(reopenedClient.count("import.persist"), 0)
        XCTAssertEqual(reopenedClient.count("import.finalize"), 0)
        XCTAssertEqual(reopenedClient.count("bookshelf.add"), 0)
        let pending = try await reopened.pendingFeatureOperations()
        XCTAssertTrue(pending.contains { $0.id == operation && !$0.acknowledged })
        let source = try await reopened.retainedSourceURL(for: book)
        XCTAssertEqual(try Data(contentsOf: source), fixture.original)
        XCTAssertEqual(try Data(contentsOf: fixture.input), fixture.original)
        try await reopened.close()
    }
}

@MainActor
private final class ReprocessFixture {
    let input: URL
    let original: Data
    let root: URL
    let service: ReaderLibraryService
    let client: ReprocessCoreReplyGate
    init() throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        input = documents.appendingPathComponent("仙子请听我解释.txt")
        original = try Data(contentsOf: input)
        XCTAssertEqual(original.count, 8_871_723)
        XCTAssertEqual(SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined(),
            "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5")
        root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderReprocess-" + UUID().uuidString)
        let core = root.appendingPathComponent("Core")
        try FileManager.default.createDirectory(at: core, withIntermediateDirectories: true)
        client = try ReprocessCoreReplyGate(storage: core)
        let gate = client
        service = try ReaderLibraryService(storageURL: core, sourceURL: root.appendingPathComponent("Sources"), client: client,
            timing: ReaderRequestTiming(now: { gate.now }, suspend: { await Task.yield() }))
    }
    func assertSourcePreserved(for book: ReaderBook) async throws {
        let retained = try await service.retainedSourceURL(for: book)
        XCTAssertEqual(try Data(contentsOf: retained), original)
        XCTAssertEqual(try Data(contentsOf: input), original)
    }
    func cleanUp() { client.destroy(); try? FileManager.default.removeItem(at: root) }
}

private final class ReprocessCoreReplyGate: ReaderCoreEventClient, @unchecked Sendable {
    private let native: ReaderCoreClient
    private let lock = NSLock()
    private var counts: [String: Int] = [:]
    private var method: String?
    private var heldID: UInt64?
    private var held: Result<ReaderCoreEvent, ReaderCoreClientError>?
    private var ready = false
    private var clock: TimeInterval = 0
    private var rejectPersist = false
    init(storage: URL) throws {
        native = try ReaderCoreClient(configJSON: JSONSerialization.data(withJSONObject: ["dataDirectory": storage.path]))
    }
    var now: TimeInterval { lock.lock(); defer { lock.unlock() }; return clock }
    func count(_ value: String) -> Int { lock.lock(); defer { lock.unlock() }; return counts[value, default: 0] }
    func hold(_ value: String) { lock.lock(); defer { lock.unlock() }; method = value }
    func release() { lock.lock(); defer { lock.unlock() }; ready = true }
    func rejectNextPersistIdentity() { lock.lock(); defer { lock.unlock() }; rejectPersist = true }
    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        var forwarded = params
        if method == "import.persist", rejectPersist { forwarded["transactionId"] = ""; rejectPersist = false }
        let id = try native.send(method: method, requestId: requestId, params: forwarded)
        counts[method, default: 0] += 1
        if method == self.method && heldID == nil { heldID = requestId }
        return id
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        guard requestId == heldID else { return native.pollEvent(requestId: requestId) }
        if held == nil, let reply = native.pollEvent(requestId: requestId) {
            if case .success(let event) = reply, ["result", "error"].contains(event.type) { held = reply; clock += 200 }
            else { return reply }
        }
        guard ready, let terminal = held else { return nil }
        held = nil; heldID = nil; method = nil; ready = false
        return terminal
    }
    func cancel(requestId: UInt64) throws { lock.lock(); defer { lock.unlock() }; try native.cancel(requestId: requestId) }
    func destroy() { lock.lock(); defer { lock.unlock() }; native.destroy() }
}
