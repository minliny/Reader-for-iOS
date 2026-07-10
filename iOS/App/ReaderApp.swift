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

    /// Process-wide shared TTS player.
    ///
    /// A single `ReaderTTSPlayer` instance shared between:
    /// - **HostAdapter** (Core-driven `tts.system.*` HostRequests via `HostAdapterHolder`)
    /// - **ReaderView** (UI TTS control via `@EnvironmentObject`)
    ///
    /// This converges the previously split ownership (HostAdapter created its
    /// own local instance; ReaderView created a separate `@StateObject`). Now
    /// both sides observe the same `@Published playbackState`, so Core-driven
    /// TTS queue advances are immediately reflected in the reader UI.
    ///
    /// `@MainActor` isolation on the holder ensures all access is serialized
    /// on the main thread — `AVSpeechSynthesizer` is main-thread-bound, and
    /// `ReaderTTSPlayer`'s public methods are `@MainActor`-isolated.
    #if canImport(ReaderShellValidation) && canImport(AVFoundation) && canImport(UIKit)
    @MainActor
    private enum SharedTTSPlayer {
        static let shared = ReaderTTSPlayer()
    }
    #endif
    @StateObject private var coordinator: ReadingFlowCoordinator
    @StateObject private var navigationState: AppNavigationState
    // P3-B: 全局会话存储，注入到根视图供所有子视图通过 @EnvironmentObject 访问
    @StateObject private var sessionStore: ReaderSessionStore = ReaderSessionStore()
    // 主题管理器：8 主题（paper/warm/green/blue × day/night）+ App 主题模式（system/light/dark）。
    // 由 ReaderApp 注入到环境，子视图通过 @EnvironmentObject / @Environment(\.readerThemePalette) 访问。
    @StateObject private var themeManager = ReaderThemeManager()
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
        // B1-iOS P0 核心接线：启动引导 ComponentRegistry，注册所有 slice 的 component factory。
        // 幂等：多次调用不重复注册。真源：总计划 §4.E + B1-iOS P0 核心接线。
        ComponentRegistry.bootstrapAllSlices()

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

        // Inject production TTS / Share providers into the shared HostAdapter.
        // Before this call, tts.system.* and share.invoke return .notImplemented.
        // After injection, they route to the shared ReaderTTSPlayer
        // (AVSpeechSynthesizer) and ReaderSharePresenter
        // (UIActivityViewController).
        //
        // TTS ownership convergence:
        //   The single `SharedTTSPlayer.shared` instance is injected into both
        //   HostAdapter (here) and the SwiftUI view hierarchy (via
        //   `.environmentObject(SharedTTSPlayer.shared)` in `defaultRootContent`).
        //   ReaderView reads it via `@EnvironmentObject`. This means Core-driven
        //   `tts.system.*` calls and UI-initiated TTS controls mutate the same
        //   AVSpeechSynthesizer — playbackState is observed by both sides.
        //   All public methods on ReaderTTSPlayer are @MainActor-isolated, so
        //   there is no concurrent access.
        #if canImport(ReaderShellValidation) && canImport(AVFoundation) && canImport(UIKit)
        HostAdapterHolder.adapter.setTTSSynthProvider {
            return SharedTTSPlayer.shared
        }
        HostAdapterHolder.adapter.setSharePresenterProvider {
            return ReaderSharePresenter()
        }
        print("[HostAdapter] TTS + Share providers injected into HostAdapterHolder (shared TTS player)")
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
        #if canImport(ReaderShellValidation) && canImport(AVFoundation) && canImport(UIKit)
        .environmentObject(SharedTTSPlayer.shared)
        #endif
        // 主题系统注入：themeManager（供子视图 @EnvironmentObject）+ palette（供 @Environment(\.readerThemePalette)）。
        .environmentObject(themeManager)
        .readerThemePalette(themeManager.palette)
        // preferredColorScheme：appThemeMode 为 light/dark 时强制，system 时返回 nil（跟随系统）。
        .preferredColorScheme(themeManager.appThemeMode == "light" ? .light : themeManager.appThemeMode == "dark" ? .dark : nil)
        // 同步系统 ColorScheme 到 themeManager（system 模式下据此解析 effectiveIsNight）。
        .background(ReaderSystemColorSchemeSync())
    }
}

/// 系统颜色方案同步器：读取 @SwiftUI.Environment(\.colorScheme) 并同步到 ReaderThemeManager，
/// 供 appThemeMode == "system" 时解析 effectiveIsNight（对照 HarmonyOS systemColorScheme 注入）。
private struct ReaderSystemColorSchemeSync: View {
    @EnvironmentObject private var themeManager: ReaderThemeManager
    @SwiftUI.Environment(\.colorScheme) private var systemColorScheme

    var body: some View {
        Color.clear
            .frame(maxWidth: 0, maxHeight: 0)
            .onAppear { themeManager.updateSystemColorScheme(systemColorScheme) }
            .onChange(of: systemColorScheme) { newValue in
                themeManager.updateSystemColorScheme(newValue)
            }
    }
}
