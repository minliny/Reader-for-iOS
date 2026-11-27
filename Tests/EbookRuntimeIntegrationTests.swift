import Foundation
import ReaderCoreBridge
import ReaderHost
import UIKit
import WebKit
import XCTest
@testable import ReaderApp

private struct EbookColdReceipt: Codable {
    let rootName: String
    let source: String
    let writerPID: Int32
    let book: String
    let chapter: Int64
    let scalar: Int
}

@MainActor
final class EbookRuntimeIntegrationTests: XCTestCase {
    func test04WebKitImportSelectReflowSaveAndRejectOldDocument() async throws {
        let root = try isolatedRoot()
        let directory = root.appendingPathComponent("library", isDirectory: true)
        let library = try await LibraryHost.open(directory: directory)
        let core = library.runtime
        let imported = try await importFixture(fixture("m1-window", "epub"), runtime: core, root: root)
        let book = imported.bookId
        let source = imported.source
        XCTAssertEqual(source.sha256, "35efc3246026578c8f56ea227964bb05a5d7cd8d49ee0f7794221f9ab3a4481e")
        let first = try await ebook(runtime: core, book: book, index: 0, source: source)
        let second = try await ebook(runtime: core, book: book, index: 1, source: source)
        XCTAssertEqual(first.descriptor.entryPath, second.descriptor.entryPath)
        XCTAssertEqual(second.descriptor.entryPath, "EPUB/text/trail.xhtml")
        XCTAssertEqual(second.descriptor.chapterStartScalar, 65)
        XCTAssertEqual(second.descriptor.chapterEndScalar, 962)

        let surface = try EbookReadingSurface()
        let window = try mount(surface)
        defer { window.isHidden = true }
        let session = UUID().uuidString
        var events: [EbookScriptEvent] = []
        surface.onEvent = { events.append($0) }
        defer {
            let observed = events.map {
                "\($0.kind):\($0.layoutGeneration):\($0.value?.scalar ?? -1):\($0.value?.code ?? "-")"
            }
            print("M1_WEBKIT_EVENTS \(observed)")
        }
        print("M1_WEBKIT_STAGE first")
        _ = try await surface.open(first, session: session, anchor: 0)
        print("M1_WEBKIT_STAGE second")
        let prior = try XCTUnwrap(events.last(where: { $0.kind == "ready" }))
        let ready = try await surface.open(second, session: session, anchor: 27, style: EbookStyle(fontSize: 18))
        XCTAssertEqual(ready.scalar, 27)
        XCTAssertEqual(ready.text, "𠀀")
        let images = try XCTUnwrap(ready.loadedImageCount)
        XCTAssertGreaterThanOrEqual(images, 1)
        let nativeImage = try await surface.webView.callAsyncJavaScript(
            """
            const frame = document.querySelector('iframe');
            const image = frame.contentDocument.images[0];
            return frame.getAttribute('sandbox') === 'allow-same-origin' &&
              image?.complete === true && image.naturalWidth > 0;
            """,
            arguments: [:], contentWorld: .world(name: "ReaderEbookRuntime")
        )
        XCTAssertEqual(nativeImage as? Bool, true)
        print("M1_WEBKIT_STAGE selection")
        let selected = try await surface.select(start: 27, end: 34)
        XCTAssertEqual(selected?.startScalar, 27)
        XCTAssertEqual(selected?.endScalar, 34)
        let roundTrip = try await surface.selection()
        XCTAssertEqual(roundTrip?.startScalar, 27)
        XCTAssertEqual(roundTrip?.endScalar, 34)
        let original = try await surface.webView.callAsyncJavaScript(
            "return document.querySelector('iframe').contentWindow.getSelection().toString();",
            arguments: [:], contentWorld: .world(name: "ReaderEbookRuntime")
        )
        let originalText = try XCTUnwrap(original as? String)
        XCTAssertEqual(originalText.unicodeScalars.map(\.value), "𠀀与Café".unicodeScalars.map(\.value))

        print("M1_WEBKIT_STAGE reflow")
        let reflowed = try await surface.reflow(style: EbookStyle(fontSize: 23))
        XCTAssertEqual(reflowed.scalar, 27)
        XCTAssertEqual(reflowed.text, "𠀀")
        let current = try XCTUnwrap(events.last(where: { $0.kind == "ready" }))
        XCTAssertEqual(current.layoutGeneration, 1)
        print("M1_WEBKIT_STAGE stale proof")
        try await deliverStaleEvent(prior, surface: surface)
        try await deliverStaleEvent(current, surface: surface, generation: 0)
        XCTAssertFalse(events.contains { $0.kind == "ready" && $0.value?.scalar == 999_999 })
        let measured = try await surface.position()
        XCTAssertEqual(measured?.scalar, 27)

        print("M1_WEBKIT_STAGE save")
        let coordinator = ReadingSessionCoordinator(runtime: core)
        let before = try await core.request(ReaderM1.readingProgressGet, .init(bookId: book, sourceId: "local")).value
        let pending = coordinator.save(.init(
            expectedProgressRevision: before.progressRevision, bookId: book, sourceId: second.chapter.sourceId,
            chapterIndex: 1, chapterOffset: 27, chapterProgress: 0.25,
            expectedBodyVersion: second.chapter.bodyVersion, expectedProcessingVersion: second.chapter.processingVersion
        )) { _ in }
        coordinator.retirePage()
        await surface.retire()
        let persisted = try await pending.value
        XCTAssertEqual(persisted.value.chapterOffset, 27)
        await core.close()

        print("M1_WEBKIT_STAGE invalid window")
        let invalid = EbookDocument(
            descriptor: LocalBookChapterPresentationData(
                sourceId: second.descriptor.sourceId, bookId: book, chapterIndex: 1,
                bodyVersion: second.descriptor.bodyVersion, processingVersion: second.descriptor.processingVersion,
                entryPath: second.descriptor.entryPath, documentCanonicalContent: second.descriptor.documentCanonicalContent,
                chapterStartScalar: second.descriptor.chapterStartScalar + 7, chapterEndScalar: second.descriptor.chapterEndScalar
            ), chapter: second.chapter, source: source, xhtml: second.xhtml
        )
        do {
            _ = try await surface.open(invalid, session: session, anchor: 27)
            XCTFail("WebKit accepted a mismatched Core window")
        } catch EbookSurfaceFailure.unavailable(let code) {
            XCTAssertEqual(code, "CORE_PROCESSED_MAPPING_UNPROVEN")
        }
        let unavailable = try await surface.position()
        XCTAssertNil(unavailable)
        await surface.retire()

        let receipt = EbookColdReceipt(
            rootName: root.lastPathComponent, source: source.sha256,
            writerPID: ProcessInfo.processInfo.processIdentifier, book: book, chapter: 1, scalar: 27
        )
        try JSONEncoder().encode(receipt).write(to: testSupportDirectory.appendingPathComponent("epub-cold.json"), options: .atomic)
        print("M1_WEBKIT_WRITE pid=\(receipt.writerPID) sha=\(source.sha256) window=[65,962) images=\(images) selection=[27,34) reflow=18->23 anchor=27 stale=false mismatch=guarded")
    }

