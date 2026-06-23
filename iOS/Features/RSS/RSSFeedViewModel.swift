import Foundation
import ReaderAppPersistence
import ReaderCoreModels
import ReaderShellValidation

public enum RSSFeedState: Equatable {
    case idle
    case loading
    case loaded(summary: CoreRSSFeedSummary)
    case empty(summary: CoreRSSFeedSummary)
    case failed(message: String)
}

@MainActor
public final class RSSFeedViewModel: ObservableObject {
    @Published public var feedURL: String
    @Published public var feedName: String
    @Published public var feedState: RSSFeedState = .idle
    @Published public var subscriptions: [RSSSource] = []
    @Published public var selectedSubscriptionURL: String?

    private let loader: any CoreRSSFeedLoading
    private let store: RSSSubscriptionStore

    public init(
        feedURL: String = "",
        feedName: String = "",
        loader: any CoreRSSFeedLoading = CoreRSSFeedService(),
        store: RSSSubscriptionStore = .shared
    ) {
        self.feedURL = feedURL
        self.feedName = feedName
        self.loader = loader
        self.store = store
    }

    public func loadSubscriptions() async {
        do {
            subscriptions = try await store.load()
            if feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               let first = subscriptions.first(where: \.enabled) ?? subscriptions.first {
                selectSubscription(first)
            }
        } catch {
            feedState = .failed(message: "Failed to load RSS subscriptions: \(error.localizedDescription)")
        }
    }

    public func refresh() async {
        let source = makeSource()
        feedState = .loading
        do {
            let summary = try await loader.fetchAndParse(source: source)
            apply(summary)
            await persistSubscription(summary.source)
        } catch {
            feedState = .failed(message: error.localizedDescription)
        }
    }

    public func saveCurrentSubscription() async {
        let source = makeSource()
        guard !source.url.isEmpty else {
            feedState = .failed(message: "Feed URL is required.")
            return
        }

        do {
            try await store.addOrUpdate(source)
            subscriptions = try await store.load()
            selectedSubscriptionURL = source.url
        } catch {
            feedState = .failed(message: "Failed to save RSS subscription: \(error.localizedDescription)")
        }
    }

    public func selectSubscription(_ source: RSSSource) {
        feedURL = source.url
        feedName = source.name ?? ""
        selectedSubscriptionURL = source.url
    }

    public func load(data: Data, source: RSSSource) async {
        feedURL = source.url
        feedName = source.name ?? ""
        feedState = .loading
        do {
            let summary = try await loader.parseFeed(data: data, source: source)
            apply(summary)
            await persistSubscription(summary.source)
        } catch {
            feedState = .failed(message: error.localizedDescription)
        }
    }

    private func makeSource() -> RSSSource {
        RSSSource(
            url: feedURL.trimmingCharacters(in: .whitespacesAndNewlines),
            name: feedName.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            enableJs: false
        )
    }

    private func apply(_ summary: CoreRSSFeedSummary) {
        if summary.items.isEmpty {
            feedState = .empty(summary: summary)
        } else {
            feedState = .loaded(summary: summary)
        }
    }

    private func persistSubscription(_ source: RSSSource) async {
        var stored = source
        stored.lastFetchedAt = Date()
        do {
            try await store.addOrUpdate(stored)
            subscriptions = try await store.load()
            selectedSubscriptionURL = stored.url
        } catch {
            // Keep the parsed feed visible even if local subscription persistence fails.
        }
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
