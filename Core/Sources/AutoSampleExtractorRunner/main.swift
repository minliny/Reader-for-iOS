// AutoSampleExtractorRunner/main.swift
// Fetches booksources from yiove API, probes, classifies, and writes auto samples.
// Usage: swift run --package-path Core AutoSampleExtractorRunner -- <repo_root>

import CryptoKit
import Foundation
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderPlatformAdapters

// ── Config ────────────────────────────────────────────────────────────────────
private let apiBase          = "https://shuyuan-api.yiove.com"
private let pageSize         = 20
private let maxPagesPerRun   = 5
private let maxSamplesPerRun = 20
private let probeTimeout: TimeInterval = 10

// ── YAML helpers ──────────────────────────────────────────────────────────────
private func ys(_ s: String) -> String {
    let e = s.replacingOccurrences(of: "\\", with: "\\\\")
               .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(e)\""
}
private func yn(_ n: Int?) -> String { n.map { "\($0)" } ?? "null" }
private func ynStr(_ s: String?) -> String { s.map { ys($0) } ?? "null" }
private func yb(_ b: Bool) -> String { b ? "true" : "false" }

// ── Hashing ───────────────────────────────────────────────────────────────────
private func sha8(_ s: String) -> String {
    let hash = SHA256.hash(data: Data(s.utf8))
    return hash.compactMap { String(format: "%02x", $0) }.joined().prefix(8).description
}

// ── JS / rule indicator checks ───────────────────────────────────────────────
private func containsJSIndicator(_ s: String) -> Bool {
    let l = s.lowercased()
    return l.contains("js:") || l.contains("eval(") || l.contains("<script")
           || l.contains("javascript:")
}

// Returns a flat string from a rule value (string or object) for indicator checks.
private func ruleRawText(_ value: Any?) -> String? {
    guard let v = value else { return nil }
    if let s = v as? String            { return s }
    if let o = v as? [String: Any]     { return o.values.compactMap { $0 as? String }.joined(separator: " ") }
    return nil
}

// ── Selector extraction / cleaning ───────────────────────────────────────────
private enum RuleKind { case search, toc, content }

private func extractSelector(from value: Any?, kind: RuleKind = .search) -> String? {
    guard let value = value else { return nil }
    let raw: String
    if let s = value as? String {
        raw = s
    } else if let o = value as? [String: Any] {
        // Keys that hold the item-list selector per rule type
        let candidates: [String]
        switch kind {
        case .search:  candidates = ["bookList", "name"]
        case .toc:     candidates = ["chapterList", "chapterName"]
        case .content: candidates = ["content", "items"]
        }
        guard let first = candidates.compactMap({ o[$0] as? String }).first else { return nil }
        raw = first
    } else {
        return nil
    }
    return cleanSelector(raw)
}

private func cleanSelector(_ raw: String) -> String? {
    if containsJSIndicator(raw) { return nil }
    // Strip "css:" prefix
    var s = raw.hasPrefix("css:") ? String(raw.dropFirst(4)) : raw
    // Reject XPath-style
    if s.hasPrefix("//") || s.hasPrefix("xpath:") { return nil }
    // Take the leaf of child / descendant combinator
    if s.contains(" > ") { s = s.components(separatedBy: " > ").last ?? s }
    else if s.contains(" ") { s = s.components(separatedBy: " ").last ?? s }
    // Strip @attr suffix (e.g., ".item@href")
    if let atIdx = s.firstIndex(of: "@") { s = String(s[s.startIndex ..< atIdx]) }
    s = s.trimmingCharacters(in: .whitespaces)
    return s.isEmpty ? nil : "css:\(s)"
}

// ── Probe body analysis ───────────────────────────────────────────────────────
private func isJSChallenge(_ body: String) -> Bool {
    let l = body.lowercased()
    return l.contains("cf-browser-verification")
           || l.contains("challenge-platform")
           || l.contains("please enable javascript")
           || l.contains("请开启javascript")
           || (l.contains("cloudflare") && l.contains("checking"))
}

