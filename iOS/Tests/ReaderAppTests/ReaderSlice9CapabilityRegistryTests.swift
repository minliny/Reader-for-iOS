import XCTest
@testable import ReaderShellValidation

final class ReaderSlice9CapabilityRegistryTests: XCTestCase {
    func testRegistryIsCompleteAndInternallyConsistent() {
        XCTAssertEqual(ReaderSlice9CapabilityRegistry.validate(), [])
        XCTAssertEqual(
            Set(ReaderSlice9CapabilityRegistry.records.map(\.id)),
            Set(ReaderSlice9CapabilityID.allCases)
        )
    }

    func testMissingPlatformContractsRemainFailClosed() {
        let blocked: [ReaderSlice9CapabilityID] = [
            .localPDFInteractive,
            .mangaReader,
            .contentAudioReader,
            .downloadQueue,
            .storageManagement,
        ]
        for id in blocked {
            let capability = ReaderSlice9CapabilityRegistry.capability(id)
            XCTAssertEqual(capability.state, .blocked, id.rawValue)
            XCTAssertFalse(capability.blockerCodes.isEmpty, id.rawValue)
        }
    }

    func testTTSIsNotRegisteredAsContentAudioEvidence() {
        let audio = ReaderSlice9CapabilityRegistry.capability(.contentAudioReader)
        XCTAssertEqual(audio.state, .blocked)
        XCTAssertTrue(audio.implementedContracts.isEmpty)
        XCTAssertTrue(audio.boundaryNote.contains("TTS"))
    }

    func testDownloadAndStorageClaimsStayNarrow() {
        let foreground = ReaderSlice9CapabilityRegistry.capability(.mediaDownloadForeground)
        XCTAssertEqual(foreground.state, .partial)
        XCTAssertEqual(foreground.implementedContracts, ["media.download"])
        XCTAssertTrue(foreground.blockerCodes.contains("SLICE9_BACKGROUND_DOWNLOAD_NOT_IMPLEMENTED"))

        XCTAssertEqual(ReaderSlice9CapabilityRegistry.capability(.storagePath).state, .executable)
        XCTAssertEqual(ReaderSlice9CapabilityRegistry.capability(.storageManagement).state, .blocked)
    }
}
