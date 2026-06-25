import Foundation

public enum HostRuntimeEvidenceStatus: String, Codable, Sendable {
    case descriptorOnly
    case notRun
    case measuredPass
    case measuredFail
    case blocked
}

public enum HostRuntimeEvidenceID: String, Codable, CaseIterable, Sendable {
    case credentialRedactionRevocationMatrix = "credential_redaction_revocation_matrix"
    case productGatedJSBridgeReleaseRunner = "product_gated_js_bridge_release_runner"
    case runtimeRollbackAudit = "runtime_rollback_audit"
    case secureStoragePlatformAudit = "secure_storage_platform_audit"
    case sessionCookieLoginPlatformRunner = "session_cookie_login_platform_runner"
    case webViewCookieMirrorAudit = "webview_cookie_mirror_audit"
    case webViewDOMPlatformSmokeRunner = "webview_dom_platform_smoke_runner"
    case localBookSecurityScopedHandoff = "local_book_security_scoped_handoff"
}

public enum AppleRuntimeEvidenceKind: String, Codable, Sendable {
    case nativeWKWebViewLoginFlow
    case productionKeychainAccessGroup
    case realWebsiteLogin
    case crossProcessPlatformCookieSync
    case webViewHTTPCookieMirror
    case releaseGateDowngradeEvidence
    case operatorApproval
    case ciArtifact
}

public struct HostRuntimeEvidenceBundle: Codable, Equatable, Sendable {
    public let schemaVersion: String
    public let bundleId: String
    public let generatedAt: Date
    public let platformOwner: String
    public let cleanRoom: HostRuntimeCleanRoomStatement
    public let evidence: [HostRuntimeEvidenceDescriptor]

    public init(
        schemaVersion: String = HostRuntimeEvidenceExporter.schemaVersion,
        bundleId: String,
        generatedAt: Date,
        platformOwner: String = "Reader-iOS",
        cleanRoom: HostRuntimeCleanRoomStatement = .default,
        evidence: [HostRuntimeEvidenceDescriptor]
    ) {
        self.schemaVersion = schemaVersion
        self.bundleId = bundleId
        self.generatedAt = generatedAt
        self.platformOwner = platformOwner
        self.cleanRoom = cleanRoom
        self.evidence = evidence
    }
}

public struct HostRuntimeCleanRoomStatement: Codable, Equatable, Sendable {
    public let cleanRoomMaintained: Bool
    public let externalGPLCodeCopied: Bool
    public let sourceBasis: [String]

    public static let `default` = HostRuntimeCleanRoomStatement(
        cleanRoomMaintained: true,
        externalGPLCodeCopied: false,
        sourceBasis: [
            "Reader-iOS local host code",
            "Reader-Core public contracts",
            "sanitized runtime observations"
        ]
    )
}

public struct HostRuntimeEvidenceDescriptor: Codable, Equatable, Sendable {
    public let evidenceId: HostRuntimeEvidenceID
    public let coreGapIds: [String]
    public let evidenceKinds: [AppleRuntimeEvidenceKind]
    public let status: HostRuntimeEvidenceStatus
    public let liveExecutionClaimed: Bool
    public let observedAt: Date?
    public let subject: HostRuntimeEvidenceSubject
    public let redaction: HostRuntimeRedactionSummary
    public let requiredArtifacts: [String]
    public let observedArtifacts: [String]
    public let blockers: [String]
    public let notes: [String]

    public init(
        evidenceId: HostRuntimeEvidenceID,
        coreGapIds: [String],
        evidenceKinds: [AppleRuntimeEvidenceKind],
        status: HostRuntimeEvidenceStatus,
        liveExecutionClaimed: Bool = false,
        observedAt: Date? = nil,
        subject: HostRuntimeEvidenceSubject = HostRuntimeEvidenceSubject(),
        redaction: HostRuntimeRedactionSummary = .strict,
        requiredArtifacts: [String],
        observedArtifacts: [String] = [],
        blockers: [String] = [],
        notes: [String] = []
    ) {
        self.evidenceId = evidenceId
        self.coreGapIds = coreGapIds
        self.evidenceKinds = evidenceKinds
        self.status = status
        self.liveExecutionClaimed = liveExecutionClaimed
        self.observedAt = observedAt
        self.subject = subject
        self.redaction = redaction
        self.requiredArtifacts = requiredArtifacts
        self.observedArtifacts = observedArtifacts
        self.blockers = blockers
        self.notes = notes
    }
}

