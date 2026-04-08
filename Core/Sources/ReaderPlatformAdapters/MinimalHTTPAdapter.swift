import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ReaderCoreProtocols

/// Minimal reference adapter for platform network calls.
public final class MinimalHTTPAdapter: HTTPClient, @unchecked Sendable {
    private let session: URLSession

    public init(configuration: URLSessionConfiguration = .default) {
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let url = URL(string: request.url) else {
            throw URLError(.badURL)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        urlRequest.timeoutInterval = request.timeout
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }

        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            guard let headerKey = key as? String else {
                continue
            }
            headers[headerKey] = "\(value)"
        }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            data: data
        )
    }
}
