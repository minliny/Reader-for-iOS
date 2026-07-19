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

    func testCacheAndReplaceUndoCommandsReturnStrictTypedResults() async throws {
        let revision = String(repeating: "a", count: 64)
        let beforeRule: [String: Any] = [
            "id": 9,
            "name": "weather",
            "pattern": "rain",
            "replacement": "cloud",
            "scopeTitle": false,
            "scopeContent": true,
            "isEnabled": true,
            "isRegex": false,
            "timeoutMillisecond": 3_000,
            "order": 0,
        ]
        var afterRule = beforeRule
        afterRule["replacement"] = "sun"
        let runtime = FakeSlice10CommandRuntime { method in
            switch method {
            case "cache.book.status":
                return Self.cacheStatusObject()
            case "cache.book.prefetch":
                return [
                    "sourceId": "source-1",
                    "bookId": "book-1",
                    "chapterRange": [2, 5],
                    "chapterCount": 3,
                    "prefetchedCount": 2,
                    "queuedIndexes": [2, 4],
                    "alreadyQueuedIndexes": [3],
                    "skippedCachedIndexes": [],
                ]
            case "cache.clear":
                return [
                    "scope": "book",
                    "cacheEntriesRemoved": 3,
                    "chapterEntriesRemoved": 2,
                    "queueEntriesRemoved": 1,
                    "removedContentBytes": 4_096,
                ]
            case "replace.undo":
                return [
                    "transactionId": "replace-tx-1",
                    "revision": revision,
                    "operation": "update",
                    "ruleId": 9,
                    "changed": true,
                    "undoneAt": 1_500,
                    "restoredRule": beforeRule,
                ]
            default:
                XCTFail("unexpected method \(method)")
                return [:]
            }
        }
        let service = ReaderSlice10CoreService(runtime: runtime, requestTimeout: 1)
        let undoTokenObject: [String: Any] = [
            "schemaVersion": 1,
            "transactionId": "replace-tx-1",
            "revision": revision,
            "operation": "update",
            "ruleId": 9,
            "issuedAt": 1_000,
            "expiresAt": 2_000,
            "before": beforeRule,
            "after": afterRule,
        ]
        let undoToken = try ReaderCoreReplaceUndoToken(coreObject: undoTokenObject)

        let status = try await service.loadBookCacheStatus(
            sourceID: "source-1",
            bookID: "book-1",
            correlationID: "status"
        )
        let prefetch = try await service.prefetchBookCache(
            sourceID: "source-1",
            bookID: "book-1",
            chapterRange: [2, 5],
            priority: 7,
            requestedAt: 1_234,
            correlationID: "prefetch"
        )
        let clear = try await service.clearCache(
            scope: .book,
            sourceID: "source-1",
            bookID: "book-1",
            correlationID: "clear"
        )
        let undo = try await service.undoReplace(
            undoToken: undoToken,
            correlationID: "undo"
        )

        XCTAssertEqual(runtime.methods, [
            "cache.book.status", "cache.book.prefetch", "cache.clear", "replace.undo",
        ])

        let statusParams = try XCTUnwrap(runtime.command(method: "cache.book.status")?["params"] as? [String: Any])
        XCTAssertEqual(statusParams["sourceId"] as? String, "source-1")
        XCTAssertEqual(statusParams["bookId"] as? String, "book-1")
        XCTAssertEqual(statusParams.count, 2)

        let prefetchParams = try XCTUnwrap(runtime.command(method: "cache.book.prefetch")?["params"] as? [String: Any])
        XCTAssertEqual((prefetchParams["chapterRange"] as? [NSNumber])?.map(\.intValue), [2, 5])
        XCTAssertEqual((prefetchParams["priority"] as? NSNumber)?.intValue, 7)
        XCTAssertEqual((prefetchParams["requestedAt"] as? NSNumber)?.int64Value, 1_234)
        XCTAssertEqual(prefetchParams["sourceId"] as? String, "source-1")
        XCTAssertEqual(prefetchParams["bookId"] as? String, "book-1")

        let clearParams = try XCTUnwrap(runtime.command(method: "cache.clear")?["params"] as? [String: Any])
        XCTAssertEqual(clearParams["scope"] as? String, "book")
        XCTAssertEqual(clearParams["sourceId"] as? String, "source-1")
        XCTAssertEqual(clearParams["bookId"] as? String, "book-1")

        let undoParams = try XCTUnwrap(runtime.command(method: "replace.undo")?["params"] as? [String: Any])
        let forwardedToken = try XCTUnwrap(undoParams["undoToken"] as? NSDictionary)
        XCTAssertTrue(forwardedToken.isEqual(to: undoTokenObject))

        XCTAssertEqual(status.sourceID, "source-1")
        XCTAssertEqual(status.chapters.first?.state, .cached)
        XCTAssertEqual(status.globalStats.queueEntryCount, 6)
        XCTAssertEqual(status.globalStats.queuedCount, 4)
        XCTAssertEqual(status.globalStats.inProgressCount, 1)
        XCTAssertEqual(status.globalStats.completedCount, 0)
        XCTAssertEqual(status.globalStats.failedCount, 1)
        XCTAssertEqual(status.globalStats.cancelledCount, 0)
        XCTAssertEqual(prefetch.queuedIndexes, [2, 4])
        XCTAssertEqual(prefetch.alreadyQueuedIndexes, [3])
        XCTAssertEqual(clear.cacheEntriesRemoved, 3)
        XCTAssertEqual(clear.removedContentBytes, 4_096)
        XCTAssertEqual(undo.restoredRule?.replacement, "cloud")
    }

    func testCacheAndReplaceUndoCoreErrorsAreNotConvertedToSuccess() async {
        let runtime = FakeSlice10CoreErrorRuntime(
            code: "INVALID_PARAMS",
            message: "Core rejected the exact command payload"
        )
        let service = ReaderSlice10CoreService(runtime: runtime, requestTimeout: 1)
        let revision = String(repeating: "a", count: 64)
        let rule = Self.replaceRuleObject(id: 9, replacement: "before")
        var after = rule
        after["replacement"] = "after"
        let token = try! ReaderCoreReplaceUndoToken(coreObject: [
            "schemaVersion": 1,
            "transactionId": "replace-error",
            "revision": revision,
            "operation": "update",
            "ruleId": 9,
            "issuedAt": 1_000,
            "expiresAt": 2_000,
            "before": rule,
            "after": after,
        ])
        let operations: [() async throws -> Void] = [
            { _ = try await service.loadBookCacheStatus(sourceID: "source-1", bookID: "book-1") },
            { _ = try await service.prefetchBookCache(sourceID: "source-1", bookID: "book-1", chapterRange: [2, 5]) },
            { _ = try await service.clearCache(scope: .book, sourceID: "source-1", bookID: "book-1") },
            { _ = try await service.undoReplace(undoToken: token) },
        ]

        for operation in operations {
            do {
                _ = try await operation()
                XCTFail("Core error must not be converted to a synthetic result")
            } catch let error as ReaderCoreNativeError {
                XCTAssertEqual(
                    error,
                    .coreError(
                        code: "INVALID_PARAMS",
                        message: "Core rejected the exact command payload"
                    )
                )
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }

        XCTAssertEqual(runtime.methods, [
            "cache.book.status", "cache.book.prefetch", "cache.clear", "replace.undo",
        ])
    }

    func testCacheStatusRejectsEveryMissingRequiredGlobalQueueCount() async {
        let requiredCounts = [
            "queueEntryCount", "queuedCount", "inProgressCount",
            "completedCount", "failedCount", "cancelledCount",
        ]

        for missingField in requiredCounts {
            var status = Self.cacheStatusObject()
            var global = try! XCTUnwrap(status["globalStats"] as? [String: Any])
            global.removeValue(forKey: missingField)
            status["globalStats"] = global
            let runtime = FakeSlice10CommandRuntime { _ in status }
            do {
                _ = try await ReaderSlice10CoreService(runtime: runtime, requestTimeout: 1)
                    .loadBookCacheStatus(sourceID: "source-1", bookID: "book-1")
                XCTFail("missing globalStats.\(missingField) must fail")
            } catch let error as ReaderSlice10CoreServiceError {
                guard case .invalidResult(let method, let message) = error else {
                    return XCTFail("unexpected error \(error)")
                }
                XCTAssertEqual(method, "cache.book.status")
                XCTAssertTrue(message.contains(missingField))
            } catch {
                XCTFail("unexpected error \(error)")
            }
        }
    }

    func testCacheAndUndoRejectIncompleteOrUnknownCoreResults() async throws {
        var incompleteStatus = Self.cacheStatusObject()
        incompleteStatus.removeValue(forKey: "missingCount")
        let statusRuntime = FakeSlice10CommandRuntime { _ in incompleteStatus }
        do {
            _ = try await ReaderSlice10CoreService(runtime: statusRuntime, requestTimeout: 1)
                .loadBookCacheStatus(sourceID: "source-1", bookID: "book-1")
            XCTFail("missing status field must fail")
        } catch let error as ReaderSlice10CoreServiceError {
            XCTAssertEqual(error.code, "SLICE10_CORE_INVALID_RESULT")
        }

        let clearRuntime = FakeSlice10CommandRuntime { _ in [
            "scope": "book",
            "cacheEntriesRemoved": 1,
            "chapterEntriesRemoved": 1,
            "queueEntriesRemoved": 0,
            "removedContentBytes": 10,
            "invented": true,
        ] }
        do {
            _ = try await ReaderSlice10CoreService(runtime: clearRuntime, requestTimeout: 1)
                .clearCache(scope: .book, sourceID: "source-1", bookID: "book-1")
            XCTFail("unknown clear field must fail")
        } catch let error as ReaderSlice10CoreServiceError {
            XCTAssertEqual(error.code, "SLICE10_CORE_INVALID_RESULT")
        }
    }

    func testCacheAndReplaceUndoRejectMissingCoreResultData() async {
        let runtime = FakeSlice10CommandRuntime { _ in nil }
        let service = ReaderSlice10CoreService(runtime: runtime, requestTimeout: 1)

        do {
            _ = try await service.loadBookCacheStatus(sourceID: "source-1", bookID: "book-1")
            XCTFail("missing Core result data must not become an empty success object")
        } catch let error as ReaderSlice10CoreServiceError {
            XCTAssertEqual(
                error,
                .invalidResult(method: "cache.book.status", message: "result data is missing")
            )
        } catch {
            XCTFail("unexpected error \(error)")
        }
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

    private static func cacheStatusObject() -> [String: Any] {
        [
            "sourceId": "source-1",
            "bookId": "book-1",
            "tocAvailable": true,
            "chapterCount": 3,
            "chapters": [[
                "chapterIndex": 2,
                "title": "Chapter 3",
                "url": "https://books.example/chapter/3",
                "state": "cached",
                "cachedBytes": 1_024,
                "attempts": 1,
                "maxAttempts": 3,
            ]],
            "cachedCount": 1,
            "queuedCount": 1,
            "inProgressCount": 0,
            "completedCount": 0,
            "failedCount": 0,
            "cancelledCount": 0,
            "missingCount": 1,
            "globalStats": [
                "entryCount": 10,
                "totalContentBytes": 40_960,
                "oldestCachedAt": 1_000,
                "newestCachedAt": 2_000,
                "queueEntryCount": 6,
                "queuedCount": 4,
                "inProgressCount": 1,
                "completedCount": 0,
                "failedCount": 1,
                "cancelledCount": 0,
            ],
        ]
    }

    private static func replaceRuleObject(id: Int, replacement: String) -> [String: Any] {
        [
            "id": id,
            "name": "weather",
            "pattern": "rain",
            "replacement": replacement,
            "scopeTitle": false,
            "scopeContent": true,
            "isEnabled": true,
            "isRegex": false,
            "timeoutMillisecond": 3_000,
            "order": 0,
        ]
    }
}

private final class FakeSlice10CommandRuntime: RustCoreCommandRuntime {
    typealias Response = (String) throws -> [String: Any]?

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
        var event: [String: Any] = [
            "type": "result",
            "requestId": NSNumber(value: requestID),
        ]
        if let data = try response(method) {
            event["data"] = data
        }
        let eventData = try JSONSerialization.data(withJSONObject: event)
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

private final class FakeSlice10CoreErrorRuntime: RustCoreCommandRuntime {
    private let code: String
    private let message: String
    private var events: [UInt64: ReaderCoreNativeEvent] = [:]
    private(set) var methods: [String] = []

    init(code: String, message: String) {
        self.code = code
        self.message = message
    }

    @discardableResult
    func send(json: Data) throws -> Int32 {
        let command = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        let requestID = try XCTUnwrap((command["requestId"] as? NSNumber)?.uint64Value)
        methods.append(try XCTUnwrap(command["method"] as? String))
        let eventData = try JSONSerialization.data(withJSONObject: [
            "type": "error",
            "requestId": NSNumber(value: requestID),
            "error": ["code": code, "message": message],
        ])
        events[requestID] = try ReaderCoreNativeEvent(data: eventData)
        return 0
    }

    func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent? {
        events.removeValue(forKey: requestId)
    }

    func cancel(requestId: UInt64) throws {}
}
