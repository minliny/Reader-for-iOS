import SwiftUI
import ReaderShellValidation
import ReaderCoreModels

#if DEBUG && canImport(ReaderCoreNativeAdapter)
import ReaderCoreNativeAdapter
#endif

#if DEBUG && canImport(WebKit)
import WebKit
#endif

@main
public struct ReaderApp: App {
    @StateObject private var coordinator: ReadingFlowCoordinator
    @StateObject private var navigationState: AppNavigationState
    private let environment: ReaderShellEnvironment
    @AppStorage("useRealServices") private var useRealServices = false

    #if DEBUG && canImport(WebKit)
    @State private var autorunConfiguration: WebViewRuntimeAutorunConfiguration?
    #endif
    #if DEBUG && canImport(ReaderCoreNativeAdapter)
    @State private var nativeCoreEvidenceAutorunConfiguration: NativeCoreEvidenceAutorunConfiguration?
    #endif

    public init() {
        let useReal = UserDefaults.standard.bool(forKey: "useRealServices")
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator(useReal: useReal)
        _coordinator = StateObject(wrappedValue: coordinator)
        _navigationState = StateObject(wrappedValue: AppNavigationState())

        var env = ReaderShellEnvironment()
        #if canImport(WebKit) && canImport(UIKit)
        env.webViewAdapter = ShellAssembly.makeProductionWebViewAdapter()
        #endif
        environment = env

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

        #if DEBUG && canImport(ReaderCoreNativeAdapter)
        let nativeConfig = NativeCoreEvidenceAutorunConfiguration.parse(CommandLine.arguments)
        print("[NativeCoreEvidence] autorun args parsed enabled=\(nativeConfig.isEnabled) valid=\(nativeConfig.isValid)")
        print("[NativeCoreEvidence] bundleId=com.reader.ios")
        if nativeConfig.isEnabled && nativeConfig.isValid {
            _nativeCoreEvidenceAutorunConfiguration = State(wrappedValue: nativeConfig)
        }
        #endif
    }

    public var body: some Scene {
        WindowGroup {
            #if DEBUG && canImport(ReaderCoreNativeAdapter)
            if let config = nativeCoreEvidenceAutorunConfiguration, config.isEnabled && config.isValid {
                NativeCoreEvidenceAutorunView(configuration: config)
            } else {
                defaultRootContent
            }
            #else
            defaultRootContent
            #endif
        }
    }

    @ViewBuilder
    private var defaultRootContent: some View {
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

struct RootShellView: View {
    @ObservedObject var coordinator: ReadingFlowCoordinator
    @ObservedObject var navigationState: AppNavigationState
    let environment: ReaderShellEnvironment
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Tab 0: 书架
            NavigationStack {
                BookshelfView()
                    .navigationTitle("书架")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink(destination: SearchView()) {
                                Image(systemName: "magnifyingglass")
                            }
                        }
                    }
            }
            .tabItem {
                Label("书架", systemImage: "books.vertical")
            }
            .tag(0)

            // Tab 1: 发现
            DiscoverHomeShellView()
                .tabItem {
                    Label("发现", systemImage: "safari")
                }
                .tag(1)

            // Tab 2: 书源
            NavigationStack {
                BookSourceListView(coordinator: coordinator)
                    .navigationTitle("书源")
            }
            .tabItem {
                Label("书源", systemImage: "doc.text.magnifyingglass")
            }
            .tag(2)

            // Tab 3: 我的
            MineTabView()
                .tabItem {
                    Label("我的", systemImage: "person.circle")
                }
                .tag(3)
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
        case .rssList:
            RSSFeedView()
        case .bookshelf:
            BookshelfView()
        case .prototypeGallery:
            PrototypeGalleryView()
        case .bookSources:
            BookSourceListView(coordinator: coordinator)
        case .bookDetail(let bookURL, let title, let author):
            BookDetailView(result: SearchResultItem(
                title: title,
                detailURL: bookURL,
                author: author
            ))
        default:
            Text("\(route.title) — 待实现")
        }
    }
}
