import CryptoKit
import Foundation
import ReaderCoreBridge
import ReaderHost
import WebKit
import XCTest

@MainActor
final class M2NetworkHostTests: XCTestCase {
    private let base = "http://127.0.0.1:18765"

    func testURLSessionGBKRedirect503AndOriginalCancellation() async throws {
        try await withLibrary { library in
            let runtime = library.runtime
            let network = try XCTUnwrap(library.network)
            XCTAssertEqual(Set(network.capabilities),
                           [.timeNow, .hostSmokeEcho, .httpExecute, .cookieGet, .cookieSet, .webviewEvaluateJavaScript, .mediaDownload])
            XCTAssertEqual(network.protocolExtensions, ["http.execute.timeoutMs.v1"])
            let set = try await runtime.request(ReaderM2.runtimeHostSmokeCookieSet, .init(params: .init(
                cookie: .init(name: "reader_m2", value: "loopback-only", path: "/"),
                url: base + "/host/echo", sessionId: "http-fixture"
            )))
            XCTAssertTrue(set.value.stored)
            let echo = try await runtime.request(ReaderM2.runtimeHostSmokeHttpExecute, .init(params: .init(
                url: base + "/host/echo", method: "POST", body: "中文", charset: "GBK",
                usePlatformCookieJar: true, session: .init(id: "http-fixture")
            )))
            XCTAssertEqual(echo.value.status, 200)
            XCTAssertEqual(echo.value.body, "ACK 中文")
            let echoedCookie = echo.value.headers?.first {
                $0.key.caseInsensitiveCompare("X-Reader-Request-Cookie") == .orderedSame
            }?.value
            XCTAssertEqual(echoedCookie, .string("reader_m2=loopback-only"))

            let redirect = try await runtime.request(ReaderM2.runtimeHostSmokeHttpExecute, .init(params: .init(
                url: base + "/host/redirect", followRedirects: true, maxRedirects: 2
            )))
            XCTAssertEqual(redirect.value.status, 200)
            XCTAssertEqual(redirect.value.finalUrl, base + "/host/document")
            XCTAssertEqual(redirect.value.redirects?.map(\.status), [302])
            let exposed = try await runtime.request(ReaderM2.runtimeHostSmokeHttpExecute, .init(params: .init(
                url: base + "/host/redirect", followRedirects: false
            )))
            XCTAssertEqual(exposed.value.status, 302)
            XCTAssertEqual(exposed.value.finalUrl, base + "/host/redirect")

            let protected = try await runtime.request(ReaderM2.runtimeHostSmokeHttpExecute, .init(params: .init(
                url: base + "/host/redirect-cross-origin", headers: [
                    "Authorization": .string("Basic fixture"),
                    "Cookie": .string("privateFixture=1"),
                    "Proxy-Authorization": .string("Basic fixture")
                ], followRedirects: true, usePlatformCookieJar: false
            )))
            XCTAssertEqual(protected.value.body, "0")
            XCTAssertEqual(protected.value.redirects?.map(\.status), [302])

            do {
                _ = try await runtime.request(ReaderM2.runtimeHostSmokeHttpExecute,
                    .init(params: .init(url: base + "/host/body-over-budget")))
                XCTFail("A response without Content-Length must still respect the running 8 MiB budget")
            } catch let error as CoreRequestFailure {
                XCTAssertEqual(error.m2Value.details?.host?.diagnostics?.code, .invalidResponse)
            }

            do {
                _ = try await runtime.request(ReaderM2.runtimeHostSmokeHttpExecute,
                                              .init(params: .init(url: base + "/host/unavailable")))
                XCTFail("503 must reach the original Core caller as host.error")
            } catch let error as CoreRequestFailure {
                XCTAssertEqual(error.m2Value.code, .internal)
                XCTAssertEqual(error.m2Value.details?.category, "SOURCE_HTTP_FAILED")
                XCTAssertEqual(error.m2Value.details?.host?.capability, .httpExecute)
                XCTAssertEqual(error.m2Value.details?.host?.diagnostics?.code, .httpError)
                XCTAssertEqual(error.m2Value.details?.host?.diagnostics?.phase, .response)
                XCTAssertEqual(error.m2Value.details?.host?.diagnostics?.details?["status"], .integer(503))
                XCTAssertEqual(error.m2Value.details?.host?.requestId, error.id.requestId)
            }

            let cancelled = try await cancelAfterEntry(runtime, path: "/host/hold",
                rpc: ReaderM2.runtimeHostSmokeHttpExecute, params: .init(params: .init(
                    timeoutMs: 20_000, url: base + "/host/hold"
                )))
            XCTAssertEqual(cancelled.m2Value.code, .cancelled)
            let after = try await runtime.request(ReaderM1.coreInfo, .init())
            XCTAssertEqual(after.value.sqliteUserVersion, 47)
            print("M2_HOST_HTTP status=200 gbk=D6D0CEC4 redirect=302/200 crossOriginCredentials=0 streamedBudget=INVALID_RESPONSE hostError=HTTP_ERROR/503 cancelledRequest=\(cancelled.id.requestId) postCancelCoreInfo=47")
        }
    }

