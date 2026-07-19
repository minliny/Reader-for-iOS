import XCTest
import ReaderShellValidation
import ReaderUIContract
import ReaderUIRuntime
@testable import ReaderApp

@MainActor
final class ReaderPlaybackPilotCoordinatorTests: XCTestCase {
    func testLiveConfigurationKeepsPageShadowWhileTtsAndAutoPageArePilot() {
        let navigation = AppNavigationState()
        let coordinator = ReaderPlaybackPilotCoordinator()
        let reducer = ReaderReducer(navigationState: navigation, playbackPilot: coordinator)

        reducer.dispatch(UiEvent(type: .reader_page_next, correlationId: "shadow-page"))

        XCTAssertEqual(navigation.readerPageIndex, 1)
        XCTAssertFalse(coordinator.isPagePilot)
        XCTAssertTrue(coordinator.isTTSPilot)
        XCTAssertTrue(coordinator.isAutoPagePilot)
        XCTAssertTrue(coordinator.acceptsRuntimePageProposals)
        XCTAssertFalse(coordinator.isRuntimePageProjectionActive)
        XCTAssertEqual(coordinator.metrics.admittedTransactions, 0)
        XCTAssertFalse(ReaderView.shouldStartLegacyContentLoader(
            pilotManaged: false,
            playbackPilotActive: true
        ))
    }

    func testPaginatorProposalUsesRealPageRangeScalarAnchorAndMeasuredViewport() throws {
        let text = "A👨‍👩‍👧‍👦B"
        let secondPageStart = text.index(text.startIndex, offsetBy: 2)
        let pages = [
            PageRange(
                index: 0,
                start: text.startIndex,
                end: secondPageStart,
                characterCount: 2
            ),
            PageRange(
                index: 1,
                start: secondPageStart,
                end: text.endIndex,
                characterCount: 1
            ),
        ]

        let proposal = try XCTUnwrap(PaginatedReaderView.pilotPageProposal(
            text: text,
            pages: pages,
            currentPageIndex: 0,
            pageStride: 1,
            direction: .next,
            chapterIndex: 4,
            viewport: CGSize(width: 390.8, height: 844.9),
            fontScale: 1,
            lineHeight: 32.4
        ))

        XCTAssertEqual(proposal.targetPageIndex, 1)
        XCTAssertEqual(proposal.chapterOffset, text[..<secondPageStart].unicodeScalars.count)
        XCTAssertEqual(proposal.viewportWidth, 390)
        XCTAssertEqual(proposal.viewportHeight, 844)
    }

    func testPagePilotBypassesImmediateReducerAndCommitsOnlyCanonicalResult() async throws {
        let executor = FakePlaybackExecutor()
        executor.deferProgress = true
        let coordinator = makeCoordinator(
            configuration: ReaderPlaybackPilotConfiguration(pagePairMode: .pilot),
            executor: executor
        )
        coordinator.bindChapter(chapter())
        let navigation = AppNavigationState()
        let reducer = ReaderReducer(navigationState: navigation, playbackPilot: coordinator)

        reducer.dispatch(UiEvent(type: .reader_page_next, correlationId: "page-commit"))

        XCTAssertEqual(navigation.readerPageIndex, 0, "Pilot must bypass the native immediate increment")
        let request = try XCTUnwrap(coordinator.pendingPageProposal)
        coordinator.providePageProposal(pageProposal(.next, target: 1), correlationID: request.correlationID)

        try await eventually { executor.pendingProgressIDs.contains(request.correlationID) }
        XCTAssertEqual(coordinator.committedPageIndex, 0, "location resolve alone must not project the page")
        XCTAssertEqual(coordinator.canonicalLocation, "reader-location-v1:book-1:4:0")
        XCTAssertFalse(executor.finished.contains(request.correlationID), "DomainContext must survive the commit boundary")

        executor.resumeProgress(request.correlationID)
        try await eventually { coordinator.committedPageIndex == 1 }
        XCTAssertEqual(coordinator.canonicalLocation, "reader-location-v1:book-1:4:120")
        XCTAssertEqual(executor.executed, ["reader.location.resolve", "reader.progress.update"])
        XCTAssertEqual(coordinator.metrics.executedCoreEffects, 2)
        XCTAssertEqual(executor.finished.filter { $0 == request.correlationID }.count, 1)
        XCTAssertEqual(navigation.readerPageIndex, 0, "native reducer remains at zero after Core commit")
    }

