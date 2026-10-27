import Combine
import Foundation
import UIKit
import XCTest
@testable import Reader

@MainActor
final class ReaderApplicationModelTests: XCTestCase {
    private let book = ApplicationModelServiceFake.sampleBook

    /// Draft ownership at the production ACK consumer only. This makes no
    /// Core-write or native sheet lifecycle acceptance claim.
    func testGroupDraftOriginalSaveACKClearsOnlyItsSubmissionAcrossEditsAndPresentationReopen() {
        for boundary in 0..<7 {
            let shelf = ReaderShelfPresentation()
            let draft = shelf.groupDraft
            let presentation = UUID()
            draft.activate(presentation)
            let original = ReaderBookGroup(groupId: 1, groupName: "First group")
            let other = ReaderBookGroup(groupId: 2, groupName: "Other group")
            draft.editing = original
            draft.name = original.groupName
            let submitted = draft.submission()
            var nextSubmission: ReaderGroupDraftOwner.Submission?
            switch boundary {
            case 1:
                draft.name = "  " + original.groupName + "  "
                XCTAssertEqual(draft.name.trimmingCharacters(in: .whitespacesAndNewlines), submitted.title)
            case 2:
                draft.name = "New input"
                draft.name = original.groupName
            case 3:
                draft.editing = other
            case 4:
                draft.editing = other
                draft.editing = original
            case 5, 6:
                draft.retire(presentation)
                let reopened = shelf.groupDraft
                XCTAssertTrue(reopened === draft, "Closing and reopening must retain the shelf's one draft owner")
                reopened.activate(UUID())
                if boundary == 6 { reopened.name = "Input after reopening" }
                nextSubmission = reopened.submission()
                draft.retire(presentation) // A late old dismissal cannot retire the new presentation.
            default: break
            }
            let currentSubmission = nextSubmission ?? draft.submission()
            let retainedName = draft.name, retainedEditing = draft.editing
            let consumed = draft.consumeSaved(submitted)
            XCTAssertEqual(consumed, boundary == 0, "boundary \(boundary)")
            if boundary == 0 {
                XCTAssertEqual(draft.name, "")
                XCTAssertNil(draft.editing)
            } else {
                XCTAssertEqual(draft.name, retainedName, "boundary \(boundary)")
                XCTAssertEqual(draft.editing, retainedEditing, "boundary \(boundary)")
                // A later explicit save can own this still-present input.
                XCTAssertTrue(draft.consumeSaved(currentSubmission), "boundary \(boundary)")
            }
            draft.name = "A later draft"
            XCTAssertFalse(draft.consumeSaved(submitted), "An old completion cannot clear a later draft")
            XCTAssertEqual(draft.name, "A later draft")
        }
    }

    func testOnlineReadingFailureMessagesKeepCacheAndNetworkOutcomesDistinct() {
        XCTAssertEqual(
            ReaderApplicationModel.readingFailureMessage(
                ReaderLibraryError.core(code: "INVALID_PARAMS", message: "cache", retryable: false, reason: "CACHE_MISSING"),
                opening: true),
            "本章尚未缓存，请联网后重试")
        XCTAssertEqual(
            ReaderApplicationModel.readingFailureMessage(
                ReaderLibraryError.core(code: "INTERNAL", message: "network", retryable: true, reason: "NETWORK_ENVIRONMENT"),
                opening: false),
            "网络未完成，已保留当前正文")
        XCTAssertEqual(
            ReaderApplicationModel.readingFailureMessage(
                ReaderLibraryError.core(code: "INTERNAL", message: "retry", retryable: true, reason: nil),
                opening: true),
            "网络请求未完成，请联网后重试")
    }

    func testScopedOnlineJumpClassifiesCoreFailuresAndPreservesBodyAndPosition() async throws {
        // These protocol replies exercise the production model only. They do
        // not establish real source, transport, or OS-offline behavior.
        let onlineBook = ReaderBook(sourceId: "online-model-test", bookId: "model-book", title: "Model jump", chapterCount: 2)
        let failures: [(ReaderLibraryError, String)] = [
            (.core(code: "INVALID_PARAMS", message: "cache unavailable", retryable: false, reason: "CACHE_MISSING"),
             "本章尚未缓存，已保留当前正文"),
            (.core(code: "INTERNAL", message: "request failed", retryable: true, reason: "NETWORK_ENVIRONMENT"),
             "网络未完成，已保留当前正文")
        ]
        for selectedBook in [onlineBook, book] {
            let service = ApplicationModelServiceFake()
            service.openingProgress = ReaderProgressSnapshot(found: true, progressRevision: "original-position", progress:
                ReaderProgress(sourceId: selectedBook.sourceId, bookId: selectedBook.bookId, chapterIndex: 0,
                               chapterOffset: 37, chapterProgress: 0.37, bodyVersion: "body-0", processingVersion: "processing-1"))
            let model = try await openedModel(service, book: selectedBook)
            let original = try XCTUnwrap(model.reader)
            let scope = ReaderContentPositionScope(sourceId: selectedBook.sourceId, bookId: selectedBook.bookId,
                chapterIndex: 1, bodyVersion: "body-1", processingVersion: "processing-1")
            for (failure, onlineMessage) in failures {
                service.contentError = failure
                await model.jump(scope: scope, scalarOffset: 12)
                XCTAssertEqual(model.feedback, selectedBook.sourceId == "local" ? failure.localizedDescription : onlineMessage)
                XCTAssertEqual(model.reader?.id, original.id)
                XCTAssertEqual(model.reader?.book, original.book)
                XCTAssertEqual(model.reader?.content, original.content)
                XCTAssertEqual(model.reader?.scalarOffset, 37)
                XCTAssertEqual(model.reader?.progressRevision, original.progressRevision)
                XCTAssertEqual(model.reader?.restorationID, original.restorationID)
                XCTAssertFalse(model.chapterLoading)
                XCTAssertTrue(service.saves.isEmpty)
                XCTAssertEqual(service.flushCount, 0, "A failed body read must not flush or publish the target position")
            }
            service.contentError = nil
            let staleScope = ReaderContentPositionScope(sourceId: selectedBook.sourceId, bookId: selectedBook.bookId,
                chapterIndex: 1, bodyVersion: "stale-body", processingVersion: "processing-1")
            await model.jump(scope: staleScope, scalarOffset: 12)
            XCTAssertEqual(model.feedback, ReaderLibraryError.invalidPosition.localizedDescription)
            XCTAssertEqual(model.reader?.content, original.content)
            XCTAssertEqual(model.reader?.scalarOffset, 37)
            XCTAssertEqual(model.reader?.restorationID, original.restorationID)
            let readsBeforeInvalidIdentity = service.contentReadCount
            let foreignScope = ReaderContentPositionScope(sourceId: "another-model-source", bookId: selectedBook.bookId,
                chapterIndex: 1, bodyVersion: "body-1", processingVersion: "processing-1")
            await model.jump(scope: foreignScope, scalarOffset: 12)
            XCTAssertEqual(service.contentReadCount, readsBeforeInvalidIdentity)
            XCTAssertEqual(model.feedback, ReaderLibraryError.invalidPosition.localizedDescription)
            XCTAssertEqual(model.reader?.content, original.content)
            XCTAssertEqual(model.reader?.scalarOffset, 37)
            XCTAssertEqual(model.reader?.restorationID, original.restorationID)
            XCTAssertFalse(model.chapterLoading)
            XCTAssertTrue(service.saves.isEmpty)
            XCTAssertEqual(service.flushCount, 0)
        }
    }

