import XCTest
import ReaderCoreProtocols
import ReaderCoreNativeAdapter
import ReaderUIContract
@testable import ReaderShellValidation

final class ReaderSlice11HostBoundaryTests: XCTestCase {
    func testCookieHandlersIsolateOpaqueSessionsAndFilterByName() async throws {
        let jar = HostScopedCookieJarFactory.makeBasicCookieJar()
        let setter = CookieSetHandler(cookieJar: jar)
        let getter = CookieGetHandler(cookieJar: jar)

        _ = try await setter.handle(params: [
            "url": "https://books.example.test/login",
            "sessionId": "profile-a",
            "cookie": ["name": "sid", "value": "a", "path": "/"],
        ])
        _ = try await setter.handle(params: [
            "url": "https://books.example.test/login",
            "sessionId": "profile-b",
            "cookie": ["name": "sid", "value": "b", "path": "/"],
        ])

        let a = try await getter.handle(params: [
            "url": "https://books.example.test/reader",
            "sessionId": "profile-a",
            "name": "sid",
        ])
        let b = try await getter.handle(params: [
            "domain": "books.example.test",
            "sessionId": "profile-b",
            "name": "sid",
        ])

        let aCookies = try XCTUnwrap(a["cookies"] as? [[String: Any]])
        let bCookies = try XCTUnwrap(b["cookies"] as? [[String: Any]])
        XCTAssertEqual(aCookies.map { $0["value"] as? String }, ["a"])
        XCTAssertEqual(bCookies.map { $0["value"] as? String }, ["b"])
    }

    func testExplicitCookieSessionNeverFallsBackToAmbientDefaultJar() async throws {
        let jar = HostScopedCookieJarFactory.makeBasicCookieJar()
        await jar.setCookie(Cookie(
            name: "ambient",
            value: "must-not-leak",
            domain: "books.example.test",
            path: "/"
        ))
        let getter = CookieGetHandler(cookieJar: jar)

        var explicitSessions: [[String: Any]] = []
        for sessionID in ["new-empty-session", "__default__"] {
            explicitSessions.append(try await getter.handle(params: [
                "url": "https://books.example.test/reader",
                "sessionId": sessionID,
            ]))
        }
        let ambient = try await getter.handle(params: [
            "url": "https://books.example.test/reader",
        ])

        XCTAssertTrue(explicitSessions.allSatisfy {
            ($0["cookies"] as? [[String: Any]])?.isEmpty == true
        })
        XCTAssertEqual(
            (ambient["cookies"] as? [[String: Any]])?.compactMap { $0["value"] as? String },
            ["must-not-leak"]
        )
    }

    func testUICookieCapabilityRejectsBlankSessionInsteadOfClearingGlobalJar() async throws {
        let jar = HostScopedCookieJarFactory.makeBasicCookieJar()
        let capability = HostCookieCapability(cookieJar: jar)

        let outcome = try await capability.handle(HostRequest(
            type: .cookie_clear,
            payload: ["sessionId": AnyCodable("  ")]
        ))

        XCTAssertFalse(outcome.succeeded)
        XCTAssertTrue(String(describing: outcome.error).contains("non-blank"))
    }

    func testProtectedDownloadUsesOnlyItsOpaqueSessionAndStoresResponseCookie() async throws {
        let jar = HostScopedCookieJarFactory.makeBasicCookieJar()
        let scope = HostCookieSessionScope.key(for: "download-session")
        await jar.setCookie(
            Cookie(name: "sid", value: "session-cookie", domain: "media.example.test", path: "/"),
            scopeKey: scope
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Slice11MediaURLProtocolStub.self]
        var capturedCookie: String?
        Slice11MediaURLProtocolStub.handler = { request in
            capturedCookie = request.value(forHTTPHeaderField: "Cookie")
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: ["Set-Cookie": "renewed=yes; Path=/; HttpOnly"]
            )!
            return (response, Data("protected".utf8))
        }
        defer { Slice11MediaURLProtocolStub.handler = nil }

        let cacheRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("slice11-media-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: cacheRoot) }
        let executor = URLSessionMediaDownloadExecutor(
            session: URLSession(configuration: configuration),
            cacheRoot: cacheRoot,
            cookieJar: jar
        )

        let result = try await executor.download(request: .init(
            url: "https://media.example.test/protected.bin",
            cacheKey: "protected",
            sessionId: "download-session"
        ))

        XCTAssertEqual(result.statusCode, 200)
        XCTAssertEqual(capturedCookie, "sid=session-cookie")
        let stored = await jar.getCookies(
            for: "media.example.test",
            path: "/",
            scopeKey: scope
        )
        XCTAssertTrue(stored.contains { $0.name == "renewed" && $0.value == "yes" })
    }

