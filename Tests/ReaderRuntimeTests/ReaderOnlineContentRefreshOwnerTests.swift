import Combine
import Foundation
import UIKit
import XCTest
@testable import Reader

/// Production Host ownership only. The controllable protocol replies below
/// are not Core migration, provider, HTTP, or native acceptance evidence.
/// Every displayed body is the unchanged, SHA-verified pg25332.txt original.
@MainActor
final class ReaderOnlineContentRefreshOwnerTests: XCTestCase {
    func testRefreshFreezesOldScopeThroughSolePreflightFlushAndAdoptsFreshSnapshotCASAndAnchor() async throws {
        let service = try OnlineRefreshOwnerService()
        let leases = OnlineRefreshOwnerBackgroundTasks()
        let model = try await openedModel(service, backgroundTasks: leases)
        defer { service.releasePending(); model.setForeground(true) }
        let original = try XCTUnwrap(model.reader)
        model.recordVisibleOffset(96, sessionID: original.id, restorationID: original.restorationID)
        service.holdSaves = true
        let saving = expectation(description: "The refresh owns its one old-scope save")
        service.onSave = { count in if count == 1 { saving.fulfill() } }
        let refreshing = expectation(description: "Refresh dispatch follows the acknowledged save and flush")
        service.onRefresh = { count in if count == 1 { refreshing.fulfill() } }
        let backgroundEnded = expectation(description: "The background edge has retired its work")
        leases.onEnd = { backgroundEnded.fulfill() }

        let refresh = Task { await model.refreshOnlineChapter(sessionID: original.id, restorationID: original.restorationID) }
        await fulfillment(of: [saving], timeout: 3)
        XCTAssertTrue(model.onlineChapterRefreshBusy)
        XCTAssertTrue(model.onlineChapterRefreshPending)
        XCTAssertTrue(model.sourceSwitchFrozen)
        XCTAssertTrue(model.chapterLoading)
        XCTAssertEqual(service.refreshCalls.count, 0, "The HTTP-capable adapter cannot run before the old save ACK")
        model.recordVisibleOffset(120, sessionID: original.id, restorationID: original.restorationID)
        model.setForeground(false)
        let duplicateFlush = await model.flushReading()
        XCTAssertFalse(duplicateFlush, "A public/background flush cannot borrow the refresh's private flush authority")
        XCTAssertEqual(model.reader?.scalarOffset, 96)
        XCTAssertEqual(service.saves.count, 1)

        service.holdSaves = false
        service.completeSave(0, revision: "old-scope-save-ack")
        await fulfillment(of: [refreshing, backgroundEnded], timeout: 3)
        leases.onEnd = nil
        XCTAssertEqual(service.flushCount, 1, "Only the refresh's preflight may flush the old scope")
        let request = try XCTUnwrap(service.refreshCalls.first)
        XCTAssertEqual(request.current, original.content)
        XCTAssertEqual(request.offset, 96)
        XCTAssertFalse(request.upgradeCachedContent)
        model.recordVisibleOffset(140, sessionID: original.id, restorationID: original.restorationID)
        await model.refreshOnlineChapter(sessionID: original.id, restorationID: original.restorationID)
        await model.closeReader()
        XCTAssertEqual(service.refreshCalls.count, 1)
        XCTAssertEqual(service.saves.count, 1)
        XCTAssertEqual(model.reader?.id, original.id)

        let refreshed = service.refreshedContent
        let snapshot = service.snapshot(content: refreshed, offset: 173, revision: "fresh-observed-cas")
        service.completeRefresh(.success(.init(content: refreshed, progressSnapshot: snapshot,
            positionMigration: .init(status: "committed", previousBodyVersion: try XCTUnwrap(original.content.bodyVersion),
                bodyVersion: try XCTUnwrap(refreshed.bodyVersion),
                previousProcessingVersion: try XCTUnwrap(original.content.processingVersion),
                processingVersion: try XCTUnwrap(refreshed.processingVersion),
                anchors: [.init(id: "viewport", previousOffset: 96, offset: 173)],
                progress: snapshot.progress))))
        await refresh.value
        let adopted = try XCTUnwrap(model.reader)
        XCTAssertNotEqual(adopted.id, original.id)
        XCTAssertNotEqual(adopted.restorationID, original.restorationID)
        XCTAssertEqual(adopted.content, refreshed)
        XCTAssertEqual(adopted.scalarOffset, 173)
        XCTAssertEqual(adopted.progressRevision, "fresh-observed-cas")
        XCTAssertFalse(model.onlineChapterRefreshPending)
        XCTAssertFalse(model.onlineChapterRefreshBusy)
        XCTAssertFalse(model.sourceSwitchFrozen)
        XCTAssertEqual(service.reconcileCalls.count, 0)

        // The former native surface cannot edit or refresh the adopted session.
        model.recordVisibleOffset(201, sessionID: original.id, restorationID: original.restorationID)
        model.updateSelection(start: 1, end: 4, text: String(service.originalContent.content.unicodeScalars.dropFirst().prefix(3)),
            sessionID: original.id, restorationID: original.restorationID)
        await model.refreshOnlineChapter(sessionID: original.id, restorationID: original.restorationID)
        XCTAssertEqual(model.reader?.scalarOffset, 173)
        XCTAssertNil(model.selection)
        XCTAssertEqual(service.refreshCalls.count, 1)
        model.recordVisibleOffset(181, sessionID: adopted.id, restorationID: adopted.restorationID)
        let saved = await model.flushReading()
        XCTAssertTrue(saved)
        XCTAssertEqual(service.saves.count, 2)
        let next = try XCTUnwrap(service.saves.last)
        XCTAssertEqual(next.content, refreshed)
        XCTAssertEqual(next.offset, 181)
        XCTAssertEqual(next.expectedRevision, "fresh-observed-cas", "The next write must consume the fresh observation's CAS")
    }

