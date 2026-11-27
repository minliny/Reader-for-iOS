import Foundation

public enum SourceDocumentFile {
    public enum Failure: Error {
        case invalidURL
        case exceedsLimit
    }

    public static func read(_ url: URL) async throws -> Data {
        try await Task.detached {
            guard url.isFileURL else { throw Failure.invalidURL }
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let file = try FileHandle(forReadingFrom: url)
            defer { try? file.close() }

            let limit = 8 * 1_024 * 1_024
            var data = Data()
            while let block = try file.read(upToCount: min(64 * 1_024, limit - data.count + 1)), !block.isEmpty {
                guard block.count <= limit - data.count else { throw Failure.exceedsLimit }
                data.append(block)
            }
            return data
        }.value
    }
}