    func testReadingWindowPartialFailureReportsOncePerSessionAndPreservesCurrentBodyAndPosition() async throws {
        // Controlled protocol results prove model ownership only, not genuine
        // source acquisition, transport failure, or OS-offline acceptance.
        let service = ApplicationModelServiceFake()
        service.holdCacheWindows = true
        defer { service.releasePendingRequests() }
        let onlineBook = ReaderBook(sourceId: "online-model-test", bookId: "window-model", title: "Model window", chapterCount: 2)
        service.openingProgress = ReaderProgressSnapshot(found: true, progressRevision: "original-window-position", progress:
            ReaderProgress(sourceId: onlineBook.sourceId, bookId: onlineBook.bookId, chapterIndex: 0,
                           chapterOffset: 37, chapterProgress: 0.37, bodyVersion: "body-0", processingVersion: "processing-1"))
        let firstRequest = expectation(description: "The original online window is awaiting its result")
        service.onCacheWindow = { count in if count == 1 { firstRequest.fulfill() } }
        let model = try await openedModel(service, book: onlineBook)
        await fulfillment(of: [firstRequest], timeout: 2)
        let original = try XCTUnwrap(model.reader)
        var messages: [String] = []
        let firstFeedback = expectation(description: "One confirmed adjacent failure is presented")
        let reopenedFeedback = expectation(description: "A later reader session may report its own failure")
        let observation = model.$feedback.compactMap { $0 }.sink { message in
            messages.append(message)
            if messages.count == 1 { firstFeedback.fulfill() }
            if messages.count == 2 { reopenedFeedback.fulfill() }
        }
        defer { observation.cancel() }
        let partial = ReaderReadingCacheWindow(requestedIndexes: [1], cachedIndexes: [], failedIndexes: [1])
        service.completeCacheWindow(0, result: .success(partial))
        await fulfillment(of: [firstFeedback], timeout: 2)
        XCTAssertEqual(messages, ["相邻章节缓存未完成"])
        XCTAssertEqual(model.reader?.id, original.id)
        XCTAssertEqual(model.reader?.book, original.book)
        XCTAssertEqual(model.reader?.content, original.content)
        XCTAssertEqual(model.reader?.scalarOffset, original.scalarOffset)
        XCTAssertEqual(model.reader?.progressRevision, original.progressRevision)
        XCTAssertEqual(model.reader?.restorationID, original.restorationID)
        XCTAssertNil(model.recoveryMessage)
        XCTAssertTrue(service.saves.isEmpty)
        XCTAssertEqual(service.flushCount, 0)

        let nextRequest = expectation(description: "Changing chapter schedules a fresh window in the same session")
        service.onCacheWindow = { count in if count == 2 { nextRequest.fulfill() } }
        await model.changeChapter(to: 1)
        await fulfillment(of: [nextRequest], timeout: 2)
        XCTAssertNil(model.feedback, "Retiring a window clears only its own displayed feedback")
        service.completeCacheWindow(1, result: .success(.init(requestedIndexes: [0], cachedIndexes: [], failedIndexes: [0])))
        await service.waitForCacheWindowReturn(1)
        XCTAssertNil(model.feedback)
        XCTAssertEqual(messages.count, 1, "Repeated adjacent failures must not notify again in this reading session")

        await model.closeReader()
        let reopenedRequest = expectation(description: "A newly opened reader owns a distinct cache window")
        service.onCacheWindow = { count in if count == 3 { reopenedRequest.fulfill() } }
        model.open(onlineBook)
        await fulfillment(of: [reopenedRequest], timeout: 2)
        XCTAssertNotEqual(model.reader?.id, original.id)
        service.completeCacheWindow(2, result: .success(partial))
        await fulfillment(of: [reopenedFeedback], timeout: 2)
        XCTAssertEqual(messages, ["相邻章节缓存未完成", "相邻章节缓存未完成"])
    }

    func testReadingWindowFeedbackDoesNotReplaceOrClearAnotherOperationFeedback() async throws {
        let service = ApplicationModelServiceFake()
        service.holdCacheWindows = true
        defer { service.releasePendingRequests() }
        let onlineBook = ReaderBook(sourceId: "online-model-test", bookId: "window-priority", title: "Model priority", chapterCount: 2)
        let firstRequest = expectation(description: "The online window has started")
        service.onCacheWindow = { count in if count == 1 { firstRequest.fulfill() } }
        let model = try await openedModel(service, book: onlineBook)
        await fulfillment(of: [firstRequest], timeout: 2)
        let partial = ReaderReadingCacheWindow(requestedIndexes: [1], cachedIndexes: [], failedIndexes: [1])
        model.showFeedback("书签已保存")
        service.completeCacheWindow(0, result: .success(partial))
        await service.waitForCacheWindowReturn(0)
        XCTAssertEqual(model.feedback, "书签已保存", "Opportunistic caching cannot replace an operation's feedback")

        model.setForeground(false)
        let secondRequest = expectation(description: "Foreground admission retries the same reader window owner")
        service.onCacheWindow = { count in if count == 2 { secondRequest.fulfill() } }
        model.setForeground(true)
        await fulfillment(of: [secondRequest], timeout: 2)
        let feedback = expectation(description: "Skipping a higher-priority message did not consume the session notification")
        let observation = model.$feedback.first(where: { $0 == "相邻章节缓存未完成" }).sink { _ in feedback.fulfill() }
        defer { observation.cancel() }
        service.completeCacheWindow(1, result: .success(partial))
        await fulfillment(of: [feedback], timeout: 2)
        model.showFeedback("其他操作已完成")
        let nextRequest = expectation(description: "A chapter change retires the cache-owned feedback token")
        service.onCacheWindow = { count in if count == 3 { nextRequest.fulfill() } }
        await model.changeChapter(to: 1)
        await fulfillment(of: [nextRequest], timeout: 2)
        XCTAssertEqual(model.feedback, "其他操作已完成", "Retiring the old cache token cannot clear its replacement")
        service.completeCacheWindow(2, result: .success(.init(requestedIndexes: [0], cachedIndexes: [0], failedIndexes: [])))
        await service.waitForCacheWindowReturn(2)
        XCTAssertEqual(model.feedback, "其他操作已完成")
    }

