import XCTest
import ReaderUIContract
import ReaderUIRuntime
@testable import ReaderApp

/// R8 executable-runtime mixed-rollout tests.
///
/// Live cohorts are mixed Pilot/Shadow. Explicit rollback configurations keep
/// native fallback and comparison behavior independently testable.
@MainActor
final class ReaderUIRuntimeShadowParityTests: XCTestCase {
    func testLiveConfigurationMatchesConsumerLockExactly() throws {
        let lock = try loadConsumerLock()
        let configuration = ReaderUIRuntimeShadowConfiguration.live

        XCTAssertEqual(
            lock.readerUiVersion,
            try expectedReaderUIVersion(for: lock),
            "Reader UI version must come from the verified release artifact when supplied, otherwise from the checked-in consumer lock"
        )
        XCTAssertEqual(lock.hostRequestSchemaVersion, "1.2.0")
        XCTAssertEqual(lock.runtimeActionsSha256, "0ac249341d8de651314687d8352bc1c3f62d3778371ff500f1f0a025a64be82c")
        XCTAssertEqual(lock.rollout.mode, configuration.defaultMode.rawValue)
        XCTAssertEqual(lock.rollout.coveredEvents, configuration.coveredEvents)
        XCTAssertEqual(
            lock.rollout.cohorts,
            configuration.cohorts.map {
                ConsumerLock.Rollout.Cohort(
                    id: $0.id,
                    mode: $0.mode.rawValue,
                    effectPolicy: $0.effectPolicy,
                    evidence: $0.evidence,
                    rollback: $0.rollback,
                    events: $0.events
                )
            }
        )
        XCTAssertEqual(GeneratedRuntimeActions.schemaVersion, 3)
        XCTAssertEqual(configuration.coveredEvents.count, 35)
        XCTAssertEqual(configuration.coveredEvents.filter { configuration.mode(for: $0) == .pilot }.count, 7)
        XCTAssertEqual(configuration.coveredEvents.filter { configuration.mode(for: $0) == .shadow }.count, 28)
        XCTAssertTrue(
            Set(configuration.coveredEvents).isSubset(of: Set(GeneratedRuntimeActions.byEvent.keys)),
            "The host allowlist may select generated actions but must never copy or invent action semantics"
        )
        XCTAssertEqual(configuration.mode(for: "reader.directory.open"), .pilot)
        XCTAssertEqual(configuration.mode(for: "reader.directory.close"), .pilot)
        XCTAssertEqual(configuration.mode(for: "book.open"), .pilot)
        XCTAssertEqual(configuration.mode(for: "reader.page.next"), .shadow)
        XCTAssertEqual(configuration.mode(for: "reader.page.prev"), .shadow)
        XCTAssertEqual(configuration.mode(for: "reader.tts.start"), .pilot)
        XCTAssertEqual(configuration.mode(for: "reader.tts.stop"), .pilot)
        XCTAssertEqual(configuration.mode(for: "reader.autoPage.start"), .pilot)
        XCTAssertEqual(configuration.mode(for: "reader.autoPage.stop"), .pilot)
        XCTAssertEqual(configuration.mode(for: "import.start"), .shadow)
        XCTAssertEqual(configuration.mode(for: "import.apply"), .shadow)
        XCTAssertEqual(configuration.mode(for: "import.cancel"), .shadow)
        XCTAssertEqual(configuration.mode(for: "source.switch.open"), .shadow)
        XCTAssertEqual(configuration.mode(for: "source.switch.cancel"), .shadow)
        XCTAssertEqual(configuration.mode(for: "source.switch.confirm"), .shadow)
        XCTAssertEqual(configuration.mode(for: "source.switch.rollback"), .shadow)
        XCTAssertEqual(configuration.mode(for: "reader.sourceSwitch.open"), .shadow)
        XCTAssertEqual(configuration.mode(for: "reader.sourceSwitch.close"), .shadow)
        XCTAssertEqual(configuration.mode(for: "reader.replace.apply"), .shadow)
        XCTAssertEqual(configuration.mode(for: "reader.replace.create"), .shadow)
        XCTAssertEqual(configuration.mode(for: "reader.replace.validate"), .shadow)
        XCTAssertEqual(configuration.mode(for: "rss.refresh"), .shadow)
        XCTAssertEqual(configuration.mode(for: "rss.subscription.add"), .shadow)
        XCTAssertEqual(configuration.mode(for: "rss.subscription.delete"), .shadow)
        XCTAssertEqual(configuration.mode(for: "rss.subscription.edit"), .shadow)
        XCTAssertEqual(configuration.mode(for: "rss.entry.open"), .shadow)
        XCTAssertEqual(configuration.mode(for: "rss.favorite.add"), .shadow)
        XCTAssertEqual(configuration.mode(for: "rss.favorite.remove"), .shadow)
        XCTAssertEqual(configuration.mode(for: "sync.run"), .shadow)
        XCTAssertEqual(configuration.mode(for: "webdav.config.test"), .shadow)
        XCTAssertEqual(configuration.mode(for: "sync.start"), .shadow)
        XCTAssertEqual(configuration.mode(for: "sync.progress"), .shadow)
        XCTAssertEqual(configuration.mode(for: "sync.complete"), .shadow)
        XCTAssertEqual(configuration.mode(for: "sync.conflict"), .shadow)
        XCTAssertEqual(configuration.mode(for: "sync.resolve"), .shadow)
    }

