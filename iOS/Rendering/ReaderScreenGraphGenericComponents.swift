import Foundation
import ReaderUIContract
import SwiftUI

public struct ReaderScreenGraphVisibleGapReason: Equatable, Sendable {
    public let code: String
    public let detail: String

    public init(code: String, detail: String) {
        self.code = code
        self.detail = detail
    }
}

/// Audited against all canonical instances, not inferred from ComponentType names. The contract
/// currently has no per-type props schema, so only these types have enough stable data for a
/// conservative generic SwiftUI family. Host-composite bindings are classified separately below.
public enum ReaderScreenGraphGenericComponentPolicy {
    public static let genericUsableTypes: Set<ComponentType> = [
        .bookshelfEmptyPage,
        .content,
        .dialog,
        .dropdown,
        .empty,
        .error,
        .errorState,
        .formSection,
        .input,
        .list,
        .listRow,
        .localBookImportPage,
        .mainTabsStructure,
        .permission,
        .permissionRequiredPage,
        .progressBar,
        .readingInfoLayer,
        .restoreProgressPage,
        .settingsListItem,
        .slider,
        .sourceFormPage,
        .sourceSwitchResultsPanel,
        .toast,
        .toggle,
        .webView,
    ]

    public static let visibleGapReasons: [ComponentType: ReaderScreenGraphVisibleGapReason] = [
        .bookChapterList: .init(
            code: "missing-collection-items",
            detail: "The only BookChapterList node has no chapters, children, or collection props."
        ),
        .bookMoreMenuPage: .init(
            code: "missing-action-model",
            detail: "The menu node has title/subtitle only and no menu items or action bindings."
        ),
        .bookSummaryCard: .init(
            code: "missing-semantic-props",
            detail: "The only BookSummaryCard node has empty props and no children."
        ),
        .remoteWebDavBooksPage: .init(
            code: "missing-collection-items",
            detail: "The page has a title only and no remote books, loading state, or actions."
        ),
        .restoreConfirmPage: .init(
            code: "missing-confirmation-model",
            detail: "Nodes expose only an optional variant and no scopes, summary, or confirm binding."
        ),
        .restoreResultPage: .init(
            code: "missing-semantic-props",
            detail: "The only RestoreResultPage node has empty props and no children."
        ),
    ]
}

/// Host-composite coverage is separate from SwiftUI contract-tree rendering. These components are
/// owned by an existing Host surface, so registering a generic renderer would draw a second,
/// recursively fabricated UI layer. Admission requires an exact schema and binding audit instead.
public enum ReaderScreenGraphHostCompositePolicy {
    public static let integratedTypes: Set<ComponentType> = [
        .readerBase,
        .readerTopArea,
        .readerBottomBar,
        .tapZones,
    ]

