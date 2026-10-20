import Foundation
import XCTest
@testable import Reader

@MainActor
final class ReaderFilePickerOwnerTests: XCTestCase {
    private let first = URL(fileURLWithPath: "/selection/first.txt")
    private let second = URL(fileURLWithPath: "/selection/second.txt")

    func testSelectionThenDismissDeliversExactlyOneReadyURL() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        XCTAssertTrue(owner.presented.wrappedValue)
        XCTAssertNil(owner.select(first, operationID: id))
        XCTAssertFalse(owner.presented.wrappedValue)
        XCTAssertEqual(owner.didDismiss(), first)
        XCTAssertNil(owner.operationID)
        XCTAssertNil(owner.didDismiss(operationID: id))
        XCTAssertNil(owner.select(first, operationID: id))
    }

    func testDismissThenSelectionDeliversTheLateDelegateURLExactlyOnce() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        XCTAssertNil(owner.didDismiss())
        XCTAssertFalse(owner.isPresented)
        XCTAssertEqual(owner.operationID, id, "Dismissal must retain ownership until selection or cancellation arrives")
        XCTAssertNil(owner.didDismiss(operationID: id), "A duplicate dismissal cannot consume the still-awaited selection")
        XCTAssertEqual(owner.select(first, operationID: id), first)
        XCTAssertNil(owner.select(first, operationID: id))
        XCTAssertNil(owner.didDismiss())
    }

    func testSystemBindingCloseDoesNotCancelASelectionWhoseDelegateHasNotArrived() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        owner.presented.wrappedValue = false
        XCTAssertNil(owner.didDismiss())
        XCTAssertEqual(owner.operationID, id)
        XCTAssertEqual(owner.select(first, operationID: id), first)
    }

    func testDuplicateSelectionCannotReplaceTheOriginalIntentBeforeDismissal() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        XCTAssertNil(owner.select(first, operationID: id))
        XCTAssertNil(owner.select(second, operationID: id))
        XCTAssertEqual(owner.didDismiss(operationID: id), first)
        XCTAssertNil(owner.didDismiss(operationID: id))
    }

    func testCancelAfterSelectionPreventsDeliveryAndOldCallbacksCannotAffectTheNextPicker() async {
        let owner = ReaderFilePickerOwner()
        let old = owner.begin()
        XCTAssertNil(owner.select(first, operationID: old))
        owner.cancel(operationID: old)
        let current = owner.begin()
        XCTAssertNotEqual(current, old)
        XCTAssertNil(owner.didDismiss(), "The older closing identity must not dismiss the new presentation")
        XCTAssertTrue(owner.isPresented)
        XCTAssertEqual(owner.operationID, current)
        XCTAssertNil(owner.select(first, operationID: old))
        owner.cancel(operationID: old)
        XCTAssertEqual(owner.operationID, current)
        XCTAssertNil(owner.select(second, operationID: current))
        XCTAssertEqual(owner.didDismiss(operationID: current), second)
    }

    func testCancelAfterDismissPreventsLateSelectionFromStartingAnImport() async {
        let owner = ReaderFilePickerOwner()
        let old = owner.begin()
        XCTAssertNil(owner.didDismiss(operationID: old))
        owner.cancel(operationID: old)
        let current = owner.begin()
        XCTAssertNil(owner.select(first, operationID: old))
        XCTAssertNil(owner.didDismiss(operationID: old))
        owner.cancel(operationID: old)
        XCTAssertTrue(owner.isPresented)
        XCTAssertEqual(owner.operationID, current)
        XCTAssertNil(owner.didDismiss(operationID: current))
        XCTAssertEqual(owner.select(second, operationID: current), second)
    }

    func testNewExplicitRequestSupersedesAnOldDismissedOperationAwaitingSelection() async {
        let owner = ReaderFilePickerOwner()
        let old = owner.begin()
        XCTAssertNil(owner.didDismiss(operationID: old))
        let current = owner.begin()
        XCTAssertNotEqual(current, old)
        XCTAssertNil(owner.select(first, operationID: old))
        XCTAssertNil(owner.select(second, operationID: current))
        XCTAssertEqual(owner.didDismiss(), second)
    }

    func testRepeatedBeginDuringPresentationKeepsTheAlreadyCreatedDelegateIdentity() async {
        let owner = ReaderFilePickerOwner()
        let id = owner.begin()
        XCTAssertEqual(owner.begin(), id)
        XCTAssertNil(owner.select(first, operationID: id))
        XCTAssertEqual(owner.didDismiss(), first)
    }
}
