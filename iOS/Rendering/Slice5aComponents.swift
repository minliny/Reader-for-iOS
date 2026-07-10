import SwiftUI
import ReaderUIContract

// MARK: - Slice 5a Component Views（RSS 系列）
//
// RSS 全链路的 16 个 component view。
// 真源：contracts/fixtures/view-state.fixtures.json 的 rss / rss-all / rss-detail /
// rss-original / rss-original-browser / rss-subscription-management / rss-empty /
// rss-error / rss-refreshing / rss-search / rss-starred / rss-favorite-groups /
// rss-source-groups / rss-source-add / rss-source-edit / rss-source-import RouteId
//
// 设计：
// - RSS 主页（rss）：topbar + 5 个内容组件 + bottom-nav
// - RSS 子页：BackTopBar + 单一 Page view（已在 Slice 2 注册的 BackTopBar 不重复）
// - 状态页（rss-empty / rss-error）：复用 RssStatePageView 私有辅助 view
// - 每个内容组件从 ViewStateComponent.props 解码为强类型 Props

// MARK: - 1. RssSearchEntry

struct RssSearchEntryView: View {
    let props: RssSearchEntryProps

    var body: some View {
        HStack(spacing: 8) {
            Image(ReaderAssetIcon.search.assetName)
                .foregroundColor(ReaderDesignTokens.Color.muted)
            Text("搜索订阅源")
                .foregroundColor(ReaderDesignTokens.Color.muted)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(ReaderDesignTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 16)
    }
}

// MARK: - 2. RssModeRow

struct RssModeRowView: View {
    let props: RssModeRowProps

    var body: some View {
        HStack(spacing: ReaderDesignTokens.demoContentGap) {
            modeChip(title: "全部", active: true)
            modeChip(title: "收藏", active: false)
            modeChip(title: "分组", active: false)
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private func modeChip(title: String, active: Bool) -> some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: active ? .semibold : .regular))
            .foregroundColor(active ? ReaderDesignTokens.Color.surface : ReaderDesignTokens.Color.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(active ? ReaderDesignTokens.Color.ink : ReaderDesignTokens.Color.surface)
            .clipShape(Capsule())
    }
}

// MARK: - 3. RssSourceOverview

struct RssSourceOverviewView: View {
    let props: RssSourceOverviewProps

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("订阅源概览")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.ink)
            Text("共 0 个订阅源 · 0 篇未读")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - 4. RssArticleSection

struct RssArticleSectionView: View {
    let props: RssArticleSectionProps

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            Text("文章列表")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.ink)
            Text("暂无文章更新")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - 5. RssAllPage

struct RssAllPageView: View {
    let props: RssAllPageProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                Text("全部条目")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                Text("（Slice 5a 骨架占位，后续 slice 接真实数据）")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 6. RssDetailPage

struct RssDetailPageView: View {
    let props: RssDetailPageProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                if let title = props.title {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.ink)
                }
                Text("（Slice 5a 骨架占位，后续 slice 接真实正文）")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 7. RssOriginalPage

struct RssOriginalPageView: View {
    let props: RssOriginalPageProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(ReaderAssetIcon.file.assetName)
                .font(.system(size: 36)) // 图标尺寸，非文字字号
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text("原文 webview（Slice 5a 占位）")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 8. RssRefreshingPage

struct RssRefreshingPageView: View {
    let props: RssRefreshingPageProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            ProgressView()
                .progressViewStyle(.circular)
            Text("刷新中…")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 9. RssOriginalBrowserPage

struct RssOriginalBrowserPageView: View {
    let props: RssOriginalBrowserPageProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(ReaderAssetIcon.globe.assetName)
                .font(.system(size: 36)) // 图标尺寸，非文字字号
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Text("外部浏览器（Slice 5a 占位）")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 32)
    }
}

// MARK: - 10. RssFavoriteGroupsPage

struct RssFavoriteGroupsPageView: View {
    let props: RssFavoriteGroupsPageProps

