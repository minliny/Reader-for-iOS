import SwiftUI
import ReaderCoreModels

@main
public struct ReaderApp: App {
    @StateObject private var coordinator = ReadingFlowCoordinator.makeDefault()

    public init() {}

    public var body: some Scene {
        WindowGroup {
            BookSourceImportView(coordinator: coordinator)
        }
    }
}
