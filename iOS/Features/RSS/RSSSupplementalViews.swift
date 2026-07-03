import SwiftUI
import ReaderCoreModels

enum RSSStateKind: Hashable {
    case empty
    case error
}

struct RSSSearchView: View {
    @State private var selectedScope = "全部"
    private let scopes = ["全部", "订阅源", "文章", "分组"]

    var body: some View {
        DemoBackScreen(title: "RSS 搜索") {
            ReaderCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        ReaderIcon(.search, size: 16)
                            .frame(width: 22)
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        Text("搜索订阅源、文章标题或分组")
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(minHeight: 38)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
                            ForEach(scopes, id: \.self) { scope in
                                PillChip(scope, isSelected: selectedScope == scope) {
                                    selectedScope = scope
                                }
                            }
                        }
                    }
                }
            }

            RSSSupplementalArticleSection(
                title: "搜索结果",
                articles: Array(RSSSupplementalDemoData.articles.prefix(3)),
                actionTitle: "管理源",
                actionDestination: { RSSSubscriptionManagementView() }
            )
        }
    }
}

struct RSSReadRecordView: View {
    private let source: RSSManagementSource?
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(source: RSSManagementSource? = nil) {
        self.source = source
    }

    init(sourceID: String?, title: String? = nil) {
        if let sourceID {
            self.source = RSSManagementSource.fallback(sourceID: sourceID, title: title)
        } else {
            self.source = nil
        }
    }

