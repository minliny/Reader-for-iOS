import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

public struct TOCView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    public let book: SearchResultItem

    public init(coordinator: ReadingFlowCoordinator, book: SearchResultItem) {
        self.coordinator = coordinator
        self.book = book
    }

    public var body: some View {
        DemoBackScreen(title: "目录") {
            directoryCard
        }
        .task {
            if coordinator.tocItems.isEmpty {
                await coordinator.selectBook(book)
            }
        }
    }

    private var directoryCard: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.bookDirectoryFullGap) {
            header
            tocContent
        }
        .padding(.top, ReaderDesignTokens.bookDirectoryFullTopPadding)
        .padding(.horizontal, ReaderDesignTokens.bookDirectoryFullHorizontalPadding)
        .padding(.bottom, ReaderDesignTokens.bookDirectoryFullBottomPadding)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                )
                .shadow(
                    color: SwiftUI.Color(red: 80/255, green: 67/255, blue: 52/255, opacity: 0.08),
                    radius: 12,
                    x: 0,
                    y: 8
                )
        )
        .padding(.top, ReaderDesignTokens.bookDirectoryListTopPadding - ReaderDesignTokens.demoContentVerticalPadding)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("目录")
    }

    private var header: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(.readerModuleDirectory, size: 22, accessibilityLabel: "目录")
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .lineLimit(1)
                Text("\(coordinator.selectedSource?.bookSourceName ?? "未选中书源") · 共 \(coordinator.tocItems.count) 章")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDirectoryHeaderMinHeight, alignment: .leading)
        .padding(.horizontal, 2)
    }

    @ViewBuilder
    private var tocContent: some View {
        if coordinator.isLoading {
            ReaderStateBanner(
                icon: .refresh,
                title: "加载目录中",
                messages: ["正在从当前书源获取章节列表。"]
            )
        } else if let error = coordinator.currentError {
            ReaderStateCard(
                icon: .warning,
                title: "目录加载失败",
                subtitle: error.message,
                actionTitle: "重新加载"
            ) {
                Task { await coordinator.selectBook(book) }
            }
        } else if coordinator.tocItems.isEmpty {
            ReaderStateCard(
                icon: .readerModuleDirectory,
                title: "暂无目录",
                subtitle: "当前书籍还没有可展示的章节列表。",
                actionTitle: "重新加载"
            ) {
                Task { await coordinator.selectBook(book) }
            }
        } else {
            chapterRows
        }
    }

    private var chapterRows: some View {
        VStack(spacing: 0) {
            ForEach(Array(coordinator.tocItems.enumerated()), id: \.element.chapterURL) { index, chapter in
                NavigationLink {
                    ContentView(coordinator: coordinator, chapter: chapter)
                } label: {
                    TOCChapterDemoRow(
                        chapter: chapter,
                        displayIndex: index + 1,
                        isCurrent: coordinator.selectedChapter?.chapterURL == chapter.chapterURL
                    )
                }
                .buttonStyle(.plain)

                if chapter.chapterURL != coordinator.tocItems.last?.chapterURL {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .background(ReaderDesignTokens.Color.surface.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))
        .overlay(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                .stroke(ReaderDesignTokens.Color.readerModuleNavBorder, lineWidth: 1)
        )
    }
}

struct TOCChapterDemoRow: View {
    let chapter: TOCItem
    let displayIndex: Int
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: ReaderDesignTokens.bookGroupRowGap) {
            Text(chapter.chapterTitle)
                .font(.system(size: 14, weight: isCurrent ? .heavy : .regular))
                .foregroundColor(isCurrent ? ReaderDesignTokens.Color.primaryDark : .primary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ReaderDesignTokens.bookDirectoryMarkerGap) {
                markerText(String(format: "%02d", displayIndex))
                ReaderIcon(.chevron, size: 14, accessibilityLabel: "打开章节")
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: ReaderDesignTokens.bookDirectoryMarkerSize, height: ReaderDesignTokens.bookDirectoryMarkerSize)
                    .background(Capsule().fill(ReaderDesignTokens.Color.chipBackground.opacity(0.82)))
            }
            .frame(width: ReaderDesignTokens.bookDirectoryMarkerColumnWidth, alignment: .trailing)
        }
        .padding(.horizontal, ReaderDesignTokens.bookDirectoryFullHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookDirectoryRowMinHeight, alignment: .leading)
        .background(isCurrent ? ReaderDesignTokens.Color.primary.opacity(0.08) : SwiftUI.Color.clear)
        .contentShape(Rectangle())
        .accessibilityLabel(chapter.chapterTitle)
    }

    private func markerText(_ value: String) -> some View {
        Text(value)
            .font(.system(size: 10, weight: .heavy).monospacedDigit())
            .foregroundColor(isCurrent ? .white : ReaderDesignTokens.Color.primaryDark)
            .frame(width: ReaderDesignTokens.bookDirectoryMarkerSize, height: ReaderDesignTokens.bookDirectoryMarkerSize)
            .background(
                Capsule()
                    .fill(isCurrent ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.primary.opacity(0.12))
            )
    }
}
