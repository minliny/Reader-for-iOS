import Combine
import Foundation
import ReaderCoreModels
import ReaderCoreNativeAdapter
import ReaderShellValidation
import ReaderUIContract
import ReaderUIRuntime

public enum ReaderPlaybackPilotMode: String, Equatable, Sendable {
    case shadow
    case pilot
}

public struct ReaderPlaybackPilotConfiguration: Equatable, Sendable {
    public let pagePairMode: ReaderPlaybackPilotMode
    public let ttsPairMode: ReaderPlaybackPilotMode
    public let autoPagePairMode: ReaderPlaybackPilotMode

    public init(
        pagePairMode: ReaderPlaybackPilotMode = .shadow,
        ttsPairMode: ReaderPlaybackPilotMode = .shadow,
        autoPagePairMode: ReaderPlaybackPilotMode = .shadow
    ) {
        self.pagePairMode = pagePairMode
        self.ttsPairMode = ttsPairMode
        self.autoPagePairMode = autoPagePairMode
    }

    /// Production TTS and auto-page pairs are Pilot. The page pair remains
    /// Shadow until its own cohort promotion. `live` must remain in lockstep
    /// with the playback cohort in `READER_UI_CONSUMER.json`.
    public static let live = ReaderPlaybackPilotConfiguration(
        ttsPairMode: .pilot,
        autoPagePairMode: .pilot
    )

    public func mode(for event: String) -> ReaderPlaybackPilotMode? {
        switch event {
        case "reader.page.next", "reader.page.prev": return pagePairMode
        case "reader.tts.start", "reader.tts.stop": return ttsPairMode
        case "reader.autoPage.start", "reader.autoPage.stop": return autoPagePairMode
        default: return nil
        }
    }
}

public struct ReaderPlaybackChapterContext: Equatable, Sendable {
    public let sourceID: String
    public let bookID: String
    public let chapterIndex: Int
    public let chapterTitle: String
    public let chapterURL: String
    public let content: String
    public let initialPageIndex: Int
    public let canonicalLocation: String?

    public init(
        sourceID: String,
        bookID: String,
        chapterIndex: Int,
        chapterTitle: String,
        chapterURL: String,
        content: String,
        initialPageIndex: Int = 0,
        canonicalLocation: String? = nil
    ) {
        self.sourceID = sourceID
        self.bookID = bookID
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.chapterURL = chapterURL
        self.content = content
        self.initialPageIndex = initialPageIndex
        self.canonicalLocation = canonicalLocation
    }

    fileprivate var identity: String {
        "\(sourceID)|\(bookID)|\(chapterIndex)|\(chapterURL)"
    }

    fileprivate var ttsChapter: CoreTTSChapterReference {
        CoreTTSChapterReference(
            sourceID: sourceID,
            bookID: bookID,
            chapterIndex: chapterIndex,
            chapterTitle: chapterTitle,
            chapterURL: chapterURL
        )
    }
}

public enum ReaderPlaybackPageDirection: String, Equatable, Sendable {
    case next
    case previous
}

/// A proposal produced from the actual PaginatedReaderView PageRange array.
/// It is not committed UI state; Core must first return a matching canonical
/// location for this exact measured viewport and target page.
public struct ReaderPlaybackPageProposal: Equatable, Sendable {
    public let direction: ReaderPlaybackPageDirection
    public let targetPageIndex: Int
    public let pageCount: Int
    public let chapterIndex: Int
    public let chapterOffset: Int
    public let chapterProgress: Double
    public let viewportWidth: Int
    public let viewportHeight: Int
    public let fontScale: Double
    public let lineHeight: Double

    public init(
        direction: ReaderPlaybackPageDirection,
        targetPageIndex: Int,
        pageCount: Int,
        chapterIndex: Int,
        chapterOffset: Int,
        chapterProgress: Double,
        viewportWidth: Int,
        viewportHeight: Int,
        fontScale: Double,
        lineHeight: Double
    ) {
        self.direction = direction
        self.targetPageIndex = targetPageIndex
        self.pageCount = pageCount
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.fontScale = fontScale
        self.lineHeight = lineHeight
    }

    fileprivate var isValid: Bool {
        targetPageIndex >= 0
            && pageCount > 0
            && targetPageIndex < pageCount
            && chapterIndex >= 0
            && chapterOffset >= 0
            && (0 ... 1).contains(chapterProgress)
            && viewportWidth > 0
            && viewportHeight > 0
            && fontScale > 0
            && lineHeight > 0
    }

    fileprivate var runtimeLayout: ReaderUIPageLayout {
        ReaderUIPageLayout(
            anchor: "chapter-\(chapterIndex):offset-\(chapterOffset)",
            targetPageIndex: targetPageIndex,
            chapterIndex: chapterIndex,
            chapterOffset: chapterOffset,
            chapterProgress: chapterProgress,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            fontScale: fontScale
        )
    }
}

public struct ReaderPlaybackPageProposalRequest: Equatable, Sendable {
    public let correlationID: String
    public let direction: ReaderPlaybackPageDirection
    public let sequence: Int
}

@MainActor
public protocol ReaderPlaybackSpeechDriving: AnyObject {
    func start(
        text: String,
        correlationID: String,
        generation: Int,
        completion: @escaping @MainActor (_ correlationID: String, _ generation: Int) -> Void
    ) throws
    func stop(correlationID: String)
}

@MainActor
public protocol ReaderForegroundTimerScheduling: AnyObject {
    func arm(
        timerID: String,
        correlationID: String,
        delayMs: Int,
        generation: Int,
        fire: @escaping @MainActor (_ correlationID: String, _ generation: Int) -> Void
    ) throws
    func cancel(timerID: String)
}

/// Real one-shot foreground timer adapter. It never repeats: a successful
/// canonical page commit returns a fresh `timer.foreground.arm` effect.
@MainActor
public final class ReaderForegroundOneShotTimer: ReaderForegroundTimerScheduling {
    private var tasks: [String: Task<Void, Never>] = [:]

    public init() {}

