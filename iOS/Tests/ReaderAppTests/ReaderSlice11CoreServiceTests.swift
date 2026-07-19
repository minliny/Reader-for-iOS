import XCTest
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

final class ReaderSlice11CoreServiceTests: XCTestCase {
    func testDynamicSourceCommandsPreserveFrozenMethodsAndTypedResults() async throws {
        let runtime = FakeSlice11CommandRuntime { command in
            switch command["method"] as? String {
            case "source.import":
                return ["sourceId": "source-1", "name": "Example", "imported": true]
            case "source.check.run":
                return ["results": [[
                    "sourceId": "source-1", "available": true,
                    "levelsPassed": ["L1", "L2"], "durationMs": 12,
                ]]]
            case "source.debug":
                return [
                    "logs": [["state": 1, "msg": "parsed", "timestampMs": 42, "step": "search"]],
                    "finalState": 1,
                    "durationMs": 5,
                ]
            default:
                XCTFail("unexpected command \(String(describing: command["method"]))")
                return [:]
            }
        }
        let service = ReaderSlice11CoreService(runtime: runtime, requestTimeout: 1)

        let imported = try await service.importCanonicalSource(
            sourceID: "source-1",
            name: "Example",
            baseURL: "https://books.example.test",
            rules: ["search": "$.items[*]"]
        )
        let checked = try await service.runSourceCheck(
            sourceIDs: ["source-1"],
            keyword: "book",
            levels: ["L1", "L2"],
            timeoutMilliseconds: 2_000
        )
        let debugged = try await service.debugSourceReplay(
            sourceID: "source-1",
            key: "book",
            responses: .init(sourceID: "source-1", searchResponse: "{\"items\":[]}")
        )

        XCTAssertEqual(runtime.methods, ["source.import", "source.check.run", "source.debug"])
        XCTAssertEqual(imported.sourceID, "source-1")
        XCTAssertEqual(checked.first?.levelsPassed, ["L1", "L2"])
        XCTAssertEqual(debugged.logs.first?.step, "search")

        let importParams = try XCTUnwrap(runtime.params(for: "source.import"))
        XCTAssertEqual(importParams["sourceId"] as? String, "source-1")
        XCTAssertEqual(importParams["baseUrl"] as? String, "https://books.example.test")
        let checkParams = try XCTUnwrap(runtime.params(for: "source.check.run"))
        XCTAssertEqual(checkParams["timeoutMs"] as? Int, 2_000)
        XCTAssertEqual(checkParams["levels"] as? [String], ["L1", "L2"])
    }

