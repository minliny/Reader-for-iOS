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
    let bottomPadding: CGFloat

    init(
        bottomPadding: CGFloat = ReaderDesignTokens.demoContentVerticalPadding,
        @ViewBuilder content: () -> Content
    ) {
        self.bottomPadding = bottomPadding
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                content
            }
            .padding(.horizontal, ReaderDesignTokens.demoContentHorizontalPadding)
            .padding(.top, ReaderDesignTokens.demoContentVerticalPadding)
            .padding(.bottom, bottomPadding)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(ReaderDesignTokens.Color.paperSolid.ignoresSafeArea())
    }
}

struct MainTabBarVisibilityPreferenceKey: PreferenceKey {
    static var defaultValue: Bool = true

    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value && nextValue()
    }
}

extension View {
    func mainTabBarVisible(_ isVisible: Bool) -> some View {
        preference(key: MainTabBarVisibilityPreferenceKey.self, value: isVisible)
    }
}

enum DemoBackScreenContentStyle {
    case paper
    case custom
}

public enum MainTabTopBarRequest: Equatable {
    case bookshelfSearch
    case bookshelfMore
    case discoverRefresh
    case rssRefresh
    case rssManage
}

struct DemoBackScreen<Content: View, Trailing: View, BottomActionHost: View, SheetHost: View, DialogHost: View, StateHost: View>: View {
    let title: String
    let contentStyle: DemoBackScreenContentStyle
    let content: Content
    let trailing: Trailing
    let bottomActionHost: BottomActionHost
    let sheetHost: SheetHost
    let dialogHost: DialogHost
    let stateHost: StateHost

    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder bottomActionHost: () -> BottomActionHost,
        @ViewBuilder sheetHost: () -> SheetHost,
        @ViewBuilder dialogHost: () -> DialogHost,
        @ViewBuilder stateHost: () -> StateHost
    ) {
        self.title = title
        self.contentStyle = contentStyle
        self.content = content()
        self.trailing = trailing()
        self.bottomActionHost = bottomActionHost()
        self.sheetHost = sheetHost()
        self.dialogHost = dialogHost()
        self.stateHost = stateHost()
    }

    var body: some View {
        DemoLibraryShell(title: title, contentStyle: contentStyle) {
            content
        } trailing: {
            trailing
        } bottomActionHost: {
            bottomActionHost
        } sheetHost: {
            sheetHost
        } dialogHost: {
            dialogHost
        } stateHost: {
            stateHost
        }
    }
}

extension DemoBackScreen where BottomActionHost == EmptyView, SheetHost == EmptyView, DialogHost == EmptyView, StateHost == EmptyView {
    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: title,
            contentStyle: contentStyle,
            content: content,
            trailing: trailing,
            bottomActionHost: { EmptyView() },
            sheetHost: { EmptyView() },
            dialogHost: { EmptyView() },
            stateHost: { EmptyView() }
        )
    }
}

extension DemoBackScreen where Trailing == EmptyView, BottomActionHost == EmptyView, SheetHost == EmptyView, DialogHost == EmptyView, StateHost == EmptyView {
    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, contentStyle: contentStyle, content: content, trailing: {
            EmptyView()
        })
    }
}

extension DemoBackScreen where Trailing == EmptyView, SheetHost == EmptyView, DialogHost == EmptyView, StateHost == EmptyView {
    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottomActionHost: () -> BottomActionHost
    ) {
        self.init(
            title: title,
            contentStyle: contentStyle,
            content: content,
            trailing: { EmptyView() },
            bottomActionHost: bottomActionHost,
            sheetHost: { EmptyView() },
            dialogHost: { EmptyView() },
            stateHost: { EmptyView() }
        )
    }
}

extension DemoBackScreen where SheetHost == EmptyView, DialogHost == EmptyView, StateHost == EmptyView {
    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder bottomActionHost: () -> BottomActionHost
    ) {
        self.init(
            title: title,
            contentStyle: contentStyle,
            content: content,
            trailing: trailing,
            bottomActionHost: bottomActionHost,
            sheetHost: { EmptyView() },
            dialogHost: { EmptyView() },
            stateHost: { EmptyView() }
        )
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
        .buttonStyle(DemoPressButtonStyle())
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .accessibilityLabel(accessibilityLabel)
    }
}