    var body: some View {
        DemoBackScreen(title: "阅读记录") {
            if let source {
                RSSSupplementalHeaderPanel(
                    icon: .clock,
                    title: source.name,
                    subtitle: "阅读记录 · \(source.group) · \(source.latest)"
                )
            }
            RSSRecordList(records: RSSSupplementalDemoData.records)
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSSupplementalBottomButton(title: "返回列表", isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                NavigationLink {
                    RSSRecordClearConfirmView()
                } label: {
                    RSSSupplementalBottomLabel(title: "清空记录", isPrimary: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RSSRecordClearConfirmView: View {
    var body: some View {
        RSSSupplementalConfirmPage(
            title: "清空阅读记录",
            icon: .trash,
            heading: "清空 RSS 阅读记录？",
            copy: "只会清除 RSS 阅读历史，不会删除收藏、订阅源、未读状态或正文缓存。",
            detail: "记录清空后仍可从 RSS 列表和收藏分组进入文章。",
            cancelTitle: "取消",
            cancelDestination: { RSSReadRecordView() },
            confirmTitle: "确认清空"
        )
    }
}

struct RSSRuleSubscriptionView: View {
    var body: some View {
        DemoBackScreen(title: "规则订阅") {
            RSSRuleSubscriptionList(subscriptions: RSSSupplementalDemoData.ruleSubscriptions)
            RSSSupplementalInlineActionWrap {
                NavigationLink {
                    RSSRuleSubscriptionDetailView()
                } label: {
                    RSSSupplementalInlineActionLabel(icon: .upload, title: "打开订阅")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RSSRuleSubscriptionEditView(subscriptionID: "new-subscription", title: "新增规则订阅")
                } label: {
                    RSSSupplementalInlineActionLabel(icon: .add, title: "新增")
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RSSRuleSubscriptionDetailView: View {
    private let subscription: RSSRuleSubscription

    init(subscriptionID: String = "community-rss", title: String? = "社区 RSS 源订阅") {
        self.subscription = RSSRuleSubscription.fallback(subscriptionID: subscriptionID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "订阅详情") {
            RSSSupplementalInfoPanel(
                icon: .sync,
                title: subscription.name,
                subtitle: "\(subscription.type) · 自动更新 · \(subscription.update)",
                rows: [
                    RSSSupplementalInfoRow(title: "订阅地址", body: subscription.url, isWarning: false),
                    RSSSupplementalInfoRow(title: "更新策略", body: "Wi-Fi 下自动更新；保留本地启用状态、分组和登录态。", isWarning: false),
                    RSSSupplementalInfoRow(title: "最近变更", body: "新增 2 个源，更新 1 个正文规则，跳过 1 个本地冲突。", isWarning: false)
                ]
            )
            RSSImportChangeList()
        } bottomActionHost: {
            BottomFixedActionRow {
                NavigationLink {
                    RSSRuleSubscriptionEditView(subscriptionID: subscription.id, title: subscription.name)
                } label: {
                    RSSSupplementalBottomLabel(title: "编辑", isPrimary: false)
                }
                .buttonStyle(.plain)
            } trailing: {
                NavigationLink {
                    RSSRuleSubscriptionApplyConfirmView(subscriptionID: subscription.id, title: subscription.name)
                } label: {
                    RSSSupplementalBottomLabel(title: "应用更新", isPrimary: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RSSRuleSubscriptionEditView: View {
    private let subscription: RSSRuleSubscription
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(subscriptionID: String = "community-rss", title: String? = "社区 RSS 源订阅") {
        self.subscription = RSSRuleSubscription.fallback(subscriptionID: subscriptionID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "编辑规则订阅") {
            RSSSupplementalEditFieldList(fields: fields)
        } bottomActionHost: {
            BottomFixedActionRow {
                NavigationLink {
                    RSSRuleSubscriptionTestView(subscriptionID: subscription.id, title: subscription.name)
                } label: {
                    RSSSupplementalBottomLabel(title: "测试订阅", isPrimary: false)
                }
                .buttonStyle(.plain)
            } trailing: {
                RSSSupplementalBottomButton(title: "保存", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }

    private var fields: [RSSSupplementalEditField] {
        [
            RSSSupplementalEditField(group: "基础", label: "订阅名称", value: subscription.name),
            RSSSupplementalEditField(group: "基础", label: "订阅类型", value: subscription.type),
            RSSSupplementalEditField(group: "基础", label: "订阅地址", value: subscription.url),
            RSSSupplementalEditField(group: "同步", label: "自动更新", value: "Wi-Fi 下自动"),
            RSSSupplementalEditField(group: "同步", label: "冲突策略", value: "保留本地名称、分组、启用状态"),
            RSSSupplementalEditField(group: "安全", label: "登录配置", value: "不覆盖 Cookie 和账号信息")
        ]
    }
}

struct RSSRuleSubscriptionTestView: View {
    private let subscription: RSSRuleSubscription

    init(subscriptionID: String = "community-rss", title: String? = "社区 RSS 源订阅") {
        self.subscription = RSSRuleSubscription.fallback(subscriptionID: subscriptionID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "测试规则订阅") {
            RSSSupplementalInfoPanel(
                icon: .bug,
                title: subscription.name,
                subtitle: "请求订阅地址 · 校验结构 · 生成导入预览",
                rows: [
                    RSSSupplementalInfoRow(title: "1. 请求订阅地址", body: "\(subscription.url) 返回 200，内容类型 application/json。", isWarning: false),
                    RSSSupplementalInfoRow(title: "2. 解析订阅内容", body: "12 个 RSS 源、2 个更新项、1 个本地冲突。", isWarning: false),
                    RSSSupplementalInfoRow(title: "3. 冲突策略", body: "保留本地名称、分组、启用状态，不覆盖登录凭据。", isWarning: false)
                ]
            )
        } bottomActionHost: {
            BottomFixedActionRow {
                NavigationLink {
                    RSSRuleSubscriptionEditView(subscriptionID: subscription.id, title: subscription.name)
                } label: {
                    RSSSupplementalBottomLabel(title: "返回编辑", isPrimary: false)
                }
                .buttonStyle(.plain)
            } trailing: {
                NavigationLink {
                    RSSRuleSubscriptionDetailView(subscriptionID: subscription.id, title: subscription.name)
                } label: {
                    RSSSupplementalBottomLabel(title: "查看结果", isPrimary: true)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct RSSRuleSubscriptionApplyConfirmView: View {
    private let subscription: RSSRuleSubscription

    init(subscriptionID: String = "community-rss", title: String? = "社区 RSS 源订阅") {
        self.subscription = RSSRuleSubscription.fallback(subscriptionID: subscriptionID, title: title)
    }

    var body: some View {
        RSSSupplementalConfirmPage(
            title: "应用订阅更新",
            icon: .sync,
            heading: "应用 \(subscription.name) 更新？",
            copy: "将新增 2 个源、更新 1 个规则，并跳过 1 个本地冲突。登录凭据不会被覆盖。",
            detail: "应用前可进入导入预览确认每个 RSS 源的处理策略。",
            cancelTitle: "返回详情",
            cancelDestination: { RSSRuleSubscriptionDetailView(subscriptionID: subscription.id, title: subscription.name) },
            confirmTitle: "进入导入预览"
        )
    }
}

struct RSSFavoriteGroupsView: View {
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        DemoBackScreen(title: "收藏分组") {
            RSSFavoriteGroupList(groups: RSSSupplementalDemoData.favoriteGroups)
            RSSSupplementalInlineActionWrap {
                NavigationLink {
                    RSSFavoriteGroupEditView(groupID: "new-favorite-group", title: "新增分组")
                } label: {
                    RSSSupplementalInlineActionLabel(icon: .add, title: "新增分组")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RSSFavoriteGroupEditView(groupID: "default", title: "默认分组")
                } label: {
                    RSSSupplementalInlineActionLabel(icon: .edit, title: "排序")
                }
                .buttonStyle(.plain)
            }
        } bottomActionHost: {
            BottomFixedActionRow {
                RSSSupplementalBottomButton(title: "取消", isPrimary: false) {
                    dismiss()
                }
            } trailing: {
                RSSSupplementalBottomButton(title: "保存", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }
}

struct RSSFavoriteGroupEditView: View {
    private let group: RSSFavoriteGroup
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    init(groupID: String = "default", title: String? = "默认分组") {
        self.group = RSSFavoriteGroup.fallback(groupID: groupID, title: title)
    }

    var body: some View {
        DemoBackScreen(title: "编辑收藏分组") {
            RSSSupplementalEditFieldList(fields: fields)
        } bottomActionHost: {
            BottomFixedActionRow {
                NavigationLink {
                    RSSFavoriteGroupsView()
                } label: {
                    RSSSupplementalBottomLabel(title: "取消", isPrimary: false)
                }
                .buttonStyle(.plain)
            } trailing: {
                RSSSupplementalBottomButton(title: "保存", isPrimary: true) {
                    dismiss()
                }
            }
        }
    }

    private var fields: [RSSSupplementalEditField] {
        [
            RSSSupplementalEditField(group: "分组配置", label: "分组名称", value: group.name),
            RSSSupplementalEditField(group: "分组配置", label: "首页显示", value: group.pinned ? "显示" : "隐藏"),
            RSSSupplementalEditField(group: "分组配置", label: "排序规则", value: "收藏时间优先，其次订阅源名称"),
            RSSSupplementalEditField(group: "分组配置", label: "适用文章", value: group.meta)
        ]
    }
}

struct RSSFavoriteClearConfirmView: View {
    var body: some View {
        RSSSupplementalConfirmPage(
            title: "清空收藏分组",
            icon: .trash,
            heading: "清空默认分组收藏？",
            copy: "仅移除当前收藏分组里的条目，文章本身和订阅源不会删除。",
            detail: "其他收藏分组、阅读记录和订阅源状态不会受影响。",
            cancelTitle: "返回分组",
            cancelDestination: { RSSFavoriteGroupsView() },
            confirmTitle: "确认清空"
        )
    }
}

struct RSSStateView: View {
    let kind: RSSStateKind

    var body: some View {
        DemoBackScreen(title: kind == .error ? "RSS 错误" : "RSS 空状态") {
            RSSSupplementalStateCard(kind: kind)
        }
    }
}

private struct RSSSupplementalDemoData {
    static let articles: [RSSDemoArticle] = [
        RSSDemoArticle(
            title: "Reader UI 前端输入件更新说明",
            source: "GitHub Releases",
            time: "10:18",
            group: "开源项目",
            desc: "补齐 RSS 管理、阅读器原文和跨端 handoff 所需的前端输入件。",
            unread: true,
            link: "https://example.com/rss/ui-update"
        ),
        RSSDemoArticle(
            title: "规则订阅格式草案",
            source: "社区 RSS 源订阅",
            time: "09:42",
            group: "社区",
            desc: "订阅包包含源列表、正文规则、分组策略和安全导入策略。",
            unread: true,
            link: "https://example.com/rss/rule-subscription"
        ),
        RSSDemoArticle(
            title: "本地系统通知",
            source: "本地系统通知",
            time: "昨天",
            group: "系统",
            desc: "部分暂停源已保留缓存，刷新失败不会影响已读内容。",
            unread: false,
            link: "https://example.com/rss/local-system"
        )
    ]

    static let records: [RSSReadRecord] = [
        RSSReadRecord(title: "Reader UI 前端输入件更新说明", meta: "GitHub Releases · 今天 10:18 · 已读 68%", link: "https://example.com/rss/ui-update"),
        RSSReadRecord(title: "规则订阅格式草案", meta: "社区 RSS 源订阅 · 今天 09:42 · 已读 100%", link: "https://example.com/rss/rule-subscription"),
        RSSReadRecord(title: "本地系统通知", meta: "本地系统通知 · 昨天 · 已读 35%", link: "https://example.com/rss/local-system")
    ]

    static let ruleSubscriptions: [RSSRuleSubscription] = [
        RSSRuleSubscription(id: "community-rss", name: "社区 RSS 源订阅", type: "RSS 源", url: "https://example.com/rss-source.json", update: "上次同步 10:18"),
        RSSRuleSubscription(id: "book-source-rules", name: "书源维护规则", type: "书源", url: "https://example.com/book-source-rules.json", update: "昨日同步"),
        RSSRuleSubscription(id: "replace-rules", name: "正文净化规则", type: "替换规则", url: "https://example.com/replace-rules.json", update: "手动更新")
    ]

    static let favoriteGroups: [RSSFavoriteGroup] = [
        RSSFavoriteGroup(id: "default", name: "默认分组", meta: "2 条收藏 · 首页显示", pinned: true),
        RSSFavoriteGroup(id: "open-source", name: "开源项目", meta: "1 条收藏 · 自动归类", pinned: true),
        RSSFavoriteGroup(id: "community", name: "社区", meta: "1 条收藏 · 手动归类", pinned: false)
    ]
}

private struct RSSDemoArticle: Hashable {
    let title: String
    let source: String
    let time: String
    let group: String
    let desc: String
    let unread: Bool
    let link: String

    var subscriptionItem: SubscriptionItem {
        SubscriptionItem(
            title: title,
            link: link,
            author: source,
            summary: desc,
            publishedAt: Date(timeIntervalSince1970: 1_800_000_000),
            sourceId: source.lowercased().replacingOccurrences(of: " ", with: "-"),
            sourceName: source
        )
    }
}

private struct RSSReadRecord: Hashable {
    let title: String
    let meta: String
    let link: String

    var subscriptionItem: SubscriptionItem {
        SubscriptionItem(
            title: title,
            link: link,
            author: "RSS",
            summary: meta,
            publishedAt: Date(timeIntervalSince1970: 1_800_000_000),
            sourceId: "rss-record",
            sourceName: "RSS"
        )
    }
}

private struct RSSRuleSubscription: Hashable {
    let id: String
    let name: String
    let type: String
    let url: String
    let update: String

    var icon: ReaderAssetIcon {
        switch type {
        case "书源":
            return .sourceStack
        case "替换规则":
            return .replace
        default:
            return .rss
        }
    }

    static func fallback(subscriptionID: String, title: String?) -> RSSRuleSubscription {
        if let subscription = RSSSupplementalDemoData.ruleSubscriptions.first(where: { $0.id == subscriptionID || $0.name == title }) {
            return subscription
        }
        return RSSRuleSubscription(
            id: subscriptionID,
            name: title?.nonEmpty ?? "社区 RSS 源订阅",
            type: "RSS 源",
            url: "https://example.com/rss-source.json",
            update: "待同步"
        )
    }
}

private struct RSSFavoriteGroup: Hashable {
    let id: String
    let name: String
    let meta: String
    let pinned: Bool

    static func fallback(groupID: String, title: String?) -> RSSFavoriteGroup {
        if let group = RSSSupplementalDemoData.favoriteGroups.first(where: { $0.id == groupID || $0.name == title }) {
            return group
        }
        return RSSFavoriteGroup(
            id: groupID,
            name: title?.nonEmpty ?? "默认分组",
            meta: "0 条收藏 · 手动归类",
            pinned: false
        )
    }
}

private struct RSSSupplementalArticleSection<ActionDestination: View>: View {
    let title: String
    let articles: [RSSDemoArticle]
    let actionTitle: String
    let actionDestination: () -> ActionDestination

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(maxWidth: .infinity, alignment: .leading)

                NavigationLink {
                    actionDestination()
                } label: {
                    RSSSupplementalInlineActionLabel(icon: .sourceStack, title: actionTitle)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)

            ForEach(Array(articles.enumerated()), id: \.element) { index, article in
                NavigationLink {
                    RSSArticleDetailView(item: article.subscriptionItem, sourceTitle: article.source)
                } label: {
                    RSSSupplementalArticleRow(article: article)
                }
                .buttonStyle(.plain)
                if index < articles.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .rssSupplementalCard()
    }
}

private struct RSSSupplementalArticleRow: View {
    let article: RSSDemoArticle

    var body: some View {
        HStack(alignment: .top, spacing: ReaderDesignTokens.rssArticleRowGap) {
            Circle()
                .fill(article.unread ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.rssDotRead)
                .frame(width: ReaderDesignTokens.rssArticleRowDotSize, height: ReaderDesignTokens.rssArticleRowDotSize)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(article.title)
                    .font(.system(size: ReaderDesignTokens.rssArticleRowTitleFontSize, weight: .bold))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .lineLimit(2)
                Text("\(article.source) · \(article.time) · \(article.group)")
                    .font(.system(size: ReaderDesignTokens.rssArticleRowSmallFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(article.desc)
                    .font(.system(size: ReaderDesignTokens.rssArticleRowBodyFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(ReaderDesignTokens.rssArticleRowBodyLineLimit)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ReaderIcon(.chevron, size: 12)
                .frame(width: ReaderDesignTokens.rssArticleRowChevronColumn)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, ReaderDesignTokens.rssArticleRowVerticalPadding)
        .padding(.horizontal, ReaderDesignTokens.rssArticleRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.rssArticleRowMinHeight, alignment: .top)
    }
}

private struct RSSRecordList: View {
    let records: [RSSReadRecord]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(records.enumerated()), id: \.element) { index, record in
                NavigationLink {
                    RSSArticleDetailView(item: record.subscriptionItem, sourceTitle: "RSS")
                } label: {
                    HStack(spacing: 8) {
                        ReaderIcon(.clock, size: 15, accessibilityLabel: "阅读记录")
                            .frame(
                                width: ReaderDesignTokens.rssImportListIconSize,
                                height: ReaderDesignTokens.rssImportListIconSize
                            )
                            .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.title)
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                                .lineLimit(1)
                            Text(record.meta)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        ReaderIcon(.chevron, size: 12)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .frame(minHeight: ReaderDesignTokens.rssEditListRowMinHeight)
                }
                .buttonStyle(.plain)

                if index < records.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .rssSupplementalCard()
    }
}

private struct RSSRuleSubscriptionList: View {
    let subscriptions: [RSSRuleSubscription]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(subscriptions.enumerated()), id: \.element) { index, subscription in
                NavigationLink {
                    RSSRuleSubscriptionDetailView(subscriptionID: subscription.id, title: subscription.name)
                } label: {
                    HStack(spacing: 8) {
                        ReaderIcon(subscription.icon, size: 15, accessibilityLabel: subscription.type)
                            .frame(
                                width: ReaderDesignTokens.rssImportListIconSize,
                                height: ReaderDesignTokens.rssImportListIconSize
                            )
                            .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(subscription.name)
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                                .lineLimit(1)
                            Text("\(subscription.type) · \(subscription.url)")
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Text(subscription.update)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .frame(width: 72, alignment: .trailing)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .frame(minHeight: ReaderDesignTokens.rssManagementListRowMinHeight)
                }
                .buttonStyle(.plain)

                if index < subscriptions.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .rssSupplementalCard()
    }
}

private struct RSSImportChangeList: View {
    private let rows: [(title: String, meta: String, tone: RSSSupplementalTone)] = [
        ("书源维护公告", "更新 · 规则版本更高 · 需登录", .warn),
        ("社区 RSS 源合集", "新增 · 4 个分类入口 · 无需登录", .good),
        ("本地系统通知", "跳过 · 本地已存在 · 保留本地状态", .muted)
    ]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack(spacing: 8) {
                    ReaderIcon(row.tone == .muted ? .rss : .check, size: 15)
                        .frame(
                            width: ReaderDesignTokens.rssImportListIconSize,
                            height: ReaderDesignTokens.rssImportListIconSize
                        )
                        .background(Circle().fill(row.tone == .muted ? ReaderDesignTokens.Color.primary.opacity(0.10) : ReaderDesignTokens.Color.primary))
                        .foregroundColor(row.tone == .muted ? ReaderDesignTokens.Color.primaryDark : .white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title)
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                            .lineLimit(1)
                        Text(row.meta)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    RSSSupplementalBadge(title: row.tone.label, tone: row.tone)
                }
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .frame(minHeight: ReaderDesignTokens.rssEditListRowMinHeight)

                if index < rows.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .rssSupplementalCard()
    }
}

private struct RSSFavoriteGroupList: View {
    let groups: [RSSFavoriteGroup]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(groups.enumerated()), id: \.element) { index, group in
                NavigationLink {
                    RSSFavoriteGroupEditView(groupID: group.id, title: group.name)
                } label: {
                    HStack(spacing: 8) {
                        ReaderIcon(.bookmark, size: 15, accessibilityLabel: group.name)
                            .frame(
                                width: ReaderDesignTokens.rssImportListIconSize,
                                height: ReaderDesignTokens.rssImportListIconSize
                            )
                            .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(group.name)
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                                .lineLimit(1)
                            Text(group.meta)
                                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        RSSSupplementalBadge(title: group.pinned ? "显示" : "隐藏", tone: group.pinned ? .good : .muted)
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 9)
                    .frame(minHeight: ReaderDesignTokens.rssManagementListRowMinHeight)
                }
                .buttonStyle(.plain)

                if index < groups.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .rssSupplementalCard()
    }
}

private struct RSSSupplementalStateCard: View {
    let kind: RSSStateKind

    var body: some View {
        VStack(spacing: 10) {
            ReaderIcon(kind == .error ? .warning : .rss, size: 36, accessibilityLabel: title)
                .frame(width: ReaderDesignTokens.rssBrowserConfirmIconSize, height: ReaderDesignTokens.rssBrowserConfirmIconSize)
                .background(Circle().fill(iconBackground))
                .foregroundColor(iconColor)

            Text(title)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .multilineTextAlignment(.center)

            Text(copy)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            if kind == .error {
                RSSSupplementalErrorList()
            }

            HStack(spacing: 8) {
                NavigationLink {
                    RSSFeedView()
                } label: {
                    RSSSupplementalInlineActionLabel(icon: kind == .error ? .refresh : .list, title: kind == .error ? "重试刷新" : "查看全部")
                }
                .buttonStyle(.plain)

                NavigationLink {
                    RSSSubscriptionManagementView()
                } label: {
                    RSSSupplementalInlineActionLabel(icon: .sourceStack, title: "订阅管理")
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, ReaderDesignTokens.rssBrowserConfirmVerticalPadding)
        .padding(.horizontal, ReaderDesignTokens.rssBrowserConfirmHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssBrowserConfirmCardMinHeight)
        .rssSupplementalCard()
    }

    private var title: String {
        kind == .error ? "订阅刷新失败" : "暂无未读订阅"
    }

    private var copy: String {
        if kind == .error {
            return "2 个订阅源刷新失败，已保留最近缓存条目。可以稍后重试、查看错误源，或进入订阅源管理修复登录态和规则。"
        }
        return "当前订阅源没有新的未读条目。你可以查看全部、管理订阅源或手动刷新。日常空状态仍保留 RSS 主导航上下文。"
    }

    private var iconBackground: SwiftUI.Color {
        kind == .error ? SwiftUI.Color(red: 0.78, green: 0.22, blue: 0.18).opacity(0.12) : ReaderDesignTokens.Color.primary.opacity(0.12)
    }

    private var iconColor: SwiftUI.Color {
        kind == .error ? SwiftUI.Color(red: 0.56, green: 0.21, blue: 0.18) : ReaderDesignTokens.Color.primaryDark
    }
}

private struct RSSSupplementalErrorList: View {
    private let rows = [
        ("书源维护公告", "登录态失效 · 需要重新登录"),
        ("本地系统通知", "源已暂停 · 不参与自动刷新")
    ]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.0) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.0)
                        .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .heavy))
                    Text(row.1)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                }
                .foregroundColor(SwiftUI.Color(red: 0.49, green: 0.18, blue: 0.16))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                        .fill(SwiftUI.Color(red: 0.84, green: 0.13, blue: 0.13).opacity(0.08))
                )
            }
        }
        .frame(maxWidth: .infinity)
    }
}

private struct RSSSupplementalHeaderPanel: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(icon, size: ReaderDesignTokens.rssDebugHeaderIconSize, accessibilityLabel: title)
                .frame(width: ReaderDesignTokens.rssDebugHeaderIconSize, height: ReaderDesignTokens.rssDebugHeaderIconSize)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.12)))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(ReaderDesignTokens.rssDebugPanelPadding)
        .rssSupplementalCard()
    }
}

private struct RSSSupplementalInfoPanel: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let rows: [RSSSupplementalInfoRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ReaderIcon(icon, size: ReaderDesignTokens.rssDebugHeaderIconSize, accessibilityLabel: title)
                    .frame(width: ReaderDesignTokens.rssDebugHeaderIconSize, height: ReaderDesignTokens.rssDebugHeaderIconSize)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.12)))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)

            Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)

            ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                    Text(row.body)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(row.isWarning ? .primary : .secondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssEditListRowMinHeight, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                if index < rows.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .padding(ReaderDesignTokens.rssDebugPanelPadding)
        .rssSupplementalCard()
    }
}

private struct RSSSupplementalInfoRow: Hashable {
    let title: String
    let body: String
    let isWarning: Bool
}

private struct RSSSupplementalEditField: Hashable {
    let group: String
    let label: String
    let value: String
}

private struct RSSSupplementalEditFieldList: View {
    let fields: [RSSSupplementalEditField]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(fields.enumerated()), id: \.element) { index, field in
                VStack(alignment: .leading, spacing: 3) {
                    Text(field.group)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                    Text(field.label)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                        .lineLimit(1)
                    Text(field.value)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssEditListRowMinHeight, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)

                if index < fields.count - 1 {
                    Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                }
            }
        }
        .rssSupplementalCard()
    }
}

private struct RSSSupplementalConfirmPage<CancelDestination: View>: View {
    let title: String
    let icon: ReaderAssetIcon
    let heading: String
    let copy: String
    let detail: String
    let cancelTitle: String
    let cancelDestination: () -> CancelDestination
    let confirmTitle: String
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction

    var body: some View {
        DemoBackScreen(title: title) {
            RSSSupplementalConfirmCard(icon: icon, heading: heading, copy: copy, detail: detail)
        } bottomActionHost: {
            BottomFixedActionRow {
                NavigationLink {
                    cancelDestination()
                } label: {
                    RSSSupplementalBottomLabel(title: cancelTitle, isPrimary: false)
                }
                .buttonStyle(.plain)
            } trailing: {
                RSSSupplementalBottomButton(title: confirmTitle, isPrimary: true) {
                    dismiss()
                }
            }
        }
    }
}

private struct RSSSupplementalConfirmCard: View {
    let icon: ReaderAssetIcon
    let heading: String
    let copy: String
    let detail: String

    var body: some View {
        VStack(spacing: ReaderDesignTokens.rssBrowserConfirmGap) {
            ReaderIcon(icon, size: 32, accessibilityLabel: heading)
                .frame(width: ReaderDesignTokens.rssBrowserConfirmIconSize, height: ReaderDesignTokens.rssBrowserConfirmIconSize)
                .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.12)))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            Text(heading)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .multilineTextAlignment(.center)
            Text(copy)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(detail)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmDetailFontSize, weight: .semibold))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, ReaderDesignTokens.rssBrowserConfirmVerticalPadding)
        .padding(.horizontal, ReaderDesignTokens.rssBrowserConfirmHorizontalPadding)
        .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth + 56)
        .frame(minHeight: ReaderDesignTokens.rssBrowserConfirmCardMinHeight)
        .rssSupplementalCard()
    }
}

private struct RSSSupplementalInlineActionWrap<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 6) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct RSSSupplementalInlineActionLabel: View {
    let icon: ReaderAssetIcon
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            ReaderIcon(icon, size: 13)
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .font(.system(size: 11, weight: .heavy))
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .padding(.horizontal, 8)
        .frame(minHeight: ReaderDesignTokens.rssImportListActionMinHeight)
        .background(Capsule().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))
    }
}

