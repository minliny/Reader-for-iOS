import XCTest
import ReaderUIContract
@testable import ReaderApp

@MainActor
final class ReaderContract25RouteRegistryTests: XCTestCase {
    func testNativeRegistryExactlyMatchesAll260GeneratedRoutes() {
        let generated = Set(ReaderUIContract.RouteId.allCases.map(\.rawValue))
        let native = Set(DemoRouteMappings.all.map(\.demoRoute))

        XCTAssertEqual(ReaderUIContract.RouteId.allCases.count, 260)
        XCTAssertEqual(DemoRouteMappings.all.count, 260)
        XCTAssertEqual(native, generated)
    }

    func testAll35Contract25RoutesHaveExplicitRendererOwnership() {
        let expected: Set<ReaderUIContract.RouteId> = [
            .readerFontImportConfirm, .readerFontDeleteConfirm, .readerFontFallback,
            .readerThemeNew, .readerThemeDeleteConfirm, .readerTypographyResetConfirm,
            .readerReplaceDeleteConfirm, .readerReplaceApplyResult, .readerReplaceImportExport,
            .readerReplacePreview, .readerReplacePage,
            .sourceSwitchEmpty, .sourceSwitchError, .sourceSwitchTimeout,
            .sourceSwitchLoading, .sourceSwitchRollback, .sourceSwitchPreview,
            .readerTocLoading, .readerTocOffline, .readerTocError,
            .readerContentLoading, .readerContentOffline, .readerContentError,
            .readerPageBoundaryFirst, .readerPageBoundaryLast,
            .readerProgressRestore, .readerBackgroundRestore,
            .importPermissionDenied, .importFormatUnsupported, .importEmptyFile,
            .importParsing, .importDuplicate, .importConflictResolve,
            .importPartialSuccess, .importResultDetail
        ]

        XCTAssertEqual(ReaderContract25RouteRegistry.routeIds, expected)
        XCTAssertEqual(ReaderContract25RouteRegistry.all.count, 35)
        XCTAssertTrue(expected.allSatisfy { ReaderContract25RouteRegistry.renderer(for: $0) != nil })

        let distribution = Dictionary(
            grouping: ReaderContract25RouteRegistry.all,
            by: \.renderer
        ).mapValues(\.count)
        XCTAssertEqual(distribution[.readerWorkspaceState], 6)
        XCTAssertEqual(distribution[.readerReplacementState], 5)
        XCTAssertEqual(distribution[.sourceSwitchState], 6)
        XCTAssertEqual(distribution[.readerContentState], 10)
        XCTAssertEqual(distribution[.localImportState], 8)
    }

    func testContract25ActionsOnlyTargetGeneratedRoutes() {
        let generated = Set(ReaderUIContract.RouteId.allCases)
        let targets = ReaderContract25RouteRegistry.all.flatMap(\.actions).map(\.target)

        XCTAssertFalse(targets.isEmpty)
        XCTAssertTrue(targets.allSatisfy(generated.contains))
    }

    func testEveryContract25RouteBuildsNonEmptyContractComponentTree() {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        XCTAssertTrue(ComponentRegistry.isRegistered(.globalStatePage))

        for page in ReaderContract25RouteRegistry.all {
            let viewState = ViewStateFactory.make(routeId: page.routeId)
            XCTAssertFalse(viewState.components.isEmpty, page.routeId.rawValue)
            XCTAssertEqual(viewState.components.first?.type, .globalStatePage, page.routeId.rawValue)
        }
    }

    func testKeyActionsDriveInternalRendererTransitionsAndExternalExitTargets() throws {
        let replacement = try XCTUnwrap(ReaderContract25RouteRegistry.page(for: .readerReplacePage))
        var replacementNavigation = ReaderContract25RouteNavigation(initialRouteId: replacement.routeId)
        XCTAssertEqual(
            replacementNavigation.perform(replacement.actions[0]),
            .rendered(.readerReplacePreview)
        )
        XCTAssertEqual(replacementNavigation.currentRouteId, .readerReplacePreview)

        let parsing = try XCTUnwrap(ReaderContract25RouteRegistry.page(for: .importParsing))
        var importNavigation = ReaderContract25RouteNavigation(initialRouteId: parsing.routeId)
        XCTAssertEqual(importNavigation.perform(parsing.actions[1]), .rendered(.importDuplicate))
        XCTAssertEqual(importNavigation.currentRouteId, .importDuplicate)

        let empty = try XCTUnwrap(ReaderContract25RouteRegistry.page(for: .sourceSwitchEmpty))
        var sourceNavigation = ReaderContract25RouteNavigation(initialRouteId: empty.routeId)
        XCTAssertEqual(sourceNavigation.perform(empty.actions[0]), .external(.sourceSwitch))
        XCTAssertEqual(sourceNavigation.currentRouteId, .sourceSwitchEmpty)
    }

    func testKeyRoutesSelectCanonicalShellAndConcreteSwiftUIRenderer() throws {
        let font = try XCTUnwrap(ReaderContract25RouteRegistry.page(for: .readerFontImportConfirm))
        let replace = try XCTUnwrap(ReaderContract25RouteRegistry.page(for: .readerReplacePage))
        let source = try XCTUnwrap(ReaderContract25RouteRegistry.page(for: .sourceSwitchPreview))
        let content = try XCTUnwrap(ReaderContract25RouteRegistry.page(for: .readerContentError))
        let localImport = try XCTUnwrap(ReaderContract25RouteRegistry.page(for: .importConflictResolve))

        XCTAssertEqual(font.shell, .readerShell)
        XCTAssertEqual(font.renderer, .readerWorkspaceState)
        XCTAssertEqual(replace.shell, .readerShell)
        XCTAssertEqual(replace.renderer, .readerReplacementState)
        XCTAssertEqual(source.shell, .flowShell)
        XCTAssertEqual(source.renderer, .sourceSwitchState)
        XCTAssertEqual(content.shell, .readerShell)
        XCTAssertEqual(content.renderer, .readerContentState)
        XCTAssertEqual(localImport.shell, .libraryShell)
        XCTAssertEqual(localImport.renderer, .localImportState)

        _ = ReaderContract25RouteScreen(routeId: font.routeId)
        _ = ReaderContract25RouteScreen(routeId: source.routeId)
        _ = ReaderContract25RouteScreen(routeId: localImport.routeId)
    }

    func testContractNavigationUsesExtendedShellMetadataForNewRoutes() {
        let reader = ContractNavigationStack(initialRouteId: "reader-content-error")
        let flow = ContractNavigationStack(initialRouteId: "source-switch-preview")
        let library = ContractNavigationStack(initialRouteId: "import-conflict-resolve")

        XCTAssertEqual(reader.currentShell, .readerShell)
        XCTAssertEqual(flow.currentShell, .flowShell)
        XCTAssertEqual(library.currentShell, .libraryShell)
        XCTAssertEqual(reader.pop(), "bookshelf")
        XCTAssertEqual(flow.pop(), "bookshelf")
        XCTAssertEqual(library.pop(), "bookshelf")
    }
}
