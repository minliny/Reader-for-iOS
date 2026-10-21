import Combine
import Foundation
import XCTest
@testable import Reader

/// Controlled protocol replies exercise Host catalog adoption and races only.
/// They are not evidence of a real book, source, network request or native UI.
@MainActor
final class ReaderOnlineCatalogModelTests: XCTestCase {
    func testCatalogAppendPreservesLivePositionAndCASAndEnablesNewChapterNavigation() async throws {
        let service = CatalogModelService()
        let model = ReaderApplicationModel(service: service)
        try await open(model, service: service)
        let original = try XCTUnwrap(model.reader)
        let result = try await model.refreshOnlineCatalog(sessionID: original.id, bookID: original.book.id)
        let adopted = try XCTUnwrap(model.reader)
        assertPreserved(adopted, original)
        XCTAssertNotEqual(adopted.catalogGeneration, original.catalogGeneration)
        XCTAssertEqual(adopted.chapters, result.chapters)
        XCTAssertEqual(adopted.chapters.map(\.index), [0, 1, 2])
        _ = try await model.refreshOnlineCatalog(sessionID: original.id, bookID: original.book.id)
        XCTAssertEqual(model.reader?.catalogGeneration, adopted.catalogGeneration,
                       "An unchanged Core projection must not invalidate the directory on visible-offset updates")
        XCTAssertEqual(service.contentReads, [0], "Catalog adoption must not reload or replace the visible body")
        XCTAssertEqual(service.progressReads, 1, "A fresh progress read cannot substitute for the existing CAS lease")
        XCTAssertTrue(service.saves.isEmpty)

        await model.moveChapter(1)
        XCTAssertEqual(model.reader?.content.chapterIndex, 1)
        let firstFlushed = await model.flushReading()
        XCTAssertTrue(firstFlushed)
        await model.moveChapter(1)
        XCTAssertEqual(model.reader?.content.chapterIndex, 2, "The appended real catalog index must become a forward target")
        let appendedFlushed = await model.flushReading()
        XCTAssertTrue(appendedFlushed)
        await model.moveChapter(-1)
        XCTAssertEqual(model.reader?.content.chapterIndex, 1)
        let backwardFlushed = await model.flushReading()
        XCTAssertTrue(backwardFlushed)
        XCTAssertEqual(service.contentReads, [0, 1, 2, 1])
        XCTAssertEqual(service.saves.map(\.chapter), [1, 2, 1])
        XCTAssertEqual(service.saves.map(\.expectedRevision), ["lease-0", "lease-1", "lease-2"])
        XCTAssertEqual(model.reader?.id, original.id)
        await model.closeReader()
        XCTAssertNil(model.reader)
    }

    func testOlderCatalogResponseAndClosedSessionCannotReplaceCurrentCatalog() async throws {
        let service = CatalogModelService(); service.holdRefreshes = true
        defer { service.releaseRefreshes() }
        let model = ReaderApplicationModel(service: service)
        try await open(model, service: service)
        let original = try XCTUnwrap(model.reader)
        let firstDispatched = expectation(description: "First catalog read dispatched")
        let secondDispatched = expectation(description: "Newer catalog read dispatched")
        let oldSessionDispatched = expectation(description: "Catalog read for the original session dispatched")
        service.onRefresh = { count in
            if count == 1 { firstDispatched.fulfill() }
            if count == 2 { secondDispatched.fulfill() }
            if count == 3 { oldSessionDispatched.fulfill() }
        }
        let first = Task { try await model.refreshOnlineCatalog(sessionID: original.id, bookID: original.book.id) }
        await fulfillment(of: [firstDispatched], timeout: 2)
        let second = Task { try await model.refreshOnlineCatalog(sessionID: original.id, bookID: original.book.id) }
        await fulfillment(of: [secondDispatched], timeout: 2)
        service.completeRefresh(1, chapters: CatalogModelService.chapters(4))
        _ = try await second.value
        service.completeRefresh(0, chapters: CatalogModelService.chapters(3))
        do { _ = try await first.value; XCTFail("An older catalog observation must be retired") }
        catch is CancellationError { }
        XCTAssertEqual(model.reader?.chapters.map(\.index), [0, 1, 2, 3])
        assertPreserved(try XCTUnwrap(model.reader), original)

        let late = Task { try await model.refreshOnlineCatalog(sessionID: original.id, bookID: original.book.id) }
        await fulfillment(of: [oldSessionDispatched], timeout: 2)
        await model.closeReader()
        try await open(model, service: service)
        let reopened = try XCTUnwrap(model.reader)
        XCTAssertNotEqual(reopened.id, original.id)
        service.completeRefresh(2, chapters: CatalogModelService.chapters(5))
        do { _ = try await late.value; XCTFail("The old session's response must not mutate the reopened reader") }
        catch is CancellationError { }
        assertPreserved(try XCTUnwrap(model.reader), reopened)
        XCTAssertEqual(model.reader?.chapters, reopened.chapters)
        await model.closeReader()
    }

