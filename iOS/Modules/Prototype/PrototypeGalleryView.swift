import SwiftUI

// MARK: - Prototype Gallery Catalog (38 entries, fixture-driven, debug-only)
// 外壳已 demo 化：DemoBackScreen + ScrollView + ReaderCard entry list + .sheet(item:) detail。
// 所有原型内部已去除 NavigationStack/List/Section/NavigationLink/SF Symbols/Form/GroupBox/LabeledContent/.borderedProminent/.bordered。

public struct PrototypeGalleryView: View {
    @State private var selectedEntry: PrototypeEntry?

    private let entries: [PrototypeEntry] = PrototypeGalleryView.allEntries

    public init() {}

    public var body: some View {
        DemoBackScreen(title: "[DEBUG] Prototype Gallery") {
            ScrollView {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                    Text("38 个原型 · fixture-driven · 不接真实网络")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .padding(.bottom, 4)

                    ForEach(PrototypeGroup.allCases) { group in
                        let groupEntries = entries.filter { $0.group == group }
                        if !groupEntries.isEmpty {
                            PrototypeGroupSection(group: group, entries: groupEntries) { entry in
                                selectedEntry = entry
                            }
                        }
                    }
                }
                .padding(.horizontal, ReaderDesignTokens.demoContentHorizontalPadding)
                .padding(.top, ReaderDesignTokens.demoContentVerticalPadding)
                .padding(.bottom, ReaderDesignTokens.demoContentVerticalPadding)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
        }
        .sheet(item: $selectedEntry) { entry in
            PrototypeEntryDetailContainer(entry: entry)
        }
    }
}

private struct PrototypeGroupSection: View {
    let group: PrototypeGroup
    let entries: [PrototypeEntry]
    let onSelect: (PrototypeEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(group.assetIcon, size: 18, accessibilityLabel: group.rawValue)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                Text(group.rawValue)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            }
            .padding(.top, 8)

            ForEach(entries) { entry in
                Button {
                    onSelect(entry)
                } label: {
                    ReaderCard {
                        HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.name)
                                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                                if !entry.description.isEmpty {
                                    Text(entry.description)
                                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            ReaderIcon(.chevron, size: 16, accessibilityLabel: "查看")
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                                .rotationEffect(.degrees(90))
                        }
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(DemoPressButtonStyle())
                .accessibilityLabel(entry.name)
            }
        }
    }
}

private struct PrototypeEntryDetailContainer: View {
    let entry: PrototypeEntry

    var body: some View {
        DemoBackScreen(title: entry.name) {
            ScrollView {
                entry.content()
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
        }
    }
}

extension PrototypeGalleryView {
    /// 主底栏 4 Tab fixture（用于测试断言：不包含 阅读/搜索/设置）。
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

// MARK: - Demo Button Helpers (替换 .borderedProminent / .bordered)

private struct DemoPrimaryActionButton: View {
    let title: String
    let icon: ReaderAssetIcon?
    let action: () -> Void

    init(_ title: String, icon: ReaderAssetIcon? = nil, action: @escaping () -> Void = {}) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    ReaderIcon(icon, size: 16, accessibilityLabel: title)
                }
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            .background(Capsule().fill(ReaderDesignTokens.Color.primary))
        }
        .buttonStyle(DemoPressButtonStyle())
        .accessibilityLabel(title)
    }
}

private struct DemoSecondaryActionButton: View {
    let title: String
    let icon: ReaderAssetIcon?
    let action: () -> Void

    init(_ title: String, icon: ReaderAssetIcon? = nil, action: @escaping () -> Void = {}) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    ReaderIcon(icon, size: 16, accessibilityLabel: title)
                }
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .lineLimit(1)
            }
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            .background(
                Capsule()
                    .fill(ReaderDesignTokens.Color.surface)
                    .overlay(Capsule().stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1))
            )
        }
        .buttonStyle(DemoPressButtonStyle())
        .accessibilityLabel(title)
    }
}

/// `LabeledContent` 的 demo 替代。
private struct PrototypeMetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Spacer()
            Text(value)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// `GroupBox` 的 demo 替代。
private struct PrototypeFieldGroup<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - A. App Shell Prototype

struct AppShellPrototype: View {
    @State private var selectedTab = 0
    private let tabs: [(ReaderAssetIcon, String)] = [
        (.bookshelf, "书架"), (.discover, "发现"),
        (.source, "书源"), (.people, "我的")
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
                            ReaderIcon(tabs[idx].0, size: 22, accessibilityLabel: tabs[idx].1)
                            Text(tabs[idx].1)
                                .font(ReaderTypography.controlLabel)
                        }
                        .foregroundColor(selectedTab == idx ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.controlInk)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DemoPressButtonStyle())
                }
            }
            .frame(height: ReaderControlMetrics.bottomBarHeight)
            .background(ReaderDesignTokens.Color.bottomBarBg)
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
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                PrototypeSettingsGroup(header: "个人") {
                    PrototypeNavRow(icon: .gear, title: "设置")
                    PrototypeNavRow(icon: .clock, title: "阅读记录")
                    PrototypeNavRow(icon: .activity, title: "阅读统计")
                    PrototypeNavRow(icon: .bookmark, title: "收藏/书签")
                }
                PrototypeSettingsGroup(header: "备份与同步") {
                    PrototypeNavRow(icon: .cloud, title: "WebDAV 备份")
                    PrototypeNavRow(icon: .sync, title: "同步进度")
                    PrototypeNavRow(icon: .storage, title: "备份设置")
                }
            }
            .padding(.horizontal, ReaderDesignTokens.demoContentHorizontalPadding)
            .padding(.vertical, ReaderDesignTokens.demoContentVerticalPadding)
        }
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

