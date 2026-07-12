import XCTest
import ReaderUIContract
@testable import ReaderShellValidation

@MainActor
final class HostContract25CapabilityTests: XCTestCase {
    private let contract25Types: Set<HostRequestType> = [
        .file_select, .font_registerFile,
        .clipboard_read, .clipboard_write,
        .tts_start, .tts_stop, .tts_pause,
        .brightness_set, .brightness_get,
        .screen_keepAwake, .screen_allowSleep,
        .haptics_light, .haptics_medium, .haptics_heavy,
        .network_status,
        .webdav_connect, .webdav_backup, .webdav_restore,
        .share_text, .share_file,
        .background_task_start, .background_task_end,
    ]

    func testContract25ManifestHasExactly22TypesAndAllDispatch() async {
        XCTAssertEqual(contract25Types.count, 22)
        let adapter = HostAdapter()
        for type in contract25Types {
            XCTAssertTrue(adapter.registeredTypes().contains(type), type.rawValue)
            XCTAssertNotNil(adapter.tier(for: type), type.rawValue)
            let outcome = await adapter.dispatch(HostRequest(
                type: type,
                payload: minimalPayload(for: type)
            ))
            if case .notConfigured(let missing) = outcome.error {
                XCTFail("\(missing.rawValue) bypassed HostCapabilityRegistry")
            }
        }
    }

    func testClipboardAliasesUseSinglePasteboardOwner() async {
        let adapter = HostAdapter()
        let value = "contract-25-\(UUID().uuidString)"
        let write = await adapter.dispatch(HostRequest(
            type: .clipboard_write,
            payload: ["text": AnyCodable(value)]
        ))
        let read = await adapter.dispatch(HostRequest(type: .clipboard_read))
        XCTAssertTrue(write.succeeded)
        XCTAssertEqual(write.result?["written"]?.value as? Bool, true)
        XCTAssertTrue(read.succeeded)
        XCTAssertEqual(read.result?["text"]?.value as? String, value)

        let invalid = await adapter.dispatch(HostRequest(type: .clipboard_write))
        guard case .invalidParams = invalid.error else {
            return XCTFail("clipboard.write must reject missing canonical text")
        }
    }

    func testTTSAliasesReuseExistingSynthAndValidateText() async {
        let synth = Contract25TTSSynth()
        let adapter = HostAdapter()
        adapter.setTTSSynthProvider { synth }

        let invalid = await adapter.dispatch(HostRequest(type: .tts_start))
        guard case .invalidParams = invalid.error else {
            return XCTFail("tts.start must reject missing canonical text")
        }
        let start = await adapter.dispatch(HostRequest(
            type: .tts_start,
            payload: ["text": AnyCodable("hello")]
        ))
        let pause = await adapter.dispatch(HostRequest(type: .tts_pause))
        let stop = await adapter.dispatch(HostRequest(type: .tts_stop))
        XCTAssertTrue(start.succeeded)
        XCTAssertTrue(pause.succeeded)
        XCTAssertTrue(stop.succeeded)
        XCTAssertEqual(synth.spoken, ["hello"])
        XCTAssertEqual(synth.pauseCount, 1)
        XCTAssertEqual(synth.stopCount, 1)
    }

    func testFileSelectUsesPresenterSeamAndFailsClosedWithoutUI() async {
        let unavailable = HostAdapter()
        let closed = await unavailable.dispatch(HostRequest(type: .file_select))
        guard case .notImplemented(.file_select, _) = closed.error else {
            return XCTFail("file.select must fail closed without presenter: \(String(describing: closed.error))")
        }

        let selectedURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("sample.txt")
        let presenter = Contract25FilePresenter(urls: [selectedURL])
        let adapter = HostAdapter()
        adapter.setFileSelectionPresenterProvider { presenter }
        let outcome = await adapter.dispatch(HostRequest(
            type: .file_select,
            payload: [
                "mimeTypes": AnyCodable([AnyCodable("public.text")]),
                "allowsMultiple": AnyCodable(false),
            ]
        ))
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.result?["selected"]?.value as? Bool, true)
        let files = outcome.result?["files"]?.value as? [AnyCodable]
        let first = files?.first?.value as? [String: AnyCodable]
        XCTAssertEqual(first?["name"]?.value as? String, "sample.txt")

