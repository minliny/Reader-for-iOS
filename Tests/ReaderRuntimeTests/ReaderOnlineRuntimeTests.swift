import Combine
import CryptoKit
import Foundation
import Network
import Security
import SwiftUI
import UIKit
import XCTest
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

/// A real HTTP endpoint scoped to this App-hosted XCTest and IPv4 loopback.
private final class ReaderRefreshLoopbackProvider: @unchecked Sendable {
    struct Hit {
        let path: String
        let digest: String
    }

    private let listener: NWListener
    private let queue = DispatchQueue(label: "ReaderRefreshLoopbackProvider")
    private var chapter: String
    private var received: [Hit] = []

    init(chapter: String) throws {
        self.chapter = chapter
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        listener = try NWListener(using: parameters)
    }

    var port: UInt16? { listener.port?.rawValue }
    var hits: [Hit] { queue.sync { received } }

    func setChapter(_ response: String) { queue.sync { chapter = response } }
    func stop() { listener.cancel() }

    func start(ready: XCTestExpectation) {
        listener.stateUpdateHandler = { [weak self] state in
            if case .ready = state {
                self?.listener.stateUpdateHandler = nil
                ready.fulfill()
            }
        }
        listener.newConnectionHandler = { [weak self] connection in
            guard let self else { connection.cancel(); return }
            connection.start(queue: self.queue)
            self.queue.asyncAfter(deadline: .now() + 5) { connection.cancel() }
            self.receive(on: connection)
        }
        listener.start(queue: queue)
    }

    static func hash(_ body: String) -> String {
        SHA256.hash(data: Data(body.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private func receive(on connection: NWConnection, buffered: Data = Data()) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { [weak self] data, _, complete, error in
            guard let self, let data, error == nil else { connection.cancel(); return }
            let bytes = buffered + data
            guard bytes.count <= 16_384 else { connection.cancel(); return }
            let headerEnd = Data("\r\n\r\n".utf8)
            guard let end = bytes.range(of: headerEnd) else {
                if complete { connection.cancel() }
                else { self.receive(on: connection, buffered: bytes) }
                return
            }
            let headers = String(decoding: bytes[..<end.lowerBound], as: UTF8.self)
            let request = headers.components(separatedBy: "\r\n")[0].split(separator: " ")
            guard request.count == 3, request[0] == "GET" else { connection.cancel(); return }
            self.respond(on: connection, path: String(request[1]))
        }
    }

    private func respond(on connection: NWConnection, path: String) {
        let body: String
        let status: String
        switch path {
        case "/book":
            status = "200 OK"
            body = "<h1>阿Ｑ正傳</h1><span class='author'>魯迅</span><a class='toc' href='/toc'>目录</a>"
        case "/toc":
            status = "200 OK"
            body = "<ol class='toc'><li><a href='/chapter/0'>優勝記略</a></li></ol>"
        case "/chapter/0":
            status = "200 OK"
            body = chapter
        default:
            status = "404 Not Found"
            body = ""
        }
        received.append(Hit(path: path, digest: Self.hash(body)))
        let response = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\n"
            + "Cache-Control: no-store\r\nContent-Length: \(body.utf8.count)\r\nConnection: close\r\n\r\n" + body
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in connection.cancel() })
    }
}

final class ReaderOnlineRuntimeTests: XCTestCase {
    /// Anonymous live response only: no account, submitted form, fabricated
    /// Cookie, source import, or production library is used by this method.
    /// The URL/source identity are the original Baidu entry in the captured
    /// book_sources_20261024/book_sources_dedup.json (SHA256 1b681349...50e902c).
    @MainActor
    func testRealBaiduWebKitResponseCookiesSurviveLoginSaveAndKeychainReopen() async throws {
        let sourceID = "https://dushu.baidu.com/"
        let otherSourceID = "https://m.idejian.com"
        let loginURL = "https://wappass.baidu.com/password_login"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealLoginCookie-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let sourceURL = root.appendingPathComponent("Sources")
        let storageURL = root.appendingPathComponent("Core")
        let namespace = try ReaderHostLibraryIdentity.loadOrCreate(in: sourceURL.appendingPathComponent(".operations"))
        func hash(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "io.reader.minliny.source-cookies." + hash(namespace),
            kSecAttrAccount as String: hash(sourceID)]
        var readQuery = query; readQuery[kSecReturnData as String] = true
        var originalItem: CFTypeRef?
        let initialStatus = SecItemCopyMatching(readQuery as CFDictionary, &originalItem)
        guard initialStatus == errSecItemNotFound else {
            XCTFail("A fresh temporary library must have no existing credential item; no existing item was modified")
            throw ReaderLibraryError.invalidResponse("temporary login namespace was not empty")
        }
        // Installed-user credentials have a different preserved library UUID.
        // Delete only this admitted, previously absent service/account pair.
        defer {
            let status = SecItemDelete(query as CFDictionary)
            XCTAssertTrue(status == errSecSuccess || status == errSecItemNotFound,
                          "The exact temporary credential item must be removed")
            var remaining: CFTypeRef?
            XCTAssertEqual(SecItemCopyMatching(readQuery as CFDictionary, &remaining), errSecItemNotFound)
        }

        // Native attributes and private value hashes can be compared on failure
        // without exposing Cookie values in XCTest logs or attachments.
        func fingerprints(_ cookies: [HTTPCookie]) -> [String: String] {
            Dictionary(cookies.map { cookie in
                let identity = [cookie.domain, cookie.path, cookie.name].joined(separator: "\u{0}")
                let facts = [hash(cookie.value), String(cookie.isSecure), String(cookie.isHTTPOnly),
                    String(cookie.isSessionOnly), cookie.expiresDate.map { String($0.timeIntervalSince1970) } ?? "session",
                    cookie.properties?[HTTPCookiePropertyKey("SameSite")] as? String ?? ""]
                return (identity, facts.joined(separator: "\u{0}"))
            }, uniquingKeysWith: { _, last in last })
        }
        weak var originalService: ReaderLibraryService?
        weak var originalTransport: ReaderIOSHostTransport?
        var observedCookieNames: [String] = []
        var observedFinalPage = ""
        @MainActor
        func saveActualWebKitResponse() async throws -> [String: String] {
            let service = try ReaderLibraryService(storageURL: storageURL, sourceURL: sourceURL)
            originalService = service; originalTransport = await service.hostTransport
            do {
                let baseline = try await service.prepareLogin(sourceID)
                XCTAssertTrue(baseline.isEmpty)
                var receivedSnapshot: [HTTPCookie]?
                let result = try await ReaderSourceWebBridge.shared.evaluate([
                    "document": ["kind": "url", "url": loginURL],
                    "javaScript": "JSON.stringify({origin:location.origin,path:location.pathname})",
                    "timeoutMillis": 20000
                ], ownerID: UUID(), requestID: 1, cookies: baseline, cookieSink: { receivedSnapshot = $0 })
                let actual = try XCTUnwrap(receivedSnapshot, "The production WebKit allCookies callback must run")
                let baiduCookies = actual.filter { cookie in
                    let domain = cookie.domain.lowercased()
                    return domain == "baidu.com" || domain.hasSuffix(".baidu.com")
                }
                guard baiduCookies.contains(where: { $0.name == "BAIDUID" && !$0.value.isEmpty }) else {
                    XCTFail("The real page did not supply the observed anonymous BAIDUID prerequisite; no Cookie was injected")
                    throw ReaderLibraryError.invalidResponse("real upstream Cookie prerequisite not met")
                }
                let finalURL = try XCTUnwrap((result["finalUrl"] as? String).flatMap(URL.init(string:)))
                let finalHost = finalURL.host?.lowercased() ?? ""
                XCTAssertEqual(finalURL.scheme?.lowercased(), "https")
                XCTAssertTrue(finalHost == "baidu.com" || finalHost.hasSuffix(".baidu.com"),
                              "A different final origin cannot stand in for the original Baidu login page")
                // Query/fragment values and page content are never attached.
                observedFinalPage = (finalURL.scheme ?? "") + "://" + (finalURL.host ?? "") + finalURL.path
                observedCookieNames = Array(Set(actual.map(\.name))).sorted()
                let expected = fingerprints(actual)
                try await service.completeLogin(sourceID, cookies: actual, originalCookies: baseline)
                let published = try await service.prepareLogin(sourceID)
                XCTAssertEqual(fingerprints(published), expected)
                let isolated = try await service.prepareLogin(otherSourceID)
                XCTAssertTrue(isolated.isEmpty, "Another original source cannot read the saved Baidu Cookie jar")
                var stored: CFTypeRef?
                XCTAssertEqual(SecItemCopyMatching(readQuery as CFDictionary, &stored), errSecSuccess)
                XCTAssertFalse(try XCTUnwrap(stored as? Data).isEmpty, "Production completeLogin must create its durable Keychain item")
                try await service.close()
                return expected
            } catch { try? await service.close(); throw error }
        }
        let expected = try await saveActualWebKitResponse()
        // close() alone is insufficient: a live transport would retain the
        // weak-registry Cookie store and could hide a failed Keychain restore.
        XCTAssertNil(originalService)
        XCTAssertNil(originalTransport)
        guard originalService == nil, originalTransport == nil else {
            throw ReaderLibraryError.invalidResponse("original Cookie owner did not release")
        }
        @MainActor
        func reopenExactLibrary() async throws {
            let reopened = try ReaderLibraryService(storageURL: storageURL, sourceURL: sourceURL)
            do {
                let restored = try await reopened.prepareLogin(sourceID)
                XCTAssertEqual(fingerprints(restored), expected, "The released temporary library must restore the actual native Cookie snapshot from Keychain")
                let isolated = try await reopened.prepareLogin(otherSourceID)
                XCTAssertTrue(isolated.isEmpty)
                try await reopened.close()
            } catch { try? await reopened.close(); throw error }
        }
        try await reopenExactLibrary()
        let otherRoot = root.appendingPathComponent("OtherLibrary")
        let otherLibrary = try ReaderLibraryService(storageURL: otherRoot.appendingPathComponent("Core"), sourceURL: otherRoot.appendingPathComponent("Sources"))
        do {
            let isolated = try await otherLibrary.prepareLogin(sourceID)
            XCTAssertTrue(isolated.isEmpty, "A different preserved library identity cannot read the temporary Cookie item")
            try await otherLibrary.close()
        } catch { try? await otherLibrary.close(); throw error }
        let facts = try JSONSerialization.data(withJSONObject: [
            "sourceId": sourceID, "declaredLoginURL": loginURL, "actualFinalPage": observedFinalPage,
            "actualCookieNames": observedCookieNames, "cookieCount": expected.count,
            "scope": "anonymous real WebKit response -> production completeLogin -> released-owner Keychain reopen; no authenticated login or login sheet UI"
        ], options: [.sortedKeys])
        let attachment = XCTAttachment(data: facts, uniformTypeIdentifier: "public.json")
        attachment.name = "Actual-anonymous-WebKit-Cookie-Keychain-boundary"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testCancelledQueuedReadCannotReenterRetiredTransportWhileMutationAdmissionRemainsAvailable() async {
        let transport = ReaderIOSHostTransport(namespace: "read-admission:" + UUID().uuidString)
        // These are transport request identities, not synthetic sources or
        // fabricated Core Host envelopes. No network or Core reply is sent.
        transport.bind(requestID: 401, sourceID: nil)
        // No handler/job has entered yet: retireRead clears its idle state.
        transport.retireRead(requestID: 401)

        let queuedWorker = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            XCTAssertTrue(Task.isCancelled)
            XCTAssertFalse(transport.beginHostRequest(requestID: 401, cancellableRead: true),
                "A cancelled queued read must not restart Host work after retirement clears its state")

            // Mutation observers can end while their accepted Core/Host job
            // still owns its original work. The default admission preserves it.
            XCTAssertTrue(transport.beginHostRequest(requestID: 402),
                "An ended observer must not reject accepted mutation Host work")
            transport.endHostRequest(requestID: 402)
        }
        await queuedWorker.value
        // The old read cancellation does not reject an independent live read.
        XCTAssertTrue(transport.beginHostRequest(requestID: 403, cancellableRead: true))
        transport.endHostRequest(requestID: 403)
    }

