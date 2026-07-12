import XCTest
import ReaderCoreProtocols
import ReaderUIContract
@testable import ReaderShellValidation

/// HostAdapter capability dispatch proof.
///
/// Verifies the `HostAdapter.dispatch(_:)` → `HostCapabilityRegistry` path is
/// complete for all 55 `HostRequestType` cases — every type has a registered
/// handler, so no UI/reducer `HostRequest` returns `.notConfigured`.
///
/// Proof strategy:
/// 1. **Registration completeness** — `HostAdapter().registeredTypes()`
///    returns all 55 `HostRequestType.allCases`. No type is left unclaimed.
/// 2. **Tier classification** — every registered type has a non-nil tier.
/// 3. **Cross-platform capability round-trip** — cookie/file/credential/
///    clipboard/storage.path round-trip on macOS `swift test` (these are
///    `crossPlatform` or `simulatorProof` handlers that work without UIKit).
/// 4. **Platform-conditional notImplemented** — TTS / share / device / webview
///    handlers return `.notImplemented` on macOS `swift build` (no UIKit /
///    no provider injected).
/// 5. **Fail-closed for unknown types** — the registry is initialized with
///    no handlers; an unknown type returns `.notConfigured`.
@MainActor
final class HostAdapterCapabilityDispatchProofTests: XCTestCase {

    // MARK: - Proof 1: all 55 types registered

    /// `HostAdapter()` (default init) registers all capability handlers,
    /// covering all 55 `HostRequestType` cases. No type returns
    /// `.notConfigured` when dispatched.
    func testAllHostRequestTypesAreRegistered() async {
        let adapter = HostAdapter()
        let registered = adapter.registeredTypes()
        let allTypes = Set(HostRequestType.allCases)

        let missing = allTypes.subtracting(registered)
        XCTAssertTrue(missing.isEmpty,
                      "HostAdapter must register all HostRequestType cases; missing: \(missing)")
    }

    // MARK: - Proof 2: every registered type has a tier

    /// Every registered type has a non-nil `tier(for:)` so the manifest test
    /// can classify it for simulator vs real-device proof routing.
    func testEveryRegisteredTypeHasTier() {
        let adapter = HostAdapter()
        for type in HostRequestType.allCases {
            let tier = adapter.tier(for: type)
            XCTAssertNotNil(tier, "type \(type.rawValue) must have a tier classification")
        }
    }

    // MARK: - Proof 3: cookie round-trip (crossPlatform)

    /// `cookie.set` then `cookie.get` round-trips through the shared
    /// `ScopedCookieJar`. The cookie value must survive the round-trip.
    func testCookieSetGetRoundTrip() async {
        let adapter = HostAdapter()
        // Use a root-path URL so the cookie's default path "/" matches the
        // request path (BasicCookieJar's path matching requires the cookie
        // path to be a prefix of the request path).
        let url = "https://cookie-proof.example.test/"
        let cookieName = "proof-session"
        let cookieValue = "abc-123-\(UUID().uuidString)"

        var setPayload: [String: AnyCodable] = [
            "url": AnyCodable(url),
            "cookie": AnyCodable([
                "name": cookieName,
                "value": cookieValue,
            ] as [String: String]),
        ]
        let setRequest = HostRequest(type: .cookie_set, payload: setPayload)
        let setOutcome = await adapter.dispatch(setRequest)
        XCTAssertTrue(setOutcome.succeeded, "cookie.set must succeed; got: \(String(describing: setOutcome.error))")
        XCTAssertEqual(setOutcome.result?["stored"]?.value as? Bool, true)

        let getRequest = HostRequest(type: .cookie_get, payload: ["url": AnyCodable(url)])
        let getOutcome = await adapter.dispatch(getRequest)
        XCTAssertTrue(getOutcome.succeeded, "cookie.get must succeed; got: \(String(describing: getOutcome.error))")
        // result["cookies"] is AnyCodable([AnyCodable([String: AnyCodable])]).
        // Unwrap layer by layer: [AnyCodable] → first → [String: AnyCodable].
        guard let cookiesCodable = getOutcome.result?["cookies"]?.value as? [AnyCodable],
              let firstCookieCodable = cookiesCodable.first?.value as? [String: AnyCodable] else {
            XCTFail("cookie.get must return cookies array with at least one entry; result: \(String(describing: getOutcome.result))")
            return
        }
        XCTAssertEqual(firstCookieCodable["name"]?.value as? String, cookieName)
        XCTAssertEqual(firstCookieCodable["value"]?.value as? String, cookieValue)

        // Cleanup: clear cookies for this host.
        _ = setPayload.removeValue(forKey: "cookie")
        _ = await adapter.dispatch(HostRequest(type: .cookie_clear, payload: [:]))
    }

    // MARK: - Proof 4: file round-trip (simulatorProof — works on macOS too)