    func testFailedRefreshOnlyReconcilesAndKeepsSameIntentFrozenUntilExplicitObservationRecoversReading() async throws {
        let service = try OnlineRefreshOwnerService()
        let model = try await openedModel(service)
        defer { service.releasePending(); model.setForeground(true) }
        let original = try XCTUnwrap(model.reader)
        let refreshing = expectation(description: "Original explicit acquisition entered once")
        service.onRefresh = { _ in refreshing.fulfill() }
        let firstReconcile = expectation(description: "A lost refresh result requests observation only")
        service.heldReconcileCalls = [0]
        service.onReconcile = { count in if count == 1 { firstReconcile.fulfill() } }
        let refresh = Task { await model.refreshOnlineChapter(sessionID: original.id, restorationID: original.restorationID) }
        await fulfillment(of: [refreshing], timeout: 3)
        service.completeRefresh(.failure(ReaderLibraryError.operationPending("original-refresh-terminal")))
        await fulfillment(of: [firstReconcile], timeout: 3)
        service.completeReconcile(0, .failure(ReaderLibraryError.operationPending("original-refresh-terminal")))
        await refresh.value
        XCTAssertTrue(model.onlineChapterRefreshPending)
        XCTAssertTrue(model.sourceSwitchFrozen)
        XCTAssertFalse(model.onlineChapterRefreshBusy)
        XCTAssertEqual(model.reader?.id, original.id)
        XCTAssertEqual(model.reader?.restorationID, original.restorationID)
        XCTAssertEqual(model.reader?.content, original.content)
        XCTAssertNil(model.feedback, "An unknown original result has no success ACK to present")
        model.recordVisibleOffset(210, sessionID: original.id, restorationID: original.restorationID)
        await model.refreshOnlineChapter(sessionID: original.id, restorationID: original.restorationID)
        let frozenFlush = await model.flushReading()
        XCTAssertFalse(frozenFlush)
        XCTAssertTrue(service.saves.isEmpty)
        XCTAssertEqual(model.reader?.scalarOffset, original.scalarOffset)

        let failedObservation = expectation(description: "Explicit reconciliation keeps the original owner")
        service.heldReconcileCalls = [1]
        service.onReconcile = { count in if count == 2 { failedObservation.fulfill() } }
        let firstRecovery = Task { await model.reconcileOnlineChapterRefresh() }
        await fulfillment(of: [failedObservation], timeout: 3)
        service.completeReconcile(1, .failure(ReaderLibraryError.operationPending("original-refresh-terminal")))
        await firstRecovery.value
        XCTAssertTrue(model.onlineChapterRefreshPending)
        XCTAssertTrue(model.sourceSwitchFrozen)
        XCTAssertEqual(model.reader?.id, original.id)
        XCTAssertEqual(service.refreshCalls.count, 1, "Recovery must never replay force/upgrade acquisition")

        let recoveredObservation = expectation(description: "The same intent obtains an admissible cache observation")
        service.heldReconcileCalls = [2]
        service.onReconcile = { count in if count == 3 { recoveredObservation.fulfill() } }
        let secondRecovery = Task { await model.reconcileOnlineChapterRefresh() }
        await fulfillment(of: [recoveredObservation], timeout: 3)
        service.completeReconcile(2, .success(.init(content: service.refreshedContent,
            progressSnapshot: service.snapshot(content: service.refreshedContent, offset: 211, revision: "reconciled-fresh-cas"))))
        await secondRecovery.value
        let recovered = try XCTUnwrap(model.reader)
        XCTAssertFalse(model.onlineChapterRefreshPending)
        XCTAssertFalse(model.sourceSwitchFrozen)
        XCTAssertNotEqual(recovered.id, original.id)
        XCTAssertEqual(recovered.scalarOffset, 211)
        XCTAssertEqual(recovered.progressRevision, "reconciled-fresh-cas")
        XCTAssertEqual(model.feedback, "已核对当前正文与阅读位置", "Cache reconciliation restores reading; it does not confirm the original acquisition")
        XCTAssertEqual(service.refreshCalls.count, 1)
        XCTAssertEqual(service.reconcileCalls.map(\.chapterIndex), [0, 0, 0])
        XCTAssertTrue(service.reconcileCalls.allSatisfy { $0.book == original.book })
        model.recordVisibleOffset(220, sessionID: original.id, restorationID: original.restorationID)
        XCTAssertEqual(model.reader?.scalarOffset, 211)
    }

