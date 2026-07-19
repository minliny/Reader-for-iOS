import XCTest
@testable import ReaderShellValidation

final class ReaderSlice12CapabilityRegistryTests: XCTestCase {
    func testRegistryIsCompleteAndInternallyConsistent() {
        XCTAssertEqual(ReaderSlice12CapabilityRegistry.validate(), [])
        XCTAssertEqual(
            Set(ReaderSlice12CapabilityRegistry.records.map(\.id)),
            Set(ReaderSlice12CapabilityID.allCases)
        )
    }

    func testLocalToolingDoesNotPromoteReleaseOrDeviceGates() {
        XCTAssertEqual(ReaderSlice12CapabilityRegistry.capability(.displaySettingsMigration).state, .executable)
        XCTAssertEqual(ReaderSlice12CapabilityRegistry.capability(.releaseIdentityAudit).state, .executable)
        XCTAssertEqual(ReaderSlice12CapabilityRegistry.capability(.fullProductReleaseGate).state, .blocked)
        XCTAssertEqual(ReaderSlice12CapabilityRegistry.capability(.accessibilityRuntime).state, .partial)
        XCTAssertEqual(ReaderSlice12CapabilityRegistry.capability(.responsiveViewports).state, .partial)
    }

    func testMissingCoreOwnersStayBlocked() {
        for id in [ReaderSlice12CapabilityID.durableOnboardingOwner, .generalSettingsOwner, .backgroundRecovery] {
            let value = ReaderSlice12CapabilityRegistry.capability(id)
            XCTAssertEqual(value.state, .blocked, id.rawValue)
            XCTAssertFalse(value.blockerCodes.isEmpty, id.rawValue)
        }
    }

    func testPlannedRoutesAndHostPrimitivesAreNotAppDeviceEvidence() {
        let onboarding = ReaderSlice12CapabilityRegistry.capability(.onboardingPermissionRecovery)
        XCTAssertTrue(onboarding.blockerCodes.contains("SLICE12_ONBOARDING_NATIVE_ROUTE_WIRING_MISSING"))
        XCTAssertTrue(onboarding.blockerCodes.contains("SLICE12_SYSTEM_SETTINGS_OPEN_CONTRACT_MISSING"))
        let system = ReaderSlice12CapabilityRegistry.capability(.systemIntegration)
        XCTAssertTrue(system.blockerCodes.contains("SLICE12_SYSTEM_INTEGRATION_BUSINESS_ENTRY_MATRIX_MISSING"))
        let release = ReaderSlice12CapabilityRegistry.capability(.fullProductReleaseGate)
        XCTAssertTrue(release.blockerCodes.contains("SLICE12_COMPLETE_JOURNEY_DEVICE_PROOF_MISSING"))
    }
}
