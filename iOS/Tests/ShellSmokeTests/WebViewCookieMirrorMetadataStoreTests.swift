import XCTest
import ReaderCoreModels
@testable import ReaderShellValidation

final class WebViewCookieMirrorMetadataStoreTests: XCTestCase {

    func testStoreWritesCookieMetadataWithoutValuesQueryOrHTML() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-ios-cookie-metadata-\(UUID().uuidString)", isDirectory: true)
        let outputURL = tempRoot.appendingPathComponent("cookie_mirror_metadata.json")
        let fixedDate = Date(timeIntervalSince1970: 1_782_156_100)
        let store = WebViewCookieMirrorMetadataStore(outputURL: outputURL, clock: { fixedDate })
        let request = RuntimeWebViewRequest(
            requestId: "cookie-request-1",
            sourceId: "source-cookie",
            sourceName: "Cookie Source",
            url: "https://www.example.com/private/path?token=secret-token",
            stage: .detail
        )
        let result = RuntimeWebViewResult.success(
            requestId: request.requestId,
            sourceId: request.sourceId,
            sourceName: request.sourceName,
            originalUrl: request.url,
            finalUrl: "https://www.example.com/private/path?token=secret-token",
            stage: request.stage,
            html: "<html>secret-token</html>",
            interactionResults: [
                RuntimeWebViewInteractionResult.success(
                    stepIndex: 0,
                    stepType: .click,
                    parameters: ["selector": "#login"],
                    updatedCookies: [
                        RuntimeLoginCookie(
                            name: "csrf",
                            value: "interaction-secret-cookie",
                            domain: "www.example.com",
                            path: "/",
                            secure: true,
                            httpOnly: false
                        )
                    ]
                )
            ],
            updatedCookies: [
                RuntimeLoginCookie(
                    name: "sid",
                    value: "raw-session-cookie",
                    domain: ".example.com",
                    path: "/reader",
                    expiresAt: fixedDate.addingTimeInterval(3600),
                    secure: true,
                    httpOnly: true
                )
            ]
        )

        let metadata = try XCTUnwrap(try store.saveCookieMirrorMetadata(request: request, result: result))

        XCTAssertEqual(metadata.schemaVersion, "reader-ios.webview-cookie-mirror-metadata.v1")
        XCTAssertEqual(metadata.cookieCount, 2)
        XCTAssertEqual(metadata.requestedURL.host, "www.example.com")
        XCTAssertTrue(metadata.requestedURL.queryRedacted)
        XCTAssertTrue(metadata.cookies.allSatisfy(\.valueRedacted))
        XCTAssertTrue(metadata.cleanRoom.cleanRoomMaintained)
        XCTAssertFalse(metadata.cleanRoom.externalGPLCodeCopied)

        let json = String(data: try Data(contentsOf: outputURL), encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("sid"))
        XCTAssertTrue(json.contains("csrf"))
        XCTAssertFalse(json.contains("raw-session-cookie"))
        XCTAssertFalse(json.contains("interaction-secret-cookie"))
        XCTAssertFalse(json.contains("secret-token"))
        XCTAssertFalse(json.contains("private/path"))
        XCTAssertFalse(json.contains("<html"))
        XCTAssertFalse(json.contains("Set-Cookie:"))
    }

    func testStoreSkipsEmptyCookieUpdates() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-ios-cookie-empty-\(UUID().uuidString)", isDirectory: true)
        let outputURL = tempRoot.appendingPathComponent("cookie_mirror_metadata.json")
        let store = WebViewCookieMirrorMetadataStore(outputURL: outputURL)
        let request = RuntimeWebViewRequest(
            requestId: "cookie-request-empty",
            sourceId: "source-cookie",
            sourceName: "Cookie Source",
            url: "https://www.example.com",
            stage: .detail
        )
        let result = RuntimeWebViewResult.success(
            requestId: request.requestId,
            sourceId: request.sourceId,
            sourceName: request.sourceName,
            originalUrl: request.url,
            finalUrl: request.url,
            stage: request.stage,
            html: "<html></html>"
        )

        XCTAssertNil(try store.saveCookieMirrorMetadata(request: request, result: result))
        XCTAssertFalse(FileManager.default.fileExists(atPath: outputURL.path))
    }

    func testCookieMirrorEvidenceBundleUsesMetadataOnlySubject() throws {
        let metadata = WebViewCookieMirrorMetadata(
            generatedAt: Date(timeIntervalSince1970: 1_782_156_120),
            requestId: "cookie-request-2",
            sourceId: "source-cookie",
            stage: .content,
            requestedURL: WebViewCookieMirrorURLMetadata(
                urlString: "https://www.example.com/reader/detail?token=secret"
            ),
            finalURL: WebViewCookieMirrorURLMetadata(
                urlString: "https://www.example.com/reader/detail?token=secret"
            ),
            cookies: [
                WebViewCookieMirrorCookieMetadata(
                    cookie: RuntimeLoginCookie(
                        name: "sid",
                        value: "raw-session-cookie",
                        domain: "www.example.com",
                        secure: true,
                        httpOnly: true
                    ),
                    observationSource: .pageResult
                )
            ]
        )

        let bundle = HostRuntimeEvidenceExporter.webViewCookieMirrorBundle(
            metadata: metadata,
            generatedAt: Date(timeIntervalSince1970: 1_782_156_130)
        )
        let evidence = try XCTUnwrap(bundle.evidence.first)

        XCTAssertEqual(evidence.evidenceId, .webViewCookieMirrorAudit)
        XCTAssertEqual(evidence.status, .measuredPass)
        XCTAssertTrue(evidence.liveExecutionClaimed)
        XCTAssertTrue(evidence.subject.cookieMetadataOnly)
        XCTAssertEqual(evidence.subject.sourceId, "source-cookie")
        XCTAssertEqual(evidence.observedArtifacts, [
            "host_runtime_evidence_manifest.json",
            "cookie_mirror_metadata.json"
        ])
        XCTAssertTrue(evidence.blockers.isEmpty)

        let json = String(data: try HostRuntimeEvidenceExporter.encodedData(bundle), encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("webview_cookie_mirror_audit"))
        XCTAssertTrue(json.contains("Cookie metadata count: 1"))
        XCTAssertFalse(json.contains("raw-session-cookie"))
        XCTAssertFalse(json.contains("token=secret"))
        XCTAssertFalse(json.contains("Set-Cookie:"))
    }
}
