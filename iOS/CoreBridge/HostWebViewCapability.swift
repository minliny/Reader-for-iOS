// CoreBridge
//
// HostWebViewCapability — UI/reducer-initiated `webview.open/close/evaluate`.
//
// Bridges the contract `HostRequest` to the iOS-only `WKWebViewExecutor`. On
// macOS `swift build`, the executor is unavailable and the handler returns
// `.notImplemented` so the registry still recognizes the type (no
// `.notConfigured` for UI webview requests).
//
// Tier: realDeviceProof — WKWebView JS execution behaves differently on the
// simulator (different JIT, different user-agent). Anti-bot challenges that
// rely on browser fingerprinting require a real device for faithful proof.
//
// Payload contract:
// - `.webview_open`:    `{ url: String, profileId?: String }` → `{ sessionId: String }`
// - `.webview_close`:   `{ sessionId?: String }` → `{ closed: true }`
// - `.webview_evaluate`:
//   `{ document: { kind: "html"|"url", body?: String, url?: String, baseUrl?: String },
//      javaScript: String, timeoutMillis?: UInt64, profileId?: String }`
//   → `{ value: Any, finalUrl?: String, title?: String }`

import Foundation
import ReaderUIContract

#if canImport(WebKit) && canImport(UIKit)
import WebKit
import UIKit

public struct HostWebViewCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [
        .webview_open, .webview_close, .webview_evaluate,
    ]
    public let tier: HostCapabilityTier = .realDeviceProof

    private let executor: WKWebViewExecutor

    public init(executor: WKWebViewExecutor) {
        self.executor = executor
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        switch request.type {
        case .webview_open:
            return handleOpen(request.payload)
        case .webview_close:
            return handleClose(request.payload)
        case .webview_evaluate:
            return try await handleEvaluate(request.payload)
        default:
            return .failure(.notImplemented(request.type, "HostWebViewCapability does not handle \(request.type.rawValue)"))
        }
    }

    private func handleOpen(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        guard let url = payload["url"]?.value as? String,
              URL(string: url)?.host != nil else {
            return .failure(.invalidParams("webview.open requires an absolute `url`"))
        }
        // WKWebViewExecutor is intentionally request-scoped and does not own
        // a durable browser session. Returning `opened=true` here would claim
        // a physical lifecycle that never happened.
        return .failure(.notImplemented(
            .webview_open,
            "persistent WKWebView sessions are not implemented by the request-scoped executor"
        ))
    }

    private func handleClose(_ payload: [String: AnyCodable]) -> HostCapabilityOutcome {
        // Symmetric with open: no durable session means there is nothing that
        // can truthfully be reported as physically closed.
        return .failure(.notImplemented(
            .webview_close,
            "persistent WKWebView sessions are not implemented by the request-scoped executor"
        ))
    }

    private func handleEvaluate(_ payload: [String: AnyCodable]) async throws -> HostCapabilityOutcome {
        guard let url = payload["url"]?.value as? String,
              URL(string: url)?.host != nil else {
            return .failure(.invalidParams("webview.evaluate requires an absolute `url`"))
        }
        guard let javaScript = payload["script"]?.value as? String, !javaScript.isEmpty else {
            return .failure(.invalidParams("webview.evaluate requires non-empty `script`"))
        }
        let timeoutMillis = (payload["timeoutMs"]?.value as? Int).map { UInt64($0) }
            ?? (payload["timeoutMs"]?.value as? Double).map { UInt64($0) }
        let profileId = payload["profileId"]?.value as? String

        let document = WebViewDocument(kind: .url, body: nil, url: url, baseUrl: nil)
        let evaluationRequest = WebViewEvaluationRequest(
            document: document,
            javaScript: javaScript,
            timeoutMillis: timeoutMillis,
            profileId: profileId
        )

        do {
            let result = try await executor.evaluate(request: evaluationRequest)
            var resultDict: [String: AnyCodable] = [
                "result": Self.wrapAnyCodable(result.value),
            ]
            if let finalUrl = result.finalUrl {
                resultDict["finalUrl"] = AnyCodable(finalUrl)
            }
            if let title = result.title {
                resultDict["title"] = AnyCodable(title)
            }
            return .success(resultDict)
        } catch let error as WebViewExecutorError {
            return .failure(.underlying("webview.evaluate failed: \(error.localizedDescription)"))
        } catch {
            return .failure(.underlying("webview.evaluate failed: \(error.localizedDescription)"))
        }
    }

    /// Wrap an arbitrary JSON-compatible value into `AnyCodable`. Handles the
    /// common types returned by `WKWebView.evaluateJavaScript` (String, Number,
    /// Bool, Array, Dict, NSNull).
    private static func wrapAnyCodable(_ value: Any) -> AnyCodable {
        if let s = value as? String { return AnyCodable(s) }
        if let b = value as? Bool { return AnyCodable(b) }
        if let i = value as? Int { return AnyCodable(i) }
        if let d = value as? Double { return AnyCodable(d) }
        if let arr = value as? [Any] {
            return AnyCodable(arr.map { wrapAnyCodable($0) })
        }
        if let dict = value as? [String: Any] {
            return AnyCodable(dict.reduce(into: [String: AnyCodable]()) { acc, kv in
                acc[kv.key] = wrapAnyCodable(kv.value)
            })
        }
        if value is NSNull {
            return AnyCodable(String?.none as String?)
        }
        return AnyCodable(String(describing: value))
    }
}

#else

/// macOS stub — WKWebView requires UIKit. The handler is registered so the
/// registry recognizes `.webview_*` types (no `.notConfigured`), but every
/// request returns `.notImplemented` with a clear message. This keeps macOS
/// `swift build` / `swift test` green while iOS simulator/device runs get the
/// real implementation above.
public struct HostWebViewCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [
        .webview_open, .webview_close, .webview_evaluate,
    ]
    public let tier: HostCapabilityTier = .realDeviceProof

    public init(executor: AnyObject) {
        // Executor parameter accepted for source compatibility with the iOS
        // initializer; ignored on macOS.
    }

    public init() {}

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        return .failure(.notImplemented(request.type, "WKWebView requires UIKit — not available on macOS swift build"))
    }
}

#endif
