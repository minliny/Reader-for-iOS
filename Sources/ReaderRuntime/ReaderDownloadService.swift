import Foundation

struct ReaderLegacyDownloadResumeNeedsNewIntent: LocalizedError {
    var errorDescription: String? {
        "原继续操作已确认，但旧记录不能启动新的下载；请重新选择继续或下载章节。"
    }
}

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
    public let displayTitle: String?
    public let isVip: Bool?
    public let isPay: Bool?
    public let contextTitle: String?
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
        case chapterIndex, title, displayTitle, isVip, isPay, contextTitle, url, navigable, state, cachedBytes, attempts, maxAttempts, lastError, variables
    }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        chapterIndex = try v.decode(UInt32.self, forKey: .chapterIndex)
        title = try v.decodeIfPresent(String.self, forKey: .title) ?? ""
        displayTitle = try v.decodeIfPresent(String.self, forKey: .displayTitle)
        isVip = try v.decodeIfPresent(Bool.self, forKey: .isVip)
        isPay = try v.decodeIfPresent(Bool.self, forKey: .isPay)
        contextTitle = try v.decodeIfPresent(String.self, forKey: .contextTitle)
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

/// Exact Core keyset identity. SQLite's BINARY order compares UTF-8 bytes;
/// Swift's canonically equivalent String equality must not merge two keys.
public struct ReaderDownloadBookCursor: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public init(sourceId: String, bookId: String) { self.sourceId = sourceId; self.bookId = bookId }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.sourceId.utf8.elementsEqual(rhs.sourceId.utf8) && lhs.bookId.utf8.elementsEqual(rhs.bookId.utf8)
    }
    public func hash(into hasher: inout Hasher) {
        hasher.combine(Data(sourceId.utf8)); hasher.combine(Data(bookId.utf8))
    }
    public func precedes(_ other: Self) -> Bool {
        if !sourceId.utf8.elementsEqual(other.sourceId.utf8) {
            return sourceId.utf8.lexicographicallyPrecedes(other.sourceId.utf8)
        }
        return bookId.utf8.lexicographicallyPrecedes(other.bookId.utf8)
    }
    public var accessibilityKey: String { "\(sourceId.utf8.count):\(sourceId)\(bookId.utf8.count):\(bookId)" }
}

/// Metadata describes the retained task identity, independently of membership
/// in the shelf. Unknown/future media remain visible without text controls.
public struct ReaderDownloadBook: Decodable, Sendable, Identifiable {
    public let sourceId: String
    public let bookId: String
    public let onShelf: Bool
    public let sourceConfigured: Bool
    public let sourceName: String?
    public let title: String?
    public let author: String?
    public let coverUrl: String?
    public let metadataSource: String
    public let contentKind: String
    public let contentKindSource: String
    public let taskCount: UInt64
    public let queuedCount: UInt64
    public let inProgressCount: UInt64
    public let pausedCount: UInt64
    public let completedCount: UInt64
    public let failedCount: UInt64
    public let cancelledCount: UInt64
    public let latestUpdatedAt: Int64
    public var id: ReaderDownloadBookCursor { .init(sourceId: sourceId, bookId: bookId) }
    public var supportsTextControls: Bool { contentKind == "text" }
    public var displayTitle: String { title.flatMap { $0.isEmpty ? nil : $0 } ?? bookId }
    public var controlBook: ReaderBook {
        ReaderBook(sourceId: sourceId, bookId: bookId, title: displayTitle,
                   author: author ?? "", coverUrl: coverUrl, sourceName: sourceName)
    }
}

public struct ReaderDownloadBooksPage: Decodable, Sendable {
    public let items: [ReaderDownloadBook]
    public let hasMore: Bool
    public let nextCursor: ReaderDownloadBookCursor?

    public func validate(after: ReaderDownloadBookCursor?, limit: UInt32) throws {
        guard (1...100).contains(limit), items.count <= Int(limit) else {
            throw ReaderLibraryError.invalidResponse("download books page size")
        }
        var previous = after
        for item in items {
            guard !item.sourceId.isEmpty, !item.bookId.isEmpty, item.taskCount > 0,
                  previous.map({ $0.precedes(item.id) }) ?? true else {
                throw ReaderLibraryError.invalidResponse("download books identity/order")
            }
            var total: UInt64 = 0
            for count in [item.queuedCount, item.inProgressCount, item.pausedCount, item.completedCount, item.failedCount, item.cancelledCount] {
                let addition = total.addingReportingOverflow(count)
                guard !addition.overflow else { throw ReaderLibraryError.invalidResponse("download books count overflow") }
                total = addition.partialValue
            }
            guard total == item.taskCount else { throw ReaderLibraryError.invalidResponse("download books counts") }
            previous = item.id
        }
        guard hasMore ? (!items.isEmpty && nextCursor == items.last?.id) : nextCursor == nil else {
            throw ReaderLibraryError.invalidResponse("download books cursor")
        }
    }
}

