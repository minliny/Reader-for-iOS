import Foundation
import ReaderCoreBridge
import ReaderDesign
import ReaderHost
import SwiftUI
import UIKit
import XCTest
@testable import ReaderApp

private struct ProductJourneyReceipt: Codable {
    struct Entry: Codable {
        let bookId: String
        let title: String
        let original: String
        let format: String
        let chapter: Int64
        let scalar: Int
        let selectedText: String
    }
    let rootName: String
    let pid: Int32
    let entries: [Entry]
}

@MainActor
final class Wave2ProductJourneyTests: XCTestCase {
    private var receiptURL: URL {
        get throws {
            let url = URL.applicationSupportDirectory.appending(path: "XPLAT-M1-WAVE2-XCTest", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            return url.appending(path: "product-cold.json")
        }
    }

    func test01ProductImportDetailReadBookmarkAndSave() async throws {
        let root = try receiptURL.deletingLastPathComponent().appending(path: UUID().uuidString, directoryHint: .isDirectory)
        let urls = try [fixture("local-reading", "txt"), fixture("m1-window", "epub"), fixture("sample-ncx", "mobi")]
        let model = ShelfModel()
        await model.start(root: root, sandboxRoots: [urls[0].deletingLastPathComponent()])
        let window = try mount(ReaderRootView(root: root, model: model))
        defer { window.isHidden = true }
        try await eventually("empty production shelf") { model.books?.isEmpty == true }
        let library = try XCTUnwrap(model.library)
        assertLibrary47(library, fresh: true)
        let files = try XCTUnwrap(model.files)
        let runtime = library.runtime
        let picker = DocumentPicker(onSelect: model.importFiles, onCancel: {})
        // Drive the production UIKit delegate with Grant-equivalent test-owned fixtures.
        let nativePicker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        let delegate = DocumentPicker.Coordinator(picker)
        delegate.documentPicker(nativePicker, didPickDocumentsAt: urls)
        try await eventually("three actual originals imported", seconds: 12) {
            model.task?.completed == urls.count || (model.task?.failed ?? 0) > 0
        }
        XCTAssertEqual(model.task?.failed, 0)
        XCTAssertEqual(model.task?.completed, 3)
        try await eventually("production shelf confirms three Core receipts") { model.books?.count == 3 }
        XCTAssertNil(model.recovery)
        var entries = [ProductJourneyReceipt.Entry]()
        for input in urls {
            let sha = try hash(input)
            let format = input.pathExtension
            let book = try XCTUnwrap(model.books?.first { $0.bookId == "local:\(sha)" })
            let details = BookDetailModel()
            let identity = BookIdentity(book)
            await details.load(identity, runtime: runtime)
            let current = try XCTUnwrap(details.book)
            let original = try XCTUnwrap(details.original)
            XCTAssertEqual(original.sha256, sha)
            XCTAssertFalse(details.chapters.isEmpty)
            let presentation = try await runtime.request(ReaderM1.localBookPresentationKindV1,
                .init(bookId: book.bookId)).value
            let chapter = format == "epub" ? Int64(1) : details.chapters[0].index
            let body = try await runtime.request(ReaderM1.localBookChapterContent,
                .init(bookId: book.bookId, chapterIndex: chapter)).value
            print("M1_PRODUCT_SOURCE input=\(format) coreFormat=\(presentation.format) rendererAdmitted=\(!presentation.reimportRequired) chapter=\(chapter) scalars=\(body.content.unicodeScalars.count)")
            if format == "epub" { XCTAssertTrue(details.chapters.contains(where: { $0.index == chapter })) }
            show(BookDetailContent(book: current, chapters: details.chapters, onRead: {}, onDirectory: {}, onRemove: {}),
                 in: window)
            try await Task.sleep(for: .milliseconds(80))
            show(DirectoryContent(chapters: details.chapters, selected: chapter, onSelect: { _ in }), in: window)
            try await Task.sleep(for: .milliseconds(80))
            let session = ReadingSessionCoordinator(runtime: runtime)
            let renderer = ReadingRenderState()
            var exited = false
            show(NavigationStack {
                ReadingScreen(book: current, chapters: details.chapters, original: original, runtime: runtime, files: files,
                              startChapter: chapter, session: session, renderer: renderer) { exited = true }
            }, in: window)
            try await eventually("mounted production \(format) reading surface", seconds: 12) {
                await renderer.position() != nil
            }
            if format == "epub" { XCTAssertNotNil(renderer.ebook) }
            let nativeName = renderer.ebook != nil ? "WKWebView" : "CoreText"
            let visibleChapter = try XCTUnwrap(session.chapter)
            XCTAssertEqual(visibleChapter.index, chapter)
            let target = format == "epub" ? 27 : min(5, body.content.unicodeScalars.count - 1)
            let measured: EbookScriptEvent.Value?
            if let ebook = renderer.ebook { measured = try await ebook.restore(target) }
            else { measured = try await renderer.text?.restore(target) }
            let scalar = try XCTUnwrap(measured?.scalar)
            let visibleText = try XCTUnwrap(measured?.text)
            XCTAssertEqual(scalar, target)
            XCTAssertGreaterThan(scalar, 0)
            try await eventually("production surface publishes exact position") { session.position == scalar }
            await session.addBookmark()
            let bookmark = try XCTUnwrap(session.bookmarks.first)
            XCTAssertEqual(bookmark.chapterIndex, chapter)
            XCTAssertEqual(bookmark.chapterPos, Int64(scalar))
            if let ebook = renderer.ebook { _ = try await ebook.restore(0) }
            else { _ = try await renderer.text?.restore(0) }
            await session.chooseChapter(bookmark.chapterIndex, bookmark: bookmark)
            try await eventually("rendered bookmark jump \(format)", seconds: 12) {
                guard session.chapter?.anchor == scalar else { return false }
                return await renderer.position() == scalar
            }
            await session.deleteBookmark(bookmark)
            XCTAssertTrue(session.bookmarks.isEmpty)
            await session.addBookmark()
            XCTAssertEqual(session.bookmarks.first?.chapterPos, Int64(scalar))
            show(BookshelfContent(books: model.books, state: model.state, recovery: model.recovery, onOpen: { _ in },
                                  onRemove: { _ in }, onRetry: {}), in: window)
            try await eventually("leave drains original \(format) operation") { exited }
            let stored = try await runtime.request(ReaderM1.readingProgressGet,
                .init(bookId: book.bookId, sourceId: "local")).value
            XCTAssertEqual(stored.progress?.chapterIndex, chapter)
            XCTAssertEqual(stored.progress?.chapterOffset, Int64(scalar))
            entries.append(.init(bookId: book.bookId, title: book.title, original: sha, format: format,
                                 chapter: chapter, scalar: scalar, selectedText: visibleText))
            print("M1_PRODUCT_WRITE format=\(format) book=\(book.bookId) chapters=\(details.chapters.count) native=\(nativeName) chapter=\(chapter) scalar=\(scalar) bookmarks=add/jump/delete/add")
        }
        await runtime.close()
        let pid = ProcessInfo.processInfo.processIdentifier
        try JSONEncoder().encode(ProductJourneyReceipt(rootName: root.lastPathComponent, pid: pid, entries: entries)).write(to: receiptURL)
        print("M1_PRODUCT_WRITE pid=\(pid) count=\(entries.count) layout=reader-sqlite-47-remote")
    }

    func test02ProductIndependentColdRestoresThreeNativeAnchors() async throws {
        let receipt = try JSONDecoder().decode(ProductJourneyReceipt.self, from: Data(contentsOf: receiptURL))
        let pid = ProcessInfo.processInfo.processIdentifier
        XCTAssertNotEqual(receipt.pid, pid)
        XCTAssertEqual(receipt.entries.count, 3)
        let root = try receiptURL.deletingLastPathComponent().appending(path: receipt.rootName, directoryHint: .isDirectory)
        let model = ShelfModel()
        await model.start(root: root)
        let window = try mount(ReaderRootView(root: root, model: model))
        defer { window.isHidden = true }
        try await eventually("cold production book shelf") { model.books?.count == 3 }
        let library = try XCTUnwrap(model.library)
        assertLibrary47(library, fresh: false)
        let runtime = library.runtime
        let files = try XCTUnwrap(model.files)
        for entry in receipt.entries {
            let book = try XCTUnwrap(model.books?.first { $0.bookId == entry.bookId })
            let details = BookDetailModel()
            let identity = BookIdentity(book)
            await details.load(identity, runtime: runtime)
            XCTAssertEqual(details.original?.sha256, entry.original)
            let session = ReadingSessionCoordinator(runtime: runtime)
            let renderer = ReadingRenderState()
            var exited = false
            show(NavigationStack {
                ReadingScreen(book: book, chapters: details.chapters, original: details.original, runtime: runtime,
                              files: files, startChapter: nil, session: session, renderer: renderer) { exited = true }
            }, in: window)
            try await eventually("cold native \(entry.format) anchor", seconds: 12) {
                guard session.chapter?.index == entry.chapter,
                      session.chapter?.anchor == entry.scalar else { return false }
                return await renderer.position() == entry.scalar
            }
            await session.reloadBookmarks()
            XCTAssertEqual(session.bookmarks.first?.chapterPos, Int64(entry.scalar))
            let native: EbookScriptEvent.Value?
            if let ebook = renderer.ebook { native = try await ebook.position() }
            else { native = try await renderer.text?.position() }
            XCTAssertEqual(native?.text, entry.selectedText)
            print("M1_PRODUCT_COLD writer=\(receipt.pid) reader=\(pid) format=\(entry.format) chapter=\(entry.chapter) core=\(entry.scalar) visible=\(native?.scalar ?? -1) text=\(native?.text ?? "-")")
            show(Text(""), in: window)
            try await eventually("cold reading surface closes") { exited }
        }
        await runtime.close()
    }

    private func mount<V: View>(_ view: V) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        show(view, in: window)
        window.makeKeyAndVisible()
        return window
    }

    private func show<V: View>(_ view: V, in window: UIWindow) {
        if let host = window.rootViewController as? UIHostingController<AnyView> {
            host.rootView = AnyView(view)
        } else {
            window.rootViewController = UIHostingController(rootView: AnyView(view))
        }
        window.rootViewController?.view.layoutIfNeeded()
    }

    private func eventually(_ label: String, seconds: Int = 6, _ ready: () async -> Bool) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now + .seconds(seconds)
        while clock.now < deadline {
            if await ready() { return }
            try await Task.sleep(for: .milliseconds(45))
        }
        XCTFail("Timed out: \(label)")
        throw NSError(domain: "Wave2ProductJourney", code: 1)
    }
}
