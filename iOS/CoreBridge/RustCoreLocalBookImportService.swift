import CryptoKit
import Foundation
import ReaderCoreFoundation
import ReaderCoreModels
import ReaderCoreNativeAdapter

/// Production local-book importer for Slice 9.
///
/// The file picker owns security-scoped authorization. This adapter performs
/// the bounded Host read while that scope is active, sends the raw bytes to the
/// existing Reader-Core-Native `local_book.import` contract, and reads every
/// materialized chapter back through `local_book.chapter.content`. The latter
/// results are copied into SnapshotStore strictly as a renderer cache; Core
/// remains the business-data authority.
public final class RustCoreLocalBookImportService: CoreLocalBookImporting, @unchecked Sendable {
    private struct ImportedBook: Sendable {
        let bookID: String
        let title: String
        let author: String?
        let coverURL: String?
        let format: LocalBookFormat
        let encoding: String?
        let byteCount: Int
        let chapterCount: Int
        let toc: [ImportedTOCEntry]
    }

    private struct ImportedTOCEntry: Sendable {
        let index: Int
        let title: String
        let url: String
    }

    private struct ImportedChapter: Sendable {
        let index: Int
        let title: String
        let content: String
    }

    private let runtime: any RustCoreCommandRuntime
    private let maximumInputSize: Int
    private let requestTimeout: TimeInterval
    private let snapshotStore: SnapshotStore

    public init(
        runtime: any RustCoreCommandRuntime,
        maximumInputSize: Int = 8_000_000,
        requestTimeout: TimeInterval = 30,
        snapshotStore: SnapshotStore? = nil
    ) {
        self.runtime = runtime
        self.maximumInputSize = maximumInputSize
        self.requestTimeout = requestTimeout
        self.snapshotStore = snapshotStore ?? Self.defaultSnapshotStore()
    }

    public func importBook(at url: URL) async throws -> CoreLocalBookImportSummary {
        let data: Data
        do {
            data = try Data(contentsOf: url, options: [.mappedIfSafe])
        } catch {
            throw CoreLocalBookImportBridgeError.failedClosed(
                code: "SLICE9_LOCAL_FILE_READ_FAILED",
                message: error.localizedDescription
            )
        }
        guard !data.isEmpty else {
            throw CoreLocalBookImportBridgeError.unsupported(diagnostics: ["empty_file: input has zero bytes"])
        }
        guard data.count <= maximumInputSize else {
            throw CoreLocalBookImportBridgeError.failedClosed(
                code: "SLICE9_LOCAL_FILE_TOO_LARGE",
                message: "input contains \(data.count) bytes; maximum is \(maximumInputSize)"
            )
        }

        let checksum = Self.sha256(data)
        let bookID = "ios-local:\(checksum)"
        let imported = try await importIntoCore(
            data: data,
            url: url,
            bookID: bookID
        )
        guard imported.bookID == bookID else {
            throw CoreLocalBookImportBridgeError.failedClosed(
                code: "SLICE9_LOCAL_BOOK_ID_DRIFT",
                message: "Core returned \(imported.bookID) for \(bookID)"
            )
        }
        guard !imported.toc.isEmpty else {
            throw CoreLocalBookImportBridgeError.failedClosed(
                code: "SLICE9_LOCAL_TOC_EMPTY",
                message: "Core materialized no readable chapters for \(url.lastPathComponent)"
            )
        }

        let chapters = try await cacheMaterializedChapters(
            bookID: imported.bookID,
            toc: imported.toc
        )
        guard chapters.contains(where: \.contentCached) else {
            throw CoreLocalBookImportBridgeError.failedClosed(
                code: "SLICE9_LOCAL_CONTENT_UNAVAILABLE",
                message: "Core returned no readable chapter body"
            )
        }

        let book = LocalBook(
            id: imported.bookID,
            title: imported.title,
            author: imported.author,
            coverPath: imported.coverURL,
            filePath: url.path,
            fileFormat: imported.format,
            fileSize: Int64(imported.byteCount),
            encoding: imported.encoding,
            unknownFields: [
                "coreImporter": .string("Reader-Core-Native/local_book.import"),
                "coreMaterialized": .bool(true),
                "coreChapterCount": .number(Double(imported.chapterCount)),
                "coreSourceChecksum": .string(checksum),
                "cleanRoomMaintained": .bool(true),
                "externalGPLCodeCopied": .bool(false)
            ]
        )

        return CoreLocalBookImportSummary(
            book: book,
            chapterCount: imported.chapterCount,
            resourceCount: 0,
            diagnostics: [
                "native_core_materialized: local_book.import",
                "renderer_cache_materialized: \(chapters.filter(\.contentCached).count)/\(chapters.count)"
            ],
            chapters: chapters,
            detectedFormat: imported.format,
            detectedEncoding: imported.encoding,
            inputByteCount: imported.byteCount,
            sourceChecksum: checksum,
            readingAuthority: .nativeCoreMaterialized
        )
    }

    private func importIntoCore(data: Data, url: URL, bookID: String) async throws -> ImportedBook {
        let extensionHint = url.pathExtension.lowercased()
        var params: [String: Any] = [
            "bookId": bookID,
            "title": url.deletingPathExtension().lastPathComponent,
            "fileName": url.lastPathComponent,
            "bytesBase64": data.base64EncodedString()
        ]
        if !extensionHint.isEmpty {
            params["format"] = extensionHint
        }
        let handle = try RustCoreRequestScopedCommand<ImportedBook>(
            runtime: runtime,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            method: "local_book.import",
            params: params,
            timeout: requestTimeout,
            resultTransform: Self.parseImportResult
        )
        try handle.start()
        return try await handle.value()
    }

