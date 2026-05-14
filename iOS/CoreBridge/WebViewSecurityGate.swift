import Foundation
import ReaderCoreModels

// MARK: - Security Policy

public struct WebViewSecurityPolicy: Equatable, Sendable {
    public var enableWebViewRuntime: Bool
    public var allowJavaScriptExecution: Bool
    public var allowedHosts: Set<String>
    public var allowNetworkNavigation: Bool
    public var allowLocalSnapshotOnly: Bool
    public var timeoutSeconds: TimeInterval
    public var userAgent: String?

    public init(
        enableWebViewRuntime: Bool = false,
        allowJavaScriptExecution: Bool = false,
        allowedHosts: Set<String> = [],
        allowNetworkNavigation: Bool = false,
        allowLocalSnapshotOnly: Bool = true,
        timeoutSeconds: TimeInterval = 30,
        userAgent: String? = nil
    ) {
        self.enableWebViewRuntime = enableWebViewRuntime
        self.allowJavaScriptExecution = allowJavaScriptExecution
        self.allowedHosts = allowedHosts
        self.allowNetworkNavigation = allowNetworkNavigation
        self.allowLocalSnapshotOnly = allowLocalSnapshotOnly
        self.timeoutSeconds = timeoutSeconds
        self.userAgent = userAgent
    }

    /// Strictest policy: all disabled (safe default).
    public static let disabled = WebViewSecurityPolicy()

    /// Test-only: single-host, no JS, no network nav, snapshot only.
    public static func testPolicy(allowedHost: String) -> WebViewSecurityPolicy {
        WebViewSecurityPolicy(
            enableWebViewRuntime: true,
            allowJavaScriptExecution: false,
            allowedHosts: [allowedHost],
            allowNetworkNavigation: false,
            allowLocalSnapshotOnly: true,
            timeoutSeconds: 15
        )
    }

    public func allowsHost(_ host: String) -> Bool {
        guard enableWebViewRuntime else { return false }
        if allowedHosts.isEmpty { return false }
        return allowedHosts.contains(host)
    }
}

// MARK: - Snapshot

public struct WebViewExecutionSnapshot: Codable, Equatable, Sendable {
    public let requestedURL: String
    public let resolvedHost: String
    public let policyEnabled: Bool
    public let jsAllowed: Bool
    public let timestamp: Date
    public let executionState: ExecutionState
    public let errorMessage: String?
    public let htmlMetadata: String?

    public enum ExecutionState: String, Codable, Sendable {
        case notStarted
        case policyRejected
        case hostNotAllowed
        case executing
        case completed
        case failed
    }

    public init(
        requestedURL: String,
        resolvedHost: String,
        policyEnabled: Bool,
        jsAllowed: Bool,
        executionState: ExecutionState,
        errorMessage: String? = nil,
        htmlMetadata: String? = nil
    ) {
        self.requestedURL = requestedURL
        self.resolvedHost = resolvedHost
        self.policyEnabled = policyEnabled
        self.jsAllowed = jsAllowed
        self.timestamp = Date()
        self.executionState = executionState
        self.errorMessage = errorMessage
        self.htmlMetadata = htmlMetadata
    }
}

// MARK: - Security Gate

public final class WebViewSecurityGate: Sendable {
    public private(set) var policy: WebViewSecurityPolicy

    public init(policy: WebViewSecurityPolicy = .disabled) {
        self.policy = policy
    }

    public func updatePolicy(_ newPolicy: WebViewSecurityPolicy) {
        self.policy = newPolicy
    }

    /// Validates whether a request is allowed under the current policy.
    /// Returns nil if allowed, or a snapshot describing the rejection.
    public func validate(request: RuntimeWebViewRequest) -> WebViewExecutionSnapshot? {
        if !policy.enableWebViewRuntime {
            return WebViewExecutionSnapshot(
                requestedURL: request.url,
                resolvedHost: hostFromURL(request.url),
                policyEnabled: false,
                jsAllowed: false,
                executionState: .policyRejected,
                errorMessage: "WebView runtime is disabled by security policy"
            )
        }

        let host = hostFromURL(request.url)
        if !policy.allowsHost(host) {
            return WebViewExecutionSnapshot(
                requestedURL: request.url,
                resolvedHost: host,
                policyEnabled: true,
                jsAllowed: policy.allowJavaScriptExecution,
                executionState: .hostNotAllowed,
                errorMessage: "Host '\(host)' not in allowed hosts"
            )
        }

        return nil
    }

    public func allowedSnapshot(for request: RuntimeWebViewRequest) -> WebViewExecutionSnapshot {
        WebViewExecutionSnapshot(
            requestedURL: request.url,
            resolvedHost: hostFromURL(request.url),
            policyEnabled: policy.enableWebViewRuntime,
            jsAllowed: policy.allowJavaScriptExecution,
            executionState: .notStarted,
            errorMessage: nil
        )
    }

    private func hostFromURL(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }
}