/// An original prefetch request changed its observation point. This carries no
/// task state or acknowledgement; consumers must read Core's current status.
public struct ReaderDownloadStatusInvalidation: Sendable {
    public enum Phase: Sendable { case submitted, hostRequest, terminal }
    public let sourceID: String
    public let bookID: String
    public let operationID: String
    public let coreOperationID: String
    public let sequence: UInt64
    public let requestID: UInt64
    public let method: String
    public let chapterRange: [UInt32]
    public let phase: Phase

    func at(_ phase: Phase) -> Self {
        .init(sourceID: sourceID, bookID: bookID, operationID: operationID,
              coreOperationID: coreOperationID, sequence: sequence, requestID: requestID,
              method: method, chapterRange: chapterRange, phase: phase)
    }
}

public protocol ReaderDownloadServing: ReaderLibraryServing {
    func readerDownloadBooksPage(after: ReaderDownloadBookCursor?, limit: UInt32) async throws -> ReaderDownloadBooksPage
    func downloadStatusInvalidations(for book: ReaderBook) async -> AsyncStream<ReaderDownloadStatusInvalidation>
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
    func readerDownloadBooksPage(after: ReaderDownloadBookCursor?, limit: UInt32) async throws -> ReaderDownloadBooksPage {
        throw ReaderLibraryError.invalidResponse("download book inventory unavailable")
    }

    /// Pages are individually consistent. A later refresh replaces this
    /// projection; it never claims a cross-page database snapshot.
    func readerDownloadBooks() async throws -> [ReaderDownloadBook] {
        var items: [ReaderDownloadBook] = []
        var cursor: ReaderDownloadBookCursor?
        repeat {
            try Task.checkCancellation()
            let page = try await readerDownloadBooksPage(after: cursor, limit: 50)
            try page.validate(after: cursor, limit: 50)
            items.append(contentsOf: page.items)
            guard page.hasMore else { return items }
            cursor = page.nextCursor
        } while true
    }
    func downloadStatusInvalidations(for book: ReaderBook) async -> AsyncStream<ReaderDownloadStatusInvalidation> {
        AsyncStream { $0.finish() }
    }

    func clearDownloadedChapter(_ book: ReaderBook, chapterIndex: UInt32, operationID: String) async throws {
        throw ReaderLibraryError.invalidResponse("download removal unavailable")
    }
}

