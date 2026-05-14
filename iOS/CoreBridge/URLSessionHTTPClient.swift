import Foundation
import ReaderCoreProtocols

public final class URLSessionHTTPClient: HTTPClient, Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let url = URL(string: request.url) else {
            throw HTTPClientError.invalidURL(request.url)
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method

        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if let body = request.body {
            urlRequest.httpBody = body
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        var headers: [String: String] = [:]
        for (key, value) in httpResponse.allHeaderFields {
            if let key = key as? String, let value = value as? String {
                headers[key] = value
            }
        }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            data: data
        )
    }
}

public enum HTTPClientError: Error, LocalizedError {
    case invalidURL(String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL(let url): return "Invalid URL: \(url)"
        case .invalidResponse: return "Invalid HTTP response"
        }
    }
}
