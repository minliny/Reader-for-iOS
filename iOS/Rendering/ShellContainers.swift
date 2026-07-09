import SwiftUI
import ReaderUIContract

// MARK: - ShellContainers
//
// 5 个 RouteShell 容器，每个接收 ViewState.components 树并按 shell 语义布局。
//
// 真源：
// - `generated/swift/MotionPolicy.swift` L382-589 RouteShellLookup.shellByRouteId
// - `generated/swift/Route.swift` L208-214 RouteShell（5 case）
// - `frontend-demo-optimized/render-runtime.js` shell 选择逻辑
//
// 与现有 `DemoShells.swift` 的差异：
// - DemoShells 用 `@ViewBuilder` slot 接收本地 View（不消费 contract ViewState）
// - ShellContainers 接收 contract `ViewState`，按 shell 语义从 components 树布局
// - 新旧并存：ShellContainers 是 ViewState 驱动入口，DemoShells 保留为 fallback

/// 按 ViewState.routeId 选择对应 Shell 容器。
public struct ShellContainer: View {
    public let viewState: ReaderUIContract.ViewState

    public init(viewState: ReaderUIContract.ViewState) {
        self.viewState = viewState
    }

    public var body: some View {
        let shell = RouteShellLookup.shell(for: viewState.routeId) ?? .mainTabShell
        switch shell {
        case .mainTabShell:
            MainTabShellContainer(viewState: viewState)
        case .libraryShell:
            LibraryShellContainer(viewState: viewState)
        case .readerShell:
            ReaderShellContainer(viewState: viewState)
        case .settingsShell:
            SettingsShellContainer(viewState: viewState)
        case .flowShell:
            FlowShellContainer(viewState: viewState)
        }
    }
}

// MARK: - MainTabShell（主 Tab 壳：底部 BottomNav + 顶部 AppTopBar + 内容区）

/// MainTabShell 容器。渲染非 nav/bar 的内容区 + BottomNav。
/// 真源：`frontend-demo-optimized/styles/01-shell-layout.css` `.fd-main-nav` / `.fd-top-bar`
public struct MainTabShellContainer: View {
    public let viewState: ReaderUIContract.ViewState

    public init(viewState: ReaderUIContract.ViewState) {
        self.viewState = viewState
    }

    private let navTypes: Set<ComponentType> = [.bottomNav]
    private let barTypes: Set<ComponentType> = [.appTopBar]

    public var body: some View {
        VStack(spacing: 0) {
            // 顶部 AppTopBar（如果有）
            ViewStateRenderer(viewState: viewState).filtered(to: barTypes)

            // 内容区（排除 nav 和 bar）
            ScrollView {
                ViewStateRenderer(viewState: viewState).excluding(navTypes.union(barTypes))
                    .padding(.bottom, ReaderDesignTokens.mainTabContentBottomPadding)
            }

            // 底部 BottomNav
            ViewStateRenderer(viewState: viewState).filtered(to: navTypes)
        }
    }
}

// MARK: - LibraryShell（二级页壳：返回栏 + 内容区 + overlay host）

/// LibraryShell 容器。渲染 BackTopBar + 内容区。
/// 真源：`frontend-demo-optimized/styles/01-shell-layout.css` `.fd-back-bar`
public struct LibraryShellContainer: View {
    public let viewState: ReaderUIContract.ViewState

    public init(viewState: ReaderUIContract.ViewState) {
        self.viewState = viewState
    }

    private let barTypes: Set<ComponentType> = [.backTopBar, .appTopBar]

    public var body: some View {
        VStack(spacing: 0) {
            ViewStateRenderer(viewState: viewState).filtered(to: barTypes)
            ScrollView {
                ViewStateRenderer(viewState: viewState).excluding(barTypes)
            }
        }
    }
}

// MARK: - ReaderShell（阅读器壳：阅读面 + 控制层 overlay + 模块导航）

/// ReaderShell 容器。渲染 ReaderBase + ReadingTextFlow + 控制层 overlay。
/// 真源：`frontend-demo-optimized/styles/03a-reader-appearance.css` / `03b-reader-settings.css`
public struct ReaderShellContainer: View {
    public let viewState: ReaderUIContract.ViewState

    public init(viewState: ReaderUIContract.ViewState) {
        self.viewState = viewState
    }

    private let readerBaseTypes: Set<ComponentType> = [.readerBase, .readingBackgroundLayer, .readingTextFlow, .readingInfoLayer, .tapZones]
    private let controlLayerTypes: Set<ComponentType> = [
        .readerTopArea, .readerControlSheet, .readerBottomBar,
        .readerDirectoryPanel, .readerAppearancePanel, .readerTtsPanel,
        .readerSettingsPanel, .readerSearchPanel, .readerReplacePanel,
        .readerAutoScrollPanel, .floatingBrightness, .floatingQuickActions, .floatingPageControl
    ]

    public var body: some View {
        ZStack {
            // 阅读基础层（z-index = content）
            ViewStateRenderer(viewState: viewState).filtered(to: readerBaseTypes)
                .zIndex(ReaderZIndex.content.rawValue)

            // 控制层 overlay（z-index = overlay）
            ViewStateRenderer(viewState: viewState).filtered(to: controlLayerTypes)
                .zIndex(ReaderZIndex.overlay.rawValue)
        }
    }
}

// MARK: - SettingsShell（设置壳：列表布局 + section 分组）

/// SettingsShell 容器。渲染 SettingsSection + SettingsListItem 列表。
public struct SettingsShellContainer: View {
    public let viewState: ReaderUIContract.ViewState

    public init(viewState: ReaderUIContract.ViewState) {
        self.viewState = viewState
    }

    private let barTypes: Set<ComponentType> = [.backTopBar, .appTopBar]

    public var body: some View {
        VStack(spacing: 0) {
            ViewStateRenderer(viewState: viewState).filtered(to: barTypes)
            Form {
                ViewStateRenderer(viewState: viewState).excluding(barTypes)
            }
        }
    }
}

// MARK: - FlowShell（流程壳：步骤区 + 对比区 + 结果区）

/// FlowShell 容器。渲染换源流程等步骤式页面。
/// 真源：`frontend-demo-optimized/styles/01-shell-layout.css` `.fd-flow-shell`
public struct FlowShellContainer: View {
    public let viewState: ReaderUIContract.ViewState

    public init(viewState: ReaderUIContract.ViewState) {
        self.viewState = viewState
    }

    private let barTypes: Set<ComponentType> = [.backTopBar, .appTopBar]

    public var body: some View {
        VStack(spacing: 0) {
            ViewStateRenderer(viewState: viewState).filtered(to: barTypes)
            ScrollView {
                ViewStateRenderer(viewState: viewState).excluding(barTypes)
            }
        }
    }
}
