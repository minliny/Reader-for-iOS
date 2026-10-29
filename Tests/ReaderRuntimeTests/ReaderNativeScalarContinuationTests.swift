import Combine
import Foundation
import SwiftUI
import UIKit
import XCTest
@testable import Reader

@MainActor
final class ReaderNativeScalarContinuationTests: XCTestCase {
    /// Native component + production Host/Core integration; no physical gesture or full reading UI claim.
    func testRealOriginalNativePageScalarACKSurvivesReflowAndColdOpen() async throws {
        enum EvidenceError: Error { case mismatch }
        func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
            guard try condition() else { XCTFail(message); throw EvidenceError.mismatch }
        }
        let manager = FileManager.default
        let digest = "997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38"
        let input = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 99_898, digest: digest)
        let original = try Data(contentsOf: input)
        let originalText = try XCTUnwrap(String(data: original, encoding: .utf8))
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderNativeScalar-" + UUID().uuidString)
        let coreURL = root.appendingPathComponent("Core"), sourcesURL = root.appendingPathComponent("Sources")
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let oldKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        let host = UIHostingController(rootView: AnyView(EmptyView()))
        window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds
        defer { window.isHidden = true; window.rootViewController = nil; oldKey?.makeKey() }
        var services: [ReaderLibraryService] = []
        var activeModel: ReaderApplicationModel?
        var waitingLayout: XCTestExpectation?, waitingPage: XCTestExpectation?
        var positions: [UInt64] = [], commits: [(UUID, ReaderNativePageOutcome)] = []
        var layoutReadyCount = 0
        func unmount() {
            waitingLayout = nil; waitingPage = nil
            host.rootView = AnyView(EmptyView()); host.view.layoutIfNeeded()
        }
        func open(_ model: ReaderApplicationModel, book: ReaderBook, chapter: UInt32? = nil) async throws -> ReaderActiveSession {
            let ready = expectation(description: "production Model opened real Core body")
            let subscription = model.$reader.compactMap { $0 }.first().sink { _ in ready.fulfill() }
            model.open(book, chapterIndex: chapter)
            await fulfillment(of: [ready], timeout: 15)
            subscription.cancel()
            return try XCTUnwrap(model.reader)
        }
        func mount(_ model: ReaderApplicationModel, session: ReaderActiveSession,
                   width: CGFloat, font: CGFloat, turn: UUID? = nil) {
            let surface = ReaderTextSurface(content: session.content, scalarOffset: session.scalarOffset,
                restorationID: session.restorationID, fontSize: font, lineHeight: 1.96,
                horizontalInset: 20, bottomInset: 24, paper: ReaderPaperPalette(theme: .day),
                positionChanged: { offset in
                    positions.append(offset)
                    model.recordVisibleOffset(offset, sessionID: session.id, restorationID: session.restorationID)
                }, centerTapped: {}, pageTurnID: turn, automaticPageEnabled: turn != nil,
                pageCommitted: { id, outcome in
                    commits.append((id, outcome))
                    let pending = waitingPage; waitingPage = nil; pending?.fulfill()
                }, layoutReady: {
                    layoutReadyCount += 1
                    let pending = waitingLayout; waitingLayout = nil; pending?.fulfill()
                }, reducePageMotion: true)
            host.rootView = AnyView(surface.frame(width: width, height: window.bounds.height).ignoresSafeArea())
            host.view.setNeedsLayout(); host.view.layoutIfNeeded(); window.layoutIfNeeded()
        }
        func textView(_ view: UIView) -> UITextView? {
            if let text = view as? UITextView { return text }
            return view.subviews.lazy.compactMap { textView($0) }.first
        }
        func layoutEvidence(_ text: UITextView?, body: ReaderChapterContent, stage: String) {
            var facts = "stage=\(stage) chapter=\(body.chapterIndex) scalars=\(body.scalarCount)\n"
                + "layoutReadyCount=\(layoutReadyCount) waitingLayout=\(waitingLayout != nil) positions=\(positions)\n"
                + "waitingPage=\(waitingPage != nil) commits=\(commits)\n"
                + "scene=\(scene.coordinateSpace.bounds) activation=\(scene.activationState.rawValue)\n"
                + "windowFrame=\(window.frame) windowBounds=\(window.bounds)\n"
                + "hostFrame=\(host.view.frame) hostBounds=\(host.view.bounds) safeArea=\(host.view.safeAreaInsets)\n"
            if let text {
                facts += "textFrame=\(text.frame) textBounds=\(text.bounds) mounted=\(text.window === window)\n"
                    + "contentSize=\(text.contentSize) contentOffset=\(text.contentOffset)\n"
                    + "contentInset=\(text.contentInset) adjustedInset=\(text.adjustedContentInset) textInset=\(text.textContainerInset)\n"
                    + "textContainer=\(text.textContainer.size) utf16=\(text.textStorage.length)\n"
            } else { facts += "UITextView=missing\n" }
            let attachment = XCTAttachment(string: facts)
            attachment.name = "native-scalar-layout-" + stage; attachment.lifetime = .keepAlways; add(attachment)
        }
        func nativeAnchor(_ scalar: UInt64, body: ReaderChapterContent, font: CGFloat, stage: String) throws {
            let text = try XCTUnwrap(textView(host.view))
            let projection = ReaderParagraphProjection(content: body.content)
            let paragraph = try XCTUnwrap(projection.paragraphs.first { $0.sourceScalarRange.contains(scalar) })
            let scalars = Array(body.content.unicodeScalars)
            let excerpt = String(String.UnicodeScalarView(scalars[Int(scalar)..<min(Int(scalar) + 28,
                Int(paragraph.sourceScalarRange.upperBound))]))
            try require(!excerpt.isEmpty && originalText.contains(excerpt), "Saved scalar must identify unchanged original text")
            let prefix = (body.chapterTitle + "\n").utf16.count
            let displayed = prefix + projection.displayUTF16Offset(forSourceScalar: scalar)
            let actualFont = try XCTUnwrap(text.attributedText.attribute(.font, at: displayed, effectiveRange: nil) as? UIFont)
            try require(abs(actualFont.pointSize - font) < 0.1, "The native anchor must use the requested real reading font size")
            let range = NSRange(location: prefix + paragraph.displayUTF16Range.location,
                                length: paragraph.displayUTF16Range.length)
            try require((text.text as NSString).substring(with: range) == paragraph.text,
                        "Actual native text must retain the scalar's entire original paragraph")
            let position = try XCTUnwrap(text.position(from: text.beginningOfDocument, offset: displayed))
            let caret = text.caretRect(for: position)
            let glyph = text.layoutManager.glyphIndexForCharacter(at: displayed)
            let line = text.layoutManager.lineFragmentUsedRect(forGlyphAt: glyph, effectiveRange: nil)
                .offsetBy(dx: text.textContainerInset.left, dy: text.textContainerInset.top)
            try require(caret.height > 0 && line.height > 0 && text.bounds.intersects(caret)
                        && text.bounds.intersects(line) && window.bounds.intersects(text.convert(caret, to: window)),
                        "Core's exact scalar caret and TextKit line must be visible in the native viewport")
            let attachment = XCTAttachment(string: "stage=\(stage) scalar=\(scalar)\nexcerpt=\(excerpt)\n"
                + "paragraph=\(paragraph.text)\nviewport=\(text.bounds) caret=\(caret) line=\(line)")
            attachment.name = "native-scalar-" + stage; attachment.lifetime = .keepAlways; add(attachment)
        }
        do {
            try require(!manager.fileExists(atPath: root.path), "Only a fresh UUID library is admitted")
            let library = try ReaderLibraryService(storageURL: coreURL, sourceURL: sourcesURL)
            services.append(library)
            let imported = try await library.importBook(at: input)
            try require(imported.created && imported.book.bookId == "local:" + digest, "Real Core must import the exact original")
            let chapters = try await library.chapters(for: imported.book)
            let chapter = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
            let model = ReaderApplicationModel(service: library, readingTimeStorageURL: root.appendingPathComponent("Time-1.json"))
            activeModel = model
            let session = try await open(model, book: imported.book, chapter: chapter.index)
            let body = session.content
            try require(body.scalarCount > 1_000 && body.bodyVersion?.isEmpty == false
                        && body.processingVersion?.isEmpty == false, "The real chapter needs a versioned, long Core body")
            let before = try await library.progress(for: imported.book)
            try require(!before.found && before.progress == nil && before.progressRevision == session.progressRevision,
                        "Opening must preserve the initial Core CAS observation without saving zero")
            let initialLayout = expectation(description: "production native initial layout")
            waitingLayout = initialLayout
            let width = window.bounds.width
            mount(model, session: session, width: width, font: 18)
            await fulfillment(of: [initialLayout], timeout: 8)
            let initialText = textView(host.view)
            layoutEvidence(initialText, body: body, stage: "initial")
            try require(waitingLayout == nil, "Production must report its initial native layout before a page request")
            try require(positions.isEmpty, "Initial native restoration cannot publish a synthetic position")
            let text = try XCTUnwrap(initialText)
            let originalWidth = text.bounds.width
            try require(text.window === window && text.bounds.width.isFinite && text.bounds.height.isFinite
                        && text.bounds.width > 0 && text.bounds.height > 0,
                        "The real native layout needs a mounted, nonempty viewport; see initial layout attachment")
            let initialPageY = text.contentOffset.y
            let lastPageY = max(0, text.contentSize.height - text.bounds.height)
            // Production also advances a final partial page. Admit its real measured
            // travel, then prove the actual request reaches the native page target.
            let expectedPageY = min(lastPageY, initialPageY + max(1, text.bounds.height - 16))
            try require(initialPageY.isFinite && text.contentSize.height.isFinite && lastPageY.isFinite
                        && lastPageY - initialPageY > 0.5,
                        "The real chapter must offer native page travel: y=\(initialPageY) last=\(lastPageY); see initial layout attachment")
            let turn = UUID(), page = expectation(description: "production automatic native page committed")
            waitingPage = page
            mount(model, session: session, width: width, font: 18, turn: turn)
            await fulfillment(of: [page], timeout: 8)
            let committedText = textView(host.view)
            layoutEvidence(committedText, body: body, stage: "page-committed")
            try require(committedText === text, "The production page request must advance the mounted UITextView")
            try require(waitingPage == nil && commits.count == 1 && commits[0].0 == turn, "The exact production turn must commit once")
            guard case .advanced = commits[0].1 else {
                XCTFail("The real native page must advance, received \(commits[0].1)")
                throw EvidenceError.mismatch
            }
            try require(text.contentOffset.y > initialPageY && abs(text.contentOffset.y - expectedPageY) < 0.5,
                        "Production must move the native viewport to its measured page target: before=\(initialPageY) expected=\(expectedPageY) actual=\(text.contentOffset.y)")
            let scalar = try XCTUnwrap(positions.last)
            try require(scalar > 0 && scalar < body.scalarCount && model.reader?.scalarOffset == scalar,
                        "Only the production surface event may supply this real nonzero scalar")
            let flushed = await model.flushReading()
            let ackRevision = try XCTUnwrap(model.reader?.progressRevision)
            let saved = try await library.progress(for: imported.book)
            let position = try XCTUnwrap(saved.progress)
            let receiptEvidence = XCTAttachment(string: "Model original ACK revision=\(ackRevision)\nCore stored position="
                + String(decoding: try JSONEncoder().encode(saved), as: UTF8.self))
            receiptEvidence.name = "native-scalar-original-ack-and-stored-row"; receiptEvidence.lifetime = .keepAlways; add(receiptEvidence)
            try require(flushed && saved.found && ackRevision != session.progressRevision && saved.progressRevision == ackRevision,
                        "Model must consume the original save ACK revision before a separate Core read confirms it")
            try require(position.sourceId == body.sourceId && position.bookId == body.bookId
                        && position.chapterIndex == body.chapterIndex && position.chapterOffset == scalar
                        && position.bodyVersion == body.bodyVersion && position.processingVersion == body.processingVersion,
                        "Core must retain the exact native scalar and complete position scope")
            try require(position.locationRevision == nil,
                        "A scalar-only save without a resolver anchor or source-switch transaction cannot fabricate a location revision")
            try nativeAnchor(position.chapterOffset, body: body, font: 18, stage: "saved")
            let reflow = expectation(description: "production font and width reflow restored")
            let eventCount = positions.count
            waitingLayout = reflow
            mount(model, session: try XCTUnwrap(model.reader), width: max(280, width - 56), font: 23)
            await fulfillment(of: [reflow], timeout: 8)
            try require(textView(host.view) === text && text.bounds.width < originalWidth,
                        "Font/width reflow must update the same native surface rather than remount a restored replacement")
            try require(waitingLayout == nil && positions.count == eventCount && model.reader?.scalarOffset == scalar,
                        "A style-only reflow cannot publish a synthetic zero position")
            try nativeAnchor(scalar, body: body, font: 23, stage: "reflow")
            let reflowFlushed = await model.flushReading()
            let afterReflow = try await library.progress(for: imported.book)
            try require(reflowFlushed && afterReflow == saved, "Reflow must not replace the original acknowledged Core position")
            unmount(); await model.closeReader()
            try require(model.reader == nil, "The original Host session must close before its Core")
            try await library.close()
            let reopened = try ReaderLibraryService(storageURL: coreURL, sourceURL: sourcesURL)
            services.append(reopened)
            let coldModel = ReaderApplicationModel(service: reopened, readingTimeStorageURL: root.appendingPathComponent("Time-2.json"))
            activeModel = coldModel
            let coldObservation = try await reopened.progress(for: imported.book)
            let cold = try await open(coldModel, book: imported.book)
            try require(cold.content == body && cold.scalarOffset == scalar && coldObservation.progress == position
                        && cold.progressRevision?.isEmpty == false && cold.progressRevision == coldObservation.progressRevision,
                        "A new Model/Core must restore the persistent row and exact scalar while adopting its current Core CAS observation")
            let coldLayout = expectation(description: "cold native anchor layout")
            waitingLayout = coldLayout
            mount(coldModel, session: cold, width: width, font: 18)
            await fulfillment(of: [coldLayout], timeout: 8)
            try require(waitingLayout == nil && positions.count == eventCount, "Cold native restoration must not emit a replacement position")
            try nativeAnchor(scalar, body: cold.content, font: 18, stage: "cold")
            let coldProgress = try await reopened.progress(for: imported.book)
            try require(coldProgress.progress == position && coldProgress.progressRevision == cold.progressRevision,
                        "Cold native restoration must retain the persisted position and its newly observed Core CAS")
            let retained = try await reopened.retainedSourceURL(for: imported.book)
            try require(retained.path.hasPrefix(sourcesURL.path + "/"), "Retained source must belong to this private UUID library")
            try require(try Data(contentsOf: input) == original && Data(contentsOf: retained) == original,
                        "Both the provisioned original and retained source must remain byte-identical")
            unmount(); await coldModel.closeReader()
            try require(coldModel.reader == nil, "The cold Host must close before successful cleanup")
            try await reopened.close(); activeModel = nil
            try manager.removeItem(at: root)
        } catch {
            unmount()
            if let activeModel { await activeModel.closeReader() }
            for library in services { try? await library.close() }
            let attachment = XCTAttachment(string: "Preserved failed private Core/Sources: " + root.path)
            attachment.name = "native-scalar-failure-root"; attachment.lifetime = .keepAlways; add(attachment)
            throw error
        }
    }
}