/// Shared `button.press` feedback for demo-derived controls.
/// Uses native SwiftUI animation while keeping token values aligned with the
/// frontend demo motion contract.
struct DemoPressButtonStyle: ButtonStyle {
    var scale: CGFloat = AppMotion.Scale.pressMin
    var duration: TimeInterval = AppMotion.Duration.buttonPress

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(
                MotionEnvironment().animation(duration),
                value: configuration.isPressed
            )
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
                    .buttonStyle(DemoPressButtonStyle())
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
        .buttonStyle(DemoPressButtonStyle())
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : [.isButton])
        .animation(MotionEnvironment().animation(AppMotion.Duration.chipSelect), value: isSelected)
    }
}

struct DemoFilterOption {
    let id: String
    let label: String
    var icon: ReaderAssetIcon?
    var isActive: Bool
    var action: () -> Void

    init(
        id: String? = nil,
        label: String,
        icon: ReaderAssetIcon? = nil,
        isActive: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.id = id ?? label
        self.label = label
        self.icon = icon
        self.isActive = isActive
        self.action = action
    }
}

struct DemoFilterGroup {
    let title: String
    let options: [DemoFilterOption]
}

struct DemoFilterDisclosure: View {
    let label: String
    let summary: String
    var accessibilityLabel: String
    var applyTitle: String?
    var onApply: (() -> Void)?
    let groups: [DemoFilterGroup]
    @Binding var isOpen: Bool
    private let motion = MotionEnvironment()

    init(
        label: String,
        summary: String,
        accessibilityLabel: String? = nil,
        applyTitle: String? = nil,
        isOpen: Binding<Bool>,
        groups: [DemoFilterGroup],
        onApply: (() -> Void)? = nil
    ) {
        self.label = label
        self.summary = summary
        self.accessibilityLabel = accessibilityLabel ?? label
        self.applyTitle = applyTitle
        self._isOpen = isOpen
        self.groups = groups
        self.onApply = onApply
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.filterControlGap) {
            HStack(spacing: ReaderDesignTokens.filterControlGap) {
                Button {
                    let duration = isOpen ? AppMotion.Duration.dropdownCollapse : AppMotion.Duration.dropdownExpand
                    motion.withMotionAnimation(duration) {
                        isOpen.toggle()
                    }
                } label: {
                    HStack(spacing: ReaderDesignTokens.filterTriggerGap) {
                        ReaderIcon(.filter, size: 16, accessibilityLabel: accessibilityLabel)
                            .frame(width: ReaderDesignTokens.filterTriggerIconColumn)
                        Text(label)
                            .font(.system(size: 12, weight: .heavy))
                            .lineLimit(1)
                        Text(summary)
                            .font(.system(size: 11, weight: .heavy))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        ReaderIcon(.chevron, size: 14, accessibilityLabel: isOpen ? "收起" : "展开")
                            .frame(width: ReaderDesignTokens.filterTriggerChevronColumn)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isOpen ? -90 : 90))
                            .animation(motion.animation(AppMotion.Duration.dropdownSelect), value: isOpen)
                    }
                    .padding(.horizontal, ReaderDesignTokens.filterTriggerHorizontalPadding)
                    .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.filterControlMinHeight)
                    .foregroundColor(SwiftUI.Color(red: 0x3f/255, green: 0x37/255, blue: 0x2f/255))
                    .background(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .fill(ReaderDesignTokens.Color.surface.opacity(0.90))
                            .overlay(
                                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                    .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.92), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(DemoPressButtonStyle())
                .accessibilityLabel(accessibilityLabel)
                .accessibilityValue(summary)

                if let applyTitle, let onApply {
                    Button {
                        motion.withMotionAnimation(AppMotion.Duration.filterCommit) {
                            onApply()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            ReaderIcon(.check, size: 13, accessibilityLabel: applyTitle)
                            Text(applyTitle)
                                .font(.system(size: 12, weight: .heavy))
                                .lineLimit(1)
                        }
                        .padding(.horizontal, ReaderDesignTokens.filterTriggerHorizontalPadding)
                        .frame(minWidth: ReaderDesignTokens.filterApplyMinWidth)
                        .frame(minHeight: ReaderDesignTokens.filterControlMinHeight)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            SwiftUI.Color(red: 0x43/255, green: 0x6f/255, blue: 0x88/255),
                                            SwiftUI.Color(red: 0x31/255, green: 0x5f/255, blue: 0x78/255)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(
                            color: SwiftUI.Color(red: 49/255, green: 95/255, blue: 120/255, opacity: 0.22),
                            radius: 7,
                            x: 0,
                            y: 7
                        )
                    }
                    .buttonStyle(DemoPressButtonStyle())
                    .accessibilityLabel(applyTitle)
                }
            }

