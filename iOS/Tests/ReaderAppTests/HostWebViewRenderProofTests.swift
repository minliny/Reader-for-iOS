import XCTest
import ReaderCoreProtocols
@testable import ReaderShellValidation

/// iOS Host-side proof for the `webview.evaluateJavaScript` lane — mirrors
/// Android's `WebViewEvaluateJavaScriptProofTest.kt` / HarmonyOS proof
/// structure so iOS reaches the same proof level.
///
/// Proof tier (this file): handler/router. These tests verify that
/// `WebViewEvaluateJavaScriptHandler` correctly parses the Core request,
/// validates it (mirroring `HostWebViewDocument.validate` /
/// `HostWebViewEvaluateJavaScriptRequest.validate` in
/// `crates/reader-contract/src/host.rs` lines 679-820), delegates to the
/// `WebViewExecutor`, and builds the response dict. They use
/// `StubWebViewExecutor` — no real WKWebView is exercised.
///
/// Device-headless/App tier (pending): real WKWebView execution (load HTML/URL,
/// evaluate JS, capture finalUrl/title, enforce timeout) requires device-tier
/// proof (simulator / real device with a live WKWebView). The production
/// `WKWebViewExecutor` is a `notImplemented` stub until that tier lands.
///
/// Mirrors `HostLoginCookieProofTests` structure: 3 proof cases + 2 validation
/// cases, all calling the handler directly without a live Rust Core runtime.
final class HostWebViewRenderProofTests: XCTestCase {

    // MARK: - Proof 1: webview.evaluateJavaScript returns value (html document)

    /// Mirrors Android `webViewEvaluatesJavaScriptReturnsValue`:
    /// StubWebViewExecutor returns `value = "hello from JS"`, `finalUrl` ending
    /// in `/rendered`, `title = "Rendered Page"`. The handler is called with a
    /// `kind: "html"` document (body present, no url) and a JS expression. The
    /// response must carry the canned `value`, `finalUrl`, and `title`.
    func testWebViewEvaluatesJavaScriptReturnsValue() async throws {
        let executor = StubWebViewExecutor(result: WebViewEvaluationResult(
            value: "hello from JS",
            finalUrl: "https://example.test/rendered",
            title: "Rendered Page"
        ))
        let handler = WebViewEvaluateJavaScriptHandler(executor: executor)

        let params: [String: Any] = [
            "document": [
                "kind": "html",
                "body": "<html><body>test</body></html>",
            ] as [String: Any],
            "javaScript": "document.body.innerText",
        ]

        let result = try await handler.handle(params: params)

        XCTAssertEqual(result["value"] as? String, "hello from JS",
                       "value must be the canned JS result")
        guard let finalUrl = result["finalUrl"] as? String else {
            XCTFail("result must have finalUrl, got keys: \(result.keys.sorted())")
            return
        }
        XCTAssertTrue(finalUrl.hasSuffix("/rendered"),
                      "finalUrl must end with /rendered, got: \(finalUrl)")
        XCTAssertEqual(result["title"] as? String, "Rendered Page",
                       "title must be the canned page title")
    }

    // MARK: - Proof 2: webview.evaluateJavaScript loads url and returns DOM

    /// Mirrors Android `webViewLoadsUrlAndReturnsDom`:
    /// StubWebViewExecutor returns `value = "<html>rendered</html>"` and
    /// `finalUrl` ending in `/final`. The handler is called with a
    /// `kind: "url"` document (url present, no body/baseUrl) and a JS
    /// expression that extracts the DOM. The response must carry the canned
    /// `value` (containing "rendered") and `finalUrl` (ending in `/final`).
    func testWebViewLoadsUrlAndReturnsDom() async throws {
        let executor = StubWebViewExecutor(result: WebViewEvaluationResult(
            value: "<html>rendered</html>",
            finalUrl: "https://example.test/final",
            title: nil
        ))
        let handler = WebViewEvaluateJavaScriptHandler(executor: executor)

        let params: [String: Any] = [
            "document": [
                "kind": "url",
                "url": "https://example.test/start",
            ] as [String: Any],
            "javaScript": "document.documentElement.outerHTML",
        ]

        let result = try await handler.handle(params: params)

        guard let value = result["value"] as? String else {
            XCTFail("result must have value string, got keys: \(result.keys.sorted())")
            return
        }
        XCTAssertTrue(value.contains("rendered"),
                      "value must contain 'rendered', got: \(value)")
        guard let finalUrl = result["finalUrl"] as? String else {
            XCTFail("result must have finalUrl, got keys: \(result.keys.sorted())")
            return
        }
        XCTAssertTrue(finalUrl.hasSuffix("/final"),
                      "finalUrl must end with /final, got: \(finalUrl)")
        XCTAssertNil(result["title"],
                     "title must be omitted when executor returns nil title")
    }

    // MARK: - Proof 3: webview.evaluateJavaScript timeout fails closed

