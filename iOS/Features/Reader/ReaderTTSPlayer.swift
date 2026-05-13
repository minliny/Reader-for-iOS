import Foundation
import AVFoundation

public enum TTSPlaybackState: Equatable {
    case idle
    case playing
    case paused
    case finished
}

@MainActor
public final class ReaderTTSPlayer: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    @Published public var playbackState: TTSPlaybackState = .idle
    @Published public var speechRate: Float = AVSpeechUtteranceDefaultSpeechRate
    @Published public var currentWordRange: NSRange?

    private let synthesizer = AVSpeechSynthesizer()
    private var pendingUtterance: AVSpeechUtterance?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ text: String) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            ?? AVSpeechSynthesisVoice(language: "en-US")

        pendingUtterance = utterance
        playbackState = .playing
        synthesizer.speak(utterance)
    }

    public func pause() {
        guard playbackState == .playing else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        playbackState = .paused
    }

    public func resume() {
        guard playbackState == .paused else { return }
        synthesizer.continueSpeaking()
        playbackState = .playing
    }

    public func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        playbackState = .idle
    }

    public func togglePlayPause(text: String) {
        switch playbackState {
        case .idle, .finished:
            speak(text)
        case .playing:
            pause()
        case .paused:
            resume()
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.playbackState = .finished
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didPause utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.playbackState = .paused
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didContinue utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            self.playbackState = .playing
        }
    }
}
