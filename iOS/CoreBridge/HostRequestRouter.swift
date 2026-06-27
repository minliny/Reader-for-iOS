// CoreBridge
//
// HostRequestRouter: routes Rust Core `host.request` events (capability=http.execute)
// to the iOS Host's `URLSessionHTTPClient`, then sends `host.complete` or
// `host.error` back to Core.
//
// This is the Core/Host boundary wiring: Core produces request descriptors,
// Host executes real HTTP via URLSession. Core never opens a socket.
//
// S6.1: This router is the single HTTP execution path for Rust Core's
// http.execute capability. It is shared by all RustCore*Service adapters.

import Foundation
import ReaderCoreProtocols
import ReaderCoreNativeAdapter

/// Errors thrown by `HostRequestRouter`.
public enum HostRequestRouterError: Error, Equatable, LocalizedError {
    case runtimeNotBooted
    case missingOperationId
    case unexpectedHostRequestType(String)
    case unexpectedCapability(String)
    case hostHTTPFailed(String)

    public var errorDescription: String? {
        switch self {
        case .runtimeNotBooted: return "Rust Core runtime is not booted"
        case .missingOperationId: return "host.request missing operationId"
        case .unexpectedHostRequestType(let t): return "expected host.request, got \(t)"
        case .unexpectedCapability(let c): return "expected http.execute, got \(c)"
        case .hostHTTPFailed(let m): return "Host HTTP failed: \(m)"
        }
    }
}

/// Routes Core `host.request` (http.execute) events to `URLSessionHTTPClient`
/// and replies with `host.complete` / `host.error`.
///
/// The router is a stateless helper: each call handles exactly one
/// `host.request` event for one `requestId`. Callers (RustCore*Service)
/// poll the runtime for the host.request, then invoke `handleHostRequest`
/// with the event + original requestId.
public struct HostRequestRouter: Sendable {
    private let httpClient: HTTPClient
    private let runtime: ReaderCoreNativeRuntime

    public init(httpClient: HTTPClient, runtime: ReaderCoreNativeRuntime) {
        self.httpClient = httpClient
        self.runtime = runtime
    }

    /// Handle a single `host.request` event for `http.execute`:
    /// 1. Extract url/method/headers/body from the event params.
    /// 2. Execute via `HTTPClient.send`.
    /// 3. Send `host.complete` (with status/headers/body) or `host.error` back to Core.
    public func handleHostRequest(_ event: ReaderCoreNativeEvent) async throws {
        guard event.type == "host.request" else {
            throw HostRequestRouterError.unexpectedHostRequestType(event.type)
        }
        guard event.capability == "http.execute" else {
            throw HostRequestRouterError.unexpectedHostRequestType(event.capability ?? "nil")
        }
        guard let operationId = event.operationId else {
            throw HostRequestRouterError.missingOperationId
        }
        guard let params = event.hostParams else {
            throw HostRequestRouterError.hostHTTPFailed("host.request missing params")
        }

        let url = (params["url"] as? String) ?? ""
        let method = (params["method"] as? String) ?? "GET"
        let headersDict = (params["headers"] as? [String: Any]) ?? [:]
        let headers = headersDict.reduce(into: [String: String]()) { acc, kv in
            if let s = kv.value as? String { acc[kv.key] = s }
        }
        let bodyString = params["body"] as? String
        let body = bodyString?.data(using: .utf8)

        guard !url.isEmpty else {
            try sendHostError(operationId: operationId, code: "INVALID_PARAMS", message: "host.request url is empty")
            return
        }

        let request = HTTPRequest(
            url: url,
            method: method,
            headers: headers,
            body: body
        )

        do {
            let response = try await httpClient.send(request)
            try sendHostComplete(
                operationId: operationId,
                status: response.statusCode,
                headers: response.headers,
                body: response.data
            )
        } catch {
            try sendHostError(
                operationId: operationId,
                code: "INTERNAL",
                message: error.localizedDescription
            )
        }
    }

    /// Send `host.complete` for the given operationId with HTTP response data.
    /// Uses a fresh requestId derived from operationId to avoid collision with
    /// the original request.
    private func sendHostComplete(
        operationId: UInt64,
        status: Int,
        headers: [String: String],
        body: Data
    ) throws {
        let bodyString = body.isEmpty ? "" : (String(data: body, encoding: .utf8) ?? "")
        let completeRequestId: UInt64 = 9_000_000_000 + operationId
        let payload: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: completeRequestId),
            "method": "host.complete",
            "params": [
                "operationId": NSNumber(value: operationId),
                "result": [
                    "status": status,
                    "headers": headers.isEmpty ? [:] : headers,
                    "body": bodyString,
                ] as [String: Any],
            ] as [String: Any],
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        try runtime.send(json: json)
    }

    /// Send `host.error` for the given operationId.
    private func sendHostError(
        operationId: UInt64,
        code: String,
        message: String
    ) throws {
        let errorRequestId: UInt64 = 9_100_000_000 + operationId
        let payload: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: errorRequestId),
            "method": "host.error",
            "params": [
                "operationId": NSNumber(value: operationId),
                "error": [
                    "code": code,
                    "message": message,
                    "retryable": false,
                ] as [String: Any],
            ] as [String: Any],
        ]
        let json = try JSONSerialization.data(withJSONObject: payload)
        try runtime.send(json: json)
    }
}
