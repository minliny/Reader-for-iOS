import Foundation
import XCTest
#if !READER_COOKIE_METHOD_TESTS
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif
#endif

/// These cases execute the production Cookie store with Foundation Cookie jars.
/// Injected persistence makes failure and commit ordering deterministic; no
/// network, real credentials, Keychain, or device acceptance is claimed here.
final class ReaderSourceCookieStoreTests: XCTestCase {
    private final class Persistence {
        var records: [String: [HTTPCookie]] = [:]
        var failLoad = false
        var failSave = false
        var beforeSave: (() -> Void)?

        func load(_ sourceID: String) throws -> [HTTPCookie] {
            if failLoad { throw ProbeError.load }
            return records[sourceID] ?? []
        }

        func save(_ sourceID: String, _ cookies: [HTTPCookie]) throws {
            beforeSave?()
            if failSave { throw ProbeError.save }
            records[sourceID] = cookies
        }

        func makeStore(namespace: String) -> ReaderSourceCookieStore {
            ReaderSourceCookieStore.shared(namespace: namespace, load: load, save: save)
        }
    }

    private enum ProbeError: Error { case load, save }

    private func cookie(_ name: String, _ value: String, httpOnly: Bool = true) throws -> HTTPCookie {
        let url = try XCTUnwrap(URL(string: "https://reader-cookie.invalid/"))
        return try XCTUnwrap(HTTPCookie.cookies(withResponseHeaderFields:
            ["Set-Cookie": "\(name)=\(value); Path=/; Secure" + (httpOnly ? "; HttpOnly" : "")], for: url).first)
    }

    private func values(_ cookies: [HTTPCookie]) -> [String: String] {
        Dictionary(cookies.map { ($0.name, $0.value) }, uniquingKeysWith: { _, latest in latest })
    }

