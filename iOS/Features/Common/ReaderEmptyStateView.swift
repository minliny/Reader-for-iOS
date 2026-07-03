import SwiftUI

public struct ReaderEmptyStateView: View {
    public let title: String
    public let message: String
    public let systemImage: String
    public let actionTitle: String?
    public let action: (() -> Void)?

    public init(
        title: String,
        message: String,
        systemImage: String,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        ReaderStateCard(
            icon: icon,
            title: title,
            subtitle: message,
            actionTitle: actionTitle,
            action: action
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var icon: ReaderAssetIcon {
        switch systemImage {
        case let value where value.contains("book"):
            return .bookOpen
        case let value where value.contains("folder"):
            return .folderOff
        case let value where value.contains("wifi"):
            return .offline
        case let value where value.contains("magnifyingglass"):
            return .search
        default:
            return .info
        }
    }
}
