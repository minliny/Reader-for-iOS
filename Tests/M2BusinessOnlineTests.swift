import Foundation
import ReaderCoreBridge
import ReaderHost
import XCTest
@testable import ReaderApp

private struct M2OnlineCheckpoint: Codable {
    let pid: Int32
    let directory: String
    let params: M2SourceSwitchCommitParams
    let switchFingerprint: String
    let pending: M2SourceSwitchCommitParams
    let pendingFingerprint: String
    let anchor: Int
}

@MainActor
extension M2BusinessJourneyTests {
    @objc func test02SearchOnlineReadingAndSourceSwitch() async throws {
        let root = try m2Support().appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let (library, network) = try await m2Open(root, fresh: true)
        let runtime = library.runtime
        let sources = SourceManagementCoordinator(runtime: runtime, network: network)
        let primary = M2BusinessFixture.Source(suite: "online", edition: "primary")
        let secondary = M2BusinessFixture.Source(suite: "online", edition: "secondary")
        let additional = ["reservea", "reserveb", "reservec"].map {
            M2BusinessFixture.Source(suite: "online", edition: $0)
        }
        let searchable = [primary, secondary] + additional
        for source in searchable { _ = try await m2Import(source, with: sources) }
        let result = try await verifySearch(runtime: runtime, primary: primary, sources: searchable)
        XCTAssertEqual(result.bookId, primary.bookID)

        let online = OnlineReadingCoordinator(runtime: runtime)
        let detail = try await online.detail(primary.detailParams)
        XCTAssertEqual(detail.book.title, M2BusinessFixture.title)
        XCTAssertEqual(detail.tocUrl, primary.tocURL)
        let catalog = try await online.directory(primary.directoryParams)
        XCTAssertEqual(catalog.toc.map(\.title), M2BusinessFixture.chapterTitles)
        XCTAssertEqual(catalog.directoryProofState, .verified)
        let priorVersion = try XCTUnwrap(catalog.catalogVersion)
        let book = try await m2AddToShelf(primary, runtime: runtime)
        let session = ReadingSessionCoordinator(runtime: runtime)
        await session.beginOnline(book: book, files: m2Files(root), startChapter: 0)
        let opened = try XCTUnwrap(session.chapter)
        XCTAssertEqual(opened.projection.content, M2BusinessFixture.chapterOne)
        XCTAssertEqual(opened.index, 0)
        let anchor = 14
        session.measured(anchor, expected: opened.generation)
        let saved = await session.drain()
        XCTAssertTrue(saved)
        try await verifyRefreshedDirectory(online, session: session, source: primary, priorVersion: priorVersion)
        XCTAssertEqual(session.chapter?.index, 0)
        XCTAssertEqual(session.position, anchor)

        let firstPath = primary.chapterPath(1)
        let secondPath = primary.chapterPath(2)
        let hits = try await M2BusinessFixture.state()
        try await M2BusinessFixture.configure(firstPath, "offline")
        let refreshed = await session.refreshOnlineChapter()
        XCTAssertFalse(refreshed)
        XCTAssertNotNil(session.onlineFailure)
        let refreshedHits = try await M2BusinessFixture.state()
        XCTAssertGreaterThan(refreshedHits.count(firstPath), hits.count(firstPath))
        XCTAssertEqual(session.chapter?.projection.bodyVersion, opened.projection.bodyVersion)
        XCTAssertEqual(session.chapter?.projection.content, opened.projection.content)
        XCTAssertEqual(session.position, anchor, "a failed explicit refresh preserves the acknowledged scalar")

        try await M2BusinessFixture.configure(firstPath, "disconnect")
        try await M2BusinessFixture.configure(secondPath, "disconnect")
        await session.reopen()
        XCTAssertEqual(session.chapter?.projection.content, opened.projection.content)
        XCTAssertEqual(session.chapter?.anchor, anchor)
        let beforeUncached = session.chapter?.generation
        await session.chooseChapter(1)
        XCTAssertNotNil(session.onlineFailure)
        let disconnectedHits = try await M2BusinessFixture.state()
        XCTAssertGreaterThan(disconnectedHits.count(secondPath), refreshedHits.count(secondPath))
        XCTAssertEqual(disconnectedHits.count(firstPath), refreshedHits.count(firstPath),
                       "the cached chapter should reopen before touching the disconnected response")
        XCTAssertEqual(session.chapter?.index, 0)
        XCTAssertEqual(session.position, anchor)
        XCTAssertNotEqual(session.generation, beforeUncached)
        let cacheOnly = try await online.chapter(primary.chapter(1, cacheOnly: true))
        XCTAssertEqual(cacheOnly.via, .cache)
        do {
            _ = try await online.chapter(primary.chapter(2))
            XCTFail("uncached chapter unexpectedly opened with disconnected loopback")
        } catch let failure as CoreRequestFailure {
            XCTAssertNotEqual(failure.value.code, .cancelled)
            print("M2_ONLINE_OFFLINE cachedScalar=\(anchor) cache=\(cacheOnly.via.rawValue) uncachedError=\(failure.value.code.rawValue) request=\(failure.id.requestId)")
        }
        try await M2BusinessFixture.configure(firstPath, "ok")
        try await M2BusinessFixture.configure(secondPath, "ok")

        let switches = try await online.switchCandidates(.init(sourceId: primary.id, bookId: primary.bookID,
            keyword: result.title, sourceIds: [secondary.id]))
        let target = try XCTUnwrap(switches.candidates.first { $0.sourceId == secondary.id })
        XCTAssertEqual(target.bookUrl, secondary.bookID)
        let newDetail = try await online.detail(secondary.detailParams)
        let newCatalog = try await online.directory(secondary.directoryParams)
        XCTAssertEqual(newCatalog.toc.map(\.title), catalog.toc.map(\.title))
        XCTAssertNotNil(newCatalog.catalogVersion)
        let operationId = UUID().uuidString.lowercased() + "/1"
        let switchParams = M2SourceSwitchCommitParams(operationId: operationId, sequence: 1,
            from: .init(sourceId: primary.id, bookId: primary.bookID),
            target: .init(sourceId: secondary.id, bookId: target.bookUrl, title: newDetail.book.title, author: target.author,
                          kind: newDetail.book.kind),
            newToc: newCatalog.toc.map { .init(chapterId: $0.url, chapterTitle: $0.title, chapterUrl: $0.url, order: $0.index) },
            currentChapterTitle: opened.title, currentChapterIndex: opened.index,
            updatedAt: Int64(Date().timeIntervalSince1970 * 1000))
        let committed = try await session.switchOnlineSource(switchParams)
        let verified = try await online.querySwitch(.init(operationId: operationId, expected: switchParams))
        let receipt = try XCTUnwrap(verified.transaction)
        XCTAssertEqual(committed.book.sourceId, secondary.id)
        XCTAssertEqual(receipt.operationId, operationId)
        XCTAssertEqual(receipt.phase, .finalized)
        XCTAssertEqual(receipt.from.bookId, primary.bookID)
        XCTAssertEqual(receipt.target.bookId, secondary.bookID)
        XCTAssertEqual(session.chapter?.title, opened.title)
        XCTAssertEqual(session.chapter?.projection.content, opened.projection.content)
        XCTAssertEqual(session.position, anchor)
        let switchedPosition = try await runtime.request(ReaderM1.readingProgressGet,
            .init(bookId: secondary.bookID, sourceId: secondary.id)).value
        XCTAssertEqual(switchedPosition.progress?.chapterOffset, Int64(anchor))
        let interrupted = M2SourceSwitchCommitParams(operationId: UUID().uuidString.lowercased() + "/2", sequence: 2,
            from: .init(sourceId: secondary.id, bookId: secondary.bookID),
            target: .init(sourceId: primary.id, bookId: primary.bookID, title: detail.book.title, author: detail.book.author,
                          kind: detail.book.kind),
            newToc: catalog.toc.map { .init(chapterId: $0.url, chapterTitle: $0.title, chapterUrl: $0.url, order: $0.index) },
            currentChapterTitle: opened.title, currentChapterIndex: opened.index,
            updatedAt: switchParams.updatedAt + 1)
        let outstanding = try await online.switchSource(interrupted)
        XCTAssertEqual(outstanding.phase, .pending)
        let exactPending = try await online.querySwitch(.init(operationId: outstanding.transactionId, expected: interrupted))
        let pending = try XCTUnwrap(exactPending.transaction)
        XCTAssertEqual(pending.phase, .pending)
        try m2WriteReceipt(M2OnlineCheckpoint(
            pid: ProcessInfo.processInfo.processIdentifier, directory: root.lastPathComponent, params: switchParams,
            switchFingerprint: receipt.payloadFingerprint, pending: interrupted,
            pendingFingerprint: pending.payloadFingerprint, anchor: anchor
        ), named: "online-cold-receipt.json")
        print("M2_SOURCE_SWITCH operation=\(operationId) transaction=\(committed.transactionId) phase=\(receipt.phase.rawValue) chapter=0 scalar=\(anchor) directoryVersion=\(priorVersion) interrupted=\(outstanding.transactionId)")
        await runtime.close()
    }

