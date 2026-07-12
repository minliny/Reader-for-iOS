import SwiftUI
import ReaderUIContract

// MARK: - ContractNavigationStack
//
// 把 NavigationStack + NavigationPath 接到 contract route push/pop/replace 语义。
//
// 真源：
// - `frontend-demo-optimized/render-runtime.js` goTo(L8869) / goTab(L8932) / replaceTopRoute(L8968) / goBack(L9038)
// - `frontend-demo-optimized/route-contract.js` routes 注册表
// - `generated/swift/MotionPolicy.swift` L382-589 RouteShellLookup.shellByRouteId
//
// 4 种导航语义（对照 render-runtime.js）：
// - push：routeStack.append(routeId)，motion = app.route.push.forward，打断 = redirect
// - pop：routeStack.removeLast()，motion = app.route.pop.backward，打断 = cancel
// - replace：routeStack[last] = routeId，motion = app.route.replace，打断 = completeThenReplace
// - tab switch：routeStack = [tabRootRouteId]（清空栈），打断 = redirect
//
// 深链返回栈补默认来源：
// - ReaderShell 空栈 → bookshelf
// - SettingsShell 空栈 → settings

/// 契约导航栈。封装 route push/pop/replace/tab-switch 语义。
@MainActor
public final class ContractNavigationStack: ObservableObject {

    /// 当前路由栈（栈底是根路由，栈顶是当前路由）。
    @Published public private(set) var routeStack: [String] = ["bookshelf"]

    /// 当前栈顶路由（若栈空返回 "bookshelf"）。
    public var currentRouteId: String {
        routeStack.last ?? "bookshelf"
    }

    /// 栈深度。
    public var depth: Int { routeStack.count }

    /// 是否可以 pop（栈深 > 1）。
    public var canGoBack: Bool { routeStack.count > 1 }

    public init(initialRouteId: String = "bookshelf") {
        self.routeStack = [initialRouteId]
    }

    // MARK: - 导航操作

    /// push 语义：入栈新路由。
    /// 对照 `render-runtime.js` goTo(route, shouldPush=true) L8884 `routeStack.push(route)`。
    public func push(_ routeId: String) {
        routeStack.append(routeId)
    }

    /// pop 语义：出栈返回前驱。
    /// 对照 `render-runtime.js` goBack() L9044 `routeStack.pop()`。
    /// 空栈或单元素栈时按 RouteShell 补默认前驱。
    @discardableResult
    public func pop() -> String? {
        guard routeStack.count > 1 else {
            // 空栈补默认前驱
            return defaultPredecessor(for: currentRouteId)
        }
        routeStack.removeLast()
        return routeStack.last
    }

    /// replace 语义：替换栈顶。
    /// 对照 `render-runtime.js` replaceTopRoute(route) L8982 `routeStack[len-1] = route`。
    public func replaceTop(_ routeId: String) {
        if routeStack.isEmpty {
            routeStack = [routeId]
        } else {
            routeStack[routeStack.count - 1] = routeId
        }
    }

    /// tab switch 语义：清空栈，设新根。
    /// 对照 `render-runtime.js` goTab(route) L8963 `routeStack.splice(0, len, route)`。
    public func switchTab(rootRouteId: String) {
        routeStack = [rootRouteId]
    }

    /// pop to root：清空到根路由。
    public func popToRoot() {
        guard let root = routeStack.first else { return }
        routeStack = [root]
    }

    /// 重置到指定路由（测试用）。
    public func reset(to routeId: String = "bookshelf") {
        routeStack = [routeId]
    }

    // MARK: - 深链返回栈补默认来源

    /// 按 RouteShell 补默认前驱（空栈时返回）。
    /// 真源：`generated/swift/MotionPolicy.swift` RouteShellLookup.shellByRouteId
    private func defaultPredecessor(for routeId: String) -> String? {
        let shell = ReaderNativeRouteShellLookup.shell(for: routeId) ?? .mainTabShell
        switch shell {
        case .readerShell:
            return "bookshelf"
        case .settingsShell:
            return "settings"
        case .libraryShell:
            return "bookshelf"
        case .flowShell:
            return "bookshelf"
        case .mainTabShell:
            return nil  // 主 Tab 不补前驱
        }
    }

    // MARK: - 查询

    /// 返回栈的 shell 分布（用于 motion resolver 构造 MotionRequest）。
    public var currentShell: RouteShell {
        ReaderNativeRouteShellLookup.shell(for: currentRouteId) ?? .mainTabShell
    }

    /// 前驱路由的 shell（用于 motion resolver 判断 fromShell → toShell）。
    public var predecessorShell: RouteShell? {
        guard routeStack.count >= 2 else { return nil }
        let predecessor = routeStack[routeStack.count - 2]
        return ReaderNativeRouteShellLookup.shell(for: predecessor)
    }
}
