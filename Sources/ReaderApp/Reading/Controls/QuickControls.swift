import ReaderDesign
import SwiftUI

struct QuickControls: View {
    let onAction: (ReadingControlAction) -> Void
    var speechAvailable = false

    var body: some View {
        HStack(spacing: 0) {
            item("目录", icon: ReaderIconRegistry.directory, action: .directory)
            item("书签", icon: ReaderIconRegistry.bookmark, action: .bookmarks)
            item("上一章", icon: ReaderIconRegistry.previousChapter, action: .previous)
            item("下一章", icon: ReaderIconRegistry.nextChapter, action: .next)
            if speechAvailable {
                item("听书", icon: ReaderIconRegistry.ttsHeadphones, action: .speech)
                    .accessibilityIdentifier("reader-tts-start")
            }
        }
    }

    private func item(_ title: String, icon: ReaderIconMapping, action: ReadingControlAction) -> some View {
        Button { onAction(action) } label: {
            VStack(spacing: 4) {
                ReaderIcon(icon)
                Text(title).readerTypography(ReaderDesignMetrics.readerControlChapterSource, relativeTo: .caption2)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .contentShape(Rectangle())
        }
    }
}
