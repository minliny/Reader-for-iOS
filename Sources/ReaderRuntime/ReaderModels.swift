import Foundation

public struct ReaderBook: Codable, Hashable, Sendable, Identifiable {
    public let sourceId: String
    public let bookId: String
    public let title: String
    public let author: String
    public let chapterCount: UInt32
    public let currentChapterTitle: String?
    public let currentChapterIndex: UInt32?
    /// Core's whole-book progress in basis points, 0...10000.
    public let readProgress: UInt32?
    public let lastReadAt: Int64?
    public let coverUrl: String?
    public let intro: String?
    public let kind: String?
    public let group: String?
    public let addedAt: Int64?
    public let sortIndex: Int32
    public let sourceName: String?
    public var id: String { "\(sourceId)|\(bookId)" }

    public init(sourceId: String = "local", bookId: String, title: String, author: String = "",
                chapterCount: UInt32 = 0, currentChapterTitle: String? = nil,
                currentChapterIndex: UInt32? = nil, readProgress: UInt32? = nil,
                lastReadAt: Int64? = nil, coverUrl: String? = nil, intro: String? = nil,
                kind: String? = nil, group: String? = nil, addedAt: Int64? = nil,
                sortIndex: Int32 = 0, sourceName: String? = nil) {
        self.sourceId = sourceId; self.bookId = bookId; self.title = title; self.author = author
        self.chapterCount = chapterCount; self.currentChapterTitle = currentChapterTitle
        self.currentChapterIndex = currentChapterIndex; self.readProgress = readProgress
        self.lastReadAt = lastReadAt; self.coverUrl = coverUrl; self.intro = intro; self.kind = kind
        self.group = group; self.addedAt = addedAt; self.sortIndex = sortIndex; self.sourceName = sourceName
    }

    private enum CodingKeys: String, CodingKey {
        case sourceId, bookId, title, author, chapterCount, currentChapterTitle,
             currentChapterIndex, readProgress, lastReadAt, coverUrl, intro, kind, group, addedAt, sortIndex, sourceName
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sourceId = try values.decode(String.self, forKey: .sourceId)
        bookId = try values.decode(String.self, forKey: .bookId)
        title = try values.decodeIfPresent(String.self, forKey: .title) ?? ""
        author = try values.decodeIfPresent(String.self, forKey: .author) ?? ""
        // Core omits zero chapterCount; Swift initializer defaults do not apply
        // to synthesized Codable decoding.
        chapterCount = try values.decodeIfPresent(UInt32.self, forKey: .chapterCount) ?? 0
        currentChapterTitle = try values.decodeIfPresent(String.self, forKey: .currentChapterTitle)
        currentChapterIndex = try values.decodeIfPresent(UInt32.self, forKey: .currentChapterIndex)
        readProgress = try values.decodeIfPresent(UInt32.self, forKey: .readProgress)
        lastReadAt = try values.decodeIfPresent(Int64.self, forKey: .lastReadAt)
        coverUrl = try values.decodeIfPresent(String.self, forKey: .coverUrl)
        intro = try values.decodeIfPresent(String.self, forKey: .intro)
        kind = try values.decodeIfPresent(String.self, forKey: .kind)
        group = try values.decodeIfPresent(String.self, forKey: .group)
        addedAt = try values.decodeIfPresent(Int64.self, forKey: .addedAt)
        sortIndex = try values.decodeIfPresent(Int32.self, forKey: .sortIndex) ?? 0
        sourceName = try values.decodeIfPresent(String.self, forKey: .sourceName)
    }
}

public struct ReaderChapter: Codable, Hashable, Sendable, Identifiable {
    public let index: UInt32
    public let title: String
    public let url: String
    public let level: UInt32?
    public var id: UInt32 { index }
    public init(index: UInt32, title: String, url: String = "", level: UInt32? = nil) {
        self.index = index; self.title = title; self.url = url; self.level = level
    }
}

public struct ReaderContentBlock: Codable, Hashable, Sendable {
    public let kind: String
    public let text: String?
    public let source: String?
    public let startScalar: UInt64
    public let endScalar: UInt64
    public let imageWidthBasisPoints: UInt32?
    public let imageIntrinsicWidth: UInt32?
    public let imageIntrinsicHeight: UInt32?
    public init(kind: String, text: String? = nil, source: String? = nil,
                startScalar: UInt64, endScalar: UInt64, imageWidthBasisPoints: UInt32? = nil,
                imageIntrinsicWidth: UInt32? = nil, imageIntrinsicHeight: UInt32? = nil) {
        self.kind = kind; self.text = text; self.source = source; self.startScalar = startScalar
        self.endScalar = endScalar; self.imageWidthBasisPoints = imageWidthBasisPoints
        self.imageIntrinsicWidth = imageIntrinsicWidth; self.imageIntrinsicHeight = imageIntrinsicHeight
    }
}

