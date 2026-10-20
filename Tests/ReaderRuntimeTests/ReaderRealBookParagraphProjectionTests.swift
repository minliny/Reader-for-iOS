import CryptoKit
import Foundation
import UIKit
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

@MainActor
final class ReaderRealBookParagraphProjectionTests: XCTestCase {
    func testRealDownloadsBookParagraphGeometryAndCoreCoordinatesSurviveReopen() async throws {
        // The native journey provisions this exact user-owned Downloads file
        // into the dedicated simulator. Never generate substitute book text.
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let originalURL = documents.appendingPathComponent("仙子请听我解释.txt")
        let original = try Data(contentsOf: originalURL)
        XCTAssertEqual(original.count, 8_871_723)
        let digest = SHA256.hash(data: original).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(digest, "aac01dbeb5e10710ee802466f077889f5b83d27db70a69e68a33af9ac51658a5")

        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealParagraph-" + UUID().uuidString,
                                                                                isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let coreURL = root.appendingPathComponent("Core", isDirectory: true)
        let sourcesURL = root.appendingPathComponent("Sources", isDirectory: true)
        let library = try ReaderLibraryService(storageURL: coreURL, sourceURL: sourcesURL)
        var reopened: ReaderLibraryService?
        do {
            let imported = try await library.importBook(at: originalURL)
            XCTAssertEqual(imported.book.bookId, "local:" + digest)
            let chapters = try await library.chapters(for: imported.book)
            let introChapter = try XCTUnwrap(chapters.first)
            let firstChapter = try XCTUnwrap(chapters.first { $0.title.hasPrefix("第一章") })
            XCTAssertEqual(introChapter.title, "序章")
            let intro = try await library.content(for: imported.book, chapterIndex: introChapter.index)
            let first = try await library.content(for: imported.book, chapterIndex: firstChapter.index)
            let introProjection = ReaderParagraphProjection(content: intro.content)
            let firstProjection = ReaderParagraphProjection(content: first.content)
            XCTAssertEqual(intro.scalarCount, 18)
            XCTAssertEqual(introProjection.text, "正文卷\n------------")
            XCTAssertEqual(introProjection.paragraphs.count, 2)
            XCTAssertGreaterThan(firstProjection.paragraphs.count, 20)
            XCTAssertTrue(firstProjection.text.contains("“终于全成就通关了。”"))
            assertRetainedCoordinates(introProjection, content: intro.content)
            assertRetainedCoordinates(firstProjection, content: first.content)
            try assertFrozenIntroGeometry(introProjection)

            // An old canonical position may lie in a now-hidden empty line.
            // Its exact scalar must survive the display round trip and Core reopen.
            let firstParagraph = try XCTUnwrap(introProjection.paragraphs.first)
            let nextParagraph = try XCTUnwrap(introProjection.paragraphs.dropFirst().first)
            let hiddenOffset = firstParagraph.sourceScalarRange.upperBound + 1
            XCTAssertLessThan(hiddenOffset, nextParagraph.sourceScalarRange.lowerBound)
            let anchor = introProjection.anchor(forSourceScalar: hiddenOffset)
            XCTAssertEqual(anchor.displayUTF16Offset, nextParagraph.displayUTF16Range.location)
            XCTAssertEqual(introProjection.sourceScalarOffset(forDisplayUTF16: anchor.displayUTF16Offset),
                           nextParagraph.sourceScalarRange.lowerBound)
            XCTAssertEqual(introProjection.sourceScalarOffset(forDisplayUTF16: anchor.displayUTF16Offset, preserving: anchor),
                           hiddenOffset)
            let initial = try await library.progress(for: imported.book)
            _ = try await library.saveProgress(for: imported.book, content: intro, scalarOffset: hiddenOffset,
                                               expectedRevision: initial.progressRevision)
            try await library.close()
            let restoredLibrary = try ReaderLibraryService(storageURL: coreURL, sourceURL: sourcesURL)
            reopened = restoredLibrary
            let restoredBody = try await restoredLibrary.content(for: imported.book, chapterIndex: introChapter.index)
            let restoredProgress = try await restoredLibrary.progress(for: imported.book)
            XCTAssertEqual(restoredBody, intro)
            XCTAssertEqual(restoredProgress.progress?.chapterOffset, hiddenOffset)
            let restoredProjection = ReaderParagraphProjection(content: restoredBody.content)
            let restoredAnchor = restoredProjection.anchor(forSourceScalar: try XCTUnwrap(restoredProgress.progress).chapterOffset)
            XCTAssertEqual(restoredProjection.sourceScalarOffset(forDisplayUTF16: restoredAnchor.displayUTF16Offset,
                                                                  preserving: restoredAnchor), hiddenOffset)
            try await restoredLibrary.close()
        } catch {
            try? await library.close()
            if let reopened { try? await reopened.close() }
            throw error
        }
        // The test only reads the provisioned source and owns its temporary Core.
        XCTAssertEqual(try Data(contentsOf: originalURL), original)
    }

