import Combine
import Foundation
import ReaderUIContract
import ReaderUIRuntime

/// Runtime rollout modes represented by `READER_UI_CONSUMER.json`.
public enum ReaderUIRuntimeShadowMode: String, Codable, Equatable, Sendable {
    case shadow
    case pilot
}

/// Single-source rollback toggles for runtime pilot cohorts. Rollback changes
/// a value to `.shadow` together with the host lock and redeploys; the native
/// reducer branch remains available for that explicit rollback path.
public enum ReaderUIRuntimeRollout {
    public static let directoryPairMode: ReaderUIRuntimeShadowMode = .pilot
    public static let bookOpenMode: ReaderUIRuntimeShadowMode = .pilot
    public static let playbackPilotMode: ReaderUIRuntimeShadowMode = .pilot
    // These cohorts remain explicit experimental seams only. Production keeps
    // them Shadow until typed Core/Host transactions and app entry wiring are
    // proven end to end.
    public static let importPilotMode: ReaderUIRuntimeShadowMode = .shadow
    public static let sourceSwitchPilotMode: ReaderUIRuntimeShadowMode = .shadow
    public static let replaceRulePilotMode: ReaderUIRuntimeShadowMode = .shadow
    public static let rssPilotMode: ReaderUIRuntimeShadowMode = .shadow
    // Sync remains Shadow until the typed sync.merge -> sync.webdav.plan ->
    // Host HTTP transaction and request-scoped cancellation are production-wired.
    public static let syncPilotMode: ReaderUIRuntimeShadowMode = .shadow
}

/// Cohort evidence or rollback descriptor. Production cohorts currently use
/// plain descriptive strings; structured decoding remains for lock compatibility.
public enum CohortDetail: Codable, Equatable, Sendable {
    case text(String)
    case structured(CohortDetailBody)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            self = .text(string)
        } else if let body = try? container.decode(CohortDetailBody.self) {
            self = .structured(body)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "CohortDetail must be a String or an Object"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let string):
            try container.encode(string)
        case .structured(let body):
            try container.encode(body)
        }
    }

    public var isEmpty: Bool {
        switch self {
        case .text(let s): return s.isEmpty
        case .structured(let b):
            return b.parityTests == nil && b.count == nil
                && b.strategy == nil && b.trigger == nil
        }
    }
}

public struct CohortDetailBody: Codable, Equatable, Sendable {
    // Evidence fields
    public let parityTests: String?
    public let count: Int?
    // Rollback fields
    public let strategy: String?
    public let trigger: String?

    public init(
        parityTests: String? = nil,
        count: Int? = nil,
        strategy: String? = nil,
        trigger: String? = nil
    ) {
        self.parityTests = parityTests
        self.count = count
        self.strategy = strategy
        self.trigger = trigger
    }
}

public struct ReaderUIRuntimeShadowCohort: Codable, Equatable, Sendable {
    public let id: String
    public let mode: ReaderUIRuntimeShadowMode
    public let evidence: CohortDetail?
    public let rollback: CohortDetail?
    public let effectPolicy: String?
    public let events: [String]

    public init(
        id: String,
        mode: ReaderUIRuntimeShadowMode,
        evidence: CohortDetail? = nil,
        rollback: CohortDetail? = nil,
        effectPolicy: String? = nil,
        events: [String]
    ) {
        self.id = id
        self.mode = mode
        self.evidence = evidence
        self.rollback = rollback
        self.effectPolicy = effectPolicy
        self.events = events
    }
}

/// Host-owned rollout policy. This is an allowlist only; action semantics still
/// come exclusively from Reader-UI's generated `GeneratedRuntimeActions` table.
public struct ReaderUIRuntimeShadowConfiguration: Equatable, Sendable {
    public let defaultMode: ReaderUIRuntimeShadowMode
    public let coveredEvents: [String]
    public let cohorts: [ReaderUIRuntimeShadowCohort]

    public init(
        defaultMode: ReaderUIRuntimeShadowMode = .shadow,
        coveredEvents: [String],
        cohorts: [ReaderUIRuntimeShadowCohort] = []
    ) {
        self.defaultMode = defaultMode
        self.coveredEvents = coveredEvents
        self.cohorts = cohorts
    }

