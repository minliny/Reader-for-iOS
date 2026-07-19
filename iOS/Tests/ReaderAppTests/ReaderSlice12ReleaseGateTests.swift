import CryptoKit
import XCTest
@testable import ReaderShellValidation

final class ReaderSlice12ReleaseGateTests: XCTestCase {
    func testVersionDriftAndMissingEvidenceFailClosed() throws {
        let fixture = try makeFixture(consumerVersion: "2.5.1", manifestKind: nil)
        defer { try? FileManager.default.removeItem(at: fixture.root) }

        let report = ReaderSlice12ReleaseGate.evaluate(
            consumerLockURL: fixture.consumer,
            readerUIRootURL: fixture.uiRoot,
            coreArtifactURL: nil,
            platformEvidenceManifestURL: nil
        )

        XCTAssertFalse(report.isReady)
        XCTAssertEqual(report.readerUIVersion, "3.0.0")
        XCTAssertEqual(report.consumerVersion, "2.5.1")
        let codes = Set(report.blockers.map(\.code))
        XCTAssertTrue(codes.contains("SLICE12_CONSUMER_VERSION_MISMATCH"))
        XCTAssertTrue(codes.contains("SLICE12_CORE_ARTIFACT_MISSING"))
        XCTAssertTrue(codes.contains("SLICE12_PLATFORM_EVIDENCE_MISSING"))
    }

    func testTemplateAndPlannedRowsNeverBecomePassedEvidence() throws {
        let fixture = try makeFixture(consumerVersion: "3.0.0", manifestKind: "template")
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let core = fixture.root.appendingPathComponent("reader-core.a")
        try coreArtifactData().write(to: core)

        let report = ReaderSlice12ReleaseGate.evaluate(
            consumerLockURL: fixture.consumer,
            readerUIRootURL: fixture.uiRoot,
            readerUISourceSHA: String(repeating: "a", count: 40),
            coreArtifactURL: core,
            platformEvidenceManifestURL: fixture.evidence
        )

        XCTAssertFalse(report.isReady)
        XCTAssertTrue(report.blockers.contains { $0.code == "SLICE12_PLATFORM_EVIDENCE_TEMPLATE_ONLY" })
        XCTAssertNotNil(report.coreArtifactSHA256)
    }

    func testExecutionManifestCannotPromotePlannedRows() throws {
        let fixture = try makeFixture(consumerVersion: "3.0.0", manifestKind: "execution")
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let core = fixture.root.appendingPathComponent("reader-core.a")
        try coreArtifactData().write(to: core)
        try writePlannedExecutionEvidence(fixture: fixture, coreArtifact: core)

        let report = ReaderSlice12ReleaseGate.evaluate(
            consumerLockURL: fixture.consumer,
            readerUIRootURL: fixture.uiRoot,
            readerUISourceSHA: String(repeating: "a", count: 40),
            coreArtifactURL: core,
            platformEvidenceManifestURL: fixture.evidence
        )

        XCTAssertFalse(report.isReady)
        XCTAssertTrue(report.blockers.contains { $0.code == "SLICE12_DEPENDENCY_NOT_PASSED" })
    }

    func testExactExecutionIdentityAndRehashedArtifactsStillRequireExternalDeviceAttestation() throws {
        let fixture = try makeFixture(consumerVersion: "3.0.0", manifestKind: nil)
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let core = fixture.root.appendingPathComponent("reader-core.a")
        try coreArtifactData().write(to: core)
        try writePassingExecutionEvidence(fixture: fixture, coreArtifact: core)

        let report = ReaderSlice12ReleaseGate.evaluate(
            consumerLockURL: fixture.consumer,
            readerUIRootURL: fixture.uiRoot,
            readerUISourceSHA: String(repeating: "a", count: 40),
            coreArtifactURL: core,
            platformEvidenceManifestURL: fixture.evidence
        )

        XCTAssertFalse(report.isReady)
        XCTAssertTrue(report.blockers.contains { $0.code == "SLICE12_UNTRUSTED_DEVICE_EVIDENCE" })
    }

