import XCTest
import ReaderCoreModels
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
        XCTAssertNotNil(mapping[.reader_location_resolve])
        XCTAssertNotNil(mapping[.book_parse])
        XCTAssertNotNil(mapping[.bookshelf_list])
    }

    func testCommandMappingTableSourceSearchMapsToBookSearch() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.source_search], "book.search")
    }

    func testCommandMappingTableSourceDetailMapsToBookDetail() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.source_detail], "book.detail")
    }

    func testCommandMappingTableContentLoadMapsToChapterContent() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.content_load], "chapter.content")
    }

    func testCommandMappingTableChapterListMapsToBookToc() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.chapter_list], "book.toc")
    }

    func testCommandMappingTableReaderProgressUpdateMapsToReadingProgressUpdate() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.reader_progress_update], "reading.progress.update")
    }

    func testCommandMappingTableReaderLocationResolveMapsToSameName() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.reader_location_resolve], "reader.location.resolve")
    }

    func testCommandMappingTableBookParseMapsToLocalBookParse() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.book_parse], "local_book.parse")
    }

    func testCommandMappingTableBookshelfListMapsToSameName() {
        let mapping = ReaderCoreBridge.commandMapping
        XCTAssertEqual(mapping[.bookshelf_list], "bookshelf.list")
    }

    // MARK: - ReaderCoreBridge real provider/Core dispatch

    func testCoreBridgeSendSourceSearchDispatchesProviderAndReturnsCompletedEvent() async throws {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)
        defer {
            provider.resetMock()
            provider.setMode(.rustCore)
        }

        let bridge = ReaderCoreBridge(provider: provider)
        let command = CoreCommand(
            type: .source_search,
            payload: ["query": AnyCodable("test")],
            correlationId: "corr-search",
            requestId: "req-search"
        )
        let result = try await bridge.send(command)

        XCTAssertEqual(result.type, .source_search_completed)
        XCTAssertEqual(result.correlationId, "corr-search")
        XCTAssertEqual(result.requestId, "req-search")
        XCTAssertEqual(result.payload["count"]?.value as? Int, MockReaderCoreService.mockSearchResults.count)
        XCTAssertEqual(
            (result.payload["results"]?.value as? [AnyCodable])?.count,
            MockReaderCoreService.mockSearchResults.count
        )
    }

    func testCoreBridgeSendSourceDetailDispatchesProviderAndReturnsBook() async throws {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)
        defer {
            provider.resetMock()
            provider.setMode(.rustCore)
        }

        let result = try await ReaderCoreBridge(provider: provider).send(CoreCommand(
            type: .source_detail,
            payload: ["detailUrl": AnyCodable("https://example.com/book/1")]
        ))

        XCTAssertEqual(result.type, .source_detail_loaded)
        let book = result.payload["book"]?.value as? [String: AnyCodable]
        XCTAssertEqual(book?["title"]?.value as? String, "凡人修仙传")
    }

    func testCoreBridgeSendChapterListDispatchesProviderAndReturnsChapters() async throws {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)
        defer {
            provider.resetMock()
            provider.setMode(.rustCore)
        }

        let result = try await ReaderCoreBridge(provider: provider).send(CoreCommand(
            type: .chapter_list,
            payload: ["bookUrl": AnyCodable("https://example.com/book/1")]
        ))

        XCTAssertEqual(result.type, .chapter_listed)
        XCTAssertEqual(result.payload["count"]?.value as? Int, MockReaderCoreService.mockTOCItems.count)
    }

    func testCoreBridgeSendContentLoadDispatchesProviderAndReturnsContent() async throws {
        let provider = ReaderCoreServiceProvider.shared
        provider.setMockScenario(.success)
        defer {
            provider.resetMock()
            provider.setMode(.rustCore)
        }

        let result = try await ReaderCoreBridge(provider: provider).send(CoreCommand(
            type: .content_load,
            payload: ["chapterId": AnyCodable("ch-001")]
        ))

        XCTAssertEqual(result.type, .content_loaded)
        let content = result.payload["content"]?.value as? [String: AnyCodable]
        XCTAssertFalse((content?["content"]?.value as? String ?? "").isEmpty)
    }

    func testCoreBridgeSendProgressUpdateMapsPayloadAndExecutesCoreMethod() async throws {
        let provider = RecordingCoreBridgeProvider()
        let bridge = ReaderCoreBridge(provider: provider)
        let command = CoreCommand(
            type: .reader_progress_update,
            payload: [
                "bookId": AnyCodable("bk-001"),
                "sourceId": AnyCodable("src-001"),
                "chapterIndex": AnyCodable(4),
                "locator": AnyCodable([
                    "type": AnyCodable("char-offset"),
                    "charOffset": AnyCodable(512),
                    "locationRevision": AnyCodable("rev-7"),
                ]),
                "progress": AnyCodable(0.42),
            ],
            requestId: "900001"
        )

        let result = try await bridge.send(command)

        XCTAssertEqual(provider.lastDirectMethod, "reading.progress.update")
        XCTAssertEqual(provider.lastDirectRequestId, "900001")
        XCTAssertEqual(provider.lastDirectParams?["bookId"] as? String, "bk-001")
        XCTAssertEqual(provider.lastDirectParams?["chapterIndex"] as? Int, 4)
        XCTAssertEqual(provider.lastDirectParams?["chapterOffset"] as? Int, 512)
        XCTAssertEqual(provider.lastDirectParams?["chapterProgress"] as? Double, 0.42)
        XCTAssertEqual(provider.lastDirectParams?["locationRevision"] as? String, "rev-7")
        XCTAssertEqual(result.type, .reader_progress_updated)
        XCTAssertEqual(result.payload["stored"]?.value as? Bool, true)
    }

    func testCoreBridgeUnsupportedCommandThrowsTypedErrorInsteadOfReturningNil() async {
        let bridge = ReaderCoreBridge(provider: RecordingCoreBridgeProvider())
        do {
            _ = try await bridge.send(CoreCommand(type: .rss_list, payload: [:]))
            XCTFail("rss.list Core bridge path remains pending; RSS events are canonical via ReaderRssPilotCoordinator")
        } catch let error as ReaderCoreBridgeError {
            XCTAssertEqual(error, .unsupportedCommand(.rss_list, mappedMethod: "(pending)"))
        } catch {
            XCTFail("Expected ReaderCoreBridgeError, got \(error)")
        }
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

@MainActor
private final class RecordingCoreBridgeProvider: ReaderCoreBridgeServiceProviding {
    private(set) var lastDirectMethod: String?
    private(set) var lastDirectParams: [String: Any]?
    private(set) var lastDirectRequestId: String?

    func searchBooks(keyword: String, page: Int, source: BookSource?) async -> LoadState<[SearchResultItem]> {
        .unsupported("not configured in recording provider")
    }

    func getBookDetail(bookURL: String, source: BookSource?) async -> LoadState<SearchResultItem> {
        .unsupported("not configured in recording provider")
    }

    func getChapterList(bookURL: String, source: BookSource?) async -> LoadState<[TOCItem]> {
        .unsupported("not configured in recording provider")
    }

    func getChapterContent(chapterURL: String, source: BookSource?) async -> LoadState<ContentPage> {
        .unsupported("not configured in recording provider")
    }

    func executeCoreCommand(
        method: String,
        params: [String: Any],
        requestId: String?
    ) async -> Result<[String: Any], AppReaderError> {
        lastDirectMethod = method
        lastDirectParams = params
        lastDirectRequestId = requestId
        return .success([
            "stored": true,
            "bookId": params["bookId"] as? String ?? "",
        ])
    }
}
