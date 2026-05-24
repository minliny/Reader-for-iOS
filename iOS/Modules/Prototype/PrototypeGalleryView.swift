import SwiftUI

// MARK: - Prototype Gallery Catalog (38 entries, fixture-driven, debug-only)

public struct PrototypeGalleryView: View {
    @State private var selectedEntry: PrototypeEntry?
    @State private var selectedTab: Tab = .bookshelf

    private let entries: [PrototypeEntry] = PrototypeGalleryView.allEntries

    public init() {}

    public var body: some View {
        NavigationStack {
            List {
                ForEach(PrototypeGroup.allCases) { group in
                    let groupEntries = entries.filter { $0.group == group }
                    if !groupEntries.isEmpty {
                        Section(group.rawValue) {
                            ForEach(groupEntries) { entry in
                                NavigationLink {
                                    ScrollView {
                                        entry.content()
                                            .navigationTitle(entry.name)
                                            .navigationBarTitleDisplayMode(.inline)
                                    }
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.name)
                                            .font(ReaderTypography.listTitle)
                                        if !entry.description.isEmpty {
                                            Text(entry.description)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Prototype Gallery")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("[DEBUG] Prototype Gallery")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

extension PrototypeGalleryView {
    enum Tab: String, CaseIterable {
        case bookshelf = "书架"
        case discover = "发现"
        case sources = "书源"
        case mine = "我的"
    }

    static let allEntries: [PrototypeEntry] = [
        // A: App / Navigation
        PrototypeEntry(id: "app-shell", group: .appShell, name: "App Shell / Main Tabs (4 tabs)") {
            AppShellPrototype()
        },

        // B: Bookshelf
        PrototypeEntry(id: "bookshelf-cover", group: .bookshelf, name: "书架封面模式") {
            BookshelfCoverPrototype()
        },
        PrototypeEntry(id: "bookshelf-list", group: .bookshelf, name: "书架列表模式") {
            BookshelfListPrototype()
        },
        PrototypeEntry(id: "bookshelf-empty", group: .bookshelf, name: "书架空状态") {
            BookshelfEmptyPrototype()
        },

        // C: Search / Detail
        PrototypeEntry(id: "search-home", group: .searchDetail, name: "搜索首页") {
            SearchHomePrototype()
        },
        PrototypeEntry(id: "search-results", group: .searchDetail, name: "搜索结果") {
            SearchResultsPrototype()
        },
        PrototypeEntry(id: "search-empty", group: .searchDetail, name: "搜索空状态") {
            SearchEmptyPrototype()
        },
        PrototypeEntry(id: "search-error", group: .searchDetail, name: "搜索错误状态") {
            SearchErrorPrototype()
        },
        PrototypeEntry(id: "book-detail", group: .searchDetail, name: "书籍详情") {
            BookDetailPrototype()
        },
        PrototypeEntry(id: "book-detail-toc", group: .searchDetail, name: "书籍详情 TOC 预览") {
            BookDetailTOCPrototype()
        },

        // D: Reader (9 control states)
        PrototypeEntry(id: "reader-base", group: .reader, name: "阅读页基础控制层") {
            ReaderBasePrototype()
        },
        PrototypeEntry(id: "reader-search", group: .reader, name: "阅读页搜索 overlay") {
            ReaderSearchOverlayPrototype()
        },
        PrototypeEntry(id: "reader-autoscroll", group: .reader, name: "阅读页自动翻页 overlay") {
            ReaderAutoScrollOverlayPrototype()
        },
        PrototypeEntry(id: "reader-replace", group: .reader, name: "阅读页内容替换 overlay") {
            ReaderReplaceOverlayPrototype()
        },
        PrototypeEntry(id: "reader-night", group: .reader, name: "阅读页夜间状态（非弹窗）") {
            ReaderNightStatePrototype()
        },
        PrototypeEntry(id: "reader-directory", group: .reader, name: "阅读页目录/书签 overlay") {
            ReaderDirectoryOverlayPrototype()
        },
        PrototypeEntry(id: "reader-tts", group: .reader, name: "阅读页朗读 overlay") {
            ReaderTTSOverlayPrototype()
        },
        PrototypeEntry(id: "reader-appearance", group: .reader, name: "阅读页界面 overlay") {
            ReaderAppearanceOverlayPrototype()
        },
        PrototypeEntry(id: "reader-settings", group: .reader, name: "阅读页设置 overlay") {
            ReaderSettingsOverlayPrototype()
        },

        // E: Source Management
        PrototypeEntry(id: "source-list", group: .sourceMgmt, name: "书源管理列表") {
            SourceListPrototype()
        },
        PrototypeEntry(id: "source-detail", group: .sourceMgmt, name: "书源详情") {
            SourceDetailPrototype()
        },
        PrototypeEntry(id: "source-edit-import", group: .sourceMgmt, name: "书源编辑 / 导入状态") {
            SourceEditImportPrototype()
        },
        PrototypeEntry(id: "source-test-error", group: .sourceMgmt, name: "书源测试 / 禁用 / 错误状态") {
            SourceTestErrorPrototype()
        },

        // F: Discover / RSS
        PrototypeEntry(id: "discover-home", group: .discover, name: "发现首页") {
            DiscoverHomePrototype()
        },
        PrototypeEntry(id: "rss-list", group: .rss, name: "RSS 列表") {
            RSSListPrototype()
        },
        PrototypeEntry(id: "rss-detail", group: .rss, name: "RSS 详情") {
            RSSDetailPrototype()
        },
        PrototypeEntry(id: "rss-subscriptions", group: .rss, name: "RSS 订阅管理") {
            RSSSubscriptionsPrototype()
        },

        // F: WebDAV / Sync
        PrototypeEntry(id: "webdav-config", group: .webdav, name: "WebDAV 配置") {
            WebDAVConfigPrototype()
        },
        PrototypeEntry(id: "backup-settings", group: .sync, name: "备份设置") {
            BackupSettingsPrototype()
        },
        PrototypeEntry(id: "sync-progress", group: .sync, name: "阅读进度同步状态") {
            SyncProgressPrototype()
        },
        PrototypeEntry(id: "remote-webdav-books", group: .webdav, name: "远程 WebDAV 书籍") {
            RemoteWebDAVBooksPrototype()
        },
        PrototypeEntry(id: "sync-error", group: .sync, name: "同步错误 / WebDAV auth error") {
            SyncErrorPrototype()
        },

        // G: Settings / States
        PrototypeEntry(id: "global-settings", group: .settings, name: "全局设置（我的页面内）") {
            GlobalSettingsPrototype()
        },
        PrototypeEntry(id: "state-loading", group: .states, name: "loading 状态页") {
            StatePagePrototype(state: .loading)
        },
        PrototypeEntry(id: "state-empty", group: .states, name: "empty 状态页") {
            StatePagePrototype(state: .empty)
        },
        PrototypeEntry(id: "state-error", group: .states, name: "error 状态页") {
            StatePagePrototype(state: .error(message: "网络连接失败", retryable: true))
        },
        PrototypeEntry(id: "state-offline", group: .states, name: "offline 状态页") {
            StatePagePrototype(state: .offline)
        },
        PrototypeEntry(id: "state-permission", group: .states, name: "permission required 状态页") {
            StatePagePrototype(state: .permissionRequired(permission: "存储"))
        },
    ]
}

// MARK: - A. App Shell Prototype

struct AppShellPrototype: View {
    @State private var selectedTab = 0
    private let tabs: [(String, String)] = [
        ("books.vertical", "书架"), ("safari", "发现"),
        ("doc.text.magnifyingglass", "书源"), ("person.circle", "我的")
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 主底栏：书架 / 发现 / 书源 / 我的
            HStack(spacing: 0) {
                ForEach(0..<tabs.count, id: \.self) { idx in
                    Button {
                        selectedTab = idx
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tabs[idx].0)
                                .font(.system(size: 22))
                            Text(tabs[idx].1)
                                .font(ReaderTypography.controlLabel)
                        }
                        .foregroundColor(selectedTab == idx ? ReaderColors.primary : ReaderColors.controlInk)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .frame(height: ReaderControlMetrics.bottomBarHeight)
            .background(ReaderColors.bottomBarBg)
            .overlay(Divider().opacity(0.3), alignment: .top)

            // 内容区
            Group {
                switch selectedTab {
                case 0: BookshelfCoverPrototype()
                case 1: DiscoverHomePrototype()
                case 2: SourceListPrototype()
                case 3: MineTabPrototype()
                default: EmptyView()
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

/// 「我的」Tab 内容
struct MineTabPrototype: View {
    var body: some View {
        List {
            Section {
                NavigationLink(destination: { AnyView(GlobalSettingsPrototype()) }) {
                    Label("设置", systemImage: "gearshape")
                }
                Label("阅读记录", systemImage: "clock")
                Label("阅读统计", systemImage: "chart.bar")
                Label("收藏/书签", systemImage: "bookmark")
            } header: { Text("个人") }

            Section {
                NavigationLink(destination: { AnyView(WebDAVConfigPrototype()) }) {
                    Label("WebDAV 备份", systemImage: "icloud")
                }
                NavigationLink(destination: { AnyView(SyncProgressPrototype()) }) {
                    Label("同步进度", systemImage: "arrow.triangle.2.circlepath")
                }
                NavigationLink(destination: { AnyView(BackupSettingsPrototype()) }) {
                    Label("备份设置", systemImage: "externaldrive")
                }
            } header: { Text("备份与同步") }
        }
    }
}

// MARK: - B. Bookshelf Prototypes

struct BookshelfCoverPrototype: View {
    private let books = PrototypeFixtures.bookshelfBooks
    private let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("书架").font(ReaderTypography.pageTitle).foregroundColor(ReaderColors.controlInk)
                Spacer()
                Image(systemName: "square.grid.2x2").font(.title3).foregroundColor(ReaderColors.primary)
                Image(systemName: "magnifyingglass").font(.title3).foregroundColor(ReaderColors.controlInk).padding(.leading, 12)
                Image(systemName: "ellipsis").font(.title3).foregroundColor(ReaderColors.controlInk).padding(.leading, 4)
            }.padding(.horizontal, 16).padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: ReaderSpacing.lg) {
                    ForEach(books) { book in
                        VStack(alignment: .leading, spacing: 4) {
                            Image(systemName: book.cover)
                                .font(.system(size: 32))
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(ReaderColors.floatingControlBg)
                                .clipShape(ReaderShapes.card)

                            Text(book.title).font(ReaderTypography.listTitle)
                                .foregroundColor(ReaderColors.controlInk).lineLimit(1)
                            Text(book.author).font(.caption).foregroundStyle(.secondary)
                            ProgressView(value: book.progress)
                                .tint(ReaderColors.primary)
                            Text("\(Int(book.progress * 100))%")
                                .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(ReaderColors.paperBg)
    }
}

struct BookshelfListPrototype: View {
    private let books = PrototypeFixtures.bookshelfBooks

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("书架").font(ReaderTypography.pageTitle).foregroundColor(ReaderColors.controlInk)
                Spacer()
                Image(systemName: "list.bullet").font(.title3).foregroundColor(ReaderColors.primary)
            }.padding(.horizontal, 16).padding(.top, 8)

            List(books) { book in
                HStack(spacing: 12) {
                    Image(systemName: book.cover).font(.title2)
                        .frame(width: 48, height: 64)
                        .background(ReaderColors.floatingControlBg)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(book.title).font(ReaderTypography.listTitle)
                                .foregroundColor(ReaderColors.controlInk)
                            Spacer()
                            Text(book.group).font(.caption2)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(ReaderColors.floatingControlBg)
                                .clipShape(Capsule())
                        }
                        Text(book.author).font(.caption).foregroundStyle(.secondary)
                        ProgressView(value: book.progress).tint(ReaderColors.primary)
                        HStack {
                            Text(book.lastChapter).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                            Spacer()
                            Text("\(Int(book.progress * 100))%").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listStyle(.plain)
        }
        .background(ReaderColors.paperBg)
    }
}

struct BookshelfEmptyPrototype: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "books.vertical").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("书架空空").font(.title2).fontWeight(.semibold)
            Text("去搜索或发现页面添加书籍吧").font(.subheadline).foregroundStyle(.secondary)
            HStack(spacing: 16) {
                Button("添加书籍") {}.buttonStyle(.borderedProminent).tint(ReaderColors.primary)
                Button("导入书源") {}.buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderColors.paperBg)
    }
}

// MARK: - C. Search / Detail Prototypes

struct SearchHomePrototype: View {
    @State private var query = ""
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("搜索书名或作者", text: $query)
                    .font(ReaderTypography.readerBody)
            }
            .frame(height: 44).padding(.horizontal, 12)
            .background(ReaderColors.quickButtonBg)
            .clipShape(Capsule())
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("搜索历史").font(ReaderTypography.listTitle).foregroundColor(ReaderColors.controlInk)
                ForEach(PrototypeFixtures.searchHistory, id: \.self) { item in
                    HStack {
                        Image(systemName: "clock").font(.caption).foregroundStyle(.secondary)
                        Text(item).font(.subheadline).foregroundColor(ReaderColors.bodyText)
                        Spacer()
                    }.padding(.vertical, 4)
                }
            }.padding(.horizontal, 16)
            Spacer()
        }
        .padding(.top, 16)
        .background(ReaderColors.paperBg)
    }
}

struct SearchResultsPrototype: View {
    let results = PrototypeFixtures.searchResults
    var body: some View {
        List(results) { r in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(r.title).font(ReaderTypography.listTitle).foregroundColor(ReaderColors.controlInk)
                    Spacer()
                    Text("\(r.sourceCount) 个书源").font(.caption2).foregroundStyle(ReaderColors.primary)
                }
                Text(r.author).font(.caption).foregroundStyle(.secondary)
                Text(r.intro).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack {
                    Text("来源: \(r.sourceName)").font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Button("加入书架") {}.font(.caption).buttonStyle(.bordered).tint(ReaderColors.primary).controlSize(.small)
                }
            }
            .padding(.vertical, 4)
        }
        .listStyle(.plain)
    }
}

struct SearchEmptyPrototype: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass").font(.system(size: 48)).foregroundStyle(.secondary)
            Text("没有找到结果").font(.title3).fontWeight(.semibold)
            Text("试试换个关键词，或检查书源是否已启用")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderColors.paperBg)
    }
}

struct SearchErrorPrototype: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 48)).foregroundStyle(.orange)
            Text("搜索失败").font(.title3).fontWeight(.semibold)
            Text("千帆小说：连接超时").font(.subheadline).foregroundStyle(.secondary)
            Button("重试") {}.buttonStyle(.borderedProminent).tint(ReaderColors.primary)
            Text("书源异常，建议检查书源状态或切换书源").font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderColors.paperBg)
    }
}

