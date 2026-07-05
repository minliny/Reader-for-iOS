import SwiftUI
import ReaderShellValidation
import ReaderCoreModels

#if DEBUG && canImport(ReaderCoreNativeAdapter)
import ReaderCoreNativeAdapter
#endif

#if DEBUG && canImport(WebKit) && canImport(UIKit)
import WebKit
#endif

#if !SWIFT_PACKAGE
@main
#endif
public struct ReaderApp: App {
    @StateObject private var coordinator: ReadingFlowCoordinator
    @StateObject private var navigationState: AppNavigationState
    // P3-B: 全局会话存储，注入到根视图供所有子视图通过 @EnvironmentObject 访问
    @StateObject private var sessionStore: ReaderSessionStore = ReaderSessionStore()
    private let environment: ReaderShellEnvironment

    #if DEBUG && canImport(WebKit) && canImport(UIKit)
    @State private var autorunConfiguration: WebViewRuntimeAutorunConfiguration?
    #endif
    #if DEBUG && canImport(ReaderCoreNativeAdapter)
    @State private var nativeCoreEvidenceAutorunConfiguration: NativeCoreEvidenceAutorunConfiguration?
    @State private var unifiedEvidenceAutorunConfiguration: UnifiedEvidenceAutorunConfiguration?
    #endif

    public init() {
        // S6.2: Rust Core is the default business path. The legacy
        // useRealServices UserDefaults toggle is removed — production never
        // needs the old Swift Core factory path. Tests that need mock mode
        // inject it via ShellAssembly.makeMockReadingFlowCoordinator().
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        _coordinator = StateObject(wrappedValue: coordinator)
        _navigationState = StateObject(wrappedValue: AppNavigationState())

        var env = ReaderShellEnvironment()
        #if canImport(WebKit) && canImport(UIKit)
        env.webViewAdapter = ShellAssembly.makeProductionWebViewAdapter()
        #endif
        environment = env

        // S6.1: Boot Rust Core runtime + wire provider to rustCore mode.
        #if canImport(ReaderCoreNativeAdapter)
        do {
            try RustCoreRuntimeHolder.shared.boot()
            ReaderCoreServiceProvider.shared.configureRustCoreMode()
            print("[RustCore] runtime booted + provider configured for rustCore mode")
        } catch {
            print("[RustCore] boot failed at app init: \(error) — falling back to mock")
        }
        #endif

        #if DEBUG && canImport(WebKit) && canImport(UIKit)
        // 解析 autorun 配置
        let config = WebViewRuntimeAutorunConfiguration.parse(CommandLine.arguments)
        print("[WebViewHarness] autorun args parsed enabled=\(config.isEnabled) valid=\(config.isValid)")
        print("[WebViewHarness] bundleId=\(Bundle.main.bundleIdentifier ?? "nil")")
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        print("[WebViewHarness] documentsDirectory=\(docsDir?.path ?? "nil")")
        if config.isEnabled && config.isValid {
            _autorunConfiguration = State(wrappedValue: config)
        }
        #endif

        #if DEBUG && canImport(ReaderCoreNativeAdapter)
        let nativeConfig = NativeCoreEvidenceAutorunConfiguration.parse(CommandLine.arguments)
        print("[NativeCoreEvidence] autorun args parsed enabled=\(nativeConfig.isEnabled) valid=\(nativeConfig.isValid)")
        print("[NativeCoreEvidence] bundleId=\(Bundle.main.bundleIdentifier ?? "nil")")
        if nativeConfig.isEnabled && nativeConfig.isValid {
            _nativeCoreEvidenceAutorunConfiguration = State(wrappedValue: nativeConfig)
        }

        let unifiedConfig = UnifiedEvidenceAutorunConfiguration.parse(CommandLine.arguments)
        print("[UnifiedEvidence] autorun args parsed enabled=\(unifiedConfig.isEnabled) valid=\(unifiedConfig.isValid)")
        print("[UnifiedEvidence] bundleId=\(Bundle.main.bundleIdentifier ?? "nil")")
        if unifiedConfig.isEnabled && unifiedConfig.isValid {
            _unifiedEvidenceAutorunConfiguration = State(wrappedValue: unifiedConfig)
        }
        #endif
    }

    public var body: some Scene {
        WindowGroup {
            #if DEBUG && canImport(ReaderCoreNativeAdapter)
            if let config = unifiedEvidenceAutorunConfiguration, config.isEnabled && config.isValid {
                UnifiedEvidenceAutorunView(configuration: config)
            } else if let config = nativeCoreEvidenceAutorunConfiguration, config.isEnabled && config.isValid {
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
        // P3-B: StateContainerView 是 4 态容器（需要 phase + content builders），
        // 不适合做全局错误边界（错误边界需要响应任意来源的异常）。
        // 改为在根视图注入 ReaderSessionStore，子视图通过 @EnvironmentObject 访问，
        // 后续可基于 sessionStore.reportError 统一上报错误。
        // TODO: 待 P3-B 后续落地全局错误边界包裹
        Group {
            #if DEBUG && canImport(WebKit) && canImport(UIKit)
            if let config = autorunConfiguration, config.isEnabled && config.isValid {
                WebViewRuntimeAutorunView(configuration: config)
            } else {
                AppShellView(
                    coordinator: coordinator,
                    navigationState: navigationState,
                    environment: environment
                )
            }
            #else
            AppShellView(
                coordinator: coordinator,
                navigationState: navigationState,
                environment: environment
            )
            #endif
        }
        .environmentObject(sessionStore)
    }
}
