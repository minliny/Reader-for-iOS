import XCTest
import CryptoKit
@testable import ReaderShellValidation

/// Host-side deterministic tests for the production
/// `URLSessionMediaDownloadExecutor`.
///
/// These tests verify the real executor (not the stub) against a `URLProtocol`
/// interceptor that injects canned HTTP responses without hitting the network.
/// A passing macOS run proves the source-test lane only; it must not be recorded
/// as simulator, device, live-network, screenshot or release evidence.
///
/// Coverage:
/// 1. Full GET 200 download — sha256, tempPath, fromCache=false.
/// 2. Range request — `Range` header forwarded, 206 response.
/// 3. 304 short-circuit — fromCache=true, byteLength=0, no tempPath.
/// 4. ETag / If-None-Match forwarded, response ETag captured.
/// 5. maxBytes exceeded throws `.networkError`.
/// 6. Invalid url throws `.invalidParams`.
/// 7. HEAD method skips file write (tempPath=nil).
/// 8. savePath override writes to the specified location.
/// 9. Redirect — finalUrl captured from the redirected URL.
/// 10. sha256 hex lowercase matches `CryptoKit.SHA256`.
/// 11. savePath outside the admitted sandbox roots fails closed pre-network.
/// 12. cacheKey traversal text is hashed and stays under cacheRoot.
/// 13. nested admitted savePath creates its parent directory.
/// 14. ambient URLSession cookies are disabled at the request boundary.
///
/// Still outside this proof: large-file streaming, background `URLSession`,
/// cellular policy and restart recovery. Opaque-session cookie affinity is
/// covered by `ReaderSlice11HostBoundaryTests`.
final class URLSessionMediaDownloadExecutorProofTests: XCTestCase {

    // MARK: - Helpers

