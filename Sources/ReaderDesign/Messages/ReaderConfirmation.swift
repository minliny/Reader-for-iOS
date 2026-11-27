import SwiftUI

public struct ReaderConfirmation: Sendable, Equatable {
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let generation: Int

    public init(title: String, message: String, confirmTitle: String, generation: Int) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.generation = generation
    }
}

public extension View {
    func readerConfirmation(_ confirmation: Binding<ReaderConfirmation?>,
                            onConfirm: @escaping (Int) -> Void) -> some View {
        modifier(ReaderConfirmationView(confirmation: confirmation, onConfirm: onConfirm))
    }
}

private struct ReaderConfirmationView: ViewModifier {
    @Binding var confirmation: ReaderConfirmation?
    let onConfirm: (Int) -> Void

    func body(content: Content) -> some View {
        let presented = Binding(
            get: { confirmation != nil },
            set: { if !$0 { confirmation = nil } }
        )
        content.alert(confirmation?.title ?? "", isPresented: presented, presenting: confirmation) { expected in
            Button("取消", role: .cancel) {}
            Button(expected.confirmTitle, role: .destructive) {
                guard confirmation?.generation == expected.generation else { return }
                onConfirm(expected.generation)
            }
        } message: { expected in
            Text(expected.message)
        }
    }
}
