import Foundation
import ReaderCoreBridge
import ReaderHost
import XCTest
@testable import ReaderApp

private struct ColdReadReceipt: Codable {
    let rootName: String
    let writerPID: Int32
    let book: String
    let originalSHA256: String
    let local: String
    let offset: Int64
    let otherSourceId: String
    let otherOffset: Int64
}

private actor GateSystemHost: CoreHost {
    nonisolated let capabilities: [ReaderHostCapability] = [.timeNow]
    private let system = SystemSurfaceHost()
    private var arrived: CheckedContinuation<Void, Never>?
    private var resumeClock: CheckedContinuation<Void, Never>?
    private(set) var seen: [ReaderHostCapability] = []

    func execute(_ request: ReaderHostRequestEvent) async -> CoreHostReply {
        seen.append(request.capability)
        if request.capability == .timeNow {
            await withCheckedContinuation { continuation in
                resumeClock = continuation
                arrived?.resume()
                arrived = nil
            }
        }
        return await system.execute(request)
    }

    func waitForClock() async {
        if resumeClock == nil { await withCheckedContinuation { arrived = $0 } }
    }

    func releaseClock() {
        resumeClock?.resume()
        resumeClock = nil
    }
}

@MainActor
final class ClientsRPCIntegrationTests: XCTestCase {
    func test01FreshImportWriteAndFence() async throws {
        let root = try isolatedRoot()
        let directory = root.appendingPathComponent("library", isDirectory: true)
        let library = try await LibraryHost.open(directory: directory)
        assertLibrary47(library, fresh: true)
        let layout = try CoreFileABI.probe(directory).observation.layout?.layoutId
        XCTAssertEqual(layout, "reader-sqlite-47-remote")
        let core = library.runtime
        let cases: LifeFixture = try decodeFixture("reading-lifecycle")
        let selection: ScalarFixture = try decodeFixture("scalar-selection")
        let original = try await importFixture(fixture("local-reading", "txt"), runtime: core, root: root)
        let book = original.bookId
        let chapter = try await core.request(ReaderM1.localBookChapterContent, .init(bookId: book, chapterIndex: 0)).value
        try selection.verify(in: chapter.content)
        let localKey = TextReadingProgressGetParams(bookId: book, sourceId: cases.localSourceId)
        let before = try await core.request(ReaderM1.readingProgressGet, localKey).value
        let revision = try XCTUnwrap(before.progressRevision)
        let body = try XCTUnwrap(chapter.bodyVersion)
        let processing = try XCTUnwrap(chapter.processingVersion)
        func changes(_ revision: String, _ body: String, _ processing: String) -> TextReadingProgressUpdateParams {
            .init(expectedProgressRevision: revision, bookId: book, sourceId: cases.localSourceId,
                  chapterIndex: 0, chapterOffset: selection.startScalar, chapterProgress: 0.25,
                  expectedBodyVersion: body, expectedProcessingVersion: processing)
        }

        let fence = try StorageWriteFence(directory.appendingPathComponent("reader-core.sqlite3"))
        defer { fence.release() }
        try fence.execute("BEGIN IMMEDIATE")
        let coordinator = ReadingSessionCoordinator(runtime: core)
        var oldPagePublications = 0
        let dispatch = AsyncStream<CoreOperationID>.makeStream(bufferingPolicy: .unbounded)
        let owner = coordinator.save(changes(revision, body, processing), onDispatched: { id in
            dispatch.continuation.yield(id)
            dispatch.continuation.finish()
        }) { _ in oldPagePublications += 1 }
        var observed = dispatch.stream.makeAsyncIterator()
        let activeId = await observed.next()
        let active = try XCTUnwrap(activeId)
        coordinator.retirePage()
        try fence.execute("ROLLBACK")
        let terminal = try await owner.value
        XCTAssertEqual(terminal.id.runtimeId, core.runtimeId)
        XCTAssertEqual(terminal.id, active)
        XCTAssertTrue(terminal.value.stored)
        XCTAssertEqual(terminal.value.chapterOffset, selection.startScalar)
        XCTAssertEqual(oldPagePublications, 0)
        let capacity = try await core.request(ReaderM1.runtimeStatus, .init(includeCapacity: true)).value
        XCTAssertEqual(capacity.capacity?.current.pendingDeliveryCount, 0)
        let after = try await core.request(ReaderM1.coreInfo, .init()).value
        XCTAssertEqual(after.sqliteUserVersion, 47)

        let updated = try XCTUnwrap(terminal.value.progressRevision)
        for (params, reason) in [
            (changes(updated, "stale-body", processing), cases.stalePositionReason),
            (changes(updated, body, "stale-processing"), cases.stalePositionReason),
            (changes(revision, body, processing), cases.staleProgressReason)
        ] {
            do {
                _ = try await core.request(ReaderM1.readingProgressUpdate, params)
                XCTFail("Stale write was accepted")
            } catch let rejection as CoreRequestFailure {
                XCTAssertEqual(rejection.value.code, .invalidParams)
                XCTAssertEqual(rejection.value.details?.reason, reason)
            }
        }
        let other = try await core.request(ReaderM1.readingProgressUpdate, .init(
            bookId: book, sourceId: cases.otherSourceId, chapterIndex: cases.otherChapterIndex,
            chapterOffset: cases.otherScalar, chapterProgress: 0.5
        )).value
        XCTAssertEqual(other.sourceId, cases.otherSourceId)
        XCTAssertEqual(other.chapterOffset, cases.otherScalar)
        let local = try await core.request(ReaderM1.readingProgressGet, localKey).value
        XCTAssertEqual(local.progress?.chapterOffset, selection.startScalar)

        await core.close()
        let receipt = ColdReadReceipt(
            rootName: root.lastPathComponent, writerPID: ProcessInfo.processInfo.processIdentifier, book: book,
            originalSHA256: original.source.sha256, local: cases.localSourceId, offset: selection.startScalar,
            otherSourceId: cases.otherSourceId, otherOffset: cases.otherScalar
        )
        try JSONEncoder().encode(receipt).write(to: testSupportDirectory.appendingPathComponent("rpc-cold.json"), options: .atomic)
        print("M1_RPC_WRITE pid=\(receipt.writerPID) layout=\(layout ?? "-") source=\(original.source.sha256) terminal=\(terminal.id.requestId) oldPage=\(oldPagePublications) deliveryBacklog=0 local=\(receipt.offset) other=\(receipt.otherOffset) conflicts=3")
    }

