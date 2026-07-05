import XCTest
import SwiftUI
@testable import ReaderApp
import ReaderUIContract

/// P0/M3 第一批页面动画迁移：验证每个迁移点构造的 MotionRequest 能正确解析到契约 MotionId。
///
/// 本测试不测 View 渲染，只测迁移点构造的 MotionRequest → MotionId 闭环。
/// 这样 codegen 改 policy 时，iOS 调用点的行为变化会在测试里暴露。
@MainActor
final class ReaderMotionFirstBatchMigrationTests: XCTestCase {

    // MARK: - 1. Tab switch (AppShellView / SettingsTabView / SettingsDemoShellView)

    func testTabSwitchRequestResolvesToTabSwitchMotionId() {
        // AppShellView.swift: tab content switch
        // SettingsTabView.swift: settings demo route switch
        // SettingsDemoShellView.swift: current route switch
        let request = MotionRequest(operation: .tabSwitch, containerRole: .mainTabShell)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .tab_switch,
                       "tab switch in mainTabShell must resolve to .tab_switch")
    }

    func testTabSwitchRequestAnimationNonNilWhenReducedMotionOff() {
        let motion = MotionEnvironment(override: false)
        let request = MotionRequest(operation: .tabSwitch, containerRole: .mainTabShell)
        XCTAssertNotNil(ReaderMotionAdapter.animation(for: request, motion: motion),
                        "tab switch must yield a non-nil Animation when reduced motion is off")
    }

    func testTabSwitchRequestAnimationNilWhenReducedMotionOn() {
        let motion = MotionEnvironment(override: true)
        let request = MotionRequest(operation: .tabSwitch, containerRole: .mainTabShell)
        XCTAssertNil(ReaderMotionAdapter.animation(for: request, motion: motion),
                     "tab switch has forceZeroDuration=true; reduced motion must yield nil")
    }

    // MARK: - 2. Bookshelf → reader entry (BookshelfView.enterImmersive)

    func testBookshelfToReaderEntryCoverResolvesToCoverToImmersive() {
        // BookshelfView.enterImmersive: source == .coverToImmersive → sourceRole="bookCover"
        let request = MotionRequest(
            fromShell: .mainTabShell,
            toShell: .readerShell,
            operation: .push,
            sourceRole: "bookCover"
        )
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .reader_entry_coverToImmersive,
                       "push from mainTabShell to readerShell with sourceRole=bookCover must resolve to .reader_entry_coverToImmersive")
    }

    func testBookshelfToReaderEntryActionResolvesToActionToImmersive() {
        // BookshelfView.enterImmersive: source == .actionToImmersive → sourceRole="actionButton"
        let request = MotionRequest(
            fromShell: .mainTabShell,
            toShell: .readerShell,
            operation: .push,
            sourceRole: "actionButton"
        )
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .reader_entry_actionToImmersive,
                       "push from mainTabShell to readerShell with sourceRole=actionButton must resolve to .reader_entry_actionToImmersive")
    }

    func testBookshelfToReaderEntryAnimationNonNil() {
        let motion = MotionEnvironment(override: false)
        let request = MotionRequest(
            fromShell: .mainTabShell,
            toShell: .readerShell,
            operation: .push,
            sourceRole: "bookCover"
        )
        XCTAssertNotNil(ReaderMotionAdapter.animation(for: request, motion: motion),
                        "reader entry must yield a non-nil Animation when reduced motion is off")
    }

    // MARK: - 2b. Reader → bookshelf exit (BookshelfView.closeActiveDestination)

    func testReaderToBookshelfExitResolvesToFallbackInterrupt() {
        // operation: .pop from readerShell → mainTabShell has no specific policy;
        // resolver falls back to .motion_interrupt_redirect (fallback-no-motion policy)
        let request = MotionRequest(
            fromShell: .readerShell,
            toShell: .mainTabShell,
            operation: .pop
        )
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .motion_interrupt_redirect,
                       "pop from readerShell to mainTabShell has no specific policy; must fall back to .motion_interrupt_redirect")
    }

    // MARK: - 3. State replace (StateContainerView 4-state switch)

    func testStateContentReplaceResolvesToStateContentReplaceMotionId() {
        // StateContainerView.swift: 4-state switch (idle/loading/result/error)
        let request = MotionRequest(operation: .replace, sourceRole: "content", containerRole: .inlineState)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .state_content_replace,
                       "replace + sourceRole=content + inlineState must resolve to .state_content_replace")
    }

    func testStateContentReplaceAnimationNonNil() {
        let motion = MotionEnvironment(override: false)
        let request = MotionRequest(operation: .replace, sourceRole: "content", containerRole: .inlineState)
        XCTAssertNotNil(ReaderMotionAdapter.animation(for: request, motion: motion),
                        "state content replace must yield a non-nil Animation when reduced motion is off")
    }

    // MARK: - 4. Reader overlay sheet enter (ReaderView.toggleReaderChrome show)

    func testReaderOverlaySheetEnterResolvesToOverlaySheetEnterMotionId() {
        // ReaderView.toggleReaderChrome: willShow=true → enter + sheet + readerShell
        let request = MotionRequest(operation: .enter, targetRole: "sheet", containerRole: .readerShell)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .overlay_sheet_enter,
                       "enter + sheet + readerShell must resolve to .overlay_sheet_enter")
    }

    // MARK: - 4b. Reader control hide (ReaderView.toggleReaderChrome hide)

    func testReaderControlHideResolvesToReaderControlHideMotionId() {
        // ReaderView.toggleReaderChrome: willShow=false → exit + controlLayer + readerSurface
        let request = MotionRequest(operation: .exit, sourceRole: "controlLayer", containerRole: .readerSurface)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .reader_control_hide,
                       "exit + controlLayer + readerSurface must resolve to .reader_control_hide")
    }

    // MARK: - 5. Settings shell dialog enter (SettingsDemoShellView.activeConfirm)

    func testSettingsDialogEnterResolvesToOverlayDialogEnterMotionId() {
        // SettingsDemoShellView.swift: activeConfirm 出现 → enter + dialog + settingsShell
        let request = MotionRequest(operation: .enter, targetRole: "dialog", containerRole: .settingsShell)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .overlay_dialog_enter,
                       "enter + dialog + settingsShell must resolve to .overlay_dialog_enter")
    }

    func testSettingsDialogExitResolvesToOverlayDialogExitMotionId() {
        // SettingsDemoShellView.swift: activeConfirm 消失 → exit + dialog + settingsShell
        let request = MotionRequest(operation: .exit, targetRole: "dialog", containerRole: .settingsShell)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .overlay_dialog_exit,
                       "exit + dialog + settingsShell must resolve to .overlay_dialog_exit")
    }

    // MARK: - Migration completeness: all first-batch requests resolve (never nil)

    func testAllFirstBatchMigrationRequestsResolve() {
        let requests: [MotionRequest] = [
            // tab switch
            MotionRequest(operation: .tabSwitch, containerRole: .mainTabShell),
            // bookshelf → reader entry (cover)
            MotionRequest(fromShell: .mainTabShell, toShell: .readerShell, operation: .push, sourceRole: "bookCover"),
            // bookshelf → reader entry (action)
            MotionRequest(fromShell: .mainTabShell, toShell: .readerShell, operation: .push, sourceRole: "actionButton"),
            // reader → bookshelf exit
            MotionRequest(fromShell: .readerShell, toShell: .mainTabShell, operation: .pop),
            // state replace
            MotionRequest(operation: .replace, sourceRole: "content", containerRole: .inlineState),
            // reader overlay sheet enter
            MotionRequest(operation: .enter, targetRole: "sheet", containerRole: .readerShell),
            // reader control hide
            MotionRequest(operation: .exit, sourceRole: "controlLayer", containerRole: .readerSurface),
            // settings shell dialog enter
            MotionRequest(operation: .enter, targetRole: "dialog", containerRole: .settingsShell),
        ]
        for request in requests {
            XCTAssertNotNil(ReaderMotionAdapter.resolve(request: request),
                           "all first-batch migration requests must resolve (fallback-no-motion guarantees this)")
        }
    }
}
