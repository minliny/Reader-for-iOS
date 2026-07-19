import XCTest
import SwiftUI
@testable import ReaderApp
import ReaderUIContract

/// P0/M3 第二批页面动画迁移：验证每个迁移点构造的 MotionRequest 能正确解析到契约 MotionId。
///
/// 第二批范围：reader page turn / session capsule / handle drag-release /
/// dropdown expand-collapse / toast / chip select / toggle switch / tab item press。
@MainActor
final class ReaderMotionSecondBatchMigrationTests: XCTestCase {

    // MARK: - 1. Reader page turn (PaginatedReaderView)

    func testReaderPageTurnResolvesToReaderPageTurnMotionId() {
        // PaginatedReaderView.swift: currentPageIndex 切换
        let request = MotionRequest(operation: .update, sourceRole: "page", containerRole: .readerSurface)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .reader_page_turn_next_prev,
                       "update + page + readerSurface must resolve to .reader_page_turn_next_prev")
    }

    func testReaderPageTurnAnimationNonNil() {
        let motion = MotionEnvironment(override: false)
        let request = MotionRequest(operation: .update, sourceRole: "page", containerRole: .readerSurface)
        XCTAssertNotNil(ReaderMotionAdapter.animation(for: request, motion: motion),
                        "reader page turn must yield a non-nil Animation when reduced motion is off")
    }

    // MARK: - 2. Session capsule countdown tick (ReaderSessionCapsuleView)

    func testSessionCapsuleUpdateResolvesToReaderSessionCapsuleUpdateMotionId() {
        // ReaderSessionCapsuleView.swift: countdown 数字切换
        let request = MotionRequest(operation: .update, containerRole: .sessionCapsule)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .reader_session_capsule_update,
                       "update + sessionCapsule must resolve to .reader_session_capsule_update")
    }

    func testSessionCapsuleUpdateAnimationNonNil() {
        let motion = MotionEnvironment(override: false)
        let request = MotionRequest(operation: .update, containerRole: .sessionCapsule)
        XCTAssertNotNil(ReaderMotionAdapter.animation(for: request, motion: motion),
                        "session capsule update must yield a non-nil Animation when reduced motion is off")
    }

    // MARK: - 3. Handle drag release (ReaderView grabber)

    func testHandleDragReleaseResolvesToReaderControlHandleReleaseMotionId() {
        // ReaderView.swift: grabber onEnded → dragRelease
        let request = MotionRequest(operation: .dragRelease, sourceRole: "handle", containerRole: .readerSurface)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .reader_control_handle_release,
                       "dragRelease + handle + readerSurface must resolve to .reader_control_handle_release")
    }

    func testHandleDragReleaseAnimationNonNil() {
        let motion = MotionEnvironment(override: false)
        let request = MotionRequest(operation: .dragRelease, sourceRole: "handle", containerRole: .readerSurface)
        XCTAssertNotNil(ReaderMotionAdapter.animation(for: request, motion: motion),
                        "handle drag release must yield a non-nil Animation when reduced motion is off")
    }

    // MARK: - 4. Dropdown expand/collapse (SettingsDemoShellView / DiscoverHomeShellView)

    func testDropdownExpandResolvesToDropdownMenuExpandMotionId() {
        // SettingsDemoShellView.swift / DiscoverHomeShellView.swift: optionOpen=true / isControlPanelExpanded=true
        let request = MotionRequest(operation: .enter, targetRole: "dropdown", containerRole: .overlayHost)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .dropdown_menu_expand,
                       "enter + dropdown + overlayHost must resolve to .dropdown_menu_expand")
    }

    func testDropdownCollapseResolvesToDropdownMenuCollapseMotionId() {
        let request = MotionRequest(operation: .exit, targetRole: "dropdown", containerRole: .overlayHost)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .dropdown_menu_collapse,
                       "exit + dropdown + overlayHost must resolve to .dropdown_menu_collapse")
    }

    // MARK: - 5. Toast enter (SettingsDemoShellView)

    func testToastEnterResolvesToFeedbackToastEnterMotionId() {
        // SettingsDemoShellView.swift: toastMessage 变化
        let request = MotionRequest(operation: .enter, targetRole: "toast", containerRole: .overlayHost)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .feedback_toast_enter,
                       "enter + toast + overlayHost must resolve to .feedback_toast_enter")
    }

    // MARK: - 6. Chip select (SettingsDemoShellView)

    func testChipSelectUsesItsDirectContractMotion() {
        // Chip selection is a primitive motion, not a route policy. The view calls
        // this exact generated MotionId directly instead of relying on a catch-all.
        XCTAssertNotNil(ReaderMotionAdapter.spec(for: .chip_item_select))
        XCTAssertNotNil(
            ReaderMotionAdapter.animation(for: .chip_item_select, motion: MotionEnvironment(override: false))
        )
    }

    // MARK: - 7. Toggle switch (SettingsDemoShellView)

    func testToggleSwitchResolvesToToggleSwitchMotionId() {
        // SettingsDemoShellView.swift: DemoSettingsSwitch isOn 切换
        let request = MotionRequest(operation: .update, sourceRole: "toggle", containerRole: .listItem)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .toggle_switch,
                       "update + toggle + listItem must resolve to .toggle_switch")
    }

    // MARK: - 8. Tab item press (FloatingTabBar)

    func testTabItemPressResolvesToTabItemSelectMotionId() {
        // FloatingTabBar.swift: TabPressButtonStyle isPressed
        let request = MotionRequest(operation: .update, sourceRole: "tabItem", containerRole: .mainTabShell)
        XCTAssertEqual(ReaderMotionAdapter.resolve(request: request), .tab_item_select,
                       "update + tabItem + mainTabShell must resolve to .tab_item_select")
    }

    // MARK: - 9. Voice pulse loop (ReaderSessionCapsuleView.startVoicePulse)

    func testVoicePulseSpecHasLoopForever() {
        // voice pulse 直接用 MotionId 调用 adapter（不走 resolver），验证 spec 有 loop
        let spec = ReaderMotionAdapter.spec(for: .reader_session_capsule_voiceIcon_active)
        XCTAssertNotNil(spec?.loop, "voiceIcon.active spec must have loop config")
        XCTAssertEqual(spec?.loop?.forever, true, "voiceIcon.active loop.forever must be true")
        XCTAssertEqual(spec?.loop?.autoreverses, true, "voiceIcon.active loop.autoreverses must be true")
    }

    func testVoicePulseAnimationIsRepeatForeverWhenReducedMotionOff() {
        let motion = MotionEnvironment(override: false)
        let animation = ReaderMotionAdapter.animation(for: .reader_session_capsule_voiceIcon_active, motion: motion)
        XCTAssertNotNil(animation, "voice pulse must yield a non-nil Animation when reduced motion is off")
        // Animation 非 nil 即可；SwiftUI Animation 类型不透明，无法静态断言 repeatForever
    }

    func testVoicePulseAnimationNilWhenReducedMotionOn() {
        let motion = MotionEnvironment(override: true)
        let animation = ReaderMotionAdapter.animation(for: .reader_session_capsule_voiceIcon_active, motion: motion)
        XCTAssertNil(animation, "voice pulse must yield nil when reduced motion is on (forceZeroDuration → seconds=0)")
    }

    // MARK: - Migration completeness: all second-batch requests resolve (never nil)

    func testAllSecondBatchMigrationRequestsResolve() {
        let requests: [MotionRequest] = [
            // reader page turn
            MotionRequest(operation: .update, sourceRole: "page", containerRole: .readerSurface),
            // session capsule update
            MotionRequest(operation: .update, containerRole: .sessionCapsule),
            // handle drag release
            MotionRequest(operation: .dragRelease, sourceRole: "handle", containerRole: .readerSurface),
            // dropdown expand
            MotionRequest(operation: .enter, targetRole: "dropdown", containerRole: .overlayHost),
            // dropdown collapse
            MotionRequest(operation: .exit, targetRole: "dropdown", containerRole: .overlayHost),
            // toast enter
            MotionRequest(operation: .enter, targetRole: "toast", containerRole: .overlayHost),
            // toggle switch
            MotionRequest(operation: .update, sourceRole: "toggle", containerRole: .listItem),
            // tab item press
            MotionRequest(operation: .update, sourceRole: "tabItem", containerRole: .mainTabShell),
        ]
        for request in requests {
            XCTAssertNotNil(ReaderMotionAdapter.resolve(request: request),
                           "all policy-backed second-batch requests must resolve explicitly")
        }
    }
}