    func testReadingWindowUnconfirmedErrorsAndRetiredResultsStaySilent() async throws {
        let service = ApplicationModelServiceFake()
        service.holdCacheWindows = true
        defer { service.releasePendingRequests() }
        let onlineBook = ReaderBook(sourceId: "online-model-test", bookId: "window-retired", title: "Model retired window", chapterCount: 2)
        let firstRequest = expectation(description: "The first window is awaiting a result")
        service.onCacheWindow = { count in if count == 1 { firstRequest.fulfill() } }
        let model = try await openedModel(service, book: onlineBook)
        await fulfillment(of: [firstRequest], timeout: 2)
        var messages: [String] = []
        let observation = model.$feedback.compactMap { $0 }.sink { messages.append($0) }
        defer { observation.cancel() }
        let unconfirmedErrors: [Error] = [CancellationError(), ReaderLibraryError.busy,
            ReaderLibraryError.invalidResponse("window status unavailable")]
        for (index, error) in unconfirmedErrors.enumerated() {
            service.completeCacheWindow(index, result: .failure(error))
            await service.waitForCacheWindowReturn(index)
            XCTAssertNil(model.feedback)
            model.setForeground(false)
            let requested = expectation(description: "The next active window is admitted after an unconfirmed result")
            service.onCacheWindow = { count in if count == index + 2 { requested.fulfill() } }
            model.setForeground(true)
            await fulfillment(of: [requested], timeout: 2)
        }
        let partial = ReaderReadingCacheWindow(requestedIndexes: [1], cachedIndexes: [], failedIndexes: [1])
        model.setForeground(false)
        service.completeCacheWindow(3, result: .success(partial))
        await service.waitForCacheWindowReturn(3)
        XCTAssertNil(model.feedback, "An inactive window cannot publish even when it later returns confirmed chapter failures")

        let oldRequest = expectation(description: "An active window is held while the chapter changes")
        service.onCacheWindow = { count in if count == 5 { oldRequest.fulfill() } }
        model.setForeground(true)
        await fulfillment(of: [oldRequest], timeout: 2)
        let currentRequest = expectation(description: "The new chapter owns a later window")
        service.onCacheWindow = { count in if count == 6 { currentRequest.fulfill() } }
        await model.changeChapter(to: 1)
        await fulfillment(of: [currentRequest], timeout: 2)
        let current = try XCTUnwrap(model.reader)
        service.completeCacheWindow(4, result: .success(partial))
        await service.waitForCacheWindowReturn(4)
        XCTAssertNil(model.feedback, "The prior chapter's callback has lost its window and content identity")
        service.completeCacheWindow(5, result: .success(.init(requestedIndexes: [0], cachedIndexes: [0], failedIndexes: [])))
        await service.waitForCacheWindowReturn(5)
        XCTAssertTrue(messages.isEmpty)
        XCTAssertEqual(model.reader?.content, current.content)
        XCTAssertEqual(model.reader?.scalarOffset, current.scalarOffset)
        XCTAssertEqual(model.reader?.restorationID, current.restorationID)
        XCTAssertNil(model.recoveryMessage)
    }

    private func openedModel(_ service: ApplicationModelServiceFake,
                             book selectedBook: ReaderBook? = nil,
                             backgroundTasks: (any ReaderBackgroundTaskManaging)? = nil) async throws -> ReaderApplicationModel {
        let model = ReaderApplicationModel(service: service, backgroundTasks: backgroundTasks)
        let opened = expectation(description: "Core content was projected into a reader session")
        let observation = model.$reader.compactMap { $0 }.first().sink { _ in opened.fulfill() }
        defer { observation.cancel() }
        model.open(selectedBook ?? book)
        await fulfillment(of: [opened], timeout: 2)
        _ = try XCTUnwrap(model.reader)
        return model
    }

    func testOlderShelfResponseCannotReplaceNewerRefresh() async {
        let service = ApplicationModelServiceFake()
        service.holdLists = true
        defer { service.releasePendingRequests() }
        let firstRequested = expectation(description: "First refresh dispatched")
        let secondRequested = expectation(description: "Second refresh dispatched")
        service.onList = { count in
            if count == 1 { firstRequested.fulfill() }
            if count == 2 { secondRequested.fulfill() }
        }
        let model = ReaderApplicationModel(service: service)
        let first = Task { await model.reloadLibrary() }
        await fulfillment(of: [firstRequested], timeout: 2)
        let second = Task { await model.reloadLibrary() }
        await fulfillment(of: [secondRequested], timeout: 2)
        let newer = ReaderBook(bookId: "local:new", title: "Newer shelf")
        service.completeList(1, books: [newer])
        await second.value
        service.completeList(0, books: [book])
        await first.value
        XCTAssertEqual(model.books, [newer])
        XCTAssertEqual(model.libraryState, .ready)
    }

    func testDismissedImportWithUnknownWriteOutcomeRemainsUnresolved() async throws {
        let service = ApplicationModelServiceFake()
        service.holdImports = true
        defer { service.releasePendingRequests() }
        let dispatched = expectation(description: "Import dispatched")
        let unresolved = expectation(description: "Unknown mutation outcome stays unresolved")
        service.onImport = { _ in dispatched.fulfill() }
        let model = ReaderApplicationModel(service: service)
        let observation = model.$importOperation.compactMap { $0 }
            .first(where: { $0.phase == .unresolved }).sink { _ in unresolved.fulfill() }
        defer { observation.cancel() }
        model.importFile(URL(fileURLWithPath: "/selection/first.txt"))
        await fulfillment(of: [dispatched], timeout: 2)
        let operation = try XCTUnwrap(model.importOperation)
        model.importResultVisible = false
        service.pending = [ReaderPendingImport(id: "opaque-import-receipt", fileName: "first.txt", requiresReconciliation: true)]
        service.completeImport(.failure(ReaderLibraryError.operationPending("opaque-import-receipt")))
        await fulfillment(of: [unresolved], timeout: 2)
        XCTAssertEqual(model.importOperation?.id, operation.id)
        XCTAssertEqual(model.importOperation?.phase, .unresolved)
        XCTAssertTrue(model.importBusy)
        XCTAssertFalse(model.importResultVisible, "Finishing the task must not reopen a dismissed result surface")
        model.importFile(URL(fileURLWithPath: "/selection/second.txt"))
        XCTAssertEqual(service.importCount, 1, "An unresolved original mutation must not dispatch a replacement")
        XCTAssertTrue(model.importResultVisible)
    }

    func testAcknowledgedImportWithCleanupPendingDoesNotBlockTheNextImport() async {
        let service = ApplicationModelServiceFake()
        service.importResult = ReaderImportResult(book: book, created: true, finalizationPending: true)
        let model = ReaderApplicationModel(service: service)
        let completed = expectation(description: "Shelf acknowledgement is presented as completed")
        let observation = model.$importOperation.compactMap { $0 }
            .first(where: { $0.phase == .completed }).sink { _ in completed.fulfill() }
        defer { observation.cancel() }
        model.importFile(URL(fileURLWithPath: "/selection/first.txt"))
        await fulfillment(of: [completed], timeout: 2)
        XCTAssertFalse(model.importBusy)
        service.holdImports = true
        defer { service.releasePendingRequests() }
        let nextDispatched = expectation(description: "Another import remains available")
        service.onImport = { count in if count == 2 { nextDispatched.fulfill() } }
        model.importFile(URL(fileURLWithPath: "/selection/second.txt"))
        await fulfillment(of: [nextDispatched], timeout: 2)
        XCTAssertEqual(service.importCount, 2)
    }

    func testStartupProjectsUnresolvedImportWithoutInventingAFailedWrite() async {
        let service = ApplicationModelServiceFake()
        service.pending = [ReaderPendingImport(id: "opaque-pending", fileName: "pending.txt", requiresReconciliation: true)]
        let model = ReaderApplicationModel(service: service)
        await model.start()
        XCTAssertEqual(service.recoverCount, 1)
        XCTAssertEqual(model.importOperation?.phase, .unresolved)
        XCTAssertTrue(model.importBusy)
        XCTAssertEqual(model.books, [book])
        XCTAssertEqual(model.libraryState, .ready)
    }

    func testCleanupOnlyStartupRecordDoesNotLockImport() async {
        let service = ApplicationModelServiceFake()
        service.pending = [ReaderPendingImport(id: "cleanup", fileName: "imported.txt", requiresReconciliation: false)]
        let model = ReaderApplicationModel(service: service)
        await model.start()
        XCTAssertEqual(service.recoverCount, 1)
        XCTAssertFalse(model.importBusy)
        XCTAssertNotEqual(model.importOperation?.phase, .unresolved)
    }