    public static func validate(
        type: ComponentType,
        componentId: String,
        props: [String: AnyCodable],
        bindings: [ReaderScreenGraphPlannedBinding]
    ) throws {
        guard integratedTypes.contains(type) else {
            throw ReaderScreenGraphPlannerError.componentConversion(
                componentId: componentId,
                reason: "unreviewed host-composite type \(type.rawValue)"
            )
        }
        if type == .readerBase, !bindings.isEmpty {
            guard bindings.count == 1,
                  let binding = bindings.first,
                  binding.target == "document",
                  binding.trigger == "appear",
                  binding.evidenceProperty == "explicitBinding",
                  binding.disposition == .plannedFailClosed,
                  ["pdf.open", "manga.open"].contains(binding.event.rawValue),
                  props.string("executionOwner") == "platform-renderer",
                  props.string("coreSupport") == "not-declared",
                  props.string("availability") == "capability-gated" else {
                throw ReaderScreenGraphPlannerError.bindingMismatch(
                    componentId: componentId,
                    reason: "ReaderBase document intent must remain capability-gated and planned-fail-closed"
                )
            }
            return
        }

        guard type == .tapZones else {
            guard bindings.isEmpty else {
                throw ReaderScreenGraphPlannerError.bindingMismatch(
                    componentId: componentId,
                    reason: "\(type.rawValue) host-composite has no reviewed action targets"
                )
            }
            return
        }

        guard props.string("mode") == "horizontal",
              let enabled = props.bool("enabled") else {
            throw ReaderScreenGraphPlannerError.componentConversion(
                componentId: componentId,
                reason: "TapZones mode or enablement schema drift"
            )
        }

        let enabledByTarget: [ReaderTapZoneTarget: Bool]
        switch Set(props.keys) {
        case ["enabled", "mode", "previousRatio", "controlRatio", "nextRatio",
              "previousEnabled", "controlEnabled", "nextEnabled"]:
            guard props.double("previousRatio") == 0.26,
                  props.double("controlRatio") == 0.48,
                  props.double("nextRatio") == 0.26,
                  let previousEnabled = props.bool("previousEnabled"),
                  let controlEnabled = props.bool("controlEnabled"),
                  let nextEnabled = props.bool("nextEnabled") else {
                throw ReaderScreenGraphPlannerError.componentConversion(
                    componentId: componentId,
                    reason: "TapZones reviewed geometry schema drift"
                )
            }
            enabledByTarget = [
                .previous: previousEnabled,
                .control: controlEnabled,
                .next: nextEnabled,
            ]

        case ["enabled", "mode"]:
            // PDF/manga surfaces publish target bindings but leave geometry and live boundary
            // authority to the platform renderer. All three semantic targets are present.
            guard enabled else {
                throw ReaderScreenGraphPlannerError.bindingMismatch(
                    componentId: componentId,
                    reason: "minimal TapZones schema requires enabled=true"
                )
            }
            enabledByTarget = Dictionary(
                uniqueKeysWithValues: ReaderTapZoneTarget.allCases.map { ($0, true) }
            )

        default:
            throw ReaderScreenGraphPlannerError.componentConversion(
                componentId: componentId,
                reason: "unreviewed TapZones geometry schema"
            )
        }

        guard enabled == enabledByTarget.values.contains(true) else {
            throw ReaderScreenGraphPlannerError.bindingMismatch(
                componentId: componentId,
                reason: "TapZones enabled must match target enablement"
            )
        }

        var bindingByTarget: [ReaderTapZoneTarget: ReaderScreenGraphPlannedBinding] = [:]
        for binding in bindings {
            guard let target = ReaderTapZoneTarget(rawValue: binding.target),
                  bindingByTarget[target] == nil,
                  binding.trigger == "tap",
                  binding.evidenceProperty == "explicitBinding",
                  binding.disposition == .executableRuntime else {
                throw ReaderScreenGraphPlannerError.bindingMismatch(
                    componentId: componentId,
                    reason: "TapZones requires unique explicit tap targets"
                )
            }
            bindingByTarget[target] = binding
        }

        for target in ReaderTapZoneTarget.allCases {
            guard (bindingByTarget[target] != nil) == enabledByTarget[target] else {
                throw ReaderScreenGraphPlannerError.bindingMismatch(
                    componentId: componentId,
                    reason: "TapZones binding does not match \(target.rawValue)Enabled"
                )
            }
            guard let binding = bindingByTarget[target] else { continue }
            switch target {
            case .previous:
                guard binding.event == .reader_page_prev, binding.payload.isEmpty else {
                    throw ReaderScreenGraphPlannerError.bindingMismatch(
                        componentId: componentId,
                        reason: "previous must bind reader.page.prev with empty payload"
                    )
                }
            case .control:
                guard binding.event == .reader_control_toggle,
                      Set(binding.payload.keys) == ["overlay"],
                      binding.payload.string("overlay") == "reader-control" else {
                    throw ReaderScreenGraphPlannerError.bindingMismatch(
                        componentId: componentId,
                        reason: "control must bind reader.control.toggle for reader-control"
                    )
                }
            case .next:
                guard binding.event == .reader_page_next, binding.payload.isEmpty else {
                    throw ReaderScreenGraphPlannerError.bindingMismatch(
                        componentId: componentId,
                        reason: "next must bind reader.page.next with empty payload"
                    )
                }
            }
        }
    }

    public static func action(
        for target: ReaderTapZoneTarget,
        in component: ReaderScreenGraphPlannedComponent
    ) -> ReaderScreenGraphExecutableAction? {
        guard component.component.type == .tapZones,
              component.compositionMode == .hostComposite,
              let binding = component.bindings.first(where: {
                  $0.target == target.rawValue && $0.disposition == .executableRuntime
              }) else {
            return nil
        }
        return ReaderScreenGraphExecutableAction(event: binding.event, payload: binding.payload)
    }
}