    /// Production R8 allowlist. A test reads `READER_UI_CONSUMER.json` and
    /// requires this ordered list and its cohorts to match the lock exactly.
    public static let live = ReaderUIRuntimeShadowConfiguration(
        coveredEvents: [
            "book.open",
            "reader.directory.open",
            "reader.directory.close",
            "reader.page.next",
            "reader.page.prev",
            "reader.tts.start",
            "reader.tts.stop",
            "reader.autoPage.start",
            "reader.autoPage.stop",
            "import.start",
            "import.apply",
            "import.cancel",
            "source.switch.open",
            "source.switch.cancel",
            "source.switch.confirm",
            "source.switch.rollback",
            "reader.sourceSwitch.open",
            "reader.sourceSwitch.close",
            "reader.replace.apply",
            "reader.replace.create",
            "reader.replace.validate",
            "rss.refresh",
            "rss.subscription.add",
            "rss.subscription.delete",
            "rss.subscription.edit",
            "rss.entry.open",
            "rss.favorite.add",
            "rss.favorite.remove",
            "sync.run",
            "webdav.config.test",
            "sync.start",
            "sync.progress",
            "sync.complete",
            "sync.conflict",
            "sync.resolve",
        ],
        cohorts: [
            ReaderUIRuntimeShadowCohort(
                id: "directory-pair-pilot",
                mode: ReaderUIRuntimeRollout.directoryPairMode,
                evidence: .text("ReaderUIRuntimeShadowParityTests covers production entry, continuous open/close, back, replacement, fail-closed failure, and exactly-once; the ReaderForIOSApp arm64 Simulator build is the promotion build gate."),
                rollback: .text("Set ReaderUIRuntimeRollout.directoryPairMode from .pilot to .shadow, change this cohort mode to shadow, and redeploy; the existing native reducer path resumes without data migration."),
                effectPolicy: "none",
                events: ["reader.directory.open", "reader.directory.close"]
            ),
            ReaderUIRuntimeShadowCohort(
                id: "book-open-pilot",
                mode: ReaderUIRuntimeRollout.bookOpenMode,
                evidence: .text("ReaderBookOpenPilotCoordinatorTests covers admission, four-stage execution, replacement rejection, zero geometry rejection, terminal failure cancel, identity drift, and correlation reuse; ReaderForIOSApp arm64 Simulator build is the promotion gate."),
                rollback: .text("Set ReaderBookOpenPilotConfiguration.live from .pilot to .shadow, change this cohort mode to shadow, and redeploy; the existing native reducer path resumes without data migration."),
                effectPolicy: "exactly-once",
                events: ["book.open"]
            ),
            ReaderUIRuntimeShadowCohort(
                id: "playback-pilot",
                mode: ReaderUIRuntimeRollout.playbackPilotMode,
                evidence: .text("ReaderPlaybackPilotCoordinatorTests covers TTS start/stop, auto-page start/stop, page pair, stale result guard, and rollback; ReaderForIOSApp arm64 Simulator build is the promotion gate."),
                rollback: .text("Set ReaderPlaybackPilotConfiguration.live ttsPairMode and autoPagePairMode from .pilot to .shadow, change this cohort mode to shadow, and redeploy."),
                effectPolicy: "exactly-once",
                events: ["reader.tts.start", "reader.tts.stop", "reader.autoPage.start", "reader.autoPage.stop"]
            ),
        ]
    )

    public func mode(for event: String) -> ReaderUIRuntimeShadowMode? {
        guard coveredEvents.contains(event) else { return nil }
        return cohorts.first(where: { $0.events.contains(event) })?.mode ?? defaultMode
    }

