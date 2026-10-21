import SwiftUI

/// Registered iOS confirmation boundary. Pages submit captured targets; this
/// adapter owns only presentation and never chooses or mutates those targets.
@MainActor
final class ReaderNativeAlertOwner: ObservableObject {
    struct Request: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let actionTitle: String
        let destructive: Bool
        let action: () -> Void
    }
    @Published var request: Request?
    func confirm(_ title: String, message: String, actionTitle: String = "确认", destructive: Bool = false,
                 action: @escaping () -> Void) {
        guard request == nil else { return }
        request = Request(title: title, message: message, actionTitle: actionTitle, destructive: destructive, action: action)
    }
}

private struct ReaderConfirmationHost: ViewModifier {
    @ObservedObject var owner: ReaderNativeAlertOwner
    func body(content: Content) -> some View {
        content.alert(owner.request?.title ?? "", isPresented: Binding(
            get: { owner.request != nil }, set: { if !$0 { owner.request = nil } }), presenting: owner.request) { request in
            Button(request.actionTitle, role: request.destructive ? .destructive : nil) { request.action() }
            Button("取消", role: .cancel) {}
        } message: { Text($0.message) }
    }
}

extension View {
    func readerConfirmation(_ owner: ReaderNativeAlertOwner) -> some View { modifier(ReaderConfirmationHost(owner: owner)) }
    func readerField() -> some View {
        modifier(ReaderFieldModifier())
    }
}

private struct ReaderFieldModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.padding(12).background(ReaderPalette(scheme).field, in: RoundedRectangle(cornerRadius: 12))
    }
}

struct ReaderOperationStatus: View {
    @ObservedObject var owner: ReaderLibraryActionOwner
    let scope: String
    var allowGlobalRecovery = false
    var recoveryContext: String? = nil
    var completed: () -> Void = {}
    var body: some View {
        if let message = owner.recovery, owner.scope == scope || allowGlobalRecovery {
            ReaderRecoveryNotice(message: recoveryContext.map { $0 + "：" + message } ?? message,
                                 busy: owner.busy, title: "原操作待核对") {
                Task { if await owner.resumeOriginal() { completed() } }
            }
        } else if owner.scope == scope, let message = owner.feedback {
            ReaderTransientFeedback(message: message).allowsHitTesting(false)
        }
    }
}
