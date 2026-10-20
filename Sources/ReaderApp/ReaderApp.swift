import SwiftUI

@main
struct ReaderApp: App {
    @StateObject private var bootstrap = ReaderBootstrap()
    @StateObject private var preferences = ReaderPreferences()
    @Environment(\.scenePhase) private var phase

    init() { ReaderFonts.registerBundledFonts() }

    var body: some Scene {
        WindowGroup {
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
            .background(ReaderPalette(preferences.appDark ? .dark : .light).paper)
            .task { bootstrap.setForeground(phase == .active); await bootstrap.prepare() }
            .onOpenURL { url in bootstrap.openFile(url) }
            .onChange(of: phase) { _, value in bootstrap.setForeground(value == .active) }
        }
    }
}

@MainActor
final class ReaderBootstrap: ObservableObject {
    @Published private(set) var model: ReaderApplicationModel?
    @Published private(set) var failed = false
    private var preparing = false
    private var pendingFile: URL?
    private var foreground = true

    func prepare() async {
        guard model == nil, !preparing else { return }
        preparing = true
        failed = false
        do {
            let directory = try FileManager.default.url(for: .applicationSupportDirectory,
                in: .userDomainMask, appropriateFor: nil, create: true).appendingPathComponent("Reader", isDirectory: true)
            let storage = directory.appendingPathComponent("Core", isDirectory: true)
            let sources = directory.appendingPathComponent("LocalSources", isDirectory: true)
            let service = try await Task.detached(priority: .userInitiated) {
                try ReaderLibraryService(storageURL: storage, sourceURL: sources)
            }.value
            let model = ReaderApplicationModel(service: service)
            self.model = model
            model.setForeground(foreground)
            await model.start()
            if let pendingFile { self.pendingFile = nil; model.importFile(pendingFile) }
        } catch { failed = true }
        preparing = false
    }

    func openFile(_ url: URL) {
        guard url.isFileURL else { return }
        if let model { model.importFile(url) } else { pendingFile = url }
    }

    func setForeground(_ active: Bool) {
        foreground = active
        model?.setForeground(active)
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
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack(alignment: .bottom) {
            if let session = model.reader {
                ReaderReadingView(model: model, preferences: preferences, session: session)
                    .id(session.id)
            } else {
                VStack(spacing: 0) {
                    if settings {
                        ReaderSettingsView(preferences: preferences)
                    } else {
                        ReaderBookshelfView(model: model, preferences: preferences,
                            shelfAnchor: $shelfAnchor, query: $shelfQuery, searching: $shelfSearching,
                            importFile: { if model.importBusy { model.importResultVisible = true } else { _ = filePicker.begin() } })
                    }
                    navigation
                }
            }
            if let feedback = model.feedback {
                ReaderTransientFeedback(message: feedback).padding(.horizontal, 24).padding(.bottom, 100)
                    .environment(\.colorScheme, preferences.appDark ? .dark : .light)
                    .allowsHitTesting(false)
            }
        }.background(ReaderPalette(scheme).paper)
            .preferredColorScheme((model.reader == nil ? preferences.appDark : preferences.theme.isDark) ? .dark : .light)
            .sheet(isPresented: filePicker.presented, onDismiss: {
                if let url = filePicker.didDismiss() { model.importFile(url) }
            }) {
                if let operation = filePicker.operationID {
                    ReaderDocumentPicker(selected: { url in
                        if let ready = filePicker.select(url, operationID: operation) { model.importFile(ready) }
                    }, cancelled: { filePicker.cancel(operationID: operation) })
                }
            }
            .sheet(isPresented: $model.importResultVisible) {
                if let operation = model.importOperation {
                    ReaderImportResultView(operation: operation, close: { model.importResultVisible = false },
                        reconcile: { Task { await model.reconcileImports(); await model.reloadLibrary() } })
                        .presentationDetents([.medium])
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