    private func cacheMaterializedChapters(
        bookID: String,
        toc: [ImportedTOCEntry]
    ) async throws -> [CoreLocalBookImportChapterSummary] {
        var summaries: [CoreLocalBookImportChapterSummary] = []
        for (position, entry) in toc.enumerated() {
            let handle = try RustCoreRequestScopedCommand<ImportedChapter>(
                runtime: runtime,
                requestID: RustCoreServiceSupport.allocateRequestID(),
                method: "local_book.chapter.content",
                params: ["bookId": bookID, "chapterIndex": entry.index],
                timeout: requestTimeout,
                resultTransform: Self.parseChapterResult
            )
            try handle.start()
            let chapter = try await handle.value()
            guard chapter.index == entry.index else {
                throw CoreLocalBookImportBridgeError.failedClosed(
                    code: "SLICE9_LOCAL_CHAPTER_IDENTITY_DRIFT",
                    message: "requested chapter \(entry.index), received \(chapter.index)"
                )
            }
            let normalizedContent = chapter.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalizedContent.isEmpty else {
                throw CoreLocalBookImportBridgeError.failedClosed(
                    code: "SLICE9_LOCAL_CHAPTER_CONTENT_EMPTY",
                    message: "chapter \(entry.index) has no renderable text"
                )
            }
            let nextURL = position + 1 < toc.count ? toc[position + 1].url : nil
            let save = snapshotStore.saveChapterContentSnapshot(
                sourceId: "local-book",
                sourceName: "Local Book",
                host: "local",
                chapterURL: entry.url,
                chapterTitle: chapter.title.isEmpty ? entry.title : chapter.title,
                content: chapter.content,
                nextChapterURL: nextURL
            )
            switch save {
            case .success:
                summaries.append(CoreLocalBookImportChapterSummary(
                    index: entry.index,
                    title: chapter.title.isEmpty ? entry.title : chapter.title,
                    chapterURL: entry.url,
                    preview: String(normalizedContent.prefix(64)),
                    contentCached: true
                ))
            case .failure(let error):
                throw CoreLocalBookImportBridgeError.failedClosed(
                    code: "SLICE9_LOCAL_RENDERER_CACHE_WRITE_FAILED",
                    message: error.localizedDescription
                )
            }
        }
        return summaries
    }

    private static func parseImportResult(_ data: [String: Any]?) throws -> ImportedBook {
        guard let data,
              let rawBook = data["book"] as? [String: Any],
              let bookID = nonBlank(rawBook["bookId"]),
              let title = nonBlank(rawBook["title"]),
              let rawFormat = nonBlank(data["format"]),
              let format = localFormat(rawFormat),
              let rawTOC = data["toc"] as? [[String: Any]] else {
            throw CoreLocalBookImportBridgeError.failedClosed(
                code: "SLICE9_LOCAL_IMPORT_RESULT_INVALID",
                message: "local_book.import omitted required book/format/toc fields"
            )
        }
        let toc = try rawTOC.map { raw -> ImportedTOCEntry in
            guard let index = integer(raw["index"]), index >= 0,
                  let title = nonBlank(raw["title"]),
                  let url = nonBlank(raw["url"]) else {
                throw CoreLocalBookImportBridgeError.failedClosed(
                    code: "SLICE9_LOCAL_TOC_RESULT_INVALID",
                    message: "Core returned an invalid TOC entry"
                )
            }
            return ImportedTOCEntry(index: index, title: title, url: url)
        }
        return ImportedBook(
            bookID: bookID,
            title: title,
            author: nonBlank(rawBook["author"]),
            coverURL: nonBlank(rawBook["coverUrl"]),
            format: format,
            encoding: nonBlank(data["encoding"]),
            byteCount: integer(data["byteLen"]) ?? 0,
            chapterCount: integer(data["chapterCount"]) ?? toc.count,
            toc: toc.sorted { $0.index < $1.index }
        )
    }

    private static func parseChapterResult(_ data: [String: Any]?) throws -> ImportedChapter {
        guard let data,
              let index = integer(data["chapterIndex"]), index >= 0,
              let title = data["chapterTitle"] as? String,
              let content = data["content"] as? String else {
            throw CoreLocalBookImportBridgeError.failedClosed(
                code: "SLICE9_LOCAL_CHAPTER_RESULT_INVALID",
                message: "local_book.chapter.content omitted required fields"
            )
        }
        return ImportedChapter(index: index, title: title, content: content)
    }

    private static func localFormat(_ value: String) -> LocalBookFormat? {
        switch value.lowercased() {
        case "txt", "html": return .txt
        case "epub": return .epub
        case "pdf": return .pdf
        case "mobi": return .mobi
        case "azw", "azw3": return .azw
        case "umd": return .umd
        default: return nil
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func nonBlank(_ value: Any?) -> String? {
        guard let value = value as? String else { return nil }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func defaultSnapshotStore() -> SnapshotStore {
        let root = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return SnapshotStore(snapshotRoot: root.appendingPathComponent("ReaderApp/Snapshots", isDirectory: true))
    }
}
