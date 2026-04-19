import SwiftUI
import ReaderShellValidation

@main
public struct ReaderApp: App {
    @StateObject private var coordinator: ReadingFlowCoordinator
    @StateObject private var navigationState: AppNavigationState
    private let environment: ReaderShellEnvironment

    public init() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        _coordinator = StateObject(wrappedValue: coordinator)
        _navigationState = StateObject(wrappedValue: AppNavigationState())
        environment = ReaderShellEnvironment()
    }

    public var body: some Scene {
        WindowGroup {
            RootShellView(
                coordinator: coordinator,
                navigationState: navigationState,
                environment: environment
            )
        }
    }
}

struct RootShellView: View {
    @ObservedObject var coordinator: ReadingFlowCoordinator
    @ObservedObject var navigationState: AppNavigationState
    let environment: ReaderShellEnvironment

    var body: some View {
        NavigationStack(path: $navigationState.navigationPath) {
            ReaderFlowFeatureView(
                coordinator: coordinator,
                navigationState: navigationState,
                environment: environment
            )
            .navigationDestination(for: Route.self) { route in
                destinationView(for: route)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: Route) -> some View {
        switch route {
        case .home:
            ReaderFlowFeatureView(
                coordinator: coordinator,
                navigationState: navigationState,
                environment: environment
            )
        case .bookSourceImport:
            BookSourceImportView(coordinator: coordinator)
        case .search:
            SearchView(coordinator: coordinator)
        case .toc(let bookTitle, let bookAuthor):
            if let book = coordinator.selectedBook {
                TOCView(coordinator: coordinator, book: book)
            } else {
                Text("书籍信息不可用")
            }
        case .content(let chapterTitle):
            if let chapter = coordinator.selectedChapter {
                ContentView(coordinator: coordinator, chapter: chapter)
            } else {
                Text("章节信息不可用")
            }
        }
    }
}
