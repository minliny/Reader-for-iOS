import ReaderUIContract
import SwiftUI

/// Exact projection of the canonical ReadingBackgroundLayer primitive.
///
/// All 21 current instances are contract-tree leaves owned by `host-store`, carry only
/// `theme=paper`, and have no action or state-event bindings. Unknown theme IDs or props fail
/// closed so a future theme schema cannot silently inherit today's rendering semantics.
public struct ReaderScreenGraphReadingBackgroundLayerProps: ComponentProps, Equatable, Sendable {
    public let themeEvidence: String

    public init?(component: ViewStateComponent) {
        guard component.type == .readingBackgroundLayer,
              let props = component.props,
              Set(props.keys) == ["theme"],
              props.string("theme") == "paper",
              component.bindings?.isEmpty != false,
              component.children?.isEmpty != false else {
            return nil
        }
        self.themeEvidence = "paper"
    }

    public init?(props: [String: AnyCodable]?) {
        guard let props,
              Set(props.keys) == ["theme"],
              props.string("theme") == "paper" else {
            return nil
        }
        self.themeEvidence = "paper"
    }
}

public struct ReaderScreenGraphReadingBackgroundLayerOwner: Equatable, Sendable {
    public let themeId: String
    public let isNight: Bool
}

/// The Host palette, not ScreenGraph fixture evidence, owns the rendered theme. Keeping this
/// projection testable prevents a future renderer from reintroducing `theme=paper` as local state.
public enum ReaderScreenGraphReadingBackgroundLayerPresentation {
    public static func owner(
        for palette: ReaderThemePalette
    ) -> ReaderScreenGraphReadingBackgroundLayerOwner {
        .init(themeId: palette.themeId, isNight: palette.isNight)
    }

    public static func backgroundColor(for palette: ReaderThemePalette) -> Color {
        palette.readingPaper
    }
}

/// Planner-level admission keeps ownership and composition proof beside the renderer schema.
/// Host-composite ancestors remain opaque in ViewState; this policy never asks the planner to
/// project or recursively render their descendants.
public enum ReaderScreenGraphReadingBackgroundLayerPolicy {
    public static func admits(_ planned: ReaderScreenGraphPlannedComponent) -> Bool {
        planned.component.type == .readingBackgroundLayer
            && planned.stateAuthorities == ["host-store"]
            && planned.compositionMode == .contractTree
            && planned.bindings.isEmpty
            && planned.stateEventEvidence.isEmpty
            && planned.children.isEmpty
            && ReaderScreenGraphReadingBackgroundLayerProps(component: planned.component) != nil
    }
}

/// A decorative native background with no interaction or local state ownership.
struct ReaderScreenGraphReadingBackgroundLayerView: View {
    let component: ViewStateComponent
    @Environment(\.readerThemePalette) private var palette

    @ViewBuilder
    var body: some View {
        if ReaderScreenGraphReadingBackgroundLayerProps(component: component) != nil {
            Rectangle()
                .fill(
                    ReaderScreenGraphReadingBackgroundLayerPresentation.backgroundColor(
                        for: palette
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        } else {
            UnsupportedComponentFailureView(
                type: component.type,
                componentId: component.id,
                reason: "invalid-reading-background-schema-or-ownership"
            )
        }
    }
}

public func registerReaderScreenGraphReadingBackgroundLayerComponent() {
    ComponentRegistry.register(.readingBackgroundLayer) { component in
        AnyView(ReaderScreenGraphReadingBackgroundLayerView(component: component))
    }
}