    func testTrustedDigestsDoNotAdmitMetadataFreeVideoOrHollowJSONReports() throws {
        let fixture = try makeFixture(consumerVersion: "3.0.0", manifestKind: nil)
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let core = fixture.root.appendingPathComponent("reader-core.a")
        try coreArtifactData().write(to: core)
        try writePassingExecutionEvidence(
            fixture: fixture,
            coreArtifact: core,
            contentMode: .hollow
        )

        let report = ReaderSlice12ReleaseGate.evaluate(
            consumerLockURL: fixture.consumer,
            readerUIRootURL: fixture.uiRoot,
            readerUISourceSHA: String(repeating: "a", count: 40),
            coreArtifactURL: core,
            platformEvidenceManifestURL: fixture.evidence,
            trustedPhysicalEvidenceSHA256s: try trustedPhysicalDigests(in: fixture.evidence)
        )

        XCTAssertFalse(report.isReady)
        XCTAssertFalse(report.blockers.contains { $0.code == "SLICE12_UNTRUSTED_DEVICE_EVIDENCE" })
        let invalidTestReports = report.blockers.filter { $0.code == "SLICE12_TEST_REPORT_CONTENT_INVALID" }
        XCTAssertGreaterThanOrEqual(invalidTestReports.count, 2)
        XCTAssertTrue(invalidTestReports.contains { $0.message.contains("slice-9-tests.json") })
        XCTAssertTrue(invalidTestReports.contains { $0.message.contains("slice-10-tests.json") })
        let invalidContent = report.blockers.filter { $0.code == "SLICE12_EVIDENCE_ARTIFACT_CONTENT_INVALID" }
        XCTAssertGreaterThanOrEqual(invalidContent.count, 7)
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-9-device.mov") })
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-10-device.mov") })
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-11-device.mov") })
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-12-complete-journey.mov") })
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-12-accessibility.json") })
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-12-performance.json") })
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-12-corpus.json") })
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-12-corpus-diff.json") })
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-12-release-lock.json") })
        XCTAssertTrue(invalidContent.contains { $0.message.contains("slice-12-rollback.json") })
    }

    func testTrustedStructurallyValidMinimalEvidenceCanPass() throws {
        let fixture = try makeFixture(consumerVersion: "3.0.0", manifestKind: nil)
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let core = fixture.root.appendingPathComponent("reader-core.a")
        try coreArtifactData().write(to: core)
        try writePassingExecutionEvidence(fixture: fixture, coreArtifact: core)

        let report = ReaderSlice12ReleaseGate.evaluate(
            consumerLockURL: fixture.consumer,
            readerUIRootURL: fixture.uiRoot,
            readerUISourceSHA: String(repeating: "a", count: 40),
            coreArtifactURL: core,
            platformEvidenceManifestURL: fixture.evidence,
            trustedPhysicalEvidenceSHA256s: try trustedPhysicalDigests(in: fixture.evidence)
        )

        XCTAssertTrue(report.isReady, report.blockers.map { "\($0.code): \($0.message)" }.joined(separator: "\n"))
    }

    func testEvidenceArtifactDriftFailsAfterManifestCreation() throws {
        let fixture = try makeFixture(consumerVersion: "3.0.0", manifestKind: nil)
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let core = fixture.root.appendingPathComponent("reader-core.a")
        try coreArtifactData().write(to: core)
        try writePassingExecutionEvidence(fixture: fixture, coreArtifact: core)
        try Data("tampered-performance".utf8).write(
            to: fixture.root.appendingPathComponent("evidence/slice-12-performance.json")
        )

        let report = ReaderSlice12ReleaseGate.evaluate(
            consumerLockURL: fixture.consumer,
            readerUIRootURL: fixture.uiRoot,
            readerUISourceSHA: String(repeating: "a", count: 40),
            coreArtifactURL: core,
            platformEvidenceManifestURL: fixture.evidence
        )

        XCTAssertFalse(report.isReady)
        XCTAssertTrue(report.blockers.contains {
            $0.code == "SLICE12_EVIDENCE_ARTIFACT_LENGTH_MISMATCH"
                || $0.code == "SLICE12_EVIDENCE_ARTIFACT_DIGEST_MISMATCH"
        })
        XCTAssertTrue(report.blockers.contains { $0.code == "SLICE12_EVIDENCE_ARTIFACT_CONTENT_INVALID" })
    }

