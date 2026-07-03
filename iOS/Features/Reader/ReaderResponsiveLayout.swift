import CoreGraphics
import SwiftUI

enum ReaderViewportClass: Equatable {
    case phonePortrait
    case expandedWidth
    case tabletExpanded
    case compactLandscape
}

enum ReaderControlPlacement: Equatable {
    case bottom
    case trailingDock
}

struct ReaderContentInsets: Equatable {
    let top: CGFloat
    let leading: CGFloat
    let bottom: CGFloat
    let trailing: CGFloat

    var edgeInsets: EdgeInsets {
        EdgeInsets(top: top, leading: leading, bottom: bottom, trailing: trailing)
    }
}

struct ReaderResponsiveLayout: Equatable {
    let viewportClass: ReaderViewportClass
    let controlPlacement: ReaderControlPlacement
    let readingInsets: ReaderContentInsets
    let dockRightInset: CGFloat
    let dockWidth: CGFloat
    let dockSheetHeight: CGFloat
    let dockNavBottomInset: CGFloat
    let dockNavHeight: CGFloat
    let dockNavGap: CGFloat
    let dockControlActionRowHeight: CGFloat
    let dockChapterPanelHeight: CGFloat
    let compactModuleNav: Bool

    var usesTrailingDock: Bool {
        controlPlacement == .trailingDock
    }

