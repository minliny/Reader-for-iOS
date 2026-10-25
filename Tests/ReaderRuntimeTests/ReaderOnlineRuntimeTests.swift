import CryptoKit
import Foundation
import Security
import XCTest
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderOnlineRuntimeTests: XCTestCase {
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

    /// These are original source definitions selected from the frozen real
    /// HarmonyOS package, not a synthetic successful HTTP/rule replay. Failures
    /// remain real failures and cannot be replaced by an in-process response.
    func testRealStoredSourcesSearchDetailShelfAndCachedBody() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let package = try Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json"))
        XCTAssertEqual(SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined(), "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealOnline-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        do {
            let imported = try await service.importSources(package, operationID: UUID().uuidString)
            XCTAssertEqual(imported.count, 2)
            XCTAssertTrue(imported.allSatisfy(\.succeeded), "Real source import must preserve the original terminal facts")
            let sources = try await service.onlineSources().filter(\.enabled)
            XCTAssertEqual(sources.count, 2)
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
                    XCTFail("Expected the Core cache-missing category, received \(error)"); return
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
            try await reopened.close()
        } catch { try? await service.close(); throw error }
    }
}
