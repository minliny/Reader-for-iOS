import XCTest
import ReaderUIContract
import ReaderUIRuntime
@testable import ReaderApp

@MainActor
final class ReaderControlCandidateConsumptionTests: XCTestCase {
    func testProductionLockDoesNotAdmitSchema3ReaderControlCandidate() {
        XCTAssertGreaterThanOrEqual(GeneratedRuntimeActions.schemaVersion, 3)
        XCTAssertNil(ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.control.toggle"))
        XCTAssertNil(ReaderUIRuntimeShadowConfiguration.live.mode(for: "reader.module.switch"))

        let runtime = ReaderUIRuntimeCoordinator(
            state: ReaderUIState(routeId: "immersive-reading")
        )
        let result = runtime.observe(toggleEvent())

        XCTAssertNil(result)
        XCTAssertNil(runtime.readerControlOverlay)
        XCTAssertEqual(runtime.metrics.fallback, 1)
    }

    func testLocalCandidateConsumesToggleAndCompatibleOverlayFamilyWithoutChangingRoute() {
        let show = makeCandidateHarness()
        show.coordinator.toggleReaderControl()
        XCTAssertEqual(show.runtime.readerControlOverlay, "reader-control")
        XCTAssertEqual(show.runtime.state.routeId, "immersive-reading")
        XCTAssertEqual(show.runtime.lastReaderControlMotionDelta, .show)
        XCTAssertEqual(show.runtime.lastReaderControlMotionDelta?.motionID, .reader_control_show)
        XCTAssertEqual(show.navigation.overlayState, .none, "Pilot must not replay the native overlay write")

        let modulePairs = [
            ("reader-control", "directory"),
            ("directory", "tts"),
            ("tts", "appearance"),
            ("appearance", "settings"),
        ]
        for (previous, target) in modulePairs {
            let harness = makeCandidateHarness(overlay: previous)
            harness.coordinator.readerModuleSwitch(module: target)
            XCTAssertEqual(harness.runtime.readerControlOverlay, target)
            XCTAssertEqual(harness.runtime.state.routeId, "immersive-reading")
            XCTAssertEqual(harness.runtime.lastReaderControlMotionDelta, .switchModule)
            XCTAssertEqual(harness.runtime.lastReaderControlMotionDelta?.motionID, .reader_module_switch)
        }

        let hide = makeCandidateHarness(overlay: "settings")
        hide.coordinator.toggleReaderControl()
        XCTAssertNil(hide.runtime.readerControlOverlay)
        XCTAssertEqual(hide.runtime.state.routeId, "immersive-reading")
        XCTAssertEqual(hide.runtime.lastReaderControlMotionDelta, .hide)
        XCTAssertEqual(hide.runtime.lastReaderControlMotionDelta?.motionID, .reader_control_hide)
    }

    func testRepeatedModuleIsCanonicalNoOpWithNoMotion() {
        let harness = makeCandidateHarness(overlay: "directory")
        harness.coordinator.readerModuleSwitch(module: "directory")

        XCTAssertEqual(harness.runtime.readerControlOverlay, "directory")
        XCTAssertEqual(harness.runtime.lastTransition?.previous, harness.runtime.lastTransition?.state)
        XCTAssertEqual(harness.runtime.lastReaderControlMotionDelta, .noOp)
        XCTAssertNil(harness.runtime.lastReaderControlMotionDelta?.motionID)
        XCTAssertEqual(harness.navigation.overlayState, .sheet)
    }

    func testWrongRouteFailsClosedAndPreservesNativeState() {
        let navigation = AppNavigationState()
        navigation.setOverlay(.dialog)
        let runtime = ReaderUIRuntimeCoordinator(
            configuration: localCandidateConfiguration(),
            state: ReaderUIState(routeId: "bookshelf", overlay: "dialog")
        )
        let reducer = ReaderReducer(navigationState: navigation, runtimeShadow: runtime)

        reducer.dispatch(toggleEvent())

        XCTAssertEqual(runtime.lastFailure?.code, "READER_ROUTE_GUARD")
        XCTAssertEqual(runtime.readerControlOverlay, "dialog")
        XCTAssertNil(runtime.lastTransition)
        XCTAssertEqual(navigation.overlayState, .dialog)
        XCTAssertEqual(runtime.metrics.runtimeError, 1)
    }

    func testNonReaderOverlayAndMissingReaderControlBothFailClosed() {
        let dialog = makeCandidateHarness(overlay: "dialog")
        dialog.coordinator.dispatch(toggleEvent())
        XCTAssertEqual(dialog.runtime.lastFailure?.code, "READER_CONTROL_OVERLAY_GUARD")
        XCTAssertEqual(dialog.runtime.readerControlOverlay, "dialog")
        XCTAssertEqual(dialog.navigation.overlayState, .dialog)

        let empty = makeCandidateHarness()
        empty.coordinator.dispatch(moduleEvent("directory"))
        XCTAssertEqual(empty.runtime.lastFailure?.code, "READER_CONTROL_OVERLAY_GUARD")
        XCTAssertNil(empty.runtime.readerControlOverlay)
        XCTAssertEqual(empty.navigation.overlayState, .none)
    }

    func testInvalidModuleFailsClosedWithoutReplacingOverlay() {
        let harness = makeCandidateHarness(overlay: "reader-control")
        harness.coordinator.dispatch(moduleEvent("search"))

        XCTAssertEqual(harness.runtime.lastFailure?.code, "INVALID_TYPED_PAYLOAD")
        XCTAssertEqual(harness.runtime.readerControlOverlay, "reader-control")
        XCTAssertEqual(harness.navigation.overlayState, .sheet)
        XCTAssertNil(harness.runtime.lastReaderControlMotionDelta)
    }

    func testStaleRuntimeRouteStackTabOrOverlayBaselineFailsClosed() {
        let staleStates = [
            ReaderUIState(routeId: "bookshelf", routeStack: ["bookshelf"]),
            ReaderUIState(routeId: "immersive-reading", routeStack: []),
            ReaderUIState(routeId: "immersive-reading", routeStack: ["bookshelf"], tab: "rss"),
            ReaderUIState(routeId: "immersive-reading", routeStack: ["bookshelf"], overlay: "reader-control"),
        ]

        for staleState in staleStates {
            let navigation = makeReaderNavigation()
            let runtime = ReaderUIRuntimeCoordinator(
                configuration: localCandidateConfiguration(),
                state: staleState
            )
            let coordinator = ReaderCoordinator(
                navigationState: navigation,
                runtimeShadow: runtime
            )
            let before = runtime.state

            coordinator.toggleReaderControl()

            XCTAssertEqual(runtime.lastFailure?.code, "READER_CONTROL_BASELINE_MISMATCH")
            XCTAssertEqual(runtime.state, before)
            XCTAssertNil(runtime.lastTransition)
            XCTAssertNil(runtime.lastReaderControlMotionDelta)
            XCTAssertEqual(navigation.overlayState, .none)
        }
    }

    func testSuccessThenTypedFailureDoesNotReuseStaleMotion() {
        let harness = makeCandidateHarness()
        harness.coordinator.toggleReaderControl()
        XCTAssertEqual(harness.runtime.lastReaderControlMotionDelta, .show)

        XCTAssertNil(harness.runtime.observe(UiEvent(type: .reader_directory_open)))
        XCTAssertNil(harness.runtime.lastReaderControlMotionDelta)
        XCTAssertEqual(harness.runtime.metrics.fallback, 1)

        // Explicitly align the native projection before the next candidate;
        // the invalid typed payload, not a stale baseline, must reject it.
        harness.navigation.setOverlay(.sheet)
        harness.coordinator.dispatch(moduleEvent("search"))

        XCTAssertEqual(harness.runtime.lastFailure?.code, "INVALID_TYPED_PAYLOAD")
        XCTAssertNil(harness.runtime.lastReaderControlMotionDelta)
        XCTAssertEqual(harness.runtime.lastTransition?.event, "reader.control.toggle")
        XCTAssertEqual(harness.runtime.readerControlOverlay, "reader-control")
    }

    private func makeCandidateHarness(
        overlay: String? = nil
    ) -> (
        navigation: AppNavigationState,
        runtime: ReaderUIRuntimeCoordinator,
        coordinator: ReaderCoordinator
    ) {
        let navigation = makeReaderNavigation(overlay: overlay)
        let runtime = ReaderUIRuntimeCoordinator(
            configuration: localCandidateConfiguration(),
            state: ReaderUIState(
                routeId: "immersive-reading",
                routeStack: ["bookshelf"],
                overlay: overlay
            )
        )
        return (
            navigation,
            runtime,
            ReaderCoordinator(navigationState: navigation, runtimeShadow: runtime)
        )
    }

    private func makeReaderNavigation(overlay: String? = nil) -> AppNavigationState {
        let navigation = AppNavigationState()
        navigation.enterImmersiveReading(ReaderContext(
            bookID: "candidate-book",
            chapterURL: "candidate://chapter",
            chapterTitle: "Candidate",
            source: .actionToImmersive
        ))
        switch overlay {
        case nil:
            break
        case "reader-control":
            navigation.setOverlay(.sheet)
        case "directory", "tts", "appearance", "settings":
            navigation.setOverlay(.sheet)
            navigation.focus("reader-module-\(overlay!)")
        case "dialog":
            navigation.setOverlay(.dialog)
        case "keyboard":
            navigation.setOverlay(.keyboard)
        default:
            XCTFail("Unsupported test overlay \(overlay!)")
        }
        return navigation
    }

    /// The unlocked candidate allowlist exists only in this XCTest target.
    /// Production continues to construct `ReaderUIRuntimeShadowConfiguration.live`.
    private func localCandidateConfiguration() -> ReaderUIRuntimeShadowConfiguration {
        ReaderUIRuntimeShadowConfiguration(
            coveredEvents: [
                "reader.control.toggle",
                "reader.module.switch",
            ],
            cohorts: [
                ReaderUIRuntimeShadowCohort(
                    id: "reader-control-local-candidate",
                    mode: .pilot,
                    evidence: .text("Local XCTest candidate only; production remains consumer-lock governed."),
                    rollback: .text("Remove the injected XCTest coordinator; production .live is unchanged."),
                    effectPolicy: "none",
                    events: [
                        "reader.control.toggle",
                        "reader.module.switch",
                    ]
                ),
            ]
        )
    }

    private func toggleEvent() -> UiEvent {
        UiEvent(
            type: .reader_control_toggle,
            payload: ["overlay": AnyCodable("reader-control")]
        )
    }

    private func moduleEvent(_ module: String) -> UiEvent {
        UiEvent(
            type: .reader_module_switch,
            payload: ["module": AnyCodable(module)]
        )
    }
}
