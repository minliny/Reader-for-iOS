// SampleLogin002IsolationRunner/main.swift
// Minimum-variable isolation for sample_login_002 (practice.expandtesting.com)
// Usage: swift run --package-path Core SampleLogin002IsolationRunner -- <repo_root>

import Foundation
import ReaderCoreModels
import ReaderCoreNetwork
import ReaderCoreProtocols
import ReaderCoreFoundation
import ReaderPlatformAdapters

private struct LoginFlowConfig {
    let method: String
    let contentType: String
    let actionURL: String
    let usernameField: String
    let passwordField: String
    let usernameValue: String
    let passwordValue: String
    let successURL: String
    let successMarkers: [String]
}

private struct Analysis {
    let responseClass: String
    let setCookie: Bool
    let login: Bool
    let js: Bool
    let found: Bool
    let successMarkersSeen: [String]
}

private struct StepRecord {
    let stepId: String
    let changedVar: String
    let policy: [String: Bool]
    let httpStatus: Int?
    let contentType: String?
    let finalURL: String
    let responseClass: String
    let setCookie: Bool
    let login: Bool
    let js: Bool
    let found: Bool
    let candidateFailureType: String
    let secondaryReason: String
    let decision: String
    let notes: String
}

private struct DecisionSummary {
    let finalFT: String
    let finalSR: String
    let winningStep: String?
    let actualLevel: String
    let accessTier: String
    let matrixUpdate: Bool
    let notes: String
}

private func ys(_ s: String) -> String {
    let e = s.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(e)\""
}
private func yb(_ b: Bool) -> String { b ? "true" : "false" }
private func yn(_ n: Int?) -> String { n.map { "\($0)" } ?? "null" }
private func ynStr(_ s: String?) -> String { s.map { ys($0) } ?? "null" }

private func stringValue(_ value: JSONValue?) -> String? {
    guard case .string(let s)? = value else { return nil }
    return s
}

private func stringArrayValue(_ value: JSONValue?) -> [String]? {
    guard case .array(let values)? = value else { return nil }
    return values.compactMap {
        guard case .string(let s) = $0 else { return nil }
        return s
    }
}

private func boolValue(_ value: JSONValue?) -> Bool? {
    guard case .bool(let b)? = value else { return nil }
    return b
}

private func loadLoginFlow(from source: BookSource) -> LoginFlowConfig? {
    guard case .object(let object)? = source.unknownFields["xReaderLoginFlow"],
          boolValue(object["enabled"]) == true,
          let method = stringValue(object["method"]),
          let contentType = stringValue(object["contentType"]),
          let actionURL = stringValue(object["actionUrl"]),
          let usernameField = stringValue(object["usernameField"]),
          let passwordField = stringValue(object["passwordField"]),
          let usernameValue = stringValue(object["usernameValue"]),
          let passwordValue = stringValue(object["passwordValue"]),
          let successURL = stringValue(object["successUrl"]),
          let successMarkers = stringArrayValue(object["successMarkers"])
    else {
        return nil
    }

    return LoginFlowConfig(
        method: method,
        contentType: contentType,
        actionURL: actionURL,
        usernameField: usernameField,
        passwordField: passwordField,
        usernameValue: usernameValue,
        passwordValue: passwordValue,
        successURL: successURL,
        successMarkers: successMarkers
    )
}

private func responseClass(for statusCode: Int?) -> String {
    guard let statusCode else { return "network_error" }
    switch statusCode {
    case 200...299: return "success_2xx"
    case 300...399: return "redirect_3xx"
    case 400...499: return "client_error_4xx"
    case 500...599: return "server_error_5xx"
    default: return "other_\(statusCode)"
    }
}