struct BookDetailPrototype: View {
    let detail = PrototypeFixtures.bookDetail
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    Image(systemName: detail.cover).font(.system(size: 48))
                        .frame(width: 96, height: 128)
                        .background(ReaderColors.floatingControlBg)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detail.title).font(.title2).fontWeight(.bold).foregroundColor(ReaderColors.controlInk)
                        Text(detail.author).font(.subheadline).foregroundStyle(.secondary)
                        HStack {
                            Image(systemName: "link").font(.caption2)
                            Text(detail.sourceName).font(.caption).foregroundStyle(ReaderColors.primary)
                        }
                        Text("更新: \(detail.lastUpdated)").font(.caption2).foregroundStyle(.secondary)
                        Text("共 \(detail.tocCount) 章").font(.caption2).foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)

                Text(detail.intro).font(.subheadline).foregroundColor(ReaderColors.bodyText)
                    .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button(action: {}) {
                        Label("开始阅读", systemImage: "book").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent).tint(ReaderColors.primary)
                    Button(action: {}) {
                        Label("加入书架", systemImage: "books.vertical")
                    }.buttonStyle(.bordered)
                }.padding(.horizontal, 16)
            }
            .padding(.top, 16)
        }
        .background(ReaderColors.paperBg)
    }
}

