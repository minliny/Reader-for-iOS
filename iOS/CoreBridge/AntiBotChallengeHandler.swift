// CoreBridge
//
// AntiBotChallengeHandler: anti-bot challenge detection + handler for the
// `anti_bot` host lane.
//
// Mirrors the Rust Core contract in
// `crates/reader-contract/src/host.rs`:
// - `HostErrorCode::ChallengeRequired` (serializes to `"CHALLENGE_REQUIRED"`)
//   — host-owned capability execution failure for unsolvable anti-bot
//   challenges (captcha, human verification, unsupported JS challenge). Core
//   marks the source as `host_required` and skips retries — this is a
//   fail-closed signal, not a transient failure.
// - `HostErrorDiagnostics::challenge_required(lane, challenge_type, url)`
//   builder — produces a diagnostic with `phase: "response"` and details:
//   `{lane, challengeType, url, autoRetryable: false}`. iOS extends the
//   details with `cookieJarId` for per-source session tracking.
// - `HostLane::AntiBot` (serializes to `"anti_bot"`) — one of the four host
//   lanes (`anti_bot`, `login_cookie`, `webview_render`, `media_download`).
//
// Proof tier (this file): handler/router. The handler fetches the URL via an
// `AntiBotExecutor`, runs the `AntiBotChallengeDetector` on the response, and
// either returns the clean body or builds a `ChallengeRequired` diagnostic
// dict matching Core's `HostErrorDiagnostics` contract. Proof tests use
// `StubAntiBotExecutor` — no real network or WKWebView is exercised.
//
// Device-headless/App tier (pending): real anti_bot source L1-L5 (cloudflare
// JS challenge solving via headless WKWebView, slider/reCAPTCHA delegation to
// a human-verifier UI, cookie jar persistence) requires device-tier proof
// (simulator / real device). The production `WKAntiBotExecutor` is a
// `notImplemented` stub until that tier lands.
//
// Anti-bot is a lane coordinator, NOT a CapabilityHandler — it coordinates
// HTTP fetch + challenge detection rather than serving a single Core
// capability request. The result enum (`AntiBotHandleResult`) lets the caller
// (router / source fetch pipeline) distinguish `.completed` from
// `.challengeRequired` without throwing, so Core can route the diagnostic
// into its `host.error` channel with the right `lane` / `challengeType`.

import Foundation

// MARK: - AntiBotExecutorError

/// Errors thrown by the anti-bot lane executor / handler.
public enum AntiBotExecutorError: Error, Equatable, LocalizedError {
    case invalidParams(String)
    case networkError(String)
    case notImplemented(String)

    public var errorDescription: String? {
        switch self {
        case .invalidParams(let m): return "AntiBot invalid params: \(m)"
        case .networkError(let m): return "AntiBot network error: \(m)"
        case .notImplemented(let m): return "AntiBot executor not implemented: \(m)"
        }
    }
}

// MARK: - AntiBotChallengeType

/// Classified anti-bot challenge type. The raw string (`asString`) is what
/// gets serialized into the `challengeType` field of the Core
/// `HostErrorDiagnostics` details (free-form string per Core contract).
public enum AntiBotChallengeType: Sendable, Equatable {
    /// No challenge detected — response is clean content.
    case none
    /// Cloudflare JS challenge (HTTP 503 + `jschl` / `cf-browser-verification`
    /// markers). Solving requires a real browser JS engine.
    case cloudflareJs
    /// Slider captcha (body contains both `slider` and `captcha` markers).
    /// Solving requires human interaction or a slider-solving service.
    case sliderCaptcha
    /// reCAPTCHA v2 (body contains `recaptcha` or `g-recaptcha` markers).
    /// Solving requires human interaction or a captcha-solving service.
    case recaptchaV2
    /// Unsupported challenge — the Host detected a challenge it cannot
    /// classify or solve (e.g. HTTP 403 with no known markers). The payload
    /// is a free-form reason string (e.g. `"http_403"`).
    case unsupported(String)

    /// Stable snake_case identifier for the Core `challengeType` field.
    /// Mirrors the Core contract examples (`"cloudflare_js"`,
    /// `"slider_captcha"`, `"recaptcha_v2"`). For `.unsupported`, the form is
    /// `"unsupported:<reason>"` so callers can both detect "unsupported" via
    /// prefix and inspect the reason.
    public var asString: String {
        switch self {
        case .none: return "none"
        case .cloudflareJs: return "cloudflare_js"
        case .sliderCaptcha: return "slider_captcha"
        case .recaptchaV2: return "recaptcha_v2"
        case .unsupported(let reason): return "unsupported:\(reason)"
        }
    }
}

// MARK: - AntiBotChallengeDetection

/// Result of running `AntiBotChallengeDetector` on an `AntiBotHttpResponse`.
/// Carries the classified `challengeType`, the URL where the challenge was
/// encountered, and the `cookieJarId` (per-source session identifier) so the
/// handler can preserve session affinity in the diagnostic.
public struct AntiBotChallengeDetection: Sendable, Equatable {
    public let challengeType: AntiBotChallengeType
    public let challengeUrl: String
    public let cookieJarId: String?