extension ReaderLibraryService: ReaderDownloadServing {
    public func readerDownloadBooksPage(after: ReaderDownloadBookCursor?, limit: UInt32 = 50) async throws -> ReaderDownloadBooksPage {
        guard (1...100).contains(limit) else { throw ReaderLibraryError.invalidPosition }
        var parameters: [String: Any] = ["limit": limit]
        if let after { parameters["after"] = ["sourceId": after.sourceId, "bookId": after.bookId] }
        let page = try decode(ReaderDownloadBooksPage.self, await coreRead("cache.download.books.list", parameters))
        try page.validate(after: after, limit: limit)
        return page
    }

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
        try await downloadChapters(book, range: range, operationID: operationID, expectedResume: nil)
    }

    private func downloadChapters(_ book: ReaderBook, range: Range<UInt32>, operationID: String,
                                  expectedResume: [String: Any]?) async throws -> ReaderDownloadReceipt {
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
            var business: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId,
                "chapterRange": [range.lowerBound, range.upperBound], "contentKind": "text", "priority": 0,
                "requestedAt": Int64(Date().timeIntervalSince1970 * 1000)]
            if let expectedResume { business["expectedResume"] = expectedResume }
            parameters = business
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
        // A stale presentation can offer Continue after the chapter naturally
        // completed. Core's no-op ACK is authoritative: an ordinary prefetch
        // would otherwise re-admit its already completed queue row.
        if result.status == ReaderDownloadChapterState.completed.rawValue {
            try await finishCoreOperation(operationID)
            return result
        }
        // Resume changes the original task to queued; prefetch drives that
        // same task. Each phase retains its own original terminal payload.
        let acquisitionID = operationID + ":acquire"
        // An existing child owns its frozen payload, including a legacy child
        // without this field. Reconciliation may replay its original receipt;
        // it may never retrofit a condition or dispatch an unknown old child.
        let existingAcquisition = try existingCoreParameters(operationID: acquisitionID, method: "cache.book.prefetch")
        if existingAcquisition == nil,
           original["operationId"] as? String == nil || original["sequence"] as? NSNumber == nil {
            // This exact parent ACK is already retained. It cannot authorize
            // new work, but it must not leave an impossible recovery owner.
            // An accepted child, including an unknown one, never takes this path.
            try await finishCoreOperation(operationID)
            throw ReaderLegacyDownloadResumeNeedsNewIntent()
        }
        let expectedResume = existingAcquisition == nil
            ? try await resumeAcquisitionBinding(book: book, chapterIndex: chapterIndex,
                                                operationID: operationID, original: original) : nil
        do {
            _ = try await downloadChapters(book, range: chapterIndex..<(chapterIndex + 1),
                                          operationID: acquisitionID, expectedResume: expectedResume)
        } catch {
            // Only the child's retained original non-execution rejection can
            // end acquisition. A failed query or a fresh status never does.
            guard let rejection = try definiteCoreCommandRejection(operationID: acquisitionID,
                method: "cache.book.prefetch", scope: "download:" + book.id),
                  case .core(_, _, _, let reason) = rejection,
                  reason == "resume_superseded" || reason == "resume_unproven" else { throw error }
            // Keep the resume's immutable ACK; a newer control/generation wins.
            // An old ACK without a grant also cannot authorize fresh work.
        }
        try await finishCoreOperation(operationID)
        return result
    }

    private func resumeAcquisitionBinding(book: ReaderBook, chapterIndex: UInt32, operationID: String,
                                          original: [String: Any]) async throws -> [String: Any] {
        guard let originalIdentity = original["operationId"] as? String, !originalIdentity.isEmpty,
              let originalSequence = original["sequence"] as? NSNumber else {
            // A legacy unbound ACK cannot prove a task generation. Keep its
            // original owner recoverable without inventing a grant or child.
            throw ReaderLibraryError.operationPending(operationID)
        }
        let binding: [String: Any]
        if let settled = try existingCoreParameters(operationID: operationID + ":settle",
                                                    method: "cache.download.operation.settle") {
            // The original settlement journal survives bounded Core receipt
            // compaction. It is a retained binding, never a new status guess.
            guard try isCoreOperationCompleted(operationID + ":settle"),
                  settled["sourceId"] as? String == book.sourceId, settled["bookId"] as? String == book.bookId,
                  settled["action"] as? String == "resume",
                  (settled["chapterIndex"] as? NSNumber)?.uint32Value == chapterIndex else {
                throw ReaderLibraryError.operationPending(operationID)
            }
            binding = settled
        } else {
            let queried = try object(await coreRead("cache.download.operation.query", [
                "sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": chapterIndex,
                "action": "resume", "operationId": originalIdentity,
                "expected": ["action": "resume", "params": original]
            ]))
            guard let receipt = queried["receipt"] as? [String: Any],
                  receipt["phase"] as? String == "settled", receipt["action"] as? String == "resume",
                  let exactBinding = receipt["binding"] as? [String: Any] else {
                throw ReaderLibraryError.operationPending(operationID)
            }
            binding = exactBinding
        }
        guard let identity = binding["operationId"] as? String,
              identity == originalIdentity,
              let sequence = binding["sequence"] as? NSNumber, sequence == originalSequence,
              let fingerprint = binding["payloadFingerprint"] as? String,
              fingerprint.utf8.count == 64,
              fingerprint.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }) else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        return ["operationId": identity, "sequence": sequence, "payloadFingerprint": fingerprint]
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
        return try decode(ReaderStorageSummary.self, await coreRead("cache.storage.summary", [
            "contentScope": "text", "retainCompletedQueue": true, "protectedChapters": try chapterObjects(protected)
        ]))
    }

    public func cleanupReaderStorage(retained: [ReaderCachedChapterIdentity], protected: [ReaderCachedChapterIdentity],
                                     operationID: String) async throws -> ReaderStorageSummary {
        let parameters: [String: Any]
        if let original = try existingCoreParameters(operationID: operationID, method: "cache.storage.cleanup") {
            // Preserve the original cleanup intent. A retry must not dispatch
            // a different payload under the same operation identity.
            parameters = original
        } else {
            parameters = ["contentScope": "text", "reason": "clear", "retainCompletedQueue": true,
                "retainedChapters": try chapterObjects(retained.sorted(by: chapterIdentityOrder)),
                "protectedChapters": try chapterObjects(protected.sorted(by: chapterIdentityOrder))]
        }
        let result = try decode(ReaderStorageSummary.self, await coreMutation("cache.storage.cleanup", parameters,
            operationID: operationID, scope: "cache-storage"))
        try await finishCoreOperation(operationID)
        return result
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
