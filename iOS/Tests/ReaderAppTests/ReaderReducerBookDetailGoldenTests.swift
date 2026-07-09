import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Book-detail Golden Tests — B2 book-detail 链路闭环
///
/// 验证 ReaderReducer 消费 book-detail 事件后，AppNavigationState 与 ReaderViewState
/// 正确更新，对齐 state-rule.fixtures.json 中 `book-detail-error-requires-error-pagestate` 规则：
/// - open book-detail → route.push(.bookDetail)，routeId == .bookDetail
/// - book-detail data loaded → viewState.components 为 book-detail 标准组件树
/// - back → route 回退到来源 route（bookshelf）
/// - error → route.push(.stateError)，pageState == .error（error 态反映到 pageState）
@MainActor
final class ReaderReducerBookDetailGoldenTests: XCTestCase {

    // MARK: - Golden: open book-detail → route.push(.bookDetail)

    func testGolden_bookDetailOpen_pushesBookDetailRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .book_detail_open,
            payload: [
                "bookId": AnyCodable("bk-001"),
                "title": AnyCodable("长夜余火"),
                "author": AnyCodable("爱潜水的乌贼")
            ]
        ))

        XCTAssertNotNil(nav.navigationPath.last)
        XCTAssertEqual(nav.navigationPath.count, 1)

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .bookDetail)
    }

    // MARK: - Golden: book-detail data loaded → components 为标准组件树

    func testGolden_bookDetail_components_loadedTree() {
        let components = ViewStateComponentFactory.components(for: .bookDetail)

        // 标准组件树：BackTopBar + BookHero + BookIntro + DirectoryPreview + ReadButton + AddToShelfButton
        XCTAssertEqual(components.count, 6)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .bookHero)
        XCTAssertEqual(components[2].type, .bookIntro)
        XCTAssertEqual(components[3].type, .directoryPreview)
        XCTAssertEqual(components[4].type, .readButton)
        XCTAssertEqual(components[5].type, .addToShelfButton)
    }

    func testGolden_bookDetail_viewState_derivesBookDetailRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .book_detail_open,
            payload: ["bookId": AnyCodable("bk-001"), "title": AnyCodable("长夜余火")]
        ))

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .bookDetail)
        XCTAssertFalse(vs.components.isEmpty)
        XCTAssertEqual(vs.components.first?.type, .backTopBar)
        XCTAssertEqual(vs.pageState, .defaultValue)
    }

    // MARK: - Golden: back → route 回退到来源 route

    func testGolden_bookDetailBack_popsToSourceRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // 来源：bookshelf → push book-detail
        reducer.dispatch(UiEvent(
            type: .book_detail_open,
            payload: ["bookId": AnyCodable("bk-001"), "title": AnyCodable("长夜余火")]
        ))
        XCTAssertEqual(ReaderViewState(from: nav).routeId, .bookDetail)

        // back
        reducer.dispatch(UiEvent(type: .route_pop))

        XCTAssertTrue(nav.navigationPath.isEmpty)
        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .bookshelf)
    }

    // MARK: - Golden: error → pageState == .error
    // 对齐 state-rule.fixtures.json `book-detail-error-requires-error-pagestate`：
    // book-detail error 非空时 pageState 必须为 error 或 source-unavailable

    func testGolden_bookDetailError_showsErrorPageState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        // 先打开 book-detail
        reducer.dispatch(UiEvent(
            type: .book_detail_open,
            payload: ["bookId": AnyCodable("bk-001"), "title": AnyCodable("长夜余火")]
        ))
        XCTAssertEqual(ReaderViewState(from: nav).pageState, .defaultValue)

        // 发生错误：route.push(stateError)
        reducer.dispatch(UiEvent(
            type: .route_push,
            payload: ["route": AnyCodable("state-error"), "message": AnyCodable("加载失败")]
        ))

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .stateError)
        XCTAssertEqual(vs.pageState, .error,
                       "book-detail error 态必须反映到 pageState（book-detail-error-requires-error-pagestate）")
    }

    // MARK: - Golden: coordinator.openBookDetail dispatches correct event

    func testGolden_coordinatorOpenBookDetail_pushesRoute() {
        let nav = AppNavigationState()
        let coordinator = ReaderCoordinator(navigationState: nav)

        coordinator.openBookDetail(bookId: "bk-001", title: "长夜余火", author: "爱潜水的乌贼")

        XCTAssertNotNil(nav.navigationPath.last)
        if let route = nav.navigationPath.last,
           case .bookDetail(let bookURL, let title, let author) = route {
            XCTAssertEqual(bookURL, "bk-001")
            XCTAssertEqual(title, "长夜余火")
            XCTAssertEqual(author, "爱潜水的乌贼")
        } else {
            XCTFail("Expected .bookDetail route")
        }
    }

    // MARK: - Golden: book-detail → bookDetailToc (directory preview)

    func testGolden_bookDetailTocOpen_pushesBookDetailTocRoute() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)

        reducer.dispatch(UiEvent(
            type: .book_directory_open,
            payload: ["bookId": AnyCodable("bk-001"), "title": AnyCodable("目录")]
        ))

        let vs = ReaderViewState(from: nav)
        XCTAssertEqual(vs.routeId, .bookDetailTocPreview)
    }
}
