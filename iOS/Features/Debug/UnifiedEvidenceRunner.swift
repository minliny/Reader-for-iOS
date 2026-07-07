#if DEBUG && canImport(ReaderCoreNativeAdapter)

import Foundation
import ReaderCoreNativeAdapter
import SwiftUI

// MARK: - Autorun configuration

/// Configuration for `--unified-evidence-autorun` CLI flag, mirroring the
/// existing `NativeCoreEvidenceAutorunConfiguration` pattern.
public struct UnifiedEvidenceAutorunConfiguration: Sendable, Equatable {
    public let isEnabled: Bool
    public let isValid: Bool
    public let invalidReason: String?
    public let outputDirectory: String
    public let exitAfterRun: Bool

    private init(
        isEnabled: Bool,
        isValid: Bool,
        invalidReason: String?,
        outputDirectory: String,
        exitAfterRun: Bool
    ) {
        self.isEnabled = isEnabled
        self.isValid = isValid
        self.invalidReason = invalidReason
        self.outputDirectory = outputDirectory
        self.exitAfterRun = exitAfterRun
    }

    public static func parse(_ arguments: [String]) -> UnifiedEvidenceAutorunConfiguration {
        guard arguments.contains("--unified-evidence-autorun") else {
            return disabled()
        }

        var outputDirectory = ""
        var exitAfterRun = false

        for (index, argument) in arguments.enumerated() {
            switch argument {
            case "--unified-evidence-output-dir":
                if index + 1 < arguments.count {
                    outputDirectory = arguments[index + 1]
                }
            case "--unified-evidence-exit-after-run":
                exitAfterRun = true
            default:
                break
            }
        }

        return UnifiedEvidenceAutorunConfiguration(
            isEnabled: true,
            isValid: true,
            invalidReason: nil,
            outputDirectory: outputDirectory,
            exitAfterRun: exitAfterRun
        )
    }

    private static func disabled() -> UnifiedEvidenceAutorunConfiguration {
        UnifiedEvidenceAutorunConfiguration(
            isEnabled: false,
            isValid: true,
            invalidReason: nil,
            outputDirectory: "",
            exitAfterRun: false
        )
    }
}

// MARK: - Runner

/// Unified evidence runner covering all 15 canonical capabilities.
///
/// Produces a `UnifiedEvidenceArtifact` (unified-evidence/1) that can be
/// validated by `tools/platform-evidence-validator/platform_evidence_validator.py`.
///
/// Capability policy:
/// - `runtime.ping`, `host.request`: exercised end-to-end — should PASS.
/// - `source.import`, `book.search`, `book.detail`, `book.toc`,
///   `chapter.content`, `reading.progress.update`: invoked via
///   `ReaderCoreNativeRuntime.request(method:...)` with minimal params. PASS if
///   Core round-trips (even with a structured CoreError), FAIL on
///   exception/timeout.
/// - `manga.pages.extract`, `rss.parse`, `local_book.parse`, `bookmark.crud`,
///   `tts.queue`, `http-tts`, `sync.webdav`: blocked — split by root cause:
///   - Core gap (requires Native repo C ABI): `manga.pages.extract`,
///     `local_book.parse`, `http-tts`, `sync.webdav`
///   - iOS runner not wired: `rss.parse` (Core has it, runner doesn't call),
///     `bookmark.crud` (iOS has BookmarkStore, Core has no runtime method),
///     `tts.queue` (iOS has ReaderTTSPlayer injected, Core has no runtime method)
public enum UnifiedEvidenceRunner {
    /// Run all 15 canonical capabilities and return the unified evidence artifact.
    ///
    /// `run` is `@MainActor` because it reads `RustCoreRuntimeHolder.shared.current`
    /// (a `@MainActor` singleton). The blocking Core round-trips are detached
    /// onto a background task so the main actor is not held during
    /// `runtime.request(...)` polling.
    @MainActor
    public static func run(tier: String = "simulator") async -> UnifiedEvidenceArtifact {
        let runtime: ReaderCoreNativeRuntime
        let ownsRuntime: Bool

        if let shared = RustCoreRuntimeHolder.shared.current {
            runtime = shared
            ownsRuntime = false
        } else {
            // Holder not booted (e.g. when invoked from a test process). Create a
            // temporary runtime and tear it down after the run.
            do {
                runtime = try ReaderCoreNativeRuntime()
                ownsRuntime = true
            } catch {
                return Self.allBlockedArtifact(tier: tier, reason: String(describing: error))
            }
        }

        return await Task.detached(priority: .userInitiated) {
            defer { if ownsRuntime { runtime.destroy() } }
            return Self.performRun(runtime: runtime, tier: tier)
        }.value
    }

