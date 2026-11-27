import Foundation
import Observation
import ReaderCoreBridge

@MainActor
@Observable
final class SearchCoordinator {
    enum Rejection: Error { case operationInFlight, noPreviousQuery }

    private let runtime: CoreRuntimeActor
    private var generation = 0
    private var active: UUID?
    private var cancellable: [CoreOperationID] = []
    private var cancelRequested = false
    private var previous: M2BookSearchParams?
    private var previousGlobal: (keyword: String, page: Int64?)?
    private(set) var visibleResult: M2BookSearchData?
    private(set) var globalResults: [SourceResult] = []
    private(set) var visibleError: (any Error)?
    var inFlight: Bool { active != nil }

    struct SourceResult: Sendable {
        let sourceId: String
        let terminal: Result<CoreOperation<M2BookSearchData>, any Error>
    }

    init(runtime: CoreRuntimeActor) { self.runtime = runtime }

    func start(_ params: M2BookSearchParams) throws -> Task<CoreOperation<M2BookSearchData>, any Error> {
        let (owner, observation) = try reserve()
        previous = params
        return Task {
            defer { finish(owner) }
            do {
                try await recordKeyword(params.keyword)
                let result = try await request(params, owner: owner)
                if generation == observation { visibleResult = result.value }
                return result
            } catch {
                if generation == observation { visibleError = error }
                throw error
            }
        }
    }

    func retry() throws -> Task<CoreOperation<M2BookSearchData>, any Error> {
        guard let previous else { throw Rejection.noPreviousQuery }
        return try start(previous)
    }

    /// Fan out to the Core's current enabled sources and keep each original terminal.
    func startGlobal(keyword: String, page: Int64? = nil) throws -> Task<[SourceResult], any Error> {
        let (owner, observation) = try reserve()
        previousGlobal = (keyword, page)
        return Task {
            defer { finish(owner) }
            do {
                try await recordKeyword(keyword)
                let sources = try await runtime.request(ReaderM2.sourceList, .init(enabledOnly: true)).value.sources
                var results: [SourceResult] = []
                // Limit concurrent requests so an imported catalogue cannot consume all
                // Core deliveries or create an unbounded number of host requests.
                let parallelism = 4
                for start in stride(from: 0, to: sources.count, by: parallelism) {
                    if cancelRequested || generation != observation { break }
                    let batch = sources[start..<min(start + parallelism, sources.count)]
                    await withTaskGroup(of: SourceResult.self) { group in
                        for source in batch {
                            let sourceId = source.sourceId
                            group.addTask { [self] in
                                do {
                                    let result = try await request(.init(sourceId: sourceId,
                                                                         keyword: keyword, page: page), owner: owner)
                                    return .init(sourceId: sourceId, terminal: .success(result))
                                } catch {
                                    return .init(sourceId: sourceId, terminal: .failure(error))
                                }
                            }
                        }
                        for await result in group {
                            results.append(result)
                            if generation == observation { globalResults.append(result) }
                        }
                    }
                }
                return results
            } catch {
                if generation == observation { visibleError = error }
                throw error
            }
        }
    }

    func retryGlobal() throws -> Task<[SourceResult], any Error> {
        guard let previousGlobal else { throw Rejection.noPreviousQuery }
        return try startGlobal(keyword: previousGlobal.keyword, page: previousGlobal.page)
    }

    func stopDisplaying() { generation += 1 }

    func cancel() async throws {
        guard active != nil else { return }
        stopDisplaying()
        cancelRequested = true
        var failure: (any Error)?
        for id in cancellable {
            do { try await runtime.cancel(id) } catch { failure = error }
        }
        if let failure { throw failure }
    }

    func history(limit: Int64? = nil) async throws -> M2SearchHistoryListData {
        try await runtime.request(ReaderM2.searchHistoryList, .init(limit: limit)).value
    }

    func removeHistory(keyword: String) async throws -> M2SearchKeywordDeleteData {
        try await runtime.request(ReaderM2.searchKeywordDelete, .init(word: keyword)).value
    }

    func clearHistory() async throws -> M2SearchHistoryClearData {
        try await runtime.request(ReaderM2.searchHistoryClear, .init()).value
    }

    private func reserve() throws -> (UUID, Int) {
        guard active == nil else { throw Rejection.operationInFlight }
        let id = UUID()
        active = id
        generation += 1
        visibleResult = nil
        globalResults = []
        visibleError = nil
        return (id, generation)
    }

    private func finish(_ owner: UUID) {
        guard active == owner else { return }
        active = nil
        cancelRequested = false
        cancellable.removeAll()
    }

    private func request(_ params: M2BookSearchParams, owner: UUID) async throws -> CoreOperation<M2BookSearchData> {
        try await runtime.request(ReaderM2.bookSearch, params) { [weak self] id in
            Task { await self?.dispatched(id, owner: owner) }
        }
    }

    private func dispatched(_ id: CoreOperationID, owner: UUID) async {
        guard active == owner else { return }
        cancellable.append(id)
        if cancelRequested { try? await runtime.cancel(id) }
    }

    private func recordKeyword(_ keyword: String?) async throws {
        guard let keyword, !keyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        _ = try await runtime.request(ReaderM2.searchHistoryAdd, .init(keyword: keyword))
    }
}
