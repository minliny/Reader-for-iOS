// CoreBridge
//
// URLSessionMediaDownloadExecutor: production `MediaDownloadExecutor` backed
// by `URLSession` + `CryptoKit`.
//
// Implements the full `media.download` host lane contract (mirrors Core's
// `HostMediaDownloadRequest` / `HostMediaDownloadResponse`):
// - Range requests via the `Range: bytes=start-end` header.
// - Redirect: `URLSession` follows redirects by default; the final URL is
//   captured from `HTTPURLResponse.url`.
// - ETag/304: sends `If-None-Match` / `If-Modified-Since` and short-circuits
//   on 304 (`fromCache = true`, `byteLength = 0`, no body written).
// - sha256: `CryptoKit.SHA256` over the downloaded bytes (hex lowercase).
// - Temp file: writes to `savePath` when provided, otherwise to a per-cacheKey
//   file under `Caches/ReaderApp/MediaDownloads/`.
// - maxBytes: aborts when the downloaded byte count exceeds the cap.
// - timeoutMillis: applied via `URLRequest.timeoutInterval`.
//
// Proof tier: simulator-proof. `URLSession` works on simulator and macOS
// `swift build`. Real-device proof (large-file streaming, background URLSession,
// cellular policy) is tracked in `HostAdapterRealDeviceProofManifestTests`.
//
// Clean-room: no Legado/Android code reused; implementation follows the Core
// contract in `crates/reader-contract/src/host.rs` only.

import Foundation
import CryptoKit

/// Production `MediaDownloadExecutor` backed by `URLSession` + `CryptoKit`.
public final class URLSessionMediaDownloadExecutor: MediaDownloadExecutor, @unchecked Sendable {
    private let session: URLSession
    private let cacheRoot: URL

    /// Initialize with an optional custom `URLSession` (e.g. for URLProtocol
    /// interception in tests) and cache root (defaults to
    /// `Caches/ReaderApp/MediaDownloads/`).
    public init(session: URLSession? = nil, cacheRoot: URL? = nil) {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 60
        config.timeoutIntervalForResource = 120
        self.session = session ?? URLSession(configuration: config)
        self.cacheRoot = cacheRoot ?? Self.defaultCacheRoot()
    }

    public func download(request: HostMediaDownloadRequest) async throws -> HostMediaDownloadResult {
        guard let url = URL(string: request.url) else {
            throw MediaDownloadExecutorError.invalidParams("invalid url: \(request.url)")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        if let timeoutMillis = request.timeoutMillis {
            urlRequest.timeoutInterval = Double(timeoutMillis) / 1000.0
        }
        for (k, v) in request.headers {
            urlRequest.setValue(v, forHTTPHeaderField: k)
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

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: urlRequest)
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
        let resourceId = request.cacheKey ?? UUID().uuidString

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

        // maxBytes enforcement.
        if let maxBytes = request.maxBytes, UInt64(data.count) > maxBytes {
            throw MediaDownloadExecutorError.networkError(
                "downloaded \(data.count) bytes exceeds maxBytes \(maxBytes)"
            )
        }

        // sha256 over the downloaded bytes.
        let sha256 = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        // Write file (GET only; HEAD skips body).
        var tempPath: String? = nil
        if request.method == "GET" && !data.isEmpty {
            let fileURL = targetFileURL(for: resourceId, savePath: request.savePath)
            do {
                try data.write(to: fileURL, options: .atomic)
                tempPath = fileURL.path
            } catch {
                throw MediaDownloadExecutorError.networkError(
                    "failed to write temp file: \(error.localizedDescription)"
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
            byteLength: UInt64(data.count),
            sha256: sha256,
            fromCache: false,
            finalUrl: finalUrl
        )
    }

    private func targetFileURL(for fileId: String, savePath: String?) -> URL {
        if let savePath = savePath, !savePath.isEmpty {
            return URL(fileURLWithPath: savePath)
        }
        return cacheRoot.appendingPathComponent("\(fileId).bin")
    }

    private static func defaultCacheRoot() -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let root = cacheDir.appendingPathComponent("ReaderApp/MediaDownloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