    func testReboundCurrentChapterCatalogKeepsContentPositionAndOldCatalog() async throws {
        let service = CatalogModelService()
        service.refreshedChapters[0] = ReaderChapter(index: 0, title: "Rebound", url: "catalog-contract://different-body")
        let model = ReaderApplicationModel(service: service)
        try await open(model, service: service)
        let original = try XCTUnwrap(model.reader)
        do {
            _ = try await model.refreshOnlineCatalog(sessionID: original.id, bookID: original.book.id)
            XCTFail("A changed canonical chapter URL requires position reconciliation, not adoption of the old body")
        } catch let error as ReaderLibraryError { XCTAssertEqual(error, .invalidPosition) }
        let retained = try XCTUnwrap(model.reader)
        assertPreserved(retained, original)
        XCTAssertEqual(retained.chapters, original.chapters)
        XCTAssertTrue(service.saves.isEmpty)
        XCTAssertEqual(service.progressReads, 1)
        await model.closeReader()
    }

    private func open(_ model: ReaderApplicationModel, service: CatalogModelService) async throws {
        let opened = expectation(description: "Reader opened from the protocol's original catalog")
        let subscription = model.$reader.compactMap { $0 }.first().sink { _ in opened.fulfill() }
        defer { subscription.cancel() }
        model.open(service.book)
        await fulfillment(of: [opened], timeout: 2)
        _ = try XCTUnwrap(model.reader)
    }
    private func assertPreserved(_ actual: ReaderActiveSession, _ original: ReaderActiveSession,
                                 file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.id, original.id, file: file, line: line)
        XCTAssertEqual(actual.book, original.book, file: file, line: line)
        XCTAssertEqual(actual.content, original.content, file: file, line: line)
        XCTAssertEqual(actual.scalarOffset, original.scalarOffset, file: file, line: line)
        XCTAssertEqual(actual.progressRevision, original.progressRevision, file: file, line: line)
        XCTAssertEqual(actual.restorationID, original.restorationID, file: file, line: line)
    }
}