    func testConsumerVersionSourceAcceptsMatchingVerifiedReleaseWithoutPinnedVersion() throws {
        let lock = try loadConsumerLock()
        let verifiedRelease = VerifiedReaderUIRelease(
            readerUiVersion: lock.readerUiVersion,
            releaseId: lock.releaseIdentity.releaseId,
            sourceSha: lock.releaseIdentity.sourceSha,
            manifestSha256: lock.releaseIdentity.manifestSha256,
            targetConfigSha256: lock.releaseIdentity.targetConfigSha256
        )

        XCTAssertEqual(
            try expectedReaderUIVersion(for: lock, verifiedRelease: verifiedRelease),
            lock.readerUiVersion
        )
    }

    func testActualAppCoordinatorDispatchKeepsContinuousDirectoryPilotState() throws {
        let navigation = AppNavigationState()
        let runtime = ReaderUIRuntimeCoordinator()
        let coordinator = ReaderCoordinator(
            navigationState: navigation,
            runtimeShadow: runtime
        )

        coordinator.openBookDirectory(bookId: "book-1")

        XCTAssertEqual(runtime.state.overlay, "directory")
        XCTAssertTrue(runtime.isDirectoryPresented)
        XCTAssertEqual(navigation.overlayState, .none, "Pilot must not replay native directory open")
        XCTAssertEqual(runtime.metrics.covered, 1)
        XCTAssertEqual(runtime.lastTransition?.effects, [])

        coordinator.closeBookDirectory()

        XCTAssertNil(runtime.state.overlay)
        XCTAssertFalse(runtime.isDirectoryPresented)
        XCTAssertEqual(navigation.overlayState, .none)
        XCTAssertEqual(runtime.metrics.covered, 2)
        XCTAssertEqual(runtime.metrics.fallback, 0)
        XCTAssertEqual(runtime.metrics.runtimeError, 0)
        XCTAssertEqual(runtime.metrics.mismatch, 0)
    }

    func testProductionIntentRouterSendsOpenCloseAndBackThroughCoordinator() {
        let navigation = AppNavigationState()
        let runtime = ReaderUIRuntimeCoordinator()
        let coordinator = ReaderCoordinator(navigationState: navigation, runtimeShadow: runtime)
        var exitCount = 0

        let entry = ReaderDirectoryPilotIntentRouter(
            isPresented: runtime.isDirectoryPresented,
            onOpen: { coordinator.openBookDirectory(bookId: "book-1") },
            onClose: { coordinator.closeBookDirectory() }
        )
        XCTAssertTrue(entry.toggle())
        XCTAssertTrue(runtime.isDirectoryPresented)

        let close = ReaderDirectoryPilotIntentRouter(
            isPresented: runtime.isDirectoryPresented,
            onOpen: { coordinator.openBookDirectory(bookId: "book-1") },
            onClose: { coordinator.closeBookDirectory() }
        )
        XCTAssertTrue(close.toggle())
        XCTAssertFalse(runtime.isDirectoryPresented)

        coordinator.openBookDirectory(bookId: "book-1")
        let back = ReaderDirectoryPilotIntentRouter(
            isPresented: runtime.isDirectoryPresented,
            onOpen: { coordinator.openBookDirectory(bookId: "book-1") },
            onClose: { coordinator.closeBookDirectory() }
        )
        back.handleBack { exitCount += 1 }

        XCTAssertFalse(runtime.isDirectoryPresented)
        XCTAssertEqual(exitCount, 0, "Reader back closes the Pilot surface before exiting the reader")
        XCTAssertEqual(runtime.metrics.covered, 4)
        XCTAssertEqual(navigation.overlayState, .none)
    }

    func testDirectoryPilotIsExactlyOnceWithNoNativeWriteOrRuntimeEffect() throws {
        let navigation = AppNavigationState()
        navigation.setOverlay(.dialog)
        let runtime = ReaderUIRuntimeCoordinator()
        let reducer = ReaderReducer(navigationState: navigation, runtimeShadow: runtime)

        reducer.dispatch(UiEvent(type: .reader_directory_open, correlationId: "directory-once"))

        let transition = try XCTUnwrap(runtime.lastTransition)
        XCTAssertEqual(transition.event, "reader.directory.open")
        XCTAssertEqual(transition.effects, [])
        XCTAssertEqual(runtime.metrics.covered, 1)
        XCTAssertEqual(runtime.metrics.suppressedRuntimeEffects, 0)
        XCTAssertEqual(navigation.overlayState, .dialog, "Native reducer must not replay the Pilot event")
    }

