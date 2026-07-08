import XCTest
import ReaderCoreProtocols
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

/// Focused Host-side proof for login/cookie/source-state continuity.
///
/// These tests cover the iOS gaps surfaced by same-key source triage without
/// touching Native C ABI or rebuilding the xcframework:
/// - production `HostRequestRouter` uses the shared cookie jar for
///   `cookie.set` / `cookie.get`;
/// - Rust Core service reconfiguration reuses the same runtime, so Core-side
///   local source variables are not lost just because service objects are
///   recreated;
/// - `source.getLoginHeaderMap` returns an empty map by default, and can be
///   backed by a future login-header store through provider injection.
final class HostStateContinuityProofTests: XCTestCase {

    func testProductionRouterCookieSetAndGetShareTheSameJar() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)
        let cookieName = "same_key_sid_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))"

        let setResult = try await router.executeCookieSet(params: [
            "url": "https://same-key.example.test/login",
            "cookie": [
                "name": cookieName,
                "value": "host-state-token",
                "domain": "same-key.example.test",
                "path": "/",
                "secure": true,
                "httpOnly": true,
            ] as [String: Any],
        ])
        XCTAssertEqual(setResult["stored"] as? Bool, true)

        let getResult = try await router.executeCookieGet(params: [
            "url": "https://same-key.example.test/chapter/1",
        ])
        let cookies = try XCTUnwrap(getResult["cookies"] as? [[String: Any]])
        let matched = cookies.first { $0["name"] as? String == cookieName }
        let sid = try XCTUnwrap(matched)
        XCTAssertEqual(sid["value"] as? String, "host-state-token")
        XCTAssertEqual(sid["domain"] as? String, "same-key.example.test")
        XCTAssertEqual(sid["path"] as? String, "/")
        XCTAssertEqual(sid["secure"] as? Bool, true)
        XCTAssertEqual(sid["httpOnly"] as? Bool, true)
    }

    @MainActor
    func testRustCoreModeReusesRuntimeAcrossServiceReconfiguration() throws {
        let provider = ReaderCoreServiceProvider.shared

        XCTAssertTrue(provider.configureRustCoreMode(), "first rustCore configuration must boot/wire runtime")
        let firstRuntime = try XCTUnwrap(RustCoreRuntimeHolder.shared.current)

        XCTAssertTrue(provider.configureRustCoreMode(), "second rustCore configuration must reuse runtime")
        let secondRuntime = try XCTUnwrap(RustCoreRuntimeHolder.shared.current)

        XCTAssertEqual(
            ObjectIdentifier(firstRuntime),
            ObjectIdentifier(secondRuntime),
            "source.getVariable/setVariable are Core-side local state, so iOS must not rebuild the runtime per command"
        )
    }

    func testSourceLoginHeaderMapDefaultsToEmptyMapInsteadOfUnsupported() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)

        let result = try await router.executeSourceGetLoginHeaderMap(params: [
            "sourceId": "src-342",
            "url": "https://login-required.example.test/book/1",
        ])

        XCTAssertEqual(result["headers"] as? [String: String], [:])
        XCTAssertEqual(result["headerMap"] as? [String: String], [:])
    }

    func testSourceLoginHeaderMapUsesInjectedProviderWhenAvailable() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let provider = StubLoginHeaderMapProvider(headers: [
            "Authorization": "Bearer redacted-token",
            "X-Reader-Source": "src-342",
        ])
        let router = HostRequestRouter(
            httpClient: URLSessionHTTPClient(),
            runtime: runtime,
            sourceLoginHeaderMapProvider: provider
        )

        let result = try await router.executeSourceGetLoginHeaderMap(params: [
            "source": [
                "sourceId": "src-342",
                "baseUrl": "https://login-required.example.test",
            ] as [String: Any],
        ])

        XCTAssertEqual(result["headers"] as? [String: String], provider.headers)
        XCTAssertEqual(result["headerMap"] as? [String: String], provider.headers)
        XCTAssertEqual(provider.lastSourceId, "src-342")
        XCTAssertEqual(provider.lastHost, "login-required.example.test")
    }
}

private final class StubLoginHeaderMapProvider: SourceLoginHeaderMapProvider, @unchecked Sendable {
    let headers: [String: String]
    private let lock = NSLock()
    private var capturedSourceId: String?
    private var capturedHost: String?

    init(headers: [String: String]) {
        self.headers = headers
    }

    var lastSourceId: String? {
        lock.withLock { capturedSourceId }
    }

    var lastHost: String? {
        lock.withLock { capturedHost }
    }

    func loginHeaderMap(sourceId: String?, url: String?, host: String?) async throws -> [String: String]? {
        lock.withLock {
            capturedSourceId = sourceId
            capturedHost = host
        }
        return headers
    }
}

private extension NSLock {
    func withLock<R>(_ body: () throws -> R) rethrows -> R {
        lock()
        defer { unlock() }
        return try body()
    }
}