    public func arm(
        timerID: String,
        correlationID: String,
        delayMs: Int,
        generation: Int,
        fire: @escaping @MainActor (_ correlationID: String, _ generation: Int) -> Void
    ) throws {
        guard !timerID.isEmpty,
              timerID == correlationID,
              (ReaderUIPlaybackDirective.autoPageMinimumIntervalMs ... ReaderUIPlaybackDirective.autoPageMaximumIntervalMs)
                .contains(delayMs) else {
            throw ReaderUIRuntimeFailure(code: "INVALID_FOREGROUND_TIMER", message: "Invalid one-shot timer request")
        }
        cancel(timerID: timerID)
        tasks[timerID] = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: UInt64(delayMs) * 1_000_000)
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            self?.tasks[timerID] = nil
            fire(correlationID, generation)
        }
    }

    public func cancel(timerID: String) {
        tasks.removeValue(forKey: timerID)?.cancel()
    }
}

@MainActor
public final class ReaderTTSPlaybackDriver: ReaderPlaybackSpeechDriving {
    private let player: ReaderTTSPlayer

    public init(player: ReaderTTSPlayer) {
        self.player = player
    }

    public func start(
        text: String,
        correlationID: String,
        generation: Int,
        completion: @escaping @MainActor (String, Int) -> Void
    ) throws {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ReaderUIRuntimeFailure(code: "EMPTY_TTS_SLICE", message: "tts.system.start requires non-empty text")
        }
        player.speak(text) {
            completion(correlationID, generation)
        }
    }

    public func stop(correlationID: String) {
        player.stop()
    }
}

public struct ReaderPlaybackPilotMetrics: Equatable, Sendable {
    public fileprivate(set) var admittedTransactions = 0
    public fileprivate(set) var executedCoreEffects = 0
    public fileprivate(set) var executedHostEffects = 0
    public fileprivate(set) var discardedCallbacks = 0
    public fileprivate(set) var failedEffects = 0

    public init() {}
}

public enum ReaderPlaybackEffectOutcome {
    case location(CoreReaderLocationStageResult)
    case progress(CoreReaderProgressStageResult)
    case ttsPlan(CoreTTSSlicePlan)
    case ttsQueue(CoreTTSQueueSnapshot)
    case speechStarted
    case timerArmed
    case teardownComplete
    case discarded
    case failed(String)
}

public enum ReaderPlaybackTTSAdvanceOutcome {
    case speaking
    case completed
    case discarded
    case failed(String)
}

public struct ReaderPlaybackEffectCallbacks {
    public let speechFinished: @MainActor (String, Int, Int) -> Void
    public let timerFired: @MainActor (String, Int) -> Void

    public init(
        speechFinished: @escaping @MainActor (String, Int, Int) -> Void,
        timerFired: @escaping @MainActor (String, Int) -> Void
    ) {
        self.speechFinished = speechFinished
        self.timerFired = timerFired
    }
}

@MainActor
public protocol ReaderPlaybackEffectExecuting: AnyObject {
    func bindChapter(_ context: ReaderPlaybackChapterContext)
    func setPageProposal(_ proposal: ReaderPlaybackPageProposal, correlationID: String)
    func execute(
        _ effect: ReaderUIEffect,
        callbacks: ReaderPlaybackEffectCallbacks
    ) async -> ReaderPlaybackEffectOutcome
    func advanceTTSAfterSpeech(
        correlationID: String,
        generation: Int,
        sliceIndex: Int,
        callbacks: ReaderPlaybackEffectCallbacks
    ) async -> ReaderPlaybackTTSAdvanceOutcome
    func invalidate(correlationID: String)
    func finish(correlationID: String)
}

/// Sole Core/Host executor for an admitted playback correlation.
/// Runtime owns the sequence; this adapter only maps each typed effect to the
/// corresponding Core method, native speech engine, or foreground timer.
@MainActor
final class ReaderPlaybackDomainExecutor: ReaderPlaybackEffectExecuting {
    private struct PageContext {
        let chapter: ReaderPlaybackChapterContext
        let proposal: ReaderPlaybackPageProposal
        var resolvedLocation: CoreReaderLocationStageResult?
    }

    private struct TTSContext {
        var plan: CoreTTSSlicePlan?
        var snapshot: CoreTTSQueueSnapshot?
        var generation: Int = 0
        var invalidated = false
    }

    private let locationService: RustCoreReaderLocationService
    private let progressService: RustCoreReaderProgressService
    private let ttsService: RustCoreTTSService
    private let speech: any ReaderPlaybackSpeechDriving
    private let timer: any ReaderForegroundTimerScheduling

    private var chapter: ReaderPlaybackChapterContext?
    private var pageContexts: [String: PageContext] = [:]
    private var ttsContexts: [String: TTSContext] = [:]
    private var inFlight: [String: () -> Void] = [:]

    init(
        locationService: RustCoreReaderLocationService,
        progressService: RustCoreReaderProgressService,
        ttsService: RustCoreTTSService,
        speech: any ReaderPlaybackSpeechDriving,
        timer: any ReaderForegroundTimerScheduling
    ) {
        self.locationService = locationService
        self.progressService = progressService
        self.ttsService = ttsService
        self.speech = speech
        self.timer = timer
    }

    convenience init(
        runtime: ReaderCoreNativeRuntime,
        speech: any ReaderPlaybackSpeechDriving,
        timer: (any ReaderForegroundTimerScheduling)? = nil,
        requestTimeout: TimeInterval = 15
    ) {
        self.init(
            locationService: RustCoreReaderLocationService(runtime: runtime, requestTimeout: requestTimeout),
            progressService: RustCoreReaderProgressService(runtime: runtime, requestTimeout: requestTimeout),
            ttsService: RustCoreTTSService(runtime: runtime, requestTimeout: requestTimeout),
            speech: speech,
            timer: timer ?? ReaderForegroundOneShotTimer()
        )
    }

    func bindChapter(_ context: ReaderPlaybackChapterContext) {
        chapter = context
    }

    func setPageProposal(_ proposal: ReaderPlaybackPageProposal, correlationID: String) {
        guard let chapter else { return }
        pageContexts[correlationID] = PageContext(
            chapter: chapter,
            proposal: proposal,
            resolvedLocation: nil
        )
    }