    func testDeclaredSchemaCannotHideFractionalVersionOrExtraRootField() throws {
        let fixture = try makeFixture(consumerVersion: "3.0.0", manifestKind: "template")
        defer { try? FileManager.default.removeItem(at: fixture.root) }
        let core = fixture.root.appendingPathComponent("reader-core.a")
        try coreArtifactData().write(to: core)
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: fixture.evidence)) as? [String: Any]
        )
        object["schemaVersion"] = 1.5
        object["unexpected"] = true
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: fixture.evidence)

        let report = ReaderSlice12ReleaseGate.evaluate(
            consumerLockURL: fixture.consumer,
            readerUIRootURL: fixture.uiRoot,
            readerUISourceSHA: String(repeating: "a", count: 40),
            coreArtifactURL: core,
            platformEvidenceManifestURL: fixture.evidence
        )

        XCTAssertFalse(report.isReady)
        XCTAssertTrue(report.blockers.contains { $0.code == "SLICE12_PLATFORM_EVIDENCE_SCHEMA_MISMATCH" })

        object["schemaVersion"] = 1
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]).write(to: fixture.evidence)
        let extraFieldReport = ReaderSlice12ReleaseGate.evaluate(
            consumerLockURL: fixture.consumer,
            readerUIRootURL: fixture.uiRoot,
            readerUISourceSHA: String(repeating: "a", count: 40),
            coreArtifactURL: core,
            platformEvidenceManifestURL: fixture.evidence
        )
        XCTAssertTrue(extraFieldReport.blockers.contains { $0.code == "SLICE12_PLATFORM_EVIDENCE_SCHEMA_INVALID" })
    }

    private func makeFixture(
        consumerVersion: String,
        manifestKind: String?
    ) throws -> (root: URL, uiRoot: URL, consumer: URL, evidence: URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("slice12-release-\(UUID().uuidString)", isDirectory: true)
        let uiRoot = root.appendingPathComponent("Reader-UI", isDirectory: true)
        let contracts = uiRoot.appendingPathComponent("contracts", isDirectory: true)
        try FileManager.default.createDirectory(at: contracts, withIntermediateDirectories: true)
        let version = Data(#"{"version":"3.0.0"}"#.utf8)
        try version.write(to: contracts.appendingPathComponent("VERSION.json"))
        let tracked = Data("tracked".utf8)
        try tracked.write(to: uiRoot.appendingPathComponent("tracked.txt"))
        let manifestObject: [String: Any] = [
            "version": "3.0.0",
            "files": [[
                "path": "tracked.txt",
                "byteLength": tracked.count,
                "sha256": sha256(tracked),
            ]],
        ]
        let manifestData = try JSONSerialization.data(withJSONObject: manifestObject, options: [.sortedKeys])
        try manifestData.write(to: uiRoot.appendingPathComponent("UI_RELEASE_MANIFEST.json"))

        let manifestHash = sha256(manifestData)
        let consumer = root.appendingPathComponent("READER_UI_CONSUMER.json")
        try JSONSerialization.data(withJSONObject: [
            "host": "ios",
            "readerUiVersion": consumerVersion,
            "releaseIdentity": [
                "sourceSha": String(repeating: "a", count: 40),
                "manifestSha256": manifestHash,
                "releaseId": "\(String(repeating: "a", count: 40)):\(manifestHash)",
            ],
        ], options: [.sortedKeys]).write(to: consumer)

        let evidenceDirectory = root.appendingPathComponent("evidence", isDirectory: true)
        try FileManager.default.createDirectory(at: evidenceDirectory, withIntermediateDirectories: true)
        let evidence = evidenceDirectory.appendingPathComponent("manifest.json")
        if let manifestKind {
            let slices = Dictionary(uniqueKeysWithValues: (0...12).map { index in
                ("slice-\(index)", ["status": "planned", "evidence": []] as [String: Any])
            })
            var evidenceObject: [String: Any] = [
                "$schema": "contracts/platform-evidence-manifest.schema.json",
                "schemaVersion": 1,
                "manifestKind": manifestKind,
                "platform": "ios",
                "slices": slices,
            ]
            evidenceObject["releaseIdentity"] = manifestKind == "template"
                ? NSNull()
                : ["releaseId": "fixture"]
            try JSONSerialization.data(withJSONObject: evidenceObject, options: [.sortedKeys]).write(to: evidence)
        }
        return (root, uiRoot, consumer, evidence)
    }

    private func writePassingExecutionEvidence(
        fixture: (root: URL, uiRoot: URL, consumer: URL, evidence: URL),
        coreArtifact: URL,
        contentMode: EvidenceContentMode = .valid
    ) throws {
        var slices: [String: Any] = [:]
        for index in 0...8 {
            slices["slice-\(index)"] = plannedSlice(title: "Slice \(index)")
        }
        for index in 9...11 {
            let reportPath = "evidence/slice-\(index)-tests.json"
            let videoPath = "evidence/slice-\(index)-device.mov"
            let reportData = contentMode == .valid
                ? try testReportData(name: "slice-\(index)-tests")
                : try hollowTestReportData(index: index)
            try reportData.write(to: fixture.root.appendingPathComponent(reportPath))
            let videoData: Data
            if contentMode == .valid {
                videoData = credibleVideoData()
            } else {
                switch index {
                case 9: videoData = prefixOnlyVideoData()
                case 10: videoData = metadataFreeVideoData()
                default: videoData = movieWithoutTrackVideoData()
                }
            }
            try videoData.write(to: fixture.root.appendingPathComponent(videoPath))
            slices["slice-\(index)"] = passedSlice(
                title: "Slice \(index)",
                reportPath: reportPath,
                reportSHA: sha256(reportData),
                evidence: [try evidenceRecord(kind: "video", path: videoPath, root: fixture.root)]
            )
        }

        let slice12Report = "evidence/slice-12-tests.json"
        let slice12ReportData = contentMode == .valid
            ? try testReportData(name: "slice-12-tests")
            : try jsonData(["tests": []])
        try slice12ReportData.write(to: fixture.root.appendingPathComponent(slice12Report))
        let requiredArtifacts: [(kind: String, path: String)] = [
            ("video", "evidence/slice-12-complete-journey.mov"),
            ("accessibility", "evidence/slice-12-accessibility.json"),
            ("performance", "evidence/slice-12-performance.json"),
            ("corpus", "evidence/slice-12-corpus.json"),
            ("corpus-diff", "evidence/slice-12-corpus-diff.json"),
            ("release-lock", "evidence/slice-12-release-lock.json"),
            ("rollback", "evidence/slice-12-rollback.json"),
        ]
        let slice12Evidence = try requiredArtifacts.map { artifact -> [String: Any] in
            let data: Data
            if contentMode == .hollow {
                data = artifact.path.hasSuffix(".mov")
                    ? malformedNestedMovieVideoData()
                    : try hollowEvidenceData(kind: artifact.kind)
            } else if artifact.path.hasSuffix(".mov") {
                data = credibleVideoData()
            } else {
                data = try structuredEvidenceData(kind: artifact.kind)
            }
            try data.write(to: fixture.root.appendingPathComponent(artifact.path))
            return try evidenceRecord(kind: artifact.kind, path: artifact.path, root: fixture.root)
        }
        slices["slice-12"] = passedSlice(
            title: "Slice 12",
            reportPath: slice12Report,
            reportSHA: sha256(slice12ReportData),
            evidence: slice12Evidence
        )

        let manifestData = try Data(contentsOf: fixture.uiRoot.appendingPathComponent("UI_RELEASE_MANIFEST.json"))
        let consumerData = try Data(contentsOf: fixture.consumer)
        let evidenceObject: [String: Any] = [
            "$schema": "contracts/platform-evidence-manifest.schema.json",
            "schemaVersion": 1,
            "manifestKind": "execution",
            "platform": "ios",
            "releaseIdentity": [
                "contractVersion": "3.0.0",
                "sourceSha": String(repeating: "a", count: 40),
                "manifestSha": sha256(manifestData),
                "readerCoreArtifactSha": sha256(try Data(contentsOf: coreArtifact)),
                "consumerLockSha": sha256(consumerData),
            ],
            "slices": slices,
        ]
        try JSONSerialization.data(withJSONObject: evidenceObject, options: [.sortedKeys]).write(to: fixture.evidence)
    }

    private func writePlannedExecutionEvidence(
        fixture: (root: URL, uiRoot: URL, consumer: URL, evidence: URL),
        coreArtifact: URL
    ) throws {
        let slices = Dictionary(uniqueKeysWithValues: (0...12).map { index in
            ("slice-\(index)", plannedSlice(title: "Slice \(index)"))
        })
        let manifestData = try Data(contentsOf: fixture.uiRoot.appendingPathComponent("UI_RELEASE_MANIFEST.json"))
        let consumerData = try Data(contentsOf: fixture.consumer)
        let evidenceObject: [String: Any] = [
            "$schema": "contracts/platform-evidence-manifest.schema.json",
            "schemaVersion": 1,
            "manifestKind": "execution",
            "platform": "ios",
            "releaseIdentity": [
                "contractVersion": "3.0.0",
                "sourceSha": String(repeating: "a", count: 40),
                "manifestSha": sha256(manifestData),
                "readerCoreArtifactSha": sha256(try Data(contentsOf: coreArtifact)),
                "consumerLockSha": sha256(consumerData),
            ],
            "slices": slices,
        ]
        try JSONSerialization.data(withJSONObject: evidenceObject, options: [.sortedKeys]).write(to: fixture.evidence)
    }

    private func plannedSlice(title: String) -> [String: Any] {
        [
            "title": title,
            "status": "planned",
            "dependencies": [],
            "coverage": coverage(),
            "gates": ["contract": "pending", "generated": "pending", "coreHost": "pending", "nativeBuild": "pending", "device": "pending"],
            "tests": [],
            "evidence": [],
            "blockers": [],
            "notes": "registered",
        ]
    }

    private func passedSlice(
        title: String,
        reportPath: String,
        reportSHA: String,
        evidence: [[String: Any]]
    ) -> [String: Any] {
        [
            "title": title,
            "status": "passed",
            "dependencies": [],
            "coverage": coverage(),
            "gates": ["contract": "passed", "generated": "passed", "coreHost": "passed", "nativeBuild": "passed", "device": "passed"],
            "tests": [[
                "name": "fixture tests",
                "command": "swift test",
                "result": "passed",
                "reportPath": reportPath,
                "reportSha256": reportSHA,
            ]],
            "evidence": evidence,
            "blockers": [],
            "notes": "fixture",
        ]
    }

    private func evidenceRecord(kind: String, path: String, root: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: root.appendingPathComponent(path))
        return [
            "kind": kind,
            "path": path,
            "byteLength": data.count,
            "sha256": sha256(data),
            "targetKind": "physical-device",
            "deviceId": "fixture-iphone-001",
            "os": "iOS 26.0",
            "capturedAt": "2026-07-19T00:00:00Z",
            "result": "passed",
        ]
    }

    private func coverage() -> [String: Any] {
        [
            "capabilityRefs": ["fixture"],
            "routeIds": [],
            "eventTypes": [],
            "motionIds": [],
            "pageStates": [],
        ]
    }

    private func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func coreArtifactData() -> Data {
        Data("!<arch>\nreader-core-unit-fixture".utf8)
    }

    private func credibleVideoData() -> Data {
        let fileTypePayload = Data("qt  ".utf8)
            + Data([0x00, 0x00, 0x00, 0x00])
            + Data("qt  ".utf8)
        var movieHeader = Data(repeating: 0, count: 100)
        writeUInt32(1_000, to: &movieHeader, at: 12)
        writeUInt32(2, to: &movieHeader, at: 96)

        var trackHeader = Data(repeating: 0, count: 84)
        trackHeader[3] = 0x07
        writeUInt32(1, to: &trackHeader, at: 12)
        writeUInt32(1_920 << 16, to: &trackHeader, at: 76)
        writeUInt32(1_080 << 16, to: &trackHeader, at: 80)

        var mediaHeader = Data(repeating: 0, count: 24)
        writeUInt32(1_000, to: &mediaHeader, at: 12)
        var handler = Data(repeating: 0, count: 24)
        handler.replaceSubrange(8..<12, with: Data("vide".utf8))

        let media = isoBox(type: "mdia", payload:
            isoBox(type: "mdhd", payload: mediaHeader)
                + isoBox(type: "hdlr", payload: handler)
        )
        let track = isoBox(type: "trak", payload:
            isoBox(type: "tkhd", payload: trackHeader) + media
        )
        let movie = isoBox(type: "moov", payload:
            isoBox(type: "mvhd", payload: movieHeader) + track
        )
        let mediaPayload = Data([0x00, 0x00, 0x00, 0x01, 0x65, 0x88, 0x84, 0x00])
        return isoBox(type: "ftyp", payload: fileTypePayload)
            + movie
            + isoBox(type: "mdat", payload: mediaPayload)
    }

    private func prefixOnlyVideoData() -> Data {
        Data([0x00, 0x00, 0x00, 0x0c]) + Data("ftypqt  ".utf8)
    }

    private func metadataFreeVideoData() -> Data {
        let fileTypePayload = Data("qt  ".utf8)
            + Data([0x00, 0x00, 0x00, 0x00])
            + Data("qt  ".utf8)
        return isoBox(type: "ftyp", payload: fileTypePayload)
            + isoBox(type: "mdat", payload: Data([0xde, 0xad, 0xbe, 0xef]))
    }

    private func movieWithoutTrackVideoData() -> Data {
        var movieHeader = Data(repeating: 0, count: 100)
        writeUInt32(1_000, to: &movieHeader, at: 12)
        writeUInt32(1, to: &movieHeader, at: 96)
        return fileTypeBoxData()
            + isoBox(type: "moov", payload: isoBox(type: "mvhd", payload: movieHeader))
            + isoBox(type: "mdat", payload: Data([0xde, 0xad, 0xbe, 0xef]))
    }

    private func malformedNestedMovieVideoData() -> Data {
        let truncatedMovieHeader = Data([0x00, 0x00, 0x00, 0x20]) + Data("mvhd".utf8)
        return fileTypeBoxData()
            + isoBox(type: "moov", payload: truncatedMovieHeader)
            + isoBox(type: "mdat", payload: Data([0xde, 0xad, 0xbe, 0xef]))
    }

    private func fileTypeBoxData() -> Data {
        isoBox(
            type: "ftyp",
            payload: Data("qt  ".utf8)
                + Data([0x00, 0x00, 0x00, 0x00])
                + Data("qt  ".utf8)
        )
    }

    private func isoBox(type: String, payload: Data) -> Data {
        let size = UInt32(8 + payload.count)
        return Data([
            UInt8((size >> 24) & 0xff),
            UInt8((size >> 16) & 0xff),
            UInt8((size >> 8) & 0xff),
            UInt8(size & 0xff),
        ]) + Data(type.utf8) + payload
    }

    private func writeUInt32(_ value: UInt32, to data: inout Data, at offset: Int) {
        data.replaceSubrange(offset..<(offset + 4), with: Data([
            UInt8((value >> 24) & 0xff),
            UInt8((value >> 16) & 0xff),
            UInt8((value >> 8) & 0xff),
            UInt8(value & 0xff),
        ]))
    }

    private func structuredEvidenceData(kind: String) throws -> Data {
        let object: [String: Any]
        switch kind {
        case "accessibility":
            object = [
                "schemaVersion": 1,
                "kind": kind,
                "result": "passed",
                "assistiveTechnology": "VoiceOver",
                "screenCount": 1,
                "checks": [[
                    "id": "reader-focus-order",
                    "name": "reader controls expose a stable focus order",
                    "result": "passed",
                ]],
            ]
        case "corpus":
            object = [
                "schemaVersion": 1,
                "kind": kind,
                "result": "passed",
                "corpusId": "slice-12-same-corpus-v1",
                "caseCount": 1,
                "cases": [[
                    "id": "epub-basic-001",
                    "inputSha256": String(repeating: "e", count: 64),
                ]],
            ]
        case "performance":
            object = [
                "schemaVersion": 1,
                "kind": kind,
                "result": "passed",
                "metrics": [[
                    "name": "reader-frame-time-p95",
                    "unit": "ms",
                    "value": 12.5,
                    "threshold": 16.7,
                    "comparison": "<=",
                    "result": "passed",
                ]],
            ]
        case "corpus-diff":
            object = [
                "schemaVersion": 1,
                "kind": kind,
                "result": "passed",
                "corpusId": "slice-12-same-corpus-v1",
                "baselineSha256": String(repeating: "b", count: 64),
                "candidateSha256": String(repeating: "c", count: 64),
                "totalCases": 1,
                "changedCases": 0,
                "differences": [],
            ]
        case "release-lock":
            let sourceSHA = String(repeating: "a", count: 40)
            let manifestSHA = String(repeating: "b", count: 64)
            object = [
                "schemaVersion": 1,
                "kind": kind,
                "result": "passed",
                "contractVersion": "3.0.0",
                "sourceSha": sourceSHA,
                "manifestSha": manifestSHA,
                "readerCoreArtifactSha": String(repeating: "c", count: 64),
                "consumerLockSha": String(repeating: "d", count: 64),
                "releaseId": "\(sourceSHA):\(manifestSHA)",
            ]
        case "rollback":
            object = [
                "schemaVersion": 1,
                "kind": kind,
                "result": "passed",
                "fromVersion": "3.0.0",
                "toVersion": "2.5.1",
                "steps": [[
                    "name": "install previous signed build and reopen a book",
                    "result": "passed",
                ]],
            ]
        default:
            throw NSError(domain: "ReaderSlice12ReleaseGateTests", code: 1)
        }
        return try jsonData(object)
    }

    private func hollowEvidenceData(kind: String) throws -> Data {
        switch kind {
        case "accessibility": return try jsonData(["x": 1])
        case "corpus": return try jsonData([])
        case "performance": return Data(#""passed""#.utf8)
        case "corpus-diff": return try jsonData([])
        case "release-lock": return try jsonData([:])
        case "rollback": return try jsonData(["kind": kind])
        default: throw NSError(domain: "ReaderSlice12ReleaseGateTests", code: 2)
        }
    }

    private func testReportData(name: String) throws -> Data {
        try jsonData([
            "schemaVersion": 1,
            "reportKind": "test-report",
            "result": "passed",
            "summary": ["total": 1, "passed": 1, "failed": 0, "skipped": 0],
            "tests": [["name": name, "result": "passed"]],
        ])
    }

    private func hollowTestReportData(index: Int) throws -> Data {
        switch index {
        case 9: return try jsonData(["x": 1])
        case 10: return try jsonData([])
        default: return Data(#""passed""#.utf8)
        }
    }

    private func jsonData(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
    }

    private func trustedPhysicalDigests(in manifestURL: URL) throws -> Set<String> {
        let manifest = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any]
        )
        let slices = try XCTUnwrap(manifest["slices"] as? [String: Any])
        var digests: Set<String> = []
        for rawSlice in slices.values {
            guard let slice = rawSlice as? [String: Any],
                  let evidence = slice["evidence"] as? [[String: Any]] else { continue }
            for artifact in evidence where artifact["targetKind"] as? String == "physical-device" {
                if let digest = artifact["sha256"] as? String { digests.insert(digest) }
            }
        }
        return digests
    }

    private enum EvidenceContentMode {
        case valid
        case hollow
    }
}