private func analyze(_ response: HTTPResponse, loginFlow: LoginFlowConfig) -> Analysis {
    let body = String(data: response.data, encoding: .utf8) ??
        String(data: response.data, encoding: .isoLatin1) ?? ""
    let lowercasedBody = body.lowercased()
    let successMarkersSeen = loginFlow.successMarkers.filter { body.contains($0) }
    let login = lowercasedBody.contains("username") ||
        lowercasedBody.contains("password") ||
        lowercasedBody.contains("test login") ||
        lowercasedBody.contains("login")
    let js = lowercasedBody.contains("cf-browser-verification") ||
        lowercasedBody.contains("challenge-platform") ||
        lowercasedBody.contains("please enable javascript") ||
        lowercasedBody.contains("cloudflare")
    let found = response.statusCode == 200 &&
        loginFlow.successMarkers.allSatisfy { body.contains($0) }
    let setCookie = response.headers.keys.contains { $0.lowercased() == "set-cookie" }

    return Analysis(
        responseClass: responseClass(for: response.statusCode),
        setCookie: setCookie,
        login: login,
        js: js,
        found: found,
        successMarkersSeen: successMarkersSeen
    )
}

private func policyYAML(_ policy: [String: Bool]) -> [String] {
    let keys = ["user_agent", "referer", "cookie_jar", "retry", "redirect_handling", "login"]
    return ["    requestPolicy:"] + keys.map { "      \($0): \(yb(policy[$0] ?? false))" }
}

private func appendRecord(_ record: StepRecord, to lines: inout [String]) {
    lines.append("  - stepId: \(ys(record.stepId))")
    lines.append("    changedVariable: \(ys(record.changedVar))")
    lines += policyYAML(record.policy)
    lines.append("    httpStatus: \(yn(record.httpStatus))")
    lines.append("    contentType: \(ynStr(record.contentType))")
    lines.append("    finalUrl: \(ys(record.finalURL))")
    lines.append("    responseClass: \(ys(record.responseClass))")
    lines.append("    setCookieObserved: \(yb(record.setCookie))")
    lines.append("    loginMarkerObserved: \(yb(record.login))")
    lines.append("    jsChallengeObserved: \(yb(record.js))")
    lines.append("    searchResultMarkerObserved: \(yb(record.found))")
    lines.append("    candidateFailureType: \(ys(record.candidateFailureType))")
    lines.append("    secondaryReason: \(ys(record.secondaryReason))")
    lines.append("    decision: \(ys(record.decision))")
    lines.append("    notes: \(ys(record.notes))")
}

