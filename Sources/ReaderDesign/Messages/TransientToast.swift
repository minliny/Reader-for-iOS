import Observation
import SwiftUI

@MainActor
@Observable
public final class ReaderToastPresenter {
    public private(set) var message: String?
    @ObservationIgnored private var recent: [String: ContinuousClock.Instant] = [:]
    @ObservationIgnored private var expiry: Task<Void, Never>?
    private let clock = ContinuousClock()

    public init() {}

    @discardableResult
    public func show(message: String, key: String, feedbackEnabled: Bool, sceneActive: Bool) -> Bool {
        guard feedbackEnabled && sceneActive else {
            dismiss()
            return false
        }
        let now = clock.now
        let window = Duration.milliseconds(ReaderDesignMetrics.shortFeedbackMillis)
        recent = recent.filter { now - $0.value < window }
        guard recent[key] == nil else { return false }
        recent[key] = now
        self.message = message
        expiry?.cancel()
        expiry = Task { [weak self] in
            do { try await Task.sleep(for: window) } catch { return }
            self?.dismiss()
        }
        return true
    }

    public func dismiss() {
        expiry?.cancel()
        expiry = nil
        message = nil
    }
}

public struct TransientToast: View {
    @Environment(\.readerTheme) private var theme
    private let message: String

    public init(message: String) { self.message = message }

    public var body: some View {
        Text(message)
            .readerTypography(ReaderDesignMetrics.rowLabel)
            .foregroundStyle(theme.messageText)
            .multilineTextAlignment(.center)
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.spaceMedium))
            .padding(.vertical, CGFloat(ReaderDesignMetrics.spaceExtraSmall))
            .background(theme.messageSurface, in: Capsule())
            .overlay { Capsule().strokeBorder(theme.messageBorder) }
            .shadow(color: theme.shadow, radius: 9, y: 4)
            .accessibilityAddTraits(.updatesFrequently)
            .allowsHitTesting(false)
    }
}
