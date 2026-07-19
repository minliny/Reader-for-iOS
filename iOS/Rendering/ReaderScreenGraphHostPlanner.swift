import CryptoKit
import Foundation
import ReaderUIContract
import ReaderUIRuntime
import SwiftUI

/// Canonical facts verified when the production shadow planner is initialized.
///
/// These are deliberately runtime-derived from `ScreenGraphRegistry.loadCanonical()` rather than
/// copied from a hand-maintained route table. A generated constant drifting from the embedded JSON
/// is therefore a hard planning failure instead of a partially rendered screen.
public struct ReaderScreenGraphCanonicalMetrics: Equatable, Sendable {
    public let sha256: String
    public let routeCount: Int
    public let directRouteCount: Int
    public let aliasRouteCount: Int
    public let variantCount: Int
    public let recursiveComponentCount: Int
    public let bindingCount: Int
    public let executableBindingCount: Int
    public let plannedFailClosedBindingCount: Int
    public let stateEventEvidenceCount: Int
    public let eventReferenceCount: Int
    public let referencedComponentTypeCount: Int
    public let explicitGapComponentTypeCount: Int
    public let actionGapCount: Int
}

public enum ReaderScreenGraphPlannerError: Error, Equatable, Sendable, CustomStringConvertible {
    case canonicalIntegrity(String)
    case unknownRoute(String)
    case routeResolution(String)
    case variantNotFound(routeId: String, variantId: String)
    case noVariant(routeId: String)
    case integerOutOfRange(path: String, value: Int64)
    case nonFiniteNumber(path: String)
    case componentConversion(componentId: String, reason: String)
    case bindingMismatch(componentId: String, reason: String)

    public var description: String {
        switch self {
        case .canonicalIntegrity(let reason):
            return "canonical-integrity: \(reason)"
        case .unknownRoute(let routeId):
            return "unknown-route: \(routeId)"
        case .routeResolution(let reason):
            return "route-resolution: \(reason)"
        case .variantNotFound(let routeId, let variantId):
            return "variant-not-found: \(routeId)/\(variantId)"
        case .noVariant(let routeId):
            return "no-variant: \(routeId)"
        case .integerOutOfRange(let path, let value):
            return "integer-out-of-range: \(path)=\(value)"
        case .nonFiniteNumber(let path):
            return "non-finite-number: \(path)"
        case .componentConversion(let componentId, let reason):
            return "component-conversion: \(componentId): \(reason)"
        case .bindingMismatch(let componentId, let reason):
            return "binding-mismatch: \(componentId): \(reason)"
        }
    }
}

/// R16 is deliberately shadow-only. Device evidence and an explicit promotion decision are still
/// required before ScreenGraph can become the visible route-rendering authority.
public enum ReaderScreenGraphRenderAuthority: String, Equatable, Sendable {
    case shadow
}

public enum ReaderScreenGraphCompositionMode: String, Equatable, Sendable {
    case contractTree = "contract-tree"
    case hostComposite = "host-composite"
}

/// Runtime admission is derived from Reader UI's generated 63-action typed payload registry.
/// A canonical UiEvent without a generated runtime contract remains visible for planning and
/// audit, but it must never become a Native callback.
public enum ReaderScreenGraphBindingDisposition: String, Equatable, Sendable {
    case executableRuntime = "executable-runtime"
    case plannedFailClosed = "planned-fail-closed"
}

public enum ReaderScreenGraphRuntimeBindingPolicy {
    public static func hasGeneratedContract(for event: UiEventType) -> Bool {
        GeneratedRuntimeTypedPayloadContracts.byEvent[event.rawValue] != nil
    }

    public static func disposition(
        event: UiEventType,
        payload: [String: AnyCodable]
    ) throws -> ReaderScreenGraphBindingDisposition {
        guard hasGeneratedContract(for: event) else {
            return .plannedFailClosed
        }
        let runtimePayload = try ReaderUIJSONBridge.payload(from: payload)
        guard try validateReaderUITypedPayload(
            event: event.rawValue,
            payload: runtimePayload
        ) != nil else {
            return .plannedFailClosed
        }
        return .executableRuntime
    }

