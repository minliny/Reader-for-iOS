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
/// currently has no per-type props schema and bindings do not carry trigger semantics, so only
/// these types have enough stable data for a conservative generic SwiftUI family.
public enum ReaderScreenGraphGenericComponentPolicy {
    public static let genericUsableTypes: Set<ComponentType> = [
        .bookshelfEmptyPage,
        .button,
        .content,
        .dialog,
        .empty,
        .errorState,
        .formSection,
        .list,
        .listRow,
        .permission,
        .readingBackgroundLayer,
        .readingInfoLayer,
        .sourceSwitchResultsPanel,
        .toast,
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
        .error: .init(
            code: "missing-retry-binding",
            detail: "The Error node declares retryable=true but has no retry event or trigger binding."
        ),
        .floatingPageControl: .init(
            code: "missing-trigger-semantics",
            detail: "Bindings identify reader.page.boundary evidence but not a user trigger or direction."
        ),
        .localBookImportPage: .init(
            code: "missing-action-model",
            detail: "The page has a title only and no picker/import action binding."
        ),
        .mainTabsStructure: .init(
            code: "missing-tab-items",
            detail: "The node has descriptive text but no tab item model, selection, or bindings."
        ),
        .permissionRequiredPage: .init(
            code: "missing-action-binding",
            detail: "The action label exists, but canonical records it as an action gap without uiEvent."
        ),
        .remoteWebDavBooksPage: .init(
            code: "missing-collection-items",
            detail: "The page has a title only and no remote books, loading state, or actions."
        ),
        .restoreConfirmPage: .init(
            code: "missing-confirmation-model",
            detail: "Nodes expose only an optional variant and no scopes, summary, or confirm binding."
        ),
        .restoreProgressPage: .init(
            code: "missing-progress-props",
            detail: "Nodes expose only an optional variant and no progress, phase, or status values."
        ),
        .restoreResultPage: .init(
            code: "missing-semantic-props",
            detail: "The only RestoreResultPage node has empty props and no children."
        ),
        .tapZones: .init(
            code: "missing-tap-zone-definitions",
            detail: "enabled is present, but zone geometry and previous/next/control trigger bindings are absent."
        ),
    ]
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

/// Converts only an explicit schema 1.1 tap binding into a callback payload. Merely having
/// `uiEvent` is insufficient because stateEventEvidence intentionally uses the same evidence key.
public enum ReaderScreenGraphGenericActionResolver {
    public static func action(for component: ViewStateComponent) -> ReaderScreenGraphExecutableAction? {
        guard component.type == .button,
              let props = component.props,
              props.string("uiEventTrigger") == "tap",
              let rawEvent = props.string("uiEvent"),
              let event = UiEventType(rawValue: rawEvent) else {
            return nil
        }
        return ReaderScreenGraphExecutableAction(
            event: event,
            payload: props.dict("uiEventPayload") ?? [:]
        )
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
    @Environment(\.readerScreenGraphActionHandler) private var actionHandler

    private var props: [String: AnyCodable] { component.props ?? [:] }
    private var accessibilityId: String {
        ReaderScreenGraphGenericAccessibility.identifier(for: component)
    }

    @ViewBuilder
    var body: some View {
        switch component.type {
        case .button:
            buttonFamily
        case .listRow:
            listRowFamily
        case .list:
            listFamily
        case .formSection:
            formSectionFamily
        case .dialog:
            dialogFamily
        case .toast:
            messageFamily(role: "status")
        case .empty:
            messageFamily(role: "empty")
        case .errorState:
            messageFamily(role: "error")
        case .permission:
            messageFamily(role: "permission")
        case .bookshelfEmptyPage:
            messageFamily(role: "empty-page")
        case .content:
            messageFamily(role: "content")
        case .sourceSwitchResultsPanel:
            messageFamily(role: "source-switch-result")
        case .readingBackgroundLayer:
            readingBackgroundFamily
        case .readingInfoLayer:
            readingInfoFamily
        default:
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "generic-policy-mismatch"
            )
        }
    }

    @ViewBuilder
    private var buttonFamily: some View {
        if let label = props.string("label") {
            let executableAction = ReaderScreenGraphGenericActionResolver.action(for: component)
            VStack(alignment: .leading, spacing: 4) {
                Button(label) {
                    guard let executableAction else { return }
                    actionHandler?(executableAction.makeEvent())
                }
                .buttonStyle(.borderedProminent)
                .disabled(executableAction == nil || actionHandler == nil)
                .accessibilityIdentifier(accessibilityId)
                .accessibilityHint(executableAction?.event.rawValue ?? "missing-ui-event-binding")

                if executableAction == nil {
                    Text("Action unavailable: missing uiEvent binding")
                        .font(.caption2)
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                        .accessibilityIdentifier("\(accessibilityId)-binding-gap")
                }
            }
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "missing-label"
            )
        }
    }

    @ViewBuilder
    private var listRowFamily: some View {
        if let title = props.string("title") {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.body.weight(.semibold))
                    if let author = props.string("author") {
                        Text(author)
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
    private var readingBackgroundFamily: some View {
        if let theme = props.string("theme") {
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    theme == "paper"
                        ? ReaderDesignTokens.Color.readerPaperGradientStart
                        : ReaderDesignTokens.Color.paperSolidAlt
                )
                .frame(minHeight: 24)
                .overlay(alignment: .bottomLeading) {
                    Text("Theme: \(theme)")
                        .font(.caption2)
                        .foregroundColor(ReaderDesignTokens.Color.muted)
                        .padding(6)
                }
                .accessibilityLabel("Reading background theme \(theme)")
                .accessibilityIdentifier(accessibilityId)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "missing-theme"
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