    func testPageSupersessionCancelsOldHandleAndDiscardsLateLocation() async throws {
        let executor = FakePlaybackExecutor()
        executor.deferLocations = true
        let coordinator = makeCoordinator(
            configuration: ReaderPlaybackPilotConfiguration(pagePairMode: .pilot),
            executor: executor
        )
        coordinator.bindChapter(chapter())

        XCTAssertTrue(coordinator.requestPage(.next, proposal: pageProposal(.next, target: 1), correlationID: "page-a"))
        try await eventually { executor.pendingLocationIDs.contains("page-a") }
        XCTAssertTrue(coordinator.requestPage(.previous, proposal: pageProposal(.previous, target: 0), correlationID: "page-b"))
        try await eventually { executor.pendingLocationIDs.contains("page-b") }

        XCTAssertEqual(executor.invalidated, ["page-a"])
        executor.resumeLocation("page-b", targetPage: 0)

        try await eventually { executor.finished.contains("page-b") }
        XCTAssertEqual(coordinator.committedPageIndex, 0)
        XCTAssertGreaterThanOrEqual(coordinator.metrics.discardedCallbacks, 1)
        XCTAssertTrue(executor.finished.contains("page-a"))
    }

    func testOutOfOrderProgressOutcomeIsDiscardedWithoutCommittingOrDestroyingPageTransaction() async throws {
        let executor = FakePlaybackExecutor()
        executor.locationReturnsProgressOutOfOrder = true
        let coordinator = makeCoordinator(
            configuration: ReaderPlaybackPilotConfiguration(pagePairMode: .pilot),
            executor: executor
        )
        coordinator.bindChapter(chapter())

        XCTAssertTrue(coordinator.requestPage(
            .next,
            proposal: pageProposal(.next, target: 1),
            correlationID: "page-out-of-order"
        ))
        try await eventually { coordinator.metrics.discardedCallbacks == 1 }

        XCTAssertEqual(coordinator.committedPageIndex, 0)
        XCTAssertTrue(coordinator.hasActiveTransaction)
        XCTAssertFalse(executor.finished.contains("page-out-of-order"))

        executor.locationReturnsProgressOutOfOrder = false
        XCTAssertTrue(coordinator.requestPage(
            .next,
            proposal: pageProposal(.next, target: 1),
            correlationID: "page-recovery"
        ))
        try await eventually { coordinator.committedPageIndex == 1 }
        XCTAssertTrue(executor.invalidated.contains("page-out-of-order"))
    }

    func testTTSPlanQueueSpeechCompletionNextAndStopAreStrictlyOrdered() async throws {
        let executor = FakePlaybackExecutor()
        executor.advanceOutcome = .completed
        let coordinator = makeCoordinator(
            configuration: ReaderPlaybackPilotConfiguration(ttsPairMode: .pilot),
            executor: executor
        )
        coordinator.bindChapter(chapter())

        XCTAssertTrue(coordinator.startTTS(correlationID: "tts-order"))
        try await eventually { coordinator.activeSession == "tts" }
        XCTAssertEqual(
            executor.executed,
            ["tts.queue.plan", "tts.queue.start", "tts.system.start"]
        )

        executor.finishSpeech()
        try await eventually { coordinator.activeSession == nil && executor.executed.contains("tts.queue.stop") }

        XCTAssertEqual(
            executor.executed,
            [
                "tts.queue.plan",
                "tts.queue.start",
                "tts.system.start",
                "tts.queue.report-status",
                "tts.queue.next",
                "tts.system.stop",
                "tts.queue.stop",
            ]
        )
        XCTAssertEqual(coordinator.metrics.admittedTransactions, 1)

        let discardedBefore = coordinator.metrics.discardedCallbacks
        executor.finishSpeech()
        try await eventually { coordinator.metrics.discardedCallbacks > discardedBefore }
    }