    public static func isExecutable(
        event: UiEventType,
        payload: [String: AnyCodable]
    ) -> Bool {
        (try? disposition(event: event, payload: payload)) == .executableRuntime
    }
}

public enum ReaderTapZoneTarget: String, CaseIterable, Equatable, Sendable {
    case previous
    case control
    case next
}

public struct ReaderScreenGraphPlannedBinding: Sendable {
    public let target: String
    public let event: UiEventType
    public let payload: [String: AnyCodable]
    public let evidenceProperty: String
    public let trigger: String
    public let disposition: ReaderScreenGraphBindingDisposition

    public var isExecutable: Bool { disposition == .executableRuntime }
}

public struct ReaderScreenGraphPlannedStateEventEvidence: Sendable {
    public let event: UiEventType
    public let payload: [String: AnyCodable]
    public let evidenceProperty: String
    public let classification: String
}

public struct ReaderScreenGraphPlannedComponent: Sendable {
    public let component: ViewStateComponent
    public let stateAuthorities: [String]
    public let compositionMode: ReaderScreenGraphCompositionMode
    public let bindings: [ReaderScreenGraphPlannedBinding]
    public let stateEventEvidence: [ReaderScreenGraphPlannedStateEventEvidence]
    public let children: [ReaderScreenGraphPlannedComponent]

    public var recursiveComponentCount: Int {
        1 + children.reduce(0) { $0 + $1.recursiveComponentCount }
    }

    public var recursiveBindingCount: Int {
        bindings.count + children.reduce(0) { $0 + $1.recursiveBindingCount }
    }

    public var recursiveExecutableBindingCount: Int {
        bindings.filter(\.isExecutable).count
            + children.reduce(0) { $0 + $1.recursiveExecutableBindingCount }
    }

    public var recursivePlannedFailClosedBindingCount: Int {
        bindings.filter { !$0.isExecutable }.count
            + children.reduce(0) { $0 + $1.recursivePlannedFailClosedBindingCount }
    }

    public var recursiveStateEventEvidenceCount: Int {
        stateEventEvidence.count + children.reduce(0) { $0 + $1.recursiveStateEventEvidenceCount }
    }

    public func component(withId id: String) -> ReaderScreenGraphPlannedComponent? {
        if component.id == id { return self }
        for child in children {
            if let match = child.component(withId: id) { return match }
        }
        return nil
    }
}

public struct ReaderScreenGraphRoutePlan: Sendable {
    public let authority: ReaderScreenGraphRenderAuthority
    public let requestedRouteId: RouteId
    public let resolvedRouteId: RouteId
    public let variantId: String
    public let shell: RouteShell
    public let viewState: ViewState
    public let components: [ReaderScreenGraphPlannedComponent]
    public let facets: [String: AnyCodable]
    public let actionGaps: [ScreenGraphActionGap]

    public var isAlias: Bool { requestedRouteId != resolvedRouteId }
    public var isPromotedRenderAuthority: Bool { false }
    public var hasDeviceProof: Bool { false }

    public var recursiveComponentCount: Int {
        components.reduce(0) { $0 + $1.recursiveComponentCount }
    }

    public var recursiveBindingCount: Int {
        components.reduce(0) { $0 + $1.recursiveBindingCount }
    }

    public var recursiveExecutableBindingCount: Int {
        components.reduce(0) { $0 + $1.recursiveExecutableBindingCount }
    }

    public var recursivePlannedFailClosedBindingCount: Int {
        components.reduce(0) { $0 + $1.recursivePlannedFailClosedBindingCount }
    }

    public var recursiveStateEventEvidenceCount: Int {
        components.reduce(0) { $0 + $1.recursiveStateEventEvidenceCount }
    }

    public func component(withId id: String) -> ReaderScreenGraphPlannedComponent? {
        for component in components {
            if let match = component.component(withId: id) { return match }
        }
        return nil
    }
}

