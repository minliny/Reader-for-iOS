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
    private var pendingCompletion: (() -> Void)?

    public override init() {
        super.init()
        synthesizer.delegate = self
    }

    public func speak(_ text: String) {
        speak(text, onCompletion: nil)
    }

    /// Correlation/generation ownership stays in ReaderPlaybackPilotCoordinator;
    /// the player reports only completion of this exact utterance. Calling
    /// `stop()` invalidates the closure before AVSpeechSynthesizer can deliver
    /// a late delegate callback.
    public func speak(_ text: String, onCompletion: @escaping () -> Void) {
        speak(text, onCompletion: Optional(onCompletion))
    }

    private func speak(_ text: String, onCompletion: (() -> Void)?) {
        stop()

        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")
            ?? AVSpeechSynthesisVoice(language: "en-US")

        pendingUtterance = utterance
        pendingCompletion = onCompletion
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
        pendingCompletion = nil
        pendingUtterance = nil
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
            guard self.pendingUtterance === utterance else { return }
            let completion = self.pendingCompletion
            self.pendingCompletion = nil
            self.pendingUtterance = nil
            self.playbackState = .finished
            completion?()
        }
    }

    nonisolated public func speechSynthesizer(
        _ synthesizer: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance
    ) {
        Task { @MainActor in
            guard self.pendingUtterance === utterance else { return }
            self.pendingCompletion = nil
            self.pendingUtterance = nil
            self.playbackState = .idle
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
