import Foundation
import MediaPlayer
import ReaderCoreBridge
import ReaderHost
import UIKit
import XCTest
@testable import ReaderApp

@MainActor
final class M3SpeechTests: XCTestCase {
    func testAVSpeechUnicodeHighlightReflowAndOwnerRetirement() async throws {
        let sample = try (decodeFixture("manga-and-speech") as M3Fixture).speech
        let library = try await LibraryHost.open(directory: isolatedRoot())
        let runtime = library.runtime
        try await M3Fixture.install(root: "/m3/speech", sourceId: sample.sourceId, bookId: sample.bookId,
                                    manga: false, runtime: runtime)
        let raw = try await runtime.request(ReaderM2.chapterContent, .init(
            sourceId: sample.sourceId, bookId: sample.bookId, chapterIndex: 0,
            chapterUrl: M2BusinessFixture.base + "/m3/speech/chapter"
        )).value
        let projection = try OnlineReadingCoordinator.projection(raw, chapterIndex: 0)
        XCTAssertTrue(projection.content.utf16.elementsEqual(sample.content.utf16))
        let body = try XCTUnwrap(projection.bodyVersion)
        let processing = try XCTUnwrap(projection.processingVersion)
        let chapter = M3TtsChapterRef(sourceId: sample.sourceId, bookId: sample.bookId,
                                     chapterIndex: 0, chapterTitle: "朗读章")
        let plan = try await runtime.request(ReaderM3.ttsSlice, .init(
            chapter: chapter, content: projection.content, strategy: .sentence
        )).value.plan
        XCTAssertEqual(plan.sourceCharCount, Int64(sample.sourceScalars))
        XCTAssertEqual(plan.slices.map(\.text), sample.slices.map(\.text))
        XCTAssertEqual(plan.slices.map(\.charStart), sample.slices.map { Int64($0.startScalar) })
        XCTAssertEqual(plan.slices.map(\.charEnd), sample.slices.map { Int64($0.endScalar) })

        let host = SpeechAndMediaHost()
        let coordinator = SpeechSessionCoordinator(runtime: runtime, media: host)
        defer { host.retire() }
        try await coordinator.start(chapter: chapter, content: projection.content, bodyVersion: body,
                                    processingVersion: processing, title: "M3 受控朗读", scalar: 0,
                                    engine: .system(locale: "en-US"), ratePercent: 50)
        try await until("AVSpeechSynthesizer willSpeakRange") { coordinator.nativeRangeCount > 0 }
        try await coordinator.pause()
        let range = try XCTUnwrap(coordinator.currentHighlight(chapter: chapter, bodyVersion: body, processingVersion: processing))
        XCTAssertTrue((0..<5).contains(range.lowerBound))
        XCTAssertLessThanOrEqual(range.upperBound, 5)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "M3 受控朗读")

        let text = TextReadingSurface()
        text.prepare(preferences: .init(fontSize: 18), viewport: CGSize(width: 340, height: 500))
        _ = try await text.open(.init(content: projection.content), session: "m3-tts-reflow", anchor: range.lowerBound, style: .init())
        let sentence = try XCTUnwrap(coordinator.currentSentence(chapter: chapter, bodyVersion: body, processingVersion: processing))
        XCTAssertEqual(sentence, 0..<5)
        text.presentSpeechHighlight(sentence)
        let canvas = try XCTUnwrap(text.view.subviews.first { $0.accessibilityIdentifier == "reader-tts-highlight" })
        XCTAssertEqual(canvas.accessibilityValue, "0..<5")
        text.prepare(preferences: .init(fontSize: 23), viewport: CGSize(width: 280, height: 470))
        let reflowed = try await text.position()
        XCTAssertEqual(reflowed?.scalar, range.lowerBound)
        XCTAssertEqual(canvas.accessibilityValue, "0..<5")
        XCTAssertEqual(coordinator.currentHighlight(chapter: chapter, bodyVersion: body, processingVersion: processing), range)
        XCTAssertNil(coordinator.currentHighlight(chapter: chapter, bodyVersion: body + "-stale", processingVersion: processing))

        let firstNativeRanges = coordinator.nativeRangeCount
        let owner = try XCTUnwrap(host.systemSessionID)
        XCTAssertEqual(coordinator.snapshot?.state, .paused)
        try await coordinator.resume()
        XCTAssertEqual(coordinator.snapshot?.state, .playing)
        try await closeTestPanel()
        XCTAssertEqual(host.systemSessionID, owner)
        XCTAssertEqual(coordinator.snapshot?.state, .playing)

