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
            return try JSONDecoder().decode(ReaderContentSearchPage.self,
                from: JSONSerialization.data(withJSONObject: ["results": rows, "hasMore": hasMore]))
        }
        let first = try page([1, 2], hasMore: true), next = try page([3, 4], hasMore: false)
        var calls: [(bookID: String, keyword: String, limit: UInt32, offset: UInt32)] = []
        var failNext = false
        let search: ReaderTextToolsState.Search = { book, keyword, limit, offset in
            calls.append((book.id, keyword, limit, offset))
            if failNext { failNext = false; throw BoundaryError.missingActualResult }
            return offset == 0 ? first : next
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
        XCTAssertEqual(state.failedSearchRequest?.offset, 0)
        XCTAssertEqual(state.failedSearchRequest?.append, false)
        XCTAssertEqual(state.results, first.results)
        state.query = "New unsubmitted user input"
        state.retrySearch(for: book, search: search)
        await (try XCTUnwrap(state.searchTask)).value
        XCTAssertEqual(calls.last?.keyword, "Original keyword")
        XCTAssertEqual(calls.last?.offset, 0); XCTAssertEqual(calls.last?.limit, 100)
        XCTAssertEqual(state.results, first.results); XCTAssertNil(state.searchFailure)
        XCTAssertEqual(state.query, "New unsubmitted user input")

        // A failed More request retains its original offset and append intent.
        failNext = true
        state.startSearch(for: book, more: true, search: search)
        await (try XCTUnwrap(state.searchTask)).value
        XCTAssertEqual(state.failedSearchRequest?.offset, 2)
        XCTAssertEqual(state.failedSearchRequest?.append, true)
        let originalCalls = calls.count
        let other = ReaderBook(bookId: "other-search-owner", title: "Other owner")
        state.retrySearch(for: other, search: search)
        XCTAssertEqual(calls.count, originalCalls); XCTAssertNil(state.searchTask)
        state.retrySearch(for: book, search: search)
        await (try XCTUnwrap(state.searchTask)).value
        XCTAssertEqual(calls.last?.bookID, book.id); XCTAssertEqual(calls.last?.keyword, "Original keyword")
        XCTAssertEqual(calls.last?.offset, 2)
        XCTAssertEqual(state.results, first.results + next.results)
        XCTAssertFalse(state.hasMore); XCTAssertNil(state.failedSearchRequest)
        XCTAssertEqual(calls.count, 5)
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
