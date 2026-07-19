import Foundation
import ReaderUIContract
import XCTest
@testable import ReaderApp

@MainActor
final class ReaderScreenGraphReadingBackgroundLayerRendererTests: XCTestCase {
    func testAll21CanonicalLayersMatchExactSchemaOwnershipAndComposition() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()
        var auditedLayerCount = 0
        var projectedLayerCount = 0

        for route in planner.registry.document.routes where route.status == .direct {
            for variant in route.variants {
                let plan = try planner.plan(
                    routeId: route.routeId,
                    preferredVariantId: variant.variantId
                )
                let layers = flatten(plan.components).filter {
                    $0.component.type == .readingBackgroundLayer
                }
                for layer in layers {
                    auditedLayerCount += 1
                    XCTAssertTrue(
                        ReaderScreenGraphReadingBackgroundLayerPolicy.admits(layer),
                        "\(route.routeId.rawValue)/\(layer.component.id ?? "ReadingBackgroundLayer")"
                    )
                    XCTAssertEqual(layer.stateAuthorities, ["host-store"])
                    XCTAssertEqual(layer.compositionMode, .contractTree)
                    XCTAssertTrue(layer.bindings.isEmpty)
                    XCTAssertTrue(layer.stateEventEvidence.isEmpty)
                    XCTAssertTrue(layer.children.isEmpty)
                    let props = try XCTUnwrap(
                        ReaderScreenGraphReadingBackgroundLayerProps(
                            component: layer.component
                        )
                    )
                    XCTAssertEqual(props.themeEvidence, "paper")
                    _ = ReaderScreenGraphReadingBackgroundLayerView(
                        component: layer.component
                    )
                }

                projectedLayerCount += flatten(plan.viewState.components).filter {
                    $0.type == .readingBackgroundLayer
                }.count
            }
        }

        XCTAssertEqual(auditedLayerCount, 21)
        XCTAssertEqual(
            projectedLayerCount,
            0,
            "Host-composite descendants must stay out of recursive ViewState rendering."
        )
        XCTAssertTrue(ComponentRegistry.isRegistered(.readingBackgroundLayer))
        XCTAssertTrue(
            ComponentRegistry.faithfulRendererTypes.contains(.readingBackgroundLayer)
        )
        XCTAssertFalse(
            ComponentRegistry.genericRendererTypes.contains(.readingBackgroundLayer)
        )