    func testExplicitCookieValueUpdatePreservesHTTPOnlyAndReportsNativeDowngradeRejection() throws {
        let persistence = Persistence()
        let sourceID = "cookie-source:" + UUID().uuidString
        persistence.records[sourceID] = [try cookie("session", "protected")]
        let store = persistence.makeStore(namespace: "cookie-method:" + UUID().uuidString)
        let valueUpdate = try store.begin(sourceID: sourceID)
        XCTAssertTrue(valueUpdate.storeCookie(try cookie("session", "explicit-accepted", httpOnly: false), preservingHTTPOnly: true))
        XCTAssertEqual(valueUpdate.jar.cookies?.first?.value, "explicit-accepted")
        XCTAssertTrue(valueUpdate.jar.cookies?.first?.isHTTPOnly == true)
        _ = try store.complete(valueUpdate, result: .success(()))
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), ["session": "explicit-accepted"])

        let explicitDowngrade = try store.begin(sourceID: sourceID)
        XCTAssertFalse(explicitDowngrade.storeCookie(try cookie("session", "rejected", httpOnly: false), preservingHTTPOnly: false),
            "A native setCookie rejection cannot become a stored=true acknowledgement")
        XCTAssertEqual(explicitDowngrade.jar.cookies?.first?.value, "explicit-accepted")
        XCTAssertTrue(explicitDowngrade.jar.cookies?.first?.isHTTPOnly == true)
        XCTAssertEqual(values(try store.snapshot(sourceID: sourceID)), ["session": "explicit-accepted"])
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), ["session": "explicit-accepted"])
    }

    func testAcceptedCookieSnapshotCanReplaceHTTPOnlyDuringPrivateDeltaReplay() throws {
        let persistence = Persistence()
        let sourceID = "cookie-source:" + UUID().uuidString
        persistence.records[sourceID] = [try cookie("session", "protected")]
        let store = persistence.makeStore(namespace: "cookie-method:" + UUID().uuidString)
        let accepted = try store.begin(sourceID: sourceID)
        // A final native/WebKit snapshot already reflects platform acceptance.
        // Replaying it must not reapply setCookie's non-HTTP overwrite guard.
        accepted.replaceCookies([try cookie("session", "accepted-without-http-only", httpOnly: false)])
        XCTAssertEqual(accepted.jar.cookies?.first?.value, "accepted-without-http-only")
        XCTAssertTrue(try store.snapshot(sourceID: sourceID).first?.isHTTPOnly == true)
        _ = try store.complete(accepted, result: .success(()))
        XCTAssertEqual(values(try store.snapshot(sourceID: sourceID)), ["session": "accepted-without-http-only"])
        XCTAssertFalse(try XCTUnwrap(store.snapshot(sourceID: sourceID).first).isHTTPOnly)
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), ["session": "accepted-without-http-only"])
        XCTAssertFalse(try XCTUnwrap(persistence.records[sourceID]?.first).isHTTPOnly)
    }

    func testResponseCookiesCommitForHTTPErrorStatusAndBeforeNonCancellationFailureEscapes() throws {
        let namespace = "cookie-method:" + UUID().uuidString
        let sourceID = "cookie-source:" + UUID().uuidString
        let persistence = Persistence()
        let store = persistence.makeStore(namespace: namespace)

        let success = try store.begin(sourceID: sourceID)
        success.jar.setCookie(try cookie("session", "accepted-200"))
        XCTAssertTrue(try store.snapshot(sourceID: sourceID).isEmpty,
            "A response candidate must remain private before commit")
        XCTAssertEqual(try store.complete(success, result: .success(200)), 200)
        XCTAssertEqual(values(try store.snapshot(sourceID: sourceID)), ["session": "accepted-200"])
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), ["session": "accepted-200"])

        // A received HTTP error response can establish or expire a session.
        let rejectedHTTPStatus = try store.begin(sourceID: sourceID)
        rejectedHTTPStatus.jar.setCookie(try cookie("session", "accepted-401"))
        XCTAssertEqual(try store.complete(rejectedHTTPStatus, result: .success(401)), 401)
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), ["session": "accepted-401"])

        // The Host keeps Cookies already received before a non-cancel transport
        // failure. The original request failure still reaches its caller.
        let timedOut = try store.begin(sourceID: sourceID)
        timedOut.jar.setCookie(try cookie("challenge", "received-before-timeout"))
        let outcome: Result<Int, Error> = .failure(URLError(.timedOut))
        XCTAssertThrowsError(try store.complete(timedOut, result: outcome)) { error in
            XCTAssertEqual((error as? URLError)?.code, .timedOut)
        }
        let accepted = try store.snapshot(sourceID: sourceID)
        XCTAssertEqual(values(accepted), ["session": "accepted-401", "challenge": "received-before-timeout"])
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), values(accepted))
        XCTAssertTrue(accepted.allSatisfy { $0.isSecure && $0.isHTTPOnly },
            "Foundation response parsing must retain Cookie attributes")
    }

    func testCancellationBeforeAdmissionDiscardsCandidateWhileAcceptedCommitCanFinish() throws {
        let namespace = "cookie-method:" + UUID().uuidString
        let sourceID = "cookie-source:" + UUID().uuidString
        let persistence = Persistence()
        persistence.records[sourceID] = [try cookie("session", "baseline")]
        let store = persistence.makeStore(namespace: namespace)

        let cancelled = try store.begin(sourceID: sourceID)
        cancelled.jar.setCookie(try cookie("session", "cancelled-candidate"))
        cancelled.cancel()
        XCTAssertThrowsError(try store.complete(cancelled, result: .success(200))) { error in
            XCTAssertEqual((error as? URLError)?.code, .cancelled)
        }

        let retiredOwner = try store.begin(sourceID: sourceID)
        retiredOwner.jar.setCookie(try cookie("session", "retired-candidate"))
        XCTAssertThrowsError(try store.complete(retiredOwner, result: .success(200), authorizeCommit: { false })) { error in
            XCTAssertEqual((error as? URLError)?.code, .cancelled)
        }

        let platformCancelled = try store.begin(sourceID: sourceID)
        platformCancelled.jar.setCookie(try cookie("session", "platform-cancelled"))
        let cancelledOutcome: Result<Int, Error> = .failure(URLError(.cancelled))
        XCTAssertThrowsError(try store.complete(platformCancelled, result: cancelledOutcome)) { error in
            XCTAssertEqual((error as? URLError)?.code, .cancelled)
        }
        XCTAssertEqual(values(try store.snapshot(sourceID: sourceID)), ["session": "baseline"])
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), ["session": "baseline"])

        let accepted = try store.begin(sourceID: sourceID)
        accepted.jar.setCookie(try cookie("session", "accepted-before-cancel"))
        // save is reached after admission. Cancellation here cannot roll an
        // already accepted commit back into the previous shared state.
        persistence.beforeSave = { accepted.cancel() }
        XCTAssertEqual(try store.complete(accepted, result: .success(200)), 200)
        persistence.beforeSave = nil
        XCTAssertEqual(values(try store.snapshot(sourceID: sourceID)), ["session": "accepted-before-cancel"])
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), ["session": "accepted-before-cancel"])
    }

    func testOverlappingOperationsMergeOnlyTheirDeltasWithinSharedNamespace() throws {
        let sourceID = "cookie-source:" + UUID().uuidString
        let otherSourceID = "cookie-source:" + UUID().uuidString
        let persistence = Persistence()
        persistence.records[sourceID] = [try cookie("session", "baseline"), try cookie("removed", "old")]
        let namespace = "cookie-method:" + UUID().uuidString
        let first = ReaderSourceCookieStore.shared(namespace: namespace, load: persistence.load, save: persistence.save)
        let second = ReaderSourceCookieStore.shared(namespace: namespace, load: persistence.load, save: persistence.save)
        XCTAssertTrue(first === second, "Live transports in one namespace must share one commit owner")

        // Both operations start before either publishes, so the second has a
        // stale baseline when its commit follows the first operation.
        let a = try first.begin(sourceID: sourceID)
        let b = try second.begin(sourceID: sourceID)
        let cancelled = try first.begin(sourceID: sourceID)
        XCTAssertFalse(a.jar === b.jar, "Native requests require independent candidate jars")
        a.jar.setCookie(try cookie("from-a", "one"))
        a.jar.setCookie(try cookie("session", "first-commit"))
        for cookie in a.jar.cookies ?? [] where cookie.name == "removed" { a.jar.deleteCookie(cookie) }
        b.jar.setCookie(try cookie("from-b", "two"))
        b.jar.setCookie(try cookie("session", "last-commit"))
        cancelled.replaceCookies([])
        cancelled.cancel()

        _ = try first.complete(a, result: .success(200))
        _ = try second.complete(b, result: .success(200))
        XCTAssertThrowsError(try first.complete(cancelled, result: .success(200)))
        let expected = ["session": "last-commit", "from-a": "one", "from-b": "two"]
        XCTAssertEqual(values(try first.snapshot(sourceID: sourceID)), expected,
            "Unchanged stale Cookies cannot undo another commit's additions or deletions")
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), expected)
        XCTAssertTrue(try second.snapshot(sourceID: otherSourceID).isEmpty)

        let deleteFromOldSnapshot = try first.begin(sourceID: sourceID)
        let updateBeforeDeletion = try second.begin(sourceID: sourceID)
        updateBeforeDeletion.jar.setCookie(try cookie("session", "updated-before-delete"))
        _ = try second.complete(updateBeforeDeletion, result: .success(200))
        XCTAssertEqual(values(try first.snapshot(sourceID: sourceID))["session"], "updated-before-delete")
        for cookie in deleteFromOldSnapshot.jar.cookies ?? [] where cookie.name == "session" {
            deleteFromOldSnapshot.jar.deleteCookie(cookie)
        }
        _ = try first.complete(deleteFromOldSnapshot, result: .success(200))
        let afterDeletion = ["from-a": "one", "from-b": "two"]
        XCTAssertEqual(values(try first.snapshot(sourceID: sourceID)), afterDeletion,
            "A later admitted deletion removes the current same-identity value while preserving other commits")
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), afterDeletion)

        let otherPersistence = Persistence()
        let otherNamespace = ReaderSourceCookieStore.shared(namespace: "cookie-method:" + UUID().uuidString, load: otherPersistence.load, save: otherPersistence.save)
        XCTAssertFalse(first === otherNamespace)
        XCTAssertTrue(try otherNamespace.snapshot(sourceID: sourceID).isEmpty)
    }

    func testPersistenceFailureCannotPublishCandidateAndFailedLoadIsNotCachedAsEmpty() throws {
        let namespace = "cookie-method:" + UUID().uuidString
        let sourceID = "cookie-source:" + UUID().uuidString
        let persistence = Persistence()
        persistence.records[sourceID] = [try cookie("session", "durable-baseline")]
        let store = persistence.makeStore(namespace: namespace)
        let failedSave = try store.begin(sourceID: sourceID)
        failedSave.replaceCookies([try cookie("replacement", "unpersisted")])
        persistence.failSave = true
        XCTAssertThrowsError(try store.complete(failedSave, result: .success(200))) { error in
            guard case ProbeError.save = error else { return XCTFail("Expected the persistence failure, got \(error)") }
        }
        XCTAssertEqual(values(try store.snapshot(sourceID: sourceID)), ["session": "durable-baseline"])
        XCTAssertEqual(values(persistence.records[sourceID] ?? []), ["session": "durable-baseline"])

        let reopened = persistence.makeStore(namespace: "cookie-method:" + UUID().uuidString)
        persistence.failLoad = true
        XCTAssertThrowsError(try reopened.begin(sourceID: sourceID)) { error in
            guard case ProbeError.load = error else { return XCTFail("Expected the load failure, got \(error)") }
        }
        persistence.failLoad = false
        persistence.failSave = false
        XCTAssertEqual(values(try reopened.snapshot(sourceID: sourceID)), ["session": "durable-baseline"],
            "A locked or unreadable credential store must be retried, never cached as an empty login")
    }
}
