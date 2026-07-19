import Foundation
import ReaderUIContract
import SwiftUI

public enum ReaderScreenGraphButtonBindingState: String, Equatable, Sendable {
    case executableRuntime = "executable-runtime"
    case plannedFailClosed = "planned-fail-closed"
    case missingCanonicalBinding = "missing-canonical-binding"
}

/// Exact semantic projection of the canonical ScreenGraph Button shapes.
///
/// Runtime enablement comes from Reader UI's generated typed payload registry, not from the
/// presence of a binding. Planned events remain visible but disabled. Selection is explicitly
/// false because canonical carries no selected state. Unknown keys fail closed so a future Button
/// schema cannot silently inherit today's behavior.
public struct ReaderScreenGraphButtonProps: Sendable {
    public let label: String
    public let enabled: Bool
    public let selected: Bool
    public let action: ReaderScreenGraphExecutableAction?
    public let bindingState: ReaderScreenGraphButtonBindingState

    public init?(component: ViewStateComponent) {
        guard component.type == .button,
              let props = component.props,
              let label = props.string("label"),
              !label.isEmpty else {
            return nil
        }

        let bindings = component.bindings ?? []
        switch Set(props.keys) {
        case ["label", "uiEvent", "uiEventPayload", "uiEventTrigger"]:
            guard bindings.count == 1,
                  let binding = bindings.first,
                  binding.target == "self",
                  binding.trigger == "tap",
                  props.string("uiEventTrigger") == binding.trigger,
                  props.string("uiEvent") == binding.event,
                  let event = UiEventType(rawValue: binding.event),
                  let payload = props.dict("uiEventPayload"),
                  Self.payloadsMatch(payload, binding.payload) else {
                return nil
            }
            let action = Self.runtimeAction(event: event, payload: payload)
            guard !ReaderScreenGraphRuntimeBindingPolicy.hasGeneratedContract(for: event)
                    || action != nil else {
                return nil
            }
            self.label = label
            self.enabled = action != nil
            self.selected = false
            self.action = action
            self.bindingState = action == nil ? .plannedFailClosed : .executableRuntime

        case ["label"], ["availability", "label"]:
            guard bindings.count == 1,
                  let binding = bindings.first,
                  !binding.target.isEmpty,
                  binding.target != "self",
                  let event = UiEventType(rawValue: binding.event),
                  props.string("availability") == nil
                    || props.string("availability") == "planned-fail-closed" else {
                return nil
            }
            let action: ReaderScreenGraphExecutableAction?
            if binding.trigger == "tap" {
                action = Self.runtimeAction(event: event, payload: binding.payload)
                guard !ReaderScreenGraphRuntimeBindingPolicy.hasGeneratedContract(for: event)
                        || action != nil else {
                    return nil
                }
            } else {
                guard !ReaderScreenGraphRuntimeBindingPolicy.hasGeneratedContract(for: event) else {
                    return nil
                }
                action = nil
            }
            guard props.string("availability") == nil || action == nil else {
                return nil
            }
            self.label = label
            self.enabled = action != nil
            self.selected = false
            self.action = action
            self.bindingState = action == nil ? .plannedFailClosed : .executableRuntime

        case ["action", "label"]:
            guard bindings.isEmpty,
                  props.string("action") == label else {
                return nil
            }
            self.label = label
            self.enabled = false
            self.selected = false
            self.action = nil
            self.bindingState = .missingCanonicalBinding

        default:
            return nil
        }
    }

    private static func runtimeAction(
        event: UiEventType,
        payload: [String: AnyCodable]
    ) -> ReaderScreenGraphExecutableAction? {
        if ReaderScreenGraphRuntimeBindingPolicy.hasGeneratedContract(for: event) {
            guard ReaderScreenGraphRuntimeBindingPolicy.isExecutable(
                event: event,
                payload: payload
            ) else {
                return nil
            }
            return ReaderScreenGraphExecutableAction(event: event, payload: payload)
        }
        return nil
    }

    private static func payloadsMatch(
        _ lhs: [String: AnyCodable],
        _ rhs: [String: AnyCodable]
    ) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let lhsData = try? encoder.encode(lhs),
              let rhsData = try? encoder.encode(rhs) else {
            return false
        }
        return lhsData == rhsData
    }
}

public enum ReaderScreenGraphButtonActionResolver {
    public static func action(
        for component: ViewStateComponent
    ) -> ReaderScreenGraphExecutableAction? {
        ReaderScreenGraphButtonProps(component: component)?.action
    }
}

public enum ReaderScreenGraphButtonAccessibility {
    public static func identifier(for component: ViewStateComponent) -> String {
        "reader-screen-graph-button-\(component.id ?? "anonymous")"
    }
}

/// A focused native control with no state ownership of its own. The existing environment callback
/// remains the only exit and is injected by ViewStateRenderer from ReaderCoordinator.dispatch.
struct ReaderScreenGraphButtonView: View {
    let component: ViewStateComponent
    @Environment(\.readerScreenGraphActionHandler) private var actionHandler

    @ViewBuilder
    var body: some View {
        if let props = ReaderScreenGraphButtonProps(component: component) {
            VStack(alignment: .leading, spacing: 4) {
                Button(props.label) {
                    guard props.enabled,
                          let action = props.action,
                          let actionHandler else {
                        return
                    }
                    actionHandler(action.makeEvent())
                }
                .buttonStyle(.borderedProminent)
                .disabled(!props.enabled || actionHandler == nil)
                .accessibilityLabel(props.label)
                .accessibilityValue(props.selected ? "selected" : "not selected")
                .accessibilityHint(
                    props.action?.event.rawValue ?? "Action unavailable: \(props.bindingState.rawValue)"
                )
                .accessibilityIdentifier(
                    ReaderScreenGraphButtonAccessibility.identifier(for: component)
                )

                if !props.enabled {
                    Text("Action unavailable: \(props.bindingState.rawValue)")
                        .font(.caption2)
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                        .accessibilityIdentifier(
                            "\(ReaderScreenGraphButtonAccessibility.identifier(for: component))-binding-gap"
                        )
                }
            }
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "invalid-button-schema-or-binding"
            )
        }
    }
}

public func registerReaderScreenGraphButtonComponent() {
    ComponentRegistry.register(.button) { component in
        AnyView(ReaderScreenGraphButtonView(component: component))
    }
}