    /// `file.write` then `file.read` round-trips through `FileManager` temp
    /// directory. The file content must survive the round-trip.
    func testFileWriteReadDeleteRoundTrip() async {
        let adapter = HostAdapter()
        let path = "temp:/host-adapter-proof-\(UUID().uuidString).txt"
        let content = "hello host adapter proof"

        let writeRequest = HostRequest(type: .file_write, payload: [
            "path": AnyCodable(path),
            "content": AnyCodable(content),
        ])
        let writeOutcome = await adapter.dispatch(writeRequest)
        XCTAssertTrue(writeOutcome.succeeded, "file.write must succeed; got: \(String(describing: writeOutcome.error))")
        XCTAssertEqual(writeOutcome.result?["byteLength"]?.value as? Int, content.utf8.count)

        let readRequest = HostRequest(type: .file_read, payload: [
            "path": AnyCodable(path),
        ])
        let readOutcome = await adapter.dispatch(readRequest)
        XCTAssertTrue(readOutcome.succeeded, "file.read must succeed; got: \(String(describing: readOutcome.error))")
        XCTAssertEqual(readOutcome.result?["content"]?.value as? String, content)

        let deleteRequest = HostRequest(type: .file_delete, payload: [
            "path": AnyCodable(path),
        ])
        let deleteOutcome = await adapter.dispatch(deleteRequest)
        XCTAssertTrue(deleteOutcome.succeeded, "file.delete must succeed; got: \(String(describing: deleteOutcome.error))")
        XCTAssertEqual(deleteOutcome.result?["deleted"]?.value as? Bool, true)
    }

    // MARK: - Proof 5: storage.path returns a valid path (simulatorProof)

    /// `storage.path` for each kind returns a non-empty path string.
    func testStoragePathReturnsValidPath() async {
        let adapter = HostAdapter()
        for kind in ["files", "cache", "external"] {
            let request = HostRequest(type: .storage_path, payload: ["scope": AnyCodable(kind)])
            let outcome = await adapter.dispatch(request)
            XCTAssertTrue(outcome.succeeded, "storage.path(\(kind)) must succeed; got: \(String(describing: outcome.error))")
            let path = outcome.result?["path"]?.value as? String
            XCTAssertNotNil(path, "storage.path(\(kind)) must return a path string")
            XCTAssertFalse(path?.isEmpty ?? true, "storage.path(\(kind)) path must be non-empty")
        }
    }

    // MARK: - Proof 6: credential round-trip (crossPlatform — Keychain)

    /// `credential.set` then `credential.get` then `credential.delete`
    /// round-trips through the Keychain. The credential value must survive
    /// the round-trip.
    ///
    /// Tier: `crossPlatform`. Verified on macOS `swift test` and real device
    /// (entitlement injected via codesign). On iOS Simulator, the host app
    /// built with `CODE_SIGNING_ALLOWED=NO` (CI gate) has no
    /// `keychain-access-groups` entitlement, so `SecItemAdd` returns
    /// `-34018 errSecMissingEntitlement`. This is a host-app entitlement
    /// configuration gap, not a handler code bug. Skip on simulator to keep
    /// the sim signal clean — the real-device proof covers this capability.
    func testCredentialSetGetDeleteRoundTrip() async throws {
        #if targetEnvironment(simulator)
        throw XCTSkip("credential.* requires keychain-access-groups entitlement; iOS Simulator host-app built with CODE_SIGNING_ALLOWED=NO lacks it (errSecMissingEntitlement -34018). Verified on macOS swift test + real device instead.")
        #else
        let adapter = HostAdapter()
        let key = "proof-account-\(UUID().uuidString)"
        let value = "secret-value-\(UUID().uuidString)"

        let setRequest = HostRequest(type: .credential_set, payload: [
            "key": AnyCodable(key),
            "value": AnyCodable(value),
        ])
        let setOutcome = await adapter.dispatch(setRequest)
        XCTAssertTrue(setOutcome.succeeded, "credential.set must succeed; got: \(String(describing: setOutcome.error))")

        let getRequest = HostRequest(type: .credential_get, payload: [
            "key": AnyCodable(key),
        ])
        let getOutcome = await adapter.dispatch(getRequest)
        XCTAssertTrue(getOutcome.succeeded, "credential.get must succeed; got: \(String(describing: getOutcome.error))")
        XCTAssertEqual(getOutcome.result?["value"]?.value as? String, value)
        XCTAssertEqual(getOutcome.result?["exists"]?.value as? Bool, true)

        let deleteRequest = HostRequest(type: .credential_delete, payload: [
            "key": AnyCodable(key),
        ])
        let deleteOutcome = await adapter.dispatch(deleteRequest)
        XCTAssertTrue(deleteOutcome.succeeded, "credential.delete must succeed; got: \(String(describing: deleteOutcome.error))")
        XCTAssertEqual(deleteOutcome.result?["deleted"]?.value as? Bool, true)

        // Verify the credential is gone.
        let getAfterDelete = await adapter.dispatch(getRequest)
        XCTAssertTrue(getAfterDelete.succeeded)
        XCTAssertEqual(getAfterDelete.result?["exists"]?.value as? Bool, false)
        #endif
    }