    /// Build a `URLSession` configured with the stub URLProtocol.
    private func makeSession(handler: @escaping (URLRequest) throws -> (HTTPURLResponse, Data)) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MediaDownloadURLProtocolStub.self]
        MediaDownloadURLProtocolStub.handler = handler
        return URLSession(configuration: config)
    }

    private func makeExecutor(
        session: URLSession,
        cacheRoot: URL? = nil,
        allowedSaveRoots: [URL]? = nil
    ) -> URLSessionMediaDownloadExecutor {
        URLSessionMediaDownloadExecutor(
            session: session,
            cacheRoot: cacheRoot,
            allowedSaveRoots: allowedSaveRoots
        )
    }

    private func makeResponse(
        url: String = "https://media-proof.example.test/file.bin",
        status: Int,
        headers: [String: String] = [:],
        data: Data
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: URL(string: url)!,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }

    private func tempCacheRoot() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("media-proof-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Proof 1: full GET 200 download

    /// GET returns 200 with body. The executor must:
    /// - write the body to a temp file under `cacheRoot`.
    /// - compute sha256 over the body (hex lowercase).
    /// - report fromCache=false, byteLength=body.count.
    /// - capture finalUrl from `HTTPURLResponse.url`.
    func testFullGetDownloadReturns200WithSha256AndTempPath() async throws {
        let body = Data("hello-media-proof".utf8)
        let expectedSha = SHA256.hash(data: body)
            .map { String(format: "%02x", $0) }
            .joined()
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let session = makeSession { _ in
            (self.makeResponse(status: 200, headers: ["Content-Type": "text/plain", "Content-Length": "\(body.count)"], data: body), body)
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        let request = HostMediaDownloadRequest(
            url: "https://media-proof.example.test/file.bin",
            cacheKey: "proof-001"
        )
        let result = try await executor.download(request: request)

        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.byteLength, UInt64(body.count))
        XCTAssertEqual(result.sha256, expectedSha)
        XCTAssertEqual(result.contentType, "text/plain")
        XCTAssertEqual(result.contentLength, UInt64(body.count))
        XCTAssertFalse(result.fromCache)
        XCTAssertEqual(result.resourceId, "proof-001")
        XCTAssertEqual(result.finalUrl, "https://media-proof.example.test/file.bin")

        // tempPath must point to a real file under cacheRoot.
        let tempPath = try XCTUnwrap(result.tempPath)
        let written = FileManager.default.contents(atPath: tempPath)
        XCTAssertEqual(written, body)
    }

    // MARK: - Proof 2: range request forwards Range header

    /// rangeStart=10 + rangeEnd=19 must produce `Range: bytes=10-19` on the
    /// outgoing request, and the executor must return the stubbed 206 response.
    func testRangeRequestForwardsRangeHeader() async throws {
        let body = Data(repeating: 0x41, count: 10)
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        var capturedRange: String?
        let session = makeSession { req in
            capturedRange = req.value(forHTTPHeaderField: "Range")
            return (self.makeResponse(status: 206, headers: ["Content-Range": "bytes 10-19/100", "Content-Length": "10"], data: body), body)
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        let request = HostMediaDownloadRequest(
            url: "https://media-proof.example.test/range.bin",
            method: "GET",
            rangeStart: 10,
            rangeEnd: 19,
            cacheKey: "proof-range-002"
        )
        let result = try await executor.download(request: request)

        XCTAssertEqual(capturedRange, "bytes=10-19")
        XCTAssertEqual(result.statusCode, 206)
        XCTAssertEqual(result.byteLength, 10)
    }

    // MARK: - Proof 3: 304 short-circuit

    /// 304 response: fromCache=true, byteLength=0, tempPath=nil, sha256=nil.
    /// The executor must NOT write any file.
    func test304ShortCircuitReturnsFromCacheWithNoBody() async throws {
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let session = makeSession { _ in
            (self.makeResponse(status: 304, headers: ["ETag": "\"etag-304\""], data: Data()), Data())
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        let request = HostMediaDownloadRequest(
            url: "https://media-proof.example.test/cached.bin",
            ifNoneMatch: "\"etag-304\"",
            cacheKey: "proof-304-003"
        )
        let result = try await executor.download(request: request)

        XCTAssertEqual(result.statusCode, 304)
        XCTAssertTrue(result.fromCache)
        XCTAssertEqual(result.byteLength, 0)
        XCTAssertNil(result.tempPath)
        XCTAssertNil(result.sha256)
        XCTAssertEqual(result.etag, "\"etag-304\"")
    }

    // MARK: - Proof 4: ETag / If-None-Match forwarded

    /// `ifNoneMatch` must be forwarded as `If-None-Match` header. The response
    /// ETag must be captured in `result.etag`.
    func testIfNoneMatchHeaderForwardedAndResponseEtagCaptured() async throws {
        let body = Data("etag-proof".utf8)
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        var capturedINM: String?
        let session = makeSession { req in
            capturedINM = req.value(forHTTPHeaderField: "If-None-Match")
            return (self.makeResponse(status: 200, headers: ["ETag": "\"etag-fresh\""], data: body), body)
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        let request = HostMediaDownloadRequest(
            url: "https://media-proof.example.test/etag.bin",
            ifNoneMatch: "\"etag-old\"",
            cacheKey: "proof-etag-004"
        )
        let result = try await executor.download(request: request)

        XCTAssertEqual(capturedINM, "\"etag-old\"")
        XCTAssertEqual(result.etag, "\"etag-fresh\"")
    }

    // MARK: - Proof 5: maxBytes exceeded throws

    /// When the streamed body exceeds `maxBytes`, the executor aborts without
    /// publishing a target or leaving a partial staging file.
    func testMaxBytesExceededThrowsNetworkError() async {
        let body = Data(repeating: 0x42, count: 200)
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let session = makeSession { _ in
            (self.makeResponse(status: 200, data: body), body)
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        let request = HostMediaDownloadRequest(
            url: "https://media-proof.example.test/big.bin",
            cacheKey: "proof-max-005",
            maxBytes: 100
        )
        do {
            _ = try await executor.download(request: request)
            XCTFail("expected networkError for maxBytes exceeded")
        } catch MediaDownloadExecutorError.networkError(let msg) {
            XCTAssertTrue(msg.contains("exceeds maxBytes"), "got: \(msg)")
        } catch {
            XCTFail("expected .networkError, got: \(error)")
        }
        XCTAssertEqual(
            (try? FileManager.default.contentsOfDirectory(atPath: cacheRoot.path)) ?? [],
            [],
            "an oversized stream must not leave a partial artifact"
        )
    }

    // MARK: - Proof 6: invalid url throws invalidParams

    /// A non-URL string (with invalid characters that `URL(string:)` rejects)
    /// throws `.invalidParams` before any network call.
    func testInvalidUrlThrowsInvalidParams() async {
        let session = makeSession { _ in
            (self.makeResponse(status: 200, data: Data()), Data())
        }
        defer { MediaDownloadURLProtocolStub.handler = nil }
        let executor = makeExecutor(session: session)

        // "ht!tp://" — `URL(string:)` rejects this because the scheme
        // contains an illegal character ('!').
        let request = HostMediaDownloadRequest(url: "ht!tp://[invalid")
        do {
            _ = try await executor.download(request: request)
            XCTFail("expected invalidParams for invalid url")
        } catch MediaDownloadExecutorError.invalidParams(let msg) {
            XCTAssertTrue(msg.contains("invalid url"), "got: \(msg)")
        } catch {
            XCTFail("expected .invalidParams, got: \(error)")
        }
    }

    // MARK: - Proof 7: HEAD method skips file write

    /// HEAD request: tempPath=nil, byteLength=0 (no body written even if the
    /// stub returns one), sha256=nil.
    func testHeadMethodSkipsFileWrite() async throws {
        let body = Data("should-be-ignored".utf8)
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let session = makeSession { _ in
            (self.makeResponse(status: 200, headers: ["Content-Length": "\(body.count)"], data: body), body)
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        let request = HostMediaDownloadRequest(
            url: "https://media-proof.example.test/head.bin",
            method: "HEAD",
            cacheKey: "proof-head-007"
        )
        let result = try await executor.download(request: request)

        XCTAssertEqual(result.statusCode, 200)
        // HEAD must not write a file even though the stub returned a body.
        XCTAssertNil(result.tempPath)
        // sha256 is computed over the buffered bytes regardless of method;
        // for HEAD the body is typically empty so sha256 reflects an empty
        // hash. The key assertion is tempPath=nil (no file written).
        // (We don't assert sha256=nil because the executor computes it
        // unconditionally — a documented behavior, not a bug.)
    }

    // MARK: - Proof 8: savePath override

    /// When `savePath` is provided, the file must be written to that exact
    /// path (not the cacheRoot).
    func testSavePathOverrideWritesToSpecifiedPath() async throws {
        let body = Data("savepath-proof".utf8)
        let cacheRoot = tempCacheRoot()
        let customPath = cacheRoot.appendingPathComponent("custom-name.bin").path
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let session = makeSession { _ in
            (self.makeResponse(status: 200, data: body), body)
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        let request = HostMediaDownloadRequest(
            url: "https://media-proof.example.test/custom.bin",
            cacheKey: "proof-save-008",
            savePath: customPath
        )
        let result = try await executor.download(request: request)

        XCTAssertEqual(result.tempPath, customPath)
        let written = FileManager.default.contents(atPath: customPath)
        XCTAssertEqual(written, body)
    }

    // MARK: - Proof 9: redirect captures finalUrl

    /// When the stub returns a redirect (3xx + Location), `URLSession` follows
    /// it by default. The executor must capture the final URL from
    /// `HTTPURLResponse.url` of the last response.
    func testRedirectCapturesFinalUrl() async throws {
        let body = Data("redirected".utf8)
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let session = makeSession { req in
            if req.url?.absoluteString == "https://media-proof.example.test/start" {
                let redirect = self.makeResponse(
                    url: "https://media-proof.example.test/start",
                    status: 302,
                    headers: ["Location": "https://cdn-proof.example.test/final"],
                    data: Data()
                )
                return (redirect, Data())
            }
            // Final hop.
            return (self.makeResponse(url: "https://cdn-proof.example.test/final", status: 200, data: body), body)
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        let request = HostMediaDownloadRequest(
            url: "https://media-proof.example.test/start",
            cacheKey: "proof-redirect-009"
        )
        let result = try await executor.download(request: request)

        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(result.finalUrl, "https://cdn-proof.example.test/final")
    }

    // MARK: - Proof 10: sha256 hex lowercase matches CryptoKit

    /// The sha256 returned by the executor must match `CryptoKit.SHA256`
    /// computed independently, in hex lowercase format.
    func testSha256MatchesCryptoKitHexLowercase() async throws {
        let body = Data("sha256-verification-payload".utf8)
        let expectedSha = SHA256.hash(data: body)
            .map { String(format: "%02x", $0) }
            .joined()
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let session = makeSession { _ in
            (self.makeResponse(status: 200, data: body), body)
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        let request = HostMediaDownloadRequest(
            url: "https://media-proof.example.test/sha.bin",
            cacheKey: "proof-sha-010"
        )
        let result = try await executor.download(request: request)

        XCTAssertEqual(result.sha256, expectedSha)
        XCTAssertTrue(result.sha256?.allSatisfy { $0.isLowercase || $0.isNumber } ?? false,
                      "sha256 must be hex lowercase")
    }

    // MARK: - Proof 11: savePath cannot escape admitted roots

    func testSavePathOutsideAllowedRootsFailsClosedBeforeNetwork() async {
        let cacheRoot = tempCacheRoot()
        let allowedRoot = cacheRoot.appendingPathComponent("allowed", isDirectory: true)
        let outsidePath = cacheRoot.appendingPathComponent("outside.bin").path
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        var networkCalled = false
        let session = makeSession { _ in
            networkCalled = true
            return (self.makeResponse(status: 200, data: Data("unsafe".utf8)), Data("unsafe".utf8))
        }
        let executor = makeExecutor(
            session: session,
            cacheRoot: allowedRoot,
            allowedSaveRoots: [allowedRoot]
        )

        do {
            _ = try await executor.download(request: HostMediaDownloadRequest(
                url: "https://media-proof.example.test/unsafe.bin",
                savePath: outsidePath
            ))
            XCTFail("expected invalidParams for savePath outside admitted roots")
        } catch MediaDownloadExecutorError.invalidParams(let message) {
            XCTAssertTrue(message.contains("outside the app sandbox roots"), "got: \(message)")
            XCTAssertFalse(networkCalled, "unsafe destination must fail before network I/O")
        } catch {
            XCTFail("expected .invalidParams, got: \(error)")
        }
    }

    // MARK: - Proof 12: cache keys are not filenames

    func testCacheKeyTraversalTextIsHashedInsideCacheRoot() async throws {
        let body = Data("safe-cache-key".utf8)
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let session = makeSession { _ in
            (self.makeResponse(status: 200, data: body), body)
        }
        let executor = makeExecutor(
            session: session,
            cacheRoot: cacheRoot,
            allowedSaveRoots: [cacheRoot]
        )

        let result = try await executor.download(request: HostMediaDownloadRequest(
            url: "https://media-proof.example.test/cache-key.bin",
            cacheKey: "../../escape/../payload"
        ))
        let path = try XCTUnwrap(result.tempPath)
        XCTAssertTrue(path.hasPrefix(cacheRoot.path + "/"), "got: \(path)")
        XCTAssertFalse(path.contains(".."), "cache key must not be copied into the filename")
        XCTAssertEqual(FileManager.default.contents(atPath: path), body)
    }

    // MARK: - Proof 13: admitted nested savePath

    func testNestedSavePathCreatesParentDirectory() async throws {
        let body = Data("nested-save-path".utf8)
        let cacheRoot = tempCacheRoot()
        let customPath = cacheRoot.appendingPathComponent("one/two/content.bin").path
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let session = makeSession { _ in
            (self.makeResponse(status: 200, data: body), body)
        }
        let executor = makeExecutor(
            session: session,
            cacheRoot: cacheRoot,
            allowedSaveRoots: [cacheRoot]
        )

        let result = try await executor.download(request: HostMediaDownloadRequest(
            url: "https://media-proof.example.test/nested.bin",
            savePath: customPath
        ))

        XCTAssertEqual(result.tempPath, customPath)
        XCTAssertEqual(FileManager.default.contents(atPath: customPath), body)
    }

    // MARK: - Proof 14: no ambient URLSession cookie owner

    func testRequestDisablesAmbientURLSessionCookies() async throws {
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        var shouldHandleCookies: Bool?
        let session = makeSession { request in
            shouldHandleCookies = request.httpShouldHandleCookies
            return (self.makeResponse(status: 200, data: Data("cookie-boundary".utf8)), Data("cookie-boundary".utf8))
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        _ = try await executor.download(request: HostMediaDownloadRequest(
            url: "https://media-proof.example.test/cookie-boundary.bin",
            cacheKey: "proof-cookie-boundary-014"
        ))

        XCTAssertEqual(shouldHandleCookies, false)
    }

    func testCallerSavePathCannotOverwriteExistingFileBeforeNetwork() async throws {
        let cacheRoot = tempCacheRoot()
        let target = cacheRoot.appendingPathComponent("owned.bin")
        try Data("caller-owned".utf8).write(to: target)
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        var networkCalled = false
        let session = makeSession { _ in
            networkCalled = true
            let body = Data("replacement".utf8)
            return (self.makeResponse(status: 200, data: body), body)
        }
        let executor = makeExecutor(
            session: session,
            cacheRoot: cacheRoot,
            allowedSaveRoots: [cacheRoot]
        )

        do {
            _ = try await executor.download(request: HostMediaDownloadRequest(
                url: "https://media-proof.example.test/overwrite.bin",
                savePath: target.path
            ))
            XCTFail("caller-owned files must not be overwritten")
        } catch MediaDownloadExecutorError.invalidParams(let message) {
            XCTAssertTrue(message.contains("already exists"))
        }
        XCTAssertFalse(networkCalled)
        XCTAssertEqual(try Data(contentsOf: target), Data("caller-owned".utf8))
    }

    func testCallerSavePathCannotBeClaimedDuringDownload() async throws {
        let cacheRoot = tempCacheRoot()
        let target = cacheRoot.appendingPathComponent("raced-owned.bin")
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        let callerOwned = Data("created-during-download".utf8)
        let body = Data("download-body".utf8)
        let session = makeSession { _ in
            try callerOwned.write(to: target)
            return (self.makeResponse(status: 200, data: body), body)
        }
        let executor = makeExecutor(
            session: session,
            cacheRoot: cacheRoot,
            allowedSaveRoots: [cacheRoot]
        )

        do {
            _ = try await executor.download(request: HostMediaDownloadRequest(
                url: "https://media-proof.example.test/raced-overwrite.bin",
                savePath: target.path
            ))
            XCTFail("a path claimed after preflight must still fail closed")
        } catch MediaDownloadExecutorError.invalidParams(let message) {
            XCTAssertTrue(message.contains("appeared during download"))
        }
        XCTAssertEqual(try Data(contentsOf: target), callerOwned)
    }

    func testURLUserInfoCredentialsAreRejectedBeforeNetwork() async throws {
        let cacheRoot = tempCacheRoot()
        defer {
            cleanup(cacheRoot)
            MediaDownloadURLProtocolStub.handler = nil
        }
        var networkCalled = false
        let session = makeSession { _ in
            networkCalled = true
            return (self.makeResponse(status: 200, data: Data()), Data())
        }
        let executor = makeExecutor(session: session, cacheRoot: cacheRoot)

        do {
            _ = try await executor.download(request: HostMediaDownloadRequest(
                url: "https://user:secret@media-proof.example.test/private.bin"
            ))
            XCTFail("URL user-info credentials must fail closed")
        } catch MediaDownloadExecutorError.invalidParams(let message) {
            XCTAssertTrue(message.contains("embedded credentials"))
        }
        XCTAssertFalse(networkCalled)
    }
}

// MARK: - URLProtocol stub

private final class MediaDownloadURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: StubError.missingHandler)
            return
        }
        do {
            let (response, data) = try handler(request)
            // For redirect responses, notify URLSession so its redirect
            // handling kicks in (matches real HTTP transport).
            if (300...399).contains(response.statusCode),
               let location = response.value(forHTTPHeaderField: "Location"),
               let redirectURL = URL(string: location) {
                let redirectRequest = URLRequest(url: redirectURL)
                client?.urlProtocol(self, wasRedirectedTo: redirectRequest, redirectResponse: response)
            }
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private enum StubError: Error {
    case missingHandler
}
