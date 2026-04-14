import Foundation
#if canImport(SwiftUI)
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
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "book.closed.fill")
                    .foregroundStyle(.tint)
                Text("会话上下文")
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(.vertical, 4)
            
            Button(action: action) {
                Text(actionTitle)
                    .font(.body.weight(.medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}
#endif
