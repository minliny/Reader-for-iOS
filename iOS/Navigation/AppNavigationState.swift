import Foundation
import SwiftUI

@MainActor
public final class AppNavigationState: ObservableObject {
    @Published public var currentRoute: Route = .home
    @Published public var navigationPath: [Route] = []

    public init() {}

    public func navigate(to route: Route) {
        currentRoute = route
        if !navigationPath.contains(route) {
            navigationPath.append(route)
        }
    }

    public func push(_ route: Route) {
        navigationPath.append(route)
    }

    public func goBack() {
        guard !navigationPath.isEmpty else { return }
        navigationPath.removeLast()
        if let last = navigationPath.last {
            currentRoute = last
        } else {
            currentRoute = .home
        }
    }

    public func popToRoot() {
        navigationPath.removeAll()
        currentRoute = .home
    }
}
