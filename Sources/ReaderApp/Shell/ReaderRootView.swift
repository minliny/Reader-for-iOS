import ReaderDesign
import SwiftUI

struct ReaderRootView: View {
    let root: URL
    @State private var model: ShelfModel
    @State private var tab: ReaderPrimaryTab = .bookshelf
    @AppStorage("reader.appearance") private var appearance = ReaderAppearance.system
    @Environment(\.colorScheme) private var systemScheme

    init(root: URL, model: ShelfModel = ShelfModel()) {
        self.root = root
        _model = State(initialValue: model)
    }

    var body: some View {
        GeometryReader { geometry in
            let wide = geometry.size.width >= CGFloat(ReaderDesignMetrics.wideBreakpoint)
            Group {
                if wide {
                    HStack(spacing: 0) {
                        ReaderNavigationRail(selection: $tab)
                        tabContent
                    }
                } else {
                    tabContent
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            ReaderBottomTabBar(selection: $tab)
                        }
                }
            }
            .background(ReaderTheme(night: appearance.night(system: systemScheme)).background)
        }
        .environment(\.readerTheme, ReaderTheme(night: appearance.night(system: systemScheme)))
        .preferredColorScheme(appearance.scheme)
        .readerDesign()
        .task { await model.start(root: root) }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch tab {
        case .bookshelf:
            BookshelfScreen(model: model, root: root)
        case .settings:
            NavigationStack { SettingsScreen(runtime: model.library?.runtime) }
        }
    }
}

private enum ReaderPrimaryTab: String, CaseIterable {
    case bookshelf, settings

    var title: String { self == .bookshelf ? "书架" : "设置" }
    var icon: ReaderIconMapping { self == .bookshelf ? ReaderIconRegistry.shelf : ReaderIconRegistry.settings }
}

private struct ReaderBottomTabBar: View {
    @Binding var selection: ReaderPrimaryTab
    @Environment(\.readerTheme) private var theme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(ReaderPrimaryTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    Label { Text(tab.title).readerTypography(ReaderDesignMetrics.mainTabLabel) } icon: {
                        ReaderIcon(tab.icon, squareSize: 24)
                    }
                    .foregroundStyle(selection == tab ? theme.onAccent : theme.secondaryText)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .padding(.horizontal, 10)
                    .background(selection == tab ? theme.accentFill : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("main-tab-\(tab.rawValue)")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .frame(maxWidth: 360)
        .background(theme.elevated.opacity(0.96), in: Capsule())
        .overlay(Capsule().stroke(theme.outline, lineWidth: 1))
        .shadow(color: theme.shadow.opacity(0.18), radius: 12, y: 3)
        .padding(.horizontal, 32)
        .padding(.bottom, 15)
        .frame(maxWidth: .infinity)
    }
}

private struct ReaderNavigationRail: View {
    @Binding var selection: ReaderPrimaryTab
    @Environment(\.readerTheme) private var theme

    var body: some View {
        VStack(spacing: 10) {
            ForEach(ReaderPrimaryTab.allCases, id: \.self) { tab in
                Button { selection = tab } label: {
                    VStack(spacing: 3) {
                        ReaderIcon(tab.icon, squareSize: 24)
                        Text(tab.title).readerTypography(ReaderDesignMetrics.mainTabLabel)
                    }
                    .foregroundStyle(selection == tab ? theme.onAccent : theme.secondaryText)
                    .frame(width: 66, height: 66)
                    .background(selection == tab ? theme.accentFill : .clear, in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("main-rail-\(tab.rawValue)")
            }
            Spacer()
        }
        .padding(.top, 24)
        .padding(.horizontal, 10)
        .frame(width: 86)
        .background(theme.elevated.opacity(0.96))
        .overlay(alignment: .trailing) { Rectangle().fill(theme.outline).frame(width: 1) }
    }
}
