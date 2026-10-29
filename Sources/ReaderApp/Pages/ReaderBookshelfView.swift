import SwiftUI
import UIKit

/// Core projects local formats and online text books onto this shelf. This
/// query filters shelf membership; it is not global source search.
struct ReaderBookshelfView: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    @Binding var shelfAnchor: String?
    @Binding var query: String
    @Binding var searching: Bool
    @ObservedObject var presentation: ReaderShelfPresentation
    var importFile: () -> Void
    var online: () -> Void
    var downloads: () -> Void = {}
    @State private var showingMore = false
    @State private var pendingMoreAction: MoreAction?
    @State private var actionBook: BookManagementPresentation?
    @State private var downloadStatusBook: ReaderBook?
    @State private var showingGroups = false
    @State private var catalogBook: ReaderBook?
    @State private var catalogFailure: String?
    @State private var catalogLoading = false
    @State private var catalogGeneration = UUID()
    @State private var catalogTask: Task<Void, Never>?
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @Environment(\.colorScheme) private var scheme
    private enum MoreAction { case importFile, layout(Bool), manage, groups, results, shelfFilter, online, downloads }
    private struct BookManagementPresentation: Identifiable {
        let id = UUID()
        let book: ReaderBook
    }
    /// The two layouts have different target view types. Keep their native
    /// identities distinct while Root continues to retain only book identity.
    private enum ScrollTarget: Hashable {
        case header, continuing, listBook(String), gridRow(String)
        var retainedAnchor: String {
            switch self {
            case .header: return "shelf:header"
            case .continuing: return "shelf:continue"
            case .listBook(let id), .gridRow(let id): return id
            }
        }
    }
    private var palette: ReaderPalette { ReaderPalette(scheme) }
    private var projectionKey: ReaderShelfProjectionKey { presentation.key(model: model, keyword: query) }
    private var resolvedBooks: [ReaderBook]? {
        if model.libraryService is any ReaderLibraryFeatures {
            return presentation.books(for: projectionKey)
        }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return needle.isEmpty ? model.books : model.books.filter {
            $0.title.localizedCaseInsensitiveContains(needle) || $0.author.localizedCaseInsensitiveContains(needle)
        }
    }
    private var visibleBooks: [ReaderBook] { resolvedBooks ?? [] }
    private var scrollTarget: ScrollTarget? {
        guard let anchor = shelfAnchor else { return nil }
        if anchor == "shelf:header" { return .header }
        if anchor == "shelf:continue" { return .continuing }
        if preferences.grid, let index = visibleBooks.firstIndex(where: { $0.id == anchor }) {
            return .gridRow(visibleBooks[(index / 3) * 3].id)
        }
        return preferences.grid ? .gridRow(anchor) : .listBook(anchor)
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 14) {
                header
                if searching {
                    TextField("筛选书架标题或作者", text: $query).font(ReaderTypography.font(.body))
                        .accessibilityIdentifier("shelf-filter")
                        .padding(.trailing, 44)
                        .padding(14).background(palette.field, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .trailing) {
                            ReaderIconAction(icon: .close, label: "关闭书架筛选") { setShelfFilterVisible(false) }
                                .accessibilityIdentifier("bookshelf-filter-close")
                                .padding(.trailing, 6)
                        }
                        .padding(.horizontal, 19)
                        .onChange(of: query) { _, _ in shelfAnchor = nil }
                }
                filterBar
                if let book = catalogBook {
                    if catalogLoading {
                        ReaderPageState(title: "正在取得《\(book.title)》目录", loading: true)
                    } else if let failure = catalogFailure {
                        ReaderPageState(title: "《\(book.title)》目录更新未完成", detail: failure,
                                        actionTitle: "重试") { refreshCatalog(book) }
                    }
                }
                if presentation.selecting { selectionBar }
                switch model.libraryState {
                case .loading: ReaderPageState(title: "正在加载书架", loading: true)
                case .failed(let message):
                    ReaderPageState(title: message, actionTitle: "重试") { Task { await model.reloadLibrary() } }
                case .empty:
                    ReaderPageState(title: "书架还是空的", detail: "导入一本本地小说，开始阅读。",
                        actionTitle: "本地导入", action: importFile)
                case .ready:
                    if resolvedBooks == nil {
                        if let failure = presentation.failure(for: projectionKey) {
                            projectionFailure(failure)
                        } else {
                            ReaderPageState(title: "正在读取书架", loading: true)
                        }
                    } else {
                        if let failure = presentation.failure(for: projectionKey) { projectionFailure(failure) }
                        if visibleBooks.isEmpty {
                            ReaderPageState(title: "没有符合条件的书籍", actionTitle: "清除筛选") { query = ""; presentation.group = nil; shelfAnchor = nil }
                        } else {
                            content(width: ReaderMetrics.shelfContentWidth(geometry.size.width),
                                    expanded: geometry.size.width >= ReaderMetrics.expandedMinWidth)
                        }
                    }
                }
            }.foregroundStyle(palette.ink)
        }
        .task(id: projectionKey) {
            await presentation.reload(model: model, keyword: query, grid: preferences.grid)
        }
        .onChange(of: searching) { old, value in
            presentation.traceSearchPresentation("binding.changed", searching: value,
                                                 key: projectionKey, previous: old)
        }
        .onAppear {
            presentation.traceSearchPresentation("shelf.appear", searching: searching, key: projectionKey)
        }
        .onChange(of: preferences.grid) { _, grid in presentation.recordLayout(key: projectionKey, grid: grid) }
        .sheet(item: $actionBook) { request in
            ReaderBookManagementView(model: model, book: request.book, changed: {
                Task { await model.reloadLibrary(); await presentation.reload(model: model, keyword: query) }
            }) {
                guard actionBook?.id == request.id else { return }
                actionBook = nil
            }.id(request.id)
        }
        .sheet(item: $downloadStatusBook) { book in
            if let service = model.libraryService as? any ReaderDownloadServing {
                ReaderOnlineDownloadSummaryPanel(book: book, service: service)
                    .id(book.id)
                    .preferredColorScheme(preferences.appDark ? .dark : .light)
            }
        }
        .sheet(isPresented: $showingGroups) {
            ReaderGroupManagementView(model: model, draft: presentation.groupDraft) {
                showingGroups = false
                Task { await presentation.reload(model: model, keyword: query) }
            }
        }
        .readerConfirmation(confirmation)
        .onChange(of: model.reader?.id) { _, value in
            if value != nil { cancelCatalogPresentation(); downloadStatusBook = nil }
        }
        .onDisappear {
            presentation.traceSearchPresentation("shelf.disappear", searching: searching, key: projectionKey)
            cancelCatalogPresentation()
        }
    }

    private func projectionFailure(_ message: String) -> some View {
        ReaderPageState(title: "书架筛选尚未完成", detail: message, actionTitle: "重试") {
            Task { await presentation.reload(model: model, keyword: query, grid: preferences.grid) }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Menu {
                Button("全部分组") { presentation.group = nil; shelfAnchor = nil }
                Button("未分组") { presentation.group = ""; shelfAnchor = nil }
                ForEach(presentation.groupOptions(model: model)) { option in
                    Button(option.name) { presentation.group = option.name; shelfAnchor = nil }
                }
            } label: { Text(presentation.group.map { $0.isEmpty ? "未分组" : $0 } ?? "全部分组") }
            Spacer(minLength: 0)
            Menu {
                ForEach(ReaderShelfSort.allCases, id: \.self) { sort in
                    Button(sortLabel(sort)) { presentation.sort = sort; shelfAnchor = nil }
                }
                Button(presentation.descending ? "改为升序" : "改为降序") { presentation.descending.toggle(); shelfAnchor = nil }
            } label: { Text(sortLabel(presentation.sort)); ReaderIcon(.chevronDown, size: 14) }
        }.font(ReaderTypography.font(.caption)).frame(minHeight: 32).padding(.horizontal, 20)
    }

    private var selectionBar: some View {
        HStack {
            Text("已选 \(presentation.selection.count) 本").font(ReaderTypography.font(.caption))
            Spacer(minLength: 0)
            Button("全选") { presentation.selection = Set(visibleBooks.map(\.id)) }
            Button("移除") { confirmRemoval() }.disabled(presentation.selection.isEmpty || model.actions.hasPending)
            Button("取消") { presentation.selecting = false; presentation.selection.removeAll() }
                .disabled(model.actions.busy)
        }.font(ReaderTypography.font(.action)).frame(minHeight: 44).padding(.horizontal, 19)
    }

    private func sortLabel(_ value: ReaderShelfSort) -> String {
        switch value { case .manual: return "默认顺序"; case .addedAt: return "加入时间"
        case .lastReadAt: return "最近阅读"; case .title: return "书名"; case .author: return "作者" }
    }

    private func activate(_ book: ReaderBook) {
        if presentation.selecting { presentation.toggle(book) } else { model.open(book) }
    }

    private func confirmRemoval() {
        guard let service = model.libraryService as? any ReaderLibraryFeatures else { return }
        let targets = model.books.filter { presentation.selection.contains($0.id) }
        guard !targets.isEmpty else { return }
        var message = "将所选 \(targets.count) 本书移出书架。"
        if targets.contains(where: { $0.sourceId == "local" }) {
            message += "本地书籍的目录、正文缓存、阅读进度及历史、正文编辑和下载任务会一并清除；移除成功后清理应用内原书副本。"
        }
        if targets.contains(where: { $0.sourceId != "local" }) {
            message += "在线书籍的已下载正文和阅读进度保留。"
        }
        message += "书签、笔记、阅读时长和下载目录原件保留。"
        confirmation.confirm("移出书架", message: message,
            actionTitle: "移除", destructive: true) {
            Task {
                if await presentation.removeSelectedBooks(targets, using: model.actions, action: { id in
                    _ = try await service.removeBooks(targets, operationID: id)
                }) {
                    await model.reloadLibrary()
                    await presentation.reload(model: model, keyword: query)
                }
            }
        }
    }

    private var header: some View {
        ZStack {
            Text("书架").font(ReaderTypography.font(.appTitle))
            HStack {
                ReaderIconAction(icon: .search, label: "搜索书籍", action: online)
                    .accessibilityIdentifier("bookshelf-search")
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
            moreAction("批量管理", icon: .check, action: .manage)
            moreAction("管理分组", icon: .filter, action: .groups)
            moreAction("筛选书架", icon: .filter, action: .shelfFilter)
                .accessibilityIdentifier("bookshelf-filter-open")
            moreAction("下载管理", icon: .directory, action: .downloads)
                .accessibilityIdentifier("bookshelf-download-management")
            if model.importOperation != nil { moreAction("查看导入结果", icon: .importFile, action: .results) }
            moreAction("搜索与书源", icon: .search, action: .online)
        }.font(ReaderTypography.font(.body)).foregroundStyle(palette.ink)
            .padding(12).frame(width: 220).background(palette.card)
            .buttonStyle(ReaderPressFeedback())
    }

    private func moreAction(_ title: String, icon: ReaderIconName, action: MoreAction) -> some View {
        Button { pendingMoreAction = action; showingMore = false } label: {
            HStack(spacing: 12) { ReaderIcon(icon, size: 20); Text(title); Spacer() }.frame(minHeight: 44)
        }
    }

    private func dispatchMoreAction() {
        guard let action = pendingMoreAction else { return }
        pendingMoreAction = nil
        switch action {
        case .importFile: importFile()
        case .layout(let grid): setGrid(grid)
        case .manage: presentation.selecting = true
        case .groups: showingGroups = true
        case .results: model.importResultVisible = true
        case .shelfFilter: setShelfFilterVisible(true)
        case .online: online()
        case .downloads: downloads()
        }
    }

    private func setShelfFilterVisible(_ visible: Bool) {
        presentation.traceSearchPresentation("action.before", searching: searching, key: projectionKey)
        searching = visible
        if !visible { query = ""; shelfAnchor = nil }
        presentation.traceSearchPresentation("action.after", searching: searching, key: projectionKey)
    }

    private func content(width: CGFloat, expanded: Bool) -> some View {
        let cover = ReaderMetrics.gridCoverSize(contentWidth: width, expanded: expanded)
        let spacing = ReaderMetrics.gridSpacing(contentWidth: width, expanded: expanded)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: ReaderMetrics.controlGap) {
                if query.isEmpty, let recent = model.books.max(by: { ($0.lastReadAt ?? 0) < ($1.lastReadAt ?? 0) }), recent.lastReadAt != nil {
                    continueCard(recent).id(ScrollTarget.continuing)
                }
                HStack {
                    Text("全部书籍").font(ReaderTypography.font(.sectionLabel))
                    Spacer()
                    ReaderIconAction(icon: preferences.grid ? .gridActive : .grid,
                                     label: preferences.grid ? "使用列表布局" : "使用封面布局", selected: preferences.grid) {
                        setGrid(!preferences.grid)
                    }
                }.frame(height: 38).id(ScrollTarget.header)
                if preferences.grid {
                    ForEach(Array(stride(from: 0, to: visibleBooks.count, by: 3)), id: \.self) { start in
                        HStack(alignment: .top, spacing: spacing) {
                            ForEach(Array(visibleBooks[start..<min(start + 3, visibleBooks.count)])) { book in
                                gridBook(book, cover: cover)
                            }
                            Spacer(minLength: 0)
                        }.frame(width: width, alignment: .leading).id(ScrollTarget.gridRow(visibleBooks[start].id))
                    }
                } else {
                    ForEach(visibleBooks) { book in
                        Button { activate(book) } label: {
                            HStack(spacing: 8) {
                                if presentation.selecting { ReaderIcon(presentation.selection.contains(book.id) ? .check : .bookshelf, size: 20) }
                                row(book, expanded: expanded)
                            }
                        }
                            .buttonStyle(ReaderPressFeedback()).accessibilityIdentifier("book-\(book.bookId)")
                            .accessibilityAddTraits(presentation.selection.contains(book.id) ? .isSelected : [])
                            .contextMenu { bookMenu(book) }
                            .id(ScrollTarget.listBook(book.id))
                    }
                }
            }.scrollTargetLayout().frame(width: width).frame(maxWidth: .infinity)
                .padding(.vertical, 4).padding(.bottom, 16)
        }.scrollPosition(id: Binding<ScrollTarget?>(get: { scrollTarget }, set: { value in
            // SwiftUI can clear its target while retiring the shelf for a reader.
            // Only a real visible target replaces the Root-owned return anchor.
            if let value {
                switch value {
                case .listBook(_) where preferences.grid: return
                case .gridRow(_) where !preferences.grid: return
                default: shelfAnchor = value.retainedAnchor
                }
            }
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
        Button { activate(book) } label: {
            VStack(alignment: .leading, spacing: 6) {
                ReaderBookCover(book: book, imageService: model.libraryService as? any ReaderRemoteImageServing).frame(width: cover.width, height: cover.height)
                    .overlay(alignment: .topTrailing) {
                        if presentation.selecting, presentation.selection.contains(book.id) { ReaderIcon(.check, size: 24) }
                    }
                Text(book.title).font(ReaderTypography.font(.shelfTitle)).lineLimit(1)
                Text(book.author).font(ReaderTypography.font(.shelfAuthor)).foregroundStyle(palette.muted).lineLimit(1)
                if let progress = book.readProgress, progress > 0 {
                    Text(progressLabel(book)).font(ReaderTypography.font(.shelfStatus)).foregroundStyle(palette.green).lineLimit(1)
                }
            }.frame(width: cover.width, alignment: .leading)
        }.buttonStyle(ReaderPressFeedback()).accessibilityIdentifier("book-\(book.bookId)")
            .accessibilityAddTraits(presentation.selection.contains(book.id) ? .isSelected : [])
            .contextMenu { bookMenu(book) }
    }

    @ViewBuilder
    private func bookMenu(_ book: ReaderBook) -> some View {
        Button("书籍信息与分组") { actionBook = BookManagementPresentation(book: book) }
        if book.sourceId != "local", model.libraryService is any ReaderOnlineServing {
            Button("更新目录") { refreshCatalog(book) }.disabled(catalogLoading)
        }
        if book.sourceId != "local", model.libraryService is any ReaderDownloadServing {
            Button("下载状态") { downloadStatusBook = book }
                .accessibilityIdentifier("shelf-download-status:" + book.id)
        }
        Button("多选") { presentation.selecting = true; presentation.toggle(book) }
    }

    /// Explicit read refresh is scoped to the captured book. It does not create
    /// a mutation intent or use a fresh read to confirm any other operation.
    private func refreshCatalog(_ book: ReaderBook) {
        guard book.sourceId != "local", let service = model.libraryService as? any ReaderOnlineServing else { return }
        catalogTask?.cancel()
        let generation = UUID(); catalogGeneration = generation
        catalogBook = book; catalogFailure = nil; catalogLoading = true
        catalogTask = Task {
            defer { if catalogGeneration == generation { catalogLoading = false; catalogTask = nil } }
            do {
                let detail = try await service.refreshOnlineCatalog(for: book)
                guard !Task.isCancelled, catalogGeneration == generation, detail.book.id == book.id,
                      model.reader == nil else { return }
                await model.reloadLibrary()
                await presentation.reload(model: model, keyword: query)
                guard !Task.isCancelled, catalogGeneration == generation, model.reader == nil else { return }
                catalogBook = nil
                model.showFeedback("已取得《\(book.title)》目录，共 \(detail.chapters.count) 章")
            } catch {
                guard !Task.isCancelled, catalogGeneration == generation, model.reader == nil else { return }
                catalogFailure = error.localizedDescription
            }
        }
    }
    private func cancelCatalogPresentation() {
        catalogGeneration = UUID(); catalogTask?.cancel(); catalogTask = nil
        catalogLoading = false; catalogBook = nil; catalogFailure = nil
    }

    private func row(_ book: ReaderBook, expanded: Bool) -> some View {
        HStack(spacing: ReaderMetrics.controlGap) {
            ReaderBookCover(book: book, imageService: model.libraryService as? any ReaderRemoteImageServing).frame(width: expanded ? 64 : 48, height: expanded ? 104 : 72)
                .clipShape(RoundedRectangle(cornerRadius: ReaderMetrics.listCoverRadius))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(book.title).font(ReaderTypography.font(.shelfTitle)).lineLimit(1)
                    Spacer(minLength: 0)
                    metadataTag(model.shelfFormatLabel(for: book)).accessibilityIdentifier("shelf-format:" + book.id)
                    metadataTag(book.sourceId == "local" ? "本地" : "在线")
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
                    ReaderBookCover(book: book, imageService: model.libraryService as? any ReaderRemoteImageServing).frame(width: 48, height: 72)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(book.title).font(ReaderTypography.font(.continueTitle)).lineLimit(1)
                            .accessibilityIdentifier("shelf-continue-title")
                        Text(book.author).font(ReaderTypography.font(.continueAuthor)).foregroundStyle(palette.muted).lineLimit(1)
                        Text(book.currentChapterTitle ?? "尚未开始").font(ReaderTypography.font(.continueAuthor))
                            .foregroundStyle(palette.muted).lineLimit(1)
                            .accessibilityIdentifier("shelf-continue-chapter")
                    }.fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("阅读").font(ReaderTypography.font(.action)).foregroundStyle(palette.onPrimary)
                        .padding(.horizontal, 10).padding(.vertical, 8).frame(minWidth: 54, minHeight: 40)
                        .background(palette.app("app.action.fill"), in: RoundedRectangle(cornerRadius: 12))
                }.padding(.horizontal, 12).padding(.vertical, 14).frame(minHeight: ReaderMetrics.continueHeight)
                    .frame(maxWidth: .infinity).background(palette.card, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(palette.border, lineWidth: 1))
            }.buttonStyle(ReaderPressFeedback()).accessibilityLabel("继续阅读，\(book.title)")
                .accessibilityIdentifier("shelf-continue-card")
        }
    }
}

