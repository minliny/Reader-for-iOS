import XCTest
import UIKit
@testable import Reader

/// Small native attribute/coordinate contracts only. These fixtures are not
/// books, downloaded resources or evidence of a real source's image display.
final class ReaderChapterImageProjectionTests: XCTestCase {
    @MainActor
    func testAttachmentKeepsOriginalScalarUTF16AndSelectionCoordinates() throws {
        let original = "🙂e\u{301}\n\n\u{FFFC}\n\n尾"
        let image = ReaderContentBlock(kind: "image", source: "https://fixture.invalid/original-image",
            startScalar: 5, endScalar: 6, imageWidthBasisPoints: 5_000,
            imageIntrinsicWidth: 200, imageIntrinsicHeight: 100)
        let content = ReaderChapterContent(sourceId: "attribute-fixture", bookId: "coordinates", chapterIndex: 3,
            chapterTitle: "", content: original, bodyVersion: "body", processingVersion: "processing", blocks: [
                image, image,
                .init(kind: "image", source: image.source, startScalar: 1, endScalar: 2),
                .init(kind: "image", source: image.source, startScalar: 5, endScalar: 7),
                .init(kind: "image", source: image.source, startScalar: .max, endScalar: 0)
            ])
        let projection = ReaderParagraphProjection(content: original)
        let baseline = projection.attributedBody(fontSize: 20, lineHeight: 2, ink: .black)
        var assets = ReaderChapterImageAssets(identity: ReaderChapterImageIdentity(content), loading: false)
        assets.images[try XCTUnwrap(image.source)] = .budgetExceeded
        let attributed = projection.attributedBody(fontSize: 20, lineHeight: 2, ink: .black,
            firstLineIndentEm: 2, imageAssets: assets, chapter: content,
            imageViewport: CGSize(width: 300, height: 190))
        XCTAssertEqual(content.content, original)
        XCTAssertEqual(attributed.string, baseline.string)
        XCTAssertEqual(attributed.length, baseline.length)
        XCTAssertEqual(Array(attributed.string.unicodeScalars), Array(baseline.string.unicodeScalars))
        let location = projection.displayUTF16Offset(forSourceScalar: 5)
        let attachment = try XCTUnwrap(attributed.attribute(.attachment, at: location, effectiveRange: nil) as? NSTextAttachment)
        XCTAssertEqual((attributed.string as NSString).character(at: location), 0xFFFC)
        XCTAssertEqual(attachment.bounds.size, CGSize(width: 150, height: 75))
        var count = 0
        attributed.enumerateAttribute(.attachment, in: NSRange(location: 0, length: attributed.length)) { value, range, _ in
            if value != nil { count += 1; XCTAssertEqual(range, NSRange(location: location, length: 1)) }
        }
        XCTAssertEqual(count, 1)
        for offset in [UInt64(0), 1, 2, 3, 5, 6, 8, 9] {
            let before = projection.displayUTF16Offset(forSourceScalar: offset)
            XCTAssertEqual(projection.sourceScalarOffset(forDisplayUTF16: before,
                preserving: projection.anchor(forSourceScalar: offset)), offset)
        }
        let end = projection.displayUTF16Offset(forSourceScalar: 6)
        XCTAssertEqual((attributed.string as NSString).substring(with: NSRange(location: location, length: end - location)), "\u{FFFC}")
        let style = try XCTUnwrap(attributed.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle)
        XCTAssertEqual(style.maximumLineHeight, 0)
        XCTAssertEqual(style.firstLineHeadIndent, 0)
        XCTAssertTrue(ReaderChapterImageAssets.accessibilityText(attributed).contains("插图超出当前资源预算"))
        XCTAssertFalse(ReaderChapterImageAssets.accessibilityText(attributed).contains("\u{FFFC}"))
    }

    @MainActor
    func testOldChapterAssetsCannotSettleOrSupplyNewChapterAttachments() {
        let block = ReaderContentBlock(kind: "image", source: "https://fixture.invalid/original-image", startScalar: 0, endScalar: 1)
        let old = ReaderChapterContent(sourceId: "attribute-fixture", bookId: "coordinates", chapterIndex: 0,
            chapterTitle: "", content: "\u{FFFC}", bodyVersion: "old", processingVersion: "processing", blocks: [block])
        let current = ReaderChapterContent(sourceId: old.sourceId, bookId: old.bookId, chapterIndex: old.chapterIndex,
            chapterTitle: "", content: old.content, bodyVersion: "current", processingVersion: old.processingVersion, blocks: [block])
        var assets = ReaderChapterImageAssets(identity: ReaderChapterImageIdentity(old), loading: false)
        assets.images[block.source!] = .failed
        XCTAssertTrue(assets.settled(for: old))
        XCTAssertFalse(assets.settled(for: current))
        let projection = ReaderParagraphProjection(content: current.content)
        let attributed = projection.attributedBody(fontSize: 20, lineHeight: 2, ink: .black,
            imageAssets: assets, chapter: current, imageViewport: CGSize(width: 200, height: 200))
        XCTAssertEqual(attributed.string, current.content)
        XCTAssertNotNil(attributed.attribute(.attachment, at: 0, effectiveRange: nil))
        XCTAssertEqual(ReaderChapterImageAssets.accessibilityText(attributed), "插图加载中")
    }
}
