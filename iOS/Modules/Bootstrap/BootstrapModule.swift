import Foundation

public protocol BootstrapModule {
    func bootstrap() async throws
}

public struct DefaultBootstrapModule: BootstrapModule {
    public init() {}

    public func bootstrap() async throws {}
}
