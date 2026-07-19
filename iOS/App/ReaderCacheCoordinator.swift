import Combine
import Foundation
import ReaderShellValidation

public struct ReaderCacheContext: Equatable, Sendable {
    public let sourceID: String
    public let bookID: String
    public let currentChapterIndex: Int?

    public init?(sourceID: String?, bookID: String?, currentChapterIndex: Int?) {
        guard let sourceID = sourceID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sourceID.isEmpty,
              let bookID = bookID?.trimmingCharacters(in: .whitespacesAndNewlines),
              !bookID.isEmpty,
              currentChapterIndex.map({ $0 >= 0 }) ?? true else {
            return nil
        }
        self.sourceID = sourceID
        self.bookID = bookID
        self.currentChapterIndex = currentChapterIndex
    }
}

public enum ReaderCacheOperation: String, Equatable, Sendable {
    case status
    case prefetch
    case clear
}

public enum ReaderCacheViewState: Equatable, Sendable {
    case unavailable(message: String)
    case idle
    case loading(ReaderCacheOperation)
    case succeeded(ReaderCacheOperation, message: String)
    case failed(ReaderCacheOperation, message: String)
}

/// Feature-local UI owner for the visible Reader cache surface. It accepts
/// only a live reader identity; no fixture/default source or book identity is
/// synthesized when the current route cannot provide one.
@MainActor
public final class ReaderCacheCoordinator: ObservableObject {
    private var service: (any ReaderSlice10CacheAndReplaceUndoServicing)?
    private let serviceResolver: (@MainActor () throws -> any ReaderSlice10CacheAndReplaceUndoServicing)?
    private var lastServiceResolutionError: String?
    private var operationGeneration = UUID()
    private var task: Task<Void, Never>?

    @Published public private(set) var context: ReaderCacheContext?
    @Published public private(set) var status: ReaderCoreBookCacheStatus?
    @Published public private(set) var lastPrefetchResult: ReaderCoreBookPrefetchResult?
    @Published public private(set) var lastClearResult: ReaderCoreCacheClearResult?
    @Published public private(set) var viewState: ReaderCacheViewState

    public init(service: (any ReaderSlice10CacheAndReplaceUndoServicing)? = nil) {
        self.service = service
        self.serviceResolver = nil
        self.viewState = service == nil
            ? .unavailable(message: "Reader Core 尚未就绪")
            : .idle
    }

    init(
        serviceResolver: @escaping @MainActor () throws -> any ReaderSlice10CacheAndReplaceUndoServicing
    ) {
        self.service = nil
        self.serviceResolver = serviceResolver
        self.viewState = .idle
    }

    public static func production() -> ReaderCacheCoordinator {
        ReaderCacheCoordinator(serviceResolver: {
            try ReaderSlice10CoreService.production()
        })
    }

    private func resolveService() -> (any ReaderSlice10CacheAndReplaceUndoServicing)? {
        if let service { return service }
        guard let serviceResolver else { return nil }
        do {
            let resolved = try serviceResolver()
            service = resolved
            lastServiceResolutionError = nil
            return resolved
        } catch {
            lastServiceResolutionError = error.localizedDescription
            return nil
        }
    }

    public func bind(_ context: ReaderCacheContext?) {
        guard self.context != context else { return }
        cancel()
        self.context = context
        status = nil
        lastPrefetchResult = nil
        lastClearResult = nil
        if context == nil {
            viewState = .unavailable(message: "当前阅读路由缺少真实 sourceId / bookId")
        } else if resolveService() == nil {
            failServiceUnavailable()
        } else {
            viewState = .idle
        }
    }

    public func refresh() {
        guard let context else {
            failMissingContext()
            return
        }
        guard let service = resolveService() else {
            failServiceUnavailable()
            return
        }
        start(.status) { [weak self] generation in
            do {
                let status = try await service.loadBookCacheStatus(
                    sourceID: context.sourceID,
                    bookID: context.bookID,
                    correlationID: Self.correlation("status")
                )
                guard let self, self.operationGeneration == generation else { return }
                self.status = status
                self.viewState = .succeeded(.status, message: "缓存状态已刷新")
            } catch {
                self?.finishFailure(.status, error: error, generation: generation)
            }
        }
    }

    public func prefetchCurrentChapter() {
        guard let context else {
            failMissingContext()
            return
        }
        guard let currentChapterIndex = context.currentChapterIndex else {
            viewState = .failed(.prefetch, message: "当前阅读路由缺少真实 chapterIndex")
            return
        }
        prefetch(range: [currentChapterIndex, currentChapterIndex + 1])
    }

