import Foundation

public enum ReaderCoreNativeEvidenceStatus: String, Codable, Sendable {
    case descriptorOnly
    case measuredPass
    case measuredFail
    case blocked
}

public enum ReaderCoreNativeEvidenceLayer: String, Codable, CaseIterable, Sendable {
    case wrapperSmoke = "wrapper_smoke"
    case appLaunch = "app_launch"
    case hostRequestLoop = "host_request_loop"
}

public struct ReaderCoreNativeEvidenceLayerResult: Codable, Equatable, Sendable {
    public let layer: ReaderCoreNativeEvidenceLayer
    public let status: ReaderCoreNativeEvidenceStatus
    public let liveExecutionClaimed: Bool
    public let summary: String
    public let observedArtifacts: [String]
    public let blockers: [String]

    public init(
        layer: ReaderCoreNativeEvidenceLayer,
        status: ReaderCoreNativeEvidenceStatus,
        liveExecutionClaimed: Bool,
        summary: String,
        observedArtifacts: [String] = [],
        blockers: [String] = []
    ) {
        self.layer = layer
        self.status = status
        self.liveExecutionClaimed = liveExecutionClaimed
        self.summary = summary
        self.observedArtifacts = observedArtifacts
        self.blockers = blockers
    }
}

public struct ReaderCoreNativeHostRequestLoopEvidence: Codable, Equatable, Sendable {
    public let requestId: UInt64
    public let completionRequestId: UInt64
    public let capability: String
    public let operationId: UInt64
    public let requestedURLScheme: String?
    public let requestedURLHost: String?
    public let resultBookCount: Int
    public let firstBookTitle: String?
    public let durationMs: Int

    public init(
        requestId: UInt64,
        completionRequestId: UInt64,
        capability: String,
        operationId: UInt64,
        requestedURLScheme: String?,
        requestedURLHost: String?,
        resultBookCount: Int,
        firstBookTitle: String?,
        durationMs: Int
    ) {
        self.requestId = requestId
        self.completionRequestId = completionRequestId
        self.capability = capability
        self.operationId = operationId
        self.requestedURLScheme = requestedURLScheme
        self.requestedURLHost = requestedURLHost
        self.resultBookCount = resultBookCount
        self.firstBookTitle = firstBookTitle
        self.durationMs = durationMs
    }
}

public struct ReaderCoreNativeAppEvidenceReport: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let generatedAt: Date
    public let processName: String
    public let bundleIdentifier: String?
    public let abiVersion: UInt32
    public let protocolVersion: UInt32?
    public let layers: [ReaderCoreNativeEvidenceLayerResult]
    public let hostRequestLoop: ReaderCoreNativeHostRequestLoopEvidence?
    public let notes: [String]

    public var hostRequestLoopPassed: Bool {
        layers.contains {
            $0.layer == .hostRequestLoop && $0.status == .measuredPass
        }
    }

    public init(
        schemaVersion: String,
        generatedAt: Date,
        processName: String,
        bundleIdentifier: String?,
        abiVersion: UInt32,
        protocolVersion: UInt32?,
        layers: [ReaderCoreNativeEvidenceLayerResult],
        hostRequestLoop: ReaderCoreNativeHostRequestLoopEvidence?,
        notes: [String]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.processName = processName
        self.bundleIdentifier = bundleIdentifier
        self.abiVersion = abiVersion
        self.protocolVersion = protocolVersion
        self.layers = layers
        self.hostRequestLoop = hostRequestLoop
        self.notes = notes
    }
}

enum ReaderCoreNativeEvidenceRunnerFailure: Error, CustomStringConvertible {
    case missingOperationId
    case unexpectedHostRequest(type: String, capability: String?)
    case unexpectedResult(type: String)
    case noParsedBooks

    var description: String {
        switch self {
        case .missingOperationId:
            return "host.request did not include operationId"
        case .unexpectedHostRequest(let type, let capability):
            return "expected host.request/http.execute, got type=\(type) capability=\(capability ?? "nil")"
        case .unexpectedResult(let type):
            return "expected result for original request, got type=\(type)"
        case .noParsedBooks:
            return "Core returned result but no parsed books"
        }
    }
}

public enum ReaderCoreNativeAppEvidenceRunner {
    public static let schemaVersion = "reader-ios.native-core-evidence.v1"