    func testLegadoImportRejectsEmbeddedCredentialBeforeCoreDispatch() async {
        let runtime = FakeSlice11CommandRuntime { _ in [:] }
        let service = ReaderSlice11CoreService(runtime: runtime, requestTimeout: 1)
        let data = Data(#"{"bookSourceName":"Unsafe","bookSourceUrl":"https://books.example.test","header":{"Authorization":"Bearer plaintext"}}"#.utf8)

        do {
            _ = try await service.importLegadoSource(jsonData: data)
            XCTFail("plaintext credential material must fail closed")
        } catch let error as ReaderSlice11CoreServiceError {
            XCTAssertEqual(error.code, "SLICE11_EMBEDDED_CREDENTIAL_REJECTED")
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertTrue(runtime.commands.isEmpty)
    }

    func testDebugRequiresCallerOwnedResponseCorpusBeforeDispatch() async {
        let runtime = FakeSlice11CommandRuntime { _ in [:] }
        let service = ReaderSlice11CoreService(runtime: runtime, requestTimeout: 1)

        do {
            _ = try await service.debugSourceReplay(
                sourceID: "source-1",
                key: "book",
                responses: .init(sourceID: "source-1")
            )
            XCTFail("empty debug corpus must fail closed")
        } catch let error as ReaderSlice11CoreServiceError {
            XCTAssertEqual(error.code, "SLICE11_SOURCE_DEBUG_CORPUS_MISSING")
        } catch {
            XCTFail("unexpected error \(error)")
        }
        XCTAssertTrue(runtime.commands.isEmpty)
    }

    func testPublicRSSRefreshVerifiesStoredCredentialFreeSubscriptionBeforeFetch() async throws {
        let runtime = FakeSlice11CommandRuntime { command in
            switch command["method"] as? String {
            case "rss.subscription.add":
                return ["subscription": Self.subscription()]
            case "rss.subscription.list":
                return ["subscriptions": [Self.subscription()]]
            case "rss.subscription.refresh":
                return Self.itemsEnvelope().merging([
                    "newCount": 1, "fetched": true, "notModified": false, "evaluatedAt": 99,
                ]) { _, new in new }
            default:
                XCTFail("unexpected command \(String(describing: command["method"]))")
                return [:]
            }
        }
        let service = ReaderSlice11CoreService(runtime: runtime, requestTimeout: 1)

        let subscription = try await service.addRSSSubscription(
            subscriptionID: "feed-1",
            feedURL: "https://feeds.example.test/main.xml",
            title: "Example"
        )
        let refreshed = try await service.refreshRSSSubscription(
            subscriptionID: "feed-1",
            evaluatedAt: 99
        )

        XCTAssertEqual(subscription.feedURL, "https://feeds.example.test/main.xml")
        XCTAssertEqual(refreshed.newCount, 1)
        XCTAssertEqual(refreshed.items.first?.guid, "entry-1")
        XCTAssertEqual(runtime.methods, [
            "rss.subscription.add", "rss.subscription.list", "rss.subscription.refresh",
        ])
    }

    func testMissingRuleAuthAndChallengeContractsReturnStableBlockers() {
        let service = ReaderSlice11CoreService(runtime: FakeSlice11CommandRuntime { _ in [:] })
        assertBlocker("SLICE11_RULE_SUBSCRIPTION_CONTRACT_MISSING") {
            try service.requireRuleSubscriptionContract()
        }
        assertBlocker("SLICE11_RSS_AUTH_BINDING_CONTRACT_MISSING") {
            try service.requireAuthenticatedRSSContract()
        }
        assertBlocker("SLICE11_CAPTCHA_RETURN_CONTRACT_MISSING") {
            try service.requireCaptchaReturnContract()
        }
        assertBlocker("SLICE11_WEBVIEW_LOGIN_RETURN_CONTRACT_MISSING") {
            try service.requireWebViewLoginReturnContract()
        }
    }

    func testFractionalCoreIntegerResultIsRejectedWithoutCoercion() async {
        let runtime = FakeSlice11CommandRuntime { _ in
            ["results": [[
                "sourceId": "source-1",
                "available": true,
                "levelsPassed": ["L1"],
                "durationMs": 12.5,
            ]]]
        }
        let service = ReaderSlice11CoreService(runtime: runtime, requestTimeout: 1)

        do {
            _ = try await service.runSourceCheck(
                sourceIDs: ["source-1"],
                keyword: "book",
                levels: ["L1"]
            )
            XCTFail("fractional integer result must fail closed")
        } catch let error as ReaderSlice11CoreServiceError {
            XCTAssertEqual(error.code, "SLICE11_CORE_INVALID_RESULT")
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testSourceExportRequiresCredentialFreeJSONArrayWithMatchingCount() async throws {
        let validRuntime = FakeSlice11CommandRuntime { _ in
            ["data": "[]", "count": 0, "format": "json"]
        }
        let valid = try await ReaderSlice11CoreService(runtime: validRuntime).exportSources()
        XCTAssertEqual(valid.json, "[]")
        XCTAssertEqual(valid.count, 0)

        let invalidResponses: [[String: Any]] = [
            ["data": "not-json", "count": 0, "format": "json"],
            ["data": "{}", "count": 0, "format": "json"],
            ["data": "[]", "count": 1, "format": "json"],
            ["data": "[]", "count": 0, "format": "encrypted-json"],
            ["data": #"[{"header":{"Authorization":"Bearer plaintext"}}]"#, "count": 1, "format": "json"],
        ]
        for response in invalidResponses {
            let runtime = FakeSlice11CommandRuntime { _ in response }
            do {
                _ = try await ReaderSlice11CoreService(runtime: runtime).exportSources()
                XCTFail("invalid source.export response must fail closed: \(response)")
            } catch let error as ReaderSlice11CoreServiceError {
                XCTAssertTrue(
                    ["SLICE11_CORE_INVALID_RESULT", "SLICE11_EMBEDDED_CREDENTIAL_REJECTED"].contains(error.code),
                    error.localizedDescription
                )
            }
        }
    }

    func testFrozenZeroValuesAreForwardedForSourceCheckAndRSSItems() async throws {
        let runtime = FakeSlice11CommandRuntime { command in
            switch command["method"] as? String {
            case "source.check.run":
                return ["results": []]
            case "rss.subscription.items":
                return Self.itemsEnvelope().merging(["items": [], "count": 0, "unreadCount": 0]) { _, new in new }
            default:
                XCTFail("unexpected command \(String(describing: command["method"]))")
                return [:]
            }
        }
        let service = ReaderSlice11CoreService(runtime: runtime)

        _ = try await service.runSourceCheck(
            sourceIDs: ["source-1"],
            keyword: "book",
            levels: [],
            timeoutMilliseconds: 0
        )
        _ = try await service.listRSSItems(subscriptionID: "feed-1", limit: 0)

        let check = try XCTUnwrap(runtime.params(for: "source.check.run"))
        XCTAssertEqual(check["levels"] as? [String], [])
        XCTAssertEqual(check["timeoutMs"] as? Int, 0)
        let items = try XCTUnwrap(runtime.params(for: "rss.subscription.items"))
        XCTAssertEqual(items["limit"] as? Int, 0)
    }

    private func assertBlocker(_ code: String, operation: () throws -> Never) {
        do {
            try operation()
        } catch let error as ReaderSlice11CoreServiceError {
            XCTAssertEqual(error.code, code)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    private static func subscription() -> [String: Any] {
        [
            "subscriptionId": "feed-1",
            "feedUrl": "https://feeds.example.test/main.xml",
            "title": "Example",
            "siteUrl": "https://feeds.example.test",
            "enabled": true,
            "lastFetchAt": 99,
            "lastEntryId": "entry-1",
            "unreadCount": 1,
        ]
    }

    private static func itemsEnvelope() -> [String: Any] {
        [
            "subscription": subscription(),
            "items": [[
                "subscriptionId": "feed-1", "title": "Entry", "link": "https://feeds.example.test/1",
                "description": "Summary", "author": "Author", "pubDate": "2026-07-19T00:00:00Z",
                "guid": "entry-1", "read": false, "firstSeenAt": 99,
            ]],
            "count": 1,
            "unreadCount": 1,
        ]
    }
}

private final class FakeSlice11CommandRuntime: RustCoreCommandRuntime {
    typealias Response = ([String: Any]) throws -> [String: Any]

    private let response: Response
    private var events: [UInt64: ReaderCoreNativeEvent] = [:]
    var commands: [[String: Any]] = []
    var methods: [String] { commands.compactMap { $0["method"] as? String } }

    init(response: @escaping Response) {
        self.response = response
    }

    @discardableResult
    func send(json: Data) throws -> Int32 {
        let command = try XCTUnwrap(JSONSerialization.jsonObject(with: json) as? [String: Any])
        commands.append(command)
        let requestID = try XCTUnwrap((command["requestId"] as? NSNumber)?.uint64Value)
        let eventData = try JSONSerialization.data(withJSONObject: [
            "type": "result",
            "requestId": NSNumber(value: requestID),
            "data": try response(command),
        ])
        events[requestID] = try ReaderCoreNativeEvent(data: eventData)
        return 0
    }

    func pollEvent(requestId: UInt64) -> ReaderCoreNativeEvent? {
        events.removeValue(forKey: requestId)
    }

    func cancel(requestId: UInt64) throws {}

    func params(for method: String) -> [String: Any]? {
        commands.first { $0["method"] as? String == method }?["params"] as? [String: Any]
    }
}
