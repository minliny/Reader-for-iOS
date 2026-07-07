import XCTest
import ReaderCoreProtocols
@testable import ReaderShellValidation

/// iOS Host-side proof for the `anti_bot` lane — mirrors the structure of
/// `HostWebViewRenderProofTests` (3 proof + 2 validation cases) so iOS
/// reaches the same handler/router proof level as the other three host lanes.
///
/// Proof tier (this file): handler/router. These tests verify that
/// `AntiBotChallengeHandler` correctly fetches a URL via `AntiBotExecutor`,
/// runs `AntiBotChallengeDetector` on the response, and either returns
/// `.completed` (clean body) or `.challengeRequired` (Core-shaped
/// `HostErrorDiagnostics` dict). They use `StubAntiBotExecutor` — no real
/// network or WKWebView is exercised.
///
/// Production executor status (do NOT conflate with "backend ready"):
/// `WKAntiBotExecutor` is a REAL two-layer implementation (L1 URLSession HTTP
/// fetch + L2 headless WKWebView fallback when `shouldAttemptWebViewFallback`
/// detects `jschl` / `cf-browser-verification` / `cf-challenge`). It is
/// iOS-only because the L2 path imports WebKit; on macOS `swift build` the
/// router leaves `antiBotExecutor = nil` and fails closed with
/// `antiBotExecutorNotConfigured`.
///
/// Device-tier gaps (still pending, NOT covered by macOS `swift test`):
/// - `cookieJarId` is accepted but NOT bound to `WKWebsiteDataStore` —
///   cookie persistence across L1/L2 is per-source but not yet persistent.
/// - Slider / reCAPTCHA human-verifier delegation is fail-closed only
///   (`ChallengeRequired` returned; no UI to solve).
/// - Real Cloudflare JS challenge solving depends on real-device user-agent /
///   JIT, which the simulator does not faithfully emulate.
///
/// Mirrors Core contract in `crates/reader-contract/src/host.rs`:
/// - `HostErrorCode::ChallengeRequired` → `"CHALLENGE_REQUIRED"`
/// - `HostErrorDiagnostics::challenge_required(lane, challenge_type, url)`
///   builder — `phase: "response"`, details `{lane, challengeType, url,
///   autoRetryable: false}`, iOS extends details with `cookieJarId`.
/// - `HostLane::AntiBot` → `"anti_bot"`.
final class HostAntiBotProofTests: XCTestCase {

    // MARK: - Proof 1: clean response returns .completed

    /// StubAntiBotExecutor returns 200 OK HTML, detector returns `.none`,
    /// handler returns `.completed` with the canned body and `finalUrl`.
    /// This is the happy path — no challenge, Core can consume the body
    /// directly.
    func testCleanResponseReturnsCompletedResult() async throws {
        let executor = StubAntiBotExecutor(defaultResponse: AntiBotHttpResponse(
            statusCode: 200,
            body: "<html><body><h1>Real Book Content</h1><p>chapter text...</p></body></html>",
            headers: ["Content-Type": "text/html; charset=utf-8"],
            finalUrl: "https://example.test/book/chapter-1"
        ))
        let handler = AntiBotChallengeHandler(executor: executor)

        let result = try await handler.handle(
            url: "https://example.test/book/chapter-1",
            headers: ["User-Agent": "Reader/1.0"],
            cookieJarId: "source-clean-001"
        )

        switch result {
        case .completed(let body, let finalUrl):
            XCTAssertTrue(body.contains("Real Book Content"),
                          "completed body must carry the canned HTML, got: \(body)")
            XCTAssertEqual(finalUrl, "https://example.test/book/chapter-1",
                           "finalUrl must match the canned response finalUrl")
        case .challengeRequired(let diagnostics):
            XCTFail("clean response must not trigger challengeRequired, got diagnostics: \(diagnostics)")
        }
    }

    // MARK: - Proof 2: Cloudflare JS challenge returns ChallengeRequired

