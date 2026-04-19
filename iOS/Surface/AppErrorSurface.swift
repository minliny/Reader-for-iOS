import SwiftUI
import ReaderCoreModels

public struct AppErrorSurface: View {
    let error: ReaderError?
    let onRetry: (() -> Void)?

    public init(error: ReaderError?, onRetry: (() -> Void)? = nil) {
        self.error = error
        self.onRetry = onRetry
    }

    public var body: some View {
        if let error = error {
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(.orange)

                Text(error.message)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                if let failureType = error.failure?.type {
                    Text("Failure: \(failureType.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let retry = onRetry {
                    Button(action: retry) {
                        Text("重试")
                            .font(.body.weight(.medium))
                            .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }
            }
            .padding(32)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
        }
    }
}
