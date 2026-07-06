// CoreBridge
//
// MediaDownloadHandler: host-side capability handler for `media.download`.
//
// Mirrors the Rust Core contract in `crates/reader-contract/src/host.rs`
// (HostMediaDownloadRequest / HostMediaDownloadResponse, commit 3e4fcb7b):
// - Input params: `{url, method?, headers?, rangeStart?, rangeEnd?,
//   ifNoneMatch?, ifModifiedSince?, cacheKey?, savePath?, maxBytes?,
//   sessionId?, timeoutMillis?}`.
// - Result: `{resourceId, tempPath?, statusCode, contentType?, contentLength?,
//   etag?, byteLength, sha256?, fromCache, finalUrl?}`.
//
// Proof tier (this file): handler/router. The handler parses the Core request,
// validates it (url non-blank + http(s) scheme; method GET/HEAD only; rangeEnd
// requires rangeStart + rangeEnd >= rangeStart; maxBytes > 0; timeoutMillis > 0),
// delegates execution to a `MediaDownloadExecutor`, and builds the response
// dict. Proof tests use `StubMediaDownloadExecutor` — no real URLSession is
// exercised.
//
// Device-headless/App tier (pending): real URLSession download (range requests
// via `Range` header, ETag/304 handling via `If-None-Match` /
// `If-Modified-Since`, sha256 hashing of the body, save-path management,
// cookie jar session affinity, maxBytes/timeout enforcement) requires
// device-tier proof (simulator / real device with live network). The
// production `URLSessionMediaDownloadExecutor` is a `fatalError` stub until
// that tier lands.
//
// Mirrors `AntiBotChallengeHandler` (synchronous `throws`) and
// `WebViewEvaluateJavaScriptHandler` (Sendable handler + Stub + production
// stub) so iOS reaches the same handler/router proof level as the other host
// lanes.

import Foundation

// MARK: - MediaDownloadExecutorError

/// Errors thrown by the media.download lane executor / handler.
public enum MediaDownloadExecutorError: Error, Equatable, LocalizedError {
    case invalidParams(String)
    case networkError(String)
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .invalidParams(let m): return "MediaDownload invalid params: \(m)"
        case .networkError(let m): return "MediaDownload network error: \(m)"
        case .notImplemented(let m): return "MediaDownload executor not implemented: \(m)"
        }
    }
}

// MARK: - HostMediaDownloadRequest

/// Request handed to a `MediaDownloadExecutor` (mirrors Core's
/// `HostMediaDownloadRequest` after parsing/validation). All fields are
/// pre-validated: `url` is non-blank with an http(s) scheme, `method` is
/// "GET" or "HEAD", and (when present) `rangeEnd >= rangeStart`.
public struct HostMediaDownloadRequest: Sendable, Equatable {
    public let url: String
    public let method: String  // "GET" or "HEAD"
    public let headers: [String: String]
    public let rangeStart: UInt64?
    public let rangeEnd: UInt64?
    public let ifNoneMatch: String?
    public let ifModifiedSince: String?
    public let cacheKey: String?
    public let savePath: String?
    public let maxBytes: UInt64?
    public let sessionId: String?
    public let timeoutMillis: UInt64?

    public init(
        url: String,
        method: String = "GET",
        headers: [String: String] = [:],
        rangeStart: UInt64? = nil,
        rangeEnd: UInt64? = nil,
        ifNoneMatch: String? = nil,
        ifModifiedSince: String? = nil,
        cacheKey: String? = nil,
        savePath: String? = nil,
        maxBytes: UInt64? = nil,
        sessionId: String? = nil,
        timeoutMillis: UInt64? = nil
    ) {
        self.url = url
        self.method = method
        self.headers = headers
        self.rangeStart = rangeStart
        self.rangeEnd = rangeEnd
        self.ifNoneMatch = ifNoneMatch
        self.ifModifiedSince = ifModifiedSince
        self.cacheKey = cacheKey
        self.savePath = savePath
        self.maxBytes = maxBytes
        self.sessionId = sessionId
        self.timeoutMillis = timeoutMillis
    }
}

// MARK: - HostMediaDownloadResult

