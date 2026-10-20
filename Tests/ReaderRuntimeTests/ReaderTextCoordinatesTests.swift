import Foundation
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderTextCoordinatesTests: XCTestCase {
    func testTextKitUTF16DoesNotBecomeAScalarOrGraphemeOffset() {
        let text = "甲🙂e\u{301}乙"
        XCTAssertEqual(text.count, 4)
        XCTAssertEqual(text.unicodeScalars.count, 5)
        XCTAssertEqual(text.utf16.count, 6)
        let utf16AtScalarBoundary = [0, 1, 3, 4, 5, 6]
        for (scalar, utf16) in utf16AtScalarBoundary.enumerated() {
            XCTAssertEqual(ReaderTextCoordinates.utf16Offset(in: text, scalarOffset: UInt64(scalar)), utf16)
            XCTAssertEqual(ReaderTextCoordinates.scalarOffset(in: text, utf16Offset: utf16), UInt64(scalar))
        }
        // TextKit offsets inside a surrogate pair round down to its scalar.
        XCTAssertEqual(ReaderTextCoordinates.scalarOffset(in: text, utf16Offset: 2), 1)
        XCTAssertEqual(ReaderTextCoordinates.scalarOffset(in: text, utf16Offset: -1), 0)
        XCTAssertEqual(ReaderTextCoordinates.utf16Offset(in: text, scalarOffset: UInt64.max), 6)
    }

    func testShelfProjectionCanOmitCoreDefaultFields() throws {
        let data = Data(#"{"sourceId":"local","bookId":"local:sample"}"#.utf8)
        let book = try JSONDecoder().decode(ReaderBook.self, from: data)
        XCTAssertEqual(book.title, "")
        XCTAssertEqual(book.author, "")
        XCTAssertEqual(book.chapterCount, 0)
        XCTAssertNil(book.currentChapterIndex)
        XCTAssertNil(book.readProgress)
    }
}
