import XCTest
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

/// Item 8f: iOS RSS 订阅 proof — Core-driven rss.parse (Path A minimal).
///
/// Per the Core/Host boundary: Core owns RSS XML parsing (pure, no network);
/// Host owns fetching the RSS XML bytes (via URLSession). The Host fetches
/// the feed out-of-band, then passes the XML body to Core's `rss.parse`
/// command, which returns structured entries (title, link, summary, publishedAt).
///
/// This is "Path A" (minimal, non-persistent): Host fetches XML → Core parses
/// → entries returned. Subscription persistence (CRUD) requires additional
/// Core contract work (rss.subscription.* / rss.source.*) and is out of scope
/// for this proof.
///
/// Proof tier: device-headless (host sim XCTest with real Core runtime).
/// The Core runtime is a real C ABI binary linked transitively via
/// `ReaderShellValidation`. No real RSS feed is fetched — the proof uses
/// fixture XML to verify Core's parsing contract.
///
/// Mirrors Core contract in:
/// - `crates/reader-contract/src/remote.rs` (RssParseParams, RssParseData,
///   RssParseEntryData)
/// - `crates/reader-contract/src/lib.rs` (RSS_PARSE = "rss.parse")
final class HostRssParseProofTests: XCTestCase {

    // MARK: - Helpers

    private func makeRuntime() throws -> ReaderCoreNativeRuntime {
        let runtime = try ReaderCoreNativeRuntime()
        return runtime
    }

