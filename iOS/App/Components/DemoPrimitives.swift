import SwiftUI

struct DemoViewportClass: RawRepresentable, Equatable, Hashable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    static let compactPortrait = DemoViewportClass(rawValue: "compact-portrait")
    static let standardPortrait = DemoViewportClass(rawValue: "standard-portrait")
    static let largePortrait = DemoViewportClass(rawValue: "large-portrait")
    static let expandedWidth = DemoViewportClass(rawValue: "expanded-width")
    static let tabletExpanded = DemoViewportClass(rawValue: "tablet-expanded")
    static let compactLandscape = DemoViewportClass(rawValue: "compact-landscape")
}

struct DemoViewportSnapshot: Equatable {
    let width: CGFloat
    let height: CGFloat
    let widthClass: String
    let heightClass: String
    let orientation: String
    let viewportClass: DemoViewportClass

    static func make(size: CGSize) -> DemoViewportSnapshot {
        let width = max(0, size.width.rounded())
        let height = max(0, size.height.rounded())
        let orientation = width > height ? "landscape" : "portrait"
        let widthClass: String
        if width < 360 {
            widthClass = "compact"
        } else if width < 480 {
            widthClass = "standard"
        } else if width < 600 {
            widthClass = "large"
        } else if width < 840 {
            widthClass = "expanded"
        } else {
            widthClass = "tablet"
        }

        let heightClass: String
        if height < 520 {
            heightClass = "compact"
        } else if height < 720 {
            heightClass = "short"
        } else {
            heightClass = "regular"
        }

        let viewportClass: DemoViewportClass
        if orientation == "landscape", height < 520 {
            viewportClass = .compactLandscape
        } else if width >= 840 {
            viewportClass = .tabletExpanded
        } else if width >= 600 {
            viewportClass = .expandedWidth
        } else if orientation == "portrait", width >= 480 {
            viewportClass = .largePortrait
        } else if orientation == "portrait", width >= 360 {
            viewportClass = .standardPortrait
        } else if orientation == "portrait" {
            viewportClass = .compactPortrait
        } else {
            viewportClass = DemoViewportClass(rawValue: "\(widthClass)-\(orientation)")
        }

        return DemoViewportSnapshot(
            width: width,
            height: height,
            widthClass: widthClass,
            heightClass: heightClass,
            orientation: orientation,
            viewportClass: viewportClass
        )
    }

    var usesTabletMainNav: Bool {
        viewportClass == .tabletExpanded
    }

    var runtimePhoneWidth: CGFloat {
        switch viewportClass {
        case .expandedWidth:
            min(560, max(0, width - 40))
        case .tabletExpanded:
            min(760, max(0, width - 64))
        default:
            min(ReaderDesignTokens.phoneWidth, max(0, width))
        }
    }

    var runtimePhoneHeight: CGFloat {
        switch viewportClass {
        case .expandedWidth:
            min(ReaderDesignTokens.phoneHeight, max(0, height - 68))
        case .tabletExpanded:
            min(960, max(0, height - 68))
        default:
            min(ReaderDesignTokens.phoneHeight, max(0, height))
        }
    }

    var runtimeStackPhoneHeight: CGFloat {
        switch viewportClass {
        case .expandedWidth:
            min(900, max(0, height - 68))
        case .tabletExpanded:
            min(960, max(0, height - 68))
        default:
            runtimePhoneHeight
        }
    }
}

struct DemoPaperScreen<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                content
            }
            .padding(.horizontal, ReaderDesignTokens.demoContentHorizontalPadding)
            .padding(.vertical, ReaderDesignTokens.demoContentVerticalPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
    }
}

enum DemoBackScreenContentStyle {
    case paper
    case custom
}

struct DemoBackScreen<Content: View, Trailing: View>: View {
    let title: String
    let contentStyle: DemoBackScreenContentStyle
    let content: Content
    let trailing: Trailing
    @SwiftUI.Environment(\.dismiss) private var dismiss

    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.contentStyle = contentStyle
        self.content = content()
        self.trailing = trailing()
    }

    var body: some View {
        VStack(spacing: 0) {
            DemoBackBar(title: title, onBack: { dismiss() }) {
                trailing
            }
            switch contentStyle {
            case .paper:
                DemoPaperScreen {
                    content
                }
            case .custom:
                content
            }
        }
        .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
#if os(iOS)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(true)
#endif
    }
}

extension DemoBackScreen where Trailing == EmptyView {
    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, contentStyle: contentStyle, content: content) {
            EmptyView()
        }
    }
}

struct DemoTopBar<Actions: View>: View {
    let title: String
    let actions: Actions

    init(title: String, @ViewBuilder actions: () -> Actions) {
        self.title = title
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .center, spacing: ReaderDesignTokens.topBarActionGap) {
            Text(title)
                .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.topBarTitleFontSize, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ReaderDesignTokens.topBarActionGap) {
                actions
            }
        }
        .padding(.horizontal, ReaderDesignTokens.topBarHorizontalPadding)
        .padding(.top, ReaderDesignTokens.topBarTopPadding)
        .frame(minHeight: ReaderDesignTokens.topBarMinHeight)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

extension DemoTopBar where Actions == EmptyView {
    init(title: String) {
        self.init(title: title) {
            EmptyView()
        }
    }
}

struct DemoBackBar<Trailing: View>: View {
    let title: String
    let onBack: () -> Void
    let trailing: Trailing

