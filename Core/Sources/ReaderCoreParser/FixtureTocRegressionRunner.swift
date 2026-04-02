import Foundation
import ReaderCoreProtocols

public struct FixtureTocRegressionManifest: Codable, Sendable {
    public let runId: String
    public let generatedAt: String
    public let samples: [FixtureTocRegressionSample]
}

public struct FixtureTocRegressionSample: Codable, Sendable {
    public let sampleId: String
    public let regressionSampleId: String
    public let inputHTMLPath: String
    public let rulePath: String
    public let expectedPath: String
}

public struct FixtureTocRegressionResult: Codable, Sendable {
    public let mode: String
    public let generatedAt: String
    public let executorVerified: Bool
    public let runId: String
    public let summary: FixtureTocRegressionSummary
    public let sampleResults: [FixtureTocSampleExecutionResult]
}

public struct FixtureTocRegressionSummary: Codable, Sendable {
    public let totalSamples: Int
    public let passed: Int
    public let failed: Int
    public let skipped: Int
}

public struct FixtureTocSampleExecutionResult: Codable, Sendable {
    public let regressionSampleId: String
    public let sampleId: String
    public let status: String
    public let passed: Bool
    public let errorType: String?
    public let diffReason: String?
}

public enum FixtureTocRegressionRunner {
    public static func run(manifest: FixtureTocRegressionManifest) throws -> FixtureTocRegressionResult {
        let results = try manifest.samples.map(runSample)
        let passed = results.filter(\.passed).count
        let failed = results.count - passed

        return FixtureTocRegressionResult(
            mode: "executor_run",
            generatedAt: iso8601Now(),
            executorVerified: true,
            runId: manifest.runId,
            summary: FixtureTocRegressionSummary(
                totalSamples: results.count,
                passed: passed,
                failed: failed,
                skipped: 0
            ),
            sampleResults: results
        )
    }

    private static func runSample(_ sample: FixtureTocRegressionSample) throws -> FixtureTocSampleExecutionResult {
        let html = try String(contentsOfFile: sample.inputHTMLPath, encoding: .utf8)
        let ruleData = try Data(contentsOf: URL(fileURLWithPath: sample.rulePath))
        let expectedData = try Data(contentsOf: URL(fileURLWithPath: sample.expectedPath))

        let rule = try JSONDecoder().decode(FixtureTocRuleFile.self, from: ruleData)
        let expected = try JSONDecoder().decode(FixtureTocExpectedFile.self, from: expectedData)

        do {
            let parser = makeParser(for: rule)
            let items = try parser.parse(
                html: html,
                titleRule: rule.titleRule,
                urlRule: rule.urlRule,
                baseURL: rule.baseURL
            )
            return compareSuccess(items: items, expected: expected, sample: sample)
        } catch {
            return compareFailure(error: error, expected: expected, sample: sample)
        }
    }

    private static func makeParser(for rule: FixtureTocRuleFile) -> FixtureTocParser {
        guard rule.executorMode == "stub", let stubError = rule.stubError else {
            return FixtureTocParser()
        }
        return FixtureTocParser(cssExecutor: FixtureTocStubRuleExecutor(stubError: stubError))
    }

    private static func compareSuccess(
        items: [FixtureTocItem],
        expected: FixtureTocExpectedFile,
        sample: FixtureTocRegressionSample
    ) -> FixtureTocSampleExecutionResult {
        guard expected.expected.success else {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                errorType: nil,
                diffReason: "expected error but parser returned success"
            )
        }

