import Observation
import ReaderDesign
import ReaderHost
import SwiftUI
import WebKit

enum SourceBrowserAction {
    case back, forward, refresh, finish
}

struct SourceBrowserContent<Content: View>: View {
    let title: String
    let address: String
    let secure: Bool
    let canGoBack: Bool
    let canGoForward: Bool
    let loading: Bool
    let progress: Double
    let onAction: (SourceBrowserAction) -> Void
    let content: Content
    @Environment(\.readerTheme) private var theme

    init(title: String, address: String, secure: Bool, canGoBack: Bool, canGoForward: Bool,
         loading: Bool, progress: Double, onAction: @escaping (SourceBrowserAction) -> Void,
         @ViewBuilder content: () -> Content) {
        self.title = title
        self.address = address
        self.secure = secure
        self.canGoBack = canGoBack
        self.canGoForward = canGoForward
        self.loading = loading
        self.progress = progress
        self.onAction = onAction
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            top
            if loading {
                ProgressView(value: progress)
                    .tint(theme.accentFill)
                    .frame(height: CGFloat(ReaderDesignMetrics.sourceLoginProgressHeight))
                    .clipped()
                    .accessibilityLabel("加载网页")
            }
            content.frame(maxWidth: .infinity, maxHeight: .infinity)
            bottom
        }
        .background(theme.background)
    }

    private var top: some View {
        VStack(spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
            Text(title)
                .readerTypography(ReaderDesignMetrics.sourceLoginTitle)
                .foregroundStyle(theme.primaryText)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                ReaderIcon(secure ? ReaderIconRegistry.sourceLoginSecure : ReaderIconRegistry.sourceLoginUnknown,
                           squareSize: CGFloat(ReaderDesignMetrics.sourceLoginLockSize))
                Text(address)
                    .readerTypography(ReaderDesignMetrics.sourceLoginAddress)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityIdentifier("source.browser.address")
            }
            .foregroundStyle(theme.secondaryText)
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.spaceSmall))
            .padding(.vertical, CGFloat(ReaderDesignMetrics.rowBlockSpacing))
            .background(theme.field, in: Capsule())
        }
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        .padding(.vertical, CGFloat(ReaderDesignMetrics.spaceExtraSmall))
        .frame(maxWidth: .infinity, minHeight: CGFloat(ReaderDesignMetrics.sourceLoginToolbarMinHeight))
        .background(theme.surface)
        .overlay(alignment: .bottom) { Divider().overlay(theme.divider) }
    }

    private var bottom: some View {
        HStack {
            browserButton("后退", ReaderIconRegistry.back, id: "source.browser.back", disabled: !canGoBack, .back)
            browserButton("前进", ReaderIconRegistry.nextChapter, id: "source.browser.forward", disabled: !canGoForward, .forward)
            browserButton("刷新", ReaderIconRegistry.refresh, id: "source.browser.refresh", disabled: false, .refresh)
            Spacer()
            Button { onAction(.finish) } label: {
                Text("完成")
                    .readerTypography(ReaderDesignMetrics.sourceLoginControlLabel)
                    .foregroundStyle(theme.onAccent)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(theme.accentFill)
            .frame(minHeight: CGFloat(ReaderDesignMetrics.minimumActionTarget))
            .accessibilityIdentifier("source.browser.done")
        }
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        .frame(minHeight: CGFloat(ReaderDesignMetrics.sourceLoginToolbarMinHeight))
        .background(theme.surface)
        .overlay(alignment: .top) { Divider().overlay(theme.divider) }
    }

    private func browserButton(_ title: String, _ icon: ReaderIconMapping, id: String, disabled: Bool,
                               _ action: SourceBrowserAction) -> some View {
        Button { onAction(action) } label: {
            ReaderIcon(icon)
                .font(.system(size: CGFloat(ReaderDesignMetrics.sourceLoginActionIconSize), weight: .semibold))
                .frame(width: CGFloat(ReaderDesignMetrics.minimumActionTarget),
                       height: CGFloat(ReaderDesignMetrics.minimumActionTarget))
        }
        .buttonStyle(.plain)
        .foregroundStyle(disabled ? theme.mutedText : theme.accent)
        .disabled(disabled)
        .accessibilityLabel(title)
        .accessibilityIdentifier(id)
    }
}

