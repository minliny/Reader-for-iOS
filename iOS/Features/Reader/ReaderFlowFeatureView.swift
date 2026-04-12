import SwiftUI
import ReaderShellValidation

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
                VStack(alignment: .leading, spacing: 20) {
                    statusCard(featureState)

                    if moduleBoundary.canImportBookSource {
                        BookSourceImportView(coordinator: coordinator)
                    }

                    readerActions(featureState)

                    if featureState.hasSelectedBook || featureState.hasSelectedChapter || featureState.hasContentPage {
                        progressCard
                    }
                }
                .padding(20)
            }
            .navigationTitle(environment.appEntry.appName)
        }
    }

    private func statusCard(_ featureState: ReaderFlowFeatureState) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Reader Flow")
                .font(.headline)

            Text(featureState.currentStageTitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text("Core >= \(environment.appEntry.minimumCoreVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
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

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("当前进度")
                .font(.headline)

            if let source = coordinator.selectedSource {
                Text("书源：\(source.bookSourceName)")
            }

            if let book = coordinator.selectedBook {
                Text("书籍：\(book.title)")
            }

            if let chapter = coordinator.selectedChapter {
                Text("章节：\(chapter.chapterTitle)")
            }

            if coordinator.contentPage != nil {
                Text("正文：已加载")
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private func actionRow(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.body.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
