import CryptoKit
import Foundation
import UIKit
import SwiftUI
import XCTest
@testable import Reader

@MainActor
final class ReaderNativeSelectionTapTests: XCTestCase {
    private enum BoundaryError: Error { case invalidViewport }
    /// Real Core import/body/highlight plus native TextKit geometry. These
    /// coordinator boundaries do not claim a physical tap / system menu run.
    func testRealOriginalScrollAndPagedOutsideSelectionTapConsumesFirstTapAndPreservesCoreHighlight() async throws {
        let digest = "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5"
        let input = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 8_871_723, digest: digest)
        let original = try Data(contentsOf: input, options: .mappedIfSafe)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealSelectionTap-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                                               sourceURL: root.appendingPathComponent("Sources"))
        do {
            let imported = try await service.importBook(at: input)
            XCTAssertTrue(imported.created); XCTAssertEqual(imported.book.bookId, "local:" + digest)
            let chapters = try await service.chapters(for: imported.book)
            let chapter = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
            let body = try await service.content(for: imported.book, chapterIndex: chapter.index)
            let projection = ReaderParagraphProjection(content: body.content)
            let paragraph = try XCTUnwrap(projection.paragraphs.first { $0.text.unicodeScalars.count >= 8 })
            let start = paragraph.sourceScalarRange.lowerBound + 2, end = start + 4
            let prefix = (body.chapterTitle + "\n").utf16.count
            let displayStart = prefix + projection.displayUTF16Offset(forSourceScalar: start)
            let displayEnd = prefix + projection.displayUTF16Offset(forSourceScalar: end)
            let selected = NSRange(location: displayStart, length: displayEnd - displayStart)
            let mark = try await service.createHighlight(for: imported.book, content: body,
                range: ReaderScalarRange(lowerBound: start, upperBound: end), style: "highlight",
                note: "真实原书选区边界", operationID: UUID().uuidString)
            let marks = try await service.highlights(for: imported.book)
            XCTAssertEqual(marks, [mark])
            XCTAssertEqual(mark.positionScope, try ReaderContentPositionScope(book: imported.book, content: body))
            let before = try await service.progress(for: imported.book)
            try await verifyScroll(body, selection: selected, sourceStart: start, sourceEnd: end, marks: marks)
            try await verifyPaged(body, selection: selected, sourceStart: start, sourceEnd: end, marks: marks)
            let after = try await service.progress(for: imported.book)
            XCTAssertEqual(after, before, "Dismissing native selection must not write a new Core position")
            let remaining = try await service.highlights(for: imported.book)
            XCTAssertEqual(remaining, marks, "Ending native selection does not delete the saved Core annotation")
            XCTAssertEqual(try Data(contentsOf: input), original)
            let retained = try await service.retainedSourceURL(for: imported.book)
            XCTAssertEqual(try Data(contentsOf: retained), original)
            XCTAssertEqual(SHA256.hash(data: try Data(contentsOf: retained)).map { String(format: "%02x", $0) }.joined(), digest)
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    /// Exercises mounted TextKit selection, UIKit clipboard actions and the
    /// gesture delegate. The system menu and finger input are UI journeys.
    func testGutenbergCrossParagraphSelectionKeepsCoreScalarsAndRejectsReaderPagePan() async throws {
        let digest = "997442c1d041cc731d57bd164078a1dd6e98a5fe0eb9b6ec8b202edc3d0a5a38"
        let input = try ReaderLocalFormatsTests.originalURL(format: "txt", byteCount: 99_898, digest: digest)
        let original = try Data(contentsOf: input)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderCrossParagraph-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"),
                                               sourceURL: root.appendingPathComponent("Sources"))
        do {
            let imported = try await service.importBook(at: input)
            XCTAssertTrue(imported.created)
            XCTAssertEqual(imported.book.bookId, "local:" + digest)
            let chapters = try await service.chapters(for: imported.book)
            let chapter = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
            let body = try await service.content(for: imported.book, chapterIndex: chapter.index)
            let projection = ReaderParagraphProjection(content: body.content)
            let first = try XCTUnwrap(projection.paragraphs.firstIndex { $0.text.contains("我要給阿Ｑ做正傳") })
            let second = try XCTUnwrap(projection.paragraphs.dropFirst(first + 1).first)
            XCTAssertTrue(second.text.contains("然而要做這一篇速朽的文章"))
            let paragraph = projection.paragraphs[first]
            let tail = String(paragraph.text.suffix(5))
            let head = String(second.text.prefix(8))
            let start = paragraph.sourceScalarRange.upperBound - UInt64(tail.unicodeScalars.count)
            let end = second.sourceScalarRange.lowerBound + UInt64(head.unicodeScalars.count)
            let prefix = (body.chapterTitle + "\n").utf16.count
            let displayStart = prefix + NSMaxRange(paragraph.displayUTF16Range) - tail.utf16.count
            let displayEnd = prefix + second.displayUTF16Range.location + head.utf16.count
            let selection = NSRange(location: displayStart, length: displayEnd - displayStart)
            let expectedText = tail + "\n" + head
            let mark = try await service.createHighlight(for: imported.book, content: body,
                range: ReaderScalarRange(lowerBound: start, upperBound: end), style: "highlight",
                note: "跨段選文", operationID: UUID().uuidString)
            XCTAssertEqual(mark.positionScope, try ReaderContentPositionScope(book: imported.book, content: body))
            let before = try await service.progress(for: imported.book)
            try await verifyScroll(body, selection: selection, sourceStart: start, sourceEnd: end,
                                   marks: [mark], expectedText: expectedText)
            try await verifyPaged(body, selection: selection, sourceStart: start, sourceEnd: end,
                                  marks: [mark], expectedText: expectedText, transition: .cover)
            let after = try await service.progress(for: imported.book)
            let marks = try await service.highlights(for: imported.book)
            XCTAssertEqual(after, before)
            XCTAssertEqual(marks, [mark])
            let retained = try await service.retainedSourceURL(for: imported.book)
            XCTAssertEqual(try Data(contentsOf: retained), original)
            XCTAssertEqual(try Data(contentsOf: input), original)
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    private func verifyScroll(_ body: ReaderChapterContent, selection: NSRange,
                              sourceStart: UInt64, sourceEnd: UInt64, marks: [ReaderHighlight],
                              expectedText: String? = nil) async throws {
        let observed = Observation()
        let firstLayout = expectation(description: "real scroll body layout")
        var firstReady = false
        var surface = ReaderTextSurface(content: body, scalarOffset: 0, restorationID: UUID(),
            fontSize: 18, lineHeight: 1.96, horizontalInset: 20, bottomInset: 24, paper: .init(),
            positionChanged: { _ in observed.positions += 1 }, centerTapped: { observed.centers += 1 },
            selectionChanged: { observed.selections.append(($0, $1, $2)) },
            layoutReady: { if !firstReady { firstReady = true; firstLayout.fulfill() } })
        let coordinator = surface.makeCoordinator()
        let text = UITextView(frame: CGRect(x: 0, y: 0, width: 390, height: 600))
        text.isEditable = false; text.isSelectable = true
        text.textContainer.lineFragmentPadding = 0
        text.delegate = coordinator; coordinator.activeView = text
        let controller = UIViewController(); controller.view = text
        let window = UIWindow(frame: text.bounds); window.rootViewController = controller; window.isHidden = false
        defer { coordinator.retire(text); window.isHidden = true }
        coordinator.layoutChanged(text)
        await fulfillment(of: [firstLayout], timeout: 5)
        text.selectedRange = selection
        coordinator.textViewDidChangeSelection(text)
        XCTAssertEqual(observed.selections.last?.0, sourceStart); XCTAssertEqual(observed.selections.last?.1, sourceEnd)
        if let expectedText {
            try verifySelectedText(expectedText, in: text, observed: observed)
        }

        let highlightedLayout = expectation(description: "real saved highlight scroll reflow")
        var highlightedReady = false
        surface.highlights = marks
        surface.layoutReady = { if !highlightedReady { highlightedReady = true; highlightedLayout.fulfill() } }
        coordinator.parent = surface; coordinator.layoutChanged(text)
        await fulfillment(of: [highlightedLayout], timeout: 5)
        XCTAssertEqual(text.selectedRange, selection, "The same-body saved highlight refresh preserves native selection")
        try verifyPaperBoundary(text, paper: text, selection: selection, observed: observed,
            prepare: { coordinator.preparePaperTap(at: $0, in: text, touchedView: $1) },
            complete: { coordinator.completePaperTap(at: $0, in: text) })
        XCTAssertEqual(observed.positions, 0)
        text.selectedRange = selection
        let outside = CGPoint(x: text.bounds.midX, y: text.bounds.maxY - 40)
        XCTAssertTrue(coordinator.preparePaperTap(at: outside, in: text))
        coordinator.retire(text)
        let retiredSelection = text.selectedRange
        coordinator.completePaperTap(at: outside, in: text)
        XCTAssertEqual(text.selectedRange, retiredSelection, "A retired owner's late tap cannot change native selection")
        XCTAssertEqual(observed.centers, 1)
    }

    private func verifyPaged(_ body: ReaderChapterContent, selection: NSRange,
                             sourceStart: UInt64, sourceEnd: UInt64, marks: [ReaderHighlight],
                             expectedText: String? = nil, transition: ReaderPageTransition = .slide) async throws {
        let observed = Observation()
        let firstLayout = expectation(description: "real paged body layout")
        var firstReady = false
        var surface = ReaderPagedTextSurface(content: body, scalarOffset: 0, restorationID: UUID(),
            fontSize: 18, lineHeight: 1.96, horizontalInset: 20, bottomInset: 24, paper: .init(),
            positionChanged: { _ in observed.positions += 1 }, centerTapped: { observed.centers += 1 },
            selectionChanged: { observed.selections.append(($0, $1, $2)) },
            layoutReady: { if !firstReady { firstReady = true; firstLayout.fulfill() } },
            transition: transition)
        let coordinator = surface.makeCoordinator()
        let controller = ReaderPagedContainerController()
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let window = UIWindow(windowScene: scene)
        window.frame = scene.coordinateSpace.bounds
        window.rootViewController = controller; window.isHidden = false
        defer { coordinator.retire(); window.isHidden = true }
        // Establish the actual scene-sized host before Core-backed pagination
        // measures it. A page child's own bounds are not the tap owner's bounds.
        controller.loadViewIfNeeded(); controller.view.frame = window.bounds
        window.layoutIfNeeded(); controller.view.layoutIfNeeded()
        coordinator.mount(controller); coordinator.update(surface, in: controller)
        controller.view.layoutIfNeeded()
        await fulfillment(of: [firstLayout], timeout: 5)
        var text = try committedText(in: controller.view)
        text.selectedRange = selection; coordinator.textViewDidChangeSelection(text)
        XCTAssertEqual(observed.selections.last?.0, sourceStart); XCTAssertEqual(observed.selections.last?.1, sourceEnd)
        if let expectedText {
            try verifySelectedText(expectedText, in: text, observed: observed)
            try await verifyNativeCopyPaste(expectedText, from: text, in: window)
        }

        let highlightedLayout = expectation(description: "real saved highlight paged reflow")
        var highlightedReady = false
        surface.highlights = marks
        surface.layoutReady = { if !highlightedReady { highlightedReady = true; highlightedLayout.fulfill() } }
        coordinator.update(surface, in: controller)
        await fulfillment(of: [highlightedLayout], timeout: 5)
        text = try committedText(in: controller.view)
        XCTAssertEqual(text.selectedRange, selection, "The same-body saved highlight refresh preserves native selection")
        let bodyTap = try XCTUnwrap(controller.view.gestureRecognizers?.compactMap { $0 as? UITapGestureRecognizer }.first)
        try verifyPaperBoundary(text, paper: controller.view, selection: selection, observed: observed,
            prepare: { coordinator.preparePaperTap(at: $0, in: text, touchedView: $1) },
            complete: { coordinator.completePaperTap(at: $0, in: text) })
        XCTAssertEqual(observed.positions, 0, "Clearing selection and then opening controls must not turn the native page")
        XCTAssertTrue(try committedText(in: controller.view) === text, "The same committed page remains visible after the center tap")
        let nativePan: UIPanGestureRecognizer
        if transition == .cover {
            nativePan = try XCTUnwrap(controller.view.gestureRecognizers?.compactMap { $0 as? UIPanGestureRecognizer }
                .first { $0.delegate === coordinator })
            XCTAssertTrue(nativePan.isEnabled)
            XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(nativePan),
                          "The mounted Reader page pan is admitted after selection ends")
        } else {
            nativePan = UIPanGestureRecognizer()
        }
        text.selectedRange = selection
        XCTAssertFalse(coordinator.gestureRecognizerShouldBegin(nativePan), "A selected page still rejects Reader page pans")
        let outside = try paperCenter(in: text, paper: controller.view)
        XCTAssertTrue(coordinator.preparePaperTap(at: outside, in: text))
        XCTAssertTrue(coordinator.gestureRecognizerShouldBegin(bodyTap))
        coordinator.retire()
        let retiredSelection = text.selectedRange
        coordinator.completePaperTap(at: outside, in: text)
        XCTAssertEqual(text.selectedRange, retiredSelection, "A retired owner's late tap cannot change native selection")
        XCTAssertEqual(observed.centers, 1)
    }

    private func verifySelectedText(_ expected: String, in text: UITextView, observed: Observation) throws {
        text.layoutManager.ensureLayout(for: text.textContainer)
        let range = try XCTUnwrap(text.selectedTextRange)
        let start = text.caretRect(for: range.start)
        let end = text.caretRect(for: range.end)
        XCTAssertGreaterThan(end.midY, start.midY, "The native selection must span visible text lines")
        XCTAssertTrue(text.bounds.intersects(start) && text.bounds.intersects(end))
        XCTAssertEqual(text.text(in: range), expected)
        XCTAssertEqual(observed.selections.last?.2, expected)
    }

    private func verifyNativeCopyPaste(_ expected: String, from source: UITextView, in window: UIWindow) async throws {
        #if targetEnvironment(simulator)
        try XCTSkipUnless(ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"] ==
                          "Reader-iPhone-Daily-Closeout-20261123", "Clipboard use requires the dedicated iPhone simulator")
        let host = try XCTUnwrap(window.rootViewController?.view)
        let previousKeyWindow = window.windowScene?.windows.first(where: \.isKeyWindow)
        let selected = source.selectedRange
        let pasteboard = UIPasteboard.general
        let priorItems = pasteboard.items
        let receiver = UITextView(frame: CGRect(x: 12, y: 12, width: 200, height: 72))
        host.addSubview(receiver)
        window.makeKey()
        defer {
            receiver.resignFirstResponder()
            receiver.removeFromSuperview()
            source.resignFirstResponder()
            source.selectedRange = selected
            previousKeyWindow?.makeKey()
            pasteboard.items = priorItems
        }

        // Start with an unrelated value so a no-op copy cannot pass using
        // clipboard content from an earlier attempt.
        pasteboard.string = UUID().uuidString
        let beforeCopy = pasteboard.changeCount
        XCTAssertTrue(source.becomeFirstResponder())
        source.selectedRange = selected
        let application = UIApplication.shared
        XCTAssertTrue(application.sendAction(#selector(UIResponderStandardEditActions.copy(_:)),
                                             to: source, from: nil, for: nil))
        XCTAssertNotEqual(pasteboard.changeCount, beforeCopy, "The UIKit copy action must update the pasteboard")

        XCTAssertTrue(receiver.becomeFirstResponder())
        let pasted = expectation(for: NSPredicate { object, _ in
            (object as? UITextView)?.hasText == true
        }, evaluatedWith: receiver)
        XCTAssertTrue(application.sendAction(#selector(UIResponderStandardEditActions.paste(_:)),
                                             to: receiver, from: nil, for: nil))
        await fulfillment(of: [pasted], timeout: 5)
        XCTAssertTrue(receiver.text?.utf8.elementsEqual(expected.utf8) == true,
                      "UIKit paste must reproduce the exact selected paragraphs and newline")
        #else
        throw XCTSkip("Clipboard use requires the dedicated iPhone simulator")
        #endif
    }

    private func verifyPaperBoundary(_ text: UITextView, paper: UIView, selection: NSRange, observed: Observation,
                                     prepare: (CGPoint, UIView?) -> Bool, complete: (CGPoint) -> Void) throws {
        text.layoutManager.ensureLayout(for: text.textContainer)
        let range = try XCTUnwrap(text.selectedTextRange)
        let rect = try XCTUnwrap(text.selectionRects(for: range).first { !$0.rect.isEmpty }).rect
        let inside = CGPoint(x: rect.midX, y: rect.midY)
        XCTAssertTrue(text.bounds.contains(inside))
        XCTAssertFalse(prepare(inside, text)); complete(inside)
        XCTAssertEqual(text.selectedRange, selection); XCTAssertEqual(observed.centers, 0)
        let caret = text.caretRect(for: range.end)
        let handle = CGPoint(x: caret.midX + 12, y: caret.maxY + 10)
        XCTAssertTrue(text.bounds.contains(handle))
        XCTAssertFalse(prepare(handle, text)); complete(handle)
        XCTAssertEqual(text.selectedRange, selection)
        let outside = try paperCenter(in: text, paper: paper)
        let menuControl = UIButton(type: .system); text.addSubview(menuControl)
        XCTAssertFalse(prepare(outside, menuControl)); complete(outside)
        menuControl.removeFromSuperview()
        XCTAssertEqual(text.selectedRange, selection)
        let offset = text.contentOffset
        XCTAssertTrue(prepare(outside, text)); complete(outside)
        XCTAssertEqual(text.selectedRange.length, 0)
        XCTAssertEqual(observed.selections.last?.0, 0); XCTAssertEqual(observed.selections.last?.1, 0)
        XCTAssertEqual(observed.selections.last?.2, "")
        XCTAssertEqual(observed.centers, 0, "The first tap ends selection only")
        XCTAssertEqual(text.contentOffset, offset)
        XCTAssertNotNil(text.attributedText.attribute(.backgroundColor, at: selection.location, effectiveRange: nil),
                        "The Core annotation remains painted after native selection ends")
        let center = try paperCenter(in: text, paper: paper)
        XCTAssertTrue(prepare(center, text)); complete(center)
        XCTAssertEqual(observed.centers, 1, "The next ordinary center tap opens reading controls")
    }

    private func paperCenter(in text: UITextView, paper: UIView) throws -> CGPoint {
        paper.layoutIfNeeded(); text.layoutIfNeeded()
        let window = try XCTUnwrap(paper.window, "The tap owner must be mounted in a real UIWindow")
        let hostPoint = CGPoint(x: paper.bounds.midX, y: paper.bounds.maxY - 40)
        let point = paper.convert(hostPoint, to: text)
        let roundTrip = text.convert(point, to: paper)
        let windowPoint = paper.convert(hostPoint, to: window)
        let visibleText = text.convert(text.bounds, to: paper).intersection(paper.bounds)
        let sameWindow = text.window === window
        let geometry = "hostFrame=\(paper.frame) hostBounds=\(paper.bounds) textFrame=\(text.frame) textBounds=\(text.bounds) visibleText=\(visibleText) hostPoint=\(hostPoint) textPoint=\(point) roundTrip=\(roundTrip) windowPoint=\(windowPoint) windowBounds=\(window.bounds) sameWindow=\(sameWindow)"
        let attachment = XCTAttachment(string: geometry)
        attachment.name = "selection-paper-tap-actual-viewport"; attachment.lifetime = .keepAlways; add(attachment)
        guard sameWindow, paper.bounds.width > 0, paper.bounds.height > 80,
              text.bounds.contains(point), visibleText.contains(hostPoint), window.bounds.contains(windowPoint),
              abs(roundTrip.x - paper.bounds.midX) < 0.01,
              abs(roundTrip.y - hostPoint.y) < 0.01 else {
            XCTFail("A center paper tap must lie in the current live text viewport: \(geometry)")
            throw BoundaryError.invalidViewport
        }
        return point
    }

    private func committedText(in root: UIView) throws -> UITextView {
        func collect(_ view: UIView) -> [UITextView] {
            (view as? UITextView).map { [$0] } ?? view.subviews.flatMap(collect)
        }
        let current = collect(root).filter { $0.accessibilityIdentifier == "reading-body" && $0.isAccessibilityElement }
        XCTAssertEqual(current.count, 1)
        return try XCTUnwrap(current.first)
    }

    private final class Observation {
        var positions = 0
        var centers = 0
        var selections: [(UInt64, UInt64, String)] = []
    }
}

