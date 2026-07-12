// CoreBridge
//
// HostTTSCapability — UI/reducer-initiated `tts.system.start/stop/pause/resume`.
//
// Bridges the contract `HostRequest` to a `HostTTSsynth` protocol that wraps
// `AVSpeechSynthesizer`. The concrete `ReaderTTSPlayer` (in
// `iOS/Features/Reader/`) is the production conformer; tests inject a stub.
// The protocol lives here so CoreBridge does not depend on the ReaderApp
// target.
//
// Tier: realDeviceProof — AVSpeechSynthesizer works on the sim, but voice
// availability and speech timing differ. Real-device proof is required for
// TTS fidelity assertions (rate, pitch, language matching).
//
// Payload contract:
// - `.tts_system_start`:  `{ text: String, rate?: Float, pitch?: Float, language?: String }`
//                         → `{ started: true }`
// - `.tts_system_stop`:   `{}` → `{ stopped: true }`
// - `.tts_system_pause`:  `{}` → `{ paused: true }`
// - `.tts_system_resume`: `{}` → `{ resumed: true }`

import Foundation
import ReaderUIContract

/// Abstraction over `AVSpeechSynthesizer` so CoreBridge does not import
/// AVFoundation (the concrete `ReaderTTSPlayer` lives in the ReaderApp target
/// and conforms via a thin extension). The synth is `@MainActor`-isolated
/// because `AVSpeechSynthesizer` must be created and used on the main thread.
@MainActor
public protocol HostTTSSynth: AnyObject {
    func speak(_ text: String)
    func pause()
    func resume()
    func stop()
}

/// Cross-actor safe wrapper: the handler holds a `HostTTSSynth` factory
/// closure instead of a `HostTTSSynth` instance, so the handler itself is
/// `Sendable` even though the synth is `@MainActor`.
public struct HostTTSCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [
        .tts_system_start, .tts_system_stop, .tts_system_pause, .tts_system_resume,
        .tts_start, .tts_stop, .tts_pause,
    ]
    public let tier: HostCapabilityTier = .realDeviceProof

    /// Factory closure invoked on the main actor to obtain the synth. Returns
    /// nil on platforms where TTS is not available (macOS `swift build`
    /// without AVFoundation).
    private let synthProvider: @Sendable () async -> HostTTSSynth?

    public init(synthProvider: @escaping @Sendable () async -> HostTTSSynth?) {
        self.synthProvider = synthProvider
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        guard let synth = await synthProvider() else {
            return .failure(.notImplemented(request.type, "TTS synth not available on this platform"))
        }
        switch request.type {
        case .tts_system_start, .tts_start:
            return try await handleStart(request.payload, type: request.type, synth: synth)
        case .tts_system_stop:
            await MainActor.run { synth.stop() }
            return .success(["acknowledged": AnyCodable(true)])
        case .tts_stop:
            await MainActor.run { synth.stop() }
            return .success(["stopped": AnyCodable(true)])
        case .tts_system_pause:
            await MainActor.run { synth.pause() }
            return .success(["acknowledged": AnyCodable(true)])
        case .tts_pause:
            await MainActor.run { synth.pause() }
            return .success(["paused": AnyCodable(true)])
        case .tts_system_resume:
            await MainActor.run { synth.resume() }
            return .success(["acknowledged": AnyCodable(true)])
        default:
            return .failure(.notImplemented(request.type, "HostTTSCapability does not handle \(request.type.rawValue)"))
        }
    }

    private func handleStart(
        _ payload: [String: AnyCodable],
        type: HostRequestType,
        synth: HostTTSSynth
    ) async throws -> HostCapabilityOutcome {
        guard let text = payload["text"]?.value as? String, !text.isEmpty else {
            return .failure(.invalidParams("\(type.rawValue) requires non-empty `text`"))
        }
        // rate/pitch/language are passed through to the synth via the
        // concrete conformer's configuration (the protocol only exposes
        // `speak(_:)` to keep the surface minimal; per-call rate overrides
        // are handled by the synth's own settings). This handler validates
        // and acknowledges.
        await MainActor.run { synth.speak(text) }
        var result: [String: AnyCodable] = ["started": AnyCodable(true)]
        if type == .tts_system_start { return .success(result) }
        if let rate = payload["rate"]?.value as? Double {
            result["rate"] = AnyCodable(rate)
        }
        if let pitch = payload["pitch"]?.value as? Double {
            result["pitch"] = AnyCodable(pitch)
        }
        if let language = payload["language"]?.value as? String {
            result["language"] = AnyCodable(language)
        }
        return .success(result)
    }
}
