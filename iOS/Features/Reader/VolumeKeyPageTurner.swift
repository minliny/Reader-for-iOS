import Foundation
import AVFoundation
#if canImport(UIKit)
import UIKit
import MediaPlayer
#endif

/// Observes hardware volume button presses via `AVAudioSession` KVO and
/// triggers page-turn callbacks.
///
/// **Limitation (iOS):** iOS does not provide a public API to intercept
/// volume buttons without changing the system volume. When this feature is
/// enabled, pressing volume up/down will also change the system volume.
/// The class attempts to reset the volume to the saved level via a hidden
/// `MPVolumeView` slider, but this is best-effort and may not work on all
/// iOS versions.
///
/// Volume up = next page, volume down = previous page.
/// A 0.3s debounce prevents double-triggering.
public final class VolumeKeyPageTurner: NSObject {

    public enum VolumeDirection: Sendable {
        case up
        case down
    }

    public var onVolumeChange: (@Sendable (VolumeDirection) -> Void)?

    private var observation: NSKeyValueObservation?
    private var savedVolume: Float = 0
    private var lastTriggerTime: Date = .distantPast
    private let debounceInterval: TimeInterval = 0.3

    #if canImport(UIKit)
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    #endif

    public override init() {
        super.init()
    }

    public func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        savedVolume = session.outputVolume

        #if canImport(UIKit)
        // Hidden MPVolumeView for best-effort volume reset
        volumeView = MPVolumeView(frame: .zero)
        if let slider = volumeView?.subviews.first(where: { $0 is UISlider }) as? UISlider {
            volumeSlider = slider
        }
        #endif

        observation = session.observe(\.outputVolume, options: [.new]) { [weak self] _, change in
            self?.handleVolumeChange(change.newValue ?? 0)
        }
    }

    public func stop() {
        observation?.invalidate()
        observation = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #if canImport(UIKit)
        volumeView = nil
        volumeSlider = nil
        #endif
    }

    private func handleVolumeChange(_ newVolume: Float) {
        let now = Date()
        guard now.timeIntervalSince(lastTriggerTime) > debounceInterval else { return }

        let direction: VolumeDirection
        if newVolume > savedVolume + 0.01 {
            direction = .up
        } else if newVolume < savedVolume - 0.01 {
            direction = .down
        } else {
            return
        }

        lastTriggerTime = now
        savedVolume = newVolume

        // Best-effort volume reset
        #if canImport(UIKit)
        DispatchQueue.main.async { [weak self] in
            self?.volumeSlider?.value = self?.savedVolume ?? 0.5
        }
        #endif

        onVolumeChange?(direction)
    }
}
