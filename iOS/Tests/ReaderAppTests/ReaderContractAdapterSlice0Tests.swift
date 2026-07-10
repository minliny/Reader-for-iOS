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
        {"name":"--fd-ds-color-paper","category":"color","value":"#fff8f4"}
        """.utf8))
        let navHeight = try decoder.decode(ReaderUIContract.Token.self, from: Data("""
        {"name":"--fd-ds-size-main-nav-height","category":"size","value":"68px"}
        """.utf8))

        XCTAssertNotNil(ReaderTokenAdapter.color(for: paper, colorScheme: .light))
        XCTAssertNotNil(ReaderTokenAdapter.color(for: paper, colorScheme: .dark))
        XCTAssertEqual(ReaderTokenAdapter.length(for: navHeight), ReaderDesignTokens.mainNavHeight)
    }

    func testTokenAdapterReadsGeneratedTokenRegistry() throws {
        let paper = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-color-paper"))
        XCTAssertEqual(paper, ReaderUIContract.TokenRegistry.token(named: "--fd-ds-color-paper"))
        XCTAssertEqual(paper.category, .color)
        XCTAssertNotNil(ReaderTokenAdapter.color(for: paper, colorScheme: .light))

        let tabSwitch = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-motion-duration-tabSwitch"))
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

    // MARK: - Token category coverage (Task 5)

    func testTokenAdapterMapsSpacingTokens() throws {
        // spacing category — `--fd-ds-space-md` (16px) 走默认分支返回 16
        let spaceMd = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-space-md"))
        XCTAssertEqual(spaceMd.category, .spacing)
        XCTAssertEqual(ReaderTokenAdapter.length(for: spaceMd), 16)
        XCTAssertEqual(ReaderTokenAdapter.length(named: "--fd-ds-space-md"), 16)

        // `--fd-ds-space-screen-padding` 走显式分支，映射到 demoContentHorizontalPadding
        let screenPadding = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-space-screen-padding"))
        XCTAssertEqual(screenPadding.category, .spacing)
        XCTAssertEqual(
            ReaderTokenAdapter.length(for: screenPadding),
            ReaderDesignTokens.demoContentHorizontalPadding
        )
    }

    func testTokenAdapterMapsRadiusTokens() throws {
        // `--fd-ds-radius-card` (4px) → ReaderDesignTokens.bookCoverFrameCornerRadius
        let radiusCard = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-radius-card"))
        XCTAssertEqual(radiusCard.category, .radius)
        XCTAssertEqual(
            ReaderTokenAdapter.length(for: radiusCard),
            ReaderDesignTokens.bookCoverFrameCornerRadius
        )

        // `--fd-ds-radius-control` (999px) → ReaderDesignTokens.mainNavCornerRadius
        let radiusControl = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-radius-control"))
        XCTAssertEqual(radiusControl.category, .radius)
        XCTAssertEqual(
            ReaderTokenAdapter.length(named: "--fd-ds-radius-control"),
            ReaderDesignTokens.mainNavCornerRadius
        )
    }

    func testTokenAdapterMapsZIndexTokens() throws {
        // `--fd-ds-z-overlay` (10) → .overlay
        let zOverlay = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-z-overlay"))
        XCTAssertEqual(zOverlay.category, .zIndex)
        XCTAssertEqual(ReaderTokenAdapter.zIndex(for: zOverlay), .overlay)
        XCTAssertEqual(ReaderTokenAdapter.zIndex(named: "--fd-ds-z-overlay"), .overlay)
        XCTAssertEqual(ReaderTokenAdapter.zIndexValue(for: zOverlay), 10.0)

        // `--fd-ds-z-flow-window` (36) → .flowWindow
        let zFlow = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-z-flow-window"))
        XCTAssertEqual(ReaderTokenAdapter.zIndex(for: zFlow), .flowWindow)
        XCTAssertEqual(ReaderTokenAdapter.zIndexValue(for: zFlow), 36.0)

        // 非 zIndex category 的 token 应返回 nil
        let nonZ = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-color-paper"))
        XCTAssertNil(ReaderTokenAdapter.zIndex(for: nonZ))
    }

    func testTokenAdapterMapsTextConstraintTokens() throws {
        // `--fd-ds-text-reader-line-length` (31ch) → 31
        let lineLength = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-text-reader-line-length"))
        XCTAssertEqual(lineLength.category, .textConstraint)
        XCTAssertEqual(ReaderTokenAdapter.textConstraint(for: lineLength), 31)
        XCTAssertEqual(ReaderTokenAdapter.textConstraint(named: "--fd-ds-text-reader-line-length"), 31)

        // 通过 length API 也能取到 31（textConstraint 也支持 length）
        XCTAssertEqual(ReaderTokenAdapter.length(for: lineLength), 31)

        // 非 textConstraint category 的 token 应返回 nil
        let nonTc = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-space-md"))
        XCTAssertNil(ReaderTokenAdapter.textConstraint(for: nonTc))
    }

    func testTokenAdapterMapsFontTokens() throws {
        // `--fd-ds-font-sans` → Font.system(size:design:.default)
        let sans = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-font-sans"))
        XCTAssertEqual(sans.category, .font)
        XCTAssertNotNil(ReaderTokenAdapter.font(for: sans, size: 16))
        XCTAssertNotNil(ReaderTokenAdapter.font(named: "--fd-ds-font-sans", size: 16))

        // `--fd-ds-font-serif` → Font.custom("STSongti-SC-Regular", size:)
        let serif = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-font-serif"))
        XCTAssertEqual(serif.category, .font)
        XCTAssertNotNil(ReaderTokenAdapter.font(for: serif, size: 18))
        XCTAssertNotNil(ReaderTokenAdapter.font(named: "--fd-ds-font-serif", size: 18))

        // mono / kai / fangsong 也应可解析
        for name in ["--fd-ds-font-mono", "--fd-ds-font-kai", "--fd-ds-font-fangsong"] {
            XCTAssertNotNil(ReaderTokenAdapter.font(named: name, size: 14), "font \(name) 应可解析")
        }

        // 非 font category 的 token 应返回 nil
        let nonFont = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-space-md"))
        XCTAssertNil(ReaderTokenAdapter.font(for: nonFont, size: 14))
    }

    func testTokenAdapterMapsIconTokens() throws {
        // `--fd-ds-icon-chevron` (value: "chevron")
        let chevron = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-icon-chevron"))
        XCTAssertEqual(chevron.category, .icon)
        XCTAssertEqual(chevron.value, "chevron")

        // token.value 与 ReaderAssetIcon.rawValue 对齐，assetName == "reader-icon-chevron"
        let icon = ReaderAssetIcon(rawValue: chevron.value)
        XCTAssertEqual(icon.assetName, "reader-icon-chevron")
        XCTAssertEqual(ReaderAssetIcon.chevron.assetName, "reader-icon-chevron")

        // platforms.swift 字段应包含 `Image("reader-icon-chevron")`
        let swiftPlatform = try XCTUnwrap(chevron.platforms?.swift)
        XCTAssertTrue(swiftPlatform.contains("reader-icon-chevron"), "platforms.swift 应包含 reader-icon-chevron")

        // 再验证一个图标 token（search）保证不是巧合
        let search = try XCTUnwrap(ReaderTokenAdapter.token(named: "--fd-ds-icon-search"))
        XCTAssertEqual(search.category, .icon)
        XCTAssertEqual(search.value, "search")
        XCTAssertEqual(ReaderAssetIcon(rawValue: search.value).assetName, "reader-icon-search")
        XCTAssertEqual(ReaderAssetIcon.search.assetName, "reader-icon-search")
    }

}