        let catalog = try XCTUnwrap(
            planner.registry.document.componentCatalog.first {
                $0.type == .readingBackgroundLayer
            }
        )
        XCTAssertEqual(catalog.status, .referenced)
        XCTAssertEqual(catalog.instanceCount, 21)
    }

    func testUnknownThemePropsBindingsAndChildrenFailClosed() throws {
        let valid = try decodeComponent(
            #"{"type":"ReadingBackgroundLayer","id":"valid","props":{"theme":"paper"},"children":[],"bindings":[]}"#
        )
        XCTAssertNotNil(ReaderScreenGraphReadingBackgroundLayerProps(component: valid))

        let unknownTheme = try decodeComponent(
            #"{"type":"ReadingBackgroundLayer","id":"unknown","props":{"theme":"warm"},"children":[],"bindings":[]}"#
        )
        XCTAssertNil(ReaderScreenGraphReadingBackgroundLayerProps(component: unknownTheme))

        let extraProp = try decodeComponent(
            #"{"type":"ReadingBackgroundLayer","id":"extra","props":{"theme":"paper","opacity":0.8},"children":[],"bindings":[]}"#
        )
        XCTAssertNil(ReaderScreenGraphReadingBackgroundLayerProps(component: extraProp))

        let bound = try decodeComponent(
            #"{"type":"ReadingBackgroundLayer","id":"bound","props":{"theme":"paper"},"children":[],"bindings":[{"target":"self","event":"reader.nightState.toggle","payload":{},"trigger":"tap"}]}"#
        )
        XCTAssertNil(ReaderScreenGraphReadingBackgroundLayerProps(component: bound))

        let parent = try decodeComponent(
            #"{"type":"ReadingBackgroundLayer","id":"parent","props":{"theme":"paper"},"children":[{"type":"Content","id":"child","props":{},"children":[],"bindings":[]}],"bindings":[]}"#
        )
        XCTAssertNil(ReaderScreenGraphReadingBackgroundLayerProps(component: parent))
    }

    func testAuthorityAndCompositionDriftFailAdmissionWithoutHostRecursion() throws {
        let component = try decodeComponent(
            #"{"type":"ReadingBackgroundLayer","id":"layer","props":{"theme":"paper"},"children":[],"bindings":[]}"#
        )
        let wrongAuthority = ReaderScreenGraphPlannedComponent(
            component: component,
            stateAuthorities: ["contract"],
            compositionMode: .contractTree,
            bindings: [],
            stateEventEvidence: [],
            children: []
        )
        XCTAssertFalse(
            ReaderScreenGraphReadingBackgroundLayerPolicy.admits(wrongAuthority)
        )

        let wrongComposition = ReaderScreenGraphPlannedComponent(
            component: component,
            stateAuthorities: ["host-store"],
            compositionMode: .hostComposite,
            bindings: [],
            stateEventEvidence: [],
            children: []
        )
        XCTAssertFalse(
            ReaderScreenGraphReadingBackgroundLayerPolicy.admits(wrongComposition)
        )
    }

    func testHostPaletteOwnsRenderedThemeInsteadOfFixtureEvidence() throws {
        let component = try decodeComponent(
            #"{"type":"ReadingBackgroundLayer","id":"layer","props":{"theme":"paper"},"children":[],"bindings":[]}"#
        )
        let props = try XCTUnwrap(
            ReaderScreenGraphReadingBackgroundLayerProps(component: component)
        )
        XCTAssertEqual(props.themeEvidence, "paper")

        let paperDay = ReaderThemeResolver.palette(themeId: "paper", isNight: false)
        let greenNight = ReaderThemeResolver.palette(themeId: "green", isNight: true)
        XCTAssertEqual(
            ReaderScreenGraphReadingBackgroundLayerPresentation.owner(for: paperDay),
            .init(themeId: "paper", isNight: false)
        )
        XCTAssertEqual(
            ReaderScreenGraphReadingBackgroundLayerPresentation.owner(for: greenNight),
            .init(themeId: "green", isNight: true)
        )
        XCTAssertNotEqual(
            ReaderScreenGraphReadingBackgroundLayerPresentation.owner(for: paperDay),
            ReaderScreenGraphReadingBackgroundLayerPresentation.owner(for: greenNight)
        )

        _ = ReaderScreenGraphReadingBackgroundLayerView(component: component)
            .readerThemePalette(greenNight)
    }

    func testAll21ScreenGraphRoutesMapOneToOneToProductionHostPaletteSurface() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        let catalog = try XCTUnwrap(
            planner.registry.document.componentCatalog.first {
                $0.type == .readingBackgroundLayer
            }
        )
        let canonicalRoutes = Set(catalog.routeIds)
        let productionRoutes = Set(
            ReaderContract25RouteRegistry.all
                .filter { $0.renderer.usesHostReadingBackground }
                .map(\.routeId)
        )

        XCTAssertEqual(canonicalRoutes.count, 21)
        XCTAssertEqual(productionRoutes.count, 21)
        XCTAssertEqual(productionRoutes, canonicalRoutes)
        for routeId in canonicalRoutes {
            let page = try XCTUnwrap(ReaderContract25RouteRegistry.page(for: routeId))
            XCTAssertEqual(page.shell, .readerShell)
            XCTAssertTrue(page.renderer.usesHostReadingBackground)
            _ = ReaderContract25RouteScreen(routeId: routeId)
        }

        let ownerA = ReaderScreenGraphReadingBackgroundLayerPresentation.owner(
            for: ReaderThemeResolver.palette(themeId: "paper", isNight: false)
        )
        let ownerB = ReaderScreenGraphReadingBackgroundLayerPresentation.owner(
            for: ReaderThemeResolver.palette(themeId: "green", isNight: true)
        )
        XCTAssertNotEqual(ownerA, ownerB)
    }

    private func decodeComponent(_ json: String) throws -> ViewStateComponent {
        try JSONDecoder().decode(ViewStateComponent.self, from: Data(json.utf8))
    }

    private func flatten(
        _ components: [ReaderScreenGraphPlannedComponent]
    ) -> [ReaderScreenGraphPlannedComponent] {
        components.flatMap { [$0] + flatten($0.children) }
    }

    private func flatten(
        _ components: [ViewStateComponent]
    ) -> [ViewStateComponent] {
        components.flatMap { [$0] + flatten($0.children ?? []) }
    }
}
