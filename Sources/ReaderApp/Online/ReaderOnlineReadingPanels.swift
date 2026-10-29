import SwiftUI
import UIKit
#if DEBUG
import OSLog
import CryptoKit
#endif

/// Bounded presentation cache: candidates/query/timing survive closing the
/// switch sheet. Core remains the owner of books, catalogs and transactions.
@MainActor final class ReaderSwitchPresentationCache {
    static let shared = ReaderSwitchPresentationCache()
    private struct Entry {
        let state: ReaderOnlineWorkspaceModel
        let candidates: ReaderSwitchCandidateHost
        #if DEBUG
        let evidence: ReaderOnlineSearchEvidence
        #endif
    }
    private var entries: [String: Entry] = [:]
    private var order: [String] = []
    func state(for identity: String, initialQuery: String) -> ReaderOnlineWorkspaceModel {
        entry(for: identity, initialQuery: initialQuery).state
    }
    func candidateHost(for identity: String, initialQuery: String) -> ReaderSwitchCandidateHost {
        entry(for: identity, initialQuery: initialQuery).candidates
    }
    #if DEBUG
    func searchEvidence(for identity: String, initialQuery: String) -> ReaderOnlineSearchEvidence {
        entry(for: identity, initialQuery: initialQuery).evidence
    }
    #endif
    private func entry(for identity: String, initialQuery: String) -> Entry {
        if let entry = entries[identity] { return entry }
        let state = ReaderOnlineWorkspaceModel(); state.query = initialQuery
        #if DEBUG
        let evidence = ReaderOnlineSearchEvidence(attachingTo: state, expectedMode: ReaderOnlineSearchEvidence.switchMode)
        let entry = Entry(state: state, candidates: ReaderSwitchCandidateHost(state: state, currentBookID: identity), evidence: evidence)
        #else
        let entry = Entry(state: state, candidates: ReaderSwitchCandidateHost(state: state, currentBookID: identity))
        #endif
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

#if DEBUG
/// Only the selected physical search mode observes its existing production
/// workspace. No source, request, cancellation or persistence owner is changed.
@MainActor final class ReaderOnlineSearchEvidence: ObservableObject {
    nonisolated static let switchMode = "physical-v4-04-search-trace-v1"
    nonisolated static let globalMode = "physical-v4-02-search-trace-v1"
    nonisolated static let globalHeaderIdentifier = "online-search-trace-owner"
    private static var attachedWorkspace = false
    @Published private(set) var proof = ""
    let enabled: Bool
    private var publishedVersion = 0

    init(attachingTo state: ReaderOnlineWorkspaceModel, expectedMode: String) {
        let environment = ProcessInfo.processInfo.environment
        #if targetEnvironment(simulator)
        enabled = false
        #else
        enabled = [Self.switchMode, Self.globalMode].contains(expectedMode)
            && environment["READER_V4_SEARCH_TRACE_MODE"] == expectedMode
            && !Self.attachedWorkspace && state.searchTraceSink == nil
            && environment["READER_V4_SEARCH_TRACE_RUN_ID"].flatMap(UUID.init(uuidString:)).map {
                $0.uuidString.lowercased() == environment["READER_V4_SEARCH_TRACE_RUN_ID"]
            } == true
            && Bundle.main.bundleIdentifier == "io.reader.minliny.free"
            && UIDevice.current.userInterfaceIdiom == .phone && environment["SIMULATOR_UDID"] == nil
        #endif
        guard enabled, let runID = environment["READER_V4_SEARCH_TRACE_RUN_ID"], state.searchTraceSink == nil else { return }
        Self.attachedWorkspace = true
        let collector = ReaderOnlineSearchTraceCollector(mode: expectedMode, runID: runID) { [weak self] value, version in
            Task { @MainActor [weak self] in
                guard let self, version > self.publishedVersion else { return }
                self.publishedVersion = version; self.proof = value
            }
        }
        state.searchTraceSink = { collector.receive($0) }
    }
}

/// The sink only admits bounded values under a short memory lock. A single
/// coalescing writer performs all encoding and I/O off the observed executors.
/// A captured snapshot proves observed event closure, never network freshness
/// or worker quiescence. Late Host events revise the same owned snapshot.
private final class ReaderOnlineSearchTraceCollector: @unchecked Sendable {
    private struct Buffer {
        var events: [UInt32: ReaderSearchTraceEvent] = [:]
        var exportRequested = false
    }
    private struct Generation: Encodable {
        let searchID: UUID
        let events: [ReaderSearchTraceEvent]
        let sequenceContiguous: Bool
        let observerFinished: Bool
        let observedCallsClosed: Bool
        let coreExecutionRetirementProven: Bool
        let sourceBindingsWellFormed: Bool
        let transportAttempted: Bool
        let httpNetworkLoadCount: Int
        let httpLocalCacheCount: Int
        let incomplete: Bool
    }
    private struct Snapshot: Encodable {
        let schemaVersion = 3
        let mode: String
        let runID: String
        let version: Int
        let status: String
        let transportQuiescenceProven = false
        let collectorLimited: Bool
        let generations: [Generation]
    }
    private struct Proof: Encodable {
        let r: String; let g: String; let n: Int; let e: Int; let f: Int
        let c: Int? // Only global mode adds strict Core-retired generation count.
        let s: String; let h: String; let v: Int
    }
    private let mode: String
    private let runID: String
    private let publish: @Sendable (String, Int) -> Void
    private let lock = NSLock()
    private let writer = DispatchQueue(label: "io.reader.minliny.v4-search-trace", qos: .utility)
    private var buffers: [UUID: Buffer] = [:]
    private var order: [UUID] = []
    private var version = 0
    private var dirtyVersion = 0
    private var scheduled = false
    private var limited = false
    private var failed = false
    // Writer-only ownership; no caller supplies a path or accesses business data.
    private var directory: URL?
    private var marker: Data?

    init(mode: String, runID: String, publish: @escaping @Sendable (String, Int) -> Void) {
        self.mode = mode; self.runID = runID; self.publish = publish
    }
    func receive(_ event: ReaderSearchTraceEvent) {
        let enqueue: Bool = lock.withLock {
            guard !failed else { return false }
            if buffers[event.searchID] == nil {
                guard order.count < 2 else {
                    guard !limited else { return false }
                    limited = true; version += 1; dirtyVersion = version
                    if scheduled { return false }; scheduled = true; return true
                }
                order.append(event.searchID); buffers[event.searchID] = Buffer()
            }
            guard (1...2048).contains(event.sequence), buffers[event.searchID]?.events[event.sequence] == nil else {
                guard !limited else { return false }
                limited = true; version += 1; dirtyVersion = version
                if scheduled { return false }; scheduled = true; return true
            }
            buffers[event.searchID]?.events[event.sequence] = event; version += 1
            if [.generationFinished, .generationStopped, .traceLimitReached].contains(event.stage) {
                buffers[event.searchID]?.exportRequested = true
            }
            guard buffers[event.searchID]?.exportRequested == true else { return false }
            dirtyVersion = version
            guard !scheduled else { return false }; scheduled = true; return true
        }
        if enqueue { writer.async { self.writeSnapshots() } }
    }
    private func writeSnapshots() {
        while true {
            let input = lock.withLock { (buffers, order, version, dirtyVersion, limited) }
            let generations = input.1.compactMap { id in input.0[id].map { generation(id, events: Array($0.events.values)) } }
            let status = input.4 || generations.contains(where: \.incomplete) ? "incomplete" : "captured"
            let snapshot = Snapshot(mode: mode, runID: runID, version: input.2, status: status,
                collectorLimited: input.4, generations: generations)
            do {
                let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
                let bytes = try encoder.encode(snapshot)
                try write(bytes)
                let sha = SHA256.hash(data: bytes).map { String(format: "%02x", $0) }.joined()
                let proof = Proof(r: runID, g: input.1.last?.uuidString.lowercased() ?? "", n: generations.count,
                    e: generations.reduce(0) { $0 + $1.events.count }, f: generations.filter(\.observerFinished).count,
                    c: mode == ReaderOnlineSearchEvidence.globalMode ? generations.filter(\.coreExecutionRetirementProven).count : nil,
                    s: status, h: sha, v: input.2)
                let value = try encoder.encode(proof)
                guard value.count <= 256 else { throw CocoaError(.fileWriteUnknown) }
                let settled = lock.withLock { () -> Bool in
                    guard dirtyVersion == input.3 else { return false }; scheduled = false; return true
                }
                if settled { publish(String(decoding: value, as: UTF8.self), input.2); return }
            } catch {
                lock.withLock { failed = true; scheduled = false }
                // Do not expose errors that can contain paths or source URLs.
                let value = Proof(r: runID, g: "", n: generations.count, e: 0, f: 0,
                    c: mode == ReaderOnlineSearchEvidence.globalMode ? 0 : nil, s: "write_failed", h: "", v: input.2)
                if let bytes = try? JSONEncoder().encode(value), bytes.count <= 256 {
                    publish(String(decoding: bytes, as: UTF8.self), input.2)
                }
                return
            }
        }
    }
    private func generation(_ id: UUID, events input: [ReaderSearchTraceEvent]) -> Generation {
        let events = input.sorted { $0.sequence < $1.sequence }
        let contiguous = events.enumerated().allSatisfy { $0.element.sequence == UInt32($0.offset + 1) }
        let finished = events.filter { $0.stage == .generationFinished }.count == 1
        func balanced(_ start: ReaderSearchTraceEvent.Stage, _ end: ReaderSearchTraceEvent.Stage,
                      key: (ReaderSearchTraceEvent) -> String?) -> Bool {
            let a = events.filter { $0.stage == start }, b = events.filter { $0.stage == end }
            let x = a.compactMap(key), y = b.compactMap(key)
            return a.count == x.count && b.count == y.count && x.count == Set(x).count
                && y.count == Set(y).count && Set(x) == Set(y)
        }
        func request(_ e: ReaderSearchTraceEvent) -> String? { e.coreRequestID.map(String.init) }
        func host(_ e: ReaderSearchTraceEvent) -> String? {
            guard let r = e.coreRequestID, let h = e.hostOperationID else { return nil }; return "\(r):\(h)"
        }
        func http(_ e: ReaderSearchTraceEvent) -> String? {
            guard let h = host(e), let t = e.taskIdentifier, let a = e.transportAttempt else { return nil }; return "\(h):\(t):\(a)"
        }
        let httpStarts = events.filter { $0.stage == .httpTaskResumeAttempted }
        let httpCompletions = events.filter { $0.stage == .httpTaskCompleted }
        let httpMetrics = events.filter { $0.stage == .httpTaskMetricsCollected }
        let completionSequences = Dictionary(httpCompletions.compactMap { e in http(e).map { ($0, e.sequence) } },
                                             uniquingKeysWith: { first, _ in first })
        let metricsSequences = Dictionary(httpMetrics.compactMap { e in http(e).map { ($0, e.sequence) } },
                                          uniquingKeysWith: { first, _ in first })
        let httpOrdered = httpStarts.allSatisfy { start in
            guard let key = http(start), let completed = completionSequences[key],
                  let collected = metricsSequences[key] else { return false }
            return start.sequence < completed && start.sequence < collected
        }
        let metricsValid = httpMetrics.allSatisfy { e in
            guard let value = e.httpFetchSummary else { return false }
            let counts = [value.networkLoadCount, value.localCacheCount,
                          value.serverPushCount, value.unknownCount]
            return (0...64).contains(value.transactionCount) && counts.allSatisfy { $0 >= 0 }
                && counts.reduce(0, +) == value.transactionCount
        }
        let closed = balanced(.sourceAttemptStarted, .sourceAttemptFinished, key: { $0.sourceOrdinal.map(String.init) })
            && balanced(.coreSent, .coreObservationEnded, key: request)
            && balanced(.coreSent, .coreTerminal, key: request)
            && balanced(.hostOperationStarted, .hostOperationFinished, key: host)
            && balanced(.httpTaskResumeAttempted, .httpTaskCompleted, key: http)
            && balanced(.httpTaskResumeAttempted, .httpTaskMetricsCollected, key: http)
            && balanced(.webViewRunStarted, .webViewRunCompleted, key: host)
        let executionEnds = events.filter { $0.stage == .coreExecutionObservationEnded }
        let coreExecutionRetirementProven = events.contains { $0.stage == .coreSent }
            && balanced(.coreSent, .coreExecutionObservationStarted, key: request)
            && balanced(.coreExecutionObservationStarted, .coreExecutionObservationEnded, key: request)
            && executionEnds.allSatisfy { end in
                guard end.coreExecutionObservationOutcome == .retired,
                      let summary = end.coreExecutionSummary, summary.requestId == end.coreRequestID,
                      summary.isStrictlyRetired else { return false }
                let snapshots = events.filter { $0.stage == .coreExecutionSnapshotObserved && $0.coreRequestID == end.coreRequestID }
                return !snapshots.isEmpty && snapshots.allSatisfy { $0.coreExecutionSummary?.requestId == summary.requestId
                    && $0.coreExecutionSummary?.generation == summary.generation }
            }
        let starts = events.filter { $0.stage == .generationStarted }
        let expected = starts.first?.count ?? 0
        let attempts = events.filter { $0.stage == .sourceAttemptStarted }
        let allSources = expected > 0 && expected <= 2048 && attempts.count == expected
            && Set(attempts.compactMap(\.sourceOrdinal)) == Set((1...max(1, min(expected, 2048))).map(UInt32.init))
        let sourceBindingsWellFormed = attempts.allSatisfy { event in
            guard let binding = event.sourceBinding,
                  binding.contract == .sourceProjectionSHA256V1 else { return false }
            return binding.sha256.utf8.count == 64 && binding.sha256.utf8.allSatisfy {
                (48...57).contains($0) || (97...102).contains($0)
            }
        } && Set(attempts.compactMap { $0.sourceBinding?.sha256 }).count == attempts.count
        let transportAttempted = !httpStarts.isEmpty || events.contains { $0.stage == .webViewRunStarted }
        let incomplete = !contiguous || !finished || !closed || !coreExecutionRetirementProven || !httpOrdered || !metricsValid
            || starts.count != 1 || !allSources || !sourceBindingsWellFormed
            || events.contains { [.generationStopped, .traceLimitReached, .coreSendFailed,
                                  .httpTaskMetricsUnavailable].contains($0.stage) }
        return Generation(searchID: id, events: events, sequenceContiguous: contiguous,
            observerFinished: finished, observedCallsClosed: closed, coreExecutionRetirementProven: coreExecutionRetirementProven,
            sourceBindingsWellFormed: sourceBindingsWellFormed, transportAttempted: transportAttempted,
            httpNetworkLoadCount: httpMetrics.reduce(0) { $0 + ($1.httpFetchSummary?.networkLoadCount ?? 0) },
            httpLocalCacheCount: httpMetrics.reduce(0) { $0 + ($1.httpFetchSummary?.localCacheCount ?? 0) },
            incomplete: incomplete)
    }
    private func write(_ bytes: Data) throws {
        let manager = FileManager.default
        if directory == nil {
            let root = manager.temporaryDirectory.standardizedFileURL.resolvingSymlinksInPath()
                .appendingPathComponent((mode == ReaderOnlineSearchEvidence.switchMode ? "ReaderSwitchSearchTrace-" : "ReaderOnlineSearchTrace-") + runID,
                                        isDirectory: true)
            guard !manager.fileExists(atPath: root.path) else { throw CocoaError(.fileWriteFileExists) }
            try manager.createDirectory(at: root, withIntermediateDirectories: false)
            let owner = try JSONSerialization.data(withJSONObject: ["mode": mode, "runID": runID], options: [.sortedKeys])
            try owner.write(to: root.appendingPathComponent("owner.json"), options: .withoutOverwriting)
            directory = root; marker = owner
        }
        guard let directory, let marker else { throw CocoaError(.fileWriteUnknown) }
        let values = try directory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
        guard values.isDirectory == true, values.isSymbolicLink != true,
              directory.resolvingSymlinksInPath() == directory,
              try Data(contentsOf: directory.appendingPathComponent("owner.json")) == marker else {
            throw CocoaError(.fileWriteUnknown)
        }
        try bytes.write(to: directory.appendingPathComponent("trace.json"), options: [.atomic, .completeFileProtection])
    }
}
#endif

struct ReaderOnlineSwitchPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    let session: ReaderActiveSession
    @StateObject private var state: ReaderOnlineWorkspaceModel
    @State private var discoveryPresentationID = UUID()
    @State private var candidateHost: ReaderSwitchCandidateHost
    #if DEBUG
    @ObservedObject private var searchEvidence: ReaderOnlineSearchEvidence
    #endif
    @FocusState private var queryFocused: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    init(model: ReaderApplicationModel, preferences: ReaderPreferences, session: ReaderActiveSession) {
        self.model = model; self.preferences = preferences; self.session = session
        let cache = ReaderSwitchPresentationCache.shared
        _state = StateObject(wrappedValue: cache.state(for: session.book.id, initialQuery: session.book.title))
        _candidateHost = State(initialValue: cache.candidateHost(for: session.book.id, initialQuery: session.book.title))
        #if DEBUG
        _searchEvidence = ObservedObject(wrappedValue: cache.searchEvidence(for: session.book.id, initialQuery: session.book.title))
        #endif
    }
    var body: some View {
        let presentationID = discoveryPresentationID
        let queryFocus = $queryFocused
        let dismissAction = dismiss
        VStack(spacing: 12) {
            HStack {
                Button("关闭") { queryFocused = false; dismiss() }.accessibilityIdentifier("online-switch-close")
                Spacer()
                #if DEBUG
                if searchEvidence.enabled { ownerTitle.accessibilityValue(searchEvidence.proof) }
                else { ownerTitle }
                #else
                ownerTitle
                #endif
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
    private var ownerTitle: some View {
        Text("切换书源").font(ReaderTypography.font(.controlHeader))
            .accessibilityIdentifier("online-switch-owner:\(model.actions.busy ? "busy" : model.actions.hasPending ? "pending" : "settled")")
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
            timings: rows.map { state.candidateElapsedMilliseconds($0) }, currentIDs: state.currentResultIDs,
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
                                Text(state.sourceName(candidate.sourceId) + (state.candidateElapsedMilliseconds(candidate).map { " · \($0) ms" } ?? "")).font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(appearance.scheme).muted)
                                if let status = state.candidateSearchStatus(candidate) { Text(status).font(ReaderTypography.font(.caption)) }
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

private enum ReaderDownloadStatusText {
    static func summary(_ status: ReaderDownloadStatus) -> String {
        "已完成 \(status.completedCount) · 缓存 \(status.cachedCount) · 失败 \(status.failedCount) · 暂停 \(status.pausedCount)"
    }

    static func state(_ state: ReaderDownloadChapterState) -> String {
        switch state {
        case .missing: return "未下载"; case .queued: return "排队中"; case .paused: return "已暂停"; case .inProgress: return "下载中"
        case .cached: return "阅读缓存"; case .completed: return "已完成"; case .failed: return "失败"; case .cancelled: return "已取消"
        }
    }
}

private struct ReaderDownloadReadIdentity: Hashable {
    let sourceID: String
    let bookID: String
    let sessionID: UUID?
    let chapterIndex: UInt32?
    let protectedChapters: [ReaderCachedChapterIdentity]

    init(book: ReaderBook, sessionID: UUID? = nil, chapterIndex: UInt32? = nil,
         protectedChapters: [ReaderCachedChapterIdentity]? = nil) {
        sourceID = book.sourceId; bookID = book.bookId
        self.sessionID = sessionID; self.chapterIndex = chapterIndex
        self.protectedChapters = protectedChapters ?? chapterIndex.map { [.init(book: book, chapterIndex: $0)] } ?? []
    }
}

private struct ReaderDownloadReadTaskIdentity: Hashable {
    let entity: ReaderDownloadReadIdentity
    let foreground: Bool
}

private struct ReaderDownloadReadSnapshot {
    let status: ReaderDownloadStatus
    let storage: ReaderStorageSummary?
}

private typealias ReaderDownloadPresentation = ReaderDownloadReadOwner<ReaderDownloadReadIdentity, ReaderDownloadReadSnapshot>

private extension ReaderDownloadReadOwner where Identity == ReaderDownloadReadIdentity, Value == ReaderDownloadReadSnapshot {
    @discardableResult
    func refresh(identity: ReaderDownloadReadIdentity, book: ReaderBook,
                 service: any ReaderDownloadServing, includeStorage: Bool = true) -> Task<Void, Never>? {
        // A full request retains its inventory demand if status-only hints
        // arrive while the current status read is still in flight.
        return invalidate(identity: identity, priority: includeStorage ? 1 : 0) { [weak self] publish in
            let status = try await service.readerDownloadStatus(book)
            try Task.checkCancellation()
            guard status.sourceId == identity.sourceID, status.bookId == identity.bookID else {
                throw ReaderLibraryError.invalidResponse("download status identity")
            }
            // Keep confirmed same-context inventory while reading status.
            let retainedStorage = self?.identity == identity ? self?.value?.storage : nil
            publish(ReaderDownloadReadSnapshot(status: status, storage: retainedStorage))
            if includeStorage {
                // Do not hold the status lane while inventory awaits Core.
                // Its transform merges with the latest status at publication.
                self?.invalidateSupplement(identity: identity) {
                    let storage = try await service.readerStorageSummary(protected: identity.protectedChapters)
                    try Task.checkCancellation()
                    return { current in ReaderDownloadReadSnapshot(status: current.status, storage: storage) }
                }
            }
        }
    }
}

/// Shelf access does not create a reading session or request chapter content.
struct ReaderOnlineDownloadSummaryPanel: View {
    let book: ReaderBook
    let service: any ReaderDownloadServing
    @StateObject private var presentation = ReaderDownloadPresentation()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase

    private var readIdentity: ReaderDownloadReadIdentity { .init(book: book) }
    private var status: ReaderDownloadStatus? { presentation.identity == readIdentity ? presentation.value?.status : nil }
    private var failure: String? {
        presentation.identity == readIdentity ? presentation.failure : nil
    }

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button("关闭") { presentation.retire(); dismiss() }
                    .accessibilityIdentifier("online-download-summary-close")
                Spacer()
                Text("下载状态").font(ReaderTypography.font(.controlHeader))
                Spacer()
                Button(presentation.loading ? "正在刷新" : "刷新") { refresh() }
                    .disabled(presentation.loading || phase != .active)
                    .accessibilityIdentifier("online-download-summary-refresh")
            }.padding(.horizontal, 20)
            if let failure {
                ReaderPageState(title: status == nil ? "下载状态不可用" : "下载状态刷新未完成",
                                detail: failure, actionTitle: "重试") { refresh() }
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let status {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Text(book.title).font(ReaderTypography.font(.controlHeader))
                            .accessibilityIdentifier("online-download-summary-title:" + book.id)
                        Text("书源：" + (book.sourceName ?? book.sourceId)).font(ReaderTypography.font(.caption))
                            .accessibilityIdentifier("online-download-summary-source:" + book.id)
                        Text(ReaderDownloadStatusText.summary(status)).font(ReaderTypography.font(.caption))
                            .accessibilityIdentifier("online-download-summary:" + book.id)
                        ForEach(status.chapters) { chapter in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(chapter.displayTitle ?? chapter.title)
                                    ReaderChapterSourceLabel(isVip: chapter.isVip, isPay: chapter.isPay)
                                    Spacer()
                                    Text(ReaderDownloadStatusText.state(chapter.state))
                                        .accessibilityIdentifier("online-download-summary-state:" + book.id + ":" + String(chapter.chapterIndex))
                                }
                                Text("尝试 \(chapter.attempts) / \(chapter.maxAttempts)")
                                    .accessibilityIdentifier("online-download-summary-attempts:" + book.id + ":" + String(chapter.chapterIndex))
                                if let error = chapter.lastError { Text(error) }
                            }.font(ReaderTypography.font(.caption)).padding(.vertical, 8)
                                .accessibilityElement(children: .contain)
                                .accessibilityIdentifier("online-download-summary-chapter:" + book.id + ":" + String(chapter.chapterIndex))
                            Divider()
                        }
                    }.padding(20)
                }.accessibilityIdentifier("online-download-summary-scroll")
            } else if failure == nil {
                ReaderPageState(title: "正在加载下载状态", loading: true)
            }
        }.padding(.vertical, 20)
            .task(id: ReaderDownloadReadTaskIdentity(entity: readIdentity, foreground: phase == .active)) {
                guard !Task.isCancelled, phase == .active else { return }
                presentation.activate(identity: readIdentity)
                refresh()
            }
            .onChange(of: phase) { _, value in
                if value != .active { presentation.retire() }
            }
            .onDisappear { presentation.retire() }
    }

    private func refresh() {
        guard phase == .active else { return }
        presentation.refresh(identity: readIdentity, book: book, service: service, includeStorage: false)
    }
}

