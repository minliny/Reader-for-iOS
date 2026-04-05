import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct HeaderProfile: Codable {
    let userAgent: String?
    let referer: String?

    enum CodingKeys: String, CodingKey {
        case userAgent = "user_agent"
        case referer
    }
}

struct RetryPolicy: Codable {
    let maxAttempts: Int?

    enum CodingKeys: String, CodingKey {
        case maxAttempts = "max_attempts"
    }
}

struct RequestPolicy: Codable {
    let noHeader: Bool
    let headerProfile: HeaderProfile
    let noCookie: Bool
    let noLogin: Bool
    let loginMode: String?
    let noJS: Bool
    let noRetry: Bool
    let retryPolicy: RetryPolicy?
    let redirectHandling: Bool
    let jsMarkOnly: Bool?

    enum CodingKeys: String, CodingKey {
        case noHeader = "no_header"
        case headerProfile = "header_profile"
        case noCookie = "no_cookie"
        case noLogin = "no_login"
        case loginMode = "login_mode"
        case noJS = "no_js"
        case noRetry = "no_retry"
        case retryPolicy = "retry_policy"
        case redirectHandling = "redirect_handling"
        case jsMarkOnly = "js_mark_only"
    }
}

struct StepRunnerInput: Codable {
    let sampleId: String
    let stepId: String
    let requestPolicy: RequestPolicy
}

struct StepRunnerOutput: Codable {
    let httpStatus: Int
    let contentType: String
    let finalUrl: String
    let responseClass: String
    let setCookieObserved: Bool
    let loginMarkerObserved: Bool
    let jsChallengeObserved: Bool
    let searchResultMarkerObserved: Bool
    let candidateFailureType: String
    let secondaryReason: String
    let decision: String
}

private struct BookSourceFile: Codable {
    let bookSourceUrl: String
    let searchUrl: String
    let ruleSearch: RuleSearch?
}

private struct RuleSearch: Codable {
    let bookList: String?
}

private enum ResponseClass: String {
    case htmlSearchPage = "html_search_page"
    case blockedPage = "blocked_page"
    case jsGatePage = "js_gate_page"
    case unknown = "unknown"
}

private struct Evaluation {
    let candidateFailureType: String
    let secondaryReason: String
    let decision: String
}

private final class RedirectDelegate: NSObject, URLSessionTaskDelegate {
    let allowRedirects: Bool
    private(set) var lastRedirectURL: URL?

    init(allowRedirects: Bool) {
        self.allowRedirects = allowRedirects
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        lastRedirectURL = request.url
        completionHandler(allowRedirects ? request : nil)
    }
}

private final class MinimalCookieJar {
    private var cookies: [HTTPCookie] = []

    func store(from response: HTTPURLResponse, for url: URL) {
        let headerPairs = response.allHeaderFields.reduce(into: [String: String]()) { partialResult, entry in
            guard let key = entry.key as? String else { return }
            partialResult[key] = String(describing: entry.value)
        }
        let parsedCookies = HTTPCookie.cookies(withResponseHeaderFields: headerPairs, for: url)
        for cookie in parsedCookies {
            cookies.removeAll {
                $0.name == cookie.name && $0.domain == cookie.domain && $0.path == cookie.path
            }
            cookies.append(cookie)
        }
    }

    func headerValue(for url: URL) -> String? {
        let applicable = cookies.filter { cookie in
            guard let host = url.host else { return false }
            let trimmedDomain = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            let matchesDomain = host == cookie.domain || host == trimmedDomain || host.hasSuffix(".\(trimmedDomain)")
            let matchesPath = url.path.hasPrefix(cookie.path)
            return matchesDomain && matchesPath
        }
        guard !applicable.isEmpty else {
            return nil
        }
        return HTTPCookie.requestHeaderFields(with: applicable)["Cookie"]
    }

    var hasCookies: Bool {
        !cookies.isEmpty
    }
}

@main
struct StepRunnerCLI {
    static func main() throws {
        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        guard !inputData.isEmpty else {
            throw RunnerError("STDIN is empty.")
        }

        let decoder = JSONDecoder()
        let input = try decoder.decode(StepRunnerInput.self, from: inputData)
        let repoRoot = try locateRepositoryRoot()
        let searchURL = try buildSearchURL(sampleId: input.sampleId, repoRoot: repoRoot)
        let output = try runStep(input: input, searchURL: searchURL, repoRoot: repoRoot)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let outputData = try encoder.encode(output)
        FileHandle.standardOutput.write(outputData)
    }