/// Exact canonical-vs-native coverage. `supportedReferenced` combines faithful Native renderers,
/// conservative generic adapters, and separately audited Host-composite integrations. Unsupported
/// referenced primitives stay visible through fail-closed. Explicit gaps are reported separately.
public struct ReaderScreenGraphComponentCoverage: Sendable {
    public let canonicalReferenced: Set<ComponentType>
    public let canonicalExplicitGaps: Set<ComponentType>
    public let faithfulReferenced: Set<ComponentType>
    public let genericUsableReferenced: Set<ComponentType>
    public let hostCompositeIntegratedReferenced: Set<ComponentType>
    public let supportedReferenced: Set<ComponentType>
    public let visibleReferencedGaps: Set<ComponentType>
    public let visibleGapReasons: [ComponentType: ReaderScreenGraphVisibleGapReason]
    public let nativeRenderersForExplicitGaps: Set<ComponentType>
    public let screenGraphAdapterTypes: Set<ComponentType>
    public let explicitGapAdapterTypes: Set<ComponentType>

    /// "Full" means every referenced type is either a faithful Native renderer or a reviewed
    /// Host-composite integration. Generic closure is useful but never promoted to faithful parity.
    public var fullRenderer: Bool {
        visibleReferencedGaps.isEmpty && genericUsableReferenced.isEmpty
    }
}

public struct ReaderScreenGraphHostPlanner: Sendable {
    public static let expectedCanonicalSHA256 = "78052471b2ab3ac2c5729499d7234c0a94e6e1273862e8b48528cc512e6b089e"

    public let registry: ScreenGraphRegistry
    public let metrics: ReaderScreenGraphCanonicalMetrics

    public init() throws {
        let registry: ScreenGraphRegistry
        do {
            // Required production consumption point: do not decode a copied fixture or host-local
            // graph. The generated Reader UI package remains the canonical source.
            registry = try ScreenGraphRegistry.loadCanonical()
        } catch {
            throw ReaderScreenGraphPlannerError.canonicalIntegrity(String(describing: error))
        }

        let canonicalData = Data(ScreenGraphCanonicalAsset.json.utf8)
        let actualSHA = SHA256.hash(data: canonicalData)
            .map { String(format: "%02x", $0) }
            .joined()

        var variantCount = 0
        var recursiveComponentCount = 0
        var bindingCount = 0
        var executableBindingCount = 0
        var plannedFailClosedBindingCount = 0
        var stateEventEvidenceCount = 0
        var actionGapCount = 0
        let catalogByType = Dictionary(
            uniqueKeysWithValues: registry.document.componentCatalog.map { ($0.type, $0) }
        )

        func walk(_ nodes: [ScreenGraphComponentNode]) throws {
            for node in nodes {
                guard let catalog = catalogByType[node.type],
                      node.stateAuthorities == catalog.stateAuthorities,
                      node.compositionMode == catalog.compositionMode else {
                    throw ReaderScreenGraphPlannerError.canonicalIntegrity(
                        "component metadata drift: \(node.id)"
                    )
                }
                recursiveComponentCount += 1
                bindingCount += node.bindings.count
                for binding in node.bindings {
                    if GeneratedRuntimeTypedPayloadContracts.byEvent[binding.event.rawValue] != nil {
                        executableBindingCount += 1
                    } else {
                        plannedFailClosedBindingCount += 1
                    }
                }
                stateEventEvidenceCount += node.stateEventEvidence.count
                try walk(node.children)
            }
        }

        for route in registry.document.routes {
            variantCount += route.variants.count
            for variant in route.variants {
                actionGapCount += variant.actionGaps.count
                try walk(variant.components)
            }
        }

        let directRouteCount = registry.document.routes.filter { $0.status == .direct }.count
        let aliasRouteCount = registry.document.routes.filter { $0.status == .alias }.count
        let referencedCount = registry.document.componentCatalog.filter { $0.status == .referenced }.count
        let explicitGapCount = registry.document.componentCatalog.filter { $0.status == .explicitGap }.count

        let metrics = ReaderScreenGraphCanonicalMetrics(
            sha256: actualSHA,
            routeCount: registry.document.routes.count,
            directRouteCount: directRouteCount,
            aliasRouteCount: aliasRouteCount,
            variantCount: variantCount,
            recursiveComponentCount: recursiveComponentCount,
            bindingCount: bindingCount,
            executableBindingCount: executableBindingCount,
            plannedFailClosedBindingCount: plannedFailClosedBindingCount,
            stateEventEvidenceCount: stateEventEvidenceCount,
            eventReferenceCount: bindingCount + stateEventEvidenceCount,
            referencedComponentTypeCount: referencedCount,
            explicitGapComponentTypeCount: explicitGapCount,
            actionGapCount: actionGapCount
        )

        let expected = ReaderScreenGraphCanonicalMetrics(
            sha256: Self.expectedCanonicalSHA256,
            routeCount: 260,
            directRouteCount: 184,
            aliasRouteCount: 76,
            variantCount: 190,
            recursiveComponentCount: 615,
            bindingCount: 97,
            executableBindingCount: 38,
            plannedFailClosedBindingCount: 59,
            stateEventEvidenceCount: 19,
            eventReferenceCount: 116,
            referencedComponentTypeCount: 138,
            explicitGapComponentTypeCount: 36,
            actionGapCount: 6
        )

        guard ScreenGraphCanonicalAsset.sha256 == Self.expectedCanonicalSHA256 else {
            throw ReaderScreenGraphPlannerError.canonicalIntegrity(
                "generated SHA constant is \(ScreenGraphCanonicalAsset.sha256)"
            )
        }
        guard metrics == expected else {
            throw ReaderScreenGraphPlannerError.canonicalIntegrity(
                "expected \(expected), got \(metrics)"
            )
        }

        self.registry = registry
        self.metrics = metrics
    }

