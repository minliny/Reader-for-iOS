import Foundation
import ReaderCoreFoundation
import ReaderCoreModels
import ReaderCoreNativeAdapter
import XCTest
@testable import ReaderShellValidation

final class RustCoreLocalBookImportServiceTests: XCTestCase {
    func testAdapterUsesFrozenImportAndChapterContracts() async throws {
        let runtime = FakeLocalBookRuntime(format: "epub")
        let snapshots = temporaryDirectory("contract-snapshots")
        defer { try? FileManager.default.removeItem(at: snapshots) }
        let input = temporaryFile("contract.epub")
        try Data("contract-book-bytes".utf8).write(to: input)
        defer { try? FileManager.default.removeItem(at: input) }

        let service = RustCoreLocalBookImportService(
            runtime: runtime,
            snapshotStore: SnapshotStore(snapshotRoot: snapshots)
        )
        let summary = try await service.importBook(at: input)

        XCTAssertEqual(runtime.methods, [
            "local_book.import",
            "local_book.chapter.content",
            "local_book.chapter.content",
        ])
        XCTAssertEqual(summary.detectedFormat, .epub)
        XCTAssertEqual(summary.readingAuthority, .nativeCoreMaterialized)
        XCTAssertTrue(summary.canOpenReader)
        XCTAssertEqual(summary.chapters.map(\.chapterURL), [
            "local://fixture-book/chapter/0",
            "local://fixture-book/chapter/1",
        ])
        XCTAssertTrue(summary.chapters.allSatisfy(\.contentCached))
        XCTAssertEqual(runtime.lastImportParams?["format"] as? String, "epub")
        XCTAssertNotNil(runtime.lastImportParams?["bytesBase64"] as? String)

        let cached = SnapshotStore(snapshotRoot: snapshots).loadChapterContentSnapshot(
            sourceId: "local-book",
            chapterURL: "local://fixture-book/chapter/1"
        )
        XCTAssertEqual(cached?.content, "Body 1")
    }

    func testAdapterFailsClosedWhenCoreChapterIdentityDrifts() async throws {
        let runtime = FakeLocalBookRuntime(format: "txt", chapterIndexOffset: 1)
        let snapshots = temporaryDirectory("drift-snapshots")
        defer { try? FileManager.default.removeItem(at: snapshots) }
        let input = temporaryFile("drift.txt")
        try Data("Chapter 1\nBody".utf8).write(to: input)
        defer { try? FileManager.default.removeItem(at: input) }

        let service = RustCoreLocalBookImportService(
            runtime: runtime,
            snapshotStore: SnapshotStore(snapshotRoot: snapshots)
        )
        do {
            _ = try await service.importBook(at: input)
            XCTFail("identity drift must fail closed")
        } catch CoreLocalBookImportBridgeError.failedClosed(let code, _) {
            XCTAssertEqual(code, "SLICE9_LOCAL_CHAPTER_IDENTITY_DRIFT")
        } catch {
            XCTFail("unexpected error: \(error)")
        }
    }

