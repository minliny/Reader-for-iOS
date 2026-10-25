import Foundation

public struct ReaderCachedChapterIdentity: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: UInt32
    public init(sourceId: String, bookId: String, chapterIndex: UInt32) {
        self.sourceId = sourceId; self.bookId = bookId; self.chapterIndex = chapterIndex
    }
    public init(book: ReaderBook, chapterIndex: UInt32) {
        self.init(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: chapterIndex)
    }
}

public enum ReaderDownloadChapterState: String, Codable, Sendable {
    case missing, queued, paused, inProgress, cached, completed, failed, cancelled
}

public struct ReaderDownloadChapter: Decodable, Sendable, Identifiable {
    public let chapterIndex: UInt32
    public let title: String
    public let url: String
    public let navigable: Bool?
    public let state: ReaderDownloadChapterState
    public let cachedBytes: UInt64
    public let attempts: UInt32
    public let maxAttempts: UInt32
    public let lastError: String?
    public var id: UInt32 { chapterIndex }
    let variables: [String: String]
    private enum CodingKeys: String, CodingKey {
        case chapterIndex, title, url, navigable, state, cachedBytes, attempts, maxAttempts, lastError, variables
    }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        chapterIndex = try v.decode(UInt32.self, forKey: .chapterIndex)
        title = try v.decodeIfPresent(String.self, forKey: .title) ?? ""
        url = try v.decodeIfPresent(String.self, forKey: .url) ?? ""
        navigable = try v.decodeIfPresent(Bool.self, forKey: .navigable)
        state = try v.decode(ReaderDownloadChapterState.self, forKey: .state)
        cachedBytes = try v.decodeIfPresent(UInt64.self, forKey: .cachedBytes) ?? 0
        attempts = try v.decodeIfPresent(UInt32.self, forKey: .attempts) ?? 0
        maxAttempts = try v.decodeIfPresent(UInt32.self, forKey: .maxAttempts) ?? 0
        lastError = try v.decodeIfPresent(String.self, forKey: .lastError)
        variables = try v.decodeIfPresent([String: String].self, forKey: .variables) ?? [:]
    }
}

public struct ReaderDownloadStatus: Decodable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let tocAvailable: Bool
    /// Canonical index extent; group rows need not be readable chapters.
    public let chapterCount: UInt32
    public let readableChapterCount: UInt32?
    public let chapters: [ReaderDownloadChapter]
    public let cachedCount: Int
    public let queuedCount: Int
    public let inProgressCount: Int
    public let completedCount: Int
    public let failedCount: Int
    public let cancelledCount: Int
    public let missingCount: Int
    public var pausedCount: Int { chapters.filter { $0.state == .paused }.count }
    let continuationVariables: [String: String]?
}

public struct ReaderDownloadReceipt: Decodable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterRange: [UInt32]
    public let chapterCount: UInt32
    public let prefetchedCount: Int
    public let queuedIndexes: [UInt32]
    public let alreadyQueuedIndexes: [UInt32]
    public let skippedCachedIndexes: [UInt32]
    public let materializations: [ReaderDownloadMaterialization]
}

public struct ReaderDownloadMaterialization: Decodable, Sendable {
    public let chapterIndex: UInt32
    public let token: String
}

public struct ReaderDownloadTaskReceipt: Decodable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: UInt32
    public let status: String
    public let attempts: UInt32
    public let maxAttempts: UInt32
}

public struct ReaderStorageSummary: Decodable, Sendable {
    public let completedQueueChapters: [ReaderCachedChapterIdentity]
    public let completedQueueHasMore: Bool
    /// Core normalized text bytes; these are not reclaimed SQLite file bytes.
    public let removedContentBytes: UInt64
    public let totalBytes: UInt64
    public let retainedBytes: UInt64
    public let automaticBytes: UInt64
    public let cleanableBytes: UInt64
    public let protectedChapters: [ReaderCachedChapterIdentity]
    public let removedChapters: [ReaderCachedChapterIdentity]
    public let hasMore: Bool
    public let cleanupError: String?
}

public struct ReaderReadingCacheWindow: Sendable {
    public let requestedIndexes: [UInt32]
    public let cachedIndexes: [UInt32]
    public let failedIndexes: [UInt32]
}