    fileprivate var validationErrors: [String] {
        var errors: [String] = []
        let covered = Set(coveredEvents)
        if covered.count != coveredEvents.count {
            errors.append("coveredEvents contains duplicates")
        }

        let generated = Set(GeneratedRuntimeActions.byEvent.keys)
        for event in coveredEvents where !generated.contains(event) {
            errors.append("covered event is not generated: \(event)")
        }

        var seenCohortIDs = Set<String>()
        var seenCohortEvents = Set<String>()
        for cohort in cohorts {
            if cohort.id.isEmpty || !seenCohortIDs.insert(cohort.id).inserted {
                errors.append("invalid or duplicate cohort id: \(cohort.id)")
            }
            if cohort.events.isEmpty {
                errors.append("cohort has no events: \(cohort.id)")
            }
            if cohort.mode != .shadow {
                if cohort.evidence?.isEmpty != false {
                    errors.append("non-shadow cohort has no evidence: \(cohort.id)")
                }
                if cohort.rollback?.isEmpty != false {
                    errors.append("non-shadow cohort has no rollback: \(cohort.id)")
                }
                let policy = cohort.effectPolicy ?? "none"
                if !["none", "exactly-once"].contains(policy) {
                    errors.append("cohort has invalid effectPolicy: \(cohort.id)")
                }
            }
            for event in cohort.events {
                if !covered.contains(event) {
                    errors.append("cohort event is not covered: \(event)")
                }
                if !seenCohortEvents.insert(event).inserted {
                    errors.append("event appears in multiple cohorts: \(event)")
                }
                let policy = cohort.effectPolicy ?? "none"
                if cohort.mode == .pilot && policy == "none",
                   let descriptor = GeneratedRuntimeActions.byEvent[event],
                   !descriptor.coreSequence.isEmpty || descriptor.hostRequest != nil {
                    errors.append("pilot event has Core/Host effects with effectPolicy=none: \(event)")
                }
            }
        }
        return errors
    }
}

protocol ReaderUIRuntimeDispatching: AnyObject {
    var state: ReaderUIState { get }

    func dispatch(
        event: String,
        jsonPayload: ReaderUIJSONPayload,
        correlationId: String?
    ) throws -> ReaderUITransition
}

extension ReaderUIRuntime: ReaderUIRuntimeDispatching {}

public struct ReaderUIRuntimeShadowMetrics: Equatable, Sendable {
    public fileprivate(set) var covered: Int = 0
    public fileprivate(set) var fallback: Int = 0
    public fileprivate(set) var runtimeError: Int = 0
    public fileprivate(set) var mismatch: Int = 0

    /// Effects returned by shadow transitions are counted and intentionally
    /// suppressed. The R8 Pilot pair is validation-gated to effect-free actions.
    public fileprivate(set) var suppressedRuntimeEffects: Int = 0

    public init() {}
}

/// Rendering intent derived from the canonical runtime transition. This is
/// deliberately not semantic state: `ReaderUIState.overlay` remains the only
/// Reader control/module truth, while motion follows its before/after delta.
public enum ReaderControlMotionDelta: Equatable, Sendable {
    case show
    case hide
    case switchModule
    case noOp

    public var motionID: MotionId? {
        switch self {
        case .show: return .reader_control_show
        case .hide: return .reader_control_hide
        case .switchModule: return .reader_module_switch
        case .noOp: return nil
        }
    }
}

/// Long-lived Reader-UI runtime coordinator used by the real App
/// `UiEvent -> ReaderReducer.dispatch` path.
///
/// Invariants for R8:
/// - the directory Pilot uses runtime overlay as its only semantic state;
/// - directory Pilot transitions never write `AppNavigationState`;
/// - directory Pilot actions have no Core/Host effects;
/// - shadow runtime effects are never sent to Core or Host Adapter;
/// - events outside the consumer-lock allowlist stay on native fallback only.
@MainActor
public final class ReaderUIRuntimeCoordinator: ObservableObject {
    struct NativeSnapshot {
        fileprivate let projection: SemanticProjection
    }

    private let runtime: any ReaderUIRuntimeDispatching
    public let configuration: ReaderUIRuntimeShadowConfiguration

    @Published public private(set) var metrics = ReaderUIRuntimeShadowMetrics()
    @Published public private(set) var lastTransition: ReaderUITransition?
    @Published public private(set) var lastReaderControlMotionDelta: ReaderControlMotionDelta?
    @Published public private(set) var lastFailure: ReaderUIRuntimeFailure?
    public private(set) var lastMismatch: String?

    public convenience init(
        configuration: ReaderUIRuntimeShadowConfiguration = .live,
        state: ReaderUIState = ReaderUIState()
    ) {
        self.init(configuration: configuration, runtime: ReaderUIRuntime(state: state))
    }

    init(
        configuration: ReaderUIRuntimeShadowConfiguration,
        runtime: any ReaderUIRuntimeDispatching
    ) {
        let validationErrors = configuration.validationErrors
        precondition(
            validationErrors.isEmpty,
            "Invalid ReaderUI runtime shadow configuration: \(validationErrors.joined(separator: "; "))"
        )
        self.configuration = configuration
        self.runtime = runtime
    }