    // MARK: - Proof 7: clipboard round-trip (crossPlatform)

    /// `clipboard.copy` then `clipboard.paste` round-trips through the system
    /// pasteboard. The text must survive the round-trip.
    func testClipboardCopyPasteRoundTrip() async {
        let adapter = HostAdapter()
        let text = "clipboard-proof-\(UUID().uuidString)"

        let copyRequest = HostRequest(type: .clipboard_copy, payload: ["text": AnyCodable(text)])
        let copyOutcome = await adapter.dispatch(copyRequest)
        XCTAssertTrue(copyOutcome.succeeded, "clipboard.copy must succeed; got: \(String(describing: copyOutcome.error))")

        let pasteRequest = HostRequest(type: .clipboard_paste, payload: [:])
        let pasteOutcome = await adapter.dispatch(pasteRequest)
        XCTAssertTrue(pasteOutcome.succeeded, "clipboard.paste must succeed; got: \(String(describing: pasteOutcome.error))")
        XCTAssertEqual(pasteOutcome.result?["text"]?.value as? String, text,
                       "clipboard.paste must return the copied text")
    }

    // MARK: - Proof 8: http.cancel is request-scoped

    /// Cancelling an unknown/completed id is an idempotent structured success
    /// with `cancelled=false`. The active-task `true` path is covered by
    /// URLSessionHTTPClientCapabilitiesTests.
    func testHttpCancelUnknownRequestReturnsFalse() async {
        let adapter = HostAdapter()
        let request = HostRequest(type: .http_cancel, payload: [
            "requestId": AnyCodable("req-proof-001"),
        ])
        let outcome = await adapter.dispatch(request)
        XCTAssertTrue(outcome.succeeded, "http.cancel must return a structured outcome; got: \(String(describing: outcome.error))")
        XCTAssertEqual(outcome.result?["cancelled"]?.value as? Bool, false)
    }

    // MARK: - Proof 9: TTS / share return notImplemented without provider

    /// `tts.system.start` returns `.notImplemented` because no synth provider
    /// is injected by default (ReaderApp injects it at app startup).
    func testTTSStartReturnsNotImplementedWithoutProvider() async {
        let adapter = HostAdapter()
        let request = HostRequest(type: .tts_system_start, payload: [
            "text": AnyCodable("hello world"),
        ])
        let outcome = await adapter.dispatch(request)
        XCTAssertFalse(outcome.succeeded, "tts.system.start must fail without a synth provider")
        guard case .notImplemented(.tts_system_start, _) = outcome.error else {
            XCTFail("expected .notImplemented(.tts_system_start), got: \(String(describing: outcome.error))")
            return
        }
    }

    /// `share.invoke` returns `.notImplemented` because no presenter is
    /// injected by default.
    func testShareInvokeReturnsNotImplementedWithoutPresenter() async {
        let adapter = HostAdapter()
        let request = HostRequest(type: .share_invoke, payload: [
            "text": AnyCodable("share proof"),
        ])
        let outcome = await adapter.dispatch(request)
        XCTAssertFalse(outcome.succeeded, "share.invoke must fail without a presenter")
        guard case .notImplemented(.share_invoke, _) = outcome.error else {
            XCTFail("expected .notImplemented(.share_invoke), got: \(String(describing: outcome.error))")
            return
        }
    }

    // MARK: - Proof 10: invalid params fail closed

    /// `file.read` with missing `path` returns `.invalidParams` (not a crash).
    func testFileReadWithMissingPathReturnsInvalidParams() async {
        let adapter = HostAdapter()
        let request = HostRequest(type: .file_read, payload: [:])
        let outcome = await adapter.dispatch(request)
        XCTAssertFalse(outcome.succeeded)
        if case .invalidParams = outcome.error {
            // expected
        } else {
            XCTFail("expected .invalidParams, got: \(String(describing: outcome.error))")
        }
    }

    // MARK: - Proof 11: empty registry returns notConfigured

    /// A fresh `HostCapabilityRegistry` (no registrations) returns
    /// `.notConfigured` for any `HostRequestType`. This is the fail-closed
    /// baseline.
    func testEmptyRegistryReturnsNotConfigured() async {
        let registry = HostCapabilityRegistry()
        let request = HostRequest(type: .http_execute, payload: [:])
        let outcome = await registry.dispatch(request)
        XCTAssertFalse(outcome.succeeded)
        guard case .notConfigured(.http_execute) = outcome.error else {
            XCTFail("expected .notConfigured(.http_execute), got: \(String(describing: outcome.error))")
            return
        }
    }

    // MARK: - Proof 12: custom registry injection (test seam)

    /// `HostAdapter(registry:)` accepts a custom registry without registering
    /// default handlers. Useful for tests that want to inject stubs.
    func testCustomRegistryInjection() async {
        let registry = HostCapabilityRegistry()
        let adapter = HostAdapter(registry: registry)
        XCTAssertTrue(adapter.registeredTypes().isEmpty,
                      "custom registry init must not register default handlers")
    }
}