struct BookDetailTOCPrototype: View {
    let chapters = PrototypeFixtures.tocItems
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("目录预览").font(ReaderTypography.controlTitle).foregroundColor(ReaderColors.controlInk)
                Spacer()
                Text("共 1205 章").font(.caption).foregroundStyle(.secondary)
                Image(systemName: "arrow.up.arrow.down").font(.caption)
            }

            ForEach(chapters.prefix(8)) { item in
                HStack {
                    if item.isCurrent {
                        Circle().fill(ReaderColors.primary).frame(width: 6, height: 6)
                    } else {
                        Circle().fill(Color.clear).frame(width: 6, height: 6)
                    }
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundColor(item.isCurrent ? ReaderColors.primary : ReaderColors.bodyText)
                        .padding(.leading, CGFloat(item.level) * 16)
                    if item.hasBookmark {
                        Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.orange)
                    }
                    Spacer()
                }
            }

            Button("查看完整目录") {}.font(.subheadline).frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(ReaderColors.floatingControlBg).clipShape(Capsule())
        }
        .padding()
    }
}

// MARK: - D. Reader Prototypes (9 control states)

struct ReaderBasePrototype: View {
    @State private var pageProgress: Double = 0.25
    @State private var brightness: Double = 0.6
    @State private var dock: BrightnessDock = .left
    var isNight: Bool = false

