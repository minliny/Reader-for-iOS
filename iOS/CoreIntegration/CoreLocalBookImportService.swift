import Foundation
import ReaderCoreAPI
import ReaderCoreFoundation
import ReaderCoreModels

public struct CoreLocalBookImportChapterSummary: Equatable, Sendable {
    public var index: Int
    public var title: String
    public var chapterURL: String
    public var preview: String
    public var contentCached: Bool

    public init(
        index: Int,
        title: String,
        chapterURL: String,
        preview: String,
        contentCached: Bool
    ) {
        self.index = index
        self.title = title
        self.chapterURL = chapterURL
        self.preview = preview
        self.contentCached = contentCached
    }
}

public struct CoreLocalBookImportSummary: Equatable, Sendable {
    public var book: LocalBook
    public var chapterCount: Int
    public var resourceCount: Int
    public var diagnostics: [String]
    public var chapters: [CoreLocalBookImportChapterSummary]
    public var detectedFormat: LocalBookFormat
    public var detectedEncoding: String?
    public var inputByteCount: Int
    public var sourceChecksum: String
    public var cleanRoomMaintained: Bool
    public var externalGPLCodeCopied: Bool

    public var firstChapterURL: String? { chapters.first(where: \.contentCached)?.chapterURL }
    public var firstChapterTitle: String? { chapters.first(where: \.contentCached)?.title }
    public var cachedTOCItems: [TOCItem] {
        chapters
            .filter(\.contentCached)
            .sorted { $0.index < $1.index }
            .map {
                TOCItem(
                    chapterTitle: $0.title,
                    chapterURL: $0.chapterURL,
                    chapterIndex: $0.index,
                    unknownFields: [
                        "localBookCached": .bool(true)
                    ]
                )
            }
    }

    public init(
        book: LocalBook,
        chapterCount: Int,
        resourceCount: Int,
        diagnostics: [String],
        chapters: [CoreLocalBookImportChapterSummary] = [],
        detectedFormat: LocalBookFormat,
        detectedEncoding: String?,
        inputByteCount: Int,
        sourceChecksum: String,
        cleanRoomMaintained: Bool = true,
        externalGPLCodeCopied: Bool = false
    ) {
        self.book = book
        self.chapterCount = chapterCount
        self.resourceCount = resourceCount
        self.diagnostics = diagnostics
        self.chapters = chapters
        self.detectedFormat = detectedFormat
        self.detectedEncoding = detectedEncoding
        self.inputByteCount = inputByteCount
        self.sourceChecksum = sourceChecksum
        self.cleanRoomMaintained = cleanRoomMaintained
        self.externalGPLCodeCopied = externalGPLCodeCopied
    }
}

public enum CoreLocalBookImportBridgeError: Error, Equatable, LocalizedError, Sendable {
    case unsupported(diagnostics: [String])

    public var errorDescription: String? {
        switch self {
        case .unsupported(let diagnostics):
            if diagnostics.isEmpty {
                return "Core local-book importer rejected the selected file."
            }
            return diagnostics.joined(separator: "\n")
        }
    }
}

public protocol CoreLocalBookImporting: Sendable {
    func importBook(at url: URL) async throws -> CoreLocalBookImportSummary
}

public struct CoreLocalBookImportService: CoreLocalBookImporting {
    private static let localSourceID = "local-book"
    private static let localSourceName = "Local Book"

    private let maximumInputSize: Int
    private let snapshotStore: SnapshotStore

    public init(maximumInputSize: Int = 8_000_000, snapshotStore: SnapshotStore? = nil) {
        self.maximumInputSize = maximumInputSize
        self.snapshotStore = snapshotStore ?? Self.defaultSnapshotStore()
    }

