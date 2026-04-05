// run_sample_003_nonjs_smoke.swift
// Usage: swift run --package-path Core Sample003NonJSSmokeRunner -- <repo_root>

import Foundation
import ReaderCoreModels
import ReaderCoreParser

private struct ExpectedSearchFile: Decodable {
    struct Body: Decodable {
        struct Item: Decodable {
            let title: String
            let detailURL: String
        }
        let resultCount: Int
        let items: [Item]
    }
    let expected: Body
}

private struct ExpectedTocFile: Decodable {
    struct Body: Decodable {
        struct Chapter: Decodable {
            let chapterTitle: String
            let chapterURL: String
            let chapterIndex: Int
        }
        let chapterCount: Int
        let chapters: [Chapter]
    }
    let expected: Body
}

private struct ExpectedContentFile: Decodable {
    struct Body: Decodable {
        let contentNonEmpty: Bool
        let content: String
    }
    let expected: Body
}

private func ys(_ s: String) -> String {
    let e = s
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
    return "\"\(e)\""
}

@main
struct Sample003NonJSSmokeRunner {

    static func main() throws {
        let args = CommandLine.arguments
        let positional = args.dropFirst().filter { $0 != "--" }
        let repoRoot = positional.first
            ?? FileManager.default.currentDirectoryPath

        func rp(_ rel: String) -> String {
            URL(fileURLWithPath: repoRoot).appendingPathComponent(rel).path
        }
        func readStr(_ rel: String) throws -> String {
            try String(contentsOfFile: rp(rel), encoding: .utf8)
        }
        func readData(_ rel: String) throws -> Data {
            try Data(contentsOf: URL(fileURLWithPath: rp(rel)))
        }

        let bookSource = try JSONDecoder().decode(
            BookSource.self,
            from: try readData("samples/booksources/p0_non_js/sample_003.json")
        )
        let searchHTML  = try readStr("samples/fixtures/html/sample_003_search.html")
        let tocHTML     = try readStr("samples/fixtures/html/sample_003_toc.html")
        let contentHTML = try readStr("samples/fixtures/html/sample_003_content.html")

        let expSearch  = try JSONDecoder().decode(ExpectedSearchFile.self,  from: try readData("samples/expected/search/sample_003.json"))
        let expToc     = try JSONDecoder().decode(ExpectedTocFile.self,     from: try readData("samples/expected/toc/sample_003.json"))
        let expContent = try JSONDecoder().decode(ExpectedContentFile.self, from: try readData("samples/expected/content/sample_003.json"))

        let engine = NonJSParserEngine()

        // ── Search ────────────────────────────────────────────────────────
        var searchStatus      = "failed"
        var actualSearch: [SearchResultItem] = []
        var searchFailure: String? = "SEARCH_FAILED"

        do {
            let query = SearchQuery(keyword: "fixture")
            actualSearch = try engine.parseSearchResponse(
                Data(searchHTML.utf8), source: bookSource, query: query
            )
            let countOK = actualSearch.count == expSearch.expected.resultCount
            let itemsOK = actualSearch.count == expSearch.expected.items.count &&
                zip(actualSearch, expSearch.expected.items).allSatisfy {
                    $0.title == $1.title && $0.detailURL == $1.detailURL
                }
            if countOK && itemsOK {
                searchStatus  = "passed"
                searchFailure = nil
            } else {
                searchFailure = "OUTPUT_MISMATCH"
            }
        } catch {
            searchFailure = "SEARCH_FAILED"
        }

        // ── TOC ───────────────────────────────────────────────────────────
        var tocStatus      = "failed"
        var actualToc: [TOCItem] = []
        var tocFailure: String? = "TOC_FAILED"

        do {
            actualToc = try engine.parseTOCResponse(
                Data(tocHTML.utf8),
                source: bookSource,
                detailURL: "http://fixture3.local/book/1.html"
            )
            let countOK = actualToc.count == expToc.expected.chapterCount
            let itemsOK = actualToc.count == expToc.expected.chapters.count &&
                zip(actualToc, expToc.expected.chapters).allSatisfy {
                    $0.chapterTitle == $1.chapterTitle && $0.chapterURL == $1.chapterURL
                }
            if countOK && itemsOK {
                tocStatus  = "passed"
                tocFailure = nil
            } else {
                tocFailure = "OUTPUT_MISMATCH"
            }
        } catch {
            tocFailure = "TOC_FAILED"
        }

        // ── Content ───────────────────────────────────────────────────────
        var contentStatus   = "failed"
        var actualContent   = ""
        var contentFailure: String? = "CONTENT_FAILED"

        do {
            let page = try engine.parseContentResponse(
                Data(contentHTML.utf8),
                source: bookSource,
                chapterURL: "http://fixture3.local/chapter/1.html"
            )
            actualContent = page.content
            if !actualContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                contentStatus  = "passed"
                contentFailure = nil
            } else {
                contentFailure = "CONTENT_FAILED"
            }
        } catch {
            contentFailure = "CONTENT_FAILED"
        }

        // ── Overall ───────────────────────────────────────────────────────
        let overall = (searchStatus == "passed" && tocStatus == "passed" && contentStatus == "passed")
            ? "passed" : "failed"
        let overallFailure = [searchFailure, tocFailure, contentFailure]
            .compactMap { $0 }.first
        let contentNonEmpty = !actualContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let contentPreview  = String(actualContent.prefix(80))

        let now   = ISO8601DateFormatter().string(from: Date())
        let runId = "smoke_sample_003_nonjs_\(Int(Date().timeIntervalSince1970))"

        var out: [String] = []
        out.append("reportId: \(ys(runId))")
        out.append("generatedAt: \(ys(now))")
        out.append("phase: \"p0_non_js_core_stable\"")
        out.append("sampleId: \"sample_003\"")
        out.append("")
        out.append("results:")
        out.append("  search:")
        out.append("    status: \(ys(searchStatus))")
        out.append("    actualCount: \(actualSearch.count)")
        out.append("    expectedCount: \(expSearch.expected.resultCount)")
        out.append("    items:")
        for item in actualSearch {
            out.append("      - name: \(ys(item.title))")
            out.append("        url: \(ys(item.detailURL))")
        }
        out.append("  toc:")
        out.append("    status: \(ys(tocStatus))")
        out.append("    actualCount: \(actualToc.count)")
        out.append("    expectedCount: \(expToc.expected.chapterCount)")
        out.append("    chapters:")
        for ch in actualToc {
            out.append("      - title: \(ys(ch.chapterTitle))")
            out.append("        url: \(ys(ch.chapterURL))")
        }
        out.append("  content:")
        out.append("    status: \(ys(contentStatus))")
        out.append("    contentNonEmpty: \(contentNonEmpty)")
        out.append("    expectedNonEmpty: \(expContent.expected.contentNonEmpty)")
        out.append("    contentPreview: \(ys(contentPreview))")
        out.append("")
        out.append("final:")
        out.append("  overall: \(ys(overall))")
        if let ft = overallFailure {
            out.append("  failureType: \(ys(ft))")
        } else {
            out.append("  failureType: null")
        }
        out.append("  notes: \"sample_003 full chain smoke: search -> toc -> content\"")

        let yaml = out.joined(separator: "\n") + "\n"

        let reportPath = rp("samples/reports/latest/sample_003_nonjs_smoke_result.yml")
        try yaml.write(toFile: reportPath, atomically: true, encoding: .utf8)

        print("report: \(reportPath)")
        print("overall: \(overall)")
        if let ft = overallFailure {
            print("failureType: \(ft)")
        }
    }
}
