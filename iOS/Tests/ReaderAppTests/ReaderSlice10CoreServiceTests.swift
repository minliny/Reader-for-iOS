import XCTest
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

final class ReaderSlice10CoreServiceTests: XCTestCase {
    func testReadingDataSearchAndCandidateCommandsUseExactCoreMethods() async throws {
        let runtime = FakeSlice10CommandRuntime { method in
            switch method {
            case "bookmark.create":
                return ["bookmark": Self.bookmarkObject()]
            case "read-record.create":
                return ["record": ["deviceId": "device-1", "bookName": "Book", "readTime": 12, "lastRead": 34]]
            case "search.history.list":
                return ["keywords": ["alpha", "beta"]]
            case "search.content":
                return ["results": [[
                    "sourceId": "source-1", "bookId": "book-1", "bookName": "Book",
                    "chapterIndex": 2, "chapterOffset": 41, "matchLength": 5,
                    "snippetStart": 35, "chapterTitle": "Chapter 3", "snippet": "...alpha...",
                ]]]
            case "change.bookSource":
                return ["candidates": [[
                    "sourceId": "source-2", "bookUrl": "https://books.example/book-2",
                    "bookName": "Book", "author": "Author", "coverUrl": "https://img.example/cover.jpg",
                ]]]
            default:
                XCTFail("unexpected method \(method)")
                return [:]
            }
        }
        let service = ReaderSlice10CoreService(runtime: runtime, requestTimeout: 1)

        let bookmark = try await service.createBookmark(
            .init(bookName: "Book", bookAuthor: "Author", chapterIndex: 2, chapterPosition: 41, chapterName: "Chapter 3"),
            correlationID: "bookmark"
        )
        let record = try await service.upsertReadRecord(
            deviceID: "device-1", bookName: "Book", readTime: 12, lastRead: 34, correlationID: "record"
        )
        let history = try await service.listSearchHistory(limit: 8, correlationID: "history")
        let matches = try await service.searchCachedContent(
            keyword: "alpha", sourceID: "source-1", bookID: "book-1", maximumResults: 20, correlationID: "content"
        )
        let candidates = try await service.discoverSourceSwitchCandidates(
            bookID: "book-1", keyword: "Book", sourceIDs: ["source-2"], correlationID: "source"
        )

        XCTAssertEqual(runtime.methods, [
            "bookmark.create", "read-record.create", "search.history.list", "search.content", "change.bookSource",
        ])
        XCTAssertEqual(bookmark.chapterPosition, 41)
        XCTAssertEqual(record.readTime, 12)
        XCTAssertEqual(history, ["alpha", "beta"])
        XCTAssertEqual(matches.first?.chapterOffset, 41)
        XCTAssertEqual(candidates.first?.sourceID, "source-2")

        let historyParams = try XCTUnwrap(runtime.command(method: "search.history.list")?["params"] as? [String: Any])
        XCTAssertEqual(historyParams["limit"] as? Int, 8)
        let contentParams = try XCTUnwrap(runtime.command(method: "search.content")?["params"] as? [String: Any])
        XCTAssertEqual(contentParams["maxResults"] as? Int, 20)
        XCTAssertEqual(contentParams["sourceId"] as? String, "source-1")
    }

    func testRuntimeOnlyEditsAndTypedRuleCRUDPreserveCoreOwnedShapes() async throws {
        let runtime = FakeSlice10CommandRuntime { method in
            switch method {
            case "content-edit.put":
                return ["edit": [
                    "editId": 7, "bookId": "book-1", "chapterIndex": 3,
                    "editedContent": "edited", "editedAt": 1234,
                ]]
            case "replace-rule.create":
                return ["rule": [
                    "id": 9, "name": "trim", "pattern": "\\s+", "replacement": " ",
                    "scopeTitle": false, "scopeContent": true, "isEnabled": true,
                    "isRegex": true, "timeoutMillisecond": 3000, "order": 2,
                ]]
            case "txt-toc-rule.create":
                return ["rule": [
                    "id": 11, "name": "chapter", "rule": "^Chapter", "serialNumber": 4, "enable": true,
                ]]
            case "dict-rule.query":
                return ["definition": "A definition"]
            case "change.cover":
                return ["coverUrls": ["https://img.example/a.jpg"]]
            case "book.chapterReview":
                return ["reviews": [["author": "reader", "content": "good", "rating": "5"]]]
            default:
                XCTFail("unexpected method \(method)")
                return [:]
            }
        }
        let service = ReaderSlice10CoreService(runtime: runtime, requestTimeout: 1)

        let edit = try await service.putContentEdit(
            bookID: "book-1", chapterIndex: 3, editedContent: "edited", editedAt: 1234
        )
        let replace = try await service.createReplaceRule(
            .init(name: "trim", pattern: "\\s+", replacement: " ", order: 2)
        )
        let toc = try await service.createTxtTocRule(
            .init(name: "chapter", rule: "^Chapter", serialNumber: 4)
        )
        let definition = try await service.queryDictionary(ruleName: "default", word: "word")
        let covers = try await service.discoverCoverCandidates(bookID: "book-1", sourceIDs: ["source-1"])
        let reviews = try await service.loadChapterReviews(sourceID: "source-1", bookID: "book-1")

        XCTAssertEqual(edit.editID, 7)
        XCTAssertEqual(replace.id, 9)
        XCTAssertEqual(replace.timeoutMilliseconds, 3000)
        XCTAssertEqual(toc.id, 11)
        XCTAssertEqual(definition, "A definition")
        XCTAssertEqual(covers, ["https://img.example/a.jpg"])
        XCTAssertEqual(reviews.first?.content, "good")
        XCTAssertEqual(runtime.methods, [
            "content-edit.put", "replace-rule.create", "txt-toc-rule.create",
            "dict-rule.query", "change.cover", "book.chapterReview",
        ])
    }

