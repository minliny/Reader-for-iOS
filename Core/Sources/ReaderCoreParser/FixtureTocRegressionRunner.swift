import Foundation
import Dispatch
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
    public let running: Int
}

public struct FixtureTocSampleExecutionResult: Codable, Sendable {
    public let regressionSampleId: String
    public let sampleId: String
    public let status: String
    public let passed: Bool
    public let currentStage: String
    public let errorType: String?
    public let diffReason: String?
    public let error: String?
}

public enum FixtureTocRegressionRunner {
    public static func run(
        manifest: FixtureTocRegressionManifest,
        sampleTimeout: TimeInterval = 30,
        log: @escaping (String) -> Void = { _ in },
        tocLog: @escaping (String) -> Void = { _ in },
        onUpdate: @escaping (FixtureTocRegressionResult) -> Void = { _ in }
    ) throws -> FixtureTocRegressionResult {
        let recorder = ProgressRecorder(manifest: manifest, onUpdate: onUpdate)
        log("RUNNER_INIT runId=\(manifest.runId)")
        log("SAMPLE_LIST_READY count=\(manifest.samples.count)")
        recorder.publishCurrentSnapshot()

        for (index, sample) in manifest.samples.enumerated() {
            log("SAMPLE_START id=\(sample.sampleId) index=\(index + 1)")
            recorder.record(runningResult(sample: sample, stage: "search"))
            let result = runSampleWithTimeout(
                sample,
                timeout: sampleTimeout,
                log: log,
                tocLog: tocLog
            ) { stage in
                recorder.record(runningResult(sample: sample, stage: stage))
            }
            recorder.record(result)
        }

        return recorder.snapshot()
    }

    private static func runSampleWithTimeout(
        _ sample: FixtureTocRegressionSample,
        timeout: TimeInterval,
        log: @escaping (String) -> Void,
        tocLog: @escaping (String) -> Void,
        onStageUpdate: @escaping (String) -> Void
    ) -> FixtureTocSampleExecutionResult {
        let state = SampleExecutionState(initialStage: "search")
        let completion = CompletionBox()
        let semaphore = DispatchSemaphore(value: 0)
        let queue = DispatchQueue(label: "FixtureTocRegressionRunner.\(sample.sampleId)", qos: .userInitiated)

        queue.async {
            let sampleTocLog: (String) -> Void = { message in
                guard state.allowsLogging else {
                    return
                }
                tocLog(message)
            }
            let result = executeSample(
                sample,
                state: state,
                log: log,
                tocLog: sampleTocLog,
                onStageUpdate: onStageUpdate
            )
            if state.markCompletedIfPending() {
                logFinalResult(result, log: log)
                completion.store(result)
                semaphore.signal()
            }
        }

        if semaphore.wait(timeout: .now() + timeout) == .timedOut {
            let stage = state.markTimedOut()
            let reason = "sample exceeded \(Int(timeout))s during \(stage) stage"
            log("SAMPLE_TIMEOUT id=\(sample.sampleId) stage=\(stage)")
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "timeout",
                passed: false,
                currentStage: stage,
                errorType: "TIMEOUT",
                diffReason: reason,
                error: reason
            )
        }