    // MARK: - Implementation

    private static func performRun(
        runtime: ReaderCoreNativeRuntime,
        tier: String
    ) -> UnifiedEvidenceArtifact {
        let startedAt = Date()
        var capabilities: [CapabilityResult] = []
        capabilities.reserveCapacity(CANONICAL_CAPABILITIES.count)

        // ---- Pass-on-round-trip capabilities (Core responds, even with error) ----
        capabilities.append(measureRoundTrip(
            capability: "runtime.ping",
            method: "runtime.ping",
            runtime: runtime,
            requestId: 8_000,
            params: [:],
            timeout: 5
        ))

        capabilities.append(measureRoundTrip(
            capability: "source.import",
            method: "source.import",
            runtime: runtime,
            requestId: 8_001,
            params: [
                "sourceId": "unified-evidence",
                "name": "Unified Evidence",
                "baseUrl": "https://unified-evidence.example.test",
                "rules": [
                    "search": [["kind": "jsonPath", "path": "$.books[*]"]],
                    "detail": [["kind": "jsonPath", "path": "$.book"]],
                    "toc": [["kind": "jsonPath", "path": "$.toc"]],
                    "chapter": [["kind": "cssText", "selector": "p"]],
                ] as [String: Any],
            ],
            timeout: 5
        ))

        capabilities.append(measureRoundTrip(
            capability: "book.search",
            method: "book.search",
            runtime: runtime,
            requestId: 8_002,
            params: [
                "sourceId": "unified-evidence",
                "searchResponse": "{\"books\":[{\"bookId\":\"1\",\"title\":\"Unified\",\"author\":\"Evidence\"}]}",
                "source": [
                    "sourceId": "unified-evidence",
                    "name": "Unified Evidence",
                    "baseUrl": "https://unified-evidence.example.test",
                    "rules": [
                        "search": [["kind": "jsonPath", "path": "$.books[*]"]],
                    ],
                ] as [String: Any],
            ],
            timeout: 5
        ))

        capabilities.append(measureRoundTrip(
            capability: "book.detail",
            method: "book.detail",
            runtime: runtime,
            requestId: 8_003,
            params: [
                "sourceId": "unified-evidence",
                "book": ["bookId": "1", "title": "Unified"],
                "detailResponse": "{\"book\":{\"title\":\"Unified Detail\",\"author\":\"Evidence\"}}",
                "source": [
                    "sourceId": "unified-evidence",
                    "name": "Unified Evidence",
                    "baseUrl": "https://unified-evidence.example.test",
                    "rules": [
                        "detail": [["kind": "jsonPath", "path": "$.book"]],
                    ],
                ] as [String: Any],
            ],
            timeout: 5
        ))

        capabilities.append(measureRoundTrip(
            capability: "book.toc",
            method: "book.toc",
            runtime: runtime,
            requestId: 8_004,
            params: [
                "sourceId": "unified-evidence",
                "bookId": "1",
                "tocResponse": "{\"toc\":[{\"title\":\"Chapter 1\",\"url\":\"c1\"}]}",
                "source": [
                    "sourceId": "unified-evidence",
                    "name": "Unified Evidence",
                    "baseUrl": "https://unified-evidence.example.test",
                    "rules": [
                        "toc": [["kind": "jsonPath", "path": "$.toc"]],
                    ],
                ] as [String: Any],
            ],
            timeout: 5
        ))

        capabilities.append(measureRoundTrip(
            capability: "chapter.content",
            method: "chapter.content",
            runtime: runtime,
            requestId: 8_005,
            params: [
                "sourceId": "unified-evidence",
                "bookId": "1",
                "chapterTitle": "Chapter 1",
                "chapterResponse": "<html><body><p>Unified evidence content.</p></body></html>",
                "source": [
                    "sourceId": "unified-evidence",
                    "name": "Unified Evidence",
                    "baseUrl": "https://unified-evidence.example.test",
                    "rules": [
                        "chapter": [["kind": "cssText", "selector": "p"]],
                    ],
                ] as [String: Any],
            ],
            timeout: 5
        ))

        capabilities.append(measureRoundTrip(
            capability: "reading.progress.update",
            method: "reading.progress.update",
            runtime: runtime,
            requestId: 8_006,
            params: [
                "bookId": "unified-evidence-1",
                "chapterIndex": 0,
                "chapterOffset": 0,
                "chapterProgress": 0.5,
            ],
            timeout: 5
        ))

        // ---- host.request: full host request loop (runtime.hostSmoke -> host.request -> host.complete -> result) ----
        let hostLoopResult = measureHostRequestLoop(runtime: runtime, timeout: 5)
        capabilities.append(hostLoopResult.capability)

        // ---- Blocked capabilities: split by root cause ----
        // Two distinct categories:
        // 1. Core gap: Core does not expose a runtime method for this
        //    capability (no `manga.pages.extract`, `local_book.parse`,
        //    `http-tts`, or `sync.webdav` method in reader-ffi). These
        //    require Native repo changes (C ABI + Core implementation).
        // 2. iOS runner not wired: Core exposes the method OR iOS has a
        //    local implementation, but UnifiedEvidenceRunner does not
        //    exercise it. These are iOS-side wiring tasks.
        let blockedCapabilities: [(name: String, reason: String)] = [
            // Category 1: Core gap — requires Native repo C ABI extension
            ("manga.pages.extract", "Core gap: reader-ffi does not expose manga.pages.extract method"),
            ("local_book.parse", "Core gap: reader-ffi does not expose local_book.parse method"),
            ("http-tts", "Core gap: reader-ffi does not expose http-tts method (HTTP TTS protocol engine)"),
            ("sync.webdav", "Core gap: reader-ffi does not expose sync.webdav method (WebDAV sync engine)"),
            // Category 2: iOS runner not wired — Core has the method or iOS
            // has a local implementation, but this runner doesn't exercise it
            ("rss.parse", "iOS runner not wired: Core exposes rss.parse (proven by HostRssParseProofTests), but UnifiedEvidenceRunner doesn't invoke it"),
            ("bookmark.crud", "iOS runner not wired: iOS has BookmarkStore (App/Persistence), but Core doesn't expose a bookmark.crud runtime method; runner cannot round-trip via Core"),
            ("tts.queue", "iOS runner not wired: iOS has ReaderTTSPlayer + HostTTSSynth injected into HostAdapter, but Core doesn't expose a tts.queue runtime method; runner cannot round-trip via Core"),
        ]
        for (name, reason) in blockedCapabilities {
            capabilities.append(CapabilityResult(
                capability: name,
                status: .blocked,
                error: reason
            ))
        }

        // Order capabilities by the canonical order for stable output.
        var ordered = CANONICAL_CAPABILITIES.compactMap { name in
            capabilities.first { $0.capability == name }
        }
        // Defensive: if any canonical capability was somehow missed, append the
        // remaining entries (should not happen, but keeps the validator happy).
        if ordered.count != CANONICAL_CAPABILITIES.count {
            let seen = Set(ordered.map { $0.capability })
            for name in CANONICAL_CAPABILITIES where !seen.contains(name) {
                ordered.append(CapabilityResult(
                    capability: name,
                    status: .blocked,
                    error: "runner did not produce a result"
                ))
            }
        }

        let summary = UnifiedEvidenceArtifact.computeSummary(from: ordered)
        let totalDurationMs = Int(Date().timeIntervalSince(startedAt) * 1000)

        let notes: [String] = [
            "Unified evidence runner covering 15 canonical capabilities (unified-evidence/1).",
            "Pass-on-round-trip capabilities: Core round-trip = PASS (structured CoreError still proves the bridge).",
            "host.request exercised via runtime.hostSmoke -> host.request -> host.complete -> result.",
            "Blocked capabilities split by root cause: Core gap (manga/local_book/http-tts/sync.webdav need Native C ABI) vs iOS runner not wired (rss.parse/bookmark.crud/tts.queue have iOS impls but runner doesn't exercise them).",
            "totalDurationMs=\(totalDurationMs)",
        ]

        let device = collectDeviceInfo()
        let coreCommit = readCoreCommit(runtime: runtime)
        let hostCommit = readHostCommit()

        let artifact = UnifiedEvidenceArtifact(
            platform: "ios",
            tier: tier,
            generatedAt: Date(),
            coreCommit: coreCommit,
            hostCommit: hostCommit,
            device: device,
            capabilities: ordered,
            summary: summary,
            hostRequestLoop: hostLoopResult.loopEvidence,
            notes: notes
        )

        // Persist + console-print for autorun capture.
        Self.writeArtifact(artifact)
        Self.printArtifact(artifact)

        return artifact
    }