/// Platform font and layout-budget checks only; no book/Core fixture or claim
/// of whole-reader rendering, physical touch, or accessibility acceptance.
@MainActor
final class ReaderControlAccessibilityLayoutTests: XCTestCase {
    private let categories: [(DynamicTypeSize, UIContentSizeCategory)] = [
        (.xSmall, .extraSmall), (.small, .small), (.medium, .medium), (.large, .large),
        (.xLarge, .extraLarge), (.xxLarge, .extraExtraLarge), (.xxxLarge, .extraExtraExtraLarge),
        (.accessibility1, .accessibilityMedium), (.accessibility2, .accessibilityLarge),
        (.accessibility3, .accessibilityExtraLarge), (.accessibility4, .accessibilityExtraExtraLarge),
        (.accessibility5, .accessibilityExtraExtraExtraLarge)
    ]

    func testDefaultAndSmallerControlGeometryKeepsFrozenHostMetrics() {
        for (size, category) in categories.prefix(4) {
            let mapped = ReaderMetrics.controlContentCategory(for: size)
            XCTAssertEqual(mapped, category)
            let layout = ReaderMetrics.controlContent(category: mapped)
            XCTAssertFalse(layout.adaptsText, category.rawValue)
            XCTAssertEqual(layout.actionLabelHeight, 13)
            XCTAssertEqual(layout.actionHeight, 55.438, accuracy: 0.0001)
            XCTAssertEqual(layout.summaryHeight, 108.563, accuracy: 0.0001)
            XCTAssertEqual(layout.actionPanelHeight, 75.438, accuracy: 0.0001)
            XCTAssertEqual(layout.moduleLabelHeight, 15)
            XCTAssertEqual(layout.moduleButtonHeight, 62)
            XCTAssertEqual(layout.navigationHeight, 80)
            XCTAssertEqual(layout.headerHeight, 30)
            XCTAssertEqual(layout.contentTop(progress: 0), 29)
            XCTAssertEqual(layout.contentTop(progress: 1), 57)
            XCTAssertEqual(layout.quickViewportHeight(dockHeight: 330), 190)
            XCTAssertEqual(layout.quickViewportHeight(dockHeight: 252), 112)
            XCTAssertEqual(layout.fullViewportHeight(dockHeight: 736), 666)
            XCTAssertEqual(layout.quickDockHeight(baseline: 330, fullHeight: 736), 330)
            XCTAssertFalse(layout.needsIntegratedScroll(quickHeight: 330))
            XCTAssertFalse(layout.needsIntegratedScroll(quickHeight: 252))
        }
    }

