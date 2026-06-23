import XCTest
@testable import ReaderApp
import ReaderAppPersistence
@testable import ReaderShellValidation
import ReaderCoreModels
import ReaderCoreProtocols

@MainActor
final class RSSCoreIntegrationTests: XCTestCase {
    func testCoreRSSFeedServiceParsesRSSXMLIntoSubscriptionItems() async throws {
        let source = RSSSource(url: "https://example.com/rss.xml", name: "Example Feed", enableJs: false)
        let summary = try await CoreRSSFeedService().parseFeed(data: Data(sampleRSS.utf8), source: source)

        XCTAssertEqual(summary.format, .rss)
        XCTAssertEqual(summary.items.count, 2)
        XCTAssertEqual(summary.items[0].title, "Article 1")
        XCTAssertEqual(summary.items[0].link, "https://example.com/1")
        XCTAssertEqual(summary.items[0].summary, "Summary 1")
        XCTAssertEqual(summary.items[0].sourceName, "Example Feed")
        XCTAssertTrue(summary.cleanRoomMaintained)
        XCTAssertFalse(summary.externalGPLCodeCopied)
    }

    func testRSSFeedViewModelRefreshUsesCoreBackedLoader() async throws {
        let source = RSSSource(url: "https://example.com/rss.xml", name: "Example Feed", enableJs: false)
        let expected = CoreRSSFeedSummary(
            source: source,
            format: .rss,
            items: [
                SubscriptionItem(
                    title: "Article",
                    link: "https://example.com/a",
                    summary: "Summary",
                    sourceId: source.url,
                    sourceName: source.name
                )
            ],
            nextPageURL: nil,
            diagnostics: ["fixture:core_rss_bridge"]
        )
        let loader = FakeRSSFeedLoader(fetchSummary: expected)
        let viewModel = RSSFeedViewModel(
            feedURL: source.url,
            feedName: source.name ?? "",
            loader: loader
        )

        await viewModel.refresh()

        let fetchedSources = await loader.fetchedSources
        XCTAssertEqual(fetchedSources.map(\.url), [source.url])
        guard case .loaded(let summary) = viewModel.feedState else {
            XCTFail("Expected loaded RSS state, got \(viewModel.feedState)")
            return
        }
        XCTAssertEqual(summary.items.first?.title, "Article")
        XCTAssertEqual(summary.diagnostics, ["fixture:core_rss_bridge"])
    }

    func testRSSFeedViewModelReportsEmptyFeed() async {
        let source = RSSSource(url: "https://example.com/empty.xml", name: "Empty", enableJs: false)
        let empty = CoreRSSFeedSummary(
            source: source,
            format: .rss,
            items: [],
            nextPageURL: nil,
            diagnostics: []
        )
        let viewModel = RSSFeedViewModel(
            feedURL: source.url,
            feedName: source.name ?? "",
            loader: FakeRSSFeedLoader(fetchSummary: empty)
        )

        await viewModel.refresh()

        guard case .empty(let summary) = viewModel.feedState else {
            XCTFail("Expected empty RSS state, got \(viewModel.feedState)")
            return
        }
        XCTAssertEqual(summary.source.url, source.url)
    }

    func testRSSSubscriptionStorePersistsAndUpdatesByURL() async throws {
        let storeURL = temporaryFileURL(name: "rss-subscriptions.json")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let store = RSSSubscriptionStore(storageURL: storeURL)
        let original = RSSSource(url: " https://example.com/rss.xml ", name: "Original", enableJs: false)
        let updated = RSSSource(url: "https://example.com/rss.xml", name: "Updated", enableJs: false)

        try await store.addOrUpdate(original)
        try await store.addOrUpdate(updated)

        let subscriptions = try await store.load()
        XCTAssertEqual(subscriptions.count, 1)
        XCTAssertEqual(subscriptions[0].url, "https://example.com/rss.xml")
        XCTAssertEqual(subscriptions[0].name, "Updated")
        XCTAssertFalse(subscriptions[0].enableJs)
    }

