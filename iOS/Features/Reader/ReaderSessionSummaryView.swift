import SwiftUI

public struct ReaderSessionSummaryView: View {
    public let title: String
    public let subtitle: String
    public let actionTitle: String
    public let action: () -> Void
    
    public init(
        title: String,
        subtitle: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("会话上下文")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            
            Button(action: action) {
                Text(actionTitle)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16))
    }
}
