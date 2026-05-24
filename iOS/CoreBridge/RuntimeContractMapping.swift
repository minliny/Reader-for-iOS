import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

// MARK: - S26.6.2 Core Runtime Contract ↔ iOS WebView Adapter Mapping

extension RuntimePolicy {
    /// Map Core RuntimePolicy → iOS WebViewSecurityPolicy.
    public func toWebViewPolicy() -> WebViewSecurityPolicy {
        WebViewSecurityPolicy(
            enableWebViewRuntime: runtimeEnabled,
            allowJavaScriptExecution: javaScriptEnabled,
            allowedHosts: Set(allowedHosts),
            allowNetworkNavigation: allowNetworkNavigation,
            allowLocalSnapshotOnly: allowSnapshotCapture,
            timeoutSeconds: timeoutSeconds,
            userAgent: nil
        )
    }

    /// Create Core RuntimePolicy from iOS WebViewSecurityPolicy.
    public static func from(_ webViewPolicy: WebViewSecurityPolicy) -> RuntimePolicy {
        RuntimePolicy(
            runtimeEnabled: webViewPolicy.enableWebViewRuntime,
            javaScriptEnabled: webViewPolicy.allowJavaScriptExecution,
            allowedHosts: Array(webViewPolicy.allowedHosts),
            allowNetworkNavigation: webViewPolicy.allowNetworkNavigation,
            allowSnapshotCapture: webViewPolicy.allowLocalSnapshotOnly,
            timeoutSeconds: webViewPolicy.timeoutSeconds,
            allowCookieStorage: false,
            allowCredentialPersistence: false
        )
    }
}

extension RuntimeSnapshot {
    /// Create Core RuntimeSnapshot from iOS WebViewExecutionSnapshot.
    public static func from(_ snapshot: WebViewExecutionSnapshot) -> RuntimeSnapshot {
        let stateStr: String = {
            switch snapshot.executionState {
            case .completed: return "completed"
            case .policyRejected, .hostNotAllowed: return "denied"
            case .failed: return "failed"
            case .executing: return "executing"
            case .notStarted: return "notStarted"
            }
        }()
        return RuntimeSnapshot(
            requestId: snapshot.requestedURL,
            requestedURL: snapshot.requestedURL,
            host: snapshot.resolvedHost,
            policySummary: snapshot.policyEnabled ? "enabled" : "disabled",
            state: stateStr,
            errorCode: snapshot.errorMessage,
            timestamp: snapshot.timestamp,
            redactionApplied: true
        )
    }
}

extension RuntimeResult {
    /// Create denied result with error code.
    public static func denied(requestId: String, errorCode: RuntimeErrorCode, snapshot: RuntimeSnapshot? = nil) -> RuntimeResult {
        RuntimeResult(
            requestId: requestId, status: .denied,
            snapshot: snapshot, errorCode: errorCode, finishedAt: Date()
        )
    }

    /// Create unavailable result (policy allowed but no executor).
    public static func unavailable(requestId: String, snapshot: RuntimeSnapshot? = nil) -> RuntimeResult {
        RuntimeResult(
            requestId: requestId, status: .failed,
            snapshot: snapshot, errorCode: .executionUnavailable, finishedAt: Date()
        )
    }
}

// MARK: - ProductionWebViewAdapter Core Protocol Conformance

#if canImport(WebKit) && canImport(UIKit)

extension ProductionWebViewAdapter: @preconcurrency RuntimeExecutorProtocol {

    public func execute(request: RuntimeRequest) async throws -> RuntimeResult {
        // 1. Map Core policy to iOS policy for gate check
        let iosPolicy = request.policy.toWebViewPolicy()
        updatePolicy(iosPolicy)

        // 2. Gate check
        let gateResult = securityGate.evaluate(
            host: hostFromURL(request.url),
            policy: iosPolicy
        )

        let snapshot = WebViewExecutionSnapshot(
            requestedURL: request.url,
            resolvedHost: hostFromURL(request.url),
            policyEnabled: iosPolicy.enableWebViewRuntime,
            jsAllowed: iosPolicy.allowJavaScriptExecution,
            executionState: gateResult.isDenied ? .policyRejected : .notStarted,
            errorMessage: gateResult.isDenied ? mapDenialReason(gateResult, policy: iosPolicy) : nil,
            htmlMetadata: nil
        )

        if gateResult.isDenied {
            return RuntimeResult.denied(
                requestId: request.requestId,
                errorCode: mapDenialError(gateResult, policy: iosPolicy),
                snapshot: RuntimeSnapshot.from(snapshot)
            )
        }

        // 3. Policy allowed but execution not yet implemented → unavailable
        return RuntimeResult.unavailable(
            requestId: request.requestId,
            snapshot: RuntimeSnapshot.from(snapshot)
        )
    }

    public func isHostAllowed(_ host: String) -> Bool {
        webViewPolicy.allowsHost(host)
    }

    public var currentPolicy: RuntimePolicy {
        RuntimePolicy.from(securityGate.policy)
    }

    // MARK: - Helpers

    private func hostFromURL(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }

    private func mapDenialError(_ result: GateEvaluation, policy: WebViewSecurityPolicy) -> RuntimeErrorCode {
        if !policy.enableWebViewRuntime { return .runtimeDisabled }
        if !policy.allowJavaScriptExecution { return .javaScriptDisabled }
        if !policy.allowsHost(hostFromURL(result.host ?? "")) { return .hostNotAllowed }
        if !policy.allowNetworkNavigation { return .networkNavigationDenied }
        return .executionUnavailable
    }

    private func mapDenialReason(_ result: GateEvaluation, policy: WebViewSecurityPolicy) -> String {
        if !policy.enableWebViewRuntime { return "runtimeDisabled" }
        if !policy.allowJavaScriptExecution { return "javaScriptDisabled" }
        if !policy.allowsHost(hostFromURL(result.host ?? "")) { return "hostNotAllowed" }
        return "denied"
    }
}

/// Minimal gate evaluation result bridging.
struct GateEvaluation {
    let isDenied: Bool
    let host: String?
}

extension WebViewSecurityGate {
    func evaluate(host: String, policy: WebViewSecurityPolicy) -> GateEvaluation {
        if !policy.enableWebViewRuntime {
            return GateEvaluation(isDenied: true, host: host)
        }
        if !policy.allowsHost(host) {
            return GateEvaluation(isDenied: true, host: host)
        }
        return GateEvaluation(isDenied: false, host: host)
    }
}

#endif
