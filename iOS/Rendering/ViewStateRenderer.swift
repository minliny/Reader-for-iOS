import SwiftUI
import ReaderUIContract

// MARK: - ViewStateRenderer
//
// 契约 `ViewState`（含 `components: [ViewStateComponent]`）→ SwiftUI View tree 渲染器。
//
// 真源：
// - `generated/swift/ViewState.swift` L189-194 ViewState（routeId/pageState/context/components）
// - `generated/swift/ViewState.swift` L182-187 ViewStateComponent（type/id/props/children）
// - `contracts/fixtures/view-state.fixtures.json` 130 条 fixture 定义每 RouteId 的标准组件组合
//
// 设计（总计划 §4.E 阶段 1 基础设施）：
// - 遍历 `components` 数组，按 `type: ComponentType` 分发到 `ComponentRegistry`。
// - 递归处理 `children: [ViewStateComponent]?`（组件可嵌套，如 BookshelfShelfSection 含 BookGrid 含 BookCard[]）。
// - 未注册的 ComponentType 返回 `EmptyView` + debug print（不崩溃）。
// - 不直接处理 shell 布局（由 `ShellContainers` 负责），只负责 component 树渲染。

/// 契约 ViewState → SwiftUI View tree 渲染器。
///
/// 用法：
/// ```swift
/// ViewStateRenderer(viewState: navigationState.contractViewState)
/// ```
public struct ViewStateRenderer: View {
    public let viewState: ReaderUIContract.ViewState

    public init(viewState: ReaderUIContract.ViewState) {
        self.viewState = viewState
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(viewState.components.enumerated()), id: \.offset) { _, component in
                ComponentRegistry.render(component)
            }
        }
    }
}

// MARK: - 单 component 渲染（用于 ShellContainers 内嵌）

/// 渲染单个 ViewStateComponent（用于 shell 容器内嵌指定 component）。
public struct ComponentView: View {
    public let component: ViewStateComponent

    public init(_ component: ViewStateComponent) {
        self.component = component
    }

    public var body: some View {
        ComponentRegistry.render(component)
    }
}

// MARK: - children 渲染（用于容器 component 递归渲染子组件）

/// 渲染 children 数组（用于 BookshelfShelfSection / BookGrid 等容器 component）。
public struct ChildrenView: View {
    public let children: [ViewStateComponent]?

    public init(_ children: [ViewStateComponent]?) {
        self.children = children
    }

    public var body: some View {
        ComponentRegistry.renderChildren(children)
    }
}

// MARK: - 按 ComponentType 过滤渲染

extension ViewStateRenderer {
    /// 只渲染指定 type 的 component（用于 shell 容器提取特定 component，如 BottomNav）。
    public func filtered(to types: Set<ComponentType>) -> some View {
        let filtered = viewState.components.filter { types.contains($0.type) }
        return VStack(spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.offset) { _, component in
                ComponentRegistry.render(component)
            }
        }
    }

    /// 渲染除指定 type 外的 component（用于 shell 容器排除 nav/bar 后渲染内容区）。
    public func excluding(_ types: Set<ComponentType>) -> some View {
        let filtered = viewState.components.filter { !types.contains($0.type) }
        return VStack(spacing: 0) {
            ForEach(Array(filtered.enumerated()), id: \.offset) { _, component in
                ComponentRegistry.render(component)
            }
        }
    }
}


// MARK: - ContractHostView（contract-host 渲染入口）

/// 按 RouteId 渲染 contract component tree，走 ShellContainer 的 shell 语义布局。
///
/// B1-iOS P0 核心接线：AppShellView 对 book-detail / source-switch 等路由
/// 走 contract renderer（ViewStateComponentFactory → ShellContainer → ComponentRegistry），
/// 不再直接实例化 legacy feature view。flag 控制（见 AppShellView.useContractHost）。
///
/// P1 修复（shell 语义 + route 参数）：
/// - 之前直接 VStack 渲染 components，绕过了 ShellContainer，导致
///   LibraryShell/FlowShell 的 BackTopBar 区、slot 过滤等 shell 规则未生效。
/// - 之前只接 routeId，丢实际 route 参数（bookURL/title/author），导致
///   bookDetailComponents 渲染硬编码 fixture（"长夜余火/爱潜水的乌贼"）。
/// - 现在构造 contract ViewState 并走 ShellContainer，shell 按 routeId 选择
///   对应容器（LibraryShell/FlowShell/SettingsShell/...），BackTopBar + 内容区
///   布局由 shell 容器负责。
/// - route 参数通过 ViewState.context + 带参工厂方法注入组件树。
public struct ContractHostView: View {
    public let viewState: ReaderUIContract.ViewState
    /// P0 修复：contract host 的返回动作（pop 路由）。注入 environment 供 BackTopBarView 读取。
    private let onExit: (() -> Void)?

    public init(viewState: ReaderUIContract.ViewState, onExit: (() -> Void)? = nil) {
        self.viewState = viewState
        self.onExit = onExit
    }

    /// 无 route 参数的便捷 init：只传 routeId（用于无参数路由或 fallback）。
    public init(routeId: RouteId, onExit: (() -> Void)? = nil) {
        self.viewState = ViewStateFactory.make(routeId: routeId)
        self.onExit = onExit
    }

    /// book-detail 便捷 init：注入真实书籍参数（bookURL/title/author）。
    /// `author` 为 `String?`，对齐 `Route.bookDetail` 的可选 author。
    public init(bookDetail bookURL: String, title: String, author: String?, onExit: (() -> Void)? = nil) {
        var context: [String: AnyCodable] = [
            "bookURL": AnyCodable(bookURL),
            "title": AnyCodable(title),
        ]
        if let author = author {
            context["author"] = AnyCodable(author)
        }
        self.viewState = ViewStateFactory.make(
            routeId: .bookDetail,
            context: context
        )
        self.onExit = onExit
    }

    /// source-switch 便捷 init：注入真实 bookURL。
    public init(sourceSwitch bookURL: String, onExit: (() -> Void)? = nil) {
        self.viewState = ViewStateFactory.make(
            routeId: .sourceSwitch,
            context: [
                "bookURL": AnyCodable(bookURL),
            ]
        )
        self.onExit = onExit
    }

    public var body: some View {
        ShellContainer(viewState: viewState)
            .environment(\.backTopBarAction, onExit)
    }
}
