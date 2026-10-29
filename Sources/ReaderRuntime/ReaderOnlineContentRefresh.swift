import Foundation

/// Only an exact dispatched refresh whose read did not reach a publication
/// fence remains here. This is neither a durable write journal nor a task list.
struct ReaderOnlineContentRefreshIdentity: Hashable {
    let sourceId: String
    let bookId: String
    let chapterIndex: UInt32
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.chapterIndex == rhs.chapterIndex && lhs.sourceId.utf8.elementsEqual(rhs.sourceId.utf8)
            && lhs.bookId.utf8.elementsEqual(rhs.bookId.utf8)
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(Array(sourceId.utf8)); hasher.combine(Array(bookId.utf8)); hasher.combine(chapterIndex)
    }
}

/// A source refresh is opt-in; ordinary online adapters and their read-only
/// mocks do not acquire a second content or position implementation.
public protocol ReaderOnlineContentRefreshing: ReaderLibraryServing {
    func refreshOnlineContent(for book: ReaderBook, current: ReaderChapterContent,
                              scalarOffset: UInt64, upgradeCachedContent: Bool) async throws -> ReaderOnlineContentRefreshResult
    func reconcileOnlineContent(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderOnlineContentSnapshot
}

public struct ReaderOnlineContentPositionMigration: Codable, Hashable, Sendable {
    public struct Anchor: Codable, Hashable, Sendable {
        public let id: String
        public let previousOffset: UInt64
        public let offset: UInt64
        public init(id: String, previousOffset: UInt64, offset: UInt64) {
            self.id = id; self.previousOffset = previousOffset; self.offset = offset
        }
    }
    public let status: String
    public let reason: String?
    public let previousBodyVersion: String
    public let bodyVersion: String
    public let previousProcessingVersion: String
    public let processingVersion: String
    public let anchors: [Anchor]
    public let progress: ReaderProgress?
    public var isPartial: Bool { status == "committed" && reason == "positions_partially_restored" }

    public init(status: String, reason: String? = nil, previousBodyVersion: String, bodyVersion: String,
                previousProcessingVersion: String, processingVersion: String, anchors: [Anchor],
                progress: ReaderProgress? = nil) {
        self.status = status; self.reason = reason
        self.previousBodyVersion = previousBodyVersion; self.bodyVersion = bodyVersion
        self.previousProcessingVersion = previousProcessingVersion; self.processingVersion = processingVersion
        self.anchors = anchors; self.progress = progress
    }
}

public struct ReaderOnlineContentSnapshot: Sendable {
    public let content: ReaderChapterContent
    public let progressSnapshot: ReaderProgressSnapshot
    public init(content: ReaderChapterContent, progressSnapshot: ReaderProgressSnapshot) {
        self.content = content; self.progressSnapshot = progressSnapshot
    }
}

public struct ReaderOnlineContentRefreshResult: Sendable {
    public let content: ReaderChapterContent
    public let progressSnapshot: ReaderProgressSnapshot
    public let positionMigration: ReaderOnlineContentPositionMigration
    public init(content: ReaderChapterContent, progressSnapshot: ReaderProgressSnapshot,
                positionMigration: ReaderOnlineContentPositionMigration) {
        self.content = content; self.progressSnapshot = progressSnapshot; self.positionMigration = positionMigration
    }
}

extension ReaderLibraryService: ReaderOnlineContentRefreshing {
    public func refreshOnlineContent(for book: ReaderBook, current: ReaderChapterContent,
                                     scalarOffset: UInt64, upgradeCachedContent: Bool) async throws -> ReaderOnlineContentRefreshResult {
        guard book.sourceId != "local", scalarOffset <= current.scalarCount,
              Int32(exactly: current.chapterIndex) != nil else { throw ReaderLibraryError.invalidPosition }
        let oldScope = try ReaderContentPositionScope(book: book, content: current)
        let identity = ReaderOnlineContentRefreshIdentity(sourceId: book.sourceId, bookId: book.bookId,
            chapterIndex: current.chapterIndex)
        guard !onlineContentRefreshesInFlight.contains(identity),
              !unfencedOnlineContentRefreshes.contains(identity) else { throw ReaderLibraryError.busy }
        onlineContentRefreshesInFlight.insert(identity)
        defer { onlineContentRefreshesInFlight.remove(identity) }
        let context: [String: Any] = ["bodyVersion": oldScope.bodyVersion,
            "processingVersion": oldScope.processingVersion,
            "anchors": [["id": "viewport", "offset": scalarOffset]]]
        // Only the explicit caller chooses acquisition. A subsequent failure
        // must be reconciled through cacheOnly, never by replaying this request.
        let response = try await onlineContentResult(for: book, chapterIndex: current.chapterIndex,
            forceRefresh: !upgradeCachedContent, upgradeCachedContent: upgradeCachedContent,
            positionContext: context,
            onSendAttempt: { self.unfencedOnlineContentRefreshes.insert(identity) },
            onReadPublicationFence: { fenced in
                if fenced { self.unfencedOnlineContentRefreshes.remove(identity) }
            })
        let content = try onlineContentProjection(response, for: book, chapterIndex: current.chapterIndex)
        guard let rawMigration = response["positionMigration"] as? [String: Any] else {
            throw ReaderLibraryError.invalidResponse("content refresh migration missing")
        }
        let migration = try decode(ReaderOnlineContentPositionMigration.self,
            JSONSerialization.data(withJSONObject: rawMigration))
        try Self.validateOnlineContentMigration(migration, book: book, current: current,
            content: content, scalarOffset: scalarOffset)
        // Migration.progress is the committed coordinate, not a progress CAS
        // receipt. Only a fresh Core observation supplies the next revision.
        let snapshot = try await progress(for: book)
        guard !unfencedOnlineContentRefreshes.contains(identity) else { throw ReaderLibraryError.busy }
        try Self.validateOnlineContentSnapshot(snapshot, book: book, content: content)
        guard snapshot.progress?.chapterOffset == migration.anchors[0].offset else {
            throw ReaderLibraryError.invalidResponse("content refresh progress changed")
        }
        if let migrated = migration.progress {
            guard let observed = snapshot.progress,
                  Self.sameOnlineContentPosition(migrated, observed) else {
                throw ReaderLibraryError.invalidResponse("content refresh migration progress changed")
            }
        }
        return .init(content: content, progressSnapshot: snapshot, positionMigration: migration)
    }

