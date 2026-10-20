import Foundation
import SwiftUI
#if DEBUG
import OSLog
#endif

/// Selection and SwiftUI dismissal are independent native events. Neither is
/// allowed to discard the other event or start an import on its own.
@MainActor
final class ReaderFilePickerOwner: ObservableObject {
    @Published private(set) var isPresented = false
    @Published private(set) var operationID: UUID?

    var presented: Binding<Bool> {
        Binding(get: { self.isPresented }, set: { shown in
            if shown { _ = self.begin() }
            else { self.presentationWillClose() }
        })
    }

    private struct Operation {
        let id: UUID
        var selectedURL: URL?
        var dismissed = false
    }
    private var operation: Operation?
    /// SwiftUI normally updates the binding before onDismiss. Keep the exact
    /// closing identity so a cancelled, older sheet cannot dismiss a new one.
    private var awaitingDismissal: [UUID] = []

    @discardableResult
    func begin() -> UUID {
        // Two taps while the same presentation is opening still own one sheet
        // and its already-created delegate. A closed operation awaiting a late
        // selection is superseded by an explicit new picker request.
        if isPresented, let id = operation?.id { return id }
        let id = UUID()
        operation = Operation(id: id)
        operationID = id
        isPresented = true
        trace("begin", id: id)
        return id
    }

    /// Return a URL only when the matching dismissal has also arrived.
    @discardableResult
    func select(_ url: URL, operationID id: UUID) -> URL? {
        guard var current = operation, current.id == id else {
            trace("select ignored", id: id)
            return nil
        }
        // UIDocumentPicker may redeliver a delegate event; the first selection
        // is the operation's immutable intent until consumption or cancellation.
        guard current.selectedURL == nil else { trace("duplicate select ignored", id: id); return nil }
        current.selectedURL = url
        operation = current
        trace("select", id: id)
        presentationWillClose()
        return consumeReadyOperation()
    }

    /// `operationID` is useful when the caller has captured a particular
    /// presentation. The no-argument onDismiss consumes the binding's oldest
    /// closing identity, or the active operation if dismissal arrived first.
    @discardableResult
    func didDismiss(operationID explicitID: UUID? = nil) -> URL? {
        guard let id = explicitID ?? awaitingDismissal.first ?? operation?.id else { return nil }
        awaitingDismissal.removeAll { $0 == id }
        guard var current = operation, current.id == id else {
            trace("dismiss ignored", id: id)
            return nil
        }
        guard !current.dismissed else { trace("duplicate dismiss ignored", id: id); return nil }
        current.dismissed = true
        operation = current
        isPresented = false
        trace("dismiss", id: id)
        return consumeReadyOperation()
    }

    func cancel(operationID id: UUID) {
        guard let current = operation, current.id == id else { trace("cancel ignored", id: id); return }
        trace("cancel", id: id)
        presentationWillClose()
        operation = nil
        operationID = nil
    }

    private func presentationWillClose() {
        if let current = operation, !current.dismissed, !awaitingDismissal.contains(current.id) {
            awaitingDismissal.append(current.id)
        }
        isPresented = false
    }

    private func consumeReadyOperation() -> URL? {
        guard let current = operation, current.dismissed, let url = current.selectedURL else { return nil }
        operation = nil
        operationID = nil
        awaitingDismissal.removeAll { $0 == current.id }
        isPresented = false
        trace("ready", id: current.id)
        return url
    }

    private func trace(_ event: String, id: UUID) {
        #if DEBUG
        // Operation IDs are random lifecycle tokens. Never log selected URLs,
        // document names, bookmark contents, or imported book metadata here.
        Self.logger.debug("file-picker \(event, privacy: .public) operation=\(id.uuidString, privacy: .public)")
        #endif
    }
    #if DEBUG
    private static let logger = Logger(subsystem: "io.reader.minliny", category: "FilePickerLifecycle")
    #endif
}
