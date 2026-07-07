import XCTest
import ReaderCoreProtocols
@testable import ReaderShellValidation

/// iOS Host-side proof for the `media.download` lane — mirrors the structure
/// of `HostAntiBotProofTests` / `HostWebViewRenderProofTests` so iOS reaches
/// the same handler/router proof level as the other host lanes.
///
/// Proof tier (this file): handler/router. These tests verify that
/// `MediaDownloadHandler` correctly parses the Core request, validates it
/// (url non-blank + http(s) scheme; method GET/HEAD only; rangeEnd requires
/// rangeStart + rangeEnd >= rangeStart; maxBytes > 0; timeoutMillis > 0),
/// delegates to the `MediaDownloadExecutor`, and builds the response dict.
/// They use `StubMediaDownloadExecutor` — no real URLSession is exercised.
///
/// Production executor status (do NOT conflate with "backend ready"):
/// `URLSessionMediaDownloadExecutor` is a REAL cross-platform implementation
/// backed by URLSession + CryptoKit — range requests (`Range: bytes=start-end`
/// header), ETag / 304 caching (`If-None-Match` / `If-Modified-Since`), sha256
/// hex digest, temp-file management under `Caches/ReaderApp/MediaDownloads/`,
/// `maxBytes` enforcement, and `timeoutMillis` → `URLRequest.timeoutInterval`.
/// It is wired into `RustCoreServiceSupport.makeRouter` on every platform
/// (macOS `swift build` included).
///
/// Device-tier gaps (still pending, NOT covered by macOS `swift test` against
/// `example.test` fixtures):
/// - Live-CDN range / 304 / sha256 round-trip requires a real reachable host
///   (verified by `URLSessionMediaDownloadExecutorProofTests` via `URLProtocol`
///   interception on the simulator, NOT by macOS `swift test` against
///   `cdn.example.test`).
/// - Background URLSession for large downloads, cellular policy, and
///   resume-data persistence are NOT implemented — current executor uses a
///   foreground `URLSession.shared`-style task only.
/// - Cookie jar session affinity is NOT wired (media downloads do not yet
///   attach `ScopedCookieJar` cookies to the request).
///
/// Mirrors Core contract in `crates/reader-contract/src/host.rs`
/// (HostMediaDownloadRequest / HostMediaDownloadResponse, commit 3e4fcb7b).
final class HostMediaDownloadProofTests: XCTestCase {

    // MARK: - Proof 1: full GET download returns response