private struct PrototypeNavRow: View {
    let icon: ReaderAssetIcon
    let title: String

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(icon, size: 18, accessibilityLabel: title)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Spacer()
            ReaderIcon(.chevron, size: 14, accessibilityLabel: "查看")
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .rotationEffect(.degrees(90))
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight)
    }
}

private struct PrototypeSettingsGroup<Content: View>: View {
    let header: String
    let content: Content

    init(header: String, @ViewBuilder content: () -> Content) {
        self.header = header
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(header)
                .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .padding(.bottom, 6)
            ReaderCard {
                VStack(spacing: 0) {
                    content
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
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
                Text("书架").font(ReaderTypography.pageTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                ReaderIcon(.grid, size: 22, accessibilityLabel: "封面模式")
                    .foregroundColor(ReaderDesignTokens.Color.primary)
                ReaderIcon(.search, size: 22, accessibilityLabel: "搜索")
                    .foregroundColor(ReaderDesignTokens.Color.controlInk).padding(.leading, 12)
                ReaderIcon(.more, size: 22, accessibilityLabel: "更多")
                    .foregroundColor(ReaderDesignTokens.Color.controlInk).padding(.leading, 4)
            }.padding(.horizontal, 16).padding(.top, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: ReaderSpacing.lg) {
                    ForEach(books) { book in
                        VStack(alignment: .leading, spacing: 4) {
                            ReaderIcon(.book, size: 32, accessibilityLabel: book.title)
                                .frame(maxWidth: .infinity)
                                .frame(height: 100)
                                .background(ReaderDesignTokens.Color.floatingControlBg)
                                .clipShape(ReaderShapes.card)

                            Text(book.title).font(ReaderTypography.listTitle)
                                .foregroundColor(ReaderDesignTokens.Color.controlInk).lineLimit(1)
                            Text(book.author).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                            // demo `.fd-restore-progress-meter`：8px pill。
                            DemoRestoreProgressMeter(progress: book.progress, tint: ReaderDesignTokens.Color.primary)
                            Text("\(Int(book.progress * 100))%")
                                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

struct BookshelfListPrototype: View {
    private let books = PrototypeFixtures.bookshelfBooks

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("书架").font(ReaderTypography.pageTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                ReaderIcon(.list, size: 22, accessibilityLabel: "列表模式")
                    .foregroundColor(ReaderDesignTokens.Color.primary)
            }.padding(.horizontal, 16).padding(.top, 8)

            ScrollView {
                VStack(spacing: 8) {
                    ForEach(books) { book in
                        HStack(spacing: 12) {
                            ReaderIcon(.book, size: 22, accessibilityLabel: book.title)
                                .frame(width: 48, height: 64)
                                .background(ReaderDesignTokens.Color.floatingControlBg)
                                .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))

                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(book.title).font(ReaderTypography.listTitle)
                                        .foregroundColor(ReaderDesignTokens.Color.controlInk)
                                    Spacer()
                                    Text(book.group).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(ReaderDesignTokens.Color.floatingControlBg)
                                        .clipShape(Capsule())
                                }
                                Text(book.author).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                                // demo `.fd-restore-progress-meter`：8px pill。
                                DemoRestoreProgressMeter(progress: book.progress, tint: ReaderDesignTokens.Color.primary)
                                HStack {
                                    Text(book.lastChapter).font(.system(size: ReaderDesignTokens.settingsRowValueFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted).lineLimit(1)
                                    Spacer()
                                    Text("\(Int(book.progress * 100))%").font(.system(size: ReaderDesignTokens.settingsRowValueFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding(16)
            }
        }
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

struct BookshelfEmptyPrototype: View {
    var body: some View {
        VStack(spacing: 20) {
            ReaderIcon(.bookshelf, size: 48, accessibilityLabel: "书架空空")
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text("书架空空").font(.system(size: ReaderDesignTokens.readerOverlayLargeTitleFontSize, weight: .semibold))
            Text("去搜索或发现页面添加书籍吧").font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            HStack(spacing: 16) {
                DemoPrimaryActionButton("添加书籍", icon: .add)
                DemoSecondaryActionButton("导入书源", icon: .upload)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

// MARK: - C. Search / Detail Prototypes

struct SearchHomePrototype: View {
    @State private var query = ""
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                ReaderIcon(.search, size: 18, accessibilityLabel: "搜索")
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                TextField("搜索书名或作者", text: $query)
                    .font(ReaderTypography.readerBody)
            }
            .frame(height: 44).padding(.horizontal, 12)
            .background(ReaderDesignTokens.Color.metaBg)
            .clipShape(Capsule())
            .padding(.horizontal, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("搜索历史").font(ReaderTypography.listTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                ForEach(PrototypeFixtures.searchHistory, id: \.self) { item in
                    HStack {
                        ReaderIcon(.clock, size: 14, accessibilityLabel: "历史")
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                        Text(item).font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundColor(ReaderDesignTokens.Color.ink)
                        Spacer()
                    }.padding(.vertical, 4)
                }
            }.padding(.horizontal, 16)
            Spacer()
        }
        .padding(.top, 16)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

struct SearchResultsPrototype: View {
    let results = PrototypeFixtures.searchResults
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(results) { r in
                    ReaderCard {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(r.title).font(ReaderTypography.listTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                                Spacer()
                                Text("\(r.sourceCount) 个书源").font(.system(size: ReaderDesignTokens.discoverBookRowSmallFontSize)).foregroundStyle(ReaderDesignTokens.Color.primary)
                            }
                            Text(r.author).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                            Text(r.intro).font(.system(size: ReaderDesignTokens.discoverBookRowBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted).lineLimit(2)
                            HStack {
                                Text("来源: \(r.sourceName)").font(.system(size: ReaderDesignTokens.discoverBookRowSmallFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                                Spacer()
                                DemoPrimaryActionButton("加入书架", icon: .add)
                                    .frame(maxWidth: 120)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct SearchEmptyPrototype: View {
    var body: some View {
        VStack(spacing: 16) {
            ReaderIcon(.search, size: 48, accessibilityLabel: "没有找到结果")
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text("没有找到结果").font(.system(size: ReaderDesignTokens.continueCardTitleFontSize, weight: .semibold))
            Text("试试换个关键词，或检查书源是否已启用")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

struct SearchErrorPrototype: View {
    var body: some View {
        VStack(spacing: 16) {
            ReaderIcon(.warning, size: 48, accessibilityLabel: "搜索失败")
                .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
            Text("搜索失败").font(.system(size: ReaderDesignTokens.continueCardTitleFontSize, weight: .semibold))
            Text("千帆小说：连接超时").font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            DemoPrimaryActionButton("重试", icon: .refresh)
            Text("书源异常，建议检查书源状态或切换书源").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

struct BookDetailPrototype: View {
    let detail = PrototypeFixtures.bookDetail
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    ReaderIcon(.book, size: 48, accessibilityLabel: detail.title)
                        .frame(width: 96, height: 128)
                        .background(ReaderDesignTokens.Color.floatingControlBg)
                        .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detail.title).font(.system(size: ReaderDesignTokens.readerOverlayLargeTitleFontSize, weight: .bold)).foregroundColor(ReaderDesignTokens.Color.controlInk)
                        Text(detail.author).font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                        HStack {
                            ReaderIcon(.link, size: 12, accessibilityLabel: "书源")
                            Text(detail.sourceName).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.primary)
                        }
                        Text("更新: \(detail.lastUpdated)").font(.system(size: ReaderDesignTokens.discoverBookRowSmallFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                        Text("共 \(detail.tocCount) 章").font(.system(size: ReaderDesignTokens.discoverBookRowSmallFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                    }
                }
                .padding(.horizontal, 16)

                Text(detail.intro).font(.system(size: ReaderDesignTokens.rssReaderBodyFontSize)).foregroundColor(ReaderDesignTokens.Color.ink)
                    .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    DemoPrimaryActionButton("开始阅读", icon: .bookOpen)
                    DemoSecondaryActionButton("加入书架", icon: .bookshelf)
                }.padding(.horizontal, 16)
            }
            .padding(.top, 16)
        }
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

struct BookDetailTOCPrototype: View {
    let chapters = PrototypeFixtures.tocItems
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("目录预览").font(ReaderTypography.controlTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                Text("共 1205 章").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                ReaderIcon(.sort, size: 14, accessibilityLabel: "排序")
            }

            ForEach(chapters.prefix(8)) { item in
                HStack {
                    if item.isCurrent {
                        Circle().fill(ReaderDesignTokens.Color.primary).frame(width: 6, height: 6)
                    } else {
                        Circle().fill(Color.clear).frame(width: 6, height: 6)
                    }
                    Text(item.title)
                        .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize))
                        .foregroundColor(item.isCurrent ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.ink)
                        .padding(.leading, CGFloat(item.level) * 16)
                    if item.hasBookmark {
                        ReaderIcon(.bookmark, size: 12, accessibilityLabel: "已加书签")
                            .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
                    }
                    Spacer()
                }
            }

            DemoSecondaryActionButton("查看完整目录", icon: .list)
        }
        .padding()
    }
}

// MARK: - D. Reader Prototypes (9 control states)

struct ReaderBasePrototype: View {
    @State private var pageProgress: Double = 0.25
    @State private var brightness: Double = 0.6
    var isNight: Bool = false

    var colors: (bg: Color, text: Color, ink: Color, pri: Color, float: Color, quick: Color, bar: Color) {
        isNight
        ? (ReaderDesignTokens.Color.paperSolid, ReaderDesignTokens.Color.ink, ReaderDesignTokens.Color.controlInk, ReaderDesignTokens.Color.primary, ReaderDesignTokens.Color.floatingControlBg, ReaderDesignTokens.Color.metaBg, ReaderDesignTokens.Color.bottomBarBg)
        : (ReaderDesignTokens.Color.paperSolid, ReaderDesignTokens.Color.ink, ReaderDesignTokens.Color.controlInk, ReaderDesignTokens.Color.primary, ReaderDesignTokens.Color.floatingControlBg, ReaderDesignTokens.Color.metaBg, ReaderDesignTokens.Color.bottomBarBg)
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
                    ReaderIcon(.battery, size: 14, accessibilityLabel: "电量")
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

            // Quick actions (no text labels)
            VStack { Spacer()
                HStack(spacing: ReaderControlMetrics.quickCircleGap) {
                    QuickButton(icon: .readerContentSearch, label: "搜索本章", ink: colors.ink, bg: colors.quick)
                    QuickButton(icon: .readerAutoPage, label: "自动翻页", ink: colors.ink, bg: colors.quick)
                    QuickButton(icon: .readerContentReplace, label: "内容替换", ink: colors.ink, bg: colors.quick)
                    QuickButton(icon: isNight ? .sun : .nightMode, label: "夜间/日间", ink: colors.ink, bg: colors.quick)
                }
                .padding(.bottom, 8)
                // Page control (本章内上一页/下一页)
                HStack {
                    ReaderIcon(.chevronLeft, size: 18, accessibilityLabel: "本章内上一页")
                        .foregroundColor(colors.pri)
                    ZStack(alignment: .leading) {
                        Capsule().fill(colors.ink.opacity(0.16)).frame(height: 4)
                        Capsule().fill(colors.pri).frame(width: 342 * pageProgress, height: 4)
                        Circle().fill(colors.pri).frame(width: 16, height: 16)
                            .offset(x: 342 * pageProgress - 8)
                    }
                    ReaderIcon(.chevron, size: 18, accessibilityLabel: "本章内下一页")
                        .foregroundColor(colors.pri)
                        .rotationEffect(.degrees(180))
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
                    BottomBarButton(icon: .readerModuleDirectory, label: "目录", ink: colors.ink)
                    BottomBarButton(icon: .readerModuleTts, label: "朗读", ink: colors.ink)
                    BottomBarButton(icon: .readerModuleAppearance, label: "界面", ink: colors.ink)
                    BottomBarButton(icon: .readerModuleSettings, label: "设置", ink: colors.ink)
                }
                .frame(height: ReaderControlMetrics.bottomBarHeight)
                .background(colors.bar)
            }
        }
        .overlay(alignment: .top) {
            // Brightness — demo `.fd-reader-step-row` 风格 +/- 步进（非系统 Slider）
            DemoSliderControl(
                title: "亮度",
                value: $brightness,
                range: 0...1,
                step: 0.1,
                valueFormatter: { String(format: "%.0f%%", $0 * 100) }
            )
            .padding(.horizontal, 16)
            .background(colors.float, in: RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))
            .padding(.horizontal, 20)
            .padding(.top, 56 + 48 + 8)  // topBar + metaRow + gap
        }
    }
}

struct ReaderBaseTopBar: View {
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                ReaderIcon(.chevronLeft, size: 18, accessibilityLabel: "返回")
                    .foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                Text(PrototypeFixtures.bookDetail.title)
                    .font(.system(size: ReaderDesignTokens.readerOverlaySectionTitleFontSize, weight: .semibold))
                    .foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                HStack(spacing: 16) {
                    ReaderIcon(.refresh, size: 18, accessibilityLabel: "刷新当前章节")
                    ReaderIcon(.sourceSwitch, size: 18, accessibilityLabel: "换源")
                    ReaderIcon(.more, size: 18, accessibilityLabel: "更多操作")
                }
                .foregroundColor(ReaderDesignTokens.Color.controlInk)
            }
            .frame(height: ReaderControlMetrics.topBarHeight)
            .padding(.horizontal, 16)
            .background(ReaderDesignTokens.Color.readerTopBackground)

            HStack {
                HStack(spacing: 4) {
                    ReaderIcon(.link, size: 12, accessibilityLabel: "书源")
                    Text(PrototypeFixtures.bookDetail.sourceName).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                }
                .foregroundColor(ReaderDesignTokens.Color.primary)
                .padding(.horizontal, 10).padding(.vertical, 2)
                .overlay(Capsule().stroke(ReaderDesignTokens.Color.primary, lineWidth: 1))
                Spacer()
                Text(PrototypeFixtures.chapterTitle).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .frame(height: ReaderControlMetrics.metaRowHeight)
            .padding(.horizontal, 16)
            .background(ReaderDesignTokens.Color.metaBg)
        }
    }
}

struct QuickButton: View {
    let icon: ReaderAssetIcon
    let label: String
    let ink: Color
    let bg: Color
    var body: some View {
        ReaderIcon(icon, size: 20, accessibilityLabel: label)
            .frame(width: ReaderControlMetrics.quickCircleSize, height: ReaderControlMetrics.quickCircleSize)
            .background(bg).clipShape(Circle()).foregroundColor(ink)
            .accessibilityLabel(label)
    }
}

struct BottomBarButton: View {
    let icon: ReaderAssetIcon
    let label: String
    let ink: Color
    var body: some View {
        VStack(spacing: 4) {
            ReaderIcon(icon, size: 20, accessibilityLabel: label).foregroundColor(ink)
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
                Text("搜索本章").font(ReaderTypography.controlTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                ReaderIcon(.close, size: 18, accessibilityLabel: "关闭")
                    .foregroundColor(ReaderDesignTokens.Color.controlInk)
            }
            HStack {
                ReaderIcon(.search, size: 16, accessibilityLabel: "搜索")
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                TextField("输入关键词", text: $searchText)
            }
            .frame(height: 42).padding(.horizontal, 12)
            .background(ReaderDesignTokens.Color.metaBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))

            VStack(spacing: 8) {
                HStack {
                    Text("找到 3 处匹配").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                    Spacer()
                    HStack(spacing: 16) {
                        ReaderIcon(.chevron, size: 14, accessibilityLabel: "上一个匹配")
                            .rotationEffect(.degrees(-90))
                        ReaderIcon(.chevron, size: 14, accessibilityLabel: "下一个匹配")
                            .rotationEffect(.degrees(90))
                    }
                }
                Text("...韩立，天色不早了，你怎么还在**写字**？...")
                    .font(.system(size: ReaderDesignTokens.rssReaderBodyFontSize)).foregroundColor(ReaderDesignTokens.Color.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(ReaderDesignTokens.Color.floatingControlBgAlt).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
            }
        }
        .padding(16)
        .background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl))
    }
}

struct ReaderAutoScrollOverlayPrototype: View {
    @State private var speed: Double = 0.5
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("自动翻页").font(ReaderTypography.controlTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                ReaderIcon(.close, size: 18, accessibilityLabel: "关闭")
            }
            HStack {
                ForEach(["滚动", "覆盖", "仿真"], id: \.self) { mode in
                    Text(mode).font(.system(size: ReaderDesignTokens.chipFontSize)).padding(.horizontal, 16).padding(.vertical, 6)
                        .background(ReaderDesignTokens.Color.metaBg).clipShape(Capsule())
                }
            }
            DemoSliderControl(title: "翻页速度", value: $speed, range: 0...1, step: 0.1)
            DemoPrimaryActionButton("开始", icon: .play)
        }
        .padding(16)
        .background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl))
    }
}

struct ReaderReplaceOverlayPrototype: View {
    let rules = PrototypeFixtures.replaceRules
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("内容替换").font(ReaderTypography.controlTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                ReaderIcon(.close, size: 18, accessibilityLabel: "关闭")
            }
            Text("仅显示当前书籍匹配规则").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            ForEach(rules) { rule in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(rule.pattern) → \(rule.replacement)").font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundColor(ReaderDesignTokens.Color.controlInk)
                    }
                    Spacer()
                    DemoSettingsSwitch(isOn: rule.enabled)
                }
                .padding(10).background(ReaderDesignTokens.Color.metaBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))
            }
            DemoSecondaryActionButton("+ 添加规则", icon: .add)
        }
        .padding(16)
        .background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl))
    }
}

struct ReaderNightStatePrototype: View {
    var body: some View {
        VStack(spacing: 0) {
            ReaderBasePrototype(isNight: true)
            // Night toast (not a dialog)
            Text("已切换至夜间模式")
                .font(.system(size: ReaderDesignTokens.chipFontSize)).foregroundColor(ReaderDesignTokens.Color.controlInk)
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(ReaderDesignTokens.Color.floatingControlBgAlt).clipShape(Capsule())
                .offset(y: -100)
        }
    }
}

struct ReaderDirectoryOverlayPrototype: View {
    @State private var tab: DemoTocSwitchRow.Tab = .toc
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("目录/书签").font(ReaderTypography.controlTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                ReaderIcon(.close, size: 18, accessibilityLabel: "关闭")
            }
            DemoTocSwitchRow(selection: $tab)

            ZStack(alignment: .trailing) {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(PrototypeFixtures.tocItems) { item in
                            HStack(spacing: 4) {
                                if item.isCurrent {
                                    Circle().fill(ReaderDesignTokens.Color.primary).frame(width: 6, height: 6)
                                } else { Spacer().frame(width: 6) }
                                Text(item.title)
                                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize))
                                    .foregroundColor(item.isCurrent ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.ink)
                                    .padding(.leading, CGFloat(item.level) * 14)
                                if item.hasBookmark {
                                    ReaderIcon(.bookmark, size: 12, accessibilityLabel: "已加书签")
                                        .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 4).padding(.horizontal, 8)
                            .background(item.isCurrent ? ReaderDesignTokens.Color.primary.opacity(0.08) : .clear)
                            .clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md))
                        }
                    }.padding(.trailing, 8)
                }
                // 右侧常驻进度条
                Capsule().fill(ReaderDesignTokens.Color.muted.opacity(0.16)).frame(width: 4)
                    .overlay(alignment: .top) {
                        Capsule().fill(ReaderDesignTokens.Color.primary).frame(height: 30)
                    }
                    .frame(maxHeight: .infinity).padding(.vertical, 4)
            }
        }
        .padding(16)
        .background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl))
    }
}

