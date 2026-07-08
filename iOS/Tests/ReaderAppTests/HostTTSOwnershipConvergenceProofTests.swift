import XCTest
import AVFoundation
import ReaderCoreNativeAdapter
import ReaderUIContract
@testable import ReaderShellValidation
#if canImport(UIKit)
@testable import ReaderApp
#endif

/// TTS ownership convergence proof.
///
/// After the ownership convergence (commit 6fcd54d), a single
/// `ReaderTTSPlayer` instance is shared between:
/// - **HostAdapter** (Core-driven `tts.system.*` HostRequests via
///   `HostAdapterHolder.adapter.setTTSSynthProvider`)
/// - **ReaderView** (UI TTS control via `@EnvironmentObject`)
///
/// This test proves the convergence is real:
/// 1. Inject a `ReaderTTSPlayer` instance into `HostAdapterHolder.adapter`.
/// 2. Dispatch `tts.system.start` through the HostAdapter.
/// 3. Assert the **same** `ReaderTTSPlayer` instance's `playbackState`
///    transitions to `.playing` — proving Core-driven calls mutate the
///    shared instance that the UI observes.
/// 4. Dispatch `tts.system.stop` and assert `playbackState` transitions
///    to `.idle`.
///
/// This is the "simulator audio proof" for the TTS ownership convergence:
/// it verifies that Core-driven `tts.system.*` calls and UI-initiated TTS
/// controls would mutate the same `AVSpeechSynthesizer` — `playbackState`
/// is observed by both sides.
///
/// Note: This test uses a real `ReaderTTSPlayer` (with a real
/// `AVSpeechSynthesizer`) but does not assert audio output — only state
/// transitions. `AVSpeechSynthesizer.speak` on macOS `swift test` may not
/// produce audible output, but the delegate callbacks (`didFinish`) fire
/// synchronously enough for state assertions in practice. On iOS Simulator
/// the behavior is equivalent.
@MainActor
final class HostTTSOwnershipConvergenceProofTests: XCTestCase {

    // MARK: - Setup / teardown

    /// Reset the holder to a clean (nil-provider) state before each test.
    override func setUp() async throws {
        HostAdapterHolder.adapter.setTTSSynthProvider { nil }
    }

    /// Restore the holder to its default (nil-provider) state after each test.
    override func tearDown() async throws {
        HostAdapterHolder.adapter.setTTSSynthProvider { nil }
    }

    // MARK: - Proof 1: Core-driven tts.system.start mutates shared player state

    /// Inject a `ReaderTTSPlayer` into `HostAdapterHolder.adapter`, then
    /// dispatch `tts.system.start`. The same instance's `playbackState`
    /// must transition to `.playing` — proving Core-driven calls reach the
    /// shared instance that the UI would observe via `@EnvironmentObject`.
    func testCoreDrivenTTSStartMutatesSharedPlayerState() async throws {
        #if !canImport(UIKit)
        throw XCTSkip("ReaderTTSPlayer requires UIKit (AVSpeechSynthesizer delegate); skipping on macOS swift test")
        #else
        let sharedPlayer = ReaderTTSPlayer()
        XCTAssertEqual(sharedPlayer.playbackState, .idle,
                       "player must start in .idle state")

        // Inject the shared player into HostAdapter — this is what
        // ReaderApp.init() does with SharedTTSPlayer.shared.
        HostAdapterHolder.adapter.setTTSSynthProvider { [sharedPlayer] in
            return sharedPlayer
        }

        // Dispatch tts.system.start through the HostAdapter — this is the
        // Core-driven path (e.g. unified evidence tts.queue capability).
        let request = HostRequest(type: .tts_system_start, payload: [
            "text": AnyCodable("ownership convergence proof"),
        ])
        let outcome = await HostAdapterHolder.adapter.dispatch(request)

        // The dispatch must succeed (provider was injected).
        XCTAssertTrue(outcome.succeeded,
                      "tts.system.start must succeed with injected player; got: \(String(describing: outcome.error))")
        XCTAssertEqual(outcome.result?["started"]?.value as? Bool, true)

        // The key assertion: the shared player's playbackState must be
        // .playing — proving the Core-driven dispatch mutated the same
        // instance that the UI observes.
        XCTAssertEqual(sharedPlayer.playbackState, .playing,
                       "shared player playbackState must be .playing after Core-driven tts.system.start — this proves ownership convergence")
        #endif
    }

    // MARK: - Proof 2: Core-driven tts.system.stop resets shared player state

    /// After `tts.system.start`, dispatch `tts.system.stop` and assert the
    /// shared player's `playbackState` transitions to `.idle`.
    func testCoreDrivenTTSStopResetsSharedPlayerState() async throws {
        #if !canImport(UIKit)
        throw XCTSkip("ReaderTTSPlayer requires UIKit (AVSpeechSynthesizer delegate); skipping on macOS swift test")
        #else
        let sharedPlayer = ReaderTTSPlayer()
        HostAdapterHolder.adapter.setTTSSynthProvider { [sharedPlayer] in
            return sharedPlayer
        }

        // Start first
        let startRequest = HostRequest(type: .tts_system_start, payload: [
            "text": AnyCodable("stop proof"),
        ])
        _ = await HostAdapterHolder.adapter.dispatch(startRequest)
        XCTAssertEqual(sharedPlayer.playbackState, .playing)

        // Stop via Core-driven dispatch
        let stopRequest = HostRequest(type: .tts_system_stop, payload: [:])
        let stopOutcome = await HostAdapterHolder.adapter.dispatch(stopRequest)

        XCTAssertTrue(stopOutcome.succeeded,
                      "tts.system.stop must succeed; got: \(String(describing: stopOutcome.error))")
        XCTAssertEqual(sharedPlayer.playbackState, .idle,
                       "shared player playbackState must be .idle after Core-driven tts.system.stop")
        #endif
    }

    // MARK: - Proof 3: same instance is returned by provider across dispatches

    /// The provider closure must return the same `ReaderTTSPlayer` instance
    /// across multiple dispatches — proving the shared owner is stable, not
    /// per-request.
    func testProviderReturnsSameInstanceAcrossDispatches() async throws {
        #if !canImport(UIKit)
        throw XCTSkip("ReaderTTSPlayer requires UIKit (AVSpeechSynthesizer delegate); skipping on macOS swift test")
        #else
        let sharedPlayer = ReaderTTSPlayer()
        HostAdapterHolder.adapter.setTTSSynthProvider { [sharedPlayer] in
            return sharedPlayer
        }

        // First dispatch
        let startRequest = HostRequest(type: .tts_system_start, payload: [
            "text": AnyCodable("first"),
        ])
        _ = await HostAdapterHolder.adapter.dispatch(startRequest)

        // The player's state must reflect the first dispatch
        XCTAssertEqual(sharedPlayer.playbackState, .playing)

        // Stop
        _ = await HostAdapterHolder.adapter.dispatch(HostRequest(type: .tts_system_stop, payload: [:]))
        XCTAssertEqual(sharedPlayer.playbackState, .idle)

        // Second dispatch — same instance must be reused
        let secondStartRequest = HostRequest(type: .tts_system_start, payload: [
            "text": AnyCodable("second"),
        ])
        _ = await HostAdapterHolder.adapter.dispatch(secondStartRequest)
        XCTAssertEqual(sharedPlayer.playbackState, .playing,
                       "same shared player must be reused for second dispatch — provider is stable")

        // Cleanup
        _ = await HostAdapterHolder.adapter.dispatch(HostRequest(type: .tts_system_stop, payload: [:]))
        #endif
    }
}