    public func componentCoverage(
        registeredTypes: Set<ComponentType> = ComponentRegistry.registeredTypes,
        genericRendererTypes: Set<ComponentType> = ComponentRegistry.genericRendererTypes
    ) -> ReaderScreenGraphComponentCoverage {
        let referenced = Set(
            registry.document.componentCatalog
                .filter { $0.status == .referenced }
                .map(\.type)
        )
        let explicitGaps = Set(
            registry.document.componentCatalog
                .filter { $0.status == .explicitGap }
                .map(\.type)
        )
        let hostComposite = referenced.intersection(
            ReaderScreenGraphHostCompositePolicy.integratedTypes
        )
        let faithful = referenced
            .intersection(registeredTypes.subtracting(genericRendererTypes))
            .subtracting(hostComposite)
        let generic = referenced.intersection(genericRendererTypes)
        let supported = faithful.union(generic).union(hostComposite)
        let visible = referenced.subtracting(supported)
        let reasons = ReaderScreenGraphGenericComponentPolicy.visibleGapReasons.filter {
            visible.contains($0.key)
        }
        return ReaderScreenGraphComponentCoverage(
            canonicalReferenced: referenced,
            canonicalExplicitGaps: explicitGaps,
            faithfulReferenced: faithful,
            genericUsableReferenced: generic,
            hostCompositeIntegratedReferenced: hostComposite,
            supportedReferenced: supported,
            visibleReferencedGaps: visible,
            visibleGapReasons: reasons,
            nativeRenderersForExplicitGaps: explicitGaps.intersection(registeredTypes),
            screenGraphAdapterTypes: generic,
            explicitGapAdapterTypes: explicitGaps.intersection(genericRendererTypes)
        )
    }

    public func plan(
        viewState: ViewState,
        preferredVariantId: String? = nil
    ) throws -> ReaderScreenGraphRoutePlan {
        guard let routeId = RouteId(rawValue: viewState.routeId) else {
            throw ReaderScreenGraphPlannerError.unknownRoute(viewState.routeId)
        }
        return try plan(
            routeId: routeId,
            preferredVariantId: preferredVariantId,
            pageState: viewState.pageState,
            overridingContext: viewState.context ?? [:]
        )
    }