    var colors: (bg: Color, text: Color, ink: Color, pri: Color, float: Color, quick: Color, bar: Color) {
        isNight
        ? (ReaderColors.nightPaperBg, ReaderColors.nightBodyText, ReaderColors.nightControlInk, ReaderColors.nightPrimary, ReaderColors.nightFloatingControlBg, ReaderColors.nightQuickButtonBg, ReaderColors.nightBottomBarBg)
        : (ReaderColors.paperBg, ReaderColors.bodyText, ReaderColors.controlInk, ReaderColors.primary, ReaderColors.floatingControlBg, ReaderColors.quickButtonBg, ReaderColors.bottomBarBg)
    }

    var body: some View {
        ZStack {
            colors.bg.ignoresSafeArea()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(PrototypeFixtures.chapterTitle)
                        .font(ReaderTypography.chapterTitle).foregroundColor(colors.text)
                    Text(PrototypeFixtures.readerContent)
                        .font(ReaderTypography.readerBody).foregroundColor(colors.text)
                        .lineSpacing(18 * 0.72)
                }
                .padding(.horizontal, ReaderControlMetrics.contentPaddingHorizontal)
                .padding(.top, ReaderControlMetrics.contentPaddingTop)
                .padding(.bottom, ReaderControlMetrics.contentPaddingBottom)
            }

            // ── Four-corner info (跨平台基线：左上书名/右上电量/左下章节/右下时间) ──
            Group {
                // 左上：书名
                Text(PrototypeFixtures.bookDetail.title)
                    .font(ReaderTypography.controlLabel)
                    .foregroundColor(colors.ink.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.top, 8).padding(.leading, 20)
                // 右上：电量
                HStack(spacing: 2) {
                    Image(systemName: "battery.75percent")
                        .font(.caption2)
                    Text(PrototypeFixtures.batteryText)
                        .font(ReaderTypography.controlLabel)
                }
                .foregroundColor(colors.ink.opacity(0.7))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                .padding(.top, 8).padding(.trailing, 20)
                // 左下：章节
                Text(PrototypeFixtures.chapterTitle)
                    .font(ReaderTypography.controlLabel)
                    .foregroundColor(colors.ink.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    .padding(.bottom, ReaderControlMetrics.contentPaddingBottom - 50).padding(.leading, 20)
                // 右下：时间
                Text(PrototypeFixtures.timeText)
                    .font(ReaderTypography.controlLabel)
                    .foregroundColor(colors.ink.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.bottom, ReaderControlMetrics.contentPaddingBottom - 50).padding(.trailing, 20)
            }

            // Top bar
            VStack { ReaderBaseTopBar(); Spacer() }

            // Brightness bar (left, auto-brightness + dock arrow)
            VStack {
                Spacer()
                HStack {
                    VStack(spacing: 12) {
                        Image(systemName: "circle.lefthalf.filled").font(.caption).foregroundColor(colors.ink)
                        ZStack {
                            Capsule().fill(colors.ink.opacity(0.16)).frame(width: 4, height: 180)
                            VStack { Spacer()
                                Capsule().fill(colors.pri).frame(width: 4, height: 180 * brightness)
                            }
                            .clipShape(Capsule())
                        }
                        Image(systemName: dock == .left ? "chevron.right" : "chevron.left")
                            .font(.caption2).foregroundColor(colors.ink)
                    }
                    .frame(width: 40)
                    .padding(.vertical, 16)
                    .background(colors.float).clipShape(Capsule())
                    Spacer()
                }
                .padding(.leading, ReaderControlMetrics.brightnessInset)
                Spacer()
            }

            // Quick actions (no text labels)
            VStack { Spacer()
                HStack(spacing: ReaderControlMetrics.quickCircleGap) {
                    QuickButton(icon: "magnifyingglass", label: "搜索本章", ink: colors.ink, bg: colors.quick)
                    QuickButton(icon: "arrow.triangle.2.circlepath", label: "自动翻页", ink: colors.ink, bg: colors.quick)
                    QuickButton(icon: "text.magnifyingglass", label: "内容替换", ink: colors.ink, bg: colors.quick)
                    QuickButton(icon: isNight ? "sun.max.fill" : "moon.fill", label: "夜间/日间", ink: colors.ink, bg: colors.quick)
                }
                .padding(.bottom, 8)
                // Page control (本章内上一页/下一页)
                HStack {
                    Image(systemName: "chevron.left").foregroundColor(colors.pri).font(.title3)
                        .accessibilityLabel("本章内上一页")
                    ZStack(alignment: .leading) {
                        Capsule().fill(colors.ink.opacity(0.16)).frame(height: 4)
                        Capsule().fill(colors.pri).frame(width: 342 * pageProgress, height: 4)
                        Circle().fill(colors.pri).frame(width: 16, height: 16)
                            .offset(x: 342 * pageProgress - 8)
                    }
                    Image(systemName: "chevron.right").foregroundColor(colors.pri).font(.title3)
                        .accessibilityLabel("本章内下一页")
                }
                .frame(width: ReaderControlMetrics.pageControlWidth, height: ReaderControlMetrics.pageControlHeight)
                .padding(.horizontal, 24)
                .background(colors.float).clipShape(Capsule())
                .padding(.bottom, 8)
                Spacer()
            }

            // Bottom bar (目录/朗读/界面/设置 — 不含 WebDAV/书源/RSS)
            VStack { Spacer()
                HStack(spacing: 0) {
                    BottomBarButton(icon: "list.bullet", label: "目录", ink: colors.ink)
                    BottomBarButton(icon: "waveform", label: "朗读", ink: colors.ink)
                    BottomBarButton(icon: "paintpalette.fill", label: "界面", ink: colors.ink)
                    BottomBarButton(icon: "gearshape", label: "设置", ink: colors.ink)
                }
                .frame(height: ReaderControlMetrics.bottomBarHeight)
                .background(colors.bar)
            }
        }
    }
}