struct ReaderTTSOverlayPrototype: View {
    @State private var rate: Double = 0.5
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("朗读").font(ReaderTypography.controlTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                ReaderIcon(.close, size: 18, accessibilityLabel: "关闭")
            }
            PrototypeFieldGroup("语音引擎") {
                HStack {
                    Text("系统默认").font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundColor(ReaderDesignTokens.Color.controlInk)
                    Spacer()
                    ReaderIcon(.chevron, size: 12, accessibilityLabel: "选择引擎")
                        .rotationEffect(.degrees(90))
                }
            }
            DemoSliderControl(title: "语速", value: $rate, range: 0...1, step: 0.1)
            DemoPrimaryActionButton("开始朗读", icon: .play)
            Text("朗读仅控制播放，不使用章节跳转语义").font(.system(size: ReaderDesignTokens.readerControlLabelFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .padding(16)
        .background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl))
    }
}

struct ReaderAppearanceOverlayPrototype: View {
    @State private var fontSize: Double = 18
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("界面设置").font(ReaderTypography.controlTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                ReaderIcon(.close, size: 18, accessibilityLabel: "关闭")
            }
            PrototypeFieldGroup("字体") {
                HStack {
                    ForEach(["系统", "宋体", "黑体"], id: \.self) { f in
                        Text(f).font(.system(size: ReaderDesignTokens.chipFontSize)).frame(maxWidth: .infinity).padding(.vertical, 4)
                            .background(ReaderDesignTokens.Color.metaBg).clipShape(Capsule())
                    }
                }
            }
            DemoSliderControl(title: "字号", value: $fontSize, range: 12...32, step: 1,
                              valueFormatter: { "\(Int($0))" })
            PrototypeFieldGroup("间距") {
                DemoSliderControl(title: "行间距", value: .constant(0.5), range: 0...1, step: 0.1)
            }
        }
        .padding(16)
        .background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl))
    }
}

