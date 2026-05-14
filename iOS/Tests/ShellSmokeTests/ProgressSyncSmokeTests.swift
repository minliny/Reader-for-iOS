import XCTest
import ReaderAppSupport
@testable import ReaderShellValidation

final class ProgressSyncSmokeTests: XCTestCase {

    // MARK: - Manager Defaults

    @MainActor
    func testDefaultSyncDisabled() {
        let manager = ProgressSyncManager.shared
        manager.resetConfiguration()
        XCTAssertFalse(manager.isSyncEnabled)

        manager.handleTrigger(.appLaunch)
        if case .failed(let msg) = manager.syncState {
            XCTAssertTrue(msg.contains("not configured"))
        } else {
            XCTFail("Should be in failed state when sync not configured")
        }
    }

    @MainActor
    func testConfigureEnablesSync() {
        let manager = ProgressSyncManager.shared
        let fake = FakeProgressSyncAdapter()
        manager.configure(adapter: fake)
        XCTAssertTrue(manager.isSyncEnabled)
        manager.resetConfiguration()
    }

    // MARK: - Fake Adapter

    func testFakeAdapterPushAndPull() async throws {
        let adapter = FakeProgressSyncAdapter()
        let progress = ReadingProgress(
            bookID: "book-1",
            sourceID: "src",
            bookURL: "https://example.com/book/1",
            chapterURL: "/ch/1",
            chapterTitle: "Chapter 1",
            progressRatio: 0.5
        )
        try await adapter.pushProgress(progress)
        let pulled = try await adapter.pullProgress(bookID: "book-1")
        XCTAssertEqual(pulled?.progressRatio, 0.5)
    }

    func testFakeAdapterListReturnsPushed() async throws {
        let adapter = FakeProgressSyncAdapter()
        let p1 = ReadingProgress(bookID: "a", sourceID: "s", bookURL: "b1", chapterURL: "c1", chapterTitle: "t1")
        let p2 = ReadingProgress(bookID: "b", sourceID: "s", bookURL: "b2", chapterURL: "c2", chapterTitle: "t2")
        try await adapter.pushProgress(p1)
        try await adapter.pushProgress(p2)
        let list = try await adapter.listRemoteProgress()
        XCTAssertEqual(list.count, 2)
    }

    // MARK: - Conflict Resolution

    func testLocalWinsPolicy() {
        let resolver = ProgressSyncConflictResolver(policy: .localWins)
        let local = ReadingProgress(bookID: "x", sourceID: "s", bookURL: "b", chapterURL: "c1", chapterTitle: "t", progressRatio: 0.8)
        let remote = ReadingProgress(bookID: "x", sourceID: "s", bookURL: "b", chapterURL: "c2", chapterTitle: "t", progressRatio: 0.3)
        let result = resolver.resolve(local: local, remote: remote)
        XCTAssertTrue(result.resolved)
        XCTAssertEqual(result.finalProgress?.progressRatio, 0.8)
    }

    func testRemoteWinsPolicy() {
        let resolver = ProgressSyncConflictResolver(policy: .remoteWins)
        let local = ReadingProgress(bookID: "x", sourceID: "s", bookURL: "b", chapterURL: "c1", chapterTitle: "t", progressRatio: 0.3)
        let remote = ReadingProgress(bookID: "x", sourceID: "s", bookURL: "b", chapterURL: "c2", chapterTitle: "t", progressRatio: 0.9)
        let result = resolver.resolve(local: local, remote: remote)
        XCTAssertTrue(result.resolved)
        XCTAssertEqual(result.finalProgress?.progressRatio, 0.9)
    }

    func testNewestTimestampWinsPolicy() {
        let resolver = ProgressSyncConflictResolver(policy: .newestTimestampWins)
        let older = ReadingProgress(bookID: "x", sourceID: "s", bookURL: "b", chapterURL: "c1", chapterTitle: "t", progressRatio: 0.2, updatedAt: Date.distantPast)
        let newer = ReadingProgress(bookID: "x", sourceID: "s", bookURL: "b", chapterURL: "c2", chapterTitle: "t", progressRatio: 0.9, updatedAt: Date())
        let result = resolver.resolve(local: older, remote: newer)
        XCTAssertTrue(result.resolved)
        XCTAssertEqual(result.finalProgress?.progressRatio, 0.9)
    }

    func testManualRequiredDoesNotAutoResolve() {
        let resolver = ProgressSyncConflictResolver(policy: .manualRequired)
        let local = ReadingProgress(bookID: "x", sourceID: "s", bookURL: "b", chapterURL: "c1", chapterTitle: "t")
        let remote = ReadingProgress(bookID: "x", sourceID: "s", bookURL: "b", chapterURL: "c2", chapterTitle: "t")
        let result = resolver.resolve(local: local, remote: remote)
        XCTAssertFalse(result.resolved)
        XCTAssertNil(result.finalProgress)
        XCTAssertEqual(result.conflictPolicy, .manualRequired)
    }

    // MARK: - All Triggers Defined

    func testAllTriggersDefined() {
        XCTAssertEqual(ProgressSyncTrigger.allCases.count, 6)
        XCTAssertTrue(ProgressSyncTrigger.allCases.contains(.exitReader))
        XCTAssertTrue(ProgressSyncTrigger.allCases.contains(.appWillTerminate))
    }

    // MARK: - ConflictPolicy All Cases

    func testConflictPolicyAllCases() {
        XCTAssertEqual(ProgressSyncConflictPolicy.allCases.count, 4)
    }
}
