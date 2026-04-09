// SampleCookie001IsolationRunner/main.swift
// Minimum-variable isolation for sample_cookie_001
// Usage: swift run --package-path Core SampleCookie001IsolationRunner -- <repo_root>

import Foundation
import ReaderCoreModels
import ReaderCoreNetwork
import ReaderCoreProtocols
import ReaderPlatformAdapters

// MARK: - YAML helpers
private func ys(_ s: String) -> String {
    let e = s.replacingOccurrences(of: "\\", with: "\\\\")
               .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(e)\""
}
private func yb(_ b: Bool) -> String { b ? "true" : "false" }
private func yn(_ n: Int?) -> String { n.map { "\($0)" } ?? "null" }
private func ynStr(_ s: String?) -> String { s.map { ys($0) } ?? "null" }

// MARK: - Analysis
private struct Analysis {
    let responseClass: String
    let setCookie: Bool
    let login: Bool
    let js: Bool
    let found: Bool
}
private func analyze(_ resp: HTTPResponse, ruleSearch: String) -> Analysis {
    let cls: String
    switch resp.statusCode {
    case 200...299: cls = "success_2xx"
    case 300...399: cls = "redirect_3xx"
    case 400...499: cls = "client_error_4xx"
    case 500...599: cls = "server_error_5xx"
    default:        cls = "other_\(resp.statusCode)"
    }
    let setCookie = resp.headers.keys.contains { $0.lowercased() == "set-cookie" }
    let body = String(data: resp.data, encoding: .utf8)
            ?? String(data: resp.data, encoding: .isoLatin1) ?? ""
    let lb = body.lowercased()
    let login = lb.contains("请登录") || lb.contains("login.php") ||
                lb.contains("用户名") || lb.contains("请输入密码") ||
                lb.contains("sign in")
    let js    = lb.contains("cf-browser-verification") ||
                lb.contains("challenge-platform") ||
                lb.contains("please enable javascript") ||
                lb.contains("请开启javascript") ||
                (lb.contains("cloudflare") && lb.contains("checking"))
    let hint: String
    if ruleSearch.hasPrefix("css:.") {
        hint = String(ruleSearch.dropFirst(5)).components(separatedBy: " ").first ?? ""
    } else { hint = "" }
    let found: Bool
    if resp.statusCode == 200 && !login && !js {
        found = hint.isEmpty
            ? body.count > 3000
            : (body.contains("class=\"\(hint)\"") || body.contains("class='\(hint)'"))
    } else { found = false }
    return Analysis(responseClass: cls, setCookie: setCookie, login: login, js: js, found: found)
}

// MARK: - Step record
private struct StepRecord {
    let stepId: String
    let changedVar: String
    let policy: [String: Bool]   // user_agent/referer/cookie_jar/retry/redirect_handling/login
    let httpStatus: Int?
    let contentType: String?
    let finalUrl: String
    let responseClass: String
    let setCookie: Bool
    let login: Bool
    let js: Bool
    let found: Bool
    let candidateFailureType: String
    let secondaryReason: String
    let decision: String
}