    func testSystemCookiesPersistAndLoginWebViewIsPhysicallyIsolated() async throws {
        let directory = try isolatedDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        try await withLibrary(directory: directory) { library in
            let runtime = library.runtime
            let network = try XCTUnwrap(library.network)
            for (source, value) in [("login-a", "seed-a"), ("login-b", "seed-b")] {
                let seeded = try await runtime.request(ReaderM2.runtimeHostSmokeCookieSet, .init(params: .init(
                    cookie: .init(name: "sourceSeed", value: value, path: "/"),
                    url: base + "/host/document", sessionId: source
                )))
                XCTAssertTrue(seeded.value.stored)
            }
            let siteURL = try XCTUnwrap(URL(string: base + "/host/document"))
            let login = try await network.beginLogin(sourceId: "login-a", url: siteURL)
            try await eventually("manual login document ready") { login.state != .loading }
            XCTAssertEqual(login.state, .ready)
            let webCookies = await login.webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            XCTAssertEqual(webCookies.first(where: { $0.name == "sourceSeed" })?.value, "seed-a")
            let title = try await javaScript("document.title", in: login.webView)
            XCTAssertEqual(title, "M2 loopback document")

            let fromServer = try await runtime.request(ReaderM2.runtimeHostSmokeHttpExecute, .init(params: .init(
                url: base + "/host/cookie?set=serverProof=network", usePlatformCookieJar: true, session: .init(id: "login-a")
            )))
            XCTAssertEqual(fromServer.value.status, 200)
            let updatedWebCookies = await login.webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            XCTAssertEqual(updatedWebCookies.first(where: { $0.name == "serverProof" })?.value, "network")

            let written = try await javaScript("document.cookie = 'loginProof=web; Path=/'; document.cookie", in: login.webView)
            XCTAssertTrue(written?.contains("loginProof=web") == true)
            try await network.synchronizeLogin(sourceId: "login-a")
            let got = try await runtime.request(ReaderM2.runtimeHostSmokeCookieGet, .init(params: .init(
                url: base + "/host/document", name: "loginProof", sessionId: "login-a"
            )))
            XCTAssertEqual(got.value.cookies.map(\.value), ["web"])
            let echoed = try await runtime.request(ReaderM2.runtimeHostSmokeHttpExecute, .init(params: .init(
                url: base + "/host/cookie", usePlatformCookieJar: true, session: .init(id: "login-a")
            )))
            XCTAssertTrue(echoed.value.body.contains("loginProof=web"))
            let background = try await runtime.request(ReaderM2.runtimeHostSmokeWebViewEvaluateJavaScript,
                .init(params: .init(document: .url(.init(url: siteURL.absoluteString)),
                                    javaScript: "document.cookie", timeoutMillis: 10_000)))
            XCTAssertEqual(background.value.value, .string(""))
            XCTAssertEqual(background.value.title, "M2 loopback document")
            let copied = try await runtime.request(ReaderM2.runtimeHostSmokeWebViewEvaluateJavaScript,
                .init(params: .init(document: .url(.init(url: siteURL.absoluteString)),
                                    javaScript: "document.cookie = 'backgroundProof=isolated; Path=/'; document.cookie",
                                    timeoutMillis: 10_000, profileId: "login-a")))
            if case .string(let value) = copied.value.value {
                XCTAssertTrue(value.contains("backgroundProof=isolated"))
                XCTAssertTrue(value.contains("loginProof=web"))
            } else { XCTFail("Expected the real background document Cookie string") }
            let manuallyObserved = try await javaScript("document.cookie", in: login.webView)
            XCTAssertFalse(manuallyObserved?.contains("backgroundProof") == true)
            network.revokeLogin(sourceId: "login-a")
            XCTAssertEqual(login.state, .revoked)
            print("M2_HOST_WEBKIT loginTitle=\(title ?? "") httpToWK=seed-a/serverProof wkToHTTP=loginProof webViewsHaveDistinctDataStores=true scopedCookieCopyDoesNotWriteBack=true")
        }
        try await withLibrary(directory: directory) { library in
            let runtime = library.runtime
            let network = try XCTUnwrap(library.network)
            let persisted = try await runtime.request(ReaderM2.runtimeHostSmokeCookieGet, .init(params: .init(
                url: base + "/host/document", name: "loginProof", sessionId: "login-a"
            )))
            XCTAssertEqual(persisted.value.cookies.map(\.value), ["web"])
            try await network.clearLogin(sourceId: "login-a", baseURL: XCTUnwrap(URL(string: base)))
            let cleared = try await runtime.request(ReaderM2.runtimeHostSmokeCookieGet, .init(params: .init(
                url: base + "/host/document", sessionId: "login-a"
            )))
            let sibling = try await runtime.request(ReaderM2.runtimeHostSmokeCookieGet, .init(params: .init(
                url: base + "/host/document", sessionId: "login-b"
            )))
            XCTAssertTrue(cleared.value.cookies.isEmpty)
            XCTAssertEqual(sibling.value.cookies.map(\.value), ["seed-b"])
            print("M2_HOST_COOKIE reopenedRuntime=\(runtime.runtimeId) persisted=web cleared=login-a preserved=login-b")
        }
    }

