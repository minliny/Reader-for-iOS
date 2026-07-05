import SwiftUI
import XCTest
@testable import ReaderApp
import ReaderUIContract

@MainActor
final class ReaderContractAdapterSlice0Tests: XCTestCase {
    func testReaderUIPackageGeneratedTypesAreReachable() {
        XCTAssertEqual(RouteId.bookshelf.rawValue, "bookshelf")
        XCTAssertEqual(MainTab.allCases.map(\.rawValue), ["bookshelf", "discover", "rss", "settings"])
        XCTAssertEqual(UiEventType.mainTab_select.rawValue, "mainTab.select")
    }

    func testTokenAdapterMapsSliceOneSemanticTokens() throws {
        let decoder = JSONDecoder()
        let paper = try decoder.decode(ReaderUIContract.Token.self, from: Data("""
        {"name":"--reader-ds-color-paper","category":"color","value":"#fff8f4"}
        """.utf8))
        let navHeight = try decoder.decode(ReaderUIContract.Token.self, from: Data("""
        {"name":"--reader-ds-size-main-nav-height","category":"size","value":"68px"}
        """.utf8))

        XCTAssertNotNil(ReaderTokenAdapter.color(for: paper, colorScheme: .light))
        XCTAssertNotNil(ReaderTokenAdapter.color(for: paper, colorScheme: .dark))
        XCTAssertEqual(ReaderTokenAdapter.length(for: navHeight), ReaderDesignTokens.mainNavHeight)
    }

    func testTokenAdapterReadsGeneratedTokenRegistry() throws {
        let paper = try XCTUnwrap(ReaderTokenAdapter.token(named: "--reader-ds-color-paper"))
        XCTAssertEqual(paper, ReaderUIContract.TokenRegistry.token(named: "--reader-ds-color-paper"))
        XCTAssertEqual(paper.category, .color)
        XCTAssertNotNil(ReaderTokenAdapter.color(for: paper, colorScheme: .light))

        let tabSwitch = try XCTUnwrap(ReaderTokenAdapter.token(named: "--reader-ds-motion-duration-tabSwitch"))
        XCTAssertEqual(tabSwitch.category, .motionDuration)
        let tabSwitchDuration = try XCTUnwrap(
            ReaderTokenAdapter.duration(for: tabSwitch, motion: MotionEnvironment(override: false))
        )
        XCTAssertEqual(
            tabSwitchDuration,
            0.16,
            accuracy: 0.0001
        )
    }

    func testMotionAdapterMapsP0TabAndReducedMotion() {
        let normalMotion = MotionEnvironment(override: false)
        let reducedMotion = MotionEnvironment(override: true)

        XCTAssertEqual(
            ReaderMotionAdapter.localMotionId(for: ReaderUIContract.MotionId.tab_switch)?.rawValue,
            "tab.item.switch"
        )
        XCTAssertEqual(
            ReaderMotionAdapter.duration(for: .tab_switch, motion: normalMotion),
            AppMotion.Duration.tabSwitch,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ReaderMotionAdapter.duration(for: .tab_switch, motion: reducedMotion),
            ReaderMotion.Duration.instant,
            accuracy: 0.0001
        )
    }

    func testMotionAdapterReadsGeneratedMotionSpecRegistry() throws {
        let spec = try XCTUnwrap(ReaderMotionAdapter.spec(for: .tab_switch))
        XCTAssertEqual(spec, ReaderUIContract.MotionSpecRegistry.spec(for: .tab_switch))
        XCTAssertEqual(spec.durationMs, 160)
        XCTAssertEqual(spec.tokens?.durationToken, "app.motion.duration.tabSwitch")
        XCTAssertTrue(spec.guardRules?.contains("layoutStable:indicatorDoesNotPushLayout") == true)

        XCTAssertEqual(
            ReaderMotionAdapter.duration(for: .tab_switch, motion: MotionEnvironment(override: false)),
            TimeInterval(spec.durationMs) / 1000,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            ReaderMotionAdapter.duration(for: .tab_switch, motion: MotionEnvironment(override: true)),
            ReaderMotion.Duration.instant,
            accuracy: 0.0001
        )
    }
}
