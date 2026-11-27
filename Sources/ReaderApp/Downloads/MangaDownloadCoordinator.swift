import Foundation
import ReaderCoreBridge
import ReaderHost

@MainActor
final class MangaDownloadCoordinator {
    private struct Scope: Hashable {
        let book: OnlineBookReference.Identity
        let index: Int64
    }

    private let runtime: CoreRuntimeActor
    private let network: NetworkAndWebHost?
    private var tasks: [Scope: Task<Void, any Error>] = [:]
    private var controls = Set<Scope>()

    init(runtime: CoreRuntimeActor, network: NetworkAndWebHost?) {
        self.runtime = runtime
        self.network = network
    }

    func status(_ book: OnlineBookReference) async throws -> M3CacheBookStatusData {
        let result = try await runtime.request(ReaderM3.cacheBookStatus, .init(
            sourceId: book.sourceId, bookId: book.bookId, includeGlobalStats: false, includeChapterStates: true
        )).value
        guard result.sourceId == book.sourceId, result.bookId == book.bookId else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return result
    }

    func prepareDirectory(_ book: OnlineBookReference) async throws {
        let reading = OnlineReadingCoordinator(runtime: runtime)
        let detail = try await reading.detail(book.detailParams)
        guard detail.contentKind == .manga else { throw CoreBridgeFailure.endpointMismatch }
        _ = try await reading.refreshDirectory(.init(sourceId: book.sourceId, bookId: book.bookId,
                                                     tocUrl: detail.tocUrl, variables: detail.variables))
    }

    func isWorking(_ book: OnlineBookReference, index: Int64) -> Bool {
        tasks[.init(book: book.id, index: index)] != nil
    }

    /// The app session owns the physical operation when its panel disappears.
    func start(_ book: OnlineBookReference, index: Int64) throws -> Task<Void, any Error> {
        guard let network, book.isManga else { throw CoreBridgeFailure.endpointMismatch }
        let scope = Scope(book: book.id, index: index)
        guard tasks[scope] == nil else { throw DownloadCoordinator.Failure.operationInFlight }
        let task = Task { [self] in
            defer { tasks.removeValue(forKey: scope) }
            try await materialize(book, index: index, network: network)
        }
        tasks[scope] = task
        return task
    }

    func control(_ action: MangaReadingCoordinator.DownloadAction, book: OnlineBookReference, index: Int64) async throws {
        let scope = Scope(book: book.id, index: index)
        guard controls.insert(scope).inserted else { throw DownloadCoordinator.Failure.operationInFlight }
        defer { controls.remove(scope) }
        let prior = tasks[scope]
        let receipt = try await runtime.request(action.rpc, .init(
            sourceId: book.sourceId, bookId: book.bookId, chapterIndex: index
        )).value
        guard receipt.sourceId == book.sourceId, receipt.bookId == book.bookId,
              receipt.chapterIndex == index else { throw CoreBridgeFailure.endpointMismatch }
        switch (action, receipt.status) {
        case (.pause, .paused), (.cancel, .cancelled):
             prior?.cancel()
             _ = await prior?.result
        case (.resume, .pending):
             _ = await prior?.result
             _ = try start(book, index: index)
        default:
             break // A completed task owns its original terminal.
        }
    }

    private func materialize(_ book: OnlineBookReference, index: Int64, network: NetworkAndWebHost) async throws {
        let chapter = try await runtime.request(ReaderM3.mangaChapterGet, .init(
            sourceId: book.sourceId, bookId: book.bookId, chapterIndex: index
        )).value
        let queue = try await runtime.request(ReaderM3.cacheBookPrefetch, .init(
            sourceId: book.sourceId, bookId: book.bookId, chapterRange: [index, index + 1], contentKind: .manga
        )).value
        guard queue.sourceId == book.sourceId, queue.bookId == book.bookId else {
            throw CoreBridgeFailure.endpointMismatch
        }
        if let grant = queue.materializations.first(where: { $0.chapterIndex == index }) {
            guard let manga = grant.manga, manga.manifest.manifestVersion == chapter.manifest.manifestVersion else {
                throw CoreBridgeFailure.endpointMismatch
            }
            try await download(manga, grant: grant, network: network)
        } else if !queue.skippedCachedIndexes.contains(index) {
            throw DownloadCoordinator.Failure.operationInFlight
        }
    }

    private func download(_ value: M3MangaChapterData, grant: M3CacheChapterMaterializationData,
                          network: NetworkAndWebHost) async throws {
        let manifest = value.manifest
        let chapter = manifest.chapter
        let portable = M3MangaWindowManifest(chapter: chapter, sourceRuleVersion: manifest.sourceRuleVersion,
            manifestVersion: manifest.manifestVersion, decodeRevision: manifest.decodeRevision, pages: manifest.pages)
        let assets = MangaPageAssets(runtime: runtime, transfers: network.mangaTransfers, retained: network.mangaCompressedCache)
        var outcome = M3CacheChapterMaterializationReportParamsOutcome.completed
        var failure: (any Error)?
        do {
            for page in portable.pages {
                try Task.checkCancellation()
                let decoded = try await assets.decode(page, manifest: portable, preferredWidth: 384)
                try await network.mangaCompressedCache.store(file: decoded.file, inspection: decoded.inspection,
                    chapter: chapter, manifest: manifest.manifestVersion, resource: page.resourceRef)
            }
        } catch {
            outcome = .failed
            failure = error
        }
        await assets.reset()
        // Pause/cancel already published the queue state. Its stale token must
        // not authorize a success/failure after the panel has released us.
        try Task.checkCancellation()
        let result = try await runtime.request(ReaderM3.cacheChapterMaterializationReport, .init(
            sourceId: chapter.sourceId, bookId: chapter.bookId, chapterIndex: grant.chapterIndex,
            token: grant.token, outcome: outcome, errorCode: failure == nil ? nil : "MANGA_OFFLINE_IMAGE_UNAVAILABLE",
            manga: .init(chapter: chapter, manifestVersion: manifest.manifestVersion,
                         resourceRefs: failure == nil ? portable.pages.map(\.resourceRef) : [])
        )).value
        guard result.state.rawValue == outcome.rawValue else { throw CoreBridgeFailure.endpointMismatch }
        if let failure { throw failure }
    }
}