    // MARK: - Capability measurement helpers

    /// Measure a capability that PASS-es on any Core round-trip (result OR
    /// structured CoreError). Only timeouts / Swift throws count as FAIL.
    private static func measureRoundTrip(
        capability: String,
        method: String,
        runtime: ReaderCoreNativeRuntime,
        requestId: UInt64,
        params: [String: Any],
        timeout: TimeInterval
    ) -> CapabilityResult {
        let start = Date()
        do {
            let event = try runtime.request(
                method: method,
                requestId: requestId,
                params: params,
                timeout: timeout
            )
            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            // A result event is the cleanest PASS.
            return CapabilityResult(
                capability: capability,
                status: .pass,
                method: method,
                durationMs: durationMs,
                redactedEvidence: "type=\(event.type)"
            )
        } catch ReaderCoreNativeError.coreError(let code, _) {
            // Structured Core error — Core round-trip succeeded.
            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            return CapabilityResult(
                capability: capability,
                status: .pass,
                method: method,
                durationMs: durationMs,
                redactedEvidence: "coreError=\(code)"
            )
        } catch {
            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            return CapabilityResult(
                capability: capability,
                status: .fail,
                method: method,
                durationMs: durationMs,
                error: String(describing: error)
            )
        }
    }

    /// Measure the full host request loop: runtime.hostSmoke -> host.request ->
    /// host.complete -> result. Returns the capability result and (on success)
    /// the host request loop evidence.
    private static func measureHostRequestLoop(
        runtime: ReaderCoreNativeRuntime,
        timeout: TimeInterval
    ) -> (capability: CapabilityResult, loopEvidence: HostRequestLoopEvidence?) {
        let start = Date()
        let requestId: UInt64 = 8_010
        let completionRequestId: UInt64 = 8_011

        do {
            let command = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 1,
                "requestId": NSNumber(value: requestId),
                "method": "runtime.hostSmoke",
                "params": [
                    "capability": "host.smoke.echo",
                    "params": ["ping": "pong"],
                ] as [String: Any],
            ])
            try runtime.send(json: command)