struct ReaderOnlineDownloadPanel: View {
    /// A presentation location, never a queued task or an operation result.
    private struct ControlTarget {
        let entity: ReaderDownloadReadIdentity
        let chapterIndex: UInt32
    }
    @ObservedObject var model: ReaderApplicationModel
    let book: ReaderBook
    private let retainedSession: ReaderActiveSession?
    private let taskOnly: Bool
    private let closeAction: (() -> Void)?
    @State private var presentationActive = true
    @State private var chapterAnchor: UInt32?
    @Binding private var retainedChapterAnchor: UInt32?
    @StateObject private var downloadActions: ReaderDownloadControlOwner
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @StateObject private var presentation = ReaderDownloadPresentation()
    @State private var start = "1"
    @State private var end = "1"
    @State private var failure: String?
    @State private var selected = Set<UInt32>()
    @State private var updatingCatalog = false
    @State private var catalogFeedback: String?
    @State private var batchFeedback: String?
    @State private var catalogGeneration = UUID()
    @State private var catalogTask: Task<Void, Never>?
    @State private var controlTarget: ControlTarget?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var phase

    init(model: ReaderApplicationModel, session: ReaderActiveSession) {
        self.model = model
        self.book = session.book
        self.retainedSession = session
        self.taskOnly = false
        self.closeAction = nil
        _retainedChapterAnchor = .constant(nil)
        _downloadActions = StateObject(wrappedValue: ReaderDownloadControlOwner(
            pendingChecker: { [weak actions = model.actions] id in
                guard let checker = actions?.pendingChecker else { return nil }
                return await checker(id)
            }
        ))
    }

