import CryptoKit
import CoreFoundation
import Foundation

public struct ReaderSlice12ReleaseFinding: Equatable, Sendable {
    public let code: String
    public let message: String

    public init(code: String, message: String) {
        self.code = code
        self.message = message
    }
}

public struct ReaderSlice12ReleaseReport: Equatable, Sendable {
    public let readerUIVersion: String?
    public let consumerVersion: String?
    public let manifestSHA256: String?
    public let coreArtifactSHA256: String?
    public let blockers: [ReaderSlice12ReleaseFinding]

    public var isReady: Bool { blockers.isEmpty }
}

/// Read-only, fail-closed Slice 12 release preflight.
///
/// This verifier never updates the consumer lock and never converts a template
/// or `planned` evidence row into `passed`. It rehashes the Reader-UI manifest
/// inventory from disk, verifies the iOS lock identity, requires a Core
/// artifact, and requires actual iOS Slice 9-12 evidence rows to be passed.
/// Physical-device evidence is trusted only when its digest is supplied by an
/// external CI/device attestation channel; the manifest cannot attest itself.
public enum ReaderSlice12ReleaseGate {
    public static func evaluate(
        consumerLockURL: URL,
        readerUIRootURL: URL,
        readerUISourceSHA: String? = nil,
        coreArtifactURL: URL?,
        platformEvidenceManifestURL: URL?,
        trustedPhysicalEvidenceSHA256s: Set<String> = []
    ) -> ReaderSlice12ReleaseReport {
        var blockers: [ReaderSlice12ReleaseFinding] = []
        let consumerData = try? Data(contentsOf: consumerLockURL)
        let consumerSHA = consumerData.map(sha256)
        let consumer = readObject(consumerLockURL, code: "SLICE12_CONSUMER_LOCK_INVALID", blockers: &blockers)
        let versionURL = readerUIRootURL.appendingPathComponent("contracts/VERSION.json")
        let manifestURL = readerUIRootURL.appendingPathComponent("UI_RELEASE_MANIFEST.json")
        let version = readObject(versionURL, code: "SLICE12_UI_VERSION_INVALID", blockers: &blockers)
        let manifest = readObject(manifestURL, code: "SLICE12_UI_MANIFEST_INVALID", blockers: &blockers)

        let readerUIVersion = version?["version"] as? String
        let consumerVersion = consumer?["readerUiVersion"] as? String
        if readerUIVersion == nil {
            blockers.append(.init(code: "SLICE12_UI_VERSION_MISSING", message: "Reader-UI VERSION.json has no version"))
        }
        if consumerVersion == nil {
            blockers.append(.init(code: "SLICE12_CONSUMER_VERSION_MISSING", message: "iOS consumer lock has no readerUiVersion"))
        }
        if let readerUIVersion, let consumerVersion, readerUIVersion != consumerVersion {
            blockers.append(.init(
                code: "SLICE12_CONSUMER_VERSION_MISMATCH",
                message: "iOS lock \(consumerVersion) does not match Reader-UI \(readerUIVersion)"
            ))
        }
        if let manifestVersion = manifest?["version"] as? String,
           let readerUIVersion,
           manifestVersion != readerUIVersion {
            blockers.append(.init(
                code: "SLICE12_UI_MANIFEST_VERSION_MISMATCH",
                message: "UI manifest \(manifestVersion) does not match VERSION \(readerUIVersion)"
            ))
        }

        let normalizedSourceSHA = readerUISourceSHA?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalizedSourceSHA?.range(of: "^[0-9a-f]{40}([0-9a-f]{24})?$", options: .regularExpression) == nil {
            blockers.append(.init(
                code: "SLICE12_UI_SOURCE_SHA_MISSING",
                message: "an exact 40- or 64-character Reader-UI source SHA is required"
            ))
        }

        let manifestData = try? Data(contentsOf: manifestURL)
        let manifestSHA = manifestData.map(sha256)
        let releaseIdentity = consumer?["releaseIdentity"] as? [String: Any]
        if let normalizedSourceSHA {
            let lockedSourceSHA = releaseIdentity?["sourceSha"] as? String
            if lockedSourceSHA?.lowercased() != normalizedSourceSHA {
                blockers.append(.init(
                    code: "SLICE12_CONSUMER_SOURCE_SHA_MISMATCH",
                    message: "consumer sourceSha does not match the verified Reader-UI source SHA"
                ))
            }
        }
        if let expected = releaseIdentity?["manifestSha256"] as? String,
           let manifestSHA,
           expected.lowercased() != manifestSHA {
            blockers.append(.init(
                code: "SLICE12_CONSUMER_MANIFEST_DIGEST_MISMATCH",
                message: "consumer manifest digest does not match UI_RELEASE_MANIFEST.json"
            ))
        } else if releaseIdentity?["manifestSha256"] as? String == nil {
            blockers.append(.init(
                code: "SLICE12_CONSUMER_RELEASE_IDENTITY_MISSING",
                message: "consumer lock has no immutable manifest digest"
            ))
        }
        if let sourceSHA = releaseIdentity?["sourceSha"] as? String,
           let expectedManifest = releaseIdentity?["manifestSha256"] as? String,
           let releaseID = releaseIdentity?["releaseId"] as? String {
            if releaseID != "\(sourceSHA):\(expectedManifest)" {
                blockers.append(.init(
                    code: "SLICE12_CONSUMER_RELEASE_ID_INVALID",
                    message: "releaseId is not sourceSha:manifestSha256"
                ))
            }
        } else {
            blockers.append(.init(
                code: "SLICE12_CONSUMER_RELEASE_ID_INVALID",
                message: "consumer release identity is incomplete"
            ))
        }

        verifyManifestInventory(manifest, root: readerUIRootURL, blockers: &blockers)

        let coreDigest: String?
        if let coreArtifactURL,
           let data = try? Data(contentsOf: coreArtifactURL),
           isReaderCoreBinaryArtifact(data) {
            coreDigest = sha256(data)
        } else {
            coreDigest = nil
            blockers.append(.init(
                code: "SLICE12_CORE_ARTIFACT_MISSING",
                message: "an exact Reader-Core static archive or Mach-O artifact is required"
            ))
        }

        verifyPlatformEvidence(
            platformEvidenceManifestURL,
            expectedContractVersion: readerUIVersion,
            expectedSourceSHA: normalizedSourceSHA,
            expectedManifestSHA: manifestSHA,
            expectedCoreArtifactSHA: coreDigest,
            expectedConsumerLockSHA: consumerSHA,
            trustedPhysicalEvidenceSHA256s: Set(trustedPhysicalEvidenceSHA256s.map { $0.lowercased() }),
            blockers: &blockers
        )
        return ReaderSlice12ReleaseReport(
            readerUIVersion: readerUIVersion,
            consumerVersion: consumerVersion,
            manifestSHA256: manifestSHA,
            coreArtifactSHA256: coreDigest,
            blockers: blockers
        )
    }

