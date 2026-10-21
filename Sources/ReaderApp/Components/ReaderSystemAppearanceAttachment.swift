import SwiftUI
import UIKit

/// Observe the actual owning scene before per-window Reader color overrides.
/// A window's effective colorScheme cannot be reused as the system preference.
struct ReaderSystemAppearanceAttachment: UIViewRepresentable {
    var changed: (Bool) -> Void
    func makeUIView(context: Context) -> ReaderSystemAppearanceView {
        let view = ReaderSystemAppearanceView(); view.changed = changed
        return view
    }
    func updateUIView(_ view: ReaderSystemAppearanceView, context: Context) {
        view.changed = changed; view.report()
    }
    static func dismantleUIView(_ view: ReaderSystemAppearanceView, coordinator: ()) { view.retire() }
}

@MainActor
final class ReaderSystemAppearanceView: UIView {
    var changed: ((Bool) -> Void)?
    private weak var observedScene: UIWindowScene?
    private var registration: (any UITraitChangeRegistration)?
    private var generation = UUID()
    private var lastValue: Bool?
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if observedScene !== window?.windowScene {
            retire(); observedScene = window?.windowScene
            if let scene = observedScene {
                registration = scene.registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: UIWindowScene, _: UITraitCollection) in
                    self?.report()
                }
            }
        }
        report()
    }
    func report() {
        guard let scene = observedScene else { return }
        let style = scene.traitCollection.userInterfaceStyle
        guard style != .unspecified else { return }
        let value = style == .dark
        guard value != lastValue else { return }
        lastValue = value
        let expected = generation
        DispatchQueue.main.async { [weak self, weak scene] in
            guard let self, self.generation == expected, self.observedScene === scene else { return }
            self.changed?(value)
        }
    }
    func retire() {
        generation = UUID()
        if let scene = observedScene, let registration { scene.unregisterForTraitChanges(registration) }
        registration = nil; observedScene = nil; lastValue = nil
    }
}
