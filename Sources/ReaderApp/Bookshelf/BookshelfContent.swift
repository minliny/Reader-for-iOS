import ReaderCoreBridge
import ReaderDesign
import SwiftUI

enum ShelfPresentationMode: String {
    case list
    case cover
}

struct BookshelfContent: View {
    let books: [BookshelfEntryData]?
    let state: ReaderPageState?
    let recovery: ShelfRecovery?
    let onOpen: (BookshelfEntryData) -> Void
    let onRemove: (BookshelfEntryData) -> Void
    let onRetry: () -> Void
    var onRetryGeneration: ((Int) -> Void)? = nil
    var onRecovery: (Int, Int) -> Void = { _, _ in }
    var onSelectWide: ((BookshelfEntryData) -> Void)? = nil
    var recoveryAvailable = true
    var onSearch: () -> Void = {}
    var onMore: () -> Void = {}
    var onImport: () -> Void = {}
    var onSettings: () -> Void = {}
    var onDownloads: () -> Void = {}
    var onSources: () -> Void = {}
    var initialPresentation: ShelfPresentationMode = .list
    var initiallyShowingMore = false

    @Environment(\.readerTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var presentation: ShelfPresentationMode = .list
    @State private var showingMore = false

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= CGFloat(ReaderDesignMetrics.wideBreakpoint)
            VStack(spacing: 0) {
                shelfHeader
                shelfBody(width: geometry.size.width, wide: wide)
            }
            .background(theme.background)
            .overlay(alignment: .top) {
                if let recovery {
                    RecoveryNotice(title: recovery.title, message: recovery.message,
                                   generation: recovery.generation, action: recovery.action,
                                   availability: recoveryAvailable, onAction: onRecovery)
                        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
                        .padding(.top, 4)
                }
            }
            .sheet(isPresented: $showingMore) {
                BookshelfMoreSheet(onImport: { showingMore = false; onImport() },
                                   onDownloads: { showingMore = false; onDownloads() },
                                   onSettings: { showingMore = false; onSettings() },
                                   onSources: { showingMore = false; onSources() })
                    .presentationDetents([.height(330), .medium])
                    .presentationDragIndicator(.visible)
            }
        }
        .accessibilityIdentifier("bookshelf-content")
        .task {
            presentation = initialPresentation
            if initiallyShowingMore { showingMore = true }
        }
    }

    private var shelfHeader: some View {
        HStack(alignment: .center, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            Text("书架")
                .readerTypography(ReaderDesignMetrics.appTitle, relativeTo: .largeTitle)
                .foregroundStyle(theme.primaryText)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: 4)
            Button(action: onSearch) {
                ReaderIcon(ReaderIconRegistry.search, squareSize: 22)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("搜索书籍")
            .accessibilityIdentifier("shelf-search")
            Button { showingMore = true; onMore() } label: {
                ReaderIcon(ReaderIconRegistry.more, squareSize: 22)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("书架操作")
            .accessibilityIdentifier("shelf-more")
        }
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        .padding(.top, 10)
        .padding(.bottom, 2)
    }

    @ViewBuilder
    private func shelfBody(width: CGFloat, wide: Bool) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
                if let books, !books.isEmpty {
                    if let current = books.first(where: { $0.readingPosition != nil || $0.readProgress ?? 0 > 0 }) {
                        ShelfContinueCard(entry: current, onOpen: { onOpen(current) })
                    }
                    ShelfSectionHeader(bookCount: books.count, presentation: $presentation,
                                       enabled: true, onFilter: {})
                    if presentation == .list {
                        shelfList(books, narrow: width < CGFloat(ReaderDesignMetrics.narrowBreakpoint), wide: wide)
                    } else {
                        shelfGrid(books, wide: wide)
                    }
                } else if let state {
                    switch state {
                    case .empty:
                        ShelfSectionHeader(bookCount: 0, presentation: $presentation,
                                           enabled: false, onFilter: {})
                        ShelfEmptyCard(onImport: onImport, onSearch: onSearch)
                    case .loading, .failed:
                        PageState(state: state) { generation in
                            if let onRetryGeneration { onRetryGeneration(generation) } else { onRetry() }
                        }
                        .frame(minHeight: 420)
                    }
                } else if let books, books.isEmpty {
                    ShelfSectionHeader(bookCount: 0, presentation: $presentation,
                                       enabled: false, onFilter: {})
                    ShelfEmptyCard(onImport: onImport, onSearch: onSearch)
                }
                Color.clear.frame(height: 92)
            }
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
            .padding(.top, CGFloat(ReaderDesignMetrics.spaceSmall))
            .frame(maxWidth: wide ? 980 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .accessibilityIdentifier("shelf-scroll")
    }

    private func shelfList(_ entries: [BookshelfEntryData], narrow: Bool, wide: Bool) -> some View {
        let columns = wide ? [GridItem(.flexible(), spacing: CGFloat(ReaderDesignMetrics.spaceSmall)),
                              GridItem(.flexible(), spacing: CGFloat(ReaderDesignMetrics.spaceSmall))] :
            [GridItem(.flexible())]
        return LazyVGrid(columns: columns, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            ForEach(entries.map(IdentifiedShelfEntry.init)) { item in
                let entry = item.entry
                ShelfBookRow(entry: entry, narrow: narrow, selected: false,
                             onOpen: { onOpen(entry) }, onRemove: { onRemove(entry) })
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityIdentifier("shelf-list")
    }

    private func shelfGrid(_ entries: [BookshelfEntryData], wide: Bool) -> some View {
        let count = wide ? 4 : 3
        let columns = Array(repeating: GridItem(.flexible(), spacing: CGFloat(ReaderDesignMetrics.spaceSmall)), count: count)
        return LazyVGrid(columns: columns, spacing: CGFloat(ReaderDesignMetrics.spaceMedium)) {
            ForEach(entries.map(IdentifiedShelfEntry.init)) { item in
                ShelfBookGridCard(entry: item.entry, onOpen: { onOpen(item.entry) })
            }
        }
        .accessibilityIdentifier("shelf-cover-grid")
    }
}

private struct IdentifiedShelfEntry: Identifiable {
    let entry: BookshelfEntryData
    var id: BookIdentity { BookIdentity(entry) }
}

private struct ShelfSectionHeader: View {
    let bookCount: Int
    @Binding var presentation: ShelfPresentationMode
    let enabled: Bool
    let onFilter: () -> Void
    @Environment(\.readerTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            Text("我的书架")
                .readerTypography(ReaderDesignMetrics.pageTitle, relativeTo: .headline)
                .foregroundStyle(theme.primaryText)
            Text("\(bookCount) 本")
                .readerTypography(ReaderDesignMetrics.rowDetail, relativeTo: .caption)
                .foregroundStyle(theme.secondaryText)
                .monospacedDigit()
            Spacer(minLength: 4)
            HStack(spacing: 2) {
                segment("list", icon: ReaderIconRegistry.directory, selected: presentation == .list) { presentation = .list }
                segment("cover", icon: ReaderIconRegistry.shelf, selected: presentation == .cover) { presentation = .cover }
            }
            .padding(3)
            .frame(height: 34)
            .background(theme.field, in: Capsule())
            .overlay(Capsule().stroke(theme.outline, lineWidth: 1))
            Button(action: onFilter) {
                ZStack(alignment: .topTrailing) {
                    ReaderIcon(ReaderIconRegistry.filter, squareSize: 20)
                        .frame(width: 34, height: 34)
                    if enabled && bookCount > 0 {
                        Circle().fill(theme.accentFill).frame(width: 6, height: 6)
                    }
                }
            }
            .buttonStyle(.plain)
            .opacity(enabled ? 1 : 0.42)
            .disabled(!enabled)
            .accessibilityLabel("筛选书架")
        }
        .frame(minHeight: 40)
    }

    private func segment(_ id: String, icon: ReaderIconMapping, selected: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ReaderIcon(icon, squareSize: 18)
                .frame(width: 30, height: 28)
                .foregroundStyle(selected ? theme.accent : theme.secondaryText)
                .background(selected ? theme.surface : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityIdentifier("shelf-view-\(id)")
    }
}

private struct ShelfContinueCard: View {
    let entry: BookshelfEntryData
    let onOpen: () -> Void
    @Environment(\.readerTheme) private var theme
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) { cover; metadata }
                    continueButton.frame(maxWidth: .infinity)
                }
            } else {
                HStack(spacing: 12) { cover; metadata; continueButton }
            }
        }
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .accessibilityIdentifier("shelf-continue-card")
    }

    private var cover: some View { BookCover(entry: entry).frame(width: 56, height: 78) }

    private var metadata: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("继续阅读").readerTypography(ReaderDesignMetrics.sectionHeading, relativeTo: .caption)
                .foregroundStyle(theme.accent)
            Text(entry.title).readerTypography(ReaderDesignMetrics.shelfTitle, relativeTo: .body)
                .foregroundStyle(theme.primaryText).lineLimit(2)
            Text(entry.author.isEmpty ? "本地书籍" : entry.author)
                .readerTypography(ReaderDesignMetrics.shelfAuthor, relativeTo: .caption)
                .foregroundStyle(theme.secondaryText).lineLimit(1)
            Text(entry.currentChapterTitle ?? "已保存阅读位置")
                .readerTypography(ReaderDesignMetrics.shelfChapter, relativeTo: .caption)
                .foregroundStyle(theme.secondaryText).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var continueButton: some View {
        Button("继续", action: onOpen)
            .readerTypography(ReaderDesignMetrics.mainTabLabel, relativeTo: .caption)
            .foregroundStyle(theme.onAccent)
            .frame(minWidth: typeSize.isAccessibilitySize ? 80 : 60, minHeight: 36)
            .background(theme.accentFill, in: Capsule())
            .buttonStyle(.plain)
    }
}

