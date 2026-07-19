import Foundation
import ReaderUIContract
import XCTest
@testable import ReaderApp

@MainActor
final class ReaderScreenGraphButtonRendererTests: XCTestCase {
    func testAll59CanonicalButtonsDecodeAndOnly19RuntimeBindingsRemainExecutable() throws {
        ComponentRegistry.reset()
        ComponentRegistry.bootstrapAllSlices()
        let planner = try ReaderScreenGraphHostPlanner()
        var buttonCount = 0
        var executableCount = 0
        var plannedFailClosedCount = 0
        var disabledBindingGapCount = 0

        for route in planner.registry.document.routes where route.status == .direct {
            for variant in route.variants {
                let plan = try planner.plan(
                    routeId: route.routeId,
                    preferredVariantId: variant.variantId
                )
                for planned in flatten(plan.components) where planned.component.type == .button {
                    buttonCount += 1
                    let component = planned.component
                    let props = try XCTUnwrap(
                        ReaderScreenGraphButtonProps(component: component),
                        component.id ?? route.routeId.rawValue
                    )
                    XCTAssertFalse(props.label.isEmpty)
                    XCTAssertFalse(props.selected, component.id ?? "Button")
                    XCTAssertEqual(
                        ReaderScreenGraphButtonAccessibility.identifier(for: component),
                        "reader-screen-graph-button-\(component.id ?? "anonymous")"
                    )
                    _ = ReaderScreenGraphButtonView(component: component)

                    if let binding = planned.bindings.first {
                        XCTAssertEqual(planned.bindings.count, 1)
                        if binding.isExecutable {
                            XCTAssertEqual(binding.trigger, "tap")
                            XCTAssertTrue(props.enabled)
                            XCTAssertEqual(props.bindingState, .executableRuntime)
                            let action = try XCTUnwrap(props.action)
                            XCTAssertEqual(action.event, binding.event)
                            XCTAssertEqual(
                                try canonicalData(action.payload),
                                try canonicalData(binding.payload)
                            )
                            executableCount += 1
                        } else {
                            XCTAssertFalse(props.enabled)
                            XCTAssertNil(props.action)
                            XCTAssertEqual(props.bindingState, .plannedFailClosed)
                            plannedFailClosedCount += 1
                        }
                    } else {
                        XCTAssertTrue(planned.bindings.isEmpty)
                        XCTAssertEqual(
                            Set(component.props?.keys.map { $0 } ?? []),
                            ["action", "label"]
                        )
                        XCTAssertEqual(
                            component.props?.string("action"),
                            component.props?.string("label")
                        )
                        XCTAssertFalse(props.enabled)
                        XCTAssertNil(props.action)
                        XCTAssertEqual(props.bindingState, .missingCanonicalBinding)
                        disabledBindingGapCount += 1
                    }
                }
            }
        }

        XCTAssertEqual(buttonCount, 59)
        XCTAssertEqual(executableCount, 19)
        XCTAssertEqual(plannedFailClosedCount, 38)
        XCTAssertEqual(disabledBindingGapCount, 2)
        XCTAssertTrue(ComponentRegistry.isRegistered(.button))
        XCTAssertTrue(ComponentRegistry.faithfulRendererTypes.contains(.button))
        XCTAssertFalse(ComponentRegistry.genericRendererTypes.contains(.button))

        let catalog = try XCTUnwrap(
            planner.registry.document.componentCatalog.first { $0.type == .button }
        )
        XCTAssertEqual(catalog.status, .referenced)
        XCTAssertEqual(catalog.instanceCount, 59)
    }