    func testInvalidRuleInputFailsBeforeDispatch() async {
        let runtime = FakeSlice10CommandRuntime { _ in [:] }
        let service = ReaderSlice10CoreService(runtime: runtime, requestTimeout: 1)

        do {
            _ = try await service.createReplaceRule(.init(name: "bad", pattern: "[", replacement: ""))
            XCTFail("invalid regex must fail closed")
        } catch let error as ReaderSlice10CoreServiceError {
            XCTAssertEqual(error.code, "SLICE10_REPLACE_REGEX_INVALID")
        } catch {
            XCTFail("unexpected error \(error)")
        }

        do {
            _ = try await service.createTxtTocRule(.init(name: "bad", rule: "("))
            XCTFail("invalid regex must fail closed")
        } catch let error as ReaderSlice10CoreServiceError {
            XCTAssertEqual(error.code, "SLICE10_TXT_TOC_REGEX_INVALID")
        } catch {
            XCTFail("unexpected error \(error)")
        }

        XCTAssertTrue(runtime.commands.isEmpty)
    }

    func testTypedParsersRejectBooleanAndFractionalIntegerCoercion() async {
        let booleanRuntime = FakeSlice10CommandRuntime { method in
            XCTAssertEqual(method, "bookmark.create")
            var bookmark = Self.bookmarkObject()
            bookmark["chapterIndex"] = true
            return ["bookmark": bookmark]
        }
        do {
            _ = try await ReaderSlice10CoreService(runtime: booleanRuntime, requestTimeout: 1).createBookmark(
                .init(bookName: "Book", chapterIndex: 0, chapterPosition: 0, chapterName: "Chapter")
            )
            XCTFail("Bool must not be coerced to an integer")
        } catch let error as ReaderSlice10CoreServiceError {
            XCTAssertEqual(error.code, "SLICE10_CORE_INVALID_RESULT")
        } catch {
            XCTFail("unexpected error \(error)")
        }

        let fractionalRuntime = FakeSlice10CommandRuntime { method in
            XCTAssertEqual(method, "bookmark.create")
            var bookmark = Self.bookmarkObject()
            bookmark["chapterPos"] = 1.5
            return ["bookmark": bookmark]
        }
        do {
            _ = try await ReaderSlice10CoreService(runtime: fractionalRuntime, requestTimeout: 1).createBookmark(
                .init(bookName: "Book", chapterIndex: 0, chapterPosition: 0, chapterName: "Chapter")
            )
            XCTFail("fractional values must not be coerced to integers")
        } catch let error as ReaderSlice10CoreServiceError {
            XCTAssertEqual(error.code, "SLICE10_CORE_INVALID_RESULT")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testHttpTTSCredentialsUnsafeURLsAndResponseHeadersFailClosed() async {
        let runtime = FakeSlice10CommandRuntime { method in
            XCTAssertEqual(method, "http-tts.build-request")
            return [
                "method": "GET",
                "url": "https://tts.example/speak?text=hello",
                "headers": ["Authorization": "secret"],
            ]
        }
        let service = ReaderSlice10CoreService(runtime: runtime, requestTimeout: 1)

        do {
            _ = try await service.putSafeHttpTTS(
                .init(id: 1, name: "unsafe", urlTemplate: "http://tts.example/{{text}}")
            )
            XCTFail("non-HTTPS config must fail closed")
        } catch let error as ReaderSlice10CoreServiceError {
            XCTAssertEqual(error.code, "SLICE10_HTTP_TTS_URL_UNSAFE")
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertTrue(runtime.commands.isEmpty)

        do {
            _ = try await service.buildSafeHttpTTSRequest(id: 1, text: "hello")
            XCTFail("descriptor headers require an opaque credential binding")
        } catch let error as ReaderSlice10CoreServiceError {
            XCTAssertEqual(error.code, "SLICE10_HTTP_TTS_CREDENTIAL_BINDING_REQUIRED")
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertEqual(runtime.methods, ["http-tts.build-request"])
    }

    private static func bookmarkObject() -> [String: Any] {
        [
            "time": 1_700_000_000_000 as Int64,
            "bookName": "Book", "bookAuthor": "Author", "chapterIndex": 2,
            "chapterPos": 41, "chapterName": "Chapter 3", "bookText": "text", "content": "note",
        ]
    }
}

private final class FakeSlice10CommandRuntime: RustCoreCommandRuntime {
    typealias Response = (String) throws -> [String: Any]

    private let response: Response
    private var events: [UInt64: ReaderCoreNativeEvent] = [:]
    var commands: [[String: Any]] = []
    var cancelledRequestIDs: [UInt64] = []
    var methods: [String] { commands.compactMap { $0["method"] as? String } }

    init(response: @escaping Response) {
        self.response = response
    }

    @discardableResult
    func send(json: Data) throws -> Int32 {
        let command = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        commands.append(command)
        let requestID = try XCTUnwrap((command["requestId"] as? NSNumber)?.uint64Value)
        let method = try XCTUnwrap(command["method"] as? String)
        let eventData = try JSONSerialization.data(withJSONObject: [
            "type": "result",
            "requestId": NSNumber(value: requestID),
            "data": try response(method),
        ])
        events[requestID] = try ReaderCoreNativeEvent(data: eventData)
        return 0
    }

    func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent? {
        events.removeValue(forKey: requestId)
    }

    func cancel(requestId: UInt64) throws {
        cancelledRequestIDs.append(requestId)
    }

    func command(method: String) -> [String: Any]? {
        commands.first { $0["method"] as? String == method }
    }
}
