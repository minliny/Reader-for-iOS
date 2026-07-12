// CoreBridge
//
// HostHttpCapability — UI/reducer-initiated `http.execute` / `http.cancel`.
//
// Bridges the contract `HostRequest` (type `.http_execute/.http_cancel`) to the
// existing `HTTPClient` protocol (production: `URLSessionHTTPClient`). This is
// the UI-side mirror of the Core-side `http.execute` lane routed by
// `HostRequestRouter`.
//
// Tier: simulatorProof — `URLSessionHTTPClient` works on macOS `swift build`
// for unit tests, but live HTTP requests against external hosts are only
// meaningful on the iOS simulator or a real device. The handler itself is
// cross-platform; the tier is `simulatorProof` because the proof tests assert
// live network behavior.
//
// Payload contract (mirrors Core `http.execute` params):
// - `.http_execute`:
//   `{ url: String, method?: String, headers?: {String:String}, body?: String,
//      timeout?: Double, useCookieJar?: Bool, scopeKey?: {sourceId,host},
//      followRedirects?: Bool }`
//   → `{ status: Int, headers: {String:String}, body: String, finalUrl?: String,
//        cookies?: [{name, value}] }`
// - `.http_cancel`:
//   `{ requestId: String }` → `{ cancelled: Bool, requestId: String }`

import Foundation
import ReaderCoreProtocols
import ReaderUIContract

public struct HostHttpCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.http_execute, .http_cancel]
    public let tier: HostCapabilityTier = .simulatorProof

    private let httpClient: HTTPClient
    private let requestScopedClient: (any RequestScopedHTTPClient)?

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
        self.requestScopedClient = httpClient as? any RequestScopedHTTPClient
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .http_execute:
            return try await handleExecute(request)
        case .http_cancel:
            return handleCancel(request)
        default:
            return .failure(.notImplemented(request.type, "HostHttpCapability does not handle \(request.type.rawValue)"))
        }
    }

    // MARK: - http.execute

    private func handleExecute(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        let payload = request.payload
        guard let urlString = payload["url"]?.value as? String, !urlString.isEmpty else {
            return .failure(.invalidParams("http.execute requires non-empty `url`"))
        }
        let method = (payload["method"]?.value as? String) ?? "GET"
        let headers = Self.stringDictionary(payload["headers"]?.value) ?? [:]
        let bodyString = payload["body"]?.value as? String
        let body = bodyString?.data(using: .utf8)
        let timeout = (payload["timeout"]?.value as? Double) ?? 15.0
        let useCookieJar = (payload["useCookieJar"]?.value as? Bool) ?? false
        let scopeKey = extractScopeKey(payload)
        let followRedirects = payload["followRedirects"]?.value as? Bool

        var httpRequest = HTTPRequest(
            url: urlString,
            method: method,
            headers: headers,
            body: body,
            timeout: timeout,
            useCookieJar: useCookieJar,
            cookieScopeKey: scopeKey
        )
        if let followRedirects = followRedirects {
            httpRequest.followRedirects = followRedirects
        }

        do {
            let response: HTTPResponse
            if let requestId = request.requestId?.trimmingCharacters(in: .whitespacesAndNewlines),
               !requestId.isEmpty,
               let requestScopedClient {
                response = try await requestScopedClient.send(httpRequest, requestId: requestId)
            } else {
                response = try await httpClient.send(httpRequest)
            }
            var result = buildResult(from: response)
            if let requestId = request.requestId, !requestId.isEmpty {
                result["requestId"] = AnyCodable(requestId)
            }
            return .success(result)
        } catch {
            return .failure(.underlying("http.execute failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - http.cancel

    private func handleCancel(_ request: HostRequest) -> HostCapabilityOutcome {
        guard let requestId = request.payload["requestId"]?.value as? String,
              !requestId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.invalidParams("http.cancel requires non-empty `requestId`"))
        }
        guard let requestScopedClient else {
            return .failure(.notImplemented(
                .http_cancel,
                "configured HTTPClient does not support request-scoped cancellation"
            ))
        }
        let cancelled = requestScopedClient.cancel(requestId: requestId)
        return .success([
            "cancelled": AnyCodable(cancelled),
            "requestId": AnyCodable(requestId),
        ])
    }

    // MARK: - Helpers

    private func buildResult(from response: HTTPResponse) -> [String: AnyCodable] {
        let bodyString = response.data.isEmpty
            ? ""
            : (String(data: response.data, encoding: .utf8) ?? "")
        var result: [String: AnyCodable] = [
            "status": AnyCodable(response.statusCode),
            "headers": AnyCodable(response.headers.reduce(into: [String: AnyCodable]()) { acc, kv in
                acc[kv.key] = AnyCodable(kv.value)
            }),
            "body": AnyCodable(bodyString),
        ]
        if let finalUrl = response.finalUrl {
            result["finalUrl"] = AnyCodable(finalUrl)
        }
        let cookies = Self.extractCookies(from: response.headers)
        if !cookies.isEmpty {
            result["cookies"] = AnyCodable(cookies.map { AnyCodable($0) })
        }
        return result
    }

    private func extractScopeKey(_ payload: [String: AnyCodable]) -> CookieJarScopeKey? {
        guard let scopeDict = Self.stringDictionary(payload["scopeKey"]?.value),
              let sourceId = scopeDict["sourceId"],
              let host = scopeDict["host"] else {
            return nil
        }
        return CookieJarScopeKey(sourceId: sourceId, host: host)
    }

    private static func stringDictionary(_ raw: (any Sendable)?) -> [String: String]? {
        if let values = raw as? [String: String] { return values }
        if let values = raw as? [String: AnyCodable] {
            var result: [String: String] = [:]
            for (key, value) in values {
                guard let string = value.value as? String else { return nil }
                result[key] = string
            }
            return result
        }
        if let values = raw as? [String: Any] {
            var result: [String: String] = [:]
            for (key, value) in values {
                guard let string = value as? String else { return nil }
                result[key] = string
            }
            return result
        }
        return nil
    }

    /// Best-effort `Set-Cookie` parse — mirrors `HostRequestRouter.extractCookies`
    /// so the UI gets the same cookie payload shape as the Core-side lane.
    static func extractCookies(from headers: [String: String]) -> [[String: AnyCodable]] {
        var setCookieValues: [String] = []
        for (key, value) in headers where key.lowercased() == "set-cookie" {
            setCookieValues.append(value)
        }
        guard !setCookieValues.isEmpty else { return [] }
        var cookies: [[String: AnyCodable]] = []
        for raw in setCookieValues {
            for fragment in raw.split(separator: ",") {
                let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
                let segment = trimmed.contains(";") ? String(trimmed[..<trimmed.firstIndex(of: ";")!]) : trimmed
                if let eqIndex = segment.firstIndex(of: "=") {
                    let name = String(segment[..<eqIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
                    let value = String(segment[segment.index(after: eqIndex)...])
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty {
                        cookies.append(["name": AnyCodable(name), "value": AnyCodable(value)])
                    }
                }
            }
        }
        return cookies
    }
}