struct ReaderBaseTopBar: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "chevron.left").font(.title3)
                    .accessibilityLabel("返回").foregroundColor(ReaderColors.controlInk)
                Spacer()
                Text(PrototypeFixtures.bookDetail.title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(ReaderColors.controlInk)
                Spacer()
                HStack(spacing: 16) {
                    Image(systemName: "arrow.clockwise").accessibilityLabel("刷新当前章节")
                    Image(systemName: "arrow.left.arrow.right").accessibilityLabel("换源")
                    Image(systemName: "ellipsis").accessibilityLabel("更多操作")
                }
                .foregroundColor(ReaderColors.controlInk)
            }
            .frame(height: ReaderControlMetrics.topBarHeight)
            .padding(.horizontal, 16)
            .background(ReaderColors.softTopBg)

            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "link").font(.caption2)
                    Text(PrototypeFixtures.bookDetail.sourceName).font(.caption)
                }
                .foregroundColor(ReaderColors.primary)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .overlay(Capsule().stroke(ReaderColors.primary, lineWidth: 1))
                Spacer()
                Text(PrototypeFixtures.chapterTitle).font(.caption).foregroundStyle(.secondary)
            }
            .frame(height: ReaderControlMetrics.metaRowHeight)
            .padding(.horizontal, 16)
            .background(ReaderColors.metaBg)
        }
    }
}

struct QuickButton: View {
    let icon: String; let label: String; let ink: Color; let bg: Color
    var body: some View {
        Image(systemName: icon).font(.system(size: 20))
            .frame(width: ReaderControlMetrics.quickCircleSize, height: ReaderControlMetrics.quickCircleSize)
            .background(bg).clipShape(Circle()).foregroundColor(ink)
            .accessibilityLabel(label)
    }
}

struct BottomBarButton: View {
    let icon: String; let label: String; let ink: Color
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 20)).foregroundColor(ink)
            Text(label).font(ReaderTypography.controlLabel).foregroundColor(ink)
        }
        .frame(maxWidth: .infinity)
        .accessibilityLabel(label)
    }
}

// D.12-19 Reader Overlay Prototypes

struct ReaderSearchOverlayPrototype: View {
    @State private var searchText = ""
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("搜索本章").font(ReaderTypography.controlTitle).foregroundColor(ReaderColors.controlInk)
                Spacer()
                Image(systemName: "xmark").foregroundColor(ReaderColors.controlInk)
            }
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("输入关键词", text: $searchText)
            }
            .frame(height: 42).padding(.horizontal, 12)
            .background(ReaderColors.quickButtonBg).clipShape(RoundedRectangle(cornerRadius: 14))

            VStack(spacing: 8) {
                HStack {
                    Text("找到 3 处匹配").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    HStack(spacing: 16) {
                        Image(systemName: "chevron.up").accessibilityLabel("上一个匹配")
                        Image(systemName: "chevron.down").accessibilityLabel("下一个匹配")
                    }
                }
                Text("...韩立，天色不早了，你怎么还在**写字**？...")
                    .font(.subheadline).foregroundColor(ReaderColors.bodyText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(ReaderColors.floatingControlBgAlt).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
        .background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct ReaderAutoScrollOverlayPrototype: View {
    @State private var speed: Double = 0.5
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("自动翻页").font(ReaderTypography.controlTitle).foregroundColor(ReaderColors.controlInk)
                Spacer(); Image(systemName: "xmark")
            }
            HStack {
                ForEach(["滚动", "覆盖", "仿真"], id: \.self) { mode in
                    Text(mode).font(.caption).padding(.horizontal, 16).padding(.vertical, 6)
                        .background(ReaderColors.quickButtonBg).clipShape(Capsule())
                }
            }
            VStack(spacing: 4) {
                Text("翻页速度").font(.caption).foregroundStyle(.secondary)
                Slider(value: $speed).tint(ReaderColors.primary)
            }
            Button(action: {}) { Label("开始", systemImage: "play.fill").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).tint(ReaderColors.primary).controlSize(.large)
        }
        .padding(16)
        .background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct ReaderReplaceOverlayPrototype: View {
    let rules = PrototypeFixtures.replaceRules
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("内容替换").font(ReaderTypography.controlTitle).foregroundColor(ReaderColors.controlInk)
                Spacer(); Image(systemName: "xmark")
            }
            Text("仅显示当前书籍匹配规则").font(.caption).foregroundStyle(.secondary)
            ForEach(rules) { rule in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(rule.pattern) → \(rule.replacement)").font(.subheadline).foregroundColor(ReaderColors.controlInk)
                    }
                    Spacer()
                    Toggle("", isOn: .constant(rule.enabled)).tint(ReaderColors.primary)
                }
                .padding(10).background(ReaderColors.quickButtonBg).clipShape(RoundedRectangle(cornerRadius: 10))
            }
            Button("+ 添加规则") {}.font(.subheadline)
        }
        .padding(16)
        .background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct ReaderNightStatePrototype: View {
    var body: some View {
        VStack(spacing: 0) {
            ReaderBasePrototype(isNight: true)
            // Night toast (not a dialog)
            Text("已切换至夜间模式")
                .font(.caption).foregroundColor(ReaderColors.nightControlInk)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(ReaderColors.nightFloatingControlBgAlt).clipShape(Capsule())
                .offset(y: -100)
        }
    }
}

