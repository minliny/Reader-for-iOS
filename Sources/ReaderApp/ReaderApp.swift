import SwiftUI

@main
struct ReaderApp: App {
    @UIApplicationDelegateAdaptor(ReaderOrientationDelegate.self) private var orientationDelegate
    @StateObject private var lifetime: ReaderAppLifetime

    init() {
        #if DEBUG
        let isolated = ReaderNativeCleanupLaunch.isRequested || ReaderIsolatedUnitTestLaunch.isRequested
        #else
        let isolated = false
        #endif
        _lifetime = StateObject(wrappedValue: ReaderAppLifetime(production: !isolated))
        ReaderFonts.registerBundledFonts()
        #if DEBUG
        if isolated {
            ReaderNativeCleanupLaunch.registerBackgroundRejectionHandler()
        } else {
            ReaderRuleSubscriptionScheduler.shared.register()
        }
        #else
        ReaderRuleSubscriptionScheduler.shared.register()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            #if DEBUG
            if ReaderIsolatedUnitTestLaunch.isRequested {
                Color.clear.accessibilityIdentifier(ReaderIsolatedUnitTestLaunch.isAdmitted
                    ? "isolated-unit-host-ready" : "isolated-unit-host-rejected")
            } else if ReaderNativeCleanupLaunch.isRequested {
                ReaderNativeCleanupHarnessView()
            } else {
                productionRoot
            }
            #else
            productionRoot
            #endif
        }
    }

    @ViewBuilder private var productionRoot: some View {
        if let bootstrap = lifetime.bootstrap, let preferences = lifetime.preferences {
            ReaderProductionRoot(bootstrap: bootstrap, preferences: preferences)
        }
    }
}

/// Keep the original owners at App lifetime, including scene recreation. An
/// isolated DEBUG launch installs an empty container, not dormant normal owners.
@MainActor
private final class ReaderAppLifetime: ObservableObject {
    let bootstrap: ReaderBootstrap?
    let preferences: ReaderPreferences?
    init(production: Bool) {
        if production { bootstrap = ReaderBootstrap(); preferences = ReaderPreferences() }
        else { bootstrap = nil; preferences = nil }
    }
}

/// Construct the normal owners only in the normal launch branch. A DEBUG
/// isolated journey must not start a second business runtime behind its UI.
private struct ReaderProductionRoot: View {
    @ObservedObject var bootstrap: ReaderBootstrap
    @ObservedObject var preferences: ReaderPreferences
    @Environment(\.scenePhase) private var phase

    var body: some View {
            Group {
                if let model = bootstrap.model {
                    ReaderRootView(model: model, preferences: preferences)
                } else if bootstrap.failed {
                    ReaderPageState(title: "阅读服务启动失败", detail: "已有书籍文件已保留，请重试。",
                        actionTitle: "重试") { Task { await bootstrap.prepare() } }
                        .preferredColorScheme(preferences.appDark ? .dark : .light)
                } else {
                    ReaderPageState(title: "正在准备书架", loading: true)
                        .preferredColorScheme(preferences.appDark ? .dark : .light)
                }
            }
            .background(ReaderSystemAppearanceAttachment(changed: { preferences.applySystemAppearance(systemDark: $0) }).frame(width: 0, height: 0))
            .background(ReaderPalette(preferences.appDark ? .dark : .light).paper)
            .task { bootstrap.setForeground(phase == .active); await bootstrap.prepare() }
            .onOpenURL { url in bootstrap.openFile(url) }
            .onChange(of: phase) { _, value in bootstrap.setForeground(value == .active) }
    }
}

@MainActor
final class ReaderBootstrap: ObservableObject {
    @Published private(set) var model: ReaderApplicationModel?
    @Published private(set) var failed = false
    private var preparing = false
    private var pendingFiles: [URL] = []
    private var foreground = true
    private var subscriptionOpportunity: Task<Void, Never>?
    private var subscriptionOpportunityID = UUID()

    func prepare() async {
        guard model == nil, !preparing else { return }
        preparing = true
        failed = false
        do {
            let service = try await ReaderAppRuntimeStore.shared.library()
            let model = ReaderApplicationModel(service: service)
            self.model = model
            model.setForeground(foreground)
            await model.start()
            beginSubscriptionOpportunity()
            if !pendingFiles.isEmpty {
                let files = pendingFiles; pendingFiles.removeAll()
                model.importFiles(files)
            }
        } catch { failed = true }
        preparing = false
    }

    func openFile(_ url: URL) {
        guard url.isFileURL else { return }
        if let model, !preparing { model.importFile(url) } else { pendingFiles.append(url) }
    }

    func setForeground(_ active: Bool) {
        let changed = foreground != active
        foreground = active
        model?.setForeground(active)
        guard changed else { return }
        if active { beginSubscriptionOpportunity() }
        else {
            subscriptionOpportunityID = UUID()
            subscriptionOpportunity?.cancel(); subscriptionOpportunity = nil
        }
    }

    private func beginSubscriptionOpportunity() {
        guard foreground, model != nil, subscriptionOpportunity == nil else { return }
        let generation = UUID(); subscriptionOpportunityID = generation
        subscriptionOpportunity = Task { [weak self] in
            await ReaderRuleSubscriptionScheduler.shared.foregroundOpportunity()
            guard let self, subscriptionOpportunityID == generation else { return }
            subscriptionOpportunity = nil
        }
    }
}