    func testLargerControlBudgetsFitRegisteredNativeFontsForEveryContentSizeCategory() throws {
        ReaderFonts.registerBundledFonts()
        var observations: [[String: Any]] = []
        for (size, category) in categories.dropFirst(4) {
            let mapped = ReaderMetrics.controlContentCategory(for: size)
            XCTAssertEqual(mapped, category)
            let traits = UITraitCollection(preferredContentSizeCategory: category)
            let metrics = UIFontMetrics(forTextStyle: .body)
            let layout = ReaderMetrics.controlContent(category: mapped)
            XCTAssertTrue(layout.adaptsText, category.rawValue)
            XCTAssertGreaterThanOrEqual(layout.moduleMinimumWidth, ReaderMetrics.minimumHitSize)
            let labels: [(ReaderTypeface, CGFloat, CGFloat, CGFloat)] = [
                (.inter, 11, 800, layout.actionLabelHeight), (.uiBold, 10, 700, layout.moduleLabelHeight),
                (.inter, 13, 700, layout.chapterTitleHeight), (.inter, 9, 400, layout.progressLabelHeight),
                (.uiBold, 14, 700, layout.headerLabelHeight), (.uiBold, 10, 700, layout.collapseLabelHeight)
            ]
            for (face, size, weight, budget) in labels {
                let registered = ReaderFonts.uiFont(face, size: size, weight: weight)
                let native = metrics.scaledFont(for: registered, compatibleWith: traits)
                let cjk = metrics.scaledFont(for: ReaderFonts.uiFont(.ui, size: size), compatibleWith: traits)
                XCTAssertEqual(native.familyName, registered.familyName)
                XCTAssertGreaterThan(native.pointSize, registered.pointSize)
                XCTAssertGreaterThanOrEqual(budget, native.lineHeight, "\(category.rawValue): \(native.fontName)")
                XCTAssertGreaterThanOrEqual(budget, cjk.lineHeight, "\(category.rawValue): registered CJK fallback budget")
                observations.append(["category": category.rawValue, "swiftUIDynamicType": String(describing: size),
                    "font": native.fontName, "pointSize": native.pointSize,
                    "nativeLineHeight": native.lineHeight, "cjkLineHeight": cjk.lineHeight, "budget": budget])
            }
        }
        let evidence = XCTAttachment(data: try JSONSerialization.data(withJSONObject: observations, options: [.sortedKeys]),
            uniformTypeIdentifier: "public.json")
        evidence.name = "control-dynamic-type-registered-font-line-heights"; evidence.lifetime = .keepAlways; add(evidence)
    }

