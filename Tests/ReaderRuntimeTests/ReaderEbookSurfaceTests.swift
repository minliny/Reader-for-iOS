import XCTest
import CryptoKit
import UIKit
import WebKit
@testable import Reader

final class ReaderEbookSurfaceTests: XCTestCase {
    @MainActor
    func testRegisteredFontAssetDeliversTheActualBundledFace() throws {
        ReaderFonts.registerBundledFonts()
        let prepared = try ReaderEbookFontAsset.prepare(postScriptName: ReaderFonts.postScriptName(.serif))
        let original = Bundle.main.url(forResource: "NotoSerifSC-Regular", withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: "NotoSerifSC-Regular", withExtension: "ttf")
        XCTAssertEqual(prepared.0, try Data(contentsOf: XCTUnwrap(original)))
        XCTAssertEqual(prepared.1, "font/ttf")
        XCTAssertThrowsError(try ReaderEbookFontAsset.prepare(postScriptName: "Reader-Unregistered-Face-Does-Not-Exist"))
    }

    /// A browser interoperability fixture, not a generated novel or evidence
    /// of real EPUB/MOBI acceptance. System WebKit executes the production bridge.
    @MainActor
    func testNativeDOMRetainsSemanticsAndVersionedScalarSelectionAfterCoreEdits() async throws {
        let loaded = expectation(description: "native layout")
        let selected = expectation(description: "scalar selection")
        let handler = ReaderEbookScriptTestHandler { body in
            if body["kind"] as? String == "failure" { XCTFail("Native DOM rejected: \(body)"); loaded.fulfill() }
            if body["kind"] as? String == "ready" { loaded.fulfill() }
            if body["kind"] as? String == "selection", let value = body["value"] as? [String: Any] {
                XCTAssertEqual((value["start"] as? NSNumber)?.uint64Value, 1)
                XCTAssertEqual((value["end"] as? NSNumber)?.uint64Value, 2)
                selected.fulfill()
            }
        }
        let options: [String: Any] = ["session":"native-fixture","canonical":"Title\n\nA😀B\n\nTail",
            "start":7,"end":10,"content":"A🦊B","edits":[["startScalar":1,"endScalar":2,"text":"🦊"]],
            "offset":1,"fontSize":26,"lineHeight":1.8,"horizontalInset":20,"leftInset":20,"rightInset":20,
            "topInset":8,"bottomInset":24,"dark":false,"ink":"#112233","meta":"#778899","selection":"#FFCCAA",
            "fontURL":"","paragraphSpacing":19,"letterSpacing":0.5,"firstLineIndentEm":2,"alignment":"justify",
            "paged":true,"highlights":[["start":1,"end":2]],"reduceMotion":true]
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.userContentController.add(handler, contentWorld: .defaultClient, name: "readerEbook")
        configuration.userContentController.addUserScript(WKUserScript(source: try ReaderEbookScript.bootstrap(configuration: options),
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), configuration: configuration)
        let window = UIWindow(frame: web.bounds)
        let controller = UIViewController(); controller.view = web
        window.rootViewController = controller; window.isHidden = false
        defer { window.isHidden = true; web.stopLoading(); configuration.userContentController.removeScriptMessageHandler(forName: "readerEbook", contentWorld: .defaultClient) }
        web.loadHTMLString("<!doctype html><html><head></head><body><h1>Title</h1><p id='one'>A<em>😀</em>B</p><p>Tail</p></body></html>", baseURL: nil)
        await fulfillment(of: [loaded], timeout: 10)
        let value = try await web.callAsyncJavaScript("""
            const paragraph=document.getElementById('one');
            return {text:document.body.textContent,em:paragraph.querySelector('em').textContent,
                    title:!!document.querySelector('h1'),spacing:getComputedStyle(paragraph).marginBottom,
                    page:window.__readerEbook.pageTarget(1)};
            """, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String: Any]
        XCTAssertEqual(value?["text"] as? String, "A🦊B")
        XCTAssertEqual(value?["em"] as? String, "🦊")
        XCTAssertEqual(value?["title"] as? Bool, false)
        XCTAssertEqual(value?["spacing"] as? String, "19px")
        XCTAssertEqual((value?["page"] as? [String: Any])?["end"] as? Bool, true)
        _ = try await web.callAsyncJavaScript("""
            const text=document.querySelector('em').firstChild,range=document.createRange();
            range.setStart(text,0);range.setEnd(text,2);getSelection().removeAllRanges();getSelection().addRange(range);
            """, arguments: [:], in: nil, contentWorld: .defaultClient)
        await fulfillment(of: [selected], timeout: 5)
    }

