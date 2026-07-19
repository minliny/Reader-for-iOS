import SwiftUI
import ReaderAppSupport
import ReaderShellValidation

/// Paginated reader view: splits text into pages, displays one at a time
/// with tap zones and slide animation.
///
/// Used by `ReaderView` when `displaySettings.pageTurnMode == .paginated`.
/// Tap zones match the immersive reader contract: 26% previous, 48% chrome,
/// 26% next. Also supports horizontal swipe gestures.
///
/// When `displaySettings.dualPageEnabled` is true and the viewport is
/// landscape (width > height), two pages are shown side by side.
struct PaginatedReaderView: View {
    let title: String?
    let text: String
    let displaySettings: ReaderDisplaySettings
    let contentInsets: ReaderContentInsets
    let onToggleUI: () -> Void
    let onProgressUpdate: (Double) -> Void
    @ObservedObject var pageTurnTrigger: PageTurnTrigger
    let chapterIndex: Int
    let pilotCommittedPageIndex: Int?
    let pilotProposalRequest: ReaderPlaybackPageProposalRequest?
    let onPilotPageIntent: ((ReaderPlaybackPageDirection, ReaderPlaybackPageProposal) -> Bool)?
    let onPilotPageProposal: ((ReaderPlaybackPageProposalRequest, ReaderPlaybackPageProposal) -> Void)?
    let onPilotPageUnavailable: ((ReaderPlaybackPageProposalRequest, String) -> Void)?
    @Environment(\.readerThemePalette) private var palette

    init(
        title: String?,
        text: String,
        displaySettings: ReaderDisplaySettings,
        contentInsets: ReaderContentInsets,
        onToggleUI: @escaping () -> Void,
        onProgressUpdate: @escaping (Double) -> Void,
        pageTurnTrigger: PageTurnTrigger,
        chapterIndex: Int = 0,
        pilotCommittedPageIndex: Int? = nil,
        pilotProposalRequest: ReaderPlaybackPageProposalRequest? = nil,
        onPilotPageIntent: ((ReaderPlaybackPageDirection, ReaderPlaybackPageProposal) -> Bool)? = nil,
        onPilotPageProposal: ((ReaderPlaybackPageProposalRequest, ReaderPlaybackPageProposal) -> Void)? = nil,
        onPilotPageUnavailable: ((ReaderPlaybackPageProposalRequest, String) -> Void)? = nil
    ) {
        self.title = title
        self.text = text
        self.displaySettings = displaySettings
        self.contentInsets = contentInsets
        self.onToggleUI = onToggleUI
        self.onProgressUpdate = onProgressUpdate
        self._pageTurnTrigger = ObservedObject(wrappedValue: pageTurnTrigger)
        self.chapterIndex = chapterIndex
        self.pilotCommittedPageIndex = pilotCommittedPageIndex
        self.pilotProposalRequest = pilotProposalRequest
        self.onPilotPageIntent = onPilotPageIntent
        self.onPilotPageProposal = onPilotPageProposal
        self.onPilotPageUnavailable = onPilotPageUnavailable
    }

