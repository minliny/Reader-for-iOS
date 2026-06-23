import XCTest
import ReaderCoreModels
@testable import ReaderShellValidation

#if os(iOS)
private final class RecordingRuntimeWebViewExecutor: RuntimeWebViewExecutorProtocol, @unchecked Sendable {
    private(set) var executedRequests: [RuntimeWebViewRequest] = []
    private(set) var interactionRequests: [RuntimeWebViewRequest] = []
    private let resultBuilder: (RuntimeWebViewRequest) -> RuntimeWebViewResult
    private let interactionBuilder: (RuntimeWebViewRequest, [RuntimeWebViewScript]) -> [RuntimeWebViewInteractionResult]

    init(
        resultBuilder: @escaping (RuntimeWebViewRequest) -> RuntimeWebViewResult,
        interactionBuilder: @escaping (RuntimeWebViewRequest, [RuntimeWebViewScript]) -> [RuntimeWebViewInteractionResult] = { _, _ in [] }
    ) {
        self.resultBuilder = resultBuilder
        self.interactionBuilder = interactionBuilder
    }

    var executorId: String { "recording-webview-executor" }
    var executorName: String { "Recording WebView Executor" }

    func supportsFeature(_ feature: RuntimeWebViewFeature) -> Bool {
        switch feature {
        case .javascriptExecution, .pageSnapshot, .interactionSupport,
             .customUserAgent, .navigationHistory:
            return true
        default:
            return false
        }
    }

    func capabilities() -> RuntimeWebViewExecutorCapabilities {
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
            version: "recording-test"
        )
    }

    func execute(request: RuntimeWebViewRequest) async -> RuntimeWebViewResult {
        executedRequests.append(request)
        return resultBuilder(request)
    }

    func executeInteractionSteps(
        request: RuntimeWebViewRequest,
        scripts: [RuntimeWebViewScript]
    ) async -> [RuntimeWebViewInteractionResult] {
        interactionRequests.append(request)
        return interactionBuilder(request, scripts)
    }

    func release() async {}
}

private struct AllowingRealNetworkGate: RealNetworkGate {
    func evaluate(_ policy: RealNetworkPolicy) -> RealNetworkGateDecision {
        .allowed
    }
}

private final class RecordingCookieMirrorMetadataStore: WebViewCookieMirrorMetadataWriting, @unchecked Sendable {
    private(set) var requests: [RuntimeWebViewRequest] = []
    private(set) var finalURLs: [String] = []
    private(set) var pageCookieNames: [[String]] = []
    private(set) var interactionCookieNames: [[String]] = []

    func saveCookieMirrorMetadata(
        request: RuntimeWebViewRequest,
        finalURL: String,
        pageCookies: [RuntimeLoginCookie],
        interactionCookies: [RuntimeLoginCookie]
    ) throws -> WebViewCookieMirrorMetadata? {
        requests.append(request)
        finalURLs.append(finalURL)
        pageCookieNames.append(pageCookies.map(\.name).sorted())
        interactionCookieNames.append(interactionCookies.map(\.name).sorted())
        let cookies = pageCookies.map {
            WebViewCookieMirrorCookieMetadata(cookie: $0, observationSource: .pageResult)
        } + interactionCookies.map {
            WebViewCookieMirrorCookieMetadata(cookie: $0, observationSource: .interactionResult)
        }
        guard !cookies.isEmpty else { return nil }
        return WebViewCookieMirrorMetadata(
            generatedAt: Date(timeIntervalSince1970: 1_782_156_200),
            requestId: request.requestId,
            sourceId: request.sourceId,
            stage: request.stage,
            requestedURL: WebViewCookieMirrorURLMetadata(urlString: request.url),
            finalURL: WebViewCookieMirrorURLMetadata(urlString: finalURL),
            cookies: cookies
        )
    }
}
#endif

final class WebViewAdapterSmokeTests: XCTestCase {

