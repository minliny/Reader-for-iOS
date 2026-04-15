#if canImport(SwiftUI)
import SwiftUI
#endif
import ReaderShellValidation
#if canImport(SwiftUI)
@MainActor
public struct ReaderFlowFeatureView: View {
    @ObservedObject public var coordinator: ReadingFlowCoordinator
    public let environment: ReaderShellEnvironment
    public let moduleBoundary: ReaderModuleBoundary

    public init(
        coordinator: ReadingFlowCoordinator,
        environment: ReaderShellEnvironment = ReaderShellEnvironment(),
        moduleBoundary: ReaderModuleBoundary = ReaderModuleBoundary()
    ) {
        self.coordinator = coordinator
        self.environment = environment
        self.moduleBoundary = moduleBoundary
    }

    public var body: some View {
        let featureState = ReaderFlowFeatureState(
            coordinator: coordinator,
            boundary: moduleBoundary
        )

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    statusCard(featureState)

                    if moduleBoundary.canImportBookSource {
                        BookSourceImportView(coordinator: coordinator)
                    }

                    if featureState.hasSelectedBook || featureState.hasSelectedChapter || featureState.hasContentPage {
                        sessionSummary(featureState)
                    }

                    readerActions(featureState)

                }
                .padding(20)
            }
            .background(Color.platformGroupedBackground)
            .navigationTitle(environment.appEntry.appName)
        }
    }

    private func statusCard(_ featureState: ReaderFlowFeatureState) -> some View {
        ReaderStatusCardView(
            eyebrow: "Reader Flow",
            title: featureState.currentStageTitle,
            subtitle: "Core >= \(environment.appEntry.minimumCoreVersion)",
            items: progressItems
        )
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func sessionSummary(_ featureState: ReaderFlowFeatureState) -> some View {
        if let chapter = coordinator.selectedChapter, moduleBoundary.canReadContent {
            NavigationLink {
                ContentView(coordinator: coordinator, chapter: chapter)
            } label: {
                ReaderSessionSummaryView(
                    title: coordinator.selectedBook?.title ?? "未知书籍",
                    subtitle: chapter.chapterTitle,
                    actionTitle: "继续阅读",
                    action: {}
                )
                .allowsHitTesting(false) // 依靠外层 NavigationLink 触发跳转
            }
            .buttonStyle(.plain)
        } else if let book = coordinator.selectedBook, featureState.hasTOCItems {
            NavigationLink {
                TOCView(coordinator: coordinator, book: book)
            } label: {
                ReaderSessionSummaryView(
                    title: book.title,
                    subtitle: "等待选择章节",
                    actionTitle: "继续目录",
                    action: {}
                )
                .allowsHitTesting(false)
            }
            .buttonStyle(.plain)
        } else if featureState.hasSearchResults {
            NavigationLink {
                SearchView(coordinator: coordinator)
            } label: {
                ReaderSessionSummaryView(
                    title: "搜索结果",
                    subtitle: "选择书籍以继续",
                    actionTitle: "继续搜索",
                    action: {}
                )
                .allowsHitTesting(false)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private func readerActions(_ featureState: ReaderFlowFeatureState) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主链路入口")
                .font(.headline)

            if moduleBoundary.canSearch {
                if featureState.canStartSearch {
                    NavigationLink {
                        SearchView(coordinator: coordinator)
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

            if let selectedBook = coordinator.selectedBook, featureState.hasTOCItems {
                NavigationLink {
                    TOCView(coordinator: coordinator, book: selectedBook)
                } label: {
                    actionRow(
                        title: "继续目录",
                        subtitle: selectedBook.title
                    )
                }
                .buttonStyle(.plain)
            }

            if let selectedChapter = coordinator.selectedChapter, moduleBoundary.canReadContent {
                NavigationLink {
                    ContentView(coordinator: coordinator, chapter: selectedChapter)
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
#endif