    func testFailedPreflightPositionSaveCannotDispatchRefreshOrReconciliation() async throws {
        let service = try OnlineRefreshOwnerService()
        let model = try await openedModel(service)
        defer { service.releasePending() }
        let original = try XCTUnwrap(model.reader)
        service.rejectSaves = true
        model.recordVisibleOffset(97, sessionID: original.id, restorationID: original.restorationID)
        await model.refreshOnlineChapter(sessionID: original.id, restorationID: original.restorationID)
        XCTAssertEqual(service.saves.count, 1)
        XCTAssertEqual(service.saves.first?.expectedRevision, "opening-cas")
        XCTAssertTrue(service.refreshCalls.isEmpty, "A failed old-position save cannot authorize replacement")
        XCTAssertTrue(service.reconcileCalls.isEmpty, "No replacement was dispatched, so recovery belongs to the original position save")
        XCTAssertFalse(model.onlineChapterRefreshPending)
        XCTAssertFalse(model.onlineChapterRefreshBusy)
        XCTAssertFalse(model.sourceSwitchFrozen)
        XCTAssertEqual(model.reader?.id, original.id)
        XCTAssertEqual(model.reader?.content, original.content)
        XCTAssertEqual(model.reader?.scalarOffset, 97)
        XCTAssertNotNil(model.recoveryMessage)
    }

    private func openedModel(_ service: OnlineRefreshOwnerService,
                             backgroundTasks: OnlineRefreshOwnerBackgroundTasks? = nil) async throws -> ReaderApplicationModel {
        let model = ReaderApplicationModel(service: service, backgroundTasks: backgroundTasks ?? OnlineRefreshOwnerBackgroundTasks(),
            readingTimeStorageURL: FileManager.default.temporaryDirectory.appendingPathComponent("ReaderOnlineRefreshOwner-" + UUID().uuidString))
        let opened = expectation(description: "Production model opened the verified original body")
        let observation = model.$reader.compactMap { $0 }.first().sink { _ in opened.fulfill() }
        defer { observation.cancel() }
        model.open(service.book)
        await fulfillment(of: [opened], timeout: 3)
        XCTAssertEqual(model.reader?.content.content, service.originalContent.content)
        return model
    }
}

@MainActor
private final class OnlineRefreshOwnerBackgroundTasks: ReaderBackgroundTaskManaging {
    private var next = 1
    var onEnd: (() -> Void)?
    func begin(name: String, expiration: @escaping @MainActor () -> Void) -> UIBackgroundTaskIdentifier {
        defer { next += 1 }
        return UIBackgroundTaskIdentifier(rawValue: next)
    }
    func end(_ identifier: UIBackgroundTaskIdentifier) { onEnd?() }
}

/// Protocol scheduling and DTO observations only. This fake never parses,
/// migrates, downloads, edits, or generates book text, and has no Core store.
@MainActor
private final class OnlineRefreshOwnerService: ReaderOnlineContentRefreshing {
    struct SaveCall {
        let content: ReaderChapterContent
        let offset: UInt64
        let expectedRevision: String?
    }
    struct RefreshCall {
        let current: ReaderChapterContent
        let offset: UInt64
        let upgradeCachedContent: Bool
    }
    struct ReconcileCall { let book: ReaderBook; let chapterIndex: UInt32 }
    enum Failure: Error { case rejected, unexpectedCall, releasedAtTeardown }

    let book = ReaderBook(sourceId: "owner-protocol-boundary", bookId: "https://www.gutenberg.org/ebooks/25332",
                          title: "阿Ｑ正傳", author: "Xun Lu", chapterCount: 1)
    let originalContent: ReaderChapterContent
    let refreshedContent: ReaderChapterContent
    var holdSaves = false
    var rejectSaves = false
    var heldReconcileCalls: Set<Int> = []
    var onSave: ((Int) -> Void)?
    var onRefresh: ((Int) -> Void)?
    var onReconcile: ((Int) -> Void)?
    private(set) var saves: [SaveCall] = []
    private(set) var refreshCalls: [RefreshCall] = []
    private(set) var reconcileCalls: [ReconcileCall] = []
    private(set) var flushCount = 0
    private var saveContinuations: [Int: CheckedContinuation<ReaderProgressSnapshot, Error>] = [:]
    private var refreshContinuation: CheckedContinuation<ReaderOnlineContentRefreshResult, Error>?
    private var reconcileContinuations: [Int: CheckedContinuation<ReaderOnlineContentSnapshot, Error>] = [:]

