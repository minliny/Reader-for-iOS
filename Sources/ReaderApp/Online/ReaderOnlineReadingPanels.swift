import SwiftUI
import UIKit
#if DEBUG
import OSLog
#endif

/// Bounded presentation cache: candidates/query/timing survive closing the
/// switch sheet. Core remains the owner of books, catalogs and transactions.
@MainActor final class ReaderSwitchPresentationCache {
    static let shared = ReaderSwitchPresentationCache()
    private struct Entry {
        let state: ReaderOnlineWorkspaceModel
        let candidates: ReaderSwitchCandidateHost
    }
    private var entries: [String: Entry] = [:]
    private var order: [String] = []
    func state(for identity: String, initialQuery: String) -> ReaderOnlineWorkspaceModel {
        entry(for: identity, initialQuery: initialQuery).state
    }
    func candidateHost(for identity: String, initialQuery: String) -> ReaderSwitchCandidateHost {
        entry(for: identity, initialQuery: initialQuery).candidates
    }
    private func entry(for identity: String, initialQuery: String) -> Entry {
        if let entry = entries[identity] { return entry }
        let state = ReaderOnlineWorkspaceModel(); state.query = initialQuery
        let entry = Entry(state: state, candidates: ReaderSwitchCandidateHost(state: state, currentBookID: identity))
        entries[identity] = entry; order.append(identity)
        while order.count > 8 {
            let evicted = order.removeFirst()
            if let entry = entries.removeValue(forKey: evicted) {
                entry.state.retireCachedDiscovery()
                entry.candidates.retire()
            }
        }
        return entry
    }
}

struct ReaderOnlineSwitchPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    let session: ReaderActiveSession
    @StateObject private var state: ReaderOnlineWorkspaceModel
    @State private var discoveryPresentationID = UUID()
    @State private var candidateHost: ReaderSwitchCandidateHost
    @FocusState private var queryFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    init(model: ReaderApplicationModel, preferences: ReaderPreferences, session: ReaderActiveSession) {
        self.model = model; self.preferences = preferences; self.session = session
        let cache = ReaderSwitchPresentationCache.shared
        _state = StateObject(wrappedValue: cache.state(for: session.book.id, initialQuery: session.book.title))
        _candidateHost = State(initialValue: cache.candidateHost(for: session.book.id, initialQuery: session.book.title))
    }
    var body: some View {
        let presentationID = discoveryPresentationID
        let queryFocus = $queryFocused
        let dismissAction = dismiss
        VStack(spacing: 12) {
            HStack {
                Button("关闭") { queryFocused = false; dismiss() }.accessibilityIdentifier("online-switch-close")
                Spacer()
                Text("切换书源").font(ReaderTypography.font(.controlHeader))
                    .accessibilityIdentifier("online-switch-owner:\(model.actions.busy ? "busy" : model.actions.hasPending ? "pending" : "settled")")
                Spacer()
                Button(state.searching ? "停止" : "重新搜索") { if state.searching { state.stop() } else { state.researchCandidates() } }
            }.padding(.horizontal, 20)
            HStack { TextField("书名或作者", text: $state.query).readerField().focused($queryFocused); Button("搜索", action: state.researchCandidates) }.padding(.horizontal, 20)
            Text("当前：\(session.book.sourceName ?? state.sourceName(session.book.sourceId))").font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
            if state.searching { ProgressView("正在查找其他来源") }
            if !state.failures.isEmpty { Text("\(state.failures.count) 个来源未完成").font(ReaderTypography.font(.caption)) }
            if candidates.isEmpty, !state.searching {
                emptyCandidates
            } else {
                ReaderSwitchCandidateViewport(owner: candidateHost, state: state,
                    actions: model.actions, model: model, sessionID: session.id,
                    bookID: session.book.id, presentationID: presentationID,
                    clearQueryFocus: { queryFocus.wrappedValue = false }, dismissPanel: { dismissAction() })
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            ReaderOnlineSourceRefreshNotice(state: state)
            ReaderOperationStatus(owner: model.actions, scope: session.book.id)
                .accessibilityIdentifier("online-switch-outcome")
        }.padding(.vertical, 20).background(ReaderPalette(scheme).paper)
            .task {
                guard !Task.isCancelled else { return }
                state.activateDiscoveryPresentation(presentationID)
                state.service = model.libraryService as? any ReaderOnlineServing
                await state.refreshDiscoverySources(presentationID: presentationID)
            }
            .onDisappear {
                queryFocused = false
                candidateHost.endPresentation(presentationID)
                state.retireDiscoveryPresentation(presentationID)
            }
    }
    @ViewBuilder private var emptyCandidates: some View {
        if state.sourceLoading {
            ReaderPageState(title: "正在加载书源", loading: true)
        } else if state.sources.allSatisfy({ !$0.enabled }) {
            ReaderPageState(title: state.sourceReadFailure == nil ? "还没有启用的书源" : "书源加载失败", detail: state.sourceReadFailure ?? "可在书源管理中启用书源，已有正文和阅读位置保留。", actionTitle: state.sourceReadFailure == nil ? nil : "重试") {
                let presentationID = discoveryPresentationID
                Task { await state.refreshDiscoverySources(presentationID: presentationID) }
            }
        } else if state.stopped {
            ReaderPageState(title: "查找已停止", detail: "已有正文和阅读位置保留，可重新搜索。", actionTitle: "重新搜索", action: state.researchCandidates)
        } else if !state.failures.isEmpty {
            ReaderPageState(title: state.timings.isEmpty ? "查找来源失败" : "部分来源未完成", detail: "尚不能确认没有其他来源，已有正文和阅读位置保留。", actionTitle: "重新搜索", action: state.researchCandidates)
        } else if !state.searched || state.timings.isEmpty {
            ReaderPageState(title: "尚未取得来源结果", detail: "已有正文和阅读位置保留，可重新搜索。", actionTitle: "重新搜索", action: state.researchCandidates)
        } else {
            ReaderPageState(title: "没有其他来源", detail: "已有正文和阅读位置保留，可重新搜索。", actionTitle: "重新搜索", action: state.researchCandidates)
        }
    }
    private var candidates: [ReaderOnlineCandidate] { state.results.filter { $0.id != session.book.id } }
}

