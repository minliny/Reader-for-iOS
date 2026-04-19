import SwiftUI
import ReaderShellValidation

@MainActor
public struct ReaderFlowFeatureView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    public var navigationState: AppNavigationState
    public let environment: ReaderShellEnvironment
    public let moduleBoundary: ReaderModuleBoundary

    public init(
        coordinator: ReadingFlowCoordinator,
        navigationState: AppNavigationState,
        environment: ReaderShellEnvironment = ReaderShellEnvironment(),
        moduleBoundary: ReaderModuleBoundary = ReaderModuleBoundary()
    ) {
        self.coordinator = coordinator
        self.navigationState = navigationState
        self.environment = environment
        self.moduleBoundary = moduleBoundary
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                statusCard

                if moduleBoundary.canImportBookSource {
                    BookSourceImportView(coordinator: coordinator)
                }

                if coordinator.selectedBook != nil || coordinator.selectedChapter != nil || coordinator.contentPage != nil {
                    sessionSummary
                }

                readerActions
            }
            .padding(20)
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle(environment.appEntry.appName)
    }

    private var statusCard: some View {
        ReaderStatusCardView(
            eyebrow: "Reader Flow",
            title: currentStageTitle,
            subtitle: "Core >= \(environment.appEntry.minimumCoreVersion)",
            items: progressItems
        )
        .padding(.bottom, 8)
    }

    private var currentStageTitle: String {
        if coordinator.isLoading {
            if coordinator.selectedChapter != nil {
                return "正文加载中"
            }
            if coordinator.selectedBook != nil {
                return "目录加载中"
            }
            if coordinator.selectedSource != nil {
                return "搜索中"
            }
            return "书源导入中"
        }

        if coordinator.currentError != nil {
            if coordinator.selectedChapter != nil {
                return "正文加载失败"
            }
            if coordinator.selectedBook != nil {
                return "目录加载失败"
            }
            if coordinator.selectedSource != nil {
                return "搜索失败"
            }
            return "书源导入失败"
        }

        if coordinator.contentPage != nil {
            return "正文已加载"
        }

        if coordinator.selectedChapter != nil {
            return "章节已选择"
        }

        if !coordinator.tocItems.isEmpty {
            return "目录已加载"
        }

        if coordinator.selectedBook != nil {
            return "书籍已选择"
        }

        if !coordinator.searchResults.isEmpty {
            return "搜索结果已就绪"
        }

        if moduleBoundary.canSearch && coordinator.selectedSource != nil {
            return "可开始搜索"
        }

        return "等待导入书源"
    }

    @ViewBuilder
    private var sessionSummary: some View {
        if let chapter = coordinator.selectedChapter, moduleBoundary.canReadContent {
            Button {
                navigationState.push(.content(chapterTitle: chapter.chapterTitle))
            } label: {
                ReaderSessionSummaryView(
                    title: coordinator.selectedBook?.title ?? "未知书籍",
                    subtitle: chapter.chapterTitle,
                    actionTitle: "继续阅读",
                    action: {}
                )
            }
            .buttonStyle(.plain)
        } else if let book = coordinator.selectedBook, !coordinator.tocItems.isEmpty {
            Button {
                navigationState.push(.toc(bookTitle: book.title, bookAuthor: book.author))
            } label: {
                ReaderSessionSummaryView(
                    title: book.title,
                    subtitle: "等待选择章节",
                    actionTitle: "继续目录",
                    action: {}
                )
            }
            .buttonStyle(.plain)
        } else if !coordinator.searchResults.isEmpty {
            Button {
                navigationState.push(.search)
            } label: {
                ReaderSessionSummaryView(
                    title: "搜索结果",
                    subtitle: "选择书籍以继续",
                    actionTitle: "继续搜索",
                    action: {}
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var readerActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主链路入口")
                .font(.headline)

            if moduleBoundary.canSearch {
                if moduleBoundary.canSearch && coordinator.selectedSource != nil {
                    Button {
                        navigationState.push(.search)
                    } label: {
                        actionRow(
                            title: "开始搜索",
                            subtitle: "进入 Search -> TOC -> Content 最小主链路"
                        )
                    }
                    .buttonStyle(.plain)
                } else {
                    actionRow(
                        title: "开始搜索",
                        subtitle: "请先导入并选中一个书源"
                    )
                }
            }

            if let selectedBook = coordinator.selectedBook, !coordinator.tocItems.isEmpty {
                Button {
                    navigationState.push(.toc(bookTitle: selectedBook.title, bookAuthor: selectedBook.author))
                } label: {
                    actionRow(
                        title: "继续目录",
                        subtitle: selectedBook.title
                    )
                }
                .buttonStyle(.plain)
            }

            if let selectedChapter = coordinator.selectedChapter, moduleBoundary.canReadContent {
                Button {
                    navigationState.push(.content(chapterTitle: selectedChapter.chapterTitle))
                } label: {
                    actionRow(
                        title: "继续阅读",
                        subtitle: selectedChapter.chapterTitle
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func actionRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.platformSecondaryGroupedBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    private var progressItems: [ReaderStatusCardItem] {
        var items: [ReaderStatusCardItem] = []

        if let source = coordinator.selectedSource?.bookSourceName {
            items.append(ReaderStatusCardItem(label: "书源", value: source))
        }

        if let book = coordinator.selectedBook?.title {
            items.append(ReaderStatusCardItem(label: "书籍", value: book))
        }

        if let chapter = coordinator.selectedChapter?.chapterTitle {
            items.append(ReaderStatusCardItem(label: "章节", value: chapter))
        }

        if coordinator.contentPage != nil {
            items.append(ReaderStatusCardItem(label: "正文", value: "已加载"))
        }

        return items
    }
}
