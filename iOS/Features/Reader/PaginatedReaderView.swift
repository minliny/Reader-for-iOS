import SwiftUI
import ReaderAppSupport
import ReaderShellValidation

/// Paginated reader view: splits text into pages, displays one at a time
/// with tap zones and slide animation.
///
/// Used by `ReaderView` when `displaySettings.pageTurnMode == .paginated`.
/// Tap zones: left third = previous page, center third = toggle UI,
/// right third = next page. Also supports horizontal swipe gestures.
///
/// When `displaySettings.dualPageEnabled` is true and the viewport is
/// landscape (width > height), two pages are shown side by side.
struct PaginatedReaderView: View {
    let text: String
    let displaySettings: ReaderDisplaySettings
    let onToggleUI: () -> Void
    let onProgressUpdate: (Double) -> Void
    @ObservedObject var pageTurnTrigger: PageTurnTrigger

    @State private var pages: [PageRange] = []
    @State private var currentPageIndex: Int = 0
    @State private var availableSize: CGSize = .zero
    @State private var slideEdge: Edge = .trailing

    private var isDualPageMode: Bool {
        displaySettings.dualPageEnabled && availableSize.width > availableSize.height
    }

    private var pageStride: Int {
        isDualPageMode ? 2 : 1
    }

    var body: some View {
        GeometryReader { geo in
            content(size: geo.size)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func content(size: CGSize) -> some View {
        Group {
            if pages.isEmpty {
                Color.clear.onAppear {
                    availableSize = size
                    recomputePages()
                }
            } else {
                pageStack
            }
        }
        .onChange(of: size) { newSize in
            availableSize = newSize
            recomputePages()
        }
        .onChange(of: text) { _ in
            recomputePages()
            currentPageIndex = 0
        }
        .onChange(of: displaySettings.fontSize) { _ in recomputePages() }
        .onChange(of: displaySettings.lineSpacing) { _ in recomputePages() }
        .onChange(of: displaySettings.horizontalPadding) { _ in recomputePages() }
        .onChange(of: displaySettings.verticalPadding) { _ in recomputePages() }
        .onChange(of: displaySettings.dualPageEnabled) { _ in recomputePages() }
    }

    @ViewBuilder
    private var pageStack: some View {
        ZStack {
            Color(hex: displaySettings.backgroundMode.backgroundColor)

            if isDualPageMode {
                dualPageLayout
            } else {
                singlePageLayout
            }

            tapZoneOverlay
        }
        .gesture(swipeGesture)
        .animation(.easeInOut(duration: 0.25), value: currentPageIndex)
        .overlay(alignment: .bottom) {
            pageIndicator
        }
        .onReceive(pageTurnTrigger.$trigger) { direction in
            guard let direction = direction else { return }
            switch direction {
            case .next:
                goNext()
            case .previous:
                goPrevious()
            }
            pageTurnTrigger.trigger = nil
        }
    }

    // MARK: - Single Page

    @ViewBuilder
    private var singlePageLayout: some View {
        if currentPageIndex < pages.count {
            pageText(at: currentPageIndex)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .id(currentPageIndex)
                .transition(.move(edge: slideEdge).combined(with: .opacity))
        }
    }

    // MARK: - Dual Page

    @ViewBuilder
    private var dualPageLayout: some View {
        HStack(spacing: 0) {
            // Left page
            if currentPageIndex < pages.count {
                pageText(at: currentPageIndex)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }

            // Right page (next page)
            if currentPageIndex + 1 < pages.count {
                pageText(at: currentPageIndex + 1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            } else {
                Color.clear.frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .id(currentPageIndex)
        .transition(.move(edge: slideEdge).combined(with: .opacity))
    }

    // MARK: - Page Text

    @ViewBuilder
    private func pageText(at index: Int) -> some View {
        let pageText = pageString(at: index)
        Text(pageText)
            .font(.custom(displaySettings.fontFamily, size: CGFloat(displaySettings.fontSize)))
            .foregroundColor(Color(hex: displaySettings.backgroundMode.textColor))
            .lineSpacing(CGFloat(displaySettings.lineSpacing))
            .multilineTextAlignment(.leading)
            .padding(EdgeInsets(
                top: displaySettings.verticalPadding,
                leading: displaySettings.horizontalPadding,
                bottom: displaySettings.verticalPadding + displaySettings.paragraphSpacing,
                trailing: displaySettings.horizontalPadding
            ))
    }

    // MARK: - Tap Zones

    @ViewBuilder
    private var tapZoneOverlay: some View {
        if displaySettings.tapZoneEnabled {
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goPrevious() }
                    .frame(maxWidth: .infinity)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onToggleUI() }
                    .frame(width: availableSize.width * 0.34)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goNext() }
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Swipe Gesture

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 30)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > abs(vertical) else { return }
                if horizontal < 0 {
                    goNext()
                } else {
                    goPrevious()
                }
            }
    }

    // MARK: - Page Indicator

    @ViewBuilder
    private var pageIndicator: some View {
        if pages.count > 1 {
            if isDualPageMode && currentPageIndex + 1 < pages.count {
                Text("\(currentPageIndex + 1)-\(currentPageIndex + 2) / \(pages.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            } else {
                Text("\(currentPageIndex + 1) / \(pages.count)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Navigation

    private func goNext() {
        guard currentPageIndex + pageStride < pages.count else {
            // Last spread — go to the very last page if not already there
            if currentPageIndex < pages.count - 1 {
                slideEdge = .trailing
                currentPageIndex = pages.count - 1
                reportProgress()
            }
            return
        }
        slideEdge = .trailing
        currentPageIndex += pageStride
        reportProgress()
    }

    private func goPrevious() {
        guard currentPageIndex > 0 else { return }
        slideEdge = .leading
        currentPageIndex = max(0, currentPageIndex - pageStride)
        reportProgress()
    }

    private func reportProgress() {
        guard !pages.isEmpty else { return }
        let ratio = Double(currentPageIndex) / Double(pages.count)
        onProgressUpdate(ratio)
    }

    // MARK: - Pagination

    private func recomputePages() {
        guard availableSize.width > 0, availableSize.height > 0, !text.isEmpty else {
            pages = []
            return
        }

        let effectiveWidth: Double
        if isDualPageMode {
            // Each page gets half the width
            effectiveWidth = Double(availableSize.width) / 2.0
        } else {
            effectiveWidth = Double(availableSize.width)
        }

        let metrics = PaginationMetrics(
            fontSize: displaySettings.fontSize,
            lineSpacing: displaySettings.lineSpacing,
            paragraphSpacing: displaySettings.paragraphSpacing,
            horizontalPadding: displaySettings.horizontalPadding,
            verticalPadding: displaySettings.verticalPadding,
            availableWidth: effectiveWidth,
            availableHeight: Double(availableSize.height)
        )
        pages = TextPaginationEngine().paginate(text, metrics: metrics)

        // In dual-page mode, align currentPageIndex to even numbers
        if isDualPageMode && currentPageIndex % 2 != 0 {
            currentPageIndex = max(0, currentPageIndex - 1)
        }
        if currentPageIndex >= pages.count {
            currentPageIndex = max(0, pages.count - 1)
        }
        reportProgress()
    }

    private func pageString(at index: Int) -> String {
        guard index >= 0, index < pages.count else { return "" }
        let page = pages[index]
        return String(text[page.start..<page.end])
    }
}
