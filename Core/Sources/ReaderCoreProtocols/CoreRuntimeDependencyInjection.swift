import Foundation

public enum CoreRuntimeDependencyInjection {
    public static func makeDependencies(httpAdapterName: String = "default") -> CoreAdapterDependencies {
        CoreAdapterDependencies(http: requireHTTPAdapter(named: httpAdapterName))
    }

    public static func requireHTTPAdapter(named name: String = "default") -> any HTTPAdapterProtocol {
        fatalError("HTTPAdapterProtocol must be injected outside Core for profile '\(name)'.")
    }
}
