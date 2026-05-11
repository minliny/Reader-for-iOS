import Foundation

public protocol HTTPClientProtocol: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

public final class IOSHTTPAdapter: HTTPClientProtocol, @unchecked Sendable {
    private let session: URLSession
    private let lock = NSLock()

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        return try await session.data(for: request)
    }
}
