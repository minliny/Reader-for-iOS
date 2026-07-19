import XCTest
@testable import ReaderApp
@testable import ReaderShellValidation
import ReaderUIContract

@MainActor
final class ReaderCacheCoordinatorTests: XCTestCase {
    func testRefreshAndPrefetchUseOnlyBoundLiveReaderContext() async throws {
        let service = FakeReaderCacheService()
        let coordinator = ReaderCacheCoordinator(service: service)
        coordinator.bind(ReaderCacheContext(
            sourceID: "source-live",
            bookID: "book-live",
            currentChapterIndex: 4
        ))

        coordinator.refresh()
        try await eventually { coordinator.status != nil }

        XCTAssertEqual(service.statusSelectors, ["source-live|book-live"])
        XCTAssertEqual(coordinator.status?.globalStats.queueEntryCount, 3)
        XCTAssertEqual(coordinator.viewState, .succeeded(.status, message: "缓存状态已刷新"))

        coordinator.prefetchFollowingChapters(limit: 3)
        try await eventually { coordinator.lastPrefetchResult != nil }

        XCTAssertEqual(service.prefetchRanges, [[5, 8]])
        XCTAssertEqual(service.prefetchSelectors, ["source-live|book-live"])
        XCTAssertNotNil(service.requestedAt.first ?? nil)
        XCTAssertEqual(coordinator.lastPrefetchResult?.chapterRange, [5, 8])
    }

    func testCurrentBookClearRefreshesStatusAndSettingsClearUsesCacheScopeWithoutSelector() async throws {
        let service = FakeReaderCacheService()
        let coordinator = ReaderCacheCoordinator(service: service)
        coordinator.bind(ReaderCacheContext(
            sourceID: "source-live",
            bookID: "book-live",
            currentChapterIndex: 4
        ))

        coordinator.clearCurrentBook()
        try await eventually { service.clearScopes.count == 1 && coordinator.lastClearResult != nil }

        XCTAssertEqual(service.clearScopes, [.book])
        XCTAssertEqual(service.clearSelectors, ["source-live|book-live"])
        XCTAssertEqual(coordinator.status?.bookID, "book-live")

        let navigation = AppNavigationState()
        let reducer = ReaderReducer(navigationState: navigation, cacheCoordinator: coordinator)
        reducer.dispatch(UiEvent(type: .settings_cache_clear))
        try await eventually { service.clearScopes.count == 2 && service.clearSelectors.count == 2 }

        XCTAssertEqual(service.clearScopes, [.book, .cache])
        XCTAssertEqual(service.clearSelectors, ["source-live|book-live", "nil|nil"])
        XCTAssertTrue(navigation.navigationPath.isEmpty)
    }

    func testMissingLiveIdentityFailsClosedWithoutCoreCall() {
        let service = FakeReaderCacheService()
        let coordinator = ReaderCacheCoordinator(service: service)

        coordinator.bind(ReaderCacheContext(sourceID: nil, bookID: "book-live", currentChapterIndex: 4))
        coordinator.refresh()
        coordinator.prefetchCurrentChapter()
        coordinator.clearCurrentBook()

        XCTAssertNil(coordinator.context)
        XCTAssertTrue(service.statusSelectors.isEmpty)
        XCTAssertTrue(service.prefetchSelectors.isEmpty)
        XCTAssertTrue(service.clearScopes.isEmpty)
        XCTAssertEqual(
            coordinator.viewState,
            .unavailable(message: "当前阅读路由缺少真实 sourceId / bookId")
        )
    }

    func testDeferredProductionResolverRecoversAfterAggregateStorageBecomesReady() async throws {
        let service = FakeReaderCacheService()
        var storageReady = false
        var resolutionAttempts = 0
        let coordinator = ReaderCacheCoordinator(serviceResolver: {
            resolutionAttempts += 1
            guard storageReady else {
                throw ReaderSlice10CoreServiceError.failedClosed(
                    code: "SLICE10_STORAGE_NOT_READY",
                    message: "aggregate storage restore is still running"
                )
            }
            return service
        })
        coordinator.bind(ReaderCacheContext(
            sourceID: "source-live",
            bookID: "book-live",
            currentChapterIndex: 4
        ))

        XCTAssertEqual(resolutionAttempts, 1)
        XCTAssertTrue(service.statusSelectors.isEmpty)
        guard case .unavailable(let message) = coordinator.viewState else {
            return XCTFail("restoring storage must be visible as unavailable")
        }
        XCTAssertTrue(message.contains("restore is still running"))

        storageReady = true
        coordinator.refresh()
        try await eventually { coordinator.status != nil }

        XCTAssertEqual(resolutionAttempts, 2)
        XCTAssertEqual(service.statusSelectors, ["source-live|book-live"])
        XCTAssertEqual(coordinator.viewState, .succeeded(.status, message: "缓存状态已刷新"))
    }

