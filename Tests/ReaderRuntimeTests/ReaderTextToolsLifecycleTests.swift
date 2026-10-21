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
}
