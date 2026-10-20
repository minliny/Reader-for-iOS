import SwiftUI
import QuartzCore

/// Native clock for the local-reading subset of frozen Host 33f7c7b2's
/// SessionState / GestureDriver / SpatialPath / MotionPolicy / Runtime.
/// It owns presentation only. Every actor is rendered from this one sample;
/// callers must not add a second SwiftUI animation to its output.
@MainActor
final class ReaderControlMotionDriver: ObservableObject {
    enum Position: String, Equatable { case hidden, quick, full }

    struct Sample: Equatable {
        var visibility: CGFloat = 0
        var expansion: CGFloat = 0
        var compensationY: CGFloat = 0
        var isPresented = false
        var target: Position = .hidden
    }

    /// One publication prevents observers seeing mismatched expansion/visibility.
    @Published private(set) var sample = Sample()
    var visibility: CGFloat { sample.visibility }
    var expansion: CGFloat { sample.expansion }
    var isPresented: Bool { sample.isPresented }
    var target: Position { sample.target }
    var isDragging: Bool { drag != nil }
    var isAnimating: Bool { clock != nil }
    var dockHeight: CGFloat { quickHeight + (fullHeight - quickHeight) * expansion }
    /// MR1 moves the captured whole composition 18pt while fading. Hidden is
    /// not a shared offscreen Y; a closing Full dock retains its composition.
    var offsetY: CGFloat { Self.dismissTravel * (1 - visibility) + sample.compensationY }
    var spatialY: CGFloat { -dockHeight + offsetY }

    private(set) var quickHeight: CGFloat = 330
    private(set) var fullHeight: CGFloat = 640
    private(set) var allowsExpansion = true
    private(set) var currentDuration: TimeInterval = 0
    private(set) var continuationSlope: CGFloat?
    private static let dismissTravel: CGFloat = 18
    private static let directionSlop: CGFloat = 8
    // ReaderControlPanel.ets runtimeConfig at frozen Host 33f7c7b2: 500ms.
    private static let tapMaxDuration: TimeInterval = 0.5
    private let now: () -> TimeInterval
    private let automaticallyTicks: Bool
    private var path: Path?
    private var clock: Clock?
    private var drag: Drag?
    private var displayLink: CADisplayLink?
    private lazy var displayProxy = DisplayProxy(owner: self)

    init(now: @escaping () -> TimeInterval = CACurrentMediaTime,
         automaticallyTicks: Bool = true) {
        self.now = now
        self.automaticallyTicks = automaticallyTicks
    }

    /// Heights are WHOLE dock heights: the regular 330pt composition already
    /// includes module navigation and its gap. Do not add another 80 + 14.
    func configure(quickHeight: CGFloat, fullHeight: CGFloat, allowsExpansion: Bool = true) {
        guard quickHeight.isFinite, fullHeight.isFinite, quickHeight > 0,
              fullHeight >= quickHeight else { return }
        let geometryChanged = quickHeight != self.quickHeight || fullHeight != self.fullHeight
        self.allowsExpansion = allowsExpansion
        guard geometryChanged else { return }
        advance(to: now())
        let oldY = spatialY
        self.quickHeight = quickHeight
        self.fullHeight = fullHeight
        guard isPresented else { return }
        var frame = currentFrame
        frame.compensationY += oldY - y(frame)
        publish(frame)
        if var held = drag {
            // Rebase the finger at the actual sample and erase old-layout
            // velocity. Overscroll residue remains physical finger travel.
            held.lastVelocity = 0
            held.velocityInterval = 0
            held.directionAnchor = held.lastTranslation
            drag = held
            path = rebasedPath(frame, direction: held.recentDirection)
            return
        }
        // Layout compensation uses the same progress and clock as the dock.
        animate(to: target, destination: endpoint(target), duration: nominalDuration(to: target), slope: nil)
    }

    func move(to position: Position, reduceMotion: Bool = false) {
        let position: Position = position == .full && !allowsExpansion ? .quick : position
        advance(to: now())
        if drag == nil, position == target, clock != nil, !reduceMotion { return }
        drag = nil
        let destination = endpoint(position)
        if reduceMotion {
            settle(at: position, frame: destination)
            return
        }
        let frame = currentFrame
        let distance = max(abs(destination.expansion - frame.expansion),
                           abs(destination.visibility - frame.visibility))
        let timing = nominalDuration(to: position) * Double(distance)
        animate(to: position, destination: destination,
                duration: frame.compensationY == 0 ? timing : max(timing, 0.22), slope: nil)
    }

