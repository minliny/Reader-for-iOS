import Foundation
import ReaderCoreBridge
import ReaderHost
import XCTest
@testable import ReaderApp

private struct M2DownloadColdReceipt: Codable {
    let pid: Int32
    let directory: String
    let request: M2CacheBookPrefetchParams
    let binding: M2ReadingOperationBinding
}

@MainActor
extension M2BusinessJourneyTests {
    private var downloadReceiptURL: URL {
        get throws { try m2Support().appending(path: "download-cold-receipt.json") }
    }

    @objc func test03DownloadControlsAndWriteColdReceipt() async throws {
        let root = try m2Support().appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let (library, network) = try await m2Open(root, fresh: true)
        let runtime = library.runtime
        let input = M2BusinessFixture.Source(suite: "downloads", edition: "primary")
        let sources = SourceManagementCoordinator(runtime: runtime, network: network)
        _ = try await m2Import(input, with: sources)
        let online = OnlineReadingCoordinator(runtime: runtime)
        let catalog = try await online.directory(input.directoryParams)
        XCTAssertEqual(catalog.toc.count, 4)
        let entries = M2CacheBookStatusParams(sourceId: input.id, bookId: input.bookID, includeChapterStates: true)
        let journal = root.appending(path: "download-input-journal.json")
        let downloads = DownloadCoordinator(runtime: runtime, journal: journal)
        let first = makeDownload(input, range: [0, 1], sequence: 1)
        let firstPath = input.chapterPath(1)
        let initial = try await M2BusinessFixture.state()
        try await M2BusinessFixture.configure(firstPath, "hold")
        let original = try downloads.begin(first)
        let firstBinding: M2ReadingOperationBinding
        do {
            try await M2BusinessFixture.waitForRequest(firstPath, after: initial.count(firstPath))
            let running = try await downloads.queryPrefetch(first)
            XCTAssertEqual(running.receipt?.phase, .pending)
            firstBinding = try XCTUnwrap(running.receipt?.binding)
            XCTAssertFalse(running.canResumeOriginal)
            let controls = M2CacheDownloadTaskParams(sourceId: input.id, bookId: input.bookID, chapterIndex: 0)
            let pause = try await downloads.pause(controls)
            XCTAssertEqual(pause.status, .paused)
            let paused = try await downloads.status(entries)
            XCTAssertEqual(paused.chapters.first { $0.chapterIndex == 0 }?.state, .paused)
            let resume = try await downloads.resume(controls)
            XCTAssertEqual(resume.status, .pending)
            let cancel = try await downloads.cancel(controls)
            XCTAssertEqual(cancel.status, .cancelled)
            let cancelled = try await downloads.status(entries)
            XCTAssertEqual(cancelled.chapters.first { $0.chapterIndex == 0 }?.state, .cancelled)
            print("M2_DOWNLOAD_CONTROLS operation=\(first.operationId ?? "-") observed=\(pause.status.rawValue)→\(resume.status.rawValue)→\(cancel.status.rawValue)")
            try await M2BusinessFixture.release(firstPath)
        } catch {
            try? await M2BusinessFixture.release(firstPath)
            throw error
        }
        do {
            _ = try await original.value
            XCTFail("The pinned Core should classify the stale Host completion as an original terminal error")
        } catch let terminal as CoreRequestFailure {
            XCTAssertEqual(terminal.value.code, .internal)
            XCTAssertTrue(terminal.value.message.contains("READING_PREPARATION_queue_owner"))
            print("M2_DOWNLOAD_ORIGINAL_ERROR request=\(terminal.id.requestId) code=\(terminal.value.code.rawValue) message=\(terminal.value.message)")
        }
        let unclosed = try await downloads.queryPrefetch(first)
        let exactPending = try XCTUnwrap(unclosed.receipt)
        XCTAssertTrue(unclosed.canResumeOriginal)
        XCTAssertEqual(exactPending.phase, .pending)
        assertSameBinding(exactPending.binding, firstBinding)
        let beforeRecovery = try await M2BusinessFixture.state()
        let recoveredCancellation = try await downloads.recoverPrefetch(first)
        XCTAssertEqual(recoveredCancellation.phase, .settled)
        assertSameBinding(recoveredCancellation.binding, firstBinding)
        guard case .prefetch(let noFetch)? = recoveredCancellation.data else {
            XCTFail("Expected exact original no-fetch result when settled after cancellation")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        XCTAssertEqual(noFetch.prefetchedCount, 0)
        XCTAssertTrue(noFetch.materializations.isEmpty)
        let afterRecovery = try await M2BusinessFixture.state()
        XCTAssertEqual(afterRecovery.count(firstPath), beforeRecovery.count(firstPath))
        print("M2_DOWNLOAD_CANCEL_RECOVERY operation=\(firstBinding.operationId) payload=\(firstBinding.payloadFingerprint) phase=pending→settled fetched=0")
        let exactCancelled = try await downloads.queryPrefetch(first)
        XCTAssertEqual(exactCancelled.receipt?.phase, .settled)
        let afterOriginal = try await downloads.status(entries)
        XCTAssertEqual(afterOriginal.chapters.first { $0.chapterIndex == 0 }?.state, .cancelled)

        let second = makeDownload(input, range: [1, 2], sequence: 2)
        let secondPath = input.chapterPath(2)
        let beforeRetire = try await M2BusinessFixture.state()
        try await M2BusinessFixture.configure(secondPath, "hold")
        let background = try downloads.begin(second)
        do {
            try await M2BusinessFixture.waitForRequest(secondPath, after: beforeRetire.count(secondPath))
            let panel = downloads.panelGeneration
            downloads.retirePanel()
            XCTAssertGreaterThan(downloads.panelGeneration, panel)
            let retained = try await downloads.queryPrefetch(second)
            XCTAssertEqual(retained.receipt?.phase, .pending)
            XCTAssertFalse(retained.canResumeOriginal)
            try await M2BusinessFixture.release(secondPath)
        } catch {
            try? await M2BusinessFixture.release(secondPath)
            throw error
        }
        let continued = try await background.value
        XCTAssertEqual(continued.value.prefetchedCount, 1)
        XCTAssertEqual(continued.value.materializations.map(\.chapterIndex), [1])
        let cached = try await online.chapter(input.chapter(2, cacheOnly: true))
        XCTAssertEqual(cached.via, .cache)
        let secondStatus = try await downloads.status(entries)
        XCTAssertEqual(secondStatus.chapters.first { $0.chapterIndex == 1 }?.state, .completed)
        let report = try await downloads.queryPrefetch(second)
        XCTAssertEqual(report.receipt?.phase, .settled)
        print("M2_DOWNLOAD_RETIRED operation=\(second.operationId ?? "-") request=\(continued.id.requestId) pending→settled fetched=1 queue=completed")

        let cold = makeDownload(input, range: [3, 4], sequence: 3)
        let coldPath = input.chapterPath(4)
        let beforeCold = try await M2BusinessFixture.state()
        try await M2BusinessFixture.configure(coldPath, "hold")
        _ = try downloads.begin(cold)
        do {
            try await M2BusinessFixture.waitForRequest(coldPath, after: beforeCold.count(coldPath))
            let live = try await downloads.queryPrefetch(cold)
            let pending = try XCTUnwrap(live.receipt)
            XCTAssertEqual(pending.phase, .pending)
            XCTAssertEqual(pending.binding.operationId, cold.operationId)
            XCTAssertFalse(live.canResumeOriginal)
            let pid = ProcessInfo.processInfo.processIdentifier
            let checkpoint = M2DownloadColdReceipt(pid: pid, directory: root.lastPathComponent, request: cold,
                                                  binding: pending.binding)
            try JSONEncoder().encode(checkpoint).write(to: downloadReceiptURL, options: .atomic)
            print("M2_DOWNLOAD_WRITE pid=\(pid) operation=\(pending.binding.operationId) phase=pending canResumeOriginal=false payload=\(pending.binding.payloadFingerprint)")
            // XCTest ends this app process after the write selectors. The held
            // response stays unacknowledged in Core until the separate cold run.
        } catch {
            try? await M2BusinessFixture.release(coldPath)
            throw error
        }
    }

    @objc func test04ColdProcessRecoversOriginalDownload() async throws {
        let receipt = try JSONDecoder().decode(M2DownloadColdReceipt.self, from: Data(contentsOf: downloadReceiptURL))
        let pid = ProcessInfo.processInfo.processIdentifier
        XCTAssertNotEqual(receipt.pid, pid)
        let root = try m2Support().appending(path: receipt.directory, directoryHint: .isDirectory)
        let (library, _) = try await m2Open(root, fresh: false)
        let runtime = library.runtime
        let input = M2BusinessFixture.Source(suite: "downloads", edition: "primary")
        let downloads = DownloadCoordinator(runtime: runtime, journal: root.appending(path: "download-input-journal.json"))
        let reopened = try await downloads.queryPrefetch(receipt.request)
        let original = try XCTUnwrap(reopened.receipt)
        XCTAssertTrue(reopened.canResumeOriginal)
        XCTAssertEqual(original.phase, .pending)
        assertSameBinding(original.binding, receipt.binding)
        let changed = M2CacheBookPrefetchParams(
            sourceId: receipt.request.sourceId, bookId: receipt.request.bookId,
            chapterRange: receipt.request.chapterRange, priority: 9, requestedAt: receipt.request.requestedAt,
            operationId: receipt.request.operationId, sequence: receipt.request.sequence
        )
        do {
            _ = try await downloads.queryPrefetch(changed)
            XCTFail("changed original payload unexpectedly passed exact query")
        } catch let error as CoreRequestFailure {
            XCTAssertEqual(error.value.code, .invalidParams)
        }

        let path = input.chapterPath(4)
        let before = try await M2BusinessFixture.state()
        try await M2BusinessFixture.release(path)
        let recovered = try await downloads.recoverSavedPrefetches()
        XCTAssertEqual(recovered.count, 1)
        let settled = try XCTUnwrap(recovered.first)
        XCTAssertEqual(settled.phase, .settled)
        assertSameBinding(settled.binding, receipt.binding)
        guard case .prefetch(let terminal)? = settled.data else {
            XCTFail("Missing durable original prefetch payload")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        XCTAssertEqual(terminal.materializations.map(\.chapterIndex), [3])
        XCTAssertEqual(terminal.prefetchedCount, 1)
        let after = try await M2BusinessFixture.state()
        XCTAssertEqual(after.count(path), before.count(path) + 1)
        XCTAssertTrue(after.failures.isEmpty)
        let final = try await downloads.queryPrefetch(receipt.request)
        XCTAssertEqual(final.receipt?.phase, .settled)
        let alreadyDrained = try await downloads.recoverSavedPrefetches()
        XCTAssertTrue(alreadyDrained.isEmpty)
        let cached = try await OnlineReadingCoordinator(runtime: runtime).chapter(input.chapter(4, cacheOnly: true))
        XCTAssertEqual(cached.via, .cache)
        let queue = try await downloads.status(.init(sourceId: input.id, bookId: input.bookID, includeChapterStates: true))
        XCTAssertEqual(queue.chapters.first { $0.chapterIndex == 3 }?.state, .completed)
        print("M2_DOWNLOAD_COLD writer=\(receipt.pid) reader=\(pid) operation=\(settled.binding.operationId) phase=pending→settled payload=\(settled.binding.payloadFingerprint) partialReplayCount=1 cache=\(cached.via.rawValue) queue=completed")
        await runtime.close()
        try await verifyColdSourceManagement(pid: pid)
        try await verifyColdOnlineReading(pid: pid)
    }

    private func makeDownload(
        _ source: M2BusinessFixture.Source, range: [Int64], sequence: Int64
    ) -> M2CacheBookPrefetchParams {
        .init(sourceId: source.id, bookId: source.bookID, chapterRange: range, requestedAt: 40 + sequence,
              operationId: "\(UUID().uuidString.lowercased())/\(sequence)", sequence: sequence)
    }

    private func assertSameBinding(_ actual: M2ReadingOperationBinding, _ expected: M2ReadingOperationBinding) {
        XCTAssertEqual(actual.operationId, expected.operationId)
        XCTAssertEqual(actual.sequence, expected.sequence)
        XCTAssertEqual(actual.payloadFingerprint, expected.payloadFingerprint)
    }
}
