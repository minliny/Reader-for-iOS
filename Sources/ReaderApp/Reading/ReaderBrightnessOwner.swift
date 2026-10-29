import SwiftUI
import UIKit
import Combine

/// Thin UIKit boundary for the frozen ReaderBrightnessWriter lifecycle.
/// UIScreen writes are synchronous: there is no pending native queue to recreate.
/// A cancelled drag observes the last applied value; it never writes a rollback.
@MainActor
final class ReaderBrightnessOwner: NSObject, ObservableObject {
    @Published private(set) var percent: CGFloat = 1
    @Published private(set) var isReady = false

    private weak var scene: UIWindowScene?
    private weak var screen: UIScreen?
    private var attachmentID: UUID?
    private var baseline: CGFloat?
    private var readerPresent = false
    private var foreground = false
    private var dragStart: CGFloat?
    // UIKit ownership changes synchronously, including while SwiftUI dismantles
    // the attachment. Published properties are only a deferred UI projection.
    private var ready = false
    private var appliedPercent: CGFloat = 1
    private var projectionGeneration = UUID()

    override init() {
        super.init()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(sceneActivated(_:)), name: UIScene.didActivateNotification, object: nil)
        center.addObserver(self, selector: #selector(sceneDeactivated(_:)), name: UIScene.willDeactivateNotification, object: nil)
        center.addObserver(self, selector: #selector(sceneDeactivated(_:)), name: UIScene.didEnterBackgroundNotification, object: nil)
        center.addObserver(self, selector: #selector(screenChanged(_:)), name: UIScreen.brightnessDidChangeNotification, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    /// Call for the reader lifetime, not for each opening of its controls.
    func enterReader() {
        readerPresent = true
        acquireIfPossible()
    }

    func leaveReader() {
        readerPresent = false
        releaseScreen()
    }

    fileprivate func attach(scene newScene: UIWindowScene, attachmentID: UUID) {
        self.attachmentID = attachmentID
        // SwiftUI updates its attachment for every body refresh. Only an actual
        // window/screen replacement can release and recapture this baseline.
        guard scene !== newScene || screen !== newScene.screen else { return }
        releaseScreen()
        scene = newScene
        screen = newScene.screen
        foreground = newScene.activationState == .foregroundActive
        acquireIfPossible()
    }

    fileprivate func detach(attachmentID: UUID) {
        // A retiring SwiftUI bridge cannot detach a newer bridge for the same scene.
        guard self.attachmentID == attachmentID else { return }
        releaseScreen()
        self.attachmentID = nil
        scene = nil
        screen = nil
        foreground = false
    }

    private func acquireIfPossible() {
        guard readerPresent, foreground, let screen else { return }
        if baseline == nil { baseline = screen.brightness }
        ready = true
        recordAppliedValue(screen.brightness)
    }

    private func releaseScreen() {
        dragStart = nil
        let savedBaseline = baseline
        baseline = nil
        ready = false
        // Revoke the claim before restoration can deliver a brightness callback.
        if let savedBaseline, let screen { screen.brightness = savedBaseline }
        scheduleProjection()
    }

    private func observeAppliedValue() {
        guard readerPresent, foreground, baseline != nil, let screen else { return }
        recordAppliedValue(screen.brightness)
    }

    private func request(_ value: CGFloat) {
        guard value.isFinite, ready, readerPresent, foreground, baseline != nil, let screen else { return }
        let stepped = min(100, max(1, (value * 10).rounded() / 10))
        screen.brightness = ReaderBrightnessCurve.screenValue(stepped)
        // UIKit exposes the actual normalized result synchronously.
        recordAppliedValue(screen.brightness)
    }

    private func recordAppliedValue(_ applied: CGFloat) {
        appliedPercent = ReaderBrightnessCurve.controlPercent(applied)
        scheduleProjection()
    }

    private func scheduleProjection() {
        let generation = UUID()
        projectionGeneration = generation
        DispatchQueue.main.async { [weak self] in
            guard let self, self.projectionGeneration == generation else { return }
            // Read the current internal facts; never replay an old attachment's
            // captured readiness or brightness after its owner has changed.
            if abs(self.appliedPercent - self.percent) > 0.00001 { self.percent = self.appliedPercent }
            if self.isReady != self.ready { self.isReady = self.ready }
        }
    }

    func updateDrag(translationY: CGFloat, trackHeight: CGFloat = ReaderMetrics.brightnessTrackHeight) {
        guard translationY.isFinite, trackHeight.isFinite, trackHeight > 0, ready else { return }
        if dragStart == nil { dragStart = appliedPercent }
        guard let dragStart else { return }
        request(dragStart - translationY / trackHeight * 99)
    }

    func endDrag(translationY: CGFloat, trackHeight: CGFloat = ReaderMetrics.brightnessTrackHeight) {
        guard dragStart != nil else { return }
        updateDrag(translationY: translationY, trackHeight: trackHeight)
        dragStart = nil
        observeAppliedValue()
    }

    func cancelDrag() {
        guard dragStart != nil else { return }
        dragStart = nil
        // No unsent work exists on this synchronous UIKit boundary.
        observeAppliedValue()
    }

    func tapTrack(y: CGFloat, trackHeight: CGFloat = ReaderMetrics.brightnessTrackHeight) {
        guard y.isFinite, trackHeight.isFinite, trackHeight > 0, ready else { return }
        dragStart = nil
        request(1 + (1 - min(trackHeight, max(0, y)) / trackHeight) * 99)
    }

    func adjust(by delta: CGFloat) {
        guard delta.isFinite else { return }
        dragStart = nil
        request(appliedPercent + delta)
    }

    @objc private func sceneActivated(_ notification: Notification) {
        guard let incoming = notification.object as? UIWindowScene, incoming === scene else { return }
        foreground = true
        // A foreground claim reads a fresh baseline; it does not reapply an old manual sample.
        acquireIfPossible()
    }

    @objc private func sceneDeactivated(_ notification: Notification) {
        guard let incoming = notification.object as? UIWindowScene, incoming === scene else { return }
        foreground = false
        releaseScreen()
    }

    @objc private func screenChanged(_ notification: Notification) {
        guard let incoming = notification.object as? UIScreen, incoming === screen, dragStart == nil else { return }
        observeAppliedValue()
    }
}

/// Keep this zero-size attachment mounted for the complete reader lifetime.
/// It observes the actual hosting window, never a guessed connected scene or UIScreen.main.
struct ReaderBrightnessAttachment: UIViewRepresentable {
    let owner: ReaderBrightnessOwner
    func makeUIView(context: Context) -> ReaderBrightnessAttachmentView {
        let view = ReaderBrightnessAttachmentView()
        view.owner = owner
        return view
    }
    func updateUIView(_ view: ReaderBrightnessAttachmentView, context: Context) {
        view.owner = owner
        view.updateAttachment()
    }
    static func dismantleUIView(_ view: ReaderBrightnessAttachmentView, coordinator: ()) { view.detach() }
}

final class ReaderBrightnessAttachmentView: UIView {
    weak var owner: ReaderBrightnessOwner?
    private let attachmentID = UUID()
    private var retired = false
    override func didMoveToWindow() { super.didMoveToWindow(); updateAttachment() }
    func updateAttachment() {
        let observedScene = window?.windowScene
        // The first UIKit attachment can occur within SwiftUI's update pass.
        // Admit it on the next main turn, while rejecting replaced/retired views.
        DispatchQueue.main.async { [weak self, weak observedScene] in
            guard let self, !self.retired, self.window?.windowScene === observedScene else { return }
            if let observedScene { self.owner?.attach(scene: observedScene, attachmentID: self.attachmentID) }
            else { self.owner?.detach(attachmentID: self.attachmentID) }
        }
    }
    func detach() { retired = true; owner?.detach(attachmentID: attachmentID) }
}

/// Default frozen ReaderControlGeometry: rail38×190, icon20 at y9, track8×104,
/// track pointer target24, two14-point gaps. Unsupported automatic brightness
/// has no active A control; its20-point endpoint slot remains empty.
/// An integrated height budget scales vertical geometry and its input mapping
/// together, so this sibling cannot enlarge the panel's reserved height.
struct ReaderBrightnessRail: View {
    @ObservedObject var owner: ReaderBrightnessOwner
    var height: CGFloat? = nil
    @Environment(\.colorScheme) private var scheme
    @GestureState private var dragging = false
    static let trackHeight = ReaderMetrics.brightnessTrackHeight

    var body: some View {
        let palette = ReaderPalette(scheme)
        let height = min(ReaderMetrics.brightnessRail.height,
                         max(ReaderMetrics.minimumHitSize, self.height ?? ReaderMetrics.brightnessRail.height))
        let scale = height / ReaderMetrics.brightnessRail.height
        let trackHeight = Self.trackHeight * scale
        VStack(spacing: 0) {
            ReaderIcon(.sun, size: 20 * scale).padding(.top, 9 * scale)
            ZStack(alignment: .bottom) {
                Capsule().fill(palette.border).frame(width: 8)
                VStack {
                    Spacer(minLength: 0)
                    Rectangle().fill(palette.readPrimary)
                        .frame(height: trackHeight * min(100, max(1, owner.percent)) / 100)
                }.frame(width: 8).clipShape(Capsule())
            }.frame(width: 24, height: trackHeight)
                .contentShape(Rectangle())
                .gesture(dragGesture(trackHeight: trackHeight).exclusively(before: SpatialTapGesture().onEnded { event in
                    owner.tapTrack(y: event.location.y, trackHeight: trackHeight)
                }))
                .transaction { $0.animation = nil }
                .padding(.top, 14 * scale)
                .accessibilityElement()
                .accessibilityLabel("阅读亮度")
                .accessibilityValue(owner.isReady ? "\(Int(owner.percent.rounded()))%" : "当前窗口亮度暂不可用")
                .accessibilityAdjustableAction { direction in
                    owner.adjust(by: direction == .increment ? 0.1 : -0.1)
                }
            Color.clear.frame(width: 24, height: 20 * scale).padding(.top, 14 * scale)
                .accessibilityHidden(true)
        }.frame(width: 38, height: height, alignment: .top)
            .background(palette.panel, in: Capsule())
            .overlay(Capsule().stroke(palette.app("TOK_LINE_STRONG"), lineWidth: 1))
            .opacity(owner.isReady ? 1 : 0.45)
            .allowsHitTesting(owner.isReady)
            .onChange(of: dragging) { previous, current in
                if previous && !current { owner.cancelDrag() }
            }
            .onDisappear { owner.cancelDrag() }
    }

    private func dragGesture(trackHeight: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 1, coordinateSpace: .local)
            .updating($dragging) { _, active, _ in active = true }
            .onChanged { owner.updateDrag(translationY: $0.translation.height, trackHeight: trackHeight) }
            .onEnded { owner.endDrag(translationY: $0.translation.height, trackHeight: trackHeight) }
    }
}

/*
 * Copyright (C) 2018 The Android Open Source Project
 * Licensed under the Apache License, Version 2.0.
 * https://www.apache.org/licenses/LICENSE-2.0
 *
 * Existing ReaderBrightnessCurve.ts formulas, translated without algorithm changes.
 * Upstream: android-15.0.0_r1 SettingsLib/DisplayUtils BrightnessUtils.java
 * Source SHA256: 7d9a706e4b4ff49ae8decef1406719ca8c6b518d652488f171a22e1800785247
 * HLG controls low-setting precision; it does not claim calibrated screen nits.
 */
private enum ReaderBrightnessCurve {
    private static let r: CGFloat = 0.5
    private static let a: CGFloat = 0.17883277
    private static let b: CGFloat = 0.28466892
    private static let c: CGFloat = 0.55991073
    private static let minimum: CGFloat = 0.01
    static func screenValue(_ percent: CGFloat) -> CGFloat {
        if percent >= 100 { return 1 }
        if percent <= 1 { return minimum }
        let normalized = min(1, max(0, (percent.isFinite ? percent - 1 : 49) / 99))
        let value = normalized <= r ? pow(normalized / r, 2) : exp((normalized - c) / a) + b
        return minimum + (1 - minimum) * min(12, max(0, value)) / 12
    }
    static func controlPercent(_ value: CGFloat) -> CGFloat {
        let normalized = min(1, max(0, ((value.isFinite ? value : minimum) - minimum) / (1 - minimum))) * 12
        let result = normalized <= 1 ? sqrt(normalized) * r : a * log(normalized - b) + c
        return min(100, max(1, 1 + 99 * result))
    }
}
