import SwiftUI
import ReaderCoreModels

public struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel
    @StateObject private var ttsPlayer = ReaderTTSPlayer()
    @State private var showSettings = false
    @State private var showTTS = false
    @State private var scrollOffset: CGFloat = 0
    @SwiftUI.Environment(\.dismiss) private var dismiss

    public init(
        chapterURL: String,
        chapterTitle: String,
        chapterList: [TOCItem] = [],
        currentChapterIndex: Int = 0,
        bookID: String? = nil,
        sourceID: String? = nil
    ) {
        self._viewModel = StateObject(wrappedValue: ReaderViewModel(
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            chapterList: chapterList,
            currentChapterIndex: currentChapterIndex,
            bookID: bookID,
            sourceID: sourceID
        ))
    }

    public var body: some View {
        ZStack {
            contentBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                progressSurface
                readerStateView
                actionBar
            }
        }
        .navigationTitle(viewModel.chapterTitle)
#if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
#endif
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showTTS.toggle() }) {
                    Image(systemName: "speaker.wave.2")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "textformat.size")
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsPanel(
                displaySettings: $viewModel.displaySettings,
                onDismiss: {
                    viewModel.saveSettings()
                    showSettings = false
                }
            )
            .presentationDetents([.medium])
        }
        .onAppear {
            Task { await viewModel.loadContent() }
        }
        .onDisappear {
            viewModel.saveSettings()
            ttsPlayer.stop()
        }
        .safeAreaInset(edge: .bottom) {
            if showTTS {
                ReaderTTSControlView(
                    player: ttsPlayer,
                    contentText: currentContentText
                )
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private var currentContentText: String {
        switch viewModel.readerState {
        case .loaded(let content), .partial(let content, _):
            return content.content
        default:
            return ""
        }
    }

    // MARK: - Subviews

    @ViewBuilder
    private var contentBackground: some View {
        Color(hex: viewModel.displaySettings.backgroundMode.backgroundColor)
    }

    @ViewBuilder
    private var progressSurface: some View {
        if viewModel.totalChapterCount > 0 {
            ReaderProgressSurfaceView(
                chapterIndex: viewModel.currentChapterIndex,
                chapterCount: viewModel.totalChapterCount,
                progressPercentage: viewModel.readingProgress
            )
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    @ViewBuilder
    private var readerStateView: some View {
        switch viewModel.readerState {
        case .idle:
            idleStateView

        case .loading:
            loadingStateView

        case .loaded(let content):
            loadedContentView(content)

        case .empty:
            emptyStateView

        case .failed(let message):
            failedStateView(message)

        case .unsupported(let reason):
            unsupportedStateView(reason)

        case .partial(let content, let warnings):
            partialContentView(content, warnings: warnings)
        }
    }

    @ViewBuilder
    private var actionBar: some View {
        if case .loaded = viewModel.readerState {
            ReaderStageActionBar(
                onPrevious: viewModel.canGoPreviousChapter
                    ? { viewModel.goPreviousChapter() } : nil,
                onNext: viewModel.canGoNextChapter
                    ? { viewModel.goNextChapter() } : nil,
                onReload: { Task { await viewModel.reload() } }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        } else if case .partial = viewModel.readerState {
            ReaderStageActionBar(
                onPrevious: viewModel.canGoPreviousChapter
                    ? { viewModel.goPreviousChapter() } : nil,
                onNext: viewModel.canGoNextChapter
                    ? { viewModel.goNextChapter() } : nil,
                onReload: { Task { await viewModel.reload() } }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        } else if case .failed = viewModel.readerState {
            ReaderStageActionBar(
                onPrevious: nil,
                onNext: nil,
                onReload: { Task { await viewModel.reload() } }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        } else if case .empty = viewModel.readerState {
            ReaderStageActionBar(
                onPrevious: viewModel.canGoPreviousChapter
                    ? { viewModel.goPreviousChapter() } : nil,
                onNext: viewModel.canGoNextChapter
                    ? { viewModel.goNextChapter() } : nil,
                onReload: { Task { await viewModel.reload() } }
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: - State Views

    private var idleStateView: some View {
        Text("Loading...")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var loadingStateView: some View {
        ProgressView("Loading content...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func loadedContentView(_ content: ContentPage) -> some View {
        ScrollView {
            contentText(text: content.content)
                .background(
                    GeometryReader { geo in
                        Color.clear.preference(
                            key: ScrollOffsetPreferenceKey.self,
                            value: geo.frame(in: .named("scroll")).minY
                        )
                    }
                )
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
            trackScrollProgress(offset: offset)
        }
    }

    private func partialContentView(_ content: ContentPage, warnings: [String]) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Label("Partial Content", systemImage: "exclamationmark.circle.fill")
                    .foregroundStyle(.yellow)
                    .font(.subheadline.weight(.semibold))

                ForEach(warnings, id: \.self) {
                    Text("⚠️ \($0)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.yellow.opacity(0.1))

            ScrollView {
                contentText(text: content.content)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("No Content")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Chapter content is unavailable")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failedStateView(_ message: String) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Label("Load Failed", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    private func unsupportedStateView(_ reason: String) -> some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(alignment: .leading, spacing: 8) {
                Label("Unsupported", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline.weight(.semibold))

                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 16)
            Spacer()
        }
    }

    // MARK: - Shared Content Rendering

    private func contentText(text: String) -> some View {
        Text(text)
            .font(.custom(viewModel.displaySettings.fontFamily, size: CGFloat(viewModel.displaySettings.fontSize)))
            .foregroundColor(Color(hex: viewModel.displaySettings.backgroundMode.textColor))
            .lineSpacing(CGFloat(viewModel.displaySettings.lineSpacing))
            .padding(EdgeInsets(
                top: viewModel.displaySettings.verticalPadding,
                leading: viewModel.displaySettings.horizontalPadding,
                bottom: viewModel.displaySettings.verticalPadding + viewModel.displaySettings.paragraphSpacing,
                trailing: viewModel.displaySettings.horizontalPadding
            ))
            .frame(maxWidth: .infinity)
    }

    // MARK: - Helpers

    private func trackScrollProgress(offset: CGFloat) {
        scrollOffset = offset
    }
}

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetPreferenceKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if DEBUG
extension ReaderView {
    /// Debug-only fixture init — for tab bar hiding verification
    public init(fixtureChapterTitle: String, fixtureContent: String) {
        self._viewModel = StateObject(wrappedValue: ReaderViewModel(
            chapterURL: "debug://fixture/chapter",
            chapterTitle: fixtureChapterTitle,
            fixtureContent: fixtureContent
        ))
    }
}
#endif