// Only the candidate list survives dismissal. Header/focus/status/dismissal stay
// in the new sheet, and a cached graph never owns an application/session closure.
@MainActor final class ReaderSwitchCandidateHost {
    private let state: ReaderOnlineWorkspaceModel
    private let currentBookID: String
    private var hosting: ReaderSwitchCandidateHostingController?
    private var presentationInput: ReaderSwitchCandidatePresentationInput?
    // SwiftUI may call UIViewControllerRepresentable.update while it is
    // reconciling the view tree. Keep the requested platform state
    // synchronously for the action gate, but publish it to the hosted SwiftUI
    // root on the next main-actor turn.
    private var requestedConfiguration: ReaderSwitchCandidatePresentationInput.Configuration?
    private var configurationCommit: Task<Void, Never>?
    private var configurationGeneration = UUID()
    private var rootConfiguration: ReaderSwitchCandidatePresentationInput.Configuration? {
        presentationInput?.configuration
    }
    private weak var attachment: ReaderSwitchCandidateViewportController?
    private var retired = false
    // A per-book platform viewport only. Core/business/candidate ownership is
    // unchanged; UIKit supplies native layout, scrolling and gesture physics.
    private struct ViewportDisplay: Equatable {
        let query: String
        let candidates: [ReaderOnlineCandidate]
        let sourceNames: [String]
        let timings: [Int?]
        let currentIDs: Set<String>
        let searching: Bool
    }
    private struct ViewportGeometry {
        let bounds: CGSize
        let content: CGSize
        let inset: UIEdgeInsets
        let adjusted: UIEdgeInsets
        let zoom: CGFloat
        init(_ scroll: UIScrollView) {
            bounds = scroll.bounds.size; content = scroll.contentSize
            inset = scroll.contentInset; adjusted = scroll.adjustedContentInset; zoom = scroll.zoomScale
        }
        var finite: Bool {
            [bounds.width,bounds.height,content.width,content.height,inset.top,inset.left,inset.bottom,inset.right,
             adjusted.top,adjusted.left,adjusted.bottom,adjusted.right,zoom].allSatisfy { $0.isFinite }
        }
        func accepts(_ offset: CGPoint, epsilon: CGFloat) -> Bool {
            // Public UIKit scrollable extents only; no paging/physics algorithm.
            let minX = -adjusted.left, minY = -adjusted.top
            let maxX = max(minX, content.width - bounds.width + adjusted.right)
            let maxY = max(minY, content.height - bounds.height + adjusted.bottom)
            return finite && offset.x.isFinite && offset.y.isFinite &&
                offset.x >= minX - epsilon && offset.x <= maxX + epsilon &&
                offset.y >= minY - epsilon && offset.y <= maxY + epsilon
        }
        func sameViewport(as other: Self, epsilon: CGFloat) -> Bool {
            // Zoom is dimensionless; a pixel tolerance applies only to points.
            guard zoom == other.zoom else { return false }
            return zip([bounds.width,bounds.height,inset.top,inset.left,inset.bottom,inset.right,
                 adjusted.top,adjusted.left,adjusted.bottom,adjusted.right],
                [other.bounds.width,other.bounds.height,other.inset.top,other.inset.left,other.inset.bottom,other.inset.right,
                 other.adjusted.top,other.adjusted.left,other.adjusted.bottom,other.adjusted.right])
                .allSatisfy { abs($0.0 - $0.1) <= epsilon }
        }
        func sameContent(as other: Self, epsilon: CGFloat) -> Bool {
            abs(content.width - other.content.width) <= epsilon && abs(content.height - other.content.height) <= epsilon
        }
    }
    private struct ViewportSnapshot {
        let id = UUID()
        let sourceAttachmentID: UUID
        let display: ViewportDisplay
        let environment: ReaderSwitchCandidateEnvironment
        let geometry: ViewportGeometry
        let offset: CGPoint
    }
    private struct ViewportRestore {
        let snapshotID: UUID
        let attachmentID: UUID
        var hostAppeared = false
        var containerAppeared = false
        var appliedNativeIDs = Set<ObjectIdentifier>()
    }
    private var viewportSnapshot: ViewportSnapshot?
    private var viewportRestore: ViewportRestore?
    private var viewportInteraction: ReaderSwitchViewportInteraction?
    private var applyingViewportOffset = false
    #if DEBUG
    private static let viewportLogger = Logger(subsystem: "io.reader.minliny", category: "reader-switch-viewport")
    private var viewportTraceCount = 0
    private var viewportLayoutTraceCount = 0
    private(set) var viewportRootAssignments = 0
    private var viewportLastLayout: String?