    func verifyColdOnlineReading(pid: Int32) async throws {
        let checkpoint = try m2ReadReceipt(M2OnlineCheckpoint.self, named: "online-cold-receipt.json")
        XCTAssertNotEqual(checkpoint.pid, pid)
        let root = try m2Support().appending(path: checkpoint.directory, directoryHint: .isDirectory)
        let (library, _) = try await m2Open(root, fresh: false)
        let secondary = M2BusinessFixture.Source(suite: "online", edition: "secondary")
        let runtime = library.runtime
        let online = OnlineReadingCoordinator(runtime: runtime)
        let pendingQuery = M2SourceSwitchTransactionQueryParams(operationId: try XCTUnwrap(checkpoint.pending.operationId),
                                                                expected: checkpoint.pending)
        let pending = try await online.querySwitch(pendingQuery).transaction
        XCTAssertEqual(pending?.phase, .pending)
        XCTAssertEqual(pending?.payloadFingerprint, checkpoint.pendingFingerprint)
        let recovered = try await online.recoverSwitches()
        XCTAssertEqual(recovered.recovered.map(\.transactionId), [pendingQuery.operationId])
        let recoveredReceipt = try await online.querySwitch(pendingQuery).transaction
        XCTAssertEqual(recoveredReceipt?.phase, .rolledBack)
        XCTAssertEqual(recoveredReceipt?.payloadFingerprint, checkpoint.pendingFingerprint)
        let original = try await online.querySwitch(
            .init(operationId: XCTUnwrap(checkpoint.params.operationId), expected: checkpoint.params)
        )
        XCTAssertEqual(original.transaction?.phase, .finalized)
        XCTAssertEqual(original.transaction?.payloadFingerprint, checkpoint.switchFingerprint)
        let book = try await runtime.request(ReaderM1.bookshelfGet, .init(sourceId: secondary.id, bookId: secondary.bookID)).value
        let before = try await M2BusinessFixture.state()
        let reading = ReadingSessionCoordinator(runtime: runtime)
        await reading.beginOnline(book: try XCTUnwrap(book.book), files: m2Files(root))
        XCTAssertEqual(reading.chapter?.projection.content, M2BusinessFixture.chapterOne)
        XCTAssertEqual(reading.position, checkpoint.anchor)
        XCTAssertEqual(reading.chapter?.anchor, checkpoint.anchor)
        let after = try await M2BusinessFixture.state()
        XCTAssertEqual(after.count(secondary.chapterPath(1)), before.count(secondary.chapterPath(1)))
        print("M2_ONLINE_COLD writer=\(checkpoint.pid) reader=\(pid) target=\(secondary.id) committed=finalized interrupted=rolledBack scalar=\(checkpoint.anchor)")
        await runtime.close()
    }