/// Frozen NoCoverCover geometry, rather than an invented title-on-cover design.
struct ReaderBookCover: View {
    let book: ReaderBook
    var imageService: (any ReaderRemoteImageServing)? = nil
    @State private var image: UIImage?
    @State private var failed = false
    @State private var loading = false
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let palette = ReaderPalette(scheme)
            ZStack(alignment: .topLeading) {
                palette.app("TOK_META_BG")
                if let image {
                    Image(uiImage: image).resizable().scaledToFill().frame(width: width, height: height).clipped()
                } else {
                Group {
                Capsule().fill(palette.app("app.NoCoverCover.build.backgroundColor.2E41484C"))
                    .frame(width: 40 / 96.96 * width, height: 1).position(x: width / 2, y: 52 / 145.44 * height)
                Text(failed ? "封面不可用" : "暂无封面")
                    .font(.custom(ReaderFonts.postScriptName(.serifBold), size: 15 * width / 96.96, relativeTo: .body))
                    .foregroundStyle(palette.ink).lineLimit(1).minimumScaleFactor(0.5)
                    .frame(width: 72 / 96.96 * width, height: 18.3 * width / 96.96)
                    .position(x: width / 2, y: 63.57 / 145.44 * height + 18.3 * width / 96.96 / 2)
                Capsule().fill(palette.app("app.NoCoverCover.build.backgroundColor.2E41484C"))
                    .frame(width: 40 / 96.96 * width, height: 1).position(x: width / 2, y: 92.44 / 145.44 * height)
                }
                if loading { ProgressView().frame(width: width, height: height) }
                }
            }.clipShape(RoundedRectangle(cornerRadius: ReaderMetrics.coverRadius))
        }.accessibilityHidden(true).task(id: book.id + "|" + (book.coverUrl ?? "")) {
            image = nil; failed = false; loading = false
            guard let uri = book.coverUrl, !uri.isEmpty else { return }
            loading = true
            do {
                let value: UIImage
                if uri.lowercased().hasPrefix("data:image/") {
                    value = try await Task.detached(priority: .utility) { try ReaderCoverImage.embedded(uri) }.value
                } else {
                    guard book.sourceId != "local", let imageService else { throw ReaderLibraryError.invalidResponse("cover source") }
                    let data = try await imageService.remoteImage(sourceID: book.sourceId, url: uri)
                    try Task.checkCancellation()
                    value = try await Task.detached(priority: .utility) { try ReaderCoverImage.thumbnail(data) }.value
                }
                guard !Task.isCancelled else { return }
                image = value; loading = false
            } catch {
                guard !Task.isCancelled else { return }
                failed = true; loading = false
            }
        }
    }
}