    var body: some View {
        Form {
            Section("收藏分组") {
                Text("（Slice 5a 骨架占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 11. RssSourceGroupsPage

struct RssSourceGroupsPageView: View {
    let props: RssSourceGroupsPageProps

    var body: some View {
        Form {
            Section("RSS 源分组") {
                Text("（Slice 5a 骨架占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 12. RssSourceImportPage

struct RssSourceImportPageView: View {
    let props: RssSourceImportPageProps

    var body: some View {
        Form {
            Section("导入 RSS 源") {
                if let message = props.message {
                    Text(message)
                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                }
            }
            Section("来源") {
                Text("从 OPML / URL 导入（Slice 5a 占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 13. RssSourceEditPage

struct RssSourceEditPageView: View {
    let props: RssSourceEditPageProps

    var body: some View {
        Form {
            Section("RSS 源") {
                LabeledRow(label: "模式", value: props.mode ?? "add")
            }
            Section("源信息") {
                Text("（Slice 5a 骨架占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 14. RssSubscriptionManagementPage

struct RssSubscriptionManagementPageView: View {
    let props: RssSubscriptionManagementPageProps

    var body: some View {
        Form {
            Section(props.title ?? "订阅源") {
                Text("（Slice 5a 骨架占位）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - 15. RssEmptyState

struct RssEmptyStateView: View {
    let props: RssEmptyStateProps

    var body: some View {
        RssStatePageView(
            systemImage: .folder,
            title: props.title,
            message: props.message,
            actionTitle: props.action
        )
    }
}

// MARK: - 16. RssErrorState

struct RssErrorStateView: View {
    let props: RssErrorStateProps

    var body: some View {
        RssStatePageView(
            systemImage: .warning,
            title: props.title,
            message: props.message,
            actionTitle: props.action
        )
    }
}

// MARK: - 私有辅助 view: RssStatePageView

private struct RssStatePageView: View {
    let systemImage: ReaderAssetIcon
    let title: String?
    let message: String?
    let actionTitle: String?

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(systemImage.assetName)
                .font(.system(size: 36)) // 图标尺寸，非文字字号
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            if let title = title {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
            }
            if let message = message {
                Text(message)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle = actionTitle {
                Button(actionTitle) {
                    // Slice 5a 占位：后续 slice 接真实事件路由
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(ReaderDesignTokens.Color.ink)
                .foregroundColor(ReaderDesignTokens.Color.surface)
                .clipShape(Capsule())
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 32)
    }
}

// MARK: - Slice 5a Component Registration

extension ComponentRegistry {

    /// 注册 Slice 5a 的 16 个 RSS component。
    /// 应在 App 启动时调用（如 ReaderApp.init），与 registerSlice2/3/4Components() 一起调用。
    public static func registerSlice5aComponents() {
        register([
            (.rssSearchEntry, { component in
                let props = RssSearchEntryProps(props: component.props) ?? RssSearchEntryProps(props: [:])!
                return AnyView(RssSearchEntryView(props: props))
            }),
            (.rssModeRow, { component in
                let props = RssModeRowProps(props: component.props) ?? RssModeRowProps(props: [:])!
                return AnyView(RssModeRowView(props: props))
            }),
            (.rssSourceOverview, { component in
                let props = RssSourceOverviewProps(props: component.props) ?? RssSourceOverviewProps(props: [:])!
                return AnyView(RssSourceOverviewView(props: props))
            }),
            (.rssArticleSection, { component in
                let props = RssArticleSectionProps(props: component.props) ?? RssArticleSectionProps(props: [:])!
                return AnyView(RssArticleSectionView(props: props))
            }),
            (.rssAllPage, { component in
                let props = RssAllPageProps(props: component.props) ?? RssAllPageProps(props: [:])!
                return AnyView(RssAllPageView(props: props))
            }),
            (.rssDetailPage, { component in
                let props = RssDetailPageProps(props: component.props) ?? RssDetailPageProps(props: [:])!
                return AnyView(RssDetailPageView(props: props))
            }),
            (.rssOriginalPage, { component in
                let props = RssOriginalPageProps(props: component.props) ?? RssOriginalPageProps(props: [:])!
                return AnyView(RssOriginalPageView(props: props))
            }),
            (.rssRefreshingPage, { component in
                let props = RssRefreshingPageProps(props: component.props) ?? RssRefreshingPageProps(props: [:])!
                return AnyView(RssRefreshingPageView(props: props))
            }),
            (.rssOriginalBrowserPage, { component in
                let props = RssOriginalBrowserPageProps(props: component.props) ?? RssOriginalBrowserPageProps(props: [:])!
                return AnyView(RssOriginalBrowserPageView(props: props))
            }),
            (.rssFavoriteGroupsPage, { component in
                let props = RssFavoriteGroupsPageProps(props: component.props) ?? RssFavoriteGroupsPageProps(props: [:])!
                return AnyView(RssFavoriteGroupsPageView(props: props))
            }),
            (.rssSourceGroupsPage, { component in
                let props = RssSourceGroupsPageProps(props: component.props) ?? RssSourceGroupsPageProps(props: [:])!
                return AnyView(RssSourceGroupsPageView(props: props))
            }),
            (.rssSourceImportPage, { component in
                let props = RssSourceImportPageProps(props: component.props) ?? RssSourceImportPageProps(props: [:])!
                return AnyView(RssSourceImportPageView(props: props))
            }),
            (.rssSourceEditPage, { component in
                let props = RssSourceEditPageProps(props: component.props) ?? RssSourceEditPageProps(props: [:])!
                return AnyView(RssSourceEditPageView(props: props))
            }),
            (.rssSubscriptionManagementPage, { component in
                let props = RssSubscriptionManagementPageProps(props: component.props) ?? RssSubscriptionManagementPageProps(props: [:])!
                return AnyView(RssSubscriptionManagementPageView(props: props))
            }),
            (.rssEmptyState, { component in
                let props = RssEmptyStateProps(props: component.props) ?? RssEmptyStateProps(props: [:])!
                return AnyView(RssEmptyStateView(props: props))
            }),
            (.rssErrorState, { component in
                let props = RssErrorStateProps(props: component.props) ?? RssErrorStateProps(props: [:])!
                return AnyView(RssErrorStateView(props: props))
            }),
        ])
    }
}
