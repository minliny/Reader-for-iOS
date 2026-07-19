import ReaderUIContract

/// Explicit Native ownership for the 24 capability-complete routes introduced by Reader UI 3.0.
///
/// The ScreenGraph remains shadow authority until device proof and promotion. This registry does
/// not invent route actions: it freezes the expected shell and top-level Native structure so every
/// route can be audited and rendered through registered structural adapters without becoming a
/// generic bookshelf fallback.
enum ReaderContract30Renderer: String, CaseIterable, Sendable {
    case contractTree = "contract-tree"
    case readerHostComposite = "reader-host-composite"
}

struct ReaderContract30RoutePage: Equatable, Identifiable, Sendable {
    let routeId: ReaderUIContract.RouteId
    let shell: ReaderUIContract.RouteShell
    let renderer: ReaderContract30Renderer
    let topLevelTypes: [ReaderUIContract.ComponentType]

    var id: ReaderUIContract.RouteId { routeId }
}

enum ReaderContract30RouteRegistry {
    private static func page(
        _ routeId: ReaderUIContract.RouteId,
        _ shell: ReaderUIContract.RouteShell,
        _ topLevelTypes: [ReaderUIContract.ComponentType],
        renderer: ReaderContract30Renderer = .contractTree
    ) -> ReaderContract30RoutePage {
        .init(
            routeId: routeId,
            shell: shell,
            renderer: renderer,
            topLevelTypes: topLevelTypes
        )
    }

    /// Authored directly against generated RouteId and ComponentType cases. A generated rename or
    /// removal therefore fails compilation; exact membership tests catch an unregistered addition.
    static let all: [ReaderContract30RoutePage] = [
        page(.onboardingWelcome, .flowShell, [.appShellStructure]),
        page(.onboardingCapabilitySetup, .flowShell, [.permissionRequiredPage]),
        page(.permissionRecovery, .flowShell, [.permissionRequiredPage]),

        page(.localFormatSupport, .libraryShell, [.backTopBar, .localBookImportPage]),
        page(
            .pdfReader,
            .readerShell,
            [.readerBase, .readerTopArea],
            renderer: .readerHostComposite
        ),
        page(
            .mangaReader,
            .readerShell,
            [.readerBase, .readerTopArea],
            renderer: .readerHostComposite
        ),

        page(.httpTtsManagement, .settingsShell, [.backTopBar, .settingsGeneralPage]),
        page(.httpTtsEditor, .settingsShell, [.backTopBar, .sourceFormPage]),
        page(.httpTtsTest, .settingsShell, [.backTopBar, .globalStatePage]),
        page(
            .contentEdit,
            .readerShell,
            [.readerTopArea, .readerReplacePanel],
            renderer: .readerHostComposite
        ),

        page(.bookCoverChange, .libraryShell, [.backTopBar, .sourceFormPage]),
        page(.bookCoverSearch, .libraryShell, [.backTopBar, .searchResultsPage]),
        page(.chapterReviews, .libraryShell, [.backTopBar, .list]),
        page(.bookmarksManager, .libraryShell, [.backTopBar, .readerDirectoryPanel]),
        page(.downloadQueue, .libraryShell, [.backTopBar, .readerBookCachePage]),
        page(.downloadTaskDetail, .libraryShell, [.backTopBar, .readerBookCachePage]),

        page(.storageManagement, .settingsShell, [.backTopBar, .globalSettingsPage]),
        page(.webviewLogin, .flowShell, [.backTopBar, .webView, .button]),
        page(.webviewCaptcha, .flowShell, [.backTopBar, .webView]),
        page(.webviewChallenge, .flowShell, [.globalStatePage]),
        page(.webviewCookieReturn, .flowShell, [.globalStatePage]),

        page(.settingsTts, .settingsShell, [.backTopBar, .settingsGeneralPage]),
        page(.settingsStorage, .settingsShell, [.backTopBar, .settingsGeneralPage]),
        page(.settingsAccessibility, .settingsShell, [.backTopBar, .settingsGeneralPage]),
    ]

    private static let byRouteId: [ReaderUIContract.RouteId: ReaderContract30RoutePage] = {
        let pages = Dictionary(uniqueKeysWithValues: all.map { ($0.routeId, $0) })
        precondition(pages.count == all.count, "Reader UI 3.0 route registry contains duplicates")
        return pages
    }()

    static var routeIds: Set<ReaderUIContract.RouteId> { Set(byRouteId.keys) }

    static func page(for routeId: ReaderUIContract.RouteId) -> ReaderContract30RoutePage? {
        byRouteId[routeId]
    }

    static func renderer(for routeId: ReaderUIContract.RouteId) -> ReaderContract30Renderer? {
        byRouteId[routeId]?.renderer
    }
}