private struct ShelfEmptyCard: View {
    let onImport: () -> Void
    let onSearch: () -> Void
    @Environment(\.readerTheme) private var theme

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "books.vertical.fill")
                .font(.system(size: 36, weight: .medium))
                .foregroundStyle(theme.primaryText)
                .accessibilityHidden(true)
            Text("书架还是空的").readerTypography(ReaderDesignMetrics.pageTitle, relativeTo: .headline)
                .foregroundStyle(theme.primaryText)
            Text("导入本地书籍或通过搜索加入书架。")
                .readerTypography(ReaderDesignMetrics.rowDetail, relativeTo: .body)
                .foregroundStyle(theme.secondaryText)
                .multilineTextAlignment(.center)
            Button("导入本地书籍", action: onImport)
                .readerTypography(ReaderDesignMetrics.rowLabel)
                .foregroundStyle(theme.onAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(theme.accentFill, in: Capsule())
                .buttonStyle(.plain)
                .accessibilityIdentifier("shelf-empty-import")
            Button("搜索书籍", action: onSearch)
                .readerTypography(ReaderDesignMetrics.rowLabel)
                .foregroundStyle(theme.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(theme.surface, in: Capsule())
                .overlay(Capsule().stroke(theme.outline, lineWidth: 1))
                .buttonStyle(.plain)
                .accessibilityIdentifier("shelf-empty-search")
        }
        .padding(20)
        .frame(maxWidth: 352)
        .background(theme.surface, in: .rect(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .overlay(RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)).stroke(theme.outline, lineWidth: 1))
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
        .accessibilityIdentifier("shelf-empty-card")
    }
}

