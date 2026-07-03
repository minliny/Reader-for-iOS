import SwiftUI

public struct BookSourceRowView: View {
    let name: String
    let url: String
    let group: String?
    @Binding var enabled: Bool
    let onDelete: () -> Void
    let onShare: (() -> Void)?
    let onTapDetail: (() -> Void)?

    public init(
        name: String,
        url: String,
        group: String? = nil,
        enabled: Binding<Bool>,
        onDelete: @escaping () -> Void,
        onShare: (() -> Void)? = nil,
        onTapDetail: (() -> Void)? = nil
    ) {
        self.name = name
        self.url = url
        self.group = group
        self._enabled = enabled
        self.onDelete = onDelete
        self.onShare = onShare
        self.onTapDetail = onTapDetail
    }

    public var body: some View {
        HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
            sourceIdentityButton

            HStack(spacing: 6) {
                iconAction(icon: enabled ? .pause : .play, label: enabled ? "停用" : "启用") {
                    enabled.toggle()
                }
                if let onShare {
                    iconAction(icon: .upload, label: "分享", action: onShare)
                }
                iconAction(icon: .trash, label: "删除", action: onDelete)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssSourceListRowMinHeight, alignment: .leading)
        .background(ReaderDesignTokens.Color.surface)
    }

    private var sourceIdentityButton: some View {
        Button {
            onTapDetail?()
        } label: {
            HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(.source, size: 18, accessibilityLabel: name)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(name)
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        sourceStatusChip
                    }

                    Text(url)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if let group, !group.isEmpty {
                        Text(group)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("查看 \(name) 详情")
    }

    private var sourceStatusChip: some View {
        Text(enabled ? "已启用" : "已禁用")
            .font(.system(size: 10, weight: .heavy))
            .foregroundColor(enabled ? .white : ReaderDesignTokens.Color.primaryDark)
            .padding(.horizontal, 8)
            .frame(minHeight: 22)
            .background(
                Capsule().fill(enabled ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.chipBackground)
            )
    }

    private func iconAction(icon: ReaderAssetIcon, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ReaderIcon(icon, size: 14, accessibilityLabel: label)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .frame(width: ReaderDesignTokens.rssSourceListMoreButtonSize, height: ReaderDesignTokens.rssSourceListMoreButtonSize)
                .background(Circle().fill(ReaderDesignTokens.Color.chipBackground.opacity(0.82)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
