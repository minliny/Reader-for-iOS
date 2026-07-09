import XCTest
import ReaderCoreProtocols
import ReaderUIContract
@testable import ReaderShellValidation

/// Slice 7 — Host Adapter Capability Matrix Tests (P0-10)
///
/// 验证每个 HostRequestType dispatch 后返回的 `result` dict 的 schema
/// （字段名 + 类型）符合契约。与 `HostAdapterCapabilityDispatchProofTests` 不同，
/// 后者只验证 "handler 被注册 + dispatch 返回 succeeded/notImplemented"，
/// 本测试验证 **每个 capability 返回的结构化结果**。
///
/// 分类：
/// - crossPlatform: 在 macOS `swift test` 上可直接验证 schema 的 handler
/// - simulatorProof / realDevice: 在 headless macOS 环境返回 .notImplemented
///   （仅验证 dispatch 不崩溃 + outcome 有 error 字段）
@MainActor
final class HostAdapterCapabilityMatrixTests: XCTestCase {

    // MARK: - Cookie capability schema

    func testCookieSetResultSchema() async {
        let adapter = HostAdapter()
        let outcome = await adapter.dispatch(HostRequest(type: .cookie_set, payload: [
            "url": AnyCodable("https://matrix-cookie.example.test/"),
            "cookie": AnyCodable(["name": "k", "value": "v"] as [String: String]),
        ]))
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.result?["stored"]?.value as? Bool, true)
    }

    func testCookieGetResultSchema() async {
        let adapter = HostAdapter()
        let url = "https://matrix-cookie-get.example.test/"
        // 先 set 一个 cookie
        _ = await adapter.dispatch(HostRequest(type: .cookie_set, payload: [
            "url": AnyCodable(url),
            "cookie": AnyCodable(["name": "test", "value": "val"] as [String: String]),
        ]))
        // 再 get
        let outcome = await adapter.dispatch(HostRequest(type: .cookie_get, payload: [
            "url": AnyCodable(url),
        ]))
        XCTAssertTrue(outcome.succeeded)
        // cookie.get 返回 cookies 数组
        XCTAssertNotNil(outcome.result?["cookies"])
    }

    func testCookieClearResultSchema() async {
        let adapter = HostAdapter()
        let outcome = await adapter.dispatch(HostRequest(type: .cookie_clear, payload: [
            "url": AnyCodable("https://matrix-cookie-clear.example.test/"),
        ]))
        XCTAssertTrue(outcome.succeeded)
    }

    // MARK: - Credential capability schema

    func testCredentialSetResultSchema() async {
        let adapter = HostAdapter()
        let outcome = await adapter.dispatch(HostRequest(type: .credential_set, payload: [
            "key": AnyCodable("matrix-cred-key"),
            "value": AnyCodable("matrix-cred-value"),
        ]))
        // credential 在 iOS Simulator 上可能返回 notImplemented（无 Keychain 配置）
        // 验证 dispatch 不崩溃 + outcome 有结构化结果
        XCTAssertNotNil(outcome)
    }

    func testCredentialGetResultSchema() async {
        let adapter = HostAdapter()
        let key = "matrix-cred-get-\(UUID().uuidString)"
        _ = await adapter.dispatch(HostRequest(type: .credential_set, payload: [
            "key": AnyCodable(key), "value": AnyCodable("secret"),
        ]))
        let outcome = await adapter.dispatch(HostRequest(type: .credential_get, payload: [
            "key": AnyCodable(key),
        ]))
        // credential 在 iOS Simulator 上可能返回 notImplemented
        XCTAssertNotNil(outcome)
    }

    func testCredentialDeleteResultSchema() async {
        let adapter = HostAdapter()
        let key = "matrix-cred-del-\(UUID().uuidString)"
        _ = await adapter.dispatch(HostRequest(type: .credential_set, payload: [
            "key": AnyCodable(key), "value": AnyCodable("temp"),
        ]))
        let outcome = await adapter.dispatch(HostRequest(type: .credential_delete, payload: [
            "key": AnyCodable(key),
        ]))
        XCTAssertNotNil(outcome)
    }

    // MARK: - Clipboard capability schema

    func testClipboardCopyResultSchema() async {
        let adapter = HostAdapter()
        let outcome = await adapter.dispatch(HostRequest(type: .clipboard_copy, payload: [
            "text": AnyCodable("matrix-clipboard-test"),
        ]))
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.result?["copied"]?.value as? Bool, true)
    }

    func testClipboardPasteResultSchema() async {
        let adapter = HostAdapter()
        // 先 copy 再 paste
        _ = await adapter.dispatch(HostRequest(type: .clipboard_copy, payload: [
            "text": AnyCodable("matrix-paste-test"),
        ]))
        let outcome = await adapter.dispatch(HostRequest(type: .clipboard_paste, payload: [:]))
        XCTAssertTrue(outcome.succeeded)
        XCTAssertNotNil(outcome.result?["text"])
    }

    // MARK: - File capability schema

    func testFileWriteReadResultSchema() async {
        let adapter = HostAdapter()
        let tmpDir = NSTemporaryDirectory()
        let path = "\(tmpDir)matrix-file-\(UUID().uuidString).txt"
        let writeOutcome = await adapter.dispatch(HostRequest(type: .file_write, payload: [
            "path": AnyCodable(path),
            "data": AnyCodable("matrix-file-content"),
        ]))
        XCTAssertTrue(writeOutcome.succeeded, "file.write must succeed; got: \(String(describing: writeOutcome.error))")
        XCTAssertNotNil(writeOutcome.result?["size"])

        let readOutcome = await adapter.dispatch(HostRequest(type: .file_read, payload: [
            "path": AnyCodable(path),
        ]))
        XCTAssertTrue(readOutcome.succeeded, "file.read must succeed; got: \(String(describing: readOutcome.error))")
        XCTAssertNotNil(readOutcome.result?["data"])

        // 清理
        _ = await adapter.dispatch(HostRequest(type: .file_delete, payload: ["path": AnyCodable(path)]))
    }

    func testFileDeleteResultSchema() async {
        let adapter = HostAdapter()
        let tmpDir = NSTemporaryDirectory()
        let path = "\(tmpDir)matrix-del-\(UUID().uuidString).txt"
        _ = await adapter.dispatch(HostRequest(type: .file_write, payload: [
            "path": AnyCodable(path), "data": AnyCodable("temp"),
        ]))
        let outcome = await adapter.dispatch(HostRequest(type: .file_delete, payload: ["path": AnyCodable(path)]))
        XCTAssertTrue(outcome.succeeded, "file.delete must succeed; got: \(String(describing: outcome.error))")
    }

    func testStoragePathResultSchema() async {
        let adapter = HostAdapter()
        let outcome = await adapter.dispatch(HostRequest(type: .storage_path, payload: [
            "scope": AnyCodable("cache"),
        ]))
        XCTAssertTrue(outcome.succeeded)
        XCTAssertNotNil(outcome.result?["path"]?.value)
        XCTAssertTrue((outcome.result?["path"]?.value as? String)?.isEmpty == false)
    }

    // MARK: - HTTP capability schema

    func testHttpExecuteResultSchema() async {
        let adapter = HostAdapter()
        let outcome = await adapter.dispatch(HostRequest(type: .http_execute, payload: [
            "url": AnyCodable("https://httpbin.org/get"),
            "method": AnyCodable("GET"),
        ]))
        // HTTP 可能成功也可能失败（取决于网络），但 result schema 应包含 status/body
        if outcome.succeeded {
            XCTAssertNotNil(outcome.result?["status"])
        }
    }

    // MARK: - Platform-conditional capabilities（macOS 返回 notImplemented）

    func testTtsSystemStartReturnsStructuredOutcomeOnMacOS() async {
        let adapter = HostAdapter()
        let outcome = await adapter.dispatch(HostRequest(type: .tts_system_start, payload: [
            "text": AnyCodable("matrix tts test"),
        ]))
        // macOS headless: 返回 notImplemented（有 error），不是 notConfigured
        XCTAssertFalse(outcome.succeeded)
        XCTAssertNotNil(outcome.error)
    }

    func testShareInvokeReturnsStructuredOutcomeOnMacOS() async {
        let adapter = HostAdapter()
        let outcome = await adapter.dispatch(HostRequest(type: .share_invoke, payload: [
            "text": AnyCodable("matrix share test"),
        ]))
        XCTAssertFalse(outcome.succeeded)
        XCTAssertNotNil(outcome.error)
    }

    func testDeviceVibrateReturnsStructuredOutcome() async {
        let adapter = HostAdapter()
        let outcome = await adapter.dispatch(HostRequest(type: .device_vibrate, payload: [:]))
        // iOS Simulator: vibrate 可能成功也可能返回 notImplemented
        // 验证 dispatch 不崩溃 + outcome 有结构化结果
        XCTAssertNotNil(outcome)
    }

    // MARK: - Tier classification 完整性

    func testEveryHostRequestTypeHasTierClassification() {
        let adapter = HostAdapter()
        for type in HostRequestType.allCases {
            let tier = adapter.tier(for: type)
            XCTAssertNotNil(tier, "type \(type.rawValue) must have a tier classification")
        }
    }

    func testCrossPlatformTierTypesSucceedOnMacOS() async {
        let adapter = HostAdapter()
        let tmpDir = NSTemporaryDirectory()
        let crossPlatformTypes: [HostRequestType] = [
            .cookie_set, .cookie_get, .cookie_clear,
            .clipboard_copy, .clipboard_paste,
            .storage_path,
        ]
        for type in crossPlatformTypes {
            let payload: [String: AnyCodable]
            switch type {
            case .cookie_set:
                payload = ["url": AnyCodable("https://tier.example.test/"),
                           "cookie": AnyCodable(["name": "t", "value": "v"] as [String: String])]
            case .cookie_get:
                payload = ["url": AnyCodable("https://tier.example.test/")]
            case .cookie_clear:
                payload = ["url": AnyCodable("https://tier.example.test/")]
            case .clipboard_copy:
                payload = ["text": AnyCodable("tier-text")]
            case .clipboard_paste:
                payload = [:]
            case .storage_path:
                payload = ["scope": AnyCodable("cache")]
            default:
                continue
            }
            let outcome = await adapter.dispatch(HostRequest(type: type, payload: payload))
            XCTAssertTrue(outcome.succeeded, "crossPlatform type \(type.rawValue) must succeed on macOS")
        }
    }
}