public protocol ReaderDownloadServing: ReaderLibraryServing {
    func readerDownloadStatus(_ book: ReaderBook) async throws -> ReaderDownloadStatus
    func downloadChapters(_ book: ReaderBook, range: Range<UInt32>, operationID: String) async throws -> ReaderDownloadReceipt
    func pauseDownload(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws -> ReaderDownloadTaskReceipt
    func resumeDownload(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws -> ReaderDownloadTaskReceipt
    func cancelDownload(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws -> ReaderDownloadTaskReceipt
    func clearDownloadedChapter(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws
    func cacheReadingWindow(_ book: ReaderBook, around chapterIndex: UInt32) async throws -> ReaderReadingCacheWindow
    func readerStorageSummary(protected: [ReaderCachedChapterIdentity]) async throws -> ReaderStorageSummary
    func cleanupReaderStorage(retained: [ReaderCachedChapterIdentity], protected: [ReaderCachedChapterIdentity],
                              operationID: String) async throws -> ReaderStorageSummary
}

public extension ReaderDownloadServing {
    func clearDownloadedChapter(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws {
        throw ReaderLibraryError.invalidResponse("download removal unavailable")
    }
}

extension ReaderLibraryService: ReaderDownloadServing {
    public func readerDownloadStatus(_ book: ReaderBook) async throws -> ReaderDownloadStatus {
        let status = try decode(ReaderDownloadStatus.self, await coreRead("cache.book.status", [
            "sourceId": book.sourceId, "bookId": book.bookId, "includeGlobalStats": false, "includeChapterStates": true
        ]))
        guard status.sourceId == book.sourceId, status.bookId == book.bookId else {
            throw ReaderLibraryError.invalidResponse("download status identity")
        }
        return status
    }

    public func downloadChapters(_ book: ReaderBook, range: Range<UInt32>, operationID: String) async throws -> ReaderDownloadReceipt {
        guard book.sourceId != "local", !range.isEmpty else { throw ReaderLibraryError.invalidPosition }
        let parameters: [String: Any]
        if let original = try existingCoreParameters(operationID: operationID, method: "cache.book.prefetch") {
            guard original["sourceId"] as? String == book.sourceId, original["bookId"] as? String == book.bookId,
                  original["chapterRange"] as? [UInt32] == [range.lowerBound, range.upperBound] else {
                throw ReaderLibraryError.invalidResponse("download operation identity")
            }
            var business = original
            business.removeValue(forKey: "operationId"); business.removeValue(forKey: "sequence")
            parameters = business
        } else {
            let status = try await readerDownloadStatus(book)
            guard status.tocAvailable, range.upperBound <= status.chapterCount else { throw ReaderLibraryError.invalidPosition }
            parameters = ["sourceId": book.sourceId, "bookId": book.bookId,
                "chapterRange": [range.lowerBound, range.upperBound], "contentKind": "text", "priority": 0,
                "requestedAt": Int64(Date().timeIntervalSince1970 * 1000)]
        }
        let receipt = try decode(ReaderDownloadReceipt.self, await downloadMutation("cache.book.prefetch", parameters,
            operationID: operationID, scope: "download:" + book.id, timeout: 300))
        guard receipt.sourceId == book.sourceId, receipt.bookId == book.bookId,
              receipt.chapterRange == [range.lowerBound, range.upperBound] else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        // The prefetch ACK grants exact generation-bound leases. It does not
        // claim that Host resources have been persisted or tasks completed.
        for lease in receipt.materializations {
            try Task.checkCancellation()
            try await materializeDownloadChapter(book, lease: lease, operationID: operationID)
        }
        try await finishCoreOperation(operationID)
        return receipt
    }

    public func pauseDownload(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws -> ReaderDownloadTaskReceipt {
        let result = try await downloadTaskCommand("cache.download.pause", book: book, chapterIndex: chapterIndex, operationID: operationID)
        try await finishCoreOperation(operationID)
        return result
    }

    public func resumeDownload(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws -> ReaderDownloadTaskReceipt {
        guard chapterIndex < UInt32.max else { throw ReaderLibraryError.invalidPosition }
        let result = try await downloadTaskCommand("cache.download.resume", book: book, chapterIndex: chapterIndex, operationID: operationID)
        guard let original = try existingCoreParameters(operationID: operationID, method: "cache.download.resume") else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        // Resume and the subsequent resource report share Core's chapter
        // lineage. Release that acknowledged Core slot while retaining this
        // Host parent until its original acquisition child has completed.
        try await settleDownloadCommand(method: "cache.download.resume", parameters: original, operationID: operationID)
        // Resume changes the original task to queued; prefetch drives that
        // same task. Each phase retains its own original terminal payload.
        _ = try await downloadChapters(book, range: chapterIndex..<(chapterIndex + 1), operationID: operationID + ":acquire")
        try await finishCoreOperation(operationID)
        return result
    }

    public func cancelDownload(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws -> ReaderDownloadTaskReceipt {
        let result = try await downloadTaskCommand("cache.download.cancel", book: book, chapterIndex: chapterIndex, operationID: operationID)
        try await finishCoreOperation(operationID)
        return result
    }

    public func clearDownloadedChapter(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws {
        guard book.sourceId != "local" else { throw ReaderLibraryError.invalidPosition }
        let originalClear = try existingCoreParameters(operationID: operationID, method: "cache.clear")
        if let original = originalClear {
            guard original["scope"] as? String == "chapter", original["sourceId"] as? String == book.sourceId,
                  original["bookId"] as? String == book.bookId,
                  (original["chapterIndex"] as? NSNumber)?.uint32Value == chapterIndex else {
                throw ReaderLibraryError.invalidResponse("download removal identity changed")
            }
        }
        if try isCoreOperationCompleted(operationID) { return }
        if originalClear == nil {
            for pending in try pendingCoreCommands() where pending.method == "cache.book.prefetch" {
                guard let params = try existingCoreParameters(operationID: pending.id, method: pending.method),
                      params["sourceId"] as? String == book.sourceId, params["bookId"] as? String == book.bookId,
                      let range = params["chapterRange"] as? [UInt32], range.count == 2,
                      range[0] <= chapterIndex, chapterIndex < range[1] else { continue }
                // Clear cannot delete a body under an unconsumed original
                // materialization lease. Resolve that owner before accepting
                // this distinct destructive intent; pause/cancel stay usable.
                throw ReaderLibraryError.operationPending(pending.id)
            }
        }
        let result = try object(await downloadMutation("cache.clear", ["scope": "chapter",
            "sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": chapterIndex],
            operationID: operationID, scope: "download-task:\(book.id):\(chapterIndex)"))
        guard result["scope"] as? String == "chapter", result["chapterEntriesRemoved"] is NSNumber,
              result["queueEntriesRemoved"] is NSNumber else { throw ReaderLibraryError.operationPending(operationID) }
        // The original ACK authorizes cleanup. A newer cache/task is only a
        // protection against deleting resources subsequently reused by it.
        let current = try await readerDownloadStatus(book)
        if let chapter = current.chapters.first(where: { $0.chapterIndex == chapterIndex }),
           chapter.state == .missing, chapter.cachedBytes == 0 {
            let directory = sourceURL.appendingPathComponent(".download-assets", isDirectory: true)
                .appendingPathComponent(downloadAssetHash([book.sourceId, book.bookId]), isDirectory: true)
                .appendingPathComponent(String(chapterIndex), isDirectory: true)
            if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
        }
        try await finishCoreOperation(operationID)
    }

    private func downloadTaskCommand(_ method: String, book: ReaderBook, chapterIndex: UInt32,
                                     operationID: String) async throws -> ReaderDownloadTaskReceipt {
        guard book.sourceId != "local" else { throw ReaderLibraryError.invalidPosition }
        // A resume intent owns acquisition after its control ACK settles.
        // Its child report must acquire the chapter control slot separately.
        let scope = (method == "cache.download.resume" ? "download-resume:" : "download-task:") + "\(book.id):\(chapterIndex)"
        let result = try decode(ReaderDownloadTaskReceipt.self, await downloadMutation(method, [
            "sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": chapterIndex
        ], operationID: operationID, scope: scope))
        guard result.sourceId == book.sourceId, result.bookId == book.bookId, result.chapterIndex == chapterIndex else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        return result
    }

    public func cacheReadingWindow(_ book: ReaderBook, around chapterIndex: UInt32) async throws -> ReaderReadingCacheWindow {
        guard book.sourceId != "local" else { return .init(requestedIndexes: [], cachedIndexes: [], failedIndexes: []) }
        guard readingCacheWindowInFlight.insert(book.id).inserted else { throw ReaderLibraryError.busy }
        defer { readingCacheWindowInFlight.remove(book.id) }
        let status = try await readerDownloadStatus(book)
        let readable = status.chapters.filter { $0.navigable != false && !$0.url.isEmpty }.sorted { $0.chapterIndex < $1.chapterIndex }
        guard let current = readable.firstIndex(where: { $0.chapterIndex == chapterIndex }) else { throw ReaderLibraryError.invalidPosition }
        let window = readable[max(0, current - 2)...min(readable.count - 1, current + 2)].filter { $0.chapterIndex != chapterIndex }
        var cached: [UInt32] = [], failed: [UInt32] = []
        for chapter in window {
            try Task.checkCancellation()
            if [.cached, .completed].contains(chapter.state) { cached.append(chapter.chapterIndex); continue }
            // Do not compete with an explicit download's active or paused row.
            if [.queued, .inProgress, .paused].contains(chapter.state) { continue }
            var variables = status.continuationVariables ?? [:]
            variables.merge(chapter.variables) { _, chapterValue in chapterValue }
            do {
                let result = try object(await coreRead("chapter.content", ["sourceId": book.sourceId, "bookId": book.bookId,
                    "chapterIndex": chapter.chapterIndex, "chapterTitle": chapter.title, "chapterUrl": chapter.url, "variables": variables]))
                guard result["sourceId"] as? String == book.sourceId, result["bookId"] as? String == book.bookId,
                      result["bodyVersion"] as? String != nil, result["processingVersion"] as? String != nil,
                      let text = result["content"] as? String, !text.isEmpty else {
                    throw ReaderLibraryError.invalidResponse("reading cache identity")
                }
                cached.append(chapter.chapterIndex)
            } catch is CancellationError { throw CancellationError() }
            catch { failed.append(chapter.chapterIndex) }
        }
        return .init(requestedIndexes: window.map(\.chapterIndex), cachedIndexes: cached, failedIndexes: failed)
    }

    public func readerStorageSummary(protected: [ReaderCachedChapterIdentity] = []) async throws -> ReaderStorageSummary {
        let retained = try await completedDownloadProtection()
        return try decode(ReaderStorageSummary.self, await coreRead("cache.storage.summary", [
            "contentScope": "text", "retainedChapters": try chapterObjects(retained), "protectedChapters": try chapterObjects(protected)
        ]))
    }

    public func cleanupReaderStorage(retained: [ReaderCachedChapterIdentity], protected: [ReaderCachedChapterIdentity],
                                     operationID: String) async throws -> ReaderStorageSummary {
        let parameters: [String: Any]
        if let original = try existingCoreParameters(operationID: operationID, method: "cache.storage.cleanup") {
            // Preserve the original cleanup snapshot. Newly opened consumers
            // must not cause a retry to dispatch a different delete payload.
            parameters = original
        } else {
            let completed = try await completedDownloadProtection()
            let keep = Array(Set(retained + completed)).sorted(by: chapterIdentityOrder)
            parameters = ["contentScope": "text", "reason": "clear", "retainedChapters": try chapterObjects(keep),
                "protectedChapters": try chapterObjects(protected.sorted(by: chapterIdentityOrder))]
        }
        let result = try decode(ReaderStorageSummary.self, await coreMutation("cache.storage.cleanup", parameters,
            operationID: operationID, scope: "cache-storage"))
        try await finishCoreOperation(operationID)
        return result
    }

    private func completedDownloadProtection() async throws -> [ReaderCachedChapterIdentity] {
        var after: ReaderCachedChapterIdentity?, found = Set<ReaderCachedChapterIdentity>()
        repeat {
            var parameters: [String: Any] = ["contentScope": "text"]
            if let after { parameters["completedQueueAfter"] = try chapterObjects([after]).first! }
            let page = try decode(ReaderStorageSummary.self, await coreRead("cache.storage.summary", parameters))
            for identity in page.completedQueueChapters { found.insert(identity) }
            guard page.completedQueueHasMore else { return found.sorted(by: chapterIdentityOrder) }
            guard let last = page.completedQueueChapters.last,
                  after.map({ chapterIdentityOrder($0, last) }) ?? true else {
                throw ReaderLibraryError.invalidResponse("cache completed queue cursor")
            }
            after = last
        } while true
    }

    private func chapterObjects(_ values: [ReaderCachedChapterIdentity]) throws -> [[String: Any]] {
        guard let objects = try JSONSerialization.jsonObject(with: JSONEncoder().encode(values)) as? [[String: Any]] else {
            throw ReaderLibraryError.invalidResponse("cache chapter identities")
        }
        return objects
    }

    private func chapterIdentityOrder(_ a: ReaderCachedChapterIdentity, _ b: ReaderCachedChapterIdentity) -> Bool {
        if a.sourceId != b.sourceId { return a.sourceId < b.sourceId }
        if a.bookId != b.bookId { return a.bookId < b.bookId }
        return a.chapterIndex < b.chapterIndex
    }
}