    private func assertRetainedCoordinates(_ projection: ReaderParagraphProjection, content: String,
                                           file: StaticString = #filePath, line: UInt = #line) {
        let originalLines = content.components(separatedBy: .newlines)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        // Compare untrimmed lines, including any leading spaces supplied by Core.
        XCTAssertEqual(projection.paragraphs.map(\.text), originalLines, file: file, line: line)
        XCTAssertEqual(projection.text.components(separatedBy: "\n"), originalLines, file: file, line: line)
        for paragraph in projection.paragraphs {
            XCTAssertEqual((content as NSString).substring(with: paragraph.sourceUTF16Range), paragraph.text,
                           file: file, line: line)
            for scalar in paragraph.sourceScalarRange.lowerBound...paragraph.sourceScalarRange.upperBound {
                let displayed = projection.displayUTF16Offset(forSourceScalar: scalar)
                XCTAssertEqual(projection.sourceScalarOffset(forDisplayUTF16: displayed), scalar, file: file, line: line)
            }
        }
        // Hidden boundaries are intentionally many-to-one; their restoration
        // anchors, including leading/trailing separators, retain every scalar.
        for scalar in UInt64(0)...projection.sourceScalarCount {
            let anchor = projection.anchor(forSourceScalar: scalar)
            XCTAssertEqual(projection.sourceScalarOffset(forDisplayUTF16: anchor.displayUTF16Offset, preserving: anchor),
                           scalar, file: file, line: line)
        }
    }

    private func assertFrozenIntroGeometry(_ projection: ReaderParagraphProjection) throws {
        let body = projection.attributedBody(fontSize: 18, lineHeight: 1.96, ink: .black)
        let first = try XCTUnwrap(projection.paragraphs.first)
        let second = try XCTUnwrap(projection.paragraphs.dropFirst().first)
        let firstStyle = try XCTUnwrap(body.attribute(.paragraphStyle, at: first.displayUTF16Range.location,
                                                     effectiveRange: nil) as? NSParagraphStyle)
        let secondStyle = try XCTUnwrap(body.attribute(.paragraphStyle, at: second.displayUTF16Range.location,
                                                      effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(firstStyle.paragraphSpacing, 16)
        XCTAssertEqual(secondStyle.paragraphSpacing, 0)
        XCTAssertEqual(firstStyle.firstLineHeadIndent, 0)
        let storage = NSTextStorage(attributedString: body)
        let manager = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: 352, height: CGFloat.greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        manager.addTextContainer(container)
        storage.addLayoutManager(manager)
        manager.ensureLayout(for: container)
        func top(_ paragraph: ReaderParagraphProjection.Paragraph) -> CGFloat {
            let glyphs = manager.glyphRange(forCharacterRange: NSRange(location: paragraph.displayUTF16Range.location, length: 1),
                                            actualCharacterRange: nil)
            return manager.boundingRect(forGlyphRange: glyphs, in: container).minY
        }
        // Host: one 35.28pt body line plus exactly one 16pt paragraph gap.
        XCTAssertEqual(top(second) - top(first), 51.28, accuracy: 0.1)
    }
}
