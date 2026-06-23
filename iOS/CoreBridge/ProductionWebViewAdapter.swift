import Foundation
import ReaderCoreModels
import ReaderPlatformAdapters

#if canImport(WebKit) && canImport(UIKit)
import WebKit
import UIKit

public typealias WebViewExecutorFactory = @MainActor @Sendable (
    WebViewSecurityPolicy,
    RuntimeWebViewRequest
) -> any RuntimeWebViewExecutorProtocol

public typealias WebViewRealNetworkPolicyProvider = @MainActor @Sendable () -> RealNetworkPolicy

/// Production WKWebView adapter conforming to RuntimeWebViewExecutorProtocol.
/// Execution is gated by WebViewSecurityGate; defaults to disabled (safe).
@MainActor
public final class ProductionWebViewAdapter: RuntimeWebViewExecutorProtocol, @unchecked Sendable {

    public let executorId = "ios.production.webview"
    public let executorName = "Production WKWebView Adapter"

    let securityGate: WebViewSecurityGate
    private let executorFactory: WebViewExecutorFactory
    private let realNetworkGate: any RealNetworkGate
    private let realNetworkPolicyProvider: WebViewRealNetworkPolicyProvider
    private let cookieMirrorMetadataStore: (any WebViewCookieMirrorMetadataWriting)?
    private var activeExecutor: (any RuntimeWebViewExecutorProtocol)?
    private(set) var lastSnapshot: WebViewExecutionSnapshot?
    private(set) var lastCookieMirrorMetadata: WebViewCookieMirrorMetadata?
    private(set) var lastCookieMirrorMetadataWriteError: String?

    public init(
        securityGate: WebViewSecurityGate = WebViewSecurityGate(),
        snapshotRootDirectory: String? = nil,
        realNetworkGate: any RealNetworkGate = DefaultRealNetworkGate(),
        realNetworkPolicyProvider: WebViewRealNetworkPolicyProvider? = nil,
        cookieMirrorMetadataStore: (any WebViewCookieMirrorMetadataWriting)? = WebViewCookieMirrorMetadataStore(),
        executorFactory: WebViewExecutorFactory? = nil
    ) {
        self.securityGate = securityGate
        self.realNetworkGate = realNetworkGate
        self.realNetworkPolicyProvider = realNetworkPolicyProvider ?? {
            RealNetworkPolicyStore.shared.current
        }
        self.cookieMirrorMetadataStore = cookieMirrorMetadataStore
        let rootDirectory = snapshotRootDirectory ?? Self.defaultSnapshotRootDirectory()
        self.executorFactory = executorFactory ?? { policy, _ in
            WKWebViewRuntimeAdapter.strict(
                rootDirectory: rootDirectory,
                allowedHosts: Array(policy.allowedHosts),
                requireHttps: true
            )
        }
    }

    // MARK: - Policy

    public func updatePolicy(_ policy: WebViewSecurityPolicy) {
        securityGate.updatePolicy(policy)
    }

    public var webViewPolicy: WebViewSecurityPolicy {
        securityGate.policy
    }

    // MARK: - RuntimeWebViewExecutorProtocol

    public func supportsFeature(_ feature: RuntimeWebViewFeature) -> Bool {
        switch feature {
        case .javascriptExecution, .pageSnapshot, .interactionSupport,
             .customUserAgent, .navigationHistory:
            return true
        default: return false
        }
    }

    public func capabilities() -> RuntimeWebViewExecutorCapabilities {
        RuntimeWebViewExecutorCapabilities(
            supportedFeatures: [
                .javascriptExecution,
                .pageSnapshot,
                .interactionSupport,
                .customUserAgent,
                .navigationHistory
            ],
            maxConcurrentExecutions: 1,
            supportsSnapshot: true,
            supportsOfflineMode: false,
            supportsLoginFlow: false,
            version: "0.2.0-core-delegated"
        )
    }

