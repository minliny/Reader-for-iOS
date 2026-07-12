import XCTest
import ReaderUIContract
@testable import ReaderShellValidation

#if canImport(UIKit)
import UIKit
#endif

/// Real-device-proof manifest for `HostAdapter` capabilities.
///
/// This test file documents the tier classification of all 58
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

    /// All 58 `HostRequestType` cases must have a non-nil tier when dispatched
    /// through `HostAdapter()`. This catches regressions where a new type is
    /// added to the contract but no handler registers it.
    func testAllTypesHaveTierClassification() {
        let adapter = HostAdapter()
        XCTAssertEqual(HostRequestType.allCases.count, 58)
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
    /// Reader-UI 2.5 manifest: crossPlatform=14, simulatorProof=19,
    /// realDeviceProof=25. Total: 14 + 19 + 25 = 58.
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

        XCTAssertEqual(crossPlatform, Set([
            .cookie_get, .cookie_set, .cookie_clear,
            .credential_get, .credential_set, .credential_delete,
            .clipboard_copy, .clipboard_paste, .clipboard_read, .clipboard_write,
            .timer_foreground_arm, .timer_foreground_cancel,
            .persistence_get, .persistence_put,
        ]))
        XCTAssertEqual(simulatorProof, Set([
            .http_execute, .http_cancel,
            .file_read, .file_write, .file_delete, .storage_path,
            .permission_request, .permission_check,
            .notification_show, .notification_cancel,
            .share_invoke, .share_text, .share_file,
            .font_registerFile, .font_unregisterFile, .network_status,
            .webdav_connect, .webdav_backup, .webdav_restore,
        ]))
        XCTAssertEqual(realDeviceProof, Set([
            .webview_open, .webview_close, .webview_evaluate,
            .tts_system_start, .tts_system_stop, .tts_system_pause, .tts_system_resume,
            .tts_start, .tts_stop, .tts_pause,
            .device_vibrate, .device_screen_keep_on, .device_screen_release,
            .background_schedule, .background_cancel,
            .file_select, .brightness_set, .brightness_get,
            .screen_keepAwake, .screen_allowSleep,
            .haptics_light, .haptics_medium, .haptics_heavy,
            .background_task_start, .background_task_end,
        ]))
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
        #if canImport(UIKit)
        let originalBrightness = UIScreen.main.brightness
        let originalIdleTimerDisabled = UIApplication.shared.isIdleTimerDisabled
        defer {
            UIScreen.main.brightness = originalBrightness
            UIApplication.shared.isIdleTimerDisabled = originalIdleTimerDisabled
        }
        #endif
        let realDeviceTypes: [HostRequestType] = [
            .webview_open, .webview_close, .webview_evaluate,
            .tts_system_start, .tts_system_stop, .tts_system_pause, .tts_system_resume,
            .tts_start, .tts_stop, .tts_pause,
            .device_vibrate, .device_screen_keep_on, .device_screen_release,
            .background_schedule, .background_cancel,
            .file_select, .brightness_set, .brightness_get,
            .screen_keepAwake, .screen_allowSleep,
            .haptics_light, .haptics_medium, .haptics_heavy,
            .background_task_start, .background_task_end,
        ]

        for type in realDeviceTypes {
            let request = HostRequest(type: type, payload: minimalPayload(for: type))
            let outcome = await adapter.dispatch(request)

            // Automated device runs must leave no active background task
            // behind. The interactive file picker remains a separate manual
            // proof because this default adapter intentionally has no UI
            // presenter injected.
            if outcome.succeeded,
               (type == .background_schedule || type == .background_task_start),
               let taskId = outcome.result?["taskId"]?.value as? String {
                let endType: HostRequestType = type == .background_schedule
                    ? .background_cancel
                    : .background_task_end
                _ = await adapter.dispatch(HostRequest(
                    type: endType,
                    payload: ["taskId": AnyCodable(taskId)]
                ))
            }

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
                            "HostAdapter() should register all handlers")
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
        #if !targetEnvironment(simulator)
        let key = "manifest-\(UUID().uuidString)"
        let credSet = await adapter.dispatch(HostRequest(
            type: .credential_set,
            payload: [
                "key": AnyCodable(key),
                "value": AnyCodable("secret"),
            ]
        ))
        XCTAssertTrue(credSet.succeeded,
                      "credential.set must succeed on macOS; got: \(String(describing: credSet.error))")

        let credGet = await adapter.dispatch(HostRequest(
            type: .credential_get,
            payload: [
                "key": AnyCodable(key),
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

        let aliasWrite = await adapter.dispatch(HostRequest(
            type: .clipboard_write,
            payload: ["text": AnyCodable(clipText)]
        ))
        let aliasRead = await adapter.dispatch(HostRequest(type: .clipboard_read, payload: [:]))
        XCTAssertTrue(aliasWrite.succeeded)
        XCTAssertTrue(aliasRead.succeeded)
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
        case .webview_close:
            return [:]
        case .webview_evaluate:
            return [
                "url": AnyCodable("https://manifest-proof.example.test"),
                "script": AnyCodable("document.title"),
            ]
        case .tts_system_start, .tts_start:
            return ["text": AnyCodable("manifest proof")]
        case .tts_system_stop, .tts_system_pause, .tts_system_resume,
             .tts_stop, .tts_pause, .file_select, .brightness_get,
             .screen_keepAwake, .screen_allowSleep,
             .haptics_light, .haptics_medium, .haptics_heavy:
            return [:]
        case .brightness_set:
            return ["value": AnyCodable(0.5)]
        case .device_vibrate:
            return [:]
        case .device_screen_keep_on:
            return ["enabled": AnyCodable(true)]
        case .device_screen_release:
            return [:]
        case .background_schedule:
            return ["taskId": AnyCodable("manifest-proof-task")]
        case .background_cancel:
            return ["taskId": AnyCodable("manifest-proof-task")]
        case .background_task_start:
            return ["name": AnyCodable("manifest-proof-task")]
        case .background_task_end:
            return ["taskId": AnyCodable("manifest-proof-task")]
        default:
            return [:]
        }
    }
}
