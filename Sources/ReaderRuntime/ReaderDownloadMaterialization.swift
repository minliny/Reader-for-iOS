import CryptoKit
import Foundation
import ImageIO

extension ReaderLibraryService {
    func materializeDownloadChapter(_ book: ReaderBook, lease: ReaderDownloadMaterialization,
                                    operationID: String) async throws {
        guard !lease.token.isEmpty else { throw ReaderLibraryError.operationPending(operationID) }
        let childID = operationID + ":materialize:" + String(lease.chapterIndex)
        let parameters: [String: Any]
        if let original = try existingCoreParameters(operationID: childID, method: "cache.chapter.materialization.report") {
            guard original["sourceId"] as? String == book.sourceId, original["bookId"] as? String == book.bookId,
                  (original["chapterIndex"] as? NSNumber)?.uint32Value == lease.chapterIndex,
                  original["token"] as? String == lease.token else { throw ReaderLibraryError.operationPending(operationID) }
            var business = original
            business.removeValue(forKey: "operationId"); business.removeValue(forKey: "sequence")
            parameters = business
        } else {
            var report: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId,
                "chapterIndex": lease.chapterIndex, "token": lease.token]
            do {
                let body = try await cachedDownloadBody(book, chapter: lease.chapterIndex)
                var total = 0
                var fetched = Set<String>()
                for image in body.blocks where image.kind == "image" {
                    try Task.checkCancellation()
                    guard let source = image.source, !source.isEmpty else {
                        throw ReaderLibraryError.invalidResponse("download image identity")
                    }
                    if !fetched.insert(source).inserted { continue }
                    guard fetched.count <= 32 else { throw ReaderLibraryError.invalidResponse("chapter image request budget") }
                    let current = try await readerDownloadStatus(book)
                    if let state = current.chapters.first(where: { $0.chapterIndex == lease.chapterIndex })?.state,
                       state == .paused || state == .cancelled {
                        // A current control state only stops further I/O. It
                        // cannot settle this lease; Core's original-token
                        // report below supplies its exact paused/cancelled ACK.
                        throw ReaderLibraryError.invalidResponse("download resource work interrupted")
                    }
                    let bytes = try await chapterImage(book: book, content: body, url: source)
                    total += bytes.count
                    guard total <= 32 * 1024 * 1024 else { throw ReaderLibraryError.invalidResponse("chapter image budget") }
                }
                report["outcome"] = "completed"
            } catch is CancellationError { throw CancellationError() }
            catch {
                // Report the exact lease as failed; retained Core text remains
                // readable. A later user resume owns a new generation.
                report["outcome"] = "failed"
                report["errorCode"] = "IOS_RESOURCE_UNAVAILABLE"
            }
            report["reportedAt"] = Int64(Date().timeIntervalSince1970 * 1000)
            parameters = report
        }
        let result = try object(await downloadMutation("cache.chapter.materialization.report", parameters,
            operationID: childID, scope: "download-task:\(book.id):\(lease.chapterIndex)"))
        guard result["sourceId"] as? String == book.sourceId, result["bookId"] as? String == book.bookId,
              (result["chapterIndex"] as? NSNumber)?.uint32Value == lease.chapterIndex,
              ["completed", "failed", "cancelled", "paused"].contains(result["state"] as? String ?? "") else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        try await finishCoreOperation(childID)
    }

    func cachedDownloadBody(_ book: ReaderBook, chapter: UInt32) async throws -> ReaderChapterContent {
        let result = try object(await coreRead("chapter.content", ["sourceId": book.sourceId,
            "bookId": book.bookId, "chapterIndex": chapter, "chapterTitle": "", "cacheOnly": true]))
        guard result["via"] as? String == "cache", result["sourceId"] as? String == book.sourceId,
              result["bookId"] as? String == book.bookId,
              let text = result["content"] as? String,
              let bodyVersion = result["bodyVersion"] as? String, let processingVersion = result["processingVersion"] as? String else {
            throw ReaderLibraryError.invalidResponse("download cached body")
        }
        // ChapterContentData binds its requested index in Core; the wire DTO
        // echoes source/book and versions, but has no chapterIndex property.
        let blocks = try (result["blocks"] as? [[String: Any]]).map {
            try decode([ReaderContentBlock].self, JSONSerialization.data(withJSONObject: $0))
        } ?? []
        return .init(sourceId: book.sourceId, bookId: book.bookId, chapterIndex: chapter,
            chapterTitle: result["chapterTitle"] as? String ?? "", content: text,
            bodyVersion: bodyVersion, processingVersion: processingVersion, blocks: blocks)
    }

    /// Physical resource storage only. Core still owns the chapter, body
    /// version, image descriptors, download generation and task outcome.
    public func chapterImage(book: ReaderBook, content: ReaderChapterContent, url: String) async throws -> Data {
        guard book.sourceId == content.sourceId, book.bookId == content.bookId,
              let body = content.bodyVersion, let processing = content.processingVersion,
              content.blocks.contains(where: { $0.kind == "image" && $0.source == url }) else {
            throw ReaderLibraryError.invalidResponse("chapter image owner")
        }
        let root = sourceURL.appendingPathComponent(".download-assets", isDirectory: true)
            .appendingPathComponent(downloadAssetHash([book.sourceId, book.bookId]), isDirectory: true)
            .appendingPathComponent(String(content.chapterIndex), isDirectory: true)
            .appendingPathComponent(downloadAssetHash([body, processing]), isDirectory: true)
        let file = root.appendingPathComponent(downloadAssetHash([url]))
        if FileManager.default.fileExists(atPath: file.path) {
            let size = try file.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 8 * 1024 * 1024 else { throw ReaderLibraryError.invalidResponse("stored image budget") }
            let bytes = try Data(contentsOf: file, options: [.mappedIfSafe])
            try validateDownloadImage(bytes)
            return bytes
        }
        let bytes = try await remoteImage(sourceID: book.sourceId, url: url)
        try validateDownloadImage(bytes)
        try Task.checkCancellation()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try bytes.write(to: file, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return bytes
    }

    private func validateDownloadImage(_ bytes: Data) throws {
        guard !bytes.isEmpty, bytes.count <= 8 * 1024 * 1024,
              let image = CGImageSourceCreateWithData(bytes as CFData, nil), CGImageSourceGetCount(image) > 0,
              let properties = CGImageSourceCopyPropertiesAtIndex(image, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.doubleValue > 0, height.doubleValue > 0,
              width.doubleValue * height.doubleValue <= 40_000_000,
              CGImageSourceCreateThumbnailAtIndex(image, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 128,
                kCGImageSourceShouldCacheImmediately: true
              ] as CFDictionary) != nil else {
            throw ReaderLibraryError.invalidResponse("download image decoding budget")
        }
    }

    func downloadAssetHash(_ parts: [String]) -> String {
        // Length-delimited JSON prevents identity aliases across separators.
        let bytes = (try? JSONEncoder().encode(parts)) ?? Data()
        return SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
    }
}
