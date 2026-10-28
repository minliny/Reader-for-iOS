import Foundation
import CryptoKit
import XCTest
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
@testable import Reader

/// State/real-Core lifecycle boundary, not a native paper-tap journey.
@MainActor
final class ReaderTextToolsLifecycleTests: XCTestCase {
    private enum BoundaryError: Error { case missingActualResult }

    /// Controlled result DTOs exercise request/retry ownership only. They do
    /// not stand in for a real-book Core search or native search journey.
    func testSearchRetryKeepsFailedKeywordOffsetAndReplacementOrAppendIntent() async throws {
        let book = ReaderBook(bookId: "host-search-owner", title: "Controlled search owner")
        func page(_ offsets: [UInt64], hasMore: Bool) throws -> ReaderContentSearchPage {
            let rows: [[String: Any]] = offsets.map { offset in
                ["sourceId": book.sourceId, "bookId": book.bookId, "bookName": book.title,
                 "chapterIndex": 0, "chapterOffset": offset, "matchLength": 1, "snippetStart": offset,
                 "chapterTitle": "Ownership boundary", "snippet": "Controlled result \(offset)"]
            }
            var data: [String: Any] = ["results": rows, "hasMore": hasMore]
            if hasMore { data["nextCursor"] = "controlled-retry-cursor:1" }
            return try JSONDecoder().decode(ReaderContentSearchPage.self, from: JSONSerialization.data(withJSONObject: data))
        }
        let first = try page([1, 2], hasMore: true), next = try page([3, 4], hasMore: false)
        var calls: [(bookID: String, keyword: String, limit: UInt32, cursor: String?)] = []
        var failNext = false
        let search: ReaderTextToolsState.Search = { book, keyword, limit, cursor in
            calls.append((book.id, keyword, limit, cursor))
            if failNext { failNext = false; throw BoundaryError.missingActualResult }
            return cursor == nil ? first : next
        }
        let state = ReaderTextToolsState()
        defer { state.cancelSearch() }
        state.query = "Original keyword"
        state.startSearch(for: book, more: false, search: search)
        await (try XCTUnwrap(state.searchTask)).value
        XCTAssertEqual(state.results, first.results)

        // A failed refresh of that same keyword must replace the old first
        // page on retry, rather than infer an append from retained results.
        failNext = true
        state.startSearch(for: book, more: false, search: search)
        await (try XCTUnwrap(state.searchTask)).value
        XCTAssertNil(state.failedSearchRequest?.cursor)
        XCTAssertEqual(state.failedSearchRequest?.append, false)
        XCTAssertEqual(state.results, first.results)
        state.query = "New unsubmitted user input"
        state.retrySearch(for: book, search: search)
        await (try XCTUnwrap(state.searchTask)).value
        XCTAssertEqual(calls.last?.keyword, "Original keyword")
        XCTAssertNil(calls.last?.cursor); XCTAssertEqual(calls.last?.limit, 100)
        XCTAssertEqual(state.results, first.results); XCTAssertNil(state.searchFailure)
        XCTAssertEqual(state.query, "New unsubmitted user input")

        // The historical selector is retained; More now owns the original
        // version-bound cursor rather than recomputing a legacy offset.
        failNext = true
        state.startSearch(for: book, more: true, search: search)
        await (try XCTUnwrap(state.searchTask)).value
        XCTAssertEqual(state.failedSearchRequest?.cursor, "controlled-retry-cursor:1")
        XCTAssertEqual(state.failedSearchRequest?.append, true)
        let originalCalls = calls.count
        let other = ReaderBook(bookId: "other-search-owner", title: "Other owner")
        state.retrySearch(for: other, search: search)
        XCTAssertEqual(calls.count, originalCalls); XCTAssertNil(state.searchTask)
        state.retrySearch(for: book, search: search)
        await (try XCTUnwrap(state.searchTask)).value
        XCTAssertEqual(calls.last?.bookID, book.id); XCTAssertEqual(calls.last?.keyword, "Original keyword")
        XCTAssertEqual(calls.last?.cursor, "controlled-retry-cursor:1")
        XCTAssertEqual(state.results, first.results + next.results)
        XCTAssertFalse(state.hasMore); XCTAssertNil(state.failedSearchRequest)
        XCTAssertEqual(calls.count, 5)
    }