    func testRuntimeEffectsAreRecordedAndSuppressedWhileNativeReducerWritesOnce() throws {
        let navigation = AppNavigationState()
        let shadow = ReaderUIRuntimeShadowCoordinator(
            configuration: bookOpenShadowRollbackConfiguration
        )
        let reducer = ReaderReducer(navigationState: navigation, runtimeShadow: shadow)
        let event = UiEvent(
            type: .book_open,
            payload: [
                "bookId": AnyCodable("book-1"),
                "sourceId": AnyCodable("source-1"),
                "sourceKind": AnyCodable("remote"),
            ],
            correlationId: "open-1"
        )

        reducer.dispatch(event)

        let transition = try XCTUnwrap(shadow.lastTransition)
        XCTAssertEqual(
            transition.effects.map(\.type),
            ["source.detail"]
        )
        XCTAssertEqual(transition.effects.map(\.kind), [.core])
        XCTAssertEqual(transition.effects.map(\.correlationId), ["open-1"])
        XCTAssertEqual(shadow.metrics.suppressedRuntimeEffects, 1)

        // If shadow dispatched or replayed an effect/state mutation, this path
        // would contain duplicate writes. Native reducer remains exactly once.
        XCTAssertEqual(navigation.navigationPath.count, 1)
        XCTAssertEqual(ReaderViewState(from: navigation).routeId.rawValue, "book-detail")
        XCTAssertEqual(shadow.state.routeId, "immersive-reading")
        XCTAssertEqual(shadow.metrics.mismatch, 1, "Shadow records the known pre-Pilot native/runtime route difference")
    }

    func testBookOpenShadowInfersOnlyTheKnownLocalSourceSentinel() throws {
        let shadow = ReaderUIRuntimeShadowCoordinator(
            configuration: bookOpenShadowRollbackConfiguration
        )
        let result = try XCTUnwrap(shadow.observe(UiEvent(
            type: .book_open,
            payload: [
                "bookId": AnyCodable("core-local-book-1"),
                "sourceId": AnyCodable("local-book"),
            ],
            correlationId: "open-local-1"
        ))).get()

        XCTAssertEqual(result.effects.map(\.type), ["chapter.list"])
        XCTAssertEqual(result.effects.map(\.correlationId), ["open-local-1"])
        XCTAssertEqual(shadow.metrics.suppressedRuntimeEffects, 1)
    }

    func testRuntimeFailureDoesNotBlockOrReplaceNativeProductionWrite() {
        let navigation = AppNavigationState()
        let shadow = ReaderUIRuntimeShadowCoordinator(
            configuration: bookOpenShadowRollbackConfiguration
        )
        let reducer = ReaderReducer(navigationState: navigation, runtimeShadow: shadow)

        // Missing sourceId is invalid for the runtime action, but shadow mode
        // must still let the native production reducer process book.open.
        reducer.dispatch(UiEvent(
            type: .book_open,
            payload: ["bookId": AnyCodable("native-still-writes")]
        ))

        XCTAssertEqual(shadow.metrics.covered, 1)
        XCTAssertEqual(shadow.metrics.runtimeError, 1)
        XCTAssertEqual(shadow.lastFailure?.code, "INVALID_TYPED_PAYLOAD")
        XCTAssertEqual(navigation.navigationPath.count, 1)
        guard case .bookDetail(let bookURL, _, _) = navigation.navigationPath.last else {
            return XCTFail("Native reducer must remain authoritative after a shadow runtime failure")
        }
        XCTAssertEqual(bookURL, "native-still-writes")
    }

    func testEventOutsideAllowlistIsCountedAsFallbackAndNeverTouchesRuntimeState() {
        let navigation = AppNavigationState()
        let shadow = ReaderUIRuntimeShadowCoordinator()
        let reducer = ReaderReducer(navigationState: navigation, runtimeShadow: shadow)

        reducer.dispatch(UiEvent(type: .reader_control_toggle))

        XCTAssertEqual(navigation.overlayState, .sheet)
        XCTAssertNil(shadow.state.overlay)
        XCTAssertEqual(shadow.metrics.covered, 0)
        XCTAssertEqual(shadow.metrics.fallback, 1)
        XCTAssertEqual(shadow.metrics.runtimeError, 0)
    }

