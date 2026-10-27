import XCTest
import Combine
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

@MainActor
final class ReaderControlMotionDriverTests: XCTestCase {
    @MainActor
    private final class TestClock {
        var time: TimeInterval = 0
        func advance(_ driver: ReaderControlMotionDriver, to time: TimeInterval) {
            self.time = time
            driver.advance(to: time)
        }
    }

    private func makeDriver() -> (ReaderControlMotionDriver, TestClock) {
        let time = TestClock()
        let driver = ReaderControlMotionDriver(now: { time.time }, automaticallyTicks: false)
        driver.configure(quickHeight: 330, fullHeight: 630)
        return (driver, time)
    }

    func testAutomaticMorphUsesTheSingleSmoothstepSample() async {
        let (driver, time) = makeDriver()
        driver.move(to: .quick, reduceMotion: true)
        driver.move(to: .full)
        XCTAssertEqual(driver.currentDuration, 0.32, accuracy: 1e-9)
        time.advance(driver, to: 0.08)
        XCTAssertEqual(driver.expansion, 0.15625, accuracy: 1e-9)
        XCTAssertEqual(driver.visibility, 1)
        XCTAssertEqual(driver.dockHeight, 330 + 300 * 0.15625, accuracy: 1e-9)
        XCTAssertEqual(driver.spatialY, -driver.dockHeight, accuracy: 1e-9)
        time.advance(driver, to: 0.32)
        XCTAssertEqual(driver.expansion, 1)
        XCTAssertFalse(driver.isAnimating)
    }

    func testDismissFadesCapturedFullCompositionAndUnmountsOnlyAtEndpoint() async {
        let (driver, time) = makeDriver()
        driver.move(to: .full, reduceMotion: true)
        driver.move(to: .hidden)
        time.advance(driver, to: 0.1)
        XCTAssertTrue(driver.isPresented)
        XCTAssertEqual(driver.expansion, 1)
        XCTAssertEqual(driver.dockHeight, 630)
        XCTAssertEqual(driver.visibility, 0.5, accuracy: 1e-9)
        XCTAssertEqual(driver.offsetY, 9, accuracy: 1e-9)
        XCTAssertEqual(driver.spatialY, -621, accuracy: 1e-9)
        time.advance(driver, to: 0.2)
        XCTAssertFalse(driver.isPresented)
        XCTAssertEqual(driver.visibility, 0)
    }

    func testDirectDragFollowsPhysicalPointsAndFullCollapsesBeforeItCanDismiss() async {
        let (driver, _) = makeDriver()
        driver.move(to: .full, reduceMotion: true)
        driver.dragChanged(translationY: 0, time: 0)
        driver.dragChanged(translationY: 60, time: 0.1)
        XCTAssertEqual(driver.expansion, 0.8, accuracy: 1e-9)
        XCTAssertEqual(driver.spatialY, -570, accuracy: 1e-9)
        XCTAssertEqual(driver.visibility, 1)
        driver.dragEnded(translationY: 60, time: 0.1)
        XCTAssertEqual(driver.target, .quick)
        XCTAssertNotNil(driver.continuationSlope)
        driver.stop()

        let (crossing, _) = makeDriver()
        crossing.move(to: .full, reduceMotion: true)
        crossing.dragChanged(translationY: 0, time: 0)
        crossing.dragChanged(translationY: 310, time: 0.2)
        XCTAssertEqual(crossing.expansion, 0)
        XCTAssertEqual(crossing.visibility, 1 - 10.0 / 18, accuracy: 1e-9)
        XCTAssertTrue(crossing.isPresented)
        crossing.dragEnded(translationY: 310, time: 0.2, reduceMotion: true)
        XCTAssertEqual(crossing.target, .hidden)
        XCTAssertFalse(crossing.isPresented)
    }