    func testCancelledWebViewResultDoesNotCommitCookieChanges() throws {
        XCTAssertTrue(ReaderSourceWebBridge.shouldCommitCookies(for: .success([:])))
        XCTAssertTrue(ReaderSourceWebBridge.shouldCommitCookies(for: .failure(URLError(.timedOut))))
        XCTAssertFalse(ReaderSourceWebBridge.shouldCommitCookies(for: .failure(URLError(.cancelled))))
        XCTAssertFalse(ReaderSourceWebBridge.shouldCommitCookies(for: .failure(CancellationError())))
    }

    func testNativeHTTPReachesTheRealSourceOriginOrItsRedirect() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let definitions = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json"))) as? [[String: Any]])
        var address = try XCTUnwrap(URLComponents(string: try XCTUnwrap(definitions.first?["bookSourceUrl"] as? String)))
        address.scheme = "http"
        let url = try XCTUnwrap(address.url)
        let namespace = "real-http-policy:" + UUID().uuidString
        let sourceID = "source-package:" + (url.host ?? "")
        let hashedNamespace = SHA256.hash(data: Data(namespace.utf8)).map { String(format: "%02x", $0) }.joined()
        let hashedSource = SHA256.hash(data: Data(sourceID.utf8)).map { String(format: "%02x", $0) }.joined()
        defer {
            // A real origin may set Cookies. Remove only this test's random
            // Keychain identity; never touch the user's source credentials.
            let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "io.reader.minliny.source-cookies." + hashedNamespace,
                kSecAttrAccount as String: hashedSource] as CFDictionary)
            XCTAssertTrue(status == errSecSuccess || status == errSecItemNotFound)
        }
        let transport = ReaderIOSHostTransport(namespace: namespace)
        let response = try await transport.fetchPackage(at: url)
        XCTAssertTrue((100..<600).contains(response.status), "A real HTTP response, including a source rejection, proves transport reached the source; a fabricated successful body cannot substitute")
        let facts = try JSONSerialization.data(withJSONObject: ["requestURL": url.absoluteString, "status": response.status, "finalURL": response.finalUrl ?? ""], options: [.sortedKeys])
        let attachment = XCTAttachment(data: facts, uniformTypeIdentifier: "public.json")
        attachment.name = "Actual-native-HTTP-source-response"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testNativeCookieJarsAreSourceIsolatedAndRestoreOnlyWithinTheSameLibrary() throws {
        let namespace = "transport-test:" + UUID().uuidString
        let url = try XCTUnwrap(URL(string: "https://reader-cookie.invalid/"))
        let cookie = try XCTUnwrap(HTTPCookie(properties: [.domain: "reader-cookie.invalid", .path: "/", .name: "session", .value: "method-fixture", .secure: "TRUE"]))
        // Only this random test identity is removed. Production source entries
        // and the App's container data are outside this test's write scope.
        let hashedNamespace = SHA256.hash(data: Data(namespace.utf8)).map { String(format: "%02x", $0) }.joined()
        let hashedSource = SHA256.hash(data: Data("source-a".utf8)).map { String(format: "%02x", $0) }.joined()
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "io.reader.minliny.source-cookies." + hashedNamespace,
            kSecAttrAccount as String: hashedSource]
        func keychainData() throws -> Data {
            var read = query; read[kSecReturnData as String] = true
            var value: CFTypeRef?
            let status = SecItemCopyMatching(read as CFDictionary, &value)
            XCTAssertEqual(status, errSecSuccess)
            return try XCTUnwrap(value as? Data)
        }
        defer {
            let status = SecItemDelete(query as CFDictionary)
            XCTAssertTrue(status == errSecSuccess || status == errSecItemNotFound, "Random test namespace cleanup must complete")
        }
        // Release each transport/store before reopening. The namespace registry
        // is weak, so restoration must actually read Keychain, not live memory.
        weak var prior: ReaderIOSHostTransport?
        weak var priorPeer: ReaderIOSHostTransport?
        weak var priorCancelled: ReaderIOSHostTransport?
        do {
            let first = ReaderIOSHostTransport(namespace: namespace)
            prior = first
            let peer = ReaderIOSHostTransport(namespace: namespace)
            priorPeer = peer
            XCTAssertTrue(try peer.cookies(sourceID: "source-a").isEmpty)
            try first.commitCookieChanges(sourceID: "source-a", originalCookies: [], updatedCookies: [cookie])
            XCTAssertEqual(try first.cookies(sourceID: "source-a").count, 1)
            XCTAssertEqual(try peer.cookies(sourceID: "source-a").first?.value, cookie.value,
                "A peer that already loaded this namespace must observe the same commit owner")
            XCTAssertTrue(try first.cookies(sourceID: "source-b").isEmpty)
            let originalData = try keychainData()
            let baseline = try first.cookies(sourceID: "source-a")
            try first.commitCookieChanges(sourceID: "source-a", originalCookies: baseline, updatedCookies: baseline)
            XCTAssertEqual(try keychainData(), originalData, "A no-op must preserve the exact Keychain blob")

            weak var cancellingOwner: ReaderIOSHostTransport?
            let cancelled = ReaderIOSHostTransport(namespace: namespace, httpRunner: { _, jar, _ in
                jar.setCookie(try XCTUnwrap(HTTPCookie(properties: [.domain: cookie.domain, .path: "/", .name: cookie.name, .value: "cancelled-private-candidate", .secure: "TRUE"])))
                cancellingOwner?.cancel(requestID: 0)
                return ["status": 200, "body": ""]
            })
            cancellingOwner = cancelled
            priorCancelled = cancelled
            XCTAssertThrowsError(try cancelled.perform(ReaderCoreHostRequest(operationId: 1, capability: "http.execute",
                rawParams: ["url": url.absoluteString, "sessionId": "source-a"]))) { error in
                XCTAssertEqual((error as? URLError)?.code, .cancelled)
            }
            cancelled.finish(requestID: 0)
            XCTAssertEqual(try keychainData(), originalData, "A cancelled private candidate must leave Keychain bytes unchanged")
            XCTAssertEqual(try peer.cookies(sourceID: "source-a").first?.value, cookie.value)
        }
        XCTAssertNil(prior, "The first transport must release before testing Keychain restoration")
        XCTAssertNil(priorPeer)
        XCTAssertNil(priorCancelled)
        do {
            let reopened = ReaderIOSHostTransport(namespace: namespace)
            prior = reopened
            let baseline = try reopened.cookies(sourceID: "source-a")
            XCTAssertEqual(baseline.count, 1)
            let concurrent = try XCTUnwrap(HTTPCookie(properties: [.domain: "reader-cookie.invalid", .path: "/", .name: "concurrent-http", .value: "new-session", .secure: "TRUE"]))
            try reopened.commitCookieChanges(sourceID: "source-a", originalCookies: baseline, updatedCookies: baseline + [concurrent])
            try reopened.commitCookieChanges(sourceID: "source-a", originalCookies: baseline, updatedCookies: baseline)
            XCTAssertTrue(try reopened.cookies(sourceID: "source-a").contains(where: { $0.name == concurrent.name && $0.value == concurrent.value }),
                "An unchanged WebKit snapshot cannot erase a concurrent native HTTP cookie")
            let nativeParsed = try XCTUnwrap(HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "server=native-response; Path=/; Secure; HttpOnly"], for: url).first)
            let original = try reopened.cookies(sourceID: "source-a")
            try reopened.commitCookieChanges(sourceID: "source-a", originalCookies: original, updatedCookies: original + [nativeParsed])
            _ = try reopened.perform(ReaderCoreHostRequest(operationId: 2, capability: "cookie.set",
                rawParams: ["url": url.absoluteString, "sessionId": "source-a",
                            "cookie": ["name": "server", "value": "explicit-keychain-updated", "secure": true]]))
            let updated = try XCTUnwrap(reopened.cookies(sourceID: "source-a").first(where: { $0.name == "server" }))
            XCTAssertEqual(updated.value, "explicit-keychain-updated")
            XCTAssertTrue(updated.isHTTPOnly)
        }
        XCTAssertNil(prior, "The live shared store must release before the second Keychain restoration")
        let restoredAgain = ReaderIOSHostTransport(namespace: namespace)
        let restoredServer = try XCTUnwrap(restoredAgain.cookies(sourceID: "source-a").first(where: { $0.name == "server" }))
        XCTAssertEqual(restoredServer.value, "explicit-keychain-updated")
        XCTAssertTrue(restoredServer.isHTTPOnly)
        let anotherLibrary = ReaderIOSHostTransport(namespace: namespace + ":other")
        XCTAssertTrue(try anotherLibrary.cookies(sourceID: "source-a").isEmpty)
    }

    func testHTTPAndExplicitCookieWritesUseTheSameDurablePublicationBoundary() throws {
        let sourceID = "cookie-transport:" + UUID().uuidString
        let namespace = "cookie-transport-method:" + UUID().uuidString
        let url = try XCTUnwrap(URL(string: "https://reader-cookie.invalid/"))
        var durable: [HTTPCookie] = []
        var failSave = false
        var saveAttemptCount = 0
        let store = ReaderSourceCookieStore(load: { _ in durable }, save: { _, cookies in
            saveAttemptCount += 1
            if failSave { throw URLError(.cannotWriteToFile) }
            durable = cookies
        })
        let transport = ReaderIOSHostTransport(namespace: namespace, cookieStore: store, httpRunner: { params, jar, _ in
            let value = params["method"] as? String == "HEAD" ? "response-401" : "received-before-timeout"
            let cookie = try XCTUnwrap(HTTPCookie.cookies(withResponseHeaderFields:
                ["Set-Cookie": "session=\(value); Path=/; Secure; HttpOnly"], for: url).first)
            jar.setCookie(cookie)
            XCTAssertFalse(try store.snapshot(sourceID: sourceID).contains(where: { $0.value == value }),
                "The actual HTTP execution seam must receive a private jar")
            if params["method"] as? String != "HEAD" { throw URLError(.timedOut) }
            return ["status": 401, "body": "", "finalUrl": url.absoluteString]
        })
        // Method evidence only: this runner replaces network I/O; actual Host
        // staging/finalization and Foundation parsing still execute unchanged.
        let request: (String) -> ReaderCoreHostRequest = { method in
            ReaderCoreHostRequest(operationId: 1, capability: "http.execute",
                rawParams: ["url": url.absoluteString, "sessionId": sourceID, "method": method])
        }
        XCTAssertThrowsError(try transport.perform(request("GET"))) { error in
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
        XCTAssertEqual(try transport.cookies(sourceID: sourceID).first?.value, "received-before-timeout")
        XCTAssertEqual(durable.first?.value, "received-before-timeout")
        XCTAssertEqual(try transport.perform(request("HEAD")).status, 401)
        XCTAssertEqual(durable.first?.value, "response-401")

        _ = try transport.perform(ReaderCoreHostRequest(operationId: 2, capability: "cookie.set",
            rawParams: ["url": url.absoluteString, "sessionId": sourceID,
                        "cookie": ["name": "session", "value": "explicit-accepted", "secure": true]]))
        XCTAssertEqual(try transport.cookies(sourceID: sourceID).first?.value, "explicit-accepted")
        XCTAssertEqual(durable.first?.value, "explicit-accepted")
        XCTAssertTrue(try transport.cookies(sourceID: sourceID).first?.isHTTPOnly == true,
            "An omitted optional HttpOnly field must not downgrade the existing session")
        XCTAssertEqual(try transport.cookies(sourceID: sourceID).count, 1)

        let attemptsBeforeRejectedDowngrade = saveAttemptCount
        XCTAssertThrowsError(try transport.perform(ReaderCoreHostRequest(operationId: 3, capability: "cookie.set",
            rawParams: ["url": url.absoluteString, "sessionId": sourceID,
                        "cookie": ["name": "session", "value": "rejected-downgrade", "secure": true, "httpOnly": false]]))) { error in
            XCTAssertEqual((error as? ReaderHostFailure)?.code, "PERMISSION_DENIED")
        }
        XCTAssertEqual(saveAttemptCount, attemptsBeforeRejectedDowngrade)
        XCTAssertEqual(try transport.cookies(sourceID: sourceID).first?.value, "explicit-accepted")
        XCTAssertTrue(try transport.cookies(sourceID: sourceID).first?.isHTTPOnly == true)
        XCTAssertEqual(durable.first?.value, "explicit-accepted")

        failSave = true
        let attemptsBeforeFailure = saveAttemptCount
        XCTAssertThrowsError(try transport.perform(ReaderCoreHostRequest(operationId: 2, capability: "cookie.set",
            rawParams: ["url": url.absoluteString, "sessionId": sourceID,
                        "cookie": ["name": "session", "value": "not-persisted", "secure": true]]))) { error in
            XCTAssertEqual((error as? URLError)?.code, .cannotWriteToFile)
        }
        XCTAssertEqual(saveAttemptCount, attemptsBeforeFailure + 1)
        let original = try transport.cookies(sourceID: sourceID)
        XCTAssertThrowsError(try transport.commitCookieChanges(sourceID: sourceID, originalCookies: original, updatedCookies: [])) { error in
            XCTAssertEqual((error as? URLError)?.code, .cannotWriteToFile)
        }
        XCTAssertEqual(saveAttemptCount, attemptsBeforeFailure + 2)
        XCTAssertEqual(try transport.cookies(sourceID: sourceID).first?.value, "explicit-accepted")
        XCTAssertEqual(durable.first?.value, "explicit-accepted")
    }

    func testConcurrentHTTPTransportCancellationRespectsCookieCommitAdmission() throws {
        final class Outcome: @unchecked Sendable {
            private let lock = NSLock()
            private var result: Result<ReaderCoreHostResponse, Error>?
            func set(_ value: Result<ReaderCoreHostResponse, Error>) { lock.withLock { result = value } }
            func get() -> Result<ReaderCoreHostResponse, Error>? { lock.withLock { result } }
        }
        let url = try XCTUnwrap(URL(string: "https://reader-cookie.invalid/"))
        // Each run has an independent random identity and in-memory persistence.
        // The first pauses during I/O; the second pauses after commit admission.
        for cancelBeforeAdmission in [true, false] {
            let sourceID = "cookie-concurrency:" + UUID().uuidString
            let staged = DispatchSemaphore(value: 0), release = DispatchSemaphore(value: 0)
            let outcome = Outcome()
            var durable: [HTTPCookie] = []
            let store = ReaderSourceCookieStore(load: { _ in [] }, save: { _, cookies in
                if !cancelBeforeAdmission {
                    staged.signal()
                    guard release.wait(timeout: .now() + 5) == .success else { throw URLError(.timedOut) }
                }
                durable = cookies
            })
            let transport = ReaderIOSHostTransport(namespace: UUID().uuidString, cookieStore: store, httpRunner: { _, jar, _ in
                jar.setCookie(try XCTUnwrap(HTTPCookie.cookies(withResponseHeaderFields:
                    ["Set-Cookie": "session=accepted; Path=/; Secure"], for: url).first))
                if cancelBeforeAdmission {
                    staged.signal()
                    guard release.wait(timeout: .now() + 5) == .success else { throw URLError(.timedOut) }
                }
                return ["status": 200, "body": "", "finalUrl": url.absoluteString]
            })
            let finished = expectation(description: "HTTP cookie operation finished")
            DispatchQueue.global(qos: .userInitiated).async {
                outcome.set(Result { try transport.perform(ReaderCoreHostRequest(operationId: 1, capability: "http.execute",
                    rawParams: ["url": url.absoluteString, "sessionId": sourceID])) })
                finished.fulfill()
            }
            XCTAssertEqual(staged.wait(timeout: .now() + 5), .success)
            // This must return while save is blocked: cancel cannot take the
            // store lock or hold transport.lock while waiting on an operation.
            transport.cancel(requestID: 0)
            release.signal()
            wait(for: [finished], timeout: 5)
            let result = try XCTUnwrap(outcome.get())
            if cancelBeforeAdmission {
                XCTAssertThrowsError(try result.get()) { error in XCTAssertEqual((error as? URLError)?.code, .cancelled) }
                XCTAssertTrue(try transport.cookies(sourceID: sourceID).isEmpty)
                XCTAssertTrue(durable.isEmpty)
            } else {
                XCTAssertEqual(try result.get().status, 200)
                XCTAssertEqual(try transport.cookies(sourceID: sourceID).first?.value, "accepted")
                XCTAssertEqual(durable.first?.value, "accepted")
            }
            transport.finish(requestID: 0)
        }
    }

    func testImageHTTPFailureKeepsReceivedCookiesBeforeImageBusinessValidation() async throws {
        let sourceID = "cookie-image:" + UUID().uuidString
        let url = try XCTUnwrap(URL(string: "https://reader-cookie.invalid/cover"))
        var durable: [HTTPCookie] = []
        let store = ReaderSourceCookieStore(load: { _ in [] }, save: { _, cookies in durable = cookies })
        let transport = ReaderIOSHostTransport(namespace: UUID().uuidString, cookieStore: store, httpRunner: { _, jar, binary in
            XCTAssertTrue(binary)
            jar.setCookie(try XCTUnwrap(HTTPCookie.cookies(withResponseHeaderFields:
                ["Set-Cookie": "challenge=received; Path=/; Secure"], for: url).first))
            return ["status": 403, "bodyBytes": Data(), "finalUrl": url.absoluteString]
        })
        do {
            _ = try await transport.fetchImage(parameters: ["url": url.absoluteString], sourceID: sourceID)
            XCTFail("An HTTP rejection cannot become image bytes")
        } catch {
            XCTAssertEqual(try transport.cookies(sourceID: sourceID).first?.name, "challenge")
            XCTAssertEqual(durable.first?.name, "challenge")
        }
    }

    /// Real original source bytes exercise the Host DTO/finite receipt boundary.
    /// This method provides preview bytes explicitly and does not claim that a
    /// subscription URL was fetched or that an OS background task executed.
    func testOriginalSourcePackageManagementAndSubscriptionPlanUseActualCoreReceipts() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let package = try Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json"))
        XCTAssertEqual(SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined(), "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322")
        let definitions = try XCTUnwrap(JSONSerialization.jsonObject(with: package) as? [[String: Any]])
        let first = try XCTUnwrap(definitions.first)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealSourceManagement-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        do {
            let validation = try await service.validateSources(package)
            XCTAssertTrue(validation.allSatisfy(\.succeeded))
            let imported = try await service.importSources(JSONSerialization.data(withJSONObject: first), operationID: UUID().uuidString)
            XCTAssertTrue(imported.allSatisfy(\.succeeded))
            let initial = try await service.onlineSources()
            XCTAssertEqual(initial.count, 1)
            let subscription = ReaderSourceSubscription(id: 73, name: "原书源包方法验证", url: "https://m.idejian.com", type: 0, customOrder: 0, autoUpdate: false, update: 0)
            let putID = UUID().uuidString
            let saved = try await service.saveRuleSubscription(subscription, operationID: putID)
            let repeatedSave = try await service.saveRuleSubscription(subscription, operationID: putID)
            XCTAssertEqual(repeatedSave, saved)
            let parameters = try JSONSerialization.data(withJSONObject: ["subscriptionId": saved.id, "remoteJson": String(decoding: package, as: UTF8.self)])
            let data = try await service.performCoreCommand(method: "rule-sub.update.preview.v1", parameters: parameters)
            let plan = try JSONDecoder().decode(ReaderSubscriptionPlan.self, from: data)
            XCTAssertEqual(plan.subscriptionId, saved.id)
            XCTAssertTrue(plan.changes.contains(where: { $0.kind == "added" }))
            let safe = plan.changes.filter(\.safeToApply).map(\.sourceId)
            let applyID = UUID().uuidString
            let applied = try await service.applyRuleSubscription(plan, sourceIDs: safe, operationID: applyID)
            let repeated = try await service.applyRuleSubscription(plan, sourceIDs: safe, operationID: applyID)
            XCTAssertEqual(applied, repeated)
            let allSources = try await service.onlineSources()
            XCTAssertEqual(allSources.count, 2)
            let firstID = try XCTUnwrap(initial.first).id
            try await service.updateSource(firstID, enabled: false, operationID: UUID().uuidString)
            let changedSources = try await service.onlineSources()
            XCTAssertEqual(changedSources.first(where: { $0.id == firstID })?.enabled, false)
            let exported = try await service.exportSources(nil)
            XCTAssertEqual((try JSONSerialization.jsonObject(with: exported) as? [[String: Any]])?.count, 2)
            let second = try XCTUnwrap(changedSources.first(where: { $0.id != firstID }))
            try await service.deleteSource(second.id, operationID: UUID().uuidString)
            let remaining = try await service.onlineSources()
            XCTAssertEqual(remaining.map(\.id), [firstID])
            try await service.deleteRuleSubscription(saved, operationID: UUID().uuidString)
            let subscriptions = try await service.ruleSubscriptions()
            XCTAssertTrue(subscriptions.isEmpty)
            XCTAssertEqual(try Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json")), package)
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

    @MainActor
    func testLoopbackChangedChapterRefreshRemapsNativeAnchorAndExplicitRetry() async throws {
        executionTimeAllowance = 90
        let manager = FileManager.default
        let originalDigest = "997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38"
        let input = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 99_898, digest: originalDigest)
        let original = try Data(contentsOf: input)
        let paragraphs = try XCTUnwrap(String(data: original, encoding: .utf8))
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let first = try XCTUnwrap(paragraphs.firstIndex { $0.hasPrefix("阿Ｑ不獨是姓名籍貫有些渺茫") })
        let inserted = try XCTUnwrap(paragraphs.first { $0.hasPrefix("我要給阿Ｑ做正傳") })
        let passage = "在阿Ｑ耳朵裡彷彿在十里之外"
        let originalParagraphs = Array(paragraphs[first...].prefix(30))
        func html(_ prose: [String]) -> String {
            "<div class='content'>" + prose.map { paragraph in
                let escaped = paragraph.replacingOccurrences(of: "&", with: "&amp;")
                    .replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
                return "<p>" + escaped + "</p>"
            }.joined() + "</div>"
        }
        let initialHTML = html(originalParagraphs)
        let rejectedHTML = "<html><body><div class='unavailable'>本章暂时不可用</div></body></html>"
        let updatedHTML = html([inserted] + originalParagraphs)
        let provider = try ReaderRefreshLoopbackProvider(chapter: initialHTML)
        defer { provider.stop() }
        let ready = expectation(description: "ephemeral IPv4 loopback listener ready")
        provider.start(ready: ready)
        await fulfillment(of: [ready], timeout: 5)
        let port = try XCTUnwrap(provider.port, "Loopback listener must be bound before Core starts")
        let sourceID = "http://127.0.0.1:\(port)"
        let bookID = sourceID + "/book"
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderRefreshLoopback-" + UUID().uuidString)
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
            sourceURL: root.appendingPathComponent("Sources"))
        let model = ReaderApplicationModel(service: service, readingTimeStorageURL: root.appendingPathComponent("Time.json"))
        var evidence: [String: Any] = ["scope": "loopback HTTP to production iOS Host/Core/Model and mounted TextKit",
                                      "originalTXTSha256": originalDigest, "temporaryRoot": root.path]
        defer {
            evidence["http"] = provider.hits.map { ["path": $0.path, "responseSHA256": $0.digest] }
            if let data = try? JSONSerialization.data(withJSONObject: evidence, options: [.sortedKeys]) {
                let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
                attachment.name = "Loopback-explicit-refresh-failure-retry-and-native-anchor"
                attachment.lifetime = .keepAlways; add(attachment)
            }
        }
        func require(_ condition: @autoclosure () throws -> Bool, _ detail: String) throws {
            guard try condition() else { throw ReaderLibraryError.invalidResponse(detail) }
        }
        func scalar(in content: ReaderChapterContent) throws -> UInt64 {
            let match = try XCTUnwrap(content.content.range(of: passage))
            try require(!content.content[match.upperBound...].contains(passage), "The visible Core passage must be unique")
            return UInt64(content.content[..<match.lowerBound].unicodeScalars.count)
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let previousWindow = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        defer { window.isHidden = true; window.rootViewController = nil; previousWindow?.makeKey() }
        var publishedPositions: [UInt64] = []
        func textView(in view: UIView) -> UITextView? {
            if let text = view as? UITextView { return text }
            return view.subviews.lazy.compactMap { textView(in: $0) }.first
        }
        func mountAndVerify(_ session: ReaderActiveSession, stage: String) async throws {
            let ready = expectation(description: stage + " native TextKit position restored")
            var pending: XCTestExpectation? = ready
            let surface = ReaderTextSurface(content: session.content, scalarOffset: session.scalarOffset,
                restorationID: session.restorationID, fontSize: 18, lineHeight: 1.96,
                horizontalInset: 20, bottomInset: 24, paper: ReaderPaperPalette(theme: .day),
                positionChanged: { offset in
                    publishedPositions.append(offset)
                    model.recordVisibleOffset(offset, sessionID: session.id, restorationID: session.restorationID)
                }, centerTapped: {}, layoutReady: { pending?.fulfill(); pending = nil }, reducePageMotion: true)
            host.rootView = AnyView(surface.frame(width: window.bounds.width, height: window.bounds.height).ignoresSafeArea())
            host.view.setNeedsLayout()
            host.view.layoutIfNeeded()
            window.layoutIfNeeded()
            await fulfillment(of: [ready], timeout: 8)
            let text = try XCTUnwrap(textView(in: host.view))
            let projection = ReaderParagraphProjection(content: session.content.content)
            let displayed = (session.content.chapterTitle + "\n").utf16.count
                + projection.displayUTF16Offset(forSourceScalar: session.scalarOffset)
            let displayedPassage = NSRange(location: displayed, length: passage.utf16.count)
            try require(text.window === window && text.contentOffset.y > 0
                && NSMaxRange(displayedPassage) <= text.textStorage.length
                && (text.text as NSString).substring(with: displayedPassage) == passage,
                "The production UITextView must contain the exact mapped original prose off the first screen")
            let position = try XCTUnwrap(text.position(from: text.beginningOfDocument, offset: displayed))
            let caret = text.caretRect(for: position)
            let glyph = text.layoutManager.glyphIndexForCharacter(at: displayed)
            let line = text.layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
                .offsetBy(dx: text.textContainerInset.left, dy: text.textContainerInset.top)
            try require(caret.height > 0 && line.height > 0 && text.bounds.intersects(caret)
                && text.bounds.intersects(line) && window.bounds.intersects(text.convert(caret, to: window)),
                "The Core scalar caret and TextKit line must be on screen after " + stage)
            evidence[stage + "Native"] = ["scalar": session.scalarOffset, "viewport": String(describing: text.bounds),
                "caret": String(describing: caret), "line": String(describing: line)]
        }
        do {
            let definition: [String: Any] = ["bookSourceUrl": sourceID, "bookSourceName": "本地刷新验证",
                "bookSourceType": 0, "enabled": true,
                "ruleBookInfo": ["name": "h1@text", "author": "span.author@text", "tocUrl": "a.toc@href"],
                "ruleToc": ["chapterList": "ol.toc li", "chapterName": "a@text", "chapterUrl": "a@href"],
                "ruleContent": ["content": "div.content@html"]]
            let imports = try await service.importSources(JSONSerialization.data(withJSONObject: definition),
                operationID: UUID().uuidString)
            try require(imports.count == 1 && imports[0].succeeded, "The isolated loopback source must import")
            let detail = try await service.onlineDetail(.init(sourceId: sourceID, bookId: bookID, title: "阿Ｑ正傳"))
            try require(detail.chapters.count == 1 && detail.chapters.first?.url == sourceID + "/chapter/0",
                "The sole real HTTP TOC chapter must identify the requested loopback path")
            let book = try await service.addOnlineBook(detail, chapterIndex: detail.firstReadableIndex, operationID: UUID().uuidString)
            let oldContent = try await service.content(for: book, chapterIndex: detail.firstReadableIndex)
            let oldOffset = try scalar(in: oldContent)
            try require(oldOffset > 0 && oldContent.bodyVersion?.isEmpty == false && oldContent.processingVersion?.isEmpty == false,
                "Original Core document must provide a versioned, nonzero scalar position")
            let existing = try await service.progress(for: book)
            _ = try await service.saveProgress(for: book, content: oldContent, scalarOffset: oldOffset,
                expectedRevision: existing.progressRevision)
            let before = try await service.progress(for: book)
            let opened = expectation(description: "production Model reads the original stored Core scalar")
            let observation = model.$reader.compactMap { $0 }.first().sink { _ in opened.fulfill() }
            defer { observation.cancel() }
            model.open(book)
            await fulfillment(of: [opened], timeout: 15)
            let old = try XCTUnwrap(model.reader)
            try require(old.content == oldContent && old.scalarOffset == oldOffset && old.progressRevision == before.progressRevision
                && old.progressRevision?.isEmpty == false, "Production Model must adopt the original Core position and revision")
            try await mountAndVerify(old, stage: "original")
            let initialHits = provider.hits
            let initialChapterHits = initialHits.filter { $0.path == "/chapter/0" }
            try require(initialHits.contains { $0.path == "/book" } && initialHits.contains { $0.path == "/toc" }
                && !initialChapterHits.isEmpty && initialChapterHits.allSatisfy { $0.digest == ReaderRefreshLoopbackProvider.hash(initialHTML) },
                "Original detail, TOC and chapter must come from actual local HTTP responses")

            provider.setChapter(rejectedHTML)
            await model.refreshOnlineChapter(sessionID: old.id, restorationID: old.restorationID)
            let retained = try XCTUnwrap(model.reader)
            let protected = try await service.reconcileOnlineContent(for: book, chapterIndex: old.content.chapterIndex)
            let failedHits = provider.hits.filter { $0.path == "/chapter/0" }
            try require(failedHits.count == initialChapterHits.count + 1
                && failedHits.last?.digest == ReaderRefreshLoopbackProvider.hash(rejectedHTML),
                "One explicit failed HTTP response and cache-only reconciliation must never replay acquisition")
            try require(retained.id != old.id && retained.content == old.content && retained.scalarOffset == oldOffset
                && retained.progressRevision == before.progressRevision && protected.content == old.content
                && protected.progressSnapshot == before && !model.onlineChapterRefreshPending && !model.sourceSwitchFrozen
                && model.feedback?.contains("已保留当前正文") == true,
                "A definite failed refresh must preserve the old body, exact progress and usable session")
            try await mountAndVerify(retained, stage: "retained")
            evidence["failureFeedback"] = model.feedback

            provider.setChapter(updatedHTML)
            await model.refreshOnlineChapter(sessionID: retained.id, restorationID: retained.restorationID)
            let updated = try XCTUnwrap(model.reader)
            let remapped = try scalar(in: updated.content)
            let after = try await service.progress(for: book)
            let persisted = try XCTUnwrap(after.progress)
            let finalHits = provider.hits.filter { $0.path == "/chapter/0" }
            try require(finalHits.count == failedHits.count + 1
                && finalHits.last?.digest == ReaderRefreshLoopbackProvider.hash(updatedHTML),
                "One explicit retry must consume the different real HTTP response")
            try require(updated.id != retained.id && updated.content.chapterIndex == old.content.chapterIndex
                && updated.content.bodyVersion != old.content.bodyVersion && updated.content.bodyVersion?.isEmpty == false
                && updated.content.processingVersion?.isEmpty == false && updated.content.content != old.content.content
                && remapped > oldOffset && updated.scalarOffset == remapped,
                "The production replacement must install a new version and migrate to the same original prose")
            try require(persisted.chapterIndex == old.content.chapterIndex && persisted.chapterOffset == remapped
                && persisted.bodyVersion == updated.content.bodyVersion && persisted.processingVersion == updated.content.processingVersion
                && after.progressRevision == updated.progressRevision && after.progressRevision?.isEmpty == false
                && after.progressRevision != before.progressRevision && model.feedback == "本章已更新",
                "The visible Model session must carry the committed Core position and fresh progress revision")
            try await mountAndVerify(updated, stage: "updated")
            try require(publishedPositions.isEmpty, "Native restoration must not overwrite the Core remap")
            try require(try Data(contentsOf: input) == original, "The provisioned original must remain byte-identical")
            evidence["versions"] = ["beforeBody": old.content.bodyVersion ?? "", "afterBody": updated.content.bodyVersion ?? "",
                "beforeProcessing": old.content.processingVersion ?? "", "afterProcessing": updated.content.processingVersion ?? ""]
            evidence["status"] = "verified"
            host.rootView = AnyView(EmptyView())
            await model.closeReader()
            try await service.close()
            try manager.removeItem(at: root)
        } catch {
            evidence["status"] = "failed"
            evidence["error"] = String(describing: error)
            host.rootView = AnyView(EmptyView())
            await model.closeReader()
            try? await service.close()
            throw error
        }
    }

    /// These are original source definitions selected from the frozen real
    /// HarmonyOS package, not a synthetic successful HTTP/rule replay. Failures
    /// remain real failures and cannot be replaced by an in-process response.
    @MainActor
    func testRealBaiduCandidateRejectsDeclaredPreviewAndPreservesFreeBodyWithoutShelfAdmission() async throws {
        try await runRealBaiduCandidate(explicitRefresh: false)
    }

    @MainActor
    func testRealBaiduExplicitChapterRefreshUsesCoreMigrationAndFreshProgressBeforePreviewRefusal() async throws {
        try await runRealBaiduCandidate(explicitRefresh: true)
    }

    @MainActor
    private func runRealBaiduCandidate(explicitRefresh: Bool) async throws {
        executionTimeAllowance = 90
        let start = ContinuousClock.now, initialFailures = testRun?.failureCount ?? 0
        let expectedSHA = "1344379b0583a11d00320d56e1f1167cfeed258c54f689c888b1f68e3bd02d37"
        let sourceID = "https://dushu.baidu.com/"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealBaiduPreview-" + UUID().uuidString)
        let sourceURL = root.appendingPathComponent("Sources"), operations = sourceURL.appendingPathComponent(".operations")
        var service: ReaderLibraryService?, cookieQuery: [String: Any]?, identityBytes: Data?
        var stage = "candidate-input", candidateSHA = "NOT_READ", observations: [[String: Any]] = []
        var scenarioFailure: Error?, scenarioFailureStage: String?
        func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else { throw ReaderLibraryError.invalidResponse("\(stage): \(message)") }
        }
        func canonical(_ data: Data) throws -> Data {
            try JSONSerialization.data(withJSONObject: JSONSerialization.jsonObject(with: data), options: [.sortedKeys])
        }
        func attach(_ status: String, error: Error? = nil) throws {
            let elapsed = start.duration(to: .now).components
            var facts: [String: Any] = ["status": status, "stage": stage, "temporaryRoot": root.path,
                "candidateSha256": candidateSHA, "expectedCandidateSha256": expectedSHA,
                "elapsedSeconds": Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18,
                "observations": observations, "shelfAdmission": explicitRefresh ? "ISOLATED_EXPLICIT_ADMISSION" : "NOT_PERFORMED",
                "scope": "REAL_NETWORK_ISOLATED_CORE_HOST_ONLY_NOT_NATIVE_UI_OR_ENTITLEMENT"]
            if let error {
                facts["errorType"] = String(reflecting: type(of: error))
                if let failure = error as? ReaderLibraryError, case let .core(code, message, retryable, reason) = failure {
                    facts["coreError"] = ["code": code, "category": reason ?? "", "retryable": retryable,
                        "messageSha256": hash(Data(message.utf8))]
                }
            }
            let value = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys]),
                                      uniformTypeIdentifier: "public.json")
            value.name = "Actual-Baidu-candidate-free-body-and-preview-refusal"; value.lifetime = .keepAlways; add(value)
        }
        func cleanExactCredential() throws {
            guard let cookieQuery else { return }
            try require(try Data(contentsOf: operations.appendingPathComponent(ReaderHostLibraryIdentity.fileName)) == identityBytes,
                        "retain the original temporary namespace before exact credential cleanup")
            let deleted = SecItemDelete(cookieQuery as CFDictionary)
            var read = cookieQuery; read[kSecReturnData as String] = true
            var remaining: CFTypeRef?
            let status = SecItemCopyMatching(read as CFDictionary, &remaining)
            try require((deleted == errSecSuccess || deleted == errSecItemNotFound) && status == errSecItemNotFound,
                        "only the admitted temporary service/account pair may be removed")
        }
        do {
            let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
            let input = documents.appendingPathComponent("baidu-novel-preview-guard.json")
            let package = try Data(contentsOf: input); candidateSHA = hash(package)
            try require(candidateSHA == expectedSHA, "the explicit-import candidate must match its frozen original bytes")
            stage = "admit-private-cookie-pair-before-network"
            let namespace = try ReaderHostLibraryIdentity.loadOrCreate(in: operations)
            identityBytes = try Data(contentsOf: operations.appendingPathComponent(ReaderHostLibraryIdentity.fileName))
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "io.reader.minliny.source-cookies." + hash(Data(namespace.utf8)),
                kSecAttrAccount as String: hash(Data(sourceID.utf8))]
            var read = query; read[kSecReturnData as String] = true
            var prior: CFTypeRef?
            try require(SecItemCopyMatching(read as CFDictionary, &prior) == errSecItemNotFound,
                        "a pre-existing credential pair cannot be used or cleaned")
            cookieQuery = query
            let active = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: sourceURL)
            service = active
            let scenario = Task { @MainActor in
                stage = "import-real-candidate"
                try require(try await active.listBooks().isEmpty, "fresh isolated shelf")
                let imported = try await active.importSources(package, operationID: UUID().uuidString)
                try require(imported.count == 1 && imported.allSatisfy(\.succeeded), "original source import ACK")
                let sources = try await active.onlineSources()
                try require(sources.count == 1 && sources[0].id == sourceID && sources[0].enabled, "exact Baidu source identity")
                observations.append(["stage": stage, "sourceId": sourceID, "sourceVersion": sources[0].version])
                stage = "real-search-and-detail"
                let search = try await active.searchSource(sourceID, keyword: "等到鸢尾纯白", page: 1)
                observations.append(["stage": stage, "actualSearchCount": search.books.count, "elapsedMilliseconds": search.elapsedMilliseconds])
                let matches = search.books.filter { candidate in
                    guard candidate.sourceId == sourceID, candidate.title == "等到鸢尾纯白",
                          let url = URLComponents(string: candidate.bookId) else { return false }
                    return url.host == "boxnovel.baidu.com" && url.queryItems?.contains(where: {
                        $0.name == "bookid" && $0.value == "4345127024"
                    }) == true
                }
                try require(matches.count == 1, "one actual exact-title/book4345127024 search candidate")
                let candidate = try XCTUnwrap(matches.first)
                let detail = try await active.onlineDetail(candidate)
                var book = detail.book
                try require(book.sourceId == sourceID && book.bookId == candidate.bookId && detail.chapters.count == 50,
                            "actual matching50-chapter directory")
                for (index, vip) in [(UInt32(0), false), (19, false), (20, true), (36, true)] {
                    let chapter = try XCTUnwrap(detail.chapters.first { $0.index == index })
                    try require(chapter.isVip == vip && !chapter.url.isEmpty,
                                "source fee metadata must preserve the real row's navigation")
                    observations.append(["stage": stage, "chapterIndex": index, "isVip": vip, "navigable": true])
                }
                if explicitRefresh {
                    stage = "explicit-isolated-admission"
                    book = try await active.addOnlineBook(detail, chapterIndex: 0, operationID: UUID().uuidString)
                    try require(try await active.listBooks().map(\.id) == [book.id], "only the actual admitted book may enter this isolated shelf")
                }
                stage = "real-free-chapter0"
                let free = try await active.content(for: book, chapterIndex: 0)
                observations.append(["stage": stage, "actualVisibleScalars": free.scalarCount,
                    "actualVisibleSHA256": hash(Data(free.content.utf8)),
                    "bodyVersion": free.bodyVersion ?? "", "processingVersion": free.processingVersion ?? ""])
                // Retained f322 reader_documents proves this visible scope;
                // chapter_cache's 2232-scalar raw body is a different layer.
                try require(free.sourceId == sourceID && free.bookId == book.bookId && free.chapterIndex == 0 &&
                    free.scalarCount == 2098 &&
                    free.bodyVersion == "37a89892948c700d4a228a2ef9c12ca45d8f98e698d79f553341b1b05e983fe5" &&
                    free.processingVersion == "41ea864565d336ab3cd3f22dc4f3051e0389041238618bbeb52054431657adfa",
                    "the actual visible body and blocks must match the retained Core visible-document versions")
                if explicitRefresh {
                    stage = "explicit-current-chapter-refresh"
                    let before = try await active.progress(for: book)
                    _ = try await active.saveProgress(for: book, content: free, scalarOffset: 37,
                        expectedRevision: before.progressRevision)
                    let refreshed = try await active.refreshOnlineContent(for: book, current: free,
                        scalarOffset: 37, upgradeCachedContent: false)
                    try require(refreshed.content == free, "an actual unchanged free response retains its complete visible body/scope")
                    try require(refreshed.positionMigration.status == "unchanged" && !refreshed.positionMigration.isPartial,
                                "Core must report the actual unchanged-body migration")
                    try require(refreshed.positionMigration.anchors == [.init(id: "viewport", previousOffset: 37, offset: 37)],
                                "the original viewport anchor must come from Core")
                    let currentProgress = try await active.progress(for: book)
                    try require(refreshed.progressSnapshot.progress?.chapterOffset == 37 &&
                        refreshed.progressSnapshot == currentProgress,
                        "the adopted observation must be Core's current complete progress snapshot")
                    let reconciled = try await active.reconcileOnlineContent(for: book, chapterIndex: 0)
                    try require(reconciled.content == free && reconciled.progressSnapshot == refreshed.progressSnapshot,
                                "cache-only reconciliation must return the exact admitted scope and current CAS")
                    observations.append(["stage": stage, "migrationStatus": refreshed.positionMigration.status,
                        "anchorOffset": 37, "bodyVersion": refreshed.content.bodyVersion ?? "",
                        "processingVersion": refreshed.content.processingVersion ?? "", "freshProgressPaired": true,
                        "cacheOnlyReconciled": true, "fullBodyChanged": false])
                }
                let progress = try await active.progress(for: book)
                let cache = try canonical(await active.coreRead("cache.book.status", ["sourceId": sourceID, "bookId": book.bookId]))
                observations.append(["stage": stage, "bookIdSha256": hash(Data(book.bookId.utf8)),
                    "scalarCount": free.scalarCount, "bodySha256": hash(Data(free.content.utf8)),
                    "bodyVersion": free.bodyVersion ?? "", "processingVersion": free.processingVersion ?? "",
                    "cacheStatusSha256": hash(cache), "progressSha256": hash(try JSONEncoder().encode(progress))])
                stage = "real-preview-chapter36-must-refuse"
                var refused = false
                do {
                    let unexpected = try await active.content(for: book, chapterIndex: 36)
                    observations.append(["stage": stage, "unexpectedReturnedScalarCount": unexpected.scalarCount,
                        "unexpectedBodySha256": hash(Data(unexpected.content.utf8))])
                } catch let failure as ReaderLibraryError {
                    guard case let .core(code, message, retryable, reason) = failure else { throw failure }
                    let originalRefusal = message.contains("当前书源只返回试读内容，未取得完整正文")
                    observations.append(["stage": stage, "coreCode": code, "category": reason ?? "",
                        "retryable": retryable, "containsOriginalSourceRefusal": originalRefusal,
                        "messageSha256": hash(Data(message.utf8))])
                    try require(originalRefusal, "the actual Core error must preserve the original source refusal")
                    refused = true
                }
                try require(refused, "a97/100-scalar preview cannot return as a successful complete chapter")
                stage = "verify-original-free-cache-and-progress"
                try require(try await active.progress(for: book) == progress, "the complete prior progress must be unchanged")
                try require(try canonical(await active.coreRead("cache.book.status", ["sourceId": sourceID, "bookId": book.bookId])) == cache,
                            "failed preview must not change the original cache inventory")
                try require(try await active.content(for: book, chapterIndex: 0) == free, "the original free body and versions must remain exact")
                let finalBooks = try await active.listBooks()
                try require(explicitRefresh ? finalBooks.map(\.id) == [book.id] : finalBooks.isEmpty,
                            "the method may retain only its own explicitly admitted shelf book")
                try require(try await active.pendingFeatureOperations().isEmpty, "no original feature mutation may remain pending")
                try require(hash(Data(contentsOf: input)) == expectedSHA, "candidate input bytes must remain unchanged")
            }
            // This cancels only the owned read scenario; accepted Core/HTTP
            // results are never replaced by synthetic timeout responses.
            let deadline = Task { @MainActor in
                do { try await Task.sleep(until: start.advanced(by: .seconds(90)), clock: .continuous); scenario.cancel() }
                catch { }
            }
            do { try await scenario.value; deadline.cancel() }
            catch { deadline.cancel(); scenario.cancel(); throw error }
        } catch { scenarioFailure = error; scenarioFailureStage = stage }
        do {
            // A failed close retains both directory and namespace; do not
            // delete credentials while their original transport can still run.
            if let service { try await service.close() }
            stage = "exact-private-cleanup"
            try cleanExactCredential()
        } catch {
            observations.append(["stage": "exact-private-cleanup", "succeeded": false])
            if scenarioFailure == nil { scenarioFailure = error; scenarioFailureStage = stage }
        }
        if let scenarioFailure {
            stage = scenarioFailureStage ?? stage
            try? attach("FAIL_OWNED_LIBRARY_PRESERVED", error: scenarioFailure)
            throw scenarioFailure
        }
        do {
            try require((testRun?.failureCount ?? initialFailures) == initialFailures, "any XCTest failure must retain the owned root")
            try attach("REAL_CORE_ASSERTIONS_CONFIRMED_BEFORE_OWNED_ROOT_REMOVAL")
            try FileManager.default.removeItem(at: root)
        } catch {
            // Keep the same UUID ownership if recursive removal only removed
            // some children. Never overwrite a changed identity.
            if let identityBytes {
                try? FileManager.default.createDirectory(at: operations, withIntermediateDirectories: true)
                let identityURL = operations.appendingPathComponent(ReaderHostLibraryIdentity.fileName)
                if !FileManager.default.fileExists(atPath: identityURL.path) {
                    try? identityBytes.write(to: identityURL, options: .withoutOverwriting)
                }
            }
            try? attach("FAIL_OWNED_LIBRARY_PRESERVED", error: error)
            throw error
        }
    }

    func testRealStoredSourcesSearchDetailShelfAndCachedBody() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let package = try Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json"))
        func hash(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
        let packageSHA256 = SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined()
        let expectedPackageSHA256 = "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
        XCTAssertEqual(packageSHA256, expectedPackageSHA256)
        guard packageSHA256 == expectedPackageSHA256 else {
            throw ReaderLibraryError.invalidResponse("original real source package identity changed")
        }
        let manager = FileManager.default
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealOnline-" + UUID().uuidString)
        let sourceURL = root.appendingPathComponent("Sources")
        let operationsURL = sourceURL.appendingPathComponent(".operations")
        var runtimes: [ReaderLibraryService] = []
        var namespace: String?
        var identityBytes: Data?
        var admittedCookiePairs: [(sourceID: String, query: [String: Any])] = []
        var keychainAdmissionFailed = false
        func cleanupFailure(_ detail: String) -> ReaderLibraryError {
            let attachment = XCTAttachment(string: "temporaryRoot=\(root.path)\nnamespace=\(namespace ?? "uncreated")\n\(detail)")
            attachment.name = "Real-source-temporary-cleanup-failure"
            attachment.lifetime = .keepAlways; add(attachment)
            XCTFail("Temporary library cleanup failed; preserve its directory and identity at \(root.path): \(detail)")
            return .invalidResponse("real-source temporary cleanup failed")
        }
        func cleanupTemporaryLibrary() async throws {
            let runtimeCount = runtimes.count
            var closeFailures: [String] = []
            for (index, runtime) in runtimes.enumerated() {
                do { try await runtime.close() }
                catch { closeFailures.append("runtime[\(index)] close: \(error)") }
            }
            guard closeFailures.isEmpty else { throw cleanupFailure(closeFailures.joined(separator: "\n")) }
            runtimes.removeAll()
            guard !keychainAdmissionFailed else {
                throw cleanupFailure("An exact temporary credential pair was not admitted as originally absent; no credential or directory was deleted")
            }
            if namespace != nil {
                let currentIdentity: Data
                do {
                    currentIdentity = try Data(contentsOf: operationsURL.appendingPathComponent(ReaderHostLibraryIdentity.fileName))
                } catch {
                    throw cleanupFailure("The temporary library identity could not be verified: \(error)")
                }
                guard let identityBytes, currentIdentity == identityBytes else {
                    throw cleanupFailure("The temporary library identity changed before cleanup")
                }
            }
            var cookieFailures: [String] = []
            for pair in admittedCookiePairs {
                // Only pairs proven absent before this method's first network
                // call are owned here. Never delete a whole Keychain service.
                let deleted = SecItemDelete(pair.query as CFDictionary)
                var readQuery = pair.query; readQuery[kSecReturnData as String] = true
                var remaining: CFTypeRef?
                let read = SecItemCopyMatching(readQuery as CFDictionary, &remaining)
                if (deleted != errSecSuccess && deleted != errSecItemNotFound) || read != errSecItemNotFound {
                    cookieFailures.append("source=\(pair.sourceID) deleteStatus=\(deleted) postreadStatus=\(read)")
                }
            }
            guard cookieFailures.isEmpty else { throw cleanupFailure(cookieFailures.joined(separator: "\n")) }
            do {
                if manager.fileExists(atPath: root.path) { try manager.removeItem(at: root) }
                guard !manager.fileExists(atPath: root.path) else {
                    throw ReaderLibraryError.invalidResponse("temporary library still exists after removal")
                }
            } catch {
                let removalError = error
                // Recursive removal can fail after deleting some children.
                // Restore only this UUID root's exact original identity so a
                // retained partial directory is still attributable to this run.
                if let identityBytes {
                    do {
                        try manager.createDirectory(at: operationsURL, withIntermediateDirectories: true)
                        let identityURL = operationsURL.appendingPathComponent(ReaderHostLibraryIdentity.fileName)
                        if manager.fileExists(atPath: identityURL.path) {
                            guard try Data(contentsOf: identityURL) == identityBytes else {
                                throw ReaderLibraryError.invalidResponse("retained temporary identity differs; it was not overwritten")
                            }
                        } else { try identityBytes.write(to: identityURL, options: .withoutOverwriting) }
                    } catch {
                        throw cleanupFailure("Directory removal failed: \(removalError); exact temporary identity restoration also failed: \(error)")
                    }
                }
                throw cleanupFailure("Directory removal did not complete; temporary identity retained: \(removalError)")
            }
            let attachment = XCTAttachment(string: "closedRuntimes=\(runtimeCount)\nexactCredentialPairsAbsent=\(admittedCookiePairs.count)\ntemporaryRootRemoved=true")
            attachment.name = "Real-source-temporary-cleanup-complete"
            attachment.lifetime = .keepAlways; add(attachment)
        }
        var scenarioFailure: Error?
        do {
            namespace = try ReaderHostLibraryIdentity.loadOrCreate(in: operationsURL)
            identityBytes = try Data(contentsOf: operationsURL.appendingPathComponent(ReaderHostLibraryIdentity.fileName))
            let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: sourceURL)
            runtimes.append(service)
            let imported = try await service.importSources(package, operationID: UUID().uuidString)
            XCTAssertEqual(imported.count, 2)
            XCTAssertTrue(imported.allSatisfy(\.succeeded), "Real source import must preserve the original terminal facts")
            let sources = try await service.onlineSources().filter(\.enabled)
            XCTAssertEqual(sources.count, 2)
            let credentialService = "io.reader.minliny.source-cookies." + hash(try XCTUnwrap(namespace))
            for sourceID in Set(sources.map(\.id)).sorted() {
                let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: credentialService, kSecAttrAccount as String: hash(sourceID)]
                var readQuery = query; readQuery[kSecReturnData as String] = true
                var originalItem: CFTypeRef?
                let initialStatus = SecItemCopyMatching(readQuery as CFDictionary, &originalItem)
                guard initialStatus == errSecItemNotFound else {
                    keychainAdmissionFailed = true
                    XCTFail("An exact fresh temporary credential pair must be absent before networking; status=\(initialStatus)")
                    throw ReaderLibraryError.invalidResponse("temporary source credential pair was not empty")
                }
                admittedCookiePairs.append((sourceID, query))
            }
            var successful: ReaderOnlineCandidate?
            var outcomes: [[String: Any]] = []
            for source in sources {
                do {
                    let result = try await service.searchSource(source.id, keyword: "剑来", page: 1)
                    outcomes.append(["sourceId": source.id, "count": result.books.count, "elapsedMilliseconds": result.elapsedMilliseconds])
                    if successful == nil { successful = result.books.first }
                } catch { outcomes.append(["sourceId": source.id, "failure": error.localizedDescription]) }
            }
            let diagnostic = try JSONSerialization.data(withJSONObject: outcomes, options: [.prettyPrinted, .sortedKeys])
            let attachment = XCTAttachment(data: diagnostic, uniformTypeIdentifier: "public.json")
            attachment.name = "Actual-source-search-outcomes"; attachment.lifetime = .keepAlways; add(attachment)
            let candidate = try XCTUnwrap(successful, "At least one actual source must return a real candidate; no fixture fallback")
            let detail = try await service.onlineDetail(candidate)
            XCTAssertFalse(detail.chapters.isEmpty)
            let book = try await service.addOnlineBook(detail, chapterIndex: detail.firstReadableIndex, operationID: UUID().uuidString)
            XCTAssertEqual(book.sourceId, candidate.sourceId); XCTAssertEqual(book.bookId, candidate.bookId)
            let otherChapter = try XCTUnwrap(detail.chapters.dropFirst(3).first(where: { !$0.url.isEmpty && $0.index != detail.firstReadableIndex && $0.index < UInt32.max }))
            do {
                _ = try await service.performCoreCommand(method: "chapter.content", parameters: JSONSerialization.data(withJSONObject: [
                    "sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": otherChapter.index,
                    "chapterTitle": "", "cacheOnly": true
                ]))
                XCTFail("A real chapter outside the admission/cache window must not be reported as cached")
            } catch let error as ReaderLibraryError {
                guard case .core(let code, let message, _, let reason) = error else {
                    XCTFail("Expected the Core cache-missing category, received \(error)"); throw error
                }
                XCTAssertEqual(reason, "CACHE_MISSING", "Core cache-only failure category was lost: code=\(code) message=\(message)")
            }
            let content = try await service.content(for: book, chapterIndex: detail.firstReadableIndex)
            XCTAssertFalse(content.content.isEmpty); XCTAssertNotNil(content.bodyVersion); XCTAssertNotNil(content.processingVersion)
            let cached = try await service.performCoreCommand(method: "chapter.content", parameters: JSONSerialization.data(withJSONObject: ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": detail.firstReadableIndex, "chapterTitle": "", "cacheOnly": true]))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: cached) as? [String: Any])
            XCTAssertEqual(object["via"] as? String, "cache")
            XCTAssertEqual(object["content"] as? String, content.content)
            let progress = try await service.progress(for: book)
            let saved = try await service.saveProgress(for: book, content: content, scalarOffset: min(37, content.scalarCount), expectedRevision: progress.progressRevision)
            XCTAssertEqual(saved.progress?.sourceId, candidate.sourceId)
            let downloadID = UUID().uuidString
            let downloaded = try await service.downloadChapters(book, range: otherChapter.index..<(otherChapter.index + 1), operationID: downloadID)
            XCTAssertTrue(downloaded.materializations.contains(where: { $0.chapterIndex == otherChapter.index && !$0.token.isEmpty }))
            let downloadedStatus = try await service.readerDownloadStatus(book)
            XCTAssertEqual(downloadedStatus.chapters.first(where: { $0.chapterIndex == otherChapter.index })?.state, .completed,
                "A prefetch terminal alone cannot complete a download; its original resource lease must be reported")
            try await service.close()
            let reopened = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
            runtimes.append(reopened)
            do {
                let restored = try await reopened.progress(for: book)
                XCTAssertEqual(restored.progress?.chapterOffset, saved.progress?.chapterOffset)
                let toc = try await reopened.chapters(for: book)
                XCTAssertFalse(toc.isEmpty)
                let offline = try await reopened.performCoreCommand(method: "chapter.content", parameters: JSONSerialization.data(withJSONObject: ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": detail.firstReadableIndex, "chapterTitle": "", "cacheOnly": true]))
                XCTAssertEqual((try JSONSerialization.jsonObject(with: offline) as? [String: Any])?["content"] as? String, content.content)
                let coldDownload = try await reopened.readerDownloadStatus(book)
                XCTAssertEqual(coldDownload.chapters.first(where: { $0.chapterIndex == otherChapter.index })?.state, .completed)
                let downloadedBody = try await reopened.cachedDownloadBody(book, chapter: otherChapter.index)
                XCTAssertFalse(downloadedBody.content.isEmpty)
                // This temporary library uses the original source package and a
                // genuinely downloaded chapter. Automatic cleanup must honor the
                // completed task under Core's current inventory, while explicit
                // chapter clear below remains a separate user intent.
                let completedIdentity = ReaderCachedChapterIdentity(book: book, chapterIndex: otherChapter.index)
                let currentIdentity = ReaderCachedChapterIdentity(book: book, chapterIndex: detail.firstReadableIndex)
                // Use another actual catalog chapter outside the current
                // reading window. A normal content read creates automatic
                // cache without a download task or a position update.
                let automaticChapter = try XCTUnwrap(coldDownload.chapters.first(where: {
                    $0.navigable != false && !$0.url.isEmpty && $0.state == .missing &&
                    $0.chapterIndex != otherChapter.index &&
                    UInt64($0.chapterIndex) > UInt64(detail.firstReadableIndex) + 2
                }), "The original source must supply a separate uncached real chapter; do not manufacture one")
                let automaticIdentity = ReaderCachedChapterIdentity(book: book, chapterIndex: automaticChapter.chapterIndex)
                let automaticBody = try await reopened.content(for: book, chapterIndex: automaticChapter.chapterIndex)
                XCTAssertFalse(automaticBody.content.isEmpty)
                XCTAssertNotNil(automaticBody.bodyVersion); XCTAssertNotNil(automaticBody.processingVersion)
                let beforeCleanupStatus = try await reopened.readerDownloadStatus(book)
                let automaticRow = try XCTUnwrap(beforeCleanupStatus.chapters.first(where: {
                    $0.chapterIndex == automaticChapter.chapterIndex
                }))
                let storage = try await reopened.readerStorageSummary(protected: [currentIdentity])
                XCTAssertTrue(storage.completedQueueChapters.contains(completedIdentity))
                XCTAssertGreaterThan(storage.retainedBytes, 0)
                let cachedRows = beforeCleanupStatus.chapters.filter { $0.cachedBytes > 0 }
                let cleanableIdentities = cachedRows.map {
                    ReaderCachedChapterIdentity(book: book, chapterIndex: $0.chapterIndex)
                }.filter { !storage.protectedChapters.contains($0) }
                let preconditions: [String: Any] = [
                    "sourceId": book.sourceId, "bookId": book.bookId,
                    "automaticChapterIndex": automaticChapter.chapterIndex,
                    "automaticState": automaticRow.state.rawValue,
                    "automaticCachedBytes": automaticRow.cachedBytes,
                    "summaryCleanableBytes": storage.cleanableBytes,
                    "expectedCleanableChapterIndexes": cleanableIdentities.map(\.chapterIndex),
                    "currentChapterIndex": detail.firstReadableIndex,
                    "completedChapterIndex": otherChapter.index,
                    "boundary": "Only this fresh temporary library is inspected; cleanup must have exactly one real automatic chapter."
                ]
                let preconditionAttachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: preconditions,
                    options: [.sortedKeys]), uniformTypeIdentifier: "public.json")
                preconditionAttachment.name = "Real-source-temporary-automatic-cache-preconditions"
                preconditionAttachment.lifetime = .keepAlways; add(preconditionAttachment)
                guard automaticRow.state == .cached, automaticRow.cachedBytes > 0,
                      automaticBody.bodyVersion != nil, automaticBody.processingVersion != nil,
                      !storage.completedQueueChapters.contains(automaticIdentity),
                      !storage.protectedChapters.contains(automaticIdentity),
                      Set(cleanableIdentities) == Set([automaticIdentity]),
                      storage.cleanableBytes == automaticRow.cachedBytes,
                      storage.totalBytes == cachedRows.reduce(UInt64(0), { $0 + $1.cachedBytes }),
                      !storage.hasMore, !storage.completedQueueHasMore, storage.cleanupError == nil else {
                    XCTFail("Real automatic-cache identity and complete cleanable inventory must be proven before cleanup")
                    throw ReaderLibraryError.invalidResponse("real automatic cleanup prerequisite")
                }
                let cleanup = try await reopened.cleanupReaderStorage(retained: [], protected: [currentIdentity],
                    operationID: UUID().uuidString)
                XCTAssertEqual(Set(cleanup.removedChapters), Set([automaticIdentity]))
                XCTAssertEqual(cleanup.removedContentBytes, automaticRow.cachedBytes)
                XCTAssertFalse(cleanup.hasMore); XCTAssertNil(cleanup.cleanupError)
                XCTAssertFalse(cleanup.removedChapters.contains(completedIdentity))
                let afterCleanupStatus = try await reopened.readerDownloadStatus(book)
                let removedAutomatic = try XCTUnwrap(afterCleanupStatus.chapters.first(where: {
                    $0.chapterIndex == automaticChapter.chapterIndex
                }))
                XCTAssertEqual(removedAutomatic.state, .missing)
                XCTAssertEqual(removedAutomatic.cachedBytes, 0)
                XCTAssertEqual(afterCleanupStatus.chapters.first(where: { $0.chapterIndex == otherChapter.index })?.state,
                    .completed)
                let afterCleanupBody = try await reopened.cachedDownloadBody(book, chapter: otherChapter.index)
                XCTAssertEqual(afterCleanupBody.content, downloadedBody.content)
                let afterAutomaticCleanupProgress = try await reopened.progress(for: book)
                XCTAssertEqual(afterAutomaticCleanupProgress.progress, restored.progress)
                let protectedCurrentBody = try await reopened.cachedDownloadBody(book, chapter: detail.firstReadableIndex)
                XCTAssertEqual(protectedCurrentBody.content, content.content)
                let clearID = UUID().uuidString
                try await reopened.clearDownloadedChapter(book, chapterIndex: otherChapter.index, operationID: clearID)
                let cleared = try await reopened.readerDownloadStatus(book)
                XCTAssertEqual(cleared.chapters.first(where: { $0.chapterIndex == otherChapter.index })?.state, .missing)
                let afterClear = try await reopened.progress(for: book)
                XCTAssertEqual(afterClear.progress, restored.progress)
                let retainedBody = try await reopened.cachedDownloadBody(book, chapter: detail.firstReadableIndex)
                XCTAssertEqual(retainedBody.content, content.content)
                // Reopening the exact completed owner must not enqueue again after
                // an explicit later clear, or reinterpret fresh state as its ACK.
                _ = try await reopened.downloadChapters(book, range: otherChapter.index..<(otherChapter.index + 1), operationID: downloadID)
                try await reopened.clearDownloadedChapter(book, chapterIndex: otherChapter.index, operationID: clearID)
                let afterReplay = try await reopened.readerDownloadStatus(book)
                XCTAssertEqual(afterReplay.chapters.first(where: { $0.chapterIndex == otherChapter.index })?.state, .missing)
                let facts: [String: Any] = [
                    "sourceId": book.sourceId, "bookId": book.bookId,
                    "downloadedChapterIndex": otherChapter.index,
                    "downloadedBodySHA256": SHA256.hash(data: Data(downloadedBody.content.utf8))
                        .map { String(format: "%02x", $0) }.joined(),
                    "automaticChapterIndex": automaticChapter.chapterIndex,
                    "automaticBodySHA256": SHA256.hash(data: Data(automaticBody.content.utf8))
                        .map { String(format: "%02x", $0) }.joined(),
                    "automaticCachedBytesBeforeCleanup": automaticRow.cachedBytes,
                    "summaryCleanableBytes": storage.cleanableBytes,
                    "summaryRetainedBytes": storage.retainedBytes,
                    "cleanupRemovedChapterIndexes": cleanup.removedChapters.map(\.chapterIndex),
                    "cleanupRemovedContentBytes": cleanup.removedContentBytes,
                    "automaticMissingAfterCleanup": removedAutomatic.state == .missing && removedAutomatic.cachedBytes == 0,
                    "currentBodyAndProgressPreservedAfterAutomaticCleanup":
                        protectedCurrentBody.content == content.content && afterAutomaticCleanupProgress.progress == restored.progress,
                    "completedStillPresentAfterCleanup": afterCleanupStatus.chapters
                        .first(where: { $0.chapterIndex == otherChapter.index })?.state == .completed,
                    "explicitClearAndOriginalReplayRemainMissing": afterReplay.chapters
                        .first(where: { $0.chapterIndex == otherChapter.index })?.state == .missing,
                    "boundary": "Original saved source package and real downloaded chapter in an isolated temporary library; no installed user download is cleared."
                ]
                let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys]),
                    uniformTypeIdentifier: "public.json")
                attachment.name = "Real-source-temporary-download-cleanup-boundary"
                attachment.lifetime = .keepAlways; add(attachment)
            }
        } catch { scenarioFailure = error }
        do { try await cleanupTemporaryLibrary() }
        catch {
            if let scenarioFailure { XCTFail("The real-source scenario also failed before teardown: \(scenarioFailure)") }
            throw error
        }
        if let scenarioFailure { throw scenarioFailure }
    }
}
