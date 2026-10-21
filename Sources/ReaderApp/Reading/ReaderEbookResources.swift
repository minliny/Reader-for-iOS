import Foundation
import CryptoKit
import ImageIO
import UniformTypeIdentifiers
import WebKit
import ReaderCore

enum ReaderEbookError: Error, Equatable {
    case invalidIdentity
    case invalidEntry
    case sourceChanged
    case resourceLimit
    case archiveRead(Int32)
    case invalidDocument
    case positionMismatch
    case networkPolicyCompilation(domain: String, code: Int)
    case scriptFailure(stage: String, reason: String)
    case navigationFailure(domain: String, code: Int, provisional: Bool)
    case fontResourceFailure(domain: String, code: Int)
}

/// Paths come from Core's presentation/resource identity. This only checks the
/// platform URL boundary; Core repeats canonical-path validation before ZIP I/O.
enum ReaderEbookResourcePath {
    static func isCanonical(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\")
            && !path.contains("\0") && !path.contains(":")
            && path.split(separator: "/", omittingEmptySubsequences: false)
                .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
    }

    static func url(entry: String, origin: String) throws -> URL {
        guard isCanonical(entry) else { throw ReaderEbookError.invalidEntry }
        var parts = URLComponents()
        parts.scheme = "reader-ebook"
        parts.host = origin
        parts.path = "/" + entry
        guard let url = parts.url else { throw ReaderEbookError.invalidEntry }
        return url
    }

    static func entry(url: URL, origin: String) throws -> String {
        guard url.scheme == "reader-ebook", url.host == origin,
              url.user == nil, url.password == nil, url.port == nil,
              let parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ReaderEbookError.invalidEntry
        }
        // URLComponents decodes once. Double-escaped filename characters stay
        // literal and are never decoded a second time by this Host adapter.
        let value = String(parts.path.dropFirst())
        guard parts.path.hasPrefix("/"), isCanonical(value) else { throw ReaderEbookError.invalidEntry }
        return value
    }

    static func mimeType(_ entry: String) -> String {
        switch (entry as NSString).pathExtension.lowercased() {
        case "xhtml": return "application/xhtml+xml"
        case "html", "htm": return "text/html"
        case "css": return "text/css"
        case "svg": return "image/svg+xml"
        case "woff": return "font/woff"
        case "woff2": return "font/woff2"
        case "otf": return "font/otf"
        case "ttf": return "font/ttf"
        default: return UTType(filenameExtension: (entry as NSString).pathExtension)?.preferredMIMEType
            ?? "application/octet-stream"
        }
    }
}

/// The original source is retained by ReaderLibraryService. This object only
/// opens it read-only, verifies the existing content identity, then delegates
/// EPUB/MOBI archive decoding to pinned Core's bounded binary asset ABI.
actor ReaderEbookArchiveReader {
    private let sourceURL: URL
    private let bookID: String
    private var verifiedStamp: SourceStamp?

    init(sourceURL: URL, bookID: String) {
        self.sourceURL = sourceURL
        self.bookID = bookID
    }

    func readEntry(_ entry: String, maximumBytes: Int) throws -> Data {
        guard maximumBytes > 0, maximumBytes <= 32 * 1024 * 1024,
              ReaderEbookResourcePath.isCanonical(entry) else { throw ReaderEbookError.invalidEntry }
        try verifySource()
        try Task.checkCancellation()
        let archive = Array(sourceURL.path.utf8)
        let path = Array(entry.utf8)
        var buffer = rc_owned_bytes_t(data: nil, length: 0)
        let status = archive.withUnsafeBufferPointer { archiveBytes in
            path.withUnsafeBufferPointer { entryBytes in
                rc_epub_read_entry(archiveBytes.baseAddress, archiveBytes.count,
                                   entryBytes.baseAddress, entryBytes.count, maximumBytes, &buffer)
            }
        }
        defer { rc_owned_bytes_free(&buffer) }
        guard status == 0 else { throw ReaderEbookError.archiveRead(status) }
        guard buffer.length <= maximumBytes, let bytes = buffer.data else { throw ReaderEbookError.resourceLimit }
        let data = Data(bytes: bytes, count: buffer.length)
        guard try stamp() == verifiedStamp else { throw ReaderEbookError.sourceChanged }
        try Task.checkCancellation()
        return data
    }

    private struct SourceStamp: Equatable {
        let size: UInt64
        let modified: Date
        let fileNumber: UInt64
    }

    private func stamp() throws -> SourceStamp {
        let attributes = try FileManager.default.attributesOfItem(atPath: sourceURL.path)
        guard sourceURL.isFileURL, attributes[.type] as? FileAttributeType == .typeRegular,
              let size = attributes[.size] as? NSNumber, size.uint64Value <= 64 * 1024 * 1024,
              let modified = attributes[.modificationDate] as? Date,
              let number = attributes[.systemFileNumber] as? NSNumber else {
            throw ReaderEbookError.invalidIdentity
        }
        return SourceStamp(size: size.uint64Value, modified: modified, fileNumber: number.uint64Value)
    }

    private func verifySource() throws {
        let before = try stamp()
        if let verifiedStamp {
            guard before == verifiedStamp else { throw ReaderEbookError.sourceChanged }
            return
        }
        guard bookID.hasPrefix("local:"), bookID.count == 70 else { throw ReaderEbookError.invalidIdentity }
        let file = try FileHandle(forReadingFrom: sourceURL)
        defer { try? file.close() }
        var digest = SHA256()
        while let chunk = try file.read(upToCount: 1024 * 1024), !chunk.isEmpty {
            try Task.checkCancellation()
            digest.update(data: chunk)
        }
        let hash = digest.finalize().map { String(format: "%02x", $0) }.joined()
        guard bookID == "local:" + hash else { throw ReaderEbookError.invalidIdentity }
        guard try stamp() == before else { throw ReaderEbookError.sourceChanged }
        verifiedStamp = before
    }
}