    public var state: ReaderUIState { runtime.state }
    public var isDirectoryPresented: Bool { runtime.state.overlay == "directory" }
    public var readerControlOverlay: String? { runtime.state.overlay }

    /// Candidate dispatch preflight. A Pilot may become the sole writer only
    /// when its untouched runtime `previous` exactly matches the native
    /// reducer projection. This rejects stale long-lived runtimes before they
    /// can apply a semantically valid action to the wrong route or overlay.
    func validateReaderControlCandidateBaseline(
        for event: UiEvent,
        navigationState: AppNavigationState
    ) -> Bool {
        guard configuration.mode(for: event.type.rawValue) == .pilot,
              event.type == .reader_control_toggle || event.type == .reader_module_switch else {
            return true
        }
        lastReaderControlMotionDelta = nil
        let runtimeBaseline = ReaderControlCandidateBaseline(state: runtime.state)
        let nativeBaseline = ReaderControlCandidateBaseline(navigationState: navigationState)
        guard runtimeBaseline == nativeBaseline else {
            let failure = ReaderUIRuntimeFailure(
                code: "READER_CONTROL_BASELINE_MISMATCH",
                message: "Runtime candidate baseline \(runtimeBaseline) does not match native \(nativeBaseline)"
            )
            metrics.runtimeError += 1
            lastFailure = failure
            lastMismatch = failure.message
            return false
        }
        return true
    }

    /// Maps only canonical Reader control transitions. The event payload is
    /// intentionally ignored: show/hide/switch/no-op follows the committed
    /// `ReaderUIState.overlay` delta, including repeated-module no-op.
    public static func readerControlMotionDelta(
        for transition: ReaderUITransition
    ) -> ReaderControlMotionDelta? {
        switch transition.event {
        case "reader.control.toggle":
            guard transition.previous.overlay != transition.state.overlay else { return .noOp }
            return transition.state.overlay == nil ? .hide : .show
        case "reader.module.switch":
            return transition.previous.overlay == transition.state.overlay ? .noOp : .switchModule
        default:
            return nil
        }
    }

    /// Observe an event before the native reducer handles it. The returned
    /// effects remain data-only and are counted as suppressed.
    @discardableResult
    public func observe(
        _ event: UiEvent
    ) -> Result<ReaderUITransition, ReaderUIRuntimeFailure>? {
        // Motion belongs to the latest dispatch outcome, never to the last
        // successful transition. Fallbacks and every failure leave this nil.
        lastReaderControlMotionDelta = nil
        let eventName = event.type.rawValue
        guard let mode = configuration.mode(for: eventName) else {
            metrics.fallback += 1
            return nil
        }

        // The allowlist selects events, while the generated table remains the
        // sole source of action/guard/effect semantics.
        guard GeneratedRuntimeActions.byEvent[eventName] != nil else {
            let failure = ReaderUIRuntimeFailure(
                code: "SHADOW_CONFIGURATION_ERROR",
                message: "Covered event is absent from GeneratedRuntimeActions: \(eventName)"
            )
            metrics.runtimeError += 1
            lastFailure = failure
            return .failure(failure)
        }

        metrics.covered += 1
        do {
            var payload = try ReaderUIJSONBridge.payload(from: event.payload)
            if event.type == .book_open {
                if payload["sourceKind"] == nil,
                   let sourceKind = Self.bookOpenSourceKind(payload: payload) {
                    payload["sourceKind"] = .string(sourceKind)
                }
                payload = Self.canonicalBookOpenPayload(payload)
            }
            let transition = try runtime.dispatch(
                event: eventName,
                jsonPayload: payload,
                correlationId: event.correlationId
            )
            if mode == .shadow {
                metrics.suppressedRuntimeEffects += transition.effects.count
            }
            lastTransition = transition
            lastReaderControlMotionDelta = Self.readerControlMotionDelta(for: transition)
            lastFailure = nil
            return .success(transition)
        } catch let failure as ReaderUIRuntimeFailure {
            metrics.runtimeError += 1
            lastFailure = failure
            return .failure(failure)
        } catch {
            let failure = ReaderUIRuntimeFailure(
                code: "SHADOW_RUNTIME_ERROR",
                message: error.localizedDescription
            )
            metrics.runtimeError += 1
            lastFailure = failure
            return .failure(failure)
        }
    }