    func testQuickDragUsesEighteenPointClosePathAndHoldsHiddenUntilRelease() async {
        let (driver, _) = makeDriver()
        driver.move(to: .quick, reduceMotion: true)
        driver.dragChanged(translationY: 0, time: 0)
        driver.dragChanged(translationY: 9, time: 0.1)
        XCTAssertEqual(driver.visibility, 0.5, accuracy: 1e-9)
        XCTAssertEqual(driver.spatialY, -321, accuracy: 1e-9)
        driver.dragChanged(translationY: 18, time: 0.2)
        XCTAssertTrue(driver.isPresented)
        XCTAssertEqual(driver.visibility, 0)
        driver.dragEnded(translationY: 18, time: 0.2)
        XCTAssertFalse(driver.isPresented)
    }

    func testLatestEightPointDirectionChoosesTargetWhileSpeedOnlyChangesDuration() async {
        let (reversed, _) = makeDriver()
        reversed.move(to: .quick, reduceMotion: true)
        reversed.dragChanged(translationY: 0, time: 0)
        reversed.dragChanged(translationY: -180, time: 0.2)
        reversed.dragChanged(translationY: -160, time: 0.21)
        reversed.dragEnded(translationY: -160, time: 0.21)
        XCTAssertEqual(reversed.target, .quick) // net travel remains upward
        reversed.stop()

        let (subSlop, _) = makeDriver()
        subSlop.move(to: .quick, reduceMotion: true)
        subSlop.dragChanged(translationY: 0, time: 0)
        subSlop.dragChanged(translationY: -180, time: 0.2)
        subSlop.dragChanged(translationY: -172, time: 0.21)
        subSlop.dragEnded(translationY: -172, time: 0.21)
        XCTAssertEqual(subSlop.target, .full) // exactly eight is not > eight
        subSlop.stop()

        let (fast, _) = makeDriver()
        let (slow, _) = makeDriver()
        for driver in [fast, slow] { driver.move(to: .quick, reduceMotion: true); driver.dragChanged(translationY: 0, time: 0) }
        fast.dragChanged(translationY: -120, time: 0.1)
        fast.dragEnded(translationY: -120, time: 0.1)
        slow.dragChanged(translationY: -120, time: 0.5)
        slow.dragEnded(translationY: -120, time: 0.5)
        XCTAssertEqual(fast.target, .full)
        XCTAssertEqual(slow.target, .full)
        XCTAssertLessThan(fast.currentDuration, slow.currentDuration)
        fast.stop(); slow.stop()
    }

    func testOverscrollResidueMustBeConsumedBeforeReverseMotion() async {
        let (driver, _) = makeDriver()
        driver.move(to: .quick, reduceMotion: true)
        driver.dragChanged(translationY: 0, time: 0)
        driver.dragChanged(translationY: -330, time: 0.2)
        XCTAssertEqual(driver.expansion, 1)
        driver.dragChanged(translationY: -320, time: 0.3)
        XCTAssertEqual(driver.expansion, 1)
        driver.dragChanged(translationY: -290, time: 0.4)
        XCTAssertEqual(driver.expansion, 1 - 10.0 / 300, accuracy: 1e-9)
        driver.cancelDrag(reduceMotion: true)
        XCTAssertEqual(driver.target, .quick)
    }

    func testFrozenFiveHundredMillisecondTapBoundaryAndHomeCannotExpand() async {
        // Frozen ReaderControlPanel passes 500ms, not a generic 250ms tap.
        let (tap, _) = makeDriver()
        tap.move(to: .quick, reduceMotion: true)
        tap.dragChanged(translationY: 0, time: 0)
        tap.dragEnded(translationY: 0, time: 0.3, reduceMotion: true)
        XCTAssertEqual(tap.target, .full)

        let (hold, _) = makeDriver()
        hold.move(to: .quick, reduceMotion: true)
        hold.dragChanged(translationY: 0, time: 0)
        hold.dragEnded(translationY: 0, time: 0.5, reduceMotion: true)
        XCTAssertEqual(hold.target, .quick)

        let (home, _) = makeDriver()
        home.configure(quickHeight: 330, fullHeight: 630, allowsExpansion: false)
        home.move(to: .full, reduceMotion: true) // delayed command from a departed module
        XCTAssertEqual(home.target, .quick)
        home.dragChanged(translationY: 0, time: 0)
        home.dragChanged(translationY: -100, time: 0.1)
        XCTAssertEqual(home.expansion, 0)
        XCTAssertEqual(home.spatialY, -330)
        home.dragEnded(translationY: -100, time: 0.1, reduceMotion: true)
        XCTAssertEqual(home.target, .quick)
        home.dragChanged(translationY: 0, time: 1)
        home.dragEnded(translationY: 0, time: 1.3, reduceMotion: true)
        XCTAssertEqual(home.target, .quick)
        home.dragChanged(translationY: 0, time: 2)
        home.dragChanged(translationY: 18, time: 2.1)
        home.dragEnded(translationY: 18, time: 2.1, reduceMotion: true)
        XCTAssertFalse(home.isPresented)
    }