@MainActor
private final class CatalogModelService: ReaderOnlineServing {
    enum Failure: Error { case unsupported, teardown }
    let book = ReaderBook(sourceId: "catalog-contract", bookId: "catalog-book", title: "Catalog identity contract", chapterCount: 2)
    var refreshedChapters = CatalogModelService.chapters(3)
    var holdRefreshes = false
    var onRefresh: ((Int) -> Void)?
    private var refreshCount = 0
    private var refreshes: [Int: CheckedContinuation<ReaderOnlineDetail, Error>] = [:]
    private(set) var contentReads: [UInt32] = []
    private(set) var progressReads = 0
    struct Save { let chapter: UInt32; let expectedRevision: String? }
    private(set) var saves: [Save] = []
    static func chapters(_ count: Int) -> [ReaderChapter] {
        (0..<count).map { ReaderChapter(index: UInt32($0), title: "Catalog index \($0)", url: "catalog-contract://chapter/\($0)") }
    }
    func listBooks() async throws -> [ReaderBook] { [book] }
    func chapters(for book: ReaderBook) async throws -> [ReaderChapter] { Self.chapters(2) }
    func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent {
        contentReads.append(chapterIndex)
        return ReaderChapterContent(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: chapterIndex,
            chapterTitle: "Catalog index \(chapterIndex)", content: "catalog-position:\(chapterIndex)",
            bodyVersion: "body-\(chapterIndex)", processingVersion: "processing-1")
    }
    func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot {
        progressReads += 1
        return ReaderProgressSnapshot(found: true, progressRevision: "lease-0", progress:
            ReaderProgress(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: 0, chapterOffset: 3,
                chapterProgress: 0.1, bodyVersion: "body-0", processingVersion: "processing-1"))
    }
    func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                      expectedRevision: String?) async throws -> ReaderProgressSnapshot {
        saves.append(Save(chapter: content.chapterIndex, expectedRevision: expectedRevision))
        return ReaderProgressSnapshot(found: true, progressRevision: "lease-\(saves.count)", progress:
            ReaderProgress(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: content.chapterIndex,
                chapterOffset: scalarOffset, chapterProgress: 0, bodyVersion: content.bodyVersion, processingVersion: content.processingVersion))
    }
    func refreshOnlineCatalog(for book: ReaderBook) async throws -> ReaderOnlineDetail {
        let index = refreshCount; refreshCount += 1
        if !holdRefreshes { onRefresh?(refreshCount); return detail(refreshedChapters) }
        return try await withCheckedThrowingContinuation { continuation in
            refreshes[index] = continuation; onRefresh?(refreshCount)
        }
    }
    func completeRefresh(_ index: Int, chapters: [ReaderChapter]) { refreshes.removeValue(forKey: index)?.resume(returning: detail(chapters)) }
    func releaseRefreshes() {
        let pending = refreshes; refreshes.removeAll()
        for continuation in pending.values { continuation.resume(throwing: Failure.teardown) }
    }
    private func detail(_ chapters: [ReaderChapter]) -> ReaderOnlineDetail { .init(book: book, chapters: chapters, firstReadableIndex: 0) }
    func flush() async throws {}
    func close() async throws {}
    func pendingImports() async throws -> [ReaderPendingImport] { [] }
    func recoverPendingImports() async throws -> [ReaderPendingImport] { [] }
    func importBook(at url: URL) async throws -> ReaderImportResult { throw Failure.unsupported }
    func onlineSources() async throws -> [ReaderOnlineSource] { throw Failure.unsupported }
    func importSources(_ data: Data, operationID: String) async throws -> [ReaderSourceImportItem] { throw Failure.unsupported }
    func validateSources(_ data: Data) async throws -> [ReaderSourceImportItem] { throw Failure.unsupported }
    func exportSources(_ identities: [String]?) async throws -> Data { throw Failure.unsupported }
    func updateSource(_ sourceID: String, enabled: Bool, operationID: String) async throws { throw Failure.unsupported }
    func deleteSource(_ sourceID: String, operationID: String) async throws { throw Failure.unsupported }
    func searchSource(_ sourceID: String, keyword: String, page: Int) async throws -> ReaderSourceSearchResult { throw Failure.unsupported }
    func onlineDetail(_ candidate: ReaderOnlineCandidate) async throws -> ReaderOnlineDetail { throw Failure.unsupported }
    func addOnlineBook(_ detail: ReaderOnlineDetail, chapterIndex: UInt32, operationID: String) async throws -> ReaderBook { throw Failure.unsupported }
    func onlineDiagnostic(_ sourceID: String, keyword: String) async throws -> Data { throw Failure.unsupported }
    func onlineFetch(_ url: URL) async throws -> Data { throw Failure.unsupported }
    func onlineCommand(_ method: String, parameters: Data, operationID: String?) async throws -> Data { throw Failure.unsupported }
    func prepareLogin(_ sourceID: String) async throws -> [HTTPCookie] { throw Failure.unsupported }
    func completeLogin(_ sourceID: String, cookies: [HTTPCookie], originalCookies: [HTTPCookie]) async throws { throw Failure.unsupported }
}
