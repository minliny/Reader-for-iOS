import CryptoKit
import Foundation
import ReaderCoreBridge

enum MediaDownload {
    private static let limit = 128 * 1_024 * 1_024
    private static let segment = 64 * 1_024

    struct Result: Sendable {
        let receipt: M2HostMediaDownloadResponse
        let responses: [HTTPURLResponse]
    }

    static func execute(_ model: M2HostMediaDownloadRequest, directory: URL,
                        jar: HTTPCookieStorage?) async throws -> Result {
        var request = URLRequest(url: try hostHTTPURL(model.url), cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: URLSessionNetwork.timeoutSeconds(model.timeoutMillis))
        request.httpMethod = (model.method ?? .get).rawValue
        for (field, value) in model.headers ?? [:] { request.setValue(value, forHTTPHeaderField: field) }
        if let etag = model.ifNoneMatch { request.setValue(etag, forHTTPHeaderField: "If-None-Match") }
        if let since = model.ifModifiedSince { request.setValue(since, forHTTPHeaderField: "If-Modified-Since") }
        let maximum = min(Int64(limit), model.maxBytes ?? Int64(limit))
        guard maximum > 0 else { throw NetworkHostFailure.invalid("Invalid media byte budget") }
        let start = model.rangeStart
        if let start {
            guard start >= 0, model.rangeEnd.map({ $0 >= start }) ?? true else {
                throw NetworkHostFailure.invalid("Invalid media range")
            }
            request.setValue("bytes=\(start)-\(model.rangeEnd.map(String.init) ?? "")", forHTTPHeaderField: "Range")
            request.setValue("identity", forHTTPHeaderField: "Accept-Encoding")
        } else if model.rangeEnd != nil {
            throw NetworkHostFailure.invalid("Media range start is missing")
        }
        let policy = HostRedirectPolicy(follow: true, max: 10)
        let session = URLSessionNetwork.session(timeout: request.timeoutInterval, jar: jar)
        defer { session.invalidateAndCancel() }
        let (bytes, raw) = try await session.bytes(for: request, delegate: policy)
        guard let response = raw as? HTTPURLResponse else { throw NetworkHostFailure.invalid("Missing media response") }
        let observations = policy.observations()
        guard !observations.limitExceeded else {
            throw NetworkHostFailure(code: .httpError, phase: .transport, message: "Media redirect limit exceeded")
        }
        guard (200...299).contains(response.statusCode) || response.statusCode == 304 else {
            throw NetworkHostFailure.status(response.statusCode)
        }
        let resource = model.cacheKey ?? UUID().uuidString
        let responses = observations.responses + [response]
        if model.method == .head || response.statusCode == 304 {
            return .init(receipt: receipt(resource: resource, response: response, path: nil, bytes: 0, hash: nil),
                         responses: responses)
        }
        let rangeLength = try validateRange(start: start, end: model.rangeEnd, response: response)
        guard response.expectedContentLength <= maximum, rangeLength.map({ $0 <= maximum }) ?? true else {
            throw NetworkHostFailure.invalid("Media response exceeds byte budget")
        }

        let files = FileManager.default
        try files.createDirectory(at: directory, withIntermediateDirectories: true)
        let destination = try destination(savePath: model.savePath, directory: directory)
        let temporary = directory.appendingPathComponent(".\(UUID().uuidString).partial")
        guard files.createFile(atPath: temporary.path, contents: nil) else {
            throw NetworkHostFailure(code: .internal, phase: .storage, message: "Media staging file unavailable")
        }
        defer { try? files.removeItem(at: temporary) }
        let output = try FileHandle(forWritingTo: temporary)
        defer { try? output.close() }
        var hash = SHA256()
        var count: Int64 = 0
        var chunk = Data(capacity: segment)
        for try await byte in bytes {
            guard count < maximum else { throw NetworkHostFailure.invalid("Media response exceeds byte budget") }
            chunk.append(byte)
            count += 1
            if chunk.count == segment {
                try Task.checkCancellation()
                try output.write(contentsOf: chunk)
                hash.update(data: chunk)
                chunk.removeAll(keepingCapacity: true)
            }
        }
        if !chunk.isEmpty {
            try output.write(contentsOf: chunk)
            hash.update(data: chunk)
        }
        if let rangeLength, rangeLength != count {
            throw NetworkHostFailure.invalid("Media range length does not match body")
        }
        try output.synchronize()
        try output.close()
        try Task.checkCancellation()
        try files.moveItem(at: temporary, to: destination)
        let digest = hash.finalize().map { String(format: "%02x", $0) }.joined()
        return .init(receipt: receipt(resource: resource, response: response, path: destination.path,
                                      bytes: count, hash: digest), responses: responses)
    }

    private static func destination(savePath: String?, directory: URL) throws -> URL {
        guard let savePath else { return directory.appendingPathComponent("\(UUID().uuidString).media") }
        let target = savePath.hasPrefix("/") ? URL(filePath: savePath).standardizedFileURL
            : directory.appendingPathComponent(savePath).standardizedFileURL
        guard target.deletingLastPathComponent().path == directory.standardizedFileURL.path,
              !target.lastPathComponent.hasPrefix(".") else {
            throw NetworkHostFailure(code: .permissionDenied, phase: .storage, message: "Media destination is outside Host storage")
        }
        return target
    }

    private static func receipt(resource: String, response: HTTPURLResponse, path: String?,
                                bytes: Int64, hash: String?) -> M2HostMediaDownloadResponse {
        .init(resourceId: resource, tempPath: path, statusCode: Int64(response.statusCode),
              contentType: response.mimeType, contentLength: response.expectedContentLength >= 0 ? response.expectedContentLength : nil,
              etag: response.value(forHTTPHeaderField: "ETag"), byteLength: bytes,
              sha256: hash, fromCache: false, finalUrl: response.url?.absoluteString)
    }

    private static func validateRange(start: Int64?, end: Int64?, response: HTTPURLResponse) throws -> Int64? {
        guard let start else { return nil }
        guard response.statusCode == 206, let header = response.value(forHTTPHeaderField: "Content-Range"),
              header.hasPrefix("bytes ") else {
            throw NetworkHostFailure.invalid("Media server did not honor range")
        }
        let parts = header.dropFirst("bytes ".count).split(separator: "/", omittingEmptySubsequences: false)
        guard parts.count == 2 else { throw NetworkHostFailure.invalid("Malformed media range") }
        let offsets = parts[0].split(separator: "-")
        guard offsets.count == 2, Int64(offsets[0]) == start,
              let last = Int64(offsets[1]), last >= start, last < Int64.max,
              end.map({ last <= $0 }) ?? true else {
            throw NetworkHostFailure.invalid("Returned media range does not match request")
        }
        if let total = Int64(parts[1]) {
            guard last < total, last == min(end ?? total - 1, total - 1) else {
                throw NetworkHostFailure.invalid("Incomplete media range")
            }
        } else if parts[1] != "*" || end.map({ $0 != last }) == true {
            throw NetworkHostFailure.invalid("Invalid media range total")
        }
        return last - start + 1
    }
}
