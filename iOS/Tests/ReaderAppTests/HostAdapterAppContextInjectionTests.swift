import XCTest
import ReaderUIContract
@testable import ReaderShellValidation

/// App-context injection proof for `HostAdapterHolder.adapter`.
///
/// `HostAdapterHolder.adapter` is the process-wide production `HostAdapter`
/// singleton. By default its TTS / Share providers return `nil`, so
/// `dispatch(.tts_system_start)` / `dispatch(.share_invoke)` return
/// `.notImplemented`. `ReaderApp.init()` calls
/// `HostAdapterHolder.adapter.setTTSSynthProvider(...)` /
/// `setSharePresenterProvider(...)` at launch to inject the real
/// `ReaderTTSPlayer` / `ReaderSharePresenter`.
///
/// This test proves the injection mechanism works end-to-end through the
/// production holder:
/// 1. Inject a stub provider into `HostAdapterHolder.adapter`.
/// 2. Dispatch the request.
/// 3. Assert the outcome is NOT `.notImplemented` (handler was reached).
///
/// This closes the gap between "HostAdapter is test-dispatchable" and
/// "HostAdapter is production-injected" — the latter is what the unified
/// evidence runner's `tts.queue` capability relies on.
@MainActor
final class HostAdapterAppContextInjectionTests: XCTestCase {

    // MARK: - Stubs

    /// Minimal `HostTTSSynth` stub that records calls without touching
    /// `AVSpeechSynthesizer`. `@MainActor` because `HostTTSSynth` is
    /// `@MainActor`-isolated (and therefore `Sendable`).
    @MainActor
    private final class StubTTSSynth: HostTTSSynth {
        var speakCount = 0
        var lastText: String?
        var pauseCount = 0
        var resumeCount = 0
        var stopCount = 0

        func speak(_ text: String) {
            speakCount += 1
            lastText = text
        }
        func pause() { pauseCount += 1 }
        func resume() { resumeCount += 1 }
        func stop() { stopCount += 1 }
    }

    /// Minimal `HostSharePresenter` stub that returns a fixed activity type
    /// without presenting a real `UIActivityViewController`.
    @MainActor
    private final class StubSharePresenter: HostSharePresenter {
        var presentCount = 0
        var lastItems: [String]?

        func present(items: [String], excludedActivityTypes: [String]?) async -> String? {
            presentCount += 1
            lastItems = items
            return "stub.activity.type"
        }
    }

    // MARK: - Setup / teardown

    /// Reset the holder to a clean (nil-provider) state before each test.
    ///
    /// Under Xcode hosted-app tests, `ReaderApp.init()` runs before the test
    /// bundle and injects real TTS/Share providers into `HostAdapterHolder.adapter`.
    /// Without this reset, `testDefaultHolderWithoutInjectionIsNotImplemented`
    /// would see the app-injected providers and fail. Under SwiftPM `swift test`
    /// there is no host app, so this is a no-op (providers are already nil).
    override func setUp() async throws {
        HostAdapterHolder.adapter.setTTSSynthProvider { nil }
        HostAdapterHolder.adapter.setSharePresenterProvider { nil }
    }

    /// Restore the holder to its default (nil-provider) state after each test
    /// so injection doesn't leak across tests in the same process.
    override func tearDown() async throws {
        HostAdapterHolder.adapter.setTTSSynthProvider { nil }
        HostAdapterHolder.adapter.setSharePresenterProvider { nil }
    }

    // MARK: - Proof 1: TTS not .notImplemented after injection

    /// After `HostAdapterHolder.adapter.setTTSSynthProvider(...)` is called
    /// with a real synth, `dispatch(.tts_system_start)` must NOT return
    /// `.notImplemented`. This proves the production holder + injection
    /// mechanism works (ReaderApp calls this at launch).
    func testTTSStartNotNotImplementedAfterHolderInjection() async {
        let stub = StubTTSSynth()
        HostAdapterHolder.adapter.setTTSSynthProvider { [stub] in
            return stub
        }

        let request = HostRequest(type: .tts_system_start, payload: [
            "text": AnyCodable("app-context injection proof"),
        ])
        let outcome = await HostAdapterHolder.adapter.dispatch(request)

        // The key assertion: must NOT be .notImplemented.
        if case .notImplemented(.tts_system_start, let message) = outcome.error {
            XCTFail("tts.system.start must not be .notImplemented after provider injection; message: \(message)")
            return
        }

        XCTAssertTrue(outcome.succeeded,
                      "tts.system.start should succeed with injected stub synth; got: \(String(describing: outcome.error))")
        XCTAssertEqual(stub.speakCount, 1, "stub synth.speak must be called exactly once")
        XCTAssertEqual(stub.lastText, "app-context injection proof")
        XCTAssertEqual(outcome.result?["started"]?.value as? Bool, true)
    }

