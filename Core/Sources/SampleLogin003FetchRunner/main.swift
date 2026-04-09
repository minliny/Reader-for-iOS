// SampleLogin003FetchRunner/main.swift
// Baseline-only fetch for sample_login_003 (the-internet.herokuapp.com)
// Usage: swift run --package-path Core SampleLogin003FetchRunner -- <repo_root>

import Foundation
import ReaderCoreModels
import ReaderCoreNetwork
import ReaderCoreProtocols
import ReaderCoreFoundation
import ReaderPlatformAdapters

private struct LoginFlowConfig { let successMarkers: [String]; let failureMarkers: [String] }
private func ys(_ s: String) -> String { "\"\(s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\""))\"" }
private func yb(_ b: Bool) -> String { b ? "true" : "false" }
private func yn(_ n: Int?) -> String { n.map { "\($0)" } ?? "null" }
private func ynStr(_ s: String?) -> String { s.map { ys($0) } ?? "null" }

private func stringArrayValue(_ value: JSONValue?) -> [String]? {
    guard case .array(let values)? = value else { return nil }
    return values.compactMap { if case .string(let s) = $0 { return s }; return nil }
}
private func boolValue(_ value: JSONValue?) -> Bool? {
    guard case .bool(let b)? = value else { return nil }
    return b
}
private func loadLoginFlow(from source: BookSource) -> LoginFlowConfig? {
    guard case .object(let object)? = source.unknownFields["xReaderLoginFlow"],
          boolValue(object["enabled"]) == true,
          let successMarkers = stringArrayValue(object["successMarkers"]),
          let failureMarkers = stringArrayValue(object["failureMarkers"])
    else { return nil }
    return LoginFlowConfig(successMarkers: successMarkers, failureMarkers: failureMarkers)
}
private func responseClass(for statusCode: Int?) -> String? {
    guard let statusCode else { return "network_error" }
    switch statusCode {
    case 200...299: return "success_2xx"
    case 300...399: return "redirect_3xx"
    case 400...499: return "client_error_4xx"
    case 500...599: return "server_error_5xx"
    default: return "other_\(statusCode)"
    }
}
private func analyzeBody(_ body: String, statusCode: Int, loginFlow: LoginFlowConfig) -> (login: Bool, js: Bool, found: Bool) {
    let lb = body.lowercased()
    let login = lb.contains("username") || lb.contains("password") || lb.contains("secure login form") || loginFlow.failureMarkers.contains(where: { body.contains($0) })
    let js = lb.contains("cf-browser-verification") || lb.contains("challenge-platform") || lb.contains("please enable javascript") || lb.contains("cloudflare")
    let found = statusCode == 200 && loginFlow.successMarkers.allSatisfy { body.contains($0) }
    return (login, js, found)
}

let positional = CommandLine.arguments.dropFirst().filter { $0 != "--" }
guard let repoRoot = positional.first else { fputs("Usage: SampleLogin003FetchRunner -- <repo_root>\n", stderr); exit(1) }
func rp(_ relativePath: String) -> String { URL(fileURLWithPath: repoRoot).appendingPathComponent(relativePath).path }

let semaphore = DispatchSemaphore(value: 0)
var exitCode: Int32 = 0

Task {
    defer { semaphore.signal() }
    do {
        let source = try JSONDecoder().decode(BookSource.self, from: try Data(contentsOf: URL(fileURLWithPath: rp("samples/booksources/p1_login/sample_login_003.json"))))
        guard let loginFlow = loadLoginFlow(from: source) else { throw NSError(domain: "SampleLogin003FetchRunner", code: 1, userInfo: [NSLocalizedDescriptionKey: "xReaderLoginFlow missing or invalid"]) }
        let builder = BookSourceRequestBuilder()
        let builtSearchRequest = try builder.makeSearchRequest(source: source, query: SearchQuery(keyword: "secure", page: 1))

        let client = HTTPAdapterFactory.makeDefault()

        var httpStatus: Int?
        var contentType: String?
        var setCookieObserved = false
        var loginMarkerObserved = false
        var jsChallengeObserved = false
        var searchResultMarkerObserved = false
        var fetchStatus = "failed"
        var secondaryReason = "baseline_controlled_fetch_failed"
        var notes = ""

        do {
            let response = try await client.send(HTTPRequest(url: builtSearchRequest.url, method: builtSearchRequest.method, headers: [:], body: builtSearchRequest.body, timeout: 20, useCookieJar: false))
            httpStatus = response.statusCode
            contentType = response.headers["Content-Type"] ?? response.headers["content-type"]
            setCookieObserved = response.headers.keys.contains { $0.lowercased() == "set-cookie" }
            let body = String(data: response.data, encoding: .utf8) ?? String(data: response.data, encoding: .isoLatin1) ?? ""
            let analysis = analyzeBody(body, statusCode: response.statusCode, loginFlow: loginFlow)
            loginMarkerObserved = analysis.login
            jsChallengeObserved = analysis.js
            searchResultMarkerObserved = analysis.found
            if analysis.found {
                fetchStatus = "passed"
                secondaryReason = "baseline_controlled_fetch_succeeded"
                notes = "Anonymous request unexpectedly reached secure markers without login."
            } else if analysis.login {
                notes = "Baseline /secure access fell back to login markers without secure markers."
            } else if analysis.js {
                notes = "JS challenge detected during anonymous secure request."
            } else {
                notes = "Baseline secure request failed to reach success markers (status=\(response.statusCode))."
            }
        } catch {
            notes = "Network error: \(error.localizedDescription)"
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let reportId = "fetch_login_003_\(Int(Date().timeIntervalSince1970))"
        let lines = [
            "reportId: \(ys(reportId))",
            "generatedAt: \(ys(now))",
            "phase: \"p1_login\"",
            "sampleId: \"sample_login_003\"",
            "",
            "baseline:",
            "  requestPolicy:",
            "    no_header: true",
            "    no_cookie: true",
            "    no_login: true",
            "    no_js: true",
            "    no_retry: true",
            "    redirect_handling: false",
            "",
            "result:",
            "  fetchStatus: \(ys(fetchStatus))",
            "  httpStatus: \(yn(httpStatus))",
            "  contentType: \(ynStr(contentType))",
            "  finalUrl: \(ys(builtSearchRequest.url))",
            "  responseClass: \(ynStr(responseClass(for: httpStatus)))",
            "  setCookieObserved: \(yb(setCookieObserved))",
            "  loginMarkerObserved: \(yb(loginMarkerObserved))",
            "  jsChallengeObserved: \(yb(jsChallengeObserved))",
            "  searchResultMarkerObserved: \(yb(searchResultMarkerObserved))",
            "  primaryFailureType: \"NETWORK_POLICY_MISMATCH\"",
            "  secondaryReason: \(ys(secondaryReason))",
            "  notes: \(ys(notes))"
        ]
        try (lines.joined(separator: "\n") + "\n").write(toFile: rp("samples/reports/latest/fetch_result_sample_login_003.yml"), atomically: true, encoding: .utf8)
        print("report: \(rp("samples/reports/latest/fetch_result_sample_login_003.yml"))")
        print("fetchStatus: \(fetchStatus)")
        print("secondaryReason: \(secondaryReason)")
    } catch {
        fputs("Fatal: \(error)\n", stderr)
        exitCode = 1
    }
}

semaphore.wait()
exit(exitCode)