    /// Controlled protocol DTOs exercise the production state/service boundary.
    /// No novel, source definition, body, network or actual-Core stale result is fabricated.
    func testCursorSearchUsesExactSessionAndRetiresStaleInputAndReaderGenerations() async throws {
        let book = ReaderBook(sourceId: "caf\u{e9}", bookId: "controlled-scope", title: "Protocol ownership")
        let other = ReaderBook(sourceId: "cafe\u{301}", bookId: book.bookId, title: book.title)
        XCTAssertEqual(book.sourceId, other.sourceId, "Swift canonical equivalence is not Core key identity")
        XCTAssertNotEqual(Data(book.sourceId.utf8), Data(other.sourceId.utf8))
        let a1 = String(repeating: "a", count: 32) + ":1", a2 = String(repeating: "a", count: 32) + ":2"
        let b1 = String(repeating: "b", count: 32) + ":1", late = String(repeating: "c", count: 32) + ":1"
        let d1 = String(repeating: "d", count: 32) + ":1"
        func data(_ book: ReaderBook, _ offset: UInt64, cursor: String?) -> [String: Any] {
            var value: [String: Any] = ["results": [["sourceId": book.sourceId, "bookId": book.bookId,
                "bookName": book.title, "chapterIndex": 0, "chapterOffset": offset, "matchLength": 1,
                "snippetStart": offset, "chapterTitle": "Protocol DTO", "snippet": "Controlled result",
                "positionScope": ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": 0,
                    "bodyVersion": "dto-body", "processingVersion": "dto-processing"]]], "hasMore": cursor != nil]
            if let cursor { value["nextCursor"] = cursor }
            return value
        }
        let boundary = CursorSearchCoreBoundary()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderCursorOwnership-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"),
            client: boundary, timing: .init(now: { ProcessInfo.processInfo.systemUptime }, suspend: { await Task.yield() }))
        let state = ReaderTextToolsState()
        let latePage = try JSONDecoder().decode(ReaderContentSearchPage.self, from: JSONSerialization.data(withJSONObject: data(book, 99, cursor: late)))
        var held: CheckedContinuation<ReaderContentSearchPage, Never>?
        var pending: Task<Void, Never>?
        defer { boundary.releaseAllCloses(); held?.resume(returning: latePage); pending?.cancel(); state.retireSearch() }
        do {
            state.query = "scope-keyword"
            boundary.enqueue(data(book, 1, cursor: a1))
            state.startSearch(for: book, using: service, more: false)
            await (try XCTUnwrap(state.searchTask)).value
            let first = state.results
            var call = try XCTUnwrap(boundary.searchCalls.last).parameters()
            XCTAssertEqual(call["useCursor"] as? Bool, true)
            XCTAssertNil(call["cursor"]); XCTAssertNil(call["offset"])
            XCTAssertEqual(state.nextSearchCursor, a1)

            boundary.enqueueFailure(reason: "CONTROLLED_TRANSIENT_FAILURE")
            state.startSearch(for: book, using: service, more: true)
            await (try XCTUnwrap(state.searchTask)).value
            XCTAssertEqual(state.failedSearchRequest?.cursor, a1)
            XCTAssertEqual(state.results, first)
            boundary.enqueue(data(book, 2, cursor: a2))
            state.retrySearch(for: book, using: service)
            await (try XCTUnwrap(state.searchTask)).value
            call = try XCTUnwrap(boundary.searchCalls.last).parameters()
            XCTAssertEqual(call["cursor"] as? String, a1)
            XCTAssertNil(call["offset"]); XCTAssertNil(call["useCursor"])
            XCTAssertEqual(state.results.count, 2); XCTAssertEqual(state.nextSearchCursor, a2)

            let confirmed = state.results
            boundary.enqueueFailure(reason: "CONTENT_SEARCH_STALE")
            state.startSearch(for: book, using: service, more: true)
            await (try XCTUnwrap(state.searchTask)).value
            await state.searchRetirementTask?.value
            XCTAssertEqual(state.results, confirmed)
            XCTAssertTrue(state.searchRequiresRestart); XCTAssertFalse(state.hasMore)
            XCTAssertNil(state.nextSearchCursor); XCTAssertNil(state.failedSearchRequest)
            XCTAssertTrue(try boundary.closedCalls.contains { try $0.parameters()["cursor"] as? String == a2 })
            let beforeRetry = boundary.searchCalls.count
            state.retrySearch(for: book, using: service)
            XCTAssertEqual(boundary.searchCalls.count, beforeRetry, "a stale cursor is never replayed as More")

            boundary.enqueue(data(book, 10, cursor: b1))
            state.startSearch(for: book, using: service, more: false)
            await (try XCTUnwrap(state.searchTask)).value
            boundary.enqueue(data(book, 11, cursor: nil))
            state.startSearch(for: book, using: service, more: true)
            await (try XCTUnwrap(state.searchTask)).value
            await state.searchRetirementTask?.value
            XCTAssertFalse(state.hasMore); XCTAssertNil(state.nextSearchCursor)
            XCTAssertTrue(try boundary.closedCalls.contains { try $0.parameters()["cursor"] as? String == b1 },
                "terminal continuation closes its input token even when nextCursor is absent")

            let closer: ReaderTextToolsState.CloseSearch = { book, keyword, cursor in
                try await service.closeContentSearch(for: book, keyword: keyword, cursor: cursor)
            }
            state.startSearch(for: book, more: false, close: closer) { _, _, _, _ in
                await withCheckedContinuation { held = $0 }
            }
            pending = try XCTUnwrap(state.searchTask)
            await waitUntil { held != nil }
            state.query = "changed input"; state.query = "scope-keyword"
            // A separate exact UTF-8 source identity becomes the reader owner.
            boundary.enqueue(data(other, 20, cursor: d1))
            state.startSearch(for: other, using: service, more: false)
            await (try XCTUnwrap(state.searchTask)).value
            let newer = state.results
            let reply = try XCTUnwrap(held); held = nil; reply.resume(returning: latePage)
            await pending?.value
            await state.searchRetirementTask?.value
            XCTAssertEqual(state.results, newer); XCTAssertEqual(state.nextSearchCursor, d1)
            XCTAssertFalse(state.searchRequiresRestart)
            XCTAssertTrue(try boundary.closedCalls.contains { try $0.parameters()["cursor"] as? String == late })
            XCTAssertFalse(try boundary.closedCalls.contains { try $0.parameters()["cursor"] as? String == d1 },
                "late old cleanup must not read and close the mutable new token")
            call = try XCTUnwrap(boundary.searchCalls.last).parameters()
            XCTAssertEqual(Data((try XCTUnwrap(call["sourceId"] as? String)).utf8), Data(other.sourceId.utf8))
            state.retireSearch() // Same boundary as the production search panel disappearing.
            await state.searchRetirementTask?.value
            XCTAssertEqual(state.results, newer)
            XCTAssertTrue(try boundary.closedCalls.contains { try $0.parameters()["cursor"] as? String == d1 })

            // Stop can win the actor-hop after a successful initial read has
            // produced a cursor but before MainActor accepts the page.
            let e1 = String(repeating: "e", count: 32) + ":1"
            let stoppedInitial = try JSONDecoder().decode(ReaderContentSearchPage.self,
                from: JSONSerialization.data(withJSONObject: data(book, 31, cursor: e1)))
            state.startSearch(for: book, more: false, close: closer) { _, _, _, _ in
                await withCheckedContinuation { held = $0 }
            }
            pending = try XCTUnwrap(state.searchTask)
            await waitUntil { held != nil }
            let beforeStop = state.results
            state.cancelSearch() // Stop does not mark the request lease retired.
            let initialReply = try XCTUnwrap(held); held = nil; initialReply.resume(returning: stoppedInitial)
            await pending?.value; await state.searchRetirementTask?.value
            XCTAssertEqual(state.results, beforeStop); XCTAssertNil(state.nextSearchCursor)
            XCTAssertTrue(try boundary.closedCalls.contains { try $0.parameters()["cursor"] as? String == e1 },
                "a now-known unaccepted initial token is closed even after ordinary Stop")

            let f1 = String(repeating: "f", count: 32) + ":1", f2 = String(repeating: "f", count: 32) + ":2"
            boundary.enqueue(data(book, 40, cursor: f1))
            state.startSearch(for: book, using: service, more: false)
            await (try XCTUnwrap(state.searchTask)).value
            let retainedMore = state.results
            let stoppedMore = try JSONDecoder().decode(ReaderContentSearchPage.self,
                from: JSONSerialization.data(withJSONObject: data(book, 41, cursor: f2)))
            state.startSearch(for: book, more: true, close: closer) { _, _, _, cursor in
                XCTAssertEqual(cursor, f1)
                return await withCheckedContinuation { held = $0 }
            }
            pending = try XCTUnwrap(state.searchTask)
            await waitUntil { held != nil }
            state.cancelSearch()
            let moreReply = try XCTUnwrap(held); held = nil; moreReply.resume(returning: stoppedMore)
            await pending?.value; await state.searchRetirementTask?.value
            XCTAssertEqual(state.results, retainedMore); XCTAssertEqual(state.nextSearchCursor, f1)
            XCTAssertFalse(try boundary.closedCalls.contains { try [f1, f2].contains($0.parameters()["cursor"] as? String ?? "") },
                "More Stop preserves that session for its original input-token receipt retry")
            boundary.enqueue(data(book, 41, cursor: f2))
            state.startSearch(for: book, using: service, more: true)
            await (try XCTUnwrap(state.searchTask)).value; await state.searchRetirementTask?.value
            XCTAssertEqual(try boundary.searchCalls.last?.parameters()["cursor"] as? String, f1)
            XCTAssertEqual(state.results.count, retainedMore.count + 1)
            XCTAssertEqual(state.nextSearchCursor, f2, "Exact input-token retry receives its original page once")

            let g1 = String(repeating: "1", count: 32) + ":1", h1 = String(repeating: "2", count: 32) + ":1"
            boundary.enqueue(data(book, 50, cursor: g1))
            state.startSearch(for: book, using: service, more: false)
            await (try XCTUnwrap(state.searchTask)).value
            boundary.holdClose(g1)
            let beforeReplacement = boundary.searchCalls.count
            state.query = "replacement-query"
            boundary.enqueue(data(book, 60, cursor: h1))
            state.startSearch(for: book, using: service, more: false)
            let waitingInitial = try XCTUnwrap(state.searchTask)
            await waitUntil { (try? boundary.closedCalls.contains { try $0.parameters()["cursor"] as? String == g1 }) == true }
            XCTAssertEqual(boundary.searchCalls.count, beforeReplacement, "known cleanup is awaited before dispatching another initial search")
            // Cancel/change the waiting request, then release exactly that old
            // cleanup. Only the newest query may dispatch after the await.
            state.query = "replacement-query-2"
            state.startSearch(for: book, using: service, more: false)
            let latestInitial = try XCTUnwrap(state.searchTask)
            boundary.releaseClose(g1)
            await waitingInitial.value; await latestInitial.value
            XCTAssertEqual(boundary.searchCalls.count, beforeReplacement + 1)
            XCTAssertEqual(try boundary.searchCalls.last?.parameters()["keyword"] as? String, "replacement-query-2")
            XCTAssertEqual(state.nextSearchCursor, h1)
            state.retireSearch(); await state.searchRetirementTask?.value

            boundary.enqueue(data(other, 30, cursor: nil))
            do {
                _ = try await service.searchContent(for: book, keyword: "scope-keyword", limit: 100, cursor: nil)
                XCTFail("canonically equivalent but byte-distinct result identity must be rejected")
            } catch { XCTAssertEqual(error as? ReaderLibraryError, .invalidResponse("content search session identity")) }
            XCTAssertTrue(try boundary.searchCalls.allSatisfy { try $0.parameters()["offset"] == nil })
            try await service.close()
        } catch {
            boundary.releaseAllCloses()
            state.retireSearch(); await state.searchRetirementTask?.value
            try? await service.close()
            throw error
        }
    }

    /// Typed action completion is controlled; these are editor/selection
    /// snapshots, not fabricated Core highlights or a native note acceptance.
    func testNoteSaveACKRetainsChangedSelectionDraftABAAndReopenedPresentation() async throws {
        let book = ReaderBook(bookId: "host-note-owner", title: "Controlled note owner", chapterCount: 1)
        let content = ReaderChapterContent(bookId: book.bookId, chapterIndex: 0, chapterTitle: "Ownership boundary",
            content: "Controlled ownership text", bodyVersion: "body-owner-1", processingVersion: "processing-owner-1")
        let session = ReaderActiveSession(id: UUID(), book: book, chapters: [.init(index: 0, title: content.chapterTitle)],
            content: content, scalarOffset: 0, progressRevision: nil, restorationID: UUID())
        func selection(_ start: UInt64) -> ReaderTextSelection {
            .init(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: content.chapterIndex,
                bodyVersion: content.bodyVersion, processingVersion: content.processingVersion,
                start: start, end: start + 1, text: "Controlled selection \(start)")
        }
        let originalSelection = selection(0), changedSelection = selection(1)
        for boundary in 0..<7 {
            let state = ReaderTextToolsState(), owner = ReaderLibraryActionOwner()
            defer { state.retireNotes() }
            state.activateNotes(session: session, selection: originalSelection)
            state.note = "Original raw note"
            let captured = try XCTUnwrap(state.captureNoteDraft(for: book))
            var reply: CheckedContinuation<Void, Never>?
            defer { reply?.resume() }
            let action = Task {
                let success = await owner.perform("Controlled original note save", scope: book.id) { _ in
                    await withCheckedContinuation { reply = $0 }
                }
                if success { state.finishNoteSave(captured) }
                return success
            }
            await waitUntil { reply != nil }
            switch boundary {
            case 1: state.note = "New raw note input"
            case 2:
                state.note = "Changed in between"; state.note = captured.note
            case 3: state.updateNoteContext(session: session, selection: changedSelection)
            case 4:
                state.updateNoteContext(session: session, selection: changedSelection)
                state.updateNoteContext(session: session, selection: originalSelection)
            case 5:
                state.retireNotes(); state.activateNotes(session: session, selection: originalSelection)
            case 6:
                var newer = session
                newer.content = ReaderChapterContent(bookId: book.bookId, chapterIndex: 0, chapterTitle: content.chapterTitle,
                    content: content.content, bodyVersion: content.bodyVersion, processingVersion: "processing-owner-2")
                state.updateNoteContext(session: newer, selection: originalSelection)
            default: break
            }
            let retained = state.note
            let originalID = try XCTUnwrap(owner.pendingOperationID)
            let completion = try XCTUnwrap(reply); reply = nil; completion.resume()
            let success = await action.value
            XCTAssertTrue(success); XCTAssertFalse(owner.hasPending); XCTAssertFalse(owner.busy)
            XCTAssertNil(owner.recovery)
            XCTAssertFalse(originalID.isEmpty)
            XCTAssertEqual(state.note, boundary == 0 ? "" : retained)
            XCTAssertNil(state.editingNote)
        }

        // The bookmark editor uses the same accepted-write owner. Retiring or
        // replacing its editor keeps that original write alive, while its ACK
        // may clear only the captured draft in the original presentation.
        let bookmark = try JSONDecoder().decode(ReaderBookmark.self, from: JSONSerialization.data(withJSONObject: [
            "time": 1, "bookName": book.title, "bookAuthor": "", "chapterIndex": 0,
            "chapterPos": 0, "chapterName": content.chapterTitle, "bookText": "", "content": "Saved note"
        ]))
        for boundary in 0..<7 {
            let state = ReaderBookmarkState(), owner = ReaderLibraryActionOwner()
            defer { state.retire() }
            state.activate(); state.editing = bookmark; state.note = "Original raw bookmark note"
            let captured = try XCTUnwrap(state.captureNoteDraft(for: bookmark))
            var reply: CheckedContinuation<Void, Never>?
            defer { reply?.resume() }
            let action = Task {
                let success = await owner.perform("Controlled original bookmark save", scope: book.id) { _ in
                    await withCheckedContinuation { reply = $0 }
                }
                if success { state.finishNoteSave(captured) }
                return success
            }
            await waitUntil { reply != nil }
            let originalID = try XCTUnwrap(owner.pendingOperationID)
            switch boundary {
            case 1: state.note = "New raw bookmark note"
            case 2:
                state.note = "Changed in between"; state.note = captured.note
            case 3: state.editing = nil; state.note = ""
            case 4:
                state.editing = nil; state.note = ""
                state.editing = bookmark; state.note = captured.note
            case 5: state.retire(); state.activate()
            case 6: state.retire()
            default: break
            }
            let retainedNote = state.note, retainedEditing = state.editing
            XCTAssertTrue(owner.hasPending); XCTAssertTrue(owner.busy)
            XCTAssertEqual(owner.pendingOperationID, originalID, "Closing an editor cannot cancel its accepted save")
            let completion = try XCTUnwrap(reply); reply = nil; completion.resume()
            let success = await action.value
            XCTAssertTrue(success)
            XCTAssertFalse(owner.hasPending); XCTAssertFalse(owner.busy); XCTAssertNil(owner.recovery)
            XCTAssertEqual(state.note, boundary == 0 ? "" : retainedNote)
            XCTAssertEqual(state.editing, boundary == 0 ? nil : retainedEditing)
        }
    }

    /// Reuses the existing controlled note-owner metadata, not an imported
    /// corpus or fabricated Core/native acceptance. Held replies exercise the
    /// production read owner and its exact input/presentation boundaries.
    func testNoteReadsUseExactUTF8AndRetireLateRepliesAcrossReaderAndPresentationChanges() async throws {
        let book = ReaderBook(bookId: "host-note-owner", title: "Controlled note owner", chapterCount: 1)
        let content = ReaderChapterContent(bookId: book.bookId, chapterIndex: 0, chapterTitle: "Ownership boundary",
            content: "Controlled ownership text", bodyVersion: "body-owner-1", processingVersion: "processing-owner-1")
        let session = ReaderActiveSession(id: UUID(), book: book, chapters: [.init(index: 0, title: content.chapterTitle)],
            content: content, scalarOffset: 0, progressRevision: nil, restorationID: UUID())
        func mark(_ time: Int64) throws -> ReaderHighlight {
            try JSONDecoder().decode(ReaderHighlight.self, from: JSONSerialization.data(withJSONObject: [
                "time": time, "bookUrl": book.bookId, "chapterUrl": "", "bookName": book.title, "bookAuthor": "",
                "chapterIndex": 0, "chapterPos": 0, "chapterPosEnd": 1, "layoutTitleLength": 0,
                "chapterName": content.chapterTitle, "bookText": "", "style": "highlight", "note": ""
            ]))
        }
        let first = try mark(1), second = try mark(2), current = try mark(3)
        let state = ReaderTextToolsState()
        var held: [Int: CheckedContinuation<[ReaderHighlight], Error>] = [:]
        var received: [Int: Data] = [:]
        defer {
            state.retireNotes()
            for reply in held.values { reply.resume(returning: []) }
        }
        func begin(_ id: Int) throws -> Task<Void, Never> {
            try XCTUnwrap(state.readNotes(for: book) { actualBook, query in
                XCTAssertEqual(Data(actualBook.sourceId.utf8), Data(book.sourceId.utf8))
                XCTAssertEqual(Data(actualBook.bookId.utf8), Data(book.bookId.utf8))
                received[id] = Data(query.utf8)
                return try await withCheckedThrowingContinuation { held[id] = $0 }
            })
        }
        func complete(_ id: Int, _ values: [ReaderHighlight]) throws {
            try XCTUnwrap(held.removeValue(forKey: id)).resume(returning: values)
        }
        func fail(_ id: Int) throws {
            try XCTUnwrap(held.removeValue(forKey: id)).resume(throwing: CocoaError(.fileReadUnknown))
        }
        let nfc = "\u{00e9}", nfd = "e\u{0301}"
        XCTAssertEqual(nfc, nfd); XCTAssertNotEqual(Data(nfc.utf8), Data(nfd.utf8))
        let sameEpoch = UUID()
        XCTAssertNotEqual(ReaderTextToolsState.NoteReadKey(book: book, query: nfc, readerEpoch: sameEpoch),
            ReaderTextToolsState.NoteReadKey(book: book, query: nfd, readerEpoch: sameEpoch))
        state.activateNotes(session: session, selection: nil); state.noteQuery = nfc
        let oldKey = ReaderTextToolsState.NoteReadKey(book: book, query: state.noteQuery, readerEpoch: state.noteReadEpoch)
        let old = try begin(1); await waitUntil { held[1] != nil }
        state.noteQuery = nfd
        XCTAssertTrue(old.isCancelled, "Input retirement cancels the exact original read before a view update")
        XCTAssertNotEqual(oldKey, ReaderTextToolsState.NoteReadKey(book: book, query: state.noteQuery, readerEpoch: state.noteReadEpoch))
        let newer = try begin(2); await waitUntil { held[2] != nil }
        XCTAssertEqual(received[1], Data(nfc.utf8)); XCTAssertEqual(received[2], Data(nfd.utf8))
        try complete(2, [second]); await newer.value
        try complete(1, [first]); await old.value
        XCTAssertEqual(state.notes, [second]); XCTAssertNil(state.notesFailure)

        // A superseded read's failure/defer must not clear the newer task's loading state.
        let replaced = try begin(3); await waitUntil { held[3] != nil }
        let replacement = try begin(4); await waitUntil { held[4] != nil }
        let replacementGeneration = state.notesGeneration
        try fail(3); await replaced.value
        XCTAssertTrue(replaced.isCancelled); XCTAssertTrue(state.notesLoading)
        XCTAssertEqual(state.notesGeneration, replacementGeneration); XCTAssertNil(state.notesFailure)
        try complete(4, [current]); await replacement.value
        XCTAssertEqual(state.notes, [current]); XCTAssertFalse(state.notesLoading)

        let inputABA = try begin(5); await waitUntil { held[5] != nil }
        state.noteQuery = nfc; state.noteQuery = nfd
        try complete(5, [first]); await inputABA.value
        XCTAssertTrue(inputABA.isCancelled); XCTAssertEqual(state.notes, [current])

        let readerABA = try begin(6); await waitUntil { held[6] != nil }
        var restored = session; restored.restorationID = UUID()
        state.updateNoteContext(session: restored, selection: nil)
        state.updateNoteContext(session: session, selection: nil)
        try complete(6, [first]); await readerABA.value
        XCTAssertTrue(readerABA.isCancelled); XCTAssertEqual(state.notes, [current])

        let reopened = try begin(7); await waitUntil { held[7] != nil }
        state.retireNotes(); state.activateNotes(session: session, selection: nil)
        let live = try begin(8); await waitUntil { held[8] != nil }
        try fail(7); await reopened.value
        XCTAssertTrue(reopened.isCancelled); XCTAssertTrue(state.notesLoading); XCTAssertNil(state.notesFailure)
        try complete(8, [second]); await live.value
        XCTAssertEqual(state.notes, [second])

        let removedReader = try begin(9); await waitUntil { held[9] != nil }
        state.updateNoteContext(session: nil, selection: nil)
        XCTAssertNil(state.readNotes(for: book) { _, _ in XCTFail("A missing reader cannot issue a read"); return [] })
        try complete(9, [first]); await removedReader.value
        XCTAssertTrue(removedReader.isCancelled); XCTAssertEqual(state.notes, [second])
        state.updateNoteContext(session: session, selection: nil)
        let cancelled = try begin(10); await waitUntil { held[10] != nil }
        cancelled.cancel(); try complete(10, [first]); await cancelled.value
        XCTAssertEqual(state.notes, [second]); XCTAssertFalse(state.notesLoading)

        let failed = try begin(11); await waitUntil { held[11] != nil }
        try fail(11); await failed.value
        XCTAssertNotNil(state.notesFailure); XCTAssertEqual(state.notes, [second])
        let retry = try begin(12); await waitUntil { held[12] != nil }
        try complete(12, [current]); await retry.value
        XCTAssertEqual(state.notes, [current]); XCTAssertNil(state.notesFailure); XCTAssertFalse(state.notesLoading)
        state.retireNotes()
        XCTAssertNil(state.readNotes(for: book) { _, _ in XCTFail("A retired presentation cannot issue a read"); return [] })
    }

    func testRealOriginalSearchRetirementCancelsExactReadAndPreservesConfirmedResults() async throws {
        let digest = "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
        let input = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 8_871_723, digest: digest)
        let original = try Data(contentsOf: input, options: .mappedIfSafe)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealSearchLifetime-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let storageA = root.appendingPathComponent("A/Core")
        let gateA = try StagingCoreGate(storage: storageA)
        defer { gateA.release(); gateA.destroy() }
        let storageB = root.appendingPathComponent("B/Core")
        let gateB = try StagingCoreGate(storage: storageB)
        defer { gateB.release(); gateB.destroy() }
        let libraryA = try ReaderLibraryService(storageURL: storageA, sourceURL: root.appendingPathComponent("A/Sources"),
                                                client: gateA, timing: gateA.timing)
        let libraryB = try ReaderLibraryService(storageURL: storageB, sourceURL: root.appendingPathComponent("B/Sources"),
                                                client: gateB, timing: gateB.timing)
        var ownedTasks: [Task<Void, Never>] = []
        var retiring: ReaderTextToolsState?
        var current: ReaderTextToolsState?
        do {
            let importedA = try await libraryA.importBook(at: input)
            let importedB = try await libraryB.importBook(at: input)
            XCTAssertTrue(importedA.created); XCTAssertTrue(importedB.created)
            XCTAssertEqual(importedA.book.bookId, "local:" + digest)
            XCTAssertEqual(importedB.book.bookId, importedA.book.bookId)
            let beforeA = try await libraryA.progress(for: importedA.book)
            let beforeB = try await libraryB.progress(for: importedB.book)
            // Reuse this actual original and existing private Core to exercise
            // real cursor pages/receipt replay, with no extra import or corpus.
            let cursorKeyword = "许元"
            let cursorFirst = try await libraryA.searchContent(for: importedA.book,
                keyword: cursorKeyword, limit: 2, cursor: nil)
            XCTAssertEqual(cursorFirst.results.count, 2)
            let originalCursor = try XCTUnwrap(cursorFirst.nextCursor)
            let cursorSecond = try await libraryA.searchContent(for: importedA.book,
                keyword: cursorKeyword, limit: 2, cursor: originalCursor)
            let cursorReplay = try await libraryA.searchContent(for: importedA.book,
                keyword: cursorKeyword, limit: 2, cursor: originalCursor)
            XCTAssertEqual(cursorSecond, cursorReplay, "The same input token replays the original Core receipt")
            let cursorHits = cursorFirst.results + cursorSecond.results
            XCTAssertEqual(cursorHits.count, 4)
            XCTAssertEqual(Set(cursorHits.map(\.id)).count, 4, "Two actual cursor pages must not repeat a hit")
            try await libraryA.closeContentSearch(for: importedA.book, keyword: cursorKeyword,
                cursor: cursorSecond.nextCursor ?? originalCursor)
            var actualBodies: [UInt32: ReaderChapterContent] = [:]
            for hit in cursorHits {
                let index = try XCTUnwrap(UInt32(exactly: hit.chapterIndex))
                let body: ReaderChapterContent
                if let retained = actualBodies[index] { body = retained }
                else {
                    body = try await libraryA.content(for: importedA.book, chapterIndex: index)
                    actualBodies[index] = body
                }
                let range = try hit.scalarRange(for: importedA.book, content: body)
                let lower = ReaderTextCoordinates.utf16Offset(in: body.content, scalarOffset: range.lowerBound)
                let upper = ReaderTextCoordinates.utf16Offset(in: body.content, scalarOffset: range.upperBound)
                XCTAssertEqual((body.content as NSString).substring(with: NSRange(location: lower, length: upper - lower)), cursorKeyword)
            }
            // Both keywords already exist in the actual original. All result
            // values below come from the real Core, never a fabricated page.
            let baselineA = try await libraryA.searchContent(for: importedA.book, keyword: "斟酌用词", limit: 100, offset: 0)
            let baselineB = try await libraryB.searchContent(for: importedB.book, keyword: "斟酌用词", limit: 100, offset: 0)
            let first = try XCTUnwrap(baselineA.results.first)
            let originalScope = try XCTUnwrap(first.positionScope)
            XCTAssertFalse(baselineB.results.isEmpty)

            // Gate only delivery of one original Core result. Reader state must
            // disappear before this deliberately retained terminal is released.
            retiring = ReaderTextToolsState()
            retiring?.results = baselineA.results
            retiring?.submitted = "斟酌用词"
            retiring?.hasMore = baselineA.hasMore
            retiring?.query = "全成就"
            retiring?.returnPosition = (originalScope, first.chapterOffset)
            let firstHeld = expectation(description: "Original Core search terminal is retained")
            gateA.hold("search.content", advanceObserverDeadline: false)
            gateA.onHeld = { firstHeld.fulfill() }
            retiring?.startSearch(for: importedA.book, using: libraryA, more: false)
            let firstTask = try XCTUnwrap(retiring?.searchTask); ownedTasks.append(firstTask)
            await fulfillment(of: [firstHeld], timeout: 30)
            let retiredID = try actualHeldSearch(gateA)
            weak var oldState = retiring
            retiring?.cancelSearch()
            XCTAssertNil(retiring?.searchTask)
            XCTAssertEqual(retiring?.searchLoading, false)
            XCTAssertEqual(retiring?.results, baselineA.results)
            XCTAssertEqual(retiring?.submitted, "斟酌用词")
            XCTAssertEqual(retiring?.query, "全成就")
            XCTAssertEqual(retiring?.requested, "全成就")
            XCTAssertEqual(retiring?.hasMore, baselineA.hasMore)
            XCTAssertEqual(retiring?.returnPosition?.0, originalScope)
            XCTAssertEqual(retiring?.returnPosition?.1, first.chapterOffset)
            await observeCancel(retiredID, gate: gateA)
            XCTAssertTrue(gateA.hasHeldTerminal)
            retiring = nil
            XCTAssertNil(oldState, "Presentation state must release independently of the retained original Core terminal")
            XCTAssertTrue(gateA.hasHeldTerminal)
            gateA.release()
            await firstTask.value

            // A fresh task is held by the second existing gate so its lifetime
            // is observable while the old generation completes. Separate Core
            // directories avoid opening two runtimes against one real library.
            current = ReaderTextToolsState()
            current?.results = baselineA.results
            current?.submitted = "斟酌用词"
            current?.hasMore = baselineA.hasMore
            current?.returnPosition = (originalScope, first.chapterOffset)
            current?.query = "全成就"
            let staleHeld = expectation(description: "Previous generation's actual Core result is retained")
            gateA.hold("search.content", advanceObserverDeadline: false)
            gateA.onHeld = { staleHeld.fulfill() }
            current?.startSearch(for: importedA.book, using: libraryA, more: false)
            let staleTask = try XCTUnwrap(current?.searchTask); ownedTasks.append(staleTask)
            await fulfillment(of: [staleHeld], timeout: 30)
            let staleID = try actualHeldSearch(gateA)
            let previousGeneration = try XCTUnwrap(current?.searchGeneration)
            current?.cancelSearch()
            await observeCancel(staleID, gate: gateA)

            let freshHeld = expectation(description: "New generation's actual Core result remains in flight")
            gateB.hold("search.content", advanceObserverDeadline: false)
            gateB.onHeld = { freshHeld.fulfill() }
            current?.query = "斟酌用词"
            current?.startSearch(for: importedB.book, using: libraryB, more: false)
            let freshTask = try XCTUnwrap(current?.searchTask); ownedTasks.append(freshTask)
            let currentGeneration = try XCTUnwrap(current?.searchGeneration)
            XCTAssertNotEqual(currentGeneration, previousGeneration)
            await fulfillment(of: [freshHeld], timeout: 30)
            _ = try actualHeldSearch(gateB)
            gateA.release()
            await staleTask.value
            XCTAssertEqual(current?.searchGeneration, currentGeneration)
            XCTAssertNotNil(current?.searchTask, "An old completion must not clear the new owned Task")
            XCTAssertEqual(current?.searchLoading, true)
            XCTAssertEqual(current?.requested, "斟酌用词")
            XCTAssertEqual(current?.results, baselineA.results)
            XCTAssertEqual(current?.returnPosition?.0, originalScope)
            XCTAssertEqual(current?.returnPosition?.1, first.chapterOffset)
            XCTAssertTrue(gateB.hasHeldTerminal)
            gateB.release()
            await freshTask.value
            XCTAssertNil(current?.searchTask)
            XCTAssertEqual(current?.searchLoading, false)
            XCTAssertEqual(current?.results, baselineB.results)
            XCTAssertEqual(current?.submitted, "斟酌用词")
            XCTAssertEqual(current?.hasMore, baselineB.hasMore)
            XCTAssertNil(current?.searchFailure)
            XCTAssertEqual(gateA.cancelRequestIDs, [retiredID, staleID], "Only the two retired original reads are cancelled")
            XCTAssertTrue(gateB.cancelRequestIDs.isEmpty, "The new Core read is not cancelled by an old owner")

            let afterA = try await libraryA.progress(for: importedA.book)
            let afterB = try await libraryB.progress(for: importedB.book)
            XCTAssertEqual(afterA, beforeA)
            XCTAssertEqual(afterB, beforeB)
            let retainedA = try await libraryA.retainedSourceURL(for: importedA.book)
            let retainedB = try await libraryB.retainedSourceURL(for: importedB.book)
            XCTAssertEqual(try Data(contentsOf: input), original)
            XCTAssertEqual(try Data(contentsOf: retainedA), original)
            XCTAssertEqual(try Data(contentsOf: retainedB), original)
            XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: input)).map { String(format: "%02x", $0) }.joined(), digest)
            try await libraryA.close(); try await libraryB.close()
        } catch {
            retiring?.cancelSearch(); current?.cancelSearch()
            ownedTasks.forEach { $0.cancel() }
            gateA.release(); gateB.release()
            for task in ownedTasks { await task.value }
            try? await libraryA.close(); try? await libraryB.close()
            throw error
        }
    }

    private func actualHeldSearch(_ gate: StagingCoreGate) throws -> UInt64 {
        let id = try XCTUnwrap(gate.heldRequestID)
        let terminal = try XCTUnwrap(gate.originalTerminal("search.content"))
        XCTAssertEqual(terminal.requestId, id)
        XCTAssertEqual(terminal.type, "result")
        guard terminal.requestId == id, terminal.type == "result",
              let rows = terminal.data?["results"] as? [[String: Any]], !rows.isEmpty else {
            throw BoundaryError.missingActualResult
        }
        return id
    }

    private func observeCancel(_ id: UInt64, gate: StagingCoreGate) async {
        let observed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in gate.cancelRequestIDs.contains(id) }, object: nil)
        await fulfillment(of: [observed], timeout: 5)
        XCTAssertTrue(gate.cancelRequestIDs.contains(id), "Observe the exact native cancel dispatch, not a presumed Core cancellation ACK")
    }

    private func waitUntil(_ predicate: @escaping () -> Bool) async {
        for _ in 0..<32 {
            if predicate() { return }
            await Task.yield()
        }
        let observed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in predicate() }, object: nil)
        await fulfillment(of: [observed], timeout: 3)
        XCTAssertTrue(predicate())
    }
}

