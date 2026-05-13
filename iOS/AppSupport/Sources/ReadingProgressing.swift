import Foundation

public protocol ReadingProgressing: AnyObject {
    func saveProgress(_ progress: ReadingProgress) throws
    func loadProgress(bookID: String) throws -> ReadingProgress?
    func removeProgress(bookID: String) throws
}

public protocol BookshelfProgressing: AnyObject {
    func updateProgress(bookID: String, progress: Double, chapterTitle: String?, chapterURL: String?) throws
    func loadProgressSummary(bookID: String) throws -> (progress: Double, chapterTitle: String?, chapterURL: String?)?
}

public final class UnifiedProgressManager {
    private let readingProgressStore: ReadingProgressing
    private let bookshelfProgressStore: BookshelfProgressing?
    
    public init(
        readingProgressStore: ReadingProgressing,
        bookshelfProgressStore: BookshelfProgressing? = nil
    ) {
        self.readingProgressStore = readingProgressStore
        self.bookshelfProgressStore = bookshelfProgressStore
    }
    
    public func saveCurrentProgress(
        bookID: String,
        sourceID: String,
        bookURL: String,
        chapterURL: String,
        chapterTitle: String,
        progressRatio: Double
    ) throws {
        let progress = ReadingProgress(
            bookID: bookID,
            sourceID: sourceID,
            bookURL: bookURL,
            chapterURL: chapterURL,
            chapterTitle: chapterTitle,
            progressRatio: progressRatio
        )
        
        // Save to precise progress store (source of truth)
        try readingProgressStore.saveProgress(progress)
        
        // Sync summary to bookshelf store if available
        try bookshelfProgressStore?.updateProgress(
            bookID: bookID,
            progress: progressRatio,
            chapterTitle: chapterTitle,
            chapterURL: chapterURL
        )
    }
    
    public func loadCurrentProgress(bookID: String) throws -> ReadingProgress? {
        return try readingProgressStore.loadProgress(bookID: bookID)
    }
}