    public init(challengeType: AntiBotChallengeType, challengeUrl: String, cookieJarId: String? = nil) {
        self.challengeType = challengeType
        self.challengeUrl = challengeUrl
        self.cookieJarId = cookieJarId
    }
}

// MARK: - AntiBotHttpResponse

/// HTTP response produced by an `AntiBotExecutor`. Mirrors the minimal shape
/// Core needs to classify a response: status code, body (HTML/text), response
/// headers, and the final URL after any redirects.
public struct AntiBotHttpResponse: Sendable, Equatable {
    public let statusCode: Int
    public let body: String
    public let headers: [String: String]
    public let finalUrl: String

    public init(statusCode: Int, body: String, headers: [String: String] = [:], finalUrl: String) {
        self.statusCode = statusCode
        self.body = body
        self.headers = headers
        self.finalUrl = finalUrl
    }
}

// MARK: - AntiBotExecutor

/// Executor abstraction for the `anti_bot` host lane. Core produces the
/// request descriptor (URL, headers, cookieJarId); the Host executes the HTTP
/// fetch (with cookie jar affinity) and returns the response. Core never
/// opens a socket or touches a WebView directly (Core/Host boundary, red
/// line 4).
///
/// `async throws` because the production executor (`WKAntiBotExecutor`)
/// performs real WKWebView navigation + HTTP fetch (cloudflare JS challenge
/// solving, cookie jar persistence) — all inherently asynchronous. The stub
/// executor used in proof tests is also `async throws` for protocol
/// conformance.
public protocol AntiBotExecutor: Sendable {
    func fetch(url: String, headers: [String: String], cookieJarId: String?) async throws -> AntiBotHttpResponse
}

// MARK: - AntiBotChallengeDetector

/// Classifies an `AntiBotHttpResponse` into an `AntiBotChallengeDetection`.
/// The detection rules mirror Legado's anti-bot heuristics (marker-based, no
/// JS execution) so sources protected by Cloudflare JS / slider / reCAPTCHA
/// can be flagged for `host_required` routing rather than retried blindly.
///
/// Detection order matters: more specific markers are checked first. The
/// rules are:
/// 1. HTTP 503 + body contains `jschl` or `cf-browser-verification` →
///    `.cloudflareJs`
/// 2. body contains both `slider` and `captcha` → `.sliderCaptcha`
/// 3. body contains `recaptcha` or `g-recaptcha` → `.recaptchaV2`
/// 4. HTTP 403 + none of the above → `.unsupported("http_403")`
/// 5. otherwise → `.none`
///
/// All body checks are case-insensitive (HTML attributes / tag names are
/// case-insensitive in practice).
public final class AntiBotChallengeDetector: Sendable {
    public init() {}

    public func detect(
        response: AntiBotHttpResponse,
        url: String,
        cookieJarId: String?
    ) -> AntiBotChallengeDetection {
        let body = response.body.lowercased()

        // 1. Cloudflare JS challenge (highest specificity — 503 + marker).
        if response.statusCode == 503
            && (body.contains("jschl") || body.contains("cf-browser-verification")) {
            return AntiBotChallengeDetection(
                challengeType: .cloudflareJs,
                challengeUrl: url,
                cookieJarId: cookieJarId
            )
        }

        // 2. Slider captcha (both markers required to avoid false positives
        // on pages that merely mention "slider" or "captcha" in copy).
        if body.contains("slider") && body.contains("captcha") {
            return AntiBotChallengeDetection(
                challengeType: .sliderCaptcha,
                challengeUrl: url,
                cookieJarId: cookieJarId
            )
        }

        // 3. reCAPTCHA v2.
        if body.contains("recaptcha") || body.contains("g-recaptcha") {
            return AntiBotChallengeDetection(
                challengeType: .recaptchaV2,
                challengeUrl: url,
                cookieJarId: cookieJarId
            )
        }

        // 4. HTTP 403 with no known markers — unsupported challenge.
        if response.statusCode == 403 {
            return AntiBotChallengeDetection(
                challengeType: .unsupported("http_403"),
                challengeUrl: url,
                cookieJarId: cookieJarId
            )
        }

        // 5. Clean response.
        return AntiBotChallengeDetection(
            challengeType: .none,
            challengeUrl: url,
            cookieJarId: cookieJarId
        )
    }
}

// MARK: - AntiBotHandleResult

/// Result of `AntiBotChallengeHandler.handle`. The handler does NOT throw on
/// challenge detection — challenge required is a normal lane outcome that
/// Core routes into its `host.error` channel, not a Swift-level execution
/// failure. Throwing is reserved for executor-level failures
/// (`AntiBotExecutorError`) that cannot produce a usable detection.
public enum AntiBotHandleResult {
    /// Clean response — body is the fetched content, `finalUrl` is the
    /// post-redirect URL.
    case completed(body: String, finalUrl: String)
    /// Anti-bot challenge detected — `diagnostics` is the Core
    /// `HostErrorDiagnostics` JSON dict (`{code, phase, message, details}`)
    /// ready to be forwarded into Core's `host.error` channel.
    case challengeRequired(diagnostics: [String: Any])
}

