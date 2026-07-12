import XCTest
import ReaderUIContract
import ReaderUIRuntime
@testable import ReaderApp

/// Shadow-only checks for the real `book.open` payload boundary. These do not
/// change rollout ownership: native code remains the production writer.
@MainActor
final class BookOpenShadowPayloadTests: XCTestCase {
    func testLegacyLocalChapterURLSelectsLocalBranchEvenWithLegacySourceID() throws {
        let shadow = ReaderUIRuntimeShadowCoordinator()

        let transition = try XCTUnwrap(shadow.observe(UiEvent(
            type: .book_open,
            payload: [
                "bookId": AnyCodable("core-local-book-1"),
                "sourceId": AnyCodable("legacy-import-record"),
                "chapterUrl": AnyCodable("local-book://chapter/7"),
            ],
            correlationId: "local-url-1"
        ))).get()

        XCTAssertEqual(transition.effects.map(\.type), ["chapter.list"])
        XCTAssertEqual(transition.effects.map(\.correlationId), ["local-url-1"])
    }

    func testExplicitPayloadSourceKindIsNotOverriddenByFallbackClassifier() throws {
        let shadow = ReaderUIRuntimeShadowCoordinator()

        let transition = try XCTUnwrap(shadow.observe(UiEvent(
            type: .book_open,
            payload: [
                "bookId": AnyCodable("remote-book-1"),
                "sourceId": AnyCodable("remote-source-1"),
                "sourceKind": AnyCodable("remote"),
                "chapterUrl": AnyCodable("local-book://stale-cache-path"),
            ],
            correlationId: "remote-explicit-1"
        ))).get()

        XCTAssertEqual(transition.effects.map(\.type), ["source.detail"])
        XCTAssertEqual(transition.effects.map(\.correlationId), ["remote-explicit-1"])
    }
}