/// ImageIO supplies decoding, orientation and thumbnailing. No Host image
/// codec, archive implementation or cache-eviction algorithm is introduced.
enum ReaderEbookImageBudget {
    static let maximumDimension = 2048
    static let maximumSourcePixels = 32_000_000

    static func decodedPixelCost(_ data: Data, mimeType: String) throws -> Int {
        guard mimeType.hasPrefix("image/") else { return 0 }
        if mimeType == "image/svg+xml" { return maximumDimension * maximumDimension }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber else { throw ReaderEbookError.resourceLimit }
        return min(maximumDimension, max(0, width.intValue)) * min(maximumDimension, max(0, height.intValue))
    }

    static func prepare(_ data: Data, mimeType: String) throws -> (Data, String) {
        guard mimeType.hasPrefix("image/"), mimeType != "image/svg+xml" else { return (data, mimeType) }
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              width.int64Value > 0, height.int64Value > 0,
              width.int64Value <= Int64(maximumSourcePixels) / height.int64Value else {
            throw ReaderEbookError.resourceLimit
        }
        if max(width.intValue, height.intValue) <= maximumDimension { return (data, mimeType) }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw ReaderEbookError.resourceLimit
        }
        let result = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(result, UTType.png.identifier as CFString, 1, nil) else {
            throw ReaderEbookError.resourceLimit
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw ReaderEbookError.resourceLimit }
        return (result as Data, "image/png")
    }
}

@MainActor
final class ReaderEbookResourceBridge: NSObject, WKURLSchemeHandler {
    let origin = UUID().uuidString.lowercased()
    private let loader: ReaderEbookResourceLoader
    private var tasks: [ObjectIdentifier: Task<Void, Never>] = [:]
    private var servedBytes = 0
    private var requestCount = 0
    private var retired = false
    private var inlineImages: [String: (Data, String)] = [:]
    private var inlineBytes = 0
    private let inlinePreparer = ReaderEbookInlineImagePreparer()
    private let maximumSessionBytes = 64 * 1024 * 1024
    private var fontAsset: (String, Data, String)?

    init(reader: ReaderEbookArchiveReader) { self.loader = ReaderEbookResourceLoader(reader: reader) }

    func registerFont(postScriptName: String) async throws -> URL {
        let prepared = try await Task.detached(priority: .userInitiated) {
            try ReaderEbookFontAsset.prepare(postScriptName: postScriptName)
        }.value
        try Task.checkCancellation()
        guard !retired else { throw CancellationError() }
        let path = "__reader_font__/" + UUID().uuidString.lowercased()
        fontAsset = (path, prepared.0, prepared.1)
        return try ReaderEbookResourcePath.url(entry: path, origin: origin)
    }