    func testRSSFeedViewModelPersistsFetchedSubscription() async throws {
        let storeURL = temporaryFileURL(name: "rss-fetched-subscriptions.json")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let store = RSSSubscriptionStore(storageURL: storeURL)
        let source = RSSSource(url: "https://example.com/rss.xml", name: "Example Feed", enableJs: false)
        let expected = CoreRSSFeedSummary(
            source: source,
            format: .rss,
            items: [
                SubscriptionItem(title: "Article", link: "https://example.com/a", sourceId: source.url, sourceName: source.name)
            ],
            nextPageURL: nil,
            diagnostics: []
        )
        let viewModel = RSSFeedViewModel(
            feedURL: source.url,
            feedName: source.name ?? "",
            loader: FakeRSSFeedLoader(fetchSummary: expected),
            store: store
        )

        await viewModel.refresh()

        let subscriptions = try await store.load()
        XCTAssertEqual(subscriptions.map(\.url), [source.url])
        XCTAssertEqual(subscriptions.first?.name, "Example Feed")
        XCTAssertNotNil(subscriptions.first?.lastFetchedAt)
        XCTAssertEqual(viewModel.subscriptions.map(\.url), [source.url])
        XCTAssertEqual(viewModel.selectedSubscriptionURL, source.url)
    }

    func testRSSFeedViewModelLoadsAndSelectsSavedSubscription() async throws {
        let storeURL = temporaryFileURL(name: "rss-load-subscriptions.json")
        defer { try? FileManager.default.removeItem(at: storeURL) }
        let store = RSSSubscriptionStore(storageURL: storeURL)
        let source = RSSSource(url: "https://example.com/saved.xml", name: "Saved Feed", enableJs: false)
        try await store.addOrUpdate(source)
        let viewModel = RSSFeedViewModel(loader: FakeRSSFeedLoader(fetchSummary: CoreRSSFeedSummary(
            source: source,
            format: .rss,
            items: [],
            nextPageURL: nil,
            diagnostics: []
        )), store: store)

        await viewModel.loadSubscriptions()

        XCTAssertEqual(viewModel.subscriptions.map(\.url), [source.url])
        XCTAssertEqual(viewModel.feedURL, source.url)
        XCTAssertEqual(viewModel.feedName, "Saved Feed")
        XCTAssertEqual(viewModel.selectedSubscriptionURL, source.url)
    }

    private var sampleRSS: String {
        """
        <?xml version="1.0" encoding="UTF-8"?>
        <rss version="2.0">
        <channel>
        <title>Example Feed</title>
        <item>
        <title>Article 1</title>
        <link>https://example.com/1</link>
        <description>Summary 1</description>
        <pubDate>Mon, 01 Jan 2025 10:00:00 +0000</pubDate>
        </item>
        <item>
        <title>Article 2</title>
        <link>https://example.com/2</link>
        <description>Summary 2</description>
        </item>
        </channel>
        </rss>
        """
    }

    private func temporaryFileURL(name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-ios-rss-\(UUID().uuidString)-\(name)")
    }
}

private actor FakeRSSFetchRecorder {
    private var fetchedSources: [RSSSource] = []

    func record(_ source: RSSSource) {
        fetchedSources.append(source)
    }

    func snapshot() -> [RSSSource] {
        fetchedSources
    }
}

private final class FakeRSSFeedLoader: CoreRSSFeedLoading, @unchecked Sendable {
    private let recorder = FakeRSSFetchRecorder()
    private let fetchSummary: CoreRSSFeedSummary

    var fetchedSources: [RSSSource] {
        get async { await recorder.snapshot() }
    }

    init(fetchSummary: CoreRSSFeedSummary) {
        self.fetchSummary = fetchSummary
    }

    func parseFeed(data: Data, source: RSSSource) async throws -> CoreRSSFeedSummary {
        fetchSummary
    }

    func fetchAndParse(source: RSSSource) async throws -> CoreRSSFeedSummary {
        await recorder.record(source)
        return fetchSummary
    }
}