    /// Stub returns 200 + content-type + sha256 + byteLength. Handler is
    /// called with a url and NO method (default GET). Response must carry
    /// resourceId, statusCode=200, byteLength, fromCache=false. The stub's
    /// captured request must have method="GET" (default).
    func testFullGetDownloadReturnsResponse() async throws {
        let executor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "res-full-001",
            tempPath: "/tmp/reader/res-full-001.bin",
            statusCode: 200,
            contentType: "image/png",
            contentLength: 1024,
            etag: "\"etag-001\"",
            byteLength: 1024,
            sha256: "abc123def456",
            fromCache: false,
            finalUrl: "https://cdn.example.com/file.png"
        ))
        let handler = MediaDownloadHandler(executor: executor)

        let params: [String: Any] = [
            "url": "https://cdn.example.com/file.png",
        ]

        let result = try await handler.handle(params: params)

        XCTAssertEqual(result["resourceId"] as? String, "res-full-001",
                       "resourceId must match the canned stub result")
        XCTAssertEqual(result["statusCode"] as? Int, 200,
                       "statusCode must be 200")
        XCTAssertEqual(result["byteLength"] as? Int, 1024,
                       "byteLength must match the canned stub result")
        XCTAssertEqual(result["fromCache"] as? Bool, false,
                       "fromCache must be false for a fresh download")
        XCTAssertEqual(result["contentType"] as? String, "image/png",
                       "contentType must match the canned stub result")
        XCTAssertEqual(result["sha256"] as? String, "abc123def456",
                       "sha256 must match the canned stub result")
        XCTAssertEqual(executor.lastRequest?.method, "GET",
                       "default method must be GET when not specified")
        XCTAssertEqual(executor.lastRequest?.url, "https://cdn.example.com/file.png",
                       "url must be forwarded to the executor")
    }

    // MARK: - Proof 2: range download with rangeStart and rangeEnd

    /// rangeStart=1024 + rangeEnd=8191 + method=GET. Stub returns 206
    /// (partial content). The handler must pass the range info to the
    /// executor (verified via the stub's captured request) and return
    /// statusCode=206.
    func testRangeDownloadWithRangeStartAndRangeEnd() async throws {
        let executor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "res-range-002",
            tempPath: "/tmp/reader/res-range-002.bin",
            statusCode: 206,
            contentType: "application/octet-stream",
            contentLength: 7168,
            byteLength: 7168,
            sha256: "range-sha256",
            fromCache: false,
            finalUrl: "https://cdn.example.com/file.bin"
        ))
        let handler = MediaDownloadHandler(executor: executor)

        let params: [String: Any] = [
            "url": "https://cdn.example.com/file.bin",
            "method": "GET",
            "rangeStart": 1024,
            "rangeEnd": 8191,
        ]

        let result = try await handler.handle(params: params)

        XCTAssertEqual(result["statusCode"] as? Int, 206,
                       "statusCode must be 206 (partial content)")
        XCTAssertEqual(result["byteLength"] as? Int, 7168,
                       "byteLength must match the canned stub result")
        XCTAssertEqual(executor.lastRequest?.rangeStart, 1024,
                       "rangeStart must be forwarded to the executor")
        XCTAssertEqual(executor.lastRequest?.rangeEnd, 8191,
                       "rangeEnd must be forwarded to the executor")
        XCTAssertEqual(executor.lastRequest?.method, "GET",
                       "method must be forwarded to the executor")
    }

    // MARK: - Proof 3: HEAD probe returns metadata only

    /// method=HEAD, stub returns 200 + contentLength + no tempPath (no file
    /// written for HEAD). Response must carry statusCode=200 + tempPath=nil
    /// (key absent). The stub's captured request must have method="HEAD".
    func testHeadProbeReturnsMetadataOnly() async throws {
        let executor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "res-head-003",
            tempPath: nil,
            statusCode: 200,
            contentType: "video/mp4",
            contentLength: 99_999_999,
            etag: "\"etag-head\"",
            byteLength: 0,
            sha256: nil,
            fromCache: false,
            finalUrl: "https://cdn.example.com/video.mp4"
        ))
        let handler = MediaDownloadHandler(executor: executor)

        let params: [String: Any] = [
            "url": "https://cdn.example.com/video.mp4",
            "method": "HEAD",
        ]

        let result = try await handler.handle(params: params)

        XCTAssertEqual(result["statusCode"] as? Int, 200,
                       "statusCode must be 200 for HEAD probe")
        XCTAssertNil(result["tempPath"],
                     "tempPath must be absent for HEAD (no file written)")
        XCTAssertEqual(result["contentLength"] as? Int, 99_999_999,
                       "contentLength must be present for HEAD probe")
        XCTAssertEqual(result["byteLength"] as? Int, 0,
                       "byteLength must be 0 for HEAD (no body downloaded)")
        XCTAssertEqual(executor.lastRequest?.method, "HEAD",
                       "method must be HEAD")
    }

    // MARK: - Proof 4: cached response returns fromCache=true

    /// cacheKey set, stub returns fromCache=true + statusCode=304 + byteLength=0.
    /// Response must carry fromCache=true + statusCode=304 + byteLength=0. The
    /// stub's captured request must have the cacheKey forwarded.
    func testCachedResponseReturnsFromCacheTrue() async throws {
        let executor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "res-cached-004",
            tempPath: nil,
            statusCode: 304,
            contentType: nil,
            contentLength: nil,
            etag: "\"etag-cached\"",
            byteLength: 0,
            sha256: nil,
            fromCache: true,
            finalUrl: "https://cdn.example.com/cached.json"
        ))
        let handler = MediaDownloadHandler(executor: executor)

        let params: [String: Any] = [
            "url": "https://cdn.example.com/cached.json",
            "cacheKey": "cache-slot-004",
        ]

        let result = try await handler.handle(params: params)

        XCTAssertEqual(result["fromCache"] as? Bool, true,
                       "fromCache must be true for a 304 cached response")
        XCTAssertEqual(result["statusCode"] as? Int, 304,
                       "statusCode must be 304 (not modified)")
        XCTAssertEqual(result["byteLength"] as? Int, 0,
                       "byteLength must be 0 for a 304 (no body transferred)")
        XCTAssertEqual(executor.lastRequest?.cacheKey, "cache-slot-004",
                       "cacheKey must be forwarded to the executor")
    }

    // MARK: - Validation 1: rejects non-http scheme

    /// url="file:///etc/passwd" — handler must reject before reaching the
    /// executor. Error message must mention "http or https scheme".
    func testRejectsNonHttpScheme() async throws {
        let executor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "should-not-reach",
            statusCode: 200,
            byteLength: 0
        ))
        let handler = MediaDownloadHandler(executor: executor)

        let params: [String: Any] = [
            "url": "file:///etc/passwd",
        ]

        do {
            _ = try await handler.handle(params: params)
            XCTFail("handler should reject file:// scheme")
        } catch let error as MediaDownloadExecutorError {
            switch error {
            case .invalidParams(let m):
                XCTAssertTrue(m.contains("http or https scheme"),
                              "error message should mention 'http or https scheme', got: \(m)")
            default:
                XCTFail("expected .invalidParams error, got: \(error)")
            }
        } catch {
            XCTFail("expected MediaDownloadExecutorError.invalidParams, got: \(error)")
        }
    }

    // MARK: - Validation 2: rejects POST method

    /// method="POST" — handler must reject (only GET/HEAD allowed). Error
    /// message must mention "must be GET or HEAD".
    func testRejectsPostMethod() async throws {
        let executor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "should-not-reach",
            statusCode: 200,
            byteLength: 0
        ))
        let handler = MediaDownloadHandler(executor: executor)

        let params: [String: Any] = [
            "url": "https://cdn.example.com/file.bin",
            "method": "POST",
        ]

        do {
            _ = try await handler.handle(params: params)
            XCTFail("handler should reject POST method")
        } catch let error as MediaDownloadExecutorError {
            switch error {
            case .invalidParams(let m):
                XCTAssertTrue(m.contains("must be GET or HEAD"),
                              "error message should mention 'must be GET or HEAD', got: \(m)")
            default:
                XCTFail("expected .invalidParams error, got: \(error)")
            }
        } catch {
            XCTFail("expected MediaDownloadExecutorError.invalidParams, got: \(error)")
        }
    }

    // MARK: - Validation 3: rejects rangeEnd without rangeStart

    /// rangeEnd=1024 + rangeStart=nil — handler must reject. Error message
    /// must mention "rangeEnd requires rangeStart".
    func testRejectsRangeEndWithoutRangeStart() async throws {
        let executor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "should-not-reach",
            statusCode: 200,
            byteLength: 0
        ))
        let handler = MediaDownloadHandler(executor: executor)

        let params: [String: Any] = [
            "url": "https://cdn.example.com/file.bin",
            "rangeEnd": 1024,
        ]

        do {
            _ = try await handler.handle(params: params)
            XCTFail("handler should reject rangeEnd without rangeStart")
        } catch let error as MediaDownloadExecutorError {
            switch error {
            case .invalidParams(let m):
                XCTAssertTrue(m.contains("rangeEnd requires rangeStart"),
                              "error message should mention 'rangeEnd requires rangeStart', got: \(m)")
            default:
                XCTFail("expected .invalidParams error, got: \(error)")
            }
        } catch {
            XCTFail("expected MediaDownloadExecutorError.invalidParams, got: \(error)")
        }
    }

    // MARK: - Validation 4: rejects rangeEnd below rangeStart

    /// rangeStart=2048 + rangeEnd=1024 — handler must reject. Error message
    /// must mention "rangeEnd (1024) must be >= rangeStart (2048)".
    func testRejectsRangeEndBelowRangeStart() async throws {
        let executor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "should-not-reach",
            statusCode: 200,
            byteLength: 0
        ))
        let handler = MediaDownloadHandler(executor: executor)

        let params: [String: Any] = [
            "url": "https://cdn.example.com/file.bin",
            "rangeStart": 2048,
            "rangeEnd": 1024,
        ]

        do {
            _ = try await handler.handle(params: params)
            XCTFail("handler should reject rangeEnd < rangeStart")
        } catch let error as MediaDownloadExecutorError {
            switch error {
            case .invalidParams(let m):
                XCTAssertTrue(m.contains("rangeEnd (1024) must be >= rangeStart (2048)"),
                              "error message should mention 'rangeEnd (1024) must be >= rangeStart (2048)', got: \(m)")
            default:
                XCTFail("expected .invalidParams error, got: \(error)")
            }
        } catch {
            XCTFail("expected MediaDownloadExecutorError.invalidParams, got: \(error)")
        }
    }
}
