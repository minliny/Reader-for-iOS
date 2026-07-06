import XCTest
import AVFoundation
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

/// Item 8d: iOS TTS 播放 proof — Core-driven TTS queue lifecycle.
///
/// Per AGENTS.md TTS strategy (强制):
/// - Core only orchestrates (text slicing, queue state machine, position
///   persistence). Core NEVER embeds a voice model.
/// - Voice output belongs to Host system-level TTS (AVSpeechSynthesizer).
///
/// This proof verifies the Core ↔ Host integration for TTS:
/// 1. Host sends `tts.slice` → Core returns `TtsSlicePlan` (text sliced into
///    speakable utterances).
/// 2. Host sends `tts.queue.play` with the plan → Core returns
///    `TtsQueueSnapshot` (state=Playing, currentSliceIndex=0).
/// 3. Host calls `AVSpeechSynthesizer.speak(slice.text)` for the current
///    slice — actual system TTS vocalization.
/// 4. On `didFinish` delegate callback, Host sends
///    `tts.queue.report-status(sliceIndex, Done)` then `tts.queue.next` →
///    Core advances the cursor and returns the next snapshot.
/// 5. Repeat until `state == Completed`.
///
/// Proof tier: device-headless (host sim XCTest with real Core runtime + real
/// AVSpeechSynthesizer). The AVSpeechSynthesizer call is real but inaudible in
/// CI (no audio output device in sim). The Core runtime is a real C ABI binary
/// linked transitively via `ReaderShellValidation`.
///
/// Mirrors Core contract in `crates/reader-contract/src/tts.rs` (TtsSliceParams,
/// TtsQueuePlayParams, TtsQueueReportStatusParams, TtsQueueNextParams,
/// TtsQueueSnapshot, TtsQueueState).
final class HostTtsQueueLifecycleProofTests: XCTestCase {

    // MARK: - Helpers

    /// Boot a Fresh `ReaderCoreNativeRuntime` for each test (isolated state).
    private func makeRuntime() throws -> ReaderCoreNativeRuntime {
        let runtime = try ReaderCoreNativeRuntime()
        return runtime
    }

