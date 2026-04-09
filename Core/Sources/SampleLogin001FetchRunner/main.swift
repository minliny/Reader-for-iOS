// SampleLogin001FetchRunner/main.swift
// Baseline-only fetch for sample_login_001 (biquge.com.cn)
// Usage: swift run --package-path Core SampleLogin001FetchRunner -- <repo_root>

import Foundation
import ReaderCoreModels
import ReaderCoreNetwork
import ReaderCoreProtocols
import ReaderPlatformAdapters

private func ys(_ s: String) -> String {
    let e = s.replacingOccurrences(of: "\\", with: "\\\\")
               .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(e)\""
}
private func yb(_ b: Bool) -> String { b ? "true" : "false" }
private func yn(_ n: Int?) -> String { n.map { "\($0)" } ?? "null" }
private func ynStr(_ s: String?) -> String { s.map { ys($0) } ?? "null" }

private func analyzeBody(
    _ body: String, statusCode: Int, ruleSearch: String
) -> (login: Bool, js: Bool, found: Bool) {
    let lb = body.lowercased()
    let login = lb.contains("请登录") || lb.contains("login.php") ||
                lb.contains("用户名") || lb.contains("请输入密码") ||
                lb.contains("sign in") || lb.contains("用户登录") ||
                lb.contains("注册登录")
    let js    = lb.contains("cf-browser-verification") ||
                lb.contains("challenge-platform") ||
                lb.contains("please enable javascript") ||
                lb.contains("请开启javascript") ||
                (lb.contains("cloudflare") && lb.contains("checking"))
    let hint: String
    if ruleSearch.hasPrefix("css:.") {
        hint = String(ruleSearch.dropFirst(5)).components(separatedBy: " ").first ?? ""
    } else {
        hint = ""
    }
    let found: Bool
    if statusCode == 200 && !login && !js {
        found = hint.isEmpty
            ? body.count > 3000
            : (body.contains("class=\"\(hint)\"") || body.contains("class='\(hint)'"))
    } else {
        found = false
    }
    return (login, js, found)
}

// ── Main ──────────────────────────────────────────────────────────────────────

let positional = CommandLine.arguments.dropFirst().filter { $0 != "--" }
guard let repoRoot = positional.first else {
    fputs("Usage: SampleLogin001FetchRunner -- <repo_root>\n", stderr)
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
                rp("samples/booksources/p1_login/sample_login_001.json")))
        )
        let searchURL = (bs.searchUrl ?? "")
            .replacingOccurrences(of: "{{key}}", with: "test")
            .replacingOccurrences(of: "{{keyword}}", with: "test")
            .replacingOccurrences(of: "{{page}}", with: "1")

        let client = HTTPAdapterFactory.makeDefault()

        var httpStatus: Int?          = nil
        var contentType: String?      = nil
        var responseClass: String?    = nil
        var setCookieObserved         = false
        var loginMarkerObserved       = false
        var jsChallengeObserved       = false
        var searchResultMarkerObserved = false
        var fetchStatus               = "failed"
        var secondaryReason           = "baseline_controlled_fetch_failed"
        var notes                     = ""

        do {
            let req = HTTPRequest(
                url: searchURL, method: "GET",
                headers: [:], body: nil,
                timeout: 20, useCookieJar: false
            )
            let resp = try await client.send(req)
            httpStatus   = resp.statusCode
            contentType  = resp.headers["Content-Type"] ?? resp.headers["content-type"]
            setCookieObserved = resp.headers.keys.contains { $0.lowercased() == "set-cookie" }

            switch resp.statusCode {
            case 200...299: responseClass = "success_2xx"
            case 300...399: responseClass = "redirect_3xx"
            case 400...499: responseClass = "client_error_4xx"
            case 500...599: responseClass = "server_error_5xx"
            default:        responseClass = "other_\(resp.statusCode)"
            }

            let body = String(data: resp.data, encoding: .utf8)
                    ?? String(data: resp.data, encoding: .isoLatin1) ?? ""
            let a = analyzeBody(body, statusCode: resp.statusCode, ruleSearch: bs.ruleSearch ?? "")
            loginMarkerObserved        = a.login
            jsChallengeObserved        = a.js
            searchResultMarkerObserved = a.found

            if searchResultMarkerObserved {
                fetchStatus     = "passed"
                secondaryReason = "baseline_controlled_fetch_succeeded"
                notes = "Baseline fetch succeeded without login; login isolation not required"
            } else {
                fetchStatus = "failed"
                notes = jsChallengeObserved ? "JS challenge detected in baseline response" :
                        loginMarkerObserved  ? "Login marker detected in baseline response" :
                        setCookieObserved    ? "Set-Cookie observed; search result absent; isolation required" :
                        "Baseline fetch returned no recognizable search results (status=\(resp.statusCode))"
            }
        } catch {
            fetchStatus = "failed"
            notes       = "Network error: \(error.localizedDescription)"
        }

        // Build YAML
        let now   = ISO8601DateFormatter().string(from: Date())
        let runId = "fetch_login_001_\(Int(Date().timeIntervalSince1970))"
        var out: [String] = []
        out.append("reportId: \(ys(runId))")
        out.append("generatedAt: \(ys(now))")
        out.append("phase: \"p1_login\"")
        out.append("sampleId: \"sample_login_001\"")
        out.append("")
        out.append("baseline:")
        out.append("  requestPolicy:")
        out.append("    no_header: true")
        out.append("    no_cookie: true")
        out.append("    no_login: true")
        out.append("    no_js: true")
        out.append("    no_retry: true")
        out.append("    redirect_handling: false")
        out.append("")
        out.append("result:")
        out.append("  fetchStatus: \(ys(fetchStatus))")
        out.append("  httpStatus: \(yn(httpStatus))")
        out.append("  contentType: \(ynStr(contentType))")
        out.append("  finalUrl: \(ys(searchURL))")
        out.append("  responseClass: \(ynStr(responseClass))")
        out.append("  setCookieObserved: \(yb(setCookieObserved))")
        out.append("  loginMarkerObserved: \(yb(loginMarkerObserved))")
        out.append("  jsChallengeObserved: \(yb(jsChallengeObserved))")
        out.append("  searchResultMarkerObserved: \(yb(searchResultMarkerObserved))")
        out.append("  primaryFailureType: \"NETWORK_POLICY_MISMATCH\"")
        out.append("  secondaryReason: \(ys(secondaryReason))")
        out.append("  notes: \(ys(notes))")

        let yaml = out.joined(separator: "\n") + "\n"
        let path = rp("samples/reports/latest/fetch_result_sample_login_001.yml")
        try yaml.write(toFile: path, atomically: true, encoding: .utf8)
        print("report: \(path)")
        print("fetchStatus: \(fetchStatus)")
        print("secondaryReason: \(secondaryReason)")
    } catch {
        fputs("Fatal: \(error)\n", stderr)
        exitCode = 1
    }
}
sem.wait()
exit(exitCode)