private func makeRecord(
    stepId: String,
    changedVar: String,
    policy: [String: Bool],
    response: HTTPResponse?,
    finalURL: String,
    loginFlow: LoginFlowConfig
) -> StepRecord {
    let analysis = response.map { analyze($0, loginFlow: loginFlow) } ??
        Analysis(responseClass: "network_error", setCookie: false, login: false, js: false, found: false, successMarkersSeen: [])

    let candidateFailureType: String
    let secondaryReason: String
    switch stepId {
    case "TEST-001":
        candidateFailureType = "NETWORK_POLICY_MISMATCH"
        secondaryReason = analysis.found ? "missing_header" : "baseline_controlled_fetch_failed"
    case "TEST-002":
        candidateFailureType = "NETWORK_POLICY_MISMATCH"
        secondaryReason = analysis.found ? "missing_referer" : "baseline_controlled_fetch_failed"
    case "TEST-003":
        candidateFailureType = analysis.found ? "COOKIE_REQUIRED" : "NETWORK_POLICY_MISMATCH"
        secondaryReason = analysis.found ? "missing_required_cookie" : "baseline_controlled_fetch_failed"
    case "TEST-004":
        candidateFailureType = "NETWORK_POLICY_MISMATCH"
        secondaryReason = analysis.found ? "undetermined_after_isolation" : "baseline_controlled_fetch_failed"
    case "TEST-005":
        candidateFailureType = "NETWORK_POLICY_MISMATCH"
        secondaryReason = analysis.found ? "redirect_not_handled" : "baseline_controlled_fetch_failed"
    case "TEST-006":
        candidateFailureType = analysis.found ? "LOGIN_REQUIRED" : "NETWORK_POLICY_MISMATCH"
        secondaryReason = analysis.found
            ? (analysis.login ? "auth_redirect_detected" : "login_state_absent")
            : "baseline_controlled_fetch_failed"
    case "TEST-007":
        candidateFailureType = "NETWORK_POLICY_MISMATCH"
        secondaryReason = analysis.js ? "js_challenge_observed" : "baseline_controlled_fetch_failed"
    default:
        candidateFailureType = "NETWORK_POLICY_MISMATCH"
        secondaryReason = "baseline_controlled_fetch_failed"
    }

    let decision: String
    if analysis.found {
        decision = "match_found:\(candidateFailureType)"
    } else if stepId == "TEST-007" {
        decision = "stop_undetermined"
    } else {
        decision = "continue_isolation"
    }

    let notes: String
    if analysis.found {
        notes = "Success markers seen: \(analysis.successMarkersSeen.joined(separator: ", "))"
    } else if analysis.login {
        notes = "Login markers observed instead of secure markers."
    } else if analysis.js {
        notes = "JS challenge markers observed."
    } else if response == nil {
        notes = "Network request failed before HTTP response."
    } else {
        notes = "Secure markers absent."
    }

    return StepRecord(
        stepId: stepId,
        changedVar: changedVar,
        policy: policy,
        httpStatus: response?.statusCode,
        contentType: response?.headers["Content-Type"] ?? response?.headers["content-type"],
        finalURL: finalURL,
        responseClass: analysis.responseClass,
        setCookie: analysis.setCookie,
        login: analysis.login,
        js: analysis.js,
        found: analysis.found,
        candidateFailureType: candidateFailureType,
        secondaryReason: secondaryReason,
        decision: decision,
        notes: notes
    )
}

private func applyDecisionRules(_ records: [StepRecord]) -> DecisionSummary {
    let winners = records.filter { $0.found }
    if winners.isEmpty {
        let jsObserved = records.contains { $0.js }
        return DecisionSummary(
            finalFT: "NETWORK_POLICY_MISMATCH",
            finalSR: jsObserved ? "js_challenge_observed" : "undetermined_after_isolation",
            winningStep: nil,
            actualLevel: "D",
            accessTier: jsObserved ? "C" : "B3",
            matrixUpdate: true,
            notes: jsObserved
                ? "All isolation steps failed and JS challenge markers were observed."
                : "All isolation steps failed without secure-page success markers."
        )
    }

    if winners.count > 1 {
        return DecisionSummary(
            finalFT: "NETWORK_POLICY_MISMATCH",
            finalSR: "undetermined_after_isolation",
            winningStep: winners.first?.stepId,
            actualLevel: "D",
            accessTier: "B3",
            matrixUpdate: false,
            notes: "Multiple isolation steps reached success markers: \(winners.map(\.stepId).joined(separator: ", "))."
        )
    }

    let winner = winners[0]
    switch winner.stepId {
    case "TEST-001":
        return DecisionSummary(finalFT: "NETWORK_POLICY_MISMATCH", finalSR: "missing_header", winningStep: winner.stepId, actualLevel: "B", accessTier: "B1", matrixUpdate: true, notes: "User-Agent alone unlocked the secure page.")
    case "TEST-002":
        return DecisionSummary(finalFT: "NETWORK_POLICY_MISMATCH", finalSR: "missing_referer", winningStep: winner.stepId, actualLevel: "B", accessTier: "B1", matrixUpdate: true, notes: "Referer alone unlocked the secure page.")
    case "TEST-003":
        return DecisionSummary(finalFT: "COOKIE_REQUIRED", finalSR: "missing_required_cookie", winningStep: winner.stepId, actualLevel: "B", accessTier: "B2", matrixUpdate: true, notes: "Cookie jar alone unlocked the secure page.")
    case "TEST-004":
        return DecisionSummary(finalFT: "NETWORK_POLICY_MISMATCH", finalSR: "undetermined_after_isolation", winningStep: winner.stepId, actualLevel: "D", accessTier: "B3", matrixUpdate: false, notes: "Retry changed the outcome, so login gating is unconfirmed.")
    case "TEST-005":
        return DecisionSummary(finalFT: "NETWORK_POLICY_MISMATCH", finalSR: "redirect_not_handled", winningStep: winner.stepId, actualLevel: "B", accessTier: "B2", matrixUpdate: true, notes: "Redirect behavior, not login state, changed the result.")
    case "TEST-006":
        return DecisionSummary(finalFT: "LOGIN_REQUIRED", finalSR: winner.login ? "auth_redirect_detected" : "login_state_absent", winningStep: winner.stepId, actualLevel: "A", accessTier: "B3", matrixUpdate: true, notes: "Only the real form-login step reached the secure-page success markers.")
    case "TEST-007":
        return DecisionSummary(finalFT: "NETWORK_POLICY_MISMATCH", finalSR: "js_challenge_observed", winningStep: winner.stepId, actualLevel: "D", accessTier: "C", matrixUpdate: true, notes: "JS challenge markers dominate the outcome.")
    default:
        return DecisionSummary(finalFT: "NETWORK_POLICY_MISMATCH", finalSR: "undetermined_after_isolation", winningStep: nil, actualLevel: "D", accessTier: "B3", matrixUpdate: false, notes: "Unknown winning step.")
    }
}

