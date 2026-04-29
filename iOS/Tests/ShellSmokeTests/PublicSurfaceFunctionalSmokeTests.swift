import XCTest
@testable import ReaderShellValidation
import ReaderCoreModels

final class PublicSurfaceFunctionalSmokeTests: XCTestCase {

    // MARK: - ShellAssembly Tests
    
    @MainActor
    func testShellAssemblyCreatesValidCoordinator() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        
        XCTAssertNotNil(coordinator)
        XCTAssertTrue(coordinator.searchService is MockSearchService)
        XCTAssertTrue(coordinator.tocService is MockTOCService)
        XCTAssertTrue(coordinator.contentService is MockContentService)
    }

    // MARK: - ReadingFlowCoordinator Tests
    
    @MainActor
    func testCoordinatorInitialState() {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        
        XCTAssertNil(coordinator.selectedSource)
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isLoading)
    }

    @MainActor
    func testCoordinatorSelectBookSetsSelectedBook() async {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        
        let book = SearchResultItem(
            title: "Test Book",
            detailURL: "https://example.com/book"
        )
        
        await coordinator.selectBook(book)
        
        XCTAssertEqual(coordinator.selectedBook, book)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    @MainActor
    func testCoordinatorSelectChapterSetsSelectedChapter() async {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        
        let chapter = TOCItem(
            chapterTitle: "Chapter 1",
            chapterURL: "https://example.com/ch1",
            chapterIndex: 1
        )
        
        await coordinator.selectChapter(chapter)
        
        XCTAssertEqual(coordinator.selectedChapter, chapter)
    }

    @MainActor
    func testCoordinatorSearchReturnsEmptyWithoutSource() async {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        
        await coordinator.search(keyword: "test")
        
        XCTAssertTrue(coordinator.searchResults.isEmpty)
        XCTAssertNil(coordinator.currentError)
        XCTAssertFalse(coordinator.isLoading)
    }

    @MainActor
    func testCoordinatorSearchClearsPreviousState() async {
        let coordinator = ShellAssembly.makeDefaultReadingFlowCoordinator()
        
        let book = SearchResultItem(
            title: "Test Book",
            detailURL: "https://example.com/book"
        )
        await coordinator.selectBook(book)
        
        let chapter = TOCItem(
            chapterTitle: "Chapter 1",
            chapterURL: "https://example.com/ch1",
            chapterIndex: 1
        )
        await coordinator.selectChapter(chapter)
        
        await coordinator.search(keyword: "another")
        
        XCTAssertNil(coordinator.selectedBook)
        XCTAssertTrue(coordinator.tocItems.isEmpty)
        XCTAssertNil(coordinator.selectedChapter)
        XCTAssertNil(coordinator.contentPage)
    }

    // MARK: - SearchResultItem Model Tests
    
    func testSearchResultItemInitialization() {
        let item = SearchResultItem(
            title: "Test Book",
            detailURL: "https://example.com/book",
            author: "Author"
        )
        
        XCTAssertEqual(item.title, "Test Book")
        XCTAssertEqual(item.detailURL, "https://example.com/book")
        XCTAssertEqual(item.author, "Author")
    }

    func testSearchResultItemEquality() {
        let item1 = SearchResultItem(
            title: "Same",
            detailURL: "https://example.com/book"
        )
        let item2 = SearchResultItem(
            title: "Same",
            detailURL: "https://example.com/book"
        )
        let item3 = SearchResultItem(
            title: "Different",
            detailURL: "https://example.com/book2"
        )
        
        XCTAssertEqual(item1, item2)
        XCTAssertNotEqual(item1, item3)
    }

    // MARK: - TOCItem Model Tests
    
    func testTOCItemInitialization() {
        let chapter = TOCItem(
            chapterTitle: "Chapter 1",
            chapterURL: "https://example.com/ch1",
            chapterIndex: 1
        )
        
        XCTAssertEqual(chapter.chapterTitle, "Chapter 1")
        XCTAssertEqual(chapter.chapterURL, "https://example.com/ch1")
        XCTAssertEqual(chapter.chapterIndex, 1)
    }

    func testTOCItemEquality() {
        let chapter1 = TOCItem(
            chapterTitle: "Chapter 1",
            chapterURL: "https://example.com/ch1",
            chapterIndex: 1
        )
        let chapter2 = TOCItem(
            chapterTitle: "Chapter 1",
            chapterURL: "https://example.com/ch1",
            chapterIndex: 1
        )
        let chapter3 = TOCItem(
            chapterTitle: "Chapter 2",
            chapterURL: "https://example.com/ch2",
            chapterIndex: 2
        )
        
        XCTAssertEqual(chapter1, chapter2)
        XCTAssertNotEqual(chapter1, chapter3)
    }
}