struct ReaderSettingsOverlayPrototype: View {
    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("阅读设置").font(ReaderTypography.controlTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                Spacer()
                ReaderIcon(.close, size: 18, accessibilityLabel: "关闭")
            }
            Text("只含阅读行为设置，不含 WebDAV/书源/RSS").font(.system(size: ReaderDesignTokens.readerControlLabelFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            SettingsRowPrototype(title: "屏幕方向", trailing: "竖屏")
            SettingsRowPrototype(title: "音量键翻页", trailing: "关闭")
            SettingsRowPrototype(title: "点击翻页", trailing: "开启")
            SettingsRowPrototype(title: "状态栏显示", trailing: "开启")
            Spacer()
        }
        .padding(16)
        .background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl))
    }
}

// MARK: - E. Source Management

struct SourceListPrototype: View {
    let sources = PrototypeFixtures.sources
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(sources) { s in
                    ReaderCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(s.name).font(ReaderTypography.listTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                                    Circle()
                                        .fill(s.enabled
                                              ? ReaderDesignTokens.Color.Semantic.success
                                              : ReaderDesignTokens.Color.Semantic.danger)
                                        .frame(width: 8, height: 8)
                                }
                                Text(s.url).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted).lineLimit(1)
                            }
                            Spacer()
                            switch s.lastTest {
                            case .notRun:
                                Text("未测试").font(.system(size: ReaderDesignTokens.discoverBookRowSmallFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                            case .success:
                                ReaderIcon(.check, size: 18, accessibilityLabel: "测试通过")
                                    .foregroundColor(ReaderDesignTokens.Color.Semantic.success)
                            case .failure:
                                ReaderIcon(.close, size: 18, accessibilityLabel: "测试失败")
                                    .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
                            }
                            DemoSettingsSwitch(isOn: s.enabled)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct SourceDetailPrototype: View {
    let s = PrototypeFixtures.sources[0]
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PrototypeSettingsGroup(header: "基本信息") {
                    PrototypeMetricRow(label: "名称", value: s.name)
                    PrototypeMetricRow(label: "URL", value: s.url)
                    PrototypeMetricRow(label: "分组", value: s.group)
                }
                PrototypeSettingsGroup(header: "规则摘要") {
                    Text("搜索规则：css:.mh-list").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                    Text("详情规则：css:.mh-detail").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                }
                DemoPrimaryActionButton("测试书源", icon: .play)
                DemoSecondaryActionButton("编辑书源", icon: .edit)
                HStack {
                    Text("启用书源").font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundColor(ReaderDesignTokens.Color.controlInk)
                    Spacer()
                    DemoSettingsSwitch(isOn: true)
                }
                .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
                .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight)
            }
            .padding(16)
        }
    }
}