    public func plan(
        routeId: RouteId,
        preferredVariantId: String? = nil,
        pageState: PageState? = nil,
        overridingContext: [String: AnyCodable] = [:]
    ) throws -> ReaderScreenGraphRoutePlan {
        let requestedRoute: ScreenGraphRouteNode
        let resolvedRoute: ScreenGraphRouteNode
        do {
            guard let route = registry.route(routeId) else {
                throw ReaderScreenGraphPlannerError.unknownRoute(routeId.rawValue)
            }
            requestedRoute = route
            resolvedRoute = try registry.resolve(routeId)
        } catch let error as ReaderScreenGraphPlannerError {
            throw error
        } catch {
            throw ReaderScreenGraphPlannerError.routeResolution(String(describing: error))
        }

        let variants = resolvedRoute.variants
        guard !variants.isEmpty else {
            throw ReaderScreenGraphPlannerError.noVariant(routeId: resolvedRoute.routeId.rawValue)
        }

        let variant: ScreenGraphVariant
        if let preferredVariantId {
            guard let explicit = variants.first(where: { $0.variantId == preferredVariantId }) else {
                throw ReaderScreenGraphPlannerError.variantNotFound(
                    routeId: resolvedRoute.routeId.rawValue,
                    variantId: preferredVariantId
                )
            }
            variant = explicit
        } else if let pageState,
                  let stateMatch = variants.first(where: { $0.pageState == pageState }) {
            variant = stateMatch
        } else if let contextVariantId = Self.variantId(from: overridingContext),
                  let contextMatch = variants.first(where: { $0.variantId == contextVariantId }) {
            variant = contextMatch
        } else if let defaultVariant = variants.first(where: { $0.variantId == "default" }) {
            variant = defaultVariant
        } else if let first = variants.first {
            variant = first
        } else {
            throw ReaderScreenGraphPlannerError.noVariant(routeId: resolvedRoute.routeId.rawValue)
        }

        var context = try Self.convertObject(variant.context, path: "context")
        // Runtime route parameters (book id, source id, etc.) take precedence over fixture values.
        context.merge(overridingContext) { _, runtime in runtime }
        let facets = try Self.convertObject(variant.facets, path: "facets")
        let plannedComponents = try variant.components.map(Self.convertComponent)
        let viewState = try Self.makeViewState(
            routeId: resolvedRoute.routeId.rawValue,
            pageState: variant.pageState,
            context: context,
            components: plannedComponents.map(\.component)
        )

        return ReaderScreenGraphRoutePlan(
            authority: .shadow,
            requestedRouteId: requestedRoute.routeId,
            resolvedRouteId: resolvedRoute.routeId,
            variantId: variant.variantId,
            shell: resolvedRoute.shell,
            viewState: viewState,
            components: plannedComponents,
            facets: facets,
            actionGaps: variant.actionGaps
        )
    }

    private static func variantId(from context: [String: AnyCodable]) -> String? {
        for key in ["variantId", "variant"] {
            if let value = context[key]?.value as? String { return value }
        }
        return nil
    }

