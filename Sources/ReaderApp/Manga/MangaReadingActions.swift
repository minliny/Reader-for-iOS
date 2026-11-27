import ReaderCoreBridge

extension MangaReadingCoordinator {
    enum DownloadAction {
        case pause
        case resume
        case cancel

        var rpc: ReaderRPC<M3CacheDownloadTaskParams, M3CacheDownloadTaskResult> {
            switch self {
            case .pause: ReaderM3.cacheDownloadPause
            case .resume: ReaderM3.cacheDownloadResume
            case .cancel: ReaderM3.cacheDownloadCancel
            }
        }
    }

    /// The caller obtains the target's tokens and verified first-image receipt
    /// through Core and keeps this exact operation intent for recovery queries.
    func commitSourceSwitch(_ intent: M3MangaSourceSwitchOperationParams) async throws -> M3MangaSourceSwitchOperationReceipt {
        guard let chapter, let progress,
              chapter.manifest.chapter.sourceId == intent.fromSourceId,
              chapter.manifest.chapter.bookId == intent.fromBookId,
              progress.token.epoch == intent.expectedFrom.epoch,
              progress.token.revision == intent.expectedFrom.revision else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return try await runtime.request(ReaderM3.mangaSourceSwitchCommitV2, intent).value
    }

    func querySourceSwitch(_ intent: M3MangaSourceSwitchOperationParams) async throws -> M3MangaSourceSwitchOperationQueryData {
        try await runtime.request(ReaderM3.mangaSourceSwitchOperationQueryV1,
                                  .init(operationId: intent.operationId, expected: intent)).value
    }

    /// Pinned Core accepts manga prefetch as a foreground command. Queue
    /// admission and materialization grants are read back from Core status.
    func prefetch(_ chapters: Range<Int64>) async throws -> M3CacheBookPrefetchData {
        guard let identity = chapter?.manifest.chapter, !chapters.isEmpty, chapters.lowerBound >= 0 else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return try await runtime.request(ReaderM3.cacheBookPrefetch, .init(
            sourceId: identity.sourceId, bookId: identity.bookId, chapterRange: [chapters.lowerBound, chapters.upperBound],
            contentKind: .manga
        )).value
    }

    func updateDownload(_ action: DownloadAction, chapterIndex: Int64, operationId: String, sequence: Int64)
    async throws -> M3CacheDownloadTaskResult {
        guard let identity = chapter?.manifest.chapter, chapterIndex >= 0 else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return try await runtime.request(action.rpc, .init(sourceId: identity.sourceId, bookId: identity.bookId,
            chapterIndex: chapterIndex, operationId: operationId, sequence: sequence)).value
    }

    func queryDownload(_ expected: M3CacheDownloadOperationQueryParams) async throws -> M3DownloadOperationQueryData {
        try await runtime.request(ReaderM3.cacheDownloadOperationQuery, expected).value
    }

    func downloadStatus() async throws -> M3CacheBookStatusData {
        guard let identity = chapter?.manifest.chapter else { throw CoreBridgeFailure.endpointMismatch }
        return try await runtime.request(ReaderM3.cacheBookStatus, .init(
            sourceId: identity.sourceId, bookId: identity.bookId, includeGlobalStats: false, includeChapterStates: true
        )).value
    }
}