// MARK: - AntiBotChallengeHandler

/// Anti-bot lane coordinator: fetches a URL via `AntiBotExecutor`, runs the
/// `AntiBotChallengeDetector` on the response, and either returns the clean
/// body (`.completed`) or builds a `ChallengeRequired` diagnostic dict
/// (`.challengeRequired`) matching Core's `HostErrorDiagnostics` contract.
///
/// JSON contract (aligned with Core's `HostErrorDiagnostics`):
/// ```json
/// {
///   "code": "CHALLENGE_REQUIRED",
///   "phase": "response",
///   "message": "Host lane anti_bot encountered an unsolvable challenge (cloudflare_js) at <url>",
///   "details": {
///     "lane": "anti_bot",
///     "challengeType": "cloudflare_js",
///     "url": "<url>",
///     "autoRetryable": false,
///     "cookieJarId": "<cookieJarId>"
///   }
/// }
/// ```
/// `cookieJarId` is included in `details` so Core can preserve per-source
/// session affinity when retrying the source later (after a human solves the
/// challenge in the App tier).
public struct AntiBotChallengeHandler: Sendable {
    private let executor: AntiBotExecutor
    private let detector: AntiBotChallengeDetector

    public init(executor: AntiBotExecutor, detector: AntiBotChallengeDetector = AntiBotChallengeDetector()) {
        self.executor = executor
        self.detector = detector
    }

    /// Fetch `url` and classify the response. On clean response, returns
    /// `.completed(body:finalUrl:)`. On challenge detection, returns
    /// `.challengeRequired(diagnostics:)` with the Core-shaped
    /// `HostErrorDiagnostics` dict. Throws `AntiBotExecutorError` only when
    /// the executor itself fails (network error, not implemented) — those are
    /// lane-execution failures, not challenge detections.
    public func handle(
        url: String,
        headers: [String: String],
        cookieJarId: String?
    ) async throws -> AntiBotHandleResult {
        let response = try await executor.fetch(url: url, headers: headers, cookieJarId: cookieJarId)
        let detection = detector.detect(response: response, url: url, cookieJarId: cookieJarId)

        switch detection.challengeType {
        case .none:
            return .completed(body: response.body, finalUrl: response.finalUrl)
        default:
            let diagnostics = Self.buildChallengeRequiredDiagnostics(
                challengeType: detection.challengeType,
                url: url,
                cookieJarId: cookieJarId
            )
            return .challengeRequired(diagnostics: diagnostics)
        }
    }

    /// Build the Core `HostErrorDiagnostics` JSON dict for a
    /// `ChallengeRequired` diagnostic. Exposed as internal so proof tests can
    /// verify the payload contract without re-running the handler.
    internal static func buildChallengeRequiredDiagnostics(
        challengeType: AntiBotChallengeType,
        url: String,
        cookieJarId: String?
    ) -> [String: Any] {
        let challengeTypeStr = challengeType.asString
        let message = "Host lane anti_bot encountered an unsolvable challenge (\(challengeTypeStr)) at \(url)"

        var details: [String: Any] = [
            "lane": "anti_bot",
            "challengeType": challengeTypeStr,
            "url": url,
            "autoRetryable": false,
        ]
        if let cookieJarId = cookieJarId, !cookieJarId.isEmpty {
            details["cookieJarId"] = cookieJarId
        }

        return [
            "code": "CHALLENGE_REQUIRED",
            "phase": "response",
            "message": message,
            "details": details,
        ]
    }
}

// MARK: - StubAntiBotExecutor (test proof tier)

/// Stub `AntiBotExecutor` for handler/router proof tests. Returns either a
/// single canned response for every URL, or a per-URL canned response with a
/// default fallback. No real network is exercised. Mirrors the role of
/// `StubWebViewExecutor` for the webview_render lane.
public final class StubAntiBotExecutor: AntiBotExecutor, @unchecked Sendable {
    private let defaultResponse: AntiBotHttpResponse
    private let perUrlResponses: [String: AntiBotHttpResponse]

    /// Initialize with a single canned response returned for every `fetch`
    /// call regardless of URL.
    public init(defaultResponse: AntiBotHttpResponse) {
        self.defaultResponse = defaultResponse
        self.perUrlResponses = [:]
    }

    /// Initialize with per-URL canned responses plus a default fallback for
    /// URLs not in the map.
    public init(perUrlResponses: [String: AntiBotHttpResponse], defaultResponse: AntiBotHttpResponse) {
        self.defaultResponse = defaultResponse
        self.perUrlResponses = perUrlResponses
    }

    public func fetch(url: String, headers: [String: String], cookieJarId: String?) async throws -> AntiBotHttpResponse {
        return perUrlResponses[url] ?? defaultResponse
    }
}

// MARK: - WKAntiBotExecutor
//
// The real `WKAntiBotExecutor` implementation lives in
// `WKAntiBotExecutor.swift` (WKWebView navigation + HTTP fetch, cookie jar
// persistence, challenge detection via `AntiBotChallengeDetector`). It was
// extracted from this file so the handler/router proof
// (`StubAntiBotExecutor`) and the production executor can evolve
// independently.
