import SwiftUI

/// One shared TextKit configuration, dispatched to continuous scrolling or
/// native linked-container pages. Core positions and callbacks have one owner.
struct ReaderTextBodySurface: View {
    let surface: ReaderTextSurface
    let mode: ReaderPageMode
    let transition: ReaderPageTransition
    let pageBoundary: (Int) -> Void
    var alignPageBottom = false
    var body: some View {
        if mode == .paged {
            ReaderPagedTextSurface(content: surface.content, scalarOffset: surface.scalarOffset,
                restorationID: surface.restorationID, fontSize: surface.fontSize, lineHeight: surface.lineHeight,
                horizontalInset: surface.horizontalInset, safeLeft: surface.safeLeft, safeRight: surface.safeRight,
                bottomInset: surface.bottomInset, paper: surface.paper, positionChanged: surface.positionChanged,
                centerTapped: surface.centerTapped, selectionChanged: surface.selectionChanged,
                bookmarkSelectionAction: surface.bookmarkSelectionAction, noteSelectionAction: surface.noteSelectionAction,
                fontName: surface.fontName, paragraphSpacing: surface.paragraphSpacing, letterSpacing: surface.letterSpacing,
                firstLineIndentEm: surface.firstLineIndentEm, alignment: surface.alignment, highlights: surface.highlights,
                pageTurnID: surface.pageTurnID, automaticPageEnabled: surface.automaticPageEnabled,
                pageCommitted: surface.pageCommitted, layoutReady: surface.layoutReady,
                manualInteraction: surface.manualInteraction, reducePageMotion: surface.reducePageMotion,
                automaticHighlightProgress: surface.automaticHighlightProgress,
                transition: transition, pageBoundary: pageBoundary,
                longPressSelectText: surface.longPressSelectText, readerFont: surface.readerFont,
                alignPageBottom: alignPageBottom, imageAssets: surface.imageAssets)
        } else { surface }
    }
}
