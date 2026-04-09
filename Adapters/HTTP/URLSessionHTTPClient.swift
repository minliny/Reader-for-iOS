import Foundation
import ReaderCoreProtocols
import ReaderCoreModels

private actor RedirectResponseStore {
    private var responses: [HTTPURLResponse] = []

    func append(_ response: HTTPURLResponse) {
        responses.append(response)
    }

    func snapshot() -> [HTTPURLResponse] {
        responses
    }
}

private final class RedirectCaptureDelegate: NSObject, URLSessionTaskDelegate {
    private let followRedirects: Bool
    private let store = RedirectResponseStore()

    init(followRedirects: Bool) {
        self.followRedirects = followRedirects
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        Task {
            await store.append(response)
        }
        completionHandler(followRedirects ? request : nil)
    }

    func redirectResponses() async -> [HTTPURLResponse] {
        await store.snapshot()
    }
}

public final class URLSessionHTTPClient: HTTPAdapterProtocol, @unchecked Sendable {
    private let session: URLSession
    private let cookieJar: CookieJar?
    private let defaultHeaders: [String: String]
    private let followRedirects: Bool

    public init(
        configuration: URLSessionConfiguration = .default,
        cookieJar: CookieJar? = nil,
        defaultHeaders: [String: String] = [:],
        followRedirects: Bool = true
    ) {
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
        self.cookieJar = cookieJar
        self.defaultHeaders = defaultHeaders
        self.followRedirects = followRedirects
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        guard let url = validatedURL(from: request.url) else {
            throw ReaderError.config(
                failureType: .RULE_INVALID,
                stage: Stage.NETWORK.rawValue,
                ruleField: "url",
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
                let existingCookieHeader = urlRequest.value(forHTTPHeaderField: "Cookie")
                let mergedCookieHeader = [existingCookieHeader, cookieValue]
                    .compactMap { $0 }
                    .filter { !$0.isEmpty }
                    .joined(separator: existingCookieHeader == nil ? "" : "; ")
                urlRequest.setValue(mergedCookieHeader, forHTTPHeaderField: "Cookie")
            }
        }

        do {
            let redirectDelegate = RedirectCaptureDelegate(followRedirects: followRedirects)
            let (data, response) = try await session.data(for: urlRequest, delegate: redirectDelegate)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw ReaderError.network(
                    failureType: .CONTENT_FAILED,
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
                for redirectResponse in await redirectDelegate.redirectResponses() {
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
            switch error.code {
            case .timedOut:
                throw ErrorMapper.readerError(for: .timeout)
            default:
                throw ErrorMapper.readerError(for: .networkError(error.localizedDescription))
            }
        } catch {
            throw ErrorMapper.readerError(for: .networkError(error.localizedDescription))
        }
    }

    private func storeCookies(from response: HTTPURLResponse, jar: CookieJar, fallbackHost: String) async {
        for header in setCookieHeaders(from: response) {
            await jar.setCookies(from: header, domain: fallbackHost)
        }
    }

    private func setCookieHeaders(from response: HTTPURLResponse) -> [String] {
        response.allHeaderFields.compactMap { key, value in
            guard let headerName = key as? String,
                  headerName.caseInsensitiveCompare("Set-Cookie") == .orderedSame
            else {
                return nil
            }

            if let stringValue = value as? String {
                return [stringValue]
            }

            if let stringValues = value as? [String] {
                return stringValues
            }

            return nil
        }
        .flatMap { $0 }
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
