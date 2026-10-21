import XCTest
@testable import Reader

/// DTO binding and controlled callback scheduling only. These callbacks are not
/// Core results, HTTP bodies, a source definition, or evidence of rule parsing.
@MainActor
final class ReaderSourceDebugLifetimeTests: XCTestCase {
    private enum ControlledFailure: Error { case late, cleanup }

    @MainActor
    private final class HeldRead {
        let entered = XCTestExpectation(description: "Exact original debug read entered")
        private var continuation: CheckedContinuation<Data, Error>?
        private var outcome: Result<Data, Error>?
        private(set) var parameters: Data?

        func read(_ parameters: Data) async throws -> Data {
            self.parameters = parameters; entered.fulfill()
            if let outcome { return try outcome.get() }
            // Deliberately drain only when released, even if cancelled. This
            // exposes an old success/error/finalizer arriving after a new run.
            return try await withCheckedThrowingContinuation { continuation = $0 }
        }

        func complete(_ result: Result<Data, Error>) {
            guard outcome == nil else { return }
            outcome = result
            let original = continuation; continuation = nil
            original?.resume(with: result)
        }
    }

    private func defaults() throws -> (UserDefaults, String) {
        let suite = "ReaderSourceDebugLifetimeTests." + UUID().uuidString
        return (try XCTUnwrap(UserDefaults(suiteName: suite)), suite)
    }