    private func verifySearch(
        runtime: CoreRuntimeActor, primary: M2BusinessFixture.Source, sources: [M2BusinessFixture.Source]
    ) async throws -> M2BookSearchBookData {
        let search = SearchCoordinator(runtime: runtime)
        let paths = sources.map { $0.path + "/search" }
        let old = try await M2BusinessFixture.state()
        for path in paths { try await M2BusinessFixture.configure(path, "hold") }
        let owner = try search.startGlobal(keyword: M2BusinessFixture.title)
        do {
            let deadline = ContinuousClock.now + .seconds(12)
            var started: Int
            repeat {
                let state = try await M2BusinessFixture.state()
                started = paths.count { state.count($0) > old.count($0) }
                if started == 4 { break }
                try await Task.sleep(for: .milliseconds(35))
            } while ContinuousClock.now < deadline
            XCTAssertEqual(started, 4)
            search.stopDisplaying()
            XCTAssertTrue(search.inFlight)
            XCTAssertThrowsError(try search.retryGlobal()) {
                guard case SearchCoordinator.Rejection.operationInFlight = $0 else {
                    return XCTFail("same keyword escaped its original in-flight owner: \($0)")
                }
            }
            let held = try await M2BusinessFixture.state()
            XCTAssertEqual(paths.count { held.count($0) == old.count($0) }, 1)
            for path in paths {
                XCTAssertLessThanOrEqual(held.count(path), old.count(path) + 1)
                try await M2BusinessFixture.release(path)
            }
        } catch {
            for path in paths { try? await M2BusinessFixture.release(path) }
            throw error
        }
        let late = try await owner.value
        let originals = try late.map { try $0.terminal.get() }
        XCTAssertEqual(Set(late.map(\.sourceId)), Set(sources.map(\.id)))
        XCTAssertTrue(search.globalResults.isEmpty)
        XCTAssertFalse(search.inFlight)
        let retry = try search.retryGlobal()
        let current = try await retry.value
        XCTAssertEqual(Set(current.map(\.sourceId)), Set(late.map(\.sourceId)))
        XCTAssertEqual(search.globalResults.count, sources.count)
        let repeated = try current.map { try $0.terminal.get() }
        XCTAssertTrue(Set(originals.map(\.id)).isDisjoint(with: Set(repeated.map(\.id))))
        let history = try await search.history()
        XCTAssertEqual(history.keywords.filter { $0 == M2BusinessFixture.title }.count, 1)
        print("M2_SEARCH sections=\(current.count) stoppedIDs=\(originals.map { $0.id.requestId }.sorted()) shownIDs=\(repeated.map { $0.id.requestId }.sorted()) history=1")
        let books = try XCTUnwrap(repeated.first { $0.value.sourceId == primary.id }).value.books
        return try XCTUnwrap(books.first)
    }

