import XCTest
@testable import ReaderShellValidation

final class ReaderSlice11CapabilityRegistryTests: XCTestCase {
    func testRegistryIsCompleteAndInternallyConsistent() {
        XCTAssertEqual(ReaderSlice11CapabilityRegistry.validate(), [])
        XCTAssertEqual(
            Set(ReaderSlice11CapabilityRegistry.records.map(\.id)),
            Set(ReaderSlice11CapabilityID.allCases)
        )
    }

    func testFourSourceBoundariesRemainExplicit() {
        XCTAssertEqual(ReaderSlice11CapabilityRegistry.capability(.ordinaryHTTP).state, .executable)
        XCTAssertEqual(ReaderSlice11CapabilityRegistry.capability(.cookieSessionIsolation).state, .partial)
        XCTAssertEqual(ReaderSlice11CapabilityRegistry.capability(.webViewProfileIsolation).state, .partial)
        XCTAssertEqual(ReaderSlice11CapabilityRegistry.capability(.publicRSS).state, .partial)
        XCTAssertEqual(ReaderSlice11CapabilityRegistry.capability(.authenticatedRSS).state, .blocked)
    }

    func testMissingContractsAreBlockedInsteadOfPlannedAsPassed() {
        let blocked: [ReaderSlice11CapabilityID] = [
            .ruleSubscription,
            .webViewLoginReturn,
            .captchaChallengeReturn,
            .authenticatedRSS,
            .authorizationProtectedDownload,
            .antiBotHumanChallenge,
        ]
        for id in blocked {
            let capability = ReaderSlice11CapabilityRegistry.capability(id)
            XCTAssertEqual(capability.state, .blocked, id.rawValue)
            XCTAssertFalse(capability.blockerCodes.isEmpty, id.rawValue)
            XCTAssertEqual(capability.contractMaturity, .absent, id.rawValue)
        }
    }

    func testCorpusAndDeviceEvidenceRemainPartial() {
        let partial: [ReaderSlice11CapabilityID] = [
            .legadoDSLImport,
            .sourceLiveCheck,
            .dynamicSourceCRUD,
            .cookieSessionIsolation,
            .webViewProfileIsolation,
            .credentialIsolation,
            .publicRSS,
        ]
        for id in partial {
            let capability = ReaderSlice11CapabilityRegistry.capability(id)
            XCTAssertEqual(capability.state, .partial, id.rawValue)
            XCTAssertFalse(capability.blockerCodes.isEmpty, id.rawValue)
        }
    }

    func testHostManifestNeverAdvertisesAntiBotOrPrivateCredentialCapability() {
        XCTAssertFalse(ReaderSlice11HostManifest.lanes.contains("anti_bot"))
        XCTAssertFalse(ReaderSlice11HostManifest.capabilities.contains("credential.get"))
        XCTAssertFalse(ReaderSlice11HostManifest.capabilities.contains("credential.set"))
        XCTAssertTrue(ReaderSlice11HostManifest.capabilities.contains("http.execute"))
        XCTAssertTrue(ReaderSlice11HostManifest.capabilities.contains("media.download"))
    }
}