    func testAutoPageUsesOneShotCommitThenRearmAndBackgroundTeardown() async throws {
        let executor = FakePlaybackExecutor()
        let coordinator = makeCoordinator(
            configuration: ReaderPlaybackPilotConfiguration(
                pagePairMode: .shadow,
                autoPagePairMode: .pilot
            ),
            executor: executor
        )
        coordinator.bindChapter(chapter())

        XCTAssertTrue(coordinator.startAutoPage(intervalMs: 250, correlationID: "auto-one-shot"))
        try await eventually { executor.timerArmCount == 1 }
        XCTAssertEqual(coordinator.activeSession, "auto-page")
        XCTAssertFalse(coordinator.isRuntimePageProjectionActive, "Shadow page state must not snap to a stale coordinator index")
        let firstTimer = try XCTUnwrap(executor.timerCallback)

        firstTimer("auto-one-shot", executor.timerGeneration)
        let request = try await eventuallyValue { coordinator.pendingPageProposal }
        coordinator.providePageProposal(pageProposal(.next, target: 1), correlationID: request.correlationID)

        try await eventually { coordinator.committedPageIndex == 1 && executor.timerArmCount == 2 }
        XCTAssertTrue(coordinator.isRuntimePageProjectionActive)
        XCTAssertEqual(executor.maxConcurrentLocationEffects, 1)

        coordinator.appDidEnterBackground()
        try await eventually { coordinator.activeSession == nil && executor.executed.last == "timer.foreground.cancel" }
        XCTAssertNil(coordinator.pendingPageProposal)

        let discardedBefore = coordinator.metrics.discardedCallbacks
        firstTimer("auto-one-shot", executor.timerGeneration)
        try await eventually { coordinator.metrics.discardedCallbacks > discardedBefore }
    }

    func testProgressFailurePreservesCommittedPageAndTerminatesAutoPageWithoutRearm() async throws {
        let executor = FakePlaybackExecutor()
        executor.progressFailure = "PROGRESS_STORE_FAILED"
        let coordinator = makeCoordinator(
            configuration: ReaderPlaybackPilotConfiguration(
                pagePairMode: .pilot,
                autoPagePairMode: .pilot
            ),
            executor: executor
        )
        coordinator.bindChapter(chapter())

        XCTAssertTrue(coordinator.startAutoPage(intervalMs: 250, correlationID: "auto-progress-failure"))
        try await eventually { executor.timerArmCount == 1 }
        let timer = try XCTUnwrap(executor.timerCallback)
        timer("auto-progress-failure", executor.timerGeneration)
        let request = try await eventuallyValue { coordinator.pendingPageProposal }
        coordinator.providePageProposal(pageProposal(.next, target: 1), correlationID: request.correlationID)

        try await eventually { coordinator.activeSession == nil && executor.finished.contains(request.correlationID) }
        XCTAssertEqual(coordinator.committedPageIndex, 0)
        XCTAssertEqual(coordinator.canonicalLocation, "reader-location-v1:book-1:4:0")
        XCTAssertEqual(executor.timerArmCount, 1, "failed persistence must not rearm auto-page")
        XCTAssertTrue(coordinator.lastFailure?.contains("PROGRESS_STORE_FAILED") == true)
    }

    func testProgressCommitBoundaryBlocksCancelExitReplacementAndOverlappingPageUntilTerminalResult() async throws {
        let executor = FakePlaybackExecutor()
        executor.deferProgress = true
        let coordinator = makeCoordinator(
            configuration: ReaderPlaybackPilotConfiguration(pagePairMode: .pilot),
            executor: executor
        )
        coordinator.bindChapter(chapter())

        XCTAssertTrue(coordinator.requestPage(
            .next,
            proposal: pageProposal(.next, target: 1),
            correlationID: "page-boundary"
        ))
        try await eventually { executor.pendingProgressIDs.contains("page-boundary") }

        XCTAssertTrue(coordinator.requestPage(
            .previous,
            proposal: pageProposal(.previous, target: 0),
            correlationID: "page-overlap"
        ))
        coordinator.rejectPageProposal(
            ReaderPlaybackPageProposalRequest(
                correlationID: "page-boundary",
                direction: .next,
                sequence: 99
            ),
            message: "renderer disappeared"
        )
        coordinator.readerDidExit()
        await coordinator.replaceChapter(ReaderPlaybackChapterContext(
            sourceID: "source-2",
            bookID: "book-2",
            chapterIndex: 0,
            chapterTitle: "Other",
            chapterURL: "https://example.test/other",
            content: "Other content"
        ))

        XCTAssertFalse(executor.invalidated.contains("page-boundary"))
        XCTAssertFalse(executor.finished.contains("page-boundary"))
        XCTAssertEqual(executor.boundChapters.last?.bookID, "book-1")
        XCTAssertEqual(coordinator.committedPageIndex, 0)
        XCTAssertTrue(coordinator.lastFailure?.contains("PAGE_PROGRESS_COMMIT_PENDING") == true)

        executor.resumeProgress("page-boundary")
        try await eventually { coordinator.committedPageIndex == 1 }
        XCTAssertEqual(executor.finished.filter { $0 == "page-boundary" }.count, 1)
        XCTAssertFalse(executor.executedCorrelationIDs.contains("page-overlap"))
    }