public struct HostRuntimeEvidenceSubject: Codable, Equatable, Sendable {
    public let sourceId: String?
    public let urlScheme: String?
    public let urlHost: String?
    public let allowedHost: String?
    public let urlPathComponentCount: Int?
    public let queryRedacted: Bool
    public let fileExtension: String?
    public let fileSizeBucket: String?
    public let fileNameRedacted: Bool
    public let navigationCount: Int?
    public let renderedHTMLByteCount: Int?
    public let snapshotIdPresent: Bool?
    public let cookieMetadataOnly: Bool

    public init(
        sourceId: String? = nil,
        urlScheme: String? = nil,
        urlHost: String? = nil,
        allowedHost: String? = nil,
        urlPathComponentCount: Int? = nil,
        queryRedacted: Bool = true,
        fileExtension: String? = nil,
        fileSizeBucket: String? = nil,
        fileNameRedacted: Bool = true,
        navigationCount: Int? = nil,
        renderedHTMLByteCount: Int? = nil,
        snapshotIdPresent: Bool? = nil,
        cookieMetadataOnly: Bool = true
    ) {
        self.sourceId = sourceId
        self.urlScheme = urlScheme
        self.urlHost = urlHost
        self.allowedHost = allowedHost
        self.urlPathComponentCount = urlPathComponentCount
        self.queryRedacted = queryRedacted
        self.fileExtension = fileExtension
        self.fileSizeBucket = fileSizeBucket
        self.fileNameRedacted = fileNameRedacted
        self.navigationCount = navigationCount
        self.renderedHTMLByteCount = renderedHTMLByteCount
        self.snapshotIdPresent = snapshotIdPresent
        self.cookieMetadataOnly = cookieMetadataOnly
    }

    static func webView(
        requestedURL: String,
        finalURL: String?,
        allowedHost: String,
        sourceId: String?,
        navigationCount: Int?,
        renderedHTMLByteCount: Int?,
        snapshotIdPresent: Bool?
    ) -> HostRuntimeEvidenceSubject {
        let parsed = URL(string: finalURL?.isEmpty == false ? finalURL! : requestedURL)
        return HostRuntimeEvidenceSubject(
            sourceId: sourceId,
            urlScheme: parsed?.scheme,
            urlHost: parsed?.host,
            allowedHost: allowedHost,
            urlPathComponentCount: parsed?.pathComponents.filter { $0 != "/" }.count,
            queryRedacted: parsed?.query != nil,
            navigationCount: navigationCount,
            renderedHTMLByteCount: renderedHTMLByteCount,
            snapshotIdPresent: snapshotIdPresent,
            cookieMetadataOnly: true
        )
    }

    static func localBook(fileURL: URL, fileSize: Int64?) -> HostRuntimeEvidenceSubject {
        HostRuntimeEvidenceSubject(
            fileExtension: fileURL.pathExtension.lowercased(),
            fileSizeBucket: Self.fileSizeBucket(fileSize),
            fileNameRedacted: true,
            cookieMetadataOnly: true
        )
    }

    private static func fileSizeBucket(_ size: Int64?) -> String {
        guard let size else { return "unknown" }
        switch size {
        case ..<1024: return "lt_1kb"
        case ..<(1024 * 1024): return "lt_1mb"
        case ..<(10 * 1024 * 1024): return "lt_10mb"
        case ..<(100 * 1024 * 1024): return "lt_100mb"
        default: return "gte_100mb"
        }
    }
}

public struct HostRuntimeRedactionSummary: Codable, Equatable, Sendable {
    public let applied: Bool
    public let rawCookieValuesIncluded: Bool
    public let rawCredentialValuesIncluded: Bool
    public let rawHTMLIncluded: Bool
    public let rawLocalFilePathIncluded: Bool
    public let queryStringIncluded: Bool
    public let redactedFields: [String]

    public static let strict = HostRuntimeRedactionSummary(
        applied: true,
        rawCookieValuesIncluded: false,
        rawCredentialValuesIncluded: false,
        rawHTMLIncluded: false,
        rawLocalFilePathIncluded: false,
        queryStringIncluded: false,
        redactedFields: [
            "cookie_values",
            "authorization_headers",
            "credential_values",
            "html_body",
            "local_file_path",
            "query_string",
            "snapshot_file_path"
        ]
    )
}

