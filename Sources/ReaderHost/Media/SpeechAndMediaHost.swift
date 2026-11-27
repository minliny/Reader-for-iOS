import AVFoundation
import Foundation
import MediaPlayer
import ReaderCoreBridge

public enum SpeechPhysicalEvent: Sendable {
    case range(NSRange)
    case finished
    case failed
}

public enum SpeechRemoteAction: Sendable, Equatable {
    case play, pause, toggle, stop, next, previous
}

public enum SpeechPhysicalFailure: Error {
    case unavailable
    case credentialsUnavailable
    case malformedPCM
}

public struct SystemSpeechVoice: Sendable {
    public let id: String
    public let name: String
    public let language: String
}

@MainActor
public final class SpeechAndMediaHost: NSObject {
    public static let shared = SpeechAndMediaHost(credential: { try SpeechCredentialVault.read($0) })
    private struct Active {
        let token: UUID
        let nativeID: ObjectIdentifier
        let receive: @MainActor (UUID, SpeechPhysicalEvent) -> Void
    }

    private let synthesizer = AVSpeechSynthesizer()
    private var audio: AVAudioPlayer?
    private var active: Active?
    private var session: UUID?
    private var title: String?
    private var chapter: String?
    private var rate: Double = 1
    private let player = MPNowPlayingInfoCenter.default()
    private var remoteTargets: [(MPRemoteCommand, Any)] = []
    private var interruption: (any NSObjectProtocol)?
    private let credential: @MainActor (String) throws -> String?

    public init(credential: @escaping @MainActor (String) throws -> String? = { _ in nil }) {
        self.credential = credential
        super.init()
        synthesizer.delegate = self
    }

