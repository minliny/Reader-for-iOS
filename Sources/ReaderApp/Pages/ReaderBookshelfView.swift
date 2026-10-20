import SwiftUI

/// V1 exposes local TXT facts only. Search filters this shelf; it is not global source search.
struct ReaderBookshelfView: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    @Binding var shelfAnchor: String?
    @Binding var query: String
    @Binding var searching: Bool
    var importFile: () -> Void
    @State private var showingMore = false
    @State private var pendingMoreAction: MoreAction?
    @Environment(\.colorScheme) private var scheme
    private enum MoreAction { case importFile, layout(Bool) }
    private var palette: ReaderPalette { ReaderPalette(scheme) }
    private var visibleBooks: [ReaderBook] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return needle.isEmpty ? model.books : model.books.filter {
            $0.title.localizedCaseInsensitiveContains(needle) || $0.author.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 14) {
                header
                if searching {
                    TextField("搜索本地书架", text: $query).font(ReaderTypography.font(.body))
                        .padding(14).background(palette.field, in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 19).accessibilityIdentifier("shelf-filter")
                        .onChange(of: query) { _, _ in shelfAnchor = nil }
                }
                switch model.libraryState {
                case .loading: ReaderPageState(title: "正在加载书架", loading: true)
                case .failed(let message):
                    ReaderPageState(title: message, actionTitle: "重试") { Task { await model.reloadLibrary() } }
                case .empty:
                    ReaderPageState(title: "书架还是空的", detail: "导入一本本地小说，开始阅读。",
                        actionTitle: "本地导入", action: importFile)
                case .ready:
                    if visibleBooks.isEmpty {
                        ReaderPageState(title: "没有符合条件的书籍", actionTitle: "清除搜索") { query = ""; shelfAnchor = nil }
                    } else {
                        content(width: ReaderMetrics.shelfContentWidth(geometry.size.width),
                                expanded: geometry.size.width >= ReaderMetrics.expandedMinWidth)
                    }
                }
            }.foregroundStyle(palette.ink)
        }
    }

    private var header: some View {
        ZStack {
            Text("书架").font(ReaderTypography.font(.appTitle))
            HStack {
                ReaderIconAction(icon: .search, label: "搜索本地书架", selected: searching) {
                    searching.toggle()
                    if !searching { query = ""; shelfAnchor = nil }
                }
                Spacer(minLength: 0)
                ReaderIconAction(icon: .more, label: "更多书架操作") { showingMore = true }
                    .popover(isPresented: $showingMore, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                        moreMenu.onDisappear(perform: dispatchMoreAction)
                            .presentationCompactAdaptation(.popover)
                    }
            }
        }.padding(.horizontal, 4).frame(height: ReaderMetrics.headerHeight)
            .background(palette.card, in: RoundedRectangle(cornerRadius: ReaderMetrics.headerRadius))
            .overlay(RoundedRectangle(cornerRadius: ReaderMetrics.headerRadius).stroke(palette.border, lineWidth: 1))
            .padding(.horizontal, 16).padding(.top, ReaderMetrics.headerTop)
    }

    private var moreMenu: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                pendingMoreAction = .importFile; showingMore = false
            } label: {
                HStack(spacing: 12) { ReaderIcon(.importFile, size: 20); Text("本地导入"); Spacer() }
                    .frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityIdentifier("import-book")
            Button {
                pendingMoreAction = .layout(!preferences.grid); showingMore = false
            } label: {
                HStack(spacing: 12) {
                    ReaderIcon(preferences.grid ? .list : .grid, size: 20)
                    Text(preferences.grid ? "使用列表布局" : "使用封面布局"); Spacer()
                }.frame(minHeight: 44).contentShape(Rectangle())
            }
        }.font(ReaderTypography.font(.body)).foregroundStyle(palette.ink)
            .padding(12).frame(width: 220).background(palette.card)
            .buttonStyle(ReaderPressFeedback())
    }

    private func dispatchMoreAction() {
        guard let action = pendingMoreAction else { return }
        pendingMoreAction = nil
        switch action {
        case .importFile: importFile()
        case .layout(let grid): setGrid(grid)
        }
    }

    private func content(width: CGFloat, expanded: Bool) -> some View {
        let cover = ReaderMetrics.gridCoverSize(contentWidth: width, expanded: expanded)
        let spacing = ReaderMetrics.gridSpacing(contentWidth: width, expanded: expanded)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: ReaderMetrics.controlGap) {
                if query.isEmpty, let recent = model.books.max(by: { ($0.lastReadAt ?? 0) < ($1.lastReadAt ?? 0) }), recent.lastReadAt != nil {
                    continueCard(recent).id("shelf:continue")
                }
                HStack {
                    Text("全部书籍").font(ReaderTypography.font(.sectionLabel))
                    Spacer()
                    ReaderIconAction(icon: preferences.grid ? .gridActive : .grid,
                                     label: preferences.grid ? "使用列表布局" : "使用封面布局", selected: preferences.grid) {
                        setGrid(!preferences.grid)
                    }
                }.frame(height: 38).id("shelf:header")
                if preferences.grid {
                    ForEach(Array(stride(from: 0, to: visibleBooks.count, by: 3)), id: \.self) { start in
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(Array(visibleBooks[start..<min(start + 3, visibleBooks.count)])) { book in
                                gridBook(book, cover: cover)
                            }
                            Spacer(minLength: 0)
                        }.frame(width: width, alignment: .leading).id(visibleBooks[start].id)
                    }
                } else {
                    ForEach(visibleBooks) { book in
                        Button { model.open(book) } label: { row(book, expanded: expanded) }
                            .buttonStyle(ReaderPressFeedback()).accessibilityIdentifier("book-\(book.bookId)")
                            .id(book.id)
                    }
                }
            }.scrollTargetLayout().frame(width: width).frame(maxWidth: .infinity)
                .padding(.vertical, 4).padding(.bottom, 16)
        }.scrollPosition(id: Binding(get: { shelfAnchor }, set: { value in
            // SwiftUI can clear its target while retiring the shelf for a reader.
            // Only a real visible target replaces the Root-owned return anchor.
            if let value { shelfAnchor = value }
        }), anchor: .top)
            .refreshable { await model.reloadLibrary() }
            .overlay { if model.openingBookID != nil { ProgressView().padding(18).background(palette.card, in: Capsule()) } }
    }

    private func setGrid(_ grid: Bool) {
        if grid, let anchor = shelfAnchor, let index = visibleBooks.firstIndex(where: { $0.id == anchor }) {
            shelfAnchor = visibleBooks[(index / 3) * 3].id
        }
        preferences.grid = grid
    }

    private func gridBook(_ book: ReaderBook, cover: CGSize) -> some View {
        Button { model.open(book) } label: {
            VStack(alignment: .leading, spacing: 6) {
                ReaderBookCover(book: book).frame(width: cover.width, height: cover.height)
                Text(book.title).font(ReaderTypography.font(.shelfTitle)).lineLimit(1)
                Text(book.author).font(ReaderTypography.font(.shelfAuthor)).foregroundStyle(palette.muted).lineLimit(1)
                if let progress = book.readProgress, progress > 0 {
                    Text(progressLabel(book)).font(ReaderTypography.font(.shelfStatus)).foregroundStyle(palette.green).lineLimit(1)
                }
            }.frame(width: cover.width, alignment: .leading)
        }.buttonStyle(ReaderPressFeedback()).accessibilityIdentifier("book-\(book.bookId)")
    }

    private func row(_ book: ReaderBook, expanded: Bool) -> some View {
        HStack(spacing: ReaderMetrics.controlGap) {
            ReaderBookCover(book: book).frame(width: expanded ? 64 : 48, height: expanded ? 104 : 72)
                .clipShape(RoundedRectangle(cornerRadius: ReaderMetrics.listCoverRadius))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(book.title).font(ReaderTypography.font(.shelfTitle)).lineLimit(1)
                    Spacer(minLength: 0)
                    metadataTag("小说"); metadataTag("本地")
                }
                Text(book.author).font(ReaderTypography.font(.shelfAuthor)).foregroundStyle(palette.muted).lineLimit(1)
                    .frame(minHeight: 14)
                Text(book.currentChapterTitle ?? "尚未开始").font(ReaderTypography.font(.shelfStatus))
                    .foregroundStyle(palette.muted).lineLimit(1)
                HStack {
                    Text("共 \(book.chapterCount) 章").lineLimit(1)
                    Spacer(minLength: 0)
                    Text(progressLabel(book))
                }.font(ReaderTypography.font(.shelfStatus)).foregroundStyle(palette.muted)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(palette.line)
                        Capsule().fill(palette.green).frame(width: geometry.size.width * CGFloat(book.readProgress ?? 0) / 10000)
                    }
                }.frame(height: 3)
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.frame(maxWidth: .infinity, minHeight: expanded ? 104 : 72, alignment: .leading)
            .contentShape(Rectangle())
    }

    private func metadataTag(_ value: String) -> some View {
        Text(value).font(ReaderTypography.font(.metadataTag)).foregroundStyle(palette.muted)
            .padding(.horizontal, 4).frame(minWidth: 30, minHeight: 16)
            .background(palette.card, in: RoundedRectangle(cornerRadius: 4))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(palette.border, lineWidth: 0.5))
    }

    private func progressLabel(_ book: ReaderBook) -> String {
        guard let value = book.readProgress, value > 0 else { return "未读" }
        return String(format: "%.0f%%", Double(value) / 100)
    }

    private func continueCard(_ book: ReaderBook) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("继续阅读").font(ReaderTypography.font(.continueLabel)).foregroundStyle(palette.muted)
            Button { model.open(book) } label: {
                HStack(spacing: 12) {
                    ReaderBookCover(book: book).frame(width: 48, height: 72)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title).font(ReaderTypography.font(.continueTitle)).lineLimit(1)
                        Text(book.author).font(ReaderTypography.font(.continueAuthor)).foregroundStyle(palette.muted).lineLimit(1)
                        Text(book.currentChapterTitle ?? "尚未开始").font(ReaderTypography.font(.continueAuthor))
                            .foregroundStyle(palette.muted).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Text("阅读").font(ReaderTypography.font(.action)).foregroundStyle(palette.onPrimary)
                        .frame(width: 54, height: 40).background(palette.app("app.action.fill"), in: RoundedRectangle(cornerRadius: 12))
                }.padding(.horizontal, 12).frame(height: ReaderMetrics.continueHeight)
                    .frame(maxWidth: .infinity).background(palette.card, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.border, lineWidth: 1))
            }.buttonStyle(ReaderPressFeedback()).accessibilityLabel("继续阅读，\(book.title)")
        }
    }
}