public enum HostRuntimeEvidenceExporter {
    public static let schemaVersion = "reader-ios.host-runtime-evidence.v1"

    public static func plannedRuntimeEvidenceBundle(generatedAt: Date = Date()) -> HostRuntimeEvidenceBundle {
        HostRuntimeEvidenceBundle(
            bundleId: "reader-ios-platform-runtime-planned",
            generatedAt: generatedAt,
            evidence: [
                localBookDescriptor(status: .notRun, observedAt: nil),
                descriptor(
                    .webViewDOMPlatformSmokeRunner,
                    gaps: ["S5", "S10"],
                    kinds: [.ciArtifact],
                    status: .notRun,
                    required: ["host_runtime_evidence_manifest.json", "webview_result.json"],
                    blockers: ["Requires iOS simulator or device WKWebView run"]
                ),
                descriptor(
                    .webViewCookieMirrorAudit,
                    gaps: ["S5", "S10"],
                    kinds: [.webViewHTTPCookieMirror, .crossProcessPlatformCookieSync, .ciArtifact],
                    status: .notRun,
                    required: ["host_runtime_evidence_manifest.json", "cookie_mirror_metadata.json"],
                    blockers: ["Requires iOS simulator or device WKWebView cookie-producing run"]
                ),
                descriptor(
                    .sessionCookieLoginPlatformRunner,
                    gaps: ["S5", "S10"],
                    kinds: [.nativeWKWebViewLoginFlow, .realWebsiteLogin, .operatorApproval],
                    status: .blocked,
                    required: ["operator_approval.json", "host_runtime_evidence_manifest.json"],
                    blockers: ["Requires explicit operator approval and redacted real-site login fixture"]
                ),
                descriptor(
                    .productGatedJSBridgeReleaseRunner,
                    gaps: ["S5"],
                    kinds: [.releaseGateDowngradeEvidence, .ciArtifact],
                    status: .notRun,
                    required: ["product_gated_js_bridge_release_runner.json"]
                ),
                descriptor(
                    .credentialRedactionRevocationMatrix,
                    gaps: ["S10"],
                    kinds: [.operatorApproval, .ciArtifact],
                    status: .descriptorOnly,
                    required: ["credential_redaction_revocation_matrix.json"]
                ),
                descriptor(
                    .runtimeRollbackAudit,
                    gaps: ["S10"],
                    kinds: [.releaseGateDowngradeEvidence, .ciArtifact],
                    status: .descriptorOnly,
                    required: ["runtime_rollback_audit.json"]
                ),
                descriptor(
                    .secureStoragePlatformAudit,
                    gaps: ["S10"],
                    kinds: [.productionKeychainAccessGroup, .ciArtifact],
                    status: .descriptorOnly,
                    required: ["secure_storage_platform_audit.json"]
                )
            ]
        )
    }

    public static func webViewAutorunBundle(
        requestedURL: String,
        finalURL: String,
        allowedHost: String,
        sourceId: String,
        resultSucceeded: Bool,
        errorType: String?,
        navigationCount: Int,
        renderedHTMLByteCount: Int,
        snapshotId: String?,
        cookieMirrorMetadata: WebViewCookieMirrorMetadata? = nil,
        generatedAt: Date = Date()
    ) -> HostRuntimeEvidenceBundle {
        var evidence = plannedRuntimeEvidenceBundle(generatedAt: generatedAt).evidence
        let observedArtifacts = [
            "host_runtime_evidence_manifest.json",
            "webview_run_status.json",
            "webview_result.json",
            snapshotId == nil ? nil : "webview_snapshot_metadata.json"
        ].compactMap { $0 }

        evidence = evidence.map { descriptor in
            if descriptor.evidenceId == .webViewCookieMirrorAudit,
               let cookieMirrorMetadata {
                return cookieMirrorDescriptor(
                    metadata: cookieMirrorMetadata,
                    status: .measuredPass,
                    observedAt: generatedAt,
                    observedArtifacts: [
                        "host_runtime_evidence_manifest.json",
                        "cookie_mirror_metadata.json"
                    ],
                    blockers: []
                )
            }

            guard descriptor.evidenceId == .webViewDOMPlatformSmokeRunner else {
                return descriptor
            }
            return HostRuntimeEvidenceDescriptor(
                evidenceId: .webViewDOMPlatformSmokeRunner,
                coreGapIds: ["S5", "S10"],
                evidenceKinds: [.ciArtifact],
                status: resultSucceeded ? .measuredPass : .measuredFail,
                liveExecutionClaimed: true,
                observedAt: generatedAt,
                subject: .webView(
                    requestedURL: requestedURL,
                    finalURL: finalURL,
                    allowedHost: allowedHost,
                    sourceId: sourceId,
                    navigationCount: navigationCount,
                    renderedHTMLByteCount: renderedHTMLByteCount,
                    snapshotIdPresent: snapshotId != nil
                ),
                requiredArtifacts: ["host_runtime_evidence_manifest.json", "webview_result.json"],
                observedArtifacts: observedArtifacts,
                blockers: resultSucceeded ? [] : ["WebView run failed with redacted error type: \(sanitizeToken(errorType))"],
                notes: ["Full URL, query string, raw HTML, cookie values, credentials, and snapshot file path are omitted"]
            )
        }

        return HostRuntimeEvidenceBundle(
            bundleId: "reader-ios-webview-autorun",
            generatedAt: generatedAt,
            evidence: evidence
        )
    }

