import SwiftUI
import UIKit

/// Geometry from Host@33f7c7b. All values are logical points, never screen pixels.
enum ReaderMetrics {
    static let expandedMinWidth: CGFloat = 600
    static let screenInset: CGFloat = 19
    static let shelfMaxWidth: CGFloat = 352
    static let shelfWideMaxWidth: CGFloat = 620
    static let headerHeight: CGFloat = 52
    static let headerTop: CGFloat = 8
    static let headerRadius: CGFloat = 18
    static let minimumHitSize: CGFloat = 44
    static let controlGap: CGFloat = 10
    static let cardPadding: CGFloat = 14
    static let continueHeight: CGFloat = 100
    static let continueRadius: CGFloat = 18
    static let continueCover = CGSize(width: 48, height: 72)
    static let continueAction = CGSize(width: 54, height: 40)
    static let listCover = CGSize(width: 48, height: 72)
    static let wideListCover = CGSize(width: 64, height: 104)
    static let coverRadius: CGFloat = 8
    static let listCoverRadius: CGFloat = 6
    static let titleBodyGap: CGFloat = 18
    static let chapterTitleLineHeight: CGFloat = 28.75
    static let quickHeight: CGFloat = 330
    static let wideQuickHeight: CGFloat = 252
    static let fullHeight: CGFloat = 736
    static let wideFullHeight: CGFloat = 852
    static let controlMaxWidth: CGFloat = 364
    static let wideControlMaxWidth: CGFloat = 720
    static let controlBottomGap: CGFloat = 19
    static let fullBottomGap: CGFloat = 20
    static let controlSideGap: CGFloat = 13
    static let quickBottomRadius: CGFloat = 24
    static let moduleNavigationHeight: CGFloat = 80
    static let moduleNavigationBottomGap: CGFloat = 14
    static let brightnessRail = CGSize(width: 38, height: 190)

    static func shelfContentWidth(_ width: CGFloat) -> CGFloat {
        min(width >= expandedMinWidth ? shelfWideMaxWidth : shelfMaxWidth, max(0, width - screenInset * 2))
    }
    static func gridCoverSize(contentWidth: CGFloat, expanded: Bool = false) -> CGSize {
        let maximum: CGFloat = expanded ? 186.672 : 96.656
        let width = min(maximum, max(0, (contentWidth - 16) / 3))
        return CGSize(width: width, height: width * (expanded ? 280 / 186.672 : 145.443 / 96.656))
    }
    static func gridSpacing(contentWidth: CGFloat, expanded: Bool = false) -> CGFloat {
        min(30, max(expanded ? 0 : 8, (contentWidth - gridCoverSize(contentWidth: contentWidth, expanded: expanded).width * 3) / 2))
    }
    static func readingHorizontalInset(width: CGFloat, safeHorizontal: CGFloat = 0) -> CGFloat {
        let authored = width >= expandedMinWidth ? max(44.44, (width - 720) / 2) : max(16, min(28, 24 * width / 390))
        return max(authored, safeHorizontal)
    }
    static func readingBottomInset(width: CGFloat, safeBottom: CGFloat = 0) -> CGFloat {
        max(width >= expandedMinWidth ? 56.44 : 47.99, safeBottom)
    }
    static func controlWidth(viewport: CGFloat, safeHorizontal: CGFloat = 0) -> CGFloat {
        let expanded = viewport >= expandedMinWidth
        return min(expanded ? wideControlMaxWidth : controlMaxWidth,
                   max(0, viewport - max(expanded ? 26 : controlSideGap, safeHorizontal) - max(expanded ? 14 : controlSideGap, safeHorizontal)))
    }
    static func controlFullHeight(viewportHeight: CGFloat, topBarTop: CGFloat, safeBottom: CGFloat, expanded: Bool) -> CGFloat {
        let top = max(88, topBarTop + 54 + 8)
        return min(expanded ? wideFullHeight : fullHeight, max(0, viewportHeight - top - max(fullBottomGap, safeBottom)))
    }

