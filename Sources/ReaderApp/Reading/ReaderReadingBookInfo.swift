import SwiftUI

/// Read-only active-book information. Shelf removal remains in the shelf
/// owner, so closing this sheet cannot invalidate a live reading session.
struct ReaderReadingBookInfo: View {
    @ObservedObject var model: ReaderApplicationModel
    let book: ReaderBook
    @State private var details: ReaderBook?
    @State private var failure: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 16) {
            HStack { Button("关闭") { dismiss() }; Spacer(); Text("书籍信息").font(ReaderTypography.font(.controlHeader)); Spacer() }
            if let value = details {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(value.title).font(ReaderTypography.font(.pageTitle))
                        if !value.author.isEmpty { Text(value.author) }
                        Text("\(value.chapterCount) 章")
                        if let name = value.sourceName { Text(name) }
                        if let group = value.group, !group.isEmpty { Text("分组：" + group) }
                        if let intro = value.intro, !intro.isEmpty { Text(intro) }
                    }.font(ReaderTypography.font(.body)).frame(maxWidth: .infinity, alignment: .leading)
                }
            } else { ReaderPageState(title: failure ?? "正在读取书籍信息", loading: failure == nil, actionTitle: failure == nil ? nil : "重试") { Task { await load() } } }
        }.padding(20).background(ReaderPalette(scheme).paper).task { await load() }
    }
    private func load() async {
        failure = nil
        guard let service = model.libraryService as? any ReaderLibraryFeatures else { details = book; return }
        do { details = try await service.bookDetails(for: book); if details == nil { failure = "这本书已不在书架中" } }
        catch { failure = error.localizedDescription }
    }
}