    func testInFlightSaveCoalescesLatestLocationAndCarriesForwardTheAcknowledgedRevision() async throws {
        let service = ApplicationModelServiceFake()
        service.holdSaves = true
        defer { service.releasePendingRequests() }
        let model = try await openedModel(service)
        let firstDispatched = expectation(description: "First location dispatched")
        let latestDispatched = expectation(description: "Only the newest queued location dispatched next")
        service.onSave = { count in
            if count == 1 { firstDispatched.fulfill() }
            if count == 2 { latestDispatched.fulfill() }
        }
        model.seek(to: 0.2)
        await fulfillment(of: [firstDispatched], timeout: 2)
        model.seek(to: 0.5)
        model.seek(to: 0.8)
        XCTAssertEqual(service.saves.count, 1)
        service.completeSave(0, revision: "revision-1")
        await fulfillment(of: [latestDispatched], timeout: 2)
        XCTAssertEqual(service.saves.map(\.offset), [20, 80])
        XCTAssertEqual(service.saves[0].expectedRevision, "revision-0")
        XCTAssertEqual(service.saves[1].expectedRevision, "revision-1")
        let acknowledged = expectation(description: "Latest location acknowledged")
        let observation = model.$reader.compactMap { $0 }
            .first(where: { $0.progressRevision == "revision-2" }).sink { _ in acknowledged.fulfill() }
        defer { observation.cancel() }
        service.completeSave(1, revision: "revision-2")
        await fulfillment(of: [acknowledged], timeout: 2)
        let flushed = await model.flushReading()
        XCTAssertTrue(flushed)
        XCTAssertEqual(model.reader?.scalarOffset, 80)
        XCTAssertEqual(model.reader?.progressRevision, "revision-2")
        XCTAssertEqual(service.saves.count, 2)
    }

    func testChangedBodyRestoresAtStartAndKeepsTheCoreProgressObservationForTheNextWrite() async throws {
        let service = ApplicationModelServiceFake()
        service.openingProgress = ReaderProgressSnapshot(found: true, progressRevision: "previous-observation", progress:
            ReaderProgress(bookId: book.bookId, chapterIndex: 0, chapterOffset: 81, chapterProgress: 0.81,
                           bodyVersion: "older-body", processingVersion: "processing-1"))
        let model = try await openedModel(service)
        XCTAssertEqual(model.reader?.scalarOffset, 0, "An offset from another body version is not a valid restoration")
        XCTAssertEqual(model.reader?.progressRevision, "previous-observation")
        let flushed = await model.flushReading()
        XCTAssertTrue(flushed)
        XCTAssertEqual(service.saves.first?.offset, 0)
        XCTAssertEqual(service.saves.first?.expectedRevision, "previous-observation")
    }

    func testSaveRejectionRetainsReaderAndRetryUsesOriginalObservation() async throws {
        let service = ApplicationModelServiceFake()
        service.rejectSaves = true
        let model = try await openedModel(service)
        let session = try XCTUnwrap(model.reader)
        model.recordVisibleOffset(31, sessionID: session.id, restorationID: session.restorationID)
        await model.closeReader()
        XCTAssertEqual(model.reader?.id, session.id)
        XCTAssertEqual(model.reader?.scalarOffset, 31)
        XCTAssertNotNil(model.recoveryMessage)
        XCTAssertEqual(service.saves.last?.expectedRevision, "revision-0")
        service.rejectSaves = false
        await model.closeReader()
        XCTAssertNil(model.reader)
        XCTAssertNil(model.recoveryMessage)
        XCTAssertEqual(service.saves.last?.offset, 31)
        XCTAssertEqual(service.saves.last?.expectedRevision, "revision-0")
    }

    func testSuccessfulFlushRetryClearsOnlyTheOutstandingFlushFailureAndAllowsClose() async throws {
        let service = ApplicationModelServiceFake()
        service.flushFailuresRemaining = 1
        let model = try await openedModel(service)
        let session = try XCTUnwrap(model.reader)
        await model.closeReader()
        XCTAssertEqual(model.reader?.id, session.id)
        XCTAssertNotNil(model.recoveryMessage)
        XCTAssertTrue(service.saves.isEmpty, "An already confirmed position does not require another mutation")
        await model.closeReader()
        XCTAssertNil(model.reader)
        XCTAssertNil(model.recoveryMessage)
        XCTAssertEqual(service.flushCount, 2)
        XCTAssertTrue(service.saves.isEmpty)
    }

    func testSeekCannotCreateANewUnawaitedWriteWhileClosingFlushIsOutstanding() async throws {
        let service = ApplicationModelServiceFake()
        service.holdFlushes = true
        defer { service.releasePendingRequests() }
        let model = try await openedModel(service)
        let flushing = expectation(description: "Close is waiting for durable storage flush")
        service.onFlush = { count in if count == 1 { flushing.fulfill() } }
        let close = Task { await model.closeReader() }
        await fulfillment(of: [flushing], timeout: 2)
        XCTAssertTrue(model.closingReader)
        model.seek(to: 0.8)
        XCTAssertEqual(model.reader?.scalarOffset, 0)
        XCTAssertTrue(service.saves.isEmpty)
        service.completeFlush(0)
        await close.value
        XCTAssertNil(model.reader)
        XCTAssertFalse(model.closingReader)
        XCTAssertTrue(service.saves.isEmpty)
    }

    func testPreviousChapterLayoutCallbackCannotMoveTheNewChapter() async throws {
        let service = ApplicationModelServiceFake()
        let model = try await openedModel(service)
        let previous = try XCTUnwrap(model.reader)
        await model.changeChapter(to: 1)
        let current = try XCTUnwrap(model.reader)
        XCTAssertEqual(current.content.chapterIndex, 1)
        XCTAssertNotEqual(current.restorationID, previous.restorationID)
        model.recordVisibleOffset(77, sessionID: previous.id, restorationID: previous.restorationID)
        XCTAssertEqual(model.reader?.scalarOffset, 0)
        model.recordVisibleOffset(9, sessionID: current.id, restorationID: current.restorationID)
        XCTAssertEqual(model.reader?.scalarOffset, 9)
        let flushed = await model.flushReading()
        XCTAssertTrue(flushed)
        XCTAssertEqual(service.saves.last?.content.chapterIndex, 1)
        XCTAssertEqual(service.saves.last?.offset, 9)
    }

    func testBackgroundTransitionFlushesTheVisibleLocation() async throws {
        let service = ApplicationModelServiceFake()
        let model = try await openedModel(service)
        let session = try XCTUnwrap(model.reader)
        let flushed = expectation(description: "Background task flushed pending reader position")
        service.onFlush = { _ in flushed.fulfill() }
        model.recordVisibleOffset(43, sessionID: session.id, restorationID: session.restorationID)
        model.setForeground(false)
        await fulfillment(of: [flushed], timeout: 2)
        XCTAssertFalse(model.foreground)
        XCTAssertEqual(service.saves.last?.offset, 43)
        XCTAssertEqual(service.saves.last?.content.chapterIndex, session.content.chapterIndex)
        XCTAssertEqual(model.reader?.id, session.id)
        model.setForeground(true)
    }