    /// Translation is cumulative downward-positive screen points. `time` is
    /// seconds on one monotonically increasing event timeline; it need not
    /// share CADisplayLink's epoch. There is no predictedEndTranslation fling.
    func dragChanged(translationY: CGFloat, time: TimeInterval) {
        guard translationY.isFinite, time.isFinite, isPresented else { return }
        if drag == nil { beginDrag(time: time) }
        guard var held = drag, time >= held.lastTime else { return }
        let delta = translationY - held.lastTranslation
        let interval = time - held.lastTime
        held.lastVelocity = interval > 0 ? delta / CGFloat(interval) : 0
        held.velocityInterval = interval
        held.lastTranslation = translationY
        held.lastTime = time
        let intent = translationY - held.directionAnchor
        if abs(intent) > Self.directionSlop {
            held.recentDirection = intent < 0 ? .up : .down
            held.directionAnchor = translationY
            held.moved = true
        }
        if delta == 0 { drag = held; return }
        held.pointerDisplaced = true
        var remaining = delta + held.blockedDelta
        if held.blockedDelta != 0, sameSign(remaining, held.blockedDelta) {
            held.blockedDelta = remaining
            drag = held
            return
        }
        held.blockedDelta = 0
        for _ in 0..<2 {
            if abs(remaining) <= 1e-7 { break }
            guard let segment = segmentForMovement(remaining) else { break }
            path = segment
            let fromY = y(segment.from)
            let toY = y(segment.to)
            let travel = toY - fromY
            guard abs(travel) > 1e-7 else { break }
            let desired = y(segment.frame) + remaining
            let raw = (desired - fromY) / travel
            let progress = Self.unit(raw)
            var moved = segment
            moved.progress = progress
            path = moved
            publish(moved.frame)
            let reachable = raw >= -1e-12 && raw <= 1 + 1e-12
            remaining = reachable ? 0 : desired - y(moved.frame)
            if reachable { break }
        }
        held.blockedDelta = remaining
        drag = held
    }

    func dragEnded(translationY: CGFloat, time: TimeInterval, reduceMotion: Bool = false) {
        guard translationY.isFinite, time.isFinite, let existing = drag, time >= existing.lastTime else { return }
        if translationY != existing.lastTranslation { dragChanged(translationY: translationY, time: time) }
        guard var held = drag else { return }
        let gap = max(0, time - held.lastTime)
        let window = held.velocityInterval + gap
        if window > 0 { held.lastVelocity *= CGFloat(held.velocityInterval / window) }
        drag = nil
        if !held.moved {
            if time - held.downTime < Self.tapMaxDuration && (allowsExpansion || held.pausedClock != nil) {
                let destination: Position
                if let paused = held.pausedPath, held.pausedClock != nil {
                    destination = held.pausedTarget == paused.toPosition ? paused.fromPosition : paused.toPosition
                } else {
                    destination = held.pausedTarget == .full ? .quick : .full
                }
                move(to: destination, reduceMotion: reduceMotion)
            } else {
                resume(held, reduceMotion: reduceMotion)
            }
            return
        }
        guard let segment = path, held.recentDirection != .none else {
            resume(held, reduceMotion: reduceMotion)
            return
        }
        let fromY = y(segment.from)
        let toY = y(segment.to)
        let towardsTo = held.recentDirection == .up ? toY < fromY : toY > fromY
        let requestedGoal = towardsTo ? segment.toPosition : segment.fromPosition
        let goal: Position = requestedGoal == .full && !allowsExpansion ? .quick : requestedGoal
        let destination = goal == requestedGoal ? (towardsTo ? segment.to : segment.from) : endpoint(goal)
        let remaining = abs((towardsTo ? 1 : 0) - segment.progress)
        let nominal = nominalDuration(to: goal)
        let travel = abs(toY - fromY)
        let speedFactor = travel > 1e-7 ? 1 + abs(held.lastVelocity) * CGFloat(nominal) / travel : 1
        let duration = nominal * Double(remaining / speedFactor)
        let distance = y(destination) - spatialY
        let slope = abs(distance) > 1e-7 ? Self.slope(held.lastVelocity * CGFloat(duration) / distance) : 0
        if reduceMotion { settle(at: goal, frame: destination) }
        else { animate(to: goal, destination: destination, duration: duration, slope: slope) }
    }

    /// CANCEL is not a tap or release: restore the pre-hold logical goal.
    func cancelDrag(reduceMotion: Bool = false) {
        guard let held = drag else { return }
        drag = nil
        resume(held, reduceMotion: reduceMotion)
    }

    /// Lifecycle boundary revokes the frame source and pointer. A later
    /// explicit move resumes from this captured sample, never from an endpoint.
    /// SwiftUI teardown must retain the last published sample without emitting
    /// an ObservableObject change from inside its view-removal transaction.
    func stop(publishingFinalSample: Bool = true) {
        if publishingFinalSample { advance(to: now()) }
        drag = nil
        clock = nil
        continuationSlope = nil
        stopDisplayLink()
    }