    /// This is a macOS C-ABI/source-test proof against the dependency corpus.
    /// It is not simulator, device, screenshot, performance or release proof.
    func testNativeCoreMaterializesFiveLocalFormatsFromDependencyCorpus() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        let cases: [(String, LocalBookFormat)] = [
            ("txt/txt_utf8_english_chapter_markers.txt", .txt),
            ("epub/epub3_nav_spine_resource_cover.epub", .epub),
            ("pdf/pdf_text_page_pdfkit.pdf", .pdf),
            ("mobi/mobi_clean_room_text_fragment.mobi", .mobi),
            ("umd/umd_clean_room_text_fragment.umd", .umd),
        ]
        for (relativePath, expectedFormat) in cases {
            let snapshotRoot = temporaryDirectory("native-\(expectedFormat.rawValue)")
            defer { try? FileManager.default.removeItem(at: snapshotRoot) }
            let fixture = dependencyCorpusRoot.appendingPathComponent(relativePath)
            XCTAssertTrue(FileManager.default.fileExists(atPath: fixture.path), fixture.path)

            let service = RustCoreLocalBookImportService(
                runtime: runtime,
                requestTimeout: 30,
                snapshotStore: SnapshotStore(snapshotRoot: snapshotRoot)
            )
            let summary = try await service.importBook(at: fixture)

            XCTAssertEqual(summary.detectedFormat, expectedFormat, relativePath)
            XCTAssertEqual(summary.readingAuthority, .nativeCoreMaterialized, relativePath)
            XCTAssertFalse(summary.chapters.isEmpty, relativePath)
            XCTAssertTrue(summary.chapters.allSatisfy(\.contentCached), relativePath)
            XCTAssertTrue(summary.canOpenReader, relativePath)
        }
    }

    private var dependencyCorpusRoot: URL {
        var root = URL(fileURLWithPath: #filePath)
        for _ in 0..<5 { root.deleteLastPathComponent() }
        return root.appendingPathComponent("Reader-Core/samples/localbook/format_differential/fixtures", isDirectory: true)
    }

    private func temporaryFile(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-slice9-\(UUID().uuidString)-\(name)")
    }

    private func temporaryDirectory(_ name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-slice9-\(UUID().uuidString)-\(name)", isDirectory: true)
    }
}

private final class FakeLocalBookRuntime: RustCoreCommandRuntime {
    private let lock = NSLock()
    private let format: String
    private let chapterIndexOffset: Int
    private var events: [UInt64: [ReaderCoreNativeEvent]] = [:]
    private(set) var methods: [String] = []
    private(set) var lastImportParams: [String: Any]?

    init(format: String, chapterIndexOffset: Int = 0) {
        self.format = format
        self.chapterIndexOffset = chapterIndexOffset
    }

    @discardableResult
    func send(json: Data) throws -> Int32 {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        let requestID = try XCTUnwrap((object["requestId"] as? NSNumber)?.uint64Value)
        let method = try XCTUnwrap(object["method"] as? String)
        let params = (object["params"] as? [String: Any]) ?? [:]
        lock.lock()
        methods.append(method)
        if method == "local_book.import" { lastImportParams = params }
        lock.unlock()

        let result: [String: Any]
        switch method {
        case "local_book.import":
            let requestedID = params["bookId"] as? String ?? "fixture-book"
            result = [
                "book": [
                    "bookId": requestedID,
                    "title": "Fixture Book",
                    "author": "Fixture Author",
                ],
                "format": format,
                "encoding": "utf8",
                "byteLen": 19,
                "charLen": 12,
                "chapterCount": 2,
                "toc": [
                    ["index": 0, "title": "Chapter 0", "url": "local://fixture-book/chapter/0"],
                    ["index": 1, "title": "Chapter 1", "url": "local://fixture-book/chapter/1"],
                ],
            ]
        case "local_book.chapter.content":
            let requestedIndex = (params["chapterIndex"] as? NSNumber)?.intValue
                ?? (params["chapterIndex"] as? Int)
                ?? 0
            let returnedIndex = requestedIndex + chapterIndexOffset
            result = [
                "sourceId": "local",
                "bookId": params["bookId"] as? String ?? "fixture-book",
                "chapterIndex": returnedIndex,
                "chapterTitle": "Chapter \(returnedIndex)",
                "content": "Body \(returnedIndex)",
            ]
        default:
            throw ReaderCoreNativeError.coreError(code: "UNEXPECTED_METHOD", message: method)
        }
        let eventData = try JSONSerialization.data(withJSONObject: [
            "protocolVersion": 1,
            "type": "result",
            "requestId": NSNumber(value: requestID),
            "data": result,
        ])
        let event = try ReaderCoreNativeEvent(data: eventData)
        lock.lock()
        events[requestID, default: []].append(event)
        lock.unlock()
        return 0
    }

    func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent? {
        lock.lock()
        defer { lock.unlock() }
        guard let event = events[requestId]?.first else { return nil }
        events[requestId]?.removeFirst()
        return event
    }

    func cancel(requestId: UInt64) throws {
        lock.lock()
        events[requestId] = nil
        lock.unlock()
    }
}