    public static func webViewCookieMirrorBundle(
        metadata: WebViewCookieMirrorMetadata,
        generatedAt: Date = Date()
    ) -> HostRuntimeEvidenceBundle {
        HostRuntimeEvidenceBundle(
            bundleId: "reader-ios-webview-cookie-mirror",
            generatedAt: generatedAt,
            evidence: [
                cookieMirrorDescriptor(
                    metadata: metadata,
                    status: .measuredPass,
                    observedAt: generatedAt,
                    observedArtifacts: [
                        "host_runtime_evidence_manifest.json",
                        "cookie_mirror_metadata.json"
                    ],
                    blockers: []
                )
            ]
        )
    }

    public static func localBookSecurityScopedHandoffBundle(
        fileURL: URL,
        fileSize: Int64?,
        accessStarted: Bool,
        generatedAt: Date = Date()
    ) -> HostRuntimeEvidenceBundle {
        HostRuntimeEvidenceBundle(
            bundleId: "reader-ios-local-book-security-scoped-handoff",
            generatedAt: generatedAt,
            evidence: [
                localBookDescriptor(
                    status: accessStarted ? .measuredPass : .measuredFail,
                    observedAt: generatedAt,
                    subject: .localBook(fileURL: fileURL, fileSize: fileSize),
                    observedArtifacts: ["local_book_security_scoped_handoff_manifest.json"],
                    blockers: accessStarted ? [] : ["Security-scoped resource access was denied"]
                )
            ]
        )
    }

    /// Session-cookie login evidence bundle. Emits `.measuredPass` only when a
    /// valid (non-expired, non-revoked) operator approval packet is supplied;
    /// otherwise emits `.blocked`. The bundle never carries raw cookie values,
    /// Set-Cookie headers, credentials, tokens, or HTML bodies — only redacted
    /// metadata, mirroring `HostRuntimeRedactionSummary.strict`.
    public static func sessionCookieLoginBundle(
        approval: OperatorApprovalPacket?,
        observedAt: Date = Date()
    ) -> HostRuntimeEvidenceBundle {
        let isLive = approval?.isValid(at: observedAt) == true
        let host = approval?.host
        let subject: HostRuntimeEvidenceSubject
        if let host {
            subject = HostRuntimeEvidenceSubject(
                urlScheme: "https",
                urlHost: host,
                allowedHost: host,
                queryRedacted: true,
                cookieMetadataOnly: true
            )
        } else {
            subject = HostRuntimeEvidenceSubject(cookieMetadataOnly: true)
        }

        let blockers: [String]
        if isLive {
            blockers = []
        } else if approval == nil {
            blockers = ["Requires explicit operator approval and redacted real-site login fixture"]
        } else if approval?.revoked == true {
            blockers = ["Operator approval packet revoked"]
        } else {
            blockers = ["Operator approval packet expired"]
        }

        let descriptor = HostRuntimeEvidenceDescriptor(
            evidenceId: .sessionCookieLoginPlatformRunner,
            coreGapIds: ["S5", "S10"],
            evidenceKinds: [.nativeWKWebViewLoginFlow, .realWebsiteLogin, .operatorApproval],
            status: isLive ? .measuredPass : .blocked,
            liveExecutionClaimed: isLive,
            observedAt: isLive ? observedAt : nil,
            subject: subject,
            redaction: .strict,
            requiredArtifacts: ["operator_approval.json", "host_runtime_evidence_manifest.json"],
            observedArtifacts: isLive ? ["host_runtime_evidence_manifest.json"] : [],
            blockers: blockers,
            notes: [
                "No raw cookie values, Set-Cookie headers, credentials, tokens, or HTML bodies are emitted",
                "Login execution remains operator-gated; this descriptor records approval state only"
            ]
        )

        return HostRuntimeEvidenceBundle(
            bundleId: "reader-ios-session-cookie-login",
            generatedAt: observedAt,
            evidence: [descriptor]
        )
    }