struct SourceEditImportPrototype: View {
    @State private var showSuccess = true
    var body: some View {
        VStack(spacing: 16) {
            if showSuccess {
                VStack(spacing: 12) {
                    ReaderIcon(.check, size: 48, accessibilityLabel: "导入成功")
                        .foregroundColor(ReaderDesignTokens.Color.Semantic.success)
                    Text("导入成功").font(.system(size: ReaderDesignTokens.continueCardTitleFontSize, weight: .semibold))
                    Text("已添加 1 个书源").font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                    DemoPrimaryActionButton("前往书源列表", icon: .list)
                }
            }
            Divider().padding(.horizontal)
            Text("编辑模式").font(ReaderTypography.listTitle)
            TextField("书源名称", text: .constant("千帆小说"))
                .textFieldStyle(.roundedBorder)
            TextField("书源 URL", text: .constant("https://www.qianfanxs.com"))
                .textFieldStyle(.roundedBorder)
            Text("JSON 校验通过").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderDesignTokens.Color.Semantic.success)
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
                    Text("测试中...").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                }
                Spacer()
                DemoLoadingSpinner(size: .inline)
            }.padding().background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))

            HStack {
                VStack(alignment: .leading) {
                    Text("无名书源").font(ReaderTypography.listTitle)
                    Text("连接超时 — 请检查网络和 URL").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                        .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
                }
                Spacer()
                ReaderIcon(.close, size: 22, accessibilityLabel: "测试失败")
                    .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
            }.padding().background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))

            HStack {
                VStack(alignment: .leading) {
                    Text("禁用书源").font(ReaderTypography.listTitle)
                    Text("已停用，点击启用").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                }
                Spacer()
                ReaderIcon(.pause, size: 22, accessibilityLabel: "已停用")
                    .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
            }.padding().background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))
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
                Text("发现").font(ReaderTypography.pageTitle).foregroundColor(ReaderDesignTokens.Color.controlInk).padding(.horizontal, 16)
                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(section.title).font(ReaderTypography.listTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                            .padding(.horizontal, 16)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(section.items) { item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        ReaderIcon(.book, size: 36, accessibilityLabel: item.title)
                                            .frame(width: 80, height: 100)
                                            .background(ReaderDesignTokens.Color.floatingControlBg).clipShape(RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg))
                                        Text(item.title).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .medium)).lineLimit(1)
                                        Text(item.author).font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                                    }.frame(width: 100)
                                }
                            }.padding(.horizontal, 16)
                        }
                    }
                }
            }
            .padding(.top, 16)
        }
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