    /// Mirrors Android `webViewEvaluatesJavaScriptTimeoutFailsClosed`:
    /// StubWebViewExecutor throws `WebViewExecutorError.timeout(timeoutMillis: 5000)`.
    /// The handler is called with a `kind: "url"` document and `timeoutMillis = 5000`.
    /// The handler must propagate a distinguishable timeout error (not a generic
    /// crash) so Core can retry / report the timeout separately from other
    /// failures.
    func testWebViewEvaluatesJavaScriptTimeoutFailsClosed() async throws {
        let executor = StubWebViewExecutor(error: .timeout(timeoutMillis: 5000))
        let handler = WebViewEvaluateJavaScriptHandler(executor: executor)

        let params: [String: Any] = [
            "document": [
                "kind": "url",
                "url": "https://slow.test/",
            ] as [String: Any],
            "javaScript": "document.body",
            "timeoutMillis": 5000,
        ]

        do {
            _ = try await handler.handle(params: params)
            XCTFail("handler should throw on timeout, but returned a result")
        } catch let error as WebViewExecutorError {
            // Timeout must be distinguishable from other failures — verify the
            // error is the `.timeout` case carrying the timeoutMillis value.
            switch error {
            case .timeout(let ms):
                XCTAssertEqual(ms, 5000,
                               "timeout error must carry the requested timeoutMillis")
            default:
                XCTFail("expected .timeout error, got: \(error)")
            }
        } catch {
            XCTFail("expected WebViewExecutorError.timeout, got unexpected error: \(error)")
        }
    }

    // MARK: - Validation 1: html document with url is rejected

    /// `kind: "html"` must NOT include `url` (mirrors Core's
    /// `HostWebViewDocument.validate` — "webview html document must not include
    /// url"). The handler must reject this before reaching the executor.
    func testWebViewRejectsHtmlDocumentWithUrl() async throws {
        // Canned result that should never be reached.
        let executor = StubWebViewExecutor(result: WebViewEvaluationResult(
            value: "should-not-reach-executor"
        ))
        let handler = WebViewEvaluateJavaScriptHandler(executor: executor)

        let params: [String: Any] = [
            "document": [
                "kind": "html",
                "body": "<html></html>",
                "url": "https://example.test/",
            ] as [String: Any],
            "javaScript": "document.body",
        ]

        do {
            _ = try await handler.handle(params: params)
            XCTFail("handler should reject html document with url")
        } catch let error as WebViewExecutorError {
            switch error {
            case .invalidParams(let m):
                XCTAssertTrue(m.contains("url"),
                              "error message should mention url, got: \(m)")
            default:
                XCTFail("expected .invalidParams error, got: \(error)")
            }
        } catch {
            XCTFail("expected WebViewExecutorError.invalidParams, got: \(error)")
        }
    }

    // MARK: - Validation 2: url document with body is rejected

    /// `kind: "url"` must NOT include `body` (mirrors Core's
    /// `HostWebViewDocument.validate` — "webview url document must not include
    /// body or baseUrl"). The handler must reject this before reaching the
    /// executor.
    func testWebViewRejectsUrlDocumentWithBody() async throws {
        // Canned result that should never be reached.
        let executor = StubWebViewExecutor(result: WebViewEvaluationResult(
            value: "should-not-reach-executor"
        ))
        let handler = WebViewEvaluateJavaScriptHandler(executor: executor)

        let params: [String: Any] = [
            "document": [
                "kind": "url",
                "url": "https://example.test/",
                "body": "<html></html>",
            ] as [String: Any],
            "javaScript": "document.body",
        ]

        do {
            _ = try await handler.handle(params: params)
            XCTFail("handler should reject url document with body")
        } catch let error as WebViewExecutorError {
            switch error {
            case .invalidParams(let m):
                XCTAssertTrue(m.contains("body"),
                              "error message should mention body, got: \(m)")
            default:
                XCTFail("expected .invalidParams error, got: \(error)")
            }
        } catch {
            XCTFail("expected WebViewExecutorError.invalidParams, got: \(error)")
        }
    }

    func testWebViewRejectsFractionalBooleanAndNegativeTimeouts() async {
        let handler = WebViewEvaluateJavaScriptHandler(executor: StubWebViewExecutor(
            result: WebViewEvaluationResult(value: "unused")
        ))
        for invalid: Any in [true, 1.5, -1] {
            do {
                _ = try await handler.handle(params: [
                    "document": ["kind": "html", "body": "<html></html>"],
                    "javaScript": "1",
                    "timeoutMillis": invalid,
                ])
                XCTFail("invalid timeout must be rejected: \(invalid)")
            } catch WebViewExecutorError.invalidParams(let message) {
                XCTAssertTrue(message.contains("positive integer"))
            } catch {
                XCTFail("unexpected error: \(error)")
            }
        }
    }

