import XCTest
@testable import ReaderApp

/// Motion token 对齐验证 —— 确保 `AppMotion` / `ReaderMotion` / `MotionEnvironment`
/// 的数值与 `Reader UI/frontend-demo/MOTION_CONTRACT.md` §3 Motion Tokens 一致。
///
/// 真源：
/// - `frontend-demo/MOTION_CONTRACT.md` §3 Motion Tokens
/// - `docs/ui-handoff/MOTION_PLATFORM_MAPPING.md` §1 共享 Token 命名
///
/// 任何 token 数值漂移都会导致 iOS 动效与契约不一致，因此用单测锁定。
final class MotionTokenAlignmentTests: XCTestCase {

    // MARK: - AppMotion.Duration（app.motion.duration.*）

    func testAppMotionDurationFirstOpen() {
        XCTAssertEqual(AppMotion.Duration.firstOpen, 0.28)
    }

    func testAppMotionDurationTabPress() {
        XCTAssertEqual(AppMotion.Duration.tabPress, 0.08)
    }

    func testAppMotionDurationTabSelect() {
        XCTAssertEqual(AppMotion.Duration.tabSelect, 0.12)
    }

    func testAppMotionDurationTabSwitch() {
        XCTAssertEqual(AppMotion.Duration.tabSwitch, 0.16)
    }

    func testAppMotionDurationButtonPress() {
        XCTAssertEqual(AppMotion.Duration.buttonPress, 0.08)
    }

    func testAppMotionDurationButtonActivate() {
        XCTAssertEqual(AppMotion.Duration.buttonActivate, 0.12)
    }

    func testAppMotionDurationToggleSwitch() {
        XCTAssertEqual(AppMotion.Duration.toggleSwitch, 0.14)
    }

    func testAppMotionDurationFeedbackToast() {
        XCTAssertEqual(AppMotion.Duration.feedbackToast, 0.18)
    }

    func testAppMotionDurationDropdownExpand() {
        XCTAssertEqual(AppMotion.Duration.dropdownExpand, 0.16)
    }

    // MARK: - AppMotion.Distance / Scale

    func testAppMotionDistanceDropdownY() {
        XCTAssertEqual(AppMotion.Distance.dropdownY, 6)
    }

    func testAppMotionDistanceFeedbackY() {
        XCTAssertEqual(AppMotion.Distance.feedbackY, 8)
    }

    func testAppMotionScalePressMin() {
        XCTAssertEqual(AppMotion.Scale.pressMin, 0.98)
    }

    // MARK: - ReaderMotion.Duration（reader.motion.duration.*）

    func testReaderMotionDurationInstant() {
        XCTAssertEqual(ReaderMotion.Duration.instant, 0)
    }

    func testReaderMotionDurationMicro() {
        XCTAssertEqual(ReaderMotion.Duration.micro, 0.08)
    }

    func testReaderMotionDurationFast() {
        XCTAssertEqual(ReaderMotion.Duration.fast, 0.12)
    }

    func testReaderMotionDurationBase() {
        XCTAssertEqual(ReaderMotion.Duration.base, 0.16)
    }

    func testReaderMotionDurationPageTurn() {
        XCTAssertEqual(ReaderMotion.Duration.pageTurn, 0.22)
    }

    func testReaderMotionDurationReaderEntry() {
        XCTAssertEqual(ReaderMotion.Duration.readerEntry, 0.24)
    }

    func testReaderMotionDurationSessionReturn() {
        XCTAssertEqual(ReaderMotion.Duration.sessionReturn, 0.20)
    }

    func testReaderMotionDurationPanel() {
        XCTAssertEqual(ReaderMotion.Duration.panel, 0.20)
    }

    func testReaderMotionDurationOverlay() {
        XCTAssertEqual(ReaderMotion.Duration.overlay, 0.24)
    }

    func testReaderMotionDurationInterruptSettle() {
        XCTAssertEqual(ReaderMotion.Duration.interruptSettle, 0.08)
    }

    func testReaderMotionDurationVoicePulse() {
        XCTAssertEqual(ReaderMotion.Duration.voicePulse, 0.96)
    }

    func testReaderMotionDurationLoadingSpin() {
        XCTAssertEqual(ReaderMotion.Duration.loadingSpin, 0.80)
    }

    // MARK: - ReaderMotion.Distance / Scale

    func testReaderMotionDistancePageTurnX() {
        XCTAssertEqual(ReaderMotion.Distance.pageTurnX, 16)
    }

    func testReaderMotionDistanceReaderEntryY() {
        XCTAssertEqual(ReaderMotion.Distance.readerEntryY, 12)
    }

    func testReaderMotionScaleCoverPress() {
        XCTAssertEqual(ReaderMotion.Scale.coverPress, 0.98)
    }

    func testReaderMotionScaleVoicePulseMax() {
        XCTAssertEqual(ReaderMotion.Scale.voicePulseMax, 1.06)
    }

    // MARK: - MotionEnvironment reduced-motion 规则

    func testMotionEnvironmentNormalDurationReturnsOriginal() {
        let env = MotionEnvironment(override: false)
        XCTAssertEqual(env.duration(0.24), 0.24)
    }

    func testMotionEnvironmentReducedDurationCappedToMicro() {
        let env = MotionEnvironment(override: true)
        XCTAssertEqual(env.duration(0.24), 0.08, accuracy: 0.001,
                       "reduced motion 下时长应降为 micro(80ms) 上限")
    }

    func testMotionEnvironmentReducedDurationZeroStaysZero() {
        let env = MotionEnvironment(override: true)
        XCTAssertEqual(env.duration(0), 0)
    }

    func testMotionEnvironmentNormalDistanceReturnsOriginal() {
        let env = MotionEnvironment(override: false)
        XCTAssertEqual(env.distance(16), 16)
    }

    func testMotionEnvironmentReducedDistanceIsZero() {
        let env = MotionEnvironment(override: true)
        XCTAssertEqual(env.distance(16), 0, "reduced motion 下位移应降为 0")
    }

    func testMotionEnvironmentNormalAnimationReturnsEaseInOut() {
        let env = MotionEnvironment(override: false)
        let animation = env.animation(0.24)
        XCTAssertNotNil(animation)
    }

    func testMotionEnvironmentReducedAnimationReturnsNil() {
        // 契约：reduced motion 下 instant(0) 返回 nil，即即时切换
        let env = MotionEnvironment(override: true)
        XCTAssertNil(env.animation(0),
                     "reduced motion + 0 时长应返回 nil（即时切换）")
    }

    func testMotionEnvironmentReducedAnimationForLongerDurationReturnsMicro() {
        // 契约：reduced motion 下最多 80ms（micro），仍可返回动画
        let env = MotionEnvironment(override: true)
        let animation = env.animation(0.24)
        XCTAssertNotNil(animation, "reduced motion 下 0.24 应降为 0.08 仍返回动画")
    }
}
