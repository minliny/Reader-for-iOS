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
    var isManga = false
    var tocURL: String? = nil
    var id: Identity { .init(sourceId: sourceId, bookId: bookId) }

    var displaySource: String {
        if let sourceName, !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return Self.cleanDisplaySourceName(sourceName)
        }
        return URL(string: sourceId)?.host ?? sourceId
    }

    private static func cleanDisplaySourceName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var index = trimmed.unicodeScalars.startIndex
        var strippedDecorative = false
        while index < trimmed.unicodeScalars.endIndex {
            let scalar = trimmed.unicodeScalars[index].value
            let decorative = (0x1F000...0x1FAFF).contains(scalar) ||
                (0x2600...0x27BF).contains(scalar) ||
                (0x2300...0x23FF).contains(scalar) ||
                (0x25A0...0x25FF).contains(scalar) ||
                (0x2B00...0x2BFF).contains(scalar) ||
                (0xFE00...0xFE0F).contains(scalar) ||
                scalar == 0x200D ||
                scalar == 0x20E3 ||
                (0xE0020...0xE007F).contains(scalar)
            if decorative {
                strippedDecorative = true
                index = trimmed.unicodeScalars.index(after: index)
                continue
            }
            let separator = scalar <= 0x20 || scalar == 0x3000 || scalar == 0x00B7 || scalar == 0x2022 || scalar == 0x007C
            if strippedDecorative && separator {
                index = trimmed.unicodeScalars.index(after: index)
                continue
            }
            break
        }
        let cleaned = String(trimmed.unicodeScalars[index...]).trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? trimmed : cleaned
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
                  lastChapter: shelfBook.lastChapter, sourceName: shelfBook.sourceName, kind: shelfBook.kind,
                  isManga: shelfBook.contentKind == .manga)
    }

    init(detail: M2BookDetailData, sourceName: String?) {
        self.init(sourceId: detail.sourceId, bookId: detail.book.bookId, title: detail.book.title,
                  author: detail.book.authorIdentity?.label ?? detail.book.author, coverURL: detail.book.coverUrl,
                  intro: detail.book.intro, lastChapter: detail.book.lastChapter, sourceName: sourceName,
                  kind: detail.book.kind, variables: detail.variables, isManga: detail.contentKind == .manga, tocURL: detail.tocUrl)
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
        .overlay {
            RoundedRectangle(cornerRadius: radius)
                .strokeBorder(theme.outline, lineWidth: 1)
        }
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