    private static func verifyManifestInventory(
        _ manifest: [String: Any]?,
        root: URL,
        blockers: inout [ReaderSlice12ReleaseFinding]
    ) {
        guard let rows = manifest?["files"] as? [[String: Any]], !rows.isEmpty else {
            blockers.append(.init(code: "SLICE12_UI_MANIFEST_INVENTORY_MISSING", message: "UI manifest has no file inventory"))
            return
        }
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = resolvedRoot.path
        for row in rows {
            guard let path = row["path"] as? String,
                  let expectedHash = row["sha256"] as? String,
                  isSHA256(expectedHash),
                  let expectedLength = strictUInt64(row["byteLength"]) else {
                blockers.append(.init(code: "SLICE12_UI_MANIFEST_ENTRY_INVALID", message: "manifest entry has an invalid shape"))
                continue
            }
            guard isSafePath(path) else {
                blockers.append(.init(code: "SLICE12_UI_MANIFEST_PATH_ESCAPE", message: "manifest path is unsafe: \(path)"))
                continue
            }
            let fileURL = resolvedRoot.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
            guard fileURL.path == rootPath || fileURL.path.hasPrefix(rootPath + "/") else {
                blockers.append(.init(code: "SLICE12_UI_MANIFEST_PATH_ESCAPE", message: "manifest path escapes Reader-UI root: \(path)"))
                continue
            }
            guard let data = try? Data(contentsOf: fileURL) else {
                blockers.append(.init(code: "SLICE12_UI_MANIFEST_FILE_MISSING", message: "manifest file is missing: \(path)"))
                continue
            }
            if UInt64(data.count) != expectedLength || sha256(data) != expectedHash.lowercased() {
                blockers.append(.init(code: "SLICE12_UI_MANIFEST_FILE_DRIFT", message: "manifest file digest/length drift: \(path)"))
            }
        }
    }

    private static func verifyPlatformEvidence(
        _ url: URL?,
        expectedContractVersion: String?,
        expectedSourceSHA: String?,
        expectedManifestSHA: String?,
        expectedCoreArtifactSHA: String?,
        expectedConsumerLockSHA: String?,
        trustedPhysicalEvidenceSHA256s: Set<String>,
        blockers: inout [ReaderSlice12ReleaseFinding]
    ) {
        guard let url else {
            blockers.append(.init(code: "SLICE12_PLATFORM_EVIDENCE_MISSING", message: "iOS platform evidence manifest is required"))
            return
        }
        guard let manifest = readObject(url, code: "SLICE12_PLATFORM_EVIDENCE_INVALID", blockers: &blockers) else { return }
        guard manifest["$schema"] as? String == "contracts/platform-evidence-manifest.schema.json",
              strictInteger(manifest["schemaVersion"]) == 1 else {
            blockers.append(.init(
                code: "SLICE12_PLATFORM_EVIDENCE_SCHEMA_MISMATCH",
                message: "platform evidence does not declare the canonical schema/version"
            ))
            return
        }
        let schemaFailures = validateCanonicalPlatformEvidenceManifest(manifest)
        if !schemaFailures.isEmpty {
            blockers.append(.init(
                code: "SLICE12_PLATFORM_EVIDENCE_SCHEMA_INVALID",
                message: schemaFailures.prefix(8).joined(separator: "; ")
            ))
        }
        guard manifest["manifestKind"] as? String == "execution" else {
            blockers.append(.init(code: "SLICE12_PLATFORM_EVIDENCE_TEMPLATE_ONLY", message: "template evidence cannot pass a release gate"))
            return
        }
        guard schemaFailures.isEmpty else { return }
        guard manifest["platform"] as? String == "ios" else {
            blockers.append(.init(code: "SLICE12_PLATFORM_EVIDENCE_WRONG_HOST", message: "platform evidence is not for iOS"))
            return
        }
        guard let releaseIdentity = manifest["releaseIdentity"] as? [String: Any] else {
            blockers.append(.init(code: "SLICE12_PLATFORM_RELEASE_IDENTITY_MISSING", message: "evidence has no release identity"))
            return
        }
        verifyReleaseIdentity(
            releaseIdentity,
            expectedContractVersion: expectedContractVersion,
            expectedSourceSHA: expectedSourceSHA,
            expectedManifestSHA: expectedManifestSHA,
            expectedCoreArtifactSHA: expectedCoreArtifactSHA,
            expectedConsumerLockSHA: expectedConsumerLockSHA,
            blockers: &blockers
        )
        guard let slices = manifest["slices"] as? [String: Any] else {
            blockers.append(.init(code: "SLICE12_PLATFORM_SLICES_MISSING", message: "evidence has no slice map"))
            return
        }
        let registeredSliceIDs = Set(slices.keys)
        let requiredSliceIDs = Set((0...12).map { "slice-\($0)" })
        for missing in requiredSliceIDs.subtracting(registeredSliceIDs).sorted() {
            blockers.append(.init(
                code: "SLICE12_PLATFORM_SLICE_REGISTRATION_MISSING",
                message: "\(missing) is not registered"
            ))
        }

        let manifestDirectory = url.deletingLastPathComponent().standardizedFileURL
        // Canonical platform manifests live at `<repo>/evidence/manifest.json`
        // and their safe paths are repository-relative (`evidence/...`). Test
        // and embedders may place a standalone manifest elsewhere, in which
        // case paths are relative to that manifest directory.
        let artifactRoot = manifestDirectory.lastPathComponent == "evidence"
            ? manifestDirectory.deletingLastPathComponent().standardizedFileURL
            : manifestDirectory
        for slice in ["slice-9", "slice-10", "slice-11", "slice-12"] {
            guard let row = slices[slice] as? [String: Any] else {
                blockers.append(.init(code: "SLICE12_DEPENDENCY_NOT_PASSED", message: "\(slice) is missing, not passed"))
                continue
            }
            let status = row["status"] as? String
            if status != "passed" {
                blockers.append(.init(
                    code: "SLICE12_DEPENDENCY_NOT_PASSED",
                    message: "\(slice) is \(status ?? "missing"), not passed"
                ))
                continue
            }
            verifyPassedSlice(
                slice,
                row: row,
                artifactRoot: artifactRoot,
                trustedPhysicalEvidenceSHA256s: trustedPhysicalEvidenceSHA256s,
                blockers: &blockers
            )
        }
    }

