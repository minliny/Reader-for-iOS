import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

@MainActor
public final class ReadingFlowCoordinator: ObservableObject {
    @Published public var selectedSource: BookSource?
    @Published public var searchResults: [SearchResultItem] = []
    @Published public var selectedBook: SearchResultItem?
    @Published public var tocItems: [TOCItem] = []
    @Published public var selectedChapter: TOCItem?
    @Published public var contentPage: ContentPage?
    @Published public var isLoading = false
    @Published public var currentError: ReaderError?

    public let bookSourceRepository: BookSourceRepository
    public let bookSourceDecoder: BookSourceDecoder
    public let searchService: SearchService
    public let tocService: TOCService
    public let contentService: ContentService
    public let errorLogger: ErrorLogger

    public init(
        bookSourceRepository: BookSourceRepository,
        bookSourceDecoder: BookSourceDecoder,
        searchService: SearchService,
        tocService: TOCService,
        contentService: ContentService,
        errorLogger: ErrorLogger
    ) {
        self.bookSourceRepository = bookSourceRepository
        self.bookSourceDecoder = bookSourceDecoder
        self.searchService = searchService
        self.tocService = tocService
        self.contentService = contentService
        self.errorLogger = errorLogger
    }

    public func importBookSource(from data: Data) async {
        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            let source = try bookSourceDecoder.decodeBookSource(from: data)
            try await bookSourceRepository.save(source)
            applySourceSelection(source)
        } catch let error as ReaderError {
            currentError = error
            await logError(error)
        } catch {
            let readerError = ReaderError(
                code: .unknown,
                message: "Import failed: \(error.localizedDescription)"
            )
            currentError = readerError
            await logError(readerError)
        }
    }

    public func search(keyword: String) async {
        guard let source = selectedSource else { return }

        isLoading = true
        currentError = nil
        searchResults.removeAll()
        resetBookSelectionState()
        defer { isLoading = false }

        do {
            let query = SearchQuery(keyword: keyword, page: 1)
            searchResults = try await searchService.search(source: source, query: query)
        } catch let error as ReaderError {
            currentError = error
            await logError(error, stage: "SEARCH")
        } catch {
            let readerError = ReaderError(
                code: .unknown,
                message: "Search failed: \(error.localizedDescription)"
            )
            currentError = readerError
            await logError(readerError, stage: "SEARCH")
        }
    }

    public func selectBook(_ book: SearchResultItem) async {
        selectedBook = book
        resetChapterSelectionState()
        tocItems.removeAll()

        guard let source = selectedSource else { return }
        let detailURL = book.detailURL

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            tocItems = try await tocService.fetchTOC(source: source, detailURL: detailURL)
        } catch let error as ReaderError {
            currentError = error
            await logError(error, stage: "TOC")
        } catch {
            let readerError = ReaderError(
                code: .unknown,
                message: "TOC failed: \(error.localizedDescription)"
            )
            currentError = readerError
            await logError(readerError, stage: "TOC")
        }
    }

    public func selectChapter(_ chapter: TOCItem) async {
        selectedChapter = chapter
        contentPage = nil

        guard let source = selectedSource else { return }

        isLoading = true
        currentError = nil
        defer { isLoading = false }

        do {
            contentPage = try await contentService.fetchContent(source: source, chapterURL: chapter.chapterURL)
        } catch let error as ReaderError {
            currentError = error
            await logError(error, stage: "CONTENT")
        } catch {
            let readerError = ReaderError(
                code: .unknown,
                message: "Content failed: \(error.localizedDescription)"
            )
            currentError = readerError
            await logError(readerError, stage: "CONTENT")
        }
    }

    private func logError(_ error: ReaderError, stage: String? = nil) async {
        let log = StructuredErrorLog.from(
            error,
            stage: stage,
            sampleId: selectedSource?.id
        )
        await errorLogger.log(log)
    }

    private func applySourceSelection(_ source: BookSource) {
        selectedSource = source
        searchResults.removeAll()
        resetBookSelectionState()
        currentError = nil
    }

    private func resetBookSelectionState() {
        selectedBook = nil
        tocItems.removeAll()
        resetChapterSelectionState()
    }

    private func resetChapterSelectionState() {
        selectedChapter = nil
        contentPage = nil
    }
}
