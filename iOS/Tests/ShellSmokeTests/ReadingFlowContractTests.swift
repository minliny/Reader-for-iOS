import Foundation
import XCTest
import ReaderCoreModels
import ReaderCoreProtocols
import ReaderShellValidation
import ReaderAppSupport

final class ReadingFlowContractTests: XCTestCase {
    
    // MARK: - ReadingFlowCoordinator Chapter Navigation
    
    func testCanMoveToPreviousChapterFalseWhenNoChapterSelected() throws {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        XCTAssertFalse(coordinator.canMoveToPreviousChapter)
    }
    
    func testCanMoveToNextChapterFalseWhenNoChapterSelected() throws {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        XCTAssertFalse(coordinator.canMoveToNextChapter)
    }
    
    func testCanMoveToPreviousChapterFalseWhenAtFirstChapter() throws {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        coordinator.tocItems = [
            TOCItem(chapterTitle: "Chapter 1", chapterURL: "/ch1", chapterIndex: 0),
            TOCItem(chapterTitle: "Chapter 2", chapterURL: "/ch2", chapterIndex: 1),
            TOCItem(chapterTitle: "Chapter 3", chapterURL: "/ch3", chapterIndex: 2)
        ]
        coordinator.selectedChapter = coordinator.tocItems.first
        XCTAssertFalse(coordinator.canMoveToPreviousChapter)
        XCTAssertTrue(coordinator.canMoveToNextChapter)
    }
    
    func testCanMoveToNextChapterFalseWhenAtLastChapter() throws {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        coordinator.tocItems = [
            TOCItem(chapterTitle: "Chapter 1", chapterURL: "/ch1", chapterIndex: 0),
            TOCItem(chapterTitle: "Chapter 2", chapterURL: "/ch2", chapterIndex: 1),
            TOCItem(chapterTitle: "Chapter 3", chapterURL: "/ch3", chapterIndex: 2)
        ]
        coordinator.selectedChapter = coordinator.tocItems.last
        XCTAssertTrue(coordinator.canMoveToPreviousChapter)
        XCTAssertFalse(coordinator.canMoveToNextChapter)
    }
    
    func testCanMoveToBothAtMiddleChapter() throws {
        let coordinator = ShellAssembly.makeMockReadingFlowCoordinator()
        coordinator.tocItems = [
            TOCItem(chapterTitle: "Chapter 1", chapterURL: "/ch1", chapterIndex: 0),
            TOCItem(chapterTitle: "Chapter 2", chapterURL: "/ch2", chapterIndex: 1),
            TOCItem(chapterTitle: "Chapter 3", chapterURL: "/ch3", chapterIndex: 2)
        ]
        coordinator.selectedChapter = coordinator.tocItems[1]
        XCTAssertTrue(coordinator.canMoveToPreviousChapter)
        XCTAssertTrue(coordinator.canMoveToNextChapter)
    }
    
    // MARK: - ChapterCacheEntry Contract
    
    func testChapterCacheEntryDefaultValues() throws {
        let entry = ChapterCacheEntry(
            sourceID: "s1",
            bookURL: "b1",
            chapterURL: "c1",
            chapterTitle: "Test"
        )
        XCTAssertEqual(entry.status, .notCached)
        XCTAssertNil(entry.contentHTML)
        XCTAssertNil(entry.contentMarkdown)
    }
    
    func testChapterCacheEntryWithContent() throws {
        let entry = ChapterCacheEntry(
            sourceID: "s1",
            bookURL: "b1",
            chapterURL: "c1",
            chapterTitle: "Test",
            status: .cached,
            contentHTML: "<p>HTML</p>",
            contentMarkdown: "Markdown"
        )
        XCTAssertEqual(entry.contentHTML, "<p>HTML</p>")
        XCTAssertEqual(entry.contentMarkdown, "Markdown")
    }
}