    func testInactiveThenBackgroundNotificationsDoNotDispatchDuplicateFlushes() async throws {
        let service = ApplicationModelServiceFake()
        service.holdFlushes = true
        defer { service.releasePendingRequests() }
        let model = try await openedModel(service)
        let dispatched = expectation(description: "The foreground-to-inactive edge dispatches one flush")
        service.onFlush = { count in if count == 1 { dispatched.fulfill() } }
        var inactivePublications = 0
        let observation = model.$foreground.filter { !$0 }.sink { _ in inactivePublications += 1 }
        defer { observation.cancel() }
        model.setForeground(false) // inactive
        model.setForeground(false) // background from the same lifecycle transition
        await fulfillment(of: [dispatched], timeout: 2)
        model.setForeground(false) // another delivery while that flush is suspended
        XCTAssertEqual(inactivePublications, 1)
        XCTAssertEqual(service.flushCount, 1)
        service.completeFlush(0)
        await service.waitForFlushReturn(0)
        XCTAssertEqual(service.flushCount, 1)
        XCTAssertNil(model.recoveryMessage)
        model.setForeground(true)
    }

    func testLateBackgroundFlushFailureCannotReplaceANewerSuccessfulFlush() async throws {
        let service = ApplicationModelServiceFake()
        service.holdFlushes = true
        defer { service.releasePendingRequests() }
        let model = try await openedModel(service)
        let backgroundDispatched = expectation(description: "Background flush is suspended")
        let foregroundDispatched = expectation(description: "New foreground flush is suspended independently")
        service.onFlush = { count in
            if count == 1 { backgroundDispatched.fulfill() }
            if count == 2 { foregroundDispatched.fulfill() }
        }
        model.setForeground(false)
        await fulfillment(of: [backgroundDispatched], timeout: 2)
        model.setForeground(true)
        let newer = Task { await model.flushReading() }
        await fulfillment(of: [foregroundDispatched], timeout: 2)
        service.completeFlush(1)
        let confirmed = await newer.value
        XCTAssertTrue(confirmed)
        XCTAssertNil(model.recoveryMessage)
        service.failFlush(0)
        await service.waitForFlushReturn(0)
        XCTAssertNil(model.recoveryMessage, "The obsolete failure must not invalidate the newer flush ACK")
        XCTAssertTrue(model.foreground)
        XCTAssertEqual(service.flushCount, 2)
    }

    func testLateBackgroundFlushFailureCannotMarkANewReaderSessionAsUnsaved() async throws {
        let service = ApplicationModelServiceFake()
        service.holdFlushes = true
        defer { service.releasePendingRequests() }
        let model = try await openedModel(service)
        let originalSession = try XCTUnwrap(model.reader)
        let backgroundDispatched = expectation(description: "Old session background flush is suspended")
        let closeDispatched = expectation(description: "Close owns a newer flush request")
        service.onFlush = { count in
            if count == 1 { backgroundDispatched.fulfill() }
            if count == 2 { closeDispatched.fulfill() }
        }
        model.setForeground(false)
        await fulfillment(of: [backgroundDispatched], timeout: 2)
        model.setForeground(true)
        let closing = Task { await model.closeReader() }
        await fulfillment(of: [closeDispatched], timeout: 2)
        service.completeFlush(1)
        await closing.value
        XCTAssertNil(model.reader)
        let nextBook = ReaderBook(bookId: "local:next-session", title: "Next reader", chapterCount: 2)
        let opened = expectation(description: "A different book is now the current reader")
        let observation = model.$reader.compactMap { $0 }.first(where: { $0.book.bookId == nextBook.bookId })
            .sink { _ in opened.fulfill() }
        defer { observation.cancel() }
        model.open(nextBook)
        await fulfillment(of: [opened], timeout: 2)
        let nextSession = try XCTUnwrap(model.reader)
        XCTAssertNotEqual(nextSession.id, originalSession.id)
        service.failFlush(0)
        await service.waitForFlushReturn(0)
        XCTAssertEqual(model.reader?.id, nextSession.id)
        XCTAssertEqual(model.reader?.book.bookId, nextBook.bookId)
        XCTAssertEqual(model.reader?.progressRevision, "revision-0")
        XCTAssertNil(model.recoveryMessage)
        XCTAssertFalse(model.closingReader)
    }

    func testOriginalPendingSaveACKSuppliesTheRevisionForTheNextQueuedPosition() async throws {
        let service = ApplicationModelServiceFake()
        service.holdSaves = true
        defer { service.releasePendingRequests() }
        let model = try await openedModel(service)
        let firstDispatched = expectation(description: "Original write was dispatched")
        let nextDispatched = expectation(description: "Next position is dispatched only after original ACK reconciliation")
        service.onSave = { count in
            if count == 1 { firstDispatched.fulfill() }
            if count == 2 { nextDispatched.fulfill() }
        }
        let unresolved = expectation(description: "Missing original write result remains unresolved")
        let unresolvedObservation = model.$recoveryMessage.compactMap { $0 }.first().sink { _ in unresolved.fulfill() }
        defer { unresolvedObservation.cancel() }
        model.seek(to: 0.2)
        await fulfillment(of: [firstDispatched], timeout: 2)
        service.failSave(0, error: ReaderLibraryError.operationPending("original-progress-write"))
        await fulfillment(of: [unresolved], timeout: 2)
        // Even a fresh progress read could now show the requested position.
        // It is not the original mutation's receipt and must never be queried
        // by this reconciliation path as a substitute for that ACK.
        service.openingProgress = service.receipt(forSave: 0, revision: "fresh-read-is-not-an-ack")
        service.holdProgressReconciliations = true
        let checkingOriginal = expectation(description: "The original request reconciliation is awaiting its exact reply")
        service.onProgressReconciliation = { count in if count == 2 { checkingOriginal.fulfill() } }
        model.seek(to: 0.8)
        await fulfillment(of: [checkingOriginal], timeout: 2)
        XCTAssertEqual(service.saves.count, 1)
        XCTAssertEqual(service.progressReadCount, 1, "Only opening the reader may read fresh progress")
        XCTAssertEqual(model.reader?.progressRevision, "revision-0")
        service.completeProgressReconciliation(1, result: .success(service.receipt(forSave: 0, revision: "original-ack-1")))
        await fulfillment(of: [nextDispatched], timeout: 2)
        XCTAssertEqual(service.saves.map(\.offset), [20, 80])
        XCTAssertEqual(service.saves[1].expectedRevision, "original-ack-1")
        XCTAssertEqual(model.reader?.scalarOffset, 80, "Late ACK projects ownership; it must not rewind the newer visible location")
        XCTAssertEqual(service.progressReadCount, 1)
        let confirmed = expectation(description: "The newer position receives its own ACK")
        let confirmedObservation = model.$reader.compactMap { $0 }
            .first(where: { $0.progressRevision == "original-ack-2" }).sink { _ in confirmed.fulfill() }
        defer { confirmedObservation.cancel() }
        service.completeSave(1, revision: "original-ack-2")
        await fulfillment(of: [confirmed], timeout: 2)
        XCTAssertNil(model.recoveryMessage)
    }