struct RSSListPrototype: View {
    let feeds = PrototypeFixtures.rssFeeds
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(feeds) { feed in
                    ReaderCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feed.name).font(ReaderTypography.listTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                                Text("更新: \(feed.lastUpdate)").font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                            }
                            Spacer()
                            if feed.unreadCount > 0 {
                                Text("\(feed.unreadCount)").font(.system(size: ReaderDesignTokens.chipFontSize)).padding(.horizontal, 8).padding(.vertical, 2)
                                    .background(ReaderDesignTokens.Color.primary).foregroundStyle(.white).clipShape(Capsule())
                            }
                            Circle()
                                .fill(feed.enabled
                                      ? ReaderDesignTokens.Color.Semantic.success
                                      : ReaderDesignTokens.Color.muted)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct RSSDetailPrototype: View {
    let articles = PrototypeFixtures.rssArticles
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(articles) { article in
                    ReaderCard {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                if !article.isRead {
                                    Circle().fill(ReaderDesignTokens.Color.primary).frame(width: 6, height: 6)
                                }
                                Text(article.title).font(ReaderTypography.listTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                            }
                            Text(article.summary).font(.system(size: ReaderDesignTokens.discoverBookRowBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted).lineLimit(2)
                            HStack {
                                Text(article.feedName).font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.primary)
                                Spacer()
                                Text(article.date).font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct RSSSubscriptionsPrototype: View {
    let feeds = PrototypeFixtures.rssFeeds
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(feeds) { feed in
                    ReaderCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(feed.name).font(ReaderTypography.listTitle)
                                Text(feed.url).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted).lineLimit(1)
                            }
                            Spacer()
                            DemoSettingsSwitch(isOn: feed.enabled)
                        }
                    }
                }
                DemoPrimaryActionButton("添加订阅", icon: .add)
            }
            .padding(16)
        }
    }
}

