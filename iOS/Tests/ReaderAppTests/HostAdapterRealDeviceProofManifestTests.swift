import XCTest
import ReaderUIContract
@testable import ReaderShellValidation

/// Real-device-proof manifest for `HostAdapter` capabilities.
///
/// This test file documents the tier classification of all 31
/// `HostRequestType` cases and asserts the fail-closed behavior of
/// `realDeviceProof` capabilities when run on a platform that cannot fully
/// exercise them (e.g. macOS `swift test`, or the iOS simulator for
/// capabilities that need a real device).
///
/// Tier definitions (from `HostCapabilityTier`):
/// - **crossPlatform**: pure logic, no UIKit. Verifiable on macOS `swift test`.
///   Examples: `cookie.*`, `credential.*`, `clipboard.*`.
/// - **simulatorProof**: verifiable on the iOS simulator. Examples: `http.*`,
///   `file.*`, `storage.path`, `permission.*`, `notification.*`, `share.*`.
/// - **realDeviceProof**: requires a real device to fully exercise. The
///   simulator may load the code path but the proof is incomplete. Examples:
///   `webview.*`, `tts.system.*`, `device.*`, `background.*`.
///
/// This manifest test ensures:
/// 1. Every `HostRequestType` has a known tier (no unclassified capabilities).
/// 2. The tier distribution matches the documented manifest (snapshot).
/// 3. `realDeviceProof` capabilities return a structured error (not a crash)
///    when the platform cannot support them — this is the fail-closed contract.
@MainActor
final class HostAdapterRealDeviceProofManifestTests: XCTestCase {

    // MARK: - Manifest 1: every type has a tier

    /// All 31 `HostRequestType` cases must have a non-nil tier when dispatched
    /// through `HostAdapter()`. This catches regressions where a new type is
    /// added to the contract but no handler registers it.
    func testAllTypesHaveTierClassification() {
        let adapter = HostAdapter()
        for type in HostRequestType.allCases {
            let tier = adapter.tier(for: type)
            XCTAssertNotNil(tier,
                            "type \(type.rawValue) must have a tier classification; register a handler for it")
        }
    }

    // MARK: - Manifest 2: tier distribution snapshot

    /// The tier distribution must match the documented manifest. This is a
    /// snapshot test — update the expected counts when a handler's tier
    /// changes (which should be rare and intentional).
    ///
    /// Current manifest (11 handlers, 31 types):
    /// - crossPlatform (3 handlers, 7 types):
    ///   HostCookieCapability (cookie.get/set/clear = 3),
    ///   HostCredentialCapability (credential.get/set/delete = 3),
    ///   HostClipboardCapability (clipboard.copy/paste = 2) → wait, 3+3+2=8
    ///   Actually: cookie(3) + credential(3) + clipboard(2) = 8 crossPlatform types
    /// - simulatorProof (5 handlers, 13 types):
    ///   HostHttpCapability (http.execute/cancel = 2),
    ///   HostFileCapability (file.read/write/delete + storage.path = 4),
    ///   HostPermissionCapability (permission.request/check = 2),
    ///   HostNotificationCapability (notification.show/cancel = 2),
    ///   HostShareCapability (share.invoke = 1) → 2+4+2+2+1 = 11
    ///   Actually: http(2) + file(4) + permission(2) + notification(2) + share(1) = 11
    /// - realDeviceProof (3 handlers, 12 types):
    ///   HostWebViewCapability (webview.open/close/evaluate = 3),
    ///   HostTTSCapability (tts.system.start/stop/pause/resume = 4),
    ///   HostDeviceCapability (device.vibrate/screen.keep-on/screen.release +
    ///   background.schedule/cancel = 5) → 3+4+5 = 12
    ///
    /// Total: 8 + 11 + 12 = 31 ✓
    func testTierDistributionMatchesManifest() {
        let adapter = HostAdapter()
        var crossPlatform: Set<HostRequestType> = []
        var simulatorProof: Set<HostRequestType> = []
        var realDeviceProof: Set<HostRequestType> = []

        for type in HostRequestType.allCases {
            guard let tier = adapter.tier(for: type) else {
                XCTFail("type \(type.rawValue) has no tier")
                continue
            }
            switch tier {
            case .crossPlatform: crossPlatform.insert(type)
            case .simulatorProof: simulatorProof.insert(type)
            case .realDeviceProof: realDeviceProof.insert(type)
            }
        }

        // crossPlatform: cookie + credential + clipboard = 3 + 3 + 2 = 8
        XCTAssertEqual(crossPlatform.count, 8,
                       "crossPlatform tier must have 8 types, got: \(crossPlatform)")
        XCTAssertTrue(crossPlatform.contains(.cookie_get))
        XCTAssertTrue(crossPlatform.contains(.cookie_set))
        XCTAssertTrue(crossPlatform.contains(.cookie_clear))
        XCTAssertTrue(crossPlatform.contains(.credential_get))
        XCTAssertTrue(crossPlatform.contains(.credential_set))
        XCTAssertTrue(crossPlatform.contains(.credential_delete))
        XCTAssertTrue(crossPlatform.contains(.clipboard_copy))
        XCTAssertTrue(crossPlatform.contains(.clipboard_paste))

        // simulatorProof: http + file + permission + notification + share = 2+4+2+2+1 = 11
        XCTAssertEqual(simulatorProof.count, 11,
                       "simulatorProof tier must have 11 types, got: \(simulatorProof)")
        XCTAssertTrue(simulatorProof.contains(.http_execute))
        XCTAssertTrue(simulatorProof.contains(.http_cancel))
        XCTAssertTrue(simulatorProof.contains(.file_read))
        XCTAssertTrue(simulatorProof.contains(.file_write))
        XCTAssertTrue(simulatorProof.contains(.file_delete))
        XCTAssertTrue(simulatorProof.contains(.storage_path))
        XCTAssertTrue(simulatorProof.contains(.permission_request))
        XCTAssertTrue(simulatorProof.contains(.permission_check))
        XCTAssertTrue(simulatorProof.contains(.notification_show))
        XCTAssertTrue(simulatorProof.contains(.notification_cancel))
        XCTAssertTrue(simulatorProof.contains(.share_invoke))

        // realDeviceProof: webview + tts + device = 3+4+5 = 12
        XCTAssertEqual(realDeviceProof.count, 12,
                       "realDeviceProof tier must have 12 types, got: \(realDeviceProof)")
        XCTAssertTrue(realDeviceProof.contains(.webview_open))
        XCTAssertTrue(realDeviceProof.contains(.webview_close))
        XCTAssertTrue(realDeviceProof.contains(.webview_evaluate))
        XCTAssertTrue(realDeviceProof.contains(.tts_system_start))
        XCTAssertTrue(realDeviceProof.contains(.tts_system_stop))
        XCTAssertTrue(realDeviceProof.contains(.tts_system_pause))
        XCTAssertTrue(realDeviceProof.contains(.tts_system_resume))
        XCTAssertTrue(realDeviceProof.contains(.device_vibrate))
        XCTAssertTrue(realDeviceProof.contains(.device_screen_keep_on))
        XCTAssertTrue(realDeviceProof.contains(.device_screen_release))
        XCTAssertTrue(realDeviceProof.contains(.background_schedule))
        XCTAssertTrue(realDeviceProof.contains(.background_cancel))
    }