    public static func run(
        processName: String = ProcessInfo.processInfo.processName,
        bundleIdentifier: String? = Bundle.main.bundleIdentifier,
        appLaunchObserved: Bool = false,
        generatedAt: Date = Date(),
        timeout: TimeInterval = 5
    ) -> ReaderCoreNativeAppEvidenceReport {
        var layers = [
            ReaderCoreNativeEvidenceLayerResult(
                layer: .wrapperSmoke,
                status: .descriptorOnly,
                liveExecutionClaimed: false,
                summary: "Wrapper smoke remains covered by run-shell-smoke.sh, run-sim-smoke.sh, and adapter XCTest; it is not counted as App launch evidence."
            ),
            ReaderCoreNativeEvidenceLayerResult(
                layer: .appLaunch,
                status: appLaunchObserved ? .measuredPass : .descriptorOnly,
                liveExecutionClaimed: appLaunchObserved,
                summary: appLaunchObserved
                    ? "ReaderForIOSApp launched the Native Core evidence path in the app process."
                    : "This run did not claim ReaderForIOSApp launch."
            ),
        ]

        var protocolVersion: UInt32?
        var hostEvidence: ReaderCoreNativeHostRequestLoopEvidence?
        var notes = [
            "Native protocol/schema unchanged; this report only drives existing ABI/protocol commands from the iOS host side.",
            "Host request loop uses book.search -> http.execute host.request -> host.complete -> result.",
        ]

        do {
            let result = try runHostRequestLoop(timeout: timeout)
            protocolVersion = result.protocolVersion
            hostEvidence = result.evidence
            layers.append(
                ReaderCoreNativeEvidenceLayerResult(
                    layer: .hostRequestLoop,
                    status: .measuredPass,
                    liveExecutionClaimed: true,
                    summary: "Core emitted http.execute host.request and the iOS host completed it through host.complete.",
                    observedArtifacts: ["native_core_evidence.json"]
                )
            )
        } catch {
            layers.append(
                ReaderCoreNativeEvidenceLayerResult(
                    layer: .hostRequestLoop,
                    status: .measuredFail,
                    liveExecutionClaimed: true,
                    summary: "Host request loop failed before producing a resolved Core result.",
                    blockers: [String(describing: error)]
                )
            )
            notes.append("host_request_loop_error=\(String(describing: error))")
        }

        return ReaderCoreNativeAppEvidenceReport(
            schemaVersion: schemaVersion,
            generatedAt: generatedAt,
            processName: processName,
            bundleIdentifier: bundleIdentifier,
            abiVersion: ReaderCoreNativeRuntime.abiVersion,
            protocolVersion: protocolVersion,
            layers: layers,
            hostRequestLoop: hostEvidence,
            notes: notes
        )
    }

    public static func encodedData(_ report: ReaderCoreNativeAppEvidenceReport) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(report)
    }

    public static func write(_ report: ReaderCoreNativeAppEvidenceReport, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encodedData(report).write(to: url, options: .atomic)
    }

    private static func runHostRequestLoop(
        timeout: TimeInterval
    ) throws -> (protocolVersion: UInt32?, evidence: ReaderCoreNativeHostRequestLoopEvidence) {
        let startedAt = Date()
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }

        let info = try runtime.request(method: "core.info", requestId: 7_000, timeout: timeout)
        let protocolVersion = (info.data?["protocolVersion"] as? NSNumber)?.uint32Value

        let requestId: UInt64 = 7_010
        let completionRequestId: UInt64 = 7_011
        let requestedURL = "https://native-core-evidence.example.test/search?q=reader"
        let command = try JSONSerialization.data(withJSONObject: [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestId),
            "method": "book.search",
            "params": [
                "sourceId": "native-core-app-evidence",
                "searchRequest": [
                    "url": requestedURL,
                    "method": "GET",
                    "headers": ["accept": "application/json"],
                ],
                "source": [
                    "sourceId": "native-core-app-evidence",
                    "name": "Native Core App Evidence",
                    "baseUrl": "https://native-core-evidence.example.test",
                    "rules": [
                        "search": [["kind": "jsonPath", "path": "$.books[*]"]],
                    ],
                ] as [String: Any],
            ],
        ])
        try runtime.send(json: command)

        let hostRequest = try pollUntil(runtime: runtime, requestId: requestId, timeout: timeout)
        guard hostRequest.type == "host.request", hostRequest.capability == "http.execute" else {
            throw ReaderCoreNativeEvidenceRunnerFailure.unexpectedHostRequest(
                type: hostRequest.type,
                capability: hostRequest.capability
            )
        }
        guard let operationId = hostRequest.operationId else {
            throw ReaderCoreNativeEvidenceRunnerFailure.missingOperationId
        }

        let complete = try JSONSerialization.data(withJSONObject: [
            "protocolVersion": 1,
            "requestId": NSNumber(value: completionRequestId),
            "method": "host.complete",
            "params": [
                "operationId": NSNumber(value: operationId),
                "result": [
                    "status": 200,
                    "headers": ["content-type": "application/json"],
                    "body": """
                    {"books":[{"bookId":"app-host-1","title":"App Host Loop","author":"Reader iOS"}]}
                    """,
                ],
            ],
        ])
        try runtime.send(json: complete)

        let result = try pollUntil(runtime: runtime, requestId: requestId, timeout: timeout)
        guard result.type == "result" else {
            throw ReaderCoreNativeEvidenceRunnerFailure.unexpectedResult(type: result.type)
        }

        let books = result.data?["books"] as? [[String: Any]] ?? []
        guard !books.isEmpty else {
            throw ReaderCoreNativeEvidenceRunnerFailure.noParsedBooks
        }

        let url = URL(string: requestedURL)
        return (
            protocolVersion,
            ReaderCoreNativeHostRequestLoopEvidence(
                requestId: requestId,
                completionRequestId: completionRequestId,
                capability: hostRequest.capability ?? "",
                operationId: operationId,
                requestedURLScheme: url?.scheme,
                requestedURLHost: url?.host,
                resultBookCount: books.count,
                firstBookTitle: books.first?["title"] as? String,
                durationMs: Int(Date().timeIntervalSince(startedAt) * 1000)
            )
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
}