            if isOpen {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.filterMenuGap) {
                    ForEach(Array(groups.enumerated()), id: \.offset) { _, group in
                        VStack(alignment: .leading, spacing: ReaderDesignTokens.filterMenuGroupGap) {
                            Text(group.title)
                                .font(.system(size: 11, weight: .heavy))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 68), spacing: ReaderDesignTokens.filterMenuOptionGap)],
                                alignment: .leading,
                                spacing: ReaderDesignTokens.filterMenuOptionGap
                            ) {
                                ForEach(group.options, id: \.id) { option in
                                    Button {
                                        motion.withMotionAnimation(AppMotion.Duration.dropdownSelect) {
                                            option.action()
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            if let icon = option.icon {
                                                ReaderIcon(icon, size: 13, accessibilityLabel: option.label)
                                            }
                                            Text(option.label)
                                                .font(.system(size: 11, weight: .heavy))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, ReaderDesignTokens.filterTriggerHorizontalPadding)
                                        .frame(minHeight: ReaderDesignTokens.filterMenuOptionMinHeight)
                                        .foregroundColor(option.isActive ? .white : SwiftUI.Color(red: 0x3f/255, green: 0x37/255, blue: 0x2f/255))
                                        .background(
                                            Capsule()
                                                .fill(option.isActive ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground.opacity(0.64))
                                                .overlay(
                                                    Capsule()
                                                        .stroke(
                                                            option.isActive ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.mainNavBorder.opacity(0.86),
                                                            lineWidth: 1
                                                        )
                                                )
                                        )
                                    }
                                    .buttonStyle(DemoPressButtonStyle())
                                    .accessibilityLabel(option.label)
                                    .animation(motion.animation(AppMotion.Duration.chipSelect), value: option.isActive)
                                }
                            }
                        }
                    }
                }
                .padding(ReaderDesignTokens.filterMenuPadding)
                .background(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                        .fill(ReaderDesignTokens.Color.surface.opacity(0.98))
                        .overlay(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                                .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.92), lineWidth: 1)
                        )
                        .shadow(
                            color: SwiftUI.Color(red: 82/255, green: 66/255, blue: 48/255, opacity: 0.18),
                            radius: 14,
                            x: 0,
                            y: 14
                        )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .zIndex(8)
        .animation(motion.animation(isOpen ? AppMotion.Duration.dropdownExpand : AppMotion.Duration.dropdownCollapse), value: isOpen)
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
            MotionEnvironment().withMotionAnimation(AppMotion.Duration.toggleSwitch) {
                isOn.toggle()
            }
        } label: {
            DemoIconRow(icon: icon, title: title, subtitle: subtitle, detail: isOn ? onDetail : offDetail) {
                DemoSwitchIndicator(isOn: isOn)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(DemoPressButtonStyle())
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
        .animation(MotionEnvironment().animation(AppMotion.Duration.toggleSwitch), value: isOn)
    }
}

struct DemoBottomSheet<Content: View>: View {
    let title: String?
    let maxHeight: CGFloat?
    let onDismiss: () -> Void
    let content: Content

    init(
        title: String? = nil,
        maxHeight: CGFloat? = nil,
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.maxHeight = maxHeight
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            SwiftUI.Color.black.opacity(0.28)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Capsule()
                    .fill(ReaderDesignTokens.Color.mainNavBorder)
                    .frame(width: 44, height: 4)
                    .frame(maxWidth: .infinity)

                if let title {
                    HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                        Text(title)
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: onDismiss) {
                            ReaderIcon(.clear, size: 14, accessibilityLabel: "关闭\(title)")
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    }
                }

                content
            }
            .padding(ReaderDesignTokens.cardPadding)
            .frame(maxWidth: .infinity, maxHeight: maxHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                    .fill(ReaderDesignTokens.Color.paperSolid)
                    .overlay(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.lg)
                            .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                    )
                    .shadow(
                        color: SwiftUI.Color(red: 31/255, green: 27/255, blue: 23/255, opacity: 0.22),
                        radius: 22,
                        x: 0,
                        y: 18
                    )
            )
            .padding(.horizontal, ReaderDesignTokens.cardPadding)
            .padding(.bottom, ReaderDesignTokens.cardPadding)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .contain)
    }
}

struct DemoDialogOverlay<Content: View>: View {
    let onDismiss: () -> Void
    let content: Content

    init(
        onDismiss: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.onDismiss = onDismiss
        self.content = content()
    }

    var body: some View {
        ZStack {
            SwiftUI.Color.black.opacity(0.32)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)

            content
                .padding(.horizontal, ReaderDesignTokens.cardPadding)
                .frame(maxWidth: 390)
        }
        .transition(.scale(scale: 0.96).combined(with: .opacity))
        .accessibilityElement(children: .contain)
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