private struct RSSSupplementalBottomLabel: View {
    let title: String
    let isPrimary: Bool

    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: .heavy))
            .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.primaryDark)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(isPrimary ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground)
            )
    }
}

private struct RSSSupplementalBottomButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            RSSSupplementalBottomLabel(title: title, isPrimary: isPrimary)
        }
        .buttonStyle(.plain)
    }
}

private enum RSSSupplementalTone {
    case good
    case warn
    case muted

    var label: String {
        switch self {
        case .good:
            return "新增"
        case .warn:
            return "更新"
        case .muted:
            return "跳过"
        }
    }
}

private struct RSSSupplementalBadge: View {
    let title: String
    let tone: RSSSupplementalTone

    var body: some View {
        Text(title)
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(color)
            .padding(.horizontal, 7)
            .frame(minHeight: 22)
            .background(Capsule().fill(color.opacity(0.13)))
    }

    private var color: SwiftUI.Color {
        switch tone {
        case .good:
            return SwiftUI.Color(red: 0x2f/255, green: 0x6b/255, blue: 0x52/255)
        case .warn:
            return SwiftUI.Color(red: 0x8b/255, green: 0x58/255, blue: 0x29/255)
        case .muted:
            return SwiftUI.Color.secondary
        }
    }
}

private extension View {
    func rssSupplementalCard(cornerRadius: CGFloat = ReaderDesignTokens.Radius.md) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.72), lineWidth: 1)
                )
                .shadow(
                    color: SwiftUI.Color(red: 80/255, green: 67/255, blue: 52/255, opacity: 0.08),
                    radius: 12,
                    x: 0,
                    y: 8
                )
        )
    }
}

private extension String {
    var nonEmpty: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