    func testFreshReadMatchingPendingPositionCannotReplaceMissingACKAndExactACKAvoidsAReplay() async throws {
        let service = ApplicationModelServiceFake()
        service.holdSaves = true
        defer { service.releasePendingRequests() }
        let model = try await openedModel(service)
        let dispatched = expectation(description: "Original write has no terminal ACK yet")
        service.onSave = { count in if count == 1 { dispatched.fulfill() } }
        let unresolved = expectation(description: "Original result is unconfirmed")
        let observation = model.$recoveryMessage.compactMap { $0 }.first().sink { _ in unresolved.fulfill() }
        defer { observation.cancel() }
        model.seek(to: 0.4)
        await fulfillment(of: [dispatched], timeout: 2)
        service.failSave(0, error: ReaderLibraryError.operationPending("pending-progress"))
        await fulfillment(of: [unresolved], timeout: 2)
        service.openingProgress = service.receipt(forSave: 0, revision: "read-success-without-write-ack")
        service.progressReconciliationError = ReaderLibraryError.operationPending("pending-progress")
        let stillPending = await model.flushReading()
        XCTAssertFalse(stillPending)
        XCTAssertNotNil(model.recoveryMessage)
        XCTAssertEqual(model.reader?.progressRevision, "revision-0")
        XCTAssertEqual(service.progressReadCount, 1)
        XCTAssertEqual(service.saves.count, 1, "Checking an unresolved write must not dispatch it again")
        service.progressReconciliationError = nil
        service.progressReconciliationResult = service.receipt(forSave: 0, revision: "exact-original-ack")
        let reconciled = await model.flushReading()
        XCTAssertTrue(reconciled)
        XCTAssertNil(model.recoveryMessage)
        XCTAssertEqual(model.reader?.progressRevision, "exact-original-ack")
        XCTAssertEqual(model.reader?.scalarOffset, 40)
        XCTAssertEqual(service.saves.count, 1, "The exact ACK already confirms this same position")
        XCTAssertEqual(service.progressReadCount, 1)
    }

    func testSecondBackgroundEdgeSubmitsNewPositionWhileOldBackgroundFlushIsStillPending() async throws {
        let service = ApplicationModelServiceFake()
        service.holdFlushes = true
        service.holdSaves = true
        defer { service.releasePendingRequests() }
        let leases = ApplicationModelBackgroundTasksFake()
        let model = try await openedModel(service, backgroundTasks: leases)
        let session = try XCTUnwrap(model.reader)
        let oldFlush = expectation(description: "The first background flush is still awaiting Core")
        let newSave = expectation(description: "The second background edge submits the newly visible position")
        let newFlush = expectation(description: "The new background task flushes its own acknowledged position")
        service.onFlush = { count in
            if count == 1 { oldFlush.fulfill() }
            if count == 2 { newFlush.fulfill() }
        }
        service.onSave = { count in if count == 1 { newSave.fulfill() } }
        model.setForeground(false)
        await fulfillment(of: [oldFlush], timeout: 2)
        let oldLease = try XCTUnwrap(leases.beganIDs.first)
        model.setForeground(true)
        XCTAssertEqual(leases.endedIDs, [oldLease])
        model.recordVisibleOffset(43, sessionID: session.id, restorationID: session.restorationID)
        // No debounce sleep: this edge itself must cancel the pending debounce
        // and dispatch 43 while the first flush is still suspended.
        model.setForeground(false)
        await fulfillment(of: [newSave], timeout: 2)
        XCTAssertEqual(service.saves.map(\.offset), [43])
        XCTAssertEqual(service.flushCount, 1)
        let newLease = try XCTUnwrap(leases.beganIDs.last)
        XCTAssertNotEqual(newLease, oldLease)
        XCTAssertTrue(leases.activeIDs.contains(newLease))
        service.completeSave(0, revision: "second-background-position")
        await fulfillment(of: [newFlush], timeout: 2)
        service.failFlush(0)
        await service.waitForFlushReturn(0)
        XCTAssertNil(model.recoveryMessage)
        XCTAssertTrue(leases.activeIDs.contains(newLease), "Old completion must not release the newer task's lease")
        XCTAssertEqual(leases.endedIDs, [oldLease])
        service.completeFlush(1)
        await service.waitForFlushReturn(1)
        XCTAssertEqual(model.reader?.progressRevision, "second-background-position")
        XCTAssertEqual(leases.endedIDs, [oldLease, newLease])
        XCTAssertTrue(leases.activeIDs.isEmpty)
        XCTAssertEqual(service.saves.count, 1)
        model.setForeground(true)
    }

    func testObsoleteBackgroundLeaseExpirationCannotEndTheCurrentLease() async throws {
        let service = ApplicationModelServiceFake()
        service.holdFlushes = true
        defer { service.releasePendingRequests() }
        let leases = ApplicationModelBackgroundTasksFake()
        let model = try await openedModel(service, backgroundTasks: leases)
        let first = expectation(description: "Old background task dispatched")
        let second = expectation(description: "New background task dispatched")
        service.onFlush = { count in
            if count == 1 { first.fulfill() }
            if count == 2 { second.fulfill() }
        }
        model.setForeground(false)
        await fulfillment(of: [first], timeout: 2)
        let oldLease = try XCTUnwrap(leases.beganIDs.first)
        model.setForeground(true)
        model.setForeground(false)
        await fulfillment(of: [second], timeout: 2)
        let currentLease = try XCTUnwrap(leases.beganIDs.last)
        XCTAssertNotEqual(oldLease, currentLease)
        // Simulate an already queued expiration from the ended lease. The
        // callback's own identity, not the model's latest identifier, owns it.
        leases.expire(oldLease)
        XCTAssertEqual(leases.endedIDs, [oldLease])
        XCTAssertEqual(leases.activeIDs, [currentLease])
        leases.expire(currentLease)
        leases.expire(currentLease)
        XCTAssertEqual(leases.endedIDs, [oldLease, currentLease])
        XCTAssertTrue(leases.activeIDs.isEmpty)
        service.failFlush(0)
        await service.waitForFlushReturn(0)
        service.completeFlush(1)
        await service.waitForFlushReturn(1)
        XCTAssertEqual(leases.beganIDs.count, 2, "An expired background episode cannot reacquire a lease")
        XCTAssertEqual(leases.endedIDs, [oldLease, currentLease])
        model.setForeground(true)
    }

    func testBackgroundFlushRevokedBeforeItsTaskStartsCannotDispatchIntoANewerEpisode() async throws {
        let service = ApplicationModelServiceFake()
        service.holdFlushes = true
        defer { service.releasePendingRequests() }
        let leases = ApplicationModelBackgroundTasksFake()
        let model = try await openedModel(service, backgroundTasks: leases)
        let dispatched = expectation(description: "Only the currently owned background episode dispatches")
        dispatched.assertForOverFulfill = true
        service.onFlush = { _ in dispatched.fulfill() }
        // These transitions occur in one MainActor job. The first Task has
        // not started before it loses ownership to the next background edge.
        model.setForeground(false)
        model.setForeground(true)
        model.setForeground(false)
        await fulfillment(of: [dispatched], timeout: 2)
        XCTAssertEqual(service.flushCount, 1)
        XCTAssertEqual(leases.beganIDs.count, 2)
        let currentLease = try XCTUnwrap(leases.beganIDs.last)
        XCTAssertEqual(leases.activeIDs, [currentLease])
        service.completeFlush(0)
        await service.waitForFlushReturn(0)
        XCTAssertTrue(leases.activeIDs.isEmpty)
        XCTAssertEqual(leases.endedIDs, leases.beganIDs)
        model.setForeground(true)
    }