    /// Deterministic clock seam, also used by CADisplayLink. Tests drive the
    /// production sampler directly instead of sleeping or running a RunLoop.
    func advance(to time: TimeInterval) {
        guard time.isFinite, drag == nil, var running = clock, var segment = path else { return }
        let delta = max(0, time - running.lastTime)
        running.lastTime = max(time, running.lastTime)
        running.elapsed += delta
        let fraction = running.duration <= 0 ? 1 : Self.unit(CGFloat(running.elapsed / running.duration))
        let eased = running.slope.map { Self.hermite(fraction, slope: $0) } ?? Self.smoothstep(fraction)
        segment.progress = running.startProgress + (running.targetProgress - running.startProgress) * eased
        path = segment
        clock = running
        publish(segment.frame)
        if fraction == 1 {
            settle(at: running.targetPosition,
                   frame: running.targetProgress == 1 ? segment.to : segment.from)
        }
    }

    static func smoothstep(_ fraction: CGFloat) -> CGFloat {
        let t = unit(fraction)
        return t * t * (3 - 2 * t)
    }

    /// Monotone cubic Hermite: measured initial speed, zero final speed.
    static func hermite(_ fraction: CGFloat, slope: CGFloat) -> CGFloat {
        let t = unit(fraction)
        let m = Self.slope(slope)
        return ((m - 2) * t + 3 - 2 * m) * t * t + m * t
    }

    private var currentFrame: Frame {
        Frame(visibility: visibility, expansion: expansion, compensationY: sample.compensationY)
    }

    private func endpoint(_ position: Position) -> Frame {
        Frame(visibility: position == .hidden ? 0 : 1,
              expansion: position == .hidden ? expansion : position == .full ? 1 : 0)
    }

    private func nominalDuration(to position: Position) -> TimeInterval {
        if position == .hidden { return 0.2 }
        if position == .full, expansion < 1 { return 0.32 }
        if position == .quick, expansion > 0 { return 0.26 }
        return 0.22
    }

    private func y(_ frame: Frame) -> CGFloat {
        -quickHeight - (fullHeight - quickHeight) * frame.expansion +
            Self.dismissTravel * (1 - frame.visibility) + frame.compensationY
    }

    private func publish(_ frame: Frame) {
        sample = Sample(visibility: Self.unit(frame.visibility), expansion: Self.unit(frame.expansion),
                        compensationY: frame.compensationY, isPresented: sample.isPresented, target: sample.target)
    }

    private func animate(to position: Position, destination: Frame, duration: TimeInterval, slope: CGFloat?) {
        let source = currentFrame
        sample = Sample(visibility: visibility, expansion: expansion, compensationY: source.compensationY,
                        isPresented: isPresented || position != .hidden, target: position)
        if duration <= 1e-7 || source == destination {
            settle(at: position, frame: destination)
            return
        }
        let sourcePosition: Position = source.visibility == 0 ? .hidden : source.expansion == 1 ? .full : .quick
        path = Path(from: source, to: destination, fromPosition: sourcePosition, toPosition: position, progress: 0)
        currentDuration = duration
        continuationSlope = slope
        clock = Clock(startProgress: 0, targetProgress: 1, targetPosition: position,
                      duration: duration, elapsed: 0, lastTime: now(), slope: slope)
        startDisplayLink()
    }

    private func settle(at position: Position, frame: Frame) {
        path = nil
        clock = nil
        currentDuration = 0
        continuationSlope = nil
        stopDisplayLink()
        sample = Sample(visibility: position == .hidden ? 0 : frame.visibility,
                        expansion: position == .hidden ? 0 : frame.expansion,
                        compensationY: frame.compensationY,
                        isPresented: position != .hidden, target: position)
    }

    private func beginDrag(time: TimeInterval) {
        advance(to: now())
        drag = Drag(downTime: time, lastTime: time, pausedTarget: target,
                    pausedFrame: clock.flatMap { running in path.map { running.targetProgress == 1 ? $0.to : $0.from } } ?? endpoint(target),
                    pausedPath: path, pausedClock: clock)
        clock = nil
        continuationSlope = nil
        stopDisplayLink()
    }

    private func resume(_ held: Drag, reduceMotion: Bool) {
        if held.pausedTarget == .full && !allowsExpansion {
            move(to: .quick, reduceMotion: reduceMotion)
            return
        }
        if reduceMotion { settle(at: held.pausedTarget, frame: held.pausedFrame); return }
        if !held.pointerDisplaced, let paused = held.pausedPath, var running = held.pausedClock {
            path = paused
            running.lastTime = now()
            clock = running
            continuationSlope = running.slope
            currentDuration = max(0, running.duration - running.elapsed)
            startDisplayLink()
            return
        }
        let remainingTime = held.pausedClock.map { max(0, $0.duration - $0.elapsed) }
        animate(to: held.pausedTarget, destination: held.pausedFrame,
                duration: remainingTime ?? nominalDuration(to: held.pausedTarget), slope: nil)
    }