struct ReaderDirectoryOverlayPrototype: View {
    @State private var tab = 0
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("目录/书签").font(ReaderTypography.controlTitle).foregroundColor(ReaderColors.controlInk)
                Spacer(); Image(systemName: "xmark")
            }
            Picker("", selection: $tab) {
                Text("目录").tag(0); Text("书签").tag(1)
            }.pickerStyle(.segmented)

            ZStack(alignment: .trailing) {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(PrototypeFixtures.tocItems) { item in
                            HStack(spacing: 4) {
                                if item.isCurrent {
                                    Circle().fill(ReaderColors.primary).frame(width: 6, height: 6)
                                } else { Spacer().frame(width: 6) }
                                Text(item.title)
                                    .font(.subheadline)
                                    .foregroundColor(item.isCurrent ? ReaderColors.primary : ReaderColors.bodyText)
                                    .padding(.leading, CGFloat(item.level) * 14)
                                if item.hasBookmark {
                                    Image(systemName: "bookmark.fill").font(.caption2).foregroundStyle(.orange)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4).padding(.horizontal, 8)
                            .background(item.isCurrent ? ReaderColors.primary.opacity(0.08) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }.padding(.trailing, 8)
                }
                // 右侧常驻进度条
                Capsule().fill(ReaderColors.mutedTrack).frame(width: 4)
                    .overlay(alignment: .top) {
                        Capsule().fill(ReaderColors.primary).frame(height: 30)
                    }
                    .frame(maxHeight: .infinity).padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct ReaderTTSOverlayPrototype: View {
    @State private var rate: Double = 0.5
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("朗读").font(ReaderTypography.controlTitle).foregroundColor(ReaderColors.controlInk)
                Spacer(); Image(systemName: "xmark")
            }
            GroupBox("语音引擎") {
                HStack {
                    Text("系统默认").font(.subheadline).foregroundColor(ReaderColors.controlInk)
                    Spacer(); Image(systemName: "chevron.right").font(.caption)
                }
            }
            VStack(spacing: 4) { Text("语速").font(.caption).foregroundStyle(.secondary); Slider(value: $rate).tint(ReaderColors.primary) }
            Button(action: {}) { Label("开始朗读", systemImage: "play.fill").frame(maxWidth: .infinity) }
                .buttonStyle(.borderedProminent).tint(ReaderColors.primary)
            Text("朗读仅控制播放，不使用章节跳转语义").font(.caption2).foregroundStyle(.secondary)
        }
        .padding(16)
        .background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct ReaderAppearanceOverlayPrototype: View {
    @State private var fontSize: Double = 18
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("界面设置").font(ReaderTypography.controlTitle).foregroundColor(ReaderColors.controlInk)
                Spacer(); Image(systemName: "xmark")
            }
            GroupBox("字体") {
                HStack {
                    ForEach(["系统", "宋体", "黑体"], id: \.self) { f in
                        Text(f).font(.caption).frame(maxWidth: .infinity).padding(.vertical, 4)
                            .background(ReaderColors.quickButtonBg).clipShape(Capsule())
                    }
                }
            }
            VStack(spacing: 4) { Text("字号: \(Int(fontSize))").font(.caption); Slider(value: $fontSize, in: 12...32).tint(ReaderColors.primary) }
            GroupBox("间距") {
                VStack(spacing: 4) { Text("行间距").font(.caption); Slider(value: .constant(0.5)).tint(ReaderColors.primary) }
            }
        }
        .padding(16)
        .background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

struct ReaderSettingsOverlayPrototype: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("阅读设置").font(ReaderTypography.controlTitle).foregroundColor(ReaderColors.controlInk)
                Spacer(); Image(systemName: "xmark")
            }
            Text("只含阅读行为设置，不含 WebDAV/书源/RSS").font(.caption2).foregroundStyle(.secondary)
            SettingsRowPrototype(title: "屏幕方向", trailing: "竖屏")
            SettingsRowPrototype(title: "音量键翻页", trailing: "关闭")
            SettingsRowPrototype(title: "点击翻页", trailing: "开启")
            SettingsRowPrototype(title: "状态栏显示", trailing: "开启")
            Spacer()
        }
        .padding(16)
        .background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 22))
    }
}

// MARK: - E. Source Management

struct SourceListPrototype: View {
    let sources = PrototypeFixtures.sources
    var body: some View {
        List {
            ForEach(sources) { s in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(s.name).font(ReaderTypography.listTitle).foregroundColor(ReaderColors.controlInk)
                            Circle().fill(s.enabled ? Color.green : Color.red).frame(width: 8, height: 8)
                        }
                        Text(s.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    switch s.lastTest {
                    case .notRun: Text("未测试").font(.caption2).foregroundStyle(.secondary)
                    case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    case .failure(let msg): Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                    }
                    Toggle("", isOn: .constant(s.enabled)).tint(ReaderColors.primary).labelsHidden()
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
    }
}

struct SourceDetailPrototype: View {
    let s = PrototypeFixtures.sources[0]
    var body: some View {
        List {
            Section("基本信息") {
                LabeledContent("名称", value: s.name)
                LabeledContent("URL", value: s.url)
                LabeledContent("分组", value: s.group)
            }
            Section("规则摘要") {
                Text("搜索规则：css:.mh-list").font(.caption).foregroundStyle(.secondary)
                Text("详情规则：css:.mh-detail").font(.caption).foregroundStyle(.secondary)
            }
            Section { Button("测试书源") {}.tint(ReaderColors.primary)
                Button("编辑书源") {}
                Toggle("启用书源", isOn: .constant(true)).tint(ReaderColors.primary)
            }
        }
    }
}

struct SourceEditImportPrototype: View {
    @State private var showSuccess = true
    var body: some View {
        VStack(spacing: 16) {
            if showSuccess {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 48)).foregroundStyle(.green)
                    Text("导入成功").font(.title3).fontWeight(.semibold)
                    Text("已添加 1 个书源").font(.subheadline).foregroundStyle(.secondary)
                    Button("前往书源列表") {}.buttonStyle(.borderedProminent).tint(ReaderColors.primary)
                }
            }
            Divider().padding(.horizontal)
            Text("编辑模式").font(ReaderTypography.listTitle)
            TextField("书源名称", text: .constant("千帆小说"))
                .textFieldStyle(.roundedBorder)
            TextField("书源 URL", text: .constant("https://www.qianfanxs.com"))
                .textFieldStyle(.roundedBorder)
            Text("JSON 校验通过").font(.caption).foregroundStyle(.green)
        }
        .padding()
    }
}