    /// Stub returns 503 with Cloudflare JS challenge markers (`jschl` /
    /// `cf-browser-verification`), handler returns `.challengeRequired` with
    /// `code = "CHALLENGE_REQUIRED"`, `challengeType = "cloudflare_js"`,
    /// `lane = "anti_bot"`, `autoRetryable = false`. This is the fail-closed
    /// path — Core marks the source as `host_required` and skips retries.
    func testCloudflareJsChallengeReturnsChallengeRequired() async throws {
        let executor = StubAntiBotExecutor(defaultResponse: AntiBotHttpResponse(
            statusCode: 503,
            body: "<html><head><title>Just a moment...</title><script src=\"/jschl.js\"></script></head><body>cf-browser-verification</body></html>",
            headers: ["Server": "cloudflare"],
            finalUrl: "https://protected.test/chapter-1"
        ))
        let handler = AntiBotChallengeHandler(executor: executor)

        let result = try await handler.handle(
            url: "https://protected.test/chapter-1",
            headers: [:],
            cookieJarId: nil
        )

        switch result {
        case .completed:
            XCTFail("Cloudflare 503 response must not return .completed")
        case .challengeRequired(let diagnostics):
            XCTAssertEqual(diagnostics["code"] as? String, "CHALLENGE_REQUIRED",
                           "code must be CHALLENGE_REQUIRED")
            XCTAssertEqual(diagnostics["phase"] as? String, "response",
                           "phase must be response")
            guard let details = diagnostics["details"] as? [String: Any] else {
                XCTFail("diagnostics must include details dict, got: \(diagnostics)")
                return
            }
            XCTAssertEqual(details["lane"] as? String, "anti_bot",
                           "lane must be anti_bot")
            XCTAssertEqual(details["challengeType"] as? String, "cloudflare_js",
                           "challengeType must be cloudflare_js")
            XCTAssertEqual(details["url"] as? String, "https://protected.test/chapter-1",
                           "url must match the requested URL")
            XCTAssertEqual(details["autoRetryable"] as? Bool, false,
                           "autoRetryable must be false — fail-closed signal")
        }
    }

    // MARK: - Proof 3: slider captcha returns ChallengeRequired

    /// Stub returns HTML with slider captcha markers (both `slider` and
    /// `captcha`), handler returns `.challengeRequired` with
    /// `challengeType = "slider_captcha"`. This proves the detector's
    /// dual-marker rule (avoid false positives on copy that mentions only one
    /// of the two).
    func testSliderCaptchaReturnsChallengeRequired() async throws {
        let executor = StubAntiBotExecutor(defaultResponse: AntiBotHttpResponse(
            statusCode: 200,
            body: "<html><body><div class=\"slider-captcha-widget\">slide to verify</div></body></html>",
            headers: [:],
            finalUrl: "https://captcha.test/page"
        ))
        let handler = AntiBotChallengeHandler(executor: executor)

        let result = try await handler.handle(
            url: "https://captcha.test/page",
            headers: [:],
            cookieJarId: nil
        )

        switch result {
        case .completed:
            XCTFail("slider captcha response must not return .completed")
        case .challengeRequired(let diagnostics):
            XCTAssertEqual(diagnostics["code"] as? String, "CHALLENGE_REQUIRED",
                           "code must be CHALLENGE_REQUIRED")
            guard let details = diagnostics["details"] as? [String: Any] else {
                XCTFail("diagnostics must include details dict, got: \(diagnostics)")
                return
            }
            XCTAssertEqual(details["challengeType"] as? String, "slider_captcha",
                           "challengeType must be slider_captcha")
            XCTAssertEqual(details["lane"] as? String, "anti_bot",
                           "lane must be anti_bot")
        }
    }

    // MARK: - Proof 4: reCAPTCHA v2 returns ChallengeRequired

    /// Stub returns HTML with `g-recaptcha` marker, handler returns
    /// `.challengeRequired` with `challengeType = "recaptcha_v2"`. This
    /// proves the detector catches both `recaptcha` and `g-recaptcha`
    /// (Google's div class) markers.
    func testRecaptchaReturnsChallengeRequired() async throws {
        let executor = StubAntiBotExecutor(defaultResponse: AntiBotHttpResponse(
            statusCode: 200,
            body: "<html><body><div class=\"g-recaptcha\" data-sitekey=\"6Le_example\"></div><script src=\"https://www.google.com/recaptcha/api.js\"></script></body></html>",
            headers: [:],
            finalUrl: "https://verified.test/entry"
        ))
        let handler = AntiBotChallengeHandler(executor: executor)

        let result = try await handler.handle(
            url: "https://verified.test/entry",
            headers: [:],
            cookieJarId: nil
        )

        switch result {
        case .completed:
            XCTFail("reCAPTCHA response must not return .completed")
        case .challengeRequired(let diagnostics):
            XCTAssertEqual(diagnostics["code"] as? String, "CHALLENGE_REQUIRED",
                           "code must be CHALLENGE_REQUIRED")
            guard let details = diagnostics["details"] as? [String: Any] else {
                XCTFail("diagnostics must include details dict, got: \(diagnostics)")
                return
            }
            XCTAssertEqual(details["challengeType"] as? String, "recaptcha_v2",
                           "challengeType must be recaptcha_v2")
            XCTAssertEqual(details["lane"] as? String, "anti_bot",
                           "lane must be anti_bot")
            XCTAssertEqual(details["autoRetryable"] as? Bool, false,
                           "autoRetryable must be false — fail-closed signal")
        }
    }

