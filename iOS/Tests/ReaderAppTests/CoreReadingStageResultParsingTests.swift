import XCTest
import ReaderCoreFoundation
import ReaderCoreModels
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

final class CoreReadingStageResultParsingTests: XCTestCase {
    func testRealCoreReaderLocationResolveReturnsCanonicalLocation() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let service = RustCoreReaderLocationService(runtime: runtime, requestTimeout: 5)

        let result = try await service.resolveStage(
            CoreReaderLocationStageRequest(
                sourceID: "source-location-proof",
                bookID: "book-location-proof",
                chapterIndex: 2,
                chapterTitle: "Chapter 3",
                chapterOffset: 128,
                chapterProgress: 0.5,
                layout: CoreReaderLocationLayout(
                    viewportWidth: 390,
                    viewportHeight: 844,
                    fontScale: 1,
                    pageIndex: 3,
                    pageCount: 12
                )
            ),
            correlationID: "location-binary-proof"
        )

        XCTAssertEqual(result.bookID, "book-location-proof")
        XCTAssertEqual(result.chapterIndex, 2)
        XCTAssertEqual(result.chapterOffset, 128)
        XCTAssertEqual(result.chapterProgress, 0.5)
        XCTAssertEqual(result.locationRevision, "reader-location-v1:book-location-proof:2:128")
        XCTAssertEqual(result.resolverVersion, "reader.location.resolve.v1.reflow")
        XCTAssertEqual(result.primaryAnchor, "chapterOffset")
        XCTAssertEqual(result.fallbackAnchor, "chapterProgress")
        XCTAssertTrue(result.layoutIndependent)
    }

    func testBookDetailStagePreservesRootTocURLAndVariables() {
        let fallback = SearchResultItem(
            title: "Fallback",
            detailURL: "https://example.test/book/1",
            unknownFields: ["existing": .string("kept")]
        )

        let result = RustCoreBookDetailService.parseBookDetailStage(
            [
                "sourceId": "source-core-1",
                "book": [
                    "bookId": "core-book-1",
                    "title": "Core Book",
                    "author": "Core Author",
                ],
                "tocUrl": "https://example.test/book/1/toc",
                "variables": ["token": "abc", "bookKey": "bk-1"],
            ],
            fallback: fallback
        )

        XCTAssertEqual(result.book.title, "Core Book")
        XCTAssertEqual(result.sourceID, "source-core-1")
        XCTAssertEqual(result.bookID, "core-book-1")
        XCTAssertEqual(result.book.detailURL, fallback.detailURL)
        XCTAssertEqual(result.tocURL, "https://example.test/book/1/toc")
        XCTAssertEqual(result.variables, ["token": "abc", "bookKey": "bk-1"])
        XCTAssertEqual(result.book.unknownFields["existing"], .string("kept"))
        XCTAssertEqual(result.book.unknownFields["sourceId"], .string("source-core-1"))
        XCTAssertEqual(result.book.unknownFields["bookId"], .string("core-book-1"))
        XCTAssertEqual(result.book.unknownFields["tocUrl"], .string("https://example.test/book/1/toc"))
        XCTAssertEqual(
            result.book.unknownFields["variables"],
            .object(["token": .string("abc"), "bookKey": .string("bk-1")])
        )
    }

    func testTOCStagePreservesRootIdentityAndPerEntryVariables() throws {
        let result = RustCoreTOCService.parseTOCStage([
            "sourceId": "source-1",
            "bookId": "book-1",
            "toc": [
                [
                    "index": 7,
                    "title": "第八章",
                    "url": "https://example.test/chapter/8",
                    "variables": ["chapterKey": "c-8"],
                ],
            ],
        ])

        XCTAssertEqual(result.sourceID, "source-1")
        XCTAssertEqual(result.bookID, "book-1")
        XCTAssertEqual(result.entries.count, 1)
        XCTAssertEqual(result.entries[0].item.chapterTitle, "第八章")
        XCTAssertEqual(result.entries[0].item.chapterURL, "https://example.test/chapter/8")
        XCTAssertEqual(result.entries[0].item.chapterIndex, 7)
        XCTAssertEqual(result.entries[0].variables, ["chapterKey": "c-8"])
        XCTAssertEqual(
            result.entries[0].item.unknownFields["variables"],
            .object(["chapterKey": .string("c-8")])
        )

        let contentContext = try XCTUnwrap(result.contentRequestContext(
            for: result.entries[0],
            detailVariables: ["token": "detail", "chapterKey": "detail-value"]
        ))
        XCTAssertEqual(contentContext.bookID, "book-1")
        XCTAssertEqual(contentContext.chapterTitle, "第八章")
        XCTAssertEqual(contentContext.chapterIndex, 7)
        XCTAssertEqual(contentContext.chapterURL, "https://example.test/chapter/8")
        XCTAssertEqual(contentContext.variables, ["token": "detail", "chapterKey": "c-8"])
    }

    func testTOCRequestForwardsDetailURLAndVariables() {
        let params = RustCoreTOCService.makeTOCParams(
            sourceID: "source-1",
            bookID: "book-1",
            tocURL: "https://example.test/toc",
            variables: ["token": "abc"],
            inlineSource: ["sourceId": "source-1"]
        )

        XCTAssertEqual(params["sourceId"] as? String, "source-1")
        XCTAssertEqual(params["bookId"] as? String, "book-1")
        XCTAssertEqual(params["tocUrl"] as? String, "https://example.test/toc")
        XCTAssertEqual(params["variables"] as? [String: String], ["token": "abc"])
        XCTAssertEqual(
            (params["tocRequest"] as? [String: Any])?["url"] as? String,
            "https://example.test/toc"
        )
    }

    func testPersistedSourceDetailRequestUsesCoreBookIDAndDoesNotFabricateInlineSource() {
        let params = RustCoreBookDetailService.makeDetailParams(
            sourceID: "core-source-1",
            bookID: "core-book-1",
            bookURL: "https://example.test/book/1",
            title: "Book",
            author: "Author",
            inlineSource: nil
        )

        XCTAssertEqual(params["sourceId"] as? String, "core-source-1")
        XCTAssertEqual(params["bookUrl"] as? String, "https://example.test/book/1")
        XCTAssertEqual((params["book"] as? [String: Any])?["bookId"] as? String, "core-book-1")
        XCTAssertNil((params["book"] as? [String: Any])?["bookUrl"])
        XCTAssertNil(params["source"], "book.open Pilot must use Core's persisted source lookup, not fabricate BookSource")
    }

    func testPersistedSourceTOCAndContentRequestsKeepInlineSourceAbsent() {
        let toc = RustCoreTOCService.makeTOCParams(
            sourceID: "core-source-1",
            bookID: "core-book-1",
            tocURL: "https://example.test/book/1/toc",
            variables: [:],
            inlineSource: nil
        )
        let content = RustCoreContentService.makeContentParams(
            sourceID: "core-source-1",
            context: CoreChapterContentRequestContext(
                bookID: "core-book-1",
                chapterTitle: "第一章",
                chapterIndex: 0,
                chapterURL: "https://example.test/book/1/chapter/1"
            ),
            inlineSource: nil
        )

        XCTAssertNil(toc["source"])
        XCTAssertNil(content["source"])
        XCTAssertEqual(toc["bookId"] as? String, "core-book-1")
        XCTAssertEqual(content["chapterIndex"] as? Int, 0)
    }

    func testContentStagePreservesSelectedChapterIdentityAndVariables() {
        let context = CoreChapterContentRequestContext(
            bookID: "book-1",
            chapterTitle: "第八章",
            chapterIndex: 7,
            chapterURL: "https://example.test/chapter/8",
            variables: ["token": "abc", "chapterKey": "c-8"]
        )

        let result = RustCoreContentService.parseContentStage(
            [
                "sourceId": "core-source-1",
                "bookId": "core-book-1",
                "chapterTitle": "第八章（Core）",
                "content": "真实正文",
            ],
            sourceID: "bridge-source-1",
            context: context
        )

        XCTAssertEqual(result.sourceID, "core-source-1")
        XCTAssertEqual(result.bookID, "core-book-1")
        XCTAssertEqual(result.chapterTitle, "第八章（Core）")
        XCTAssertEqual(result.chapterIndex, 7)
        XCTAssertEqual(result.chapterURL, "https://example.test/chapter/8")
        XCTAssertEqual(result.variables, ["token": "abc", "chapterKey": "c-8"])
        XCTAssertEqual(result.page.title, "第八章（Core）")
        XCTAssertEqual(result.page.content, "真实正文")
        XCTAssertEqual(result.page.chapterURL, "https://example.test/chapter/8")
        XCTAssertEqual(result.page.unknownFields["sourceId"], .string("core-source-1"))
        XCTAssertEqual(result.page.unknownFields["bookId"], .string("core-book-1"))
        XCTAssertEqual(result.page.unknownFields["chapterIndex"], .number(7))
        XCTAssertEqual(result.rawContent, .string("真实正文"))
    }

    func testContentRequestUsesSelectedChapterContextInsteadOfURLAsBookID() {
        let context = CoreChapterContentRequestContext(
            bookID: "book-1",
            chapterTitle: "第八章",
            chapterIndex: 7,
            chapterURL: "https://example.test/chapter/8",
            variables: ["chapterKey": "c-8"]
        )

        let params = RustCoreContentService.makeContentParams(
            sourceID: "source-1",
            context: context,
            inlineSource: ["sourceId": "source-1"]
        )

        XCTAssertEqual(params["bookId"] as? String, "book-1")
        XCTAssertEqual(params["chapterTitle"] as? String, "第八章")
        XCTAssertEqual(params["chapterIndex"] as? Int, 7)
        XCTAssertEqual(params["chapterUrl"] as? String, "https://example.test/chapter/8")
        XCTAssertEqual(params["variables"] as? [String: String], ["chapterKey": "c-8"])
        XCTAssertNil(params["contentRequest"], "Core accepts chapterRequest; the old alias lost contract fidelity")
        XCTAssertEqual(
            (params["chapterRequest"] as? [String: Any])?["url"] as? String,
            "https://example.test/chapter/8"
        )
    }
}