    // Public, synchronous getters only. Never materialize an unloaded view,
    // force layout, observe/replace a delegate, or retain a native view here.
    fileprivate func traceViewport(_ phase: String, container: ReaderSwitchCandidateViewportController? = nil) {
        guard viewportTraceCount < 96 else { return }
        if ["layout", "hosting.layout"].contains(phase), viewportLayoutTraceCount >= 24 { return }
        let target = container ?? attachment
        let hostView = hosting?.viewIfLoaded
        var record: [String: Any] = [:]
        record["phase"] = phase
        record["owner"] = Self.viewportIdentity(self)
        record["workspace"] = Self.viewportIdentity(state)
        record["hosting"] = Self.viewportIdentity(hosting)
        record["hostingParent"] = Self.viewportIdentity(hosting?.parent)
        record["container"] = Self.viewportIdentity(target)
        record["containerParent"] = Self.viewportIdentity(target?.parent)
        record["currentAttachment"] = Self.viewportIdentity(attachment)
        record["isCurrentAttachment"] = target.map { self.isAttached($0) } ?? false
        record["attachmentUUID"] = target?.attachmentID.uuidString ?? "-"
        record["presentationUUID"] = target?.presentationID.uuidString ?? "-"
        record["configuredAttachmentUUID"] = rootConfiguration?.attachmentID.uuidString ?? "-"
        record["retired"] = retired
        record["rootAssignments"] = viewportRootAssignments
        record["viewportSnapshotStored"] = viewportSnapshot != nil
        record["viewportSnapshotSourceAttachmentUUID"] = viewportSnapshot?.sourceAttachmentID.uuidString ?? "-"
        record["viewportRestorePending"] = viewportRestore != nil
        record["viewportRestoreAttachmentUUID"] = viewportRestore?.attachmentID.uuidString ?? "-"
        record["viewportRestoreAppliedNativeCount"] = viewportRestore?.appliedNativeIDs.count ?? 0
        record["resultCount"] = state.results.count
        record["searching"] = state.searching
        record["containerView"] = Self.viewportView(target?.viewIfLoaded)
        record["hostingView"] = Self.viewportView(hostView)
        var pending: [(UIView, Int)] = hostView.map { [($0, 0)] } ?? []
        var visited = Set<ObjectIdentifier>()
        var scrollViews: [[String: Any]] = []
        var treeLimited = false
        var scrollViewsLimited = false
        while let (view, depth) = pending.popLast() {
            let identity = ObjectIdentifier(view)
            guard !visited.contains(identity) else { continue }
            guard visited.count < 256 else { treeLimited = true; break }
            visited.insert(identity)
            if let scroll = view as? UIScrollView {
                if scrollViews.count < 8 {
                    var item = Self.viewportView(scroll)
                    item["offset"] = Self.viewportPoint(scroll.contentOffset)
                    item["contentSize"] = Self.viewportSize(scroll.contentSize)
                    item["contentInset"] = Self.viewportInset(scroll.contentInset)
                    item["adjustedInset"] = Self.viewportInset(scroll.adjustedContentInset)
                    item["insetAdjustmentBehavior"] = scroll.contentInsetAdjustmentBehavior.rawValue
                    item["tracking"] = scroll.isTracking
                    item["dragging"] = scroll.isDragging
                    item["decelerating"] = scroll.isDecelerating
                    item["scrollEnabled"] = scroll.isScrollEnabled
                    scrollViews.append(item)
                } else { scrollViewsLimited = true }
            }
            let children = view.subviews
            if depth < 16 {
                let available = max(0, 256 - visited.count - pending.count)
                if children.count > available { treeLimited = true }
                for child in children.prefix(available).reversed() { pending.append((child, depth + 1)) }
            } else if !children.isEmpty { treeLimited = true }
        }
        record["scrollViews"] = scrollViews
        record["treeVisited"] = visited.count
        record["treeLimited"] = treeLimited
        record["scrollViewsLimited"] = scrollViewsLimited
        guard let signatureData = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
              let signature = String(data: signatureData, encoding: .utf8) else { return }
        if ["layout", "hosting.layout"].contains(phase) {
            guard viewportLastLayout != signature else { return }
            viewportLastLayout = signature
            viewportLayoutTraceCount += 1
        }
        viewportTraceCount += 1
        record["sequence"] = viewportTraceCount
        record["uptime"] = ProcessInfo.processInfo.systemUptime
        guard let data = try? JSONSerialization.data(withJSONObject: record, options: [.sortedKeys]),
              let message = String(data: data, encoding: .utf8) else { return }
        Self.viewportLogger.notice("\(message, privacy: .public)")
    }
    private static func viewportIdentity(_ value: AnyObject?) -> String {
        value.map { String(describing: ObjectIdentifier($0)) } ?? "-"
    }
    private static func viewportView(_ view: UIView?) -> [String: Any] {
        guard let view else { return ["loaded": false] }
        var result: [String: Any] = [:]
        result["loaded"] = true
        result["identity"] = viewportIdentity(view)
        result["superview"] = viewportIdentity(view.superview)
        result["window"] = viewportIdentity(view.window)
        result["bounds"] = viewportRect(view.bounds)
        result["frame"] = viewportRect(view.frame)
        result["safeArea"] = viewportInset(view.safeAreaInsets)
        result["hidden"] = view.isHidden
        result["alpha"] = Double(view.alpha)
        if let window = view.window {
            result["frameInWindow"] = viewportRect(view.convert(view.bounds, to: window))
            result["windowBounds"] = viewportRect(window.bounds)
        }
        return result
    }
    private static func viewportPoint(_ point: CGPoint) -> [String: Double] {
        ["x": Double(point.x), "y": Double(point.y)]
    }
    private static func viewportSize(_ size: CGSize) -> [String: Double] {
        ["width": Double(size.width), "height": Double(size.height)]
    }
    private static func viewportRect(_ rect: CGRect) -> [String: Double] {
        ["x": Double(rect.origin.x), "y": Double(rect.origin.y),
         "width": Double(rect.width), "height": Double(rect.height)]
    }
    private static func viewportInset(_ inset: UIEdgeInsets) -> [String: Double] {
        ["top": Double(inset.top), "left": Double(inset.left),
         "bottom": Double(inset.bottom), "right": Double(inset.right)]
    }
    #endif
    init(state: ReaderOnlineWorkspaceModel, currentBookID: String) {
        self.state = state; self.currentBookID = currentBookID
    }
    func beginAttachment(_ container: ReaderSwitchCandidateViewportController) {
        guard !retired else { return }
        #if DEBUG
        traceViewport("begin.before", container: container)
        #endif
        if let previous = attachment, previous !== container { detach(previous) }
        attachment = container
        invalidateChangedViewportDisplay()
        if let snapshot = viewportSnapshot {
            viewportRestore = ViewportRestore(snapshotID: snapshot.id, attachmentID: container.attachmentID)
        }
        #if DEBUG
        traceViewport("begin.after", container: container)
        #endif
    }
    func isAttached(_ container: ReaderSwitchCandidateViewportController) -> Bool {
        !retired && attachment === container
    }
    func update(_ container: ReaderSwitchCandidateViewportController, disabled: Bool,
                environment: ReaderSwitchCandidateEnvironment) {
        guard isAttached(container) else { return }
        let configuration = ReaderSwitchCandidatePresentationInput.Configuration(
            attachmentID: container.attachmentID, disabled: disabled, environment: environment)
        if let presentationInput {
            // Update the stable root's observed platform input. Assigning a new
            // UIHostingController.rootView across attachments can recreate its
            // native ScrollView even when the hosting controller stays alive.
            if presentationInput.configuration != configuration {
                #if DEBUG
                traceViewport("input.before", container: container)
                #endif
                scheduleConfiguration(configuration, on: presentationInput)
                #if DEBUG
                traceViewport("input.after", container: container)
                #endif
            }
        } else {
            #if DEBUG
            traceViewport("root.before", container: container)
            #endif
            let input = ReaderSwitchCandidatePresentationInput(configuration)
            presentationInput = input
            let root = ReaderSwitchCandidateList(state: state, currentBookID: currentBookID,
                input: input, select: { [weak self] candidate, renderedAttachmentID in
                    self?.select(candidate, renderedAttachmentID: renderedAttachmentID)
                })
            let child = ReaderSwitchCandidateHostingController(rootView: root)
            child.viewportOwner = self
            // The outer sheet already applied safe-area/keyboard geometry.
            child.safeAreaRegions = []
            child.view.backgroundColor = .clear
            hosting = child
            requestedConfiguration = configuration
            #if DEBUG
            viewportRootAssignments += 1
            traceViewport("root.after", container: container)
            #endif
        }
        invalidateChangedViewportDisplay()
        mountIfSized(container)
    }
    /// The same gate is consumed by the real row action and the finite
    /// platform-lifecycle method. A render token never adopts a later mount.
    func isCurrentRenderedAttachment(_ renderedAttachmentID: UUID) -> Bool {
        guard let container = attachment, isAttached(container),
              container.attachmentID == renderedAttachmentID,
              rootConfiguration?.attachmentID == renderedAttachmentID,
              requestedConfiguration == rootConfiguration,
              rootConfiguration?.disabled == false,
              container.bookID == currentBookID, container.viewIfLoaded?.window != nil,
              state.isCurrentDiscoveryPresentation(container.presentationID) else { return false }
        return true
    }
    private func select(_ candidate: ReaderOnlineCandidate, renderedAttachmentID: UUID) {
        guard isCurrentRenderedAttachment(renderedAttachmentID), let container = attachment,
              container.acceptsCurrentReaderInput,
              let current = state.results.first(where: { $0.id == candidate.id }),
              current.id != currentBookID else { return }
        container.select(current)
    }
    func mountIfSized(_ container: ReaderSwitchCandidateViewportController) {
        guard isAttached(container), let hosting,
              container.isViewLoaded, container.view.bounds.width > 0,
              container.view.bounds.height > 0 else { return }
        container.mount(hosting)
    }
    func detach(_ container: ReaderSwitchCandidateViewportController) {
        // An obsolete dismantle must never remove a newly attached child.
        #if DEBUG
        traceViewport("detach.before", container: container)
        #endif
        captureViewport(container)
        container.retireInput()
        container.removeHostedChild()
        if attachment === container {
            viewportRestore = nil; stopViewportInteraction()
            if let current = rootConfiguration, current.attachmentID == container.attachmentID {
                // Disable the action gate immediately. Do not publish from
                // UIKit dismantling; the next attachment will submit its own
                // configuration through scheduleConfiguration.
                requestedConfiguration = .init(attachmentID: container.attachmentID,
                    disabled: true, environment: current.environment)
            }
            cancelConfigurationCommit()
            attachment = nil
        }
        #if DEBUG
        traceViewport("detach.after", container: container)
        #endif
    }
    func endPresentation(_ identity: UUID) {
        guard let attachment, attachment.presentationID == identity else { return }
        detach(attachment)
    }
    func retire() {
        retired = true
        cancelConfigurationCommit()
        requestedConfiguration = nil
        discardViewport("retire")
        if let attachment { detach(attachment) }
        hosting = nil; presentationInput = nil
    }
    private func cancelConfigurationCommit() {
        configurationGeneration = UUID()
        configurationCommit?.cancel()
        configurationCommit = nil
    }
    private func scheduleConfiguration(
        _ configuration: ReaderSwitchCandidatePresentationInput.Configuration,
        on input: ReaderSwitchCandidatePresentationInput
    ) {
        requestedConfiguration = configuration
        configurationCommit?.cancel()
        guard input.configuration != configuration else {
            configurationCommit = nil
            return
        }
        let generation = UUID()
        configurationGeneration = generation
        configurationCommit = Task { @MainActor [weak self, weak input] in
            await Task.yield()
            guard !Task.isCancelled, let self, let input,
                  !self.retired, self.configurationGeneration == generation,
                  self.presentationInput === input,
                  self.requestedConfiguration == configuration else { return }
            input.update(configuration)
            if self.configurationGeneration == generation { self.configurationCommit = nil }
        }
    }
    private func viewportDisplay() -> ViewportDisplay {
        let rows = state.results.filter { $0.id != currentBookID }
        return ViewportDisplay(query: state.query, candidates: rows,
            sourceNames: rows.map { state.sourceName($0.sourceId) },
            timings: rows.map { state.timings[$0.sourceId] }, currentIDs: state.currentResultIDs,
            searching: state.searching)
    }
    private func invalidateChangedViewportDisplay() {
        if let snapshot = viewportSnapshot, snapshot.display != viewportDisplay() { discardViewport("display") }
    }
    private func discardViewport(_ reason: String) {
        viewportRestore = nil; viewportSnapshot = nil; stopViewportInteraction()
        #if DEBUG
        traceViewport("restore.abort." + reason)
        #endif
    }
    private func stopViewportInteraction() {
        viewportInteraction?.detach(); viewportInteraction = nil
    }
    private func nativeViewport(_ container: ReaderSwitchCandidateViewportController) -> UIScrollView? {
        guard isAttached(container), let host = hosting, host.parent === container,
              let root = host.viewIfLoaded, let window = container.viewIfLoaded?.window,
              root.window === window else { return nil }
        var pending: [(UIView,Int)] = [(root,0)], visited = Set<ObjectIdentifier>()
        var found: UIScrollView?
        while let (view,depth) = pending.popLast() {
            guard visited.insert(ObjectIdentifier(view)).inserted else { continue }
            guard visited.count <= 256, depth <= 16 else { return nil }
            if let scroll = view as? UIScrollView, scroll.window === window, !scroll.isHidden, scroll.alpha > 0 {
                guard found == nil else { return nil }; found = scroll
            }
            let children = view.subviews
            guard children.count <= 256 - visited.count - pending.count else { return nil }
            for child in children.reversed() { pending.append((child,depth + 1)) }
        }
        return found
    }
    fileprivate func captureViewport(_ container: ReaderSwitchCandidateViewportController) {
        guard isAttached(container) else { return }
        invalidateChangedViewportDisplay()
        // An interrupted reopen must retain the previous real snapshot, never
        // replace it with the new subtree's not-yet-restored default zero.
        guard viewportRestore?.attachmentID != container.attachmentID else { return }
        guard let configuration = rootConfiguration, configuration.attachmentID == container.attachmentID,
              !viewportDisplay().candidates.isEmpty else { discardViewport("captureUnavailable"); return }
        guard let scroll = nativeViewport(container) else {
            // willDisappear can capture while the native window is still
            // attached. Its later detach must not erase those known bytes
            // merely because UIKit has already removed this same window.
            if let captured = viewportSnapshot,
               captured.sourceAttachmentID == container.attachmentID,
               captured.display == viewportDisplay() { return }
            discardViewport("captureUnavailable"); return
        }
        guard !scroll.isTracking, !scroll.isDragging, !scroll.isDecelerating else { discardViewport("captureMoving"); return }
        let geometry = ViewportGeometry(scroll), epsilon = 1 / max(scroll.window?.screen.scale ?? 1, 1)
        guard geometry.bounds.width > 0, geometry.bounds.height > 0, geometry.content.height > 0,
              geometry.accepts(scroll.contentOffset, epsilon: epsilon) else { discardViewport("captureGeometry"); return }
        viewportSnapshot = ViewportSnapshot(sourceAttachmentID: container.attachmentID,
            display: viewportDisplay(), environment: configuration.environment,
            geometry: geometry, offset: scroll.contentOffset)
        #if DEBUG
        traceViewport("restore.capture", container: container)
        #endif
    }
    fileprivate func viewportHostingLayout(_ controller: UIViewController, container: ReaderSwitchCandidateViewportController) {
        guard hosting === controller, controller.parent === container, isAttached(container) else { return }
        #if DEBUG
        traceViewport("hosting.layout", container: container)
        #endif
        restoreViewport(container)
    }
    fileprivate func viewportHostingAppeared(_ controller: UIViewController, container: ReaderSwitchCandidateViewportController) {
        guard hosting === controller, controller.parent === container, isAttached(container),
              controller.viewIfLoaded?.window === container.viewIfLoaded?.window,
              container.viewIfLoaded?.window != nil,
              viewportRestore?.attachmentID == container.attachmentID else { return }
        viewportRestore?.hostAppeared = true
        restoreViewport(container)
    }
    fileprivate func viewportContainerAppeared(_ container: ReaderSwitchCandidateViewportController) {
        guard isAttached(container), viewportRestore?.attachmentID == container.attachmentID else { return }
        viewportRestore?.containerAppeared = true
        restoreViewport(container)
    }
    fileprivate func viewportUserInteracted(_ observer: ReaderSwitchViewportInteraction) {
        guard viewportInteraction === observer, let container = attachment, isAttached(container),
              viewportRestore?.attachmentID == container.attachmentID else { return }
        discardViewport("user")
    }
    private func restoreViewport(_ container: ReaderSwitchCandidateViewportController) {
        guard !applyingViewportOffset, isAttached(container), let snapshot = viewportSnapshot,
              var restore = viewportRestore, restore.snapshotID == snapshot.id,
              restore.attachmentID == container.attachmentID,
              rootConfiguration?.attachmentID == container.attachmentID else { return }
        guard snapshot.display == viewportDisplay() else { discardViewport("display"); return }
        guard let scroll = nativeViewport(container) else {
            if restore.hostAppeared && restore.containerAppeared { discardViewport("missingNative") }
            return
        }
        guard !scroll.isTracking, !scroll.isDragging, !scroll.isDecelerating else { discardViewport("user"); return }
        if viewportInteraction?.recognizer !== scroll.panGestureRecognizer {
            stopViewportInteraction()
            viewportInteraction = ReaderSwitchViewportInteraction(owner: self, recognizer: scroll.panGestureRecognizer)
        }
        let geometry = ViewportGeometry(scroll), epsilon = 1 / max(scroll.window?.screen.scale ?? 1, 1)
        let appeared = restore.hostAppeared && restore.containerAppeared
        // A zero/unfinished content layout is not yet a compatible viewport.
        // Wait only for the next public layout/appear callback, never a timer.
        guard geometry.finite, geometry.bounds.width > 0, geometry.bounds.height > 0, geometry.content.height > 0 else {
            if appeared { discardViewport("unreadyAtAppear") }; return
        }
        // Reopen's initial zero/default environment is not its final mounted
        // geometry. Only public callbacks can advance readiness; appear ends
        // this bounded attempt if final values are still incompatible.
        guard rootConfiguration?.environment == snapshot.environment,
              geometry.sameViewport(as: snapshot.geometry, epsilon: epsilon) else {
            if appeared { discardViewport("geometryAtAppear") }; return
        }
        guard geometry.sameContent(as: snapshot.geometry, epsilon: epsilon) else {
            if appeared { discardViewport("contentAtAppear") }; return
        }
        guard geometry.accepts(scroll.contentOffset, epsilon: epsilon), geometry.accepts(snapshot.offset, epsilon: epsilon) else {
            discardViewport("bounce"); return
        }
        let nativeID = ObjectIdentifier(scroll)
        if abs(scroll.contentOffset.x - snapshot.offset.x) > epsilon || abs(scroll.contentOffset.y - snapshot.offset.y) > epsilon {
            // Never repeatedly fight a native view that moved after this one
            // correction. A replacement subtree may receive its own one write.
            guard !restore.appliedNativeIDs.contains(nativeID) else { discardViewport("movedAfterRestore"); return }
            restore.appliedNativeIDs.insert(nativeID); viewportRestore = restore
            applyingViewportOffset = true
            scroll.setContentOffset(snapshot.offset, animated: false)
            applyingViewportOffset = false
            #if DEBUG
            traceViewport("restore.applied", container: container)
            #endif
        }
        // Early old-native40 does not consume pending restoration. Both real
        // appearances must have occurred with the current native view matching.
        if appeared, abs(scroll.contentOffset.x - snapshot.offset.x) <= epsilon,
           abs(scroll.contentOffset.y - snapshot.offset.y) <= epsilon {
            viewportRestore = nil; stopViewportInteraction()
            #if DEBUG
            traceViewport("restore.confirmed", container: container)
            #endif
        }
    }

}