    func testSemanticMismatchCounterRecordsDivergenceWithoutRepairingNativeState() throws {
        let navigation = AppNavigationState()
        let shadow = ReaderUIRuntimeShadowCoordinator(
            configuration: playbackShadowRollbackConfiguration,
            state: ReaderUIState(routeId: "immersive-reading")
        )
        let event = UiEvent(type: .reader_tts_start, correlationId: "tts-shadow-pending")
        let runtimeResult = try XCTUnwrap(shadow.observe(event))

        // Deliberately skip the native reducer to exercise telemetry only.
        shadow.compareNativeResult(
            for: event,
            runtimeResult: runtimeResult,
            navigationState: navigation
        )

        XCTAssertEqual(shadow.metrics.mismatch, 1)
        XCTAssertEqual(navigation.activeSession, .none)
        XCTAssertNil(shadow.state.activeSession, "TTS is not active before plan/queue/system success")
        XCTAssertEqual(shadow.state.ttsTransaction?.stage, "awaiting-plan")
        XCTAssertNotNil(shadow.lastMismatch)
    }

    func testDirectoryPilotFailureFailsClosedWithoutNativeFallback() {
        let navigation = AppNavigationState()
        navigation.setOverlay(.dialog)
        let failingRuntime = FailingDirectoryRuntime()
        let runtime = ReaderUIRuntimeCoordinator(
            configuration: .live,
            runtime: failingRuntime
        )
        let reducer = ReaderReducer(navigationState: navigation, runtimeShadow: runtime)

        reducer.dispatch(UiEvent(type: .reader_directory_open))

        XCTAssertEqual(runtime.metrics.covered, 1)
        XCTAssertEqual(runtime.metrics.runtimeError, 1)
        XCTAssertEqual(runtime.lastFailure?.code, "INJECTED_DIRECTORY_FAILURE")
        XCTAssertNil(runtime.state.overlay)
        XCTAssertFalse(runtime.isDirectoryPresented)
        XCTAssertEqual(navigation.overlayState, .dialog, "Pilot failure must preserve production state")
    }

    func testDirectoryClosePreservesRuntimeReplacementAndNativeState() throws {
        let navigation = AppNavigationState()
        navigation.setOverlay(.sheet)
        let sharedRuntime = ReaderUIRuntime()
        let runtime = ReaderUIRuntimeCoordinator(configuration: .live, runtime: sharedRuntime)
        let coordinator = ReaderCoordinator(navigationState: navigation, runtimeShadow: runtime)

        coordinator.openBookDirectory(bookId: "book-1")
        XCTAssertEqual(sharedRuntime.state.overlay, "directory")

        // Same-runtime replacement seam mirrors the upstream schema-2 test;
        // it does not expand the production consumer allowlist.
        _ = try sharedRuntime.dispatch(event: "overlay.sheet.open")
        coordinator.closeBookDirectory()

        XCTAssertEqual(sharedRuntime.state.overlay, "sheet")
        XCTAssertFalse(runtime.isDirectoryPresented)
        XCTAssertEqual(navigation.overlayState, .sheet)
        XCTAssertEqual(runtime.metrics.covered, 2)
    }

    func testProductionReplacementClosesPilotBeforeNativeModuleFallbackOnce() {
        let navigation = AppNavigationState()
        let runtime = ReaderUIRuntimeCoordinator()
        let coordinator = ReaderCoordinator(navigationState: navigation, runtimeShadow: runtime)

        coordinator.openBookDirectory(bookId: "book-1")
        let replacement = ReaderDirectoryPilotIntentRouter(
            isPresented: runtime.isDirectoryPresented,
            onOpen: { coordinator.openBookDirectory(bookId: "book-1") },
            onClose: { coordinator.closeBookDirectory() }
        )
        XCTAssertTrue(replacement.closeIfPresented())
        coordinator.readerModuleSwitch(module: "appearance")

        XCTAssertFalse(runtime.isDirectoryPresented)
        XCTAssertEqual(navigation.overlayState, .sheet)
        XCTAssertEqual(navigation.focusTarget, "reader-module-appearance")
        XCTAssertEqual(runtime.metrics.covered, 2)
        XCTAssertEqual(runtime.metrics.fallback, 1)

        coordinator.closeBookDirectory()
        XCTAssertEqual(navigation.overlayState, .sheet, "Stale Pilot close must not clear the native replacement")
        XCTAssertEqual(runtime.metrics.covered, 3)
    }

    func testDirectoryCloseOnlyClearsMatchingDirectoryInSchema2Runtime() throws {
        let runtime = ReaderUIRuntimeCoordinator()

        _ = try XCTUnwrap(runtime.observe(UiEvent(type: .reader_directory_open))).get()
        XCTAssertEqual(runtime.state.overlay, "directory")

        _ = try XCTUnwrap(runtime.observe(UiEvent(type: .reader_directory_close))).get()
        XCTAssertNil(runtime.state.overlay)
    }

    func testDirectoryPanelProjectionKeepsNativeChapterStateInputs() throws {
        let source = try String(contentsOf: repositoryRoot()
            .appendingPathComponent("iOS/Features/Reader/ReaderView.swift"))

        XCTAssertTrue(source.contains("chapterList: viewModel.chapterList"))
        XCTAssertTrue(source.contains("currentChapterIndex: viewModel.currentChapterIndex"))
        XCTAssertTrue(source.contains("semantic `overlay == directory` selects"))
    }