        return completion.result ?? unexpectedFailureResult(
            sample: sample,
            stage: state.currentStage,
            reason: "sample finished without producing a result"
        )
    }

    private static func executeSample(
        _ sample: FixtureTocRegressionSample,
        state: SampleExecutionState,
        log: @escaping (String) -> Void,
        tocLog: @escaping (String) -> Void,
        onStageUpdate: @escaping (String) -> Void
    ) -> FixtureTocSampleExecutionResult {
        do {
            updateStage("search", sample: sample, state: state, log: log, onStageUpdate: onStageUpdate)
            let html = try String(contentsOfFile: sample.inputHTMLPath, encoding: .utf8)
            let ruleData = try Data(contentsOf: URL(fileURLWithPath: sample.rulePath))
            let expectedData = try Data(contentsOf: URL(fileURLWithPath: sample.expectedPath))

            let rule = try JSONDecoder().decode(FixtureTocRuleFile.self, from: ruleData)
            let expected = try JSONDecoder().decode(FixtureTocExpectedFile.self, from: expectedData)

            do {
                updateStage("toc", sample: sample, state: state, log: log, onStageUpdate: onStageUpdate)
                let parser = makeParser(for: rule, sampleId: sample.sampleId, tocLog: tocLog)
                let items = try parser.parse(
                    html: html,
                    titleRule: rule.titleRule,
                    urlRule: rule.urlRule,
                    baseURL: rule.baseURL,
                    sampleId: sample.sampleId
                )
                updateStage("content", sample: sample, state: state, log: log, onStageUpdate: onStageUpdate)
                return compareSuccess(items: items, expected: expected, sample: sample)
            } catch {
                updateStage("content", sample: sample, state: state, log: log, onStageUpdate: onStageUpdate)
                return compareFailure(error: error, expected: expected, sample: sample, stage: state.currentStage)
            }
        } catch {
            return unexpectedFailureResult(sample: sample, stage: state.currentStage, reason: String(describing: error))
        }
    }

    private static func updateStage(
        _ stage: String,
        sample: FixtureTocRegressionSample,
        state: SampleExecutionState,
        log: @escaping (String) -> Void,
        onStageUpdate: @escaping (String) -> Void
    ) {
        guard state.updateStageIfPending(stage) else {
            return
        }
        log("SAMPLE_STAGE id=\(sample.sampleId) stage=\(stage)")
        onStageUpdate(stage)
    }

    private static func makeParser(
        for rule: FixtureTocRuleFile,
        sampleId: String,
        tocLog: @escaping (String) -> Void
    ) -> FixtureTocParser {
        guard rule.executorMode == "stub", let stubError = rule.stubError else {
            return FixtureTocParser(sampleId: sampleId, tocLog: tocLog)
        }
        return FixtureTocParser(
            cssExecutor: FixtureTocStubRuleExecutor(stubError: stubError),
            sampleId: sampleId,
            tocLog: tocLog
        )
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
                currentStage: "content",
                errorType: nil,
                diffReason: "expected error but parser returned success",
                error: "expected error but parser returned success"
            )
        }

        if let chapterCount = expected.expected.chapterCount, chapterCount != items.count {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                currentStage: "content",
                errorType: "OUTPUT_MISMATCH",
                diffReason: "chapterCount mismatch: expected \(chapterCount), got \(items.count)",
                error: "chapterCount mismatch: expected \(chapterCount), got \(items.count)"
            )
        }

        if let chapters = expected.expected.chapters, chapters.count != items.count {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                currentStage: "content",
                errorType: "OUTPUT_MISMATCH",
                diffReason: "chapter list length mismatch",
                error: "chapter list length mismatch"
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
                        currentStage: "content",
                        errorType: "OUTPUT_MISMATCH",
                        diffReason: "chapter mismatch at index \(index)",
                        error: "chapter mismatch at index \(index)"
                    )
                }
            }
        }

        return FixtureTocSampleExecutionResult(
            regressionSampleId: sample.regressionSampleId,
            sampleId: sample.sampleId,
            status: "passed",
            passed: true,
            currentStage: "content",
            errorType: nil,
            diffReason: nil,
            error: nil
        )
    }

    private static func compareFailure(
        error: Error,
        expected: FixtureTocExpectedFile,
        sample: FixtureTocRegressionSample,
        stage: String
    ) -> FixtureTocSampleExecutionResult {
        guard !expected.expected.success else {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                currentStage: stage,
                errorType: errorMapping(for: error).type,
                diffReason: "expected success but parser threw error",
                error: String(describing: error)
            )
        }

        let actual = errorMapping(for: error)
        guard let expectedError = expected.expected.error else {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                currentStage: stage,
                errorType: actual.type,
                diffReason: "expected error payload missing",
                error: "expected error payload missing"
            )
        }

        if actual.type != expectedError.type {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                currentStage: stage,
                errorType: actual.type,
                diffReason: "errorType mismatch: expected \(expectedError.type), got \(actual.type)",
                error: "errorType mismatch: expected \(expectedError.type), got \(actual.type)"
            )
        }

        if actual.reason != expectedError.reason {
            return FixtureTocSampleExecutionResult(
                regressionSampleId: sample.regressionSampleId,
                sampleId: sample.sampleId,
                status: "failed",
                passed: false,
                currentStage: stage,
                errorType: actual.type,
                diffReason: "error reason mismatch: expected \(expectedError.reason), got \(actual.reason)",
                error: "error reason mismatch: expected \(expectedError.reason), got \(actual.reason)"
            )
        }

        return FixtureTocSampleExecutionResult(
            regressionSampleId: sample.regressionSampleId,
            sampleId: sample.sampleId,
            status: "passed",
            passed: true,
            currentStage: stage,
            errorType: nil,
            diffReason: nil,
            error: nil
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

    private static func runningResult(
        sample: FixtureTocRegressionSample,
        stage: String
    ) -> FixtureTocSampleExecutionResult {
        FixtureTocSampleExecutionResult(
            regressionSampleId: sample.regressionSampleId,
            sampleId: sample.sampleId,
            status: "running",
            passed: false,
            currentStage: stage,
            errorType: nil,
            diffReason: nil,
            error: nil
        )
    }

    private static func unexpectedFailureResult(
        sample: FixtureTocRegressionSample,
        stage: String,
        reason: String
    ) -> FixtureTocSampleExecutionResult {
        FixtureTocSampleExecutionResult(
            regressionSampleId: sample.regressionSampleId,
            sampleId: sample.sampleId,
            status: "failed",
            passed: false,
            currentStage: stage,
            errorType: "CRASH",
            diffReason: reason,
            error: reason
        )
    }

    private static func logFinalResult(
        _ result: FixtureTocSampleExecutionResult,
        log: @escaping (String) -> Void
    ) {
        switch result.status {
        case "passed":
            log("SAMPLE_DONE id=\(result.sampleId)")
        case "timeout":
            log("SAMPLE_TIMEOUT id=\(result.sampleId) stage=\(result.currentStage)")
        default:
            let message = sanitizeLogValue(result.error ?? result.diffReason ?? result.errorType ?? "unknown")
            log("SAMPLE_FAIL id=\(result.sampleId) error=\(message)")
        }
    }

    private static func sanitizeLogValue(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
    }

    private static func makeResult(
        manifest: FixtureTocRegressionManifest,
        sampleResults: [FixtureTocSampleExecutionResult]
    ) -> FixtureTocRegressionResult {
        let passed = sampleResults.filter { $0.status == "passed" }.count
        let failed = sampleResults.filter { $0.status == "failed" || $0.status == "timeout" }.count
        let running = sampleResults.filter { $0.status == "running" }.count
        let skipped = max(manifest.samples.count - passed - failed - running, 0)

        return FixtureTocRegressionResult(
            mode: "executor_run",
            generatedAt: iso8601Now(),
            executorVerified: true,
            runId: manifest.runId,
            summary: FixtureTocRegressionSummary(
                totalSamples: manifest.samples.count,
                passed: passed,
                failed: failed,
                skipped: skipped,
                running: running
            ),
            sampleResults: sampleResults
        )
    }

    private final class ProgressRecorder {
        private let lock = NSLock()
        private let manifest: FixtureTocRegressionManifest
        private let onUpdate: (FixtureTocRegressionResult) -> Void
        private var sampleResults: [FixtureTocSampleExecutionResult] = []

        init(
            manifest: FixtureTocRegressionManifest,
            onUpdate: @escaping (FixtureTocRegressionResult) -> Void
        ) {
            self.manifest = manifest
            self.onUpdate = onUpdate
        }

        func record(_ result: FixtureTocSampleExecutionResult) {
            let snapshot: FixtureTocRegressionResult
            lock.lock()
            if let index = sampleResults.firstIndex(where: { $0.regressionSampleId == result.regressionSampleId }) {
                sampleResults[index] = result
            } else {
                sampleResults.append(result)
            }
            snapshot = FixtureTocRegressionRunner.makeResult(manifest: manifest, sampleResults: sampleResults)
            lock.unlock()
            onUpdate(snapshot)
        }

        func publishCurrentSnapshot() {
            onUpdate(snapshot())
        }

        func snapshot() -> FixtureTocRegressionResult {
            lock.lock()
            let snapshot = FixtureTocRegressionRunner.makeResult(manifest: manifest, sampleResults: sampleResults)
            lock.unlock()
            return snapshot
        }
    }

    private final class SampleExecutionState: @unchecked Sendable {
        private let lock = NSLock()
        private var stage: String
        private var timedOut = false
        private var completed = false

        init(initialStage: String) {
            self.stage = initialStage
        }

        var currentStage: String {
            lock.lock()
            let value = stage
            lock.unlock()
            return value
        }

        var allowsLogging: Bool {
            lock.lock()
            let allowed = !timedOut
            lock.unlock()
            return allowed
        }

        func updateStageIfPending(_ nextStage: String) -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !timedOut, !completed else {
                return false
            }
            stage = nextStage
            return true
        }

        func markTimedOut() -> String {
            lock.lock()
            defer { lock.unlock() }
            timedOut = true
            return stage
        }

        func markCompletedIfPending() -> Bool {
            lock.lock()
            defer { lock.unlock() }
            guard !timedOut, !completed else {
                return false
            }
            completed = true
            return true
        }
    }

    private final class CompletionBox {
        private let lock = NSLock()
        private var value: FixtureTocSampleExecutionResult?

        var result: FixtureTocSampleExecutionResult? {
            lock.lock()
            let snapshot = value
            lock.unlock()
            return snapshot
        }

        func store(_ result: FixtureTocSampleExecutionResult) {
            lock.lock()
            value = result
            lock.unlock()
        }
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