    // MARK: - Validation 1: cookieJarId preserved in error details

    /// Handler called with `cookieJarId = "source-abc-123"`, the
    /// `.challengeRequired` diagnostics `details` must include this
    /// `cookieJarId` so Core can preserve per-source session affinity when
    /// retrying the source after a human solves the challenge.
    func testCookieJarIdPreservedInErrorDetails() async throws {
        let executor = StubAntiBotExecutor(defaultResponse: AntiBotHttpResponse(
            statusCode: 503,
            body: "<html><body>jschlvcf-browser-verification</body></html>",
            headers: [:],
            finalUrl: "https://protected.test/chapter-2"
        ))
        let handler = AntiBotChallengeHandler(executor: executor)

        let result = try await handler.handle(
            url: "https://protected.test/chapter-2",
            headers: [:],
            cookieJarId: "source-abc-123"
        )

        switch result {
        case .completed:
            XCTFail("503 + jschl response must not return .completed")
        case .challengeRequired(let diagnostics):
            guard let details = diagnostics["details"] as? [String: Any] else {
                XCTFail("diagnostics must include details dict, got: \(diagnostics)")
                return
            }
            XCTAssertEqual(details["cookieJarId"] as? String, "source-abc-123",
                           "cookieJarId must be preserved in details for session affinity")
            XCTAssertEqual(details["lane"] as? String, "anti_bot",
                           "lane must be anti_bot")
            XCTAssertEqual(details["challengeType"] as? String, "cloudflare_js",
                           "challengeType must be cloudflare_js (503 + jschl marker)")
        }
    }

    // MARK: - Validation 2: unsupported challenge returns ChallengeRequired

    /// Stub returns 403 with no known markers, handler returns
    /// `.challengeRequired` with `challengeType` starting with `"unsupported"`.
    /// This proves the catch-all rule — unknown challenges still fail closed
    /// (Core stops retrying) rather than silently passing as `.completed`.
    func testUnsupportedChallengeReturnsChallengeRequired() async throws {
        let executor = StubAntiBotExecutor(defaultResponse: AntiBotHttpResponse(
            statusCode: 403,
            body: "<html><body>Access denied. You do not have permission to access this resource.</body></html>",
            headers: [:],
            finalUrl: "https://forbidden.test/page"
        ))
        let handler = AntiBotChallengeHandler(executor: executor)

        let result = try await handler.handle(
            url: "https://forbidden.test/page",
            headers: [:],
            cookieJarId: "source-forbidden-456"
        )

        switch result {
        case .completed:
            XCTFail("403 response must not return .completed")
        case .challengeRequired(let diagnostics):
            XCTAssertEqual(diagnostics["code"] as? String, "CHALLENGE_REQUIRED",
                           "code must be CHALLENGE_REQUIRED")
            guard let details = diagnostics["details"] as? [String: Any] else {
                XCTFail("diagnostics must include details dict, got: \(diagnostics)")
                return
            }
            guard let challengeType = details["challengeType"] as? String else {
                XCTFail("details must include challengeType, got: \(details)")
                return
            }
            XCTAssertTrue(challengeType.hasPrefix("unsupported"),
                          "challengeType must start with 'unsupported' for unknown 403, got: \(challengeType)")
            XCTAssertTrue(challengeType.contains("http_403"),
                          "challengeType must carry the http_403 reason, got: \(challengeType)")
            XCTAssertEqual(details["autoRetryable"] as? Bool, false,
                           "autoRetryable must be false — fail-closed signal")
            XCTAssertEqual(details["cookieJarId"] as? String, "source-forbidden-456",
                           "cookieJarId must be preserved in details")
        }
    }
}
