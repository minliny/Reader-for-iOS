import Foundation
import ReaderCoreProtocols
import ReaderCoreModels

private final class RedirectCaptureDelegate: NSObject, URLSessionTaskDelegate {
    private let lock = NSLock()
    private var capturedResponses: [HTTPURLResponse] = []

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lock.lock()
        capturedResponses.append(response)
        lock.unlock()
        completionHandler(request)
    }

    var redirectResponses: [HTTPURLResponse] {
        lock.lock()
        defer { lock.unlock() }
        return capturedResponses
    }
}

public final class URLSessionHTTPClient: HTTPClient, @unchecked Sendable {
    private let session: URLSession
    private let cookieJar: CookieJar?
    private let defaultHeaders: [String: String]

    public init(
        configuration: URLSessionConfiguration = .default,
        cookieJar: CookieJar? = nil,
        defaultHeaders: [String: String] = [:]
    ) {
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        self.session = URLSession(configuration: configuration)
        self.cookieJar = cookieJar
        self.defaultHeaders = defaultHeaders
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let url = validatedURL(from: request.url) else {
            throw ReaderError.network(
                failureType: .INVALID_URL,
                stage: Stage.NETWORK.rawValue,
                message: "Invalid URL: \(request.url)",
                underlyingError: nil
            )
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.timeoutInterval = request.timeout
        urlRequest.httpBody = request.body

        for (key, value) in defaultHeaders {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }
        for (key, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        if request.useCookieJar, let jar = cookieJar {
            let cookies = await jar.getCookies(for: url.host ?? "", path: url.path)
            let cookieValue = cookies.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
            if !cookieValue.isEmpty {
                urlRequest.setValue(cookieValue, forHTTPHeaderField: "Cookie")
            }
        }

        do {
            let redirectDelegate = RedirectCaptureDelegate()
            let (data, response) = try await session.data(for: urlRequest, delegate: redirectDelegate)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReaderError.network(
                    failureType: .NETWORK_ERROR,
                    stage: Stage.NETWORK.rawValue,
                    message: "Non-HTTP response received",
                    underlyingError: nil
                )
            }

            var responseHeaders: [String: String] = [:]
            for (key, value) in httpResponse.allHeaderFields {
                if let k = key as? String, let v = value as? String {
                    responseHeaders[k] = v
                }
            }

            if request.useCookieJar, let jar = cookieJar {
                for redirectResponse in redirectDelegate.redirectResponses {
                    await storeCookies(from: redirectResponse, jar: jar, fallbackHost: redirectResponse.url?.host ?? url.host ?? "")
                }
                await storeCookies(from: httpResponse, jar: jar, fallbackHost: httpResponse.url?.host ?? url.host ?? "")
            }

            return HTTPResponse(
                statusCode: httpResponse.statusCode,
                headers: responseHeaders,
                data: data
            )
        } catch let error as URLError {
            let failureType: FailureType
            switch error.code {
            case .badURL, .unsupportedURL:
                failureType = .INVALID_URL
            case .timedOut:
                failureType = .NETWORK_TIMEOUT
            case .cannotConnectToHost, .cannotFindHost:
                failureType = .NETWORK_ERROR
            case .notConnectedToInternet:
                failureType = .NETWORK_ERROR
            default:
                failureType = .NETWORK_ERROR
            }
            throw ReaderError.network(
                failureType: failureType,
                stage: Stage.NETWORK.rawValue,
                message: "Network error: \(error.localizedDescription)",
                underlyingError: error
            )
        } catch {
            throw ReaderError.network(
                failureType: .NETWORK_ERROR,
                stage: Stage.NETWORK.rawValue,
                message: "Request failed: \(error.localizedDescription)",
                underlyingError: error
            )
        }
    }

    private func storeCookies(from response: HTTPURLResponse, jar: CookieJar, fallbackHost: String) async {
        if let setCookieHeaders = response.allHeaderFields["Set-Cookie"] as? String {
            await jar.setCookies(from: setCookieHeaders, domain: fallbackHost)
        } else if let setCookieHeaders = response.allHeaderFields["Set-Cookie"] as? [String] {
            for header in setCookieHeaders {
                await jar.setCookies(from: header, domain: fallbackHost)
            }
        }
    }

    private func validatedURL(from rawURL: String) -> URL? {
        guard let url = URL(string: rawURL),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              let host = components.host,
              !host.isEmpty,
              scheme == "http" || scheme == "https"
        else {
            return nil
        }

        return url
    }
}