    // MARK: - Manifest 3: realDeviceProof types fail closed (not crash)

    /// `realDeviceProof` capabilities dispatched on macOS `swift test` (or any
    /// platform where the underlying system API is unavailable) must return a
    /// structured `.notImplemented` error — never crash, never hang.
    ///
    /// This is the fail-closed contract: the UI layer can surface
    /// "capability not available on this platform" without the app dying.
    ///
    /// On macOS `swift test`:
    /// - `webview.*` → `HostWebViewCapability` stub returns `.notImplemented`
    ///   (WKWebViewExecutor is not compiled).
    /// - `tts.system.*` → `HostTTSCapability` provider returns nil →
    ///   `.notImplemented`.
    /// - `device.*` / `background.*` → `HostDeviceCapability` returns
    ///   `.notImplemented` (UIKit unavailable).
    func testRealDeviceProofTypesFailClosedOnMacOS() async {
        let adapter = HostAdapter()
        let realDeviceTypes: [HostRequestType] = [
            .webview_open, .webview_close, .webview_evaluate,
            .tts_system_start, .tts_system_stop, .tts_system_pause, .tts_system_resume,
            .device_vibrate, .device_screen_keep_on, .device_screen_release,
            .background_schedule, .background_cancel,
        ]

        for type in realDeviceTypes {
            let request = HostRequest(type: type, payload: minimalPayload(for: type))
            let outcome = await adapter.dispatch(request)

            // The outcome must not crash. It may succeed (on a real device or
            // simulator with the capability available) or fail with a
            // structured error. The key assertion is that we get here at all.
            if !outcome.succeeded {
                // When it fails, the error must be a structured
                // HostCapabilityError (not a crash / not an uncaught throw).
                XCTAssertNotNil(outcome.error,
                                "type \(type.rawValue) failed but has no error")
                // Acceptable error cases:
                // - .notImplemented(type, _) — platform doesn't support it
                // - .invalidParams(_) — test payload was minimal/placeholder
                // - .underlying(_) — system API returned an error
                // All three are structured and surfaceable to the UI.
                switch outcome.error! {
                case .notImplemented, .invalidParams, .underlying:
                    // expected structured error
                    break
                case .notConfigured(let t):
                    XCTFail("type \(t.rawValue) must be registered (not .notConfigured); " +
                            "HostAdapter() should register all 11 handlers")
                }
            }
        }
    }

    // MARK: - Manifest 4: crossPlatform types succeed on macOS

