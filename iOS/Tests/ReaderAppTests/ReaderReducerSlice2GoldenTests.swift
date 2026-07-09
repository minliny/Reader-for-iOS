import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Slice 2 Golden Tests — bookshelf → immersive reading flow
///
/// 验证 ReaderReducer 消费 Slice 2 事件后，AppNavigationState 正确更新：
/// - book_open / book_detail_open → route.push(bookDetail)
/// - reader_enter / reader_entry_coverToImmersive / reader_entry_actionToImmersive → enterImmersiveReading
/// - book_directory_open → route.push(bookDetailToc)
///
/// 同时验证 ReaderCoordinator.openBook 落地 P0-05：
/// - 打开书进入 immersive-reading
/// - latest-intent-wins（连续点击只保留最后目标）
///
/// 契约对齐（CONTRACT_FIRST_NATIVE_UI_PLAN.md §9 Phase 3 Slice 2）：
/// - 事件：book.open / book.detail.open / reader.enter / reader.entry.* / book.directory.open
/// - 状态：AppNavigationState.navigationPath / readerContext
/// - 派生：ReaderViewState.components（bookshelf fixture 组件组合）
@MainActor
final class ReaderReducerSlice2GoldenTests: XCTestCase {

    // MARK: - Golden: book.open → route.push(bookDetail)

    func testGolden_bookOpen_pushesBookDetail() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .book_open,
            payload: ["bookId": AnyCodable("bk-001"), "title": AnyCodable("长夜余火")]
        ))

        XCTAssertNotNil(nav.navigationPath.last)
        if let route = nav.navigationPath.last,
           case .bookDetail(let bookURL, let title, _) = route {
            XCTAssertEqual(bookURL, "bk-001")
            XCTAssertEqual(title, "长夜余火")
        } else {
            XCTFail("Expected .bookDetail route, got \(String(describing: nav.navigationPath.last))")
        }
    }

    // MARK: - Golden: book.detail.open → route.push(bookDetail)

    func testGolden_bookDetailOpen_pushesBookDetail() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .book_detail_open,
            payload: ["bookId": AnyCodable("bk-002"), "title": AnyCodable("诡秘之主")]
        ))

        XCTAssertNotNil(nav.navigationPath.last)
        if let route = nav.navigationPath.last,
           case .bookDetail(let bookURL, _, _) = route {
            XCTAssertEqual(bookURL, "bk-002")
        } else {
            XCTFail("Expected .bookDetail route")
        }
    }

    // MARK: - Golden: reader.enter → enterImmersiveReading

    func testGolden_readerEnter_entersImmersive() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .reader_enter,
            payload: ["bookId": AnyCodable("bk-003"), "chapterURL": AnyCodable("ch://1")]
        ))

        XCTAssertNotNil(nav.readerContext)
        XCTAssertEqual(nav.readerContext?.bookID, "bk-003")
        XCTAssertEqual(nav.readerContext?.source, .actionToImmersive)
    }

    // MARK: - Golden: reader.entry.coverToImmersive → source = .coverToImmersive

    func testGolden_readerEntryCoverToImmersive_setsSource() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .reader_entry_coverToImmersive,
            payload: ["bookId": AnyCodable("bk-004")]
        ))

        XCTAssertNotNil(nav.readerContext)
        XCTAssertEqual(nav.readerContext?.bookID, "bk-004")
        XCTAssertEqual(nav.readerContext?.source, .coverToImmersive)
    }

    // MARK: - Golden: reader.entry.actionToImmersive → source = .actionToImmersive

    func testGolden_readerEntryActionToImmersive_setsSource() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .reader_entry_actionToImmersive,
            payload: ["bookId": AnyCodable("bk-005")]
        ))

        XCTAssertNotNil(nav.readerContext)
        XCTAssertEqual(nav.readerContext?.bookID, "bk-005")
        XCTAssertEqual(nav.readerContext?.source, .actionToImmersive)
    }

    // MARK: - Golden: book.directory.open → route.push(bookDetailToc)

    func testGolden_bookDirectoryOpen_pushesBookDetailToc() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .book_directory_open,
            payload: ["bookId": AnyCodable("bk-001"), "title": AnyCodable("目录")]
        ))

        XCTAssertNotNil(nav.navigationPath.last)
        if let route = nav.navigationPath.last,
           case .bookDetailToc(let bookURL, let title) = route {
            XCTAssertEqual(bookURL, "bk-001")
            XCTAssertEqual(title, "目录")
        } else {
            XCTFail("Expected .bookDetailToc route")
        }
    }

    // MARK: - Golden: coordinator.openBook latest-intent-wins (P0-05)

    func testGolden_openBook_latestIntentWins() {
        let nav = AppNavigationState()
        let coordinator = ReaderCoordinator(navigationState: nav)

        coordinator.openBook("bk-001")
        XCTAssertEqual(nav.readerContext?.bookID, "bk-001")

        coordinator.openBook("bk-002")
        XCTAssertEqual(nav.readerContext?.bookID, "bk-002")
    }

    // MARK: - Golden: viewState.components for bookshelf route

    func testGolden_viewState_components_bookshelf() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .mainTab_select,
            payload: ["tab": AnyCodable("bookshelf")]
        ))

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .bookshelf)
        XCTAssertFalse(vs.components.isEmpty)
        XCTAssertEqual(vs.components.first?.type, .appTopBar)
    }

    // MARK: - Golden: coordinator.openBook enters immersive reading

    func testGolden_coordinatorOpenBook_entersImmersive() {
        let nav = AppNavigationState()
        let coordinator = ReaderCoordinator(navigationState: nav)

        coordinator.openBook("bk-001")

        XCTAssertNotNil(nav.readerContext)
        XCTAssertEqual(nav.readerContext?.bookID, "bk-001")
        XCTAssertEqual(nav.readerContext?.source, .actionToImmersive)

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .immersiveReading)
        XCTAssertFalse(vs.components.isEmpty)
        XCTAssertEqual(vs.components.first?.type, .readerBase)
    }
}