/// Result produced by a `MediaDownloadExecutor` (mirrors Core's
/// `HostMediaDownloadResponse`). `byteLength` is the actual bytes written
/// (0 for HEAD / 304), `fromCache` indicates a 304 short-circuit, and
/// `tempPath` is nil when no file was written (HEAD probe).
public struct HostMediaDownloadResult: Sendable, Equatable {
    public let resourceId: String
    public let tempPath: String?
    public let statusCode: UInt16
    public let contentType: String?
    public let contentLength: UInt64?
    public let etag: String?
    public let byteLength: UInt64
    public let sha256: String?
    public let fromCache: Bool
    public let finalUrl: String?

    public init(
        resourceId: String,
        tempPath: String? = nil,
        statusCode: UInt16,
        contentType: String? = nil,
        contentLength: UInt64? = nil,
        etag: String? = nil,
        byteLength: UInt64,
        sha256: String? = nil,
        fromCache: Bool = false,
        finalUrl: String? = nil
    ) {
        self.resourceId = resourceId
        self.tempPath = tempPath
        self.statusCode = statusCode
        self.contentType = contentType
        self.contentLength = contentLength
        self.etag = etag
        self.byteLength = byteLength
        self.sha256 = sha256
        self.fromCache = fromCache
        self.finalUrl = finalUrl
    }
}

// MARK: - MediaDownloadExecutor

/// Executor abstraction for the `media.download` host capability. Core produces
/// the request descriptor (url, method, headers, range, cache validators); the
/// Host executes the HTTP fetch (GET/HEAD, optional range, ETag/304 caching,
/// sha256 hashing) and returns the result. Core never opens a socket directly
/// (Core/Host boundary, red line 4).
///
/// Synchronous (`throws` rather than `async throws`) because the alpha proof
/// uses a stub executor with canned responses. The production executor will be
/// `async throws` once device-tier proof lands (real URLSession + sha256
/// hashing + save-path management).
public protocol MediaDownloadExecutor: Sendable {
    func download(request: HostMediaDownloadRequest) throws -> HostMediaDownloadResult
}

// MARK: - MediaDownloadHandler

/// `media.download` capability handler: parses the Core request, validates it,
/// delegates to a `MediaDownloadExecutor`, and builds the response dict.
///
/// JSON contract (camelCase, aligned with Core's `HostMediaDownloadRequest` /
/// `HostMediaDownloadResponse`):
/// - Request params: `{url, method?, headers?, rangeStart?, rangeEnd?,
///   ifNoneMatch?, ifModifiedSince?, cacheKey?, savePath?, maxBytes?,
///   sessionId?, timeoutMillis?}`.
/// - Result: `{resourceId, tempPath?, statusCode, contentType?, contentLength?,
///   etag?, byteLength, sha256?, fromCache, finalUrl?}`.
public struct MediaDownloadHandler: Sendable {
    public static let capability = "media.download"

    private let executor: MediaDownloadExecutor

    public init(executor: MediaDownloadExecutor) {
        self.executor = executor
    }

    /// Handle a `media.download` request.
    /// - Parameter params: the `HostMediaDownloadRequest` JSON dict.
    /// - Returns: the `HostMediaDownloadResponse` JSON dict on success.
    public func handle(params: [String: Any]) throws -> [String: Any] {
        let url = try parseUrl(params)
        let method = try parseMethod(params)
        let headers = parseHeaders(params)
        let rangeStart = try parseRangeStart(params)
        let rangeEnd = try parseRangeEnd(params, rangeStart: rangeStart)
        let ifNoneMatch = try parseIfNoneMatch(params)
        let ifModifiedSince = try parseIfModifiedSince(params)
        let cacheKey = parseOptionalString(params, key: "cacheKey")
        let savePath = parseOptionalString(params, key: "savePath")
        let maxBytes = try parseMaxBytes(params)
        let sessionId = parseOptionalString(params, key: "sessionId")
        let timeoutMillis = try parseTimeoutMillis(params)

        let request = HostMediaDownloadRequest(
            url: url,
            method: method,
            headers: headers,
            rangeStart: rangeStart,
            rangeEnd: rangeEnd,
            ifNoneMatch: ifNoneMatch,
            ifModifiedSince: ifModifiedSince,
            cacheKey: cacheKey,
            savePath: savePath,
            maxBytes: maxBytes,
            sessionId: sessionId,
            timeoutMillis: timeoutMillis
        )

        let result = try executor.download(request: request)
        return Self.buildResultDict(result)
    }

