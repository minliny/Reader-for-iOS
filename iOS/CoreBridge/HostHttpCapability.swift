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
//   `{ requestId: String }` → `{ cancelled: true }`
//   (Note: `URLSessionHTTPClient` does not expose per-request cancellation yet;
//   this handler acknowledges the cancel but the actual URLSession task
//   cancellation is a follow-up. The handler is wired so the registry no
//   longer reports `.notConfigured` for `.http_cancel`.)

import Foundation
import ReaderCoreProtocols
import ReaderUIContract

public struct HostHttpCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.http_execute, .http_cancel]
    public let tier: HostCapabilityTier = .simulatorProof

    private let httpClient: HTTPClient

    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .http_execute:
            return try await handleExecute(request.payload)
        case .http_cancel:
            return handleCancel(request.payload)
        default:
            return .failure(.notImplemented(request.type, "HostHttpCapability does not handle \(request.type.rawValue)"))
        }
    }

    // MARK: - http.execute

    private func handleExecute(_ payload: [String: AnyCodable]) async throws -> HostCapabilityOutcome {
        guard let urlString = payload["url"]?.value as? String, !urlString.isEmpty else {
            return .failure(.invalidParams("http.execute requires non-empty `url`"))
        }
        let method = (payload["method"]?.value as? String) ?? "GET"
        let headersDict = (payload["headers"]?.value as? [String: Any]) ?? [:]
        let headers = headersDict.reduce(into: [String: String]()) { acc, kv in
            if let s = kv.value as? String { acc[kv.key] = s }
        }
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
            let response = try await httpClient.send(httpRequest)
            return .success(buildResult(from: response))
        } catch {
            return .failure(.underlying("http.execute failed: \(error.localizedDescription)"))
        }
    }

    // MARK: - http.cancel

    private func handleCancel(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        // Acknowledge the cancel — `URLSessionHTTPClient` does not expose a
        // per-request task registry yet. The contract outcome is success so
        // the UI can clear its loading state; the actual URLSession task
        // cancellation lands when the HTTP client grows a cancel API.
        let requestId = payload["requestId"]?.value as? String ?? ""
        return .success([
            "cancelled": AnyCodable(true),
            "requestId": AnyCodable(requestId),
            "note": AnyCodable("URLSessionHTTPClient per-request cancellation not yet wired; UI state cleared"),
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
        guard let scopeDict = payload["scopeKey"]?.value as? [String: Any],
              let sourceId = scopeDict["sourceId"] as? String,
              let host = scopeDict["host"] as? String else {
            return nil
        }
        return CookieJarScopeKey(sourceId: sourceId, host: host)
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