    func testShortControlViewportUsesOneScrollableBudgetIncludingNavigation() {
        for (size, category) in categories {
            let mapped = ReaderMetrics.controlContentCategory(for: size)
            XCTAssertEqual(mapped, category)
            let layout = ReaderMetrics.controlContent(category: mapped)
            for height in [CGFloat(80), 120, 160] {
                let quick = layout.quickDockHeight(baseline: 252, fullHeight: height)
                XCTAssertEqual(quick, height)
                XCTAssertTrue(layout.needsIntegratedScroll(quickHeight: quick), category.rawValue)
                for hasHeader in [false, true] {
                    let viewport = layout.integratedViewportHeight(dockHeight: height, hasHeader: hasHeader)
                    XCTAssertGreaterThan(viewport, 0)
                    XCTAssertLessThanOrEqual(layout.integratedTop(hasHeader: hasHeader) + viewport, height)
                    XCTAssertEqual(layout.integratedTop(hasHeader: hasHeader) + viewport + layout.bottomGap, height)
                }
                XCTAssertGreaterThan(layout.quickNaturalHeight + layout.navigationGap + layout.navigationHeight,
                                     layout.integratedViewportHeight(dockHeight: height, hasHeader: false),
                                     "The navigation belongs inside the same scroll when its natural contents cannot fit")
            }
        }
    }
}