    private func segmentForMovement(_ delta: CGFloat) -> Path? {
        if delta < 0, !allowsExpansion, currentFrame.visibility == 1 { return nil }
        if let segment = path {
            let travel = y(segment.to) - y(segment.from)
            let progressDelta = abs(travel) > 1e-7 ? delta / travel : 0
            if segment.progress > 0 && segment.progress < 1 ||
                segment.progress == 0 && progressDelta > 0 ||
                segment.progress == 1 && progressDelta < 0 { return segment }
        }
        return rebasedPath(currentFrame, direction: delta < 0 ? .up : .down)
    }

    private func rebasedPath(_ frame: Frame, direction: Direction) -> Path? {
        // Visible morphs share the complete Quick<->Full spatial axis.
        if frame.visibility == 1 {
            if direction == .up && allowsExpansion && frame.expansion < 1 || direction == .down && frame.expansion > 0 {
                return Path(from: Frame(visibility: 1, expansion: 0, compensationY: frame.compensationY),
                            to: Frame(visibility: 1, expansion: 1, compensationY: frame.compensationY),
                            fromPosition: .quick, toPosition: .full, progress: frame.expansion)
            }
            if direction == .down && frame.expansion == 0 {
                return Path(from: frame, to: Frame(visibility: 0, expansion: 0, compensationY: frame.compensationY),
                            fromPosition: .quick, toPosition: .hidden, progress: 0)
            }
            return nil
        }
        // Regrabbing a close must first retrace that captured composition.
        if let segment = path { return segment }
        let visible = Frame(visibility: 1, expansion: frame.expansion, compensationY: frame.compensationY)
        return Path(from: visible, to: Frame(visibility: 0, expansion: frame.expansion, compensationY: frame.compensationY),
                    fromPosition: frame.expansion == 1 ? .full : .quick,
                    toPosition: .hidden, progress: 1 - frame.visibility)
    }

    private func startDisplayLink() {
        guard automaticallyTicks, displayLink == nil, clock != nil else { return }
        let link = CADisplayLink(target: displayProxy, selector: #selector(DisplayProxy.tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopDisplayLink() { displayLink?.invalidate(); displayLink = nil }
    private static func unit(_ value: CGFloat) -> CGFloat { value.isFinite ? max(0, min(1, value)) : 0 }
    private static func slope(_ value: CGFloat) -> CGFloat { value.isFinite ? max(0, min(3, value)) : 0 }
    private func sameSign(_ lhs: CGFloat, _ rhs: CGFloat) -> Bool { lhs != 0 && (lhs > 0) == (rhs > 0) }

    private struct Frame: Equatable {
        var visibility: CGFloat
        var expansion: CGFloat
        var compensationY: CGFloat = 0
        static func interpolate(_ from: Frame, _ to: Frame, _ progress: CGFloat) -> Frame {
            Frame(visibility: from.visibility + (to.visibility - from.visibility) * progress,
                  expansion: from.expansion + (to.expansion - from.expansion) * progress,
                  compensationY: from.compensationY + (to.compensationY - from.compensationY) * progress)
        }
    }
    private struct Path {
        let from: Frame
        let to: Frame
        let fromPosition: Position
        let toPosition: Position
        var progress: CGFloat
        var frame: Frame { Frame.interpolate(from, to, progress) }
    }
    private struct Clock {
        let startProgress: CGFloat
        let targetProgress: CGFloat
        let targetPosition: Position
        let duration: TimeInterval
        var elapsed: TimeInterval
        var lastTime: TimeInterval
        let slope: CGFloat?
    }
    private enum Direction { case none, up, down }
    private struct Drag {
        let downTime: TimeInterval
        var lastTime: TimeInterval
        let pausedTarget: Position
        let pausedFrame: Frame
        let pausedPath: Path?
        let pausedClock: Clock?
        var lastTranslation: CGFloat = 0
        var directionAnchor: CGFloat = 0
        var recentDirection: Direction = .none
        var moved = false
        var pointerDisplaced = false
        var lastVelocity: CGFloat = 0
        var velocityInterval: TimeInterval = 0
        var blockedDelta: CGFloat = 0
    }
    @MainActor
    private final class DisplayProxy: NSObject {
        weak var owner: ReaderControlMotionDriver?
        init(owner: ReaderControlMotionDriver) { self.owner = owner }
        @objc func tick(_ link: CADisplayLink) {
            guard let owner else { link.invalidate(); return }
            owner.advance(to: link.timestamp)
        }
    }
}
