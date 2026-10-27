import Foundation

public struct ReaderBookIdentity: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public init(sourceId: String, bookId: String) { self.sourceId = sourceId; self.bookId = bookId }
    public init(_ book: ReaderBook) { self.init(sourceId: book.sourceId, bookId: book.bookId) }
}

public enum ReaderShelfSort: String, Codable, CaseIterable, Sendable {
    case manual, addedAt, lastReadAt, title, author
}
public struct ReaderShelfQuery: Codable, Hashable, Sendable {
    public var sourceId: String?
    public var keyword: String?
    public var group: String?
    public var sortBy: ReaderShelfSort
    public var descending: Bool
    public init(sourceId: String? = "local", keyword: String? = nil, group: String? = nil,
                sortBy: ReaderShelfSort = .lastReadAt, descending: Bool = true) {
        self.sourceId = sourceId; self.keyword = keyword; self.group = group
        self.sortBy = sortBy; self.descending = descending
    }
}
public struct ReaderBookGroup: Codable, Hashable, Sendable, Identifiable {
    public let groupId: Int64
    public var groupName: String
    public var cover: String?
    public var order: Int32
    public var enableRefresh: Bool
    public var show: Bool
    public var id: Int64 { groupId }
    public init(groupId: Int64, groupName: String, cover: String? = nil, order: Int32 = 0,
                enableRefresh: Bool = true, show: Bool = true) {
        self.groupId = groupId; self.groupName = groupName; self.cover = cover; self.order = order
        self.enableRefresh = enableRefresh; self.show = show
    }
}
public struct ReaderContentPositionScope: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: UInt32
    public let bodyVersion: String
    public let processingVersion: String
    public init(sourceId: String, bookId: String, chapterIndex: UInt32, bodyVersion: String, processingVersion: String) {
        self.sourceId = sourceId; self.bookId = bookId; self.chapterIndex = chapterIndex
        self.bodyVersion = bodyVersion; self.processingVersion = processingVersion
    }
    public init(book: ReaderBook, content: ReaderChapterContent) throws {
        guard book.sourceId == content.sourceId, book.bookId == content.bookId,
              let body = content.bodyVersion, !body.isEmpty,
              let processing = content.processingVersion, !processing.isEmpty else { throw ReaderLibraryError.invalidPosition }
        self.init(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: content.chapterIndex,
                  bodyVersion: body, processingVersion: processing)
    }
}
public struct ReaderBookmark: Codable, Hashable, Sendable, Identifiable {
    public let time: Int64
    public let positionScope: ReaderContentPositionScope?
    public let bookName: String
    public let bookAuthor: String
    public let chapterIndex: Int32
    public let chapterPos: Int32
    public let chapterName: String
    public let bookText: String
    public let content: String
    public var id: Int64 { time }
    public var scalarOffset: UInt64 { UInt64(max(0, chapterPos)) }
}
public struct ReaderRemovalReceipt: Codable, Hashable, Sendable {
    public let requestedCount: UInt64
    public let uniqueCount: UInt64
    public let removedTargets: [ReaderBookIdentity]
    public let missingTargets: [ReaderBookIdentity]
    public let duplicateTargets: [ReaderBookIdentity]
}
public struct ReaderBatchImportItem: Sendable, Identifiable {
    public let id: UUID
    public let fileName: String
    public let result: ReaderImportResult?
    public let failure: String?
    public let cancelled: Bool
    public let unresolved: Bool
}

public struct ReaderLocalPresentationKind: Codable, Hashable, Sendable {
    public enum Kind: String, Codable, Hashable, Sendable { case text, ebook }
    public let sourceId: String
    public let bookId: String
    public let kind: Kind
    public let format: String
    public let reimportRequired: Bool
}

/// Optional capability surface. Existing V1 test doubles remain valid and do
/// not claim support for new business operations through pretend defaults.
public protocol ReaderLibraryFeatures: ReaderLibraryServing {
    func pendingFeatureOperations() async throws -> [ReaderPendingCoreCommand]
    func resumePendingFeatureOperation(_ operationID: String) async throws -> ReaderFeatureRecoveryResult
    /// A separate explicit user intent. Ordinary recovery never dispatches it.
    func continuePendingOnlineAdmission(_ operationID: String) async throws -> ReaderFeatureRecoveryResult
    func directory(for book: ReaderBook, query: String, descending: Bool, collapsedNodeIDs: [String]) async throws -> ReaderDirectorySnapshot
    func resolveDirectoryTarget(_ node: ReaderDirectoryNode, in snapshot: ReaderDirectorySnapshot) async throws -> ReaderDirectoryTarget
    func content(for book: ReaderBook, target: ReaderDirectoryTarget) async throws -> ReaderChapterContent
    func retainedSourceURL(for book: ReaderBook) async throws -> URL
    func localPresentationKind(for book: ReaderBook) async throws -> ReaderLocalPresentationKind
    func reprocessLocalBook(_ book: ReaderBook, operationID: String) async throws -> ReaderImportResult
    func ebookPresentation(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderEbookDocument
    func listBooks(query: ReaderShelfQuery) async throws -> [ReaderBook]
    func bookDetails(for book: ReaderBook) async throws -> ReaderBook?
    func importBooks(at urls: [URL]) async -> [ReaderBatchImportItem]
    func groups() async throws -> [ReaderBookGroup]
    func createGroup(name: String, operationID: String) async throws -> ReaderBookGroup
    func updateGroup(_ group: ReaderBookGroup, operationID: String) async throws -> ReaderBookGroup
    func deleteGroup(_ group: ReaderBookGroup, operationID: String) async throws
    func assignGroup(_ group: ReaderBookGroup?, to book: ReaderBook, operationID: String) async throws -> ReaderBook
    func removeBooks(_ books: [ReaderBook], operationID: String) async throws -> ReaderRemovalReceipt
    func bookmarks(for book: ReaderBook, query: String?) async throws -> [ReaderBookmark]
    func createBookmark(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                        text: String, note: String, operationID: String) async throws -> ReaderBookmark
    func updateBookmark(_ bookmark: ReaderBookmark, note: String, operationID: String) async throws -> ReaderBookmark
    func deleteBookmark(_ bookmark: ReaderBookmark, operationID: String) async throws
}
public extension ReaderLibraryFeatures {
    func bookmarks(for book: ReaderBook) async throws -> [ReaderBookmark] { try await bookmarks(for: book, query: nil) }
}