    func testButtonSchemaAndBindingDriftFailClosed() throws {
        let missingBinding = try decodeComponent(
            #"{"type":"Button","id":"missing-binding","props":{"label":"Run","uiEvent":"source.import.open","uiEventPayload":{},"uiEventTrigger":"tap"},"children":[],"bindings":[]}"#
        )
        XCTAssertNil(ReaderScreenGraphButtonProps(component: missingBinding))
        XCTAssertNil(ReaderScreenGraphButtonActionResolver.action(for: missingBinding))

        let mismatchedBinding = try decodeComponent(
            #"{"type":"Button","id":"mismatch","props":{"label":"Run","uiEvent":"source.import.open","uiEventPayload":{},"uiEventTrigger":"tap"},"children":[],"bindings":[{"target":"self","event":"source.switch.cancel","payload":{},"trigger":"tap"}]}"#
        )
        XCTAssertNil(ReaderScreenGraphButtonProps(component: mismatchedBinding))

        let fabricatedState = try decodeComponent(
            #"{"type":"Button","id":"fabricated-state","props":{"label":"Run","enabled":true,"selected":true,"uiEvent":"source.import.open","uiEventPayload":{},"uiEventTrigger":"tap"},"children":[],"bindings":[{"target":"self","event":"source.import.open","payload":{},"trigger":"tap"}]}"#
        )
        XCTAssertNil(
            ReaderScreenGraphButtonProps(component: fabricatedState),
            "Canonical carries no enabled/selected props; a future state schema needs a new audit."
        )

        let reviewedGap = try decodeComponent(
            #"{"type":"Button","id":"gap","props":{"label":"Cancel","action":"Cancel"},"children":[],"bindings":[]}"#
        )
        let gapProps = try XCTUnwrap(ReaderScreenGraphButtonProps(component: reviewedGap))
        XCTAssertFalse(gapProps.enabled)
        XCTAssertFalse(gapProps.selected)
        XCTAssertNil(gapProps.action)
        XCTAssertEqual(gapProps.bindingState, .missingCanonicalBinding)

        let planned = try decodeComponent(
            #"{"type":"Button","id":"planned","props":{"label":"Run"},"children":[],"bindings":[{"target":"run","event":"onboarding.continue","payload":{"nextRouteId":"bookshelf"},"trigger":"tap"}]}"#
        )
        let plannedProps = try XCTUnwrap(ReaderScreenGraphButtonProps(component: planned))
        XCTAssertFalse(plannedProps.enabled)
        XCTAssertNil(plannedProps.action)
        XCTAssertEqual(plannedProps.bindingState, .plannedFailClosed)
    }

    func testPlannedButtonCannotEnterCoordinatorReducerChain() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        let planned = try XCTUnwrap(
            planner.plan(routeId: .importPermissionDenied)
                .component(withId: "import_permission_denied-action")
        )
        let props = try XCTUnwrap(
            ReaderScreenGraphButtonProps(component: planned.component)
        )
        XCTAssertEqual(planned.bindings.first?.event, .source_import_open)
        XCTAssertEqual(planned.bindings.first?.disposition, .plannedFailClosed)
        XCTAssertEqual(props.bindingState, .plannedFailClosed)
        XCTAssertFalse(props.enabled)
        XCTAssertNil(props.action)

        let navigationState = AppNavigationState()
        let coordinator = ReaderCoordinator(navigationState: navigationState)
        var callbackCount = 0
        let screenGraphCallback: (UiEvent?) -> Void = { event in
            guard let event else { return }
            callbackCount += 1
            coordinator.dispatch(event)
        }

        screenGraphCallback(props.action?.makeEvent())

        XCTAssertEqual(callbackCount, 0)
        XCTAssertEqual(navigationState.currentRoute, .home)
        XCTAssertTrue(navigationState.navigationPath.isEmpty)
    }

    func testReaderUI30ImplementedRouteButtonProducesTypedExecutableAction() throws {
        let planner = try ReaderScreenGraphHostPlanner()
        let planned = try XCTUnwrap(
            planner.plan(routeId: .onboardingCapabilitySetup)
                .component(withId: "onboarding-open-permission-recovery")
        )
        let props = try XCTUnwrap(
            ReaderScreenGraphButtonProps(component: planned.component)
        )
        let action = try XCTUnwrap(props.action)

        XCTAssertEqual(planned.bindings.first?.disposition, .executableRuntime)
        XCTAssertEqual(props.bindingState, .executableRuntime)
        XCTAssertTrue(props.enabled)
        XCTAssertEqual(action.event, .route_push)
        XCTAssertEqual(action.payload.string("routeId"), "permission-recovery")
    }

    private func decodeComponent(_ json: String) throws -> ViewStateComponent {
        try JSONDecoder().decode(ViewStateComponent.self, from: Data(json.utf8))
    }

    private func canonicalData(_ payload: [String: AnyCodable]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(payload)
    }

    private func flatten(
        _ components: [ReaderScreenGraphPlannedComponent]
    ) -> [ReaderScreenGraphPlannedComponent] {
        components.flatMap { [$0] + flatten($0.children) }
    }
}