    private func callback(_ identity: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["controlledCallback": identity])
    }

    private func displayedCallback(_ owner: ReaderSourceDebugOwner) throws -> String? {
        guard let result = owner.result else { return nil }
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(result.utf8)) as? [String: Any])
        return object["controlledCallback"] as? String
    }

    private func source(_ identity: String) -> ReaderOnlineSource {
        // Namespacing/presentation identity only; never dispatched or imported.
        ReaderOnlineSource(sourceId: identity, name: identity, baseURL: identity,
            enabled: true, version: "", group: "", definition: Data())
    }

    func testResponsesBindCurrentSourceAndRejectExplicitIdentityConflict() throws {
        let sourceID = "https://m.idejian.com"
        let draft = #"{"searchResponse":"","detailResponse":"","tocResponse":"","contentResponse":"","chapterTitle":"","bookId":"retained-context"}"#
        let parameters = try ReaderSourceDebugOwner.parameters(sourceID: sourceID, key: "retained key", responses: draft)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: parameters) as? [String: Any])
        var payload = try XCTUnwrap(object["responses"] as? [String: Any])
        XCTAssertEqual(object["sourceId"] as? String, sourceID)
        XCTAssertEqual(object["key"] as? String, "retained key")
        XCTAssertEqual(payload.removeValue(forKey: "sourceId") as? String, sourceID)
        let original = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(draft.utf8)) as? [String: Any])
        XCTAssertEqual(payload as NSDictionary, original as NSDictionary, "Binding may only add the current source identity")
        let empty = try ReaderSourceDebugOwner.parameters(sourceID: sourceID, key: "", responses: "{}")
        let emptyObject = try XCTUnwrap(JSONSerialization.jsonObject(with: empty) as? [String: Any])
        XCTAssertEqual((emptyObject["responses"] as? [String: String])?["sourceId"], sourceID)

        let explicit = try JSONSerialization.data(withJSONObject: ["sourceId": sourceID, "searchResponse": ""])
        XCTAssertNoThrow(try ReaderSourceDebugOwner.parameters(sourceID: sourceID, key: "", responses: String(decoding: explicit, as: UTF8.self)))
        let explicitIDs: [Any] = ["https://dushu.baidu.com/", "", NSNull(), 1]
        for explicitID in explicitIDs {
            let conflicting = try JSONSerialization.data(withJSONObject: ["sourceId": explicitID])
            XCTAssertThrowsError(try ReaderSourceDebugOwner.parameters(sourceID: sourceID, key: "", responses: String(decoding: conflicting, as: UTF8.self)))
        }
        XCTAssertThrowsError(try ReaderSourceDebugOwner.parameters(sourceID: sourceID, key: "", responses: "[]"))

        let (preferences, suite) = try defaults()
        defer { preferences.removePersistentDomain(forName: suite) }
        let owner = ReaderSourceDebugOwner(sourceID: sourceID, defaults: preferences)
        let conflict = #"{"sourceId":"https://dushu.baidu.com/"}"#
        owner.updateResponses(conflict)
        var calls = 0
        XCTAssertNil(owner.run { _ in calls += 1; return Data() })
        XCTAssertEqual(calls, 0, "A conflicting identity must fail before dispatch")
        XCTAssertEqual(owner.responses, conflict, "A rejected wire binding must not rewrite the user's draft")
        XCTAssertFalse(owner.running); XCTAssertNotNil(owner.failure)
    }

    func testEditingAndStopCancelOldReadWithoutPublishingOrClearingNewRun() async throws {
        let (preferences, suite) = try defaults()
        defer { preferences.removePersistentDomain(forName: suite) }
        let owner = ReaderSourceDebugOwner(sourceID: "https://m.idejian.com", defaults: preferences)
        let first = HeldRead(), second = HeldRead(), third = HeldRead(), current = HeldRead()
        defer {
            owner.retire()
            for read in [first, second, third, current] { read.complete(.failure(ControlledFailure.cleanup)) }
        }
        owner.updateKey("original key")
        let firstTask = try XCTUnwrap(owner.run { try await first.read($0) })
        await fulfillment(of: [first.entered], timeout: 2)
        owner.updateKey("edited key")
        XCTAssertTrue(firstTask.isCancelled); XCTAssertFalse(owner.running)
        let secondTask = try XCTUnwrap(owner.run { try await second.read($0) })
        await fulfillment(of: [second.entered], timeout: 2)
        let originalParameters = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(first.parameters)) as? [String: Any])
        let editedParameters = try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(second.parameters)) as? [String: Any])
        XCTAssertEqual(originalParameters["key"] as? String, "original key")
        XCTAssertEqual(editedParameters["key"] as? String, "edited key")
        first.complete(.success(try callback("old-key-success")))
        await firstTask.value
        XCTAssertTrue(owner.running, "An old finalizer cannot clear the new run")
        XCTAssertNil(owner.result); XCTAssertNil(owner.failure)

        owner.updateResponses(#"{"searchResponse":""}"#)
        XCTAssertTrue(secondTask.isCancelled); XCTAssertFalse(owner.running)
        let thirdTask = try XCTUnwrap(owner.run { try await third.read($0) })
        await fulfillment(of: [third.entered], timeout: 2)
        second.complete(.failure(ControlledFailure.late))
        await secondTask.value
        XCTAssertTrue(owner.running); XCTAssertNil(owner.result); XCTAssertNil(owner.failure)

        owner.stop()
        XCTAssertTrue(thirdTask.isCancelled); XCTAssertFalse(owner.running)
        XCTAssertEqual(owner.key, "edited key")
        XCTAssertEqual(owner.responses, #"{"searchResponse":""}"#)
        let currentTask = try XCTUnwrap(owner.run { try await current.read($0) })
        await fulfillment(of: [current.entered], timeout: 2)
        third.complete(.success(try callback("stopped-success")))
        await thirdTask.value
        XCTAssertTrue(owner.running); XCTAssertNil(owner.result); XCTAssertNil(owner.failure)
        current.complete(.success(try callback("current")))
        await currentTask.value
        XCTAssertFalse(owner.running); XCTAssertNil(owner.failure)
        XCTAssertEqual(try displayedCallback(owner), "current")
    }

    func testClosedPresentationPreservesDraftAndRejectsLateCompletionAfterSameSourceReopen() async throws {
        let (preferences, suite) = try defaults()
        defer { preferences.removePersistentDomain(forName: suite) }
        let identity = "https://m.idejian.com"
        let original = ReaderSourceDebugPresentation(source: source(identity), defaults: preferences)
        original.owner.updateKey("retained debug key")
        let draft = #"{"tocResponse":"","bookId":"retained-context"}"#
        original.owner.updateResponses(draft)
        let oldRead = HeldRead(), newRead = HeldRead()
        defer {
            original.owner.retire()
            oldRead.complete(.failure(ControlledFailure.cleanup)); newRead.complete(.failure(ControlledFailure.cleanup))
        }
        let originalTask = try XCTUnwrap(original.owner.run { try await oldRead.read($0) })
        await fulfillment(of: [oldRead.entered], timeout: 2)
        original.owner.retire() // Close; the later onDisappear must be idempotent.
        XCTAssertTrue(originalTask.isCancelled); XCTAssertFalse(original.owner.running)
        let reopened = ReaderSourceDebugPresentation(source: source(identity), defaults: preferences)
        let other = ReaderSourceDebugPresentation(source: source("https://dushu.baidu.com/"), defaults: preferences)
        defer { reopened.owner.retire(); other.owner.retire() }
        XCTAssertNotEqual(original.id, reopened.id)
        XCTAssertNotEqual(reopened.id, other.id)
        XCTAssertEqual(reopened.owner.presentationID, reopened.id)
        XCTAssertEqual(reopened.owner.key, "retained debug key"); XCTAssertEqual(reopened.owner.responses, draft)
        XCTAssertEqual(other.owner.key, ""); XCTAssertEqual(other.owner.responses, "{}")
        let reopenedTask = try XCTUnwrap(reopened.owner.run { try await newRead.read($0) })
        await fulfillment(of: [newRead.entered], timeout: 2)
        original.owner.retire() // Obsolete disappearance cannot persist the old draft again.
        oldRead.complete(.failure(ControlledFailure.late))
        await originalTask.value
        XCTAssertNil(original.owner.result); XCTAssertNil(original.owner.failure)
        XCTAssertTrue(reopened.owner.running, "Old presentation completion cannot clear the reopened read")
        XCTAssertEqual(reopened.owner.key, "retained debug key")
        XCTAssertNil(reopened.owner.result); XCTAssertNil(reopened.owner.failure)
        XCTAssertNil(other.owner.result); XCTAssertNil(other.owner.failure)
        var retiredCalls = 0
        XCTAssertNil(original.owner.run { _ in retiredCalls += 1; return Data() })
        XCTAssertEqual(retiredCalls, 0)
        reopened.owner.updateKey("new presentation key")
        XCTAssertTrue(reopenedTask.isCancelled)
        newRead.complete(.success(try callback("retired-reopen-read")))
        await reopenedTask.value
        XCTAssertNil(reopened.owner.result)
        reopened.owner.retire()
        original.owner.retire() // A late obsolete disappearance cannot overwrite the newer saved draft.
        let afterDisappearance = ReaderSourceDebugPresentation(source: source(identity), defaults: preferences)
        defer { afterDisappearance.owner.retire() }
        XCTAssertEqual(afterDisappearance.owner.key, "new presentation key")
        XCTAssertEqual(afterDisappearance.owner.responses, draft)
        XCTAssertFalse(afterDisappearance.owner.running)
    }
}
