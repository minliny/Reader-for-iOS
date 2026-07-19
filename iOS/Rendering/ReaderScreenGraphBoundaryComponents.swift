import ReaderUIContract
import SwiftUI

/// Canonical chapter boundary carried by the read-only `FloatingPageControl` state evidence.
public enum ReaderScreenGraphPageBoundary: String, Equatable, Sendable {
    case first
    case last
}

/// Strongly typed adapter for the canonical `reader.page.boundary` evidence node.
///
/// `FloatingPageControl` is intentionally non-interactive: both canonical instances declare
/// `uiEventTrigger=state-evidence`, so dispatching an event from this view would invent a Host/Core
/// action that the contract does not define.
public struct FloatingPageControlProps: ComponentProps, Equatable, Sendable {
    public let title: String
    public let bookId: String
    public let boundary: ReaderScreenGraphPageBoundary

    public init?(props: [String: AnyCodable]?) {
        guard let props,
              let title = props.string("title"),
              props.string("uiEvent") == "reader.page.boundary",
              props.string("uiEventTrigger") == "state-evidence",
              let payload = props.dict("uiEventPayload"),
              let bookId = payload.string("bookId"),
              let rawBoundary = payload.string("boundary"),
              let boundary = ReaderScreenGraphPageBoundary(rawValue: rawBoundary) else {
            return nil
        }
        self.title = title
        self.bookId = bookId
        self.boundary = boundary
    }
}

/// Native reader overlay for first/last chapter boundary evidence.
struct ReaderScreenGraphFloatingPageControlView: View {
    let props: FloatingPageControlProps

    var body: some View {
        HStack(spacing: 8) {
            ReaderIcon(
                props.boundary == .first ? .chevronLeft : .chevron,
                size: 16,
                accessibilityLabel: props.title
            )
            Text(props.title)
                .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                .lineLimit(1)
        }
        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        .padding(.horizontal, 14)
        .frame(minHeight: 40)
        .background(
            Capsule()
                .fill(ReaderDesignTokens.Color.controlSurfaceSolid)
                .overlay(
                    Capsule()
                        .stroke(ReaderDesignTokens.Color.mainNavBorder.opacity(0.72), lineWidth: 1)
                )
        )
        .shadow(color: ReaderDesignTokens.Color.Shadow.elevated, radius: 10, x: 0, y: 5)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(props.title)
        .accessibilityValue("book \(props.bookId), boundary \(props.boundary.rawValue)")
        .accessibilityIdentifier("reader-screen-graph-floating-page-control-\(props.boundary.rawValue)")
        .allowsHitTesting(false)
    }
}

public func registerReaderScreenGraphBoundaryComponents() {
    ComponentRegistry.register(.floatingPageControl) { component in
        guard let props = FloatingPageControlProps(props: component.props) else {
            return AnyView(
                UnsupportedComponentFailureView(
                    type: component.type,
                    componentId: component.id,
                    reason: "invalid-reader-page-boundary-state-evidence"
                )
            )
        }
        return AnyView(ReaderScreenGraphFloatingPageControlView(props: props))
    }
}