    /// Build the `host.complete` result dict from an executor result. Exposed
    /// as internal so proof tests can verify the payload contract. Optional
    /// fields are omitted when nil / blank so the dict matches the Core
    /// `HostMediaDownloadResponse` serialization (skip-when-empty).
    internal static func buildResultDict(_ result: HostMediaDownloadResult) -> [String: Any] {
        var dict: [String: Any] = [
            "resourceId": result.resourceId,
            "statusCode": Int(result.statusCode),
            "byteLength": Int(result.byteLength),
            "fromCache": result.fromCache,
        ]
        if let tempPath = result.tempPath, !tempPath.isEmpty {
            dict["tempPath"] = tempPath
        }
        if let contentType = result.contentType, !contentType.isEmpty {
            dict["contentType"] = contentType
        }
        if let contentLength = result.contentLength {
            dict["contentLength"] = Int(contentLength)
        }
        if let etag = result.etag, !etag.isEmpty {
            dict["etag"] = etag
        }
        if let sha256 = result.sha256, !sha256.isEmpty {
            dict["sha256"] = sha256
        }
        if let finalUrl = result.finalUrl, !finalUrl.isEmpty {
            dict["finalUrl"] = finalUrl
        }
        return dict
    }

    // MARK: - Parsing / validation (mirrors Core's validate())

    private func parseUrl(_ params: [String: Any]) throws -> String {
        guard let raw = params["url"] as? String, !raw.isEmpty else {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download requires non-blank url"
            )
        }
        guard let parsed = URL(string: raw),
              let scheme = parsed.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download url must use http or https scheme"
            )
        }
        return raw
    }

    private func parseMethod(_ params: [String: Any]) throws -> String {
        guard let raw = params["method"] as? String else { return "GET" }
        let upper = raw.uppercased()
        guard upper == "GET" || upper == "HEAD" else {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download method must be GET or HEAD (got: \(raw))"
            )
        }
        return upper
    }

    private func parseHeaders(_ params: [String: Any]) -> [String: String] {
        guard let raw = params["headers"] as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (k, v) in raw {
            if let s = v as? String {
                result[k] = s
            } else {
                result[k] = String(describing: v)
            }
        }
        return result
    }

    private func parseRangeStart(_ params: [String: Any]) throws -> UInt64? {
        guard let raw = params["rangeStart"] else { return nil }
        return try parseUInt64(raw, key: "rangeStart")
    }

    private func parseRangeEnd(_ params: [String: Any], rangeStart: UInt64?) throws -> UInt64? {
        guard let raw = params["rangeEnd"] else { return nil }
        let value = try parseUInt64(raw, key: "rangeEnd")
        guard let start = rangeStart else {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download rangeEnd requires rangeStart"
            )
        }
        guard value >= start else {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download rangeEnd (\(value)) must be >= rangeStart (\(start))"
            )
        }
        return value
    }

    private func parseIfNoneMatch(_ params: [String: Any]) throws -> String? {
        guard let raw = params["ifNoneMatch"] as? String else { return nil }
        guard !raw.isEmpty else {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download ifNoneMatch must be non-blank"
            )
        }
        return raw
    }

    private func parseIfModifiedSince(_ params: [String: Any]) throws -> String? {
        guard let raw = params["ifModifiedSince"] as? String else { return nil }
        guard !raw.isEmpty else {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download ifModifiedSince must be non-blank"
            )
        }
        return raw
    }

    private func parseOptionalString(_ params: [String: Any], key: String) -> String? {
        guard let raw = params[key] as? String else { return nil }
        return raw.isEmpty ? nil : raw
    }

    private func parseMaxBytes(_ params: [String: Any]) throws -> UInt64? {
        guard let raw = params["maxBytes"] else { return nil }
        let value = try parseUInt64(raw, key: "maxBytes")
        guard value > 0 else {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download maxBytes must be greater than 0"
            )
        }
        return value
    }

    private func parseTimeoutMillis(_ params: [String: Any]) throws -> UInt64? {
        guard let raw = params["timeoutMillis"] else { return nil }
        let value = try parseUInt64(raw, key: "timeoutMillis")
        guard value > 0 else {
            throw MediaDownloadExecutorError.invalidParams(
                "media.download timeoutMillis must be greater than 0"
            )
        }
        return value
    }

    /// Parse a `UInt64` from an `Any` (NSNumber / Int / UInt64). Rejects
    /// negative values. Mirrors `WebViewEvaluateJavaScriptHandler`'s
    /// `parseTimeoutMillis` numeric handling.
    private func parseUInt64(_ raw: Any, key: String) throws -> UInt64 {
        if let n = raw as? NSNumber {
            if n.int64Value < 0 {
                throw MediaDownloadExecutorError.invalidParams(
                    "media.download \(key) must be a non-negative integer"
                )
            }
            return n.uint64Value
        }
        if let n = raw as? Int {
            guard n >= 0 else {
                throw MediaDownloadExecutorError.invalidParams(
                    "media.download \(key) must be a non-negative integer"
                )
            }
            return UInt64(n)
        }
        if let n = raw as? UInt64 {
            return n
        }
        throw MediaDownloadExecutorError.invalidParams(
            "media.download \(key) must be a non-negative integer"
        )
    }
}

