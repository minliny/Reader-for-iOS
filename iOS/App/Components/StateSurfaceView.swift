import SwiftUI

enum StateSurfaceKind: Equatable {
    case error(message: String)
    case offline
    case permission(permission: String)

    var routeTitle: String {
        switch self {
        case .error:
            return "错误"
        case .offline:
            return "离线"
        case .permission:
            return "权限"
        }
    }

    var icon: ReaderAssetIcon {
        switch self {
        case .error:
            return .warning
        case .offline:
            return .offline
        case .permission:
            return .permission
        }
    }

    var heading: String {
        switch self {
        case .error:
            return "页面暂时不可用"
        case .offline:
            return "当前处于离线状态"
        case .permission:
            return "需要系统权限"
        }
    }

    var copy: String {
        switch self {
        case .error(let message):
            return message
        case .offline:
            return "已缓存的书籍和章节仍可继续阅读。联网后可刷新书源、同步书架和更新 RSS。"
        case .permission(let permission):
            return "请在系统设置中允许「\(permission)」权限，然后返回 Reader 继续当前操作。"
        }
    }

    var detail: String {
        switch self {
        case .error:
            return "保留当前路由上下文，可直接返回上一页或稍后重试。"
        case .offline:
            return "离线模式不会清空当前阅读进度。"
        case .permission:
            return "权限授予后不需要重新进入主 Tab。"
        }
    }

    var primaryActionTitle: String {
        switch self {
        case .error:
            return "重试"
        case .offline:
            return "检查网络"
        case .permission:
            return "去设置"
        }
    }

    var secondaryActionTitle: String {
        switch self {
        case .error, .offline:
            return "返回书架"
        case .permission:
            return "稍后处理"
        }
    }

    var iconColor: SwiftUI.Color {
        switch self {
        case .error:
            return SwiftUI.Color(red: 0x8b/255, green: 0x2f/255, blue: 0x29/255)
        case .offline:
            return SwiftUI.Color(red: 0x5c/255, green: 0x55/255, blue: 0x4b/255)
        case .permission:
            return ReaderDesignTokens.Color.primaryDark
        }
    }
}

struct StateSurfaceView: View {
    let kind: StateSurfaceKind

    var body: some View {
        DemoBackScreen(title: kind.routeTitle, contentStyle: .custom) {
            VStack(spacing: 0) {
                DemoPaperScreen {
                    Spacer(minLength: 18)
                    StateSurfaceCard(kind: kind)
                    Spacer(minLength: 18)
                }

                BottomFixedActionRow {
                    StateSurfaceActionLabel(title: kind.secondaryActionTitle, isPrimary: false)
                } trailing: {
                    StateSurfaceActionLabel(title: kind.primaryActionTitle, isPrimary: true)
                }
            }
            .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
        }
    }
}

struct PermissionStateView: View {
    let permission: String

    var body: some View {
        StateSurfaceView(kind: .permission(permission: permission))
    }
}

struct ConfirmDialog<Content: View>: View {
    let icon: ReaderAssetIcon
    let iconColor: SwiftUI.Color
    let title: String
    let message: String
    let detail: String?
    let content: Content

    init(
        icon: ReaderAssetIcon,
        iconColor: SwiftUI.Color = ReaderDesignTokens.Color.primaryDark,
        title: String,
        message: String,
        detail: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.title = title
        self.message = message
        self.detail = detail
        self.content = content()
    }

    var body: some View {
        VStack(spacing: ReaderDesignTokens.rssBrowserConfirmGap) {
            ReaderIcon(icon, size: 34, accessibilityLabel: title)
                .frame(
                    width: ReaderDesignTokens.rssBrowserConfirmIconSize,
                    height: ReaderDesignTokens.rssBrowserConfirmIconSize
                )
                .background(Circle().fill(iconColor.opacity(0.12)))
                .foregroundColor(iconColor)

            Text(title)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)
                .fixedSize(horizontal: false, vertical: true)

            if let detail {
                Text(detail)
                    .font(.system(size: ReaderDesignTokens.rssBrowserConfirmDetailFontSize, weight: .semibold))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark.opacity(0.72))
                    .lineSpacing(3)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: ReaderDesignTokens.rssBrowserConfirmTextMaxWidth)
                    .fixedSize(horizontal: false, vertical: true)
            }

            content
        }
        .padding(.vertical, ReaderDesignTokens.rssBrowserConfirmVerticalPadding)
        .padding(.horizontal, ReaderDesignTokens.rssBrowserConfirmHorizontalPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssBrowserConfirmCardMinHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                .fill(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
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

extension ConfirmDialog where Content == EmptyView {
    init(
        icon: ReaderAssetIcon,
        iconColor: SwiftUI.Color = ReaderDesignTokens.Color.primaryDark,
        title: String,
        message: String,
        detail: String? = nil
    ) {
        self.init(icon: icon, iconColor: iconColor, title: title, message: message, detail: detail) {
            EmptyView()
        }
    }
}

struct ToastSurface: View {
    let icon: ReaderAssetIcon
    let message: String

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(icon, size: 16, accessibilityLabel: message)
            Text(message)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .heavy))
                .lineLimit(2)
        }
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .padding(.horizontal, 12)
        .frame(minHeight: ReaderDesignTokens.rssManageBatchRowMinHeight)
        .background(Capsule().fill(ReaderDesignTokens.Color.chipBackground))
        .accessibilityElement(children: .combine)
    }
}

private struct StateSurfaceCard: View {
    let kind: StateSurfaceKind

    var body: some View {
        ConfirmDialog(
            icon: kind.icon,
            iconColor: kind.iconColor,
            title: kind.heading,
            message: kind.copy,
            detail: kind.detail
        ) {
            ToastSurface(icon: kind.icon, message: kind.routeTitle)
        }
    }
}

private struct StateSurfaceActionLabel: View {
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
                Capsule()
                    .fill(isPrimary ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.surface)
                    .overlay(
                        Capsule()
                            .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: isPrimary ? 0 : 1)
                    )
            )
    }
}