    @State private var pages: [PageRange] = []
    @State private var currentPageIndex: Int = 0
    @State private var availableSize: CGSize = .zero
    @State private var slideEdge: Edge = .trailing
    private let motion = MotionEnvironment()

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
        .onChange(of: title) { _ in recomputePages() }
        .onChange(of: contentInsets) { _ in recomputePages() }
        .onChange(of: displaySettings.fontSize) { _ in recomputePages() }
        .onChange(of: displaySettings.lineSpacing) { _ in recomputePages() }
        .onChange(of: displaySettings.lineHeightRatio) { _ in recomputePages() }
        .onChange(of: displaySettings.letterSpacing) { _ in recomputePages() }
        .onChange(of: displaySettings.paragraphIndent) { _ in recomputePages() }
        .onChange(of: displaySettings.horizontalPadding) { _ in recomputePages() }
        .onChange(of: displaySettings.verticalPadding) { _ in recomputePages() }
        .onChange(of: displaySettings.dualPageEnabled) { _ in recomputePages() }
        .onChange(of: pilotCommittedPageIndex) { pageIndex in
            guard let pageIndex, pages.indices.contains(pageIndex) else { return }
            currentPageIndex = pageIndex
            reportProgress()
        }
        .onChange(of: pilotProposalRequest) { request in
            guard let request else { return }
            guard let proposal = pageProposal(for: request.direction) else {
                onPilotPageUnavailable?(request, "PAGE_BOUNDARY_REACHED")
                return
            }
            onPilotPageProposal?(request, proposal)
        }
    }

    @ViewBuilder
    private var pageStack: some View {
        ZStack {
            palette.readingPaper

            Group {
                if isDualPageMode {
                    dualPageLayout
                } else {
                    singlePageLayout
                }
            }
            .padding(contentInsets.edgeInsets)

            tapZoneOverlay
        }
        .gesture(swipeGesture)
        .animation(
            displaySettings.pageAnimation == "none" ? nil : ReaderMotionAdapter.animation(
                for: MotionRequest(operation: .update, sourceRole: "page", containerRole: .readerSurface),
                motion: motion
            ),
            value: currentPageIndex
        )
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
        VStack(alignment: .leading, spacing: paragraphGap) {
            if index == 0, !displayTitle.isEmpty {
                Text(displayTitle)
                    .font(ReaderTypography.readerDisplayFont(family: displaySettings.fontFamily, size: titleFontSize, weight: .bold))
                    .lineSpacing(titleFontSize * (ReaderDesignTokens.immersiveTitleLineHeight - 1))
                    .multilineTextAlignment(.center)
                    .foregroundColor(textColor)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, max(0, ReaderDesignTokens.immersiveTitleBottomMargin - paragraphGap))
            }

            ForEach(Array(pageParagraphs(at: index).enumerated()), id: \.offset) { _, paragraph in
                Text(indentedParagraph(paragraph))
                    .font(ReaderTypography.readerDisplayFont(family: displaySettings.fontFamily, size: bodyFontSize))
                    .lineSpacing(bodyLineSpacing)
                    .kerning(displaySettings.letterSpacing)
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Paginated reading typography layer")
    }

    // MARK: - Tap Zones

    @ViewBuilder
    private var tapZoneOverlay: some View {
        if displaySettings.tapZoneEnabled {
            HStack(spacing: 0) {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goPrevious() }
                    .frame(width: availableSize.width * ReaderDesignTokens.hotzonePrevRatio)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { onToggleUI() }
                    .frame(width: availableSize.width * ReaderDesignTokens.hotzoneCenterRatio)

                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { goNext() }
                    .frame(width: availableSize.width * ReaderDesignTokens.hotzoneNextRatio)
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
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .padding(.bottom, 4)
            } else {
                Text("\(currentPageIndex + 1) / \(pages.count)")
                    .font(.system(size: ReaderDesignTokens.readerControlLabelFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .padding(.bottom, 4)
            }
        }
    }

    // MARK: - Navigation

    private func goNext() {
        guard let proposal = pageProposal(for: .next) else { return }
        if onPilotPageIntent?(.next, proposal) == true { return }
        slideEdge = .trailing
        currentPageIndex = proposal.targetPageIndex
        reportProgress()
    }

    private func goPrevious() {
        guard let proposal = pageProposal(for: .previous) else { return }
        if onPilotPageIntent?(.previous, proposal) == true { return }
        slideEdge = .leading
        currentPageIndex = proposal.targetPageIndex
        reportProgress()
    }

    /// Converts the actual PageRange start into a chapter-local scalar offset.
    /// This is the only page anchor offered to ReaderUIRuntime/Core; the
    /// visible index remains unchanged until the matching location result.
    private func pageProposal(for direction: ReaderPlaybackPageDirection) -> ReaderPlaybackPageProposal? {
        Self.pilotPageProposal(
            text: text,
            pages: pages,
            currentPageIndex: currentPageIndex,
            pageStride: pageStride,
            direction: direction,
            chapterIndex: chapterIndex,
            viewport: availableSize,
            fontScale: Double(displaySettings.fontSize) / 18.0,
            lineHeight: Double(bodyFontSize * ReaderDesignTokens.immersiveBodyLineHeight)
        )
    }

    static func pilotPageProposal(
        text: String,
        pages: [PageRange],
        currentPageIndex: Int,
        pageStride: Int,
        direction: ReaderPlaybackPageDirection,
        chapterIndex: Int,
        viewport: CGSize,
        fontScale: Double,
        lineHeight: Double
    ) -> ReaderPlaybackPageProposal? {
        guard !pages.isEmpty, viewport.width > 0, viewport.height > 0 else { return nil }
        let target: Int
        switch direction {
        case .next:
            guard currentPageIndex < pages.count - 1 else { return nil }
            target = min(pages.count - 1, currentPageIndex + pageStride)
        case .previous:
            guard currentPageIndex > 0 else { return nil }
            target = max(0, currentPageIndex - pageStride)
        }
        let range = pages[target]
        let offset = text[..<range.start].unicodeScalars.count
        let scalarCount = max(1, text.unicodeScalars.count)
        return ReaderPlaybackPageProposal(
            direction: direction,
            targetPageIndex: target,
            pageCount: pages.count,
            chapterIndex: chapterIndex,
            chapterOffset: offset,
            chapterProgress: min(1, max(0, Double(offset) / Double(scalarCount))),
            viewportWidth: Int(viewport.width.rounded(.down)),
            viewportHeight: Int(viewport.height.rounded(.down)),
            fontScale: fontScale,
            lineHeight: lineHeight
        )
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
            // The responsive reading inset wraps the whole spread before
            // columns split, so each page gets half of the remaining width.
            let contentWidth = max(1, availableSize.width - contentInsets.leading - contentInsets.trailing)
            effectiveWidth = Double(contentWidth) / 2.0
        } else {
            effectiveWidth = Double(availableSize.width)
        }

        let metrics = PaginationMetrics(
            fontSize: displaySettings.fontSize,
            lineSpacing: Double(bodyLineSpacing),
            paragraphSpacing: displaySettings.paragraphSpacing,
            horizontalPadding: paginationHorizontalPadding,
            verticalPadding: paginationVerticalPadding,
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
        if let pilotCommittedPageIndex, pages.indices.contains(pilotCommittedPageIndex) {
            currentPageIndex = pilotCommittedPageIndex
        }
        reportProgress()
    }

    private func pageString(at index: Int) -> String {
        guard index >= 0, index < pages.count else { return "" }
        let page = pages[index]
        return String(text[page.start..<page.end])
    }

    private var displayTitle: String {
        (title ?? "")
            .replacingOccurrences(of: #"^第\s*\d+\s*章\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var bodyFontSize: CGFloat {
        CGFloat(displaySettings.fontSize)
    }

    private var titleFontSize: CGFloat {
        bodyFontSize + ReaderDesignTokens.immersiveTitleFontSizeOffset
    }

    private var bodyLineSpacing: CGFloat {
        bodyFontSize * (displaySettings.lineHeightRatio - 1)
    }

    private var paragraphGap: CGFloat {
        CGFloat(displaySettings.paragraphSpacing)
    }

    private var textColor: SwiftUI.Color {
        palette.readingInk
    }

    private var paginationHorizontalPadding: Double {
        guard !isDualPageMode else { return 0 }
        return Double((contentInsets.leading + contentInsets.trailing) / 2)
    }

    private var paginationVerticalPadding: Double {
        Double((contentInsets.top + contentInsets.bottom) / 2)
    }

    private func pageParagraphs(at index: Int) -> [String] {
        let lines = pageString(at: index)
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return lines.isEmpty ? [pageString(at: index)] : lines
    }

    private func indentedParagraph(_ paragraph: String) -> String {
        let indentCount = max(0, Int(displaySettings.paragraphIndent.rounded()))
        return String(repeating: "\u{3000}", count: indentCount) + paragraph
    }
}
