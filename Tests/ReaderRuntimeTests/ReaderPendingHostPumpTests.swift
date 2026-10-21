import CryptoKit
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

final class ReaderPendingHostPumpTests: XCTestCase {
    /// No mock Host response is supplied: the original source package, search,
    /// admission and uncached download all use the native Core/Host transport.
    func testRealDownloadObserverTimeoutPumpsOriginalHostRequestsAndRetainsExactACK() async throws {
        let manager = FileManager.default
        let documents = try XCTUnwrap(manager.urls(for: .documentDirectory, in: .userDomainMask).first)
        let packageURL = documents.appendingPathComponent("Reader-real-sources.json")
        let package = try Data(contentsOf: packageURL)
        XCTAssertEqual(SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined(),
                       "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322")
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderRealLateHost-" + UUID().uuidString)
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                                               sourceURL: root.appendingPathComponent("Sources"))
        do {
            let imported = try await service.importSources(package, operationID: UUID().uuidString)
            XCTAssertEqual(imported.count, 2)
            XCTAssertTrue(imported.allSatisfy(\.succeeded))
            let sources = try await service.onlineSources().filter(\.enabled)
            var candidate: ReaderOnlineCandidate?
            var outcomes: [[String: Any]] = []
            for source in sources {
                do {
                    let result = try await service.searchSource(source.id, keyword: "剑来", page: 1)
                    outcomes.append(["sourceId": source.id, "count": result.books.count])
                    if candidate == nil { candidate = result.books.first }
                } catch { outcomes.append(["sourceId": source.id, "failure": error.localizedDescription]) }
            }
            let searchEvidence = XCTAttachment(data: try JSONSerialization.data(withJSONObject: outcomes, options: [.sortedKeys]),
                                               uniformTypeIdentifier: "public.json")
            searchEvidence.name = "Late-Host-actual-source-search"; searchEvidence.lifetime = .keepAlways; add(searchEvidence)
            let detail = try await service.onlineDetail(XCTUnwrap(candidate, "A real source candidate is required; no fixture fallback"))
            let book = try await service.addOnlineBook(detail, chapterIndex: detail.firstReadableIndex, operationID: UUID().uuidString)
            let before = try await service.readerDownloadStatus(book)
            let occupied = Set(before.chapters.filter { $0.state != .missing }.map(\.chapterIndex))
            let chapter = try XCTUnwrap(detail.chapters.first {
                !$0.url.isEmpty && $0.index < UInt32.max && !occupied.contains($0.index)
            }, "An actual uncached readable chapter is required to exercise a late Host request")
            let range = chapter.index..<(chapter.index + 1)
            let operationID = UUID().uuidString
            let business: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId,
                "chapterRange": [range.lowerBound, range.upperBound], "contentKind": "text", "priority": 0,
                "requestedAt": Int64(Date().timeIntervalSince1970 * 1000)]
            // request checks this observer deadline after original dispatch and
            // before polling. A fast synchronous success is NOT an alternative
            // passing path: every Host envelope must be consumed by the pump.
            do {
                _ = try await service.downloadMutation("cache.book.prefetch", business,
                    operationID: operationID, scope: "download:" + book.id, timeout: 0)
                XCTFail("The dispatched original must first be reported pending")
            } catch ReaderLibraryError.operationPending(let id) { XCTAssertEqual(id, operationID) }
            let originalParameters = try await service.existingCoreParameters(operationID: operationID, method: "cache.book.prefetch")
            let original = try XCTUnwrap(originalParameters)
            let initialWrites = await service.unresolvedWrites
            let (requestID, _) = try XCTUnwrap(initialWrites.first { $0.value.owner == .command(operationID) })
            let durablePending = try await service.pendingCoreCommands().first { $0.id == operationID }
            XCTAssertEqual(durablePending?.acknowledged, false)
            let completed = try await service.isCoreOperationCompleted(operationID)
            XCTAssertFalse(completed)