    func test02ColdProcessReadAndExisting47() async throws {
        let bytes = try Data(contentsOf: testSupportDirectory.appendingPathComponent("rpc-cold.json"))
        let receipt = try JSONDecoder().decode(ColdReadReceipt.self, from: bytes)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        XCTAssertNotEqual(currentPID, receipt.writerPID)
        let root = try testSupportDirectory.appendingPathComponent(receipt.rootName)
        let library = try await LibraryHost.open(directory: root.appendingPathComponent("library"))
        assertLibrary47(library, fresh: false)
        XCTAssertEqual(library.probe.observation.layout?.layoutId, "reader-sqlite-47-remote")
        let core = library.runtime
        let detail = try await core.request(ReaderM1.bookshelfGet, .init(sourceId: receipt.local, bookId: receipt.book)).value
        XCTAssertEqual(detail.original?.sha256, receipt.originalSHA256)
        let local = try await core.request(ReaderM1.readingProgressGet, .init(bookId: receipt.book, sourceId: receipt.local)).value
        let other = try await core.request(ReaderM1.readingProgressGet, .init(bookId: receipt.book, sourceId: receipt.otherSourceId)).value
        XCTAssertEqual(local.progress?.chapterOffset, receipt.offset)
        XCTAssertEqual(other.progress?.chapterOffset, receipt.otherOffset)
        let originalHost = FileAndAssetHost(root: root.appendingPathComponent("assets"), sandboxRoots: [])
        let retained = try await originalHost.retained(sha256: receipt.originalSHA256)
        XCTAssertEqual(try hash(retained.path), receipt.originalSHA256)
        await core.close()

        let existing = try isolatedRoot()
        let existingDirectory = existing.appendingPathComponent("library", isDirectory: true)
        try FileManager.default.createDirectory(at: existingDirectory, withIntermediateDirectories: true)
        let writer = try StorageWriteFence(existingDirectory.appendingPathComponent("reader-core.sqlite3"), create: true)
        defer { writer.release() }

        let statements = try (1...2).map {
            try String(contentsOf: fixture("library47-schema-\($0)", "sqlpart"), encoding: .utf8)
        }.joined()
        try writer.execute(statements)
        try writer.execute("INSERT INTO library_identity_meta(id,library_id) VALUES(1,'11111111111111111111111111111111')")
        try writer.execute("INSERT INTO library_identity_authority(id,restore_nonce) VALUES(1,'22222222222222222222222222222222')")
        writer.release()
        let seed = try await CoreRuntimeActor.open(config: .init(dataDirectory: existingDirectory.path), host: SystemSurfaceHost())
        let source = try await importFixture(fixture("local-reading", "txt"), runtime: seed, root: existing)
        let saved = try await seed.request(ReaderM1.readingProgressUpdate, .init(
            bookId: source.bookId, sourceId: "local", chapterIndex: 0, chapterOffset: receipt.offset
        )).value
        XCTAssertTrue(saved.stored)
        await seed.close()
        let opened = try await LibraryHost.open(directory: existingDirectory)
        assertLibrary47(opened, fresh: false)
        let old = try await opened.runtime.request(ReaderM1.bookshelfGet, .init(sourceId: "local", bookId: source.bookId)).value
        let position = try await opened.runtime.request(ReaderM1.readingProgressGet, .init(bookId: source.bookId, sourceId: "local")).value
        XCTAssertEqual(old.original?.sha256, source.source.sha256)
        XCTAssertEqual(position.progress?.chapterOffset, saved.chapterOffset)
        await opened.runtime.close()
        print("M1_RPC_COLD writerPID=\(receipt.writerPID) readerPID=\(currentPID) local=\(receipt.offset) other=\(receipt.otherOffset) existingLayout=\(opened.probe.observation.layout?.layoutId ?? "-") existingOriginal=\(source.source.sha256)")
    }

