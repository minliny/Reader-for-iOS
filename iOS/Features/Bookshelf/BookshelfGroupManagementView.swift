import SwiftUI

struct BookshelfGroupManagementView: View {
    @State private var selectedGroupID = BookshelfGroupItem.demoGroups.first?.id ?? "default"
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    private let onExit: (() -> Void)?

    init(onExit: (() -> Void)? = nil) {
        self.onExit = onExit
    }

    var body: some View {
        DemoBackScreen(title: "分组管理", onBack: onExit) {
            groupList
            assignmentList
        } bottomActionHost: {
            BottomFixedActionRow {
                BookshelfGroupBottomButton(title: "新建分组", isPrimary: true) {
                    selectedGroupID = "new-group"
                }
            } trailing: {
                BookshelfGroupBottomButton(title: "完成", isPrimary: false) {
                    if let onExit {
                        onExit()
                    } else {
                        dismiss()
                    }
                }
            }
        }
    }

    private var selectedGroup: BookshelfGroupItem {
        BookshelfGroupItem.demoGroups.first { $0.id == selectedGroupID } ?? BookshelfGroupItem.demoGroups[0]
    }

    private var groupList: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 0) {
                managementTitle("分组列表")

                ForEach(BookshelfGroupItem.demoGroups) { group in
                    BookshelfGroupRow(
                        group: group,
                        isSelected: group.id == selectedGroup.id,
                        onSelect: { selectedGroupID = group.id }
                    )
                    if group.id != BookshelfGroupItem.demoGroups.last?.id {
                        Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    }
                }
            }
            .padding(.top, max(0, ReaderDesignTokens.bookGroupListTopPadding - ReaderDesignTokens.cardPadding))
        }
    }

    private var assignmentList: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 0) {
                managementTitle("书籍归属")

                ForEach(BookshelfGroupAssignmentItem.demoAssignments) { item in
                    BookshelfGroupAssignmentRow(item: item, isSelected: item.groupID == selectedGroup.id)
                    if item.id != BookshelfGroupAssignmentItem.demoAssignments.last?.id {
                        Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    }
                }
            }
            .padding(.top, max(0, ReaderDesignTokens.bookGroupListTopPadding - ReaderDesignTokens.cardPadding))
        }
    }

    private func managementTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            .padding(.horizontal, ReaderDesignTokens.bookGroupRowHorizontalPadding - ReaderDesignTokens.cardPadding)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct BookshelfGroupItem: Identifiable, Hashable {
    let id: String
    let name: String
    let meta: String
    let action: String
    let canDelete: Bool

    static let demoGroups: [BookshelfGroupItem] = [
        BookshelfGroupItem(id: "default", name: "默认分组", meta: "8 本 · 当前分组", action: "管理", canDelete: false),
        BookshelfGroupItem(id: "following", name: "追更", meta: "5 本 · 置顶显示", action: "管理", canDelete: true),
        BookshelfGroupItem(id: "local", name: "本地书", meta: "2 本 · 导入书籍", action: "管理", canDelete: true),
        BookshelfGroupItem(id: "reference", name: "资料", meta: "3 本 · 可重命名", action: "管理", canDelete: true)
    ]
}

private struct BookshelfGroupAssignmentItem: Identifiable, Hashable {
    let id: String
    let title: String
    let meta: String
    let groupID: String
    let groupName: String

    static let demoAssignments: [BookshelfGroupAssignmentItem] = [
        BookshelfGroupAssignmentItem(id: "mist-lighthouse", title: "灯塔与雾", meta: "书源同步 · 当前分组", groupID: "default", groupName: "默认分组"),
        BookshelfGroupAssignmentItem(id: "rain-city", title: "雨城札记", meta: "林间 · 当前分组", groupID: "following", groupName: "追更"),
        BookshelfGroupAssignmentItem(id: "local-notes", title: "本地导入手记", meta: "本地书 · 当前分组", groupID: "local", groupName: "本地书"),
        BookshelfGroupAssignmentItem(id: "sea-archive", title: "海边档案", meta: "远山 · 当前分组", groupID: "reference", groupName: "资料")
    ]
}

private struct BookshelfGroupRow: View {
    let group: BookshelfGroupItem
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack(spacing: ReaderDesignTokens.bookGroupRowGap) {
            ReaderIcon(.sort, size: 18, accessibilityLabel: "排序")
                .frame(width: ReaderDesignTokens.bookGroupIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            VStack(alignment: .leading, spacing: 3) {
                Text(group.name)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .foregroundStyle(ReaderDesignTokens.Color.ink)
                    .lineLimit(1)
                Text(group.meta)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture(perform: onSelect)

            Button(action: onSelect) {
                BookshelfGroupPill(title: group.action, isSelected: isSelected)
            }
            .buttonStyle(.plain)

            if group.canDelete {
                BookshelfGroupDeleteButton()
            }
        }
        .padding(.horizontal, ReaderDesignTokens.bookGroupRowHorizontalPadding - ReaderDesignTokens.cardPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookGroupRowMinHeight, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                .fill(isSelected ? ReaderDesignTokens.Color.primary.opacity(0.08) : SwiftUI.Color.clear)
        )
        .accessibilityLabel("\(group.name)，\(group.meta)")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

private struct BookshelfGroupAssignmentRow: View {
    let item: BookshelfGroupAssignmentItem
    let isSelected: Bool

    var body: some View {
        HStack(spacing: ReaderDesignTokens.bookGroupRowGap) {
            ReaderIcon(.bookOpen, size: 18, accessibilityLabel: "书籍")
                .frame(width: ReaderDesignTokens.bookGroupIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .foregroundStyle(ReaderDesignTokens.Color.ink)
                    .lineLimit(1)
                Text(item.meta)
                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BookshelfGroupPill(title: item.groupName, isSelected: isSelected)
        }
        .padding(.horizontal, ReaderDesignTokens.bookGroupRowHorizontalPadding - ReaderDesignTokens.cardPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookGroupAssignmentRowMinHeight, alignment: .leading)
    }
}

private struct BookshelfGroupPill: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
            .lineLimit(1)
            .foregroundColor(isSelected ? .white : ReaderDesignTokens.Color.primaryDark)
            .padding(.horizontal, 10)
            .frame(minHeight: ReaderDesignTokens.bookGroupActionMinHeight)
            .background(
                Capsule()
                    .fill(isSelected ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.primary.opacity(0.10))
            )
    }
}

private struct BookshelfGroupDeleteButton: View {
    var body: some View {
        Button(role: .destructive, action: {}) {
            ReaderIcon(.trash, size: 15, accessibilityLabel: "删除分组")
                .foregroundColor(ReaderDesignTokens.Color.danger)
                .frame(width: ReaderDesignTokens.bookGroupDeleteButtonSize, height: ReaderDesignTokens.bookGroupDeleteButtonSize)
                .background(Circle().fill(ReaderDesignTokens.Color.danger.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }
}

private struct BookshelfGroupBottomButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                .lineLimit(1)
                .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.controlIconAlt)
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
                .background(
                    Capsule()
                        .fill(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBackground)
                        .overlay(Capsule().stroke(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}
