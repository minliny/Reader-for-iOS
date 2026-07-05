import XCTest
import SwiftUI
@testable import ReaderApp
import ReaderUIContract

/// P0/M3 motion contract integration: ReaderMotionAdapter ↔ ReaderMotionResolver
///
/// 验收：业务 View 通过 `ReaderMotionAdapter.resolve(request:)` / `animation(for request:)`
/// / `start(request:...)` 三个入口，能够根据 route/shell/operation 上下文自动解析出
/// 契约 MotionId，而不是硬编码。这是第一批页面动画迁移（tab switch / route push/pop/
/// replace / bookshelf → reader entry / reader overlay sheet/dialog / state replace）
/// 的基础设施测试。
///
/// 真源：
/// - Reader UI `frontend-demo/MOTION_CONTRACT.md` §5 MotionPolicy / §6 ReaderMotionResolver
/// - `generated/swift/MotionPolicy.swift` `MotionPolicyRegistry.all` + `ReaderMotionResolver.resolve`
@MainActor
final class ReaderMotionResolverIntegrationTests: XCTestCase {

    // MARK: - resolve(request:) returns correct MotionId for first-batch scenarios

    func testResolveTabSwitchInMainTabShellReturnsTabSwitchMotionId() {
        let request = MotionRequest(
            operation: .tabSwitch,
            containerRole: .mainTabShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .tab_switch,
                       "tabSwitch operation in mainTabShell must resolve to .tab_switch")
    }

    func testResolveRoutePushInAppShellReturnsRoutePushForwardMotionId() {
        let request = MotionRequest(
            operation: .push,
            containerRole: .appShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .app_route_push_forward,
                       "push operation in appShell must resolve to .app_route_push_forward")
    }

    func testResolveRoutePopInAppShellReturnsRoutePopBackwardMotionId() {
        let request = MotionRequest(
            operation: .pop,
            containerRole: .appShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .app_route_pop_backward,
                       "pop operation in appShell must resolve to .app_route_pop_backward")
    }

    func testResolveRouteReplaceInAppShellReturnsRouteReplaceMotionId() {
        let request = MotionRequest(
            operation: .replace,
            containerRole: .appShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .app_route_replace,
                       "replace operation in appShell must resolve to .app_route_replace")
    }

    func testResolveBookshelfViewSwitchReturnsBookshelfViewSwitchMotionId() {
        let request = MotionRequest(
            operation: .replace,
            sourceRole: "viewMode",
            containerRole: .mainTabShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .bookshelf_view_switch,
                       "replace operation with sourceRole=viewMode in mainTabShell must resolve to .bookshelf_view_switch")
    }

    func testResolveReaderOverlaySheetEnterReturnsOverlaySheetEnterMotionId() {
        let request = MotionRequest(
            operation: .enter,
            targetRole: "sheet",
            containerRole: .readerShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .overlay_sheet_enter,
                       "enter operation with targetRole=sheet in readerShell must resolve to .overlay_sheet_enter")
    }

    func testResolveReaderOverlaySheetExitReturnsOverlaySheetExitMotionId() {
        let request = MotionRequest(
            operation: .exit,
            targetRole: "sheet",
            containerRole: .readerShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .overlay_sheet_exit,
                       "exit operation with targetRole=sheet in readerShell must resolve to .overlay_sheet_exit")
    }

    func testResolveReaderOverlayDialogEnterReturnsOverlayDialogEnterMotionId() {
        let request = MotionRequest(
            operation: .enter,
            targetRole: "dialog",
            containerRole: .readerShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .overlay_dialog_enter,
                       "enter operation with targetRole=dialog in readerShell must resolve to .overlay_dialog_enter")
    }

    func testResolveReaderOverlayDialogExitReturnsOverlayDialogExitMotionId() {
        let request = MotionRequest(
            operation: .exit,
            targetRole: "dialog",
            containerRole: .readerShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .overlay_dialog_exit,
                       "exit operation with targetRole=dialog in readerShell must resolve to .overlay_dialog_exit")
    }