    /// Send a Core command and poll for the result event.
    private func sendAndPollResult(
        runtime: ReaderCoreNativeRuntime,
        method: String,
        params: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let requestId: UInt64 = UInt64.random(in: 100_000...999_999)
        let command: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestId),
            "method": method,
            "params": params,
        ]
        let json = try JSONSerialization.data(withJSONObject: command)
        try runtime.send(json: json)

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let event = runtime.pollEvent(requestId: requestId) {
                if event.type == "error" {
                    throw ReaderCoreNativeError.coreError(
                        code: event.coreErrorCode ?? "INTERNAL",
                        message: event.coreErrorMessage ?? "\(method) failed"
                    )
                }
                XCTAssertEqual(event.type, "result",
                               "expected result for \(method), got \(event.type)",
                               file: file, line: line)
                return event.data ?? [:]
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
        throw ReaderCoreNativeError.requestTimedOut(requestId)
    }

    /// Sample RSS 2.0 feed XML for proof tests.
    private static let sampleRSS2XML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <rss version="2.0">
      <channel>
        <title>RSS Proof Test Feed</title>
        <link>https://example.com/feed</link>
        <description>Sample RSS feed for iOS Host proof</description>
        <item>
          <title>First Article</title>
          <link>https://example.com/articles/1</link>
          <description>Summary of the first article</description>
          <pubDate>Mon, 01 Jul 2026 10:00:00 GMT</pubDate>
          <guid>article-1</guid>
        </item>
        <item>
          <title>Second Article</title>
          <link>https://example.com/articles/2</link>
          <description>Summary of the second article</description>
          <pubDate>Tue, 02 Jul 2026 11:00:00 GMT</pubDate>
          <guid>article-2</guid>
        </item>
      </channel>
    </rss>
    """

    /// Sample Atom 1.0 feed XML for proof tests.
    private static let sampleAtomXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <feed xmlns="http://www.w3.org/2005/Atom">
      <title>Atom Proof Test Feed</title>
      <link href="https://example.com/atom" rel="self"/>
      <link href="https://example.com"/>
      <updated>2026-07-01T10:00:00Z</updated>
      <id>https://example.com/atom</id>
      <entry>
        <title>Atom Entry One</title>
        <link href="https://example.com/entries/1"/>
        <id>entry-1</id>
        <updated>2026-07-01T10:00:00Z</updated>
        <summary>First Atom entry summary</summary>
      </entry>
    </feed>
    """

    // MARK: - Proof 1: rss.parse returns entries from RSS 2.0 XML

    /// Send `rss.parse` with RSS 2.0 XML. Core must return a feed title and
    /// ≥2 entries, each with non-empty title and link.
    func testRssParseReturnsEntriesFromRSS2XML() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "feedUrl": "https://example.com/rss.xml",
            "xml": Self.sampleRSS2XML,
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "rss.parse", params: params
        )

        XCTAssertEqual(data["title"] as? String, "RSS Proof Test Feed",
                       "feed title must match")
        XCTAssertEqual(data["feedUrl"] as? String, "https://example.com/rss.xml",
                       "feedUrl must echo back")
        guard let entries = data["entries"] as? [[String: Any]] else {
            XCTFail("rss.parse result must contain entries array"); return
        }
        XCTAssertGreaterThanOrEqual(entries.count, 2,
                                    "must return ≥2 entries for 2-item RSS feed")
        for entry in entries {
            XCTAssertFalse((entry["title"] as? String ?? "").isEmpty,
                           "each entry must have non-empty title")
            XCTAssertNotNil(entry["id"] ?? entry["link"],
                            "each entry must have id or link")
        }
    }

    // MARK: - Proof 2: rss.parse returns feed metadata

    /// Send `rss.parse` and verify feed-level metadata (title, siteUrl,
    /// description) is returned alongside entries.
    func testRssParseReturnsFeedMetadata() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "feedUrl": "https://example.com/rss.xml",
            "xml": Self.sampleRSS2XML,
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "rss.parse", params: params
        )

        XCTAssertEqual(data["title"] as? String, "RSS Proof Test Feed")
        XCTAssertNotNil(data["siteUrl"], "feed must have siteUrl")
        XCTAssertNotNil(data["description"], "feed must have description")
    }

    // MARK: - Proof 3: rss.parse parses Atom 1.0 XML

    /// Send `rss.parse` with Atom 1.0 XML. Core must return ≥1 entry with
    /// non-empty title.
    func testRssParseParsesAtomXML() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "feedUrl": "https://example.com/atom.xml",
            "xml": Self.sampleAtomXML,
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "rss.parse", params: params
        )

        XCTAssertEqual(data["title"] as? String, "Atom Proof Test Feed",
                       "Atom feed title must match")
        guard let entries = data["entries"] as? [[String: Any]] else {
            XCTFail("rss.parse must return entries for Atom feed"); return
        }
        XCTAssertGreaterThanOrEqual(entries.count, 1,
                                    "Atom feed must have ≥1 entry")
        XCTAssertEqual(entries[0]["title"] as? String, "Atom Entry One",
                       "first Atom entry title must match")
    }

    // MARK: - Proof 4: rss.parse rejects blank XML

    /// Send `rss.parse` with blank XML. Core must return an error (validation:
    /// XML must be non-empty).
    func testRssParseRejectsBlankXml() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "feedUrl": "https://example.com/rss.xml",
            "xml": "   ",
        ]

        XCTAssertThrowsError(
            try sendAndPollResult(
                runtime: runtime, method: "rss.parse", params: params
            )
        ) { error in
            // Core must reject blank XML with an error
            XCTAssertNotNil(error, "blank XML must produce an error")
        }
    }

    // MARK: - Proof 5: rss.parse entries have link and summary

    /// Send `rss.parse` and verify each entry has link and summary fields
    /// populated from the RSS XML.
    func testRssParseEntriesHaveLinkAndSummary() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "feedUrl": "https://example.com/rss.xml",
            "xml": Self.sampleRSS2XML,
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "rss.parse", params: params
        )

        guard let entries = data["entries"] as? [[String: Any]] else {
            XCTFail("rss.parse must return entries"); return
        }
        XCTAssertGreaterThanOrEqual(entries.count, 2)

        let firstEntry = entries[0]
        XCTAssertEqual(firstEntry["title"] as? String, "First Article",
                       "first entry title must match")
        XCTAssertEqual(firstEntry["link"] as? String, "https://example.com/articles/1",
                       "first entry link must match")
        XCTAssertNotNil(firstEntry["summary"],
                        "first entry must have summary")
    }

    // MARK: - Proof 6: rss.parse with feed_url uses URL for relative resolution

    /// Send `rss.parse` with a feed_url and XML containing relative links.
    /// Core should use the feed_url for relative URL resolution (if implemented).
    /// This test verifies the feed_url is at least echoed back correctly.
    func testRssParseEchoesFeedUrl() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let feedUrl = "https://proof.example.com/feed.xml"
        let params: [String: Any] = [
            "feedUrl": feedUrl,
            "xml": Self.sampleRSS2XML,
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "rss.parse", params: params
        )

        XCTAssertEqual(data["feedUrl"] as? String, feedUrl,
                       "feedUrl must be echoed back in result")
    }

    // MARK: - Proof 7: Core rss.parse drives subscription display (integration)

    /// Integration proof: Core `rss.parse` returns structured entries that
    /// can drive a subscription list UI. This test verifies the data flow:
    /// Core parse → entries → display-ready items.
    ///
    /// This is the "RSS 订阅成功" path (Path A minimal): Host fetches XML →
    /// Core parses → entries returned → Host can display subscription items.
    func testCoreRssParseDrivesSubscriptionDisplay() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "feedUrl": "https://example.com/rss.xml",
            "xml": Self.sampleRSS2XML,
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "rss.parse", params: params
        )

        // Extract entries and verify they are display-ready
        guard let entries = data["entries"] as? [[String: Any]] else {
            XCTFail("rss.parse must return entries for display"); return
        }
        XCTAssertGreaterThanOrEqual(entries.count, 2,
                                    "subscription must have ≥2 articles")

        // Each entry must have the minimum fields for display:
        // - title (for the list row)
        // - link or id (for navigation)
        // - summary (for preview)
        for (idx, entry) in entries.enumerated() {
            let title = entry["title"] as? String
            XCTAssertFalse(title?.isEmpty ?? true,
                           "entry \(idx) must have non-empty title for display")
            let link = entry["link"] as? String
            let id = entry["id"] as? String
            XCTAssertTrue(!(link?.isEmpty ?? true) || !(id?.isEmpty ?? true),
                          "entry \(idx) must have link or id for navigation")
        }

        // Feed title for the subscription header
        let feedTitle = data["title"] as? String
        XCTAssertFalse(feedTitle?.isEmpty ?? true,
                       "feed must have title for subscription header")
    }
}