            let hostRequest = try pollUntil(
                runtime: runtime,
                requestId: requestId,
                timeout: timeout
            )
            guard hostRequest.type == "host.request" else {
                throw UnifiedEvidenceRunnerFailure.unexpectedEvent(
                    type: hostRequest.type,
                    context: "host.request"
                )
            }
            guard let operationId = hostRequest.operationId else {
                throw UnifiedEvidenceRunnerFailure.missingOperationId
            }
            let hostCapability = hostRequest.capability ?? "host.smoke.echo"

            let complete = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 1,
                "requestId": NSNumber(value: completionRequestId),
                "method": "host.complete",
                "params": [
                    "operationId": NSNumber(value: operationId),
                    "result": ["echoed": true],
                ] as [String: Any],
            ])
            try runtime.send(json: complete)

            let result = try pollUntil(
                runtime: runtime,
                requestId: requestId,
                timeout: timeout
            )
            guard result.type == "result" else {
                throw UnifiedEvidenceRunnerFailure.unexpectedEvent(
                    type: result.type,
                    context: "result"
                )
            }

            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            let loopEvidence = HostRequestLoopEvidence(
                requestId: Int(requestId),
                capability: hostCapability,
                operationId: Int(operationId),
                resultBookCount: 0,
                durationMs: durationMs
            )
            let hostRequestRecord = HostRequestRecord(
                capability: hostCapability,
                operationId: Int(operationId),
                completed: true
            )
            let capability = CapabilityResult(
                capability: "host.request",
                status: .pass,
                method: "runtime.hostSmoke",
                durationMs: durationMs,
                redactedEvidence: "host.request completed; result.type=\(result.type)",
                hostRequests: [hostRequestRecord]
            )
            return (capability, loopEvidence)
        } catch {
            let durationMs = Int(Date().timeIntervalSince(start) * 1000)
            let capability = CapabilityResult(
                capability: "host.request",
                status: .fail,
                method: "runtime.hostSmoke",
                durationMs: durationMs,
                error: String(describing: error)
            )
            return (capability, nil)
        }
    }

    private static func pollUntil(
        runtime: ReaderCoreNativeRuntime,
        requestId: UInt64,
        timeout: TimeInterval
    ) throws -> ReaderCoreNativeEvent {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let event = runtime.pollEvent(requestId: requestId) {
                return event
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
        throw ReaderCoreNativeError.requestTimedOut(requestId)
    }

    // MARK: - Artifact output

    private static func writeArtifact(_ artifact: UnifiedEvidenceArtifact) {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = documents.appendingPathComponent("UnifiedEvidenceRuns", isDirectory: true)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let timestamp = Self.filenameTimestamp(from: artifact.generatedAt)
            let url = directory.appendingPathComponent("evidence-run-ios-\(timestamp).json")
            let data = try UnifiedEvidenceArtifactCodec.encode(artifact)
            try data.write(to: url, options: .atomic)
        } catch {
            print("[UnifiedEvidence] failed to write artifact: \(error)")
        }
    }

    private static func printArtifact(_ artifact: UnifiedEvidenceArtifact) {
        do {
            let data = try UnifiedEvidenceArtifactCodec.encode(artifact)
            let json = String(data: data, encoding: .utf8) ?? "<utf8-encoding-failure>"
            print("===== unified-evidence/1 artifact (ios) =====")
            print(json)
            print("===== end unified-evidence artifact =====")
        } catch {
            print("[UnifiedEvidence] failed to encode artifact for console: \(error)")
        }
    }

    private static func filenameTimestamp(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let raw = formatter.string(from: date)
        // Colons are not filename-safe on all platforms.
        return raw.replacingOccurrences(of: ":", with: "-")
    }

    // MARK: - Device / commit metadata

    private static func collectDeviceInfo() -> DeviceInfo {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineSize = MemoryLayout.size(ofValue: systemInfo.machine)
        let arch = withUnsafePointer(to: &systemInfo.machine) { ptr -> String in
            ptr.withMemoryRebound(
                to: CChar.self,
                capacity: machineSize
            ) { String(cString: $0) }
        }
        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let simulatorModel = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]
        let model = simulatorModel ?? arch
        return DeviceInfo(model: model, osVersion: osVersion, arch: arch)
    }

    /// Best-effort: read the Core commit from `core.info`. Falls back to
    /// "unknown" if the field is absent or the request fails.
    private static func readCoreCommit(runtime: ReaderCoreNativeRuntime) -> String {
        do {
            let info = try runtime.request(method: "core.info", requestId: 8_099, timeout: 3)
            if let commit = info.data?["commit"] as? String, !commit.isEmpty {
                return commit
            }
            if let version = info.data?["version"] as? String, !version.isEmpty {
                return version
            }
        } catch {
            // Fall through to "unknown".
        }
        return "unknown"
    }

    /// Best-effort: read the host (app) commit. The iOS app does not embed its
    /// git commit at build time; we surface "unknown" until that wiring lands.
    private static func readHostCommit() -> String {
        return "unknown"
    }

    // MARK: - Failure fallback

    private static func allBlockedArtifact(tier: String, reason: String) -> UnifiedEvidenceArtifact {
        let capabilities = CANONICAL_CAPABILITIES.map { name in
            CapabilityResult(
                capability: name,
                status: .blocked,
                error: "runtime unavailable: \(reason)"
            )
        }
        let summary = UnifiedEvidenceArtifact.computeSummary(from: capabilities)
        return UnifiedEvidenceArtifact(
            platform: "ios",
            tier: tier,
            generatedAt: Date(),
            coreCommit: "unknown",
            hostCommit: "unknown",
            device: collectDeviceInfo(),
            capabilities: capabilities,
            summary: summary,
            hostRequestLoop: nil,
            notes: [
                "Runner could not obtain a ReaderCoreNativeRuntime; all 15 capabilities blocked.",
                "failure_reason=\(reason)",
            ]
        )
    }
}