    func testPrefetchCurrentChapterRequiresLiveChapterIndex() {
        let service = FakeReaderCacheService()
        let coordinator = ReaderCacheCoordinator(service: service)
        coordinator.bind(ReaderCacheContext(
            sourceID: "source-live",
            bookID: "book-live",
            currentChapterIndex: nil
        ))

        coordinator.prefetchCurrentChapter()

        XCTAssertTrue(service.prefetchRanges.isEmpty)
        XCTAssertEqual(
            coordinator.viewState,
            .failed(.prefetch, message: "当前阅读路由缺少真实 chapterIndex")
        )
    }

    private func eventually(
        timeout: TimeInterval = 2,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !condition() {
            await Task.yield()
        }
        if !condition() {
            XCTFail("condition did not become true")
        }
    }
}

private final class FakeReaderCacheService: ReaderSlice10CacheAndReplaceUndoServicing {
    var statusSelectors: [String] = []
    var prefetchSelectors: [String] = []
    var prefetchRanges: [[Int]] = []
    var requestedAt: [Int64?] = []
    var clearScopes: [ReaderCoreCacheClearScope] = []
    var clearSelectors: [String] = []

    func loadBookCacheStatus(
        sourceID: String,
        bookID: String,
        correlationID: String?
    ) async throws -> ReaderCoreBookCacheStatus {
        statusSelectors.append("\(sourceID)|\(bookID)")
        return ReaderCoreBookCacheStatus(
            sourceID: sourceID,
            bookID: bookID,
            tocAvailable: true,
            chapterCount: 12,
            chapters: [],
            cachedCount: 2,
            queuedCount: 1,
            inProgressCount: 0,
            completedCount: 0,
            failedCount: 0,
            cancelledCount: 0,
            missingCount: 9,
            globalStats: ReaderCoreCacheGlobalStats(
                entryCount: 2,
                totalContentBytes: 2_048,
                oldestCachedAt: 1_000,
                newestCachedAt: 2_000,
                queueEntryCount: 3,
                queuedCount: 1,
                inProgressCount: 0,
                completedCount: 1,
                failedCount: 1,
                cancelledCount: 0
            )
        )
    }

    func prefetchBookCache(
        sourceID: String,
        bookID: String,
        chapterRange: [Int],
        priority: Int?,
        requestedAt: Int64?,
        correlationID: String?
    ) async throws -> ReaderCoreBookPrefetchResult {
        prefetchSelectors.append("\(sourceID)|\(bookID)")
        prefetchRanges.append(chapterRange)
        self.requestedAt.append(requestedAt)
        return ReaderCoreBookPrefetchResult(
            sourceID: sourceID,
            bookID: bookID,
            chapterRange: chapterRange,
            chapterCount: chapterRange[1] - chapterRange[0],
            prefetchedCount: chapterRange[1] - chapterRange[0],
            queuedIndexes: Array(chapterRange[0]..<chapterRange[1]),
            alreadyQueuedIndexes: [],
            skippedCachedIndexes: []
        )
    }

    func clearCache(
        scope: ReaderCoreCacheClearScope,
        sourceID: String?,
        bookID: String?,
        correlationID: String?
    ) async throws -> ReaderCoreCacheClearResult {
        clearScopes.append(scope)
        clearSelectors.append("\(sourceID ?? "nil")|\(bookID ?? "nil")")
        return ReaderCoreCacheClearResult(
            scope: scope,
            cacheEntriesRemoved: 2,
            chapterEntriesRemoved: scope == .book ? 2 : 0,
            queueEntriesRemoved: 1,
            removedContentBytes: 2_048
        )
    }

    func undoReplace(
        undoToken: ReaderCoreReplaceUndoToken,
        correlationID: String?
    ) async throws -> ReaderCoreReplaceUndoResult {
        XCTFail("cache coordinator must not invoke replace.undo")
        throw CancellationError()
    }
}
