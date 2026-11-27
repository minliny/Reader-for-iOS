import ReaderCoreBridge
import ReaderDesign
import SwiftUI

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

    @Environment(\.readerTheme) private var theme
    @State private var selected: BookIdentity?

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= CGFloat(ReaderDesignMetrics.wideBreakpoint)
            let inset = CGFloat(ReaderDesignMetrics.screenInset)
            Group {
                if wide, let books, !books.isEmpty {
                    HStack(spacing: 0) {
                        shelfList(books, narrow: false, wide: true)
                            .frame(width: min(360, geometry.size.width * 0.43))
                        Rectangle().fill(theme.divider).frame(width: 1).accessibilityHidden(true)
                        if let entry = books.first(where: { BookIdentity($0) == selected }) ?? books.first {
                            ShelfSelectionPane(entry: entry) { onOpen(entry) }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else if let state {
                    PageState(state: state) { generation in
                        if let onRetryGeneration { onRetryGeneration(generation) }
                        else { onRetry() }
                    }
                } else if let books {
                    shelfList(books, narrow: geometry.size.width < CGFloat(ReaderDesignMetrics.narrowBreakpoint), wide: false)
                }
            }
            .background(theme.background)
            .overlay(alignment: .top) {
                if let recovery {
                    RecoveryNotice(title: recovery.title, message: recovery.message, generation: recovery.generation,
                                   action: recovery.action, availability: recoveryAvailable, onAction: onRecovery)
                        .padding(.horizontal, inset)
                        .padding(.top, 4)
                }
            }
        }
    }

    private func shelfList(_ entries: [BookshelfEntryData], narrow: Bool, wide: Bool) -> some View {
        ScrollView {
            LazyVStack(spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
                ForEach(entries, id: \.bookId) { entry in
                    ShelfBookRow(entry: entry, narrow: narrow, selected: wide && BookIdentity(entry) == selected) {
                        if wide {
                            selected = BookIdentity(entry)
                            onSelectWide?(entry)
                        } else { onOpen(entry) }
                    } onRemove: { onRemove(entry) }
                }
            }
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
            .padding(.vertical, CGFloat(ReaderDesignMetrics.spaceSmall))
        }
        .accessibilityIdentifier("shelf-list")
    }
}

private struct ShelfSelectionPane: View {
    let entry: BookshelfEntryData
    let onOpen: () -> Void
    @Environment(\.readerTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            BookCover(entry: entry).frame(width: 110, height: 152)
            Text(entry.title).readerTypography(ReaderDesignMetrics.appTitle, relativeTo: .title)
                .foregroundStyle(theme.primaryText).lineLimit(2)
            if !entry.author.isEmpty { Text(entry.author).foregroundStyle(theme.secondaryText) }
            if let intro = entry.intro, !intro.isEmpty { Text(intro).foregroundStyle(theme.secondaryText).lineLimit(6) }
            Button(action: onOpen) {
                Text("查看详情").readerTypography(ReaderDesignMetrics.rowLabel)
                    .foregroundStyle(theme.onAccent).padding(.horizontal, 15)
                    .frame(minHeight: 44)
                    .background(theme.accentFill,
                                in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.inputRadius)))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 420, alignment: .leading)
        .padding(24)
    }
}
