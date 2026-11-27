import ReaderDesign
import UIKit
import XCTest
@testable import ReaderApp

@MainActor
final class Wave2CoreTextTests: XCTestCase {
    func testScalarCoordinatesNativeSelectionAndReflow() async throws {
        let phrase = "中文𠀀😀Cafe\u{301}与纸墨"
        let text = Array(repeating: phrase + "，江山如画，清风入卷。\n", count: 130).joined()
        let coordinates = ScalarCoordinates(text)
        XCTAssertEqual(coordinates.scalar(at: 2), 2)
        XCTAssertNil(coordinates.scalar(at: 3), "Reject an index inside a CJK Ext surrogate pair")
        XCTAssertNil(coordinates.scalar(at: 5), "Reject an index inside an emoji surrogate pair")
        XCTAssertEqual(coordinates.utf16(at: 4), 6)
        for scalar in 0...coordinates.scalarCount {
            XCTAssertEqual(coordinates.utf16(at: scalar).flatMap(coordinates.scalar(at:)), scalar)
        }
        XCTAssertEqual(coordinates.string(2..<9), "𠀀😀Cafe\u{301}")
        let native = TextReadingSurface()
        native.prepare(preferences: .init(fontSize: 18), viewport: CGSize(width: 340, height: 510))
        let anchor = 107
        let before = try await native.open(.init(content: text), session: "coretext-native", anchor: anchor, style: .init())
        let first = try XCTUnwrap(native.layout)
        XCTAssertGreaterThan(first.pages.count, 1)
        XCTAssertEqual(first.pages.first?.scalars.lowerBound, 0)
        XCTAssertEqual(first.pages.last?.scalars.upperBound, coordinates.scalarCount)
        XCTAssertTrue(zip(first.pages, first.pages.dropFirst()).allSatisfy { $0.0.scalars.upperBound == $0.1.scalars.lowerBound })
        XCTAssertEqual(before.scalar, anchor)
        let selected = try await native.select(start: 2, end: 9)
        XCTAssertEqual(selected?.text, "𠀀😀Cafe\u{301}")
        XCTAssertEqual(selected?.startScalar, 2)
        XCTAssertEqual(selected?.endScalar, 9)
        let readSelection = try await native.selection()
        XCTAssertEqual(readSelection?.text, selected?.text)
        native.prepare(preferences: .init(fontSize: 23, lineSpacing: 1.6, letterSpacing: 0.5),
                       viewport: CGSize(width: 290, height: 470))
        let narrow = try XCTUnwrap(native.layout)
        XCTAssertGreaterThan(narrow.pages.count, first.pages.count)
        let narrowValue = try await native.position()
        XCTAssertEqual(narrowValue?.scalar, anchor)
        native.prepare(preferences: .init(fontSize: 23, lineSpacing: 1.6, letterSpacing: 0.5, mode: .scroll),
                       viewport: CGSize(width: 675, height: 540))
        let wide = try XCTUnwrap(native.layout)
        let wideValue = try await native.position()
        XCTAssertEqual(wideValue?.scalar, anchor)
        XCTAssertLessThan(wide.pages.count, narrow.pages.count)
        let wideSelection = try await native.selection()
        XCTAssertEqual(wideSelection?.text, "𠀀😀Cafe\u{301}")
        XCTAssertEqual(GestureArbiter().drag(start: CGPoint(x: 5, y: 20),
            translation: CGSize(width: 200, height: 0), width: 340, mode: .pages), .systemBack)
        print("M1_CORETEXT scalar=\(anchor) utf16=\(coordinates.utf16(at: anchor) ?? -1) selection=2..<9 nativePages=\(first.pages.count)/\(narrow.pages.count)/\(wide.pages.count) width=340/290/675 size=18/23/23")
    }
}