private func isLoginMarker(_ body: String) -> Bool {
    let l = body.lowercased()
    return l.contains("请登录") || l.contains("login.php") || l.contains("用户名")
           || l.contains("请输入密码") || l.contains("sign in")
}

// ── Report builders ───────────────────────────────────────────────────────────
private func buildMetadataYAML(
    sampleId: String, sourceName: String, bsUrl: String,
    tier: String, searchSel: String, probeStatus: Int?,
    htmlLength: Int, notes: String
) -> String {
    let now = ISO8601DateFormatter().string(from: Date())
    var o: [String] = []
    o.append("sampleId: \(ys(sampleId))")
    o.append("generatedAt: \(ys(now))")
    o.append("source: \"auto_extracted\"")
    o.append("priority: \"p1\"")
    o.append("category: \"non_js\"")
    o.append("bookSourceName: \(ys(sourceName))")
    o.append("bookSourceUrl: \(ys(bsUrl))")
    o.append("accessTier: \(ys(tier))")
    o.append("extractedSearchSelector: \(ys(searchSel))")
    o.append("probeHttpStatus: \(yn(probeStatus))")
    o.append("probeHtmlLength: \(htmlLength)")
    o.append("requiresLogin: false")
    o.append("requiresCookieJar: false")
    o.append("requiresJs: false")
    o.append("notes: \(ys(notes))")
    return o.joined(separator: "\n") + "\n"
}

private func buildProbeReport(
    sampleId: String, probeUrl: String, httpStatus: Int?,
    contentType: String?, htmlLength: Int,
    jsGate: Bool, loginGate: Bool, tier: String, notes: String
) -> String {
    let now   = ISO8601DateFormatter().string(from: Date())
    let runId = "probe_\(sampleId)_\(Int(Date().timeIntervalSince1970))"
    var o: [String] = []
    o.append("reportId: \(ys(runId))")
    o.append("generatedAt: \(ys(now))")
    o.append("sampleId: \(ys(sampleId))")
    o.append("probeUrl: \(ys(probeUrl))")
    o.append("")
    o.append("result:")
    o.append("  httpStatus: \(yn(httpStatus))")
    o.append("  contentType: \(ynStr(contentType))")
    o.append("  htmlLength: \(htmlLength)")
    o.append("  jsChallengeObserved: \(yb(jsGate))")
    o.append("  loginMarkerObserved: \(yb(loginGate))")
    o.append("  classifiedTier: \(ys(tier))")
    o.append("  notes: \(ys(notes))")
    return o.joined(separator: "\n") + "\n"
}

// ── Checkpoint I/O ────────────────────────────────────────────────────────────
private struct AutoCheckpoint {
    var lastPageFetched: Int       = 0
    var totalSamplesGenerated: Int = 0
    var tierACandidates: Int       = 0
    var tierCRejected: Int         = 0
    var seenUrls: Set<String>      = []
}

private func loadCheckpoint(path: String) -> AutoCheckpoint {
    var cp = AutoCheckpoint()
    guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return cp }
    var inSeenUrls = false
    for line in content.components(separatedBy: "\n") {
        let t = line.trimmingCharacters(in: .whitespaces)
        if t == "seenUrls:" { inSeenUrls = true; continue }
        if inSeenUrls {
            if t.hasPrefix("- ") {
                let url = String(t.dropFirst(2))
                    .trimmingCharacters(in: .init(charactersIn: "\"'"))
                if !url.isEmpty { cp.seenUrls.insert(url) }
            } else if !t.isEmpty && !t.hasPrefix("#") {
                inSeenUrls = false
            }
        }
        func intVal(_ key: String) -> Int? {
            guard t.hasPrefix(key + ":") else { return nil }
            return Int(t.dropFirst(key.count + 1).trimmingCharacters(in: .whitespaces))
        }
        if let v = intVal("lastPageFetched")       { cp.lastPageFetched = v }
        if let v = intVal("totalSamplesGenerated") { cp.totalSamplesGenerated = v }
        if let v = intVal("tierACandidates")       { cp.tierACandidates = v }
        if let v = intVal("tierCRejected")         { cp.tierCRejected = v }
    }
    return cp
}