    private static func runStep(input: StepRunnerInput, searchURL: URL, repoRoot: URL) throws -> StepRunnerOutput {
        let cookieJar = MinimalCookieJar()
        let attemptCount = input.requestPolicy.noRetry ? 1 : max(1, input.requestPolicy.retryPolicy?.maxAttempts ?? 2)

        var finalStatus = 0
        var finalContentType = "placeholder"
        var finalURL = searchURL.absoluteString
        var finalResponseClass = ResponseClass.unknown
        var setCookieObserved = false
        var loginMarkerObserved = false
        var jsChallengeObserved = false
        var searchResultMarkerObserved = false

        let searchMarkers = try resolveSearchMarkers(sampleId: input.sampleId, repoRoot: repoRoot)

        for _ in 0..<attemptCount {
            let redirectDelegate = RedirectDelegate(allowRedirects: input.requestPolicy.redirectHandling)
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 20
            let session = URLSession(configuration: configuration, delegate: redirectDelegate, delegateQueue: nil)

            var request = URLRequest(url: searchURL)
            request.httpMethod = "GET"

            if !input.requestPolicy.noHeader {
                if let userAgent = input.requestPolicy.headerProfile.userAgent {
                    request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
                }
                if let referer = input.requestPolicy.headerProfile.referer {
                    request.setValue(referer, forHTTPHeaderField: "Referer")
                }
            }

            if !input.requestPolicy.noCookie, let cookieHeader = cookieJar.headerValue(for: searchURL) {
                request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
            }

            do {
                let (data, response) = try session.syncData(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    continue
                }

                finalStatus = httpResponse.statusCode
                finalContentType = httpResponse.mimeType ?? "placeholder"
                finalURL = httpResponse.url?.absoluteString ?? redirectDelegate.lastRedirectURL?.absoluteString ?? searchURL.absoluteString

                if !input.requestPolicy.noCookie {
                    cookieJar.store(from: httpResponse, for: searchURL)
                    setCookieObserved = cookieJar.hasCookies || headerContainsSetCookie(httpResponse: httpResponse)
                } else {
                    setCookieObserved = headerContainsSetCookie(httpResponse: httpResponse)
                }

                let html = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                loginMarkerObserved = detectLoginMarker(in: html)
                jsChallengeObserved = detectJSChallenge(in: html)
                searchResultMarkerObserved = detectSearchResultMarker(in: html, markers: searchMarkers)
                finalResponseClass = classifyResponse(
                    html: html,
                    contentType: finalContentType,
                    searchResultMarkerObserved: searchResultMarkerObserved,
                    jsChallengeObserved: jsChallengeObserved
                )

                if finalStatus == 200, finalResponseClass == .htmlSearchPage, searchResultMarkerObserved {
                    break
                }
            } catch {
                finalStatus = 0
                finalContentType = "placeholder"
                finalURL = searchURL.absoluteString
                finalResponseClass = .unknown
            }
        }

        let evaluation = evaluate(
            stepId: input.stepId,
            statusCode: finalStatus,
            responseClass: finalResponseClass,
            loginMarkerObserved: loginMarkerObserved,
            jsChallengeObserved: jsChallengeObserved,
            searchResultMarkerObserved: searchResultMarkerObserved
        )

        return StepRunnerOutput(
            httpStatus: finalStatus,
            contentType: finalContentType,
            finalUrl: finalURL,
            responseClass: finalResponseClass.rawValue,
            setCookieObserved: setCookieObserved,
            loginMarkerObserved: loginMarkerObserved,
            jsChallengeObserved: jsChallengeObserved,
            searchResultMarkerObserved: searchResultMarkerObserved,
            candidateFailureType: evaluation.candidateFailureType,
            secondaryReason: evaluation.secondaryReason,
            decision: evaluation.decision
        )
    }

