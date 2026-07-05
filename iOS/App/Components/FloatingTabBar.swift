import SwiftUI

/// 原生 SwiftUI 浮动主 Tab 栏 —— 对齐 demo `.fd-main-nav` 规格的「浮动 pill」样式。
///
/// 真源：`Reader UI/frontend-demo/styles/01-shell-layout.css` `.fd-main-nav` / `.fd-main-nav-item`
///
/// 规格对齐（数值取自 `ReaderDesignTokens`，clean-room，不复制 CSS）：
/// - 栏高 68pt / 圆角 24 / padding 7×8 / 边框 1px `--fd-border` #c1c7cd /
///   背景 rgba(255,252,248,.92) / 阴影 `--fd-soft-shadow` 0 8px 26px rgba(89,70,50,.1)
/// - 浮动于底部安全区上方（`safeAreaInset(.bottom)`），左右距安全区 -2pt
/// - 4 列等分；item 内部 30pt icon / 18pt label / gap 3 / 字号 11pt·800 / nowrap
/// - active: 背景 `primaryDark` + 白字；inactive: `--fd-muted` #756f69
///
/// 契约对齐：
/// - `tab.item.press` —— 按下时调用 `onSelect`（reducer 内部处理 `tabPress` 时长）
/// - `tab.item.select` —— 选中态视觉切换（`tabSelect` 时长驱动）
/// - `tab.item.switch` / `app.tab.switch` —— 由 `AppNavigationState.switchTab` 处理
///
/// 与系统 `TabView` 的区别：系统栏是贴底实心 49pt，与 demo 的浮动 68pt pill 不符。
/// 本组件只承载 demo `mainNav` slot；页面切换由 AppShell 的自定义 contentRegion 负责。
enum FloatingTabBarAxis: Equatable {
    case horizontal
    case vertical
}

struct FloatingTabBar: View {
    let tabs: [AppTab]
    @Binding var selection: AppTab
    let onSelect: (AppTab) -> Void
    var axis: FloatingTabBarAxis = .horizontal

    var body: some View {
        tabContainer
        .padding(.horizontal, ReaderDesignTokens.mainNavHorizontalPadding)
        .padding(.vertical, ReaderDesignTokens.mainNavVerticalPadding)
        .frame(minHeight: ReaderDesignTokens.mainNavHeight)
        .background(
            RoundedRectangle(cornerRadius: ReaderDesignTokens.mainNavCornerRadius)
                .fill(ReaderDesignTokens.Color.mainNavBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.mainNavCornerRadius)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                )
                .shadow(color: ReaderDesignTokens.Color.Shadow.soft,
                        radius: 26, x: 0, y: 8)
        )
        .padding(.horizontal, ReaderDesignTokens.mainNavSideInsetAdjustment)
        .accessibilityIdentifier("fd-main-nav")
    }

    @ViewBuilder
    private var tabContainer: some View {
        switch axis {
        case .horizontal:
            HStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    tabButton(for: tab)
                }
            }
        case .vertical:
            VStack(spacing: 0) {
                ForEach(tabs, id: \.self) { tab in
                    tabButton(for: tab)
                        .frame(height: ReaderDesignTokens.tabletNavItemHeight)
                }
            }
            .frame(width: ReaderDesignTokens.tabletNavWidth - ReaderDesignTokens.mainNavHorizontalPadding * 2)
        }
    }

    private func tabButton(for tab: AppTab) -> some View {
        let isActive = tab == selection
        return Button {
            // `tab.item.press` —— 按下立即触发；reducer 处理 `tabPress`/`tabSelect`/`tabSwitch`。
            onSelect(tab)
        } label: {
            VStack(spacing: ReaderDesignTokens.tabItemGap) {
                ReaderIcon(tab.assetIcon, size: 24)
                    .frame(width: ReaderDesignTokens.tabItemIconShellSize,
                           height: ReaderDesignTokens.tabItemIconShellSize)
                Text(tab.title)
                    .font(.system(size: ReaderDesignTokens.tabItemFontSize, weight: .black))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ReaderDesignTokens.tabItemGap)
            .foregroundColor(isActive ? .white : ReaderDesignTokens.Color.tabItemInactive)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.mainNavCornerRadius)
                    .fill(isActive ? ReaderDesignTokens.Color.primaryDark : .clear)
            )
        }
        .buttonStyle(TabPressButtonStyle())
        .accessibilityLabel(tab.title)
        .accessibilityIdentifier("fd-main-nav-item-\(tab.rawValue)")
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : [.isButton])
    }
}

/// `tab.item.press` 视觉反馈 —— 按下时轻缩放 0.98（`AppMotion.Scale.pressMin`），
/// 用 `AppMotion.Duration.tabPress` 时长。reduced-motion 由 `MotionEnvironment` 接管。
struct TabPressButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? AppMotion.Scale.pressMin : 1)
            .animation(
                ReaderMotionAdapter.animation(
                    for: MotionRequest(operation: .update, sourceRole: "tabItem", containerRole: .mainTabShell),
                    motion: MotionEnvironment()
                ),
                value: configuration.isPressed
            )
    }
}
