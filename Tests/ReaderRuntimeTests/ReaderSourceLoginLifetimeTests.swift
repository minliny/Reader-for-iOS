import XCTest
#if canImport(ReaderSourceLoginContract)
@testable import ReaderSourceLoginContract
#else
@testable import Reader
#endif

@MainActor
final class ReaderSourceLoginLifetimeTests: XCTestCase {
    /// Exact field projections from book_sources_20261024/book_sources_dedup.json.
    /// These address checks make no HTTP, authentication or Cookie success claim.
    func testCapturedLoginAddressesUseBlankFallbackAndRejectNonWebDeclaration() async throws {
        let blank = Data(#"{"bookSourceName":"速读谷","bookSourceUrl":"https://www.sudugu.co","loginUrl":""}"#.utf8)
        XCTAssertEqual(ReaderSourceLoginURL.resolve(definition: blank, baseURL: "https://www.sudugu.co")?.absoluteString,
                       "https://www.sudugu.co")
        let declared = Data(#"{"bookSourceName":"起点中文","bookSourceUrl":"https://www.qidian.com","loginUrl":"https://www.qidian.com/all/"}"#.utf8)
        XCTAssertEqual(ReaderSourceLoginURL.resolve(definition: declared, baseURL: "https://www.qidian.com")?.absoluteString,
                       "https://www.qidian.com/all/")
        let absent = Data(#"{"bookSourceName":"酷我小说","bookSourceUrl":"http://appi.kuwo.cn"}"#.utf8)
        XCTAssertEqual(ReaderSourceLoginURL.resolve(definition: absent, baseURL: "http://appi.kuwo.cn")?.absoluteString,
                       "http://appi.kuwo.cn")
        let nonWeb = Data(#"{"bookSourceName":"排行","bookSourceUrl":"http://fanyi.so.com","loginUrl":"❀"}"#.utf8)
        XCTAssertNil(ReaderSourceLoginURL.resolve(definition: nonWeb, baseURL: "http://fanyi.so.com"))
    }

    @MainActor
    private final class HeldStep {
        let entered = XCTestExpectation(description: "Original lifecycle step suspended")
        private var continuation: CheckedContinuation<Void, Never>?
        private var released = false
        func hold() async {
            guard !released else { return }
            await withCheckedContinuation { continuation in
                self.continuation = continuation; entered.fulfill()
            }
        }
        func release() {
            released = true; let original = continuation; continuation = nil; original?.resume()
        }
    }
    private func prepared(_ sourceID: String) throws -> ReaderSourceLoginLifetime {
        let owner = ReaderSourceLoginLifetime(sourceID: sourceID)
        let request = try XCTUnwrap(owner.beginPreparation())
        XCTAssertTrue(owner.finishPreparation(request))
        return owner
    }
    private func ready(_ sourceID: String) throws -> ReaderSourceLoginLifetime {
        let owner = try prepared(sourceID)
        let seed = try XCTUnwrap(owner.beginCookieSeed())
        XCTAssertTrue(owner.finishCookieSeed(seed))
        return owner
    }

    /// Domain/platform readiness scheduling only. No cookie bytes, HTTP login,
    /// source definition, book, Core reply or Keychain success is fabricated.
    func testCookieSeedReadinessBlocksEarlySaveAndRetiredSeedCannotPublish() async throws {
        let owner = try prepared("https://m.idejian.com")
        let seed = try XCTUnwrap(owner.beginCookieSeed())
        let held = HeldStep(); defer { held.release() }
        var lateSavablePublications = 0
        let originalSeed = Task { @MainActor in
            await held.hold()
            if owner.finishCookieSeed(seed) { lateSavablePublications += 1 }
        }
        await fulfillment(of: [held.entered], timeout: 5)
        XCTAssertFalse(owner.canSave)
        XCTAssertNil(owner.beginSave(), "Partial native seed must not enable the actual write action")
        owner.retire()
        let reopened = try prepared("https://m.idejian.com")
        let otherSource = try prepared("https://dushu.baidu.com/")
        XCTAssertNotEqual(owner.presentationID, reopened.presentationID)
        XCTAssertFalse(reopened.finishCookieSeed(seed))
        XCTAssertFalse(otherSource.finishCookieSeed(seed))
        held.release(); await originalSeed.value
        XCTAssertEqual(lateSavablePublications, 0)
        XCTAssertFalse(owner.canSave)
        XCTAssertFalse(reopened.canSave)
        let currentSeed = try XCTUnwrap(reopened.beginCookieSeed())
        XCTAssertTrue(reopened.finishCookieSeed(currentSeed))
        XCTAssertTrue(reopened.canSave)
        XCTAssertNotNil(reopened.beginSave())
        XCTAssertFalse(otherSource.canSave)
        // A late prepare result also has no publication right after retirement.
        let preparing = ReaderSourceLoginLifetime(sourceID: "https://m.idejian.com")
        let request = try XCTUnwrap(preparing.beginPreparation()); preparing.retire()
        XCTAssertFalse(preparing.acceptsPreparation(request))
        XCTAssertFalse(preparing.finishPreparation(request))
    }

    /// Opaque accepted-write completion, not a login/Keychain integration test.
    func testAcceptedOriginalCredentialWriteCanFinishWithoutPublishingIntoReopenedPresentation() async throws {
        let original = try ready("https://m.idejian.com")
        let save = try XCTUnwrap(original.beginSave())
        XCTAssertTrue(original.beginCredentialWrite(save))
        let held = HeldStep(); defer { held.release() }
        var completedExactSourceIDs: [String] = []
        var lateUI = 0, lateDismiss = 0
        let acceptedWrite = Task { @MainActor in
            await held.hold()
            completedExactSourceIDs.append(save.sourceID)
            if original.finishSave(save) { lateUI += 1; lateDismiss += 1 }
        }
        await fulfillment(of: [held.entered], timeout: 5)
        original.retire()
        let sameSource = try ready("https://m.idejian.com")
        let otherSource = try ready("https://dushu.baidu.com/")
        let sameSave = try XCTUnwrap(sameSource.beginSave())
        let otherSave = try XCTUnwrap(otherSource.beginSave())
        XCTAssertFalse(sameSource.finishSave(save))
        XCTAssertFalse(otherSource.finishSave(save))
        held.release(); await acceptedWrite.value
        XCTAssertEqual(completedExactSourceIDs, ["https://m.idejian.com"])
        XCTAssertEqual(lateUI, 0); XCTAssertEqual(lateDismiss, 0)
        XCTAssertFalse(sameSource.canSave, "Old completion cannot clear the new presentation's accepted identity")
        XCTAssertFalse(otherSource.canSave)
        XCTAssertTrue(sameSource.finishSave(sameSave))
        XCTAssertTrue(otherSource.finishSave(otherSave))
        XCTAssertTrue(sameSource.canSave); XCTAssertTrue(otherSource.canSave)
        // A cookie read that has not dispatched the service write is not an
        // accepted credential write and cannot start one after being retired.
        let readingOnly = try ready("https://m.idejian.com")
        let snapshot = try XCTUnwrap(readingOnly.beginSave()); readingOnly.retire()
        XCTAssertFalse(readingOnly.beginCredentialWrite(snapshot))
        XCTAssertFalse(readingOnly.finishSave(snapshot))
    }
}
