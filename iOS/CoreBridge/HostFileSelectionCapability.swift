import Foundation
import ReaderUIContract

/// Presentation seam for Reader-UI's `file.select` host request. The concrete
/// iOS implementation lives in the app target because it needs an active view
/// controller and `UIDocumentPickerViewController` delegate ownership.
@MainActor
public protocol HostFileSelectionPresenter: AnyObject {
    /// Returns an empty array when the user cancels.
    func selectFiles(mimeTypes: [String], allowsMultiple: Bool) async throws -> [URL]
}

/// Real UI capability; registration is unconditional, while missing app UI is
/// reported as a structured `notImplemented` result rather than fake success.
public struct HostFileSelectionCapability: HostCapabilityHandler {
    public let supportedTypes: Set<HostRequestType> = [.file_select]
    public let tier: HostCapabilityTier = .realDeviceProof

    private let presenterProvider: @Sendable () async -> HostFileSelectionPresenter?

    public init(
        presenterProvider: @escaping @Sendable () async -> HostFileSelectionPresenter?
    ) {
        self.presenterProvider = presenterProvider
    }

    public func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
        guard request.type == .file_select else {
            return .failure(.notImplemented(
                request.type,
                "HostFileSelectionCapability does not handle \(request.type.rawValue)"
            ))
        }
        guard let mimeTypes = Self.stringArray(
            request.payload["mimeTypes"]?.value,
            defaultValue: ["public.data"]
        ), !mimeTypes.isEmpty else {
            return .failure(.invalidParams("file.select `mimeTypes` must be a non-empty string array"))
        }
        let allowsMultiple: Bool
        if let raw = request.payload["allowsMultiple"]?.value {
            guard let parsed = raw as? Bool else {
                return .failure(.invalidParams("file.select `allowsMultiple` must be Bool"))
            }
            allowsMultiple = parsed
        } else {
            allowsMultiple = false
        }
        guard let presenter = await presenterProvider() else {
            return .failure(.notImplemented(
                .file_select,
                "file picker requires an active application presenter"
            ))
        }
        do {
            let urls = try await presenter.selectFiles(
                mimeTypes: mimeTypes,
                allowsMultiple: allowsMultiple
            )
            let files = urls.map { url in
                AnyCodable([
                    "path": AnyCodable(url.absoluteString),
                    "name": AnyCodable(url.lastPathComponent),
                ])
            }
            return .success([
                "selected": AnyCodable(!urls.isEmpty),
                "files": AnyCodable(files),
            ])
        } catch {
            return .failure(.underlying("file.select failed: \(error.localizedDescription)"))
        }
    }

    private static func stringArray(
        _ raw: (any Sendable)?,
        defaultValue: [String]
    ) -> [String]? {
        guard let raw else { return defaultValue }
        if let values = raw as? [String] { return values }
        if let values = raw as? [AnyCodable] {
            let strings = values.compactMap { $0.value as? String }
            return strings.count == values.count ? strings : nil
        }
        return nil
    }
}