private func saveCheckpoint(_ cp: AutoCheckpoint, path: String) throws {
    let now = ISO8601DateFormatter().string(from: Date())
    var o: [String] = []
    o.append("lastRunAt: \(ys(now))")
    o.append("lastPageFetched: \(cp.lastPageFetched)")
    o.append("totalSamplesGenerated: \(cp.totalSamplesGenerated)")
    o.append("tierACandidates: \(cp.tierACandidates)")
    o.append("tierCRejected: \(cp.tierCRejected)")
    o.append("seenUrls:")
    for url in cp.seenUrls.sorted() { o.append("  - \(ys(url))") }
    try (o.joined(separator: "\n") + "\n").write(toFile: path, atomically: true, encoding: .utf8)
}

// ── Main ──────────────────────────────────────────────────────────────────────
let positional = CommandLine.arguments.dropFirst().filter { $0 != "--" }
guard let repoRoot = positional.first else {
    fputs("Usage: AutoSampleExtractorRunner -- <repo_root>\n", stderr)
    exit(1)
}
@Sendable func rp(_ rel: String) -> String {
    URL(fileURLWithPath: repoRoot).appendingPathComponent(rel).path
}

let sem = DispatchSemaphore(value: 0)
var exitCode: Int32 = 0

Task {
    defer { sem.signal() }
    do {
        let cpPath = rp("tools/checkpoints/auto_checkpoint.yml")
        var cp = loadCheckpoint(path: cpPath)

        let session = HTTPAdapterFactory.makeDefault()

        let startPage = cp.lastPageFetched + 1
        var samplesThisRun    = 0
        var consecutiveJSGate = 0

        print("AutoSampleExtractor — startPage=\(startPage), maxPages=\(maxPagesPerRun), maxSamples=\(maxSamplesPerRun)")

        outerLoop: for page in startPage ..< (startPage + maxPagesPerRun) {
            if samplesThisRun >= maxSamplesPerRun {
                print("Reached maxSamplesPerRun (\(maxSamplesPerRun)), stopping.")
                break
            }

            print("\n--- Fetching page \(page) (pageSize=\(pageSize)) ---")
                let apiUrlStr = "\(apiBase)/import/book-sources/\(page)-\(pageSize)"
            guard URL(string: apiUrlStr) != nil else {
                print("Invalid API URL, skipping page \(page)")
                continue
            }

            let pageData: Data
            do {
                let response = try await session.send(
                    HTTPRequest(
                        url: apiUrlStr,
                        method: "GET",
                        headers: [:],
                        body: nil,
                        timeout: probeTimeout,
                        useCookieJar: false
                    )
                )
                pageData = response.data
            } catch {
                print("Page \(page) fetch error: \(error.localizedDescription)")
                cp.lastPageFetched = page
                try? saveCheckpoint(cp, path: cpPath)
                continue
            }

            guard let items = try? JSONSerialization.jsonObject(with: pageData) as? [[String: Any]] else {
                print("Page \(page): unexpected JSON format, skipping")
                cp.lastPageFetched = page
                try? saveCheckpoint(cp, path: cpPath)
                continue
            }
            print("Page \(page): \(items.count) raw items")

            for item in items {
                if samplesThisRun >= maxSamplesPerRun { break outerLoop }

                // ── Filter ──────────────────────────────────────────────────
                guard let bsUrl = item["bookSourceUrl"] as? String,
                      bsUrl.hasPrefix("http") else { continue }

                let enabled = (item["enabled"] as? Bool) ?? true
                guard enabled else { continue }

                guard let searchUrl = item["searchUrl"] as? String, !searchUrl.isEmpty else { continue }

                // Reject login-required sources
                if let v = item["loginUrl"] as? String, !v.isEmpty { continue }
                if let v = item["loginUi"]  as? String, !v.isEmpty { continue }

                // Reject sources with JS in any rule
                let allRulesText = [
                    ruleRawText(item["ruleSearch"]),
                    ruleRawText(item["ruleToc"]),
                    ruleRawText(item["ruleContent"])
                ].compactMap { $0 }.joined(separator: " ")
                if containsJSIndicator(allRulesText) { continue }

                // Must have an extractable search selector
                guard let searchSel = extractSelector(from: item["ruleSearch"], kind: .search) else { continue }

                // Dedup by bookSourceUrl
                guard !cp.seenUrls.contains(bsUrl) else { continue }
                cp.seenUrls.insert(bsUrl)

                let sampleId   = "auto_\(sha8(bsUrl))"
                let sourceName = (item["bookSourceName"] as? String) ?? sampleId

                // ── Probe ────────────────────────────────────────────────────
                let probeUrlStr = searchUrl
                    .replacingOccurrences(of: "{{key}}",     with: "test")
                    .replacingOccurrences(of: "{{keyword}}", with: "test")
                    .replacingOccurrences(of: "{{page}}",    with: "1")

                print("  [\(sampleId)] probing \(sourceName) → \(probeUrlStr.prefix(80))")

                var httpStatus: Int?         = nil
                var htmlLength               = 0
                var jsGate                   = false
                var loginGate                = false
                var contentType: String?     = nil
                var probeNotes               = ""

                if URL(string: probeUrlStr) != nil {
                    do {
                        let response = try await session.send(
                            HTTPRequest(
                                url: probeUrlStr,
                                method: "GET",
                                headers: [
                                    "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15"
                                ],
                                body: nil,
                                timeout: probeTimeout,
                                useCookieJar: false
                            )
                        )
                        let pData = response.data
                        httpStatus = response.statusCode
                        contentType = response.headers["Content-Type"] ?? response.headers["content-type"]
                        let body    = String(data: pData, encoding: .utf8)
                                   ?? String(data: pData, encoding: .isoLatin1) ?? ""
                        htmlLength  = body.count
                        jsGate      = isJSChallenge(body)
                        loginGate   = isLoginMarker(body)
                        probeNotes  = jsGate    ? "JS challenge detected" :
                                      loginGate ? "Login marker detected" :
                                      "probe OK"
                    } catch {
                        probeNotes = "Network error: \(error.localizedDescription)"
                    }
                } else {
                    probeNotes = "Invalid probe URL"
                }

                // ── Classify ─────────────────────────────────────────────────
                let tier: String
                if jsGate {
                    tier = "C"
                    consecutiveJSGate += 1
                    cp.tierCRejected += 1
                    print("    → tier C (JS gate); consecutive=\(consecutiveJSGate)")
                    // Write tier C metadata stub
                    let meta = buildMetadataYAML(
                        sampleId: sampleId, sourceName: sourceName, bsUrl: bsUrl,
                        tier: tier, searchSel: searchSel, probeStatus: httpStatus,
                        htmlLength: htmlLength, notes: probeNotes
                    )
                    try meta.write(toFile: rp("samples/metadata/auto/\(sampleId).yml"),
                                   atomically: true, encoding: .utf8)
                    let probe = buildProbeReport(
                        sampleId: sampleId, probeUrl: probeUrlStr, httpStatus: httpStatus,
                        contentType: contentType, htmlLength: htmlLength,
                        jsGate: jsGate, loginGate: loginGate, tier: tier, notes: probeNotes
                    )
                    try probe.write(toFile: rp("samples/reports/auto/\(sampleId)_probe.yml"),
                                    atomically: true, encoding: .utf8)
                    try saveCheckpoint(cp, path: cpPath)
                    if consecutiveJSGate >= 5 {
                        print("    5 consecutive JS gate — skipping remaining items on this page")
                        break
                    }
                    continue
                } else if let st = httpStatus, st == 200, htmlLength > 3000, !loginGate {
                    tier = "A"
                    consecutiveJSGate = 0
                    cp.tierACandidates += 1
                } else {
                    tier = "B"
                    consecutiveJSGate = 0
                    print("    → tier B (status=\(httpStatus.map { "\($0)" } ?? "err"), len=\(htmlLength))")
                    let meta = buildMetadataYAML(
                        sampleId: sampleId, sourceName: sourceName, bsUrl: bsUrl,
                        tier: tier, searchSel: searchSel, probeStatus: httpStatus,
                        htmlLength: htmlLength, notes: probeNotes
                    )
                    try meta.write(toFile: rp("samples/metadata/auto/\(sampleId).yml"),
                                   atomically: true, encoding: .utf8)
                    let probe = buildProbeReport(
                        sampleId: sampleId, probeUrl: probeUrlStr, httpStatus: httpStatus,
                        contentType: contentType, htmlLength: htmlLength,
                        jsGate: jsGate, loginGate: loginGate, tier: tier, notes: probeNotes
                    )
                    try probe.write(toFile: rp("samples/reports/auto/\(sampleId)_probe.yml"),
                                    atomically: true, encoding: .utf8)
                    try saveCheckpoint(cp, path: cpPath)
                    continue
                }

                // ── Tier A: write full sample ─────────────────────────────────
                let tocSel     = extractSelector(from: item["ruleToc"],     kind: .toc)     ?? "css:a"
                let contentSel = extractSelector(from: item["ruleContent"], kind: .content) ?? "css:body"

                var cleanBs: [String: Any] = [:]
                cleanBs["bookSourceName"]    = sourceName
                cleanBs["bookSourceUrl"]     = bsUrl
                cleanBs["bookSourceGroup"]   = "auto_extracted"
                cleanBs["bookSourceType"]    = (item["bookSourceType"] as? Int) ?? 0
                cleanBs["searchUrl"]         = searchUrl
                cleanBs["ruleSearch"]        = searchSel
                cleanBs["ruleToc"]           = tocSel
                cleanBs["ruleContent"]       = contentSel
                cleanBs["enabled"]           = true
                cleanBs["enabledExplore"]    = false
                cleanBs["enabledCookieJar"]  = (item["enabledCookieJar"] as? Bool) ?? false
                if let h = item["header"] as? [String: String], !h.isEmpty {
                    cleanBs["header"] = h
                }

                let bsJson = try JSONSerialization.data(
                    withJSONObject: cleanBs,
                    options: [.prettyPrinted, .sortedKeys]
                )
                try bsJson.write(to: URL(fileURLWithPath: rp("samples/booksources/auto/\(sampleId).json")))

                let meta = buildMetadataYAML(
                    sampleId: sampleId, sourceName: sourceName, bsUrl: bsUrl,
                    tier: tier, searchSel: searchSel, probeStatus: httpStatus,
                    htmlLength: htmlLength, notes: probeNotes
                )
                try meta.write(toFile: rp("samples/metadata/auto/\(sampleId).yml"),
                               atomically: true, encoding: .utf8)

                let probe = buildProbeReport(
                    sampleId: sampleId, probeUrl: probeUrlStr, httpStatus: httpStatus,
                    contentType: contentType, htmlLength: htmlLength,
                    jsGate: jsGate, loginGate: loginGate, tier: tier, notes: probeNotes
                )
                try probe.write(toFile: rp("samples/reports/auto/\(sampleId)_probe.yml"),
                                atomically: true, encoding: .utf8)

                samplesThisRun           += 1
                cp.totalSamplesGenerated += 1
                print("    → tier A sample written (\(samplesThisRun)/\(maxSamplesPerRun) this run, total=\(cp.totalSamplesGenerated))")

                try saveCheckpoint(cp, path: cpPath)
            }

            cp.lastPageFetched = page
            try saveCheckpoint(cp, path: cpPath)
        }

        print("\nDone. samplesThisRun=\(samplesThisRun), totalGenerated=\(cp.totalSamplesGenerated), tierC=\(cp.tierCRejected)")

    } catch {
        fputs("Fatal: \(error)\n", stderr)
        exitCode = 1
    }
}
sem.wait()
exit(exitCode)
