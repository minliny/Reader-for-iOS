// SampleLogin002FetchRunner/main.swift
// Baseline-only fetch for sample_login_002 (practice.expandtesting.com)
// Usage: swift run --package-path Core SampleLogin002FetchRunner -- <repo_root>

import Foundation
import ReaderCoreModels
import ReaderCoreNetwork
import ReaderCoreProtocols
import ReaderCoreFoundation
import ReaderPlatformAdapters

private struct LoginFlowConfig {
    let successMarkers: [String]
}

private func ys(_ s: String) -> String {
    let e = s.replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(e)\""
}
private func yb(_ b: Bool) -> String { b ? "true" : "false" }
private func yn(_ n: Int?) -> String { n.map { "\($0)" } ?? "null" }
private func ynStr(_ s: String?) -> String { s.map { ys($0) } ?? "null" }

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
          let successMarkers = stringArrayValue(object["successMarkers"])
    else {
        return nil
    }

    return LoginFlowConfig(successMarkers: successMarkers)
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

private func analyzeBody(
    _ body: String,
    statusCode: Int,
    loginFlow: LoginFlowConfig
) -> (login: Bool, js: Bool, found: Bool) {
    let lowercasedBody = body.lowercased()
    let login = lowercasedBody.contains("username") ||
        lowercasedBody.contains("password") ||
        lowercasedBody.contains("test login") ||
        lowercasedBody.contains("login")
    let js = lowercasedBody.contains("cf-browser-verification") ||
        lowercasedBody.contains("challenge-platform") ||
        lowercasedBody.contains("please enable javascript") ||
        lowercasedBody.contains("cloudflare")
    let found = statusCode == 200 &&
        loginFlow.successMarkers.allSatisfy { body.contains($0) }
    return (login, js, found)
}

let positional = CommandLine.arguments.dropFirst().filter { $0 != "--" }
guard let repoRoot = positional.first else {
    fputs("Usage: SampleLogin002FetchRunner -- <repo_root>\n", stderr)
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
            throw NSError(domain: "SampleLogin002FetchRunner", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "xReaderLoginFlow missing or invalid"
            ])
        }

        let builder = BookSourceRequestBuilder()
        let builtSearchRequest = try builder.makeSearchRequest(
            source: source,
            query: SearchQuery(keyword: "secure", page: 1)
        )

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
            let baselineRequest = HTTPRequest(
                url: builtSearchRequest.url,
                method: builtSearchRequest.method,
                headers: [:],
                body: builtSearchRequest.body,
                timeout: 20,
                useCookieJar: false
            )
            let response = try await client.send(baselineRequest)
            httpStatus = response.statusCode
            contentType = response.headers["Content-Type"] ?? response.headers["content-type"]
            setCookieObserved = response.headers.keys.contains { $0.lowercased() == "set-cookie" }

            let body = String(data: response.data, encoding: .utf8) ??
                String(data: response.data, encoding: .isoLatin1) ?? ""
            let analysis = analyzeBody(body, statusCode: response.statusCode, loginFlow: loginFlow)
            loginMarkerObserved = analysis.login
            jsChallengeObserved = analysis.js
            searchResultMarkerObserved = analysis.found

            if analysis.found {
                fetchStatus = "passed"
                secondaryReason = "baseline_controlled_fetch_succeeded"
                notes = "Anonymous request unexpectedly reached the secure markers without login."
            } else if analysis.login {
                notes = "Anonymous request returned login page markers instead of secure markers."
            } else if analysis.js {
                notes = "JS challenge detected during anonymous request."
            } else {
                notes = "Anonymous request did not return secure markers (status=\(response.statusCode))."
            }
        } catch {
            notes = "Network error: \(error.localizedDescription)"
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let reportId = "fetch_login_002_\(Int(Date().timeIntervalSince1970))"
        var lines: [String] = []
        lines.append("reportId: \(ys(reportId))")
        lines.append("generatedAt: \(ys(now))")
        lines.append("phase: \"p1_login\"")
        lines.append("sampleId: \"sample_login_002\"")
        lines.append("")
        lines.append("baseline:")
        lines.append("  requestPolicy:")
        lines.append("    no_header: true")
        lines.append("    no_cookie: true")
        lines.append("    no_login: true")
        lines.append("    no_js: true")
        lines.append("    no_retry: true")
        lines.append("    redirect_handling: false")
        lines.append("")
        lines.append("result:")
        lines.append("  fetchStatus: \(ys(fetchStatus))")
        lines.append("  httpStatus: \(yn(httpStatus))")
        lines.append("  contentType: \(ynStr(contentType))")
        lines.append("  finalUrl: \(ys(builtSearchRequest.url))")
        lines.append("  responseClass: \(ynStr(responseClass(for: httpStatus)))")
        lines.append("  setCookieObserved: \(yb(setCookieObserved))")
        lines.append("  loginMarkerObserved: \(yb(loginMarkerObserved))")
        lines.append("  jsChallengeObserved: \(yb(jsChallengeObserved))")
        lines.append("  searchResultMarkerObserved: \(yb(searchResultMarkerObserved))")
        lines.append("  primaryFailureType: \"NETWORK_POLICY_MISMATCH\"")
        lines.append("  secondaryReason: \(ys(secondaryReason))")
        lines.append("  notes: \(ys(notes))")

        try (lines.joined(separator: "\n") + "\n").write(
            toFile: rp("samples/reports/latest/fetch_result_sample_login_002.yml"),
            atomically: true,
            encoding: .utf8
        )
        print("report: \(rp("samples/reports/latest/fetch_result_sample_login_002.yml"))")
        print("fetchStatus: \(fetchStatus)")
        print("secondaryReason: \(secondaryReason)")
    } catch {
        fputs("Fatal: \(error)\n", stderr)
        exitCode = 1
    }
}

semaphore.wait()
exit(exitCode)