    static func make(size: CGSize) -> ReaderResponsiveLayout {
        let viewportClass = classify(size: size)
        switch viewportClass {
        case .phonePortrait:
            return ReaderResponsiveLayout(
                viewportClass: viewportClass,
                controlPlacement: .bottom,
                readingInsets: ReaderContentInsets(
                    top: ReaderDesignTokens.immersiveReadingLayerTopInset,
                    leading: ReaderDesignTokens.immersiveReadingLayerSideInset,
                    bottom: ReaderDesignTokens.immersiveReadingLayerBottomInset,
                    trailing: ReaderDesignTokens.immersiveReadingLayerSideInset
                ),
                dockRightInset: ReaderDesignTokens.readerModuleNavSideInset,
                dockWidth: max(0, size.width - ReaderDesignTokens.readerModuleNavSideInset * 2),
                dockSheetHeight: ReaderDesignTokens.readerControlSheetHeight,
                dockNavBottomInset: ReaderDesignTokens.readerModuleNavBottomInset,
                dockNavHeight: ReaderDesignTokens.readerModuleNavMinHeight,
                dockNavGap: ReaderDesignTokens.readerControlSheetGap,
                dockControlActionRowHeight: ReaderDesignTokens.readerControlMainActionRowHeight,
                dockChapterPanelHeight: ReaderDesignTokens.readerControlChapterPanelHeight,
                compactModuleNav: false
            )

        case .expandedWidth:
            let dockWidth = min(
                ReaderDesignTokens.readerDockMaxWidth,
                max(0, size.width - ReaderDesignTokens.readerDockExpandedWidthInsetBudget)
            )
            return ReaderResponsiveLayout(
                viewportClass: viewportClass,
                controlPlacement: .trailingDock,
                readingInsets: ReaderContentInsets(
                    top: ReaderDesignTokens.readerDockReadingTopInset,
                    leading: ReaderDesignTokens.readerDockReadingSideInset,
                    bottom: ReaderDesignTokens.readerDockReadingBottomInset,
                    trailing: ReaderDesignTokens.readerDockReadingSideInset
                ),
                dockRightInset: ReaderDesignTokens.readerDockExpandedRightInset,
                dockWidth: dockWidth,
                dockSheetHeight: ReaderDesignTokens.readerDockWideSheetHeight,
                dockNavBottomInset: ReaderDesignTokens.readerDockNavBottomInset,
                dockNavHeight: ReaderDesignTokens.readerDockNavHeight,
                dockNavGap: ReaderDesignTokens.readerDockGap,
                dockControlActionRowHeight: ReaderDesignTokens.readerDockControlActionRowHeight,
                dockChapterPanelHeight: ReaderDesignTokens.readerDockChapterPanelHeight,
                compactModuleNav: false
            )

        case .tabletExpanded:
            let dockWidth = min(
                ReaderDesignTokens.readerDockMaxWidth,
                max(0, size.width - ReaderDesignTokens.readerDockTabletRightInset * 2)
            )
            let trailing = ReaderDesignTokens.readerDockTabletRightInset
                + dockWidth
                + ReaderDesignTokens.readerDockReadingAvoidanceGap
            return ReaderResponsiveLayout(
                viewportClass: viewportClass,
                controlPlacement: .trailingDock,
                readingInsets: ReaderContentInsets(
                    top: ReaderDesignTokens.readerDockReadingTopInset,
                    leading: ReaderDesignTokens.readerDockReadingSideInset,
                    bottom: ReaderDesignTokens.readerDockReadingBottomInset,
                    trailing: trailing
                ),
                dockRightInset: ReaderDesignTokens.readerDockTabletRightInset,
                dockWidth: dockWidth,
                dockSheetHeight: ReaderDesignTokens.readerDockWideSheetHeight,
                dockNavBottomInset: ReaderDesignTokens.readerDockNavBottomInset,
                dockNavHeight: ReaderDesignTokens.readerDockNavHeight,
                dockNavGap: ReaderDesignTokens.readerDockGap,
                dockControlActionRowHeight: ReaderDesignTokens.readerDockControlActionRowHeight,
                dockChapterPanelHeight: ReaderDesignTokens.readerDockChapterPanelHeight,
                compactModuleNav: false
            )

        case .compactLandscape:
            let dockWidth = min(
                ReaderDesignTokens.readerDockMaxWidth,
                max(0, size.width * ReaderDesignTokens.readerDockCompactWidthRatio)
            )
            let trailing = max(
                ReaderDesignTokens.readerDockCompactReadingRightInset,
                ReaderDesignTokens.readerDockCompactRightInset
                    + dockWidth
                    + ReaderDesignTokens.readerDockCompactReadingGap
            )
            return ReaderResponsiveLayout(
                viewportClass: viewportClass,
                controlPlacement: .trailingDock,
                readingInsets: ReaderContentInsets(
                    top: ReaderDesignTokens.readerDockCompactReadingTopInset,
                    leading: ReaderDesignTokens.readerDockCompactReadingLeftInset,
                    bottom: ReaderDesignTokens.readerDockCompactReadingBottomInset,
                    trailing: trailing
                ),
                dockRightInset: ReaderDesignTokens.readerDockCompactRightInset,
                dockWidth: dockWidth,
                dockSheetHeight: ReaderDesignTokens.readerDockCompactSheetHeight,
                dockNavBottomInset: ReaderDesignTokens.readerDockCompactNavBottomInset,
                dockNavHeight: ReaderDesignTokens.readerDockCompactNavHeight,
                dockNavGap: ReaderDesignTokens.readerDockGap,
                dockControlActionRowHeight: ReaderDesignTokens.readerDockCompactControlActionRowHeight,
                dockChapterPanelHeight: ReaderDesignTokens.readerDockCompactChapterPanelHeight,
                compactModuleNav: true
            )
        }
    }

    private static func classify(size: CGSize) -> ReaderViewportClass {
        guard size.width > 0, size.height > 0 else { return .phonePortrait }
        if size.width > size.height, size.height <= ReaderDesignTokens.readerCompactLandscapeMaxHeight {
            return .compactLandscape
        }
        if size.width >= ReaderDesignTokens.readerTabletExpandedMinWidth {
            return .tabletExpanded
        }
        if size.width >= ReaderDesignTokens.readerExpandedWidthMinWidth {
            return .expandedWidth
        }
        return .phonePortrait
    }
}

