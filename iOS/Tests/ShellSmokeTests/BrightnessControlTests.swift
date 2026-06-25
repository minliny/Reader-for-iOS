import XCTest
@testable import ReaderShellValidation

final class BrightnessControlTests: XCTestCase {

    func testPolicyDefaultsToDisabledWithSafeLevel() {
        let policy = BrightnessPolicy()
        XCTAssertFalse(policy.enabled, "Default policy should be disabled (no brightness override)")
        XCTAssertEqual(policy.level, 0.8, accuracy: 0.001)
        XCTAssertTrue(policy.restoreOnExit, "Default should restore system brightness on exit")
    }

    func testPolicyLevelClampedToValidRange() {
        let tooHigh = BrightnessPolicy(enabled: true, level: 1.5, restoreOnExit: true)
        XCTAssertEqual(tooHigh.level, 1.0, accuracy: 0.001, "Level > 1.0 should clamp to 1.0")

        let tooLow = BrightnessPolicy(enabled: true, level: -0.3, restoreOnExit: true)
        XCTAssertEqual(tooLow.level, 0.0, accuracy: 0.001, "Level < 0.0 should clamp to 0.0")
    }

    func testStubControllerAppliesPolicyWhenEnabled() {
        let stub = StubBrightnessController()
        let policy = BrightnessPolicy(enabled: true, level: 0.5, restoreOnExit: true)
        stub.apply(policy)
        XCTAssertEqual(stub.appliedPolicy?.level ?? -1, 0.5, accuracy: 0.001)
        XCTAssertEqual(stub.currentLevel(), 0.5, accuracy: 0.001)
    }

    func testStubControllerSkipsApplyWhenDisabled() {
        let stub = StubBrightnessController()
        let policy = BrightnessPolicy(enabled: false, level: 0.5, restoreOnExit: true)
        stub.apply(policy)
        XCTAssertNil(stub.appliedPolicy, "Disabled policy should not be applied")
    }

    func testStubControllerRestoreClearsAppliedPolicy() {
        let stub = StubBrightnessController()
        stub.apply(BrightnessPolicy(enabled: true, level: 0.3, restoreOnExit: true))
        XCTAssertEqual(stub.restoreCallCount, 0)
        stub.restore()
        XCTAssertEqual(stub.restoreCallCount, 1)
    }

    func testPolicyIsCodable() throws {
        let policy = BrightnessPolicy(enabled: true, level: 0.65, restoreOnExit: false)
        let data = try JSONEncoder().encode(policy)
        let decoded = try JSONDecoder().decode(BrightnessPolicy.self, from: data)
        XCTAssertEqual(policy, decoded)
    }
}