/// Frozen NoCoverCover geometry, rather than an invented title-on-cover design.
struct ReaderBookCover: View {
    let book: ReaderBook
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let palette = ReaderPalette(scheme)
            ZStack(alignment: .topLeading) {
                palette.app("TOK_META_BG")
                Capsule().fill(palette.app("app.NoCoverCover.build.backgroundColor.2E41484C"))
                    .frame(width: 40 / 96.96 * width, height: 1).position(x: width / 2, y: 52 / 145.44 * height)
                Text("暂无封面")
                    .font(.custom(ReaderFonts.postScriptName(.serifBold), size: 15 * width / 96.96, relativeTo: .body))
                    .foregroundStyle(palette.ink).lineLimit(1).minimumScaleFactor(0.5)
                    .frame(width: 72 / 96.96 * width, height: 18.3 * width / 96.96)
                    .position(x: width / 2, y: 63.57 / 145.44 * height + 18.3 * width / 96.96 / 2)
                Capsule().fill(palette.app("app.NoCoverCover.build.backgroundColor.2E41484C"))
                    .frame(width: 40 / 96.96 * width, height: 1).position(x: width / 2, y: 92.44 / 145.44 * height)
            }.clipShape(RoundedRectangle(cornerRadius: ReaderMetrics.coverRadius))
        }.accessibilityHidden(true)
    }
}

struct ReaderSettingsView: View {
    @ObservedObject var preferences: ReaderPreferences
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("设置").font(ReaderTypography.font(.appTitle)).padding(.top, 20)
            VStack(alignment: .leading, spacing: 18) {
                Text("应用外观").font(ReaderTypography.font(.controlHeader))
                Toggle("夜间模式", isOn: $preferences.appDark).font(ReaderTypography.font(.caption))
                    .tint(ReaderPalette(scheme).green)
                Text("阅读纸色与应用外观分别保存。")
                    .font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
            }.padding(18).background(ReaderPalette(scheme).card, in: RoundedRectangle(cornerRadius: 18))
            Spacer()
        }.padding(.horizontal, 19).frame(maxWidth: 620).frame(maxWidth: .infinity)
            .foregroundStyle(ReaderPalette(scheme).ink)
    }
}