struct ReaderResponsiveVisualAudit: Equatable {
    let viewportSize: CGSize
    let layout: ReaderResponsiveLayout
    let readingRect: CGRect
    let topBarRect: CGRect
    let dockPanelRect: CGRect?
    let dockModuleNavRect: CGRect?
    let dockStackRect: CGRect?

    var viewportRect: CGRect {
        CGRect(origin: .zero, size: viewportSize)
    }

    var requiresHardDockAvoidance: Bool {
        layout.viewportClass == .tabletExpanded || layout.viewportClass == .compactLandscape
    }

    var readingAvoidsDockWhenRequired: Bool {
        guard requiresHardDockAvoidance, let dockStackRect else { return true }
        return readingRect.maxX <= dockStackRect.minX
    }

    var topBarClearsReadingContent: Bool {
        topBarRect.maxY <= readingRect.minY
    }

    var readingRectInsideViewport: Bool {
        viewportRect.contains(readingRect)
    }

    var dockStackInsideViewport: Bool {
        guard let dockStackRect else { return true }
        return viewportRect.contains(dockStackRect)
    }

    static func make(size: CGSize) -> ReaderResponsiveVisualAudit {
        let layout = ReaderResponsiveLayout.make(size: size)
        let readingRect = CGRect(
            x: layout.readingInsets.leading,
            y: layout.readingInsets.top,
            width: max(0, size.width - layout.readingInsets.leading - layout.readingInsets.trailing),
            height: max(0, size.height - layout.readingInsets.top - layout.readingInsets.bottom)
        )

        let topInset = layout.viewportClass == .compactLandscape
            ? ReaderDesignTokens.readerTopCompactTopInset
            : ReaderDesignTokens.readerTopTopInset
        let topHorizontalInset = layout.viewportClass == .tabletExpanded
            ? ReaderDesignTokens.readerTopTabletSideInset
            : ReaderDesignTokens.readerTopSideInset
        let topHeight = layout.viewportClass == .compactLandscape
            ? ReaderDesignTokens.readerTopCompactMinHeight
            : ReaderDesignTokens.readerTopMinHeight
        let topBarRect = CGRect(
            x: topHorizontalInset,
            y: topInset,
            width: max(0, size.width - topHorizontalInset * 2),
            height: topHeight
        )

        guard layout.usesTrailingDock else {
            return ReaderResponsiveVisualAudit(
                viewportSize: size,
                layout: layout,
                readingRect: readingRect,
                topBarRect: topBarRect,
                dockPanelRect: nil,
                dockModuleNavRect: nil,
                dockStackRect: nil
            )
        }

        let dockX = max(0, size.width - layout.dockRightInset - layout.dockWidth)
        let navY = max(0, size.height - layout.dockNavBottomInset - layout.dockNavHeight)
        let panelY = max(0, navY - layout.dockNavGap - layout.dockSheetHeight)
        let dockPanelRect = CGRect(
            x: dockX,
            y: panelY,
            width: layout.dockWidth,
            height: layout.dockSheetHeight
        )
        let dockModuleNavRect = CGRect(
            x: dockX,
            y: navY,
            width: layout.dockWidth,
            height: layout.dockNavHeight
        )
        let stackMinY = min(dockPanelRect.minY, dockModuleNavRect.minY)
        let stackMaxY = max(dockPanelRect.maxY, dockModuleNavRect.maxY)
        let dockStackRect = CGRect(
            x: dockX,
            y: stackMinY,
            width: layout.dockWidth,
            height: stackMaxY - stackMinY
        )

        return ReaderResponsiveVisualAudit(
            viewportSize: size,
            layout: layout,
            readingRect: readingRect,
            topBarRect: topBarRect,
            dockPanelRect: dockPanelRect,
            dockModuleNavRect: dockModuleNavRect,
            dockStackRect: dockStackRect
        )
    }
}