    private static func resolveSearchMarkers(sampleId: String, repoRoot: URL) throws -> [String] {
        let bookSourcePath = try resolveBookSourcePath(sampleId: sampleId, repoRoot: repoRoot)
        let data = try Data(contentsOf: bookSourcePath)
        let bookSource = try JSONDecoder().decode(BookSourceFile.self, from: data)
        let rawRule = bookSource.ruleSearch?.bookList ?? ""
        let delimiters = CharacterSet(charactersIn: "@!|, \n\r\t")
        let parts = rawRule.components(separatedBy: delimiters).filter { !$0.isEmpty }
        let normalized = parts.map { token -> String in
            if token.hasPrefix("id.") {
                return String(token.dropFirst(3)).lowercased()
            }
            if token.hasPrefix(".") {
                return String(token.dropFirst()).lowercased()
            }
            return token.lowercased()
        }
        return Array(Set(normalized))
    }

    private static func buildSearchURL(sampleId: String, repoRoot: URL) throws -> URL {
        let bookSourcePath = try resolveBookSourcePath(sampleId: sampleId, repoRoot: repoRoot)
        let data = try Data(contentsOf: bookSourcePath)
        let bookSource = try JSONDecoder().decode(BookSourceFile.self, from: data)
        let keyword = "测试".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "%E6%B5%8B%E8%AF%95"
        let rawSearch = bookSource.searchUrl.replacingOccurrences(of: "{{key}}", with: keyword)

        if let absolute = URL(string: rawSearch), absolute.scheme != nil {
            return absolute
        }

        guard let baseURL = URL(string: bookSource.bookSourceUrl),
              let fullURL = URL(string: rawSearch, relativeTo: baseURL)?.absoluteURL else {
            throw RunnerError("Unable to build search URL for sample \(sampleId).")
        }
        return fullURL
    }

    private static func resolveBookSourcePath(sampleId: String, repoRoot: URL) throws -> URL {
        let mapping: [String: String] = [
            "SAMPLE-P1-COOKIE-XIANGSHU-001": "samples/booksources/p1_cookie/p1_cookie_xiangshu_search_toc_content_001.json",
            "SAMPLE-P1-COOKIE-WENSANG-001": "samples/booksources/p1_cookie/p1_cookie_wensang_search_toc_content_001.json",
            "SAMPLE-P1-COOKIE-XUANYGE-001": "samples/booksources/p1_cookie/p1_cookie_xuanyge_search_toc_content_001.json"
        ]

        guard let relativePath = mapping[sampleId] else {
            throw RunnerError("Unsupported sampleId: \(sampleId)")
        }

        return repoRoot.appendingPathComponent(relativePath)
    }

    private static func locateRepositoryRoot() throws -> URL {
        var current = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while true {
            let candidate = current.appendingPathComponent("samples")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return current
            }

            let parent = current.deletingLastPathComponent()
            if parent.path == current.path {
                break
            }
            current = parent
        }