    /// Convert a SwiftUI viewport that already excludes safe areas back into
    /// the window coordinate system used by frozen ReaderLayoutGeometry.ts.
    static func controlViewport(size: CGSize, safe: EdgeInsets) -> ReaderControlViewportLayout {
        let windowWidth = size.width + safe.leading + safe.trailing
        let windowHeight = size.height + safe.top + safe.bottom
        let expanded = windowWidth >= expandedMinWidth
        let horizontal = max(safe.leading, safe.trailing)
        let barSide = max(expanded ? 29 : 15, horizontal)
        let barTop = max(19, safe.top + 10)
        let width = controlWidth(viewport: windowWidth, safeHorizontal: horizontal)
        let left = expanded ? windowWidth - max(14, horizontal) - width : (windowWidth - width) / 2
        let full = controlFullHeight(viewportHeight: windowHeight, topBarTop: barTop,
                                     safeBottom: safe.bottom, expanded: expanded)
        return ReaderControlViewportLayout(
            topBarWidth: min(expanded ? 702 : 360, max(0, windowWidth - barSide * 2)),
            topBarPadding: max(0, barTop - safe.top),
            topBarOffsetX: (safe.trailing - safe.leading) / 2,
            dockWidth: width,
            dockOffsetX: left + width / 2 - safe.leading - size.width / 2,
            dockBottomPadding: max(0, max(expanded ? 33 : 19, safe.bottom) - safe.bottom),
            fullHeight: full,
            quickHeight: min(expanded ? Self.wideQuickHeight : Self.quickHeight, full))
    }

    static func controlContentCategory(for size: DynamicTypeSize) -> UIContentSizeCategory {
        switch size {
        case .xSmall: return .extraSmall
        case .small: return .small
        case .medium: return .medium
        case .large: return .large
        case .xLarge: return .extraLarge
        case .xxLarge: return .extraExtraLarge
        case .xxxLarge: return .extraExtraExtraLarge
        case .accessibility1: return .accessibilityMedium
        case .accessibility2: return .accessibilityLarge
        case .accessibility3: return .accessibilityExtraLarge
        case .accessibility4: return .accessibilityExtraExtraLarge
        case .accessibility5: return .accessibilityExtraExtraExtraLarge
        @unknown default: return .accessibilityExtraExtraExtraLarge
        }
    }

    static func controlContent(category: UIContentSizeCategory) -> ReaderControlContentLayout {
        ReaderControlContentLayout(category: category)
    }
}

/// One content budget for the dock. The frozen <= Large path keeps authored
/// points; larger text measures the registered fonts at the actual category.
struct ReaderControlContentLayout {
    let adaptsText: Bool
    let actionLabelHeight: CGFloat
    let moduleLabelHeight: CGFloat
    let chapterTitleHeight: CGFloat
    let progressLabelHeight: CGFloat
    let headerLabelHeight: CGFloat
    let collapseLabelHeight: CGFloat
    let moduleMinimumWidth: CGFloat

    init(category: UIContentSizeCategory) {
        adaptsText = ![UIContentSizeCategory.extraSmall, .small, .medium, .large].contains(category)
        let traits = UITraitCollection(preferredContentSizeCategory: category)
        let metrics = UIFontMetrics(forTextStyle: .body)
        func scaledFont(_ face: ReaderTypeface, _ size: CGFloat, _ weight: CGFloat = 400) -> UIFont {
            metrics.scaledFont(for: ReaderFonts.uiFont(face, size: size, weight: weight), compatibleWith: traits)
        }
        func line(_ face: ReaderTypeface, _ size: CGFloat, _ weight: CGFloat = 400) -> CGFloat {
            // Include the registered CJK face in the budget for labels whose
            // Latin font delegates Chinese glyphs to a fallback.
            ceil(max(scaledFont(face, size, weight).lineHeight, scaledFont(.ui, size).lineHeight))
        }
        actionLabelHeight = adaptsText ? max(13, line(.inter, 11, 800)) : 13
        moduleLabelHeight = adaptsText ? max(15, line(.uiBold, 10, 700)) : 15
        chapterTitleHeight = adaptsText ? max(34, line(.inter, 13, 700)) : 34
        progressLabelHeight = adaptsText ? max(30, line(.inter, 9)) : 30
        headerLabelHeight = adaptsText ? max(20, line(.uiBold, 14, 700)) : 20
        collapseLabelHeight = adaptsText ? max(14, line(.uiBold, 10, 700)) : 14
        if adaptsText {
            let font = scaledFont(.uiBold, 10, 700)
            moduleMinimumWidth = max(ReaderMetrics.minimumHitSize,
                ceil(["阅读", "目录", "外观", "设置"].map { ($0 as NSString).size(withAttributes: [.font: font]).width }.max() ?? 0) + 20)
        } else { moduleMinimumWidth = 0 }
    }