    private static func convertComponent(
        _ node: ScreenGraphComponentNode
    ) throws -> ReaderScreenGraphPlannedComponent {
        guard let compositionMode = ReaderScreenGraphCompositionMode(rawValue: node.compositionMode) else {
            throw ReaderScreenGraphPlannerError.componentConversion(
                componentId: node.id,
                reason: "unsupported compositionMode \(node.compositionMode)"
            )
        }
        guard !node.stateAuthorities.isEmpty,
              node.stateAuthorities.allSatisfy({ !$0.isEmpty }) else {
            throw ReaderScreenGraphPlannerError.componentConversion(
                componentId: node.id,
                reason: "stateAuthorities must be non-empty"
            )
        }
        // Preserve the canonical tree for audit/count/target lookup. The ViewState projection
        // below intentionally drops these descendants for host-composite nodes so the generic
        // renderer cannot recursively fabricate a second Host-owned surface.
        let children = try node.children.map(convertComponent)
        let props = try convertObject(node.props, path: "component.\(node.id).props")
        let bindings = try node.bindings.enumerated().map { index, binding in
            let payload = try convertObject(
                binding.payload,
                path: "component.\(node.id).bindings[\(index)].payload"
            )
            return ReaderScreenGraphPlannedBinding(
                target: binding.target,
                event: binding.event,
                payload: payload,
                evidenceProperty: binding.evidenceProperty,
                trigger: binding.trigger,
                disposition: try bindingDisposition(
                    event: binding.event,
                    payload: payload,
                    componentId: node.id
                )
            )
        }
        let stateEventEvidence = try node.stateEventEvidence.enumerated().map { index, evidence in
            ReaderScreenGraphPlannedStateEventEvidence(
                event: evidence.event,
                payload: try convertObject(
                    evidence.payload,
                    path: "component.\(node.id).stateEventEvidence[\(index)].payload"
                ),
                evidenceProperty: evidence.evidenceProperty,
                classification: evidence.classification
            )
        }

        switch compositionMode {
        case .contractTree:
            for binding in bindings {
                switch binding.evidenceProperty {
                case "uiEvent":
                    guard binding.target == "self" else {
                        throw ReaderScreenGraphPlannerError.bindingMismatch(
                            componentId: node.id,
                            reason: "uiEvent binding target must be self"
                        )
                    }
                    guard props["uiEvent"]?.value as? String == binding.event.rawValue else {
                        throw ReaderScreenGraphPlannerError.bindingMismatch(
                            componentId: node.id,
                            reason: "uiEvent prop does not match \(binding.event.rawValue)"
                        )
                    }
                    guard binding.trigger == "tap",
                          props["uiEventTrigger"]?.value as? String == binding.trigger else {
                        throw ReaderScreenGraphPlannerError.bindingMismatch(
                            componentId: node.id,
                            reason: "uiEvent binding requires matching tap trigger"
                        )
                    }
                    guard let payload = props["uiEventPayload"],
                          try canonicalJSON(payload) == canonicalJSON(AnyCodable(binding.payload)) else {
                        throw ReaderScreenGraphPlannerError.bindingMismatch(
                            componentId: node.id,
                            reason: "uiEventPayload prop does not match action binding"
                        )
                    }

                case "explicitBinding":
                    guard !binding.target.isEmpty, binding.target != "self" else {
                        throw ReaderScreenGraphPlannerError.bindingMismatch(
                            componentId: node.id,
                            reason: "explicit binding requires a non-self semantic target"
                        )
                    }
                    guard ["tap", "appear", "change", "submit"].contains(binding.trigger) else {
                        throw ReaderScreenGraphPlannerError.bindingMismatch(
                            componentId: node.id,
                            reason: "unreviewed explicit binding trigger \(binding.trigger)"
                        )
                    }
                    guard props["uiEvent"] == nil,
                          props["uiEventPayload"] == nil,
                          props["uiEventTrigger"] == nil else {
                        throw ReaderScreenGraphPlannerError.bindingMismatch(
                            componentId: node.id,
                            reason: "explicit binding must not duplicate prop-derived uiEvent evidence"
                        )
                    }

                default:
                    throw ReaderScreenGraphPlannerError.bindingMismatch(
                        componentId: node.id,
                        reason: "unexpected evidence property \(binding.evidenceProperty)"
                    )
                }
            }
        case .hostComposite:
            try ReaderScreenGraphHostCompositePolicy.validate(
                type: node.type,
                componentId: node.id,
                props: props,
                bindings: bindings
            )
        }

        for evidence in stateEventEvidence {
            guard evidence.evidenceProperty == "uiEvent" else {
                throw ReaderScreenGraphPlannerError.bindingMismatch(
                    componentId: node.id,
                    reason: "unexpected state evidence property \(evidence.evidenceProperty)"
                )
            }
            guard evidence.classification == "state-evidence",
                  props["uiEventTrigger"]?.value as? String == evidence.classification else {
                throw ReaderScreenGraphPlannerError.bindingMismatch(
                    componentId: node.id,
                    reason: "state event evidence requires non-executable state-evidence classification"
                )
            }
            guard props["uiEvent"]?.value as? String == evidence.event.rawValue else {
                throw ReaderScreenGraphPlannerError.bindingMismatch(
                    componentId: node.id,
                    reason: "uiEvent prop does not match state evidence \(evidence.event.rawValue)"
                )
            }
            guard let payload = props["uiEventPayload"],
                  try canonicalJSON(payload) == canonicalJSON(AnyCodable(evidence.payload)) else {
                throw ReaderScreenGraphPlannerError.bindingMismatch(
                    componentId: node.id,
                    reason: "uiEventPayload prop does not match state event evidence"
                )
            }
        }

        let component = try makeComponent(
            type: node.type,
            id: node.id,
            props: props,
            children: compositionMode == .contractTree ? children.map(\.component) : [],
            bindings: bindings
        )
        return ReaderScreenGraphPlannedComponent(
            component: component,
            stateAuthorities: node.stateAuthorities,
            compositionMode: compositionMode,
            bindings: bindings,
            stateEventEvidence: stateEventEvidence,
            children: children
        )
    }