/// Platform presentation input only: no application, session, action owner,
/// callback or native view is retained here. The hosting root observes one
/// instance for its whole cached lifetime.
@MainActor final class ReaderSwitchCandidatePresentationInput: ObservableObject {
    struct Configuration: Equatable {
        let attachmentID: UUID
        let disabled: Bool
        let environment: ReaderSwitchCandidateEnvironment
    }
    @Published private(set) var configuration: Configuration
    init(_ configuration: Configuration) { self.configuration = configuration }
    func update(_ configuration: Configuration) {
        if self.configuration != configuration { self.configuration = configuration }
    }
    func disable(attachmentID: UUID) {
        guard configuration.attachmentID == attachmentID, !configuration.disabled else { return }
        configuration = Configuration(attachmentID: attachmentID, disabled: true,
            environment: configuration.environment)
    }
}

struct ReaderSwitchCandidateEnvironment: Equatable {
    let scheme: ColorScheme
    let dynamicTypeSize: DynamicTypeSize
    let locale: Locale
    let direction: LayoutDirection
    let reduceMotion: Bool
    let legibilityWeight: LegibilityWeight?
}

struct ReaderSwitchCandidateViewport: UIViewControllerRepresentable {
    let owner: ReaderSwitchCandidateHost
    let state: ReaderOnlineWorkspaceModel
    @ObservedObject var actions: ReaderLibraryActionOwner
    let model: ReaderApplicationModel
    let sessionID: UUID
    let bookID: String
    let presentationID: UUID
    let clearQueryFocus: () -> Void
    let dismissPanel: () -> Void
    @Environment(\.colorScheme) private var scheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var direction
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.legibilityWeight) private var legibilityWeight
    func makeUIViewController(context: Context) -> ReaderSwitchCandidateViewportController {
        let controller = ReaderSwitchCandidateViewportController(owner: owner, state: state,
            sessionID: sessionID, bookID: bookID, presentationID: presentationID)
        owner.beginAttachment(controller)
        updateUIViewController(controller, context: context)
        return controller
    }
    func updateUIViewController(_ controller: ReaderSwitchCandidateViewportController, context: Context) {
        guard owner.isAttached(controller) else { return }
        controller.updateInput(model: model, clearQueryFocus: clearQueryFocus, dismissPanel: dismissPanel)
        owner.update(controller, disabled: actions.hasPending, environment: ReaderSwitchCandidateEnvironment(
            scheme: scheme, dynamicTypeSize: dynamicTypeSize, locale: locale,
            direction: direction, reduceMotion: reduceMotion, legibilityWeight: legibilityWeight))
    }
    static func dismantleUIViewController(_ controller: ReaderSwitchCandidateViewportController, coordinator: ()) {
        controller.owner.detach(controller)
    }
}

