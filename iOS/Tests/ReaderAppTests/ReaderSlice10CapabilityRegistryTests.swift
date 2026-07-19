import XCTest
@testable import ReaderShellValidation

final class ReaderSlice10CapabilityRegistryTests: XCTestCase {
    func testRegistryIsCompleteAndInternallyConsistent() {
        XCTAssertEqual(ReaderSlice10CapabilityRegistry.validate(), [])
        XCTAssertEqual(
            Set(ReaderSlice10CapabilityRegistry.records.map(\.id)),
            Set(ReaderSlice10CapabilityID.allCases)
        )
    }

    func testCompatibilityAndRuntimeOnlyPathsAreNotPromotedToFrozenSchemas() {
        XCTAssertEqual(
            ReaderSlice10CapabilityRegistry.capability(.sourceSwitchTransaction).contractMaturity,
            .readerUICompatibilityOnly
        )
        XCTAssertEqual(
            ReaderSlice10CapabilityRegistry.capability(.replaceCompatibility).contractMaturity,
            .readerUICompatibilityOnly
        )
        XCTAssertEqual(
            ReaderSlice10CapabilityRegistry.capability(.contentEdit).contractMaturity,
            .runtimeOnly
        )
        XCTAssertEqual(
            ReaderSlice10CapabilityRegistry.capability(.coverCandidateDiscovery).contractMaturity,
            .runtimeOnly
        )
    }

    func testAbsentMutationAndPlaybackContractsRemainBlocked() {
        let blocked: [ReaderSlice10CapabilityID] = [
            .dictionaryRuleCRUD,
            .coverApply,
            .chapterReviewsWrite,
            .httpTTSPlayback,
        ]
        for id in blocked {
            let capability = ReaderSlice10CapabilityRegistry.capability(id)
            XCTAssertEqual(capability.state, .blocked, id.rawValue)
            XCTAssertFalse(capability.blockerCodes.isEmpty, id.rawValue)
        }
    }

    func testBookmarkAndReadRecordDoNotClaimMissingLocators() {
        let bookmark = ReaderSlice10CapabilityRegistry.capability(.bookmarks)
        XCTAssertTrue(bookmark.blockerCodes.contains("SLICE10_BOOKMARK_CANONICAL_LOCATOR_MISSING"))
        XCTAssertTrue(bookmark.boundaryNote.contains("fails closed"))

        let records = ReaderSlice10CapabilityRegistry.capability(.readRecords)
        XCTAssertTrue(records.blockerCodes.contains("SLICE10_READ_RECORD_CHAPTER_LOCATOR_MISSING"))
        XCTAssertTrue(records.boundaryNote.contains("not chapter navigation history"))
    }

    func testHttpTTSAndSystemTTSRemainSeparateCapabilities() {
        XCTAssertEqual(ReaderSlice10CapabilityRegistry.capability(.httpTTSPlayback).state, .blocked)
        XCTAssertEqual(ReaderSlice10CapabilityRegistry.capability(.ttsQueue).state, .partial)
        XCTAssertTrue(
            ReaderSlice10CapabilityRegistry.capability(.ttsQueue).boundaryNote.contains("separate capabilities")
        )
    }
}