    func testWebViewRejectsWhitespaceOnlyProfileID() async {
        let handler = WebViewEvaluateJavaScriptHandler(executor: StubWebViewExecutor(
            result: WebViewEvaluationResult(value: "unused")
        ))
        do {
            _ = try await handler.handle(params: [
                "document": ["kind": "html", "body": "<html></html>"],
                "javaScript": "1",
                "profileId": "  \n ",
            ])
            XCTFail("whitespace profile must be rejected")
        } catch WebViewExecutorError.invalidParams(let message) {
            XCTAssertTrue(message.contains("profileId"))
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    func testWKPolicyAdmissionRejectsDisabledJSNetworkAndBaseURLHostEscape() throws {
        let urlRequest = WebViewEvaluationRequest(
            document: .init(kind: .url, url: "https://allowed.example.test/start"),
            javaScript: "1"
        )
        XCTAssertThrowsError(try WebViewEvaluationPolicyAdmission.validate(
            request: urlRequest,
            policy: .init(allowJavaScriptExecution: false)
        ))
        XCTAssertThrowsError(try WebViewEvaluationPolicyAdmission.validate(
            request: urlRequest,
            policy: .init(allowNetworkNavigation: false)
        ))

        let htmlRequest = WebViewEvaluationRequest(
            document: .init(
                kind: .html,
                body: "<html></html>",
                baseUrl: "https://escape.example.test/base"
            ),
            javaScript: "1"
        )
        XCTAssertThrowsError(try WebViewEvaluationPolicyAdmission.validate(
            request: htmlRequest,
            policy: .testPolicy(allowedHost: "allowed.example.test")
        ))
    }

    func testWKPolicyTimeoutCapsCallerRequest() throws {
        let request = WebViewEvaluationRequest(
            document: .init(kind: .html, body: "<html></html>"),
            javaScript: "1",
            timeoutMillis: 30_000
        )
        let policy = WebViewSecurityPolicy(timeoutSeconds: 0.05)
        try WebViewEvaluationPolicyAdmission.validate(request: request, policy: policy)
        XCTAssertEqual(
            WebViewEvaluationPolicyAdmission.effectiveTimeoutSeconds(request: request, policy: policy),
            0.05,
            accuracy: 0.0001
        )
        XCTAssertFalse(WebViewEvaluationPolicyAdmission.admitsNavigation(
            URL(string: "https://redirect.example.test/")!,
            policy: .testPolicy(allowedHost: "allowed.example.test")
        ))
        XCTAssertThrowsError(try WebViewEvaluationPolicyAdmission.validate(
            request: .init(
                document: .init(kind: .html, body: "<html></html>"),
                javaScript: "1",
                timeoutMillis: 0
            ),
            policy: policy
        ))
        XCTAssertThrowsError(try WebViewEvaluationPolicyAdmission.validate(
            request: .init(
                document: .init(kind: .url, url: "https://user:secret@allowed.example.test/"),
                javaScript: "1"
            ),
            policy: .testPolicy(allowedHost: "allowed.example.test")
        ))
    }

    func testWKSubresourcePolicyBlocksByDefaultAndOnlyExemptsAllowedHost() throws {
        let policy = WebViewSecurityPolicy.testPolicy(allowedHost: "allowed.example.test")
        let encoded = try XCTUnwrap(
            WebViewEvaluationPolicyAdmission.encodedSubresourceRuleList(policy: policy)
        )
        let data = try XCTUnwrap(encoded.data(using: .utf8))
        let rules = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )

        XCTAssertEqual(rules.count, 2)
        XCTAssertEqual(
            (rules[0]["action"] as? [String: String])?["type"],
            "block",
            "the first rule must deny every HTTP(S) resource"
        )
        let allowTrigger = try XCTUnwrap(rules[1]["trigger"] as? [String: Any])
        XCTAssertEqual(
            (rules[1]["action"] as? [String: String])?["type"],
            "ignore-previous-rules"
        )
        XCTAssertNil(
            allowTrigger["if-domain"],
            "if-domain matches the document domain and must not be used as a resource-host exception"
        )
        XCTAssertEqual(
            allowTrigger["url-filter"] as? String,
            #"^https?://allowed\.example\.test[/:?#]"#
        )
        XCTAssertFalse(
            (allowTrigger["url-filter"] as? String)?.contains("blocked") ?? true,
            "a blocked host must never receive an exception rule"
        )
    }

    func testWKSubresourcePolicyKeepsNetworkDisabledHTMLBlockAll() throws {
        let policy = WebViewSecurityPolicy(
            allowedHosts: ["allowed.example.test"],
            allowNetworkNavigation: false,
            allowLocalSnapshotOnly: true
        )
        let encoded = try XCTUnwrap(
            WebViewEvaluationPolicyAdmission.encodedSubresourceRuleList(policy: policy)
        )
        let data = try XCTUnwrap(encoded.data(using: .utf8))
        let rules = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        )
        XCTAssertEqual(rules.count, 1)
        XCTAssertEqual((rules[0]["action"] as? [String: String])?["type"], "block")
    }
}