    /// System browser geometry and task cancellation are exercised with a
    /// minimal interoperability document, separate from real-format evidence.
    @MainActor
    func testNativePageEpochRejectsCancelledCommitAndConsumesSelectionAndFontAxes() async throws {
        let loaded = expectation(description: "native page layout")
        var didLoad = false
        var positions = 0
        let handler = ReaderEbookScriptTestHandler { body in
            if body["kind"] as? String == "position" { positions += 1 }
            if body["kind"] as? String == "failure" { XCTFail("Native DOM rejected: \(body)") }
            if body["kind"] as? String == "ready", !didLoad { didLoad = true; loaded.fulfill() }
        }
        let options: [String: Any] = ["session":"native-page-epoch","canonical":"A😀B","start":0,"end":3,
            "content":"A😀B","edits":[],"offset":0,"fontSize":26,"lineHeight":1.8,
            "horizontalInset":20,"leftInset":20,"rightInset":20,"topInset":8,"bottomInset":24,
            "dark":false,"ink":"#112233","meta":"#778899","selection":"#FFCCAA","fontURL":"",
            "paragraphSpacing":19,"letterSpacing":0,"firstLineIndentEm":0,"alignment":"left",
            "paged":true,"highlights":[],"reduceMotion":true,"longPressSelectText":true,
            "fontVariations":["wght":400],"systemFont":true]
        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = false
        configuration.userContentController.add(handler, contentWorld: .defaultClient, name: "readerEbook")
        configuration.userContentController.addUserScript(WKUserScript(source: try ReaderEbookScript.bootstrap(configuration: options),
            injectionTime: .atDocumentEnd, forMainFrameOnly: true, in: .defaultClient))
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 600), configuration: configuration)
        let window = UIWindow(frame: web.bounds)
        let controller = UIViewController(); controller.view = web
        window.rootViewController = controller; window.isHidden = false
        defer { window.isHidden = true; web.stopLoading(); configuration.userContentController.removeScriptMessageHandler(forName: "readerEbook", contentWorld: .defaultClient) }
        web.loadHTMLString("<!doctype html><html><head></head><body><p style='min-height:1800px'>A😀B</p></body></html>", baseURL: nil)
        await fulfillment(of: [loaded], timeout: 10)
        let value = try await web.callAsyncJavaScript("""
            const api=window.__readerEbook,forward=api.pageTarget(1);
            api.cancelPage();const stale=await api.commitPage(forward.epoch);
            const backward=api.pageTarget(-1);api.cancelPage();
            const selection=getSelection(),range=document.createRange();
            range.setStart(document.querySelector('p').firstChild,0);range.setEnd(document.querySelector('p').firstChild,1);
            selection.removeAllRanges();selection.addRange(range);
            api.configure({...options,longPressSelectText:false});
            return {forward,backward,stale,text:document.body.textContent,
              select:getComputedStyle(document.body).webkitUserSelect,
              axes:getComputedStyle(document.body).fontVariationSettings,
              selected:getSelection().toString()};
            """, arguments: ["options": options], in: nil, contentWorld: .defaultClient) as? [String: Any]
        XCTAssertEqual((value?["forward"] as? [String: Any])?["end"] as? Bool, false)
        XCTAssertEqual((value?["backward"] as? [String: Any])?["end"] as? Bool, true)
        XCTAssertTrue(value?["stale"] is NSNull)
        XCTAssertEqual(value?["text"] as? String, "A😀B")
        XCTAssertEqual(value?["select"] as? String, "none")
        XCTAssertEqual(value?["selected"] as? String, "")
        XCTAssertTrue((value?["axes"] as? String)?.contains("400") == true)
        XCTAssertEqual(positions, 0, "Query/cancellation must not persist a speculative page")
    }
    func testCanonicalScalarMapKeepsImagesEmojiAndCollapsedWhitespace() throws {
        let canonical = "甲😀\n\n\u{fffc}\n乙"
        let map = try ReaderEbookScalarMap(canonical: canonical, rendered: "甲😀  \u{fffc}乙")
        XCTAssertEqual(map.renderedOffset(forCanonical: 1), 1)
        XCTAssertEqual(map.canonicalOffset(forRenderedUTF16: 1), 1)
        // A surrogate pair never becomes two Core positions.
        XCTAssertEqual(map.canonicalOffset(forRenderedUTF16: 2), 4)
        let image = map.renderedOffset(forCanonical: 4)
        XCTAssertEqual(map.canonicalOffset(forRenderedUTF16: image), 4)
        // Preserve a hidden canonical newline until actual user movement.
        let hidden = map.renderedOffset(forCanonical: 3)
        XCTAssertEqual(map.canonicalOffset(forRenderedUTF16: hidden, retainingScalar: 3), 3)
        XCTAssertThrowsError(try ReaderEbookScalarMap(canonical: canonical, rendered: "甲😀乙"))
        XCTAssertThrowsError(try ReaderEbookScalarMap(canonical: "甲乙", rendered: "乙甲"))
    }

    func testCoreConfirmedRuleEditsUseScalarCoordinatesAndRetainOriginal() throws {
        let original = "甲😀乙\n丙丁"
        let processed = "甲🦊乙\n丙"
        let edits = try ReaderEbookTextEdits.changes(original: original, processed: processed)
        var scalars = Array(original.unicodeScalars)
        for edit in edits.reversed() {
            scalars.replaceSubrange(Int(edit.startScalar)..<Int(edit.endScalar), with: edit.text.unicodeScalars)
        }
        XCTAssertEqual(scalars.map(String.init).joined(), processed)
        XCTAssertEqual(original, "甲😀乙\n丙丁")
        XCTAssertEqual(try ReaderEbookTextEdits.changes(original: original, processed: original), [])
        XCTAssertThrowsError(try ReaderEbookTextEdits.changes(original: "甲", processed: "甲\u{fffc}"))
    }

    func testArchiveURLBoundaryIsOriginBoundAndNeverTraverses() throws {
        let origin = "session-a"
        let entry = "OPS/插图 1#%.png"
        let url = try ReaderEbookResourcePath.url(entry: entry, origin: origin)
        XCTAssertEqual(try ReaderEbookResourcePath.entry(url: url, origin: origin), entry)
        XCTAssertThrowsError(try ReaderEbookResourcePath.entry(url: url, origin: "session-b"))
        for invalid in ["", "../file", "OPS/../file", "/absolute", "OPS//file", "OPS\\file", "https:file", "OPS/\0file"] {
            XCTAssertFalse(ReaderEbookResourcePath.isCanonical(invalid), invalid)
        }
        XCTAssertThrowsError(try ReaderEbookResourcePath.entry(url: URL(string: "https://session-a/OPS/file")!, origin: origin))
    }

    func testDescriptorRejectsStaleIdentityAndOutOfRangeWindow() throws {
        let content = ReaderChapterContent(bookId: "local:test", chapterIndex: 0,
            chapterTitle: "", content: "甲😀乙", bodyVersion: "body-a", processingVersion: "process-a")
        let descriptor = ReaderEbookDocument(sourceId: "local", bookId: "local:test", chapterIndex: 0,
            bodyVersion: "body-a", processingVersion: "process-a", entryPath: "OPS/body.xhtml",
            documentCanonicalContent: "甲😀乙", chapterStartScalar: 0, chapterEndScalar: 3)
        XCTAssertNoThrow(try descriptor.validate(content: content))
        let stale = ReaderChapterContent(bookId: "local:test", chapterIndex: 0, chapterTitle: "",
            content: content.content, bodyVersion: "body-b", processingVersion: "process-a")
        XCTAssertThrowsError(try descriptor.validate(content: stale))
        let wrongRange = ReaderEbookDocument(sourceId: "local", bookId: "local:test", chapterIndex: 0,
            bodyVersion: "body-a", processingVersion: "process-a", entryPath: "OPS/body.xhtml",
            documentCanonicalContent: "甲😀乙", chapterStartScalar: 0, chapterEndScalar: 4)
        XCTAssertThrowsError(try wrongRange.validate(content: content))
    }

    /// A real original is required. The entry comes from Core after actual
    /// import, never an environment-supplied guessed archive path.
    func testProvisionedRealEpubReadsOriginalEntryWithoutChangingSource() async throws {
        let url = try ReaderLocalFormatsTests.originalURL(format: "epub", byteCount: 7_406_795,
            digest: "5d6d9dd26bbea9ed0db4e4f7a127a538dfe439f5694c3370a30ac33503db9d67")
        let original = try Data(contentsOf: url)
        let digest = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderOriginalEntry-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        do {
            let book = try await library.importBook(at: url).book
            let chapters = try await library.chapters(for: book)
            let chapter = try XCTUnwrap(chapters.first { !$0.url.isEmpty })
            let document = try await library.ebookPresentation(for: book, chapterIndex: chapter.index)
            let reader = ReaderEbookArchiveReader(sourceURL: url, bookID: "local:" + digest)
            let xhtml = try await reader.readEntry(document.entryPath, maximumBytes: 32 * 1024 * 1024)
            XCTAssertFalse(xhtml.isEmpty)
            XCTAssertEqual(try Data(contentsOf: url), original)
            do {
                _ = try await reader.readEntry("../outside", maximumBytes: 1024)
                XCTFail("Traversal must fail before archive access")
            } catch { XCTAssertEqual(error as? ReaderEbookError, .invalidEntry) }
            try await library.close()
        } catch {
            try? await library.close()
            throw error
        }
    }

    @MainActor
    func testSnapshotTransitionsCancelExactlyOnceAndReleaseTheirViews() async throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 48)).image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let oldKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        let controller = UIViewController()
        window.rootViewController = controller; window.makeKeyAndVisible()
        controller.view.frame = window.bounds; controller.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; oldKey?.makeKey() }
        for style in [ReaderPageTransition.cover, .slide] {
            var outcomes: [Bool] = []
            let turn = try XCTUnwrap(ReaderEbookPageTurn(in: controller.view, before: image, after: image,
                direction: 1, transition: style, paper: .white) { outcomes.append($0) })
            turn.cancel(); turn.cancel()
            // Cancel before the queued native start. Draining that exact queue
            // turn proves the stale start cannot report an advance, without
            // assuming a native animation is still running after an arbitrary
            // delay (UIKit may complete it immediately when offscreen).
            let drained = expectation(description: "cancelled native \(style) start drained")
            DispatchQueue.main.async { drained.fulfill() }
            await fulfillment(of: [drained], timeout: 2)
            XCTAssertEqual(outcomes, [false], "A cancelled queued native \(style) must emit one cancellation")
            XCTAssertTrue(controller.children.isEmpty, "Per-turn animation cannot retain a child controller")
            XCTAssertTrue(controller.view.subviews.isEmpty, "Viewport snapshots must be released")
        }
        for style in [ReaderPageTransition.cover, .slide] {
            var outcomes: [Bool] = []
            let completed = expectation(description: "actual native \(style) completed")
            let turn = try XCTUnwrap(ReaderEbookPageTurn(in: controller.view, before: image, after: image,
                direction: -1, transition: style, paper: .white) { outcome in outcomes.append(outcome); completed.fulfill() })
            await fulfillment(of: [completed], timeout: 5)
            turn.cancel(); turn.cancel()
            XCTAssertEqual(outcomes, [true], "Late cancellation cannot revoke an already committed page")
            XCTAssertTrue(controller.children.isEmpty)
            XCTAssertTrue(controller.view.subviews.isEmpty)
        }
    }

    /// Native compositing fixtures with distinct pixels. This proves UIKit's
    /// intermediate geometry/cancellation, not a real book's visual acceptance.
    @MainActor
    func testInteractiveCoverAndSlideHaveDistinctNativeFramesAndCancelInProgress() async throws {
        let before = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 48)).image { context in
            UIColor.red.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
        }
        let after = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 48)).image { context in
            UIColor.blue.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let key = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        let host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds; host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; key?.makeKey() }
        for mode in [ReaderPageTransition.cover, .slide] {
            for direction in [1, -1] {
                var outcomes: [Bool] = []
                let turn = try XCTUnwrap(ReaderEbookPageTurn(in: host.view, before: before, after: after,
                    direction: direction, transition: mode, paper: .white, interactive: true) { outcomes.append($0) })
                turn.updateProgress(0.4)
                await nativeFrames()
                XCTAssertTrue(outcomes.isEmpty, "Scrubbing cannot acknowledge a page before release")
                let overlay = try XCTUnwrap(host.view.subviews.first)
                let images = overlay.subviews.compactMap { $0 as? UIImageView }
                let outgoing = try XCTUnwrap(images.first { $0.image === before })
                let incoming = try XCTUnwrap(images.first { $0.image === after })
                let oldFrame = try XCTUnwrap(outgoing.layer.presentation()).frame
                let newFrame = try XCTUnwrap(incoming.layer.presentation()).frame
                let width = host.view.bounds.width
                let expectedOld: CGFloat = mode == .cover && direction < 0 ? 0 : -0.4 * width * CGFloat(direction)
                let expectedNew: CGFloat = mode == .cover && direction > 0 ? 0 : 0.6 * width * CGFloat(direction)
                XCTAssertEqual(oldFrame.minX, expectedOld, accuracy: 1)
                XCTAssertEqual(newFrame.minX, expectedNew, accuracy: 1)
                let rendered = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                    XCTAssertTrue(host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: false))
                }
                let evidence = XCTAttachment(image: rendered)
                evidence.name = "native \(mode.rawValue) direction \(direction) at 40 percent; red original blue target"
                evidence.lifetime = .keepAlways; add(evidence)
                turn.cancel(); turn.cancel()
                await nativeFrames()
                XCTAssertEqual(outcomes, [false], "A real intermediate native turn cancels exactly once")
                XCTAssertTrue(host.view.subviews.isEmpty)
                XCTAssertTrue(host.children.isEmpty)
            }
        }
    }

    @MainActor
    func testInteractiveNativeTurnRegrabReturnsOrCommitsOnlyAfterRelease() async throws {
        let before = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 48)).image { context in
            UIColor.orange.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
        }
        let after = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 48)).image { context in
            UIColor.purple.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
        }
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let key = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        let host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds; host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; key?.makeKey() }
        for mode in [ReaderPageTransition.cover, .slide] {
            for commit in [false, true] {
                var outcomes: [Bool] = []
                let completed = expectation(description: "native \(mode) regrab release \(commit)")
                let turn = try XCTUnwrap(ReaderEbookPageTurn(in: host.view, before: before, after: after,
                    direction: -1, transition: mode, paper: .white, interactive: true) {
                    outcomes.append($0); completed.fulfill()
                })
                turn.updateProgress(0.35)
                await nativeFrames()
                turn.release(commit: false)
                let regrab = turn.pauseForInteraction()
                XCTAssertGreaterThan(regrab, 0)
                XCTAssertLessThan(regrab, 1)
                turn.updateProgress(0.65)
                await nativeFrames()
                XCTAssertTrue(outcomes.isEmpty, "A regrabbed return animation remains uncommitted")
                turn.release(commit: commit)
                await fulfillment(of: [completed], timeout: 5)
                turn.cancel(); turn.cancel()
                XCTAssertEqual(outcomes, [commit])
                XCTAssertTrue(host.view.subviews.isEmpty)
            }
        }
    }

    /// UIKit-only interoperability fixtures. Real EPUB/MOBI/Core acceptance is
    /// exercised separately by the original-book WK methods.
    @MainActor
    func testPersistentNativeCurlOwnsOneLiveWebViewAndBoundedRealNeighbours() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let key = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        let host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds; host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; key?.makeKey() }
        let web = WKWebView(frame: host.view.bounds)
        let loaded = expectation(description: "actual selectable WK document")
        let navigation = ReaderEbookNativeNavigation { loaded.fulfill() }
        web.navigationDelegate = navigation
        let pager = ReaderEbookCurlPager(in: host.view, webView: web, paper: .yellow)
        XCTAssertTrue(pager.attach())
        defer { pager.retire() }
        web.loadHTMLString("<meta name='viewport' content='width=device-width,initial-scale=1'><p id='native'>one live selectable viewport</p>", baseURL: nil)
        await fulfillment(of: [loaded], timeout: 5)
        withExtendedLifetime(navigation) {}
        let red = nativeImage(.red), blue = nativeImage(.blue), green = nativeImage(.green)
        pager.coverCurrent(red)
        XCTAssertTrue(pager.prepared(current: red, previous: green, next: blue))
        XCTAssertEqual(pager.transitionStyle, .pageCurl)
        XCTAssertTrue(pager.dataSource === pager)
        XCTAssertTrue(pager.gestureRecognizers.contains { $0 is UIPanGestureRecognizer && $0.isEnabled })
        let current = try XCTUnwrap(pager.viewControllers?.first)
        let previous = try XCTUnwrap(pager.pageViewController(pager, viewControllerBefore: current))
        let next = try XCTUnwrap(pager.pageViewController(pager, viewControllerAfter: current))
        XCTAssertNil(pager.pageViewController(pager, viewControllerBefore: previous))
        XCTAssertNil(pager.pageViewController(pager, viewControllerAfter: next))
        @MainActor func books(in view: UIView) -> [WKWebView] {
            (view as? WKWebView).map { [$0] } ?? view.subviews.flatMap { books(in: $0) }
        }
        XCTAssertEqual(books(in: pager.view).count, 1)
        XCTAssertTrue(books(in: current.view).first === web)
        XCTAssertTrue(books(in: previous.view).isEmpty)
        XCTAssertTrue(books(in: next.view).isEmpty)
        XCTAssertTrue(web.isUserInteractionEnabled)
        let select = "const r=document.createRange();r.selectNodeContents(document.getElementById('native'));getSelection().removeAllRanges();getSelection().addRange(r);return getSelection().toString()"
        let selected = try await web.callAsyncJavaScript(select, arguments: [:], in: nil, contentWorld: .page) as? String
        XCTAssertEqual(selected, "one live selectable viewport")
        pager.memoryPressure = { [weak pager] in pager?.discardPrepared() }
        pager.didReceiveMemoryWarning()
        XCTAssertNil(pager.pageViewController(pager, viewControllerBefore: current))
        XCTAssertNil(pager.pageViewController(pager, viewControllerAfter: current))
        XCTAssertTrue(books(in: current.view).first === web)
        let afterPressure = try await web.callAsyncJavaScript("return getSelection().toString()", arguments: [:], in: nil, contentWorld: .page) as? String
        XCTAssertEqual(afterPressure, "one live selectable viewport", "Dropping neighbour pixels must preserve the live DOM selection")
    }

    @MainActor
    func testPersistentNativeCurlQueuedAndInFlightCancellationDrainBeforeRetirement() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let key = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        let host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds; host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; key?.makeKey() }
        for path in ["queued", "native-frame-cancel", "native-frame-retire", "native-complete"] {
            let web = WKWebView(frame: host.view.bounds)
            web.isOpaque = true; web.backgroundColor = .red; web.scrollView.backgroundColor = .red
            let loaded = expectation(description: path + " actual red source WK")
            let navigation = ReaderEbookNativeNavigation { loaded.fulfill() }
            web.navigationDelegate = navigation
            let pager = ReaderEbookCurlPager(in: host.view, webView: web, paper: .red)
            XCTAssertTrue(pager.attach())
            web.loadHTMLString("<meta name='viewport' content='width=device-width,initial-scale=1'><style>html,body{margin:0;background:rgb(255,0,0);min-height:100vh}</style><p>original native viewport</p>", baseURL: nil)
            await fulfillment(of: [loaded], timeout: 5)
            withExtendedLifetime(navigation) {}
            pager.coverCurrent(nativeImage(.red))
            XCTAssertTrue(pager.prepared(current: nativeImage(.red), previous: nil, next: nativeImage(.blue)))
            var outcomes: [Bool] = []
            let completed = path == "native-frame-retire" ? nil : expectation(description: "\(path) native completion")
            pager.ended = { [weak pager] _, _, committed in
                outcomes.append(committed); pager?.settled(committed: committed); completed?.fulfill()
            }
            let removed = expectation(description: "\(path) actual child removal")
            pager.retired = { removed.fulfill() }
            XCTAssertTrue(pager.turn(1))
            if path == "queued" {
                pager.cancel(); pager.cancel()
            } else {
                var observed: UIImage?
                // Wait on real display frames, looking for simultaneous red
                // original and blue target pixels in UIKit's native curl.
                for _ in 0..<60 {
                    await nativeFrames()
                    let frame = UIGraphicsImageRenderer(bounds: host.view.bounds).image { _ in
                        XCTAssertTrue(host.view.drawHierarchy(in: host.view.bounds, afterScreenUpdates: false))
                    }
                    let counts = try nativeColourCounts(frame)
                    if counts.red > 1000 && counts.blue > 1000 { observed = frame; break }
                    if !pager.isTurning { break }
                }
                let frame = try XCTUnwrap(observed, "A real in-flight curl must contain both distinct page contents")
                let attachment = XCTAttachment(image: frame); attachment.name = path + " red-original blue-target native curl"
                attachment.lifetime = .keepAlways; add(attachment)
                XCTAssertTrue(outcomes.isEmpty, "A native intermediate frame cannot acknowledge a page")
                if path == "native-frame-retire" {
                    pager.retire(); pager.retire()
                    XCTAssertTrue(host.children.contains { $0 === pager }, "Keep containment until UIKit finishes its appearance transition")
                } else if path == "native-frame-cancel" { pager.cancel(); pager.cancel() }
            }
            if path == "native-frame-retire" {
                await fulfillment(of: [removed], timeout: 5)
                XCTAssertTrue(outcomes.isEmpty, "A retired owner receives no stale native completion")
            } else {
                await fulfillment(of: [try XCTUnwrap(completed)], timeout: 5)
                pager.cancel(); pager.cancel()
                XCTAssertEqual(outcomes, [path == "native-complete"])
                pager.retire(); pager.retire()
                await fulfillment(of: [removed], timeout: 2)
            }
            XCTAssertTrue(host.children.isEmpty)
            XCTAssertTrue(host.view.subviews.isEmpty)
        }
    }

    /// A real native completion must leave WebKit in a visible window before
    /// the owner waits for its animation frames. These are browser/platform
    /// fixtures; original-book admission remains in the separate real journeys.
    @MainActor
    func testPersistentNativeCurlMountsLiveWKUnderTargetCoverBeforeAnimationFramesAndCanRollback() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let key = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        let host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds; host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; key?.makeKey() }
        for commit in [false, true] {
            let web = WKWebView(frame: host.view.bounds)
            web.isOpaque = true; web.backgroundColor = .red; web.scrollView.backgroundColor = .red
            web.scrollView.contentInsetAdjustmentBehavior = .never
            web.scrollView.isScrollEnabled = false
            let loaded = expectation(description: "settlement \(commit) actual two-colour DOM")
            let navigation = ReaderEbookNativeNavigation { loaded.fulfill() }
            web.navigationDelegate = navigation
            let pager = ReaderEbookCurlPager(in: host.view, webView: web, paper: .red)
            XCTAssertTrue(pager.attach())
            defer { pager.retire() }
            web.loadHTMLString("<meta name='viewport' content='width=device-width,initial-scale=1'><style>html,body{margin:0}section{height:100vh}#original{background:rgb(255,0,0)}#target{background:rgb(0,0,255)}</style><section id='original'>original live DOM viewport</section><section id='target'>different target DOM viewport</section>", baseURL: nil)
            await fulfillment(of: [loaded], timeout: 5)
            withExtendedLifetime(navigation) {}
            let heightValue = try await web.callAsyncJavaScript("return innerHeight", arguments: [:], in: nil, contentWorld: .page)
            let height = CGFloat(try XCTUnwrap(heightValue as? NSNumber).doubleValue)
            XCTAssertGreaterThan(height, 100)
            @MainActor func snapshot() async throws -> UIImage {
                let configuration = WKSnapshotConfiguration()
                configuration.rect = web.bounds; configuration.afterScreenUpdates = true
                return try await withCheckedThrowingContinuation { continuation in
                    web.takeSnapshot(with: configuration) { image, error in
                        if let error { continuation.resume(throwing: error) }
                        else if let image { continuation.resume(returning: image) }
                        else { continuation.resume(throwing: ReaderEbookError.invalidDocument) }
                    }
                }
            }
            let originalOffset = web.scrollView.contentOffset
            let original = try await snapshot()
            web.scrollView.setContentOffset(CGPoint(x: 0, y: height), animated: false)
            _ = try await web.callAsyncJavaScript("await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))", arguments: [:], in: nil, contentWorld: .page)
            let target = try await snapshot()
            XCTAssertGreaterThan(try nativeColourCounts(original).red, 1000)
            XCTAssertGreaterThan(try nativeColourCounts(target).blue, 1000)
            XCTAssertTrue(ReaderEbookPageTurn.accepts(original)); XCTAssertTrue(ReaderEbookPageTurn.accepts(target))
            web.scrollView.setContentOffset(originalOffset, animated: false)
            _ = try await web.callAsyncJavaScript("await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)))", arguments: [:], in: nil, contentWorld: .page)
            pager.coverCurrent(original)
            XCTAssertTrue(pager.prepared(current: original, previous: nil, next: target))
            let originalPage = try XCTUnwrap(pager.viewControllers?.first)
            let nativeCompleted = expectation(description: "settlement \(commit) genuine native completion")
            let framesCompleted = expectation(description: "settlement \(commit) real WK frames before owner settlement")
            var nativeToken: UUID?
            var targetPage: UIViewController?
            var frameValue: [String: Any]?
            var outcomes: [Bool] = []
            pager.ended = { token, direction, completed in
                defer { nativeCompleted.fulfill() }
                outcomes.append(completed); nativeToken = token; targetPage = pager.viewControllers?.first
                XCTAssertEqual(direction, 1); XCTAssertTrue(completed)
                XCTAssertFalse(targetPage === originalPage)
                XCTAssertTrue(web.window === window, "A genuine native completion must already mount the sole live WK in the visible target")
                XCTAssertTrue(web.superview === targetPage?.view)
                XCTAssertTrue(targetPage?.view.accessibilityElementsHidden == true)
                XCTAssertTrue(targetPage?.view.isUserInteractionEnabled == false)
                let cover = targetPage?.view.subviews.last as? UIImageView
                XCTAssertTrue(cover?.image === target && cover?.isHidden == false,
                    "The genuine prepared bitmap must remain above the provisional live viewport")
                XCTAssertTrue(pager.stageSettlement(token), "The exact native turn remains provisionally covered")
                XCTAssertFalse(pager.stageSettlement(UUID()), "A stale native turn cannot mount the WK")
                // This is the production ordering that previously deadlocked:
                // move the live viewport, then await its real display frames,
                // while keeping the existing target bitmap above its DOM.
                web.scrollView.setContentOffset(CGPoint(x: 0, y: height), animated: false)
                web.callAsyncJavaScript("await new Promise(r=>requestAnimationFrame(()=>requestAnimationFrame(r)));return {y:scrollY,visibility:document.visibilityState,id:document.elementFromPoint(20,30)?.id,text:document.elementFromPoint(20,30)?.textContent}",
                    arguments: [:], in: nil, in: .page) { result in
                        if case let .success(value) = result { frameValue = value as? [String: Any] }
                        else { XCTFail("A visible live WK must complete its actual rAF: \(result)") }
                        framesCompleted.fulfill()
                    }
            }
            XCTAssertTrue(pager.turn(1))
            await fulfillment(of: [nativeCompleted, framesCompleted], timeout: 8)
            let token = try XCTUnwrap(nativeToken), visible = try XCTUnwrap(targetPage)
            let measured = try XCTUnwrap(frameValue)
            XCTAssertEqual(outcomes, [true])
            XCTAssertEqual(CGFloat((measured["y"] as? NSNumber)?.doubleValue ?? -1), height, accuracy: 0.5)
            XCTAssertEqual(measured["visibility"] as? String, "visible")
            XCTAssertEqual(measured["id"] as? String, "target")
            XCTAssertEqual(measured["text"] as? String, "different target DOM viewport")
            let covered = UIGraphicsImageRenderer(bounds: visible.view.bounds).image { _ in
                XCTAssertTrue(visible.view.drawHierarchy(in: visible.view.bounds, afterScreenUpdates: true))
            }
            let pixels = try nativeColourCounts(covered)
            XCTAssertGreaterThan(pixels.blue, 1000); XCTAssertLessThan(pixels.red, 100)
            let attachment = XCTAttachment(image: covered); attachment.name = "native completion live-WK under genuine target snapshot \(commit)"
            attachment.lifetime = .keepAlways; add(attachment)
            XCTAssertTrue(pager.isTurning, "WebKit frames alone must not commit the native turn")
            pager.settled(committed: true, token: UUID())
            XCTAssertTrue(pager.isTurning, "A stale owner completion cannot uncover or promote a page")
            if commit { pager.settled(committed: true, token: token) }
            else { pager.cancel(); pager.settled(committed: true, token: token) }
            let resting = try XCTUnwrap(pager.viewControllers?.first)
            XCTAssertTrue(resting === (commit ? visible : originalPage))
            XCTAssertTrue(web.superview === resting.view && web.window === window)
            XCTAssertFalse(resting.view.accessibilityElementsHidden); XCTAssertTrue(resting.view.isUserInteractionEnabled)
            XCTAssertTrue(resting.view.subviews.last === web, "The sole live WK must be revealed at rest for native selection")
            XCTAssertEqual(web.scrollView.contentOffset.y, commit ? height : originalOffset.y, accuracy: 0.5)
            XCTAssertFalse(pager.isTurning)
            pager.retire()
            XCTAssertTrue(host.children.isEmpty); XCTAssertTrue(host.view.subviews.isEmpty)
        }
    }

    /// Real WebKit Promise lifetime fixture; it neither creates a book nor
    /// supplies a Core/Host response. Only Reader's native waiter is cancelled.
    @MainActor
    func testPageJavaScriptCancellationReleasesReaderOwnerAndDrainsOldWKWithoutAffectingNewWK() async throws {
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let key = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene); window.frame = CGRect(x: 0, y: 0, width: 390, height: 600)
        let host = UIViewController(); window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds; host.view.layoutIfNeeded()
        defer { window.isHidden = true; window.rootViewController = nil; key?.makeKey() }
        let oldStarted = expectation(description: "old WK actual unresolved Promise started")
        let newStarted = expectation(description: "new WK actual unresolved Promise started")
        let handler = ReaderEbookScriptTestHandler { body in
            if body["kind"] as? String == "old-waiting" { oldStarted.fulfill() }
            if body["kind"] as? String == "new-waiting" { newStarted.fulfill() }
        }
        @MainActor func configuration() -> WKWebViewConfiguration {
            let configuration = WKWebViewConfiguration()
            configuration.userContentController.add(handler, contentWorld: .defaultClient, name: "readerEbook")
            return configuration
        }
        let oldWeb = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 300), configuration: configuration())
        let newWeb = WKWebView(frame: CGRect(x: 0, y: 300, width: 390, height: 300), configuration: configuration())
        host.view.addSubview(oldWeb); host.view.addSubview(newWeb)
        let oldLoaded = expectation(description: "old actual WK document"), newLoaded = expectation(description: "new actual WK document")
        let oldNavigation = ReaderEbookNativeNavigation { oldLoaded.fulfill() }
        let newNavigation = ReaderEbookNativeNavigation { newLoaded.fulfill() }
        oldWeb.navigationDelegate = oldNavigation; newWeb.navigationDelegate = newNavigation
        oldWeb.loadHTMLString("<p>old native Promise boundary</p>", baseURL: nil)
        newWeb.loadHTMLString("<p>new native Promise boundary</p>", baseURL: nil)
        await fulfillment(of: [oldLoaded, newLoaded], timeout: 5)
        withExtendedLifetime((oldNavigation, newNavigation)) {}
        let gate = ReaderEbookJavaScriptGate()
        defer { gate.retire() }
        let cancelled = expectation(description: "Reader waiter cancelled before old WebKit Promise resolves")
        weak var owner: NSObject?
        weak var snapshot: UIImage?
        var outcomes: [String] = []
        var task: Task<Void, Never>?
        autoreleasepool {
            let capturedOwner = NSObject(), capturedImage = nativeImage(.purple)
            owner = capturedOwner; snapshot = capturedImage
            task = Task { [capturedOwner, capturedImage] in
                defer { withExtendedLifetime((capturedOwner, capturedImage)) {}; cancelled.fulfill() }
                do {
                    _ = try await gate.call(oldWeb, script: "return await new Promise(resolve=>{window.__readerGateResolve=resolve;window.webkit.messageHandlers.readerEbook.postMessage({kind:'old-waiting'});})")
                    outcomes.append("unexpected-old-result")
                } catch is CancellationError { outcomes.append("cancelled") }
                catch { XCTFail("Expected Reader cancellation: \(error)") }
            }
        }
        defer { task?.cancel() }
        await fulfillment(of: [oldStarted], timeout: 5)
        XCTAssertNotNil(owner); XCTAssertNotNil(snapshot)
        let oldRequest = try XCTUnwrap(gate.pendingRequest)
        XCTAssertTrue(gate.hasPendingCall(for: oldWeb)); XCTAssertFalse(oldRequest.isDrained)
        do {
            _ = try await gate.call(oldWeb, script: "window.__readerRejectedCall=true;return true")
            XCTFail("A second native JS waiter for this WK must be rejected while its first Promise is unresolved")
        } catch let error as ReaderEbookError { XCTAssertEqual(error, .resourceLimit) }
        catch { XCTFail("Wrong same-WK admission failure: \(error)") }
        task?.cancel()
        await fulfillment(of: [cancelled], timeout: 3)
        task = nil; gate.cancel(); gate.cancel()
        XCTAssertNil(owner, "Cancelling must unwind the real waiter and release its captured Reader owner")
        XCTAssertNil(snapshot, "Cancelling must also release captured viewport pixels before native Promise resolution")
        XCTAssertEqual(outcomes, ["cancelled"])
        XCTAssertFalse(oldRequest.isDrained, "Task cancellation must not pretend WebKit's internal Promise has resolved")
        XCTAssertTrue(gate.hasPendingCall(for: oldWeb), "Keep only the small native drain fence")
        let rejected = try await oldWeb.callAsyncJavaScript("return typeof window.__readerRejectedCall", arguments: [:], in: nil, contentWorld: .defaultClient)
        XCTAssertEqual(rejected as? String, "undefined", "Rejecting accumulation must not execute a second Promise/body")

        let newCompleted = expectation(description: "new WK independently completes its own real Promise")
        var newOutcomes: [String] = []
        let newTask = Task {
            defer { newCompleted.fulfill() }
            do {
                let value = try await gate.call(newWeb, script: "return await new Promise(resolve=>{window.__readerGateResolve=resolve;window.webkit.messageHandlers.readerEbook.postMessage({kind:'new-waiting'});})")
                if let value = value as? String { newOutcomes.append(value) }
                else { XCTFail("New WK must return its own actual Promise value") }
            } catch { XCTFail("The cancelled old WK must not reject the new WK: \(error)") }
        }
        defer { newTask.cancel() }
        await fulfillment(of: [newStarted], timeout: 5)
        let newRequest = try XCTUnwrap(gate.pendingRequest)
        XCTAssertFalse(newRequest === oldRequest)
        _ = try await oldWeb.callAsyncJavaScript("window.__readerGateResolve('late-old');return true", arguments: [:], in: nil, contentWorld: .defaultClient)
        for _ in 0..<30 { if oldRequest.isDrained { break }; await nativeFrames() }
        XCTAssertTrue(oldRequest.isDrained, "The actual late native completion must drain its cancelled fence exactly once")
        XCTAssertEqual(outcomes, ["cancelled"], "A late completion cannot resume the cancelled Reader continuation again")
        XCTAssertTrue(gate.pendingRequest === newRequest && gate.hasPendingCall(for: newWeb))
        XCTAssertFalse(newRequest.isDrained); XCTAssertTrue(newOutcomes.isEmpty)
        _ = try await newWeb.callAsyncJavaScript("window.__readerGateResolve('current-new');return true", arguments: [:], in: nil, contentWorld: .defaultClient)
        await fulfillment(of: [newCompleted], timeout: 5)
        XCTAssertEqual(newOutcomes, ["current-new"])
        XCTAssertTrue(newRequest.isDrained); XCTAssertNil(gate.pendingRequest)
    }

    @MainActor
    private func nativeImage(_ colour: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 32, height: 48)).image { context in
            colour.setFill(); context.fill(CGRect(x: 0, y: 0, width: 32, height: 48))
        }
    }

    @MainActor
    private func nativeColourCounts(_ image: UIImage) throws -> (red: Int, blue: Int) {
        let cg = try XCTUnwrap(image.cgImage)
        var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        try pixels.withUnsafeMutableBytes { buffer in
            let context = try XCTUnwrap(CGContext(data: buffer.baseAddress, width: cg.width, height: cg.height,
                bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(cg.width), height: CGFloat(cg.height)))
        }
        var red = 0, blue = 0
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            if pixels[offset] > 180 && pixels[offset + 1] < 90 && pixels[offset + 2] < 90 { red += 1 }
            if pixels[offset] < 90 && pixels[offset + 1] < 90 && pixels[offset + 2] > 180 { blue += 1 }
        }
        return (red, blue)
    }

    @MainActor
    private func nativeFrames() async {
        let committed = expectation(description: "two actual native display frames")
        let observer = ReaderEbookNativeFrameTick { committed.fulfill() }
        observer.start()
        await fulfillment(of: [committed], timeout: 3)
        observer.stop()
    }
}

@MainActor
private final class ReaderEbookNativeFrameTick: NSObject {
    private var link: CADisplayLink?
    private var remaining = 2
    private let callback: () -> Void
    init(_ callback: @escaping () -> Void) { self.callback = callback }
    func start() {
        link = CADisplayLink(target: self, selector: #selector(tick))
        link?.add(to: .main, forMode: .common)
    }
    func stop() { link?.invalidate(); link = nil }
    @objc private func tick() {
        remaining -= 1
        if remaining == 0 { stop(); callback() }
    }
}

@MainActor
private final class ReaderEbookNativeNavigation: NSObject, WKNavigationDelegate {
    private let ready: () -> Void
    init(_ ready: @escaping () -> Void) { self.ready = ready }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { ready() }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        XCTFail("Native fixture navigation failed: \(error)"); ready()
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        XCTFail("Native fixture navigation failed: \(error)"); ready()
    }
}

@MainActor
private final class ReaderEbookScriptTestHandler: NSObject, WKScriptMessageHandler {
    let receive: ([String: Any]) -> Void
    init(_ receive: @escaping ([String: Any]) -> Void) { self.receive = receive }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if let body = message.body as? [String: Any] { receive(body) }
    }
}