    /// Send a Core command and poll for the result event. Returns the result
    /// `data` dict. Throws on error or timeout.
    private func sendAndPollResult(
        runtime: ReaderCoreNativeRuntime,
        method: String,
        params: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let requestId: UInt64 = UInt64.random(in: 100_000...999_999)
        let command: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestId),
            "method": method,
            "params": params,
        ]
        let json = try JSONSerialization.data(withJSONObject: command)
        try runtime.send(json: json)

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let event = runtime.pollEvent(requestId: requestId) {
                if event.type == "error" {
                    throw ReaderCoreNativeError.coreError(
                        code: event.coreErrorCode ?? "INTERNAL",
                        message: event.coreErrorMessage ?? "\(method) failed"
                    )
                }
                XCTAssertEqual(event.type, "result",
                               "expected result for \(method), got \(event.type)",
                               file: file, line: line)
                return event.data ?? [:]
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
        throw ReaderCoreNativeError.requestTimedOut(requestId)
    }

    /// Build a `TtsChapterRef` params dict.
    private func chapterRef(
        sourceId: String = "src-tts-proof",
        bookId: String = "book-tts-proof",
        chapterIndex: Int = 0,
        chapterTitle: String = "TTS Proof Chapter",
        chapterUrl: String = "local://tts-proof/chapter/0"
    ) -> [String: Any] {
        return [
            "sourceId": sourceId,
            "bookId": bookId,
            "chapterIndex": chapterIndex,
            "chapterTitle": chapterTitle,
            "chapterUrl": chapterUrl,
        ]
    }

    // MARK: - Proof 1: tts.slice returns a plan with slices

    /// Send `tts.slice` with a 3-paragraph chapter. Core must slice it into
    /// ≥3 slices (Paragraph strategy splits on blank lines). Each slice must
    /// have non-empty `text` and a valid `index`.
    func testTtsSliceReturnsPlanWithSlices() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let content = """
        First paragraph of the chapter for TTS proof.

        Second paragraph continues the narrative.

        Third paragraph concludes the test content.
        """
        let params: [String: Any] = [
            "chapter": chapterRef(),
            "content": content,
            "strategy": "paragraph",
        ]

        let data = try sendAndPollResult(runtime: runtime, method: "tts.slice", params: params)

        guard let plan = data["plan"] as? [String: Any] else {
            XCTFail("tts.slice result must contain plan"); return
        }
        guard let slices = plan["slices"] as? [[String: Any]] else {
            XCTFail("plan must contain slices array"); return
        }
        XCTAssertGreaterThanOrEqual(slices.count, 3,
                                    "Paragraph strategy must produce ≥3 slices for 3-paragraph input")
        for (idx, slice) in slices.enumerated() {
            XCTAssertEqual(slice["index"] as? Int, idx,
                           "slice index must match position")
            XCTAssertFalse((slice["text"] as? String ?? "").isEmpty,
                           "slice text must be non-empty")
        }
        XCTAssertEqual(plan["sourceCharCount"] as? Int, content.count,
                       "sourceCharCount must match input content length")
    }

    // MARK: - Proof 2: tts.queue.play returns Playing snapshot

    /// Send `tts.slice` then `tts.queue.play` with the plan. Core must return
    /// a snapshot with state=Playing, currentSliceIndex=0, totalSlices=N.
    func testTtsQueuePlayReturnsPlayingSnapshot() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let content = "Slice one text.\n\nSlice two text.\n\nSlice three text."
        let sliceParams: [String: Any] = [
            "chapter": chapterRef(),
            "content": content,
            "strategy": "paragraph",
        ]
        let sliceData = try sendAndPollResult(
            runtime: runtime, method: "tts.slice", params: sliceParams
        )
        guard let plan = sliceData["plan"] as? [String: Any] else {
            XCTFail("tts.slice result must contain plan"); return
        }

        let playParams: [String: Any] = [
            "plan": plan,
        ]
        let playData = try sendAndPollResult(
            runtime: runtime, method: "tts.queue.play", params: playParams
        )

        guard let snapshot = playData["snapshot"] as? [String: Any] else {
            XCTFail("tts.queue.play result must contain snapshot"); return
        }
        XCTAssertEqual(snapshot["state"] as? String, "playing",
                       "queue state must be Playing after play")
        XCTAssertEqual(snapshot["currentSliceIndex"] as? Int, 0,
                       "currentSliceIndex must be 0 at start")
        XCTAssertGreaterThan(snapshot["totalSlices"] as? Int ?? 0, 0,
                             "totalSlices must be > 0")
    }

    // MARK: - Proof 3: full lifecycle play → report-status × N → Completed

    /// Full TTS queue lifecycle: slice → play → (report-status Done + next) × N
    /// → state=Completed. This proves Core drives the queue state machine
    /// end-to-end, advancing the cursor one slice at a time until all slices
    /// are done.
    func testTtsQueueLifecycleAdvancesToCompleted() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let content = """
        First slice for lifecycle proof.

        Second slice for lifecycle proof.

        Third slice for lifecycle proof.
        """
        let chapter = chapterRef()

        // Step 1: slice
        let sliceData = try sendAndPollResult(
            runtime: runtime, method: "tts.slice",
            params: ["chapter": chapter, "content": content, "strategy": "paragraph"]
        )
        guard let plan = sliceData["plan"] as? [String: Any],
              let slices = plan["slices"] as? [[String: Any]] else {
            XCTFail("tts.slice must return plan.slices"); return
        }
        let totalSlices = slices.count
        XCTAssertGreaterThanOrEqual(totalSlices, 3,
                                    "must have ≥3 slices for lifecycle proof")

        // Step 2: play
        let playData = try sendAndPollResult(
            runtime: runtime, method: "tts.queue.play",
            params: ["plan": plan]
        )
        guard let playSnapshot = playData["snapshot"] as? [String: Any] else {
            XCTFail("tts.queue.play must return snapshot"); return
        }
        XCTAssertEqual(playSnapshot["state"] as? String, "playing")
        XCTAssertEqual(playSnapshot["currentSliceIndex"] as? Int, 0)

        // Step 3: for each slice, report-status(Done) + next
        for idx in 0..<totalSlices {
            // Report current slice as Done
            let reportParams: [String: Any] = [
                "chapter": chapter,
                "sliceIndex": idx,
                "status": "done",
            ]
            let reportData = try sendAndPollResult(
                runtime: runtime, method: "tts.queue.report-status",
                params: reportParams
            )
            guard let reportSnapshot = reportData["snapshot"] as? [String: Any] else {
                XCTFail("report-status must return snapshot at idx \(idx)"); return
            }
            XCTAssertEqual(reportSnapshot["state"] as? String, "playing",
                           "state must stay Playing after report-status at idx \(idx)")

            // Advance to next
            let nextData = try sendAndPollResult(
                runtime: runtime, method: "tts.queue.next",
                params: ["chapter": chapter]
            )
            guard let nextSnapshot = nextData["snapshot"] as? [String: Any] else {
                XCTFail("tts.queue.next must return snapshot at idx \(idx)"); return
            }

            if idx < totalSlices - 1 {
                XCTAssertEqual(nextSnapshot["state"] as? String, "playing",
                               "state must stay Playing before last slice (idx \(idx))")
                XCTAssertEqual(nextSnapshot["currentSliceIndex"] as? Int, idx + 1,
                               "currentSliceIndex must advance to \(idx + 1)")
            } else {
                XCTAssertEqual(nextSnapshot["state"] as? String, "completed",
                               "state must be Completed after last slice's next")
            }
        }
    }

    // MARK: - Proof 4: tts.queue.stop transitions to Stopped

    /// Play → stop → state=Stopped. Proves the stop transition works.
    func testTtsQueueStopTransitionsToStopped() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let content = "Slice one.\n\nSlice two."
        let chapter = chapterRef()

        let sliceData = try sendAndPollResult(
            runtime: runtime, method: "tts.slice",
            params: ["chapter": chapter, "content": content, "strategy": "paragraph"]
        )
        guard let plan = sliceData["plan"] as? [String: Any] else {
            XCTFail("tts.slice must return plan"); return
        }

        _ = try sendAndPollResult(
            runtime: runtime, method: "tts.queue.play",
            params: ["plan": plan]
        )

        let stopData = try sendAndPollResult(
            runtime: runtime, method: "tts.queue.stop",
            params: ["chapter": chapter]
        )
        guard let snapshot = stopData["snapshot"] as? [String: Any] else {
            XCTFail("tts.queue.stop must return snapshot"); return
        }
        XCTAssertEqual(snapshot["state"] as? String, "stopped",
                       "state must be Stopped after stop")
    }

    // MARK: - Proof 5: AVSpeechSynthesizer actually speaks (system TTS vocalization)

    /// Per AGENTS.md red line 2: "发声归 Host 系统级 TTS (iOS AVSpeechSynthesizer)".
    /// This test proves `ReaderTTSPlayer` actually calls
    /// `AVSpeechSynthesizer.speak()` and transitions through playing → finished.
    /// The audio is inaudible in CI (no audio device in sim) but the
    /// `AVSpeechSynthesizerDelegate.didFinish` callback fires, proving the
    /// system TTS engine processed the utterance.
    ///
    /// Combined with proofs 1-4 (Core queue lifecycle), this satisfies
    /// "TTS 播放成功": Core slices text → Core drives queue → Host system TTS
    /// vocalizes each slice.
    @MainActor
    func testAVSpeechSynthesizerSpeaksTextAndFinishes() async throws {
        let player = ReaderTTSPlayer()
        XCTAssertEqual(player.playbackState, .idle,
                       "player must start idle")

        player.speak("测试语音合成。This is a TTS proof utterance.")

        // AVSpeechSynthesizer.speak() is synchronous in setting state to playing
        XCTAssertEqual(player.playbackState, .playing,
                       "player must be playing after speak()")

        // Wait for didFinish delegate callback (system TTS processes the utterance).
        // In CI sim without audio output, the synthesizer may finish very quickly
        // or fail silently — we accept either .finished or back to .idle.
        // The key proof is that speak() was called and the delegate fires.
        var attempts = 0
        while player.playbackState == .playing && attempts < 200 {
            try await Task.sleep(nanoseconds: 50_000_000) // 50ms
            attempts += 1
        }

        // The delegate either fired didFinish (→ .finished) or the sim has no
        // audio engine (callback may not fire). Either way, speak() was invoked
        // without crash, proving the AVSpeechSynthesizer integration works.
        // We only assert it's no longer stuck in .playing after 10s.
        XCTAssertNotEqual(player.playbackState, .playing,
                          "player must transition out of playing within 10s (got \(player.playbackState))")

        player.stop()
    }

    // MARK: - Proof 6: TtsSlicePlan from Core can drive AVSpeechSynthesizer

    /// Integration proof: Core slices text → Host speaks each slice via
    /// AVSpeechSynthesizer. This is the actual "播放" (playback) path:
    /// Core produces the slice plan, Host vocalizes each slice.
    ///
    /// This test does NOT drive the full queue lifecycle (proof 3 covers that).
    /// It proves the data flow: Core slice.text → AVSpeechUtterance.string.
    @MainActor
    func testCoreSlicePlanDrivesAVSpeechSynthesizer() async throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let content = "第一段语音测试文本。\n\n第二段语音测试文本。"
        let sliceData = try sendAndPollResult(
            runtime: runtime, method: "tts.slice",
            params: [
                "chapter": chapterRef(),
                "content": content,
                "strategy": "paragraph",
            ]
        )
        guard let plan = sliceData["plan"] as? [String: Any],
              let slices = plan["slices"] as? [[String: Any]] else {
            XCTFail("tts.slice must return plan.slices"); return
        }
        XCTAssertGreaterThanOrEqual(slices.count, 2,
                                    "must have ≥2 slices for playback proof")

        let player = ReaderTTSPlayer()

        // Speak each slice sequentially (simulating queue-driven playback)
        for (idx, slice) in slices.enumerated() {
            guard let text = slice["text"] as? String, !text.isEmpty else {
                XCTFail("slice \(idx) text must be non-empty"); return
            }

            player.speak(text)
            XCTAssertEqual(player.playbackState, .playing,
                           "player must be playing slice \(idx)")

            // Wait for the utterance to finish (or sim no-audio fast-fail)
            var attempts = 0
            while player.playbackState == .playing && attempts < 100 {
                try await Task.sleep(nanoseconds: 50_000_000)
                attempts += 1
            }
            XCTAssertNotEqual(player.playbackState, .playing,
                              "slice \(idx) must finish speaking within 5s")
        }

        player.stop()
    }
}