    public func importBook(at url: URL) async throws -> CoreLocalBookImportSummary {
        let result = await ReaderCoreLocalBookImporter().importBook(
            ReaderCoreLocalBookInput(
                source: .fileURL(url),
                declaredFilename: url.lastPathComponent,
                declaredExtension: url.pathExtension.isEmpty ? nil : url.pathExtension,
                declaredMIMEType: declaredMIMEType(for: url),
                maximumInputSize: maximumInputSize
            )
        )

        var diagnostics = result.diagnostics.map { "\($0.code.rawValue): \($0.detail)" }
        let format = Self.mapFormat(result.detectedFormat)
        guard result.detectedFormat != .unsupported else {
            throw CoreLocalBookImportBridgeError.unsupported(diagnostics: diagnostics)
        }

        let chapterCache = cacheReadableChapters(
            for: result,
            fileURL: url,
            detectedFormat: format
        )
        diagnostics += chapterCache.diagnostics

        let book = LocalBook(
            id: result.metadata.bookId,
            title: result.metadata.title,
            author: result.metadata.author,
            coverPath: result.metadata.coverReference,
            filePath: url.path,
            fileFormat: format,
            fileSize: Int64(result.metadata.byteCount),
            encoding: result.detectedEncoding,
            unknownFields: [
                "coreImporter": .string("ReaderCoreLocalBookImporter"),
                "coreDetectedFormat": .string(result.detectedFormat.rawValue),
                "coreChapterCount": .number(Double(result.metadata.chapterCount)),
                "coreResourceCount": .number(Double(result.metadata.resourceCount)),
                "coreSourceChecksum": .string(result.metadata.sourceChecksum),
                "coreFirstChapterURL": chapterCache.chapters.first(where: \.contentCached).map { .string($0.chapterURL) } ?? .null,
                "cleanRoomMaintained": .bool(true),
                "externalGPLCodeCopied": .bool(false)
            ]
        )

        return CoreLocalBookImportSummary(
            book: book,
            chapterCount: result.metadata.chapterCount,
            resourceCount: result.metadata.resourceCount,
            diagnostics: diagnostics,
            chapters: chapterCache.chapters,
            detectedFormat: format,
            detectedEncoding: result.detectedEncoding,
            inputByteCount: result.inputByteCount,
            sourceChecksum: result.metadata.sourceChecksum
        )
    }

    private func declaredMIMEType(for url: URL) -> String? {
        switch url.pathExtension.lowercased() {
        case "txt": return "text/plain"
        case "html", "htm": return "text/html"
        case "epub": return "application/epub+zip"
        case "pdf": return "application/pdf"
        case "zip", "cbz": return "application/zip"
        case "tar": return "application/x-tar"
        case "mobi": return "application/x-mobipocket-ebook"
        case "azw", "azw3": return "application/vnd.amazon.ebook"
        case "umd": return "application/octet-stream"
        default: return nil
        }
    }

    private static func mapFormat(_ format: ReaderCoreLocalBookFormat) -> LocalBookFormat {
        switch format {
        case .txt: return .txt
        case .epub: return .epub
        case .pdf: return .pdf
        case .mobi: return .mobi
        case .azw: return .azw
        case .umd: return .umd
        case .archive: return .archive
        case .webdav: return .webdav
        case .unsupported: return .unknown
        }
    }

    private static func defaultSnapshotStore() -> SnapshotStore {
        let snapRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ReaderApp/Snapshots", isDirectory: true)
        return SnapshotStore(snapshotRoot: snapRoot)
    }

    /// Caches readable chapter content for TXT imports by reading the file
    /// within the caller's security-scoped resource block.
    ///
    /// The `Data(contentsOf: fileURL)` call is safe because this method is
    /// only called from `importBook(at:)` which is invoked while the caller
    /// (FileImportViewModel) holds an active `startAccessingSecurityScopedResource()`
    /// scope. If the scoped access has expired or the file is unreadable, the
    /// call gracefully degrades — chapters are returned with `contentCached: false`
    /// and a diagnostic is appended.
    ///
    /// Non-TXT formats skip content caching (metadata-only) because their
    /// chapter extraction requires format-specific decoders not yet wired.
    ///
    /// - Important: Do not call this method outside the security-scoped block.
    ///   The file access relies on the caller's scoped resource grant.
    private func cacheReadableChapters(
        for result: ReaderCoreLocalBookImportResult,
        fileURL: URL,
        detectedFormat: LocalBookFormat
    ) -> (chapters: [CoreLocalBookImportChapterSummary], diagnostics: [String]) {
        guard detectedFormat == .txt else {
            return (
                result.chapters.map { chapter in
                    Self.chapterSummary(for: result.metadata.bookId, chapter: chapter, contentCached: false)
                },
                []
            )
        }

        guard let data = try? Data(contentsOf: fileURL) else {
            return (
                result.chapters.map { chapter in
                    Self.chapterSummary(for: result.metadata.bookId, chapter: chapter, contentCached: false)
                },
                ["local_cache: failed to read selected TXT during scoped import"]
            )
        }

        guard data.count <= maximumInputSize else {
            return (
                result.chapters.map { chapter in
                    Self.chapterSummary(for: result.metadata.bookId, chapter: chapter, contentCached: false)
                },
                ["local_cache: skipped TXT cache because input exceeded \(maximumInputSize) bytes"]
            )
        }

        guard let text = Self.decodeTXT(data: data, detectedEncoding: result.detectedEncoding) else {
            return (
                result.chapters.map { chapter in
                    Self.chapterSummary(for: result.metadata.bookId, chapter: chapter, contentCached: false)
                },
                ["local_cache: skipped TXT cache because encoding \(result.detectedEncoding ?? "unknown") is not supported by the bridge decoder"]
            )
        }

        let chapters = Self.sliceTXTContent(text: text, coreChapters: result.chapters)
        guard !chapters.isEmpty else {
            return (
                result.chapters.map { chapter in
                    Self.chapterSummary(for: result.metadata.bookId, chapter: chapter, contentCached: false)
                },
                ["local_cache: skipped TXT cache because no readable chapters were produced"]
            )
        }

        var summaries: [CoreLocalBookImportChapterSummary] = []
        var cacheDiagnostics: [String] = []
        for chapter in chapters {
            let chapterURL = Self.localChapterURL(bookID: result.metadata.bookId, index: chapter.index)
            let nextURL = chapters.first(where: { $0.index == chapter.index + 1 }).map {
                Self.localChapterURL(bookID: result.metadata.bookId, index: $0.index)
            }
            let saveResult = snapshotStore.saveChapterContentSnapshot(
                sourceId: Self.localSourceID,
                sourceName: Self.localSourceName,
                host: "local",
                chapterURL: chapterURL,
                chapterTitle: chapter.title,
                content: chapter.content,
                nextChapterURL: nextURL
            )
            let cached: Bool
            switch saveResult {
            case .success:
                cached = true
            case .failure(let error):
                cached = false
                cacheDiagnostics.append("local_cache: failed to cache \(chapter.title): \(error.localizedDescription)")
            }
            summaries.append(
                CoreLocalBookImportChapterSummary(
                    index: chapter.index,
                    title: chapter.title,
                    chapterURL: chapterURL,
                    preview: String(chapter.content.prefix(result.previewCharacterLimit)),
                    contentCached: cached
                )
            )
        }
        return (summaries, cacheDiagnostics)
    }

