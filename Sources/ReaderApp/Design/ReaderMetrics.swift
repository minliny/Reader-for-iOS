import SwiftUI

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