    public func prefetchFollowingChapters(limit: Int = 20) {
        guard limit > 0 else {
            viewState = .failed(.prefetch, message: "预取章节数必须为正数")
            return
        }
        guard let context else {
            failMissingContext()
            return
        }
        guard let status, status.tocAvailable else {
            viewState = .failed(.prefetch, message: "请先刷新并确认 Core 已缓存目录")
            return
        }
        guard let currentChapterIndex = context.currentChapterIndex else {
            viewState = .failed(.prefetch, message: "当前阅读路由缺少真实 chapterIndex")
            return
        }
        let start = currentChapterIndex + 1
        let end = min(status.chapterCount, start + limit)
        guard end > start else {
            viewState = .failed(.prefetch, message: "当前章节后没有可预取章节")
            return
        }
        prefetch(range: [start, end])
    }

    public func clearCurrentBook() {
        guard let context else {
            failMissingContext()
            return
        }
        guard let service = resolveService() else {
            failServiceUnavailable()
            return
        }
        start(.clear) { [weak self] generation in
            do {
                let result = try await service.clearCache(
                    scope: .book,
                    sourceID: context.sourceID,
                    bookID: context.bookID,
                    correlationID: Self.correlation("clear-book")
                )
                let refreshed = try await service.loadBookCacheStatus(
                    sourceID: context.sourceID,
                    bookID: context.bookID,
                    correlationID: Self.correlation("status-after-clear")
                )
                guard let self, self.operationGeneration == generation else { return }
                self.lastClearResult = result
                self.status = refreshed
                self.viewState = .succeeded(
                    .clear,
                    message: "已清理 \(result.chapterEntriesRemoved) 个章节缓存"
                )
            } catch {
                self?.finishFailure(.clear, error: error, generation: generation)
            }
        }
    }

    /// Settings-level clear intentionally has no book selector. It maps to
    /// Core's `scope=cache` and therefore remains distinct from the reader's
    /// current-book operation.
    public func clearDerivedCache() {
        guard let service = resolveService() else {
            failServiceUnavailable()
            return
        }
        start(.clear) { [weak self] generation in
            do {
                let result = try await service.clearCache(
                    scope: .cache,
                    sourceID: nil,
                    bookID: nil,
                    correlationID: Self.correlation("clear-derived")
                )
                guard let self, self.operationGeneration == generation else { return }
                self.lastClearResult = result
                self.status = nil
                self.viewState = .succeeded(
                    .clear,
                    message: "已清理 \(result.cacheEntriesRemoved) 个 Core 缓存条目"
                )
            } catch {
                self?.finishFailure(.clear, error: error, generation: generation)
            }
        }
    }

    public func cancel() {
        operationGeneration = UUID()
        task?.cancel()
        task = nil
    }

    private func prefetch(range: [Int]) {
        guard let context else {
            failMissingContext()
            return
        }
        guard let service = resolveService() else {
            failServiceUnavailable()
            return
        }
        start(.prefetch) { [weak self] generation in
            do {
                let result = try await service.prefetchBookCache(
                    sourceID: context.sourceID,
                    bookID: context.bookID,
                    chapterRange: range,
                    priority: nil,
                    requestedAt: Int64(Date().timeIntervalSince1970 * 1_000),
                    correlationID: Self.correlation("prefetch")
                )
                let refreshed = try await service.loadBookCacheStatus(
                    sourceID: context.sourceID,
                    bookID: context.bookID,
                    correlationID: Self.correlation("status-after-prefetch")
                )
                guard let self, self.operationGeneration == generation else { return }
                self.lastPrefetchResult = result
                self.status = refreshed
                self.viewState = .succeeded(
                    .prefetch,
                    message: "已处理 \(result.prefetchedCount) 个章节预取"
                )
            } catch {
                self?.finishFailure(.prefetch, error: error, generation: generation)
            }
        }
    }

    private func start(
        _ operation: ReaderCacheOperation,
        body: @escaping @MainActor (UUID) async -> Void
    ) {
        cancel()
        let generation = UUID()
        operationGeneration = generation
        viewState = .loading(operation)
        task = Task { await body(generation) }
    }

    private func finishFailure(_ operation: ReaderCacheOperation, error: Error, generation: UUID) {
        guard operationGeneration == generation else { return }
        viewState = .failed(operation, message: error.localizedDescription)
    }

    private func failMissingContext() {
        viewState = .unavailable(message: "当前阅读路由缺少真实 sourceId / bookId")
    }

    private func failServiceUnavailable() {
        viewState = .unavailable(message: lastServiceResolutionError ?? "Reader Core 尚未就绪")
    }

    private static func correlation(_ operation: String) -> String {
        "ios:reader-cache:\(operation):\(UUID().uuidString)"
    }
}
