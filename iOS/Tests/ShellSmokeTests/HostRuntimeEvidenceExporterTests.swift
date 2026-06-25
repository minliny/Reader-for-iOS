import XCTest
@testable import ReaderShellValidation

final class HostRuntimeEvidenceExporterTests: XCTestCase {

    func testPlannedRuntimeEvidenceUsesCoreAlignedIDsAndKinds() throws {
        let generatedAt = Date(timeIntervalSince1970: 1_782_156_000)
        let bundle = HostRuntimeEvidenceExporter.plannedRuntimeEvidenceBundle(generatedAt: generatedAt)
        let ids = Set(bundle.evidence.map(\.evidenceId))

        XCTAssertEqual(bundle.schemaVersion, "reader-ios.host-runtime-evidence.v1")
        XCTAssertTrue(bundle.cleanRoom.cleanRoomMaintained)
        XCTAssertFalse(bundle.cleanRoom.externalGPLCodeCopied)
        XCTAssertTrue(ids.contains(.credentialRedactionRevocationMatrix))
        XCTAssertTrue(ids.contains(.productGatedJSBridgeReleaseRunner))
        XCTAssertTrue(ids.contains(.runtimeRollbackAudit))
        XCTAssertTrue(ids.contains(.secureStoragePlatformAudit))
        XCTAssertTrue(ids.contains(.sessionCookieLoginPlatformRunner))
        XCTAssertTrue(ids.contains(.webViewCookieMirrorAudit))
        XCTAssertTrue(ids.contains(.webViewDOMPlatformSmokeRunner))
        XCTAssertTrue(ids.contains(.localBookSecurityScopedHandoff))

        let cookieMirror = try XCTUnwrap(bundle.evidence.first { $0.evidenceId == .webViewCookieMirrorAudit })
        XCTAssertEqual(cookieMirror.status, .notRun)
        XCTAssertTrue(cookieMirror.evidenceKinds.contains(.webViewHTTPCookieMirror))
        XCTAssertTrue(cookieMirror.evidenceKinds.contains(.crossProcessPlatformCookieSync))
        XCTAssertTrue(cookieMirror.requiredArtifacts.contains("cookie_mirror_metadata.json"))
        XCTAssertFalse(cookieMirror.blockers.contains("Cookie mirror metadata path is not implemented in iOS host yet"))

        XCTAssertTrue(bundle.evidence.allSatisfy { !$0.liveExecutionClaimed })
    }

    func testWebViewAutorunBundleRedactsURLQueryHTMLCookiesAndCredentials() throws {
        let bundle = HostRuntimeEvidenceExporter.webViewAutorunBundle(
            requestedURL: "https://www.example.com/private/path?token=secret-token",
            finalURL: "https://www.example.com/private/path?token=secret-token",
            allowedHost: "www.example.com",
            sourceId: "sample_source",
            resultSucceeded: false,
            errorType: "navigationFailed: token=secret-token",
            navigationCount: 1,
            renderedHTMLByteCount: 4096,
            snapshotId: nil,
            generatedAt: Date(timeIntervalSince1970: 1_782_156_010)
        )

        let domEvidence = try XCTUnwrap(bundle.evidence.first { $0.evidenceId == .webViewDOMPlatformSmokeRunner })
        XCTAssertEqual(domEvidence.status, .measuredFail)
        XCTAssertTrue(domEvidence.liveExecutionClaimed)
        XCTAssertEqual(domEvidence.subject.urlHost, "www.example.com")
        XCTAssertEqual(domEvidence.subject.allowedHost, "www.example.com")
        XCTAssertTrue(domEvidence.subject.queryRedacted)
        XCTAssertEqual(domEvidence.subject.renderedHTMLByteCount, 4096)
        XCTAssertFalse(domEvidence.redaction.rawCookieValuesIncluded)
        XCTAssertFalse(domEvidence.redaction.rawCredentialValuesIncluded)
        XCTAssertFalse(domEvidence.redaction.rawHTMLIncluded)
        XCTAssertFalse(domEvidence.redaction.queryStringIncluded)
        XCTAssertEqual(domEvidence.blockers, ["WebView run failed with redacted error type: redacted_error_type"])

        let json = String(data: try HostRuntimeEvidenceExporter.encodedData(bundle), encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("webview_dom_platform_smoke_runner"))
        XCTAssertTrue(json.contains("webViewHTTPCookieMirror"))
        XCTAssertFalse(json.contains("secret-token"))
        XCTAssertFalse(json.contains("private/path"))
        XCTAssertFalse(json.contains("<html"))
        XCTAssertFalse(json.contains("Set-Cookie:"))
    }

    // MARK: - Session Cookie Login Bundle

    func testSessionCookieLoginBundleBlockedWhenNoApproval() throws {
        let bundle = HostRuntimeEvidenceExporter.sessionCookieLoginBundle(
            approval: nil,
            observedAt: Date(timeIntervalSince1970: 1_782_156_030)
        )

        let evidence = try XCTUnwrap(bundle.evidence.first { $0.evidenceId == .sessionCookieLoginPlatformRunner })
        XCTAssertEqual(evidence.status, .blocked)
        XCTAssertFalse(evidence.liveExecutionClaimed)
        XCTAssertFalse(evidence.redaction.rawCookieValuesIncluded)
        XCTAssertFalse(evidence.redaction.rawCredentialValuesIncluded)
        XCTAssertFalse(evidence.redaction.rawHTMLIncluded)
    }