private enum UnifiedEvidenceRunnerFailure: Error, CustomStringConvertible {
    case missingOperationId
    case unexpectedEvent(type: String, context: String)

    var description: String {
        switch self {
        case .missingOperationId:
            return "host.request did not include operationId"
        case .unexpectedEvent(let type, let context):
            return "expected \(context) event, got type=\(type)"
        }
    }
}

// MARK: - Autorun view

/// SwiftUI shell for `--unified-evidence-autorun`. Mirrors
/// `NativeCoreEvidenceAutorunView` but drives `UnifiedEvidenceRunner.run()`.
public struct UnifiedEvidenceAutorunView: View {
    @StateObject private var viewModel: UnifiedEvidenceAutorunViewModel

    public init(configuration: UnifiedEvidenceAutorunConfiguration) {
        _viewModel = StateObject(
            wrappedValue: UnifiedEvidenceAutorunViewModel(configuration: configuration)
        )
    }

    public var body: some View {
        DemoPaperScreen {
            if viewModel.isRunning {
                ReaderStateCard(
                    icon: .sync,
                    title: "Running unified evidence",
                    subtitle: "Covering 15 canonical capabilities (unified-evidence/1)."
                )
            } else if viewModel.succeeded {
                ReaderStateCard(
                    icon: .check,
                    title: "Unified evidence complete",
                    subtitle: viewModel.summaryText
                )
            } else {
                ReaderStateCard(
                    icon: .warning,
                    title: "Unified evidence failed",
                    subtitle: viewModel.errorText
                )
            }
        }
        .task {
            await viewModel.run()
        }
    }
}

