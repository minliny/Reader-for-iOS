import ReaderDesign
import SwiftUI

enum ReadingControls: Equatable {
    case hidden, quick, full
}

enum ReadingControlAction {
    case dismiss
    case expand
    case quick
    case directory
    case bookmarks
    case addBookmark
    case previous
    case next
    case speech
    case size(Double)
    case spacing(Double)
    case tracking(Double)
    case paper(String)
    case mode(ReadingMode)
}

struct ControlPanel: View {
    let state: ReadingControls
    let title: String
    let preferences: ReadingPreferences
    let onAction: (ReadingControlAction) -> Void
    var speechAvailable = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if state != .hidden {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .readerTypography(ReaderDesignMetrics.readerControlBookTitle, relativeTo: .headline)
                        .lineLimit(1)
                    Spacer()
                    Button { onAction(state == .full ? .quick : .expand) } label: {
                        ReaderIcon(ReaderIconRegistry.readerControlHeaderChevron)
                            .rotationEffect(.degrees(state == .full ? 180 : 0))
                            .frame(width: 34, height: 36)
                    }
                    .accessibilityLabel(state == .full ? "收起版式" : "展开版式")
                    Button { onAction(.dismiss) } label: {
                        ReaderIcon(ReaderIconRegistry.close).frame(width: 34, height: 36)
                    }
                    .accessibilityLabel("关闭控制岛")
                }
                if state == .full {
                    AppearanceControls(preferences: preferences, onAction: onAction)
                }
                QuickControls(onAction: onAction, speechAvailable: speechAvailable)
            }
            .buttonStyle(.plain)
            .foregroundStyle(preferences.paper.foreground)
            .padding(CGFloat(ReaderDesignMetrics.cardPadding))
            .background(preferences.paper.controlBackground,
                        in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
            .shadow(color: .black.opacity(0.16), radius: 18, y: 5)
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
            .padding(.bottom, 12)
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            .accessibilityIdentifier(state == .full ? "reader-controls-full" : "reader-controls-quick")
        }
    }
}