    func execute(
        _ effect: ReaderUIEffect,
        callbacks: ReaderPlaybackEffectCallbacks
    ) async -> ReaderPlaybackEffectOutcome {
        guard let correlationID = effect.correlationId, !correlationID.isEmpty else {
            return .failed("PLAYBACK_EFFECT_MISSING_CORRELATION")
        }
        switch effect.type {
        case "reader.location.resolve":
            return await executeLocation(correlationID: correlationID)
        case "reader.progress.update":
            return await executeProgress(correlationID: correlationID)
        case "tts.queue.plan":
            return await executeTTSPlan(correlationID: correlationID)
        case "tts.queue.start":
            return await executeTTSQueueStart(correlationID: correlationID)
        case "tts.system.start":
            return executeSpeechStart(correlationID: correlationID, callbacks: callbacks)
        case "tts.system.stop":
            speech.stop(correlationID: correlationID)
            return .teardownComplete
        case "tts.queue.stop":
            return await executeTTSQueueStop(correlationID: correlationID)
        case ReaderUIPlaybackDirective.foregroundTimerArm:
            return executeTimerArm(effect, correlationID: correlationID, callbacks: callbacks)
        case ReaderUIPlaybackDirective.foregroundTimerCancel:
            timer.cancel(timerID: effect.payload["timerId"] ?? correlationID)
            return .teardownComplete
        default:
            return .failed("PLAYBACK_UNSUPPORTED_EFFECT:\(effect.type)")
        }
    }

    func advanceTTSAfterSpeech(
        correlationID: String,
        generation: Int,
        sliceIndex: Int,
        callbacks: ReaderPlaybackEffectCallbacks
    ) async -> ReaderPlaybackTTSAdvanceOutcome {
        guard var context = ttsContexts[correlationID],
              !context.invalidated,
              context.generation == generation,
              context.snapshot?.currentSliceIndex == sliceIndex,
              let plan = context.plan else {
            return .discarded
        }
        do {
            let report = try ttsService.startReportDoneStage(
                chapter: plan.chapter,
                sliceIndex: sliceIndex,
                correlationID: correlationID
            )
            _ = try await awaitValue(report, correlationID: correlationID)
            guard isActiveTTS(correlationID, generation: generation) else { return .discarded }

            let next = try ttsService.startNextStage(
                chapter: plan.chapter,
                correlationID: correlationID
            )
            let snapshot = try await awaitValue(next, correlationID: correlationID)
            guard isActiveTTS(correlationID, generation: generation) else { return .discarded }
            context.snapshot = snapshot
            ttsContexts[correlationID] = context
            if snapshot.state == .completed {
                return .completed
            }
            guard snapshot.state == .playing,
                  let nextIndex = snapshot.currentSliceIndex,
                  plan.slices.indices.contains(nextIndex) else {
                return .failed("TTS_NEXT_SNAPSHOT_INVALID")
            }
            try speech.start(
                text: plan.slices[nextIndex].text,
                correlationID: correlationID,
                generation: generation
            ) { completedCorrelationID, completedGeneration in
                callbacks.speechFinished(completedCorrelationID, completedGeneration, nextIndex)
            }
            return .speaking
        } catch is CancellationError {
            return .discarded
        } catch {
            return isActiveTTS(correlationID, generation: generation)
                ? .failed(error.localizedDescription)
                : .discarded
        }
    }

    func invalidate(correlationID: String) {
        inFlight.removeValue(forKey: correlationID)?()
        pageContexts[correlationID] = nil
        if var context = ttsContexts[correlationID] {
            context.invalidated = true
            context.generation += 1
            ttsContexts[correlationID] = context
        }
    }

    func finish(correlationID: String) {
        inFlight[correlationID] = nil
        pageContexts[correlationID] = nil
        ttsContexts[correlationID] = nil
    }

    private func executeLocation(correlationID: String) async -> ReaderPlaybackEffectOutcome {
        guard var context = pageContexts[correlationID],
              context.resolvedLocation == nil,
              context.proposal.chapterIndex == context.chapter.chapterIndex else {
            return .failed("PAGE_DOMAIN_CONTEXT_MISSING")
        }
        let chapter = context.chapter
        let proposal = context.proposal
        do {
            let handle = try locationService.startResolveStage(
                CoreReaderLocationStageRequest(
                    sourceID: chapter.sourceID,
                    bookID: chapter.bookID,
                    chapterIndex: chapter.chapterIndex,
                    chapterTitle: chapter.chapterTitle,
                    chapterOffset: proposal.chapterOffset,
                    chapterProgress: proposal.chapterProgress,
                    layout: CoreReaderLocationLayout(
                        viewportWidth: proposal.viewportWidth,
                        viewportHeight: proposal.viewportHeight,
                        fontScale: proposal.fontScale,
                        lineHeight: proposal.lineHeight,
                        pageIndex: proposal.targetPageIndex,
                        pageCount: proposal.pageCount
                    )
                ),
                correlationID: correlationID
            )
            let location = try await awaitValue(handle, correlationID: correlationID)
            guard pageContexts[correlationID]?.proposal == proposal else { return .discarded }
            guard location.bookID == chapter.bookID,
                  location.chapterIndex == chapter.chapterIndex,
                  location.layoutIndependent,
                  !location.locationRevision.isEmpty,
                  !location.resolverVersion.isEmpty else {
                return .failed("PAGE_LOCATION_IDENTITY_MISMATCH")
            }
            context.resolvedLocation = location
            pageContexts[correlationID] = context
            return .location(location)
        } catch is CancellationError {
            return .discarded
        } catch {
            return pageContexts[correlationID] == nil
                ? .discarded
                : .failed(error.localizedDescription)
        }
    }