    func testStartingAutoPageSeriallyTearsDownTTSBeforeTimerArm() async throws {
        let executor = FakePlaybackExecutor()
        executor.effectDelayNanoseconds = 2_000_000
        let coordinator = makeCoordinator(
            configuration: ReaderPlaybackPilotConfiguration(
                ttsPairMode: .pilot,
                autoPagePairMode: .pilot
            ),
            executor: executor
        )
        coordinator.bindChapter(chapter())

        _ = coordinator.startTTS(correlationID: "tts-replaced")
        try await eventually { coordinator.activeSession == "tts" }
        _ = coordinator.startAutoPage(intervalMs: 500, correlationID: "auto-replacement")
        try await eventually { coordinator.activeSession == "auto-page" && executor.timerArmCount == 1 }

        XCTAssertEqual(
            executor.executed,
            [
                "tts.queue.plan",
                "tts.queue.start",
                "tts.system.start",
                "tts.system.stop",
                "tts.queue.stop",
                "timer.foreground.arm",
            ]
        )
        XCTAssertTrue(executor.invalidated.contains("tts-replaced"))
        XCTAssertEqual(executor.maxExecutorConcurrency, 1)
    }

    func testStartingTTSSeriallyCancelsAutoTimerBeforeCorePlan() async throws {
        let executor = FakePlaybackExecutor()
        executor.effectDelayNanoseconds = 2_000_000
        let coordinator = makeCoordinator(
            configuration: ReaderPlaybackPilotConfiguration(
                ttsPairMode: .pilot,
                autoPagePairMode: .pilot
            ),
            executor: executor
        )
        coordinator.bindChapter(chapter())

        _ = coordinator.startAutoPage(intervalMs: 500, correlationID: "auto-replaced")
        try await eventually { coordinator.activeSession == "auto-page" && executor.timerArmCount == 1 }
        _ = coordinator.startTTS(correlationID: "tts-replacement")
        try await eventually { coordinator.activeSession == "tts" }

        XCTAssertEqual(
            executor.executed,
            [
                "timer.foreground.arm",
                "timer.foreground.cancel",
                "tts.queue.plan",
                "tts.queue.start",
                "tts.system.start",
            ]
        )
        XCTAssertTrue(executor.invalidated.contains("auto-replaced"))
        XCTAssertEqual(executor.maxExecutorConcurrency, 1)
    }

    private func makeCoordinator(
        configuration: ReaderPlaybackPilotConfiguration,
        executor: FakePlaybackExecutor
    ) -> ReaderPlaybackPilotCoordinator {
        ReaderPlaybackPilotCoordinator(
            configuration: configuration,
            runtime: ReaderUIRuntime(state: ReaderUIState(routeId: "immersive-reading")),
            executor: executor
        )
    }

    private func chapter() -> ReaderPlaybackChapterContext {
        ReaderPlaybackChapterContext(
            sourceID: "source-1",
            bookID: "book-1",
            chapterIndex: 4,
            chapterTitle: "Chapter 5",
            chapterURL: "https://example.test/chapter-5",
            content: "First paragraph.\n\nSecond paragraph.",
            initialPageIndex: 0,
            canonicalLocation: "reader-location-v1:book-1:4:0"
        )
    }

    private func pageProposal(
        _ direction: ReaderPlaybackPageDirection,
        target: Int
    ) -> ReaderPlaybackPageProposal {
        ReaderPlaybackPageProposal(
            direction: direction,
            targetPageIndex: target,
            pageCount: 3,
            chapterIndex: 4,
            chapterOffset: target == 0 ? 0 : 120,
            chapterProgress: target == 0 ? 0 : 0.5,
            viewportWidth: 390,
            viewportHeight: 844,
            fontScale: 1,
            lineHeight: 32.4
        )
    }

