import ReaderUIContract
import XCTest
@testable import ReaderApp

@MainActor
final class ReaderContract30RouteRegistryTests: XCTestCase {
    func testAll24ReaderUI30RoutesHaveExplicitNativeStructureOwnership() {
        let expected: Set<ReaderUIContract.RouteId> = [
            .onboardingWelcome, .onboardingCapabilitySetup, .permissionRecovery,
            .localFormatSupport, .pdfReader, .mangaReader,
            .httpTtsManagement, .httpTtsEditor, .httpTtsTest, .contentEdit,
            .bookCoverChange, .bookCoverSearch, .chapterReviews, .bookmarksManager,
            .downloadQueue, .downloadTaskDetail, .storageManagement,
            .webviewLogin, .webviewCaptcha, .webviewChallenge, .webviewCookieReturn,
            .settingsTts, .settingsStorage, .settingsAccessibility,
        ]

        XCTAssertEqual(ReaderContract30RouteRegistry.routeIds, expected)
        XCTAssertEqual(ReaderContract30RouteRegistry.all.count, 24)
        XCTAssertTrue(expected.allSatisfy {
            ReaderContract30RouteRegistry.renderer(for: $0) != nil
        })

        let shellDistribution = Dictionary(
            grouping: ReaderContract30RouteRegistry.all,
            by: \.shell
        ).mapValues(\.count)
        XCTAssertEqual(shellDistribution[.flowShell], 7)
        XCTAssertEqual(shellDistribution[.libraryShell], 7)
        XCTAssertEqual(shellDistribution[.readerShell], 3)
        XCTAssertEqual(shellDistribution[.settingsShell], 7)
    }

    func testEveryReaderUI30RouteMatchesCanonicalShellAndRegisteredNativeTree() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()

        for page in ReaderContract30RouteRegistry.all {
            let plan = try planner.plan(routeId: page.routeId)
            XCTAssertEqual(plan.shell, page.shell, page.routeId.rawValue)
            XCTAssertEqual(
                plan.components.map(\.component.type),
                page.topLevelTypes,
                page.routeId.rawValue
            )
            XCTAssertFalse(plan.components.isEmpty, page.routeId.rawValue)

            for component in flatten(plan.components) {
                if component.compositionMode == .hostComposite {
                    XCTAssertTrue(
                        ReaderScreenGraphHostCompositePolicy.integratedTypes.contains(
                            component.component.type
                        ),
                        "\(page.routeId.rawValue)/\(component.component.type.rawValue)"
                    )
                } else {
                    XCTAssertTrue(
                        ComponentRegistry.isRegistered(component.component.type),
                        "\(page.routeId.rawValue)/\(component.component.type.rawValue)"
                    )
                }
            }
        }
    }

    func testNewRoutesSeparate18ExecutableFrom33PlannedBindings() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        var executable = 0
        var planned = 0

        for page in ReaderContract30RouteRegistry.all {
            let plan = try planner.plan(routeId: page.routeId)
            executable += plan.recursiveExecutableBindingCount
            planned += plan.recursivePlannedFailClosedBindingCount

            for component in flatten(plan.components) {
                for binding in component.bindings {
                    XCTAssertEqual(
                        binding.isExecutable,
                        ReaderScreenGraphRuntimeBindingPolicy.isExecutable(
                            event: binding.event,
                            payload: binding.payload
                        ),
                        "\(page.routeId.rawValue)/\(component.component.id ?? "component")"
                    )
                }

                guard component.component.type == .button,
                      let binding = component.bindings.first else { continue }
                let action = ReaderScreenGraphButtonActionResolver.action(
                    for: component.component
                )
                if binding.isExecutable {
                    XCTAssertNotNil(action, component.component.id ?? page.routeId.rawValue)
                } else {
                    XCTAssertNil(action, component.component.id ?? page.routeId.rawValue)
                }
            }
        }

        XCTAssertEqual(executable, 18)
        XCTAssertEqual(planned, 33)
        XCTAssertEqual(executable + planned, 51)
    }

    func testReaderUI30MappingsAreConcreteAndShellLookupIsExplicit() {
        for page in ReaderContract30RouteRegistry.all {
            let mapping = DemoRouteMappings.mapping(for: page.routeId.rawValue)
            XCTAssertEqual(mapping?.shell, page.shell.rawValue, page.routeId.rawValue)
            guard case .featureState(let target) = mapping?.platformTarget else {
                return XCTFail("\(page.routeId.rawValue) must have a concrete structural mapping")
            }
            XCTAssertTrue(target.contains("ReaderContract30RouteRegistry"), page.routeId.rawValue)
            XCTAssertEqual(
                ReaderNativeRouteShellLookup.shell(for: page.routeId.rawValue),
                page.shell,
                page.routeId.rawValue
            )
        }
    }

    private func flatten(
        _ components: [ReaderScreenGraphPlannedComponent]
    ) -> [ReaderScreenGraphPlannedComponent] {
        components.flatMap { [$0] + flatten($0.children) }
    }
}