    func registerInlineImage(_ source: String) async throws -> URL {
        guard !retired, source.utf8.count <= 12 * 1024 * 1024 else { throw ReaderEbookError.resourceLimit }
        let prepared = try await inlinePreparer.prepare(source)
        try Task.checkCancellation()
        guard !retired, prepared.0.count <= 32 * 1024 * 1024 - inlineBytes,
              prepared.0.count <= maximumSessionBytes - inlineBytes - servedBytes else {
            throw ReaderEbookError.resourceLimit
        }
        let entry = "__reader_inline__/" + UUID().uuidString.lowercased()
        inlineImages[entry] = prepared
        inlineBytes += prepared.0.count
        return try ReaderEbookResourcePath.url(entry: entry, origin: origin)
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        let id = ObjectIdentifier(urlSchemeTask)
        guard !retired, let url = urlSchemeTask.request.url,
              let entry = try? ReaderEbookResourcePath.entry(url: url, origin: origin), requestCount < 512 else {
            urlSchemeTask.didFailWithError(ReaderEbookError.invalidEntry)
            return
        }
        requestCount += 1
        tasks[id] = Task { [weak self] in
            guard let self else { return }
            do {
                let prepared: (Data, String)
                let isFont = fontAsset?.0 == entry
                if let fontAsset, fontAsset.0 == entry { prepared = (fontAsset.1, fontAsset.2) }
                else if let inline = inlineImages[entry] { prepared = inline }
                else { prepared = try await loader.load(entry, mime: ReaderEbookResourcePath.mimeType(entry)) }
                try Task.checkCancellation()
                guard !retired, tasks[id] != nil else { return }
                if !isFont {
                    guard prepared.0.count <= maximumSessionBytes - servedBytes else { throw ReaderEbookError.resourceLimit }
                    servedBytes += prepared.0.count
                }
                // Core admits XHTML/HTML and stylesheets as UTF-8 strings.
                // Old reconstructed MOBI HTML may have no charset declaration;
                // allowing WebKit to guess can reinterpret those same original
                // bytes as GB18030 and destroy the proven scalar correspondence.
                let contentType = ["text/html", "application/xhtml+xml", "text/css"].contains(prepared.1)
                    ? prepared.1 + "; charset=utf-8" : prepared.1
                let headers = ["Content-Type": contentType, "Content-Length": String(prepared.0.count),
                    "Cache-Control": "no-store", "Content-Security-Policy": Self.contentSecurityPolicy]
                guard let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers) else {
                    throw ReaderEbookError.invalidEntry
                }
                urlSchemeTask.didReceive(response)
                urlSchemeTask.didReceive(prepared.0)
                urlSchemeTask.didFinish()
            } catch {
                if !Task.isCancelled, !retired, tasks[id] != nil { urlSchemeTask.didFailWithError(error) }
            }
            tasks.removeValue(forKey: id)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {
        tasks.removeValue(forKey: ObjectIdentifier(urlSchemeTask))?.cancel()
    }

    func retire() {
        retired = true
        tasks.values.forEach { $0.cancel() }
        tasks.removeAll()
        inlineImages.removeAll()
        inlineBytes = 0
        fontAsset = nil
    }

    static let contentSecurityPolicy = "default-src 'none'; script-src 'none'; connect-src 'none'; "
        + "style-src 'self' 'unsafe-inline'; img-src 'self'; font-src 'self' data:; "
        + "frame-src 'none'; object-src 'none'; media-src 'none'; base-uri 'none'; form-action 'none'"
}

/// Serial resource preparation bounds both compressed bytes admitted by Core
/// and image decoding outside MainActor. It stores no second resource cache.
private actor ReaderEbookResourceLoader {
    let reader: ReaderEbookArchiveReader
    private var remainingBytes = 64 * 1024 * 1024
    private var remainingPixels = 16_000_000
    init(reader: ReaderEbookArchiveReader) { self.reader = reader }
    func load(_ entry: String, mime: String) async throws -> (Data, String) {
        let maximum = mime.hasPrefix("image/") ? 8 * 1024 * 1024 : 32 * 1024 * 1024
        guard remainingBytes > 0 else { throw ReaderEbookError.resourceLimit }
        let bytes = try await reader.readEntry(entry, maximumBytes: min(maximum, remainingBytes))
        try Task.checkCancellation()
        // Reentrancy is checked after the read. Concurrent completions cannot
        // each spend the same remaining budget.
        guard bytes.count <= remainingBytes else { throw ReaderEbookError.resourceLimit }
        remainingBytes -= bytes.count
        let pixels = try ReaderEbookImageBudget.decodedPixelCost(bytes, mimeType: mime)
        guard pixels <= remainingPixels else { throw ReaderEbookError.resourceLimit }
        remainingPixels -= pixels
        return try ReaderEbookImageBudget.prepare(bytes, mimeType: mime)
    }
}

/// Foundation decodes the data URL and ImageIO owns all pixel work. Serial
/// preparation prevents several small compressed images decoding in parallel.
private actor ReaderEbookInlineImagePreparer {
    private var remainingBytes = 32 * 1024 * 1024
    private var remainingPixels = 16_000_000
    func prepare(_ source: String) throws -> (Data, String) {
        try Task.checkCancellation()
        guard remainingBytes > 0, let comma = source.firstIndex(of: ","), source.hasPrefix("data:image/") else {
            throw ReaderEbookError.invalidEntry
        }
        let header = String(source[source.index(source.startIndex, offsetBy: 5)..<comma])
        let mime = String(header.split(separator: ";")[0]).lowercased()
        let payload = String(source[source.index(after: comma)...])
        let bytes: Data?
        if header.lowercased().contains(";base64") { bytes = Data(base64Encoded: payload, options: [.ignoreUnknownCharacters]) }
        else { bytes = payload.removingPercentEncoding?.data(using: .utf8) }
        guard let bytes, bytes.count <= min(8 * 1024 * 1024, remainingBytes),
              mime != "image/svg+xml" || bytes.count <= 2 * 1024 * 1024 else {
            throw ReaderEbookError.resourceLimit
        }
        let pixels = try ReaderEbookImageBudget.decodedPixelCost(bytes, mimeType: mime)
        guard pixels <= remainingPixels else { throw ReaderEbookError.resourceLimit }
        remainingPixels -= pixels
        let result = try ReaderEbookImageBudget.prepare(bytes, mimeType: mime)
        guard result.0.count <= remainingBytes else { throw ReaderEbookError.resourceLimit }
        remainingBytes -= result.0.count
        return result
    }
}