    init(model: ReaderApplicationModel, book: ReaderBook,
         downloadActions: ReaderDownloadControlOwner,
         chapterAnchor: Binding<UInt32?> = .constant(nil), close: @escaping () -> Void) {
        self.model = model; self.book = book
        retainedSession = nil; taskOnly = true; closeAction = close
        _downloadActions = StateObject(wrappedValue: downloadActions)
        _retainedChapterAnchor = chapterAnchor
    }

    /// The global route has no fallback session. The session initializer keeps
    /// its actual retained session only for the lifetime of that presentation
    /// (including the existing isolated native cleanup host).
    private var protectedSession: ReaderActiveSession? {
        model.reader ?? (presentationActive ? retainedSession : nil)
    }
    private var matchingSession: ReaderActiveSession? {
        guard let session = protectedSession,
              session.book.sourceId.utf8.elementsEqual(book.sourceId.utf8),
              session.book.bookId.utf8.elementsEqual(book.bookId.utf8) else { return nil }
        return session
    }
    private var protectedChapters: [ReaderCachedChapterIdentity] {
        protectedSession.map { [.init(book: $0.book, chapterIndex: $0.content.chapterIndex)] } ?? []
    }
    private func isCurrentChapter(_ chapter: UInt32) -> Bool {
        matchingSession?.content.chapterIndex == chapter
    }
    private var canUpdateCatalog: Bool {
        guard let retainedSession, let current = model.reader else { return false }
        return current.id == retainedSession.id && matchingSession?.id == current.id
    }
    private var taskChapters: [ReaderDownloadChapter] {
        guard let status else { return [] }
        return taskOnly ? status.chapters.filter { [.queued, .inProgress, .paused, .completed, .failed, .cancelled].contains($0.state) } : status.chapters
    }
    private var readingPresentationVisible: Bool { !taskOnly || model.reader == nil }

