import Foundation
import XCTest
import ReaderCoreModels
@testable import ReaderAppPersistence

final class RSSSubscriptionStoreCoreDecodingTests: XCTestCase {
    func testCoreSubscriptionSnapshotDecodesAllRowsStrictly() throws {
        let store = makeStore()
        let rows = try coreRows([
            [
                "subscriptionId": "feed-1",
                "feedUrl": "https://feeds.example.test/main.xml",
                "title": "Main",
                "enabled": true,
                "lastFetchAt": 1_000,
                "lastEntryId": "entry-1",
                "unreadCount": 2,
            ],
        ])

        let sources = try store.parseCoreSubscriptions(rows)

        XCTAssertEqual(sources.count, 1)
        XCTAssertEqual(sources[0].url, "https://feeds.example.test/main.xml")
        XCTAssertEqual(sources[0].name, "Main")
        XCTAssertTrue(sources[0].enabled)
        XCTAssertNotNil(sources[0].lastFetchedAt)
        XCTAssertEqual(store.coreSubscriptionID(from: sources[0]), "feed-1")
    }

    func testCoreOpaqueSubscriptionIDSurvivesCompatibilityPersistenceRoundTrip() async throws {
        let storageURL = temporaryURL()
        defer { try? FileManager.default.removeItem(at: storageURL) }
        let store = RSSSubscriptionStore(storageURL: storageURL)
        let rows = try coreRows([coreRow(subscriptionID: "Opaque-Feed-ID/42")])
        let source = try XCTUnwrap(store.parseCoreSubscriptions(rows).first)

        try await store.save([source])
        store.clearCache()
        let restoredSources = try await store.load()
        let restored = try XCTUnwrap(restoredSources.first)

        XCTAssertEqual(store.coreSubscriptionID(from: restored), "Opaque-Feed-ID/42")
    }

    func testUpdateRefreshAndDeleteUseExactOpaqueCoreIDNeverFeedURL() async throws {
        let stub = CoreRequestStub(rows: [coreRow(subscriptionID: "Opaque-Feed-ID/42")])
        let store = makeCoreStore(stub: stub)
        let listedSources = try await store.load()
        let listed = try XCTUnwrap(listedSources.first)

        // Simulate a UI reconstruction that retained only URL/title. The store
        // must map it back through the Core snapshot before updating.
        let reconstructed = RSSSource(
            url: listed.url,
            name: "Renamed",
            enableJs: false
        )
        try await store.addOrUpdate(reconstructed)
        try await store.refresh(listed, evaluatedAt: 123)
        try await store.delete(listed)

        let mutations = stub.calls.filter { $0.method != "rss.subscription.list" }
        XCTAssertEqual(
            mutations.map(\.method),
            ["rss.subscription.update", "rss.subscription.refresh", "rss.subscription.delete"]
        )
        for mutation in mutations {
            XCTAssertEqual(mutation.stringParams["subscriptionId"], "Opaque-Feed-ID/42")
            XCTAssertNotEqual(mutation.stringParams["subscriptionId"], listed.url)
        }
        XCTAssertEqual(mutations[1].integerParams["evaluatedAt"], 123)
    }

    func testDeleteByLegacyURLAPIResolvesOpaqueIDBeforeMutation() async throws {
        let stub = CoreRequestStub(rows: [coreRow(subscriptionID: "core-owned-delete-id")])
        let store = makeCoreStore(stub: stub)

        try await store.delete(url: "https://feeds.example.test/main.xml")

        XCTAssertEqual(stub.calls.map(\.method), [
            "rss.subscription.list",
            "rss.subscription.delete",
        ])
        XCTAssertEqual(stub.calls.last?.stringParams["subscriptionId"], "core-owned-delete-id")
    }

    func testNewSubscriptionGetsOpaqueClientIDInsteadOfURLIdentity() async throws {
        let stub = CoreRequestStub(rows: [])
        let store = makeCoreStore(stub: stub)
        let source = RSSSource(
            url: "https://feeds.example.test/new.xml",
            name: "New",
            enableJs: false
        )

        try await store.addOrUpdate(source)

        let add = try XCTUnwrap(stub.calls.last)
        XCTAssertEqual(add.method, "rss.subscription.add")
        XCTAssertTrue(add.stringParams["subscriptionId"]?.hasPrefix("ios-") == true)
        XCTAssertNotEqual(add.stringParams["subscriptionId"], source.url)
    }

    func testOneMalformedCoreRowRejectsTheWholeSnapshot() throws {
        let store = makeStore()
        let malformedRows: [[[String: Any]]] = [
            [[
                "subscriptionId": "feed-1", "title": "Missing URL",
                "enabled": true, "unreadCount": 0,
            ]],
            [[
                "subscriptionId": "feed-1", "feedUrl": "https://feeds.example.test/main.xml",
                "title": "Fractional", "enabled": true, "unreadCount": 0.5,
            ]],
            [[
                "subscriptionId": "feed-1", "feedUrl": "https://user:secret@feeds.example.test/main.xml",
                "title": "Credential", "enabled": true, "unreadCount": 0,
            ]],
        ]

        for rawRows in malformedRows {
            let rows = try coreRows(rawRows)
            XCTAssertThrowsError(try store.parseCoreSubscriptions(rows))
        }
    }

    private func makeStore() -> RSSSubscriptionStore {
        RSSSubscriptionStore(
            storageURL: temporaryURL()
        )
    }

    private func makeCoreStore(stub: CoreRequestStub) -> RSSSubscriptionStore {
        RSSSubscriptionStore(
            storageURL: temporaryURL(),
            coreRequest: { method, params in
                stub.request(method: method, params: params)
            }
        )
    }

    private func coreRow(subscriptionID: String) -> [String: Any] {
        [
            "subscriptionId": subscriptionID,
            "feedUrl": "https://feeds.example.test/main.xml",
            "title": "Main",
            "enabled": true,
            "lastFetchAt": 1_000,
            "lastEntryId": "entry-1",
            "unreadCount": 2,
        ]
    }

    private func temporaryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("rss-core-decode-\(UUID().uuidString).json")
    }

    private func coreRows(_ rows: [[String: Any]]) throws -> [[String: Any]] {
        let data = try JSONSerialization.data(withJSONObject: rows)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [[String: Any]])
    }
}

private struct RecordedCoreRequest: Sendable {
    let method: String
    let stringParams: [String: String]
    let integerParams: [String: Int64]
}

private final class CoreRequestStub: @unchecked Sendable {
    private let lock = NSLock()
    private let rows: [[String: Any]]
    private var recordedCalls: [RecordedCoreRequest] = []

    init(rows: [[String: Any]]) {
        self.rows = rows
    }

    var calls: [RecordedCoreRequest] {
        lock.withLock { recordedCalls }
    }

    func request(method: String, params: [String: Any]) -> [String: Any] {
        let call = RecordedCoreRequest(
            method: method,
            stringParams: params.compactMapValues { $0 as? String },
            integerParams: params.compactMapValues { value in
                if let int64 = value as? Int64 { return int64 }
                if let int = value as? Int { return Int64(int) }
                return nil
            }
        )
        lock.withLock { recordedCalls.append(call) }
        return method == "rss.subscription.list" ? ["subscriptions": rows] : [:]
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