private struct ReaderScreenGraphActionHandlerKey: EnvironmentKey {
    static let defaultValue: ((UiEvent) -> Void)? = nil
}

extension EnvironmentValues {
    var readerScreenGraphActionHandler: ((UiEvent) -> Void)? {
        get { self[ReaderScreenGraphActionHandlerKey.self] }
        set { self[ReaderScreenGraphActionHandlerKey.self] = newValue }
    }
}

public struct ReaderScreenGraphExecutableAction: Sendable {
    public let event: UiEventType
    public let payload: [String: AnyCodable]

    public func makeEvent() -> UiEvent {
        UiEvent(type: event, payload: payload)
    }
}

public enum ReaderScreenGraphGenericAccessibility {
    public static func identifier(for component: ViewStateComponent) -> String {
        "reader-screen-graph-generic-\(component.type.rawValue)-\(component.id ?? "anonymous")"
    }
}

/// Strict read-only projection of the single canonical `PermissionRequiredPage` instance.
///
/// The action label is presentation data only: canonical records it as an action gap and does not
/// provide `uiEvent`/`uiEventTrigger`. Keeping the label disabled makes the missing Host binding
/// visible without inventing an executable permission request.
public struct ReaderScreenGraphPermissionRequiredPageProps: ComponentProps, Equatable, Sendable {
    public let title: String
    public let message: String
    public let actionLabel: String

    public init?(props: [String: AnyCodable]?) {
        guard let props,
              Set(props.keys) == ["title", "message", "action"],
              let title = props.string("title"), !title.isEmpty,
              let message = props.string("message"), !message.isEmpty,
              let actionLabel = props.string("action"), !actionLabel.isEmpty else {
            return nil
        }
        self.title = title
        self.message = message
        self.actionLabel = actionLabel
    }
}

/// Strict read-only projection of the canonical main-tab structure description.
///
/// This deliberately does not parse tab identities from the prose. A real `TabView` requires a
/// canonical tab item model and selection state; when those fields arrive, this decoder fails
/// closed so the richer schema must be reviewed instead of silently remaining a generic banner.
public struct ReaderScreenGraphMainTabsStructureProps: ComponentProps, Equatable, Sendable {
    public let title: String
    public let message: String

    public init?(props: [String: AnyCodable]?) {
        guard let props,
              Set(props.keys) == ["title", "message"],
              let title = props.string("title"), !title.isEmpty,
              let message = props.string("message"), !message.isEmpty else {
            return nil
        }
        self.title = title
        self.message = message
    }
}

public enum ReaderScreenGraphRestoreProgressPhase: String, Equatable, Sendable {
    case unspecified
    case running
}

/// Strict indeterminate projection for both canonical `RestoreProgressPage` instances.
///
/// Both owning routes are loading states. Neither component carries a numeric progress value, so
/// using the determinate `DemoRestoreProgressMeter` would fabricate progress. This adapter accepts
/// only the current empty schema or `variant=running`; any future phase/progress payload fails
/// closed for a new audit.
public struct ReaderScreenGraphRestoreProgressProps: ComponentProps, Equatable, Sendable {
    public let phase: ReaderScreenGraphRestoreProgressPhase

    public init?(props: [String: AnyCodable]?) {
        guard let props else { return nil }
        switch Set(props.keys) {
        case []:
            self.phase = .unspecified
        case ["variant"] where props.string("variant") == "running":
            self.phase = .running
        default:
            return nil
        }
    }
}

/// Strict read-only projection of the canonical `Error` component.
///
/// `retryable=true` is state metadata only: the node has no retry label, `uiEvent`, trigger, or
/// binding. The renderer therefore exposes the error and the missing retry binding without adding
/// an executable control. Any future retry schema fails closed for review.
public struct ReaderScreenGraphErrorProps: ComponentProps, Equatable, Sendable {
    public let message: String
    public let retryable: Bool

