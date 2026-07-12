import Foundation

#if canImport(UIKit) && canImport(UniformTypeIdentifiers)
import UIKit
import UniformTypeIdentifiers
import ReaderShellValidation

enum ReaderFileSelectionPresentationError: LocalizedError {
    case presenterUnavailable
    case requestAlreadyActive

    var errorDescription: String? {
        switch self {
        case .presenterUnavailable:
            return "No active view controller is available for file selection."
        case .requestAlreadyActive:
            return "A file selection request is already active."
        }
    }
}

/// Real UIDocumentPicker presenter retained for the lifetime of one async
/// selection. Cancellation returns an empty list; missing UI fails closed.
@MainActor
final class ReaderFileSelectionPresenter: NSObject, HostFileSelectionPresenter,
    UIDocumentPickerDelegate {
    private var continuation: CheckedContinuation<[URL], Error>?

    func selectFiles(mimeTypes: [String], allowsMultiple: Bool) async throws -> [URL] {
        guard continuation == nil else {
            throw ReaderFileSelectionPresentationError.requestAlreadyActive
        }
        guard let presenter = Self.topViewController else {
            throw ReaderFileSelectionPresentationError.presenterUnavailable
        }
        let contentTypes = mimeTypes.compactMap(Self.contentType(from:))
        guard !contentTypes.isEmpty else {
            throw HostCapabilityError.invalidParams(
                "file.select `mimeTypes` contains no recognized UTI, MIME type or extension"
            )
        }
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let picker = UIDocumentPickerViewController(
                forOpeningContentTypes: contentTypes,
                asCopy: true
            )
            picker.allowsMultipleSelection = allowsMultiple
            picker.delegate = self
            presenter.present(picker, animated: true)
        }
    }

    func documentPicker(
        _ controller: UIDocumentPickerViewController,
        didPickDocumentsAt urls: [URL]
    ) {
        finish(returning: urls)
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        finish(returning: [])
    }

    private func finish(returning urls: [URL]) {
        let pending = continuation
        continuation = nil
        pending?.resume(returning: urls)
    }

    private static func contentType(from value: String) -> UTType? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let type = UTType(trimmed) { return type }
        if let type = UTType(mimeType: trimmed) { return type }
        return UTType(filenameExtension: trimmed.trimmingCharacters(in: CharacterSet(charactersIn: ".")))
    }

    private static var topViewController: UIViewController? {
        let allScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let scenes = allScenes.filter { $0.activationState == .foregroundActive } +
            allScenes.filter { $0.activationState != .foregroundActive }
        guard let window = scenes.lazy
            .flatMap(\.windows)
            .first(where: { $0.isKeyWindow }) ?? scenes.lazy.flatMap(\.windows).first,
              var root = window.rootViewController else {
            return nil
        }
        while let presented = root.presentedViewController {
            root = presented
        }
        return root
    }
}
#endif