struct WebDAVConfigPrototype: View {
    let config = PrototypeFixtures.webdavConfig
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PrototypeSettingsGroup(header: "服务器配置") {
                    PrototypeMetricRow(label: "服务器地址", value: config.serverURL)
                    PrototypeMetricRow(label: "用户名", value: config.username)
                    SecureField("密码", text: .constant("********")) {}.disabled(true)
                }
                ReaderCard {
                    HStack {
                        ReaderIcon(.cloud, size: 18, accessibilityLabel: "连接状态")
                        Text("连接状态").font(.system(size: ReaderDesignTokens.bookCardTitleFontSize))
                        Spacer()
                        Text(config.isConnected ? "已连接" : "未连接")
                            .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize))
                            .foregroundColor(config.isConnected
                                             ? ReaderDesignTokens.Color.Semantic.success
                                             : ReaderDesignTokens.Color.muted)
                    }
                }
                DemoPrimaryActionButton("连接测试", icon: .refresh)
                Text("不保存真实账号/token，仅原型展示").font(.system(size: ReaderDesignTokens.readerControlLabelFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(16)
        }
    }
}

struct BackupSettingsPrototype: View {
    @State private var autoBackup = false
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PrototypeSettingsGroup(header: "备份范围") {
                    PrototypeToggleRow(title: "书籍数据", isOn: true)
                    PrototypeToggleRow(title: "阅读进度", isOn: true)
                    PrototypeToggleRow(title: "书源配置", isOn: false)
                }
                PrototypeSettingsGroup(header: "自动备份") {
                    PrototypeToggleRow(title: "自动备份", isOn: autoBackup)
                    if autoBackup {
                        Text("频率：每日").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                    }
                }
                DemoPrimaryActionButton("立即备份", icon: .upload)
                Text("上次备份：2026-05-20 02:00").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(16)
        }
    }
}

private struct PrototypeToggleRow: View {
    let title: String
    let isOn: Bool

    var body: some View {
        HStack {
            Text(title).font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundColor(ReaderDesignTokens.Color.controlInk)
            Spacer()
            DemoSettingsSwitch(isOn: isOn)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight)
    }
}

struct SyncProgressPrototype: View {
    let progress = PrototypeFixtures.syncProgress
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                PrototypeSettingsGroup(header: "阅读进度") {
                    PrototypeMetricRow(label: "本地进度", value: progress.localProgress)
                    PrototypeMetricRow(label: "云端进度", value: progress.remoteProgress)
                }
                if progress.hasConflict {
                    PrototypeSettingsGroup(header: "冲突") {
                        Text("本地与云端进度不一致").font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                            .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
                        DemoSecondaryActionButton("保留本地")
                        DemoSecondaryActionButton("保留云端")
                        DemoPrimaryActionButton("合并", icon: .sync)
                    }
                }
                PrototypeSettingsGroup(header: "同步状态") {
                    PrototypeMetricRow(label: "上次同步", value: progress.lastSync)
                }
                DemoPrimaryActionButton("立即同步", icon: .sync)
            }
            .padding(16)
        }
    }
}