@MainActor final class ReaderSwitchCandidateViewportController: UIViewController {
    let owner: ReaderSwitchCandidateHost
    let attachmentID = UUID()
    private let state: ReaderOnlineWorkspaceModel
    let sessionID: UUID
    let bookID: String
    let presentationID: UUID
    private weak var model: ReaderApplicationModel?
    private var clearQueryFocus: (() -> Void)?
    private var dismissPanel: (() -> Void)?
    private weak var hostedChild: UIViewController?
    private var childConstraints: [NSLayoutConstraint] = []
    init(owner: ReaderSwitchCandidateHost, state: ReaderOnlineWorkspaceModel,
         sessionID: UUID, bookID: String, presentationID: UUID) {
        self.owner = owner; self.state = state; self.sessionID = sessionID
        self.bookID = bookID; self.presentationID = presentationID
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func loadView() { view = UIView(); view.backgroundColor = .clear }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        #if DEBUG
        owner.traceViewport("willAppear", container: self)
        #endif
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        owner.viewportContainerAppeared(self)
        #if DEBUG
        owner.traceViewport("didAppear", container: self)
        #endif
    }
    override func viewWillDisappear(_ animated: Bool) {
        owner.captureViewport(self)
        super.viewWillDisappear(animated)
        #if DEBUG
        owner.traceViewport("willDisappear", container: self)
        #endif
    }
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        #if DEBUG
        owner.traceViewport("didDisappear", container: self)
        #endif
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // Retain the last real child size while detached; never size the cached
        // ScrollView to a new container's initial zero rectangle.
        owner.mountIfSized(self)
        #if DEBUG
        owner.traceViewport("layout", container: self)
        #endif
    }
    func updateInput(model: ReaderApplicationModel, clearQueryFocus: @escaping () -> Void,
                     dismissPanel: @escaping () -> Void) {
        self.model = model; self.clearQueryFocus = clearQueryFocus; self.dismissPanel = dismissPanel
    }
    func retireInput() { model = nil; clearQueryFocus = nil; dismissPanel = nil }
    func mount(_ child: UIViewController) {
        guard hostedChild !== child, child.parent == nil else { return }
        #if DEBUG
        owner.traceViewport("mount.before", container: self)
        #endif
        addChild(child)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        child.view.frame = view.bounds
        #if DEBUG
        owner.traceViewport("mount.after-frame", container: self)
        #endif
        view.addSubview(child.view)
        childConstraints = [child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)]
        NSLayoutConstraint.activate(childConstraints)
        hostedChild = child
        child.didMove(toParent: self)
        #if DEBUG
        owner.traceViewport("mount.after", container: self)
        #endif
    }
    func removeHostedChild() {
        guard let child = hostedChild, child.parent === self else { return }
        #if DEBUG
        owner.traceViewport("remove.before", container: self)
        #endif
        child.willMove(toParent: nil)
        NSLayoutConstraint.deactivate(childConstraints); childConstraints = []
        child.view.removeFromSuperview()
        child.removeFromParent()
        hostedChild = nil
        #if DEBUG
        owner.traceViewport("remove.after", container: self)
        #endif
    }
    fileprivate var acceptsCurrentReaderInput: Bool {
        guard let model else { return false }
        return model.reader?.id == sessionID && model.reader?.book.id == bookID && !model.actions.hasPending
    }
    func select(_ candidate: ReaderOnlineCandidate) {
        guard owner.isAttached(self), viewIfLoaded?.window != nil,
              state.isCurrentDiscoveryPresentation(presentationID), let model,
              model.reader?.id == sessionID, model.reader?.book.id == bookID,
              !model.actions.hasPending else { return }
        clearQueryFocus?()
        let originalSessionID = sessionID, originalBookID = bookID
        Task { [weak self, model] in
            guard self?.selectionIsCurrent == true, model.reader?.id == originalSessionID,
                  model.reader?.book.id == originalBookID else { return }
            // Acceptance is still owned by the original model/ActionOwner. A
            // sheet dismissal or cache eviction must not cancel/replay it.
            let completed = await model.actions.perform("切换书源", scope: originalBookID) { [model] id in
                try await model.switchOnlineSource(candidate, operationID: id)
            }
            if completed { self?.dismissIfCurrent() }
        }
    }
    private var selectionIsCurrent: Bool {
        owner.isAttached(self) && viewIfLoaded?.window != nil &&
            state.isCurrentDiscoveryPresentation(presentationID)
    }
    private func dismissIfCurrent() {
        guard selectionIsCurrent, viewIfLoaded?.window != nil else { return }
        dismissPanel?()
    }
}