    func test03CapabilityRejectionAndReverseTerminals() async throws {
        let host = GateSystemHost()
        let library = try await LibraryHost.open(directory: isolatedRoot(), host: host)
        let core = library.runtime
        let cases: LifeFixture = try decodeFixture("reading-lifecycle")
        let slow = Task { try await core.request(ReaderM1.runtimeHostSmokeTimeNow, .init(params: .init())) }
        await host.waitForClock()
        let fast = try await core.request(ReaderM1.coreInfo, .init())
        await host.releaseClock()
        let first = try await slow.value
        XCTAssertGreaterThan(fast.id.requestId, first.id.requestId)
        XCTAssertEqual(first.id.runtimeId, fast.id.runtimeId)
        XCTAssertGreaterThan(first.value.unixMillis, 0)
        do {
            _ = try await core.request(ReaderM1.runtimeHostSmokeCookieGet, .init(
                params: .init(url: "https://example.invalid/", name: "session")
            ))
            XCTFail("Undeclared capability was dispatched")
        } catch let rejection as CoreRequestFailure {
            XCTAssertEqual(rejection.value.code, .internal)
            XCTAssertEqual(rejection.value.details?.host?.diagnostics?.code.rawValue, cases.unavailableDiagnostic)
            XCTAssertEqual(rejection.value.details?.host?.capability.rawValue, cases.hostOmitted)
        }
        let deliveries = await core.deliveries()
        XCTAssertEqual(deliveries.acknowledgementCount, deliveries.terminalCount + 1)
        let seen = await host.seen
        XCTAssertEqual(seen.map(\.rawValue), [cases.hostSupported])
        let status = try await core.request(ReaderM1.runtimeStatus, .init(includeCapacity: true)).value
        XCTAssertEqual(status.capacity?.current.pendingDeliveryCount, 0)
        await core.close()
        print("M1_RPC_HOST first=\(first.id.requestId) second=\(fast.id.requestId) completionOrder=second,first negative=INTERNAL/\(cases.unavailableDiagnostic) omittedSlotCalls=0 deliveryBacklog=0")
    }

}
