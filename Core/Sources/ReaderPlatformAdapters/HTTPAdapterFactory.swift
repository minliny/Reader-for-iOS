import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import ReaderCoreModels
import ReaderCoreProtocols

public struct HTTPAdapterFactory {
    public static func makeDefault(
        cookieJar: CookieJar? = nil,
        defaultHeaders: [String: String] = [:],
        followRedirects: Bool = true
    ) -> any HTTPAdapterProtocol {
        let configuration: URLSessionConfiguration = .ephemeral
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpCookieStorage = nil
        configuration.urlCache = nil
        return URLSessionHTTPClient(
            configuration: configuration,
            cookieJar: cookieJar,
            defaultHeaders: defaultHeaders,
            followRedirects: followRedirects
        )
    }
}