public struct ReaderChapterContent: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: UInt32
    public let chapterTitle: String
    public let content: String
    public let bodyVersion: String?
    public let processingVersion: String?
    public let blocks: [ReaderContentBlock]
    public var scalarCount: UInt64 { UInt64(content.unicodeScalars.count) }

    public init(sourceId: String = "local", bookId: String, chapterIndex: UInt32,
                chapterTitle: String, content: String, bodyVersion: String? = nil,
                processingVersion: String? = nil, blocks: [ReaderContentBlock] = []) {
        self.sourceId = sourceId; self.bookId = bookId; self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle; self.content = content
        self.bodyVersion = bodyVersion; self.processingVersion = processingVersion; self.blocks = blocks
    }
    private enum CodingKeys: String, CodingKey {
        case sourceId, bookId, chapterIndex, chapterTitle, content, bodyVersion, processingVersion, blocks
    }
    public init(from decoder: Decoder) throws {
        let v = try decoder.container(keyedBy: CodingKeys.self)
        sourceId = try v.decode(String.self, forKey: .sourceId)
        bookId = try v.decode(String.self, forKey: .bookId)
        chapterIndex = try v.decode(UInt32.self, forKey: .chapterIndex)
        chapterTitle = try v.decode(String.self, forKey: .chapterTitle)
        content = try v.decode(String.self, forKey: .content)
        bodyVersion = try v.decodeIfPresent(String.self, forKey: .bodyVersion)
        processingVersion = try v.decodeIfPresent(String.self, forKey: .processingVersion)
        blocks = try v.decodeIfPresent([ReaderContentBlock].self, forKey: .blocks) ?? []
    }
}

public struct ReaderProgress: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: UInt32
    public let chapterOffset: UInt64
    public let chapterProgress: Double
    public let updatedAt: Int64
    public let locationRevision: String?
    public let bodyVersion: String?
    public let processingVersion: String?

    public init(sourceId: String = "local", bookId: String, chapterIndex: UInt32,
                chapterOffset: UInt64, chapterProgress: Double, updatedAt: Int64 = 0,
                locationRevision: String? = nil, bodyVersion: String? = nil,
                processingVersion: String? = nil) {
        self.sourceId = sourceId; self.bookId = bookId; self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset; self.chapterProgress = chapterProgress
        self.updatedAt = updatedAt; self.locationRevision = locationRevision
        self.bodyVersion = bodyVersion; self.processingVersion = processingVersion
    }
}

public struct ReaderProgressSnapshot: Codable, Hashable, Sendable {
    public let found: Bool
    public let progressRevision: String?
    public let progress: ReaderProgress?
    public init(found: Bool, progressRevision: String? = nil, progress: ReaderProgress? = nil) {
        self.found = found; self.progressRevision = progressRevision; self.progress = progress
    }
}

public struct ReaderImportResult: Codable, Sendable, Hashable {
    public let book: ReaderBook
    public let created: Bool
    /// Shelf creation is acknowledged; only compensation-journal cleanup is pending.
    public let finalizationPending: Bool
    public init(book: ReaderBook, created: Bool, finalizationPending: Bool = false) {
        self.book = book; self.created = created; self.finalizationPending = finalizationPending
    }
}

public struct ReaderPendingImport: Codable, Sendable, Hashable, Identifiable {
    public let id: String
    public let fileName: String
    /// A missing Core terminal reply is explicitly unresolved, never a failed write.
    public let requiresReconciliation: Bool
    public init(id: String, fileName: String, requiresReconciliation: Bool) {
        self.id = id; self.fileName = fileName; self.requiresReconciliation = requiresReconciliation
    }
}

public enum ReaderLibraryError: Error, Sendable, Equatable, LocalizedError {
    case closed
    case busy
    case unsupportedFile
    case invalidPosition
    case invalidResponse(String)
    case core(code: String, message: String, retryable: Bool, reason: String?)
    case operationPending(String)

    public var errorDescription: String? {
        switch self {
        case .closed: return "阅读服务已关闭"
        case .busy: return "当前操作尚未完成，请稍后再试"
        case .unsupportedFile: return "请选择支持的 TXT、EPUB 或 MOBI 家族文件"
        case .invalidPosition: return "阅读位置已失效，请重新打开章节"
        case .invalidResponse: return "阅读数据暂时不可用"
        case .core(_, let message, _, _): return message
        case .operationPending: return "操作结果仍在确认，请保留文件并稍后重试"
        }
    }
}

public protocol ReaderLibraryServing: Sendable {
    func listBooks() async throws -> [ReaderBook]
    func importBook(at url: URL) async throws -> ReaderImportResult
    func chapters(for book: ReaderBook) async throws -> [ReaderChapter]
    func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent
    func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot
    func reconcilePendingProgress(for book: ReaderBook) async throws -> ReaderProgressSnapshot?
    func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                      expectedRevision: String?) async throws -> ReaderProgressSnapshot
    func flush() async throws
    func close() async throws
    func pendingImports() async throws -> [ReaderPendingImport]
    func recoverPendingImports() async throws -> [ReaderPendingImport]
}

public extension ReaderLibraryServing {
    func reconcilePendingProgress(for book: ReaderBook) async throws -> ReaderProgressSnapshot? { nil }
}

/// Thin coordinate conversion between UIKit/TextKit UTF-16 and Core's Unicode scalars.
/// Neither Swift Character counts nor UTF-16 code units are Core positions.
public enum ReaderTextCoordinates {
    public static func scalarOffset(in text: String, utf16Offset: Int) -> UInt64 {
        let limit = max(0, min(utf16Offset, text.utf16.count))
        var units = 0
        var scalars: UInt64 = 0
        for scalar in text.unicodeScalars {
            let width = scalar.value > 0xffff ? 2 : 1
            if units + width > limit { break }
            units += width; scalars += 1
        }
        return scalars
    }

    public static func utf16Offset(in text: String, scalarOffset: UInt64) -> Int {
        var units = 0
        var scalars: UInt64 = 0
        for scalar in text.unicodeScalars {
            if scalars >= scalarOffset { break }
            units += scalar.value > 0xffff ? 2 : 1
            scalars += 1
        }
        return units
    }
}