    public func begin(session id: UUID, title: String, chapter: String?,
                      control: @escaping @MainActor @Sendable (SpeechRemoteAction) -> Void) throws {
        retire()
        let focus = AVAudioSession.sharedInstance()
        try focus.setCategory(.playback, mode: .spokenAudio, policy: .longFormAudio)
        try focus.setActive(true)
        session = id
        self.title = title
        self.chapter = chapter
        registerRemoteControls(control)
        interruption = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: focus, queue: nil
        ) { notification in
            let began = (notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt) ==
                AVAudioSession.InterruptionType.began.rawValue
            guard began else { return }
            Task { @MainActor in control(.pause) }
        }
        updateNowPlaying(playing: false)
    }

    public var isPlaying: Bool {
        guard active != nil else { return false }
        if let audio { return audio.isPlaying }
        return synthesizer.isSpeaking && !synthesizer.isPaused
    }
    public var systemSessionID: UUID? { session }

    public static func systemVoices() -> [SystemSpeechVoice] {
        AVSpeechSynthesisVoice.speechVoices().map {
            SystemSpeechVoice(id: $0.identifier, name: $0.name, language: $0.language)
        }
    }

    public func speak(session id: UUID, token: UUID, text: String, locale: String?, ratePercent: Int64,
                      voiceID: String? = nil,
                      receive: @escaping @MainActor (UUID, SpeechPhysicalEvent) -> Void) throws {
        guard id == session, !text.isEmpty else { throw SpeechPhysicalFailure.unavailable }
        stopSlice()
        try AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        if let voiceID {
            guard let voice = AVSpeechSynthesisVoice(identifier: voiceID) else { throw SpeechPhysicalFailure.unavailable }
            utterance.voice = voice
        } else if let locale {
            utterance.voice = AVSpeechSynthesisVoice(language: locale)
        }
        let speed = Float(ratePercent) / 100
        utterance.rate = min(AVSpeechUtteranceMaximumSpeechRate,
                             max(AVSpeechUtteranceMinimumSpeechRate, AVSpeechUtteranceDefaultSpeechRate * speed))
        active = Active(token: token, nativeID: ObjectIdentifier(utterance), receive: receive)
        rate = Double(speed)
        updateNowPlaying(playing: true)
        synthesizer.speak(utterance)
    }

    public func playRemote(session id: UUID, token: UUID, request: M3HttpTtsBuildRequestData,
                           receive: @escaping @MainActor (UUID, SpeechPhysicalEvent) -> Void) async throws {
        guard id == session else { throw CancellationError() }
        stopSlice()
        let media = try await SpeechAudioRequest.load(request, credential: credential)
        try Task.checkCancellation()
        guard id == session else { throw CancellationError() }
        try AVAudioSession.sharedInstance().setActive(true)
        let engine = try AVAudioPlayer(data: media)
        engine.delegate = self
        let speed = Float(request.playback?.ratePercent ?? 100) / 100
        if request.playback?.rateApplied == false {
            engine.enableRate = true
            engine.rate = max(0.5, min(2, speed))
        }
        audio = engine
        active = Active(token: token, nativeID: ObjectIdentifier(engine), receive: receive)
        guard engine.prepareToPlay(), engine.play() else {
            stopSlice()
            throw SpeechPhysicalFailure.unavailable
        }
        rate = Double(speed)
        updateNowPlaying(playing: true)
    }

    public func pause(session id: UUID) {
        guard id == session else { return }
        if synthesizer.isSpeaking { synthesizer.pauseSpeaking(at: .immediate) }
        audio?.pause()
        updateNowPlaying(playing: false)
    }

    public func resume(session id: UUID) throws {
        guard id == session, active != nil else { throw SpeechPhysicalFailure.unavailable }
        try AVAudioSession.sharedInstance().setActive(true)
        if synthesizer.isPaused { synthesizer.continueSpeaking() }
        if let audio, !audio.play() { throw SpeechPhysicalFailure.unavailable }
        updateNowPlaying(playing: true)
    }

    public func stopSlice(session id: UUID? = nil) {
        guard id == nil || id == session else { return }
        active = nil
        synthesizer.stopSpeaking(at: .immediate)
        audio?.stop()
        audio = nil
        if session != nil { updateNowPlaying(playing: false) }
    }

    public func retire(session id: UUID? = nil) {
        guard let owner = session, id == nil || id == owner else { return }
        stopSlice()
        session = nil
        title = nil
        chapter = nil
        player.nowPlayingInfo = nil
        player.playbackState = .stopped
        for (command, target) in remoteTargets { command.removeTarget(target) }
        remoteTargets.removeAll()
        if let interruption {
            NotificationCenter.default.removeObserver(interruption)
            self.interruption = nil
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func deliver(_ event: SpeechPhysicalEvent, nativeID: ObjectIdentifier) {
        guard let current = active, current.nativeID == nativeID else { return }
        switch event {
        case .range: break
        case .finished, .failed:
            active = nil
            audio = nil
            updateNowPlaying(playing: false)
        }
        current.receive(current.token, event)
    }

    private func updateNowPlaying(playing: Bool) {
        guard let title else { return }
        player.nowPlayingInfo = [
            MPMediaItemPropertyTitle: title,
            MPMediaItemPropertyAlbumTitle: chapter ?? "",
            MPNowPlayingInfoPropertyMediaType: MPNowPlayingInfoMediaType.audio.rawValue,
            MPNowPlayingInfoPropertyPlaybackRate: playing ? rate : 0,
        ]
        player.playbackState = playing ? .playing : .paused
    }

    private func registerRemoteControls(_ receive: @escaping @MainActor @Sendable (SpeechRemoteAction) -> Void) {
        let commands = MPRemoteCommandCenter.shared()
        let enabled: [(MPRemoteCommand, SpeechRemoteAction)] = [
            (commands.playCommand, .play), (commands.pauseCommand, .pause),
            (commands.togglePlayPauseCommand, .toggle), (commands.stopCommand, .stop),
            (commands.nextTrackCommand, .next), (commands.previousTrackCommand, .previous),
        ]
        for (command, action) in enabled {
            command.isEnabled = true
            let target = command.addTarget { _ in
                Task { @MainActor in receive(action) }
                return .success
            }
            remoteTargets.append((command, target))
        }
    }
}

extension SpeechAndMediaHost: AVSpeechSynthesizerDelegate, AVAudioPlayerDelegate {
    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString range: NSRange,
                                              utterance: AVSpeechUtterance) {
        let nativeID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.deliver(.range(range), nativeID: nativeID) }
    }

    nonisolated public func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let nativeID = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.deliver(.finished, nativeID: nativeID) }
    }

    nonisolated public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        let nativeID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in self?.deliver(flag ? .finished : .failed, nativeID: nativeID) }
    }

    nonisolated public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: (any Error)?) {
        let nativeID = ObjectIdentifier(player)
        Task { @MainActor [weak self] in self?.deliver(.failed, nativeID: nativeID) }
    }
}
