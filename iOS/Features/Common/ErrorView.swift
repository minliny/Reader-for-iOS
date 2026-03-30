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
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text(error.message)
                .font(.headline)
                .multilineTextAlignment(.center)

            if let failureType = error.failure?.type {
                Text("Failure: \(failureType.rawValue)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let retry = retryAction {
                Button(action: retry) {
                    Text("重试")
                        .font(.subheadline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