        throw RunnerError("Repository root not found from current directory.")
    }

    private static func classifyResponse(
        html: String,
        contentType: String,
        searchResultMarkerObserved: Bool,
        jsChallengeObserved: Bool
    ) -> ResponseClass {
        let normalizedHTML = html.lowercased()
        let normalizedContentType = contentType.lowercased()

        guard normalizedContentType.contains("html") || normalizedHTML.contains("<html") else {
            return .unknown
        }

        if jsChallengeObserved {
            return .jsGatePage
        }

        if detectBlockedPage(in: normalizedHTML) {
            return .blockedPage
        }

        if searchResultMarkerObserved {
            return .htmlSearchPage
        }

        return .unknown
    }

    private static func detectSearchResultMarker(in html: String, markers: [String]) -> Bool {
        let normalized = html.lowercased()
        for marker in markers where !marker.isEmpty {
            if normalized.contains("<\(marker)") ||
                normalized.contains("id=\"\(marker)\"") ||
                normalized.contains("class=\"\(marker)\"") ||
                normalized.contains("class='\(marker)'") ||
                normalized.contains("id='\(marker)'") {
                return true
            }
        }
        return false
    }

    private static func detectLoginMarker(in html: String) -> Bool {
        let normalized = html.lowercased()
        let markers = [
            "login",
            "sign in",
            "signin",
            "password",
            "用户名",
            "登录",
            "账号",
            "密码",
            "授权"
        ]
        return markers.contains { normalized.contains($0) }
    }

    private static func detectJSChallenge(in html: String) -> Bool {
        let normalized = html.lowercased()
        let markers = [
            "__jsl_clearance",
            "javascript required",
            "enable javascript",
            "please enable javascript",
            "document.cookie",
            "window.location",
            "cf-browser-verification",
            "challenge-platform",
            "settimeout(function()",
            "<noscript"
        ]
        return markers.contains { normalized.contains($0) }
    }

    private static func detectBlockedPage(in html: String) -> Bool {
        let markers = [
            "access denied",
            "forbidden",
            "verify you are human",
            "captcha",
            "安全验证",
            "访问受限",
            "禁止访问"
        ]
        return markers.contains { html.contains($0) }
    }

    private static func headerContainsSetCookie(httpResponse: HTTPURLResponse) -> Bool {
        httpResponse.allHeaderFields.keys.contains { key in
            String(describing: key).lowercased() == "set-cookie"
        }
    }

    private static func evaluate(
        stepId: String,
        statusCode: Int,
        responseClass: ResponseClass,
        loginMarkerObserved: Bool,
        jsChallengeObserved: Bool,
        searchResultMarkerObserved: Bool
    ) -> Evaluation {
        let success = statusCode == 200 && responseClass == .htmlSearchPage && searchResultMarkerObserved

        if success {
            switch stepId {
            case "TEST-003":
                return Evaluation(
                    candidateFailureType: "COOKIE_REQUIRED",
                    secondaryReason: "missing_required_cookie",
                    decision: "stop_and_update_matrix"
                )
            case "TEST-006":
                return Evaluation(
                    candidateFailureType: "LOGIN_REQUIRED",
                    secondaryReason: loginMarkerObserved ? "login_state_absent" : "auth_redirect_detected",
                    decision: "stop_and_update_matrix"
                )
            case "BASELINE-000":
                return Evaluation(
                    candidateFailureType: "NETWORK_POLICY_MISMATCH",
                    secondaryReason: "baseline_controlled_fetch_failed",
                    decision: "continue"
                )
            case "TEST-001":
                return Evaluation(
                    candidateFailureType: "NETWORK_POLICY_MISMATCH",
                    secondaryReason: "invalid_user_agent",
                    decision: "stop_and_update_matrix"
                )
            case "TEST-002":
                return Evaluation(
                    candidateFailureType: "NETWORK_POLICY_MISMATCH",
                    secondaryReason: "missing_referer",
                    decision: "stop_and_update_matrix"
                )
            case "TEST-005":
                return Evaluation(
                    candidateFailureType: "NETWORK_POLICY_MISMATCH",
                    secondaryReason: "redirect_not_handled",
                    decision: "stop_and_update_matrix"
                )
            default:
                return Evaluation(
                    candidateFailureType: "NETWORK_POLICY_MISMATCH",
                    secondaryReason: "undetermined_after_isolation",
                    decision: "unresolved"
                )
            }
        }

        if jsChallengeObserved || responseClass == .jsGatePage {
            return Evaluation(
                candidateFailureType: "NETWORK_POLICY_MISMATCH",
                secondaryReason: "js_challenge_observed",
                decision: "continue"
            )
        }

        if stepId == "BASELINE-000" {
            return Evaluation(
                candidateFailureType: "NETWORK_POLICY_MISMATCH",
                secondaryReason: "baseline_controlled_fetch_failed",
                decision: "continue"
            )
        }

        return Evaluation(
            candidateFailureType: "NETWORK_POLICY_MISMATCH",
            secondaryReason: "undetermined_after_isolation",
            decision: "unresolved"
        )
    }
}

private struct RunnerError: Error, LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}

private extension URLSession {
    func syncData(for request: URLRequest) throws -> (Data, URLResponse) {
        let semaphore = DispatchSemaphore(value: 0)
        var resultData = Data()
        var resultResponse: URLResponse?
        var resultError: Error?

        let task = dataTask(with: request) { data, response, error in
            resultData = data ?? Data()
            resultResponse = response
            resultError = error
            semaphore.signal()
        }
        task.resume()
        semaphore.wait()

        if let resultError {
            throw resultError
        }

        guard let resultResponse else {
            throw RunnerError("No response returned.")
        }

        return (resultData, resultResponse)
    }
}