        let alternateBook = sample.bookId + "-replacement"
        try await M3Fixture.install(root: "/m3/speech", sourceId: sample.sourceId, bookId: alternateBook,
                                    manga: false, runtime: runtime)
        let replacement = try await runtime.request(ReaderM2.chapterContent, .init(
            sourceId: sample.sourceId, bookId: alternateBook, chapterIndex: 0,
            chapterUrl: M2BusinessFixture.base + "/m3/speech/chapter"
        )).value
        let replacementText = try OnlineReadingCoordinator.projection(replacement, chapterIndex: 0)
        let next = M3TtsChapterRef(sourceId: sample.sourceId, bookId: alternateBook, chapterIndex: 0)
        try await coordinator.start(chapter: next, content: replacementText.content,
                                    bodyVersion: XCTUnwrap(replacementText.bodyVersion),
                                    processingVersion: XCTUnwrap(replacementText.processingVersion),
                                    title: "M3 新书朗读", scalar: 5, engine: .system(locale: "en-US"), ratePercent: 50)
        XCTAssertNotEqual(host.systemSessionID, owner)
        let old = try await runtime.request(ReaderM3.ttsQueueStatus, .init(chapter: chapter)).value.snapshot
        XCTAssertEqual(old.state, .stopped)
        XCTAssertNil(coordinator.currentHighlight(chapter: chapter, bodyVersion: body, processingVersion: processing))
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "M3 新书朗读")

        coordinator.retire()
        await coordinator.drainRetirement()
        let stopped = try await runtime.request(ReaderM3.ttsQueueStatus, .init(chapter: next)).value.snapshot
        XCTAssertEqual(stopped.state, .stopped)
        XCTAssertNil(coordinator.highlight)
        XCTAssertNil(host.systemSessionID)
        XCTAssertNil(MPNowPlayingInfoCenter.default().nowPlayingInfo)
        print("M3_TTS_SYSTEM nativeRanges=\(firstNativeRanges) scalar=\(range) CoreSlices=0..<5,5..<8 reflow18to23=PASS playingPanelDismiss=PASS NowPlaying=PASS switchAndLeaveOwnerRetired=PASS")
        await runtime.close()
    }

    func testHTTPWAVUsesCoreRequestAndNativePlayer() async throws {
        let library = try await LibraryHost.open(directory: isolatedRoot())
        let runtime = library.runtime
        let base = "https://127.0.0.1:18766"
        _ = try await runtime.request(ReaderM3.httpTtsPut, .init(
            id: 31, name: "Loopback WAV", url: base + "/m3/speech/audio.wav?q={{text}}&rate={{rate}}",
            readerProfile: #"{"version":1,"format":"wav"}"#
        ))
        let host = SpeechAndMediaHost()
        let coordinator = SpeechSessionCoordinator(runtime: runtime, media: host)
        defer { host.retire() }
        let chapter = M3TtsChapterRef(sourceId: "local", bookId: "m3-wav", chapterIndex: 0)
        let before = try await audioRequests(server: base)
        try await coordinator.start(chapter: chapter, content: "Audio fixture.", bodyVersion: "wav-body",
                                    processingVersion: "wav-processed", title: "M3 WAV", scalar: 0,
                                    engine: .http(id: 31), ratePercent: 125)
        try await until("AVAudioPlayer started") { host.isPlaying && coordinator.highlight != nil }
        XCTAssertEqual(coordinator.highlight?.scalarRange, 0..<14)
        XCTAssertEqual(MPNowPlayingInfoCenter.default().nowPlayingInfo?[MPMediaItemPropertyTitle] as? String, "M3 WAV")
        let after = try await audioRequests(server: base)
        XCTAssertEqual(after, before + 1)
        try await until("AVAudioPlayer completion consumed by Core") { coordinator.snapshot?.state == .completed }
        XCTAssertNil(host.systemSessionID)
        coordinator.retire()
        await coordinator.drainRetirement()
        print("M3_TTS_HTTP trustedLoopbackTLSRequests=1 nativeAVAudioPlayer=PASS wireRate=1.25 finishedCoreQueue=PASS")
        await runtime.close()
    }

    private func audioRequests(server: String) async throws -> Int {
        let url = try XCTUnwrap(URL(string: server + "/control/state"))
        let (bytes, response) = try await URLSession.shared.data(from: url)
        XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
        let result = try JSONDecoder().decode(M2BusinessFixture.State.self, from: bytes)
        XCTAssertTrue(result.failures.isEmpty)
        return result.count("/m3/speech/audio.wav")
    }

    private func until(_ label: String, _ condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now + .seconds(8)
        repeat {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(20))
        } while ContinuousClock.now < deadline
        throw NSError(domain: label, code: 1)
    }

    private func closeTestPanel() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let root = UIViewController()
        let panel = UIViewController()
        let prior = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.rootViewController = root
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            prior?.makeKey()
        }
        await withCheckedContinuation { callback in root.present(panel, animated: false) { callback.resume() } }
        XCTAssertTrue(root.presentedViewController === panel)
        await withCheckedContinuation { callback in root.dismiss(animated: false) { callback.resume() } }
        XCTAssertNil(root.presentedViewController)
    }
}
