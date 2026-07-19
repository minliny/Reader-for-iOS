import XCTest
import ReaderUIContract
@testable import ReaderApp

@MainActor
final class ReaderGeneratedMotionRegistryTests: XCTestCase {
    func testAll95GeneratedMotionsHaveSpecsAndNativeIdentity() {
        let generated = Set(ReaderUIContract.MotionId.allCases)
        let specs = Set(ReaderUIContract.MotionSpecRegistry.all.map(\.id))

        XCTAssertEqual(ReaderUIContract.MotionId.allCases.count, 95)
        XCTAssertEqual(specs, generated)

        for motionId in ReaderUIContract.MotionId.allCases {
            XCTAssertEqual(ReaderMotionAdapter.localMotionId(for: motionId), motionId)
            XCTAssertNotNil(ReaderMotionAdapter.spec(for: motionId), motionId.rawValue)
        }
    }

    func testGeneratedRegistrySeparates89ActiveExactMotionsFromSixNonProductionIds() {
        let nonProductionIds: Set<String> = [
            "reader.sourceSwitch.open-close",
            "overlay.dialog.enter-exit",
            "overlay.sheet.enter-exit",
            "reader.session.controlSpace.enter",
            "reader.session.controlSpace.update",
            "reader.session.controlSpace.exit"
        ]
        let activeExact = ReaderUIContract.MotionSpecRegistry.all.filter { spec in
            spec.trigger?.isEmpty == false &&
                spec.from?.isEmpty == false &&
                spec.to?.isEmpty == false &&
                spec.interrupt?.isEmpty == false &&
                spec.finalState?.isEmpty == false &&
                spec.cleanup?.isEmpty == false
        }
        let exactIds = Set(activeExact.map(\.id.rawValue))
        let pendingIds = Set(ReaderUIContract.MotionSpecRegistry.all.map(\.id.rawValue))
            .subtracting(exactIds)
        let deprecatedIds = Set(
            ReaderUIContract.MotionSpecRegistry.all
                .filter { $0.deprecated == true }
                .map(\.id.rawValue)
        )

        XCTAssertEqual(activeExact.count, 89)
        XCTAssertEqual(pendingIds, nonProductionIds)
        XCTAssertEqual(
            deprecatedIds,
            [
                "reader.sourceSwitch.open-close",
                "overlay.dialog.enter-exit",
                "overlay.sheet.enter-exit"
            ]
        )
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