    func testLateBackgroundScrollAfterCompletedFlushDispatchesImmediatelyAndKeepsItsLeaseUntilACK() async throws {
        let service = ApplicationModelServiceFake()
        service.holdFlushes = true
        defer { service.releasePendingRequests() }
        let leases = ApplicationModelBackgroundTasksFake()
        let model = try await openedModel(service, backgroundTasks: leases)
        let session = try XCTUnwrap(model.reader)
        let flushed = expectation(description: "The initial background-edge flush was dispatched")
        service.onFlush = { count in if count == 1 { flushed.fulfill() } }
        model.setForeground(false)
        await fulfillment(of: [flushed], timeout: 2)
        service.completeFlush(0)
        await service.waitForFlushReturn(0)
        XCTAssertTrue(leases.activeIDs.isEmpty)
        XCTAssertEqual(leases.endedIDs, leases.beganIDs)
        service.holdSaves = true
        let dispatched = expectation(description: "The late current-session scroll dispatches without a debounce timer")
        service.onSave = { count in if count == 1 { dispatched.fulfill() } }
        model.recordVisibleOffset(43, sessionID: session.id, restorationID: session.restorationID)
        // The synchronous call itself must acquire the lease. No scheduler
        // sleep or 300ms wait may be needed to protect a suspended app.
        XCTAssertEqual(leases.beganIDs.count, 2)
        let saveLease = try XCTUnwrap(leases.beganIDs.last)
        XCTAssertEqual(leases.activeIDs, [saveLease])
        await fulfillment(of: [dispatched], timeout: 2)
        XCTAssertEqual(service.saves.map(\.offset), [43])
        XCTAssertEqual(service.saves[0].expectedRevision, "revision-0")
        XCTAssertEqual(model.reader?.progressRevision, "revision-0")
        XCTAssertTrue(leases.activeIDs.contains(saveLease))
        let acknowledged = expectation(description: "The original late-scroll write receives its own ACK")
        let observation = model.$reader.compactMap { $0 }
            .first(where: { $0.progressRevision == "late-scroll-ack" }).sink { _ in acknowledged.fulfill() }
        defer { observation.cancel() }
        service.completeSave(0, revision: "late-scroll-ack")
        await fulfillment(of: [acknowledged], timeout: 2)
        XCTAssertTrue(leases.activeIDs.isEmpty)
        XCTAssertEqual(leases.endedIDs, leases.beganIDs)
        XCTAssertEqual(model.reader?.scalarOffset, 43)
        XCTAssertNil(model.recoveryMessage)
        model.recordVisibleOffset(43, sessionID: session.id, restorationID: session.restorationID)
        XCTAssertEqual(service.saves.count, 1, "A duplicate callback for the confirmed position must not replay the write")
        XCTAssertEqual(leases.beganIDs.count, 2)
        XCTAssertEqual(service.flushCount, 1)
        model.setForeground(true)
    }
}

@MainActor
private final class ApplicationModelBackgroundTasksFake: ReaderBackgroundTaskManaging {
    private var nextID = 1
    private var expirations: [Int: @MainActor () -> Void] = [:]
    private(set) var beganIDs: [Int] = []
    private(set) var endedIDs: [Int] = []
    private(set) var activeIDs: Set<Int> = []

    func begin(name: String, expiration: @escaping @MainActor () -> Void) -> UIBackgroundTaskIdentifier {
        let id = nextID
        nextID += 1
        beganIDs.append(id)
        activeIDs.insert(id)
        expirations[id] = expiration
        return UIBackgroundTaskIdentifier(rawValue: id)
    }
    func end(_ identifier: UIBackgroundTaskIdentifier) {
        endedIDs.append(identifier.rawValue)
        activeIDs.remove(identifier.rawValue)
    }
    func expire(_ id: Int) { expirations[id]?() }
}

/// A controllable protocol fake: replies are released by the test, so race
/// assertions do not depend on scheduler sleeps or a copied state-machine model.
@MainActor
private final class ApplicationModelServiceFake: ReaderDownloadServing {
    static let sampleBook = ReaderBook(bookId: "local:sample", title: "Sample", chapterCount: 2)
    struct SaveCall {
        let content: ReaderChapterContent
        let offset: UInt64
        let expectedRevision: String?
    }
    enum Failure: Error { case rejected, releasedAtTeardown }