        if let chapterCount = expected.expected.chapterCount, chapterCount != items.count {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                errorType: "OUTPUT_MISMATCH",
                diffReason: "chapterCount mismatch: expected \(chapterCount), got \(items.count)"
            )
        }

        if let chapters = expected.expected.chapters, chapters.count != items.count {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                errorType: "OUTPUT_MISMATCH",
                diffReason: "chapter list length mismatch"
            )
        }

        if let chapters = expected.expected.chapters {
            for (index, chapter) in chapters.enumerated() {
                let item = items[index]
                if chapter.title != item.title || chapter.url != item.url {
                    return FixtureTocSampleExecutionResult(
                        regressionSampleId: sample.regressionSampleId,
                        sampleId: sample.sampleId,
                        status: "failed",
                        passed: false,
                        errorType: "OUTPUT_MISMATCH",
                        diffReason: "chapter mismatch at index \(index)"
                    )
                }
            }
        }

        return FixtureTocSampleExecutionResult(
            regressionSampleId: sample.regressionSampleId,
            sampleId: sample.sampleId,
            status: "passed",
            passed: true,
            errorType: nil,
            diffReason: nil
        )
    }

    private static func compareFailure(
        error: Error,
        expected: FixtureTocExpectedFile,
        sample: FixtureTocRegressionSample
    ) -> FixtureTocSampleExecutionResult {
        guard !expected.expected.success else {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                errorType: errorMapping(for: error).type,
                diffReason: "expected success but parser threw error"
            )
        }

        let actual = errorMapping(for: error)
        guard let expectedError = expected.expected.error else {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                errorType: actual.type,
                diffReason: "expected error payload missing"
            )
        }

        if actual.type != expectedError.type {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                errorType: actual.type,
                diffReason: "errorType mismatch: expected \(expectedError.type), got \(actual.type)"
            )
        }

        if actual.reason != expectedError.reason {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                errorType: actual.type,
                diffReason: "error reason mismatch: expected \(expectedError.reason), got \(actual.reason)"
            )
        }

        return FixtureTocSampleExecutionResult(
            regressionSampleId: sample.regressionSampleId,
            sampleId: sample.sampleId,
            status: "passed",
            passed: true,
            errorType: nil,
            diffReason: nil
        )
    }

    private static func errorMapping(for error: Error) -> (type: String, reason: String) {
        guard let cssError = error as? CSSExecutorError else {
            return ("CRASH", "unexpected_runtime_error")
        }

        switch cssError {
        case .invalidSelector:
            return ("RULE_INVALID", "invalid_css_selector")
        case .htmlParsingFailed:
            return ("RULE_INVALID", "html_parsing_failed")
        case .selectorNotFound:
            return ("TOC_FAILED", "chapter_list_empty")
        case .unsupportedSelectorSyntax:
            return ("RULE_UNSUPPORTED", "unsupported_selector_feature")
        case .attributeNotFound:
            return ("RULE_INVALID", "attribute_not_found")
        }
    }

    private static func iso8601Now() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}

private struct FixtureTocRuleFile: Decodable {
    let flow: String
    let titleRule: String
    let urlRule: String
    let baseURL: String?
    let executorMode: String?
    let stubError: FixtureTocStubError?
}

private struct FixtureTocExpectedFile: Decodable {
    let sampleId: String
    let regressionSampleId: String
    let flow: String
    let expected: FixtureTocExpectedPayload
}

private struct FixtureTocExpectedPayload: Decodable {
    let success: Bool
    let resultType: String?
    let chapterCount: Int?
    let chapters: [FixtureTocExpectedChapter]?
    let error: FixtureTocExpectedError?
}

private struct FixtureTocExpectedChapter: Decodable {
    let title: String
    let url: String
}

private struct FixtureTocExpectedError: Decodable {
    let type: String
    let reason: String
    let propagation: String?
}

private struct FixtureTocStubError: Decodable {
    let type: String
    let payload: String?
}

private struct FixtureTocStubRuleExecutor: FixtureTocRuleExecuting {
    let stubError: FixtureTocStubError

    func execute(_ rule: String, from html: String) throws -> [String] {
        switch stubError.type {
        case "invalidSelector":
            throw CSSExecutorError.invalidSelector(stubError.payload ?? "")
        case "selectorNotFound":
            throw CSSExecutorError.selectorNotFound(stubError.payload ?? "")
        case "unsupportedSelectorSyntax":
            throw CSSExecutorError.unsupportedSelectorSyntax(stubError.payload ?? "")
        case "attributeNotFound":
            throw CSSExecutorError.attributeNotFound(stubError.payload ?? "")
        case "htmlParsingFailed":
            throw CSSExecutorError.htmlParsingFailed
        default:
            throw CSSExecutorError.invalidSelector(stubError.payload ?? "unknown_stub_error")
        }
    }
}