    func testSessionMutualExclusionMatchesRuntimeLatestIntentWinsThroughActualDispatch() {
        let navigation = AppNavigationState()
        let shadow = ReaderUIRuntimeShadowCoordinator(
            configuration: playbackShadowRollbackConfiguration,
            state: ReaderUIState(routeId: "immersive-reading")
        )
        let reducer = ReaderReducer(navigationState: navigation, runtimeShadow: shadow)

        reducer.dispatch(UiEvent(type: .reader_tts_start, correlationId: "tts-shadow-latest"))
        XCTAssertNil(shadow.state.activeSession)
        XCTAssertEqual(shadow.state.ttsTransaction?.stage, "awaiting-plan")
        XCTAssertEqual(navigation.activeSession, .tts(playing: true))

        reducer.dispatch(UiEvent(
            type: .reader_autoPage_start,
            payload: ["intervalMs": AnyCodable("5000")],
            correlationId: "auto-shadow-latest"
        ))
        XCTAssertEqual(shadow.state.activeSession, "auto-page")
        XCTAssertNil(shadow.state.ttsTransaction)
        XCTAssertEqual(shadow.state.autoPageTransaction?.intervalMs, 5_000)
        XCTAssertEqual(navigation.activeSession, .autoPage(playing: true))
        XCTAssertEqual(navigation.overlayState, .none)
        XCTAssertEqual(shadow.metrics.covered, 2)
        XCTAssertEqual(shadow.metrics.mismatch, 0)
        // TTS plans Core slicing; replacement invalidates it before queue load.
        // Auto-page plans one foreground one-shot timer. Neither executes.
        XCTAssertEqual(shadow.metrics.suppressedRuntimeEffects, 2)
    }

