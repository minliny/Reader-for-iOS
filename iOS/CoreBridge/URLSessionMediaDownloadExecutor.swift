// CoreBridge
//
// URLSessionMediaDownloadExecutor: production `MediaDownloadExecutor` backed
// by `URLSession` + `CryptoKit`.
//
// Implements the foreground `media.download` host lane contract (mirrors Core's
// `HostMediaDownloadRequest` / `HostMediaDownloadResponse`):
// - Range requests via the `Range: bytes=start-end` header.
// - Redirect: `URLSession` follows redirects by default; the final URL is
//   captured from `HTTPURLResponse.url`.
// - ETag/304: sends `If-None-Match` / `If-Modified-Since` and short-circuits
//   on 304 (`fromCache = true`, `byteLength = 0`, no body written).
// - sha256: `CryptoKit.SHA256` over the downloaded bytes (hex lowercase).
// - Temp file: streams through a same-directory staging file, then publishes
//   under a dedicated admitted root without overwriting caller-owned paths.
// - maxBytes: stops the byte stream as soon as the bound would be exceeded.
// - timeoutMillis: applied via `URLRequest.timeoutInterval`.
//
// Proof tier: macOS source test with intercepted URLProtocol responses. This is
// not simulator/device/live-network proof. Background URLSession, cellular
// policy and restart recovery remain unproven or missing.
//
// Clean-room: no Legado/Android code reused; implementation follows the Core
// contract in `crates/reader-contract/src/host.rs` only.

import Foundation
import CryptoKit
import ReaderCoreProtocols

/// Production `MediaDownloadExecutor` backed by `URLSession` + `CryptoKit`.
public final class URLSessionMediaDownloadExecutor: MediaDownloadExecutor, @unchecked Sendable {
    private let session: URLSession
    private let cacheRoot: URL
    private let allowedSaveRoots: [URL]
    private let cookieJar: ScopedCookieJar?

