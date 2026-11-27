import AVFoundation
import Foundation
import ReaderCoreBridge

enum SpeechAudioRequest {
    @MainActor
    static func load(_ model: M3HttpTtsBuildRequestData,
                     credential: @MainActor (String) throws -> String?) async throws -> Data {
        var headers = model.headers.mapValues(ReaderM1JSONValue.string)
        let contentType = model.contentType ?? model.headers.first { $0.key.lowercased() == "content-type" }?.value
        if let contentType, !headers.keys.contains(where: { $0.lowercased() == "content-type" }) {
            headers["Content-Type"] = .string(contentType)
        }
        if let reference = model.playback?.credentialRef {
            guard let key = model.playback?.credentialHeader, let secret = try credential(reference), !secret.isEmpty else {
                throw SpeechPhysicalFailure.credentialsUnavailable
            }
            headers[key] = .string((model.playback?.credentialPrefix ?? "") + secret)
        }
        let charset = contentType?.split(separator: ";").dropFirst().lazy
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.lowercased().hasPrefix("charset=") }
            .map { String($0.dropFirst("charset=".count)).trimmingCharacters(in: CharacterSet(charactersIn: "\"")) }
        let params = M2HostHttpRequest(url: model.url, method: model.method, headers: headers,
                                       body: model.body, charset: charset, followRedirects: model.playback?.credentialRef == nil)
        let request = try URLSessionNetwork.request(params)
        let result = try await URLSessionNetwork.execute(request, params: params, jar: nil)
        guard (200...299).contains(result.response.statusCode) else {
            throw NetworkHostFailure.status(result.response.statusCode)
        }
        if let playback = model.playback, playback.format == .pcm {
            return try await Task.detached { try wrapPCM(result.data, profile: playback) }.value
        }
        return result.data
    }

    private static func wrapPCM(_ data: Data, profile: M3HttpTtsPlayback) throws -> Data {
        guard let rate = profile.sampleRate, (8_000...192_000).contains(rate),
              let channels = profile.channels,
              let format = AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: Double(rate),
                                         channels: AVAudioChannelCount(channels.rawValue), interleaved: true) else {
            throw SpeechPhysicalFailure.malformedPCM
        }
        let frameBytes = Int(channels.rawValue) * MemoryLayout<Int16>.size
        guard data.count >= frameBytes, data.count % frameBytes == 0 else { throw SpeechPhysicalFailure.malformedPCM }
        let frames = AVAudioFrameCount(data.count / frameBytes)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
            throw SpeechPhysicalFailure.malformedPCM
        }
        buffer.frameLength = frames
        guard let target = buffer.mutableAudioBufferList.pointee.mBuffers.mData else {
            throw SpeechPhysicalFailure.malformedPCM
        }
        data.copyBytes(to: target.assumingMemoryBound(to: UInt8.self), count: data.count)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".wav")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let output = try AVAudioFile(forWriting: url, settings: format.settings,
                                         commonFormat: .pcmFormatInt16, interleaved: true)
            try output.write(from: buffer)
        }
        return try Data(contentsOf: url)
    }
}