    public static func encodedData(_ bundle: HostRuntimeEvidenceBundle) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(bundle)
    }

    @discardableResult
    public static func write(_ bundle: HostRuntimeEvidenceBundle, to url: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encodedData(bundle).write(to: url, options: .atomic)
        return url
    }

    private static func localBookDescriptor(
        status: HostRuntimeEvidenceStatus,
        observedAt: Date?,
        subject: HostRuntimeEvidenceSubject = HostRuntimeEvidenceSubject(),
        observedArtifacts: [String] = [],
        blockers: [String] = ["Requires UIDocumentPicker/fileImporter security-scoped file selection"]
    ) -> HostRuntimeEvidenceDescriptor {
        descriptor(
            .localBookSecurityScopedHandoff,
            gaps: ["S3"],
            kinds: [.ciArtifact],
            status: status,
            liveExecutionClaimed: status == .measuredPass || status == .measuredFail,
            observedAt: observedAt,
            subject: subject,
            required: ["local_book_security_scoped_handoff_manifest.json"],
            observed: observedArtifacts,
            blockers: blockers,
            notes: ["Local file name and absolute file path are redacted"]
        )
    }

    private static func descriptor(
        _ evidenceId: HostRuntimeEvidenceID,
        gaps: [String],
        kinds: [AppleRuntimeEvidenceKind],
        status: HostRuntimeEvidenceStatus,
        liveExecutionClaimed: Bool = false,
        observedAt: Date? = nil,
        subject: HostRuntimeEvidenceSubject = HostRuntimeEvidenceSubject(),
        required: [String],
        observed: [String] = [],
        blockers: [String] = [],
        notes: [String] = []
    ) -> HostRuntimeEvidenceDescriptor {
        HostRuntimeEvidenceDescriptor(
            evidenceId: evidenceId,
            coreGapIds: gaps,
            evidenceKinds: kinds,
            status: status,
            liveExecutionClaimed: liveExecutionClaimed,
            observedAt: observedAt,
            subject: subject,
            requiredArtifacts: required,
            observedArtifacts: observed,
            blockers: blockers,
            notes: notes
        )
    }

    private static func cookieMirrorDescriptor(
        metadata: WebViewCookieMirrorMetadata,
        status: HostRuntimeEvidenceStatus,
        observedAt: Date?,
        observedArtifacts: [String],
        blockers: [String]
    ) -> HostRuntimeEvidenceDescriptor {
        descriptor(
            .webViewCookieMirrorAudit,
            gaps: ["S5", "S10"],
            kinds: [.webViewHTTPCookieMirror, .crossProcessPlatformCookieSync, .ciArtifact],
            status: status,
            liveExecutionClaimed: status == .measuredPass || status == .measuredFail,
            observedAt: observedAt,
            subject: HostRuntimeEvidenceSubject(
                sourceId: metadata.sourceId,
                urlScheme: metadata.finalURL.scheme ?? metadata.requestedURL.scheme,
                urlHost: metadata.finalURL.host ?? metadata.requestedURL.host,
                allowedHost: metadata.requestedURL.host,
                urlPathComponentCount: metadata.finalURL.pathComponentCount ?? metadata.requestedURL.pathComponentCount,
                queryRedacted: metadata.finalURL.queryRedacted || metadata.requestedURL.queryRedacted,
                cookieMetadataOnly: true
            ),
            required: ["host_runtime_evidence_manifest.json", "cookie_mirror_metadata.json"],
            observed: observedArtifacts,
            blockers: blockers,
            notes: [
                "Cookie metadata is captured without cookie values, Set-Cookie headers, query strings, or raw HTML",
                "Cookie metadata count: \(metadata.cookieCount)"
            ]
        )
    }

    private static func sanitizeToken(_ value: String?) -> String {
        guard let value, !value.isEmpty else { return "unknown" }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            return "redacted_error_type"
        }
        return String(value.prefix(80))
    }
}