    /// Initialize with an optional custom `URLSession` (e.g. for URLProtocol
    /// interception in tests) and cache root (defaults to
    /// `Caches/ReaderApp/MediaDownloads/`).
    public init(
        session: URLSession? = nil,
        cacheRoot: URL? = nil,
        allowedSaveRoots: [URL]? = nil,
        cookieJar: ScopedCookieJar? = nil
    ) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = session ?? URLSession(configuration: config)
        let resolvedCacheRoot = cacheRoot ?? Self.defaultCacheRoot()
        self.cacheRoot = resolvedCacheRoot
        self.allowedSaveRoots = allowedSaveRoots
            ?? Self.defaultAllowedSaveRoots(cacheRoot: resolvedCacheRoot)
        self.cookieJar = cookieJar
    }

    public func download(request: HostMediaDownloadRequest) async throws -> HostMediaDownloadResult {
        guard let url = URL(string: request.url),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host?.isEmpty == false,
              url.user == nil,
              url.password == nil else {
            throw MediaDownloadExecutorError.invalidParams(
                "invalid url: must be absolute HTTP(S) without embedded credentials: \(request.url)"
            )
        }
        guard request.method == "GET" || request.method == "HEAD" else {
            throw MediaDownloadExecutorError.invalidParams("method must be GET or HEAD")
        }
        if let sessionID = request.sessionId,
           sessionID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw MediaDownloadExecutorError.invalidParams("sessionId must be non-blank")
        }

        let resourceId = request.cacheKey ?? UUID().uuidString

        // Resolve and validate the destination before making a network request.
        // A Core/UI-provided `savePath` is data, not filesystem authority.
        let fileTarget = request.method == "GET"
            ? try targetFileURL(for: resourceId, savePath: request.savePath)
            : nil

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        // Media credentials come only from the explicitly scoped Host jar.
        // Never let URLSession's ambient/shared cookie store add a second,
        // unscoped cookie owner behind that boundary.
        urlRequest.httpShouldHandleCookies = false
        if let timeoutMillis = request.timeoutMillis {
            urlRequest.timeoutInterval = Double(timeoutMillis) / 1000.0
        }
        let sensitiveHeaders = Set(["authorization", "proxy-authorization", "cookie", "set-cookie", "x-api-key"])
        if let embedded = request.headers.keys.first(where: { sensitiveHeaders.contains($0.lowercased()) }) {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download header \(embedded) embeds credentials; use an opaque sessionId"
            )
        }
        for (k, v) in request.headers {
            urlRequest.setValue(v, forHTTPHeaderField: k)
        }
        let sessionScope: CookieJarScopeKey?
        if let sessionID = request.sessionId {
            guard let cookieJar else {
                throw MediaDownloadExecutorError.invalidParams(
                    "media.download sessionId requires a configured scoped cookie jar"
                )
            }
            let scope = HostCookieSessionScope.key(for: sessionID)
            sessionScope = scope
            let cookies = await cookieJar.getCookies(
                for: url.host ?? "",
                path: url.path.isEmpty ? "/" : url.path,
                scopeKey: scope
            ).filter { !($0.secure && scheme != "https") }
            if !cookies.isEmpty {
                urlRequest.setValue(
                    cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; "),
                    forHTTPHeaderField: "Cookie"
                )
            }
        } else {
            sessionScope = nil
        }
        if let start = request.rangeStart {
            if let end = request.rangeEnd {
                urlRequest.setValue("bytes=\(start)-\(end)", forHTTPHeaderField: "Range")
            } else {
                urlRequest.setValue("bytes=\(start)-", forHTTPHeaderField: "Range")
            }
        }
        if let etag = request.ifNoneMatch {
            urlRequest.setValue(etag, forHTTPHeaderField: "If-None-Match")
        }
        if let modifiedSince = request.ifModifiedSince {
            urlRequest.setValue(modifiedSince, forHTTPHeaderField: "If-Modified-Since")
        }

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await session.bytes(for: urlRequest)
        } catch {
            throw MediaDownloadExecutorError.networkError(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MediaDownloadExecutorError.networkError("non-HTTP response")
        }

        let statusCode = httpResponse.statusCode
        let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type")
        let contentLengthStr = httpResponse.value(forHTTPHeaderField: "Content-Length")
        let contentLength: UInt64? = contentLengthStr.flatMap { UInt64($0) }
        let etag = httpResponse.value(forHTTPHeaderField: "ETag")
        let finalUrl = httpResponse.url?.absoluteString
        if let sessionScope, let cookieJar {
            let responseURL = httpResponse.url ?? url
            for header in Self.setCookieValues(from: httpResponse) {
                await cookieJar.setCookies(
                    from: header,
                    domain: responseURL.host ?? url.host ?? "",
                    fallbackPath: responseURL.path.isEmpty ? "/" : responseURL.path,
                    scopeKey: sessionScope
                )
            }
        }
        // 304 short-circuit: no body, fromCache=true.
        if statusCode == 304 {
            return HostMediaDownloadResult(
                resourceId: resourceId,
                tempPath: nil,
                statusCode: 304,
                contentType: contentType,
                contentLength: contentLength,
                etag: etag,
                byteLength: 0,
                sha256: nil,
                fromCache: true,
                finalUrl: finalUrl
            )
        }

        // Reject a declared oversized payload before opening a staging file.
        // The streaming loop below enforces the same bound when the header is
        // absent or dishonest, so maxBytes is a memory/disk admission limit,
        // not a post-download observation.
        if let maxBytes = request.maxBytes,
           let contentLength,
           contentLength > maxBytes {
            throw MediaDownloadExecutorError.networkError(
                "declared Content-Length \(contentLength) exceeds maxBytes \(maxBytes)"
            )
        }

        let fileManager = FileManager.default
        var stagingURL: URL?
        var fileHandle: FileHandle?
        defer {
            try? fileHandle?.close()
            if let stagingURL { try? fileManager.removeItem(at: stagingURL) }
        }
        if request.method == "GET", let fileTarget {
            do {
                let directory = fileTarget.deletingLastPathComponent()
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                let staging = directory.appendingPathComponent(
                    ".reader-media-\(UUID().uuidString).partial",
                    isDirectory: false
                )
                guard fileManager.createFile(atPath: staging.path, contents: nil) else {
                    throw CocoaError(.fileWriteUnknown)
                }
                stagingURL = staging
                fileHandle = try FileHandle(forWritingTo: staging)
            } catch {
                throw MediaDownloadExecutorError.networkError(
                    "failed to create download staging file: \(error.localizedDescription)"
                )
            }
        }

        var digest = SHA256()
        var byteLength: UInt64 = 0
        var chunk: [UInt8] = []
        chunk.reserveCapacity(64 * 1_024)

        func flushChunk() throws {
            guard !chunk.isEmpty else { return }
            let data = Data(chunk)
            digest.update(data: data)
            if let fileHandle {
                try fileHandle.write(contentsOf: data)
            }
            chunk.removeAll(keepingCapacity: true)
        }

        do {
            for try await byte in bytes {
                if let maxBytes = request.maxBytes, byteLength >= maxBytes {
                    throw MediaDownloadExecutorError.networkError(
                        "downloaded stream exceeds maxBytes \(maxBytes)"
                    )
                }
                byteLength += 1
                chunk.append(byte)
                if chunk.count == chunk.capacity {
                    try flushChunk()
                }
            }
            try flushChunk()
            try fileHandle?.synchronize()
            try fileHandle?.close()
            fileHandle = nil
        } catch let error as MediaDownloadExecutorError {
            throw error
        } catch {
            throw MediaDownloadExecutorError.networkError(
                "download stream failed: \(error.localizedDescription)"
            )
        }

        let sha256: String? = byteLength > 0
            ? digest.finalize().map { String(format: "%02x", $0) }.joined()
            : nil

        // Publish only the complete staged file. A caller-provided savePath
        // was proven nonexistent before network dispatch; cache-key targets
        // may be atomically replaced inside the dedicated cache root.
        var tempPath: String? = nil
        if request.method == "GET", byteLength > 0,
           let fileURL = fileTarget,
           let staging = stagingURL {
            let targetExists = fileManager.fileExists(atPath: fileURL.path)
            if request.savePath != nil, targetExists {
                throw MediaDownloadExecutorError.invalidParams(
                    "savePath appeared during download; media.download cannot overwrite caller-owned files"
                )
            }
            do {
                if targetExists {
                    _ = try fileManager.replaceItemAt(fileURL, withItemAt: staging)
                } else {
                    try fileManager.moveItem(at: staging, to: fileURL)
                }
                stagingURL = nil
                tempPath = fileURL.path
            } catch {
                throw MediaDownloadExecutorError.networkError(
                    "failed to publish download file: \(error.localizedDescription)"
                )
            }
        }

        return HostMediaDownloadResult(
            resourceId: resourceId,
            tempPath: tempPath,
            statusCode: UInt16(statusCode),
            contentType: contentType,
            contentLength: contentLength,
            etag: etag,
            byteLength: byteLength,
            sha256: sha256,
            fromCache: false,
            finalUrl: finalUrl
        )
    }

    private func targetFileURL(for fileId: String, savePath: String?) throws -> URL {
        if let savePath = savePath, !savePath.isEmpty {
            guard (savePath as NSString).isAbsolutePath else {
                throw MediaDownloadExecutorError.invalidParams(
                    "savePath must be an absolute app-sandbox path"
                )
            }
            let candidate = URL(fileURLWithPath: savePath).standardizedFileURL
                .resolvingSymlinksInPath()
            guard allowedSaveRoots.contains(where: { Self.contains(candidate, in: $0) }) else {
                throw MediaDownloadExecutorError.invalidParams(
                    "savePath is outside the app sandbox roots"
                )
            }
            guard !FileManager.default.fileExists(atPath: candidate.path) else {
                throw MediaDownloadExecutorError.invalidParams(
                    "savePath already exists; media.download cannot overwrite caller-owned files"
                )
            }
            return candidate
        }
        let safeFileId = SHA256.hash(data: Data(fileId.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
        return cacheRoot.appendingPathComponent("\(safeFileId).bin")
    }

    private static func contains(_ candidate: URL, in root: URL) -> Bool {
        let rootURL = root.standardizedFileURL.resolvingSymlinksInPath()
        let candidatePath = candidate.path
        let rootPath = rootURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    private static func setCookieValues(from response: HTTPURLResponse) -> [String] {
        var values: [String] = []
        if let direct = response.value(forHTTPHeaderField: "Set-Cookie") {
            values.append(direct)
        }
        for (key, value) in response.allHeaderFields {
            guard let key = key as? String,
                  let value = value as? String,
                  key.lowercased() == "set-cookie",
                  !values.contains(value) else { continue }
            values.append(value)
        }
        return values
    }

    private static func defaultAllowedSaveRoots(cacheRoot: URL) -> [URL] {
        let fm = FileManager.default
        let transientRoot = fm.temporaryDirectory
            .appendingPathComponent("ReaderApp/MediaDownloads", isDirectory: true)
        try? fm.createDirectory(at: transientRoot, withIntermediateDirectories: true)
        return [cacheRoot, transientRoot]
    }

    private static func defaultCacheRoot() -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = cacheDir.appendingPathComponent("ReaderApp/MediaDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
