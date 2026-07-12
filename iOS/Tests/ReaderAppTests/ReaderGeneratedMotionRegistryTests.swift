import XCTest
import ReaderUIContract
@testable import ReaderApp

@MainActor
final class ReaderGeneratedMotionRegistryTests: XCTestCase {
    func testAll93GeneratedMotionsHaveExactSpecsAndNativeIdentity() {
        let generated = Set(ReaderUIContract.MotionId.allCases)
        let specs = Set(ReaderUIContract.MotionSpecRegistry.all.map(\.id))

        XCTAssertEqual(ReaderUIContract.MotionId.allCases.count, 93)
        XCTAssertEqual(specs, generated)

        for motionId in ReaderUIContract.MotionId.allCases {
            XCTAssertEqual(ReaderMotionAdapter.localMotionId(for: motionId), motionId)
            XCTAssertNotNil(ReaderMotionAdapter.spec(for: motionId), motionId.rawValue)
        }
    }

    func testGeneratedRawValuesRemainTheOnlyMotionWireNames() {
        XCTAssertEqual(
            ReaderUIContract.MotionId.dropdown_menu_expand.rawValue,
            "dropdown.menu.expand"
        )
        XCTAssertEqual(
            ReaderUIContract.MotionId.dropdown_menu_collapse.rawValue,
            "dropdown.menu.collapse"
        )
        XCTAssertEqual(
            ReaderUIContract.MotionId.reader_page_turn_next_prev.rawValue,
            "reader.page.turn.next-prev"
        )
        XCTAssertEqual(
            ReaderUIContract.MotionId.reader_session_capsule_control_press_toggle.rawValue,
            "reader.session.capsule.control.press-toggle"
        )
        XCTAssertEqual(ReaderUIContract.MotionId.tab_item_switch.rawValue, "tab.item.switch")

        let wireNames = ReaderUIContract.MotionId.allCases.map(\.rawValue)
        XCTAssertEqual(wireNames.count, Set(wireNames).count)
    }

    func testGeneratedMetadataDrivesNativeMotionFamily() {
        XCTAssertEqual(ReaderUIContract.MotionId.viewport_orientation_reshape.family, .viewport)
        XCTAssertEqual(ReaderUIContract.MotionId.reader_control_show.family, .reader)
        XCTAssertEqual(ReaderUIContract.MotionId.reader_control_handle_drag.family, .reader)
        XCTAssertEqual(ReaderUIContract.MotionId.tab_item_press.family, .app)
    }

    func testMotionControllerAcceptsNewGeneratedIdentifierWithoutAdapterCase() {
        let controller = MotionController()
        let transaction = controller.start(
            id: .reader_control_show,
            fromState: "hidden",
            toState: "visible",
            interruptMode: .redirect,
            finalState: "visible",
            durationSeconds: 0.16
        )

        XCTAssertEqual(controller.snapshot(for: .reader_control_show)?.id, .reader_control_show)
        XCTAssertEqual(controller.activeCount(for: .reader_control_show), 1)
        controller.settle(transactionId: transaction)
        XCTAssertEqual(controller.activeCount(for: .reader_control_show), 0)
    }
}
