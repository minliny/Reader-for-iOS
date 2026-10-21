import Foundation

public protocol ReaderRemoteImageServing: ReaderLibraryServing {
    func remoteImage(sourceID: String, url: String) async throws -> Data
}
extension ReaderLibraryService: ReaderRemoteImageServing {
    public func remoteImage(sourceID: String, url: String) async throws -> Data {
        guard sourceID != "local", !url.isEmpty, let hostTransport else { throw ReaderLibraryError.invalidResponse("remote image identity") }
        let response = try object(await coreRead("source.imageRequest", ["sourceId": sourceID, "imageUrl": url]))
        guard let request = response["request"] as? [String: Any] else { throw ReaderLibraryError.invalidResponse("image request descriptor") }
        return try await hostTransport.fetchImage(parameters: request, sourceID: sourceID)
    }
}
