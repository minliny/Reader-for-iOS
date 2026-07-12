import XCTest
import ReaderCoreFoundation
@testable import ReaderShellValidation

final class BookOpenStageParserTests: XCTestCase {
    func testLocalBookTOCAndContentRemainTypedAndMaterialized() {
        let toc = RustCoreLocalBookService.parseTOCStage([
            "sourceId": "local",
            "bookId": "local-book-1",
            "toc": [[
                "index": 4,
                "title": "第五章",
                "url": "local://local-book-1/chapter/4",
            ]],
        ])

        XCTAssertEqual(toc.sourceID, "local")
        XCTAssertEqual(toc.bookID, "local-book-1")
        XCTAssertEqual(toc.entries.map(\.item.chapterIndex), [4])
        XCTAssertEqual(toc.entries.map(\.item.chapterURL), ["local://local-book-1/chapter/4"])

        let context = CoreChapterContentRequestContext(
            bookID: "local-book-1",
            chapterTitle: "第五章",
            chapterIndex: 4,
            chapterURL: "local://local-book-1/chapter/4"
        )
        let content = RustCoreLocalBookService.parseContentStage([
            "sourceId": "local",
            "bookId": "local-book-1",
            "chapterIndex": 4,
            "chapterTitle": "第五章",
            "content": "本地正文",
        ], context: context)

        XCTAssertEqual(content.sourceID, "local")
        XCTAssertEqual(content.bookID, "local-book-1")
        XCTAssertEqual(content.chapterIndex, 4)
        XCTAssertEqual(content.page.content, "本地正文")
        XCTAssertEqual(content.page.chapterURL, "local://local-book-1/chapter/4")
    }

    func testLocationResultRequiresCanonicalResolvedPayloadAndPreservesReflow() throws {
        let result = try RustCoreReaderLocationService.parseResult(validLocationPayload())

        XCTAssertEqual(result.bookID, "book-1")
        XCTAssertEqual(result.chapterIndex, 2)
        XCTAssertEqual(result.chapterOffset, 128)
        XCTAssertEqual(result.chapterProgress, 0.5)
        XCTAssertEqual(result.primaryAnchor, "chapterOffset")
        XCTAssertEqual(result.fallbackAnchor, "chapterProgress")
        XCTAssertTrue(result.layoutIndependent)
    }

    func testLocationResultFailsClosedForMissingOrInvalidCanonicalFields() {
        var missingChapterIndex = validLocationPayload()
        var canonical = missingChapterIndex["canonicalLocation"] as! [String: Any]
        canonical.removeValue(forKey: "chapterIndex")
        missingChapterIndex["canonicalLocation"] = canonical

        var fractionalOffset = validLocationPayload()
        canonical = fractionalOffset["canonicalLocation"] as! [String: Any]
        canonical["chapterOffset"] = 1.5
        fractionalOffset["canonicalLocation"] = canonical

        var invalidProgress = validLocationPayload()
        canonical = invalidProgress["canonicalLocation"] as! [String: Any]
        canonical["chapterProgress"] = 1.01
        invalidProgress["canonicalLocation"] = canonical

        var missingRevision = validLocationPayload()
        canonical = missingRevision["canonicalLocation"] as! [String: Any]
        canonical.removeValue(forKey: "locationRevision")
        missingRevision["canonicalLocation"] = canonical

        var missingResolverVersion = validLocationPayload()
        missingResolverVersion.removeValue(forKey: "resolverVersion")

        var missingFallbackAnchor = validLocationPayload()
        var reflow = missingFallbackAnchor["reflow"] as! [String: Any]
        reflow.removeValue(forKey: "fallbackAnchor")
        missingFallbackAnchor["reflow"] = reflow

        var blankPrimaryAnchor = validLocationPayload()
        reflow = blankPrimaryAnchor["reflow"] as! [String: Any]
        reflow["primaryAnchor"] = "  "
        blankPrimaryAnchor["reflow"] = reflow

        var numericLayoutIndependent = validLocationPayload()
        reflow = numericLayoutIndependent["reflow"] as! [String: Any]
        reflow["layoutIndependent"] = 1
        numericLayoutIndependent["reflow"] = reflow

        var missingLayoutIndependent = validLocationPayload()
        reflow = missingLayoutIndependent["reflow"] as! [String: Any]
        reflow.removeValue(forKey: "layoutIndependent")
        missingLayoutIndependent["reflow"] = reflow

        var unresolved = validLocationPayload()
        unresolved["resolved"] = false

        let invalidPayloads: [(String, [String: Any])] = [
            ("missing chapterIndex", missingChapterIndex),
            ("fractional chapterOffset", fractionalOffset),
            ("out-of-range chapterProgress", invalidProgress),
            ("missing locationRevision", missingRevision),
            ("missing resolverVersion", missingResolverVersion),
            ("missing fallbackAnchor", missingFallbackAnchor),
            ("blank primaryAnchor", blankPrimaryAnchor),
            ("numeric layoutIndependent", numericLayoutIndependent),
            ("missing layoutIndependent", missingLayoutIndependent),
            ("resolved false", unresolved),
        ]
        for (label, payload) in invalidPayloads {
            XCTAssertThrowsError(
                try RustCoreReaderLocationService.parseResult(payload),
                "\(label) must not acquire a default canonical value"
            )
        }
    }

    func testLocationLayoutRequestUsesPositiveMeasuredGeometry() {
        let request = CoreReaderLocationStageRequest(
            sourceID: "source-1",
            bookID: "book-1",
            chapterIndex: 2,
            chapterTitle: "第三章",
            chapterOffset: 128,
            chapterProgress: 0.5,
            layout: CoreReaderLocationLayout(
                viewportWidth: 390,
                viewportHeight: 844,
                fontScale: 1.25
            )
        )
        let params = RustCoreReaderLocationService.layoutParams(request.layout)
        XCTAssertEqual(params["viewportWidth"] as? Int, 390)
        XCTAssertEqual(params["viewportHeight"] as? Int, 844)
        XCTAssertEqual(params["fontScale"] as? Double, 1.25)
    }

    private func validLocationPayload() -> [String: Any] {
        [
            "canonicalLocation": [
                "bookId": "book-1",
                "chapterIndex": 2,
                "chapterOffset": 128,
                "chapterProgress": 0.5,
                "locationRevision": "reader-location-v1:book-1:2:128",
            ],
            "resolverVersion": "reader.location.resolve.v1.reflow",
            "resolved": true,
            "reflow": [
                "primaryAnchor": "chapterOffset",
                "fallbackAnchor": "chapterProgress",
                "layoutIndependent": true,
            ],
        ]
    }
}