    init() throws {
        let url = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 99_898,
            digest: "997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38")
        let body = try String(contentsOf: url, encoding: .utf8)
        originalContent = ReaderChapterContent(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: 0,
            chapterTitle: book.title, content: body, bodyVersion: "owner-original-body", processingVersion: "owner-original-processing")
        // Only the observed scope identity differs. The real downloaded book
        // bytes stay unchanged; actual Core replacement is tested separately.
        refreshedContent = ReaderChapterContent(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: 0,
            chapterTitle: book.title, content: body, bodyVersion: "owner-observed-body", processingVersion: "owner-observed-processing")
    }

    func listBooks() async throws -> [ReaderBook] { [book] }
    func importBook(at url: URL) async throws -> ReaderImportResult { throw Failure.unexpectedCall }
    func chapters(for book: ReaderBook) async throws -> [ReaderChapter] { [.init(index: 0, title: book.title)] }
    func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent { originalContent }
    func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot {
        snapshot(content: originalContent, offset: 64, revision: "opening-cas")
    }
    func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                      expectedRevision: String?) async throws -> ReaderProgressSnapshot {
        let index = saves.count
        saves.append(.init(content: content, offset: scalarOffset, expectedRevision: expectedRevision))
        if rejectSaves { onSave?(saves.count); throw Failure.rejected }
        if !holdSaves { onSave?(saves.count); return snapshot(content: content, offset: scalarOffset, revision: "save-cas-\(index)") }
        return try await withCheckedThrowingContinuation { continuation in
            saveContinuations[index] = continuation
            onSave?(saves.count)
        }
    }
    func refreshOnlineContent(for book: ReaderBook, current: ReaderChapterContent,
                              scalarOffset: UInt64, upgradeCachedContent: Bool) async throws -> ReaderOnlineContentRefreshResult {
        refreshCalls.append(.init(current: current, offset: scalarOffset, upgradeCachedContent: upgradeCachedContent))
        guard refreshCalls.count == 1 else { throw Failure.unexpectedCall }
        return try await withCheckedThrowingContinuation { continuation in
            refreshContinuation = continuation
            onRefresh?(refreshCalls.count)
        }
    }
    func reconcileOnlineContent(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderOnlineContentSnapshot {
        let index = reconcileCalls.count
        reconcileCalls.append(.init(book: book, chapterIndex: chapterIndex))
        guard heldReconcileCalls.contains(index) else { throw Failure.unexpectedCall }
        return try await withCheckedThrowingContinuation { continuation in
            reconcileContinuations[index] = continuation
            onReconcile?(reconcileCalls.count)
        }
    }
    func flush() async throws { flushCount += 1 }
    func close() async throws {}
    func pendingImports() async throws -> [ReaderPendingImport] { [] }
    func recoverPendingImports() async throws -> [ReaderPendingImport] { [] }

    func snapshot(content: ReaderChapterContent, offset: UInt64, revision: String) -> ReaderProgressSnapshot {
        .init(found: true, progressRevision: revision, progress: .init(sourceId: content.sourceId, bookId: content.bookId,
            chapterIndex: content.chapterIndex, chapterOffset: offset, chapterProgress: Double(offset) / Double(content.scalarCount),
            bodyVersion: content.bodyVersion, processingVersion: content.processingVersion))
    }
    func completeSave(_ index: Int, revision: String) {
        let saved = saves[index]
        saveContinuations.removeValue(forKey: index)?.resume(returning: snapshot(content: saved.content, offset: saved.offset, revision: revision))
    }
    func completeRefresh(_ result: Result<ReaderOnlineContentRefreshResult, Error>) {
        let original = refreshContinuation
        refreshContinuation = nil
        original?.resume(with: result)
    }
    func completeReconcile(_ index: Int, _ result: Result<ReaderOnlineContentSnapshot, Error>) {
        heldReconcileCalls.remove(index)
        reconcileContinuations.removeValue(forKey: index)?.resume(with: result)
    }
    func releasePending() {
        let saves = Array(saveContinuations.values)
        saveContinuations.removeAll()
        saves.forEach { $0.resume(throwing: Failure.releasedAtTeardown) }
        completeRefresh(.failure(Failure.releasedAtTeardown))
        let reconciliations = Array(reconcileContinuations.values)
        reconcileContinuations.removeAll()
        reconciliations.forEach { $0.resume(throwing: Failure.releasedAtTeardown) }
    }
}