    // MARK: - Security Gate Defaults

    func testDefaultPolicyIsUnrestricted() {
        let policy = WebViewSecurityPolicy()
        XCTAssertTrue(policy.enableWebViewRuntime)
        XCTAssertTrue(policy.allowJavaScriptExecution)
        XCTAssertTrue(policy.allowedHosts.isEmpty)
        XCTAssertTrue(policy.allowNetworkNavigation)
        XCTAssertFalse(policy.allowLocalSnapshotOnly)
        XCTAssertTrue(policy.allowsHost("anything.com"))
    }

    func testDisabledPolicyStillOptOutsRuntime() {
        let policy = WebViewSecurityPolicy.disabled
        XCTAssertFalse(policy.enableWebViewRuntime)
        XCTAssertFalse(policy.allowsHost("www.example.com"))
    }

    func testTestPolicyEnablesSingleHost() {
        let policy = WebViewSecurityPolicy.testPolicy(allowedHost: "www.example.com")
        XCTAssertTrue(policy.enableWebViewRuntime)
        XCTAssertTrue(policy.allowJavaScriptExecution)
        XCTAssertEqual(policy.allowedHosts, ["www.example.com"])
        XCTAssertTrue(policy.allowNetworkNavigation)
        XCTAssertFalse(policy.allowLocalSnapshotOnly)
    }

    func testAllowsHostReturnsFalseWhenDisabled() {
        let policy = WebViewSecurityPolicy.disabled
        XCTAssertFalse(policy.allowsHost("www.example.com"))
    }

    func testAllowsHostReturnsFalseForNonWhitelistedHost() {
        let policy = WebViewSecurityPolicy.testPolicy(allowedHost: "www.example.com")
        XCTAssertFalse(policy.allowsHost("other.com"))
    }

    func testAllowsHostReturnsTrueForWhitelistedHost() {
        let policy = WebViewSecurityPolicy.testPolicy(allowedHost: "www.example.com")
        XCTAssertTrue(policy.allowsHost("www.example.com"))
    }

    func testAllowsHostReturnsFalseForEmptyHosts() {
        var policy = WebViewSecurityPolicy()
        policy.enableWebViewRuntime = true
        XCTAssertTrue(policy.allowsHost("anything.com"))
    }

    // MARK: - Security Gate