    func testRealWebKitTimeoutAndCancelledNavigationPreserveNextGeneration() async throws {
        try await withLibrary { library in
            let runtime = library.runtime
            do {
                _ = try await runtime.request(ReaderM2.runtimeHostSmokeWebViewEvaluateJavaScript,
                    .init(params: .init(document: .html(.init(body: "<title>expired</title>")),
                                        javaScript: "document.title", settleDelayMillis: 5_000, timeoutMillis: 300)))
                XCTFail("Evaluation deadline passed")
            } catch let error as CoreRequestFailure {
                XCTAssertEqual(error.m2Value.code, .timeout)
                XCTAssertEqual(error.m2Value.details?.host?.diagnostics?.code, .timeout)
            }
            let cancellation = try await cancelAfterEntry(runtime, path: "/host/document-hold",
                rpc: ReaderM2.runtimeHostSmokeWebViewEvaluateJavaScript, params: .init(params: .init(
                    document: .url(.init(url: base + "/host/document-hold")), javaScript: "document.title",
                    timeoutMillis: 20_000
                )))
            XCTAssertEqual(cancellation.m2Value.code, .cancelled)
            let next = try await runtime.request(ReaderM2.runtimeHostSmokeWebViewEvaluateJavaScript,
                .init(params: .init(document: .url(.init(url: base + "/host/document")),
                                    javaScript: "({title: document.title, generation: 2})", timeoutMillis: 10_000)))
            XCTAssertEqual(next.value.finalUrl, base + "/host/document")
            XCTAssertEqual(next.value.value, .object(["title": .string("M2 loopback document"), "generation": .integer(2)]))
            print("M2_HOST_WEBKIT_TERMINALS timeout=TIMEOUT cancelledRequest=\(cancellation.id.requestId) nextRequest=\(next.id.requestId) generation=2")
        }
    }