    /// Compare the successful runtime transition with a minimal semantic
    /// projection of the native post-reducer state. This never mutates either
    /// state owner and deliberately normalizes native `.sheet` to semantic
    /// `directory` only for the directory cohort.
    func compareNativeResult(
        for event: UiEvent,
        runtimeResult: Result<ReaderUITransition, ReaderUIRuntimeFailure>?,
        navigationState: AppNavigationState,
        nativeBefore: NativeSnapshot? = nil
    ) {
        guard configuration.mode(for: event.type.rawValue) == .shadow,
              case .success(let transition) = runtimeResult,
              let runtimeProjection = Self.runtimeProjection(for: event.type, state: transition.state),
              let nativeProjection = Self.nativeProjection(for: event.type, state: navigationState) else {
            return
        }
        let transitionMatches: Bool
        if let nativeBefore,
           let runtimeBefore = Self.runtimeProjection(for: event.type, state: transition.previous) {
            transitionMatches = runtimeBefore == nativeBefore.projection
                && runtimeProjection == nativeProjection
        } else {
            transitionMatches = runtimeProjection == nativeProjection
        }
        guard !transitionMatches else {
            lastMismatch = nil
            return
        }

        metrics.mismatch += 1
        if let nativeBefore,
           let runtimeBefore = Self.runtimeProjection(for: event.type, state: transition.previous) {
            lastMismatch = "\(event.type.rawValue): runtime=\(runtimeBefore)->\(runtimeProjection) native=\(nativeBefore.projection)->\(nativeProjection)"
        } else {
            lastMismatch = "\(event.type.rawValue): runtime=\(runtimeProjection) native=\(nativeProjection)"
        }
    }

    /// Capture native pre-reducer semantics so live shadow compares transitions,
    /// not only final values. This detects cases such as schema 2 directory-close
    /// preserving a dialog while the legacy native reducer clears it.
    func captureNativeState(
        for event: UiEvent,
        navigationState: AppNavigationState
    ) -> NativeSnapshot? {
        guard configuration.mode(for: event.type.rawValue) == .shadow,
              let projection = Self.nativeProjection(for: event.type, state: navigationState) else {
            return nil
        }
        return NativeSnapshot(projection: projection)
    }

    public func resetMetrics() {
        metrics = ReaderUIRuntimeShadowMetrics()
        lastReaderControlMotionDelta = nil
        lastFailure = nil
        lastMismatch = nil
    }

    private struct ReaderControlCandidateBaseline: Equatable, CustomStringConvertible {
        let route: String
        let stack: [String]
        let tab: String
        let overlay: String?

        init(state: ReaderUIState) {
            route = state.routeId
            stack = state.routeStack
            tab = state.tab
            overlay = state.overlay
        }

        @MainActor
        init(navigationState: AppNavigationState) {
            route = ReaderViewState(from: navigationState).routeId.rawValue
            tab = MainTab(appTab: navigationState.activeTab).rawValue
            overlay = Self.nativeOverlay(navigationState)

            let root = RouteId(appTab: navigationState.activeTab).rawValue
            let pushed = navigationState.navigationPath.map {
                RouteId(
                    appRoute: $0,
                    fallbackTab: navigationState.activeTab,
                    readerContext: nil
                ).rawValue
            }
            if navigationState.readerContext != nil {
                stack = [root] + pushed
            } else if pushed.isEmpty {
                stack = []
            } else {
                stack = [root] + Array(pushed.dropLast())
            }
        }

        var description: String {
            let overlayDescription = overlay ?? "nil"
            return "{route=\(route), stack=\(stack), tab=\(tab), overlay=\(overlayDescription)}"
        }

        @MainActor
        private static func nativeOverlay(_ navigationState: AppNavigationState) -> String? {
            switch navigationState.overlayState {
            case .none:
                return nil
            case .keyboard:
                return "keyboard"
            case .dialog:
                return "dialog"
            case .sheet:
                let prefix = "reader-module-"
                if let focus = navigationState.focusTarget,
                   focus.hasPrefix(prefix) {
                    return String(focus.dropFirst(prefix.count))
                }
                return "reader-control"
            }
        }
    }

