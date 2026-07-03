import SwiftUI
import ReaderCoreModels

public struct ErrorView: View {
    public let error: ReaderError
    public let retryAction: (() -> Void)?

    public init(error: ReaderError, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    public var body: some View {
        ReaderStateCard(
            icon: .warning,
            title: "加载失败",
            subtitle: subtitle,
            actionTitle: retryAction == nil ? nil : "重试",
            action: retryAction
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var subtitle: String {
        if let failureType = error.failure?.type {
            return "\(error.message)\nFailure: \(failureType.rawValue)"
        }
        return error.message
    }
}