    private func executeProgress(correlationID: String) async -> ReaderPlaybackEffectOutcome {
        guard let context = pageContexts[correlationID],
              let location = context.resolvedLocation else {
            return .failed("PAGE_PROGRESS_DOMAIN_CONTEXT_MISSING")
        }
        let request = CoreReaderProgressStageRequest(
            sourceID: context.chapter.sourceID,
            bookID: context.chapter.bookID,
            updatedAt: Int64(Date().timeIntervalSince1970),
            chapterIndex: location.chapterIndex,
            chapterOffset: location.chapterOffset,
            chapterProgress: location.chapterProgress,
            locationRevision: location.locationRevision
        )
        do {
            let handle = try progressService.startUpdateStage(request, correlationID: correlationID)
            let result = try await awaitValue(handle, correlationID: correlationID)
            guard let active = pageContexts[correlationID],
                  active.proposal == context.proposal,
                  active.resolvedLocation == location else {
                return .discarded
            }
            guard result.sourceID == context.chapter.sourceID,
                  result.bookID == context.chapter.bookID,
                  result.chapterIndex == location.chapterIndex,
                  result.chapterOffset == location.chapterOffset,
                  result.chapterProgress == location.chapterProgress,
                  result.locationRevision == location.locationRevision,
                  result.stored else {
                return .failed("PAGE_PROGRESS_IDENTITY_MISMATCH")
            }
            return .progress(result)
        } catch is CancellationError {
            return .discarded
        } catch {
            return pageContexts[correlationID] == nil
                ? .discarded
                : .failed(error.localizedDescription)
        }
    }

