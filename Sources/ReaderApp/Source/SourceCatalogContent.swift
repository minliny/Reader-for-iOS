import ReaderCoreBridge
import ReaderDesign
import SwiftUI

enum SourceListAction {
    case add, subscriptions, reports, select, selectVisible(Set<String>)
    case edit(M2SourceListEntry), enabled(String, Bool), batchEnabled(Set<String>, Bool), login(String), clearLogin(M2SourceListEntry)
    case check(Set<String>), delete(Set<String>)
    case report(M2SourceListEntry)
}

struct SourceCatalogContent: View {
    let sources: [M2SourceListEntry]
    let groups: M2SourceGroupCatalogData?
    @Binding var query: String
    @Binding var groupID: String?
    @Binding var selection: Set<String>
    let selecting: Bool
    let onAction: (SourceListAction) -> Void
    @Environment(\.readerTheme) private var theme
    @FocusState private var editingSearch: Bool

    private var displayed: [M2SourceListEntry] {
        let members = groups?.memberships.filter { $0.groupId == groupID }.map(\.sourceId) ?? []
        let visible = groupID == nil ? sources : sources.filter { members.contains($0.sourceId) }
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return visible.filter {
            needle.isEmpty || $0.name.localizedCaseInsensitiveContains(needle) || $0.baseUrl.localizedCaseInsensitiveContains(needle)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
                shortcuts
                filters
                if selecting { batchBar }
                if displayed.isEmpty {
                    PageState(state: .empty(query.isEmpty && groupID == nil ? "还没有书源" : "没有符合筛选的书源"))
                        .frame(minHeight: 190)
                }
                ForEach(displayed, id: \.sourceId) { source in
                    row(source)
                }
            }
            .padding(CGFloat(ReaderDesignMetrics.screenInset))
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.background)
    }

    private var shortcuts: some View {
        HStack(spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
            sourceShortcut("导入书源", ReaderIconRegistry.add, id: "source.add") { onAction(.add) }
            sourceShortcut("批量报告", ReaderIconRegistry.sourceHealthCheck, id: "source.reports") { onAction(.reports) }
            sourceShortcut("规则订阅", ReaderIconRegistry.sourceSubscription, id: "source.subscriptions") { onAction(.subscriptions) }
        }
    }

    private var filters: some View {
        HStack(spacing: CGFloat(ReaderDesignMetrics.controlInlineSpacing)) {
            HStack(spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
                ReaderIcon(ReaderIconRegistry.search).foregroundStyle(theme.secondaryText)
                TextField("搜索书源", text: $query)
                    .readerTypography(ReaderDesignMetrics.sourceFilterFieldText)
                    .focused($editingSearch)
                    .submitLabel(.search)
                    .onSubmit { editingSearch = false }
                    .accessibilityIdentifier("source.search")
            }
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.spaceSmall))
            .frame(minHeight: CGFloat(ReaderDesignMetrics.sourceFormFieldHeight))
            .background(theme.field, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.inputRadius)))

            Menu {
                Button("全部分组") { groupID = nil; selection = [] }
                ForEach(groups?.groups ?? [], id: \.groupId) { group in
                    Button(group.name) { groupID = group.groupId; selection = [] }
                }
            } label: {
                Label {
                    Text(groups?.groups.first { $0.groupId == groupID }?.name ?? "全部分组").lineLimit(1)
                } icon: {
                    ReaderIcon(ReaderIconRegistry.filter)
                }
                .readerTypography(ReaderDesignMetrics.sourceFilterFieldText)
                .foregroundStyle(theme.accent)
                .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
            }
            .accessibilityIdentifier("source.groups")
            Button(selecting ? "完成" : "批量") { onAction(.select) }
                .readerTypography(ReaderDesignMetrics.sourceFilterFieldText)
                .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                .accessibilityIdentifier("source.batch")
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
        }
    }

    private var batchBar: some View {
        HStack {
            Text("已选 \(selection.count) 项")
                .readerTypography(ReaderDesignMetrics.sourceStatusText)
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Button("全选结果") { onAction(.selectVisible(Set(displayed.map(\.sourceId)))) }
                .accessibilityIdentifier("source.select.visible")
            Menu("批量操作") {
                Button("启用所选") { onAction(.batchEnabled(selection, true)) }
                Button("停用所选") { onAction(.batchEnabled(selection, false)) }
                Button("检测所选") { onAction(.check(selection)) }
                    .accessibilityIdentifier("source.check.selected")
                Button("删除所选", role: .destructive) { onAction(.delete(selection)) }
            }
            .disabled(selection.isEmpty)
            .accessibilityIdentifier("source.batch.actions")
        }
        .readerTypography(ReaderDesignMetrics.sourceFilterFieldText)
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.cardPadding))
        .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
        .background(theme.accentTint, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.inputRadius)))
    }

    private func row(_ source: M2SourceListEntry) -> some View {
        HStack(spacing: CGFloat(ReaderDesignMetrics.controlInlineSpacing)) {
            if selecting {
                Button {
                    if selection.contains(source.sourceId) { selection.remove(source.sourceId) }
                    else { selection.insert(source.sourceId) }
                } label: {
                    ReaderIcon(selection.contains(source.sourceId) ? ReaderIconRegistry.checkCircle : ReaderIconRegistry.folder)
                        .frame(minWidth: CGFloat(ReaderDesignMetrics.minimumActionTarget), minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
                }
                .buttonStyle(.plain)
                .foregroundStyle(theme.accent)
                .accessibilityLabel("选择\(source.name)")
                .accessibilityAddTraits(selection.contains(source.sourceId) ? .isSelected : [])
                .accessibilityIdentifier("source.select.\(source.sourceId)")
            } else {
                ReaderIcon(ReaderIconRegistry.link)
                    .frame(width: CGFloat(ReaderDesignMetrics.sourceRowIconSize), height: CGFloat(ReaderDesignMetrics.sourceRowIconSize))
                    .foregroundStyle(theme.accent)
                    .background(theme.accentTint, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.inputRadius)))
            }

            Button {
                editingSearch = false
                onAction(.edit(source))
            } label: {
                VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                    Text(source.name).readerTypography(ReaderDesignMetrics.sourceRowTitle).lineLimit(2)
                    Text(source.baseUrl)
                        .readerTypography(ReaderDesignMetrics.sourceStatusText)
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                    if let group = sourceGroup(source) {
                        SourceStatusBadge(label: group, tone: .neutral)
                    }
                }
                .foregroundStyle(theme.primaryText)
                .frame(maxWidth: .infinity, minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget), alignment: .leading)
                .background(theme.surface)
                .contentShape(.interaction, Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("source.row.\(source.sourceId)")

            Toggle("启用\(source.name)", isOn: Binding(get: { source.enabled }, set: { onAction(.enabled(source.sourceId, $0)) }))
                .labelsHidden()
                .tint(theme.accentFill)
                .accessibilityIdentifier("source.toggle.\(source.sourceId)")

            Menu {
                Button("编辑书源") { onAction(.edit(source)) }
                Button("分层检测") { onAction(.check([source.sourceId])) }
                Button("查看检测报告") { onAction(.report(source)) }
                if source.hasLogin {
                    Button("打开登录页") { onAction(.login(source.sourceId)) }
                        .disabled(!source.enabled)
                        .accessibilityIdentifier("source.login.\(source.sourceId)")
                    Button("清除登录态") { onAction(.clearLogin(source)) }
                }
                Button("删除书源", role: .destructive) { onAction(.delete([source.sourceId])) }
            } label: {
                ReaderIcon(ReaderIconRegistry.more)
                    .foregroundStyle(theme.accent)
                    .frame(width: CGFloat(ReaderDesignMetrics.minimumActionTarget), height: CGFloat(ReaderDesignMetrics.minimumActionTarget))
            }
            .accessibilityLabel("\(source.name)的更多操作")
            .accessibilityIdentifier("source.more.\(source.sourceId)")
        }
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(theme.surface, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
    }

    private func sourceGroup(_ source: M2SourceListEntry) -> String? {
        guard let membership = groups?.memberships.first(where: { $0.sourceId == source.sourceId }) else { return nil }
        return groups?.groups.first { $0.groupId == membership.groupId }?.name
    }

    private func sourceShortcut(_ title: String, _ icon: ReaderIconMapping, id: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                ReaderIcon(icon).frame(height: CGFloat(ReaderDesignMetrics.sourceCheckActionSize))
                Text(title).readerTypography(ReaderDesignMetrics.sourceStatusText).lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
            .padding(.vertical, CGFloat(ReaderDesignMetrics.spaceExtraSmall))
            .foregroundStyle(theme.accent)
            .background(theme.surface, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(id)
    }
}

extension M2SourceListEntry {
    var hasLogin: Bool {
        if case .string(let value) = bookSource?["loginUrl"] { return !value.isEmpty }
        return false
    }
}

struct SourceStatusBadge: View {
    enum Tone { case neutral, success, warning, failure }
    let label: String
    let tone: Tone
    @Environment(\.readerTheme) private var theme

    var body: some View {
        Text(label)
            .readerTypography(ReaderDesignMetrics.sourceTransferBadgeText)
            .foregroundStyle(ink)
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.sourceTransferBadgeInlinePadding))
            .padding(.vertical, CGFloat(ReaderDesignMetrics.sourceTransferBadgeBlockPadding))
            .background(fill, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.sourceTransferBadgeRadius)))
    }

    private var ink: Color {
        switch tone {
        case .neutral: theme.secondaryText
        case .success: theme.success
        case .warning: theme.primaryText
        case .failure: theme.danger
        }
    }

    private var fill: Color {
        switch tone {
        case .neutral: theme.mutedFill
        case .success: theme.accentTint
        case .warning: theme.field
        case .failure: theme.dangerTint
        }
    }
}
