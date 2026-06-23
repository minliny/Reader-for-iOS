import XCTest
@testable import ReaderApp
import ReaderAppPersistence
@testable import ReaderShellValidation
import ReaderCoreModels

@MainActor
final class LocalBookCoreImportBridgeTests: XCTestCase {
    func testFileImportViewModelUsesCoreImporterForTXTChapterDetection() async throws {
        let url = temporaryFileURL(name: "core-local.txt")
        try Data("Chapter 1\nBody\nChapter 2\nMore".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let viewModel = FileImportViewModel()
        await viewModel.handleSelectedFile(url)

        guard case .imported(let summary) = viewModel.importState else {
            XCTFail("Expected Core-backed imported state, got \(viewModel.importState)")
            return
        }

        XCTAssertEqual(summary.book.title, url.deletingPathExtension().lastPathComponent)
        XCTAssertEqual(summary.book.fileFormat, .txt)
        XCTAssertEqual(summary.detectedFormat, .txt)
        XCTAssertEqual(summary.detectedEncoding, "utf-8")
        XCTAssertEqual(summary.chapterCount, 2)
        XCTAssertEqual(summary.chapters.count, 2)
        XCTAssertEqual(summary.firstChapterTitle, "Chapter 1")
        XCTAssertNotNil(summary.firstChapterURL)
        XCTAssertTrue(summary.chapters.allSatisfy(\.contentCached))
        XCTAssertFalse(summary.book.id.isEmpty)
        XCTAssertFalse(summary.sourceChecksum.isEmpty)
        XCTAssertTrue(summary.cleanRoomMaintained)
        XCTAssertFalse(summary.externalGPLCodeCopied)
    }

    func testTXTImportCachesReadableContentForReaderViewModel() async throws {
        let url = temporaryFileURL(name: "core-readable.txt")
        try Data("Chapter 1\nBody from cache\nChapter 2\nMore cached text".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let snapshotRoot = temporaryDirectoryURL(name: "local-book-snapshots")
        defer { try? FileManager.default.removeItem(at: snapshotRoot) }
        let snapshotStore = SnapshotStore(snapshotRoot: snapshotRoot)
        let importer = CoreLocalBookImportService(snapshotStore: snapshotStore)
        let viewModel = FileImportViewModel(importer: importer)

        await viewModel.handleSelectedFile(url)

        guard case .imported(let summary) = viewModel.importState else {
            XCTFail("Expected Core-backed imported state, got \(viewModel.importState)")
            return
        }
        guard let chapterURL = summary.firstChapterURL,
              let chapterTitle = summary.firstChapterTitle
        else {
            XCTFail("Expected a first local chapter URL")
            return
        }

        let snapshot = snapshotStore.loadChapterContentSnapshot(sourceId: "local-book", chapterURL: chapterURL)
        XCTAssertEqual(snapshot?.chapterTitle, "Chapter 1")
        XCTAssertTrue(snapshot?.content.contains("Body from cache") == true)
        XCTAssertEqual(snapshot?.nextChapterURL, summary.chapters.dropFirst().first?.chapterURL)

        let readerViewModel = ReaderViewModel(
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            bookID: summary.book.id,
            sourceID: "local-book",
            snapshotStore: snapshotStore
        )
        await readerViewModel.loadContent()

        guard case .cached(let page) = readerViewModel.readerState else {
            XCTFail("Expected ReaderViewModel to load local TXT from SnapshotStore, got \(readerViewModel.readerState)")
            return
        }
        XCTAssertEqual(page.chapterURL, chapterURL)
        XCTAssertTrue(page.content.contains("Body from cache"))

        let readerWithChapterList = ReaderViewModel(
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            chapterList: summary.cachedTOCItems,
            currentChapterIndex: 0,
            bookID: summary.book.id,
            sourceID: "local-book",
            snapshotStore: snapshotStore
        )
        await readerWithChapterList.loadContent()
        XCTAssertTrue(readerWithChapterList.canGoNextChapter)

        readerWithChapterList.goNextChapter()
        await waitForCachedChapter(
            readerWithChapterList,
            chapterURL: summary.chapters[1].chapterURL,
            contentFragment: "More cached text"
        )
    }

    func testFileImportViewModelFailsWhenCoreRejectsUnsupportedEmptyFile() async throws {
        let url = temporaryFileURL(name: "empty.bin")
        try Data().write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let viewModel = FileImportViewModel()
        await viewModel.handleSelectedFile(url)

        guard case .failed(let message) = viewModel.importState else {
            XCTFail("Expected failed import, got \(viewModel.importState)")
            return
        }

        XCTAssertTrue(message.contains("empty_file"))
    }

    func testFileImportViewModelCanUseInjectedImporterForPermissionIndependentTests() async throws {
        let url = temporaryFileURL(name: "fake.pdf")
        try Data("%PDF-1.4\n".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let expected = CoreLocalBookImportSummary(
            book: .init(
                id: "localbook:fake",
                title: "Injected",
                filePath: url.path,
                fileFormat: .pdf,
                fileSize: 9
            ),
            chapterCount: 1,
            resourceCount: 0,
            diagnostics: [],
            detectedFormat: .pdf,
            detectedEncoding: nil,
            inputByteCount: 9,
            sourceChecksum: "fake"
        )
        let viewModel = FileImportViewModel(importer: FakeCoreLocalBookImporter(summary: expected))
        await viewModel.handleSelectedFile(url)

        XCTAssertEqual(viewModel.importState, .imported(summary: expected))
    }

    func testBookshelfViewModelPersistsImportedLocalBook() async throws {
        let storeURL = temporaryFileURL(name: "bookshelf.json")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let store = BookshelfStore(storageURL: storeURL)
        let viewModel = BookshelfViewModel(store: store)
        let book = LocalBook(
            id: "localbook:test",
            title: "Local Imported",
            author: "Author",
            filePath: "/tmp/local-imported.txt",
            fileFormat: .txt,
            fileSize: 128,
            encoding: "utf-8"
        )

        await viewModel.addOrUpdateLocalBook(book)

        guard case .loaded(let items) = viewModel.bookshelfState else {
            XCTFail("Expected loaded bookshelf after local import, got \(viewModel.bookshelfState)")
            return
        }
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].sourceID, "local-book")
        XCTAssertEqual(items[0].sourceName, "Local Book")
        XCTAssertEqual(items[0].bookURL, book.filePath)
        XCTAssertEqual(items[0].title, book.title)
    }

    func testBookshelfViewModelPersistsImportedLocalBookFirstChapterEntry() async throws {
        let storeURL = temporaryFileURL(name: "bookshelf-summary.json")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let store = BookshelfStore(storageURL: storeURL)
        let viewModel = BookshelfViewModel(store: store)
        let book = LocalBook(
            id: "localbook:test-entry",
            title: "Local With Entry",
            filePath: "/tmp/local-entry.txt",
            fileFormat: .txt,
            fileSize: 128,
            encoding: "utf-8"
        )
        let summary = CoreLocalBookImportSummary(
            book: book,
            chapterCount: 1,
            resourceCount: 0,
            diagnostics: [],
            chapters: [
                CoreLocalBookImportChapterSummary(
                    index: 0,
                    title: "Chapter 1",
                    chapterURL: "local-book://book/localbook:test-entry/chapter/0",
                    preview: "Chapter 1",
                    contentCached: true
                )
            ],
            detectedFormat: .txt,
            detectedEncoding: "utf-8",
            inputByteCount: 128,
            sourceChecksum: "checksum"
        )

        await viewModel.addOrUpdateLocalBook(summary)

        guard case .loaded(let items) = viewModel.bookshelfState else {
            XCTFail("Expected loaded bookshelf after local summary import, got \(viewModel.bookshelfState)")
            return
        }
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].lastReadChapterTitle, "Chapter 1")
        XCTAssertEqual(items[0].lastReadChapterURL, "local-book://book/localbook:test-entry/chapter/0")
        XCTAssertEqual(items[0].localChapterList?.count, 1)
        XCTAssertEqual(items[0].localChapterList?.first?.chapterTitle, "Chapter 1")
    }

    func testBookshelfViewModelPersistsImportedLocalBookChapterListForNavigation() async throws {
        let storeURL = temporaryFileURL(name: "bookshelf-summary-navigation.json")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let store = BookshelfStore(storageURL: storeURL)
        let viewModel = BookshelfViewModel(store: store)
        let book = LocalBook(
            id: "localbook:test-navigation",
            title: "Local Navigation",
            filePath: "/tmp/local-navigation.txt",
            fileFormat: .txt,
            fileSize: 256,
            encoding: "utf-8"
        )
        let summary = CoreLocalBookImportSummary(
            book: book,
            chapterCount: 2,
            resourceCount: 0,
            diagnostics: [],
            chapters: [
                CoreLocalBookImportChapterSummary(
                    index: 0,
                    title: "Chapter 1",
                    chapterURL: "local-book://book/localbook:test-navigation/chapter/0",
                    preview: "Chapter 1",
                    contentCached: true
                ),
                CoreLocalBookImportChapterSummary(
                    index: 1,
                    title: "Chapter 2",
                    chapterURL: "local-book://book/localbook:test-navigation/chapter/1",
                    preview: "Chapter 2",
                    contentCached: true
                )
            ],
            detectedFormat: .txt,
            detectedEncoding: "utf-8",
            inputByteCount: 256,
            sourceChecksum: "checksum"
        )

        await viewModel.addOrUpdateLocalBook(summary)

        guard case .loaded(let items) = viewModel.bookshelfState else {
            XCTFail("Expected loaded bookshelf after local summary import, got \(viewModel.bookshelfState)")
            return
        }
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].localChapterList?.map(\.chapterTitle), ["Chapter 1", "Chapter 2"])
        XCTAssertEqual(items[0].localChapterList?.map(\.chapterURL), summary.cachedTOCItems.map(\.chapterURL))

        let reloaded = try store.loadItems()
        XCTAssertEqual(reloaded.first?.localChapterList?.count, 2)
        XCTAssertEqual(reloaded.first?.localChapterList?.last?.chapterIndex, 1)
    }

    private func temporaryFileURL(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-ios-local-book-\(UUID().uuidString)-\(name)")
    }

    private func temporaryDirectoryURL(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-ios-\(UUID().uuidString)-\(name)", isDirectory: true)
    }

    private func waitForCachedChapter(
        _ viewModel: ReaderViewModel,
        chapterURL: String,
        contentFragment: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        for _ in 0..<20 {
            if case .cached(let page) = viewModel.readerState,
               page.chapterURL == chapterURL,
               page.content.contains(contentFragment) {
                return
            }
            await Task.yield()
        }
        XCTFail("Expected cached chapter \(chapterURL) containing \(contentFragment), got \(viewModel.readerState)", file: file, line: line)
    }
}

private struct FakeCoreLocalBookImporter: CoreLocalBookImporting {
    let summary: CoreLocalBookImportSummary

    func importBook(at url: URL) async throws -> CoreLocalBookImportSummary {
        summary
    }
}