    public func execute(request: RuntimeWebViewRequest) async -> RuntimeWebViewResult {
        if let rejection = securityGate.validate(request: request) {
            lastSnapshot = rejection
            return RuntimeWebViewResult(
                requestId: request.requestId,
                sourceId: request.sourceId,
                sourceName: request.sourceName,
                originalUrl: request.url,
                finalUrl: request.url,
                stage: request.stage,
                success: false,
                errorMessage: rejection.errorMessage ?? "Security policy rejected",
                errorType: .authorizationMissing,
                html: "",
                title: nil,
                metadata: RuntimeWebViewMetadata(),
                snapshotId: nil,
                snapshotFilePath: nil
            )
        }

        switch realNetworkGate.evaluate(realNetworkPolicyProvider()) {
        case .allowed:
            break
        case .denied(let reason):
            lastSnapshot = WebViewExecutionSnapshot(
                requestedURL: request.url,
                resolvedHost: hostFromURL(request.url),
                policyEnabled: true,
                jsAllowed: securityGate.policy.allowJavaScriptExecution,
                executionState: .policyRejected,
                errorMessage: reason
            )
            return RuntimeWebViewResult(
                requestId: request.requestId,
                sourceId: request.sourceId,
                sourceName: request.sourceName,
                originalUrl: request.url,
                finalUrl: request.url,
                stage: request.stage,
                success: false,
                errorMessage: reason,
                errorType: .authorizationDenied,
                html: "",
                title: nil,
                metadata: RuntimeWebViewMetadata(),
                snapshotId: nil,
                snapshotFilePath: nil
            )
        }

        lastSnapshot = WebViewExecutionSnapshot(
            requestedURL: request.url,
            resolvedHost: hostFromURL(request.url),
            policyEnabled: true,
            jsAllowed: securityGate.policy.allowJavaScriptExecution,
            executionState: .executing,
            errorMessage: nil
        )

        let delegatedRequest = request.withOneShotWebViewAuthorization(
            policy: securityGate.policy
        )
        let executor = executorFactory(securityGate.policy, delegatedRequest)
        activeExecutor = executor

        let result = await executor.execute(request: delegatedRequest)
        persistCookieMirrorMetadata(request: delegatedRequest, result: result)
        lastSnapshot = WebViewExecutionSnapshot(
            requestedURL: request.url,
            resolvedHost: hostFromURL(result.finalUrl),
            policyEnabled: true,
            jsAllowed: securityGate.policy.allowJavaScriptExecution,
            executionState: result.success ? .completed : .failed,
            errorMessage: result.errorMessage,
            htmlMetadata: result.html.isEmpty ? nil : "bytes:\(result.html.utf8.count)"
        )
        return result
    }

    public func executeInteractionSteps(
        request: RuntimeWebViewRequest,
        scripts: [RuntimeWebViewScript]
    ) async -> [RuntimeWebViewInteractionResult] {
        guard let activeExecutor else { return [] }
        let results = await activeExecutor.executeInteractionSteps(request: request, scripts: scripts)
        persistCookieMirrorMetadata(request: request, interactionResults: results)
        return results
    }

    public func release() async {
        await activeExecutor?.release()
        activeExecutor = nil
    }

    private static func defaultSnapshotRootDirectory() -> String {
        let cacheRoot = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return cacheRoot
            .appendingPathComponent("ReaderApp/WebViewSnapshots", isDirectory: true)
            .path
    }

    private func hostFromURL(_ urlString: String) -> String {
        URL(string: urlString)?.host ?? urlString
    }

    private func persistCookieMirrorMetadata(
        request: RuntimeWebViewRequest,
        result: RuntimeWebViewResult
    ) {
        guard !result.updatedCookies.isEmpty
            || result.interactionResults.contains(where: { !$0.updatedCookies.isEmpty }) else {
            return
        }
        guard let cookieMirrorMetadataStore else { return }
        do {
            lastCookieMirrorMetadata = try cookieMirrorMetadataStore.saveCookieMirrorMetadata(
                request: request,
                result: result
            )
            lastCookieMirrorMetadataWriteError = nil
        } catch {
            lastCookieMirrorMetadataWriteError = error.localizedDescription
        }
    }

    private func persistCookieMirrorMetadata(
        request: RuntimeWebViewRequest,
        interactionResults: [RuntimeWebViewInteractionResult]
    ) {
        guard interactionResults.contains(where: { !$0.updatedCookies.isEmpty }) else {
            return
        }
        guard let cookieMirrorMetadataStore else { return }
        do {
            lastCookieMirrorMetadata = try cookieMirrorMetadataStore.saveCookieMirrorMetadata(
                request: request,
                interactionResults: interactionResults
            )
            lastCookieMirrorMetadataWriteError = nil
        } catch {
            lastCookieMirrorMetadataWriteError = error.localizedDescription
        }
    }
}

private extension RuntimeWebViewRequest {
    func withOneShotWebViewAuthorization(
        policy: WebViewSecurityPolicy
    ) -> RuntimeWebViewRequest {
        if authorization != nil {
            return self
        }

        let authorization = RuntimeAuthorization(
            authorizationId: "ios-production-webview-\(requestId)",
            sourceId: sourceId,
            sourceName: sourceName,
            grantedBy: "user",
            expiresAt: nil,
            allowedStages: Set(RuntimeStage.allCases),
            allowedMethods: Set(RuntimeHTTPMethod.allCases),
            allowedHosts: policy.allowedHosts.isEmpty ? nil : policy.allowedHosts,
            capabilityAllowlist: Set(RuntimeCapabilityType.allCases),
            forbiddenActions: [],
            auditRequired: false,
            snapshotRequired: false,
            riskLevelAtGrant: .low
        )

        return RuntimeWebViewRequest(
            requestId: requestId,
            sourceId: sourceId,
            sourceName: sourceName,
            url: url,
            stage: stage,
            waitPolicy: waitPolicy,
            scriptPolicy: policy.allowJavaScriptExecution ? scriptPolicy : .strictSandbox(),
            snapshotRequired: snapshotRequired,
            snapshotPrefix: snapshotPrefix,
            securityRiskLevel: securityRiskLevel,
            authorization: authorization,
            headers: headers
        )
    }
}
#endif