            // Condition polling only observes the original owner. It does not
            // dispatch, reconcile, issue an exact query or consume its terminal.
            let deadline = ProcessInfo.processInfo.systemUptime + 120
            var late: PendingMutation?
            repeat {
                late = await service.unresolvedWrites[requestID]
                if late?.terminal != nil { break }
                try await Task.sleep(nanoseconds: 20_000_000)
            } while ProcessInfo.processInfo.systemUptime < deadline
            let observed = try XCTUnwrap(late)
            XCTAssertEqual(observed.owner, .command(operationID))
            XCTAssertGreaterThan(observed.lateHostHandledCount, 0,
                                 "No late Host work means this did not exercise the failed continuation")
            let originalTerminal = try XCTUnwrap(observed.terminal, "The same original Core job must reach its terminal")
            let event = try originalTerminal.get()
            XCTAssertEqual(event.requestId, requestID)
            XCTAssertEqual(event.type, "result", "A source failure remains a real failure")
            let originalACK = try XCTUnwrap(event.data)
            XCTAssertEqual(originalACK["sourceId"] as? String, book.sourceId)
            XCTAssertEqual(originalACK["bookId"] as? String, book.bookId)
            let reconciled = try await service.reconcileCoreCommand(operationID: operationID)
            XCTAssertEqual(try canonical(originalACK), try canonical(JSONSerialization.jsonObject(with: reconciled)))
            let retainedParameters = try await service.existingCoreParameters(operationID: operationID, method: "cache.book.prefetch")
            XCTAssertEqual(try canonical(original), try canonical(XCTUnwrap(retainedParameters)))

            let query: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId, "action": "prefetch",
                "operationId": try XCTUnwrap(original["operationId"]), "expected": ["action": "prefetch", "params": original]]
            let queried = try await service.coreRead("cache.download.operation.query", query)
            let queryObject = try XCTUnwrap(JSONSerialization.jsonObject(with: queried) as? [String: Any])
            let receipt = try XCTUnwrap(queryObject["receipt"] as? [String: Any])
            XCTAssertEqual(try canonical(XCTUnwrap(receipt["data"])), try canonical(originalACK),
                           "Only the complete original DTO's exact Core receipt may confirm the ACK")
            let paused = try await service.pauseDownload(book, chapterIndex: chapter.index, operationID: UUID().uuidString)
            XCTAssertEqual(paused.status, "paused")
            // Consume the original lease's exact paused disposition. The old
            // resource report must not complete a newer task generation.
            _ = try await service.downloadChapters(book, range: range, operationID: operationID)
            let pausedStatus = try await service.readerDownloadStatus(book)
            XCTAssertEqual(pausedStatus.chapters.first { $0.chapterIndex == chapter.index }?.state, .paused)
            // Core and Host chapter slots must both be released for the new
            // acquisition child's materialization report, while its resume
            // parent stays owned until the actual new download is complete.
            _ = try await service.resumeDownload(book, chapterIndex: chapter.index, operationID: UUID().uuidString)
            let after = try await service.readerDownloadStatus(book)
            XCTAssertEqual(after.chapters.first { $0.chapterIndex == chapter.index }?.state, .completed)
            let cached = try await service.cachedDownloadBody(book, chapter: chapter.index)
            XCTAssertFalse(cached.content.isEmpty, "A fresh body is a final projection, never the old write ACK")
            XCTAssertEqual(try Data(contentsOf: packageURL), package)
            try await service.close()
            try manager.removeItem(at: root)
        } catch {
            // Do not remove an unsettled library while an original Host job can
            // still write into it. Keep its exact intent as failure evidence.
            let evidence = XCTAttachment(string: "Retained late-Host library: " + root.path + "\n" + String(describing: error))
            evidence.name = "Late-Host-failure-original-owner"; evidence.lifetime = .keepAlways; add(evidence)
            try? await service.close()
            throw error
        }
    }

    private func canonical(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }
}
