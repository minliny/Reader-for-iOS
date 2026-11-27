import Foundation
import ReaderCoreBridge
import ReaderHost

enum SpeechEngineChoice: Hashable {
    case system(voiceID: String?)
    case http(id: Int64)

    var coreEngine: String {
        switch self {
        case .system: "system"
        case .http(let id): "http-tts:\(id)"
        }
    }

    var engine: SpeechSessionCoordinator.Engine {
        switch self {
        case .system(let id): id.map { .systemVoice(id: $0) } ?? .system(locale: nil)
        case .http(let id): .http(id: id)
        }
    }
}

struct SpeechSystemVoice: Identifiable, Hashable {
    let id: String
    let name: String
    let language: String
}

struct SpeechConfiguration {
    let runtime: CoreRuntimeActor
    private static let voiceKey = "reader.tts.systemVoice"
    private static let defaultConfig = M3TtsConfigData(engine: "system", rate: 5, pitch: 5, followSys: true,
                                                       ratePercent: 100)

    struct Selection {
        let choice: SpeechEngineChoice
        let title: String
        let ratePercent: Int64
    }

    struct Catalog {
        let selected: Selection
        let voices: [SpeechSystemVoice]
        let engines: [M3HttpTtsData]
    }

    @MainActor func activeSelection() async throws -> Selection {
        let config = try await self.config()
        if let id = remoteID(config.engine),
           let entry = try await runtime.request(ReaderM3.httpTtsGet, .init(id: id)).value.tts {
            return selection(config: config, voices: [], engines: [entry])
        }
        let voices = UserDefaults.standard.string(forKey: Self.voiceKey) == nil ? [] : systemVoices()
        return selection(config: config, voices: voices, engines: [])
    }

    @MainActor func catalog() async throws -> Catalog {
        async let available = runtime.request(ReaderM3.httpTtsList, .init()).value.items
        let config = try await self.config()
        let engines = try await available
        let voices = systemVoices()
        return Catalog(selected: selection(config: config, voices: voices, engines: engines),
                       voices: voices, engines: engines)
    }

    @MainActor private func systemVoices() -> [SpeechSystemVoice] {
        SpeechAndMediaHost.systemVoices().sorted {
            if $0.language != $1.language {
                if $0.language.hasPrefix("zh") != $1.language.hasPrefix("zh") { return $0.language.hasPrefix("zh") }
                return $0.language < $1.language
            }
            return ($0.name, $0.id) < ($1.name, $1.id)
        }.map { SpeechSystemVoice(id: $0.id, name: $0.name, language: $0.language) }
    }

    @MainActor func choose(_ choice: SpeechEngineChoice) async throws -> Selection {
        let current = try await catalog()
        switch choice {
        case .system(let voiceID):
            if let voiceID, !current.voices.contains(where: { $0.id == voiceID }) {
                throw SpeechPhysicalFailure.unavailable
            }
        case .http(let id):
            guard current.engines.contains(where: { $0.id == id }) else { throw SpeechPhysicalFailure.unavailable }
        }
        let previous = try await config()
        let accepted = try await runtime.request(ReaderM3.ttsConfigPut,
            .init(engine: choice.coreEngine, rate: previous.rate, pitch: previous.pitch, followSys: previous.followSys,
                  ratePercent: previous.ratePercent)).value.config
        guard accepted.engine == choice.coreEngine else { throw SpeechPhysicalFailure.unavailable }
        if case .system(let voiceID) = choice {
            UserDefaults.standard.set(voiceID, forKey: Self.voiceKey)
        }
        return selection(config: accepted, voices: current.voices, engines: current.engines)
    }

    func changeRate(_ percent: Int64) async throws -> Int64 {
        let previous = try await config()
        let accepted = try await runtime.request(ReaderM3.ttsConfigPut,
            .init(engine: previous.engine, rate: Self.legacyRate(percent), pitch: previous.pitch,
                  followSys: previous.followSys, ratePercent: percent)).value.config
        guard accepted.ratePercent == percent else { throw SpeechPhysicalFailure.unavailable }
        return percent
    }

    static func legacyRate(_ percent: Int64) -> Int64 {
        min(10, max(1, (percent + 10) / 20))
    }

    private func config() async throws -> M3TtsConfigData {
        try await runtime.request(ReaderM3.ttsConfigGet, .init()).value.config ?? Self.defaultConfig
    }

    @MainActor private func selection(config: M3TtsConfigData, voices: [SpeechSystemVoice],
                                      engines: [M3HttpTtsData]) -> Selection {
        let rate = config.ratePercent.flatMap { (50...200).contains($0) && $0.isMultiple(of: 5) ? $0 : nil } ?? 100
        if let id = remoteID(config.engine), let descriptor = engines.first(where: { $0.id == id }) {
            return Selection(choice: .http(id: id), title: descriptor.name, ratePercent: rate)
        }
        let voiceID = UserDefaults.standard.string(forKey: Self.voiceKey)
        let voice = voices.first { $0.id == voiceID }
        return Selection(choice: .system(voiceID: voice?.id), title: voice?.name ?? "系统音色", ratePercent: rate)
    }

    private func remoteID(_ engine: String?) -> Int64? {
        let prefix = "http-tts:"
        guard let engine, engine.hasPrefix(prefix) else { return nil }
        return Int64(engine.dropFirst(prefix.count))
    }
}
