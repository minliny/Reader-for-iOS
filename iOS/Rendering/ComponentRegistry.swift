import Foundation
import SwiftUI
import ReaderUIContract

// MARK: - ComponentRenderer
//
// component 渲染器类型别名。接收 `ViewStateComponent`（含 type/id/props/children），
// 返回 SwiftUI `AnyView`。注册到 `ComponentRegistry` 后由 `ViewStateRenderer` 调用。

/// component 渲染器：把 `ViewStateComponent` 转为 SwiftUI View。
public typealias ComponentRenderer = (ViewStateComponent) -> AnyView

// MARK: - ComponentRegistry
//
// ComponentType → SwiftUI View 的映射表。按 slice 渐进注册（总计划 §4.E）。
//
// 设计：
// - 静态字典存储 renderer，线程安全（Swift 静态变量初始化是线程安全的）。
// - 未注册的 ComponentType 返回 `EmptyView` + debug print（不崩溃）。
// - 每个 slice 完成后调用 `register(_:_)` 注册该 slice 的 component。
//
// 真源：`generated/swift/ViewState.swift` L5-180 ComponentType（174 case）
// 真源：`contracts/fixtures/view-state.fixtures.json`（130 条 fixture，124 RouteId）

/// ComponentType → SwiftUI View 注册表。
public enum ComponentRegistry {

    /// 静态 renderer 存储字典。
    private static var renderers: [ComponentType: ComponentRenderer] = [:]

    // MARK: - 注册

    /// 注册 ComponentType 对应的渲染器。
    /// 重复注册会覆盖旧值（用于 slice 升级时替换实现）。
    public static func register(_ type: ComponentType, _ renderer: @escaping ComponentRenderer) {
        renderers[type] = renderer
    }

    /// 批量注册（用于 slice 初始化时一次性注册多个 component）。
    public static func register(_ registrations: [(ComponentType, ComponentRenderer)]) {
        for (type, renderer) in registrations {
            renderers[type] = renderer
        }
    }

    // MARK: - 渲染

    /// 渲染单个 component。未注册的 type 返回 `EmptyView` + debug print。
    public static func render(_ component: ViewStateComponent) -> AnyView {
        if let renderer = renderers[component.type] {
            return renderer(component)
        }
        #if DEBUG
        print("[ComponentRegistry] unregistered type: \(component.type.rawValue) (id=\(component.id ?? "nil"))")
        #endif
        return AnyView(EmptyView())
    }

    /// 渲染 children 数组（递归入口）。
    /// nil 或空数组返回 `EmptyView`。
    public static func renderChildren(_ children: [ViewStateComponent]?) -> AnyView {
        guard let children, !children.isEmpty else {
            return AnyView(EmptyView())
        }
        return AnyView(
            ForEach(Array(children.enumerated()), id: \.offset) { _, child in
                render(child)
            }
        )
    }

    // MARK: - 查询

    /// 查询某 ComponentType 是否已注册。
    public static func isRegistered(_ type: ComponentType) -> Bool {
        renderers[type] != nil
    }

    /// 已注册的 ComponentType 数量（用于测试断言 slice 注册完整性）。
    public static var registeredCount: Int { renderers.count }

    /// 已注册的 ComponentType 集合（用于测试断言）。
    public static var registeredTypes: Set<ComponentType> { Set(renderers.keys) }

    // MARK: - 测试 / 重置

    /// 清空所有注册（测试用）。
    public static func reset() {
        renderers.removeAll()
    }
}