    // MARK: - Proof 2: Share not .notImplemented after injection

    /// After `HostAdapterHolder.adapter.setSharePresenterProvider(...)` is
    /// called with a real presenter, `dispatch(.share_invoke)` must NOT return
    /// `.notImplemented`.
    func testShareInvokeNotNotImplementedAfterHolderInjection() async {
        let stub = StubSharePresenter()
        HostAdapterHolder.adapter.setSharePresenterProvider { [stub] in
            return stub
        }

        let request = HostRequest(type: .share_invoke, payload: [
            "items": AnyCodable(["share app-context proof"] as [String]),
        ])
        let outcome = await HostAdapterHolder.adapter.dispatch(request)

        if case .notImplemented(.share_invoke, let message) = outcome.error {
            XCTFail("share.invoke must not be .notImplemented after presenter injection; message: \(message)")
            return
        }

        XCTAssertTrue(outcome.succeeded,
                      "share.invoke should succeed with injected stub presenter; got: \(String(describing: outcome.error))")
        XCTAssertEqual(stub.presentCount, 1, "stub presenter.present must be called exactly once")
        XCTAssertEqual(stub.lastItems, ["share app-context proof"])
        XCTAssertEqual(outcome.result?["shared"]?.value as? Bool, true)
    }

    // MARK: - Proof 3: holder injection persists across dispatches

    /// A single injection must persist for subsequent dispatches (the holder
    /// is a singleton, not per-request). This proves the provider isn't
    /// consumed-once — `tts.system.stop` after `tts.system.start` must also
    /// reach the handler.
    func testHolderInjectionPersistsAcrossDispatches() async {
        let stub = StubTTSSynth()
        HostAdapterHolder.adapter.setTTSSynthProvider { [stub] in
            return stub
        }

        // First dispatch: start
        let startRequest = HostRequest(type: .tts_system_start, payload: [
            "text": AnyCodable("first dispatch"),
        ])
        let startOutcome = await HostAdapterHolder.adapter.dispatch(startRequest)
        XCTAssertTrue(startOutcome.succeeded,
                      "first tts.system.start must succeed; got: \(String(describing: startOutcome.error))")

        // Second dispatch: stop (same holder, same injected provider)
        let stopRequest = HostRequest(type: .tts_system_stop, payload: [:])
        let stopOutcome = await HostAdapterHolder.adapter.dispatch(stopRequest)
        if case .notImplemented(.tts_system_stop, _) = stopOutcome.error {
            XCTFail("tts.system.stop must not be .notImplemented — provider was injected and should persist")
            return
        }
        XCTAssertTrue(stopOutcome.succeeded,
                      "tts.system.stop should succeed; got: \(String(describing: stopOutcome.error))")
        XCTAssertEqual(stub.stopCount, 1, "stub synth.stop must be called once")
    }

    // MARK: - Proof 4: default holder (no injection) IS .notImplemented

    /// Sanity check: without injection, the holder returns `.notImplemented`.
    /// This confirms the test's "after injection" assertions are meaningful
    /// (i.e. injection actually changes the outcome).
    ///
    /// `setUp` has already reset providers to nil before this test runs, so
    /// the holder is in its default state regardless of whether a host app
    /// injected providers earlier in the process.
    func testDefaultHolderWithoutInjectionIsNotImplemented() async {
        let request = HostRequest(type: .tts_system_start, payload: [
            "text": AnyCodable("default holder check"),
        ])
        let outcome = await HostAdapterHolder.adapter.dispatch(request)

        guard case .notImplemented(.tts_system_start, _) = outcome.error else {
            XCTFail("default holder (no injection) must return .notImplemented for tts.system.start; got: \(String(describing: outcome.error))")
            return
        }
    }
}
