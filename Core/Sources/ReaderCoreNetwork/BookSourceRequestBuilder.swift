import Foundation
import ReaderCoreProtocols
import ReaderCoreModels

public final class BookSourceRequestBuilder: RequestBuilder {
    public init() {}

    public func makeSearchRequest(source: BookSource, query: SearchQuery) throws -> HTTPRequest {
        guard let searchUrlTemplate = source.searchUrl, !searchUrlTemplate.isEmpty else {
            throw ReaderError.config(
                failureType: .FIELD_MISSING,
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

        guard validatedAbsoluteURLString(finalUrl) != nil else {
            throw ReaderError.config(
                failureType: .RULE_INVALID,
                stage: Stage.REQUEST_BUILD.rawValue,
                ruleField: "searchUrl",
                message: "searchUrl must resolve to an absolute http(s) URL",
                underlyingError: nil
            )
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
                failureType: .RULE_INVALID,
                stage: Stage.REQUEST_BUILD.rawValue,
                ruleField: "detailURL",
                message: "detailURL is empty",
                underlyingError: nil
            )
        }
        guard validatedAbsoluteURLString(detailURL) != nil else {
            throw ReaderError.config(
                failureType: .RULE_INVALID,
                stage: Stage.REQUEST_BUILD.rawValue,
                ruleField: "detailURL",
                message: "detailURL must be an absolute http(s) URL",
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
                failureType: .RULE_INVALID,
                stage: Stage.REQUEST_BUILD.rawValue,
                ruleField: "chapterURL",
                message: "chapterURL is empty",
                underlyingError: nil
            )
        }
        guard validatedAbsoluteURLString(chapterURL) != nil else {
            throw ReaderError.config(
                failureType: .RULE_INVALID,
                stage: Stage.REQUEST_BUILD.rawValue,
                ruleField: "chapterURL",
                message: "chapterURL must be an absolute http(s) URL",
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

    private func validatedAbsoluteURLString(_ rawURL: String) -> URL? {
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