    private static func chapterSummary(
        for bookID: String,
        chapter: ReaderCoreLocalBookChapter,
        contentCached: Bool
    ) -> CoreLocalBookImportChapterSummary {
        CoreLocalBookImportChapterSummary(
            index: chapter.ordinal,
            title: chapter.title,
            chapterURL: localChapterURL(bookID: bookID, index: chapter.ordinal),
            preview: chapter.preview,
            contentCached: contentCached
        )
    }

    private static func localChapterURL(bookID: String, index: Int) -> String {
        "local-book://book/\(bookID)/chapter/\(index)"
    }

    private struct TXTChapterContent {
        var index: Int
        var title: String
        var content: String
    }

    private static func decodeTXT(data: Data, detectedEncoding: String?) -> String? {
        let normalized = detectedEncoding?.lowercased().replacingOccurrences(of: "_", with: "-")
        switch normalized {
        case nil, "utf-8", "utf8", "utf-8-bom":
            if data.starts(with: [0xEF, 0xBB, 0xBF]) {
                return String(data: data.dropFirst(3), encoding: .utf8)
            }
            return String(data: data, encoding: .utf8)
        case "utf-16", "utf16":
            return String(data: data, encoding: .utf16)
        case "utf-16le", "utf-16-le":
            return String(data: data, encoding: .utf16LittleEndian)
        case "utf-16be", "utf-16-be":
            return String(data: data, encoding: .utf16BigEndian)
        default:
            return String(data: data, encoding: .utf8)
        }
    }

    private static func sliceTXTContent(
        text: String,
        coreChapters: [ReaderCoreLocalBookChapter]
    ) -> [TXTChapterContent] {
        let normalizedText = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedText.components(separatedBy: "\n")
        guard !lines.isEmpty else { return [] }

        let sorted = coreChapters.sorted { $0.ordinal < $1.ordinal }
        let starts: [(chapter: ReaderCoreLocalBookChapter, line: Int)] = sorted.compactMap { chapter in
            guard let line = txtLineStart(from: chapter.locator) else { return nil }
            return (chapter, max(0, min(line, lines.count)))
        }

        guard !starts.isEmpty else {
            let title = sorted.first?.title ?? "Chapter 1"
            let trimmed = normalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? [] : [TXTChapterContent(index: 0, title: title, content: trimmed)]
        }

        var chapters: [TXTChapterContent] = []
        for (position, start) in starts.enumerated() {
            let end = position + 1 < starts.count ? starts[position + 1].line : lines.count
            guard start.line < end else { continue }
            let content = lines[start.line..<end]
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !content.isEmpty else { continue }
            chapters.append(TXTChapterContent(index: start.chapter.ordinal, title: start.chapter.title, content: content))
        }
        return chapters
    }

    private static func txtLineStart(from locator: String) -> Int? {
        guard locator.hasPrefix("txt:") else { return nil }
        let value = String(locator.dropFirst(4))
        if value == "preface" { return 0 }
        return Int(value)
    }
}