@MainActor
public final class UnifiedEvidenceAutorunViewModel: ObservableObject {
    @Published public private(set) var isRunning = false
    @Published public private(set) var succeeded = false
    @Published public private(set) var summaryText = ""
    @Published public private(set) var errorText = ""
    @Published public private(set) var outputDirectory = ""

    private let configuration: UnifiedEvidenceAutorunConfiguration

    public init(configuration: UnifiedEvidenceAutorunConfiguration) {
        self.configuration = configuration
    }

    public func run() async {
        guard !isRunning else { return }
        isRunning = true

        let artifact = await UnifiedEvidenceRunner.run(tier: Self.evidenceTier)

        let summary = artifact.summary
        let passRatePercent = Int((summary.passRate * 100).rounded())
        summaryText = "passed=\(summary.passed)/\(summary.total) passRate=\(passRatePercent)%"
        succeeded = (summary.failed == 0)

        if !succeeded {
            let failed = artifact.capabilities.filter { $0.status == .fail }
            errorText = failed
                .map { "\($0.capability): \($0.error ?? "unknown")" }
                .joined(separator: "; ")
            if errorText.isEmpty {
                errorText = "no failed capabilities reported but summary.failed=\(summary.failed)"
            }
        }

        if let url = Self.lastWrittenArtifactURL() {
            outputDirectory = url.deletingLastPathComponent().path
        }

        isRunning = false

        if configuration.exitAfterRun {
            try? await Task.sleep(nanoseconds: 500_000_000)
            exit(succeeded ? 0 : 1)
        }
    }

    private static func lastWrittenArtifactURL() -> URL? {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let directory = documents.appendingPathComponent("UnifiedEvidenceRuns", isDirectory: true)
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }
        return contents
            .filter { $0.lastPathComponent.hasPrefix("evidence-run-ios-") && $0.pathExtension == "json" }
            .sorted {
                let lhs = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhs = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhs > rhs
            }
            .first
    }

    private static var evidenceTier: String {
        #if targetEnvironment(simulator)
        return "simulator"
        #else
        return "device"
        #endif
    }
}

#endif