    private func eventually(
        attempts: Int = 500,
        _ condition: @escaping @MainActor () -> Bool
    ) async throws {
        for _ in 0..<attempts {
            if condition() { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        XCTFail("condition did not become true")
    }

    private func eventuallyValue<Value>(
        attempts: Int = 500,
        _ value: @escaping @MainActor () -> Value?
    ) async throws -> Value {
        for _ in 0..<attempts {
            if let result = value() { return result }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        throw ReaderUIRuntimeFailure(code: "TEST_TIMEOUT", message: "value did not become available")
    }
}

@MainActor
private final class FakePlaybackExecutor: ReaderPlaybackEffectExecuting {
    var executed: [String] = []
    var executedCorrelationIDs: [String] = []
    var invalidated: [String] = []
    var finished: [String] = []
    var boundChapters: [ReaderPlaybackChapterContext] = []
    var deferLocations = false
    var locationReturnsProgressOutOfOrder = false
    var deferProgress = false
    var progressFailure: String?
    var advanceOutcome: ReaderPlaybackTTSAdvanceOutcome = .speaking
    var timerCallback: (@MainActor (String, Int) -> Void)?
    var timerGeneration = 0
    var timerArmCount = 0
    var maxConcurrentLocationEffects = 0
    var maxExecutorConcurrency = 0
    var effectDelayNanoseconds: UInt64 = 0

    private var chapter: ReaderPlaybackChapterContext?
    private var proposals: [String: ReaderPlaybackPageProposal] = [:]
    private var pendingLocations: [String: CheckedContinuation<ReaderPlaybackEffectOutcome, Never>] = [:]
    private var pendingProgress: [String: CheckedContinuation<ReaderPlaybackEffectOutcome, Never>] = [:]
    private var speechCallback: (@MainActor (String, Int, Int) -> Void)?
    private var speechCorrelationID = ""
    private var speechGeneration = 0
    private var speechSliceIndex = 0
    private var concurrentLocationEffects = 0
    private var executorConcurrency = 0

    var pendingLocationIDs: Set<String> { Set(pendingLocations.keys) }
    var pendingProgressIDs: Set<String> { Set(pendingProgress.keys) }

    func bindChapter(_ context: ReaderPlaybackChapterContext) {
        chapter = context
        boundChapters.append(context)
    }

    func setPageProposal(_ proposal: ReaderPlaybackPageProposal, correlationID: String) {
        proposals[correlationID] = proposal
    }

    func execute(
        _ effect: ReaderUIEffect,
        callbacks: ReaderPlaybackEffectCallbacks
    ) async -> ReaderPlaybackEffectOutcome {
        executorConcurrency += 1
        maxExecutorConcurrency = max(maxExecutorConcurrency, executorConcurrency)
        defer { executorConcurrency -= 1 }
        if effectDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: effectDelayNanoseconds)
        }
        executed.append(effect.type)
        guard let correlationID = effect.correlationId else { return .failed("missing correlation") }
        executedCorrelationIDs.append(correlationID)
        switch effect.type {
        case "reader.location.resolve":
            if locationReturnsProgressOutOfOrder {
                return progressOutcome(correlationID: correlationID)
            }
            concurrentLocationEffects += 1
            maxConcurrentLocationEffects = max(maxConcurrentLocationEffects, concurrentLocationEffects)
            if deferLocations {
                let outcome = await withCheckedContinuation { continuation in
                    pendingLocations[correlationID] = continuation
                }
                concurrentLocationEffects -= 1
                return outcome
            }
            concurrentLocationEffects -= 1
            return locationOutcome(correlationID: correlationID)

        case "reader.progress.update":
            if let progressFailure {
                return .failed(progressFailure)
            }
            if deferProgress {
                return await withCheckedContinuation { continuation in
                    pendingProgress[correlationID] = continuation
                }
            }
            return progressOutcome(correlationID: correlationID)

        case "tts.queue.plan":
            return .ttsPlan(plan())
        case "tts.queue.start":
            return .ttsQueue(snapshot(state: .playing, index: 0, completed: 0))
        case "tts.system.start":
            speechCallback = callbacks.speechFinished
            speechCorrelationID = correlationID
            speechGeneration += 1
            speechSliceIndex = 0
            return .speechStarted
        case "tts.system.stop", "tts.queue.stop", "timer.foreground.cancel":
            return .teardownComplete
        case "timer.foreground.arm":
            timerCallback = callbacks.timerFired
            timerGeneration = Int(effect.payload["generation"] ?? "") ?? 0
            timerArmCount += 1
            return .timerArmed
        default:
            return .failed("unexpected effect \(effect.type)")
        }
    }

    func advanceTTSAfterSpeech(
        correlationID: String,
        generation: Int,
        sliceIndex: Int,
        callbacks: ReaderPlaybackEffectCallbacks
    ) async -> ReaderPlaybackTTSAdvanceOutcome {
        executorConcurrency += 1
        maxExecutorConcurrency = max(maxExecutorConcurrency, executorConcurrency)
        defer { executorConcurrency -= 1 }
        if effectDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: effectDelayNanoseconds)
        }
        executed.append("tts.queue.report-status")
        executed.append("tts.queue.next")
        if case .speaking = advanceOutcome {
            speechCallback = callbacks.speechFinished
            speechCorrelationID = correlationID
            speechGeneration = generation
            speechSliceIndex = sliceIndex + 1
            executed.append("tts.system.start")
        }
        return advanceOutcome
    }

    func invalidate(correlationID: String) {
        invalidated.append(correlationID)
        if let continuation = pendingLocations.removeValue(forKey: correlationID) {
            continuation.resume(returning: locationOutcome(correlationID: correlationID, targetPage: 1))
        }
        if let continuation = pendingProgress.removeValue(forKey: correlationID) {
            continuation.resume(returning: .discarded)
        }
    }

    func finish(correlationID: String) {
        finished.append(correlationID)
        proposals[correlationID] = nil
        if let continuation = pendingProgress.removeValue(forKey: correlationID) {
            continuation.resume(returning: .discarded)
        }
    }

    func resumeLocation(_ correlationID: String, targetPage: Int) {
        guard let continuation = pendingLocations.removeValue(forKey: correlationID) else { return }
        continuation.resume(returning: locationOutcome(correlationID: correlationID, targetPage: targetPage))
    }

    func resumeProgress(_ correlationID: String) {
        guard let continuation = pendingProgress.removeValue(forKey: correlationID) else { return }
        continuation.resume(returning: progressOutcome(correlationID: correlationID))
    }

    func finishSpeech() {
        speechCallback?(speechCorrelationID, speechGeneration, speechSliceIndex)
    }

    private func locationOutcome(
        correlationID: String,
        targetPage: Int? = nil
    ) -> ReaderPlaybackEffectOutcome {
        let proposal = proposals[correlationID]
        let target = targetPage ?? proposal?.targetPageIndex ?? 0
        return .location(CoreReaderLocationStageResult(
            bookID: chapter?.bookID ?? "book-1",
            chapterIndex: chapter?.chapterIndex ?? 4,
            chapterOffset: target == 0 ? 0 : 120,
            chapterProgress: target == 0 ? 0 : 0.5,
            locationRevision: "reader-location-v1:book-1:4:\(target == 0 ? 0 : 120)",
            resolverVersion: "reader.location.resolve.v1.reflow",
            primaryAnchor: "chapter-offset",
            fallbackAnchor: "chapter-progress",
            layoutIndependent: true
        ))
    }

    private func progressOutcome(correlationID: String) -> ReaderPlaybackEffectOutcome {
        let proposal = proposals[correlationID]
        let target = proposal?.targetPageIndex ?? 0
        return .progress(CoreReaderProgressStageResult(
            sourceID: chapter?.sourceID ?? "source-1",
            bookID: chapter?.bookID ?? "book-1",
            updatedAt: 1_720_000_000,
            chapterIndex: chapter?.chapterIndex ?? 4,
            chapterOffset: target == 0 ? 0 : 120,
            chapterProgress: target == 0 ? 0 : 0.5,
            locationRevision: "reader-location-v1:book-1:4:\(target == 0 ? 0 : 120)",
            stored: true
        ))
    }

    private func plan() -> CoreTTSSlicePlan {
        CoreTTSSlicePlan(
            chapter: CoreTTSChapterReference(
                sourceID: "source-1",
                bookID: "book-1",
                chapterIndex: 4,
                chapterTitle: "Chapter 5",
                chapterURL: "https://example.test/chapter-5"
            ),
            strategy: .paragraph,
            slices: [
                CoreTTSSlice(index: 0, text: "First paragraph.", charStart: 0, charEnd: 16, paragraphIndex: 0),
                CoreTTSSlice(index: 1, text: "Second paragraph.", charStart: 18, charEnd: 35, paragraphIndex: 1),
            ],
            sourceCharCount: 35
        )
    }

    private func snapshot(
        state: CoreTTSQueueState,
        index: Int?,
        completed: Int
    ) -> CoreTTSQueueSnapshot {
        CoreTTSQueueSnapshot(
            state: state,
            currentSliceIndex: index,
            totalSlices: 2,
            completedSlices: completed,
            chapter: plan().chapter,
            sliceStatuses: [.speaking, .pending]
        )
    }
}