@MainActor final class ReaderSwitchCandidateHostingController: UIHostingController<ReaderSwitchCandidateList> {
    weak var viewportOwner: ReaderSwitchCandidateHost?
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if let container = parent as? ReaderSwitchCandidateViewportController {
            viewportOwner?.viewportHostingLayout(self, container: container)
        }
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let container = parent as? ReaderSwitchCandidateViewportController {
            viewportOwner?.viewportHostingAppeared(self, container: container)
        }
    }
}

@MainActor fileprivate final class ReaderSwitchViewportInteraction: NSObject {
    private weak var owner: ReaderSwitchCandidateHost?
    fileprivate weak var recognizer: UIPanGestureRecognizer?
    init(owner: ReaderSwitchCandidateHost, recognizer: UIPanGestureRecognizer) {
        self.owner = owner; self.recognizer = recognizer
        super.init(); recognizer.addTarget(self, action: #selector(changed(_:)))
    }
    func detach() { recognizer?.removeTarget(self, action: #selector(changed(_:))); recognizer = nil }
    @objc private func changed(_ recognizer: UIPanGestureRecognizer) {
        guard self.recognizer === recognizer else { return }
        if recognizer.state == .began || recognizer.state == .changed { owner?.viewportUserInteracted(self) }
    }
}

struct ReaderSwitchCandidateList: View {
    @ObservedObject var state: ReaderOnlineWorkspaceModel
    let currentBookID: String
    @ObservedObject var input: ReaderSwitchCandidatePresentationInput
    let select: (ReaderOnlineCandidate, UUID) -> Void
    private var candidates: [ReaderOnlineCandidate] { state.results.filter { $0.id != currentBookID } }
    var body: some View {
        // Value snapshot for this render. In particular, the action must not
        // read input.configuration at tap time and adopt a new attachment.
        let configuration = input.configuration
        let appearance = configuration.environment
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(candidates) { candidate in
                    Button { select(candidate, configuration.attachmentID) } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(candidate.title).font(ReaderTypography.font(.controlHeader))
                                Text(candidate.author).font(ReaderTypography.font(.caption))
                                Text(state.sourceName(candidate.sourceId) + (state.timings[candidate.sourceId].map { " · \($0) ms" } ?? "")).font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(appearance.scheme).muted)
                                if !state.currentResultIDs.contains(candidate.id) { Text(state.searching ? "上次候选 · 本次搜索中" : "上次候选 · 本次未确认").font(ReaderTypography.font(.caption)) }
                            }
                            Spacer(); ReaderIcon(.chevronRight)
                        }.padding(18).contentShape(Rectangle())
                    }.buttonStyle(ReaderPressFeedback()).disabled(configuration.disabled)
                        .id(candidate.id)
                        .accessibilityIdentifier("online-switch-candidate:" + candidate.id)
                    Divider()
                }
            }.scrollTargetLayout()
        }
            .environment(\.colorScheme, appearance.scheme)
            .environment(\.dynamicTypeSize, appearance.dynamicTypeSize)
            .environment(\.locale, appearance.locale)
            .environment(\.layoutDirection, appearance.direction)
            // Reduce Motion is a read-only system environment value. The native
            // hosting child receives it through UIKit/SwiftUI accessibility.
            .environment(\.legibilityWeight, appearance.legibilityWeight)
    }
}

struct ReaderOnlineDownloadPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    let session: ReaderActiveSession
    @StateObject private var downloadActions: ReaderDownloadControlOwner
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @State private var status: ReaderDownloadStatus?
    @State private var start = "1"
    @State private var end = "1"
    @State private var failure: String?
    @State private var selected = Set<UInt32>()
    @State private var updatingCatalog = false
    @State private var catalogFeedback: String?
    @State private var batchFeedback: String?
    @State private var catalogGeneration = UUID()
    @State private var catalogTask: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase

    init(model: ReaderApplicationModel, session: ReaderActiveSession) {
        self.model = model
        self.session = session
        _downloadActions = StateObject(wrappedValue: ReaderDownloadControlOwner(
            pendingChecker: { [weak actions = model.actions] id in
                guard let checker = actions?.pendingChecker else { return nil }
                return await checker(id)
            }
        ))
    }

    private var service: (any ReaderDownloadServing)? { model.libraryService as? any ReaderDownloadServing }
    var body: some View {
        VStack(spacing: 14) {
            HStack { Button("关闭") { dismiss() }.accessibilityIdentifier("online-download-close"); Spacer(); Text("下载管理").font(ReaderTypography.font(.controlHeader)); Spacer(); Button("刷新") { Task { await refresh() } } }.padding(.horizontal, 20)
            Button(updatingCatalog ? "正在取得目录" : "更新在线目录") { updateCatalog() }.disabled(model.actions.hasPending || updatingCatalog)
                .accessibilityIdentifier("online-update-catalog")
            if let catalogFeedback { Text(catalogFeedback).font(ReaderTypography.font(.caption)).accessibilityIdentifier("online-catalog-feedback") }
            if let status {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Text(session.book.title).font(ReaderTypography.font(.controlHeader))
                        Text("已完成 \(status.completedCount) · 缓存 \(status.cachedCount) · 失败 \(status.failedCount) · 暂停 \(status.pausedCount)").font(ReaderTypography.font(.caption))
                        HStack { TextField("起章", text: $start).keyboardType(.numberPad).readerField(); Text("至"); TextField("末章", text: $end).keyboardType(.numberPad).readerField(); Button("下载") { downloadRange() } }
                        HStack { Button("整本下载") { download(0..<status.chapterCount) }; Spacer(); Button("下载所选") { downloadSelected() }.disabled(selected.isEmpty).accessibilityIdentifier("online-download-selected") }.disabled(model.actions.hasPending)
                        if let batchFeedback { Text(batchFeedback).font(ReaderTypography.font(.caption)) }
                        Text("阅读前后章缓存与主动下载分别记账。清理自动缓存保留已完成下载及当前章。").font(ReaderTypography.font(.caption))
                        if let storage = downloadActions.storage {
                            Text("可清理自动正文 \(ByteCountFormatter.string(fromByteCount: Int64(clamping: storage.cleanableBytes), countStyle: .file))").font(ReaderTypography.font(.caption))
                            Button("清理自动缓存") { confirmation.confirm("清理自动缓存？", message: "保留当前章和已完成下载；书架、阅读位置及原书不变。", actionTitle: "清理") { cleanup() } }.disabled(model.actions.hasPending)
                        }
                        if let result = downloadActions.cleanupResult, result.scope == session.book.id {
                            ReaderPageState(title: result.title, detail: result.detail)
                                .accessibilityIdentifier("online-cache-cleanup-result")
                        }
                        ForEach(status.chapters) { chapter in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Toggle(isOn: Binding(get: { selected.contains(chapter.chapterIndex) }, set: { value in if value { selected.insert(chapter.chapterIndex) } else { selected.remove(chapter.chapterIndex) } })) { Text(chapter.title) }.toggleStyle(.button)
                                        .accessibilityIdentifier("online-download-select:" + session.book.id + ":" + String(chapter.chapterIndex))
                                    Spacer(); Text(label(chapter.state)).font(ReaderTypography.font(.caption))
                                        .accessibilityIdentifier("online-download-state:" + session.book.id + ":" + String(chapter.chapterIndex))
                                }
                                if let error = chapter.lastError { Text(error).font(ReaderTypography.font(.caption)) }
                                HStack {
                                    if [.queued, .inProgress].contains(chapter.state) {
                                        Button("暂停") { task(chapter, action: .pause) }
                                            .disabled(!downloadActions.canControl)
                                            .accessibilityIdentifier("online-download-pause:" + session.book.id + ":" + String(chapter.chapterIndex))
                                    }
                                    if [.paused, .failed, .cancelled].contains(chapter.state) {
                                        Button(chapter.state == .failed ? "重试" : "继续") { task(chapter, action: .resume) }
                                            .disabled(!downloadActions.canResume)
                                            .accessibilityIdentifier("online-download-resume:" + session.book.id + ":" + String(chapter.chapterIndex))
                                    }
                                    if [.queued, .inProgress, .paused].contains(chapter.state) {
                                        Button("取消任务") { task(chapter, action: .cancel) }
                                            .disabled(!downloadActions.canControl)
                                            .accessibilityIdentifier("online-download-cancel:" + session.book.id + ":" + String(chapter.chapterIndex))
                                    }
                                    if chapter.chapterIndex != session.content.chapterIndex,
                                       [.cached, .completed, .failed, .cancelled, .paused].contains(chapter.state) {
                                        Button("清除此章下载") {
                                            confirmation.confirm("清除此章下载？", message: "删除此章缓存正文、下载任务及对应图片副本。书架、目录和阅读位置保留。", actionTitle: "清除") {
                                                clearChapter(chapter)
                                            }
                                        }
                                        .disabled(!downloadActions.canClear)
                                    }
                                }.font(ReaderTypography.font(.caption))
                            }.padding(.vertical, 8)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("online-download-attempt:" + session.book.id + ":" + String(chapter.chapterIndex) + ":" + String(chapter.attempts))
                            Divider()
                        }
                    }.padding(20)
                }.accessibilityIdentifier("online-download-scroll")
            } else { ReaderPageState(title: failure == nil ? "正在加载下载状态" : "下载状态不可用", detail: failure ?? "", loading: failure == nil) }
            if let failure, status != nil { ReaderPageState(title: "下载管理未完成", detail: failure).padding(.horizontal, 20) }
            ReaderOperationStatus(owner: model.actions, scope: session.book.id)
            ReaderOperationStatus(owner: downloadActions.resumeActions, scope: session.book.id)
            ReaderOperationStatus(owner: downloadActions.controlActions, scope: session.book.id)
        }.padding(.vertical, 20).readerConfirmation(confirmation)
            .task(id: phase) {
                guard phase == .active else { return }
                await refresh()
                while !Task.isCancelled { try? await Task.sleep(nanoseconds: 2_000_000_000); if !Task.isCancelled { await refresh() } }
            }
            .onChange(of: phase) { value in if value != .active { cancelCatalogRead() } }
            .onDisappear { cancelCatalogRead(); downloadActions.retireStorageCleanupPresentation() }
    }
    private func refresh() async {
        guard let service else { return }
        do {
            let value = try await service.readerDownloadStatus(session.book)
            try Task.checkCancellation(); status = value
            if end == "1" { end = String(value.chapterCount) }
            let summary = try await service.readerStorageSummary(protected: [.init(book: session.book, chapterIndex: session.content.chapterIndex)])
            try Task.checkCancellation()
            downloadActions.receiveStorageSummary(summary)
            failure = nil
        } catch is CancellationError { } catch { failure = error.localizedDescription }
    }
    private func updateCatalog() {
        guard !updatingCatalog, model.libraryService is any ReaderOnlineServing else { return }
        let generation = UUID(); catalogGeneration = generation
        updatingCatalog = true; catalogFeedback = nil
        catalogTask = Task {
            do {
                let detail = try await model.refreshOnlineCatalog(sessionID: session.id, bookID: session.book.id)
                try Task.checkCancellation()
                guard catalogGeneration == generation else { return }
                catalogFeedback = "已取得目录，共 \(detail.chapters.count) 章"
                await refresh()
            } catch is CancellationError { } catch {
                guard !Task.isCancelled, catalogGeneration == generation else { return }
                failure = error.localizedDescription
            }
            guard catalogGeneration == generation else { return }
            updatingCatalog = false; catalogTask = nil
        }
    }
    private func cancelCatalogRead() {
        catalogTask?.cancel(); catalogTask = nil; catalogGeneration = UUID(); updatingCatalog = false
    }
    private func downloadRange() {
        guard let lower = UInt32(start), let upper = UInt32(end), lower > 0, upper >= lower, let status, upper <= status.chapterCount else { failure = "请输入目录范围内的起止章节"; return }
        download((lower - 1)..<upper)
    }
    private func download(_ range: Range<UInt32>) {
        guard let service, !range.isEmpty else { return }
        Task { _ = await model.actions.perform("下载章节", scope: session.book.id) { id in _ = try await service.downloadChapters(session.book, range: range, operationID: id) }; await refresh() }
    }
    private func downloadSelected() {
        guard let service else { return }; let indexes = selected.sorted()
        Task {
            var completed = 0
            for index in indexes where index < UInt32.max {
                // Each accepted chapter has its own real operation owner.
                // Stop at an unresolved write and retain the remaining selection.
                let confirmed = await model.actions.perform("下载所选章节", scope: session.book.id) { id in
                    _ = try await service.downloadChapters(session.book, range: index..<(index + 1), operationID: id)
                }
                guard confirmed else {
                    batchFeedback = "已处理 \(completed) 章，其余 \(indexes.count - completed) 章未完成；所选章节保留。"
                    await refresh(); return
                }
                completed += 1
            }
            batchFeedback = "已处理 \(completed) 章，具体完成或失败状态见下方列表。"
            await refresh()
        }
    }
    private enum TaskAction { case pause, resume, cancel }
    private func task(_ chapter: ReaderDownloadChapter, action: TaskAction) {
        guard let service else { return }
        Task {
            let operation: (String) async throws -> Void = { id in
                switch action {
                case .pause: _ = try await service.pauseDownload(session.book, chapterIndex: chapter.chapterIndex, operationID: id)
                case .resume: _ = try await service.resumeDownload(session.book, chapterIndex: chapter.chapterIndex, operationID: id)
                case .cancel: _ = try await service.cancelDownload(session.book, chapterIndex: chapter.chapterIndex, operationID: id)
                }
            }
            switch action {
            case .resume: _ = await downloadActions.performResume(scope: session.book.id, action: operation)
            case .pause, .cancel: _ = await downloadActions.performControl(scope: session.book.id, action: operation)
            }
            await refresh()
        }
    }
    private func cleanup() {
        guard let service else { return }
        let presentationID = downloadActions.cleanupPresentationID
        Task { _ = await model.actions.perform("清理缓存", scope: session.book.id) { id in
            downloadActions.beginStorageCleanup(operationID: id, scope: session.book.id, presentationID: presentationID)
            let result = try await service.cleanupReaderStorage(retained: [], protected: [.init(book: session.book, chapterIndex: session.content.chapterIndex)], operationID: id)
            downloadActions.receiveStorageCleanupReceipt(result, operationID: id, scope: session.book.id, presentationID: presentationID)
        }; await refresh() }
    }
    private func clearChapter(_ chapter: ReaderDownloadChapter) {
        guard let service, chapter.chapterIndex != session.content.chapterIndex else { return }
        Task {
            _ = await downloadActions.performClear(scope: session.book.id) { id in
                try await service.clearDownloadedChapter(session.book, chapterIndex: chapter.chapterIndex, operationID: id)
            }
            await refresh()
        }
    }
    private func label(_ state: ReaderDownloadChapterState) -> String {
        switch state {
        case .missing: return "未下载"; case .queued: return "排队中"; case .paused: return "已暂停"; case .inProgress: return "下载中"
        case .cached: return "阅读缓存"; case .completed: return "已完成"; case .failed: return "失败"; case .cancelled: return "已取消"
        }
    }
}