    var holdLists = false
    var holdImports = false
    var holdSaves = false
    var holdFlushes = false
    var holdProgressReconciliations = false
    var holdCacheWindows = false
    var rejectSaves = false
    var flushFailuresRemaining = 0
    var pending: [ReaderPendingImport] = []
    var openingProgress: ReaderProgressSnapshot?
    var progressReconciliationResult: ReaderProgressSnapshot?
    var progressReconciliationError: Error?
    var contentError: Error?
    var importResult = ReaderImportResult(book: ApplicationModelServiceFake.sampleBook, created: true)
    private(set) var listCount = 0
    private(set) var importCount = 0
    private(set) var flushCount = 0
    private(set) var recoverCount = 0
    private(set) var progressReadCount = 0
    private(set) var progressReconciliationCount = 0
    private(set) var contentReadCount = 0
    private(set) var cacheWindowCount = 0
    private(set) var saves: [SaveCall] = []
    var onList: ((Int) -> Void)?
    var onImport: ((Int) -> Void)?
    var onSave: ((Int) -> Void)?
    var onFlush: ((Int) -> Void)?
    var onProgressReconciliation: ((Int) -> Void)?
    var onCacheWindow: ((Int) -> Void)?
    private var listContinuations: [Int: CheckedContinuation<[ReaderBook], Error>] = [:]
    private var importContinuation: CheckedContinuation<ReaderImportResult, Error>?
    private var saveContinuations: [Int: CheckedContinuation<ReaderProgressSnapshot, Error>] = [:]
    private var flushContinuations: [Int: CheckedContinuation<Void, Error>] = [:]
    private var progressReconciliationContinuations: [Int: CheckedContinuation<ReaderProgressSnapshot?, Error>] = [:]
    private var returnedFlushes: Set<Int> = []
    private var flushReturnWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]
    private var cacheWindowContinuations: [Int: CheckedContinuation<ReaderReadingCacheWindow, Error>] = [:]
    private var returnedCacheWindows: Set<Int> = []
    private var cacheWindowReturnWaiters: [Int: [CheckedContinuation<Void, Never>]] = [:]

    func listBooks() async throws -> [ReaderBook] {
        let index = listCount
        listCount += 1
        if !holdLists { onList?(listCount); return [Self.sampleBook] }
        return try await withCheckedThrowingContinuation { continuation in
            listContinuations[index] = continuation
            onList?(listCount)
        }
    }

    func importBook(at url: URL) async throws -> ReaderImportResult {
        importCount += 1
        if !holdImports { onImport?(importCount); return importResult }
        return try await withCheckedThrowingContinuation { continuation in
            importContinuation = continuation
            onImport?(importCount)
        }
    }

    func chapters(for book: ReaderBook) async throws -> [ReaderChapter] {
        [ReaderChapter(index: 0, title: "First"), ReaderChapter(index: 1, title: "Second")]
    }

    func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent {
        contentReadCount += 1
        if let contentError { throw contentError }
        return ReaderChapterContent(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: chapterIndex,
                                    chapterTitle: "Chapter \(chapterIndex)", content: String(repeating: "文", count: 100),
                                    bodyVersion: "body-\(chapterIndex)", processingVersion: "processing-1")
    }

    func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot {
        progressReadCount += 1
        if let openingProgress { return openingProgress }
        return ReaderProgressSnapshot(found: true, progressRevision: "revision-0", progress:
            ReaderProgress(bookId: book.bookId, chapterIndex: 0, chapterOffset: 0, chapterProgress: 0,
                           bodyVersion: "body-0", processingVersion: "processing-1"))
    }

    func reconcilePendingProgress(for book: ReaderBook) async throws -> ReaderProgressSnapshot? {
        let index = progressReconciliationCount
        progressReconciliationCount += 1
        if holdProgressReconciliations {
            return try await withCheckedThrowingContinuation { continuation in
                progressReconciliationContinuations[index] = continuation
                onProgressReconciliation?(progressReconciliationCount)
            }
        }
        onProgressReconciliation?(progressReconciliationCount)
        if let progressReconciliationError { throw progressReconciliationError }
        return progressReconciliationResult
    }

    func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                      expectedRevision: String?) async throws -> ReaderProgressSnapshot {
        let index = saves.count
        saves.append(SaveCall(content: content, offset: scalarOffset, expectedRevision: expectedRevision))
        if rejectSaves { onSave?(saves.count); throw Failure.rejected }
        if !holdSaves { onSave?(saves.count); return saveReceipt(index, revision: "saved-\(index)") }
        return try await withCheckedThrowingContinuation { continuation in
            saveContinuations[index] = continuation
            onSave?(saves.count)
        }
    }

    func flush() async throws {
        let index = flushCount
        flushCount += 1
        defer {
            returnedFlushes.insert(index)
            flushReturnWaiters.removeValue(forKey: index)?.forEach { $0.resume() }
        }
        if holdFlushes {
            return try await withCheckedThrowingContinuation { continuation in
                flushContinuations[index] = continuation
                onFlush?(flushCount)
            }
        }
        onFlush?(flushCount)
        if flushFailuresRemaining > 0 { flushFailuresRemaining -= 1; throw Failure.rejected }
    }
    func close() async throws {}
    func pendingImports() async throws -> [ReaderPendingImport] { pending }
    func recoverPendingImports() async throws -> [ReaderPendingImport] { recoverCount += 1; return pending }

    func cacheReadingWindow(_ book: ReaderBook, around chapterIndex: UInt32) async throws -> ReaderReadingCacheWindow {
        let index = cacheWindowCount
        cacheWindowCount += 1
        defer {
            returnedCacheWindows.insert(index)
            cacheWindowReturnWaiters.removeValue(forKey: index)?.forEach { $0.resume() }
        }
        if !holdCacheWindows {
            onCacheWindow?(cacheWindowCount)
            return .init(requestedIndexes: [], cachedIndexes: [], failedIndexes: [])
        }
        return try await withCheckedThrowingContinuation { continuation in
            cacheWindowContinuations[index] = continuation
            onCacheWindow?(cacheWindowCount)
        }
    }

    // These tests exercise automatic cache reads, never explicit queue or
    // cleanup commands. An unexpected use fails instead of inventing an ACK.
    func readerDownloadStatus(_ book: ReaderBook) async throws -> ReaderDownloadStatus { throw Failure.rejected }
    func downloadChapters(_ book: ReaderBook, range: Range<UInt32>, operationID: String) async throws -> ReaderDownloadReceipt { throw Failure.rejected }
    func pauseDownload(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws -> ReaderDownloadTaskReceipt { throw Failure.rejected }
    func resumeDownload(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws -> ReaderDownloadTaskReceipt { throw Failure.rejected }
    func cancelDownload(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws -> ReaderDownloadTaskReceipt { throw Failure.rejected }
    func readerStorageSummary(protected: [ReaderCachedChapterIdentity]) async throws -> ReaderStorageSummary { throw Failure.rejected }
    func cleanupReaderStorage(retained: [ReaderCachedChapterIdentity], protected: [ReaderCachedChapterIdentity], operationID: String) async throws -> ReaderStorageSummary { throw Failure.rejected }

    func completeCacheWindow(_ index: Int, result: Result<ReaderReadingCacheWindow, Error>) {
        cacheWindowContinuations.removeValue(forKey: index)?.resume(with: result)
    }
    func waitForCacheWindowReturn(_ index: Int) async {
        guard index < cacheWindowCount else { return }
        if returnedCacheWindows.contains(index) { return }
        await withCheckedContinuation { continuation in
            cacheWindowReturnWaiters[index, default: []].append(continuation)
        }
    }

    func completeList(_ index: Int, books: [ReaderBook]) { listContinuations.removeValue(forKey: index)?.resume(returning: books) }
    func completeImport(_ result: Result<ReaderImportResult, Error>) {
        let continuation = importContinuation
        importContinuation = nil
        continuation?.resume(with: result)
    }
    func completeSave(_ index: Int, revision: String) {
        saveContinuations.removeValue(forKey: index)?.resume(returning: saveReceipt(index, revision: revision))
    }
    func failSave(_ index: Int, error: Error) { saveContinuations.removeValue(forKey: index)?.resume(throwing: error) }
    func completeFlush(_ index: Int) { flushContinuations.removeValue(forKey: index)?.resume(returning: ()) }
    func failFlush(_ index: Int) { flushContinuations.removeValue(forKey: index)?.resume(throwing: Failure.rejected) }
    func waitForFlushReturn(_ index: Int) async {
        guard index < flushCount else { return }
        if returnedFlushes.contains(index) { return }
        await withCheckedContinuation { continuation in
            flushReturnWaiters[index, default: []].append(continuation)
        }
    }
    func completeProgressReconciliation(_ index: Int, result: Result<ReaderProgressSnapshot?, Error>) {
        progressReconciliationContinuations.removeValue(forKey: index)?.resume(with: result)
    }
    func receipt(forSave index: Int, revision: String) -> ReaderProgressSnapshot { saveReceipt(index, revision: revision) }
    private func saveReceipt(_ index: Int, revision: String) -> ReaderProgressSnapshot {
        let call = saves[index]
        return ReaderProgressSnapshot(found: true, progressRevision: revision, progress:
            ReaderProgress(bookId: call.content.bookId, chapterIndex: call.content.chapterIndex,
                           chapterOffset: call.offset, chapterProgress: Double(call.offset) / 100,
                           bodyVersion: call.content.bodyVersion, processingVersion: call.content.processingVersion))
    }
    func releasePendingRequests() {
        let lists = Array(listContinuations.values)
        listContinuations.removeAll()
        lists.forEach { $0.resume(throwing: Failure.releasedAtTeardown) }
        let saves = Array(saveContinuations.values)
        saveContinuations.removeAll()
        saves.forEach { $0.resume(throwing: Failure.releasedAtTeardown) }
        let flushes = Array(flushContinuations.values)
        flushContinuations.removeAll()
        flushes.forEach { $0.resume(throwing: Failure.releasedAtTeardown) }
        let reconciliations = Array(progressReconciliationContinuations.values)
        progressReconciliationContinuations.removeAll()
        reconciliations.forEach { $0.resume(throwing: Failure.releasedAtTeardown) }
        let windows = Array(cacheWindowContinuations.values)
        cacheWindowContinuations.removeAll()
        windows.forEach { $0.resume(throwing: Failure.releasedAtTeardown) }
        completeImport(.failure(Failure.releasedAtTeardown))
    }
}