    public init?(props: [String: AnyCodable]?) {
        guard let props,
              Set(props.keys) == ["message", "retryable"],
              let message = props.string("message"), !message.isEmpty,
              props.bool("retryable") == true else {
            return nil
        }
        self.message = message
        self.retryable = true
    }
}

/// Registers only audited referenced types. Canonical explicit-gap types are never passed here.
public func registerReaderScreenGraphGenericComponents() {
    for type in ReaderScreenGraphGenericComponentPolicy.genericUsableTypes {
        ComponentRegistry.registerGeneric(type) { component in
            AnyView(ReaderScreenGraphGenericComponentView(component: component))
        }
    }
}

/// Conservative native families for schema-poor ScreenGraph primitives. Every family presents
/// semantic props, keeps recursive children, and carries stable accessibility identifiers.
struct ReaderScreenGraphGenericComponentView: View {
    let component: ViewStateComponent

    private var props: [String: AnyCodable] { component.props ?? [:] }
    private var accessibilityId: String {
        ReaderScreenGraphGenericAccessibility.identifier(for: component)
    }

    @ViewBuilder
    var body: some View {
        switch component.type {
        case .listRow:
            listRowFamily
        case .settingsListItem:
            settingsListItemFamily
        case .list:
            listFamily
        case .localBookImportPage, .sourceFormPage:
            capabilityContainerFamily
        case .mainTabsStructure:
            mainTabsStructureFamily
        case .formSection:
            formSectionFamily
        case .progressBar:
            progressBarFamily
        case .input:
            inputFamily
        case .dropdown, .slider, .toggle:
            readOnlyControlFamily
        case .webView:
            webViewFamily
        case .dialog:
            dialogFamily
        case .toast:
            messageFamily(role: "status")
        case .empty:
            messageFamily(role: "empty")
        case .error:
            errorFamily
        case .errorState:
            messageFamily(role: "error")
        case .permission:
            messageFamily(role: "permission")
        case .permissionRequiredPage:
            permissionRequiredPageFamily
        case .bookshelfEmptyPage:
            messageFamily(role: "empty-page")
        case .content:
            messageFamily(role: "content")
        case .sourceSwitchResultsPanel:
            messageFamily(role: "source-switch-result")
        case .readingInfoLayer:
            readingInfoFamily
        case .restoreProgressPage:
            restoreProgressPageFamily
        default:
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "generic-policy-mismatch"
            )
        }
    }

    @ViewBuilder
    private var listRowFamily: some View {
        if let title = props.string("title")
            ?? props.string("name")
            ?? props.string("label")
            ?? props.string("body")
            ?? props.string("taskId")
            ?? props.string("scope")
            ?? props.string("providerId") {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body.weight(.semibold))
                    if let detail = props.string("author") ?? props.string("state") {
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(ReaderDesignTokens.Color.muted)
                    }
                }
                Spacer(minLength: 8)
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityId)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "missing-title"
            )
        }
    }

    @ViewBuilder
    private var settingsListItemFamily: some View {
        if let title = props.string("title") ?? props.string("scope") {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    if let detail = props.string("summary") ?? props.string("availability") {
                        Text(detail)
                            .font(.caption)
                            .foregroundColor(ReaderDesignTokens.Color.muted)
                    } else if let usedBytes = props.int("usedBytes") {
                        Text(ByteCountFormatter.string(fromByteCount: Int64(usedBytes), countStyle: .file))
                            .font(.caption.monospacedDigit())
                            .foregroundColor(ReaderDesignTokens.Color.muted)
                    }
                }
                Spacer(minLength: 8)
                if component.bindings?.isEmpty == false {
                    ReaderIcon(.chevron, size: 14, accessibilityLabel: "open")
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityId)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "missing-settings-item-title-or-scope"
            )
        }
    }

    private var listFamily: some View {
        VStack(alignment: .leading, spacing: 8) {
            semanticHeading
            ChildrenView(component.children)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier(accessibilityId)
    }

    private var formSectionFamily: some View {
        VStack(alignment: .leading, spacing: 10) {
            semanticHeading
            ChildrenView(component.children)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReaderDesignTokens.Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier(accessibilityId)
    }

    private var capabilityContainerFamily: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title = props.string("title") ?? props.string("variant") {
                Text(title)
                    .font(.headline)
            }
            if let availability = props.string("formatAvailability")
                ?? props.string("coreSupport") {
                Text(availability)
                    .font(.caption.monospaced())
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            ChildrenView(component.children)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReaderDesignTokens.Color.paperSolidAlt)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .accessibilityIdentifier(accessibilityId)
    }

    @ViewBuilder
    private var progressBarFamily: some View {
        if let value = props.double("value"), value.isFinite {
            VStack(alignment: .leading, spacing: 6) {
                ProgressView(value: min(max(value, 0), 1))
                HStack {
                    Text("\(Int(min(max(value, 0), 1) * 100))%")
                    Spacer()
                    if let completed = props.int("completedChapters"),
                       let total = props.int("totalChapters") {
                        Text("\(completed)/\(total)")
                    }
                }
                .font(.caption.monospacedDigit())
                .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityId)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "invalid-progress-value"
            )
        }
    }

    @ViewBuilder
    private var inputFamily: some View {
        if let value = props.string("value") {
            Text(value)
                .font(.body)
                .frame(maxWidth: .infinity, minHeight: props.bool("multiline") == true ? 96 : 44,
                       alignment: .topLeading)
                .padding(10)
                .background(ReaderDesignTokens.Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.7), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .accessibilityIdentifier(accessibilityId)
                .allowsHitTesting(false)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "missing-input-value"
            )
        }
    }

    @ViewBuilder
    private var readOnlyControlFamily: some View {
        if let label = props.string("label") {
            HStack {
                Text(label)
                    .font(.body.weight(.semibold))
                Spacer()
                switch component.type {
                case .toggle:
                    Toggle("", isOn: .constant(props.bool("value") ?? false))
                        .labelsHidden()
                        .disabled(true)
                case .slider:
                    Slider(
                        value: .constant(props.double("value") ?? 0),
                        in: (props.double("min") ?? 0)...max(
                            props.double("max") ?? 1,
                            props.double("min") ?? 0
                        )
                    )
                    .frame(maxWidth: 150)
                    .disabled(true)
                case .dropdown:
                    Text(props.string("value") ?? "")
                        .font(.caption.monospaced())
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                default:
                    EmptyView()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityHint("Canonical structure only; runtime state owns interaction")
            .accessibilityIdentifier(accessibilityId)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "missing-control-label"
            )
        }
    }

    @ViewBuilder
    private var webViewFamily: some View {
        if let state = props.string("state") ?? props.string("url") {
            VStack(alignment: .leading, spacing: 8) {
                ReaderIcon(.globe, size: 24, accessibilityLabel: "web view")
                Text(state)
                    .font(.caption.monospaced())
                    .lineLimit(2)
                Text("Web content requires platform UI context; canonical intent remains fail-closed")
                    .font(.caption2)
                    .foregroundColor(ReaderDesignTokens.Color.muted)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .background(ReaderDesignTokens.Color.paperSolidAlt)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityIdentifier(accessibilityId)
            .allowsHitTesting(false)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "missing-webview-state-or-url"
            )
        }
    }

    @ViewBuilder
    private var mainTabsStructureFamily: some View {
        if let decoded = ReaderScreenGraphMainTabsStructureProps(props: component.props),
           component.children?.isEmpty != false {
            VStack(alignment: .leading, spacing: 6) {
                ReaderStateBanner(
                    icon: .columns,
                    title: decoded.title,
                    messages: [decoded.message]
                )
                Text("Read-only structure summary: canonical tab items and selection are unavailable")
                    .font(.caption2)
                    .foregroundColor(ReaderDesignTokens.Color.muted)
                    .accessibilityIdentifier("\(accessibilityId)-tab-model-gap")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(accessibilityId)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "invalid-read-only-main-tabs-structure-schema"
            )
        }
    }

    private var dialogFamily: some View {
        VStack(alignment: .leading, spacing: 12) {
            semanticHeading
            ChildrenView(component.children)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ReaderDesignTokens.Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier(accessibilityId)
    }

    @ViewBuilder
    private func messageFamily(role: String) -> some View {
        if props.string("title") != nil || props.string("message") != nil {
            VStack(alignment: .leading, spacing: 6) {
                semanticHeading
                if let event = props.string("uiEvent") {
                    Text("event: \(event)")
                        .font(.caption2.monospaced())
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                }
                ChildrenView(component.children)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReaderDesignTokens.Color.paperSolidAlt)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(role): \(props.string("title") ?? props.string("message") ?? "state")")
            .accessibilityIdentifier(accessibilityId)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "missing-title-and-message"
            )
        }
    }

    @ViewBuilder
    private var errorFamily: some View {
        if let decoded = ReaderScreenGraphErrorProps(props: component.props),
           component.children?.isEmpty != false {
            VStack(alignment: .leading, spacing: 6) {
                ReaderStateBanner(
                    icon: .warning,
                    title: component.type.rawValue,
                    messages: [decoded.message]
                )
                Text("retryable=true; retry unavailable: missing canonical binding")
                    .font(.caption2.monospaced())
                    .foregroundColor(ReaderDesignTokens.Color.muted)
                    .accessibilityIdentifier("\(accessibilityId)-retry-binding-gap")
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(accessibilityId)
            .allowsHitTesting(false)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "invalid-read-only-error-schema"
            )
        }
    }

    @ViewBuilder
    private var permissionRequiredPageFamily: some View {
        if let decoded = ReaderScreenGraphPermissionRequiredPageProps(props: component.props),
           component.children?.isEmpty != false {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    ReaderIcon(.permission, size: 24, accessibilityLabel: decoded.title)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(decoded.title)
                            .font(.headline)
                        Text(decoded.message)
                            .font(.subheadline)
                            .foregroundColor(ReaderDesignTokens.Color.muted)
                    }
                }

                Button(decoded.actionLabel) {}
                    .buttonStyle(.borderedProminent)
                    .disabled(true)
                    .accessibilityHint("Action unavailable: missing canonical uiEvent binding")
                    .accessibilityIdentifier("\(accessibilityId)-disabled-action")

                Text("Action unavailable: missing canonical uiEvent binding")
                    .font(.caption2)
                    .foregroundColor(ReaderDesignTokens.Color.muted)
                    .accessibilityIdentifier("\(accessibilityId)-binding-gap")
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(ReaderDesignTokens.Color.paperSolidAlt)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(accessibilityId)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "invalid-read-only-permission-required-schema"
            )
        }
    }

    @ViewBuilder
    private var restoreProgressPageFamily: some View {
        if let decoded = ReaderScreenGraphRestoreProgressProps(props: component.props),
           component.children?.isEmpty != false {
            VStack(spacing: 10) {
                DemoLoadingSpinner(size: .reader)
                if decoded.phase == .running {
                    Text(decoded.phase.rawValue)
                        .font(.caption.monospaced())
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                }
                Text("Indeterminate restore progress: canonical progress value is unavailable")
                    .font(.caption2)
                    .foregroundColor(ReaderDesignTokens.Color.muted)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("\(accessibilityId)-progress-value-gap")
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(ReaderDesignTokens.Color.paperSolidAlt)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Restore progress")
            .accessibilityValue(decoded.phase.rawValue)
            .accessibilityIdentifier(accessibilityId)
            .allowsHitTesting(false)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "invalid-indeterminate-restore-progress-schema"
            )
        }
    }

    @ViewBuilder
    private var readingInfoFamily: some View {
        if props.string("chapterTitle") != nil || props.double("progress") != nil {
            HStack(spacing: 8) {
                if let chapterTitle = props.string("chapterTitle") {
                    Text(chapterTitle)
                        .font(.caption.weight(.semibold))
                }
                Spacer(minLength: 4)
                if let progress = props.double("progress") {
                    ProgressView(value: min(max(progress, 0), 1))
                        .frame(maxWidth: 96)
                    Text("\(Int(min(max(progress, 0), 1) * 100))%")
                        .font(.caption2.monospacedDigit())
                }
            }
            .padding(.horizontal, 8)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier(accessibilityId)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "missing-chapter-and-progress"
            )
        }
    }

    @ViewBuilder
    private var semanticHeading: some View {
        if let title = props.string("title") {
            Text(title).font(.headline)
        }
        if let message = props.string("message"), message != props.string("title") {
            Text(message)
                .font(.subheadline)
                .foregroundColor(ReaderDesignTokens.Color.muted)
        }
    }
}