    public static func anyCodable(
        _ value: ScreenGraphJSONValue,
        path: String = "$"
    ) throws -> AnyCodable {
        switch value {
        case .null:
            return AnyCodable(Optional<String>.none as String?)
        case .bool(let bool):
            return AnyCodable(bool)
        case .integer(let integer):
            guard let exact = Int(exactly: integer) else {
                throw ReaderScreenGraphPlannerError.integerOutOfRange(path: path, value: integer)
            }
            return AnyCodable(exact)
        case .number(let number):
            guard number.isFinite else {
                throw ReaderScreenGraphPlannerError.nonFiniteNumber(path: path)
            }
            return AnyCodable(number)
        case .string(let string):
            return AnyCodable(string)
        case .array(let values):
            return AnyCodable(
                try values.enumerated().map { index, value in
                    try anyCodable(value, path: "\(path)[\(index)]")
                }
            )
        case .object(let object):
            return AnyCodable(try convertObject(object, path: path))
        }
    }

    private static func convertObject(
        _ object: [String: ScreenGraphJSONValue],
        path: String
    ) throws -> [String: AnyCodable] {
        var converted: [String: AnyCodable] = [:]
        converted.reserveCapacity(object.count)
        for (key, value) in object {
            converted[key] = try anyCodable(value, path: "\(path).\(key)")
        }
        return converted
    }

    private struct ViewStateComponentWire: Encodable {
        let type: ComponentType
        let id: String
        let props: [String: AnyCodable]
        let children: [ViewStateComponent]
        let bindings: [ViewStateBindingWire]
    }

    private struct ViewStateBindingWire: Encodable {
        let target: String
        let event: String
        let payload: [String: AnyCodable]
        let trigger: String
    }

    private static func makeComponent(
        type: ComponentType,
        id: String,
        props: [String: AnyCodable],
        children: [ViewStateComponent],
        bindings: [ReaderScreenGraphPlannedBinding]
    ) throws -> ViewStateComponent {
        do {
            let data = try JSONEncoder().encode(
                ViewStateComponentWire(
                    type: type,
                    id: id,
                    props: props,
                    children: children,
                    bindings: bindings.map {
                        ViewStateBindingWire(
                            target: $0.target,
                            event: $0.event.rawValue,
                            payload: $0.payload,
                            trigger: $0.trigger
                        )
                    }
                )
            )
            return try JSONDecoder().decode(ViewStateComponent.self, from: data)
        } catch {
            throw ReaderScreenGraphPlannerError.componentConversion(
                componentId: id,
                reason: String(describing: error)
            )
        }
    }

    private struct ViewStateWire: Encodable {
        let routeId: String
        let pageState: PageState
        let context: [String: AnyCodable]
        let components: [ViewStateComponent]
    }

    private static func makeViewState(
        routeId: String,
        pageState: PageState,
        context: [String: AnyCodable],
        components: [ViewStateComponent]
    ) throws -> ViewState {
        do {
            let data = try JSONEncoder().encode(
                ViewStateWire(
                    routeId: routeId,
                    pageState: pageState,
                    context: context,
                    components: components
                )
            )
            return try JSONDecoder().decode(ViewState.self, from: data)
        } catch {
            throw ReaderScreenGraphPlannerError.componentConversion(
                componentId: "<view-state>",
                reason: String(describing: error)
            )
        }
    }

    private static func canonicalJSON(_ value: AnyCodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(value)
    }