/// Scripted wire boundary only; no source/parser/position implementation.
private final class CursorSearchCoreBoundary: ReaderCoreEventClient, @unchecked Sendable {
    struct Call {
        let requestID: UInt64
        let data: Data
        func parameters() throws -> [String: Any] { try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]) }
    }
    private enum Reply { case data([String: Any]), error(String) }
    private let lock = NSLock()
    private var scripts: [Reply] = []
    private var replies: [UInt64: ReaderCoreEvent] = [:]
    private var searches: [Call] = []
    private var closes: [Call] = []
    private var heldCloseCursors: Set<String> = []
    private var closeRequests: [UInt64: String] = [:]
    var searchCalls: [Call] { lock.lock(); defer { lock.unlock() }; return searches }
    var closedCalls: [Call] { lock.lock(); defer { lock.unlock() }; return closes }
    func enqueue(_ data: [String: Any]) { lock.lock(); defer { lock.unlock() }; scripts.append(.data(data)) }
    func enqueueFailure(reason: String) { lock.lock(); defer { lock.unlock() }; scripts.append(.error(reason)) }
    func holdClose(_ cursor: String) { lock.lock(); defer { lock.unlock() }; heldCloseCursors.insert(cursor) }
    func releaseClose(_ cursor: String) { lock.lock(); defer { lock.unlock() }; heldCloseCursors.remove(cursor) }
    func releaseAllCloses() { lock.lock(); defer { lock.unlock() }; heldCloseCursors.removeAll() }
    @discardableResult
    func send(method: String, requestId: UInt64, params: [String: Any]) throws -> UInt64 {
        lock.lock(); defer { lock.unlock() }
        var envelope: [String: Any] = ["protocolVersion": ReaderCoreClient.protocolVersion, "requestId": requestId, "type": "result"]
        switch method {
        case "search.content":
            let call = Call(requestID: requestId, data: try JSONSerialization.data(withJSONObject: params))
            if params["closeCursor"] as? Bool == true {
                closes.append(call); envelope["data"] = ["results": [], "hasMore": false] as [String: Any]
                closeRequests[requestId] = params["cursor"] as? String
            } else {
                searches.append(call)
                guard !scripts.isEmpty else { throw ReaderLibraryError.invalidResponse("Unscripted search boundary read") }
                switch scripts.removeFirst() {
                case .data(let data): envelope["data"] = data
                case .error(let reason):
                    envelope["type"] = "error"
                    envelope["error"] = ["code": "INVALID_PARAMS", "message": "Controlled boundary failure", "retryable": true,
                        "details": ["reason": reason]] as [String: Any]
                }
            }
        case "runtime.storage.flush": envelope["data"] = [:] as [String: Any]
        default: throw ReaderLibraryError.invalidResponse("Unexpected cursor boundary method: " + method)
        }
        replies[requestId] = try ReaderCoreEvent(data: JSONSerialization.data(withJSONObject: envelope))
        return requestId
    }
    func pollEvent(requestId: UInt64) -> Result<ReaderCoreEvent, ReaderCoreClientError>? {
        lock.lock(); defer { lock.unlock() }
        if let cursor = closeRequests[requestId], heldCloseCursors.contains(cursor) { return nil }
        closeRequests.removeValue(forKey: requestId)
        return replies.removeValue(forKey: requestId).map { .success($0) }
    }
    func cancel(requestId: UInt64) throws {}
    func destroy() {}
}