    private static func verifyReleaseIdentity(
        _ identity: [String: Any],
        expectedContractVersion: String?,
        expectedSourceSHA: String?,
        expectedManifestSHA: String?,
        expectedCoreArtifactSHA: String?,
        expectedConsumerLockSHA: String?,
        blockers: inout [ReaderSlice12ReleaseFinding]
    ) {
        let fields: [(name: String, expected: String?)] = [
            ("contractVersion", expectedContractVersion),
            ("sourceSha", expectedSourceSHA),
            ("manifestSha", expectedManifestSHA),
            ("readerCoreArtifactSha", expectedCoreArtifactSHA),
            ("consumerLockSha", expectedConsumerLockSHA),
        ]
        for field in fields {
            guard let expected = field.expected, !expected.isEmpty,
                  let actual = identity[field.name] as? String,
                  actual.lowercased() == expected.lowercased() else {
                blockers.append(.init(
                    code: "SLICE12_PLATFORM_RELEASE_IDENTITY_MISMATCH",
                    message: "platform evidence releaseIdentity.\(field.name) does not match the verified release input"
                ))
                continue
            }
        }
    }

    private static func verifyPassedSlice(
        _ slice: String,
        row: [String: Any],
        artifactRoot: URL,
        trustedPhysicalEvidenceSHA256s: Set<String>,
        blockers: inout [ReaderSlice12ReleaseFinding]
    ) {
        if let declaredBlockers = row["blockers"] as? [Any], !declaredBlockers.isEmpty {
            blockers.append(.init(code: "SLICE12_PASSED_WITH_BLOCKERS", message: "\(slice) is passed but still declares blockers"))
        }
        guard let gates = row["gates"] as? [String: Any],
              ["contract", "generated", "coreHost", "nativeBuild", "device"].allSatisfy({ key in
                  guard let value = gates[key] as? String else { return false }
                  return value == "passed" || value == "not-required"
              }) else {
            blockers.append(.init(code: "SLICE12_PASSED_WITH_OPEN_GATE", message: "\(slice) has a pending or malformed gate"))
            return
        }

        guard let tests = row["tests"] as? [[String: Any]], !tests.isEmpty else {
            blockers.append(.init(code: "SLICE12_PASSED_WITHOUT_TEST_REPORT", message: "\(slice) is passed without test reports"))
            return
        }
        for test in tests {
            guard test["result"] as? String == "passed",
                  let path = test["reportPath"] as? String,
                  let expectedSHA = test["reportSha256"] as? String else {
                blockers.append(.init(code: "SLICE12_TEST_REPORT_INVALID", message: "\(slice) has a failed or malformed test report"))
                continue
            }
            verifyArtifact(
                path: path,
                expectedSHA: expectedSHA,
                expectedLength: nil,
                root: artifactRoot,
                contentKind: .testReport,
                codePrefix: "SLICE12_TEST_REPORT",
                blockers: &blockers
            )
        }

        guard let evidence = row["evidence"] as? [[String: Any]], !evidence.isEmpty else {
            blockers.append(.init(code: "SLICE12_PASSED_WITHOUT_ARTIFACT", message: "\(slice) is passed without evidence artifacts"))
            return
        }
        for artifact in evidence {
            guard artifact["result"] as? String == "passed",
                  let path = artifact["path"] as? String,
                  let expectedSHA = artifact["sha256"] as? String,
                  let expectedLength = (artifact["byteLength"] as? NSNumber)?.uint64Value else {
                blockers.append(.init(code: "SLICE12_EVIDENCE_ARTIFACT_INVALID", message: "\(slice) has a failed or malformed evidence artifact"))
                continue
            }
            verifyEvidenceMetadata(artifact, slice: slice, path: path, blockers: &blockers)
            verifyArtifact(
                path: path,
                expectedSHA: expectedSHA,
                expectedLength: expectedLength,
                root: artifactRoot,
                contentKind: .evidence(artifact["kind"] as? String ?? ""),
                codePrefix: "SLICE12_EVIDENCE_ARTIFACT",
                blockers: &blockers
            )
            if artifact["targetKind"] as? String == "physical-device",
               !trustedPhysicalEvidenceSHA256s.contains(expectedSHA.lowercased()) {
                blockers.append(.init(
                    code: "SLICE12_UNTRUSTED_DEVICE_EVIDENCE",
                    message: "\(slice) physical-device artifact lacks external digest attestation: \(path)"
                ))
            }
        }

        if ["slice-9", "slice-10", "slice-11"].contains(slice),
           !evidence.contains(where: { $0["targetKind"] as? String == "physical-device" }) {
            blockers.append(.init(code: "SLICE12_DEPENDENCY_DEVICE_SMOKE_MISSING", message: "\(slice) has no physical-device smoke artifact"))
        }
        if slice == "slice-12" {
            let kinds = Set(evidence.compactMap { $0["kind"] as? String })
            for requiredKind in ["accessibility", "performance", "corpus-diff", "release-lock", "rollback"] where !kinds.contains(requiredKind) {
                blockers.append(.init(code: "SLICE12_REQUIRED_ARTIFACT_KIND_MISSING", message: "slice-12 has no \(requiredKind) artifact"))
            }
            let hasPhysicalJourney = evidence.contains {
                $0["kind"] as? String == "video" && $0["targetKind"] as? String == "physical-device"
            }
            if !hasPhysicalJourney {
                blockers.append(.init(code: "SLICE12_COMPLETE_DEVICE_JOURNEY_MISSING", message: "slice-12 has no physical-device complete-journey video"))
            }
        }
    }