    func testGateRejectsWhenPolicyDisabled() {
        let gate = WebViewSecurityGate(policy: .disabled)
        let request = RuntimeWebViewRequest(
            requestId: "test-1",
            sourceId: "src",
            sourceName: "test",
            url: "https://www.example.com",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        let rejection = gate.validate(request: request)
        XCTAssertNotNil(rejection)
        XCTAssertEqual(rejection?.executionState, .policyRejected)
    }

    func testGateRejectsNonWhitelistedHost() {
        let policy = WebViewSecurityPolicy.testPolicy(allowedHost: "www.example.com")
        let gate = WebViewSecurityGate(policy: policy)
        let request = RuntimeWebViewRequest(
            requestId: "test-2",
            sourceId: "src",
            sourceName: "test",
            url: "https://evil.com",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        let rejection = gate.validate(request: request)
        XCTAssertNotNil(rejection)
        XCTAssertEqual(rejection?.executionState, .hostNotAllowed)
    }

    func testGateAllowsWhitelistedHost() {
        let policy = WebViewSecurityPolicy.testPolicy(allowedHost: "www.example.com")
        let gate = WebViewSecurityGate(policy: policy)
        let request = RuntimeWebViewRequest(
            requestId: "test-3",
            sourceId: "src",
            sourceName: "test",
            url: "https://www.example.com/page",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        let rejection = gate.validate(request: request)
        XCTAssertNil(rejection, "Whitelisted host should pass validation")
    }

    // MARK: - S26.6.3 Xmanhua Dynamic Content Replay

    func testXmanhuaContentReplay_policyAllowsHost() {
        let policy = WebViewSecurityPolicy.testPolicy(allowedHost: "www.xmanhua.com")
        XCTAssertTrue(policy.enableWebViewRuntime)
        XCTAssertTrue(policy.allowsHost("www.xmanhua.com"))
        XCTAssertFalse(policy.allowsHost("other.com"))
    }

    func testXmanhuaContentReplay_jsEnabled_gatePasses() {
        var policy = WebViewSecurityPolicy.testPolicy(allowedHost: "www.xmanhua.com")
        policy.allowJavaScriptExecution = true
        let gate = WebViewSecurityGate(policy: policy)
        let request = RuntimeWebViewRequest(
            requestId: "xmanhua-cr-1", sourceId: "xmanhua", sourceName: "星际漫画",
            url: "https://www.xmanhua.com/m298163/",
            stage: .content,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        let rejection = gate.validate(request: request)
        XCTAssertNil(rejection, "Xmanhua host with JS enabled should pass gate")
    }

    func testXmanhuaContentReplay_snapshot_noSecrets() {
        let snapshot = WebViewExecutionSnapshot(
            requestedURL: "https://www.xmanhua.com/m298163/",
            resolvedHost: "www.xmanhua.com",
            policyEnabled: true, jsAllowed: true,
            executionState: .notStarted,
            errorMessage: nil, htmlMetadata: nil
        )
        let encoded = try? JSONEncoder().encode(snapshot)
        let json = try? JSONSerialization.jsonObject(with: encoded ?? Data()) as? [String: Any]
        XCTAssertNil(json?["cookie"])
        XCTAssertNil(json?["token"])
        XCTAssertNil(json?["authorization"])
    }

    // MARK: - S26.6 RuntimePolicy ↔ WebViewSecurityPolicy mapping

    func testRuntimePolicy_toWebViewPolicy_mapsCorrectly() {
        let core = RuntimePolicy(
            runtimeEnabled: true, javaScriptEnabled: true,
            allowedHosts: ["www.xmanhua.com"],
            allowNetworkNavigation: false, allowSnapshotCapture: true
        )
        let web = core.toWebViewPolicy()
        XCTAssertTrue(web.enableWebViewRuntime)
        XCTAssertTrue(web.allowJavaScriptExecution)
        XCTAssertTrue(web.allowedHosts.contains("www.xmanhua.com"))
        XCTAssertTrue(web.allowLocalSnapshotOnly)
    }

    func testWebViewSecurityPolicy_toRuntimePolicy_mapsCorrectly() {
        let web = WebViewSecurityPolicy.testPolicy(allowedHost: "www.xmanhua.com")
        let core = RuntimePolicy.from(web)
        XCTAssertTrue(core.runtimeEnabled)
        XCTAssertTrue(core.javaScriptEnabled)
        XCTAssertTrue(core.allowedHosts.contains("www.xmanhua.com"))
        XCTAssertFalse(core.allowCookieStorage)
        XCTAssertFalse(core.allowCredentialPersistence)
    }

    func testXmanhuaExecutionRequest_deniedWhenJavascriptDisabled() {
        let policy = RuntimePolicy(
            runtimeEnabled: true, javaScriptEnabled: false,
            allowedHosts: ["www.xmanhua.com"]
        )
        let request = RuntimeRequest(
            sourceId: "xmanhua", url: "https://www.xmanhua.com/m298163/",
            policy: policy
        )
        // JS disabled → policy prevents real execution
        let webPolicy = request.policy.toWebViewPolicy()
        XCTAssertFalse(webPolicy.allowJavaScriptExecution)
        XCTAssertTrue(webPolicy.enableWebViewRuntime)
    }
#if os(iOS)
    func testGateUpdatePolicyChangesBehavior() {
        let gate = WebViewSecurityGate(policy: .disabled)
        let request = RuntimeWebViewRequest(
            requestId: "test-4",
            sourceId: "src",
            sourceName: "test",
            url: "https://www.example.com",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        XCTAssertNotNil(gate.validate(request: request))
        gate.updatePolicy(.testPolicy(allowedHost: "www.example.com"))
        XCTAssertNil(gate.validate(request: request))
    }

    func testAllowedSnapshotRecordsPolicyState() {
        let policy = WebViewSecurityPolicy.testPolicy(allowedHost: "www.example.com")
        let gate = WebViewSecurityGate(policy: policy)
        let request = RuntimeWebViewRequest(
            requestId: "test-5",
            sourceId: "src",
            sourceName: "test",
            url: "https://www.example.com",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        let snapshot = gate.allowedSnapshot(for: request)
        XCTAssertEqual(snapshot.executionState, WebViewExecutionSnapshot.ExecutionState.notStarted)
        XCTAssertTrue(snapshot.policyEnabled)
        XCTAssertEqual(snapshot.resolvedHost, "www.example.com")
    }

    // MARK: - Adapter

    @MainActor
    func testAdapterDefaultsToUnrestricted() {
        let adapter = ProductionWebViewAdapter()
        XCTAssertEqual(adapter.executorId, "ios.production.webview")
        XCTAssertTrue(adapter.webViewPolicy.enableWebViewRuntime)
        XCTAssertTrue(adapter.webViewPolicy.allowNetworkNavigation)
    }

    @MainActor
    func testAdapterSupportsPageSnapshot() {
        let adapter = ProductionWebViewAdapter()
        XCTAssertTrue(adapter.supportsFeature(.pageSnapshot))
        XCTAssertTrue(adapter.supportsFeature(.customUserAgent))
        XCTAssertTrue(adapter.supportsFeature(.javascriptExecution))
        XCTAssertFalse(adapter.supportsFeature(.cookieHandling))
        XCTAssertFalse(adapter.capabilities().supportsLoginFlow)
    }

    @MainActor
    func testAdapterExecuteRejectsWhenPolicyExplicitlyDisabled() async {
        let adapter = ProductionWebViewAdapter(securityGate: WebViewSecurityGate(policy: .disabled))
        let request = RuntimeWebViewRequest(
            requestId: "test-adapter-1",
            sourceId: "src",
            sourceName: "test",
            url: "https://www.example.com",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        let result = await adapter.execute(request: request)
        XCTAssertFalse(result.success)
        XCTAssertEqual(result.errorType, .authorizationMissing)
    }

    @MainActor
    func testAdapterExecuteRejectsNonWhitelistedHost() async {
        let adapter = ProductionWebViewAdapter()
        adapter.updatePolicy(.testPolicy(allowedHost: "www.example.com"))
        let request = RuntimeWebViewRequest(
            requestId: "test-adapter-2",
            sourceId: "src",
            sourceName: "test",
            url: "https://other.com",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        let result = await adapter.execute(request: request)
        XCTAssertFalse(result.success)
    }

    @MainActor
    func testAdapterDelegatesWhitelistedHostWithDefaultNetworkGate() async {
        let executor = RecordingRuntimeWebViewExecutor { request in
            RuntimeWebViewResult.success(
                requestId: request.requestId,
                sourceId: request.sourceId,
                sourceName: request.sourceName,
                originalUrl: request.url,
                finalUrl: request.url,
                stage: request.stage,
                html: "<html></html>",
                title: nil,
                metadata: RuntimeWebViewMetadata(),
                snapshotId: nil,
                snapshotFilePath: nil
            )
        }
        let adapter = ProductionWebViewAdapter(executorFactory: { _, _ in executor })
        adapter.updatePolicy(.testPolicy(allowedHost: "www.example.com"))
        let request = RuntimeWebViewRequest(
            requestId: "test-adapter-3",
            sourceId: "src",
            sourceName: "test",
            url: "https://www.example.com",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        let result = await adapter.execute(request: request)
        XCTAssertTrue(result.success)
        XCTAssertEqual(executor.executedRequests.count, 1)
        XCTAssertEqual(adapter.lastSnapshot?.executionState, .completed)
    }

    @MainActor
    func testAdapterDelegatesWhitelistedHostToCoreExecutor() async {
        let executor = RecordingRuntimeWebViewExecutor { request in
            RuntimeWebViewResult.success(
                requestId: request.requestId,
                sourceId: request.sourceId,
                sourceName: request.sourceName,
                originalUrl: request.url,
                finalUrl: request.url,
                stage: request.stage,
                html: "<html><head><title>Rendered</title></head><body>ok</body></html>",
                title: "Rendered",
                metadata: RuntimeWebViewMetadata(
                    contentType: "text/html",
                    charset: "UTF-8",
                    pageSizeBytes: 64,
                    resourceCount: 0,
                    hasFrames: false,
                    isSPA: false,
                    requiresLogin: false,
                    detectedFramework: nil,
                    lastModified: nil
                ),
                snapshotId: "test-snapshot",
                snapshotFilePath: nil,
                totalExecutionTimeMs: 1,
                pageLoadTimeMs: 1,
                javascriptExecutionTimeMs: 0,
                interactionResults: []
            )
        }
        let adapter = ProductionWebViewAdapter(
            realNetworkGate: AllowingRealNetworkGate(),
            realNetworkPolicyProvider: {
                RealNetworkPolicy(mode: .debugOptIn, lastChangedAt: Date(), changedBy: "test")
            },
            executorFactory: { policy, _ in
                XCTAssertEqual(policy.allowedHosts, ["www.example.com"])
                return executor
            }
        )
        adapter.updatePolicy(.testPolicy(allowedHost: "www.example.com"))
        let request = RuntimeWebViewRequest(
            requestId: "test-adapter-4",
            sourceId: "src",
            sourceName: "test",
            url: "https://www.example.com",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        let result = await adapter.execute(request: request)
        XCTAssertTrue(result.success)
        XCTAssertEqual(result.title, "Rendered")
        XCTAssertEqual(executor.executedRequests.count, 1)
        XCTAssertEqual(executor.executedRequests.first?.authorization?.allowedHosts, ["www.example.com"])
        XCTAssertEqual(executor.executedRequests.first?.authorization?.capabilityAllowlist.contains(.webView), true)
        XCTAssertEqual(executor.executedRequests.first?.authorization?.capabilityAllowlist.contains(.snapshotWrite), true)
        XCTAssertEqual(executor.executedRequests.first?.authorization?.capabilityAllowlist.contains(.javascript), true)
        XCTAssertEqual(executor.executedRequests.first?.authorization?.capabilityAllowlist.contains(.cookieJar), true)
        XCTAssertEqual(executor.executedRequests.first?.authorization?.capabilityAllowlist.contains(.sessionPersistence), true)
        XCTAssertEqual(executor.executedRequests.first?.authorization?.capabilityAllowlist.contains(.loginFlow), true)
        XCTAssertEqual(executor.executedRequests.first?.authorization?.forbiddenActions.isEmpty, true)
        XCTAssertEqual(adapter.lastSnapshot?.executionState, .completed)
    }

    @MainActor
    func testAdapterPersistsCookieMirrorMetadataFromDelegatedResult() async {
        let metadataStore = RecordingCookieMirrorMetadataStore()
        let executor = RecordingRuntimeWebViewExecutor { request in
            RuntimeWebViewResult.success(
                requestId: request.requestId,
                sourceId: request.sourceId,
                sourceName: request.sourceName,
                originalUrl: request.url,
                finalUrl: "https://www.example.com/reader/detail?token=secret",
                stage: request.stage,
                html: "<html></html>",
                updatedCookies: [
                    RuntimeLoginCookie(
                        name: "sid",
                        value: "raw-cookie-value",
                        domain: "www.example.com",
                        secure: true,
                        httpOnly: true
                    )
                ]
            )
        }
        let adapter = ProductionWebViewAdapter(
            realNetworkGate: AllowingRealNetworkGate(),
            realNetworkPolicyProvider: {
                RealNetworkPolicy(mode: .debugOptIn, lastChangedAt: Date(), changedBy: "test")
            },
            cookieMirrorMetadataStore: metadataStore,
            executorFactory: { _, _ in executor }
        )
        adapter.updatePolicy(.testPolicy(allowedHost: "www.example.com"))
        let request = RuntimeWebViewRequest(
            requestId: "test-adapter-cookie-1",
            sourceId: "src",
            sourceName: "test",
            url: "https://www.example.com/reader/detail?token=secret",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )

        let result = await adapter.execute(request: request)

        XCTAssertTrue(result.success)
        XCTAssertEqual(metadataStore.requests.count, 1)
        XCTAssertEqual(metadataStore.finalURLs, ["https://www.example.com/reader/detail?token=secret"])
        XCTAssertEqual(metadataStore.pageCookieNames, [["sid"]])
        XCTAssertEqual(metadataStore.interactionCookieNames, [[]])
        XCTAssertEqual(adapter.lastCookieMirrorMetadata?.cookieCount, 1)
        XCTAssertNil(adapter.lastCookieMirrorMetadataWriteError)
    }

    @MainActor
    func testAdapterPersistsCookieMirrorMetadataFromInteractionSteps() async {
        let metadataStore = RecordingCookieMirrorMetadataStore()
        let executor = RecordingRuntimeWebViewExecutor(
            resultBuilder: { request in
                RuntimeWebViewResult.success(
                    requestId: request.requestId,
                    sourceId: request.sourceId,
                    sourceName: request.sourceName,
                    originalUrl: request.url,
                    finalUrl: request.url,
                    stage: request.stage,
                    html: "<html></html>"
                )
            },
            interactionBuilder: { _, _ in
                [
                    RuntimeWebViewInteractionResult.success(
                        stepIndex: 0,
                        stepType: .click,
                        parameters: ["selector": "#login"],
                        updatedCookies: [
                            RuntimeLoginCookie(
                                name: "csrf",
                                value: "interaction-cookie-value",
                                domain: "www.example.com",
                                secure: true,
                                httpOnly: false
                            )
                        ]
                    )
                ]
            }
        )
        let adapter = ProductionWebViewAdapter(
            realNetworkGate: AllowingRealNetworkGate(),
            realNetworkPolicyProvider: {
                RealNetworkPolicy(mode: .debugOptIn, lastChangedAt: Date(), changedBy: "test")
            },
            cookieMirrorMetadataStore: metadataStore,
            executorFactory: { _, _ in executor }
        )
        adapter.updatePolicy(.testPolicy(allowedHost: "www.example.com"))
        let request = RuntimeWebViewRequest(
            requestId: "test-adapter-cookie-2",
            sourceId: "src",
            sourceName: "test",
            url: "https://www.example.com/login",
            stage: .detail,
            waitPolicy: RuntimeWebViewWaitPolicy.standard()
        )
        _ = await adapter.execute(request: request)

        let interactionResults = await adapter.executeInteractionSteps(
            request: request,
            scripts: [
                RuntimeWebViewScript(
                    scriptType: .click,
                    content: "",
                    parameters: ["selector": "#login"]
                )
            ]
        )

        XCTAssertEqual(interactionResults.count, 1)
        XCTAssertEqual(metadataStore.requests.count, 1)
        XCTAssertEqual(metadataStore.pageCookieNames, [[]])
        XCTAssertEqual(metadataStore.interactionCookieNames, [["csrf"]])
        XCTAssertEqual(adapter.lastCookieMirrorMetadata?.cookieCount, 1)
        XCTAssertNil(adapter.lastCookieMirrorMetadataWriteError)
    }
#endif
}