    func testRegrabUsesActualClockSampleAndCancelRestoresPreHoldGoal() async {
        let (driver, time) = makeDriver()
        driver.move(to: .quick, reduceMotion: true)
        driver.move(to: .full)
        time.advance(driver, to: 0.16)
        let sampledY = driver.spatialY
        driver.dragChanged(translationY: 0, time: 100)
        XCTAssertEqual(driver.spatialY, sampledY)
        driver.dragChanged(translationY: 15, time: 100.1)
        XCTAssertEqual(driver.spatialY, sampledY + 15, accuracy: 1e-9)
        let heldY = driver.spatialY
        driver.cancelDrag()
        XCTAssertEqual(driver.spatialY, heldY)
        XCTAssertEqual(driver.target, .full)
        time.advance(driver, to: 0.5)
        XCTAssertEqual(driver.expansion, 1)
    }

    func testStationaryPauseResumesOriginalEasingPhaseAndReleasePauseDecaysVelocity() async {
        let (driver, time) = makeDriver()
        driver.move(to: .quick, reduceMotion: true)
        driver.move(to: .full)
        time.advance(driver, to: 0.08)
        driver.dragChanged(translationY: 0, time: 0)
        time.advance(driver, to: 10)
        XCTAssertEqual(driver.expansion, 0.15625, accuracy: 1e-9)
        driver.cancelDrag()
        time.advance(driver, to: 10.08)
        XCTAssertEqual(driver.expansion, 0.5, accuracy: 1e-9)
        driver.stop()

        let (released, releaseClock) = makeDriver()
        released.move(to: .quick, reduceMotion: true)
        released.dragChanged(translationY: 0, time: 0)
        released.dragChanged(translationY: -120, time: 0.1)
        released.dragEnded(translationY: -120, time: 1.1)
        let startY = released.spatialY
        releaseClock.advance(released, to: 0.000001)
        let initialVelocity = (released.spatialY - startY) / 0.000001
        XCTAssertEqual(initialVelocity, -1200 * 0.1 / 1.1, accuracy: 0.1)
        released.stop()
    }