// MARK: - StubMediaDownloadExecutor (test proof tier)

/// Stub `MediaDownloadExecutor` for handler/router proof tests. Returns a
/// canned result or throws a canned error — no real network is exercised. The
/// stub also captures the last received request so proof tests can verify
/// that the handler parsed + forwarded the request fields correctly (e.g.
/// range start/end, cacheKey, method). Mirrors the role of
/// `StubAntiBotExecutor` / `StubWebViewExecutor` for the other host lanes.
public final class StubMediaDownloadExecutor: MediaDownloadExecutor, @unchecked Sendable {
    private let cannedResult: HostMediaDownloadResult?
    private let cannedError: MediaDownloadExecutorError?

    /// Lock-protected captured request (last received). Read via `lastRequest`.
    private let lock = NSLock()
    private var _lastRequest: HostMediaDownloadRequest?

    /// The last request handed to `download`, or nil if never called. Useful
    /// for proof tests that verify the handler forwarded parsed fields.
    public var lastRequest: HostMediaDownloadRequest? {
        lock.lock()
        defer { lock.unlock() }
        return _lastRequest
    }

    /// Initialize with a canned result to return on every `download` call.
    public init(result: HostMediaDownloadResult) {
        self.cannedResult = result
        self.cannedError = nil
    }

    /// Initialize with a canned error to throw on every `download` call.
    public init(error: MediaDownloadExecutorError) {
        self.cannedResult = nil
        self.cannedError = error
    }

    public func download(request: HostMediaDownloadRequest) throws -> HostMediaDownloadResult {
        lock.lock()
        _lastRequest = request
        lock.unlock()

        if let error = cannedError {
            throw error
        }
        return cannedResult ?? HostMediaDownloadResult(
            resourceId: "stub-default",
            statusCode: 200,
            byteLength: 0
        )
    }
}

// MARK: - URLSessionMediaDownloadExecutor (production, device-tier proof pending)

/// Production URLSession executor for `media.download`.
///
/// NOT YET IMPLEMENTED — this is a `fatalError` stub. Real URLSession download
/// (range requests via the `Range` header, ETag/304 handling via
/// `If-None-Match` / `If-Modified-Since`, sha256 hashing of the body,
/// save-path management, cookie jar session affinity via `sessionId`,
/// `maxBytes` enforcement, `timeoutMillis` enforcement) requires device-tier
/// proof (simulator / real device with live network).
///
/// The handler/router proof in `HostMediaDownloadProofTests` uses
/// `StubMediaDownloadExecutor` and does NOT depend on this class. This stub
/// exists so the router can be wired with a real executor once device-tier
/// proof lands, without changing the handler contract.
public final class URLSessionMediaDownloadExecutor: MediaDownloadExecutor, @unchecked Sendable {
    public init() {
        fatalError("URLSessionMediaDownloadExecutor not implemented — device-headless beta")
    }

    public func download(request: HostMediaDownloadRequest) throws -> HostMediaDownloadResult {
        // Unreachable — init aborts before any instance can be constructed.
        fatalError("URLSessionMediaDownloadExecutor not implemented — device-headless beta")
    }
}