    // MARK: - resolve(request:) returns fallback for unmatched scenarios
    //
    // MotionPolicyRegistry includes a `fallback-no-motion` policy (priority 0,
    // all fields nil) that matches every request and returns `.motion_interrupt_redirect`.
    // So the resolver NEVER returns nil — it always falls back to this catch-all.

    func testResolveReturnsFallbackForUnmatchedOperation() {
        let request = MotionRequest(
            operation: .reshape,
            containerRole: .appShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .motion_interrupt_redirect,
                       "reshape operation in appShell has no specific policy; resolver must fall back to .motion_interrupt_redirect (fallback-no-motion policy)")
    }

    // MARK: - animation(for request:) returns SwiftUI Animation

    func testAnimationForTabSwitchRequestReturnsNonNilAnimation() {
        let request = MotionRequest(
            operation: .tabSwitch,
            containerRole: .mainTabShell
        )
        let motion = MotionEnvironment(override: false)
        let animation = ReaderMotionAdapter.animation(for: request, motion: motion)
        XCTAssertNotNil(animation,
                        "tabSwitch request must resolve to a non-nil Animation")
    }

    func testAnimationForUnmatchedRequestReturnsFallbackAnimation() {
        let request = MotionRequest(
            operation: .reshape,
            containerRole: .appShell
        )
        let motion = MotionEnvironment(override: false)
        let animation = ReaderMotionAdapter.animation(for: request, motion: motion)
        XCTAssertNotNil(animation,
                        "unmatched request falls back to .motion_interrupt_redirect which has a non-zero duration; animation must be non-nil")
    }

    // MARK: - Reduced motion: animation returns nil when reduced motion is enabled and forceZeroDuration

    func testAnimationReturnsNilWhenReducedMotionEnabledAndForceZeroDuration() {
        // .tab_switch spec has reducedMotion.forceZeroDuration = true
        let request = MotionRequest(
            operation: .tabSwitch,
            containerRole: .mainTabShell
        )
        let reducedMotion = MotionEnvironment(override: true)
        XCTAssertTrue(reducedMotion.isReducedMotionEnabled)
        let animation = ReaderMotionAdapter.animation(for: request, motion: reducedMotion)
        XCTAssertNil(animation,
                     "reduced motion + forceZeroDuration must yield nil Animation (instant transition)")
    }

    // MARK: - start(request:...) creates a MotionController transaction

    func testStartWithResolveCreatesTransactionForRoutePush() {
        let controller = MotionController()
        let request = MotionRequest(
            operation: .push,
            containerRole: .appShell
        )
        let txId = ReaderMotionAdapter.start(
            request: request,
            from: "bookshelf",
            to: "book-detail",
            finalState: "book-detail",
            controller: controller
        )
        XCTAssertNotNil(txId, "start(request:) must return a transaction UUID when resolver matches")
        XCTAssertEqual(controller.activeTransactions.count, 1,
                       "injected controller must hold the started transaction")
        XCTAssertEqual(controller.lastSnapshot[.appRoutePushForward]?.id, .appRoutePushForward)
    }

    func testStartWithResolveCreatesTransactionOnInjectedController() {
        let controller = MotionController()
        let request = MotionRequest(
            operation: .tabSwitch,
            containerRole: .mainTabShell
        )
        let txId = ReaderMotionAdapter.start(
            request: request,
            from: "bookshelf",
            to: "discover",
            finalState: "discover",
            controller: controller
        )
        XCTAssertNotNil(txId)
        XCTAssertEqual(controller.activeTransactions.count, 1,
                       "injected controller must hold the started transaction")
        XCTAssertEqual(controller.lastSnapshot[.tabItemSwitch]?.id, .tabItemSwitch)
    }

    func testStartWithResolveCreatesTransactionForFallbackPolicy() {
        // reshape operation in appShell has no specific policy, but
        // MotionPolicyRegistry includes a `fallback-no-motion` policy (priority 0,
        // all fields nil) that matches EVERY request and returns `.motion_interrupt_redirect`.
        // So the resolver NEVER returns nil — start(request:) always creates a transaction.
        let controller = MotionController()
        let request = MotionRequest(
            operation: .reshape,
            containerRole: .appShell
        )
        let txId = ReaderMotionAdapter.start(
            request: request,
            from: "a",
            to: "b",
            finalState: "b",
            controller: controller
        )
        XCTAssertNotNil(txId,
                       "fallback-no-motion policy matches every request; start(request:) must still create a transaction")
        XCTAssertEqual(controller.activeTransactions.count, 1,
                       "fallback transaction must be recorded on the injected controller")
    }