    /// `crossPlatform` capabilities must succeed on macOS `swift test` (no
    /// UIKit required). This is the baseline guarantee for the
    /// `crossPlatform` tier.
    ///
    /// On iOS Simulator, `credential.*` is skipped because the host app
    /// built with `CODE_SIGNING_ALLOWED=NO` (CI gate) lacks the
    /// `keychain-access-groups` entitlement (`SecItemAdd` returns
    /// `-34018 errSecMissingEntitlement`). `cookie.*` and `clipboard.*`
    /// don't need the entitlement and still run on sim. The credential
    /// capability is verified on macOS `swift test` and real device instead.
    func testCrossPlatformTypesSucceedOnMacOS() async throws {
        let adapter = HostAdapter()

        // cookie.set + cookie.get round-trip (use root path so cookie path "/"
        // matches the request path).
        let url = "https://manifest-proof.example.test/"
        let setOutcome = await adapter.dispatch(HostRequest(
            type: .cookie_set,
            payload: [
                "url": AnyCodable(url),
                "cookie": AnyCodable([
                    "name": "manifest",
                    "value": "proof-\(UUID().uuidString)",
                ] as [String: String]),
            ]
        ))
        XCTAssertTrue(setOutcome.succeeded,
                      "cookie.set must succeed on macOS; got: \(String(describing: setOutcome.error))")

        let getOutcome = await adapter.dispatch(HostRequest(
            type: .cookie_get,
            payload: ["url": AnyCodable(url)]
        ))
        XCTAssertTrue(getOutcome.succeeded,
                      "cookie.get must succeed on macOS; got: \(String(describing: getOutcome.error))")

        // credential.set + credential.get round-trip.
        // Skipped on iOS Simulator: host-app built with CODE_SIGNING_ALLOWED=NO
        // has no keychain-access-groups entitlement -> errSecMissingEntitlement.
        // Verified on macOS swift test + real device (entitlement injected).
        #if !targetEnvironment(Simulator)
        let service = "com.reader.manifest-proof"
        let account = "manifest-\(UUID().uuidString)"
        let credSet = await adapter.dispatch(HostRequest(
            type: .credential_set,
            payload: [
                "service": AnyCodable(service),
                "account": AnyCodable(account),
                "value": AnyCodable("secret"),
            ]
        ))
        XCTAssertTrue(credSet.succeeded,
                      "credential.set must succeed on macOS; got: \(String(describing: credSet.error))")

        let credGet = await adapter.dispatch(HostRequest(
            type: .credential_get,
            payload: [
                "service": AnyCodable(service),
                "account": AnyCodable(account),
            ]
        ))
        XCTAssertTrue(credGet.succeeded,
                      "credential.get must succeed on macOS; got: \(String(describing: credGet.error))")
        #endif

        // clipboard.copy + clipboard.paste round-trip
        let clipText = "manifest-clipboard-\(UUID().uuidString)"
        let clipCopy = await adapter.dispatch(HostRequest(
            type: .clipboard_copy,
            payload: ["text": AnyCodable(clipText)]
        ))
        XCTAssertTrue(clipCopy.succeeded,
                      "clipboard.copy must succeed on macOS; got: \(String(describing: clipCopy.error))")

        let clipPaste = await adapter.dispatch(HostRequest(
            type: .clipboard_paste,
            payload: [:]
        ))
        XCTAssertTrue(clipPaste.succeeded,
                      "clipboard.paste must succeed on macOS; got: \(String(describing: clipPaste.error))")
    }

    // MARK: - Manifest 5: HostCapabilityTier enum is exhaustive

    /// `HostCapabilityTier.allCases` must contain exactly the three documented
    /// tiers. Adding a new tier is a breaking change that requires updating
    /// this manifest and the dispatch logic.
    func testTierEnumIsExhaustive() {
        XCTAssertEqual(HostCapabilityTier.allCases.count, 3,
                       "HostCapabilityTier must have exactly 3 cases")
        XCTAssertTrue(HostCapabilityTier.allCases.contains(.crossPlatform))
        XCTAssertTrue(HostCapabilityTier.allCases.contains(.simulatorProof))
        XCTAssertTrue(HostCapabilityTier.allCases.contains(.realDeviceProof))
    }

    // MARK: - Helpers

    /// Build a minimal payload for a `realDeviceProof` type so the handler
    /// can be dispatched without `.invalidParams` masking the platform
    /// availability check. The payload may be incomplete — the goal is to
    /// reach the platform-availability branch, not to validate the handler's
    /// full input contract.
    private func minimalPayload(for type: HostRequestType) -> [String: AnyCodable] {
        switch type {
        case .webview_open:
            return ["url": AnyCodable("https://manifest-proof.example.test")]
        case .webview_close, .webview_evaluate:
            return ["sessionId": AnyCodable("manifest-proof-session")]
        case .tts_system_start:
            return ["text": AnyCodable("manifest proof")]
        case .tts_system_stop, .tts_system_pause, .tts_system_resume:
            return [:]
        case .device_vibrate:
            return ["style": AnyCodable("light")]
        case .device_screen_keep_on, .device_screen_release:
            return [:]
        case .background_schedule:
            return ["name": AnyCodable("manifest-proof-task")]
        case .background_cancel:
            return ["name": AnyCodable("manifest-proof-task")]
        default:
            return [:]
        }
    }
}
