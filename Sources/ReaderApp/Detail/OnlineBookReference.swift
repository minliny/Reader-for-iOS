import Foundation
import ReaderCoreBridge
import ReaderDesign
import ReaderHost
import SwiftUI

struct OnlineBookReference: Hashable, Identifiable, Sendable {
    struct Identity: Hashable, Sendable {
        let sourceId: String
        let bookId: String
    }

    let sourceId: String
    let bookId: String
    let title: String
    var author: String? = nil
    var coverURL: String? = nil
    var intro: String? = nil
    var lastChapter: String? = nil
    var sourceName: String? = nil
    var kind: String? = nil
    var variables: [String: String]? = nil
    var id: Identity { .init(sourceId: sourceId, bookId: bookId) }

    var displaySource: String {
        if let sourceName, !sourceName.isEmpty { return sourceName }
        return URL(string: sourceId)?.host ?? sourceId
    }

    var detailParams: M2BookDetailParams {
        .init(sourceId: sourceId, book: .init(bookId: bookId, title: title, author: author,
             coverUrl: coverURL, intro: intro, kind: kind, lastChapter: lastChapter, variables: variables),
              bookUrl: bookId)
    }

    var shelfQuery: BookshelfGetParams { .init(sourceId: sourceId, bookId: bookId) }
}

extension OnlineBookReference {
    init(shelfBook: BookshelfEntryData) {
        self.init(sourceId: shelfBook.sourceId, bookId: shelfBook.bookId, title: shelfBook.title,
                  author: shelfBook.author, coverURL: shelfBook.coverUrl, intro: shelfBook.intro,
                  lastChapter: shelfBook.lastChapter, sourceName: shelfBook.sourceName, kind: shelfBook.kind)
    }

    init(detail: M2BookDetailData, sourceName: String?) {
        self.init(sourceId: detail.sourceId, bookId: detail.book.bookId, title: detail.book.title,
                  author: detail.book.authorIdentity?.label ?? detail.book.author, coverURL: detail.book.coverUrl,
                  intro: detail.book.intro, lastChapter: detail.book.lastChapter, sourceName: sourceName,
                  kind: detail.book.kind, variables: detail.variables)
    }
}

struct OnlineBookCover: View {
    let book: OnlineBookReference
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat
    var network: NetworkAndWebHost? = nil

    @Environment(\.readerTheme) private var theme
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            theme.coverPlaceholder
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
                    ReaderIcon(ReaderIconRegistry.shelf).foregroundStyle(theme.accent)
                    Text(book.title).readerTypography(ReaderDesignMetrics.shelfAuthor, relativeTo: .caption)
                        .lineLimit(3)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CGFloat(ReaderDesignMetrics.spaceExtraSmall))
            }
        }
        .frame(width: width, height: height)
        .clipShape(.rect(cornerRadius: radius))
        .accessibilityHidden(true)
        .task(id: book.coverURL) {
            image = nil
            guard let network, let url = book.coverURL else { return }
            do {
                let reply = try await network.fetch(.init(timeoutMs: 5_000, url: url, responseAsset: true))
                guard !Task.isCancelled, let data = reply.bodyBase64.flatMap({ Data(base64Encoded: $0) }) else { return }
                image = UIImage(data: data)
            } catch {
                // The result card and its action remain usable with the cover fallback.
            }
        }
    }
}
