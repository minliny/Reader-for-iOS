import SwiftUI
import ReaderShellValidation

#if DEBUG && canImport(WebKit)
import WebKit
#endif

@main
public struct ReaderApp: App {
    @StateObject private var coordinator: ReadingFlowCoordinator
    @StateObject private var navigationState: AppNavigationState
    private let environment: ReaderShellEnvironment

    #if DEBUG && canImport(WebKit)
    @State private var autorunConfiguration: WebViewRuntimeAutorunConfiguration?
    #endif

    public init() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        _coordinator = StateObject(wrappedValue: coordinator)
        _navigationState = StateObject(wrappedValue: AppNavigationState())
        environment = ReaderShellEnvironment()

        #if DEBUG && canImport(WebKit)
        // 解析 autorun 配置
        let config = WebViewRuntimeAutorunConfiguration.parse(CommandLine.arguments)
        print("[WebViewHarness] autorun args parsed enabled=\(config.isEnabled) valid=\(config.isValid)")
        print("[WebViewHarness] bundleId=com.reader.ios")
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        print("[WebViewHarness] documentsDirectory=\(docsDir?.path ?? "nil")")
        if config.isEnabled && config.isValid {
            _autorunConfiguration = State(wrappedValue: config)
        }
        #endif
    }

    public var body: some Scene {
        WindowGroup {
            #if DEBUG && canImport(WebKit)
            if let config = autorunConfiguration, config.isEnabled && config.isValid {
                WebViewRuntimeAutorunView(configuration: config)
            } else {
                RootShellView(
                    coordinator: coordinator,
                    navigationState: navigationState,
                    environment: environment
                )
            }
            #else
            RootShellView(
                coordinator: coordinator,
                navigationState: navigationState,
                environment: environment
            )
            #endif
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        navigationState.push(.webdavSettings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: WebViewRuntimeHarnessView()) {
                        Text("WebView Harness")
                            .font(.caption)
                    }
                }
                #endif
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
            BookSourceImportView()
        case .search:
            SearchView()
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
        case .webdavSettings:
            WebDAVSettingsView()
        }
    }
}