    func testSessionCookieLoginBundleMeasuredPassWhenValidApproval() throws {
        let grantedAt = Date(timeIntervalSince1970: 1_782_156_000)
        let approval = OperatorApprovalPacket(
            packetId: "pkt-login",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: grantedAt,
            expiresAt: grantedAt.addingTimeInterval(3600)
        )

        let bundle = HostRuntimeEvidenceExporter.sessionCookieLoginBundle(
            approval: approval,
            observedAt: grantedAt.addingTimeInterval(60)
        )

        let evidence = try XCTUnwrap(bundle.evidence.first { $0.evidenceId == .sessionCookieLoginPlatformRunner })
        XCTAssertEqual(evidence.status, .measuredPass)
        XCTAssertTrue(evidence.liveExecutionClaimed)
        XCTAssertEqual(evidence.subject.urlHost, "www.example.com")
        XCTAssertEqual(evidence.subject.allowedHost, "www.example.com")
    }

    func testSessionCookieLoginBundleBlockedWhenExpiredApproval() throws {
        let grantedAt = Date(timeIntervalSince1970: 1_782_156_000)
        let approval = OperatorApprovalPacket(
            packetId: "pkt-login-exp",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: grantedAt,
            expiresAt: grantedAt.addingTimeInterval(60)
        )

        let bundle = HostRuntimeEvidenceExporter.sessionCookieLoginBundle(
            approval: approval,
            observedAt: grantedAt.addingTimeInterval(120)
        )

        let evidence = try XCTUnwrap(bundle.evidence.first { $0.evidenceId == .sessionCookieLoginPlatformRunner })
        XCTAssertEqual(evidence.status, .blocked)
        XCTAssertFalse(evidence.liveExecutionClaimed)
    }

    func testSessionCookieLoginBundleBlockedWhenRevokedApproval() throws {
        let grantedAt = Date(timeIntervalSince1970: 1_782_156_000)
        let approval = OperatorApprovalPacket(
            packetId: "pkt-login-rev",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: grantedAt,
            expiresAt: nil,
            revoked: true
        )

        let bundle = HostRuntimeEvidenceExporter.sessionCookieLoginBundle(
            approval: approval,
            observedAt: grantedAt.addingTimeInterval(60)
        )

        let evidence = try XCTUnwrap(bundle.evidence.first { $0.evidenceId == .sessionCookieLoginPlatformRunner })
        XCTAssertEqual(evidence.status, .blocked)
    }

    func testSessionCookieLoginBundleOmitsRawSecretsAndHTML() throws {
        let grantedAt = Date(timeIntervalSince1970: 1_782_156_000)
        let approval = OperatorApprovalPacket(
            packetId: "pkt-login-secrets",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: grantedAt,
            expiresAt: nil
        )

        let bundle = HostRuntimeEvidenceExporter.sessionCookieLoginBundle(
            approval: approval,
            observedAt: grantedAt
        )

        let json = String(data: try HostRuntimeEvidenceExporter.encodedData(bundle), encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("session_cookie_login_platform_runner"))
        XCTAssertFalse(json.contains("Set-Cookie"))
        XCTAssertFalse(json.contains("password"))
        XCTAssertFalse(json.contains("token="))
        XCTAssertFalse(json.contains("<html"))
        XCTAssertFalse(json.contains("Authorization"))
    }

    func testLocalBookSecurityScopedHandoffEvidenceOmitsFileNameAndPath() throws {
        let fileURL = URL(fileURLWithPath: "/Users/example/Private Novel Title.epub")
        let bundle = HostRuntimeEvidenceExporter.localBookSecurityScopedHandoffBundle(
            fileURL: fileURL,
            fileSize: 3_200_000,
            accessStarted: true,
            generatedAt: Date(timeIntervalSince1970: 1_782_156_020)
        )

        let evidence = try XCTUnwrap(bundle.evidence.first)
        XCTAssertEqual(evidence.evidenceId, .localBookSecurityScopedHandoff)
        XCTAssertEqual(evidence.coreGapIds, ["S3"])
        XCTAssertEqual(evidence.status, .measuredPass)
        XCTAssertTrue(evidence.liveExecutionClaimed)
        XCTAssertEqual(evidence.subject.fileExtension, "epub")
        XCTAssertEqual(evidence.subject.fileSizeBucket, "lt_10mb")
        XCTAssertTrue(evidence.subject.fileNameRedacted)
        XCTAssertFalse(evidence.redaction.rawLocalFilePathIncluded)

        let json = String(data: try HostRuntimeEvidenceExporter.encodedData(bundle), encoding: .utf8) ?? ""
        XCTAssertFalse(json.contains("Private Novel Title"))
        XCTAssertFalse(json.contains("/Users/example"))
    }
}
