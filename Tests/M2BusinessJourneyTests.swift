import Foundation
import ReaderCoreBridge
import ReaderHost
import XCTest
@testable import ReaderApp

private struct M2DeletedSourceCheckpoint: Codable {
    let pid: Int32
    let directory: String
    let params: M2RulesMutationApplyParams
    let ackFingerprint: String
    let writerProgressRevision: String
    let progress: ReadingProgressData
}

@MainActor
final class M2BusinessJourneyTests: XCTestCase {
    func test01SourceManagementV9Transactions() async throws {
        let root = try m2Support().appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let (library, network) = try await m2Open(root, fresh: true)
        let runtime = library.runtime
        let sources = SourceManagementCoordinator(runtime: runtime, network: network)
        let primary = M2BusinessFixture.Source(suite: "sources", edition: "primary")
        let other = M2BusinessFixture.Source(suite: "sources", edition: "other")
        let document = try await M2BusinessFixture.read(primary.path + "/import")
        let entries = try JSONDecoder().decode([[String: ReaderM1JSONValue]].self, from: document)
        let ids = [primary.id, other.id]
        XCTAssertEqual(entries.count, ids.count)
        var previews: [SourceImportPreview] = []
        for (id, item) in zip(ids, entries) {
            XCTAssertEqual(item["bookSourceUrl"], .string(id))
            previews.append(try await sources.previewImport(.init(sourceId: id, bookSource: item)))
        }
        let beforeImport = try await sources.list()
        XCTAssertEqual(beforeImport.total, 0)
        for preview in previews {
            let confirmation = try await sources.confirmImport(preview)
            guard case .sourceImport(let original) = confirmation else {
                XCTFail("Expected original source import terminal")
                throw M2BusinessFixture.Failure.incorrectProtocolVariant
            }
            let exact = try await sources.query(.init(
                operationId: original.binding.operationId, sequence: original.binding.sequence,
                mutation: .sourceImport(.init(params: preview.params))
            ))
            guard case .sourceImport(let retained)? = exact.receipt else {
                XCTFail("Exact source import receipt is missing")
                throw M2BusinessFixture.Failure.incorrectProtocolVariant
            }
            XCTAssertEqual(retained.ackFingerprint, original.ackFingerprint)
            XCTAssertEqual(retained.data.sourceId, preview.params.sourceId)
            print("M2_SOURCE_IMPORT steps=document/preview/confirm source=\(retained.data.sourceId) operation=\(retained.binding.operationId)")
        }
        let imported = try await sources.list()
        XCTAssertEqual(Set(imported.sources.map(\.sourceId)), Set(ids))

        let check = try await sources.check(.init(reportVersion: .v2, mode: .search,
            sourceIds: [primary.id, other.id], keyword: M2BusinessFixture.title, timeoutMs: 12000,
            levels: [.l1, .l2, .l3, .l4, .l5]))
        XCTAssertEqual(Set(check.results.map(\.sourceId)), Set([primary.id, other.id]))
        for source in check.results {
            XCTAssertTrue(source.available, "\(source.sourceId): \(source.failureReason ?? "-")")
            let report = try XCTUnwrap(source.report)
            XCTAssertEqual(report.steps.filter { $0.status == .pass }.map(\.level), [.l1, .l2, .l3, .l4, .l5])
            XCTAssertFalse(report.traceId.isEmpty)
        }
        let before = try await sources.list(.init(includeCheckReports: true, checkReportVersion: .v2))
        let primaryReport = try XCTUnwrap(before.sources.first { $0.sourceId == primary.id }?.checkReports?.first)
        let otherReport = try XCTUnwrap(before.sources.first { $0.sourceId == other.id }?.checkReports?.first)
        let drillDown = try await sources.reports(for: other.id)
        XCTAssertEqual(drillDown.first?.report.traceId, otherReport.report.traceId)
        XCTAssertFalse(primaryReport.stale)
        XCTAssertFalse(otherReport.stale)
        print("M2_SOURCE_CHECK levels=L1,L2,L3,L4,L5 primary=\(primaryReport.report.traceId) other=\(otherReport.report.traceId)")

        let online = OnlineReadingCoordinator(runtime: runtime)
        let book = try await m2AddToShelf(primary, runtime: runtime)
        let libraryReading = ReadingSessionCoordinator(runtime: runtime)
        await libraryReading.beginOnline(book: book, files: m2Files(root), startChapter: 0)
        let chapter = try XCTUnwrap(libraryReading.chapter)
        XCTAssertEqual(chapter.projection.content, M2BusinessFixture.chapterOne)
        libraryReading.measured(7, expected: chapter.generation)
        let saved = await libraryReading.drain()
        XCTAssertTrue(saved)
        let progressBefore = try await runtime.request(ReaderM1.readingProgressGet,
            .init(bookId: primary.bookID, sourceId: primary.id)).value
        XCTAssertEqual(progressBefore.progress?.chapterOffset, 7)

        try await setCookie(primary, value: "principal", runtime: runtime)
        try await setCookie(other, value: "another", runtime: runtime)
        let primaryBefore = try await cookies(primary, runtime: runtime)
        let otherBefore = try await cookies(other, runtime: runtime)
        XCTAssertEqual(primaryBefore, ["principal"])
        XCTAssertEqual(otherBefore, ["another"])
        _ = try await sources.clearLogin(sourceId: primary.id, url: primary.loginURL)
        let after = try await sources.list(.init(includeCheckReports: true, checkReportVersion: .v2))
        let primaryAfter = try await cookies(primary, runtime: runtime)
        let otherAfter = try await cookies(other, runtime: runtime)
        XCTAssertEqual(after.sources.first { $0.sourceId == primary.id }?.checkReports?.count, 0)
        XCTAssertEqual(after.sources.first { $0.sourceId == other.id }?.checkReports?.first?.report.traceId,
                       otherReport.report.traceId)
        XCTAssertEqual(primaryAfter, [])
        XCTAssertEqual(otherAfter, ["another"])
        print("M2_SOURCE_CLEAR primaryReport=0 retainedOther=\(otherReport.report.traceId) selectedCookie=0 otherCookie=1")

        _ = try await sources.check(.init(reportVersion: .v2, sourceIds: [primary.id], levels: [.l1]))
        try await setCookie(primary, value: "reenabled-session", runtime: runtime)
        let liveLogin = try await network.beginLogin(sourceId: primary.id, url: primary.loginURL, timeout: .seconds(8))
        let deadline = ContinuousClock.now + .seconds(10)
        while liveLogin.state == .loading, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(35))
        }
        XCTAssertEqual(liveLogin.state, .ready)
        let disabled = try await sources.updateEnabled(.init(sourceId: primary.id, enabled: false))
        guard case .sourceUpdate(let originalDisable) = disabled else {
            XCTFail("Expected source disable original receipt")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        let disabledSource = try await sources.list(.init(sourceId: primary.id))
        let disabledReports = try await sources.reports(for: primary.id)
        let disabledCookies = try await cookies(primary, runtime: runtime)
        XCTAssertFalse(originalDisable.data.source.enabled)
        XCTAssertEqual(disabledSource.sources.first?.enabled, false)
        XCTAssertTrue(disabledReports.isEmpty)
        XCTAssertTrue(disabledCookies.isEmpty)
        XCTAssertEqual(liveLogin.state, .revoked)
        print("M2_SOURCE_DISABLE login=revoked cookies=0 reports=0 operation=\(originalDisable.binding.operationId)")

        try await subscriptionEvolution(sources, runtime: runtime)

        let removed = try await sources.delete(.init(sourceIds: [primary.id]))
        guard case .sourceDelete(let original) = removed else {
            XCTFail("Single transaction source.delete must have original applied receipt: \(removed)")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        XCTAssertEqual(original.data.deleted, 1)
        let cleanupProjection = try await sources.list(.init(sourceId: primary.id))
        XCTAssertEqual(cleanupProjection.total, 0)
        let reloaded = try await runtime.request(ReaderM1.bookshelfGet,
            .init(sourceId: primary.id, bookId: primary.bookID)).value
        XCTAssertEqual(reloaded.book?.bookId, primary.bookID)
        let cache = try await online.chapter(primary.chapter(1, cacheOnly: true))
        XCTAssertEqual(cache.via, .cache)
        XCTAssertEqual(cache.content, .string(M2BusinessFixture.chapterOne))
        let savedPosition = try await runtime.request(ReaderM1.readingProgressGet,
            .init(bookId: primary.bookID, sourceId: primary.id)).value
        let durableProgress = try XCTUnwrap(savedPosition.progress)
        XCTAssertEqual(durableProgress.chapterOffset, 7)
        XCTAssertEqual(savedPosition.progressRevision, progressBefore.progressRevision)
        XCTAssertEqual(try encodedProgress(durableProgress), try encodedProgress(XCTUnwrap(progressBefore.progress)))
        try m2WriteReceipt(M2DeletedSourceCheckpoint(
            pid: ProcessInfo.processInfo.processIdentifier, directory: root.lastPathComponent,
            params: .init(operationId: original.binding.operationId, sequence: original.binding.sequence,
                          mutation: .sourceDelete(.init(params: .init(sourceIds: [primary.id])))),
            ackFingerprint: original.ackFingerprint, writerProgressRevision: try XCTUnwrap(savedPosition.progressRevision),
            progress: durableProgress
        ), named: "source-cold-receipt.json")
        print("M2_SOURCE_DELETE operation=\(original.binding.operationId) shelf=retained cache=\(cache.via.rawValue) scalar=7")
        await runtime.close()
    }

    func verifyColdSourceManagement(pid: Int32) async throws {
        let checkpoint = try m2ReadReceipt(M2DeletedSourceCheckpoint.self, named: "source-cold-receipt.json")
        XCTAssertNotEqual(checkpoint.pid, pid)
        let root = try m2Support().appending(path: checkpoint.directory, directoryHint: .isDirectory)
        let (library, network) = try await m2Open(root, fresh: false)
        let primary = M2BusinessFixture.Source(suite: "sources", edition: "primary")
        let other = M2BusinessFixture.Source(suite: "sources", edition: "other")
        let runtime = library.runtime
        let sources = SourceManagementCoordinator(runtime: runtime, network: network)
        let original = try await sources.query(checkpoint.params)
        guard case .sourceDelete(let removed)? = original.receipt else {
            XCTFail("Missing exact delete receipt after process replacement")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        XCTAssertEqual(removed.ackFingerprint, checkpoint.ackFingerprint)
        let deleted = try await sources.list(.init(sourceId: primary.id))
        XCTAssertEqual(deleted.total, 0)
        let reports = try await sources.reports(for: other.id)
        XCTAssertFalse(reports.isEmpty)
        let subscription = try await sources.subscription(.init(id: 91))
        XCTAssertEqual(subscription.sub?.type, 3)
        let subscribedSource = try await sources.list(.init(sourceId: M2BusinessFixture.base + "/books/sources/subscription"))
        XCTAssertEqual(subscribedSource.sources.first?.name, "回环订阅 v2")
        let book = try await runtime.request(ReaderM1.bookshelfGet, .init(sourceId: primary.id, bookId: primary.bookID)).value
        XCTAssertEqual(book.book?.bookId, primary.bookID)
        let retained = try await OnlineReadingCoordinator(runtime: runtime).chapter(primary.chapter(1, cacheOnly: true))
        XCTAssertEqual(retained.content, .string(M2BusinessFixture.chapterOne))
        let progress = try await runtime.request(ReaderM1.readingProgressGet, .init(bookId: primary.bookID, sourceId: primary.id)).value
        let durableProgress = try XCTUnwrap(progress.progress)
        let coldRevision = try XCTUnwrap(progress.progressRevision)
        XCTAssertEqual(durableProgress.chapterOffset, 7)
        XCTAssertEqual(try encodedProgress(durableProgress), try encodedProgress(checkpoint.progress))
        // The CAS token includes the storage-open epoch. Match durable fields
        // across the writer and reader instead of carrying a writer-side CAS.
        XCTAssertNotEqual(coldRevision, checkpoint.writerProgressRevision)
        print("M2_SOURCE_COLD writer=\(checkpoint.pid) reader=\(pid) deleteOperation=\(removed.binding.operationId) report=retained subscription=v2 book=retained cache=\(retained.via.rawValue) scalar=7 durableProgress=identical casRevision=rotated")
        await runtime.close()
    }

    private func encodedProgress(_ progress: ReadingProgressData) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(progress)
    }

    private func subscriptionEvolution(
        _ sources: SourceManagementCoordinator, runtime: CoreRuntimeActor
    ) async throws {
        let base = "/books/sources/subscription"
        let origin = M2BusinessFixture.base + base
        let subscriptionId: Int64 = 91
        let feed = base + "/package/1"
        try await M2BusinessFixture.configure(feed, "ok")
        let saved = try await sources.putSubscription(.init(id: subscriptionId, name: "回环规则订阅", url: origin + "/package/1", type: 3))
        guard case .ruleSubPut(let terminal) = saved else {
            XCTFail("Expected rule subscription write, got \(saved)")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        XCTAssertEqual(terminal.data.sub.id, subscriptionId)
        for version in 1...2 {
            if version == 2 { try await M2BusinessFixture.configure(feed, "package2") }
            let observed = try await sources.subscription(.init(id: subscriptionId))
            let sub = try XCTUnwrap(observed.sub)
            let plan = try await sources.fetchSubscriptionPreview(sub)
            XCTAssertEqual(plan.subscriptionId, subscriptionId)
            XCTAssertFalse(plan.planId.isEmpty)
            XCTAssertEqual(Set(plan.changes.map(\.kind)), version == 1 ? [.added] : [.added, .update])
            let ids = plan.changes.map(\.sourceId)
            let applied = try await sources.confirmSubscription(plan, sourceIds: ids)
            guard case .ruleSubUpdateApplyV1(let receipt) = applied else {
                XCTFail("Expected original rules subscription update, got \(applied)")
                throw M2BusinessFixture.Failure.incorrectProtocolVariant
            }
            XCTAssertEqual(Set(receipt.data.appliedSourceIds), Set(ids))
            let matches = try await sources.list(.init(sourceId: origin))
            XCTAssertEqual(matches.sources.first?.name, "回环订阅 v\(version)")
            print("M2_RULE_SUB version=\(version) changes=\(plan.changes.map { $0.kind.rawValue }.sorted()) operation=\(receipt.binding.operationId)")
        }
        let list = try await runtime.request(ReaderM2.ruleSubList, .init()).value
        XCTAssertEqual(list.subs.map(\.id), [subscriptionId])
    }

    private func setCookie(
        _ source: M2BusinessFixture.Source, value: String, runtime: CoreRuntimeActor
    ) async throws {
        let cookie = M2HostCookieRecord(name: "m2SourceLogin", value: value, path: "/")
        let stored = try await runtime.request(ReaderM2.runtimeHostSmokeCookieSet,
            .init(params: .init(cookie: cookie, url: source.loginURL.absoluteString, sessionId: source.id))).value
        XCTAssertTrue(stored.stored)
    }

    private func cookies(
        _ source: M2BusinessFixture.Source, runtime: CoreRuntimeActor
    ) async throws -> [String] {
        try await runtime.request(ReaderM2.runtimeHostSmokeCookieGet,
            .init(params: .init(url: source.loginURL.absoluteString, name: "m2SourceLogin", sessionId: source.id)))
            .value.cookies.compactMap(\.value)
    }
}