    private func executeTTSPlan(correlationID: String) async -> ReaderPlaybackEffectOutcome {
        guard let chapter,
              !chapter.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failed("TTS_DOMAIN_CONTEXT_MISSING")
        }
        ttsContexts[correlationID] = TTSContext()
        do {
            let handle = try ttsService.startPlanStage(
                chapter: chapter.ttsChapter,
                content: chapter.content,
                correlationID: correlationID
            )
            let plan = try await awaitValue(handle, correlationID: correlationID)
            guard var context = ttsContexts[correlationID], !context.invalidated else { return .discarded }
            guard plan.chapter == chapter.ttsChapter else { return .failed("TTS_PLAN_IDENTITY_MISMATCH") }
            context.plan = plan
            ttsContexts[correlationID] = context
            return .ttsPlan(plan)
        } catch is CancellationError {
            return .discarded
        } catch {
            return ttsContexts[correlationID]?.invalidated == false
                ? .failed(error.localizedDescription)
                : .discarded
        }
    }

    private func executeTTSQueueStart(correlationID: String) async -> ReaderPlaybackEffectOutcome {
        guard let context = ttsContexts[correlationID],
              !context.invalidated,
              let plan = context.plan else {
            return .failed("TTS_PLAN_CONTEXT_MISSING")
        }
        do {
            let handle = try ttsService.startQueueStage(plan: plan, correlationID: correlationID)
            let snapshot = try await awaitValue(handle, correlationID: correlationID)
            guard var updated = ttsContexts[correlationID], !updated.invalidated else { return .discarded }
            guard snapshot.chapter == plan.chapter,
                  snapshot.state == .playing,
                  snapshot.totalSlices == plan.slices.count,
                  let index = snapshot.currentSliceIndex,
                  plan.slices.indices.contains(index) else {
                return .failed("TTS_QUEUE_SNAPSHOT_INVALID")
            }
            updated.snapshot = snapshot
            ttsContexts[correlationID] = updated
            return .ttsQueue(snapshot)
        } catch is CancellationError {
            return .discarded
        } catch {
            return ttsContexts[correlationID]?.invalidated == false
                ? .failed(error.localizedDescription)
                : .discarded
        }
    }

    private func executeSpeechStart(
        correlationID: String,
        callbacks: ReaderPlaybackEffectCallbacks
    ) -> ReaderPlaybackEffectOutcome {
        guard var context = ttsContexts[correlationID],
              !context.invalidated,
              let plan = context.plan,
              let index = context.snapshot?.currentSliceIndex,
              plan.slices.indices.contains(index) else {
            return .failed("TTS_SPEECH_CONTEXT_MISSING")
        }
        context.generation += 1
        let generation = context.generation
        ttsContexts[correlationID] = context
        do {
            try speech.start(
                text: plan.slices[index].text,
                correlationID: correlationID,
                generation: generation
            ) { completedCorrelationID, completedGeneration in
                callbacks.speechFinished(completedCorrelationID, completedGeneration, index)
            }
            return .speechStarted
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func executeTTSQueueStop(correlationID: String) async -> ReaderPlaybackEffectOutcome {
        guard let plan = ttsContexts[correlationID]?.plan else {
            // Queue never loaded (for example plan failure), so there is no
            // Core teardown effect to execute.
            return .teardownComplete
        }
        do {
            let handle = try ttsService.startStopStage(chapter: plan.chapter, correlationID: correlationID)
            let snapshot = try await awaitValue(handle, correlationID: correlationID)
            guard snapshot.state == .stopped else { return .failed("TTS_STOP_SNAPSHOT_INVALID") }
            return .teardownComplete
        } catch is CancellationError {
            return .discarded
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func executeTimerArm(
        _ effect: ReaderUIEffect,
        correlationID: String,
        callbacks: ReaderPlaybackEffectCallbacks
    ) -> ReaderPlaybackEffectOutcome {
        guard effect.kind == .host,
              effect.payload["timerId"] == correlationID,
              effect.payload["correlationId"] == correlationID,
              effect.payload["oneShot"] == "true",
              effect.payload["foregroundOnly"] == "true",
              let delayMs = Int(effect.payload["delayMs"] ?? ""),
              let generation = Int(effect.payload["generation"] ?? "") else {
            return .failed("INVALID_FOREGROUND_TIMER_EFFECT")
        }
        do {
            try timer.arm(
                timerID: correlationID,
                correlationID: correlationID,
                delayMs: delayMs,
                generation: generation
            ) { firedCorrelationID, firedGeneration in
                callbacks.timerFired(firedCorrelationID, firedGeneration)
            }
            return .timerArmed
        } catch {
            return .failed(error.localizedDescription)
        }
    }

    private func awaitValue<Value: Sendable>(
        _ handle: RustCoreRequestScopedCommand<Value>,
        correlationID: String
    ) async throws -> Value {
        inFlight[correlationID] = { _ = handle.cancel() }
        defer { inFlight[correlationID] = nil }
        return try await handle.value()
    }

    private func isActiveTTS(_ correlationID: String, generation: Int) -> Bool {
        guard let context = ttsContexts[correlationID] else { return false }
        return !context.invalidated && context.generation == generation
    }
}

/// Runtime-owned playback transaction coordinator. `live` admits TTS and
/// auto-page as Pilot while page remains Shadow; one sole executor owns every
/// emitted Pilot effect and the native duplicate path is bypassed.
@MainActor
public final class ReaderPlaybackPilotCoordinator: ObservableObject {
    public let configuration: ReaderPlaybackPilotConfiguration
    private let runtime: ReaderUIRuntime
    private let executor: (any ReaderPlaybackEffectExecuting)?
    private var chapterIdentity: String?
    private var sequence = 0
    private var serialTail: Task<Void, Never>?

    @Published public private(set) var committedPageIndex: Int = 0
    @Published public private(set) var canonicalLocation: String?
    @Published public private(set) var pendingPageProposal: ReaderPlaybackPageProposalRequest?
    @Published public private(set) var activeSession: String?
    @Published public private(set) var autoPageHasCommittedPage = false
    @Published public private(set) var lastFailure: String?
    @Published public private(set) var metrics = ReaderPlaybackPilotMetrics()

    public init(
        configuration: ReaderPlaybackPilotConfiguration = .live,
        runtime: ReaderUIRuntime = ReaderUIRuntime(state: ReaderUIState(routeId: "immersive-reading")),
        executor: (any ReaderPlaybackEffectExecuting)? = nil
    ) {
        self.configuration = configuration
        self.runtime = runtime
        self.executor = executor
        self.committedPageIndex = runtime.state.readerPageIndex
        self.canonicalLocation = runtime.state.readerCanonicalLocation
        self.activeSession = runtime.state.activeSession
    }

    public var isPagePilot: Bool { configuration.pagePairMode == .pilot }
    public var isTTSPilot: Bool { configuration.ttsPairMode == .pilot }
    public var isAutoPagePilot: Bool { configuration.autoPagePairMode == .pilot }
    public var acceptsRuntimePageProposals: Bool { isPagePilot || isAutoPagePilot }
    public var isRuntimePageProjectionActive: Bool {
        isPagePilot
            || (isAutoPagePilot && activeSession == "auto-page" && autoPageHasCommittedPage)
    }
    public var hasActiveTransaction: Bool {
        runtime.state.pageTransaction != nil
            || runtime.state.ttsTransaction != nil
            || runtime.state.autoPageTransaction != nil
    }

    private var isPageProgressCommitPending: Bool {
        runtime.state.pageTransaction?.stage == "persisting-progress"
    }

    public func bindChapter(_ context: ReaderPlaybackChapterContext) {
        guard isPagePilot || isTTSPilot || isAutoPagePilot else { return }
        guard let executor else {
            failClosed("PLAYBACK_EXECUTOR_MISSING")
            return
        }
        if let chapterIdentity,
           chapterIdentity != context.identity,
           hasActiveTransaction {
            failClosed("BOOK_REPLACEMENT_REQUIRES_PLAYBACK_TEARDOWN")
            guard !isPageProgressCommitPending else {
                lastFailure = "PAGE_PROGRESS_COMMIT_PENDING"
                return
            }
            Task { [weak self] in
                await self?.replaceChapter(context)
            }
            return
        }
        chapterIdentity = context.identity
        committedPageIndex = context.initialPageIndex
        canonicalLocation = context.canonicalLocation
        executor.bindChapter(context)
    }

    public func replaceChapter(_ context: ReaderPlaybackChapterContext) async {
        guard !isPageProgressCommitPending else {
            failClosed("PAGE_PROGRESS_COMMIT_PENDING")
            return
        }
        await enqueueAndWait { coordinator in
            guard !coordinator.isPageProgressCommitPending else {
                coordinator.failClosed("PAGE_PROGRESS_COMMIT_PENDING")
                return
            }
            await coordinator.teardownAllNow()
            guard !coordinator.isPageProgressCommitPending else {
                coordinator.failClosed("PAGE_PROGRESS_COMMIT_PENDING")
                return
            }
            coordinator.chapterIdentity = context.identity
            coordinator.committedPageIndex = context.initialPageIndex
            coordinator.canonicalLocation = context.canonicalLocation
            coordinator.executor?.bindChapter(context)
        }
    }

    /// Returns true only when the page pair is Pilot. A true return always
    /// suppresses the legacy paginator mutation, including admission failure.
    @discardableResult
    public func requestPage(
        _ direction: ReaderPlaybackPageDirection,
        proposal: ReaderPlaybackPageProposal? = nil,
        correlationID: String? = nil
    ) -> Bool {
        guard isPagePilot else { return false }
        guard executor != nil, chapterIdentity != nil else {
            failClosed("PAGE_PILOT_DOMAIN_CONTEXT_MISSING")
            return true
        }
        let correlationID = correlationID ?? nextCorrelation(prefix: "page")
        do {
            let transition = try runtime.dispatch(
                event: direction == .next ? "reader.page.next" : "reader.page.prev",
                correlationId: correlationID
            )
            metrics.admittedTransactions += 1
            invalidate(transition.cancelledCorrelationIds)
            if let proposal {
                enqueue { coordinator in
                    await coordinator.processNow(transition.effects)
                    coordinator.finishCancelled(
                        transition.cancelledCorrelationIds,
                        preserving: correlationID
                    )
                    coordinator.providePageProposal(proposal, correlationID: correlationID)
                }
            } else {
                if !transition.effects.isEmpty || !transition.cancelledCorrelationIds.isEmpty {
                    enqueue { coordinator in
                        await coordinator.processNow(transition.effects)
                        coordinator.finishCancelled(
                            transition.cancelledCorrelationIds,
                            preserving: correlationID
                        )
                    }
                }
                sequence += 1
                pendingPageProposal = ReaderPlaybackPageProposalRequest(
                    correlationID: correlationID,
                    direction: direction,
                    sequence: sequence
                )
            }
        } catch {
            failClosed(error.localizedDescription)
        }
        return true
    }

    public func providePageProposal(
        _ proposal: ReaderPlaybackPageProposal,
        correlationID: String
    ) {
        // An auto-page Pilot owns the same measured paginator proposal even
        // while the manual page pair remains Shadow in production.
        guard acceptsRuntimePageProposals,
              proposal.isValid,
              proposal.direction.rawValue == runtime.state.pageTransaction?.direction,
              runtime.state.pageTransaction?.correlationId == correlationID,
              let executor else {
            failClosed("PAGE_PROPOSAL_REJECTED")
            return
        }
        executor.setPageProposal(proposal, correlationID: correlationID)
        do {
            let transition = try runtime.providePageLayout(
                correlationId: correlationID,
                layout: proposal.runtimeLayout
            )
            guard transition.accepted else {
                metrics.discardedCallbacks += 1
                return
            }
            if pendingPageProposal?.correlationID == correlationID {
                pendingPageProposal = nil
            }
            enqueue { coordinator in
                await coordinator.processNow(transition.effects)
                coordinator.finishCancelled(
                    transition.cancelledCorrelationIds,
                    preserving: correlationID
                )
            }
        } catch {
            failPage(correlationID: correlationID, message: error.localizedDescription)
        }
    }

    public func rejectPageProposal(
        _ request: ReaderPlaybackPageProposalRequest,
        message: String
    ) {
        guard runtime.state.pageTransaction?.correlationId == request.correlationID else {
            metrics.discardedCallbacks += 1
            return
        }
        let wasAutoPage = runtime.state.pageTransaction?.source == "auto-page"
        do {
            let cancelled = try runtime.cancelPageStep(correlationId: request.correlationID)
            invalidate(cancelled.cancelledCorrelationIds)
            executor?.finish(correlationID: request.correlationID)
            pendingPageProposal = nil
            lastFailure = message
            if wasAutoPage, let auto = runtime.state.autoPageTransaction?.correlationId {
                _ = stopAutoPage(correlationID: auto)
            }
            projectRuntimeState()
        } catch {
            // Once progress persistence begins, cancellation is forbidden. Keep
            // the request handle and DomainContext alive for its terminal result.
            lastFailure = error.localizedDescription
            projectRuntimeState()
        }
    }

    @discardableResult
    public func startTTS(correlationID: String? = nil) -> Bool {
        guard isTTSPilot else { return false }
        guard executor != nil, chapterIdentity != nil else {
            failClosed("TTS_PILOT_DOMAIN_CONTEXT_MISSING")
            return true
        }
        let correlationID = correlationID ?? nextCorrelation(prefix: "tts")
        do {
            let transition = try runtime.dispatch(event: "reader.tts.start", correlationId: correlationID)
            metrics.admittedTransactions += 1
            invalidate(transition.cancelledCorrelationIds)
            projectRuntimeState()
            enqueue { coordinator in
                await coordinator.processNow(transition.effects)
                coordinator.finishCancelled(
                    transition.cancelledCorrelationIds,
                    preserving: correlationID
                )
            }
        } catch {
            failClosed(error.localizedDescription)
        }
        return true
    }

    @discardableResult
    public func stopTTS(correlationID: String? = nil) -> Bool {
        guard isTTSPilot else { return false }
        let transition = runtime.stopTTS(correlationId: correlationID)
        guard transition.accepted else { return true }
        invalidate(transition.cancelledCorrelationIds)
        projectRuntimeState()
        enqueue { coordinator in
            await coordinator.processNow(transition.effects)
            transition.cancelledCorrelationIds.forEach { coordinator.executor?.finish(correlationID: $0) }
        }
        return true
    }

    @discardableResult
    public func startAutoPage(
        intervalMs: Int,
        correlationID: String? = nil
    ) -> Bool {
        guard isAutoPagePilot else { return false }
        guard executor != nil, chapterIdentity != nil else {
            failClosed("AUTO_PAGE_PILOT_DOMAIN_CONTEXT_MISSING")
            return true
        }
        let correlationID = correlationID ?? nextCorrelation(prefix: "auto-page")
        do {
            // Page remains Shadow in production, so the coordinator may not
            // know the paginator's current native page. Do not project its
            // stored index until the first measured auto-page commit succeeds.
            autoPageHasCommittedPage = false
            let transition = try runtime.dispatch(
                event: "reader.autoPage.start",
                payload: ["intervalMs": String(intervalMs)],
                correlationId: correlationID
            )
            metrics.admittedTransactions += 1
            invalidate(transition.cancelledCorrelationIds)
            projectRuntimeState()
            enqueue { coordinator in
                await coordinator.processNow(transition.effects)
                coordinator.finishCancelled(
                    transition.cancelledCorrelationIds,
                    preserving: correlationID
                )
            }
        } catch {
            failClosed(error.localizedDescription)
        }
        return true
    }

    @discardableResult
    public func stopAutoPage(correlationID: String? = nil) -> Bool {
        guard isAutoPagePilot else { return false }
        let transition = runtime.stopAutoPage(correlationId: correlationID)
        guard transition.accepted else { return true }
        invalidate(transition.cancelledCorrelationIds)
        pendingPageProposal = nil
        projectRuntimeState()
        enqueue { coordinator in
            await coordinator.processNow(transition.effects)
            transition.cancelledCorrelationIds.forEach { coordinator.executor?.finish(correlationID: $0) }
        }
        return true
    }

    public func appDidEnterBackground() {
        guard isAutoPagePilot else { return }
        let transition = runtime.suspendAutoPageForBackground()
        guard transition.accepted else { return }
        invalidate(transition.cancelledCorrelationIds)
        pendingPageProposal = nil
        projectRuntimeState()
        enqueue { coordinator in
            await coordinator.processNow(transition.effects)
            transition.cancelledCorrelationIds.forEach { coordinator.executor?.finish(correlationID: $0) }
        }
    }

    public func readerDidExit() {
        guard isPagePilot || isTTSPilot || isAutoPagePilot else { return }
        guard !isPageProgressCommitPending else {
            failClosed("PAGE_PROGRESS_COMMIT_PENDING")
            return
        }
        enqueue { coordinator in await coordinator.teardownAllNow() }
    }

    /// ReaderReducer calls this before its legacy switch. Pilot means the
    /// canonical event is consumed even on failure; Shadow means native code
    /// remains authoritative and this method returns false.
    @discardableResult
    public func handle(_ event: UiEvent) -> Bool {
        guard configuration.mode(for: event.type.rawValue) == .pilot else { return false }
        switch event.type {
        case .reader_page_next:
            return requestPage(.next, correlationID: event.correlationId)
        case .reader_page_prev:
            return requestPage(.previous, correlationID: event.correlationId)
        case .reader_tts_start:
            return startTTS(correlationID: event.correlationId)
        case .reader_tts_stop:
            return stopTTS(correlationID: event.correlationId)
        case .reader_autoPage_start:
            let interval = Self.integerPayload(event.payload["intervalMs"]) ?? 5_000
            return startAutoPage(intervalMs: interval, correlationID: event.correlationId)
        case .reader_autoPage_stop:
            return stopAutoPage(correlationID: event.correlationId)
        default:
            return false
        }
    }

    private func teardownAllNow() async {
        if let tts = runtime.state.ttsTransaction?.correlationId {
            let transition = runtime.stopTTS(correlationId: tts)
            invalidate(transition.cancelledCorrelationIds)
            await processNow(transition.effects)
            executor?.finish(correlationID: tts)
        }
        if let auto = runtime.state.autoPageTransaction?.correlationId {
            let transition = runtime.stopAutoPage(correlationId: auto)
            invalidate(transition.cancelledCorrelationIds)
            await processNow(transition.effects)
            transition.cancelledCorrelationIds.forEach { executor?.finish(correlationID: $0) }
        }
        if let page = runtime.state.pageTransaction?.correlationId {
            do {
                let transition = try runtime.cancelPageStep(correlationId: page)
                invalidate(transition.cancelledCorrelationIds)
                executor?.finish(correlationID: page)
            } catch {
                // A Core mutation already crossed the commit boundary. Session
                // teardown may finish, but the page correlation must survive.
                lastFailure = error.localizedDescription
                projectRuntimeState()
                return
            }
        }
        pendingPageProposal = nil
        projectRuntimeState()
    }

    private func processNow(_ effects: [ReaderUIEffect]) async {
        guard let executor else {
            failClosed("PLAYBACK_EXECUTOR_MISSING")
            return
        }
        let callbacks = ReaderPlaybackEffectCallbacks(
            speechFinished: { [weak self] correlationID, generation, sliceIndex in
                self?.enqueue { coordinator in
                    await coordinator.speechFinishedNow(
                        correlationID: correlationID,
                        generation: generation,
                        sliceIndex: sliceIndex
                    )
                }
            },
            timerFired: { [weak self] correlationID, generation in
                self?.enqueue { coordinator in
                    coordinator.timerFiredNow(correlationID: correlationID, generation: generation)
                }
            }
        )
        for effect in effects {
            if effect.kind == .core {
                metrics.executedCoreEffects += 1
            } else {
                metrics.executedHostEffects += 1
            }
            let outcome = await executor.execute(effect, callbacks: callbacks)
            await consume(outcome, for: effect)
        }
    }

    private func consume(_ outcome: ReaderPlaybackEffectOutcome, for effect: ReaderUIEffect) async {
        guard let correlationID = effect.correlationId else { return }
        switch outcome {
        case .location(let location):
            guard effect.type == "reader.location.resolve" else {
                metrics.discardedCallbacks += 1
                return
            }
            guard let proposal = executorProposalTarget(correlationID: correlationID) else {
                metrics.discardedCallbacks += 1
                executor?.finish(correlationID: correlationID)
                return
            }
            let transition = runtime.acceptPageLocationResult(
                correlationId: correlationID,
                canonicalLocation: location.locationRevision,
                pageIndex: proposal
            )
            guard transition.accepted else {
                metrics.discardedCallbacks += 1
                executor?.finish(correlationID: correlationID)
                return
            }
            projectRuntimeState()
            await processNow(transition.effects)

        case .progress:
            guard effect.type == "reader.progress.update" else {
                metrics.discardedCallbacks += 1
                return
            }
            let wasAutoPage = runtime.state.pageTransaction?.source == "auto-page"
            let transition: ReaderUIPlaybackTransition
            do {
                transition = try runtime.acceptPageProgressJSONResult(
                    correlationId: correlationID,
                    result: ["stored": .bool(true)]
                )
            } catch {
                metrics.failedEffects += 1
                lastFailure = error.localizedDescription
                await fail(effect: effect, correlationID: correlationID, message: error.localizedDescription)
                return
            }
            guard transition.accepted else {
                metrics.discardedCallbacks += 1
                executor?.finish(correlationID: correlationID)
                return
            }
            committedPageIndex = transition.state.readerPageIndex
            canonicalLocation = transition.state.readerCanonicalLocation
            if wasAutoPage {
                autoPageHasCommittedPage = true
            }
            projectRuntimeState()
            executor?.finish(correlationID: correlationID)
            await processNow(transition.effects)

        case .ttsPlan:
            let transition = runtime.acceptTTSCoreResult(
                coreType: "tts.queue.plan",
                correlationId: correlationID
            )
            guard transition.accepted else {
                metrics.discardedCallbacks += 1
                return
            }
            await processNow(transition.effects)

        case .ttsQueue:
            let transition = runtime.acceptTTSCoreResult(
                coreType: "tts.queue.start",
                correlationId: correlationID
            )
            guard transition.accepted else {
                metrics.discardedCallbacks += 1
                return
            }
            await processNow(transition.effects)

        case .speechStarted:
            let transition = runtime.acceptTTSSystemStart(correlationId: correlationID)
            guard transition.accepted else {
                metrics.discardedCallbacks += 1
                return
            }
            projectRuntimeState()
            await processNow(transition.effects)

        case .timerArmed, .teardownComplete:
            projectRuntimeState()

        case .discarded:
            metrics.discardedCallbacks += 1

        case .failed(let message):
            metrics.failedEffects += 1
            lastFailure = message
            await fail(effect: effect, correlationID: correlationID, message: message)
        }
    }

    private func fail(effect: ReaderUIEffect, correlationID: String, message: String) async {
        let transition: ReaderUIPlaybackTransition?
        switch effect.type {
        case "reader.location.resolve":
            transition = runtime.acceptPageLocationResult(correlationId: correlationID, error: message)
        case "reader.progress.update":
            transition = runtime.acceptPageProgressResult(correlationId: correlationID, error: message)
        case "tts.queue.plan", "tts.queue.start":
            transition = runtime.acceptTTSCoreResult(
                coreType: effect.type,
                correlationId: correlationID,
                error: message
            )
        case "tts.system.start":
            transition = runtime.acceptTTSSystemStart(correlationId: correlationID, error: message)
        case ReaderUIPlaybackDirective.foregroundTimerArm:
            transition = runtime.stopAutoPage(correlationId: correlationID)
        default:
            transition = nil
        }
        if let transition, transition.accepted {
            invalidate(transition.cancelledCorrelationIds)
            projectRuntimeState()
            await processNow(transition.effects.filter { $0.type != effect.type })
            transition.cancelledCorrelationIds.forEach { executor?.finish(correlationID: $0) }
        }
        if effect.type == "reader.location.resolve" || effect.type == "reader.progress.update" {
            // Both Core stages are terminal on failure. Progress failure clears
            // only the pending proposal; the last committed page remains.
            executor?.finish(correlationID: correlationID)
        }
    }

    private func speechFinishedNow(
        correlationID: String,
        generation: Int,
        sliceIndex: Int
    ) async {
        guard runtime.state.ttsTransaction?.correlationId == correlationID,
              runtime.state.ttsTransaction?.stage == "playing",
              let executor else {
            metrics.discardedCallbacks += 1
            return
        }
        let callbacks = ReaderPlaybackEffectCallbacks(
            speechFinished: { [weak self] correlationID, generation, sliceIndex in
                self?.enqueue { coordinator in
                    await coordinator.speechFinishedNow(
                        correlationID: correlationID,
                        generation: generation,
                        sliceIndex: sliceIndex
                    )
                }
            },
            timerFired: { [weak self] correlationID, generation in
                self?.enqueue { coordinator in
                    coordinator.timerFiredNow(correlationID: correlationID, generation: generation)
                }
            }
        )
        switch await executor.advanceTTSAfterSpeech(
            correlationID: correlationID,
            generation: generation,
            sliceIndex: sliceIndex,
            callbacks: callbacks
        ) {
        case .speaking:
            break
        case .completed:
            _ = stopTTS(correlationID: correlationID)
        case .discarded:
            metrics.discardedCallbacks += 1
        case .failed(let message):
            metrics.failedEffects += 1
            lastFailure = message
            _ = stopTTS(correlationID: correlationID)
        }
    }

    private func timerFiredNow(correlationID: String, generation: Int) {
        do {
            let transition = try runtime.acceptAutoPageTimerFired(
                correlationId: correlationID,
                generation: generation
            )
            guard transition.accepted,
                  let page = transition.state.pageTransaction else {
                metrics.discardedCallbacks += 1
                return
            }
            invalidate(transition.cancelledCorrelationIds)
            sequence += 1
            pendingPageProposal = ReaderPlaybackPageProposalRequest(
                correlationID: page.correlationId,
                direction: .next,
                sequence: sequence
            )
            projectRuntimeState()
        } catch {
            failClosed(error.localizedDescription)
        }
    }

    /// All Host/Core execution and callback continuations share this FIFO.
    /// MainActor alone is not sufficient because an `await` is reentrant; the
    /// explicit tail prevents replacement, exit, timer and speech callbacks
    /// from entering a second executor call while the first one is suspended.
    private func enqueue(
        _ operation: @escaping @MainActor (ReaderPlaybackPilotCoordinator) async -> Void
    ) {
        let previous = serialTail
        serialTail = Task { @MainActor [weak self] in
            if let previous { await previous.value }
            guard let self else { return }
            await operation(self)
        }
    }

    private func enqueueAndWait(
        _ operation: @escaping @MainActor (ReaderPlaybackPilotCoordinator) async -> Void
    ) async {
        await withCheckedContinuation { continuation in
            enqueue { coordinator in
                await operation(coordinator)
                continuation.resume()
            }
        }
    }

    private func finishCancelled(_ correlations: [String], preserving active: String) {
        for correlationID in correlations where correlationID != active {
            executor?.finish(correlationID: correlationID)
        }
    }

    private func invalidate(_ correlations: [String]) {
        for correlationID in correlations {
            executor?.invalidate(correlationID: correlationID)
        }
    }

    private func executorProposalTarget(correlationID: String) -> Int? {
        runtime.state.pageTransaction?.correlationId == correlationID
            ? runtime.state.pageTransaction?.layout?.targetPageIndex
            : nil
    }

    private func projectRuntimeState() {
        activeSession = runtime.state.activeSession
        if activeSession != "auto-page" {
            autoPageHasCommittedPage = false
        }
        if let error = runtime.state.error, !error.isEmpty {
            lastFailure = error
        }
    }

    private func failPage(correlationID: String, message: String) {
        lastFailure = message
        let transition = runtime.acceptPageLocationResult(correlationId: correlationID, error: message)
        if transition.accepted {
            executor?.finish(correlationID: correlationID)
            projectRuntimeState()
        }
    }

    private func failClosed(_ message: String) {
        lastFailure = message
        metrics.failedEffects += 1
    }

    private func nextCorrelation(prefix: String) -> String {
        sequence += 1
        return "ios:\(prefix):\(sequence):\(UUID().uuidString)"
    }

    private static func integerPayload(_ value: AnyCodable?) -> Int? {
        if let value = value?.value as? Int { return value }
        if let value = value?.value as? String { return Int(value) }
        return nil
    }
}
