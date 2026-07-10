import SwiftUI
import ReaderUIContract

// MARK: - Slice 5d Component Views（发现系列）
//
// 真源：contracts/fixtures/view-state.fixtures.json 的 discover / discover-rule-test /
// discover-source-bulk / discover-empty / discover-error / discover-loading /
// discover-no-results / discover-source-login RouteId

struct DiscoverSourceBarView: View {
    let props: DiscoverSourceBarProps
    var body: some View {
        HStack(spacing: 8) {
            Image(ReaderAssetIcon.grid.assetName)
                .foregroundColor(ReaderDesignTokens.Color.muted)
            Text("发现源")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.ink)
            Spacer()
            Image(ReaderAssetIcon.chevron.assetName)
                .font(.system(size: 10)) // 图标尺寸，非文字字号
                .foregroundColor(ReaderDesignTokens.Color.muted)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

struct DiscoverEntryRowView: View {
    let props: DiscoverEntryRowProps
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                entryChip("排行")
                entryChip("分类")
                entryChip("书单")
                entryChip("完本")
                entryChip("最新")
            }
            .padding(.horizontal, 16)
        }
    }
    private func entryChip(_ title: String) -> some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
            .foregroundColor(ReaderDesignTokens.Color.muted)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(ReaderDesignTokens.Color.surface)
            .clipShape(Capsule())
    }
}

struct DiscoverFilterTriggerView: View {
    let props: DiscoverFilterTriggerProps
    var body: some View {
        HStack(spacing: 8) {
            chip("筛选")
            chip("排序")
            Spacer()
        }
        .padding(.horizontal, 16)
    }
    private func chip(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
            Image(ReaderAssetIcon.chevron.assetName)
                .font(.system(size: 8)) // 图标尺寸，非文字字号
        }
        .foregroundColor(ReaderDesignTokens.Color.muted)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(ReaderDesignTokens.Color.surface)
        .clipShape(Capsule())
    }
}

struct DiscoverListHeadView: View {
    let props: DiscoverListHeadProps
    var body: some View {
        HStack {
            Text("发现列表")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                .foregroundColor(ReaderDesignTokens.Color.ink)
            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

struct DiscoverBookListView: View {
    let props: DiscoverBookListProps
    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Text("（Slice 5d 占位，后续 slice 接发现书籍列表）")
                .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                .foregroundColor(ReaderDesignTokens.Color.muted)
        }
        .padding(.horizontal, 16)
    }
}

struct DiscoverStatePageView: View {
    let props: DiscoverStatePageProps
    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            Image(iconName.assetName)
                .font(.system(size: 36)) // 图标尺寸，非文字字号
                .foregroundStyle(ReaderDesignTokens.Color.muted)
            if let title = props.title {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .semibold))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
            }
            if let message = props.message {
                Text(message)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .multilineTextAlignment(.center)
            }
            if let action = props.action {
                Button(action) {}
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
    private var iconName: ReaderAssetIcon {
        switch props.variant {
        case "loading": return .refresh
        case "error": return .warning
        case "no-results": return .search
        default: return .folder
        }
    }
}

struct DiscoverRuleTestPageView: View {
    let props: DiscoverRuleTestPageProps
    var body: some View {
        Form {
            Section("规则测试") {
                Text("（Slice 5d 占位，后续 slice 接规则测试）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct DiscoverSourceBulkPageView: View {
    let props: DiscoverSourceBulkPageProps
    var body: some View {
        Form {
            Section("发现源管理") {
                Text("（Slice 5d 占位，后续 slice 接源列表）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

struct DiscoverSourceLoginPageView: View {
    let props: DiscoverSourceLoginPageProps
    var body: some View {
        Form {
            Section("源登录") {
                Text("（Slice 5d 占位，后续 slice 接登录表单）")
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
        }
    }
}

// MARK: - Slice 5d Component Registration

extension ComponentRegistry {
    public static func registerSlice5dComponents() {
        register([
            (.discoverSourceBar, { component in
                let props = DiscoverSourceBarProps(props: component.props) ?? DiscoverSourceBarProps(props: [:])!
                return AnyView(DiscoverSourceBarView(props: props))
            }),
            (.discoverEntryRow, { component in
                let props = DiscoverEntryRowProps(props: component.props) ?? DiscoverEntryRowProps(props: [:])!
                return AnyView(DiscoverEntryRowView(props: props))
            }),
            (.discoverFilterTrigger, { component in
                let props = DiscoverFilterTriggerProps(props: component.props) ?? DiscoverFilterTriggerProps(props: [:])!
                return AnyView(DiscoverFilterTriggerView(props: props))
            }),
            (.discoverListHead, { component in
                let props = DiscoverListHeadProps(props: component.props) ?? DiscoverListHeadProps(props: [:])!
                return AnyView(DiscoverListHeadView(props: props))
            }),
            (.discoverBookList, { component in
                let props = DiscoverBookListProps(props: component.props) ?? DiscoverBookListProps(props: [:])!
                return AnyView(DiscoverBookListView(props: props))
            }),
            (.discoverStatePage, { component in
                let props = DiscoverStatePageProps(props: component.props) ?? DiscoverStatePageProps(props: [:])!
                return AnyView(DiscoverStatePageView(props: props))
            }),
            (.discoverRuleTestPage, { component in
                let props = DiscoverRuleTestPageProps(props: component.props) ?? DiscoverRuleTestPageProps(props: [:])!
                return AnyView(DiscoverRuleTestPageView(props: props))
            }),
            (.discoverSourceBulkPage, { component in
                let props = DiscoverSourceBulkPageProps(props: component.props) ?? DiscoverSourceBulkPageProps(props: [:])!
                return AnyView(DiscoverSourceBulkPageView(props: props))
            }),
            (.discoverSourceLoginPage, { component in
                let props = DiscoverSourceLoginPageProps(props: component.props) ?? DiscoverSourceLoginPageProps(props: [:])!
                return AnyView(DiscoverSourceLoginPageView(props: props))
            }),
        ])
    }
}