struct ReaderSettingsView: View {
    @ObservedObject var preferences: ReaderPreferences
    var online: () -> Void
    var downloads: () -> Void = {}
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Text("设置").font(ReaderTypography.font(.appTitle)).padding(.top, 20)
            VStack(alignment: .leading, spacing: 18) {
                Text("应用外观").font(ReaderTypography.font(.controlHeader))
                Toggle("跟随系统", isOn: $preferences.followSystem).font(ReaderTypography.font(.caption))
                    .tint(ReaderPalette(scheme).green).accessibilityIdentifier("settings-follow-system")
                Toggle("夜间模式", isOn: $preferences.appDark).font(ReaderTypography.font(.caption))
                    .tint(ReaderPalette(scheme).green).disabled(preferences.followSystem)
                    .accessibilityIdentifier("settings-night-mode")
                Text("日间与夜间分别使用已保存的默认纸色。")
                    .font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
            }.padding(18).background(ReaderPalette(scheme).card, in: RoundedRectangle(cornerRadius: 18))
            Button("书源、搜索与下载", action: online).buttonStyle(ReaderPrimaryButtonStyle())
            Button("下载管理", action: downloads).buttonStyle(ReaderPrimaryButtonStyle())
                .accessibilityIdentifier("settings-download-management")
            Spacer()
        }.padding(.horizontal, 19).frame(maxWidth: 620).frame(maxWidth: .infinity)
            .foregroundStyle(ReaderPalette(scheme).ink)
    }
}
