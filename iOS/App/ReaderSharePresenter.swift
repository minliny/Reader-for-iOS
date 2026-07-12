import Foundation
#if canImport(UIKit)
import UIKit
import ReaderShellValidation

/// Concrete `HostSharePresenter` backed by `UIActivityViewController`.
///
/// Lives in the app target (not CoreBridge) because CoreBridge must not
/// import UIKit presentation APIs. The app target wires this into
/// `HostAdapterHolder.adapter.setSharePresenterProvider(...)` at launch.
///
/// Tier: `simulatorProof` — share sheet works on the simulator, though
/// the list of available activities differs from a real device.
@MainActor
final class ReaderSharePresenter: HostSharePresenter {
    /// Find the topmost view controller to present the share sheet from.
    private var topViewController: UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first,
              var root = window.rootViewController else {
            return nil
        }
        while let presented = root.presentedViewController {
            root = presented
        }
        return root
    }

    func present(items: [String], excludedActivityTypes: [String]?) async -> String? {
        await presentActivityItems(items, excludedActivityTypes: excludedActivityTypes)
    }

    func present(fileURL: URL, excludedActivityTypes: [String]?) async -> String? {
        await presentActivityItems([fileURL], excludedActivityTypes: excludedActivityTypes)
    }

    private func presentActivityItems(
        _ activityItems: [Any],
        excludedActivityTypes: [String]?
    ) async -> String? {
        guard let presenter = topViewController else {
            return nil
        }
        let excluded: [UIActivity.ActivityType]? = excludedActivityTypes?.map { UIActivity.ActivityType(rawValue: $0) }

        return await withCheckedContinuation { continuation in
            let controller = UIActivityViewController(
                activityItems: activityItems,
                applicationActivities: nil
            )
            if let excluded {
                controller.excludedActivityTypes = excluded
            }
            controller.completionWithItemsHandler = { activityType, completed, _, _ in
                // Return the selected activity type only if the user actually
                // completed the share (not cancelled).
                if completed {
                    continuation.resume(returning: activityType?.rawValue)
                } else {
                    continuation.resume(returning: nil)
                }
            }
            presenter.present(controller, animated: true)
        }
    }
}
#endif
