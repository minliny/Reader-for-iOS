import ReaderDesign
import SwiftUI
import XCTest

@MainActor
final class DesignContractTests: XCTestCase {
    func testPinnedFontsAndEightReadingPapers() throws {
        XCTAssertTrue(ReaderTypography.nativeFont(ReaderDesignMetrics.shelfTitle).fontName.hasPrefix("NotoSansSC"))
        XCTAssertTrue(ReaderTypography.nativeFont(ReaderDesignMetrics.rowLabel).fontName.hasPrefix("NotoSansSC"))
        XCTAssertTrue(ReaderTypography.nativeFont(ReaderDesignMetrics.readerBody).fontName.hasPrefix("NotoSerifSC"))
        XCTAssertEqual(ReaderPaper.all.count, 8)
        XCTAssertEqual(Set(ReaderPaper.all.map(\.id)).count, 8)
        let lightPaper = ReaderPaper(id: "day")
        XCTAssertFalse(lightPaper.isDark)
        XCTAssertEqual(lightPaper.webBackground, "#F7F3EA")
        XCTAssertEqual(lightPaper.statusForegroundARGB, 0xFF2B241D)

        let frameworkURL = try XCTUnwrap(Bundle.main.privateFrameworksURL).appendingPathComponent("ReaderDesign.framework")
        let bundle = try XCTUnwrap(Bundle(url: frameworkURL))
        for (name, size) in [("reader_control_header_chevron", 12.0), ("settings_gen_navigation", 48.0)] {
            let image = try XCTUnwrap(UIImage(named: name, in: bundle, compatibleWith: nil))
            XCTAssertEqual(image.size.width, size)
            XCTAssertEqual(image.renderingMode, .alwaysTemplate)
        }
    }

    func testToastDeduplicatesWithinItsHostAndRejectsBackground() async throws {
        let front = ReaderToastPresenter()
        let another = ReaderToastPresenter()
        XCTAssertTrue(front.show(message: "已完成", key: "finish", feedbackEnabled: true, sceneActive: true))
        XCTAssertFalse(front.show(message: "重复", key: "finish", feedbackEnabled: true, sceneActive: true))
        XCTAssertEqual(front.message, "已完成")
        XCTAssertFalse(front.show(message: "页面已退场", key: "other", feedbackEnabled: false, sceneActive: true))
        XCTAssertNil(front.message)
        XCTAssertTrue(another.show(message: "另一个宿主", key: "finish", feedbackEnabled: true, sceneActive: true))
        XCTAssertFalse(another.show(message: "应用后台", key: "other", feedbackEnabled: true, sceneActive: false))
        XCTAssertNil(another.message)
        try await Task.sleep(for: .milliseconds(ReaderDesignMetrics.shortFeedbackMillis + 25))
        XCTAssertTrue(front.show(message: "窗口已结束", key: "finish", feedbackEnabled: true, sceneActive: true))
        front.dismiss()
    }
}