struct RemoteWebDAVBooksPrototype: View {
    let books = PrototypeFixtures.remoteBooks
    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(books) { book in
                    ReaderCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.name).font(ReaderTypography.listTitle).foregroundColor(ReaderDesignTokens.Color.controlInk)
                                Text(book.size).font(.system(size: ReaderDesignTokens.bookCardMetaFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                            }
                            Spacer()
                            switch book.status {
                            case .notDownloaded:
                                ReaderIcon(.download, size: 18, accessibilityLabel: "未下载")
                                    .foregroundStyle(ReaderDesignTokens.Color.primary)
                            case .downloaded:
                                ReaderIcon(.cloud, size: 18, accessibilityLabel: "已下载")
                                    .foregroundColor(ReaderDesignTokens.Color.Semantic.success)
                            case .downloading(let p):
                                // demo `.fd-restore-progress-meter`：8px pill，缩窄到 40pt 宽。
                                DemoRestoreProgressMeter(progress: p, tint: ReaderDesignTokens.Color.primary)
                                    .frame(width: 40)
                            }
                        }
                    }
                }
            }
            .padding(16)
        }
    }
}

struct SyncErrorPrototype: View {
    var body: some View {
        VStack(spacing: 16) {
            ReaderIcon(.cloud, size: 48, accessibilityLabel: "WebDAV 认证失败")
                .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
            Text("WebDAV 认证失败").font(.system(size: ReaderDesignTokens.continueCardTitleFontSize, weight: .semibold))
            Text("用户名或密码错误，请重新配置").font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            DemoPrimaryActionButton("重新登录", icon: .refresh)
            DemoSecondaryActionButton("跳过")
            Divider().padding(.horizontal, 40)
            ReaderIcon(.offline, size: 48, accessibilityLabel: "网络不可达")
                .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
            Text("网络不可达").font(.system(size: ReaderDesignTokens.continueCardTitleFontSize, weight: .semibold))
            Text("请检查网络连接和服务器地址").font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            DemoSecondaryActionButton("重试", icon: .refresh)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

// MARK: - G. Settings / State Pages

struct GlobalSettingsPrototype: View {
    var body: some View {
        ScrollView {
            VStack(spacing: ReaderDesignTokens.settingsSectionGap) {
                PrototypeSettingsGroup(header: "外观") {
                    SettingsRowPrototype(title: "主题", trailing: "跟随系统")
                    SettingsRowPrototype(title: "字体", trailing: "系统默认")
                }
                PrototypeSettingsGroup(header: "阅读") {
                    SettingsRowPrototype(title: "阅读设置", trailing: "翻页/字号/间距")
                    SettingsRowPrototype(title: "朗读设置", trailing: "语速/音色")
                }
                PrototypeSettingsGroup(header: "书架") {
                    SettingsRowPrototype(title: "默认视图", trailing: "封面")
                    SettingsRowPrototype(title: "自动刷新", trailing: "开启")
                }
                PrototypeSettingsGroup(header: "备份与同步") {
                    SettingsRowPrototype(title: "WebDAV 备份", trailing: "未连接")
                    SettingsRowPrototype(title: "阅读进度同步", trailing: "已同步")
                }
                PrototypeSettingsGroup(header: "关于") {
                    SettingsRowPrototype(title: "版本", trailing: "0.1.0")
                    SettingsRowPrototype(title: "开源许可", trailing: "")
                }
            }
            .padding(.horizontal, ReaderDesignTokens.demoContentHorizontalPadding)
            .padding(.vertical, ReaderDesignTokens.demoContentVerticalPadding)
        }
    }
}

struct SettingsRowPrototype: View {
    let title: String; let trailing: String
    var body: some View {
        HStack {
            Text(title).font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundColor(ReaderDesignTokens.Color.controlInk)
            Spacer()
            Text(trailing).font(.system(size: ReaderDesignTokens.bookCardTitleFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            ReaderIcon(.chevron, size: 12, accessibilityLabel: "查看")
                .foregroundStyle(ReaderDesignTokens.Color.muted)
                .rotationEffect(.degrees(90))
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight)
    }
}

struct StatePagePrototype: View {
    let state: ReaderUiState
    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .loading:
                DemoLoadingSpinner(size: .reader)
                Text("加载中...").font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            case .empty:
                ReaderIcon(.file, size: 48, accessibilityLabel: "暂无内容")
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                Text("暂无内容").font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize))
                Text("试试添加一些内容吧").font(.system(size: ReaderDesignTokens.rssReaderBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
                DemoPrimaryActionButton("去添加", icon: .add)
            case .error(let msg, let retryable):
                ReaderIcon(.warning, size: 48, accessibilityLabel: "出错了")
                    .foregroundColor(ReaderDesignTokens.Color.Semantic.danger)
                Text("出错了").font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize))
                Text(msg).font(.system(size: ReaderDesignTokens.rssReaderBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted).multilineTextAlignment(.center)
                if retryable {
                    DemoPrimaryActionButton("重试", icon: .refresh)
                }
            case .offline:
                ReaderIcon(.offline, size: 48, accessibilityLabel: "离线状态")
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                Text("离线状态").font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize))
                Text("已缓存的内容仍可阅读").font(.system(size: ReaderDesignTokens.rssReaderBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted)
            case .permissionRequired(let perm):
                ReaderIcon(.shield, size: 48, accessibilityLabel: "需要权限")
                    .foregroundColor(ReaderDesignTokens.Color.Semantic.warning)
                Text("需要权限").font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize))
                Text("请在系统设置中允许「\(perm)」权限").font(.system(size: ReaderDesignTokens.rssReaderBodyFontSize)).foregroundStyle(ReaderDesignTokens.Color.muted).multilineTextAlignment(.center)
                DemoPrimaryActionButton("去设置", icon: .gear)
            default:
                Text("未知状态").font(.system(size: ReaderDesignTokens.rssOriginalWebPreviewTitleFontSize))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}
