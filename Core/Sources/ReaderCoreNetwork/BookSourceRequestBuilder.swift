import Foundation
import ReaderCoreProtocols
import ReaderCoreModels

public final class BookSourceRequestBuilder: RequestBuilder {
    public init() {}

    public func makeSearchRequest(source: BookSource, query: SearchQuery) throws -> HTTPRequest {
        guard let searchUrlTemplate = source.searchUrl, !searchUrlTemplate.isEmpty else {
            throw ReaderError.config(
                failureType: .MISSING_REQUIRED_RULE,
                stage: Stage.REQUEST_BUILD.rawValue,
                ruleField: "searchUrl",
                message: "searchUrl is required",
                underlyingError: nil
            )
        }

        let encodedKeyword = query.keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query.keyword
        let url = searchUrlTemplate
            .replacingOccurrences(of: "{{key}}", with: encodedKeyword)
            .replacingOccurrences(of: "{{keyword}}", with: encodedKeyword)
            .replacingOccurrences(of: "{{page}}", with: "\(query.page)")

        var method = "GET"
        var body: Data?
        var finalUrl = url

        if let commaIndex = url.firstIndex(of: ",") {
            let maybeMethod = String(url[..<commaIndex]).uppercased()
            if ["GET", "POST", "PUT", "DELETE", "PATCH"].contains(maybeMethod) {
                method = maybeMethod
                let rest = String(url[url.index(after: commaIndex)...])
                if let bodyIndex = rest.firstIndex(of: ",") {
                    finalUrl = String(rest[..<bodyIndex])
                    let bodyStr = String(rest[rest.index(after: bodyIndex)...])
                    body = bodyStr.data(using: .utf8)
                } else {
                    finalUrl = rest
                }
            }
        }

        var headers = source.header
        if headers["User-Agent"] == nil {
            headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        }

        return HTTPRequest(
            url: finalUrl,
            method: method,
            headers: headers,
            body: body,
            timeout: 15,
            useCookieJar: source.enabledCookieJar
        )
    }

    public func makeTOCRequest(source: BookSource, detailURL: String) throws -> HTTPRequest {
        guard !detailURL.isEmpty else {
            throw ReaderError.config(
                failureType: .INVALID_URL,
                stage: Stage.REQUEST_BUILD.rawValue,
                message: "detailURL is empty",
                underlyingError: nil
            )
        }

        var headers = source.header
        if headers["User-Agent"] == nil {
            headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        }
        if headers["Referer"] == nil, let baseUrl = source.bookSourceUrl {
            headers["Referer"] = baseUrl
        }

        return HTTPRequest(
            url: detailURL,
            method: "GET",
            headers: headers,
            body: nil,
            timeout: 15,
            useCookieJar: source.enabledCookieJar
        )
    }

    public func makeContentRequest(source: BookSource, chapterURL: String) throws -> HTTPRequest {
        guard !chapterURL.isEmpty else {
            throw ReaderError.config(
                failureType: .INVALID_URL,
                stage: Stage.REQUEST_BUILD.rawValue,
                message: "chapterURL is empty",
                underlyingError: nil
            )
        }

        var headers = source.header
        if headers["User-Agent"] == nil {
            headers["User-Agent"] = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        }
        if headers["Referer"] == nil, let baseUrl = source.bookSourceUrl {
            headers["Referer"] = baseUrl
        }

        return HTTPRequest(
            url: chapterURL,
            method: "GET",
            headers: headers,
            body: nil,
            timeout: 15,
            useCookieJar: source.enabledCookieJar
        )
    }
}