@MainActor
@Observable
private final class SourceBrowserProjection {
    var address = "正在打开"
    var secure = false
    var canGoBack = false
    var canGoForward = false
    var loading = true
    var progress = 0.0
    var state = SourceLoginSession.State.loading

    func render(_ session: SourceLoginSession) {
        let page = session.webView
        if let url = page.url, let host = url.host() {
            let port = url.port.map { ":\($0)" } ?? ""
            address = host + port + url.path()
            secure = url.scheme?.lowercased() == "https"
        }
        state = session.state
        canGoBack = state != .revoked && page.canGoBack
        canGoForward = state != .revoked && page.canGoForward
        loading = state == .loading || (state == .ready && page.isLoading)
        progress = min(max(page.estimatedProgress, 0), 1)
    }
}

struct SourceLoginScreen: View {
    let sourceID: String
    let title: String
    let coordinator: SourceManagementCoordinator
    @State private var session: SourceLoginSession?
    @State private var projection = SourceBrowserProjection()
    @State private var didFailToOpen = false
    @State private var finishing = false
    @State private var toast = ReaderToastPresenter()
    @Environment(\.readerTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scene

    var body: some View {
        SourceBrowserContent(title: title, address: projection.address, secure: projection.secure,
                             canGoBack: projection.canGoBack, canGoForward: projection.canGoForward,
                             loading: projection.loading, progress: projection.progress, onAction: action) {
            browserBody
        }
        .toolbar(.hidden, for: .navigationBar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("source.browser")
        .task { await open() }
        .onDisappear {
            if let session {
                session.onNavigationChange = nil
                coordinator.network?.closeLogin(session)
            }
        }
        .overlay(alignment: .bottom) {
            if let message = toast.message, scene == .active {
                TransientToast(message: message)
                    .padding(.bottom, CGFloat(ReaderDesignMetrics.sourceLoginToolbarMinHeight))
            }
        }
    }

    @ViewBuilder
    private var browserBody: some View {
        if didFailToOpen {
            PageState(state: .failed("无法打开登录页", actionGeneration: 0)) { _ in Task { await open() } }
        } else if let session {
            if projection.state == .failed || projection.state == .timedOut {
                PageState(state: .failed("登录页未能加载", actionGeneration: 0)) { _ in action(.refresh) }
            } else if projection.state == .revoked {
                PageState(state: .empty("该书源的登录会话已关闭"))
            } else {
                SourceWKView(view: session.webView)
                    .accessibilityIdentifier("source.browser.web")
            }
        } else {
            PageState(state: .loading)
        }
    }

    private func open() async {
        guard session == nil else { return }
        didFailToOpen = false
        projection.loading = true
        do {
            let lease = try await coordinator.beginLogin(sourceId: sourceID)
            guard !Task.isCancelled else {
                coordinator.network?.closeLogin(lease)
                return
            }
            session = lease
            let browserState = projection
            browserState.render(lease)
            lease.onNavigationChange = { [weak lease, weak browserState] in
                if let lease { browserState?.render(lease) }
            }
        } catch is CancellationError {
            projection.loading = false
        } catch {
            projection.address = "登录页不可用"
            projection.loading = false
            didFailToOpen = true
        }
    }

    private func action(_ action: SourceBrowserAction) {
        guard !finishing else { return }
        switch action {
        case .back:
            if let session, session.webView.canGoBack { session.webView.goBack() }
        case .forward:
            if let session, session.webView.canGoForward { session.webView.goForward() }
        case .refresh:
            if let session { session.reloadPage() }
            else { Task { await open() } }
        case .finish:
            guard let session, session.state != .revoked, let network = coordinator.network else { dismiss(); return }
            finishing = true
            toast.dismiss()
            Task {
                defer { finishing = false }
                do {
                    try await network.finishLogin(session)
                    dismiss()
                } catch {
                    toast.show(message: "暂时无法确认登录态同步，请重试。", key: "source-login-finish",
                               feedbackEnabled: true, sceneActive: scene == .active)
                }
            }
        }
    }
}

private struct SourceWKView: UIViewRepresentable {
    let view: WKWebView

    func makeUIView(context: Context) -> WKWebView { view }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
}