    init(
        title: String,
        onBack: @escaping () -> Void,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.onBack = onBack
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: ReaderDesignTokens.backBarGap) {
            DemoTopActionButton(icon: .back, accessibilityLabel: "返回", action: onBack)
                .frame(width: ReaderDesignTokens.topBarIconButtonSize)

            Text(title)
                .font(ReaderTypography.demoSerif(size: ReaderDesignTokens.backBarTitleFontSize, weight: .bold))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .center)

            trailing
                .frame(width: ReaderDesignTokens.topBarIconButtonSize)
        }
        .padding(.horizontal, ReaderDesignTokens.topBarHorizontalPadding)
        .padding(.top, ReaderDesignTokens.topBarTopPadding)
        .frame(minHeight: ReaderDesignTokens.topBarMinHeight)
        .background(ReaderDesignTokens.Color.paperSolid)
    }
}

extension DemoBackBar where Trailing == EmptyView {
    init(title: String, onBack: @escaping () -> Void) {
        self.init(title: title, onBack: onBack) {
            EmptyView()
        }
    }
}

struct DemoTopActionButton: View {
    let icon: ReaderAssetIcon
    let accessibilityLabel: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ReaderIcon(icon, size: 24, accessibilityLabel: accessibilityLabel)
                .frame(
                    width: ReaderDesignTokens.topBarIconButtonSize,
                    height: ReaderDesignTokens.topBarIconButtonSize
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct ReaderCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(ReaderDesignTokens.cardPadding)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                    .fill(ReaderDesignTokens.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
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

struct ReaderStateCard: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        ReaderCard {
            VStack(alignment: .center, spacing: ReaderDesignTokens.settingsSectionGap) {
                ReaderIcon(icon, size: ReaderDesignTokens.rssBrowserConfirmIconSize, accessibilityLabel: title)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                Text(title)
                    .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: ReaderDesignTokens.rssBrowserConfirmBodyFontSize))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.system(size: 13, weight: .heavy))
                            .foregroundColor(.white)
                            .frame(minWidth: 120, minHeight: ReaderDesignTokens.rssReaderInlineActionMinHeight)
                            .padding(.horizontal, 12)
                            .background(Capsule().fill(ReaderDesignTokens.Color.primaryDark))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.rssBrowserConfirmCardMinHeight)
        }
    }
}

struct ReaderStateBanner: View {
    let icon: ReaderAssetIcon
    let title: String
    let messages: [String]

    var body: some View {
        ReaderCard {
            HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 18, accessibilityLabel: title)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                    .background(Circle().fill(ReaderDesignTokens.Color.primary.opacity(0.10)))

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                    ForEach(messages, id: \.self) { message in
                        Text(message)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

struct PillChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    init(_ title: String, isSelected: Bool = false, action: @escaping () -> Void = {}) {
        self.title = title
        self.isSelected = isSelected
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .heavy))
                .lineLimit(1)
                .padding(.horizontal, ReaderDesignTokens.chipHorizontalPadding)
                .frame(minWidth: ReaderDesignTokens.chipMinWidth, maxWidth: ReaderDesignTokens.chipMaxWidth, minHeight: ReaderDesignTokens.chipMinHeight)
                .foregroundColor(isSelected ? .white : SwiftUI.Color(red: 0x2b/255, green: 0x25/255, blue: 0x1f/255))
                .background(
                    Capsule()
                        .fill(isSelected ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
    }
}

struct DemoIconRow<Accessory: View>: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String?
    let detail: String?
    let accessory: Accessory

    init(
        icon: ReaderAssetIcon,
        title: String,
        subtitle: String? = nil,
        detail: String? = nil,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.detail = detail
        self.accessory = accessory()
    }

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(icon, size: 18, accessibilityLabel: title)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .heavy))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let detail {
                Text(detail)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .bold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            accessory
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight)
    }
}

struct DemoToggleRow: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String?
    let onDetail: String
    let offDetail: String
    @Binding var isOn: Bool

    init(
        icon: ReaderAssetIcon,
        title: String,
        subtitle: String? = nil,
        onDetail: String = "on",
        offDetail: String = "off",
        isOn: Binding<Bool>
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.onDetail = onDetail
        self.offDetail = offDetail
        self._isOn = isOn
    }

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            DemoIconRow(icon: icon, title: title, subtitle: subtitle, detail: isOn ? onDetail : offDetail) {
                DemoSwitchIndicator(isOn: isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? onDetail : offDetail)
    }
}

struct DemoSwitchIndicator: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground)
                .frame(width: ReaderDesignTokens.settingsSwitchTrackWidth, height: ReaderDesignTokens.settingsSwitchTrackHeight)
            Circle()
                .fill(.white)
                .frame(width: ReaderDesignTokens.settingsSwitchThumbSize, height: ReaderDesignTokens.settingsSwitchThumbSize)
                .padding(2)
        }
        .accessibilityHidden(true)
    }
}

struct BottomFixedActionRow<Leading: View, Trailing: View>: View {
    let leading: Leading
    let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: ReaderDesignTokens.rssModeRowGap) {
            leading
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
            trailing
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
        }
        .padding(.horizontal, ReaderDesignTokens.cardPadding)
        .frame(minHeight: ReaderDesignTokens.bottomFixedActionRowMinHeight)
        .background(
            LinearGradient(
                colors: [
                    ReaderDesignTokens.Color.paperSolid.opacity(0),
                    ReaderDesignTokens.Color.paperSolid
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

extension DemoIconRow where Accessory == EmptyView {
    init(icon: ReaderAssetIcon, title: String, subtitle: String? = nil, detail: String? = nil) {
        self.init(icon: icon, title: title, subtitle: subtitle, detail: detail) {
            EmptyView()
        }
    }
}
