import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

@main
public struct ReaderApp: App {
    @StateObject private var coordinator: ReadingFlowCoordinator
    private let environment: ReaderShellEnvironment

    public init() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        _coordinator = StateObject(wrappedValue: coordinator)
        environment = ReaderShellEnvironment()
    }

    public var body: some Scene {
        WindowGroup {
            ReaderFlowFeatureView(
                coordinator: coordinator,
                environment: environment
            )
        }
    }
}
