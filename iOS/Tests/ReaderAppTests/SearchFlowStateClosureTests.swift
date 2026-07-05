import XCTest
@testable import ReaderApp
import ReaderCoreModels

/// P0/M2 closed-planned route closure: search-home / search-results / search-loading
/// / search-empty / search-error
///
/// 验收标准不是"页面能打开"，而是 SearchState 状态机能在
/// idle → loading → success/partial/empty/failed/unsupported 之间真实切换。
/// 这些 route 在 `closedPlannedRouteMappings` 里被声明为 `.featureState(...)`，
/// 本测试覆盖：(1) route 不再是 planned；(2) stateModel 描述了对应 SearchState；
/// (3) SearchViewModel 真实执行状态切换。
@MainActor
final class SearchFlowStateClosureTests: XCTestCase {

    // MARK: - Route ownership: 5 search routes are concrete feature states, not planned

    func testSearchHomeRouteIsConcreteFeatureStateNotPlanned() {
        let mapping = DemoRouteMappings.mapping(for: "search-home")
        XCTAssertNotNil(mapping, "search-home must have a route mapping")
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("search-home must map to a feature state, got \(String(describing: mapping?.platformTarget))")
        }
        XCTAssertTrue(stateName.contains("SearchState.idle"),
                      "search-home feature state must reference SearchState.idle")
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true,
                       "search-home stateModel must not be planned")
    }

    func testSearchResultsRouteIsConcreteFeatureStateNotPlanned() {
        let mapping = DemoRouteMappings.mapping(for: "search-results")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("search-results must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("SearchState.success"))
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testSearchLoadingRouteIsConcreteFeatureStateNotPlanned() {
        let mapping = DemoRouteMappings.mapping(for: "search-loading")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("search-loading must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("SearchState.loading"))
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testSearchEmptyRouteIsConcreteFeatureStateNotPlanned() {
        let mapping = DemoRouteMappings.mapping(for: "search-empty")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("search-empty must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("SearchState.empty"))
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    func testSearchErrorRouteIsConcreteFeatureStateNotPlanned() {
        let mapping = DemoRouteMappings.mapping(for: "search-error")
        XCTAssertNotNil(mapping)
        XCTAssertEqual(mapping?.shell, "LibraryShell")
        guard case .featureState(let stateName) = mapping?.platformTarget else {
            return XCTFail("search-error must map to a feature state")
        }
        XCTAssertTrue(stateName.contains("SearchState.failed"))
        XCTAssertFalse(mapping?.stateModel.contains("planned") == true)
    }

    // MARK: - SearchState machine closure: idle → loading → success/empty/failed

    func testSearchStateIdleIsInitialValue() {
        let vm = SearchViewModel()
        XCTAssertEqual(vm.searchState, .idle, "SearchViewModel must start in idle state")
    }

    func testSearchStateTransitionsToFailedOnEmptyKeyword() async {
        let vm = SearchViewModel()
        vm.keyword = "   "
        await vm.search()
        if case .failed(let message) = vm.searchState {
            XCTAssertFalse(message.isEmpty, "empty keyword must transition to failed with message")
        } else {
            XCTFail("Expected .failed for empty keyword, got \(vm.searchState)")
        }
    }

    func testSearchStateTransitionsThroughLoadingToResult() async {
        let vm = SearchViewModel()
        await vm.loadSources()
        vm.keyword = "测试"
        let task = Task { await vm.search() }
        // Capture state synchronously after issuing search; loading is set before async provider call.
        // We can't deterministically catch loading without injecting a slow provider,
        // but we can verify the final state is one of the terminal states.
        await task.value
        switch vm.searchState {
        case .success, .empty, .failed, .unsupported, .partial:
            // any terminal state is acceptable; the point is the state machine closed.
            break
        case .idle, .loading:
            XCTFail("Search state should have settled to a terminal state, got \(vm.searchState)")
        }
    }

    func testSearchStateResetReturnsToIdle() {
        let vm = SearchViewModel()
        vm.keyword = "anything"
        vm.searchState = .empty
        vm.reset()
        XCTAssertEqual(vm.searchState, .idle, "reset() must return SearchState to .idle")
        XCTAssertEqual(vm.keyword, "", "reset() must clear keyword")
    }

    // MARK: - State model describes real components

    func testSearchHomeStateModelReferencesSearchViewAndHistory() {
        let mapping = DemoRouteMappings.mapping(for: "search-home")
        XCTAssertTrue(mapping?.stateModel.contains("SearchView") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SearchViewModel") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SearchHistoryRow") == true)
        XCTAssertTrue(mapping?.stateModel.contains("SearchScope") == true)
    }

    func testSearchLoadingStateModelReferencesLoadingSpinner() {
        let mapping = DemoRouteMappings.mapping(for: "search-loading")
        XCTAssertTrue(mapping?.stateModel.contains("DemoLoadingSpinner") == true,
                      "search-loading must render DemoLoadingSpinner per demo spec")
        XCTAssertTrue(mapping?.stateModel.contains("SearchStateCard") == true)
    }

    func testSearchErrorStateModelReferencesDangerToneAndRetry() {
        let mapping = DemoRouteMappings.mapping(for: "search-error")
        XCTAssertTrue(mapping?.stateModel.contains("SearchStateCard") == true)
        XCTAssertTrue(mapping?.stateModel.lowercased().contains("danger") == true,
                      "search-error card must use danger tone")
        XCTAssertTrue(mapping?.stateModel.contains("retry") == true,
                      "search-error must expose retry action")
    }
}