private func makeRecord(
    stepId: String, changedVar: String, policy: [String: Bool],
    analysis: Analysis, url: String, ct: String?,
    httpStatus: Int?, setCookieHeader: Bool
) -> StepRecord {
    // Candidate failure type and secondary reason per step
    let cft: String
    let sr: String
    switch stepId {
    case "TEST-001":
        cft = "NETWORK_POLICY_MISMATCH"
        sr  = analysis.found ? "missing_header" : "baseline_controlled_fetch_failed"
    case "TEST-002":
        cft = "NETWORK_POLICY_MISMATCH"
        sr  = analysis.found ? "missing_referer" : "baseline_controlled_fetch_failed"
    case "TEST-003":
        cft = analysis.found ? "COOKIE_REQUIRED" : "NETWORK_POLICY_MISMATCH"
        sr  = analysis.found ? (setCookieHeader ? "missing_required_cookie" : "cookie_expired")
                             : "baseline_controlled_fetch_failed"
    case "TEST-004":
        cft = "NETWORK_POLICY_MISMATCH"
        sr  = analysis.found ? "undetermined_after_isolation" : "baseline_controlled_fetch_failed"
    case "TEST-005":
        cft = "NETWORK_POLICY_MISMATCH"
        sr  = analysis.found ? "redirect_not_handled" : "baseline_controlled_fetch_failed"
    case "TEST-006":
        cft = analysis.found ? "LOGIN_REQUIRED" : "NETWORK_POLICY_MISMATCH"
        sr  = analysis.found ? (analysis.login ? "auth_redirect_detected" : "login_state_absent")
                             : "baseline_controlled_fetch_failed"
    case "TEST-007":
        cft = "NETWORK_POLICY_MISMATCH"
        sr  = analysis.js ? "js_challenge_observed" : "baseline_controlled_fetch_failed"
    default: // BASELINE-000
        cft = "NETWORK_POLICY_MISMATCH"
        sr  = "baseline_controlled_fetch_failed"
    }
    let decision: String
    if analysis.found {
        decision = "match_found:\(cft)"
    } else if stepId == "TEST-007" {
        decision = "stop_undetermined"
    } else {
        decision = "continue_isolation"
    }
    return StepRecord(
        stepId: stepId, changedVar: changedVar, policy: policy,
        httpStatus: httpStatus, contentType: ct,
        finalUrl: url, responseClass: analysis.responseClass,
        setCookie: analysis.setCookie, login: analysis.login,
        js: analysis.js, found: analysis.found,
        candidateFailureType: cft, secondaryReason: sr, decision: decision
    )
}

private func policyYAML(_ p: [String: Bool]) -> [String] {
    let keys = ["user_agent","referer","cookie_jar","retry","redirect_handling","login"]
    return ["    requestPolicy:"] + keys.map { "      \($0): \(yb(p[$0] ?? false))" }
}

private func appendRecord(_ r: StepRecord, to out: inout [String]) {
    out.append("  - stepId: \(ys(r.stepId))")
    out.append("    changedVariable: \(ys(r.changedVar))")
    out += policyYAML(r.policy)
    out.append("    httpStatus: \(yn(r.httpStatus))")
    out.append("    contentType: \(ynStr(r.contentType))")
    out.append("    finalUrl: \(ys(r.finalUrl))")
    out.append("    responseClass: \(ys(r.responseClass))")
    out.append("    setCookieObserved: \(yb(r.setCookie))")
    out.append("    loginMarkerObserved: \(yb(r.login))")
    out.append("    jsChallengeObserved: \(yb(r.js))")
    out.append("    searchResultMarkerObserved: \(yb(r.found))")
    out.append("    candidateFailureType: \(ys(r.candidateFailureType))")
    out.append("    secondaryReason: \(ys(r.secondaryReason))")
    out.append("    decision: \(ys(r.decision))")
}