private func formEncodedBody(flow: LoginFlowConfig) -> Data? {
    func encode(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? value
    }

    let payload = [
        "\(flow.usernameField)=\(encode(flow.usernameValue))",
        "\(flow.passwordField)=\(encode(flow.passwordValue))"
    ].joined(separator: "&")
    return payload.data(using: .utf8)
}

let positional = CommandLine.arguments.dropFirst().filter { $0 != "--" }
guard let repoRoot = positional.first else {
    fputs("Usage: SampleLogin002IsolationRunner -- <repo_root>\n", stderr)
    exit(1)
}

func rp(_ relativePath: String) -> String {
    URL(fileURLWithPath: repoRoot).appendingPathComponent(relativePath).path
}

let semaphore = DispatchSemaphore(value: 0)
var exitCode: Int32 = 0

Task {
    defer { semaphore.signal() }

    do {
        let source = try JSONDecoder().decode(
            BookSource.self,
            from: try Data(contentsOf: URL(fileURLWithPath: rp("samples/booksources/p1_login/sample_login_002.json")))
        )
        guard let loginFlow = loadLoginFlow(from: source) else {
            throw NSError(domain: "SampleLogin002IsolationRunner", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "xReaderLoginFlow missing or invalid"
            ])
        }

        let builder = BookSourceRequestBuilder()
        let builtSearchRequest = try builder.makeSearchRequest(source: source, query: SearchQuery(keyword: "secure", page: 1))
        let homeURL = source.bookSourceUrl ?? loginFlow.successURL
        let referer = source.header["Referer"] ?? source.loginUrl ?? homeURL
        let mobileUA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        func ephemeralClient(cookieJar: CookieJar? = nil) -> any HTTPAdapterProtocol {
            HTTPAdapterFactory.makeDefault(cookieJar: cookieJar)
        }

        func redirectClient(cookieJar: CookieJar? = nil) -> any HTTPAdapterProtocol {
            HTTPAdapterFactory.makeDefault(cookieJar: cookieJar, followRedirects: true)
        }

        func send(_ request: HTTPRequest, client: any HTTPAdapterProtocol) async -> HTTPResponse? {
            try? await client.send(request)
        }

        func secureRequest(headers: [String: String], useCookieJar: Bool) -> HTTPRequest {
            HTTPRequest(
                url: builtSearchRequest.url,
                method: builtSearchRequest.method,
                headers: headers,
                body: builtSearchRequest.body,
                timeout: 20,
                useCookieJar: useCookieJar
            )
        }

        func performLogin(client: any HTTPAdapterProtocol) async -> HTTPResponse? {
            let loginPageRequest = HTTPRequest(
                url: source.loginUrl ?? homeURL,
                method: "GET",
                headers: ["Referer": referer],
                body: nil,
                timeout: 20,
                useCookieJar: true
            )
            _ = await send(loginPageRequest, client: client)

            let loginRequest = HTTPRequest(
                url: loginFlow.actionURL,
                method: loginFlow.method,
                headers: [
                    "Content-Type": loginFlow.contentType,
                    "Referer": source.loginUrl ?? referer
                ],
                body: formEncodedBody(flow: loginFlow),
                timeout: 20,
                useCookieJar: true
            )
            _ = await send(loginRequest, client: client)

            let securePageRequest = HTTPRequest(
                url: loginFlow.successURL,
                method: "GET",
                headers: ["Referer": source.loginUrl ?? referer],
                body: nil,
                timeout: 20,
                useCookieJar: true
            )
            return await send(securePageRequest, client: client)
        }

        var records: [StepRecord] = []
        let generatedAt = ISO8601DateFormatter().string(from: Date())
        let reportPrefix = "isolation_login_002_\(Int(Date().timeIntervalSince1970))"

        let baselineResponse = await send(secureRequest(headers: [:], useCookieJar: false), client: ephemeralClient())
        records.append(makeRecord(stepId: "BASELINE-000", changedVar: "none", policy: ["user_agent": false, "referer": false, "cookie_jar": false, "retry": false, "redirect_handling": false, "login": false], response: baselineResponse, finalURL: builtSearchRequest.url, loginFlow: loginFlow))

        let userAgentResponse = await send(secureRequest(headers: ["User-Agent": mobileUA], useCookieJar: false), client: ephemeralClient())
        records.append(makeRecord(stepId: "TEST-001", changedVar: "header.user_agent", policy: ["user_agent": true, "referer": false, "cookie_jar": false, "retry": false, "redirect_handling": false, "login": false], response: userAgentResponse, finalURL: builtSearchRequest.url, loginFlow: loginFlow))

        let refererResponse = await send(secureRequest(headers: ["Referer": referer], useCookieJar: false), client: ephemeralClient())
        records.append(makeRecord(stepId: "TEST-002", changedVar: "header.referer", policy: ["user_agent": false, "referer": true, "cookie_jar": false, "retry": false, "redirect_handling": false, "login": false], response: refererResponse, finalURL: builtSearchRequest.url, loginFlow: loginFlow))

        let cookieJar = BasicCookieJar()
        let cookieClient = ephemeralClient(cookieJar: cookieJar)
        _ = await send(HTTPRequest(url: homeURL, method: "GET", headers: [:], body: nil, timeout: 20, useCookieJar: true), client: cookieClient)
        let cookieResponse = await send(secureRequest(headers: [:], useCookieJar: true), client: cookieClient)
        records.append(makeRecord(stepId: "TEST-003", changedVar: "cookie_jar", policy: ["user_agent": false, "referer": false, "cookie_jar": true, "retry": false, "redirect_handling": false, "login": false], response: cookieResponse, finalURL: builtSearchRequest.url, loginFlow: loginFlow))

        let retryClient = ephemeralClient()
        var retryResponse: HTTPResponse?
        for _ in 0..<3 {
            retryResponse = await send(secureRequest(headers: [:], useCookieJar: false), client: retryClient)
            if let retryResponse, analyze(retryResponse, loginFlow: loginFlow).found {
                break
            }
        }
        records.append(makeRecord(stepId: "TEST-004", changedVar: "retry", policy: ["user_agent": false, "referer": false, "cookie_jar": false, "retry": true, "redirect_handling": false, "login": false], response: retryResponse, finalURL: builtSearchRequest.url, loginFlow: loginFlow))

        let redirectResponse = await send(secureRequest(headers: [:], useCookieJar: false), client: redirectClient())
        records.append(makeRecord(stepId: "TEST-005", changedVar: "redirect_handling", policy: ["user_agent": false, "referer": false, "cookie_jar": false, "retry": false, "redirect_handling": true, "login": false], response: redirectResponse, finalURL: builtSearchRequest.url, loginFlow: loginFlow))

        let loginClient = redirectClient(cookieJar: BasicCookieJar())
        let loginResponse = await performLogin(client: loginClient)
        records.append(makeRecord(stepId: "TEST-006", changedVar: "login", policy: ["user_agent": false, "referer": false, "cookie_jar": false, "retry": false, "redirect_handling": false, "login": true], response: loginResponse, finalURL: loginFlow.successURL, loginFlow: loginFlow))

        let jsResponse = await send(secureRequest(headers: [:], useCookieJar: false), client: ephemeralClient())
        records.append(makeRecord(stepId: "TEST-007", changedVar: "js_mark_only", policy: ["user_agent": false, "referer": false, "cookie_jar": false, "retry": false, "redirect_handling": false, "login": false], response: jsResponse, finalURL: builtSearchRequest.url, loginFlow: loginFlow))

        let decision = applyDecisionRules(records)

        var stepLines: [String] = []
        stepLines.append("reportId: \(ys(reportPrefix + "_steps"))")
        stepLines.append("generatedAt: \(ys(generatedAt))")
        stepLines.append("phase: \"p1_login\"")
        stepLines.append("sampleId: \"sample_login_002\"")
        stepLines.append("")
        stepLines.append("records:")
        for record in records {
            appendRecord(record, to: &stepLines)
        }
        try (stepLines.joined(separator: "\n") + "\n").write(
            toFile: rp("samples/reports/latest/fetch_isolation_step_records_sample_login_002.yml"),
            atomically: true,
            encoding: .utf8
        )

        var summaryLines: [String] = []
        summaryLines.append("reportId: \(ys(reportPrefix + "_summary"))")
        summaryLines.append("generatedAt: \(ys(generatedAt))")
        summaryLines.append("phase: \"p1_login\"")
        summaryLines.append("sampleId: \"sample_login_002\"")
        summaryLines.append("")
        summaryLines.append("decision:")
        summaryLines.append("  baselineFailureType: \"NETWORK_POLICY_MISMATCH\"")
        summaryLines.append("  finalPrimaryFailureType: \(ys(decision.finalFT))")
        summaryLines.append("  finalSecondaryReason: \(ys(decision.finalSR))")
        summaryLines.append("  winningStep: \(decision.winningStep.map { ys($0) } ?? "null")")
        summaryLines.append("  actualLevel: \(ys(decision.actualLevel))")
        summaryLines.append("  accessTier: \(ys(decision.accessTier))")
        summaryLines.append("  matrixUpdate:")
        summaryLines.append("    update: \(yb(decision.matrixUpdate))")
        summaryLines.append("    failureType: \(ys(decision.finalFT))")
        summaryLines.append("    secondaryReason: \(ys(decision.finalSR))")
        summaryLines.append("  notes: \(ys(decision.notes))")
        try (summaryLines.joined(separator: "\n") + "\n").write(
            toFile: rp("samples/reports/latest/fetch_isolation_decision_summary_sample_login_002.yml"),
            atomically: true,
            encoding: .utf8
        )

        print("step_records: \(rp("samples/reports/latest/fetch_isolation_step_records_sample_login_002.yml"))")
        print("decision_summary: \(rp("samples/reports/latest/fetch_isolation_decision_summary_sample_login_002.yml"))")
        print("winningStep: \(decision.winningStep ?? "null")")
        print("finalPrimaryFailureType: \(decision.finalFT)")
        print("finalSecondaryReason: \(decision.finalSR)")
        print("actualLevel: \(decision.actualLevel)")
        print("accessTier: \(decision.accessTier)")
    } catch {
        fputs("Fatal: \(error)\n", stderr)
        exitCode = 1
    }
}

semaphore.wait()
exit(exitCode)