    private func verifyRefreshedDirectory(
        _ online: OnlineReadingCoordinator, session: ReadingSessionCoordinator,
        source: M2BusinessFixture.Source, priorVersion: String
    ) async throws {
        let directory = try await online.openDirectory(.init(bookId: source.bookID, sourceId: source.id))
        let node = try XCTUnwrap(directory.nodes?.first { $0.chapterIndex == 0 })
        let oldTarget = M2DirectoryTargetResolveParamsV2(bookId: source.bookID, viewId: try XCTUnwrap(directory.viewId),
            nodeId: node.nodeId, sourceId: source.id, catalogRevision: try XCTUnwrap(directory.catalogRevision),
            structureRevision: try XCTUnwrap(directory.structureRevision))
        let resolved = try await online.resolveTarget(oldTarget)
        XCTAssertEqual(resolved.chapterIndex, 0)
        let path = source.path + "/toc"
        try await M2BusinessFixture.configure(path, "tocRewrite")
        let rewritten = await session.refreshOnlineDirectory()
        XCTAssertFalse(rewritten)
        let failure = try XCTUnwrap(session.onlineFailure as? CoreRequestFailure)
        XCTAssertEqual(failure.value.details?.reason, "CATALOG_CURRENT_CHAPTER_UNRESOLVED")
        let preserved = try await online.cachedDirectory(sourceId: source.id, bookId: source.bookID)
        XCTAssertEqual(preserved?.revision, priorVersion)
        XCTAssertEqual(preserved?.chapters.last?.title, "第四章")
        let stillValid = try await online.resolveTarget(oldTarget)
        XCTAssertEqual(stillValid.chapterIndex, 0)

        try await M2BusinessFixture.configure(path, "toc2")
        let refreshed = await session.refreshOnlineDirectory()
        XCTAssertTrue(refreshed, String(describing: session.onlineFailure))
        try await M2BusinessFixture.configure(path, "ok")
        let cached = try await online.cachedDirectory(sourceId: source.id, bookId: source.bookID)
        XCTAssertNotEqual(cached?.revision, priorVersion)
        XCTAssertEqual(cached?.chapters.last?.title, "第五章")
        do {
            _ = try await online.resolveTarget(oldTarget)
            XCTFail("superseded directory view unexpectedly authorized navigation")
        } catch let failure as CoreRequestFailure {
            XCTAssertEqual(failure.value.code, .invalidParams)
        }
        print("M2_DIRECTORY_REFRESH prior=\(priorVersion) current=\(cached?.revision ?? "-") rewriteRejected=true tailAppended=true staleViewRejected=true")
    }
}
