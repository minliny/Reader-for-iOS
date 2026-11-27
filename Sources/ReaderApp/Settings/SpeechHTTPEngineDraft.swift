import Foundation
import ReaderCoreBridge
import ReaderHost

struct SpeechHTTPProfile: Codable {
    enum Format: String, CaseIterable {
        case mp3, wav, pcm
    }

    enum RequestProtocol: String, CaseIterable {
        case auto
        case template = "template-get"
        case openAI = "openai-speech"
        case azure = "azure-speech"

        var title: String {
            switch self {
            case .auto: "自动"
            case .template: "GET 模板"
            case .openAI: "OpenAI 兼容"
            case .azure: "Azure Speech"
            }
        }
    }

    var version = 1
    var voice: String?
    var format = Format.mp3.rawValue
    var credentialRef: String?
    var requestProtocol: String?
    var model: String?
    var credentialHeader: String?
    var credentialPrefix: String?
    var pcmSampleRate: Int?
    var pcmChannels: Int?

    private enum CodingKeys: String, CodingKey {
        case version, voice, format, credentialRef, model, credentialHeader, credentialPrefix, pcmSampleRate, pcmChannels
        case requestProtocol = "protocol"
    }

    static func read(_ raw: String?) throws -> Self {
        guard let raw else { return Self() }
        return try JSONDecoder().decode(Self.self, from: Data(raw.utf8))
    }
}

struct SpeechHTTPEngineDraft {
    let previous: M3HttpTtsData?
    var name: String
    var url: String
    var voice: String
    var format: SpeechHTTPProfile.Format
    var requestProtocol: SpeechHTTPProfile.RequestProtocol
    var model: String
    var sampleRate: Int
    var channels: Int
    var key = ""
    var removeCredential = false
    var hasCredential: Bool { profile.credentialRef != nil }
    private let profile: SpeechHTTPProfile

    init(existing: M3HttpTtsData? = nil) throws {
        previous = existing
        profile = try SpeechHTTPProfile.read(existing?.readerProfile)
        name = existing?.name ?? ""
        url = existing?.url ?? ""
        voice = profile.voice ?? ""
        format = SpeechHTTPProfile.Format(rawValue: profile.format) ?? .mp3
        requestProtocol = profile.requestProtocol.flatMap(SpeechHTTPProfile.RequestProtocol.init(rawValue:)) ?? .auto
        model = profile.model ?? ""
        sampleRate = profile.pcmSampleRate ?? 24_000
        channels = profile.pcmChannels ?? 1
    }

    var canSave: Bool {
        let endpoint = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let components = URLComponents(string: endpoint), components.scheme?.lowercased() == "https",
              let host = components.host, !host.isEmpty,
              components.user == nil, components.password == nil else { return false }
        return !(removeCredential && endpoint.contains("{{apiKey}}") && key.isEmpty)
    }

    func save(runtime: CoreRuntimeActor) async throws -> M3HttpTtsData {
        guard canSave else { throw SpeechPhysicalFailure.unavailable }
        let id = previous?.id ?? Int64.random(in: 1...9_007_199_254_740_991)
        var updated = profile
        updated.voice = voice.emptyToNil
        updated.format = format.rawValue
        updated.requestProtocol = requestProtocol == .auto ? nil : requestProtocol.rawValue
        updated.model = model.emptyToNil
        updated.pcmSampleRate = format == .pcm ? sampleRate : nil
        updated.pcmChannels = format == .pcm ? channels : nil
        let secret = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let newReference = secret.isEmpty ? nil : "reader.tts.\(id).\(UUID().uuidString.lowercased())"
        if removeCredential { updated.credentialRef = nil }
        if let newReference { updated.credentialRef = newReference }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        let serialized = String(decoding: try encoder.encode(updated), as: UTF8.self)
        let input = M3HttpTtsPutParams(id: id, name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            url: url.trimmingCharacters(in: .whitespacesAndNewlines), contentType: previous?.contentType,
            concurrentRate: previous?.concurrentRate, loginUrl: previous?.loginUrl, loginUi: previous?.loginUi,
            header: previous?.header, jsLib: previous?.jsLib, enabledCookieJar: previous?.enabledCookieJar,
            loginCheckJs: previous?.loginCheckJs,
            lastUpdateTime: Int64(Date().timeIntervalSince1970 * 1000), readerProfile: serialized)

        if let newReference { try SpeechCredentialVault.store(secret, reference: newReference) }
        do {
            let saved = try await runtime.request(ReaderM3.httpTtsPut, input).value.tts
            guard saved.id == id, saved.readerProfile == serialized else { throw SpeechPhysicalFailure.unavailable }
            if let prior = profile.credentialRef, prior != updated.credentialRef { try? SpeechCredentialVault.remove(prior) }
            return saved
        } catch {
            // A transport error can race a successful write. Only remove the
            // provisional key after Core confirms that this alias did not win.
            if let newReference, let verified = try? await runtime.request(ReaderM3.httpTtsGet, .init(id: id)).value,
               let returned = try? SpeechHTTPProfile.read(verified.tts?.readerProfile),
               returned.credentialRef != newReference {
                try? SpeechCredentialVault.remove(newReference)
            }
            throw error
        }
    }
}

private extension String {
    var emptyToNil: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