    func testMediaBoundedRangeAndCancellationInRealURLSession() async throws {
        try await withLibrary { library in
            let runtime = library.runtime
            let start = 7
            let end = 131_086
            let model = M2HostMediaDownloadRequest(url: base + "/host/media", rangeStart: Int64(start),
                                                   rangeEnd: Int64(end), cacheKey: "range-receipt", maxBytes: 200_000)
            let result = try await runtime.request(ReaderM2.runtimeHostSmokeMediaDownload, .init(params: model))
            let path = try XCTUnwrap(result.value.tempPath)
            let bytes = try Data(contentsOf: URL(filePath: path))
            let expected = Data((start...end).map { UInt8($0 % 256) })
            let checksum = SHA256.hash(data: expected).map { String(format: "%02x", $0) }.joined()
            XCTAssertEqual(bytes, expected)
            XCTAssertEqual(result.value.statusCode, 206)
            XCTAssertEqual(result.value.resourceId, "range-receipt")
            XCTAssertEqual(result.value.byteLength, Int64(bytes.count))
            XCTAssertEqual(result.value.sha256, checksum)
            let directory = URL(filePath: path).deletingLastPathComponent()
            let before = try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
            do {
                _ = try await runtime.request(ReaderM2.runtimeHostSmokeMediaDownload,
                    .init(params: .init(url: base + "/host/media", rangeStart: 0, rangeEnd: 255, maxBytes: 128)))
                XCTFail("Declared media budget must bound the output")
            } catch let error as CoreRequestFailure {
                XCTAssertEqual(error.m2Value.details?.host?.diagnostics?.code, .invalidResponse)
            }
            let cancellation = try await cancelAfterEntry(runtime, path: "/host/media-hold",
                rpc: ReaderM2.runtimeHostSmokeMediaDownload, params: .init(params: .init(
                    url: base + "/host/media-hold", maxBytes: 4_000_000, timeoutMillis: 20_000
                )))
            XCTAssertEqual(cancellation.m2Value.code, .cancelled)
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted(), before)
            print("M2_HOST_MEDIA range=\(start)...\(end) status=206 bytes=\(bytes.count) sha256=\(checksum) limit=INVALID_RESPONSE cancelledRequest=\(cancellation.id.requestId)")
        }
    }

    private func isolatedDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("reader-m2-host-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func withLibrary(
        directory suppliedDirectory: URL? = nil, _ exercise: (LibraryHost) async throws -> Void
    ) async throws {
        let directory = try suppliedDirectory ?? isolatedDirectory()
        defer { if suppliedDirectory == nil { try? FileManager.default.removeItem(at: directory) } }
        let library = try await LibraryHost.open(directory: directory)
        do { try await exercise(library) }
        catch {
            await library.runtime.close()
            throw error
        }
        await library.runtime.close()
    }

    private func javaScript(_ source: String, in view: WKWebView) async throws -> String? {
        try await withCheckedThrowingContinuation { continuation in
            view.evaluateJavaScript(source) { value, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: value as? String) }
            }
        }
    }

    private struct LoopbackState: Decodable {
        let counters: [String: Int]
    }

    private func loopbackState() async throws -> LoopbackState {
        let url = try XCTUnwrap(URL(string: base + "/control/state"))
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode(LoopbackState.self, from: data)
    }

    private func control(_ action: String, path: String) async throws {
        var components = try XCTUnwrap(URLComponents(string: base + "/control/" + action))
        components.queryItems = [URLQueryItem(name: "path", value: path)]
        if action == "configure" {
            components.queryItems?.append(URLQueryItem(name: "mode", value: "hold"))
        }
        var request = URLRequest(url: try XCTUnwrap(components.url))
        request.httpMethod = "POST"
        let (_, response) = try await URLSession.shared.data(for: request)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
    }

    private func cancelAfterEntry<P, V>(
        _ runtime: CoreRuntimeActor, path: String, rpc: ReaderRPC<P, V>, params: P
    ) async throws -> CoreRequestFailure {
        try await control("configure", path: path)
        let preceding = try await loopbackState().counters[path, default: 0]
        let before = await runtime.deliveries()
        let witness = AsyncStream<CoreOperationID>.makeStream()
        var terminalBeforeCancel = false
        let task = Task {
            defer { terminalBeforeCancel = true }
            return try await runtime.request(rpc, params) { id in
                witness.continuation.yield(id)
                witness.continuation.finish()
            }
        }
        do {
            try await eventually("loopback reached \(path) before cancellation") {
                if terminalBeforeCancel {
                    // Preserve a Core admission or transport error instead of
                    // reporting a generic server-arrival timeout.
                    _ = try await task.value
                    XCTFail("Host returned before cancellation at \(path)")
                    throw CocoaError(.userCancelled)
                }
                return try await self.loopbackState().counters[path, default: 0] > preceding
            }
            var ids = witness.stream.makeAsyncIterator()
            let id = await ids.next()
            let original = try XCTUnwrap(id)
            try await runtime.cancel(original)
            do {
                _ = try await task.value
                XCTFail("Original request must cancel")
                throw CocoaError(.userCancelled)
            } catch let failure as CoreRequestFailure {
                XCTAssertEqual(failure.id, original)
                // The physical request must relinquish its Host delivery while
                // the server's response is still held.
                try await eventually("original terminal and Host delivery ACK while \(path) is held") {
                    let after = await runtime.deliveries()
                    return after.acknowledgementCount == before.acknowledgementCount + 2 &&
                        after.terminalCount == before.terminalCount + 1
                }
                try await control("release", path: path)
                print("M2_HOST_CANCEL path=\(path) request=\(original.requestId) originalTerminalAndHostDeliveryAckedWhileServerHeld=true")
                return failure
            }
        } catch {
            witness.continuation.finish()
            try? await control("release", path: path)
            task.cancel()
            _ = await task.result
            throw error
        }
    }

    private func eventually(_ condition: String, _ predicate: () async throws -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while .now < deadline {
            if try await predicate() { return }
            try await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Timed out waiting for \(condition)")
        throw URLError(.timedOut)
    }
}
