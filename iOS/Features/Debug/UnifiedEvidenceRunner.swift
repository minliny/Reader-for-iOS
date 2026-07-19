#if DEBUG && canImport(ReaderCoreNativeAdapter)

import Foundation
import ReaderCoreNativeAdapter
import ReaderShellValidation
import ReaderUIContract
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
///   `chapter.content`, `reading.progress.update`, `rss.parse`: invoked via
///   `ReaderCoreNativeRuntime.request(method:...)` with minimal params. PASS if
///   Core round-trips (even with a structured CoreError), FAIL on
///   exception/timeout.
/// - `bookmark.crud`: blocked here. A local BookmarkStore round-trip is not
///   evidence for the Core-owned aggregate storage path; this runner does not
///   mutate user Core state or fabricate device-tier persistence evidence.
/// - `tts.queue`: blocked here. A Host synth dispatch does not prove the Core
///   plan/queue/report/next/stop transaction or physical-device playback.
/// - `manga.pages.extract`, `local_book.parse`, `http-tts`, `sync.webdav`:
///   blocked when this runner lacks the exact end-to-end fixture and required
///   native/device proof. Existing narrower contracts are not relabelled.
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
            return await Self.performRun(runtime: runtime, tier: tier)
        }.value
    }

    // MARK: - Implementation

    private static func performRun(
        runtime: ReaderCoreNativeRuntime,
        tier: String
    ) async -> UnifiedEvidenceArtifact {
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

        // ---- rss.parse: Core round-trip (Core exposes rss.parse method) ----
        // Core parses RSS 2.0/Atom XML and returns feed title + entries.
        // Use a minimal RSS 2.0 sample to exercise the parser.
        let rssSampleXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
          <channel>
            <title>Unified Evidence Runner Feed</title>
            <link>https://unified-evidence.example.test/rss.xml</link>
            <description>RSS parse proof for unified evidence runner</description>
            <item>
              <title>Entry 1</title>
              <link>https://unified-evidence.example.test/1</link>
              <guid>entry-1</guid>
            </item>
            <item>
              <title>Entry 2</title>
              <link>https://unified-evidence.example.test/2</link>
              <guid>entry-2</guid>
            </item>
          </channel>
        </rss>
        """
        capabilities.append(measureRoundTrip(
            capability: "rss.parse",
            method: "rss.parse",
            runtime: runtime,
            requestId: 8_010,
            params: [
                "feedUrl": "https://unified-evidence.example.test/rss.xml",
                "xml": rssSampleXML,
            ],
            timeout: 5
        ))

        // ---- bookmark.crud: explicit evidence boundary ----
        capabilities.append(measureBookmarkCRUD())

        // ---- tts.queue: explicit evidence boundary ----
        capabilities.append(await measureTTSQueue())

        // ---- Blocked capabilities: exact end-to-end proof is absent ----
        let coreGapCapabilities: [(name: String, reason: String)] = [
            ("manga.pages.extract", "Core extraction alone is not native manga session/locator/progress/device evidence"),
            ("local_book.parse", "Production uses local_book.import/content; this legacy capability name has no authorized-file/relaunch device artifact"),
            ("http-tts", "Config/request descriptors exist, but credential binding, audio playback/focus/media controls and device evidence are missing"),
            ("sync.webdav", "No admitted end-to-end WebDAV transaction and physical-device evidence artifact exists in this runner"),
        ]
        for (name, reason) in coreGapCapabilities {
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
            "rss.parse: Core round-trip via rss.parse method with RSS 2.0 sample XML.",
            "bookmark.crud: blocked; local JSON CRUD is not Core aggregate-persistence evidence.",
            "tts.queue: blocked; Host synth dispatch is not Core queue transaction or device playback evidence.",
            "Blocked capabilities retain exact contract/device-proof reasons; narrower source paths are not promoted.",
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

    /// This debug runner deliberately does not mutate the production Core
    /// snapshot. Bookmark evidence requires the real startup restore,
    /// write-through acknowledgement, relaunch restore, and a device artifact;
    /// a temporary local JSON store proves none of those properties.
    private static func measureBookmarkCRUD() -> CapabilityResult {
        CapabilityResult(
            capability: "bookmark.crud",
            status: .blocked,
            error: "Core-owned bookmark persistence requires restore/write-through/relaunch device proof; local BookmarkStore evidence is rejected"
        )
    }

    /// This runner has no safe chapter fixture and no device playback capture.
    /// A direct Host synth call would only prove provider reachability, not the
    /// Core-owned queue transaction, so it is deliberately not executed.
    private static func measureTTSQueue() async -> CapabilityResult {
        CapabilityResult(
            capability: "tts.queue",
            status: .blocked,
            error: "Core plan/queue/report/next/stop plus Host playback and physical-device evidence are required; Host reachability alone is rejected"
        )
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
