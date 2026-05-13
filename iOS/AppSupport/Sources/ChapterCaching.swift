import Foundation

public protocol ChapterCaching: AnyObject {
    func loadEntry(chapterURL: String, sourceID: String) throws -> ChapterCacheEntry?
    func saveEntry(_ entry: ChapterCacheEntry) throws
    func removeEntry(chapterURL: String, sourceID: String) throws
}

public extension ChapterCaching {
    func loadContent(chapterURL: String, sourceID: String) throws -> (html: String?, markdown: String?)? {
        guard let entry = try loadEntry(chapterURL: chapterURL, sourceID: sourceID),
              entry.status == .cached else {
            return nil
        }
        return (entry.contentHTML, entry.contentMarkdown)
    }
    
    func saveContent(chapterURL: String, sourceID: String, bookURL: String, chapterTitle: String, html: String?, markdown: String?) throws {
        let entry = ChapterCacheEntry(
            sourceID: sourceID,
            bookURL: bookURL,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            status: .cached,
            contentHTML: html,
            contentMarkdown: markdown
        )
        try saveEntry(entry)
    }
}
