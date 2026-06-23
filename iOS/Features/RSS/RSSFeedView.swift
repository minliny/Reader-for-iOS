import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

public struct RSSFeedView: View {
    @StateObject private var viewModel: RSSFeedViewModel

    @MainActor
    public init() {
        self._viewModel = StateObject(wrappedValue: RSSFeedViewModel())
    }

    @MainActor
    public init(viewModel: RSSFeedViewModel) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        List {
            subscriptionsSection
            sourceSection
            stateSection
        }
        .navigationTitle("RSS 订阅")
        .task {
            await viewModel.loadSubscriptions()
        }
    }

    @ViewBuilder
    private var subscriptionsSection: some View {
        if !viewModel.subscriptions.isEmpty {
            Section("已保存订阅") {
                ForEach(viewModel.subscriptions, id: \.url) { source in
                    Button {
                        viewModel.selectSubscription(source)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.name ?? source.url)
                                    .font(.body)
                                Text(source.url)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if viewModel.selectedSubscriptionURL == source.url {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var sourceSection: some View {
        Section("订阅源") {
            feedURLField
            TextField("Name", text: $viewModel.feedName)
            HStack {
                Button {
                    Task { await viewModel.saveCurrentSubscription() }
                } label: {
                    Label("保存", systemImage: "bookmark")
                }
                .disabled(viewModel.feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Spacer()

                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Label("刷新", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.feedURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    @ViewBuilder
    private var feedURLField: some View {
#if os(iOS)
        TextField("Feed URL", text: $viewModel.feedURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
#else
        TextField("Feed URL", text: $viewModel.feedURL)
#endif
    }

    @ViewBuilder
    private var stateSection: some View {
        switch viewModel.feedState {
        case .idle:
            Section {
                Label("未加载", systemImage: "dot.radiowaves.left.and.right")
                    .foregroundStyle(.secondary)
            }
        case .loading:
            Section {
                ProgressView("刷新中...")
            }
        case .loaded(let summary):
            summarySection(summary)
            itemSection(summary.items)
        case .empty(let summary):
            summarySection(summary)
            Section {
                Label("没有订阅条目", systemImage: "tray")
                    .foregroundStyle(.secondary)
            }
        case .failed(let message):
            Section {
                Label(message, systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
            }
        }
    }

    private func summarySection(_ summary: CoreRSSFeedSummary) -> some View {
        Section("解析结果") {
            LabeledContent("格式", value: summary.format.rawValue.uppercased())
            LabeledContent("条目", value: "\(summary.items.count)")
            if let nextPageURL = summary.nextPageURL {
                LabeledContent("下一页", value: nextPageURL)
            }
            ForEach(summary.diagnostics.prefix(3), id: \.self) { diagnostic in
                Text(diagnostic)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func itemSection(_ items: [SubscriptionItem]) -> some View {
        Section("最新条目") {
            ForEach(items, id: \.link) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title)
                        .font(.headline)
                    if let author = item.author, !author.isEmpty {
                        Text(author)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if let summary = item.summary, !summary.isEmpty {
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    Text(item.link)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
            }
        }
    }
}