    func testProtectedDownloadRejectsPlaintextAuthorizationBeforeNetwork() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Slice11MediaURLProtocolStub.self]
        var networkCount = 0
        Slice11MediaURLProtocolStub.handler = { request in
            networkCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { Slice11MediaURLProtocolStub.handler = nil }
        let executor = URLSessionMediaDownloadExecutor(session: URLSession(configuration: configuration))

        do {
            _ = try await executor.download(request: .init(
                url: "https://media.example.test/protected.bin",
                headers: ["Authorization": "Bearer plaintext"]
            ))
            XCTFail("embedded authorization must fail closed")
        } catch MediaDownloadExecutorError.invalidParams(let message) {
            XCTAssertTrue(message.contains("opaque sessionId"))
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertEqual(networkCount, 0)
    }

    func testProtectedDownloadRejectsBlankOpaqueSessionBeforeNetwork() async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Slice11MediaURLProtocolStub.self]
        var networkCount = 0
        Slice11MediaURLProtocolStub.handler = { request in
            networkCount += 1
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        defer { Slice11MediaURLProtocolStub.handler = nil }
        let executor = URLSessionMediaDownloadExecutor(session: URLSession(configuration: configuration))

        do {
            _ = try await executor.download(request: .init(
                url: "https://media.example.test/protected.bin",
                sessionId: "  "
            ))
            XCTFail("blank session must fail closed")
        } catch MediaDownloadExecutorError.invalidParams(let message) {
            XCTAssertTrue(message.contains("non-blank"))
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertEqual(networkCount, 0)
    }

    func testHTTPRetryRejectsFractionalAttemptsBeforeTransport() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = HostRequestRouter(httpClient: Slice11NeverHTTPClient(), runtime: runtime)

        do {
            _ = try await router.executeHTTP(params: [
                "url": "https://books.example.test/chapter",
                "method": "GET",
                "retry": ["maxAttempts": 1.5],
            ])
            XCTFail("fractional retry count must fail closed")
        } catch HostRequestRouterError.hostHTTPFailed(let message) {
            XCTAssertTrue(message.contains("positive integer"))
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testHTTPZeroRedirectCapIsAcceptedAndForwarded() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let client = Slice11ConfiguredHTTPClient()
        let router = HostRequestRouter(httpClient: client, runtime: runtime)

        let result = try await router.executeHTTP(params: [
            "url": "https://books.example.test/chapter",
            "method": "GET",
            "maxRedirects": 0,
        ])

        XCTAssertEqual(result["status"] as? Int, 200)
        XCTAssertEqual(client.capturedMaxRedirects, 0)
    }

    func testMediaHandlerRejectsFractionalRangeBeforeExecutor() async {
        let executor = StubMediaDownloadExecutor(result: HostMediaDownloadResult(
            resourceId: "unused",
            statusCode: 200,
            byteLength: 0
        ))
        let handler = MediaDownloadHandler(executor: executor)

        do {
            _ = try await handler.handle(params: [
                "url": "https://media.example.test/book.bin",
                "rangeStart": 1.5,
            ])
            XCTFail("fractional range must fail closed")
        } catch MediaDownloadExecutorError.invalidParams(let message) {
            XCTAssertTrue(message.contains("non-negative integer"))
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertNil(executor.lastRequest)
    }

    func testCoreCredentialStoreRejectsNonDeviceOnlyProtectionClassBeforeKeychainAccess() {
        XCTAssertThrowsError(try HostCredentialStore.shared.set(params: [
            "service": "fixture-service",
            "account": "fixture-account",
            "value": "fixture-secret",
            "accessible": "whenUnlocked",
        ])) { error in
            XCTAssertTrue(error.localizedDescription.contains("ThisDeviceOnly"))
        }
    }
}

private struct Slice11NeverHTTPClient: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        XCTFail("transport must not run for an invalid retry policy")
        return HTTPResponse(statusCode: 500, headers: [:], data: Data())
    }
}

private final class Slice11ConfiguredHTTPClient: HostConfiguredHTTPClient, @unchecked Sendable {
    private let lock = NSLock()
    private var storedMaxRedirects: Int?

    var capturedMaxRedirects: Int? {
        lock.lock()
        defer { lock.unlock() }
        return storedMaxRedirects
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await send(request, requestId: nil, maxRedirects: nil)
    }

    func send(_ request: HTTPRequest, requestId: String) async throws -> HTTPResponse {
        try await send(request, requestId: Optional(requestId), maxRedirects: nil)
    }

    func send(
        _ request: HTTPRequest,
        requestId: String?,
        maxRedirects: Int?
    ) async throws -> HTTPResponse {
        lock.lock()
        storedMaxRedirects = maxRedirects
        lock.unlock()
        return HTTPResponse(statusCode: 200, headers: [:], data: Data())
    }

    func cancel(requestId: String) -> Bool { false }
}

private final class Slice11MediaURLProtocolStub: URLProtocol {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.cannotLoadFromNetwork))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
