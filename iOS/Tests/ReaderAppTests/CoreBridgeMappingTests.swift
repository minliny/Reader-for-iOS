import XCTest
import ReaderUIContract
@testable import ReaderShellValidation

/// Slice 7 — CoreBridge Mapping Tests (P0-09)
///
/// 验证 UiEvent → CoreCommand/HostRequest 的映射完整性。
/// 真源：generated/swift/UiEvent.swift + generated/swift/CoreCommand.swift +
/// HostCapabilityRegistry.swift 中的 HostRequestType
@MainActor
final class CoreBridgeMappingTests: XCTestCase {

    // MARK: - CoreCommand mapping 表完整性

    func testCommandMappingTableContainsCoreCommands() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertNotNil(mapping[.source_search])
        XCTAssertNotNil(mapping[.source_detail])
        XCTAssertNotNil(mapping[.content_load])
        XCTAssertNotNil(mapping[.chapter_list])
        XCTAssertNotNil(mapping[.reader_progress_update])
    }

    func testCommandMappingTableSourceSearchMapsToBookSearch() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.source_search], "book.search")
    }

    func testCommandMappingTableSourceDetailMapsToBookInfo() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.source_detail], "book.info")
    }

    func testCommandMappingTableContentLoadMapsToChapterContent() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.content_load], "chapter.content")
    }

    func testCommandMappingTableChapterListMapsToChapterList() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.chapter_list], "chapter.list")
    }

    func testCommandMappingTableReaderProgressUpdateMapsToReadingProgressUpdate() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.reader_progress_update], "reading.progress.update")
    }

    // MARK: - ReaderCoreBridge.send() 返回 nil 占位验证

    func testCoreBridgeSendSourceSearchReturnsNilPlaceholder() async throws {
        let bridge = ReaderCoreBridge()
        let command = CoreCommand(type: .source_search, payload: ["query": AnyCodable("test")])
        let result = try await bridge.send(command)
        // Slice 5 占位：send 返回 nil（后续 slice 接真实 service）
        XCTAssertNil(result)
    }

    func testCoreBridgeSendContentLoadReturnsNilPlaceholder() async throws {
        let bridge = ReaderCoreBridge()
        let command = CoreCommand(type: .content_load, payload: ["chapterId": AnyCodable("ch-001")])
        let result = try await bridge.send(command)
        XCTAssertNil(result)
    }

    func testCoreBridgeSendUnknownCommandReturnsNil() async throws {
        let bridge = ReaderCoreBridge()
        let command = CoreCommand(type: .rss_list, payload: [:])
        let result = try await bridge.send(command)
        XCTAssertNil(result)
    }

    // MARK: - HostAdapter dispatch 完整性（与 UiEvent 关联）

    func testHostAdapterDispatchAllHostRequestTypesRegistered() async {
        let adapter = HostAdapter()
        let registered = adapter.registeredTypes()
        let allTypes = Set(HostRequestType.allCases)
        let missing = allTypes.subtracting(registered)
        XCTAssertTrue(missing.isEmpty, "HostAdapter must register all HostRequestType cases; missing: \(missing)")
    }

    func testHostAdapterDispatchCookieSetReturnsStructuredResult() async {
        let adapter = HostAdapter()
        let url = "https://mapping-proof.example.test/"
        let request = HostRequest(type: .cookie_set, payload: [
            "url": AnyCodable(url),
            "cookie": AnyCodable(["name": "test", "value": "val"] as [String: String]),
        ])
        let outcome = await adapter.dispatch(request)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.result?["stored"]?.value as? Bool, true)
    }

    func testHostAdapterDispatchClipboardCopyReturnsStructuredResult() async {
        let adapter = HostAdapter()
        let request = HostRequest(type: .clipboard_copy, payload: ["text": AnyCodable("hello")])
        let outcome = await adapter.dispatch(request)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertEqual(outcome.result?["copied"]?.value as? Bool, true)
    }

    func testHostAdapterDispatchStoragePathReturnsStructuredResult() async {
        let adapter = HostAdapter()
        let request = HostRequest(type: .storage_path, payload: ["scope": AnyCodable("cache")])
        let outcome = await adapter.dispatch(request)
        XCTAssertTrue(outcome.succeeded)
        XCTAssertNotNil(outcome.result?["path"]?.value)
    }
}
