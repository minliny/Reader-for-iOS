import XCTest
@testable import ReaderApp
import ReaderAppSupport
import ReaderAppPersistence
import ReaderCoreModels
@testable import ReaderShellValidation

/// Bookshelf structure alignment tests.
///
/// Source of truth is `Reader UI/frontend-demo-optimized/render-runtime.js` and
/// `Reader UI/frontend-demo-optimized/styles/00-foundation.css`, not screenshots.
final class BookshelfHTMLCSSStructureAlignmentTests: XCTestCase {

    func testSectionHeaderTokensMatchDemoCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookshelfSectionHeadMinHeight, 38)
        XCTAssertEqual(ReaderDesignTokens.bookshelfSectionHeadGap, 12)
        XCTAssertEqual(ReaderDesignTokens.bookshelfSectionActionGap, 8)
        XCTAssertEqual(ReaderDesignTokens.bookshelfSectionActionSize, 34)
    }

    func testBookshelfRootContentTokensMatchDemoCSS() {
        XCTAssertEqual(ReaderDesignTokens.demoContentGap, 10)
        XCTAssertEqual(ReaderDesignTokens.demoContentHorizontalPadding, 16)
        XCTAssertEqual(ReaderDesignTokens.demoContentVerticalPadding, 14)
    }

    func testDemoBookshelfFixtureMatchesFrontendDemoDefaultContent() {
        XCTAssertEqual(DemoBookshelfFixture.items.count, 11)
        XCTAssertEqual(DemoBookshelfFixture.items.first?.title, "长夜余火")
        XCTAssertEqual(DemoBookshelfFixture.items.first?.author, "爱潜水的乌贼")
        XCTAssertEqual(DemoBookshelfFixture.items.first?.coverURL, "demo-cover://longNight")
        XCTAssertEqual(DemoBookshelfFixture.items.first?.readingProgress, 0.38)
        XCTAssertEqual(DemoBookshelfFixture.items.first?.localChapterList?.count, 4)
        XCTAssertEqual(DemoBookshelfFixture.items[1].title, "诡秘之主")
        XCTAssertEqual(DemoBookshelfFixture.items[5].sourceID, "local-book")
    }

    func testContinueReadingCardTokensMatchDemoCSS() {
        XCTAssertEqual(ReaderDesignTokens.continueCardMinHeight, 100)
        XCTAssertEqual(ReaderDesignTokens.continueCardCoverWidth, 62)
        XCTAssertEqual(ReaderDesignTokens.continueCardActionButtonWidth, 82)
        XCTAssertEqual(ReaderDesignTokens.continueCardGap, 14)
        XCTAssertEqual(ReaderDesignTokens.continueCardVerticalPadding, 10)
        XCTAssertEqual(ReaderDesignTokens.continueCardHorizontalPadding, 16)
        XCTAssertEqual(ReaderDesignTokens.continueCardTitleFontSize, 20)
        XCTAssertEqual(ReaderDesignTokens.continueCardHeaderFontSize, 13)
        XCTAssertEqual(ReaderDesignTokens.continueActionButtonMinWidth, 74)
        XCTAssertEqual(ReaderDesignTokens.continueActionButtonMinHeight, 40)
        XCTAssertEqual(ReaderDesignTokens.continueCoverButtonWidth, 62)
        XCTAssertEqual(ReaderDesignTokens.bookCoverAspectRatio, 2.0 / 3.0)
    }

    func testBookGridTokensMatchDemoCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookGridColumns, 3)
        XCTAssertEqual(ReaderDesignTokens.bookGridRowSpacing, 16)
        XCTAssertEqual(ReaderDesignTokens.bookGridColumnSpacing, 30)
        XCTAssertEqual(ReaderDesignTokens.bookCardGap, 6)
    }

    func testBookListTokensMatchDemoCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookGridListRowSpacing, 10)
        XCTAssertEqual(ReaderDesignTokens.bookListCardMinHeight, 66)
        XCTAssertEqual(ReaderDesignTokens.bookListCoverWidth, 48)
        XCTAssertEqual(ReaderDesignTokens.bookListColumnGap, 10)
        XCTAssertEqual(ReaderDesignTokens.bookListRowGap, 2)
    }

    func testBookCoverAndTextTokensMatchDemoCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookCoverAspectRatio, 2.0 / 3.0)
        XCTAssertEqual(ReaderDesignTokens.bookCardTitleFontSize, 15)
        XCTAssertEqual(ReaderDesignTokens.bookCardMetaFontSize, 12)
        XCTAssertEqual(ReaderDesignTokens.bookCardTitleLineHeight, 1.22)
        XCTAssertEqual(ReaderDesignTokens.bookCardTitleLineLimit, 2)
        XCTAssertEqual(ReaderDesignTokens.bookCardMetaLineHeight, 1.25)
        XCTAssertEqual(ReaderDesignTokens.bookCoverFrameCornerRadius, 8)
        XCTAssertEqual(ReaderDesignTokens.bookListCoverCornerRadius, 6)
    }

    func testBookFocusLayerTokensMatchDemoHTMLCSSAndJS() {
        XCTAssertEqual(ReaderDesignTokens.bookFocusLongPressDuration, 0.56)
        XCTAssertEqual(ReaderDesignTokens.bookFocusMenuHorizontalInset, 18)
        XCTAssertEqual(ReaderDesignTokens.bookFocusMenuBottomGap, 12)
        XCTAssertEqual(ReaderDesignTokens.bookFocusMenuGap, 12)
        XCTAssertEqual(ReaderDesignTokens.bookFocusMenuPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.bookFocusMenuBorderOpacity, 0.54)
        XCTAssertEqual(ReaderDesignTokens.bookFocusBackdropOpacity, 0.34)
        XCTAssertEqual(ReaderDesignTokens.bookFocusCoverSize, 42)
        XCTAssertEqual(ReaderDesignTokens.bookFocusActionMinHeight, 54)
    }

    func testBookshelfMoreLayerTokensMatchDemoHTMLCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreMenuWidth, 238)
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreMenuTopGap, 8)
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreMenuRightGap, 2)
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreMenuGap, 8)
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreMenuPadding, 12)
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreActionMinHeight, 48)
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreActionIconColumn, 24)
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreActionGap, 10)
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreActionHorizontalPadding, 8)
        XCTAssertEqual(ReaderDesignTokens.bookshelfMoreBackdropOpacity, 0.18)
    }

    func testBookshelfBatchManagementTokensMatchDemoHTMLCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookBatchSummaryPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.bookBatchRowMinHeight, 62)
        XCTAssertEqual(ReaderDesignTokens.bookBatchSelectColumn, 28)
        XCTAssertEqual(ReaderDesignTokens.bookBatchCoverWidth, 34)
        XCTAssertEqual(ReaderDesignTokens.bookBatchSelectSize, 24)
        XCTAssertEqual(ReaderDesignTokens.bookBatchRowGap, 12)
    }

    func testBookshelfGroupManagementTokensMatchDemoHTMLCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookGroupListTopPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.bookGroupIconColumn, 24)
        XCTAssertEqual(ReaderDesignTokens.bookGroupRowGap, 12)
        XCTAssertEqual(ReaderDesignTokens.bookGroupRowHorizontalPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.bookGroupRowMinHeight, 68)
        XCTAssertEqual(ReaderDesignTokens.bookGroupAssignmentRowMinHeight, 58)
        XCTAssertEqual(ReaderDesignTokens.bookGroupActionMinHeight, 30)
        XCTAssertEqual(ReaderDesignTokens.bookGroupDeleteButtonSize, 30)
    }

    func testBookshelfLocalImportTokensMatchDemoHTMLCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookImportEntryIconColumn, 42)
        XCTAssertEqual(ReaderDesignTokens.bookImportEntryIconSize, 28)
        XCTAssertEqual(ReaderDesignTokens.bookImportEntryGap, 12)
        XCTAssertEqual(ReaderDesignTokens.bookImportEntryPadding, 16)
        XCTAssertEqual(ReaderDesignTokens.bookImportEntryButtonMinHeight, 34)
        XCTAssertEqual(ReaderDesignTokens.bookImportEntryButtonHorizontalPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.bookImportListRowMinHeight, 58)
    }

    func testBookSearchTokensMatchDemoHTMLCSS() {
        XCTAssertEqual(ReaderDesignTokens.searchEntryMinHeight, 44)
        XCTAssertEqual(ReaderDesignTokens.searchEntryIconColumn, 24)
        XCTAssertEqual(ReaderDesignTokens.searchEntryGap, 10)
        XCTAssertEqual(ReaderDesignTokens.searchEntryHorizontalPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.searchStateGap, 12)
        XCTAssertEqual(ReaderDesignTokens.searchStatePadding, 16)
        XCTAssertEqual(ReaderDesignTokens.searchHistoryRowMinHeight, 52)
        XCTAssertEqual(ReaderDesignTokens.searchHistoryIconColumn, 20)
        XCTAssertEqual(ReaderDesignTokens.searchHistoryActionColumn, 40)
        XCTAssertEqual(ReaderDesignTokens.searchHistoryRowGap, 10)
        XCTAssertEqual(ReaderDesignTokens.searchSectionActionMinHeight, 28)
        XCTAssertEqual(ReaderDesignTokens.searchResultListGap, 9)
        XCTAssertEqual(ReaderDesignTokens.searchResultRowMinHeight, 86)
        XCTAssertEqual(ReaderDesignTokens.searchResultCoverWidth, 46)
        XCTAssertEqual(ReaderDesignTokens.searchResultCoverHeight, 64)
        XCTAssertEqual(ReaderDesignTokens.searchResultStateColumn, 58)
        XCTAssertEqual(ReaderDesignTokens.searchResultActionColumn, 64)
        XCTAssertEqual(ReaderDesignTokens.searchResultRowGap, 8)
        XCTAssertEqual(ReaderDesignTokens.searchResultRowPadding, 10)
        XCTAssertEqual(ReaderDesignTokens.searchResultActionMinHeight, 28)
    }

    func testBookDirectoryPreviewTokensMatchDemoHTMLCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryListTopPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryFullGap, 10)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryFullHorizontalPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryFullTopPadding, 12)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryFullBottomPadding, 18)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryHeaderMinHeight, 44)
        XCTAssertEqual(ReaderDesignTokens.bookDirectorySwitchGap, 8)
        XCTAssertEqual(ReaderDesignTokens.bookDirectorySwitchButtonMinHeight, 34)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryRowMinHeight, 48)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryMarkerColumnWidth, 64)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryMarkerSize, 26)
        XCTAssertEqual(ReaderDesignTokens.bookDirectoryMarkerGap, 6)
    }

    func testBookDetailTokensMatchDemoHTMLCSS() {
        XCTAssertEqual(ReaderDesignTokens.bookDetailHeroCoverWidth, 86)
        XCTAssertEqual(ReaderDesignTokens.bookDetailHeroCoverHeight, 122)
        XCTAssertEqual(ReaderDesignTokens.bookDetailHeroGap, 14)
        XCTAssertEqual(ReaderDesignTokens.bookDetailHeroPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.bookDetailInlineSourceButtonMinHeight, 18)
        XCTAssertEqual(ReaderDesignTokens.bookDetailSummaryPadding, 14)
        XCTAssertEqual(ReaderDesignTokens.bookDetailSummaryGap, 8)
        XCTAssertEqual(ReaderDesignTokens.bookDetailChapterPreviewHeaderMinHeight, 48)
        XCTAssertEqual(ReaderDesignTokens.bookDetailInlineRouteMinHeight, 30)
        XCTAssertEqual(ReaderDesignTokens.bookDetailChapterPreviewRowMinHeight, 58)
    }

    @MainActor
    func testBookshelfViewCanInitializeWithDemoStructureState() {
        let view = BookshelfView(navigationState: AppNavigationState())
        XCTAssertNotNil(view)
    }

    @MainActor
    func testBookshelfBatchManagementViewCanInitializeWithDemoStructureState() {
        let view = BookshelfBatchManagementView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testBookshelfGroupManagementViewCanInitializeWithDemoStructureState() {
        let view = BookshelfGroupManagementView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testBookshelfLocalImportViewCanInitializeWithDemoStructureState() {
        let view = BookshelfLocalImportView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testSearchViewCanInitializeWithDemoStructureState() {
        let view = SearchView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testBookDirectoryPreviewViewCanInitializeWithDemoStructureState() {
        let view = BookDirectoryPreviewView(bookURL: "demo://book/long-night", title: "长夜余火")
        XCTAssertNotNil(view)
    }

    @MainActor
    func testBookDetailViewCanInitializeWithDemoStructureState() {
        let result = SearchResultItem(
            title: "长夜余火",
            detailURL: "demo://book/long-night",
            author: "爱潜水的乌贼",
            intro: "旧世界的余烬尚未冷却，新的秩序已经在废墟之上生长。"
        )
        let view = BookDetailView(result: result, sourceName: "优书网")
        XCTAssertNotNil(view)
    }

    @MainActor
    func testBookshelfItemDetailSheetUsesDemoPrimitiveStructure() {
        let item = BookshelfItem(
            id: "demo-book",
            sourceID: "demo-source",
            sourceName: "优书网",
            bookURL: "demo://book/long-night",
            title: "长夜余火",
            author: "爱潜水的乌贼",
            latestChapter: "第 32 章 雨夜",
            addedAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_010_000),
            lastReadChapterTitle: "第 32 章 雨夜",
            lastReadChapterURL: "demo://chapter/32",
            readingProgress: 0.38
        )
        let view = BookshelfItemDetailView(item: item, onEnterImmersive: { _ in })
        XCTAssertNotNil(view)
    }

    @MainActor
    func testBookmarksSheetAndRowUseDemoPrimitiveStructure() {
        let sheet = BookmarksListView(bookId: "demo-book", sourceId: "demo-source", bookTitle: "长夜余火")
        let bookmark = ReaderCoreBookmark(
            time: 1_800_000_000_000,
            bookName: "长夜余火",
            bookAuthor: "爱潜水的乌贼",
            chapterIndex: 31,
            chapterPosition: 38,
            chapterName: "第 32 章 雨夜",
            bookText: "雨声落在旧窗上。",
            content: ""
        )
        let row = BookmarkRowView(bookmark: bookmark, onOpen: {}, onDelete: {})
        XCTAssertNotNil(sheet)
        XCTAssertNotNil(row)
    }
}