    private static func verifyEvidenceMetadata(
        _ artifact: [String: Any],
        slice: String,
        path: String,
        blockers: inout [ReaderSlice12ReleaseFinding]
    ) {
        guard let targetKind = artifact["targetKind"] as? String,
              ["unit-runner", "simulator", "physical-device", "manual-observation"].contains(targetKind),
              let capturedAt = artifact["capturedAt"] as? String,
              ISO8601DateFormatter().date(from: capturedAt) != nil else {
            blockers.append(.init(
                code: "SLICE12_EVIDENCE_METADATA_INVALID",
                message: "\(slice) evidence has invalid targetKind/capturedAt: \(path)"
            ))
            return
        }
        if targetKind == "physical-device" || targetKind == "manual-observation" {
            let deviceID = (artifact["deviceId"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let os = (artifact["os"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let placeholders: Set<String> = ["unknown", "none", "null", "mock", "fake", "test", "device", "simulator", "emulator"]
            if deviceID.count < 4 || placeholders.contains(deviceID.lowercased()) || os.isEmpty {
                blockers.append(.init(
                    code: "SLICE12_DEVICE_IDENTITY_INVALID",
                    message: "\(slice) physical/manual evidence lacks a credible device identity: \(path)"
                ))
            }
        }
        if targetKind == "manual-observation",
           (artifact["operator"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            blockers.append(.init(
                code: "SLICE12_MANUAL_OPERATOR_MISSING",
                message: "\(slice) manual evidence has no operator: \(path)"
            ))
        }
    }

    private static func verifyArtifact(
        path: String,
        expectedSHA: String,
        expectedLength: UInt64?,
        root: URL,
        contentKind: ArtifactContentKind,
        codePrefix: String,
        blockers: inout [ReaderSlice12ReleaseFinding]
    ) {
        guard isSafePath(path), isSHA256(expectedSHA) else {
            blockers.append(.init(code: "\(codePrefix)_METADATA_INVALID", message: "artifact path or digest is malformed: \(path)"))
            return
        }
        let resolvedRoot = root.standardizedFileURL.resolvingSymlinksInPath()
        let rootPath = resolvedRoot.path
        let url = resolvedRoot.appendingPathComponent(path).standardizedFileURL.resolvingSymlinksInPath()
        guard url.path == rootPath || url.path.hasPrefix(rootPath + "/") else {
            blockers.append(.init(code: "\(codePrefix)_PATH_ESCAPE", message: "artifact path escapes evidence root: \(path)"))
            return
        }
        guard let data = try? Data(contentsOf: url), !data.isEmpty else {
            blockers.append(.init(code: "\(codePrefix)_MISSING", message: "artifact is missing or empty: \(path)"))
            return
        }
        if let expectedLength, UInt64(data.count) != expectedLength {
            blockers.append(.init(code: "\(codePrefix)_LENGTH_MISMATCH", message: "artifact byte length drift: \(path)"))
        }
        if sha256(data) != expectedSHA.lowercased() {
            blockers.append(.init(code: "\(codePrefix)_DIGEST_MISMATCH", message: "artifact digest drift: \(path)"))
        }
        if !hasCredibleArtifactContent(data, path: path, kind: contentKind) {
            blockers.append(.init(
                code: "\(codePrefix)_CONTENT_INVALID",
                message: "artifact bytes do not match a supported non-empty report/media format: \(path)"
            ))
        }
    }

    private enum ArtifactContentKind {
        case testReport
        case evidence(String)
    }

    /// Manual admission for the frozen canonical schema. Foundation does not
    /// ship a JSON-Schema evaluator, so the release binary validates every
    /// security-relevant constraint instead of trusting a `$schema` string.
    private static func validateCanonicalPlatformEvidenceManifest(
        _ manifest: [String: Any]
    ) -> [String] {
        var failures: [String] = []
        exactKeys(
            manifest,
            allowed: ["$schema", "schemaVersion", "manifestKind", "platform", "releaseIdentity", "slices"],
            path: "$",
            failures: &failures
        )
        guard manifest["$schema"] as? String == "contracts/platform-evidence-manifest.schema.json",
              strictInteger(manifest["schemaVersion"]) == 1,
              let kind = manifest["manifestKind"] as? String,
              ["template", "execution"].contains(kind),
              let platform = manifest["platform"] as? String,
              ["ios", "android", "harmonyos"].contains(platform) else {
            failures.append("root declaration is malformed")
            return failures
        }

        if kind == "template" {
            if !(manifest["releaseIdentity"] is NSNull) {
                failures.append("template releaseIdentity must be null")
            }
        } else if let identity = manifest["releaseIdentity"] as? [String: Any] {
            validateReleaseIdentitySchema(identity, failures: &failures)
        } else {
            failures.append("execution releaseIdentity must be an object")
        }

        guard let slices = manifest["slices"] as? [String: Any] else {
            failures.append("slices must be an object")
            return failures
        }
        let sliceIDs = Set((0...12).map { "slice-\($0)" })
        exactKeys(slices, allowed: sliceIDs, path: "$.slices", failures: &failures)
        for sliceID in sliceIDs.sorted() {
            guard let row = slices[sliceID] as? [String: Any] else {
                failures.append("$.slices.\(sliceID) must be an object")
                continue
            }
            validateSliceSchema(row, id: sliceID, template: kind == "template", failures: &failures)
        }
        return failures
    }

    private static func validateReleaseIdentitySchema(
        _ identity: [String: Any],
        failures: inout [String]
    ) {
        let path = "$.releaseIdentity"
        exactKeys(
            identity,
            allowed: ["contractVersion", "sourceSha", "manifestSha", "readerCoreArtifactSha", "consumerLockSha"],
            path: path,
            failures: &failures
        )
        guard let version = identity["contractVersion"] as? String,
              matches(version, "^[0-9]+\\.[0-9]+\\.[0-9]+$") else {
            failures.append("\(path).contractVersion is invalid")
            return
        }
        guard let sourceSHA = identity["sourceSha"] as? String,
              isSourceSHA(sourceSHA) else {
            failures.append("\(path).sourceSha is invalid")
            return
        }
        for key in ["manifestSha", "readerCoreArtifactSha", "consumerLockSha"] {
            if !isSHA256(identity[key] as? String ?? "") {
                failures.append("\(path).\(key) is invalid")
            }
        }
    }

    private static func validateSliceSchema(
        _ row: [String: Any],
        id: String,
        template: Bool,
        failures: inout [String]
    ) {
        let path = "$.slices.\(id)"
        exactKeys(
            row,
            allowed: ["title", "status", "dependencies", "coverage", "gates", "tests", "evidence", "blockers", "notes"],
            path: path,
            failures: &failures
        )
        guard validString(row["title"], min: 1, max: 256),
              let status = row["status"] as? String,
              ["planned", "in-progress", "blocked", "passed"].contains(status),
              validString(row["notes"], min: 0, max: 4_096) else {
            failures.append("\(path) title/status/notes is malformed")
            return
        }
        guard let dependencies = uniqueStringArray(row["dependencies"], allowEmpty: true),
              dependencies.allSatisfy({ matches($0, "^slice-(?:[0-9]|1[0-2])$") }) else {
            failures.append("\(path).dependencies is invalid")
            return
        }
        guard let coverage = row["coverage"] as? [String: Any] else {
            failures.append("\(path).coverage must be an object")
            return
        }
        let coverageKeys = ["capabilityRefs", "routeIds", "eventTypes", "motionIds", "pageStates"]
        exactKeys(coverage, allowed: Set(coverageKeys), path: "\(path).coverage", failures: &failures)
        var capabilityCount = 0
        for key in coverageKeys {
            guard let values = uniqueStringArray(coverage[key], allowEmpty: true),
                  values.allSatisfy({ !$0.isEmpty }) else {
                failures.append("\(path).coverage.\(key) is invalid")
                continue
            }
            if key == "capabilityRefs" { capabilityCount = values.count }
        }

        guard let gates = row["gates"] as? [String: Any] else {
            failures.append("\(path).gates must be an object")
            return
        }
        let gateKeys = ["contract", "generated", "coreHost", "nativeBuild", "device"]
        exactKeys(gates, allowed: Set(gateKeys), path: "\(path).gates", failures: &failures)
        for key in gateKeys where !["pending", "passed", "not-required"].contains(gates[key] as? String ?? "") {
            failures.append("\(path).gates.\(key) is invalid")
        }

        guard let tests = row["tests"] as? [[String: Any]],
              let evidence = row["evidence"] as? [[String: Any]],
              let blockers = row["blockers"] as? [String],
              blockers.allSatisfy({ !$0.isEmpty && $0.count <= 1_024 }) else {
            failures.append("\(path) tests/evidence/blockers is malformed")
            return
        }
        for (index, test) in tests.enumerated() {
            validateTestSchema(test, path: "\(path).tests[\(index)]", failures: &failures)
        }
        for (index, artifact) in evidence.enumerated() {
            validateEvidenceSchema(artifact, path: "\(path).evidence[\(index)]", failures: &failures)
        }

        if template, status != "planned" || !tests.isEmpty || !evidence.isEmpty {
            failures.append("\(path) violates template-only planned/empty constraints")
        }
        if status == "passed" {
            if capabilityCount == 0 { failures.append("\(path) passed without capabilityRefs") }
            if gateKeys.contains(where: { !["passed", "not-required"].contains(gates[$0] as? String ?? "") }) {
                failures.append("\(path) passed with an open gate")
            }
            if tests.isEmpty || tests.contains(where: { $0["result"] as? String != "passed" }) {
                failures.append("\(path) passed without passed tests")
            }
            if evidence.isEmpty || evidence.contains(where: { $0["result"] as? String != "passed" }) {
                failures.append("\(path) passed without passed evidence")
            }
            if !blockers.isEmpty { failures.append("\(path) passed with blockers") }
        }
    }

    private static func validateTestSchema(
        _ test: [String: Any],
        path: String,
        failures: inout [String]
    ) {
        exactKeys(
            test,
            allowed: ["name", "command", "result", "reportPath", "reportSha256"],
            path: path,
            failures: &failures
        )
        if !validString(test["name"], min: 1, max: 256)
            || !validString(test["command"], min: 1, max: 2_048)
            || !["passed", "failed"].contains(test["result"] as? String ?? "")
            || !isSafePath(test["reportPath"] as? String ?? "")
            || !isSHA256(test["reportSha256"] as? String ?? "") {
            failures.append("\(path) is malformed")
        }
    }

    private static func validateEvidenceSchema(
        _ artifact: [String: Any],
        path: String,
        failures: inout [String]
    ) {
        validateKeys(
            artifact,
            allowed: ["kind", "path", "byteLength", "sha256", "targetKind", "deviceId", "os", "operator", "capturedAt", "result"],
            required: ["kind", "path", "byteLength", "sha256", "targetKind", "capturedAt", "result"],
            path: path,
            failures: &failures
        )
        let kinds = [
            "build-report", "screenshot", "video", "device-log", "performance",
            "accessibility", "corpus", "corpus-diff", "security-audit", "release-lock", "rollback",
        ]
        let targets = ["unit-runner", "simulator", "physical-device", "manual-observation"]
        guard kinds.contains(artifact["kind"] as? String ?? ""),
              isSafePath(artifact["path"] as? String ?? ""),
              let length = strictUInt64(artifact["byteLength"]), length >= 1,
              isSHA256(artifact["sha256"] as? String ?? ""),
              let target = artifact["targetKind"] as? String, targets.contains(target),
              let capturedAt = artifact["capturedAt"] as? String,
              ISO8601DateFormatter().date(from: capturedAt) != nil,
              ["passed", "failed"].contains(artifact["result"] as? String ?? "") else {
            failures.append("\(path) is malformed")
            return
        }
        for key in ["deviceId", "os", "operator"] {
            if let raw = artifact[key], !(raw is NSNull), !validString(raw, min: 1, max: 256) {
                failures.append("\(path).\(key) is malformed")
            }
        }
        if target == "physical-device" || target == "manual-observation" {
            guard let deviceID = artifact["deviceId"] as? String,
                  deviceID.count >= 4,
                  !["unknown", "none", "null", "mock", "fake", "test", "device", "simulator", "emulator"].contains(deviceID.lowercased()),
                  validString(artifact["os"], min: 1, max: 256) else {
                failures.append("\(path) lacks required device identity")
                return
            }
        }
        if target == "manual-observation", !validString(artifact["operator"], min: 1, max: 256) {
            failures.append("\(path) lacks an operator")
        }
    }

    private static func exactKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        path: String,
        failures: inout [String]
    ) {
        let actual = Set(object.keys)
        if actual != allowed {
            let missing = allowed.subtracting(actual).sorted().joined(separator: ",")
            let extra = actual.subtracting(allowed).sorted().joined(separator: ",")
            failures.append("\(path) keys mismatch missing=[\(missing)] extra=[\(extra)]")
        }
    }

    private static func validateKeys(
        _ object: [String: Any],
        allowed: Set<String>,
        required: Set<String>,
        path: String,
        failures: inout [String]
    ) {
        let actual = Set(object.keys)
        let missing = required.subtracting(actual)
        let extra = actual.subtracting(allowed)
        if !missing.isEmpty || !extra.isEmpty {
            failures.append(
                "\(path) keys mismatch missing=[\(missing.sorted().joined(separator: ","))] extra=[\(extra.sorted().joined(separator: ","))]"
            )
        }
    }

    private static func uniqueStringArray(_ raw: Any?, allowEmpty: Bool) -> [String]? {
        guard let values = raw as? [String],
              (allowEmpty || !values.isEmpty),
              Set(values).count == values.count else { return nil }
        return values
    }

    private static func validString(_ raw: Any?, min: Int, max: Int) -> Bool {
        guard let value = raw as? String else { return false }
        return value.count >= min && value.count <= max
    }

    private static func strictInteger(_ raw: Any?) -> Int? {
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(number) else { return nil }
        return Int(number.stringValue)
    }

    private static func strictUInt64(_ raw: Any?) -> UInt64? {
        guard let number = raw as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID(),
              !CFNumberIsFloatType(number) else { return nil }
        return UInt64(number.stringValue)
    }

    private static func matches(_ value: String, _ pattern: String) -> Bool {
        value.range(of: pattern, options: .regularExpression) != nil
    }

    private static func isSHA256(_ value: String) -> Bool {
        matches(value, "^[0-9a-f]{64}$")
    }

    private static func isSourceSHA(_ value: String) -> Bool {
        matches(value, "^(?:[0-9a-f]{40}|[0-9a-f]{64})$")
    }

    private static func isSafePath(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 512,
              !value.hasPrefix("/"),
              !matches(value, "^[A-Za-z]:"),
              !value.contains("\\"),
              !value.contains("//"),
              matches(value, "^[A-Za-z0-9._/-]+$") else { return false }
        return !value.split(separator: "/", omittingEmptySubsequences: false).contains("..")
    }

    private static func isReaderCoreBinaryArtifact(_ data: Data) -> Bool {
        if data.starts(with: Data("!<arch>\n".utf8)) { return true }
        guard data.count >= 4 else { return false }
        let magic = Array(data.prefix(4))
        let machoMagics: [[UInt8]] = [
            [0xfe, 0xed, 0xfa, 0xce], [0xce, 0xfa, 0xed, 0xfe],
            [0xfe, 0xed, 0xfa, 0xcf], [0xcf, 0xfa, 0xed, 0xfe],
            [0xca, 0xfe, 0xba, 0xbe], [0xbe, 0xba, 0xfe, 0xca],
            [0xca, 0xfe, 0xba, 0xbf], [0xbf, 0xba, 0xfe, 0xca],
        ]
        return machoMagics.contains(magic)
    }

    private static func hasCredibleArtifactContent(
        _ data: Data,
        path: String,
        kind: ArtifactContentKind
    ) -> Bool {
        let extensionName = URL(fileURLWithPath: path).pathExtension.lowercased()
        let isText = { () -> Bool in
            guard let value = String(data: data, encoding: .utf8) else { return false }
            return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let isJSON = { () -> Bool in
            guard let object = try? JSONSerialization.jsonObject(with: data) else { return false }
            if let dictionary = object as? [String: Any] { return !dictionary.isEmpty }
            if let array = object as? [Any] { return !array.isEmpty }
            return false
        }
        let isPNG = data.starts(with: Data([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]))
        let isJPEG = data.count >= 3 && Array(data.prefix(3)) == [0xff, 0xd8, 0xff]
        let isZIP = data.count >= 4 && [
            [0x50, 0x4b, 0x03, 0x04], [0x50, 0x4b, 0x05, 0x06], [0x50, 0x4b, 0x07, 0x08],
        ].contains(Array(data.prefix(4)))

        switch kind {
        case .testReport:
            switch extensionName {
            case "json": return isCredibleTestReportJSON(data)
            case "txt", "log": return isText()
            case "xml": return isText() && String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("<") == true
            default: return false
            }
        case .evidence(let evidenceKind):
            switch evidenceKind {
            case "video":
                return ["mov", "mp4", "m4v"].contains(extensionName) && isCredibleISOBMFFVideo(data)
            case "screenshot": return (extensionName == "png" && isPNG) || (["jpg", "jpeg"].contains(extensionName) && isJPEG)
            case "corpus":
                return (extensionName == "json" && isCredibleStructuredEvidenceJSON(data, kind: evidenceKind))
                    || (extensionName == "zip" && isZIP)
            case "performance", "corpus-diff", "release-lock", "rollback":
                return extensionName == "json"
                    && isCredibleStructuredEvidenceJSON(data, kind: evidenceKind)
            case "accessibility":
                return (extensionName == "json" && isCredibleStructuredEvidenceJSON(data, kind: evidenceKind))
                    || (["mov", "mp4", "m4v"].contains(extensionName) && isCredibleISOBMFFVideo(data))
                    || (extensionName == "png" && isPNG)
            case "build-report", "device-log", "security-audit":
                if extensionName == "json" { return isJSON() }
                return ["txt", "log"].contains(extensionName) && isText()
            default: return false
            }
        }
    }

    /// Performs a deliberately small but structural ISO BMFF admission check.
    /// A digest can attest provenance, but a 12-byte `ftyp` prefix is not a
    /// playable video. The complete top-level box table must be length-safe,
    /// start with a recognized file-type box, and contain actual movie metadata
    /// and a video track plus media payload.
    private static func isCredibleISOBMFFVideo(_ data: Data) -> Bool {
        guard let boxes = isoBoxes(in: data, start: 0, end: data.count),
              let first = boxes.first, first.type == "ftyp",
              boxes.filter({ $0.type == "ftyp" }).count == 1,
              credibleFileTypeBox(data, payloadStart: first.payloadStart, end: first.end),
              let movie = exactlyOneBox(named: "moov", in: boxes),
              credibleMovieBox(data, movie),
              boxes.contains(where: { $0.type == "mdat" && $0.end - $0.payloadStart >= 4 }) else {
            return false
        }
        return true
    }

    private struct ISOBox {
        let type: String
        let payloadStart: Int
        let end: Int
    }

    private static func isoBox(in data: Data, at start: Int, limit: Int) -> ISOBox? {
        guard start >= 0, limit <= data.count, start <= limit, limit - start >= 8 else { return nil }
        let size32 = readBigEndianUInt32(data, at: start)
        guard let type = String(data: data[(start + 4)..<(start + 8)], encoding: .ascii),
              type.unicodeScalars.allSatisfy({ (0x20...0x7e).contains($0.value) }) else {
            return nil
        }

        var headerLength = 8
        let declaredLength: UInt64
        if size32 == 1 {
            guard limit - start >= 16 else { return nil }
            headerLength = 16
            declaredLength = readBigEndianUInt64(data, at: start + 8)
        } else if size32 == 0 {
            declaredLength = UInt64(limit - start)
        } else {
            declaredLength = UInt64(size32)
        }

        guard declaredLength >= UInt64(headerLength),
              declaredLength <= UInt64(limit - start),
              let length = Int(exactly: declaredLength) else { return nil }
        let end = start + length
        // A zero-sized box extends to EOF and therefore cannot be followed by
        // another top-level or nested box.
        if size32 == 0, end != limit { return nil }
        return ISOBox(type: type, payloadStart: start + headerLength, end: end)
    }

    private static func isoBoxes(in data: Data, start: Int, end: Int) -> [ISOBox]? {
        guard start >= 0, end <= data.count, start < end else { return nil }
        var cursor = start
        var boxes: [ISOBox] = []
        while cursor < end {
            guard let box = isoBox(in: data, at: cursor, limit: end) else { return nil }
            boxes.append(box)
            cursor = box.end
        }
        return cursor == end && !boxes.isEmpty ? boxes : nil
    }

    private static func exactlyOneBox(named type: String, in boxes: [ISOBox]) -> ISOBox? {
        let matches = boxes.filter { $0.type == type }
        return matches.count == 1 ? matches[0] : nil
    }

    private static func credibleMovieBox(_ data: Data, _ movie: ISOBox) -> Bool {
        guard let children = isoBoxes(in: data, start: movie.payloadStart, end: movie.end),
              let movieHeader = exactlyOneBox(named: "mvhd", in: children),
              credibleMovieHeader(data, movieHeader) else { return false }
        let tracks = children.filter { $0.type == "trak" }
        return !tracks.isEmpty && tracks.contains(where: { credibleVideoTrack(data, $0) })
    }

    private static func credibleMovieHeader(_ data: Data, _ box: ISOBox) -> Bool {
        guard let version = fullBoxVersion(data, box) else { return false }
        let minimumPayload = version == 0 ? 100 : 112
        let timescaleOffset = box.payloadStart + (version == 0 ? 12 : 20)
        return box.end - box.payloadStart >= minimumPayload
            && readBigEndianUInt32(data, at: timescaleOffset) > 0
    }

    private static func credibleVideoTrack(_ data: Data, _ track: ISOBox) -> Bool {
        guard let children = isoBoxes(in: data, start: track.payloadStart, end: track.end),
              let trackHeader = exactlyOneBox(named: "tkhd", in: children),
              credibleTrackHeader(data, trackHeader),
              let media = exactlyOneBox(named: "mdia", in: children) else { return false }
        return credibleVideoMediaBox(data, media)
    }

    private static func credibleTrackHeader(_ data: Data, _ box: ISOBox) -> Bool {
        guard let version = fullBoxVersion(data, box) else { return false }
        let minimumPayload = version == 0 ? 84 : 96
        let trackIDOffset = box.payloadStart + (version == 0 ? 12 : 20)
        return box.end - box.payloadStart >= minimumPayload
            && readBigEndianUInt32(data, at: trackIDOffset) > 0
    }

    private static func credibleVideoMediaBox(_ data: Data, _ media: ISOBox) -> Bool {
        guard let children = isoBoxes(in: data, start: media.payloadStart, end: media.end),
              let mediaHeader = exactlyOneBox(named: "mdhd", in: children),
              credibleMediaHeader(data, mediaHeader),
              let handler = exactlyOneBox(named: "hdlr", in: children),
              fullBoxVersion(data, handler) == 0,
              handler.end - handler.payloadStart >= 24 else { return false }
        let handlerTypeStart = handler.payloadStart + 8
        return String(data: data[handlerTypeStart..<(handlerTypeStart + 4)], encoding: .ascii) == "vide"
    }

    private static func credibleMediaHeader(_ data: Data, _ box: ISOBox) -> Bool {
        guard let version = fullBoxVersion(data, box) else { return false }
        let minimumPayload = version == 0 ? 24 : 36
        let timescaleOffset = box.payloadStart + (version == 0 ? 12 : 20)
        return box.end - box.payloadStart >= minimumPayload
            && readBigEndianUInt32(data, at: timescaleOffset) > 0
    }

    private static func fullBoxVersion(_ data: Data, _ box: ISOBox) -> UInt8? {
        guard box.end - box.payloadStart >= 4 else { return nil }
        let version = data[box.payloadStart]
        return version == 0 || version == 1 ? version : nil
    }

    private static func credibleFileTypeBox(_ data: Data, payloadStart: Int, end: Int) -> Bool {
        let payloadLength = end - payloadStart
        guard payloadLength >= 8, (payloadLength - 8).isMultiple(of: 4) else { return false }
        var brands: [String] = []
        if let major = String(data: data[payloadStart..<(payloadStart + 4)], encoding: .ascii) {
            brands.append(major)
        }
        var cursor = payloadStart + 8
        while cursor < end {
            if let compatible = String(data: data[cursor..<(cursor + 4)], encoding: .ascii) {
                brands.append(compatible)
            }
            cursor += 4
        }
        let admittedBrands: Set<String> = [
            "qt  ", "isom", "iso2", "iso3", "iso4", "iso5", "iso6", "iso7", "iso8", "iso9",
            "mp41", "mp42", "avc1", "M4A ", "M4V ", "3gp4", "3gp5", "3g2a", "dash",
            "cmfc", "cmfs", "heic", "heix", "mif1", "msf1",
        ]
        return brands.contains(where: admittedBrands.contains)
    }

    private static func readBigEndianUInt32(_ data: Data, at offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }

    private static func readBigEndianUInt64(_ data: Data, at offset: Int) -> UInt64 {
        data[offset..<(offset + 8)].reduce(UInt64(0)) { ($0 << 8) | UInt64($1) }
    }

    /// JSON evidence is admitted by semantic kind, not merely by being a
    /// non-empty object. These are intentionally minimal report contracts: they
    /// prove that a measurable/traceable operation ran without pretending to be
    /// a full replacement for the source tool's raw report.
    private static func isCredibleStructuredEvidenceJSON(_ data: Data, kind: String) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              strictInteger(object["schemaVersion"]) == 1,
              object["kind"] as? String == kind,
              object["result"] as? String == "passed" else { return false }

        switch kind {
        case "accessibility":
            guard nonBlankString(object["assistiveTechnology"]),
                  let screenCount = strictUInt64(object["screenCount"]), screenCount > 0,
                  let checks = object["checks"] as? [[String: Any]], !checks.isEmpty else { return false }
            return checks.allSatisfy {
                nonBlankString($0["id"])
                    && nonBlankString($0["name"])
                    && $0["result"] as? String == "passed"
            }
        case "corpus":
            guard nonBlankString(object["corpusId"]),
                  let caseCount = strictUInt64(object["caseCount"]), caseCount > 0,
                  let cases = object["cases"] as? [[String: Any]], UInt64(cases.count) == caseCount else {
                return false
            }
            let caseIDs = cases.compactMap { $0["id"] as? String }
            return caseIDs.count == cases.count
                && Set(caseIDs).count == cases.count
                && cases.allSatisfy {
                    nonBlankString($0["id"])
                        && isSHA256($0["inputSha256"] as? String ?? "")
                }
        case "performance":
            guard let metrics = object["metrics"] as? [[String: Any]], !metrics.isEmpty else { return false }
            return metrics.allSatisfy { metric in
                guard nonBlankString(metric["name"]),
                      nonBlankString(metric["unit"]),
                      let value = finiteNumber(metric["value"]),
                      let threshold = finiteNumber(metric["threshold"]),
                      let comparison = metric["comparison"] as? String,
                      metric["result"] as? String == "passed" else { return false }
                switch comparison {
                case "<": return value < threshold
                case "<=": return value <= threshold
                case ">": return value > threshold
                case ">=": return value >= threshold
                default: return false
                }
            }
        case "corpus-diff":
            guard nonBlankString(object["corpusId"]),
                  isSHA256(object["baselineSha256"] as? String ?? ""),
                  isSHA256(object["candidateSha256"] as? String ?? ""),
                  let totalCases = strictUInt64(object["totalCases"]), totalCases > 0,
                  let changedCases = strictUInt64(object["changedCases"]), changedCases == 0,
                  let differences = object["differences"] as? [Any], differences.isEmpty else { return false }
            return true
        case "release-lock":
            guard let contractVersion = object["contractVersion"] as? String,
                  matches(contractVersion, "^[0-9]+\\.[0-9]+\\.[0-9]+$"),
                  let sourceSHA = object["sourceSha"] as? String, isSourceSHA(sourceSHA),
                  let manifestSHA = object["manifestSha"] as? String, isSHA256(manifestSHA),
                  isSHA256(object["readerCoreArtifactSha"] as? String ?? ""),
                  isSHA256(object["consumerLockSha"] as? String ?? ""),
                  object["releaseId"] as? String == "\(sourceSHA):\(manifestSHA)" else { return false }
            return true
        case "rollback":
            guard let fromVersion = object["fromVersion"] as? String,
                  let toVersion = object["toVersion"] as? String,
                  fromVersion != toVersion,
                  matches(fromVersion, "^[0-9]+\\.[0-9]+\\.[0-9]+$"),
                  matches(toVersion, "^[0-9]+\\.[0-9]+\\.[0-9]+$"),
                  let steps = object["steps"] as? [[String: Any]], !steps.isEmpty else { return false }
            return steps.allSatisfy {
                nonBlankString($0["name"]) && $0["result"] as? String == "passed"
            }
        default:
            return false
        }
    }

    private static func isCredibleTestReportJSON(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              strictInteger(object["schemaVersion"]) == 1,
              object["reportKind"] as? String == "test-report",
              object["result"] as? String == "passed",
              let summary = object["summary"] as? [String: Any],
              let total = strictUInt64(summary["total"]), total > 0,
              let passed = strictUInt64(summary["passed"]), passed > 0,
              let failed = strictUInt64(summary["failed"]), failed == 0,
              let skipped = strictUInt64(summary["skipped"]),
              passed <= total,
              failed <= total - passed,
              skipped == total - passed - failed,
              let tests = object["tests"] as? [[String: Any]], UInt64(tests.count) == total else {
            return false
        }
        let passedCases = tests.filter { $0["result"] as? String == "passed" }.count
        let skippedCases = tests.filter { $0["result"] as? String == "skipped" }.count
        let testNames = tests.compactMap { $0["name"] as? String }
        return UInt64(passedCases) == passed
            && UInt64(skippedCases) == skipped
            && testNames.count == tests.count
            && Set(testNames).count == tests.count
            && tests.allSatisfy {
                nonBlankString($0["name"])
                    && ["passed", "skipped"].contains($0["result"] as? String ?? "")
            }
    }

    private static func nonBlankString(_ raw: Any?) -> Bool {
        guard let value = raw as? String else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private static func finiteNumber(_ raw: Any?) -> Double? {
        guard let value = raw as? NSNumber,
              CFGetTypeID(value) != CFBooleanGetTypeID() else { return nil }
        let number = value.doubleValue
        return number.isFinite ? number : nil
    }

    private static func readObject(
        _ url: URL,
        code: String,
        blockers: inout [ReaderSlice12ReleaseFinding]
    ) -> [String: Any]? {
        do {
            let data = try Data(contentsOf: url)
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw CocoaError(.propertyListReadCorrupt)
            }
            return object
        } catch {
            blockers.append(.init(code: code, message: "\(url.path): \(error.localizedDescription)"))
            return nil
        }
    }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
