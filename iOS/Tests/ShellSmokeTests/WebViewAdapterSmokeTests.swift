import XCTest
import ReaderCoreModels
@testable import ReaderShellValidation

final class WebViewAdapterSmokeTests: XCTestCase {

    // MARK: - Security Gate Defaults

    func testDefaultPolicyIsDisabled() {
        let policy = WebViewSecurityPolicy.disabled
        XCTAssertFalse(policy.enableWebViewRuntime)
        XCTAssertFalse(policy.allowJavaScriptExecution)
        XCTAssertTrue(policy.allowedHosts.isEmpty)
        XCTAssertFalse(policy.allowNetworkNavigation)
        XCTAssertTrue(policy.allowLocalSnapshotOnly)
    }

    func testTestPolicyEnablesSingleHost() {
        let policy = WebViewSecurityPolicy.testPolicy(allowedHost: "www.example.com")
        XCTAssertTrue(policy.enableWebViewRuntime)
        XCTAssertFalse(policy.allowJavaScriptExecution)
        XCTAssertEqual(policy.allowedHosts, ["www.example.com"])
        XCTAssertFalse(policy.allowNetworkNavigation)
        XCTAssertTrue(policy.allowLocalSnapshotOnly)
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
        XCTAssertFalse(policy.allowsHost("anything.com"))
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
    func testAdapterDefaultsToDisabled() {
        let adapter = ProductionWebViewAdapter()
        XCTAssertEqual(adapter.executorId, "ios.production.webview")
        XCTAssertFalse(adapter.currentPolicy.enableWebViewRuntime)
    }

    @MainActor
    func testAdapterSupportsPageSnapshot() {
        let adapter = ProductionWebViewAdapter()
        XCTAssertTrue(adapter.supportsFeature(.pageSnapshot))
        XCTAssertTrue(adapter.supportsFeature(.customUserAgent))
        XCTAssertFalse(adapter.supportsFeature(.javascriptExecution))
    }

    @MainActor
    func testAdapterExecuteRejectsWhenPolicyDisabled() async {
        let adapter = ProductionWebViewAdapter()
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
    func testAdapterReturnsConfigErrorForWhitelistedHost() async {
        let adapter = ProductionWebViewAdapter()
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
        XCTAssertFalse(result.success) // execution not yet implemented
        XCTAssertEqual(result.errorType, .configurationError)
    }
}