    func testLayoutRebasePreservesGrabberAndReduceMotionAndStopRevokeClock() async {
        let (driver, time) = makeDriver()
        driver.move(to: .quick, reduceMotion: true)
        driver.move(to: .full)
        time.advance(driver, to: 0.16)
        let before = driver.spatialY
        driver.configure(quickHeight: 350, fullHeight: 700)
        XCTAssertEqual(driver.spatialY, before, accuracy: 1e-9)
        XCTAssertTrue(driver.isAnimating, "Default geometry compensation retains the existing clock")
        time.advance(driver, to: 0.5)
        XCTAssertEqual(driver.spatialY, -700, accuracy: 1e-9)
        XCTAssertEqual(driver.offsetY, 0, accuracy: 1e-9)
        driver.move(to: .hidden, reduceMotion: true)
        XCTAssertFalse(driver.isPresented)
        XCTAssertFalse(driver.isAnimating)
        driver.move(to: .quick, reduceMotion: true)
        driver.move(to: .full)
        time.advance(driver, to: 0.58)
        driver.stop()
        let stopped = driver.sample
        time.advance(driver, to: 20)
        XCTAssertEqual(driver.sample, stopped)
        XCTAssertFalse(driver.isDragging)
        XCTAssertFalse(driver.isAnimating)

        for reduceMotion in [true, false] {
            let (configured, clock) = makeDriver()
            configured.move(to: .quick, reduceMotion: true)
            XCTAssertFalse(configured.isAnimating)
            let originalY = configured.spatialY
            configured.configure(quickHeight: 350, fullHeight: 700, reduceMotion: reduceMotion)
            XCTAssertEqual(configured.target, .quick)
            XCTAssertEqual(configured.expansion, 0, accuracy: 1e-9)
            XCTAssertFalse(configured.isDragging)
            XCTAssertEqual(configured.isAnimating, !reduceMotion)
            XCTAssertEqual(configured.spatialY, reduceMotion ? -350 : originalY, accuracy: 1e-9,
                           "Reduce Motion settles the new geometry; default motion preserves the starting sample")
            let settled = configured.sample
            clock.advance(configured, to: 10)
            XCTAssertEqual(configured.spatialY, -350, accuracy: 1e-9)
            XCTAssertEqual(configured.offsetY, 0, accuracy: 1e-9)
            XCTAssertFalse(configured.isAnimating)
            if reduceMotion { XCTAssertEqual(configured.sample, settled, "No automatic clock may change the settled reduced-motion sample") }

            configured.move(to: .full, reduceMotion: true)
            configured.configure(quickHeight: 360, fullHeight: 720, reduceMotion: true)
            XCTAssertEqual(configured.spatialY, -720, accuracy: 1e-9)
            XCTAssertEqual(configured.expansion, 1, accuracy: 1e-9)
            XCTAssertFalse(configured.isAnimating)
        }

        for reduceMotion in [true, false] {
            let (held, _) = makeDriver()
            held.move(to: .quick, reduceMotion: true)
            held.dragChanged(translationY: -80, time: 0)
            held.dragChanged(translationY: -120, time: 0.1)
            let fingerY = held.spatialY
            held.configure(quickHeight: 350, fullHeight: 700, reduceMotion: reduceMotion)
            XCTAssertTrue(held.isDragging)
            XCTAssertFalse(held.isAnimating)
            XCTAssertEqual(held.spatialY, fingerY, accuracy: 1e-9, "A held pointer must retain its actual sample across geometry changes")
            held.dragChanged(translationY: -130, time: 0.2)
            XCTAssertEqual(held.spatialY, fingerY - 10, accuracy: 1e-9, "Rebased geometry still follows the next exact finger displacement")
            XCTAssertTrue(held.isDragging)
            XCTAssertFalse(held.isAnimating)
            held.cancelDrag(reduceMotion: true)
            XCTAssertFalse(held.isDragging)
            XCTAssertFalse(held.isAnimating)
        }
    }

    func testTeardownStopDoesNotPublishOrAdvanceAndRevokesTheClock() async {
        let (driver, time) = makeDriver()
        driver.move(to: .quick, reduceMotion: true)
        driver.move(to: .full)
        time.advance(driver, to: 0.08)
        let lastPublished = driver.sample
        var publications: [ReaderControlMotionDriver.Sample] = []
        let observation = driver.$sample.dropFirst().sink { publications.append($0) }
        defer { observation.cancel() }

        // Time moved since the final display tick. Teardown may not sample it:
        // that would publish synchronously during SwiftUI's removal pass.
        time.time = 0.16
        XCTAssertTrue(driver.isAnimating)
        driver.stop(publishingFinalSample: false)
        XCTAssertTrue(publications.isEmpty)
        XCTAssertEqual(driver.sample, lastPublished)
        XCTAssertFalse(driver.isAnimating)
        XCTAssertFalse(driver.isDragging)

        time.advance(driver, to: 20)
        XCTAssertTrue(publications.isEmpty)
        XCTAssertEqual(driver.sample, lastPublished)
    }
}