    private static func bindingDisposition(
        event: UiEventType,
        payload: [String: AnyCodable],
        componentId: String
    ) throws -> ReaderScreenGraphBindingDisposition {
        do {
            return try ReaderScreenGraphRuntimeBindingPolicy.disposition(
                event: event,
                payload: payload
            )
        } catch let error as ReaderScreenGraphPlannerError {
            throw error
        } catch {
            throw ReaderScreenGraphPlannerError.bindingMismatch(
                componentId: componentId,
                reason: "typed runtime payload rejected for \(event.rawValue): \(error)"
            )
        }
    }
}

/// Stable production access point. It is immutable and can only yield shadow plans; there is no
/// promote/device-verified switch in this type.
enum ReaderScreenGraphProductionPlanner {
    static let canonical: Result<ReaderScreenGraphHostPlanner, ReaderScreenGraphPlannerError> = {
        do {
            return .success(try ReaderScreenGraphHostPlanner())
        } catch let error as ReaderScreenGraphPlannerError {
            return .failure(error)
        } catch {
            return .failure(.canonicalIntegrity(String(describing: error)))
        }
    }()

    static func plan(
        viewState: ViewState,
        preferredVariantId: String? = nil
    ) -> Result<ReaderScreenGraphRoutePlan, ReaderScreenGraphPlannerError> {
        canonical.flatMap { planner in
            do {
                return .success(try planner.plan(
                    viewState: viewState,
                    preferredVariantId: preferredVariantId
                ))
            } catch let error as ReaderScreenGraphPlannerError {
                return .failure(error)
            } catch {
                return .failure(.canonicalIntegrity(String(describing: error)))
            }
        }
    }

    static func plan(
        routeId: RouteId,
        preferredVariantId: String? = nil,
        pageState: PageState? = nil,
        overridingContext: [String: AnyCodable] = [:]
    ) -> Result<ReaderScreenGraphRoutePlan, ReaderScreenGraphPlannerError> {
        canonical.flatMap { planner in
            do {
                return .success(try planner.plan(
                    routeId: routeId,
                    preferredVariantId: preferredVariantId,
                    pageState: pageState,
                    overridingContext: overridingContext
                ))
            } catch let error as ReaderScreenGraphPlannerError {
                return .failure(error)
            } catch {
                return .failure(.canonicalIntegrity(String(describing: error)))
            }
        }
    }
}

/// The canonical component tree is genuinely instantiated/drawn into a clipped diagnostic sample,
/// while the tiny indicator remains the only visible shadow chrome. Hit testing is disabled and the
/// Native route remains the sole rendering authority.
struct ReaderScreenGraphShadowDiagnostic: View {
    let result: Result<ReaderScreenGraphRoutePlan, ReaderScreenGraphPlannerError>

    private var identifier: String {
        switch result {
        case .success(let plan):
            return "reader-screen-graph-shadow-\(plan.requestedRouteId.rawValue)-\(plan.variantId)"
        case .failure(let error):
            let safe = error.description
                .replacingOccurrences(of: " ", with: "-")
                .replacingOccurrences(of: "/", with: "-")
            return "reader-screen-graph-shadow-failure-\(safe)"
        }
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if case .success(let plan) = result {
                ViewStateRenderer(viewState: plan.viewState)
                    .frame(width: 1, height: 1)
                    .clipped()
                    .opacity(0.01)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            Circle()
                .fill(indicatorColor)
                .frame(width: 7, height: 7)
                .padding(3)
                .accessibilityLabel(indicatorLabel)
                .accessibilityIdentifier(identifier)
        }
        .allowsHitTesting(false)
    }

    private var indicatorColor: Color {
        switch result {
        case .success:
            return ReaderDesignTokens.Color.primary
        case .failure:
            return ReaderDesignTokens.Color.muted
        }
    }

    private var indicatorLabel: String {
        switch result {
        case .success(let plan):
            return "ScreenGraph shadow diagnostic \(plan.requestedRouteId.rawValue) \(plan.variantId)"
        case .failure(let error):
            return "ScreenGraph shadow diagnostic failure \(error.description)"
        }
    }
}