// MARK: - Decision rules
private struct DecisionSummary {
    let finalFT: String; let finalSR: String
    let winningStep: String?; let actualLevel: String
    let matrixUpdate: Bool; let notes: String
}
private func applyDecisionRules(_ records: [StepRecord]) -> DecisionSummary {
    let winners = records.filter { $0.found }
    if winners.isEmpty {
        // rule 10: all failed
        let jsObs = records.first { $0.js } != nil
        return DecisionSummary(
            finalFT: "NETWORK_POLICY_MISMATCH",
            finalSR: jsObs ? "js_challenge_observed" : "undetermined_after_isolation",
            winningStep: nil, actualLevel: "D",
            matrixUpdate: true,
            notes: jsObs
                ? "JS challenge observed across steps; no step resolved access"
                : "All isolation steps failed; root cause undetermined"
        )
    }
    if winners.count > 1 {
        // rule 9: conflicting
        return DecisionSummary(
            finalFT: "NETWORK_POLICY_MISMATCH", finalSR: "conflicting_signals",
            winningStep: winners.first!.stepId, actualLevel: "D",
            matrixUpdate: false,
            notes: "Multiple isolation steps succeeded: \(winners.map{$0.stepId}.joined(separator:", "))"
        )
    }
    let w = winners[0]
    switch w.stepId {
    case "TEST-001":
        return DecisionSummary(finalFT:"NETWORK_POLICY_MISMATCH", finalSR:"missing_header",
            winningStep:w.stepId, actualLevel:"B", matrixUpdate:true,
            notes:"User-Agent header resolved access")
    case "TEST-002":
        return DecisionSummary(finalFT:"NETWORK_POLICY_MISMATCH", finalSR:"missing_referer",
            winningStep:w.stepId, actualLevel:"B", matrixUpdate:true,
            notes:"Referer header resolved access")
    case "TEST-003":
        let sr = w.setCookie ? "missing_required_cookie" : "cookie_expired"
        return DecisionSummary(finalFT:"COOKIE_REQUIRED", finalSR:sr,
            winningStep:w.stepId, actualLevel:"C", matrixUpdate:true,
            notes:"Cookie jar resolved access; \(sr)")
    case "TEST-004":
        return DecisionSummary(finalFT:"NETWORK_POLICY_MISMATCH", finalSR:"undetermined_after_isolation",
            winningStep:w.stepId, actualLevel:"D", matrixUpdate:false,
            notes:"Retry resolved access; root cause undetermined (transient)")
    case "TEST-005":
        return DecisionSummary(finalFT:"NETWORK_POLICY_MISMATCH", finalSR:"redirect_not_handled",
            winningStep:w.stepId, actualLevel:"B", matrixUpdate:true,
            notes:"Redirect handling resolved access")
    case "TEST-006":
        let sr = w.login ? "auth_redirect_detected" : "login_state_absent"
        return DecisionSummary(finalFT:"LOGIN_REQUIRED", finalSR:sr,
            winningStep:w.stepId, actualLevel:"C", matrixUpdate:true,
            notes:"Login step resolved access; \(sr)")
    case "TEST-007":
        return DecisionSummary(finalFT:"NETWORK_POLICY_MISMATCH", finalSR:"js_challenge_observed",
            winningStep:w.stepId, actualLevel:"D", matrixUpdate:true,
            notes:"JS challenge observed; no JS execution performed")
    default:
        return DecisionSummary(finalFT:"NETWORK_POLICY_MISMATCH", finalSR:"undetermined_after_isolation",
            winningStep:nil, actualLevel:"D", matrixUpdate:false, notes:"Unknown winning step")
    }
}

// MARK: - Main
let positional = CommandLine.arguments.dropFirst().filter { $0 != "--" }
guard let repoRoot = positional.first else {
    fputs("Usage: SampleCookie001IsolationRunner -- <repo_root>\n", stderr)
    exit(1)
}
func rp(_ r: String) -> String {
    URL(fileURLWithPath: repoRoot).appendingPathComponent(r).path
}

let sem = DispatchSemaphore(value: 0)
var exitCode: Int32 = 0