    fileprivate enum SemanticProjection: Equatable, CustomStringConvertible {
        case route(String)
        case overlay(String?)
        case activeSession(String?)

        var description: String {
            switch self {
            case .route(let value): return "route(\(value))"
            case .overlay(let value): return "overlay(\(value ?? "nil"))"
            case .activeSession(let value): return "activeSession(\(value ?? "nil"))"
            }
        }
    }

    private static func runtimeProjection(
        for event: UiEventType,
        state: ReaderUIState
    ) -> SemanticProjection? {
        switch event {
        case .book_open:
            return .route(state.routeId)
        case .reader_directory_open, .reader_directory_close:
            return .overlay(state.overlay)
        case .reader_tts_start, .reader_autoPage_start:
            // Runtime start is result-dependent: TTS remains pending until
            // plan -> queue -> system speech succeeds. Shadow parity compares
            // the admitted semantic intent with the legacy eager capsule,
            // while `activeSession` itself correctly stays nil during pending.
            if state.autoPageTransaction != nil {
                return .activeSession("auto-page")
            }
            if state.ttsTransaction != nil {
                return .activeSession("tts")
            }
            return .activeSession(state.activeSession)
        default:
            return nil
        }
    }

    private static func nativeProjection(
        for event: UiEventType,
        state: AppNavigationState
    ) -> SemanticProjection? {
        switch event {
        case .book_open:
            return .route(ReaderViewState(from: state).routeId.rawValue)
        case .reader_directory_open, .reader_directory_close:
            let overlay: String?
            switch state.overlayState {
            case .none: overlay = nil
            case .sheet: overlay = "directory"
            case .dialog: overlay = "dialog"
            case .keyboard: overlay = "keyboard"
            }
            return .overlay(overlay)
        case .reader_tts_start, .reader_autoPage_start:
            let session: String?
            switch state.activeSession {
            case .none: session = nil
            case .tts: session = "tts"
            case .autoPage: session = "auto-page"
            }
            return .activeSession(session)
        default:
            return nil
        }
    }

    /// Canonical source classification used only to keep Shadow observation
    /// compatible with the generated `book.open` payload. A persisted source
    /// id alone is not enough: old local imports can retain a legacy id while
    /// their real chapter identity still has the `local-book://` Core scheme.
    /// Explicit `sourceKind` from a real entry payload always wins; this is the
    /// narrow fallback for older callers that have not added the field yet.
    private static func bookOpenSourceKind(payload: ReaderUIJSONPayload) -> String? {
        let sourceID = payload["sourceId"]?.stringValue ?? payload["sourceID"]?.stringValue
        let chapterURL = payload["chapterUrl"]?.stringValue
            ?? payload["chapterURL"]?.stringValue
            ?? payload["url"]?.stringValue
        if sourceID == "local-book"
            || sourceID == "local"
            || chapterURL?.hasPrefix("local-book://") == true {
            return "local"
        }
        guard let sourceID, !sourceID.isEmpty else { return nil }
        return "remote"
    }

    /// Compatibility normalization ends before the Reader-UI runtime wire.
    /// Recognized native aliases may inform canonical identity, but aliases and
    /// native-only display metadata never become contract fields. Any other
    /// unknown field remains present so the generated validator still rejects
    /// it instead of silently weakening the contract.
    private static func canonicalBookOpenPayload(
        _ payload: ReaderUIJSONPayload
    ) -> ReaderUIJSONPayload {
        var canonical = payload
        if canonical["sourceId"] == nil {
            canonical["sourceId"] = payload["sourceID"]
        }
        if canonical["bookId"] == nil {
            canonical["bookId"] = payload["bookID"] ?? payload["bookURL"]
        }
        if canonical["detailUrl"] == nil {
            canonical["detailUrl"] = payload["detailURL"]
        }
        for key in [
            "sourceID", "bookID", "bookURL", "detailURL",
            "chapterUrl", "chapterURL", "url", "title", "author",
        ] {
            canonical[key] = nil
        }
        return canonical
    }
}

/// Backwards-compatible names retained for the R7.2 parity-test surface.
public typealias ReaderUIRuntimeShadowCoordinator = ReaderUIRuntimeCoordinator
public typealias ReaderUIRuntimeShadow = ReaderUIRuntimeCoordinator