    func testCustomGeneratedActionConfigurationCanExerciseGuardWithoutExpandingLiveAllowlist() throws {
        let configuration = ReaderUIRuntimeShadowConfiguration(
            coveredEvents: ["overlay.sheet.open", "mainTab.select"]
        )
        let shadow = ReaderUIRuntimeShadowCoordinator(configuration: configuration)

        _ = try XCTUnwrap(shadow.observe(UiEvent(type: .overlay_sheet_open))).get()
        let result = try XCTUnwrap(shadow.observe(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("rss")]
        )))

        guard case .failure(let failure) = result else {
            return XCTFail("Reader-UI runtime must block tab switching while an overlay is open")
        }
        XCTAssertEqual(failure.code, "OVERLAY_GUARD")
        XCTAssertEqual(shadow.state.tab, "bookshelf")
        XCTAssertEqual(ReaderUIRuntimeShadowConfiguration.live.coveredEvents, [
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
        ])
    }

    // MARK: - book.open pilot parity

    func testBookOpenPilotConfigurationLiveIsPilotMode() {
        XCTAssertEqual(ReaderBookOpenPilotConfiguration.live.mode, .pilot)
        XCTAssertEqual(ReaderUIRuntimeShadowConfiguration.live.mode(for: "book.open"), .pilot)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.cohorts.first { $0.id == "book-open-pilot" }?.mode,
            .pilot
        )
    }

    func testBookOpenPilotAdmitsRuntimeTransactionBeforeNativePresentation() throws {
        let runtime = ReaderUIRuntimeCoordinator()
        let result = runtime.observe(UiEvent(
            type: .book_open,
            payload: [
                "bookId": AnyCodable("book-1"),
                "sourceId": AnyCodable("source-1"),
                "sourceKind": AnyCodable("remote"),
            ],
            correlationId: "pilot-admit-1"
        ))

        let transition = try XCTUnwrap(result).get()
        XCTAssertNotNil(transition.state.bookOpenTransaction)
        XCTAssertEqual(transition.state.bookOpenTransaction?.correlationId, "pilot-admit-1")
        XCTAssertEqual(transition.state.routeId, "immersive-reading")
        XCTAssertTrue(transition.state.loading)
        XCTAssertEqual(runtime.metrics.covered, 1)
        XCTAssertEqual(
            runtime.metrics.suppressedRuntimeEffects,
            0,
            "Pilot must not suppress runtime effects; the pilot executor receives them instead"
        )
    }

    func testBookOpenPilotEffectBoundaryFailureClearsTransaction() throws {
        let runtime = ReaderUIRuntime()
        _ = try runtime.dispatch(
            event: "book.open",
            payload: [
                "sourceId": "source-1",
                "bookId": "book-1",
                "sourceKind": "remote",
            ],
            correlationId: "fail-boundary-1"
        )
        XCTAssertNotNil(runtime.state.bookOpenTransaction)

        let failure = runtime.acceptBookOpenResult(
            coreType: "source.detail",
            correlationId: "fail-boundary-1",
            error: "CORE_DETAIL_NETWORK_FAILURE"
        )
        XCTAssertTrue(failure.accepted)
        XCTAssertNil(
            failure.state.bookOpenTransaction,
            "Effect boundary failure must clear the book-open transaction"
        )
        XCTAssertEqual(failure.state.error, "CORE_DETAIL_NETWORK_FAILURE")
        XCTAssertFalse(failure.state.loading)
    }

    func testBookOpenPilotStaleResultGuardRejectsOldCorrelation() throws {
        let runtime = ReaderUIRuntime()
        _ = try runtime.dispatch(
            event: "book.open",
            payload: [
                "sourceId": "source-1",
                "bookId": "book-1",
                "sourceKind": "remote",
            ],
            correlationId: "current-open-1"
        )

        let stale = runtime.acceptBookOpenResult(
            coreType: "source.detail",
            correlationId: "stale-open-1",
            chapterCount: nil
        )
        XCTAssertFalse(stale.accepted, "A result for a stale correlation must be rejected")
        XCTAssertNotNil(
            stale.state.bookOpenTransaction,
            "The active transaction is preserved when a stale result is rejected"
        )
        XCTAssertEqual(stale.state.bookOpenTransaction?.correlationId, "current-open-1")
    }

    func testBookOpenPilotRollbackRestoresShadowMode() {
        let shadowConfiguration = ReaderUIRuntimeShadowConfiguration(
            coveredEvents: ReaderUIRuntimeShadowConfiguration.live.coveredEvents,
            cohorts: []
        )
        XCTAssertEqual(shadowConfiguration.mode(for: "book.open"), .shadow)

        let shadow = ReaderUIRuntimeCoordinator(configuration: shadowConfiguration)
        _ = shadow.observe(UiEvent(
            type: .book_open,
            payload: [
                "bookId": AnyCodable("book-1"),
                "sourceId": AnyCodable("source-1"),
                "sourceKind": AnyCodable("remote"),
            ],
            correlationId: "rollback-shadow-1"
        ))

        XCTAssertEqual(
            shadow.metrics.suppressedRuntimeEffects,
            1,
            "Shadow rollback suppresses the first-stage Core effect; the native reducer remains the sole writer"
        )
        XCTAssertEqual(shadow.metrics.covered, 1)
    }

    func testBookOpenPilotDoesNotDoubleDispatchNativeReducer() throws {
        let runtime = ReaderUIRuntimeCoordinator()
        let result = runtime.observe(UiEvent(
            type: .book_open,
            payload: [
                "bookId": AnyCodable("book-1"),
                "sourceId": AnyCodable("source-1"),
                "sourceKind": AnyCodable("remote"),
            ],
            correlationId: "pilot-once-1"
        ))

        let transition = try XCTUnwrap(result).get()
        XCTAssertEqual(transition.effects.count, 1, "Pilot dispatches exactly one first-stage Core effect")
        XCTAssertEqual(transition.effects.map(\.type), ["source.detail"])
        XCTAssertEqual(transition.effects.map(\.kind), [.core])
        XCTAssertEqual(transition.cancelledCorrelationIds, [])
        XCTAssertEqual(
            runtime.metrics.suppressedRuntimeEffects,
            0,
            "Pilot must not double-dispatch: the effect goes to the pilot executor, not back into the native reducer"
        )
        XCTAssertEqual(runtime.metrics.covered, 1)
    }

    // MARK: - playback pilot parity

    func testPlaybackPilotConfigurationLiveIsPilotForTtsAndAutoPage() {
        XCTAssertEqual(ReaderPlaybackPilotConfiguration.live.ttsPairMode, .pilot)
        XCTAssertEqual(ReaderPlaybackPilotConfiguration.live.autoPagePairMode, .pilot)
        XCTAssertEqual(ReaderPlaybackPilotConfiguration.live.pagePairMode, .shadow)
        XCTAssertEqual(ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.tts.start"), .pilot)
        XCTAssertEqual(ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.tts.stop"), .pilot)
        XCTAssertEqual(ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.autoPage.start"), .pilot)
        XCTAssertEqual(ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.autoPage.stop"), .pilot)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.cohorts.first { $0.id == "playback-pilot" }?.mode,
            .pilot
        )
    }

    func testTtsStartPilotDispatchesRuntimeTransaction() throws {
        let runtime = ReaderUIRuntime(state: ReaderUIState(routeId: "immersive-reading"))
        let transition = try runtime.dispatch(event: "reader.tts.start", correlationId: "tts-pilot-1")

        XCTAssertNotNil(transition.state.ttsTransaction)
        XCTAssertEqual(transition.state.ttsTransaction?.correlationId, "tts-pilot-1")
        XCTAssertEqual(transition.state.ttsTransaction?.stage, "awaiting-plan")
    }

    func testTtsStopPilotClearsTransaction() throws {
        let runtime = ReaderUIRuntime(state: ReaderUIState(routeId: "immersive-reading"))
        _ = try runtime.dispatch(event: "reader.tts.start", correlationId: "tts-stop-1")
        XCTAssertNotNil(runtime.state.ttsTransaction)

        let transition = runtime.stopTTS(correlationId: "tts-stop-1")
        XCTAssertTrue(transition.accepted)
        XCTAssertNil(transition.state.ttsTransaction)
    }

    func testAutoPageStartPilotDispatchesRuntimeTransaction() throws {
        let runtime = ReaderUIRuntime(state: ReaderUIState(routeId: "immersive-reading"))
        let transition = try runtime.dispatch(
            event: "reader.autoPage.start",
            payload: ["intervalMs": "5000"],
            correlationId: "auto-page-pilot-1"
        )

        XCTAssertNotNil(transition.state.autoPageTransaction)
        XCTAssertEqual(transition.state.autoPageTransaction?.correlationId, "auto-page-pilot-1")
        XCTAssertEqual(transition.state.autoPageTransaction?.intervalMs, 5_000)
    }

    func testAutoPageStopPilotClearsTransaction() throws {
        let runtime = ReaderUIRuntime(state: ReaderUIState(routeId: "immersive-reading"))
        _ = try runtime.dispatch(
            event: "reader.autoPage.start",
            payload: ["intervalMs": "5000"],
            correlationId: "auto-page-stop-1"
        )
        XCTAssertNotNil(runtime.state.autoPageTransaction)

        let transition = runtime.stopAutoPage(correlationId: "auto-page-stop-1")
        XCTAssertTrue(transition.accepted)
        XCTAssertNil(transition.state.autoPageTransaction)
    }

    func testPagePairRemainsShadowMode() {
        XCTAssertEqual(ReaderPlaybackPilotConfiguration.live.pagePairMode, .shadow)
        XCTAssertEqual(ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.page.next"), .shadow)
        XCTAssertEqual(ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.page.prev"), .shadow)
    }

    // MARK: - replace rules Shadow boundary

    func testReplaceRuleLiveConfigurationRemainsShadow() {
        XCTAssertEqual(ReaderReplaceRulePilotConfiguration.live.mode, .shadow)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.replace.apply"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.replace.create"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.replace.validate"),
            .shadow
        )
        XCTAssertNil(
            ReaderUIRuntimeShadowConfiguration.live.cohorts
                .first { $0.id == "replace-rules-pilot" }
        )
    }

    // MARK: - RSS Shadow boundary

    func testRssLiveConfigurationRemainsShadow() {
        XCTAssertEqual(ReaderRssPilotConfiguration.live.mode, .shadow)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.refresh"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.subscription.add"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.subscription.delete"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.subscription.edit"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.entry.open"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.favorite.add"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "rss.favorite.remove"),
            .shadow
        )
        XCTAssertNil(
            ReaderUIRuntimeShadowConfiguration.live.cohorts
                .first { $0.id == "rss-pilot" }
        )
    }

    // MARK: - sync Shadow boundary

    func testSyncLiveConfigurationRemainsShadowUntilTypedDomainGatewayCloses() {
        XCTAssertEqual(ReaderSyncPilotConfiguration.live.mode, .shadow)
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.run"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "webdav.config.test"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.start"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.progress"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.complete"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.conflict"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.mode(for: "sync.resolve"),
            .shadow
        )
        XCTAssertEqual(
            ReaderUIRuntimeShadowConfiguration.live.cohorts
                .first { $0.id == "sync-pilot" },
            nil
        )
    }

    // MARK: - Consumer lock decoding

    /// Rollback seam for the pre-Pilot book.open parity assertions. Directory
    /// remains Pilot while only the book-open cohort falls back to Shadow.
    private var bookOpenShadowRollbackConfiguration: ReaderUIRuntimeShadowConfiguration {
        ReaderUIRuntimeShadowConfiguration(
            coveredEvents: ReaderUIRuntimeShadowConfiguration.live.coveredEvents,
            cohorts: ReaderUIRuntimeShadowConfiguration.live.cohorts.filter {
                $0.id != "book-open-pilot"
            }
        )
    }

    /// Rollback seam for shadow-path parity assertions on TTS/auto-page. The
    /// playback cohort falls back to Shadow so the native reducer and mismatch
    /// counter remain exercisable after the live promotion to Pilot.
    private var playbackShadowRollbackConfiguration: ReaderUIRuntimeShadowConfiguration {
        ReaderUIRuntimeShadowConfiguration(
            coveredEvents: ReaderUIRuntimeShadowConfiguration.live.coveredEvents,
            cohorts: ReaderUIRuntimeShadowConfiguration.live.cohorts.filter {
                $0.id != "playback-pilot"
            }
        )
    }

    private struct ConsumerLock: Decodable {
        let readerUiVersion: String
        let hostRequestSchemaVersion: String
        let runtimeActionsSha256: String
        let releaseIdentity: ReleaseIdentity
        let rollout: Rollout

        struct Rollout: Decodable {
            let mode: String
            let coveredEvents: [String]
            let cohorts: [Cohort]

            struct Cohort: Codable, Equatable {
                let id: String
                let mode: String
                let effectPolicy: String?
                let evidence: CohortDetail?
                let rollback: CohortDetail?
                let events: [String]
            }
        }
    }

    private struct ReleaseIdentity: Decodable, Equatable {
        let releaseId: String
        let sourceSha: String
        let manifestSha256: String
        let targetConfigSha256: String
    }

    /// Subset of the temporary `reader-ui-verified.json` emitted by Reader-UI's release gate.
    /// Unknown fields intentionally remain owned and validated by the upstream release tooling.
    private struct VerifiedReaderUIRelease: Decodable {
        let readerUiVersion: String
        let releaseId: String
        let sourceSha: String
        let manifestSha256: String
        let targetConfigSha256: String

        var releaseIdentity: ReleaseIdentity {
            ReleaseIdentity(
                releaseId: releaseId,
                sourceSha: sourceSha,
                manifestSha256: manifestSha256,
                targetConfigSha256: targetConfigSha256
            )
        }
    }

    private enum ConsumerVersionSourceError: Error {
        case invalidVersion(String)
        case invalidReleaseIdentity
        case verifiedArtifactMismatch
    }

    private func expectedReaderUIVersion(for lock: ConsumerLock) throws -> String {
        let verifiedRelease: VerifiedReaderUIRelease?
        if let artifactPath = ProcessInfo.processInfo.environment[
            "READER_UI_VERIFIED_RELEASE_PATH"
        ], !artifactPath.isEmpty {
            verifiedRelease = try JSONDecoder().decode(
                VerifiedReaderUIRelease.self,
                from: Data(contentsOf: URL(fileURLWithPath: artifactPath))
            )
        } else {
            verifiedRelease = nil
        }
        return try expectedReaderUIVersion(for: lock, verifiedRelease: verifiedRelease)
    }

    private func expectedReaderUIVersion(
        for lock: ConsumerLock,
        verifiedRelease: VerifiedReaderUIRelease?
    ) throws -> String {
        try validateVersionAndIdentity(
            version: lock.readerUiVersion,
            identity: lock.releaseIdentity
        )

        guard let verifiedRelease else {
            // Normal local and post-lock CI runs consume the checked-in, upstream-verified lock.
            return lock.readerUiVersion
        }

        try validateVersionAndIdentity(
            version: verifiedRelease.readerUiVersion,
            identity: verifiedRelease.releaseIdentity
        )
        guard verifiedRelease.releaseIdentity == lock.releaseIdentity else {
            throw ConsumerVersionSourceError.verifiedArtifactMismatch
        }
        return verifiedRelease.readerUiVersion
    }

    private func validateVersionAndIdentity(
        version: String,
        identity: ReleaseIdentity
    ) throws {
        guard version.range(
            of: #"^[0-9]+\.[0-9]+\.[0-9]+$"#,
            options: .regularExpression
        ) != nil else {
            throw ConsumerVersionSourceError.invalidVersion(version)
        }
        guard identity.releaseId == "\(identity.sourceSha):\(identity.manifestSha256)",
              identity.sourceSha.range(
                of: #"^[0-9a-f]{40}$"#,
                options: .regularExpression
              ) != nil,
              identity.manifestSha256.range(
                of: #"^[0-9a-f]{64}$"#,
                options: .regularExpression
              ) != nil,
              identity.targetConfigSha256.range(
                of: #"^[0-9a-f]{64}$"#,
                options: .regularExpression
              ) != nil else {
            throw ConsumerVersionSourceError.invalidReleaseIdentity
        }
    }

    private func loadConsumerLock() throws -> ConsumerLock {
        let url = repositoryRoot().appendingPathComponent("READER_UI_CONSUMER.json")
        return try JSONDecoder().decode(ConsumerLock.self, from: Data(contentsOf: url))
    }

    private func repositoryRoot() -> URL {
        var repositoryRoot = URL(fileURLWithPath: #filePath)
        for _ in 0..<4 {
            repositoryRoot.deleteLastPathComponent()
        }
        return repositoryRoot
    }

    private final class FailingDirectoryRuntime: ReaderUIRuntimeDispatching {
        let state = ReaderUIState()

        func dispatch(
            event: String,
            jsonPayload: ReaderUIJSONPayload,
            correlationId: String?
        ) throws -> ReaderUITransition {
            throw ReaderUIRuntimeFailure(
                code: "INJECTED_DIRECTORY_FAILURE",
                message: "Injected R8 fail-closed proof"
            )
        }
    }
}