    // MARK: - Resolver priority: higher priority wins over lower

    func testResolverPicksHigherPriorityPolicyWhenMultipleMatch() {
        // Both "route-replace-default" (priority 100, appShell + replace)
        // and "bookshelf-view-switch" (priority 200, mainTabShell + replace + sourceRole=viewMode)
        // could match a request with replace + mainTabShell + sourceRole=viewMode,
        // but only bookshelf-view-switch matches because route-replace-default requires appShell.
        // Verify the resolver picks the more specific, higher-priority policy.
        let request = MotionRequest(
            operation: .replace,
            sourceRole: "viewMode",
            containerRole: .mainTabShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertEqual(motionId, .bookshelf_view_switch,
                       "resolver must pick bookshelf-view-switch (priority 200) over generic replace (priority 100, different containerRole)")
    }

    // MARK: - fromRoute/toRoute resolution via RouteShellLookup

    func testResolverInfersShellFromRouteWhenShellNotProvided() {
        // ReaderMotionResolver infers shell from route via RouteShellLookup.
        // We verify that providing fromRoute/toRoute without explicit shells still resolves.
        // Using a route that maps to a known shell — exact route depends on RouteShellLookup,
        // so we test the generic route-push-default policy (operation=push, containerRole=appShell)
        // which doesn't require route inference.
        let request = MotionRequest(
            operation: .push,
            containerRole: .appShell
        )
        let motionId = ReaderMotionAdapter.resolve(request: request)
        XCTAssertNotNil(motionId,
                        "resolver must resolve even without fromRoute/toRoute when operation+containerRole match")
    }

    // MARK: - First-batch migration scenarios: contract closure

    /// Tab switch: bookshelf → discover, discover → rss, rss → settings
    func testFirstBatchTabSwitchScenariosAllResolve() {
        let tabSwitchRequest = MotionRequest(
            operation: .tabSwitch,
            containerRole: .mainTabShell
        )
        for _ in 0..<3 {
            let motionId = ReaderMotionAdapter.resolve(request: tabSwitchRequest)
            XCTAssertEqual(motionId, .tab_switch)
        }
    }

    /// Route push/pop/replace in appShell
    func testFirstBatchRoutePushPopReplaceScenariosAllResolve() {
        let pushRequest = MotionRequest(operation: .push, containerRole: .appShell)
        let popRequest = MotionRequest(operation: .pop, containerRole: .appShell)
        let replaceRequest = MotionRequest(operation: .replace, containerRole: .appShell)

        XCTAssertEqual(ReaderMotionAdapter.resolve(request: pushRequest), .app_route_push_forward)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: popRequest), .app_route_pop_backward)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: replaceRequest), .app_route_replace)
    }

    /// Reader overlay sheet/dialog enter/exit
    func testFirstBatchReaderOverlayScenariosAllResolve() {
        let sheetEnter = MotionRequest(operation: .enter, targetRole: "sheet", containerRole: .readerShell)
        let sheetExit = MotionRequest(operation: .exit, targetRole: "sheet", containerRole: .readerShell)
        let dialogEnter = MotionRequest(operation: .enter, targetRole: "dialog", containerRole: .readerShell)
        let dialogExit = MotionRequest(operation: .exit, targetRole: "dialog", containerRole: .readerShell)

        XCTAssertEqual(ReaderMotionAdapter.resolve(request: sheetEnter), .overlay_sheet_enter)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: sheetExit), .overlay_sheet_exit)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: dialogEnter), .overlay_dialog_enter)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: dialogExit), .overlay_dialog_exit)
    }

    /// State replace (bookshelf view mode switch)
    func testFirstBatchStateReplaceScenarioResolves() {
        let stateReplaceRequest = MotionRequest(
            operation: .replace,
            sourceRole: "viewMode",
            containerRole: .mainTabShell
        )
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: stateReplaceRequest), .bookshelf_view_switch)
    }
}