private struct BookshelfMoreSheet: View {
    let onImport: () -> Void
    let onDownloads: () -> Void
    let onSettings: () -> Void
    let onSources: () -> Void
    @Environment(\.readerTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("书架操作").readerTypography(ReaderDesignMetrics.pageTitle, relativeTo: .headline)
                .foregroundStyle(theme.primaryText)
                .padding(.bottom, 12)
            action("批量管理", icon: "checklist", enabled: false) {}
            action("本地导入", icon: "doc.badge.plus", enabled: true, onImport)
            action("检查更新", icon: "arrow.clockwise", enabled: false) {}
            action("下载管理", icon: "arrow.down.circle", enabled: true, onDownloads)
            action("书源管理", icon: "books.vertical", enabled: true, onSources)
            action("书架设置", icon: "slider.horizontal.3", enabled: true, onSettings)
            action("书架数据管理", icon: "externaldrive", enabled: false) {}
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background)
        .accessibilityIdentifier("shelf-more-sheet")
    }

    private func action(_ title: String, icon: String, enabled: Bool,
                        _ handler: @escaping () -> Void) -> some View {
        Button(action: handler) {
            Label(enabled ? title : "\(title)（暂未开放）", systemImage: icon)
                .readerTypography(ReaderDesignMetrics.rowLabel)
                .foregroundStyle(enabled ? theme.primaryText : theme.mutedText)
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