    let quickTop: CGFloat = 29
    let headerTop: CGFloat = 19
    let headerGap: CGFloat = 8
    let bottomGap: CGFloat = 13
    let navigationGap: CGFloat = 18
    let navigationExpansionOffset: CGFloat = 20
    let quickSectionGap: CGFloat = 6
    let chapterRowHeight: CGFloat = 52.563
    var stepSize: CGFloat { adaptsText ? 44 : 34 }
    var actionHeight: CGFloat { adaptsText ? max(44, actionLabelHeight + 20) : 55.438 }
    var actionPanelHeight: CGFloat { adaptsText ? actionHeight * 3 + 34 : 75.438 }
    var summaryHeight: CGFloat { adaptsText ? chapterTitleHeight * 2 + stepSize + progressLabelHeight + 44 + 46 : 108.563 }
    var quickNaturalHeight: CGFloat { adaptsText ? summaryHeight + quickSectionGap + actionPanelHeight : 190 }
    var moduleButtonHeight: CGFloat { 42 + 5 + moduleLabelHeight }
    var navigationHeight: CGFloat { moduleButtonHeight + 18 }
    var headerHeight: CGFloat { adaptsText ? headerLabelHeight + max(44, collapseLabelHeight + 16) + 8 : 30 }
    var fullTop: CGFloat { headerTop + headerHeight + headerGap }

    func contentTop(progress: CGFloat) -> CGFloat { quickTop + (fullTop - quickTop) * progress }
    func quickViewportHeight(dockHeight: CGFloat) -> CGFloat {
        min(quickNaturalHeight, max(0, dockHeight - quickTop - navigationHeight - bottomGap - navigationGap))
    }
    func fullViewportHeight(dockHeight: CGFloat) -> CGFloat { max(0, dockHeight - fullTop - bottomGap) }
    func quickDockHeight(baseline: CGFloat, fullHeight: CGFloat) -> CGFloat {
        guard adaptsText else { return min(baseline, fullHeight) }
        return min(fullHeight, max(baseline, quickTop + quickNaturalHeight + navigationHeight + bottomGap + navigationGap))
    }
    func needsIntegratedScroll(quickHeight: CGFloat) -> Bool {
        adaptsText || quickHeight < quickTop + navigationHeight + bottomGap + navigationGap + ReaderMetrics.minimumHitSize
    }
    func integratedTop(hasHeader: Bool) -> CGFloat { hasHeader ? headerTop : quickTop }
    func integratedViewportHeight(dockHeight: CGFloat, hasHeader: Bool) -> CGFloat {
        max(0, dockHeight - integratedTop(hasHeader: hasHeader) - bottomGap)
    }
    func integratedPanelHeight(fullHeight: CGFloat) -> CGFloat {
        max(120, fullViewportHeight(dockHeight: fullHeight))
    }
}

struct ReaderControlViewportLayout {
    let topBarWidth: CGFloat
    let topBarPadding: CGFloat
    let topBarOffsetX: CGFloat
    let dockWidth: CGFloat
    let dockOffsetX: CGFloat
    let dockBottomPadding: CGFloat
    let fullHeight: CGFloat
    let quickHeight: CGFloat
}