    public func reconcileOnlineContent(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderOnlineContentSnapshot {
        guard book.sourceId != "local", Int32(exactly: chapterIndex) != nil else { throw ReaderLibraryError.invalidPosition }
        let identity = ReaderOnlineContentRefreshIdentity(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: chapterIndex)
        // f322 remote.rs holds source_publication_guard for both refresh
        // publication (11913) and this cache read (11685). The position
        // transaction checks the original request budget before writing and
        // before commit (storage remote_content_positions.rs:1348/1394).
        // After a confirmed cancel or terminal, taking that same guard fences
        // an earlier worker; a mere Host observer timeout does not. Keep any
        // unfenced identity blocked even when an old cached body is visible.
        guard !onlineContentRefreshesInFlight.contains(identity),
              !unfencedOnlineContentRefreshes.contains(identity) else { throw ReaderLibraryError.busy }
        let response = try await onlineContentResult(for: book, chapterIndex: chapterIndex, cacheOnly: true)
        let content = try onlineContentProjection(response, for: book, chapterIndex: chapterIndex)
        let snapshot = try await progress(for: book)
        guard !onlineContentRefreshesInFlight.contains(identity),
              !unfencedOnlineContentRefreshes.contains(identity) else { throw ReaderLibraryError.busy }
        try Self.validateOnlineContentSnapshot(snapshot, book: book, content: content)
        return .init(content: content, progressSnapshot: snapshot)
    }

    private static func validateOnlineContentMigration(_ migration: ReaderOnlineContentPositionMigration,
                                                       book: ReaderBook, current: ReaderChapterContent,
                                                       content: ReaderChapterContent, scalarOffset: UInt64) throws {
        let old = try ReaderContentPositionScope(book: book, content: current)
        let updated = try ReaderContentPositionScope(book: book, content: content)
        guard current.chapterIndex == content.chapterIndex,
              ["unchanged", "committed", "preserved"].contains(migration.status),
              migration.previousBodyVersion == old.bodyVersion,
              migration.previousProcessingVersion == old.processingVersion,
              migration.bodyVersion == updated.bodyVersion,
              migration.processingVersion == updated.processingVersion,
              migration.anchors.count == 1, let anchor = migration.anchors.first,
              anchor.id == "viewport", anchor.previousOffset == scalarOffset,
              anchor.offset <= content.scalarCount else {
            throw ReaderLibraryError.invalidResponse("content refresh migration identity")
        }
        if migration.status != "committed" {
            guard old == updated, anchor.offset == scalarOffset else {
                throw ReaderLibraryError.invalidResponse("content refresh retained scope changed")
            }
        }
        if migration.status == "unchanged", migration.reason != nil {
            throw ReaderLibraryError.invalidResponse("content refresh unchanged reason")
        }
        if migration.status == "preserved", migration.reason?.isEmpty != false {
            throw ReaderLibraryError.invalidResponse("content refresh preservation reason missing")
        }
        if migration.reason == "positions_partially_restored", !migration.isPartial {
            throw ReaderLibraryError.invalidResponse("content refresh partial migration status")
        }
        if let progress = migration.progress {
            guard Self.onlineContentPositionMatches(progress, book: book, content: content),
                  progress.chapterOffset == anchor.offset else {
                throw ReaderLibraryError.invalidResponse("content refresh migration progress identity")
            }
        }
    }

    private static func validateOnlineContentSnapshot(_ snapshot: ReaderProgressSnapshot,
                                                      book: ReaderBook, content: ReaderChapterContent) throws {
        _ = try ReaderContentPositionScope(book: book, content: content)
        guard snapshot.found, snapshot.progressRevision?.isEmpty == false,
              let progress = snapshot.progress,
              onlineContentPositionMatches(progress, book: book, content: content) else {
            throw ReaderLibraryError.invalidResponse("content refresh progress observation")
        }
    }

    private static func onlineContentPositionMatches(_ progress: ReaderProgress,
                                                     book: ReaderBook, content: ReaderChapterContent) -> Bool {
        progress.sourceId == book.sourceId && progress.bookId == book.bookId
            && progress.chapterIndex == content.chapterIndex && progress.bodyVersion == content.bodyVersion
            && progress.processingVersion == content.processingVersion && progress.chapterOffset <= content.scalarCount
            && progress.chapterProgress.isFinite && (0...1).contains(progress.chapterProgress)
    }

    private static func sameOnlineContentPosition(_ first: ReaderProgress, _ second: ReaderProgress) -> Bool {
        first.sourceId == second.sourceId && first.bookId == second.bookId
            && first.chapterIndex == second.chapterIndex && first.chapterOffset == second.chapterOffset
            && first.bodyVersion == second.bodyVersion && first.processingVersion == second.processingVersion
    }
}