struct SourceTestErrorPrototype: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    Text("全本书屋").font(ReaderTypography.listTitle)
                    Text("测试中...").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                ProgressView()
            }.padding().background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                VStack(alignment: .leading) {
                    Text("无名书源").font(ReaderTypography.listTitle)
                    Text("连接超时 — 请检查网络和 URL").font(.caption).foregroundStyle(.red)
                }
                Spacer()
                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
            }.padding().background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 12))

            HStack {
                VStack(alignment: .leading) {
                    Text("禁用书源").font(ReaderTypography.listTitle)
                    Text("已停用，点击启用").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "pause.circle.fill").foregroundStyle(.orange)
            }.padding().background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
    }
}

// MARK: - F. Discover / RSS / WebDAV / Sync

struct DiscoverHomePrototype: View {
    let sections = PrototypeFixtures.discoverSections
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("发现").font(ReaderTypography.pageTitle).foregroundColor(ReaderColors.controlInk).padding(.horizontal, 16)
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(ReaderTypography.listTitle).foregroundColor(ReaderColors.controlInk)
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(section.items) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Image(systemName: "book.circle").font(.system(size: 36))
                                            .frame(width: 80, height: 100)
                                            .background(ReaderColors.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: 10))
                                        Text(item.title).font(.caption).fontWeight(.medium).lineLimit(1)
                                        Text(item.author).font(.caption2).foregroundStyle(.secondary)
                                    }.frame(width: 100)
                                }
                            }.padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.top, 16)
        }
        .background(ReaderColors.paperBg)
    }
}

struct RSSListPrototype: View {
    let feeds = PrototypeFixtures.rssFeeds
    var body: some View {
        List(feeds) { feed in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(feed.name).font(ReaderTypography.listTitle).foregroundColor(ReaderColors.controlInk)
                    Text("更新: \(feed.lastUpdate)").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if feed.unreadCount > 0 {
                    Text("\(feed.unreadCount)").font(.caption).padding(.horizontal, 8).padding(.vertical, 2)
                        .background(ReaderColors.primary).foregroundStyle(.white).clipShape(Capsule())
                }
                Circle().fill(feed.enabled ? Color.green : Color.gray).frame(width: 8, height: 8)
            }
        }
        .listStyle(.plain)
    }
}

struct RSSDetailPrototype: View {
    let articles = PrototypeFixtures.rssArticles
    var body: some View {
        List(articles) { article in
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    if !article.isRead { Circle().fill(ReaderColors.primary).frame(width: 6, height: 6) }
                    Text(article.title).font(ReaderTypography.listTitle).foregroundColor(ReaderColors.controlInk)
                }
                Text(article.summary).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                HStack {
                    Text(article.feedName).font(.caption2).foregroundStyle(ReaderColors.primary)
                    Spacer()
                    Text(article.date).font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.plain)
    }
}

struct RSSSubscriptionsPrototype: View {
    let feeds = PrototypeFixtures.rssFeeds
    var body: some View {
        List {
            ForEach(feeds) { feed in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(feed.name).font(ReaderTypography.listTitle)
                        Text(feed.url).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                    Spacer()
                    Toggle("", isOn: .constant(feed.enabled)).tint(ReaderColors.primary).labelsHidden()
                }
            }
            Section {
                Button(action: {}) { Label("添加订阅", systemImage: "plus").frame(maxWidth: .infinity) }
            }
        }
        .listStyle(.plain)
    }
}

struct WebDAVConfigPrototype: View {
    let config = PrototypeFixtures.webdavConfig
    var body: some View {
        Form {
            Section("服务器配置") {
                HStack {
                    Text("服务器地址").foregroundStyle(.secondary)
                    Spacer()
                    Text(config.serverURL).font(.caption).lineLimit(1)
                }
                HStack {
                    Text("用户名").foregroundStyle(.secondary)
                    Spacer()
                    Text(config.username).font(.caption)
                }
                SecureField("密码", text: .constant("********")) {}.disabled(true)
            }
            Section {
                HStack {
                    Label("连接状态", systemImage: config.isConnected ? "checkmark.icloud" : "xmark.icloud")
                    Spacer()
                    Text(config.isConnected ? "已连接" : "未连接").foregroundStyle(config.isConnected ? Color.green : .secondary)
                }
            }
            Section {
                Button("连接测试") {}.tint(ReaderColors.primary)
            }
            Text("不保存真实账号/token，仅原型展示").font(.caption2).foregroundStyle(.secondary)
        }
    }
}