    func test05ColdProcessRestoresVisibleEpubAnchor() async throws {
        let data = try Data(contentsOf: testSupportDirectory.appendingPathComponent("epub-cold.json"))
        let receipt = try JSONDecoder().decode(EbookColdReceipt.self, from: data)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        XCTAssertNotEqual(currentPID, receipt.writerPID)
        let root = try testSupportDirectory.appendingPathComponent(receipt.rootName)
        let library = try await LibraryHost.open(directory: root.appendingPathComponent("library"))
        assertLibrary47(library, fresh: false)
        let core = library.runtime
        let progress = try await core.request(ReaderM1.readingProgressGet, .init(bookId: receipt.book, sourceId: "local")).value
        XCTAssertEqual(progress.progress?.chapterIndex, receipt.chapter)
        XCTAssertEqual(progress.progress?.chapterOffset, Int64(receipt.scalar))
        let host = FileAndAssetHost(root: root.appendingPathComponent("assets"), sandboxRoots: [])
        let retained = try await host.retained(sha256: receipt.source)
        let document = try await ebook(runtime: core, book: receipt.book, index: receipt.chapter, source: retained)
        let surface = try EbookReadingSurface()
        let window = try mount(surface)
        defer { window.isHidden = true }
        let ready = try await surface.open(document, session: UUID().uuidString, anchor: receipt.scalar)
        let visible = try await surface.position()
        XCTAssertEqual(ready.scalar, receipt.scalar)
        XCTAssertEqual(visible?.scalar, receipt.scalar)
        XCTAssertEqual(visible?.text, "𠀀")
        await surface.retire()
        await core.close()
        print("M1_WEBKIT_COLD writerPID=\(receipt.writerPID) readerPID=\(currentPID) chapter=\(receipt.chapter) core=\(receipt.scalar) web=\(visible?.scalar ?? -1) text=\(visible?.text ?? "-")")
    }

    private func ebook(runtime: CoreRuntimeActor, book: String, index: Int64, source: RetainedSource) async throws -> EbookDocument {
        let chapter = try await runtime.request(ReaderM1.localBookChapterContent, .init(bookId: book, chapterIndex: index)).value
        let descriptor = try await runtime.request(ReaderM1.localBookChapterPresentationV1, .init(
            bookId: book, chapterIndex: index, localSourcePath: source.path.path
        )).value
        return try await EbookDocument.open(descriptor: descriptor, chapter: chapter, source: source)
    }

    private func mount(_ surface: EbookReadingSurface) throws -> UIWindow {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        window.rootViewController = controller
        let view = surface.webView
        view.frame = controller.view.bounds
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        controller.view.addSubview(view)
        window.makeKeyAndVisible()
        controller.view.layoutIfNeeded()
        return window
    }

    private func deliverStaleEvent(
        _ event: EbookScriptEvent, surface: EbookReadingSurface, generation: Int? = nil
    ) async throws {
        _ = try await surface.webView.callAsyncJavaScript(
            """
            window.webkit.messageHandlers.readerEbook.postMessage(JSON.stringify({
                version: 1, session, documentId, layoutGeneration, kind: 'ready',
                value: {scalar: 999999, text: 'STALE'}
            }));
            return true;
            """,
            arguments: [
                "session": event.session, "documentId": event.documentId,
                "layoutGeneration": generation ?? event.layoutGeneration
            ], contentWorld: .world(name: "ReaderEbookRuntime")
        )
    }
}