struct ReaderRootView: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    @StateObject private var filePicker = ReaderFilePickerOwner()
    @State private var settings = false
    @State private var shelfAnchor: String?
    @State private var shelfQuery = ""
    @State private var shelfSearching = false
    @StateObject private var shelfPresentation = ReaderShelfPresentation()
    @State private var online = false
    @State private var downloadsVisible = false
    @StateObject private var downloads = ReaderDownloadManagementPresentation()
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if downloadsVisible {
                    ReaderDownloadManagementView(model: model, owner: downloads, close: { downloadsVisible = false })
                } else if online {
                    ReaderOnlineWorkspace(model: model, preferences: preferences, close: { online = false })
                } else {
                VStack(spacing: 0) {
                    if settings {
                        ReaderSettingsView(preferences: preferences, online: { online = true }, downloads: { downloadsVisible = true })
                    } else {
                        ReaderBookshelfView(model: model, preferences: preferences,
                            shelfAnchor: $shelfAnchor, query: $shelfQuery, searching: $shelfSearching,
                            presentation: shelfPresentation,
                            importFile: { if model.importBusy { model.importResultVisible = true } else { _ = filePicker.begin() } },
                            online: { online = true }, downloads: { downloadsVisible = true })
                    }
                    navigation
                }
                }
            }.opacity(model.reader == nil ? 1 : 0).allowsHitTesting(model.reader == nil)
                .accessibilityHidden(model.reader != nil)
            if let session = model.reader {
                ReaderReadingView(model: model, preferences: preferences, session: session).id(session.id)
            }
            ReaderFeatureRecoveryEntry(model: model, owner: model.featureRecovery)
                .environment(\.colorScheme, preferences.appDark ? .dark : .light)
                .padding(.bottom, 94)
            if let feedback = model.feedback {
                ReaderTransientFeedback(message: feedback).padding(.horizontal, 24).padding(.bottom, 100)
                    .environment(\.colorScheme, preferences.appDark ? .dark : .light)
                    .allowsHitTesting(false)
            }
            VStack {
                ReaderOperationStatus(owner: model.actions, scope: model.reader?.book.id ?? "shelf",
                    allowGlobalRecovery: true,
                    recoveryContext: model.books.first(where: { $0.id == model.actions.scope }).map { "《" + $0.title + "》" }) {
                    Task { await model.reloadLibrary() }
                }.environment(\.colorScheme, preferences.appDark ? .dark : .light)
                ReaderOperationStatus(owner: model.readingTime.actions, scope: model.readingTime.scope) {
                    Task { await model.readingTime.flush() }
                }.environment(\.colorScheme, preferences.appDark ? .dark : .light)
                Spacer()
            }.padding(16)
        }.background(ReaderPalette(scheme).paper)
            .preferredColorScheme((model.reader == nil ? preferences.appDark : preferences.theme.isDark) ? .dark : .light)
            .sheet(isPresented: filePicker.presented, onDismiss: {
                if let urls = filePicker.didDismissFiles() { model.importFiles(urls) }
            }) {
                if let operation = filePicker.operationID {
                    ReaderDocumentPicker(selected: { url in
                        if let ready = filePicker.select(url, operationID: operation) { model.importFile(ready) }
                    }, cancelled: { filePicker.cancel(operationID: operation) }, selectedFiles: { urls in
                        if let ready = filePicker.selectFiles(urls, operationID: operation) { model.importFiles(ready) }
                    }, allowsMultipleSelection: true)
                }
            }
            .sheet(isPresented: $model.importResultVisible) {
                if let operation = model.importOperation {
                    ReaderImportResultView(operation: operation, close: { model.importResultVisible = false },
                        reconcile: { Task { await model.reconcileImports(); await model.reloadLibrary() } },
                        stopRemaining: model.stopRemainingImports, feedback: model.feedback)
                        .presentationDetents([.medium, .large])
                        .preferredColorScheme(preferences.appDark ? .dark : .light)
                }
            }
    }

    private var navigation: some View {
        HStack(spacing: 8) {
            tab("书架", icon: settings ? .bookshelf : .bookshelfActive, active: !settings) { settings = false }
            tab("设置", icon: settings ? .settingsActive : .settings, active: settings) { settings = true }
        }.padding(8).frame(width: 196, height: 68)
            .background(ReaderPalette(scheme).panel, in: Capsule())
            .overlay(Capsule().stroke(ReaderPalette(scheme).app("TOK_SURFACE_ELEVATED"), lineWidth: 1))
            .shadow(color: ReaderPalette(scheme).app("app.BookshelfPage.projectionBookCoverLayer.color.1A594632"), radius: 18, y: 5)
            .frame(maxWidth: .infinity).padding(.top, 10).padding(.bottom, 15)
    }
    private func tab(_ label: String, icon: ReaderIconName, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                ReaderIcon(icon, size: 24).frame(width: 30, height: 30)
                Text(label).font(ReaderTypography.font(.mainTab))
            }.frame(maxWidth: .infinity).frame(height: 50)
                .background(active ? ReaderPalette(scheme).primaryDark : .clear, in: Capsule())
        }.buttonStyle(ReaderPressFeedback()).foregroundStyle(active ? ReaderPalette(scheme).onPrimary : ReaderPalette(scheme).muted)
            .accessibilityAddTraits(active ? .isSelected : [])
    }
}