    private var service: (any ReaderDownloadServing)? { model.libraryService as? any ReaderDownloadServing }
    private var readIdentity: ReaderDownloadReadIdentity {
        .init(book: book, sessionID: matchingSession?.id, chapterIndex: matchingSession?.content.chapterIndex, protectedChapters: protectedChapters)
    }
    private var snapshot: ReaderDownloadReadSnapshot? {
        presentation.identity == readIdentity ? presentation.value : nil
    }
    private var status: ReaderDownloadStatus? { snapshot?.status }
    private var visibleControlChapter: ReaderDownloadChapter? {
        guard let status else { return nil }
        if let controlTarget, controlTarget.entity == readIdentity {
            return taskChapters.first { $0.chapterIndex == controlTarget.chapterIndex }
        }
        // Opening management during existing work still exposes an actual
        // live chapter. Explicit download/control input then fixes its target.
        return status.chapters.last { [.queued, .inProgress, .paused].contains($0.state) }
    }
    private var displayFailure: String? {
        failure ?? (presentation.identity == readIdentity ? presentation.failure : nil)
    }
    var body: some View {
        VStack(spacing: 14) {
            HStack { Button(taskOnly ? "返回" : "关闭") { presentation.retire(); presentationActive = false; if let closeAction { closeAction() } else { dismiss() } }.accessibilityIdentifier("online-download-close"); Spacer(); Text("下载管理").font(ReaderTypography.font(.controlHeader)); Spacer(); Button("刷新") { Task { await refresh() } }.disabled(phase != .active) }.padding(.horizontal, 20)
            if canUpdateCatalog {
                Button(updatingCatalog ? "正在取得目录" : "更新在线目录") { updateCatalog() }.disabled(model.actions.hasPending || updatingCatalog)
                    .accessibilityIdentifier("online-update-catalog")
            }
            if let catalogFeedback { Text(catalogFeedback).font(ReaderTypography.font(.caption)).accessibilityIdentifier("online-catalog-feedback") }
            if let status {
                let controlChapter = visibleControlChapter
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Text(book.title).font(ReaderTypography.font(.controlHeader))
                            .accessibilityIdentifier("online-download-book-identity:" + ReaderDownloadBookCursor(sourceId: book.sourceId, bookId: book.bookId).accessibilityKey)
                        Text(book.sourceName ?? book.sourceId).font(ReaderTypography.font(.caption))
                        Text(ReaderDownloadStatusText.summary(status)).font(ReaderTypography.font(.caption))
                        if !taskOnly {
                        HStack { TextField("起章", text: $start).keyboardType(.numberPad).readerField(); Text("至"); TextField("末章", text: $end).keyboardType(.numberPad).readerField(); Button("下载") { downloadRange() } }
                        HStack { Button("整本下载") { download(0..<status.chapterCount) }; Spacer(); Button("下载所选") { downloadSelected() }.disabled(selected.isEmpty).accessibilityIdentifier("online-download-selected") }.disabled(model.actions.hasPending)
                        }
                        // Relocate this one original row beside the download input;
                        // the canonical list below omits it, so every AX ID is unique.
                        if let chapter = controlChapter { chapterRow(chapter) }
                        if let batchFeedback { Text(batchFeedback).font(ReaderTypography.font(.caption)) }
                        Text("阅读前后章缓存与主动下载分别记账。清理自动缓存保留已完成下载及当前章。").font(ReaderTypography.font(.caption))
                        if let storage = snapshot?.storage {
                            Text("可清理自动正文 \(ByteCountFormatter.string(fromByteCount: Int64(clamping: storage.cleanableBytes), countStyle: .file))").font(ReaderTypography.font(.caption))
                            Button("清理自动缓存") { confirmation.confirm("清理自动缓存？", message: "保留当前章和已完成下载；书架、阅读位置及原书不变。", actionTitle: "清理") { cleanup() } }.disabled(model.actions.hasPending)
                        }
                        if let result = downloadActions.cleanupResult, result.scope == book.id {
                            ReaderPageState(title: result.title, detail: result.detail)
                                .accessibilityIdentifier("online-cache-cleanup-result")
                        }
                        ForEach(taskChapters.filter { $0.chapterIndex != controlChapter?.chapterIndex }) { chapter in
                            chapterRow(chapter)
                        }
                    }.padding(20).scrollTargetLayout()
                }.scrollPosition(id: taskOnly ? $retainedChapterAnchor : $chapterAnchor, anchor: .top).accessibilityIdentifier("online-download-scroll")
            } else { ReaderPageState(title: displayFailure == nil ? "正在加载下载状态" : "下载状态不可用", detail: displayFailure ?? "", loading: displayFailure == nil) }
            if let displayFailure, status != nil { ReaderPageState(title: "下载管理未完成", detail: displayFailure).padding(.horizontal, 20) }
            ReaderOperationStatus(owner: model.actions, scope: book.id)
            ReaderOperationStatus(owner: downloadActions.resumeActions, scope: book.id)
            ReaderOperationStatus(owner: downloadActions.controlActions, scope: book.id)
        }.padding(.vertical, 20).readerConfirmation(confirmation)
            .task(id: ReaderDownloadReadTaskIdentity(entity: readIdentity, foreground: phase == .active && readingPresentationVisible)) {
                guard readingPresentationVisible else { presentation.retire(); return }
                guard !Task.isCancelled, presentationActive, phase == .active, let service else { return }
                let identity = readIdentity
                // Register before the first read can expose the download input.
                let invalidations = await service.downloadStatusInvalidations(for: book)
                guard !Task.isCancelled, presentationActive, phase == .active, readingPresentationVisible else { return }
                presentation.activate(identity: identity)
                let invalidationTask = Task { @MainActor in
                    for await invalidation in invalidations {
                        guard !Task.isCancelled, phase == .active, readingPresentationVisible else { return }
                        guard invalidation.sourceID == identity.sourceID,
                              invalidation.bookID == identity.bookID else { continue }
                        // Any original operation for this entity may invalidate
                        // its status; the hint never confirms an action or state.
                        presentation.refresh(identity: identity, book: book,
                                             service: service, includeStorage: false)
                    }
                }
                defer { invalidationTask.cancel() }
                await refresh()
                while !Task.isCancelled { try? await Task.sleep(nanoseconds: 2_000_000_000); if !Task.isCancelled { await refresh() } }
            }
            .onChange(of: status?.chapterCount) { _, count in
                if end == "1", let count { end = String(count) }
            }
            .onChange(of: phase) { value in if value != .active { presentation.retire(); cancelCatalogRead() } }
            .onAppear { presentationActive = true }
            .onDisappear { presentationActive = false; presentation.retire(); cancelCatalogRead(); downloadActions.retireStorageCleanupPresentation() }
    }
    @ViewBuilder private func chapterRow(_ chapter: ReaderDownloadChapter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if taskOnly { Text(chapter.displayTitle ?? (chapter.title.isEmpty ? "第 \(UInt64(chapter.chapterIndex) + 1) 章" : chapter.title)) } else {
                Toggle(isOn: Binding(get: { selected.contains(chapter.chapterIndex) }, set: { value in if value { selected.insert(chapter.chapterIndex) } else { selected.remove(chapter.chapterIndex) } })) { Text(chapter.displayTitle ?? chapter.title) }.toggleStyle(.button)
                    .accessibilityIdentifier("online-download-select:" + book.id + ":" + String(chapter.chapterIndex))
                }
                ReaderChapterSourceLabel(isVip: chapter.isVip, isPay: chapter.isPay)
                Spacer(); Text(ReaderDownloadStatusText.state(chapter.state)).font(ReaderTypography.font(.caption))
                    .accessibilityIdentifier("online-download-state:" + book.id + ":" + String(chapter.chapterIndex))
            }
            Text("尝试 \(chapter.attempts) / \(chapter.maxAttempts)").font(ReaderTypography.font(.caption))
                .accessibilityIdentifier("online-download-attempts:" + book.id + ":" + String(chapter.chapterIndex))
            if isCurrentChapter(chapter.chapterIndex) { Text("当前阅读章").font(ReaderTypography.font(.caption)) }
            if let error = chapter.lastError { Text(error).font(ReaderTypography.font(.caption))
                .accessibilityIdentifier("online-download-error:" + book.id + ":" + String(chapter.chapterIndex)) }
            HStack {
                if [.queued, .inProgress].contains(chapter.state) {
                    Button("暂停") { task(chapter, action: .pause) }
                        .disabled(!downloadActions.canControl)
                        .accessibilityIdentifier("online-download-pause:" + book.id + ":" + String(chapter.chapterIndex))
                }
                if [.paused, .failed, .cancelled].contains(chapter.state) {
                    Button(chapter.state == .failed ? "重试" : "继续") { task(chapter, action: .resume) }
                        .disabled(!downloadActions.canResume)
                        .accessibilityIdentifier("online-download-resume:" + book.id + ":" + String(chapter.chapterIndex))
                }
                if [.queued, .inProgress, .paused].contains(chapter.state) {
                    Button("取消任务") { task(chapter, action: .cancel) }
                        .disabled(!downloadActions.canControl)
                        .accessibilityIdentifier("online-download-cancel:" + book.id + ":" + String(chapter.chapterIndex))
                }
                if !isCurrentChapter(chapter.chapterIndex),
                   [.cached, .completed, .failed, .cancelled, .paused].contains(chapter.state) {
                    Button("清除此章下载") {
                        confirmation.confirm("清除此章下载？", message: "删除此章缓存正文、下载任务及对应图片副本。书架、目录和阅读位置保留。", actionTitle: "清除") {
                            clearChapter(chapter)
                        }
                    }
                    .disabled(!downloadActions.canClear)
                }
            }.font(ReaderTypography.font(.caption))
        }.padding(.vertical, 8).id(chapter.chapterIndex)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("online-download-attempt:" + book.id + ":" + String(chapter.chapterIndex) + ":" + String(chapter.attempts))
        Divider()
    }
    private func refresh() async {
        guard !Task.isCancelled, presentationActive, phase == .active, readingPresentationVisible, let service else { return }
        if let request = presentation.refresh(identity: readIdentity, book: book, service: service) {
            failure = nil
            await request.value
        }
    }
    private func updateCatalog() {
        guard !updatingCatalog, canUpdateCatalog, let session = model.reader, model.libraryService is any ReaderOnlineServing else { return }
        let generation = UUID(); catalogGeneration = generation
        updatingCatalog = true; catalogFeedback = nil; failure = nil
        catalogTask = Task {
            do {
                let detail = try await model.refreshOnlineCatalog(sessionID: session.id, bookID: book.id)
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
        guard let service, !range.isEmpty, !model.actions.hasPending else { return }
        let target = ControlTarget(entity: readIdentity, chapterIndex: range.upperBound - 1)
        failure = nil
        Task {
            _ = await model.actions.perform("下载章节", scope: book.id) { id in
                controlTarget = target
                _ = try await service.downloadChapters(book, range: range, operationID: id)
            }
            await refresh()
        }
    }
    private func downloadSelected() {
        guard let service else { return }; let indexes = selected.sorted()
        Task {
            var completed = 0
            for index in indexes where index < UInt32.max {
                // Each accepted chapter has its own real operation owner.
                // Stop at an unresolved write and retain the remaining selection.
                let confirmed = await model.actions.perform("下载所选章节", scope: book.id) { id in
                    controlTarget = ControlTarget(entity: readIdentity, chapterIndex: index)
                    _ = try await service.downloadChapters(book, range: index..<(index + 1), operationID: id)
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
        let target = ControlTarget(entity: readIdentity, chapterIndex: chapter.chapterIndex)
        Task {
            let operation: (String) async throws -> Void = { id in
                controlTarget = target
                switch action {
                case .pause: _ = try await service.pauseDownload(book, chapterIndex: chapter.chapterIndex, operationID: id)
                case .resume: _ = try await service.resumeDownload(book, chapterIndex: chapter.chapterIndex, operationID: id)
                case .cancel: _ = try await service.cancelDownload(book, chapterIndex: chapter.chapterIndex, operationID: id)
                }
            }
            switch action {
            case .resume: _ = await downloadActions.performResume(scope: book.id, action: operation)
            case .pause, .cancel: _ = await downloadActions.performControl(scope: book.id, action: operation)
            }
            await refresh()
        }
    }
    private func cleanup() {
        guard let service else { return }
        let presentationID = downloadActions.cleanupPresentationID
        // Freeze the actual global reader tuple at confirmation, before any
        // asynchronous dispatch. Retries retain these original parameters.
        let protection = protectedChapters
        Task { _ = await model.actions.perform("清理缓存", scope: book.id) { id in
            downloadActions.beginStorageCleanup(operationID: id, scope: book.id, presentationID: presentationID)
            let result = try await service.cleanupReaderStorage(retained: [], protected: protection, operationID: id)
            downloadActions.receiveStorageCleanupReceipt(result, operationID: id, scope: book.id, presentationID: presentationID)
        }; await refresh() }
    }
    private func clearChapter(_ chapter: ReaderDownloadChapter) {
        guard let service, !isCurrentChapter(chapter.chapterIndex) else { return }
        Task {
            guard !isCurrentChapter(chapter.chapterIndex) else { return }
            _ = await downloadActions.performClear(scope: book.id) { id in
                try await service.clearDownloadedChapter(book, chapterIndex: chapter.chapterIndex, operationID: id)
            }
            await refresh()
        }
    }
}