struct BackupSettingsPrototype: View {
    @State private var autoBackup = false
    var body: some View {
        List {
            Section("备份范围") {
                Toggle("书籍数据", isOn: .constant(true)).tint(ReaderColors.primary)
                Toggle("阅读进度", isOn: .constant(true)).tint(ReaderColors.primary)
                Toggle("书源配置", isOn: .constant(false)).tint(ReaderColors.primary)
            }
            Section("自动备份") {
                Toggle("自动备份", isOn: $autoBackup).tint(ReaderColors.primary)
                if autoBackup {
                    Text("频率：每日").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section { Button("立即备份") {}.tint(ReaderColors.primary) }
            Section { Text("上次备份：2026-05-20 02:00").font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct SyncProgressPrototype: View {
    let progress = PrototypeFixtures.syncProgress
    var body: some View {
        List {
            Section("阅读进度") {
                LabeledContent("本地进度", value: progress.localProgress)
                LabeledContent("云端进度", value: progress.remoteProgress)
            }
            if progress.hasConflict {
                Section("冲突") {
                    Text("本地与云端进度不一致").font(.caption).foregroundStyle(.orange)
                    Button("保留本地") {}
                    Button("保留云端") {}
                    Button("合并") {}.tint(ReaderColors.primary)
                }
            }
            Section { LabeledContent("上次同步", value: progress.lastSync) }
            Section { Button("立即同步") {}.tint(ReaderColors.primary) }
        }
    }
}

struct RemoteWebDAVBooksPrototype: View {
    let books = PrototypeFixtures.remoteBooks
    var body: some View {
        List(books) { book in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.name).font(ReaderTypography.listTitle).foregroundColor(ReaderColors.controlInk)
                    Text(book.size).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                switch book.status {
                case .notDownloaded:
                    Image(systemName: "icloud.and.arrow.down").foregroundStyle(ReaderColors.primary)
                case .downloaded:
                    Image(systemName: "checkmark.icloud").foregroundStyle(.green)
                case .downloading(let p):
                    ProgressView(value: p).frame(width: 40)
                }
            }
        }
    }
}

struct SyncErrorPrototype: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.icloud.fill").font(.system(size: 48)).foregroundStyle(.red)
            Text("WebDAV 认证失败").font(.title3).fontWeight(.semibold)
            Text("用户名或密码错误，请重新配置").font(.subheadline).foregroundStyle(.secondary)
            Button("重新登录") {}.buttonStyle(.borderedProminent).tint(ReaderColors.primary)
            Button("跳过") {}.buttonStyle(.bordered)
            Divider().padding(.horizontal, 40)
            Image(systemName: "wifi.slash").font(.system(size: 48)).foregroundStyle(.orange)
            Text("网络不可达").font(.title3).fontWeight(.semibold)
            Text("请检查网络连接和服务器地址").font(.subheadline).foregroundStyle(.secondary)
            Button("重试") {}.buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderColors.paperBg)
    }
}

// MARK: - G. Settings / State Pages

struct GlobalSettingsPrototype: View {
    var body: some View {
        List {
            Section("外观") {
                SettingsRowPrototype(title: "主题", trailing: "跟随系统")
                SettingsRowPrototype(title: "字体", trailing: "系统默认")
            }
            Section("阅读") {
                SettingsRowPrototype(title: "阅读设置", trailing: "翻页/字号/间距")
                SettingsRowPrototype(title: "朗读设置", trailing: "语速/音色")
            }
            Section("书架") {
                SettingsRowPrototype(title: "默认视图", trailing: "封面")
                SettingsRowPrototype(title: "自动刷新", trailing: "开启")
            }
            Section("备份与同步") {
                SettingsRowPrototype(title: "WebDAV 备份", trailing: "未连接")
                SettingsRowPrototype(title: "阅读进度同步", trailing: "已同步")
            }
            Section("关于") {
                SettingsRowPrototype(title: "版本", trailing: "0.1.0")
                SettingsRowPrototype(title: "开源许可", trailing: "")
            }
        }
    }
}

struct SettingsRowPrototype: View {
    let title: String; let trailing: String
    var body: some View {
        HStack {
            Text(title).font(.subheadline).foregroundColor(ReaderColors.controlInk)
            Spacer()
            Text(trailing).font(.subheadline).foregroundStyle(.secondary)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct StatePagePrototype: View {
    let state: ReaderUiState
    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .loading:
                ProgressView().scaleEffect(1.5)
                Text("加载中...").font(.headline).foregroundStyle(.secondary)
            case .empty:
                Image(systemName: "doc.text").font(.system(size: 48)).foregroundStyle(.secondary)
                Text("暂无内容").font(.headline)
                Text("试试添加一些内容吧").font(.subheadline).foregroundStyle(.secondary)
                Button("去添加") {}.buttonStyle(.borderedProminent).tint(ReaderColors.primary)
            case .error(let msg, let retryable):
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 48)).foregroundStyle(.orange)
                Text("出错了").font(.headline)
                Text(msg).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                if retryable {
                    Button("重试") {}.buttonStyle(.borderedProminent).tint(ReaderColors.primary)
                }
            case .offline:
                Image(systemName: "wifi.slash").font(.system(size: 48)).foregroundStyle(.secondary)
                Text("离线状态").font(.headline)
                Text("已缓存的内容仍可阅读").font(.subheadline).foregroundStyle(.secondary)
            case .permissionRequired(let perm):
                Image(systemName: "lock.shield").font(.system(size: 48)).foregroundStyle(.orange)
                Text("需要权限").font(.headline)
                Text("请在系统设置中允许「\(perm)」权限").font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                Button("去设置") {}.buttonStyle(.borderedProminent).tint(ReaderColors.primary)
            default:
                Text("未知状态").font(.headline)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderColors.paperBg)
    }
}