Task {
    defer { sem.signal() }
    do {
        let bs = try JSONDecoder().decode(
            BookSource.self,
            from: try Data(contentsOf: URL(fileURLWithPath:
                rp("samples/booksources/p1_cookie/sample_cookie_001.json")))
        )
        let searchURL = (bs.searchUrl ?? "")
            .replacingOccurrences(of: "{{key}}", with: "test")
            .replacingOccurrences(of: "{{keyword}}", with: "test")
            .replacingOccurrences(of: "{{page}}", with: "1")
        let homeURL   = bs.bookSourceUrl ?? "https://www.wenku8.net"
        let loginURL  = bs.loginUrl ?? ""
        let ruleSearch = bs.ruleSearch ?? ""
        let mobileUA  = "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1"
        let referer   = bs.header["Referer"] ?? homeURL

        func ephemeralClient(cookieJar: CookieJar? = nil) -> any HTTPAdapterProtocol {
            HTTPAdapterFactory.makeDefault(cookieJar: cookieJar)
        }

        var records: [StepRecord] = []
        let now   = ISO8601DateFormatter().string(from: Date())
        let runId = "isolation_cookie_001_\(Int(Date().timeIntervalSince1970))"

        // ── Helper: send one request, return (response?, error?)
        func send(_ url: String, headers: [String: String] = [:],
                  client: any HTTPAdapterProtocol, useJar: Bool = false) async -> HTTPResponse? {
            let req = HTTPRequest(url: url, method: "GET", headers: headers,
                                  body: nil, timeout: 20, useCookieJar: useJar)
            return try? await client.send(req)
        }

        // ── BASELINE-000 ──────────────────────────────────────────────────
        let bl: any HTTPAdapterProtocol = ephemeralClient()
        let blResp = await send(searchURL, client: bl)
        let blA = blResp.map { analyze($0, ruleSearch: ruleSearch) }
            ?? Analysis(responseClass:"network_error", setCookie:false, login:false, js:false, found:false)
        let blSet = blResp.flatMap { r in r.headers.keys.contains { $0.lowercased() == "set-cookie" } ? true : Optional(false) } ?? false
        records.append(makeRecord(
            stepId:"BASELINE-000", changedVar:"none",
            policy:["user_agent":false,"referer":false,"cookie_jar":false,"retry":false,"redirect_handling":false,"login":false],
            analysis:blA, url:searchURL, ct:blResp?.headers["Content-Type"] ?? blResp?.headers["content-type"],
            httpStatus:blResp?.statusCode, setCookieHeader:blSet
        ))

        // ── TEST-001: user_agent ──────────────────────────────────────────
        let c1 = ephemeralClient()
        let r1 = await send(searchURL, headers:["User-Agent":mobileUA], client:c1)
        let a1 = r1.map { analyze($0, ruleSearch:ruleSearch) }
            ?? Analysis(responseClass:"network_error", setCookie:false, login:false, js:false, found:false)
        let s1 = r1.flatMap { $0.headers.keys.contains { $0.lowercased()=="set-cookie" } ? true : Optional(false) } ?? false
        records.append(makeRecord(
            stepId:"TEST-001", changedVar:"header.user_agent",
            policy:["user_agent":true,"referer":false,"cookie_jar":false,"retry":false,"redirect_handling":false,"login":false],
            analysis:a1, url:searchURL, ct:r1?.headers["Content-Type"] ?? r1?.headers["content-type"],
            httpStatus:r1?.statusCode, setCookieHeader:s1
        ))

        // ── TEST-002: referer ─────────────────────────────────────────────
        let c2 = ephemeralClient()
        let r2 = await send(searchURL, headers:["Referer":referer], client:c2)
        let a2 = r2.map { analyze($0, ruleSearch:ruleSearch) }
            ?? Analysis(responseClass:"network_error", setCookie:false, login:false, js:false, found:false)
        let s2 = r2.flatMap { $0.headers.keys.contains { $0.lowercased()=="set-cookie" } ? true : Optional(false) } ?? false
        records.append(makeRecord(
            stepId:"TEST-002", changedVar:"header.referer",
            policy:["user_agent":false,"referer":true,"cookie_jar":false,"retry":false,"redirect_handling":false,"login":false],
            analysis:a2, url:searchURL, ct:r2?.headers["Content-Type"] ?? r2?.headers["content-type"],
            httpStatus:r2?.statusCode, setCookieHeader:s2
        ))

        // ── TEST-003: cookie_jar (homepage pre-fetch) ─────────────────────
        let jar3 = BasicCookieJar()
        let c3   = ephemeralClient(cookieJar: jar3)
        _ = await send(homeURL, client:c3, useJar:true)     // collect cookies
        let r3 = await send(searchURL, client:c3, useJar:true)
        let a3 = r3.map { analyze($0, ruleSearch:ruleSearch) }
            ?? Analysis(responseClass:"network_error", setCookie:false, login:false, js:false, found:false)
        let s3 = r3.flatMap { $0.headers.keys.contains { $0.lowercased()=="set-cookie" } ? true : Optional(false) } ?? false
        records.append(makeRecord(
            stepId:"TEST-003", changedVar:"cookie_jar",
            policy:["user_agent":false,"referer":false,"cookie_jar":true,"retry":false,"redirect_handling":false,"login":false],
            analysis:a3, url:searchURL, ct:r3?.headers["Content-Type"] ?? r3?.headers["content-type"],
            httpStatus:r3?.statusCode, setCookieHeader:s3
        ))

        // ── TEST-004: retry (up to 3 attempts, baseline policy) ───────────
        let c4 = ephemeralClient()
        var r4: HTTPResponse? = nil
        for _ in 0..<3 {
            r4 = await send(searchURL, client:c4)
            if let resp = r4, analyze(resp, ruleSearch:ruleSearch).found { break }
        }
        let a4 = r4.map { analyze($0, ruleSearch:ruleSearch) }
            ?? Analysis(responseClass:"network_error", setCookie:false, login:false, js:false, found:false)
        let s4 = r4.flatMap { $0.headers.keys.contains { $0.lowercased()=="set-cookie" } ? true : Optional(false) } ?? false
        records.append(makeRecord(
            stepId:"TEST-004", changedVar:"retry",
            policy:["user_agent":false,"referer":false,"cookie_jar":false,"retry":true,"redirect_handling":false,"login":false],
            analysis:a4, url:searchURL, ct:r4?.headers["Content-Type"] ?? r4?.headers["content-type"],
            httpStatus:r4?.statusCode, setCookieHeader:s4
        ))

        // ── TEST-005: redirect_handling (default session config) ──────────
        let c5 = HTTPAdapterFactory.makeDefault(followRedirects: true)
        let r5 = await send(searchURL, client:c5)
        let a5 = r5.map { analyze($0, ruleSearch:ruleSearch) }
            ?? Analysis(responseClass:"network_error", setCookie:false, login:false, js:false, found:false)
        let s5 = r5.flatMap { $0.headers.keys.contains { $0.lowercased()=="set-cookie" } ? true : Optional(false) } ?? false
        records.append(makeRecord(
            stepId:"TEST-005", changedVar:"redirect_handling",
            policy:["user_agent":false,"referer":false,"cookie_jar":false,"retry":false,"redirect_handling":true,"login":false],
            analysis:a5, url:searchURL, ct:r5?.headers["Content-Type"] ?? r5?.headers["content-type"],
            httpStatus:r5?.statusCode, setCookieHeader:s5
        ))

        // ── TEST-006: login (GET loginUrl, extract cookies, then search) ──
        var r6: HTTPResponse? = nil
        var a6 = Analysis(responseClass:"network_error", setCookie:false, login:false, js:false, found:false)
        var s6 = false
        if !loginURL.isEmpty {
            let jar6 = BasicCookieJar()
            let c6   = ephemeralClient(cookieJar: jar6)
            _ = await send(loginURL, client:c6, useJar:true)   // get login page cookies
            r6 = await send(searchURL, client:c6, useJar:true)
            a6 = r6.map { analyze($0, ruleSearch:ruleSearch) }
                ?? Analysis(responseClass:"network_error", setCookie:false, login:false, js:false, found:false)
            s6 = r6.flatMap { $0.headers.keys.contains { $0.lowercased()=="set-cookie" } ? true : Optional(false) } ?? false
        }
        records.append(makeRecord(
            stepId:"TEST-006", changedVar:"login",
            policy:["user_agent":false,"referer":false,"cookie_jar":false,"retry":false,"redirect_handling":false,"login":true],
            analysis:a6, url:searchURL, ct:r6?.headers["Content-Type"] ?? r6?.headers["content-type"],
            httpStatus:r6?.statusCode, setCookieHeader:s6
        ))

        // ── TEST-007: js_mark_only (same as baseline, observe JS signals) ─
        let c7 = ephemeralClient()
        let r7 = await send(searchURL, client:c7)
        let a7 = r7.map { analyze($0, ruleSearch:ruleSearch) }
            ?? Analysis(responseClass:"network_error", setCookie:false, login:false, js:false, found:false)
        let s7 = r7.flatMap { $0.headers.keys.contains { $0.lowercased()=="set-cookie" } ? true : Optional(false) } ?? false
        records.append(makeRecord(
            stepId:"TEST-007", changedVar:"js_mark_only",
            policy:["user_agent":false,"referer":false,"cookie_jar":false,"retry":false,"redirect_handling":false,"login":false],
            analysis:a7, url:searchURL, ct:r7?.headers["Content-Type"] ?? r7?.headers["content-type"],
            httpStatus:r7?.statusCode, setCookieHeader:s7
        ))

        // ── Write step records ────────────────────────────────────────────
        var stepsOut: [String] = []
        stepsOut.append("reportId: \(ys(runId + "_steps"))")
        stepsOut.append("generatedAt: \(ys(now))")
        stepsOut.append("phase: \"p1_cookie\"")
        stepsOut.append("sampleId: \"sample_cookie_001\"")
        stepsOut.append("")
        stepsOut.append("records:")
        for r in records { appendRecord(r, to: &stepsOut) }
        let stepsYAML = stepsOut.joined(separator: "\n") + "\n"
        let stepsPath = rp("samples/reports/latest/fetch_isolation_step_records_sample_cookie_001.yml")
        try stepsYAML.write(toFile: stepsPath, atomically: true, encoding: .utf8)

        // ── Apply decision rules ──────────────────────────────────────────
        let ds = applyDecisionRules(records)

        // ── Write decision summary ────────────────────────────────────────
        var sumOut: [String] = []
        sumOut.append("reportId: \(ys(runId + "_summary"))")
        sumOut.append("generatedAt: \(ys(now))")
        sumOut.append("phase: \"p1_cookie\"")
        sumOut.append("sampleId: \"sample_cookie_001\"")
        sumOut.append("")
        sumOut.append("decision:")
        sumOut.append("  baselineFailureType: \"NETWORK_POLICY_MISMATCH\"")
        sumOut.append("  finalPrimaryFailureType: \(ys(ds.finalFT))")
        sumOut.append("  finalSecondaryReason: \(ys(ds.finalSR))")
        sumOut.append("  winningStep: \(ds.winningStep.map { ys($0) } ?? "null")")
        sumOut.append("  actualLevel: \(ys(ds.actualLevel))")
        sumOut.append("  matrixUpdate:")
        sumOut.append("    update: \(yb(ds.matrixUpdate))")
        sumOut.append("    failureType: \(ys(ds.finalFT))")
        sumOut.append("    secondaryReason: \(ys(ds.finalSR))")
        sumOut.append("  notes: \(ys(ds.notes))")
        let sumYAML = sumOut.joined(separator: "\n") + "\n"
        let sumPath = rp("samples/reports/latest/fetch_isolation_decision_summary_sample_cookie_001.yml")
        try sumYAML.write(toFile: sumPath, atomically: true, encoding: .utf8)

        print("step_records: \(stepsPath)")
        print("decision_summary: \(sumPath)")
        print("winningStep: \(ds.winningStep ?? "null")")
        print("finalPrimaryFailureType: \(ds.finalFT)")
        print("finalSecondaryReason: \(ds.finalSR)")
        print("actualLevel: \(ds.actualLevel)")
    } catch {
        fputs("Fatal: \(error)\n", stderr)
        exitCode = 1
    }
}
sem.wait()
exit(exitCode)
