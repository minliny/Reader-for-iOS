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
        // demo body/`.fd-phone` 真源是 `--fd-paper-solid` #f8f4ec（`paperSolidAlt`），
        // 不是 `--fd-ds-color-paper` #fff8f4（`paperSolid`）。
        .background(ReaderDesignTokens.Color.paperSolidAlt.ignoresSafeArea())
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
    let onBack: (() -> Void)?
    let content: Content
    let trailing: Trailing
    let bottomActionHost: BottomActionHost
    let sheetHost: SheetHost
    let dialogHost: DialogHost
    let stateHost: StateHost

    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder bottomActionHost: () -> BottomActionHost,
        @ViewBuilder sheetHost: () -> SheetHost,
        @ViewBuilder dialogHost: () -> DialogHost,
        @ViewBuilder stateHost: () -> StateHost
    ) {
        self.title = title
        self.contentStyle = contentStyle
        self.onBack = onBack
        self.content = content()
        self.trailing = trailing()
        self.bottomActionHost = bottomActionHost()
        self.sheetHost = sheetHost()
        self.dialogHost = dialogHost()
        self.stateHost = stateHost()
    }

    var body: some View {
        DemoLibraryShell(title: title, contentStyle: contentStyle, onBack: onBack) {
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
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.init(
            title: title,
            contentStyle: contentStyle,
            onBack: onBack,
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
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.init(title: title, contentStyle: contentStyle, onBack: onBack, content: content, trailing: {
            EmptyView()
        })
    }
}

extension DemoBackScreen where Trailing == EmptyView, SheetHost == EmptyView, DialogHost == EmptyView, StateHost == EmptyView {
    init(
        title: String,
        contentStyle: DemoBackScreenContentStyle = .paper,
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder bottomActionHost: () -> BottomActionHost
    ) {
        self.init(
            title: title,
            contentStyle: contentStyle,
            onBack: onBack,
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
        onBack: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder bottomActionHost: () -> BottomActionHost
    ) {
        self.init(
            title: title,
            contentStyle: contentStyle,
            onBack: onBack,
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
        .background(ReaderDesignTokens.Color.paperSolidAlt)
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
        .background(ReaderDesignTokens.Color.paperSolidAlt)
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
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(ReaderDesignTokens.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                    )
                    // demo `--fd-ds-shadow-soft`: 0 8px 26px rgba(89,70,50,0.1)
                    .shadow(
                        color: ReaderDesignTokens.Color.Shadow.soft,
                        radius: 26,
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
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)

                if let actionTitle, let action {
                    Button(action: action) {
                        Text(actionTitle)
                            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
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
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                    ForEach(messages, id: \.self) { message in
                        Text(message)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
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
                .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
                .lineLimit(1)
                .padding(.horizontal, ReaderDesignTokens.chipHorizontalPadding)
                .frame(minWidth: ReaderDesignTokens.chipMinWidth, maxWidth: ReaderDesignTokens.chipMaxWidth, minHeight: ReaderDesignTokens.chipMinHeight)
                .foregroundColor(isSelected ? .white : ReaderDesignTokens.Color.controlInkAlt)
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
                            .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
                            .lineLimit(1)
                        Text(summary)
                            .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        ReaderIcon(.chevron, size: 14, accessibilityLabel: isOpen ? "收起" : "展开")
                            .frame(width: ReaderDesignTokens.filterTriggerChevronColumn)
                            .foregroundStyle(ReaderDesignTokens.Color.muted)
                            .rotationEffect(.degrees(isOpen ? -90 : 90))
                            .animation(motion.animation(AppMotion.Duration.dropdownSelect), value: isOpen)
                    }
                    .padding(.horizontal, ReaderDesignTokens.filterTriggerHorizontalPadding)
                    .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.filterControlMinHeight)
                    .foregroundColor(ReaderDesignTokens.Color.controlIcon)
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
                                .font(.system(size: ReaderDesignTokens.chipFontSize, weight: .black))
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
                                            ReaderDesignTokens.Color.primaryGradientStart,
                                            ReaderDesignTokens.Color.primaryGradientEnd
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        )
                        .shadow(
                            // demo `.fd-filter-apply`: 0 7px 14px rgba(49,95,120,0.22)
                            color: ReaderDesignTokens.Color.primaryDark.opacity(0.22),
                            radius: 14,
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
                                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
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
                                                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                                                .lineLimit(1)
                                        }
                                        .padding(.horizontal, ReaderDesignTokens.filterTriggerHorizontalPadding)
                                        .frame(minHeight: ReaderDesignTokens.filterMenuOptionMinHeight)
                                        .foregroundColor(option.isActive ? .white : ReaderDesignTokens.Color.controlIcon)
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
                            // demo `.fd-filter-menu`: 0 14px 30px rgba(82,66,48,0.18)
                            color: ReaderDesignTokens.Color.Shadow.bookHero,
                            radius: 30,
                            x: 0,
                            y: 14
                        )
                )
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .zIndex(ReaderZIndex.overlay.rawValue)
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
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let detail {
                Text(detail)
                    .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .bold))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
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

struct DemoRangeRail: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let label: String
    let valueText: String

    init(
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        label: String,
        valueText: String
    ) {
        self._value = value
        self.range = range
        self.step = step
        self.label = label
        self.valueText = valueText
    }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let progress = CGFloat(normalizedProgress)
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(ReaderDesignTokens.Color.chipBackground.opacity(0.82))
                    .frame(height: 8)

                Capsule()
                    .fill(ReaderDesignTokens.Color.primary)
                    .frame(width: width * progress, height: 8)

                Circle()
                    .fill(ReaderDesignTokens.Color.surface)
                    .frame(width: 20, height: 20)
                    .overlay(
                        Circle()
                            .stroke(ReaderDesignTokens.Color.primaryDark, lineWidth: 1)
                    )
                    .shadow(
                        // iOS slider thumb: demo 无显式 thumb shadow，颜色对齐暖灰阴影族
                        color: ReaderDesignTokens.Color.Shadow.soft.opacity(0.12),
                        radius: 6,
                        x: 0,
                        y: 3
                    )
                    .offset(x: max(0, min(width - 20, width * progress - 10)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        setValue(from: gesture.location.x, width: width)
                    }
            )
        }
        .frame(height: 28)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(valueText)
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                applyStep(step)
            case .decrement:
                applyStep(-step)
            @unknown default:
                break
            }
        }
    }

    private var normalizedProgress: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    private func setValue(from x: CGFloat, width: CGFloat) {
        let percent = min(max(Double(x / max(width, 1)), 0), 1)
        let raw = range.lowerBound + percent * (range.upperBound - range.lowerBound)
        value = snapped(raw)
    }

    private func applyStep(_ delta: Double) {
        value = snapped(value + delta)
    }

    private func snapped(_ raw: Double) -> Double {
        guard step > 0 else {
            return min(max(raw, range.lowerBound), range.upperBound)
        }
        let offset = raw - range.lowerBound
        let snappedOffset = (offset / step).rounded() * step
        return min(max(range.lowerBound + snappedOffset, range.lowerBound), range.upperBound)
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
            // demo `.fd-discover-dialog-backdrop` / `.fd-source-dialog-backdrop`:
            // rgba(35, 28, 22, 0.26)（`01-shell-layout.css` line 1804）
            ReaderDesignTokens.Color.dialogBackdrop
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
                            .font(.system(size: ReaderDesignTokens.rssBrowserConfirmTitleFontSize, weight: .heavy))
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
                        // demo `--fd-shadow` (--fd-ds-shadow-elevated): 0 18px 46px rgba(89,70,50,0.16)
                        color: ReaderDesignTokens.Color.Shadow.elevated,
                        radius: 46,
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
            // demo `.fd-book-focus-backdrop` / `.fd-bookshelf-more-backdrop`:
            // rgba(31, 27, 23, 0.34)（`00-foundation.css` line 1343）
            ReaderDesignTokens.Color.focusBackdrop
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

// MARK: - Demo Loading Spinner

/// demo `.fd-reader-loading-panel i` / `.fd-discover-bottom-loading i` /
/// `.fd-rss-bottom-loading i` 的 SwiftUI 镜像（clean-room：只承载数值化几何，
/// 不复制 CSS / keyframes）。
///
/// 真源（demo CSS 实际值）：
/// - `02a-reader-control.css` `.fd-reader-loading-panel i`：30×30 圆，3px border
///   `rgba(54,97,121,0.2)`，border-top-color `#274f66`（`--fd-primary-dark`），
///   `animation: fd-reader-loading-spin 800ms linear infinite`
/// - `01-shell-layout.css` `.fd-discover-bottom-loading i` /
///   `.fd-rss-bottom-loading i`：14×14 圆，2px border `rgba(54,97,121,0.18)`，
///   border-top-color `#366179`（`--fd-primary`）
/// - `motion-tokens.css` `--reader-motion-duration-loading-spin: 800ms`
/// - `motion-tokens.css` reduced-motion：loading-spin 立即降级为静态
///
/// 用途：替换所有系统 indeterminate `ProgressView()`，让 loading 态严格按
/// demo 几何绘制。
struct DemoLoadingSpinner: View {
    enum Size {
        /// `.fd-reader-loading-panel i`：30×30，3px border，primary-dark top。
        case reader
        /// `.fd-discover-bottom-loading i` / `.fd-rss-bottom-loading i`：14×14，
        /// 2px border，primary top。
        case inline
    }

    let size: Size
    let motion: MotionEnvironment

    init(size: Size = .reader, motion: MotionEnvironment = MotionEnvironment()) {
        self.size = size
        self.motion = motion
    }

    private var dimension: CGFloat {
        switch size {
        case .reader: return 30
        case .inline: return 14
        }
    }

    private var borderWidth: CGFloat {
        switch size {
        case .reader: return 3
        case .inline: return 2
        }
    }

    /// demo `rgba(54,97,121,0.2)` / `rgba(54,97,121,0.18)` 轨道色。
    private var trackColor: SwiftUI.Color {
        switch size {
        case .reader: return ReaderDesignTokens.Color.primary.opacity(0.20)
        case .inline: return ReaderDesignTokens.Color.primary.opacity(0.18)
        }
    }

    /// demo `#274f66`（primary-dark）或 `#366179`（primary）top arc 色。
    private var topColor: SwiftUI.Color {
        switch size {
        case .reader: return ReaderDesignTokens.Color.primaryDark
        case .inline: return ReaderDesignTokens.Color.primary
        }
    }

    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .strokeBorder(trackColor, lineWidth: borderWidth)
            .overlay(
                // top arc：用 Trim 起止偏移取顶部 ~90°，颜色用 primary/primary-dark。
                Circle()
                    .trim(from: 0.0, to: 0.25)
                    .stroke(topColor, style: StrokeStyle(lineWidth: borderWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            )
            .frame(width: dimension, height: dimension)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                // demo `--reader-motion-duration-loading-spin: 800ms` linear infinite
                let normalized = motion.duration(0.8)
                guard normalized > 0 else { return }
                withAnimation(.linear(duration: normalized).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .accessibilityLabel("加载中")
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// `DemoLoadingSpinner` 的 on-primary 变体：在 primary/primary-dark 背景上
/// 用白色轨道 + 白色 top arc，几何同 `.inline`（14×14，2px border）。
///
/// 用途：`DemoPrimaryActionButton` 等在执行中需要白色 inline spinner。
struct DemoLoadingSpinnerInlineOnPrimary: View {
    @State private var rotation: Double = 0
    private let motion = MotionEnvironment()

    var body: some View {
        Circle()
            .strokeBorder(ReaderDesignTokens.Color.overlayWhite52, lineWidth: 2)
            .overlay(
                Circle()
                    .trim(from: 0.0, to: 0.25)
                    .stroke(ReaderTokenAdapter.color(named: "--fd-ds-color-surface") ?? ReaderDesignTokens.Color.surface, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            )
            .frame(width: 14, height: 14)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                let normalized = motion.duration(0.8)
                guard normalized > 0 else { return }
                withAnimation(.linear(duration: normalized).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
            .accessibilityLabel("加载中")
            .accessibilityAddTraits(.updatesFrequently)
    }
}

// MARK: - Demo Restore Progress Meter

/// demo `.fd-restore-progress-meter` 的 SwiftUI 镜像（clean-room）。
///
/// 真源（demo CSS 实际值）：
/// - `04-settings-source.css` `.fd-restore-progress-meter i`：8px 高，pill 圆角，
///   背景 `rgba(35,121,164,0.12)`
/// - `.fd-restore-progress-meter b`：fill 宽 = `--restore-progress`，
///   背景 `#366179`（`--fd-primary`）
///
/// 用途：替换 settings/source 行内 determinate `ProgressView(value:)`。
struct DemoRestoreProgressMeter: View {
    let progress: Double // 0...1
    let tint: SwiftUI.Color

    init(progress: Double, tint: SwiftUI.Color = ReaderDesignTokens.Color.primary) {
        self.progress = max(0, min(1, progress))
        self.tint = tint
    }

    var body: some View {
        GeometryReader { proxy in
            let clamped = max(0, min(1, progress))
            ZStack(alignment: .leading) {
                // track
                Capsule()
                    .fill(ReaderDesignTokens.Color.primary.opacity(0.12))
                // fill
                Capsule()
                    .fill(tint)
                    .frame(width: proxy.size.width * clamped)
            }
        }
        .frame(height: 8)
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

// MARK: - Demo Reader Progress Bar

/// demo `.fd-reader-progress` 的 SwiftUI 镜像（clean-room）。
///
/// 真源（demo CSS 实际值，`02a-reader-control.css`）：
/// - `.fd-reader-progress`：30px 高容器
/// - `.fd-reader-progress i`：5px 高 bar，inset 13px top
/// - `.fd-reader-progress b`：fill 宽 = `--progress`，背景 `#366179`
/// - `.fd-reader-progress::after`：12×12 thumb，3px border `#366179`，
///   背景 `#fffaf4`，阴影 `0 4px 8px rgba(54,97,121,0.22)`
///
/// 用途：替换 ReaderView 章节进度 `ProgressView(value:)`。
struct DemoReaderProgressBar: View {
    let progress: Double // 0...1
    let tint: SwiftUI.Color

    init(progress: Double, tint: SwiftUI.Color = ReaderDesignTokens.Color.primary) {
        self.progress = max(0, min(1, progress))
        self.tint = tint
    }

    var body: some View {
        GeometryReader { proxy in
            let clamped = max(0, min(1, progress))
            let width = proxy.size.width
            let fillWidth = width * clamped
            ZStack(alignment: .topLeading) {
                // demo 30px 容器
                // 5px bar，inset top 13px
                Capsule()
                    .fill(tint.opacity(0.18))
                    .frame(width: width, height: 5)
                    .offset(y: 13)
                Capsule()
                    .fill(tint)
                    .frame(width: fillWidth, height: 5)
                    .offset(y: 13)
                // thumb 12×12，3px border + #fffaf4 fill + 阴影
                // left = `calc(var(--progress) - 6px)`
                Circle()
                    .fill(ReaderDesignTokens.Color.controlSurfaceSolid)
                    .overlay(
                        Circle().stroke(tint, lineWidth: 3)
                    )
                    .shadow(color: ReaderDesignTokens.Color.Shadow.soft,
                            radius: 4, x: 0, y: 4)
                    .frame(width: 12, height: 12)
                    .offset(x: max(0, fillWidth - 6), y: 9)
            }
        }
        .frame(height: 30)
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

// MARK: - Demo Settings Switch

/// demo `.fd-settings-switch` 的 SwiftUI 镜像（clean-room）。
///
/// 真源（demo CSS 实际值，`05-flow-adaptive.css` line 651-675）：
/// - `.fd-settings-switch`：`--fd-settings-switch-width` × `--fd-settings-switch-height`，
///   padding 2px，pill 圆角，背景 `rgba(140, 130, 118, 0.26)`
/// - `.fd-settings-switch i`：`--fd-settings-switch-thumb` 圆，白色，
///   阴影 `0 2px 4px rgba(31, 27, 23, 0.16)`
/// - `.fd-settings-switch.is-on`：背景 `--fd-primary`
/// - `.fd-settings-switch.is-on i`：`margin-left: --fd-settings-switch-offset`
///
/// Swift 端 token 真值（`ReaderDesignTokens.swift`）：
/// - `settingsSwitchTrackWidth = 38` / `settingsSwitchTrackHeight = 22`
/// - `settingsSwitchThumbSize = 18`
///
/// 用途：替换所有系统 `Toggle`，让 settings/source 行内启用开关严格按 demo 几何绘制。
struct DemoSettingsSwitch: View {
    let isOn: Bool

    init(isOn: Bool) {
        self.isOn = isOn
    }

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            // demo track：rgba(140,130,118,0.26) → is-on: --fd-primary
            Capsule()
                .fill(isOn ? ReaderDesignTokens.Color.primary
                           : ReaderDesignTokens.Color.neutralBorder26)
                .frame(width: ReaderDesignTokens.settingsSwitchTrackWidth,
                       height: ReaderDesignTokens.settingsSwitchTrackHeight)
            // demo thumb：白色 + 阴影
            Circle()
                .fill(.white)
                .shadow(color: ReaderDesignTokens.Color.Shadow.insetDark,
                        radius: 2, x: 0, y: 2)
                .frame(width: ReaderDesignTokens.settingsSwitchThumbSize,
                       height: ReaderDesignTokens.settingsSwitchThumbSize)
                .padding(2)
        }
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : [.isButton])
        .animation(MotionEnvironment().animation(AppMotion.Duration.toggleSwitch), value: isOn)
    }
}

// MARK: - Demo Reader Switch (small 25x15)

/// demo `.fd-reader-switch` 的 SwiftUI 镜像（clean-room，小型 25×15 pill）。
///
/// 真源（demo CSS 实际值，`03a-reader-appearance.css` line 733-759）：
/// - `.fd-reader-switch`：25×15px pill，背景 `#aaa39a`
/// - `.fd-reader-switch::after`：11×11 圆，背景 `#fff`，
///   阴影 `0 1px 3px rgba(55, 44, 32, 0.22)`，top 2px left 2px
/// - `.fd-reader-switch.is-on`：背景 `--fd-primary-dark` (#274f66)
/// - `.fd-reader-switch.is-on::after`：left 12px
///
/// 用途：reader 面板内的小型开关（如自动阅读/翻页等），与 `.fd-settings-switch`
/// 38×22 区分。
struct DemoReaderSwitch: View {
    let isOn: Bool

    init(isOn: Bool) {
        self.isOn = isOn
    }

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            Capsule()
                .fill(isOn ? ReaderDesignTokens.Color.primaryDark
                           : ReaderDesignTokens.Color.readerTrackFill)
                .frame(width: 25, height: 15)
            Circle()
                .fill(.white)
                .shadow(color: ReaderDesignTokens.Color.Shadow.readerInset,
                        radius: 1.5, x: 0, y: 1)
                .frame(width: 11, height: 11)
                .padding(2)
        }
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : [.isButton])
        .animation(MotionEnvironment().animation(AppMotion.Duration.toggleSwitch), value: isOn)
    }
}

// MARK: - Demo TOC Switch Row (2-column segmented)

/// demo `.fd-reader-toc-switch-row` 的 SwiftUI 镜像（clean-room，2 列 button）。
///
/// 真源（demo CSS 实际值，`02a-reader-control.css` line 883-920）：
/// - `.fd-reader-toc-switch-row`：`grid-template-columns: repeat(2, minmax(0, 1fr))`，
///   gap 5px，padding 3px 0
/// - `.fd-reader-toc-switch-row button`：height 24px，`--fd-radius-md` 圆角，
///   背景 `rgba(238, 230, 219, 0.56)`，color `#332c25`，font 10px/600
/// - `.fd-reader-toc-switch-row button.is-active`：背景 `--fd-primary-dark`，
///   color `#fff`
///
/// 用途：替换系统 `.pickerStyle(.segmented)`，用于 TOC/书签 tab 切换。
struct DemoTocSwitchRow: View {
    enum Tab: Int, Equatable {
        case toc = 0
        case bookmarks = 1
    }

    @Binding var selection: Tab
    let motion = MotionEnvironment()

    var body: some View {
        HStack(spacing: 5) {
            tabButton(.toc, title: "目录")
            tabButton(.bookmarks, title: "书签")
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func tabButton(_ tab: Tab, title: String) -> some View {
        let isActive = selection == tab
        Button(action: {
            withAnimation(motion.animation(AppMotion.Duration.toggleSwitch)) {
                selection = tab
            }
        }) {
            Text(title)
                // demo：10px/600
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .semibold))
                .foregroundStyle(isActive ? .white : ReaderDesignTokens.Color.controlInkAlt)
                .frame(maxWidth: .infinity, minHeight: 24)
                .background(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                        .fill(isActive ? ReaderDesignTokens.Color.primaryDark
                                       : ReaderDesignTokens.Color.controlPanelSoft56)
                )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
    }
}

// MARK: - Demo Slider Control (stepper-style +/-)

/// demo 中无原生 range slider 真值（字号/亮度/语速都用 +/- 按钮组调节，
/// 见 `03a-reader-appearance.css` `.fd-reader-fontsize-row` / `.fd-reader-brightness-row`）。
/// 本原语按 demo `.fd-reader-fontsize-row` 的 +/- 几何绘制。
///
/// 真源（demo CSS 实际值，`03a-reader-appearance.css`）：
/// - `.fd-reader-fontsize-row button`：30×30 圆角方块，`--fd-radius-md`，
///   背景 `rgba(255, 250, 244, 0.92)`，边框 `rgba(154, 139, 124, 0.35)`
/// - 中间 value 显示：13px serif
///
/// 用途：替换所有系统 `Slider(value:)`，将连续值调节改为 demo 风格的 +/- 步进。
struct DemoSliderControl: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let valueFormatter: (Double) -> String

    init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double,
        valueFormatter: @escaping (Double) -> String = { String(format: "%.0f", $0) }
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.valueFormatter = valueFormatter
    }

    private func clamp(_ v: Double) -> Double {
        min(max(v, range.lowerBound), range.upperBound)
    }

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .semibold))
                .foregroundStyle(ReaderDesignTokens.Color.primaryDark)
            Spacer()
            // demo `.fd-reader-step-row` 真值（render-runtime.js line 3032-3054）：
            // `<button>-</button>` / `<button>+</button>` 文本按钮，非图标。
            // 30×30 圆角方块，背景 rgba(255,250,244,0.92)，边框 rgba(154,139,124,0.35)。
            Button(action: {
                value = clamp(value - step)
            }) {
                Text("-")
                    .font(.system(size: ReaderDesignTokens.readerOverlaySectionTitleFontSize, weight: .medium))
                    .foregroundStyle(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .fill(ReaderDesignTokens.Color.readerTopBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .stroke(ReaderDesignTokens.Color.readerTopBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(value <= range.lowerBound)
            // 中间 value：13px serif
            Text(valueFormatter(value))
                .font(ReaderTypography.demoSerif(size: 13, weight: .regular))
                .foregroundStyle(ReaderDesignTokens.Color.primaryDark)
                .frame(minWidth: 44)
            Button(action: {
                value = clamp(value + step)
            }) {
                Text("+")
                    .font(.system(size: ReaderDesignTokens.readerOverlaySectionTitleFontSize, weight: .medium))
                    .foregroundStyle(ReaderDesignTokens.Color.primaryDark)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .fill(ReaderDesignTokens.Color.readerTopBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                            .stroke(ReaderDesignTokens.Color.readerTopBorder, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(value >= range.upperBound)
        }
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight)
    }
}