        let invalid = await adapter.dispatch(HostRequest(
            type: .file_select,
            payload: ["mimeTypes": AnyCodable("public.text")]
        ))
        XCTAssertNotNil(invalid.error)
    }

    func testFontRegistrationRejectsMissingAndUnsupportedFiles() async throws {
        let adapter = HostAdapter()
        let missing = await adapter.dispatch(HostRequest(type: .font_registerFile))
        guard case .invalidParams = missing.error else {
            return XCTFail("font.registerFile must reject missing canonical fields")
        }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("not-a-font-\(UUID().uuidString).txt")
        try Data("x".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let outcome = await adapter.dispatch(HostRequest(
            type: .font_registerFile,
            payload: ["path": AnyCodable(url.path), "familyName": AnyCodable("Invalid")]
        ))
        XCTAssertEqual(outcome.error, .invalidParams("font.registerFile supports .ttf/.otf/.ttc files"))
    }

    func testBrightnessDTOAndInjectedController() async {
        let controller = Contract25BrightnessController(value: 0.25)
        let registry = HostCapabilityRegistry()
        registry.register(HostDisplayCapability(controller: controller))
        let adapter = HostAdapter(registry: registry)

        let outOfRange = await adapter.dispatch(HostRequest(
            type: .brightness_set,
            payload: ["value": AnyCodable(1.1)]
        ))
        XCTAssertEqual(
            outOfRange.error,
            .invalidParams("brightness.set `value` must be in 0...1")
        )
        let set = await adapter.dispatch(HostRequest(
            type: .brightness_set,
            payload: ["value": AnyCodable(0.7)]
        ))
        XCTAssertTrue(set.succeeded)
        let result = await adapter.dispatch(HostRequest(type: .brightness_get))
        XCTAssertEqual(result.result?["brightness"]?.value as? Double, 0.7)
    }

    func testScreenHapticsAndBackgroundAliasesHaveStrictDispatch() async {
        let adapter = HostAdapter()
        for type in [
            HostRequestType.screen_keepAwake, .screen_allowSleep,
            .haptics_light, .haptics_medium, .haptics_heavy,
        ] {
            let result = await adapter.dispatch(HostRequest(type: type))
            if !result.succeeded {
                guard case .notImplemented(let reportedType, _) = result.error,
                      reportedType == type else {
                    return XCTFail("unexpected \(type.rawValue) error: \(String(describing: result.error))")
                }
            }
        }
        let missingStart = await adapter.dispatch(HostRequest(type: .background_task_start))
        let missingEnd = await adapter.dispatch(HostRequest(type: .background_task_end))
        guard case .invalidParams = missingStart.error else {
            return XCTFail("background.task.start must reject missing name")
        }
        guard case .invalidParams = missingEnd.error else {
            return XCTFail("background.task.end must reject missing taskId")
        }
    }

    func testNetworkStatusUsesTypedProviderAndSurfacesFailures() async {
        let registry = HostCapabilityRegistry()
        registry.register(HostNetworkCapability(provider: Contract25NetworkProvider()))
        let adapter = HostAdapter(registry: registry)
        let outcome = await adapter.dispatch(HostRequest(type: .network_status))
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.result?["connected"]?.value as? Bool, true)
        XCTAssertEqual(outcome.result?["interface"]?.value as? String, "wifi")
    }

    func testWebDAVDTOAndExecutorAreRealSeamsNotSyntheticSuccess() async {
        let executor = Contract25WebDAVExecutor()
        let adapter = HostAdapter()
        adapter.setWebDAVExecutorProvider { executor }

        let partial = await adapter.dispatch(HostRequest(
            type: .webdav_connect,
            payload: ["serverURL": AnyCodable("https://dav.example.test")]
        ))
        guard case .invalidParams = partial.error else {
            return XCTFail("partial credentials must fail")
        }
        let connect = await adapter.dispatch(HostRequest(type: .webdav_connect))
        let backup = await adapter.dispatch(HostRequest(type: .webdav_backup))
        let missingRemote = await adapter.dispatch(HostRequest(type: .webdav_restore))
        let restore = await adapter.dispatch(HostRequest(
            type: .webdav_restore,
            payload: ["remoteURL": AnyCodable("https://dav.example.test/a.readerbackup.json")]
        ))
        XCTAssertTrue(connect.succeeded)
        XCTAssertTrue(backup.succeeded)
        XCTAssertFalse(missingRemote.succeeded)
        XCTAssertTrue(restore.succeeded)
        let calls = await executor.calls()
        XCTAssertEqual(calls, ["connect", "backup", "restore"])
    }

    func testShareAliasesValidateAndPassActualFileURL() async throws {
        let presenter = Contract25SharePresenter()
        let adapter = HostAdapter()
        adapter.setSharePresenterProvider { presenter }
        let missingText = await adapter.dispatch(HostRequest(type: .share_text))
        guard case .invalidParams = missingText.error else {
            return XCTFail("share.text must reject missing text")
        }
        let text = await adapter.dispatch(HostRequest(
            type: .share_text,
            payload: ["text": AnyCodable("Reader")]
        ))
        XCTAssertTrue(text.succeeded)

        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("share-\(UUID().uuidString).txt")
        try Data("Reader".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let outcome = await adapter.dispatch(HostRequest(
            type: .share_file,
            payload: ["path": AnyCodable(file.path)]
        ))
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(presenter.lastFileURL, file)
    }

    private func minimalPayload(for type: HostRequestType) -> [String: AnyCodable] {
        switch type {
        case .file_select, .clipboard_read, .tts_stop, .tts_pause,
             .brightness_get, .screen_keepAwake, .screen_allowSleep,
             .haptics_light, .haptics_medium, .haptics_heavy,
             .network_status, .webdav_connect, .webdav_backup:
            return [:]
        case .font_registerFile:
            return ["path": AnyCodable("/missing"), "familyName": AnyCodable("Missing")]
        case .font_unregisterFile:
            return ["path": AnyCodable("/missing"), "familyName": AnyCodable("Missing")]
        case .share_file:
            return ["path": AnyCodable("/missing")]
        case .clipboard_write, .share_text:
            return ["text": AnyCodable("proof")]
        case .tts_start:
            return ["text": AnyCodable("proof")]
        case .brightness_set:
            return ["value": AnyCodable(0.5)]
        case .webdav_restore:
            return ["remoteURL": AnyCodable("https://dav.example.test/backup.readerbackup.json")]
        case .background_task_start:
            return ["name": AnyCodable("proof")]
        case .background_task_end:
            return ["taskId": AnyCodable("missing")]
        default:
            return [:]
        }
    }
}

@MainActor
private final class Contract25TTSSynth: HostTTSSynth {
    var spoken: [String] = []
    var pauseCount = 0
    var stopCount = 0
    func speak(_ text: String) { spoken.append(text) }
    func pause() { pauseCount += 1 }
    func resume() {}
    func stop() { stopCount += 1 }
}

@MainActor
private final class Contract25FilePresenter: HostFileSelectionPresenter {
    let urls: [URL]
    init(urls: [URL]) { self.urls = urls }
    func selectFiles(mimeTypes: [String], allowsMultiple: Bool) async throws -> [URL] { urls }
}

private actor Contract25BrightnessController: HostBrightnessControlling {
    private var value: Double
    init(value: Double) { self.value = value }
    func brightness() async -> Double { value }
    func setBrightness(_ value: Double) async { self.value = value }
}

private struct Contract25NetworkProvider: HostNetworkStatusProviding {
    func currentStatus() async throws -> HostNetworkStatus {
        HostNetworkStatus(
            connected: true,
            status: "connected",
            interface: "wifi",
            isExpensive: false,
            isConstrained: false
        )
    }
}

private actor Contract25WebDAVExecutor: HostWebDAVExecuting {
    private var recorded: [String] = []
    func connect(credentials: HostWebDAVCredentialOverride?) async throws -> HostWebDAVConnectionResult {
        recorded.append("connect")
        return HostWebDAVConnectionResult(statusCode: 207, serverURL: "https://dav.example.test")
    }
    func backup(credentials: HostWebDAVCredentialOverride?) async throws -> HostWebDAVBackupResult {
        recorded.append("backup")
        return HostWebDAVBackupResult(
            statusCode: 201,
            remoteURL: "https://dav.example.test/a.readerbackup.json",
            byteCount: 10,
            itemCount: 1
        )
    }
    func restore(
        remoteURL: String,
        credentials: HostWebDAVCredentialOverride?
    ) async throws -> HostWebDAVRestoreResult {
        recorded.append("restore")
        return HostWebDAVRestoreResult(
            statusCode: 200,
            remoteURL: remoteURL,
            restoredItemCount: 1
        )
    }
    func calls() -> [String] { recorded }
}

@MainActor
private final class Contract25SharePresenter: HostSharePresenter {
    var lastFileURL: URL?
    func present(items: [String], excludedActivityTypes: [String]?) async -> String? {
        "contract25.text"
    }
    func present(fileURL: URL, excludedActivityTypes: [String]?) async -> String? {
        lastFileURL = fileURL
        return "contract25.file"
    }
}
