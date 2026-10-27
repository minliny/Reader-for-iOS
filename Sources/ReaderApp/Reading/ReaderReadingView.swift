import SwiftUI
import UIKit
#if DEBUG
import OSLog
#endif

private enum ReaderReadingSheet: String, Identifiable { case info, sourceSwitch, downloads; var id: String { rawValue } }

private enum ReaderControlModule { case home, directory, appearance, search, notes, rules, settings, records, autoPage }

struct ReaderReadingView: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    let session: ReaderActiveSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = ReaderControlMotionDriver()
    @StateObject private var brightness = ReaderBrightnessOwner()
    @StateObject private var textTools = ReaderTextToolsState()
    @StateObject private var bookmarks = ReaderBookmarkState()
    @StateObject private var rules: ReaderRuleWorkspace
    @StateObject private var fontLibrary = ReaderFontLibrary()
    @StateObject private var imageOwner = ReaderChapterImageOwner()
    @StateObject private var display = ReaderDisplaySessionOwner()
    @StateObject private var automaticPage = ReaderAutoPageOwner()
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @State private var module: ReaderControlModule = .home
    @State private var moreVisible = false
    @State private var pendingSheet: ReaderReadingSheet?
    @State private var sheet: ReaderReadingSheet?
    @State private var fontFallbackReported: String?
    @State private var localKind: ReaderLocalPresentationKind?
    @State private var ebookDocument: ReaderEbookDocument?
    @State private var ebookArchive: ReaderEbookArchiveReader?
    @State private var surfaceFailure: String?
    @State private var surfaceLoading = false
    @State private var surfaceReady = false
    @State private var surfaceGeneration = UUID()
    @State private var scrubFraction: Double?
    @State private var recoveryBusy = false
    @State private var pointerHeld = false
    @State private var directoryQuery = ""
    @State private var directoryDescending = false
    @State private var directoryBookmarks = false
    @State private var directorySnapshot: ReaderDirectorySnapshot?
    @State private var directoryFailure: String?
    @State private var directoryCollapsed = Set<String>()
    @State private var directoryLoading = false
    @State private var directoryGeneration = UUID()
    @State private var directoryAnchor: String?
    @State private var directoryLocatePending = false
    @State private var directoryLoadedGeneration = UUID()
    @State private var moduleParents: [ReaderControlModule] = []
    @State private var readingHeaderHeight: CGFloat = 54
    #if DEBUG
    @StateObject private var dockHitDiagnostics = ReaderDockHitDiagnostics()
    #endif
    @ScaledMetric(relativeTo: .body) private var footerHeight: CGFloat = 24

    init(model: ReaderApplicationModel, preferences: ReaderPreferences, session: ReaderActiveSession) {
        self.model = model; self.preferences = preferences; self.session = session
        _rules = StateObject(wrappedValue: ReaderRuleWorkspace(identity: session.book.id))
    }

    private var paper: ReaderPaperPalette { ReaderPaperPalette(theme: preferences.theme) }
    private var palette: ReaderPalette { ReaderPalette(preferences.appDark ? .dark : .light) }
    private var controlsVisible: Bool { motion.isPresented }
    private var fullProgress: CGFloat { motion.expansion }
    private var effectiveReduceMotion: Bool { reduceMotion || preferences.reduceMotion }
    private var surfaceIdentity: String {
        "\(session.book.id)|\(session.content.chapterIndex)|\(session.content.bodyVersion ?? "")|\(session.content.processingVersion ?? "")"
    }
    private var originalFormat: Bool { localKind?.kind == .ebook }
    private var automaticPageAvailable: Bool {
        guard model.selection == nil else { return false }
        return session.book.sourceId != "local" || localKind != nil && localKind?.reimportRequired == false
            || !(model.libraryService is any ReaderLibraryFeatures)
    }
    private var fraction: Double {
        session.content.scalarCount == 0 ? 0 : Double(session.scalarOffset) / Double(session.content.scalarCount)
    }

    var body: some View {
        GeometryReader { geometry in
            let controlLayout = controlViewport(size: geometry.size, safe: geometry.safeAreaInsets)
            // Reserve the footer in the viewport as well as at the end of the
            // chapter. An end-of-content inset alone lets intermediate lines
            // paint behind the footer. Keep the viewport stable while controls move.
            let footerSpace = footerHeight + 1 + max(0, 23 - geometry.safeAreaInsets.bottom)
            ZStack(alignment: .bottom) {
                ReaderPaperBackground(theme: preferences.theme).ignoresSafeArea()
                ReaderBrightnessAttachment(owner: brightness).frame(width: 0, height: 0)
                ReaderDisplayAttachment(owner: display).frame(width: 0, height: 0)
                let windowWidth = geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing
                let margin = ReaderMetrics.readingHorizontalInset(width: windowWidth,
                    safeHorizontal: max(geometry.safeAreaInsets.leading, geometry.safeAreaInsets.trailing))
                    readerSurface(geometry: geometry, margin: margin, footerSpace: footerSpace)
                        .clipped()
                        .padding(.bottom, footerSpace)
                        .accessibilityHidden(controlsVisible)
                    if !controlsVisible {
                        VStack {
                            Spacer()
                        HStack {
                            Text(session.book.title).lineLimit(1)
                            Spacer(minLength: 12)
                            Text("\(Int(fraction * 100))%").accessibilityIdentifier("reading-progress")
                        }.font(.custom(ReaderFonts.postScriptName(.ui), size: 12, relativeTo: .body))
                            .foregroundStyle(paper.meta).frame(height: footerHeight)
                            .padding(.leading, max(0, 25 - geometry.safeAreaInsets.leading))
                            .padding(.trailing, max(0, 25 - geometry.safeAreaInsets.trailing))
                            .padding(.bottom, max(0, 23 - geometry.safeAreaInsets.bottom))
                        }.allowsHitTesting(false)
                    }
                if controlsVisible {
                    Color.black.opacity(0.07 * motion.visibility).ignoresSafeArea().contentShape(Rectangle())
                        .onTapGesture { dismissControls() }
                    controlDock(layout: controlLayout)
                        .environment(\.colorScheme, preferences.appDark ? .dark : .light)
                        .offset(x: controlLayout.dockOffsetX)
                        .padding(.bottom, controlLayout.dockBottomPadding)
                }
                if let message = model.recoveryMessage {
                    VStack {
                        ReaderRecoveryNotice(message: message, busy: recoveryBusy) {
                            recoveryBusy = true
                            Task { _ = await model.flushReading(); recoveryBusy = false }
                        }.environment(\.colorScheme, preferences.appDark ? .dark : .light)
                            .padding(.horizontal, 16).padding(.top, 8)
                        Spacer()
                    }
                }
                if controlsVisible, model.recoveryMessage == nil {
                    VStack {
                        readingHeader.frame(width: controlLayout.topBarWidth)
                            .offset(x: controlLayout.topBarOffsetX,
                                    y: -8 * (1 - motion.visibility))
                            .opacity(motion.visibility)
                            .allowsHitTesting(motion.visibility > 0)
                            .padding(.top, controlLayout.topBarPadding)
                        Spacer()
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                if model.chapterLoading || model.closingReader {
                    ProgressView().tint(palette.green).padding(18).background(palette.card, in: Capsule())
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }.onAppear {
                configureMotion(size: geometry.size, safe: geometry.safeAreaInsets); brightness.enterReader(); reportFontFallback()
                display.onError = { model.showFeedback($0) }
                display.update(screenTimeout: preferences.screenTimeout, orientation: preferences.orientation); display.enterReader()
            }
                .onChange(of: geometry.size) { _, size in configureMotion(size: size, safe: geometry.safeAreaInsets) }
                .onChange(of: geometry.safeAreaInsets) { _, safe in configureMotion(size: geometry.size, safe: safe) }
                .onChange(of: module) { _, _ in configureMotion(size: geometry.size, safe: geometry.safeAreaInsets) }
                .onPreferenceChange(ReaderReadingHeaderHeightKey.self) { height in
                    // A hidden/unmounted header contributes the empty preference.
                    // Retain its last real measurement for the next presentation.
                    guard height.isFinite, height > 0, height != readingHeaderHeight else { return }
                    readingHeaderHeight = max(54, height)
                    configureMotion(size: geometry.size, safe: geometry.safeAreaInsets)
                }
        }
        .preferredColorScheme(preferences.theme.isDark ? .dark : .light)
        .statusBarHidden(preferences.hideStatusBar && !controlsVisible)
        .persistentSystemOverlays(preferences.hideNavigationBar ? .hidden : .automatic)
        .task(id: surfaceIdentity) { await loadSurface() }
        .task(id: surfaceIdentity) {
            if session.book.sourceId != "local" {
                await imageOwner.load(book: session.book, content: session.content,
                    service: model.libraryService as? ReaderLibraryService)
            } else { imageOwner.cancel() }
        }
        .onChange(of: imageOwner.assets.revision) { _, _ in
            if !imageOwner.assets.settled(for: session.content) { surfaceReady = false }
        }
        .onChange(of: surfaceIdentity) { _, _ in surfaceReady = false }
        .readerConfirmation(confirmation)
        .onChange(of: model.foreground) { _, active in
            if !active { automaticPage.pause(); moreVisible = false; pendingSheet = nil; pointerHeld = false; motion.cancelDrag(reduceMotion: effectiveReduceMotion); scrubFraction = nil }
        }
        .onChange(of: preferences.screenTimeout) { _, value in display.update(screenTimeout: value, orientation: preferences.orientation) }
        .onChange(of: preferences.orientation) { _, value in display.update(screenTimeout: preferences.screenTimeout, orientation: value) }
        .onChange(of: preferences.longPressSelectText) { _, enabled in
            if !enabled { model.updateSelection(start: 0, end: 0, text: "", sessionID: session.id, restorationID: session.restorationID) }
        }
        .onDisappear { textTools.cancelSearch(); imageOwner.cancel(); model.setReadingBodyVisible(false, sessionID: session.id); automaticPage.stop(); pendingSheet = nil; moreVisible = false; pointerHeld = false; motion.stop(publishingFinalSample: false); brightness.leaveReader(); display.leaveReader() }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { motion.move(to: motion.target, reduceMotion: true) }
        }
        .onChange(of: preferences.reduceMotion) { _, enabled in
            if enabled { motion.move(to: motion.target, reduceMotion: true) }
        }
        .onChange(of: preferences.autoPageSeconds) { _, value in automaticPage.setSpeed(value) }
        .onChange(of: model.selection) { _, value in if value != nil { automaticPage.pause() } }
        .onChange(of: model.sourceSwitchFrozen) { _, frozen in if frozen { automaticPage.pause() }; updateReadingTimeVisibility() }
        .onChange(of: controlsVisible) { _, _ in updateReadingTimeVisibility() }
        .onChange(of: model.foreground) { _, _ in updateReadingTimeVisibility() }
        .onChange(of: model.chapterLoading) { _, _ in updateReadingTimeVisibility() }
        .onChange(of: model.closingReader) { _, _ in updateReadingTimeVisibility() }
        .onChange(of: surfaceReady) { _, _ in updateReadingTimeVisibility() }
        .onChange(of: surfaceLoading) { _, _ in updateReadingTimeVisibility() }
        .onChange(of: surfaceFailure) { _, _ in updateReadingTimeVisibility() }
        .onChange(of: sheet) { _, _ in updateReadingTimeVisibility() }
        .onChange(of: model.importResultVisible) { _, presented in
            if presented { automaticPage.pause() }
            updateReadingTimeVisibility()
        }
        .sheet(item: $sheet) { route in
            Group {
                switch route {
                case .info: ReaderReadingBookInfo(model: model, book: session.book)
                case .sourceSwitch: ReaderOnlineSwitchPanel(model: model, preferences: preferences, session: session)
                case .downloads: ReaderOnlineDownloadPanel(model: model, session: session)
                }
            }.preferredColorScheme(preferences.appDark ? .dark : .light)
        }
        .onChange(of: preferences.fontPostScriptName) { _, _ in reportFontFallback() }
        .onChange(of: pointerHeld) { _, held in
            if !held { motion.cancelDrag(reduceMotion: effectiveReduceMotion) }
        }
    }

    /// Shared scalar/selection boundary; original-format electronic books join
    /// here without replacing the reader's navigation or position owner.
    @ViewBuilder
    private func readerSurface(geometry: GeometryProxy, margin: CGFloat, footerSpace: CGFloat) -> some View {
        let width = geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing
        let horizontal = preferences.horizontalMargin == 0 ? margin : max(preferences.horizontalMargin,
            max(geometry.safeAreaInsets.leading, geometry.safeAreaInsets.trailing))
        Group {
        if let failure = surfaceFailure {
            ReaderPageState(title: "正文暂不可展示", detail: failure, actionTitle: "重试") { Task { await loadSurface() } }
        } else if let kind = localKind, kind.reimportRequired {
            ReaderPageState(title: "需要重新处理原书", detail: "保留书架与阅读数据，由 Core 重新建立原格式定位。", actionTitle: "重新处理") { confirmReprocess() }
        } else if originalFormat {
            if let document = ebookDocument, let archive = ebookArchive {
                ReaderEbookSurface(document: document, content: session.content, archiveReader: archive,
                    scalarOffset: session.scalarOffset, restorationID: session.restorationID,
                    fontSize: preferences.fontSize, lineHeight: preferences.lineHeight, horizontalInset: horizontal,
                    safeLeft: geometry.safeAreaInsets.leading, safeRight: geometry.safeAreaInsets.trailing,
                    bottomInset: max(0, ReaderMetrics.readingBottomInset(width: width) - geometry.safeAreaInsets.bottom - footerSpace), paper: paper,
                    positionChanged: { model.recordVisibleOffset($0, sessionID: session.id, restorationID: session.restorationID) },
                    selectionChanged: { start, end, text in
                        model.updateSelection(start: start, end: end, text: text, sessionID: session.id, restorationID: session.restorationID)
                    }, centerTapped: { if controlsVisible { dismissControls() } else { invokeControls() } },
                    failed: { error in
                        guard model.reader?.id == session.id,
                              model.reader?.content.chapterIndex == session.content.chapterIndex,
                              model.reader?.content.bodyVersion == session.content.bodyVersion,
                              model.reader?.content.processingVersion == session.content.processingVersion else { return }
                        automaticPage.pause(); surfaceFailure = error.localizedDescription
                    }, bookmarkSelectionAction: { Task { _ = await model.addBookmark() } },
                    noteSelectionAction: { select(.notes); motion.move(to: .full, reduceMotion: effectiveReduceMotion) },
                    fontName: fontLibrary.resolvedFont(named: preferences.fontPostScriptName, size: preferences.fontSize)?.fontName,
                    paragraphSpacing: preferences.paragraphSpacing, letterSpacing: preferences.letterSpacing,
                    firstLineIndentEm: preferences.firstLineIndentEm,
                    alignment: preferences.textAlignment == .justified ? .justified : .left,
                    paged: preferences.pageMode == .paged, highlights: model.highlights,
                    pageTurnID: automaticPage.turnID, automaticPageEnabled: automaticPage.nativePagingEnabled,
                    pageCommitted: handleAutomaticPage,
                    layoutReady: nativeLayoutReady,
                    manualInteraction: { display.interaction(); automaticPage.pause() }, reducePageMotion: effectiveReduceMotion,
                    automaticHighlightProgress: preferences.autoPageFollowHighlight && automaticPage.nativePagingEnabled ? automaticPage.progress : nil,
                    transition: preferences.pageTransition,
                    pageBoundary: { direction in
                        automaticPage.pause()
                        Task { await model.moveChapter(direction, landingAtEnd: direction < 0) }
                    }, longPressSelectText: preferences.longPressSelectText,
                    readerFont: fontLibrary.resolvedFont(named: preferences.fontPostScriptName, size: preferences.fontSize))
            } else { ReaderPageState(title: "正在读取原格式正文", loading: true) }
        } else if session.book.sourceId == "local", model.libraryService is any ReaderLibraryFeatures, localKind == nil {
            ReaderPageState(title: "正在核对正文格式", loading: true)
        } else {
        ReaderTextBodySurface(surface: ReaderTextSurface(content: session.content, scalarOffset: session.scalarOffset,
            restorationID: session.restorationID, fontSize: preferences.fontSize,
            lineHeight: preferences.lineHeight, horizontalInset: horizontal,
            safeLeft: geometry.safeAreaInsets.leading, safeRight: geometry.safeAreaInsets.trailing,
            bottomInset: max(0, ReaderMetrics.readingBottomInset(width: width) - geometry.safeAreaInsets.bottom - footerSpace), paper: paper,
            positionChanged: { model.recordVisibleOffset($0, sessionID: session.id, restorationID: session.restorationID) },
            centerTapped: { if controlsVisible { dismissControls() } else { invokeControls() } },
            selectionChanged: { start, end, text in
                model.updateSelection(start: start, end: end, text: text, sessionID: session.id, restorationID: session.restorationID)
            }, bookmarkSelectionAction: {
                Task {
                    guard model.reader?.id == session.id, model.reader?.restorationID == session.restorationID else { return }
                    _ = await model.addBookmark()
                }
            }, noteSelectionAction: {
                guard model.reader?.id == session.id, model.reader?.restorationID == session.restorationID else { return }
                select(.notes); motion.move(to: .full, reduceMotion: effectiveReduceMotion)
            }, fontName: fontLibrary.resolvedFont(named: preferences.fontPostScriptName, size: preferences.fontSize)?.fontName, paragraphSpacing: preferences.paragraphSpacing,
            letterSpacing: preferences.letterSpacing, firstLineIndentEm: preferences.firstLineIndentEm,
            alignment: preferences.textAlignment == .justified ? .justified : .left,
            paged: preferences.pageMode == .paged, highlights: model.highlights,
            pageTurnID: automaticPage.turnID, automaticPageEnabled: automaticPage.nativePagingEnabled,
            pageCommitted: handleAutomaticPage,
            layoutReady: nativeLayoutReady,
            manualInteraction: { display.interaction(); automaticPage.pause() }, reducePageMotion: effectiveReduceMotion,
            automaticHighlightProgress: preferences.autoPageFollowHighlight && automaticPage.nativePagingEnabled ? automaticPage.progress : nil,
            longPressSelectText: preferences.longPressSelectText,
            readerFont: fontLibrary.resolvedFont(named: preferences.fontPostScriptName, size: preferences.fontSize),
            imageAssets: imageOwner.assets),
            mode: preferences.pageMode, transition: preferences.pageTransition,
            pageBoundary: { direction in
                automaticPage.pause()
                Task { await model.moveChapter(direction, landingAtEnd: direction < 0) }
            }, alignPageBottom: preferences.alignPageBottom)
        }
        }.overlay(alignment: .topLeading) {
            if surfaceFailure != nil || localKind?.reimportRequired == true || surfaceLoading || !surfaceReady {
                Button("阅读控制") { invokeControls() }.font(ReaderTypography.font(.action))
                    .padding(12).background(palette.card, in: Capsule()).padding(12)
            }
        }
    }

    private var readingHeader: some View {
        HStack(spacing: 8) {
            ReaderIconAction(icon: .back, label: "返回书架") { automaticPage.stop(); Task { await model.closeReader() } }
                .disabled(model.sourceSwitchFrozen).accessibilityIdentifier("leave-reader")
            VStack(alignment: .leading, spacing: 5) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(session.book.title)
                        .font(.custom(ReaderFonts.postScriptName(.serifBold), size: 16, relativeTo: .body))
                        .foregroundStyle(palette.readInk).lineLimit(1)
                        .accessibilityIdentifier("reading-book:" + session.book.id)
                }.accessibilityElement(children: .contain)
                    .accessibilityIdentifier("reading-header-book-title")
                VStack(alignment: .leading, spacing: 0) {
                    Text("\(session.content.chapterTitle) · \(session.book.sourceName ?? (session.book.sourceId == "local" ? "本地" : "在线"))")
                        .font(.custom(ReaderFonts.postScriptName(.serif), size: 12, relativeTo: .body))
                        .foregroundStyle(palette.app("TOK_READ_MUTED")).lineLimit(1)
                        .accessibilityIdentifier("reading-chapter:\(session.content.chapterIndex)")
                }.accessibilityElement(children: .contain)
                    .accessibilityIdentifier("reading-header-chapter-title")
            }.fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 45)
            ReaderIconAction(icon: .more, label: "更多阅读操作") { automaticPage.pause(); moreVisible = true }
                .popover(isPresented: $moreVisible, attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                    moreMenu.onDisappear(perform: dispatchMoreAction).presentationCompactAdaptation(.popover)
                }.accessibilityIdentifier("reader-more")
            ReaderIconAction(icon: .chevronDown, label: "收起阅读控制") { dismissControls() }
        }.padding(.horizontal, 13).padding(.vertical, 4.5).frame(minHeight: 54)
            .background(palette.app("TOK_READ_SURFACE"), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(palette.app("TOK_LINE_STRONG"), lineWidth: 1))
            .background {
                GeometryReader { geometry in
                    Color.clear.preference(key: ReaderReadingHeaderHeightKey.self, value: geometry.size.height)
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("reading-header-surface")
            .environment(\.colorScheme, preferences.appDark ? .dark : .light)
    }

    private func controlDock(layout: ReaderControlViewportLayout) -> some View {
        let width = layout.dockWidth
        let height = motion.dockHeight
        let p = fullProgress
        let inset = min(13, width / 4)
        let fullWidth = max(0, width - inset * 2)
        let quickWidth = max(0, fullWidth - 52)
        let quickContentHeight = min(190, max(0, motion.quickHeight - 140))
        let contentWidth = quickWidth + (fullWidth - quickWidth) * p
        let contentHeight = quickContentHeight + (max(0, motion.fullHeight - 70) - quickContentHeight) * p
        let endpointInput = !pointerHeld && !motion.isDragging && (p == 0 || p == 1) && motion.visibility > 0
        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24).fill(palette.app("TOK_READ_SURFACE"))
                .frame(width: width, height: height)
            RoundedRectangle(cornerRadius: 24).stroke(palette.app("TOK_LINE_STRONG"), lineWidth: 1)
                .frame(width: width, height: height).allowsHitTesting(false)
            if module != .home {
                RoundedRectangle(cornerRadius: 12).fill(palette.panel)
                    .frame(width: fullWidth, height: max(0, motion.fullHeight - 70))
                    .offset(x: inset, y: 57).opacity(p).allowsHitTesting(false)
                RoundedRectangle(cornerRadius: 8).fill(palette.panel)
                    .frame(width: contentWidth, height: contentHeight)
                    .offset(x: inset, y: 29 + 28 * p).opacity(1 - p).allowsHitTesting(false)
            }
            Group {
                if module == .home {
                    if quickContentHeight < 190 {
                        ScrollView { quickContent }.scrollIndicators(.hidden)
                    } else { quickContent }
                } else if module == .directory { directoryContent }
                else if module == .appearance {
                    ScrollView {
                        ReaderReadingPreferencesPanel(preferences: preferences, fontLibrary: fontLibrary,
                            supportsBottomAlignment: !originalFormat && preferences.pageMode == .paged).padding(12)
                    }.scrollIndicators(.hidden)
                }
                else if module == .search { ReaderContentSearchPanel(model: model, state: textTools, book: session.book) }
                else if module == .notes { ReaderAnnotationsPanel(model: model, state: textTools, book: session.book, presentationActive: controlsVisible) }
                else if module == .rules { ReaderRuleToolsPanel(model: model, state: rules, book: session.book, presentationActive: controlsVisible) }
                else if module == .records { ReaderReadingRecordPanel(model: model) }
                else if module == .autoPage {
                    ReaderAutoPagePanel(owner: automaticPage, preferences: preferences, progress: p, available: automaticPageAvailable,
                        previousEnabled: session.chapters.first?.index != session.content.chapterIndex && !model.chapterLoading,
                        nextEnabled: session.chapters.last?.index != session.content.chapterIndex && !model.chapterLoading,
                        previous: { automaticPage.pause(); Task { await model.moveChapter(-1) } },
                        next: { automaticPage.pause(); Task { await model.moveChapter(1) } },
                        start: startAutomaticPage)
                }
                else { readingSettings }
            }.frame(width: contentWidth, height: max(0, contentHeight), alignment: .topLeading)
                .clipped().offset(x: inset, y: 29 + 28 * p)
                .allowsHitTesting(endpointInput)
                .accessibilityHidden(!endpointInput)
            if module != .home {
                HStack {
                    if !moduleParents.isEmpty {
                        ReaderIconAction(icon: .back, label: "返回上一级阅读工具") { backModule() }
                    }
                    Text(moduleTitle).font(ReaderTypography.font(.controlHeader))
                    Spacer()
                    Button { if p > 0.5 { collapse() } else { expand() } } label: {
                        HStack(spacing: 4) {
                            Text(p > 0.5 ? "收起" : "展开").font(ReaderTypography.font(.controlCollapse))
                            ReaderIcon(.chevronDown, size: 16).rotationEffect(.degrees(p > 0.5 ? 0 : 180))
                        }.frame(minWidth: 64, minHeight: 30)
                    }.buttonStyle(ReaderPressFeedback()).accessibilityIdentifier("expand-controls")
                }.frame(width: fullWidth, height: 30).offset(x: inset, y: 19)
                    .opacity(p).allowsHitTesting(endpointInput && p > 0)
            }
            ReaderBrightnessRail(owner: brightness)
                .offset(x: width - 13.56 - 38 + (38 + 13.56) * p, y: 29)
                .opacity(1 - p).allowsHitTesting(endpointInput && p < 1)
                .accessibilityHidden(!endpointInput || p >= 1)
            HStack(spacing: 4) {
                moduleButton(.home, icon: .bookshelf, label: "阅读")
                moduleButton(.directory, icon: .directory, label: "目录")
                moduleButton(.appearance, icon: .appearance, label: "外观")
                moduleButton(.settings, icon: .settings, label: "设置")
            }.padding(.leading, 9).padding(.top, 9)
                .frame(width: max(0, width - 24), height: 80)
                .background(palette.app("TOK_SURFACE_SOLID_OPAQUE"), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.app("TOK_LINE_STRONG"), lineWidth: 1))
                .offset(x: 12, y: height - 93 + 20 * p)
                .opacity(1 - p).allowsHitTesting(endpointInput && p < 1)
                .accessibilityHidden(!endpointInput || p >= 1)
            Capsule().fill(palette.app("TOK_READ_HANDLE")).frame(width: 42, height: 4)
                .offset(x: (width - 42) / 2, y: 9).allowsHitTesting(false)
            ReaderControlTouchCap(
                label: module == .home ? "控制栏拖动区域，向下关闭" : p == 1 ? "完整控制栏，轻点收起" : "快捷控制栏，轻点展开",
                began: { time in display.interaction(); pointerHeld = true; motion.dragChanged(translationY: 0, time: time) },
                changed: { translation, time in motion.dragChanged(translationY: translation, time: time) },
                ended: { translation, time in
                    motion.dragEnded(translationY: translation, time: time, reduceMotion: effectiveReduceMotion)
                    pointerHeld = false
                },
                cancelled: { pointerHeld = false; motion.cancelDrag(reduceMotion: effectiveReduceMotion) },
                activated: {
                    if module == .home { dismissControls() }
                    else if fullProgress == 1 { collapse() } else { expand() }
                })
                .frame(width: width, height: min(19, height))
                .accessibilityIdentifier("control-grabber")
        }.frame(width: width, height: height, alignment: .topLeading).clipped()
            .opacity(layout.fullHeight > 0 ? motion.visibility : 0).offset(y: motion.offsetY)
            .allowsHitTesting(layout.fullHeight > 0).accessibilityHidden(layout.fullHeight <= 0)
            .foregroundStyle(palette.ink)
            .shadow(color: .black.opacity(preferences.appDark ? 0.2 : 0.08), radius: 20, y: 8)
            .accessibilityElement(children: .contain)
            #if DEBUG
            .environment(\.readerDockHitDiagnostics, dockHitDiagnostics)
            .background {
                ReaderDockHitDiagnosticsAttachment(owner: dockHitDiagnostics,
                    input: .init(module: String(describing: module), progress: p, endpointInput: endpointInput))
                    .frame(width: 0, height: 0)
            }
            .onChange(of: dockInputTraceKey(progress: p, endpointInput: endpointInput), initial: true) { _, _ in
                traceDockInput(progress: p, endpointInput: endpointInput)
            }
            #endif
    }

    private var moduleTitle: String {
        switch module { case .home: return "阅读"; case .directory: return "目录"; case .appearance: return "外观"
        case .search: return "正文搜索"; case .notes: return "高亮与笔记"; case .rules: return "规则"
        case .settings: return "阅读设置"; case .records: return "阅读记录"; case .autoPage: return "自动翻页" }
    }

    private var quickContent: some View {
        VStack(spacing: 6) {
            // Host@33f7c7b ReaderControlPanel.ets:1652–1788.
            VStack(spacing: 0) {
                HStack(spacing: 8) {
                    chapterStep(-1, icon: .chevronLeft, label: "上一章")
                    Text(session.content.chapterTitle)
                        .font(ReaderTextStyle(.inter, 13, 700, lineHeight: 16.25).font)
                        .foregroundStyle(palette.readInk).lineLimit(1)
                        .frame(maxWidth: .infinity).frame(height: 34)
                    chapterStep(1, icon: .chevronRight, label: "下一章")
                }.frame(height: 34).padding(.horizontal, 11).padding(.top, 10)
                    .frame(height: 52.563)
                HStack(spacing: 0) {
                    Text("\(Int(((scrubFraction ?? fraction) * 100).rounded()))%")
                        .frame(width: 26.23, alignment: .leading)
                    ReaderChapterProgressSlider(value: scrubFraction ?? fraction,
                        changed: { scrubFraction = $0 },
                        committed: { model.seek(to: $0); scrubFraction = nil },
                        cancelled: { scrubFraction = nil })
                        .frame(maxWidth: .infinity).frame(height: 30)
                        .accessibilityLabel("章节阅读进度").accessibilityIdentifier("chapter-progress")
                    Text("共 \(session.chapters.count) 章")
                        .minimumScaleFactor(0.8).allowsTightening(true)
                        .frame(width: 39, height: 30, alignment: .trailing).padding(.leading, 5.5)
                }
                .font(ReaderTextStyle(.inter, 9, 400, lineHeight: 9).font)
                .foregroundStyle(palette.app("TOK_READ_MUTED")).lineLimit(1)
                .frame(height: 30).padding(.horizontal, 11).padding(.top, 6).frame(height: 30)
            }.frame(height: 108.563, alignment: .top)
                .background(palette.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.app("TOK_LINE_STRONG"), lineWidth: 1))
            HStack(spacing: 8) {
                quickAction("搜索", icon: .search) { select(.search) }
                quickAction("自动翻页", icon: .autoPage) { select(.autoPage) }
                quickAction("替换", icon: .replace) { select(.rules) }
            }.padding(.leading, 9).frame(height: 75.438)
                .background(palette.panel, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.app("TOK_LINE_STRONG"), lineWidth: 1))
        }
    }

    private func chapterStep(_ delta: Int, icon: ReaderIconName, label: String) -> some View {
        let enabled = !model.chapterLoading && (delta < 0
            ? session.chapters.first?.index != session.content.chapterIndex
            : session.chapters.last?.index != session.content.chapterIndex)
        return Button { Task { await model.moveChapter(delta) } } label: {
            ReaderIcon(icon, size: 20).frame(width: 34, height: 34)
                .background(enabled ? palette.readElevated : palette.app("TOK_READ_DISABLED_BG"), in: Circle())
                .opacity(enabled ? 1 : 0.4)
        }.buttonStyle(ReaderPressFeedback()).disabled(!enabled).accessibilityLabel(label)
    }

    private func quickAction(_ title: String, icon: ReaderIconName, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            // Host@33f7c7b ReaderControlPanel.ets:1615–1637.
            VStack(spacing: 0) {
                ReaderIcon(icon, size: 24).padding(.top, 4.72)
                Text(title).font(ReaderTextStyle(.inter, 11, 800, lineHeight: 13).font)
                    .foregroundStyle(palette.readInk).lineLimit(1)
                    .frame(maxWidth: .infinity).frame(height: 13).padding(.top, 5.78)
            }.frame(maxWidth: .infinity).frame(height: 55.438, alignment: .top)
                .background(palette.readElevated, in: RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(ReaderPressFeedback())
    }

    private var directoryContent: some View {
        VStack(spacing: 6) {
            HStack {
                Button("目录") { directoryBookmarks = false }
                    .accessibilityAddTraits(directoryBookmarks ? [] : .isSelected)
                Button("书签") { directoryBookmarks = true }.accessibilityIdentifier("directory-bookmarks")
                    .accessibilityAddTraits(directoryBookmarks ? .isSelected : [])
                Spacer()
                Button("章首") { model.seek(toScalar: 0) }
                Button("章尾") { model.seek(toScalar: session.content.scalarCount) }
            }.font(ReaderTypography.font(.caption)).frame(minHeight: 44).padding(.horizontal, 12)
            if directoryBookmarks { ReaderBookmarkPanel(model: model, state: bookmarks, book: session.book) }
            else { chapterDirectory }
        }
    }

    private struct DirectoryReadIdentity: Equatable {
        let sessionID: UUID
        let bookID: String
        let catalogGeneration: UUID
        let query: String
        let descending: Bool
        let collapsedIDs: [String]
    }

    private var directoryReadIdentity: DirectoryReadIdentity {
        .init(sessionID: session.id, bookID: session.book.id, catalogGeneration: session.catalogGeneration,
              query: directoryQuery, descending: directoryDescending, collapsedIDs: directoryCollapsed.sorted())
    }

    private var directoryChapters: [ReaderChapter] {
        let query = directoryQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let values = session.chapters.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
        return directoryDescending ? Array(values.reversed()) : values
    }

    private var canonicalDirectoryEnabled: Bool {
        guard model.libraryService is any ReaderLibraryFeatures else { return true }
        return directorySnapshot?.status == "canonical" && directorySnapshot?.sourceId == session.book.sourceId &&
            directorySnapshot?.bookId == session.book.bookId
    }

    private var chapterDirectory: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    TextField("筛选目录标题", text: $directoryQuery).readerField().accessibilityIdentifier("directory-query")
                    Button(directoryDescending ? "正序" : "倒序") { directoryDescending.toggle() }
                        .frame(minWidth: 44, minHeight: 44)
                    Button("定位") {
                        directoryLocatePending = true
                        directoryQuery = ""; directoryCollapsed.removeAll()
                        if canonicalDirectoryEnabled {
                            let expectedSession = session.id
                            let expectedBook = session.book.id
                            Task { @MainActor in
                                await Task.yield()
                                guard canonicalDirectoryEnabled, model.reader?.id == expectedSession,
                                      model.reader?.book.id == expectedBook else { return }
                                proxy.scrollTo("canonical-\(session.content.chapterIndex)", anchor: .center)
                                directoryLocatePending = false
                            }
                        } else {
                            Task { await loadDirectory() }
                        }
                    }.frame(minWidth: 44, minHeight: 44).accessibilityIdentifier("locate-current-chapter")
                }.font(ReaderTypography.font(.caption)).padding(.horizontal, 12)
                if model.libraryService is any ReaderLibraryFeatures {
                    projectedDirectory(proxy: proxy)
                } else { canonicalDirectory(proxy: proxy) }
            }
        }.task(id: directoryReadIdentity) { await loadDirectory() }
    }

    @ViewBuilder
    private func canonicalDirectory(proxy: ScrollViewProxy) -> some View {
        if directoryChapters.isEmpty { ReaderPageState(title: "没有符合条件的章节") }
        else {
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(directoryChapters) { chapter in
                        canonicalChapterRow(chapter)
                    }
                }.scrollTargetLayout().padding(.horizontal, 12).padding(.bottom, 12)
            }.scrollPosition(id: $directoryAnchor, anchor: .top).onAppear {
                if directoryAnchor == nil || directoryLocatePending {
                    proxy.scrollTo("canonical-\(session.content.chapterIndex)", anchor: .center)
                    directoryLocatePending = false
                }
            }.onChange(of: directoryLoadedGeneration) { _, _ in
                if directoryLocatePending, canonicalDirectoryEnabled,
                   model.reader?.id == session.id, model.reader?.book.id == session.book.id {
                    proxy.scrollTo("canonical-\(session.content.chapterIndex)", anchor: .center)
                    directoryLocatePending = false
                }
            }
        }
    }

    private func canonicalChapterRow(_ chapter: ReaderChapter) -> some View {
        let selected = chapter.index == session.content.chapterIndex
        return Button { openCanonicalChapter(chapter.index) } label: {
            HStack(spacing: 12) {
                Text(chapter.title).font(ReaderTypography.font(.caption)).multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if selected { ReaderIcon(.check, size: 18) }
            }.foregroundStyle(selected ? palette.green : palette.ink)
                .padding(.horizontal, 14).frame(minHeight: 48)
                .background(selected ? palette.primarySoft : .clear, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(ReaderPressFeedback())
            .disabled(model.chapterLoading || model.closingReader)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .id("canonical-\(chapter.index)").accessibilityIdentifier("chapter-\(chapter.index)")
    }

    private func openCanonicalChapter(_ index: UInt32) {
        let expectedSession = session.id
        let expectedBook = session.book.id
        Task { @MainActor in
            guard canonicalDirectoryEnabled, model.reader?.id == expectedSession,
                  model.reader?.book.id == expectedBook else { return }
            await model.changeChapter(to: index)
        }
    }

    @ViewBuilder
    private func projectedDirectory(proxy: ScrollViewProxy) -> some View {
        if directoryLoading, directorySnapshot == nil { ReaderPageState(title: "正在读取目录", loading: true) }
        else if let directoryFailure, directorySnapshot == nil {
            ReaderPageState(title: directoryFailure, actionTitle: "重试") { Task { await loadDirectory() } }
        } else if let snapshot = directorySnapshot {
            if snapshot.sourceId != session.book.sourceId || snapshot.bookId != session.book.bookId {
                ReaderPageState(title: "目录暂不可用", actionTitle: "重试") { Task { await loadDirectory() } }
            } else if snapshot.status == "canonical" {
                canonicalDirectory(proxy: proxy)
            } else if snapshot.status != "ready" {
                ReaderPageState(title: "目录暂不可用", detail: snapshot.reason ?? "", actionTitle: "重试") { Task { await loadDirectory() } }
            } else if snapshot.nodes.isEmpty { ReaderPageState(title: directoryQuery.isEmpty ? "目录为空" : "没有符合条件的章节") }
            else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(snapshot.nodes) { node in
                            Button {
                                if node.hasChildren && !node.navigable {
                                    if directoryCollapsed.contains(node.id) { directoryCollapsed.remove(node.id) }
                                    else { directoryCollapsed.insert(node.id) }
                                } else if node.navigable { Task { await model.jump(node: node, snapshot: snapshot) } }
                            } label: {
                                HStack(spacing: 8) {
                                    if node.hasChildren { ReaderIcon(.chevronDown, size: 14).rotationEffect(.degrees(node.expanded ? 0 : -90)) }
                                    Text(node.displayTitle ?? node.title).font(ReaderTypography.font(.caption)).multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                    if node.navigable, node.chapterIndex == session.content.chapterIndex { ReaderIcon(.check, size: 18) }
                                }.padding(.leading, 14 + CGFloat(min(node.depth, 6)) * 12).padding(.trailing, 14).frame(minHeight: 48)
                                    .background(node.navigable && node.chapterIndex == session.content.chapterIndex ? palette.primarySoft : .clear,
                                        in: RoundedRectangle(cornerRadius: 12))
                            }.buttonStyle(ReaderPressFeedback())
                                .disabled((!node.navigable && !node.hasChildren) || model.chapterLoading || model.closingReader)
                                .accessibilityAddTraits(node.navigable && node.chapterIndex == session.content.chapterIndex ? .isSelected : [])
                                .accessibilityIdentifier(node.navigable ? "chapter-\(node.chapterIndex ?? 0)" : "directory-node-\(node.id)")
                                .id(node.id)
                        }
                    }.scrollTargetLayout().padding(.horizontal, 12).padding(.bottom, 12)
                }.scrollPosition(id: $directoryAnchor, anchor: .top).onAppear {
                    if directoryAnchor == nil, let node = snapshot.nodes.first(where: { $0.navigable && $0.chapterIndex == session.content.chapterIndex }) {
                        proxy.scrollTo(node.id, anchor: .center)
                    }
                }.onChange(of: directoryLoadedGeneration) { _, _ in
                    if directoryLocatePending, let node = snapshot.nodes.first(where: { $0.navigable && $0.chapterIndex == session.content.chapterIndex }) {
                        proxy.scrollTo(node.id, anchor: .center); directoryLocatePending = false
                    }
                }
            }
        }
    }

    private func loadDirectory() async {
        guard let feature = model.libraryService as? any ReaderLibraryFeatures else { return }
        let expectedSession = session.id
        let book = session.book
        let generation = UUID(); directoryGeneration = generation; directoryLoading = true
        do {
            let snapshot = try await feature.directory(for: book, query: directoryQuery,
                descending: directoryDescending, collapsedNodeIDs: Array(directoryCollapsed))
            guard directoryGeneration == generation, !Task.isCancelled,
                  model.reader?.id == expectedSession, model.reader?.book.id == book.id else { return }
            guard snapshot.sourceId == book.sourceId, snapshot.bookId == book.bookId else {
                throw ReaderLibraryError.invalidResponse("directory book identity")
            }
            if directorySnapshot?.status != snapshot.status { directoryAnchor = nil }
            directorySnapshot = snapshot; directoryFailure = nil; directoryLoadedGeneration = generation
        } catch {
            guard directoryGeneration == generation, !Task.isCancelled,
                  model.reader?.id == expectedSession, model.reader?.book.id == book.id else { return }
            directoryFailure = error.localizedDescription
            if directorySnapshot != nil { model.showFeedback("目录刷新失败，已有目录保留") }
        }
        if directoryGeneration == generation { directoryLoading = false }
    }

    private var readingSettings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button("正文搜索") { openNested(.search) }
                Button("高亮与笔记") { openNested(.notes) }
                Button("替换、字典与目录规则") { openNested(.rules) }
                Button("阅读记录") { openNested(.records) }
                Button("自动翻页") { openNested(.autoPage) }
                Button("字体与排版") { openNested(.appearance) }
                if session.book.sourceId == "local" { Button("按已保存规则重新处理本书") { confirmReprocess() }.disabled(model.actions.hasPending) }
                Button(preferences.theme.isDark ? "切换日间纸色" : "切换夜间纸色") {
                    preferences.theme = preferences.theme.isDark ? .day : .night
                }
            }.font(ReaderTypography.font(.body)).buttonStyle(ReaderPressFeedback())
                .frame(maxWidth: .infinity, alignment: .leading).padding(16)
        }
    }

    private func moduleButton(_ value: ReaderControlModule, icon: ReaderIconName, label: String) -> some View {
        Button { select(value) } label: {
            // Host@33f7c7b ReaderControlPanel.ets:1978–2007. The active
            // registered SVGs retain the same paths, changing only this ink.
            VStack(spacing: 5) {
                Image(icon.assetName).renderingMode(.template).resizable().scaledToFit()
                    .frame(width: 24, height: 24)
                    .foregroundStyle(module == value ? palette.app("app.control.onPrimary") : palette.readPrimary)
                    .frame(width: 42, height: 42)
                    .background(module == value ? palette.readPrimary : palette.app("TOK_READ_ACTIVE_SOFT"), in: Circle())
                    .accessibilityHidden(true)
                Text(label).font(ReaderTextStyle(.uiBold, 10, 700, lineHeight: 15).font)
                    .foregroundStyle(module == value ? palette.readPrimary : palette.app("TOK_READ_ICON"))
                    .frame(maxWidth: .infinity).frame(height: 15).lineLimit(1)
            }.frame(maxWidth: .infinity).frame(height: 62)
                .contentShape(RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(ReaderPressFeedback()).accessibilityAddTraits(module == value ? .isSelected : [])
            .accessibilityIdentifier("control-module-\(value)")
    }

    private func nativeLayoutReady() {
        guard model.reader?.id == session.id, model.reader?.restorationID == session.restorationID else { return }
        surfaceReady = true
        automaticPage.layoutReady(chapterIndex: session.content.chapterIndex)
    }
    private func updateReadingTimeVisibility() {
        model.setReadingBodyVisible(surfaceReady && !controlsVisible && sheet == nil && !model.importResultVisible &&
            !surfaceLoading && surfaceFailure == nil && localKind?.reimportRequired != true,
            sessionID: session.id)
    }

    private func loadSurface() async {
        guard session.book.sourceId == "local", let feature = model.libraryService as? any ReaderLibraryFeatures else { return }
        let generation = UUID(); surfaceGeneration = generation
        let identity = surfaceIdentity
        surfaceReady = false; surfaceLoading = true; surfaceFailure = nil
        localKind = nil; ebookDocument = nil; ebookArchive = nil
        defer { if generation == surfaceGeneration { surfaceLoading = false } }
        do {
            let kind = try await feature.localPresentationKind(for: session.book)
            guard !Task.isCancelled, generation == surfaceGeneration, identity == surfaceIdentity else { return }
            guard kind.sourceId == session.book.sourceId, kind.bookId == session.book.bookId else { throw ReaderLibraryError.invalidPosition }
            if kind.kind == .ebook, !kind.reimportRequired {
                let document = try await feature.ebookPresentation(for: session.book, chapterIndex: session.content.chapterIndex)
                try document.validate(content: session.content)
                let source = try await feature.retainedSourceURL(for: session.book)
                guard !Task.isCancelled, generation == surfaceGeneration, identity == surfaceIdentity else { return }
                ebookDocument = document
                ebookArchive = ReaderEbookArchiveReader(sourceURL: source, bookID: session.book.bookId)
            }
            localKind = kind
        } catch {
            guard !Task.isCancelled, generation == surfaceGeneration else { return }
            surfaceFailure = error.localizedDescription
        }
    }
    private func confirmReprocess() {
        automaticPage.pause()
        let expected = session.id
        confirmation.confirm("重新处理本书？", message: "使用已保存的正文和 TXT 目录规则，由 Core 迁移阅读位置、书签与笔记；原文件保留。", actionTitle: "重新处理") {
            guard model.reader?.id == expected else { return }
            Task {
                _ = await model.actions.perform("重新处理本书", scope: session.book.id) { id in
                    try await model.reprocessLocalCurrentBook(operationID: id)
                }
            }
        }
    }

    private var moreMenu: some View {
        VStack(spacing: 0) {
            Button("书籍信息") { pendingSheet = .info; moreVisible = false }.frame(minHeight: 44)
            if session.book.sourceId != "local" {
                Button("切换书源") { pendingSheet = .sourceSwitch; moreVisible = false }.frame(minHeight: 44)
                Button("下载管理") { pendingSheet = .downloads; moreVisible = false }.frame(minHeight: 44)
            }
        }.font(ReaderTypography.font(.body)).padding(12).frame(width: 196)
            .foregroundStyle(palette.ink).background(palette.card).buttonStyle(ReaderPressFeedback())
    }
    private func dispatchMoreAction() {
        guard let target = pendingSheet, model.reader?.id == session.id, model.foreground else { pendingSheet = nil; return }
        pendingSheet = nil
        dismissControls()
        sheet = target
    }
    private func reportFontFallback() {
        guard let name = preferences.fontPostScriptName else { fontFallbackReported = nil; return }
        guard fontLibrary.resolvedFont(named: name, size: preferences.fontSize) == nil, fontFallbackReported != name else { return }
        fontFallbackReported = name
        model.showFeedback("所选字体缺失或来源无法核实，正文暂用内置字体；原选择已保留")
    }
    private func startAutomaticPage() {
        guard automaticPageAvailable, model.foreground, !model.chapterLoading, !model.closingReader, !model.sourceSwitchFrozen else { return }
        dismissControls()
        automaticPage.start(seconds: preferences.autoPageSeconds,
            duration: Double(preferences.autoPageTimerMinutes * 60 + preferences.autoPageTimerSeconds))
    }
    private func handleAutomaticPage(_ id: UUID, _ outcome: ReaderNativePageOutcome) {
        guard model.reader?.id == session.id, automaticPage.turnID == id else { return }
        switch outcome {
        case .advanced: automaticPage.committed(id)
        case .cancelled: automaticPage.pause()
        case .chapterEnd:
            guard let position = session.chapters.firstIndex(where: { $0.index == session.content.chapterIndex }),
                  session.chapters.indices.contains(position + 1) else { automaticPage.stop(); return }
            let next = session.chapters[position + 1].index
            let originalSession = session
            let owner = automaticPage
            owner.waitingForChapter(next, turn: id)
            Task {
                await model.changeChapterAutomatically(to: next, fromChapter: originalSession.content.chapterIndex,
                    sessionID: originalSession.id, restorationID: originalSession.restorationID, turnID: id, owner: owner)
            }
        }
    }

    private func invokeControls() {
        traceGesture("invoke-controls")
        display.interaction()
        automaticPage.pause()
        moduleParents.removeAll()
        module = .home
        motion.move(to: .quick, reduceMotion: effectiveReduceMotion)
    }
    private func dismissControls() {
        traceGesture("dismiss-controls")
        scrubFraction = nil
        motion.move(to: .hidden, reduceMotion: effectiveReduceMotion)
    }
    private func traceGesture(_ event: String) {
        #if DEBUG
        Logger(subsystem: "io.reader.minliny", category: "reader-gestures")
            .debug("view event=\(event, privacy: .public) controls=\(controlsVisible) ready=\(surfaceReady)")
        #endif
    }
    #if DEBUG
    private func dockInputTraceKey(progress: CGFloat, endpointInput: Bool) -> String {
        let endpoint = progress == 0 ? "quick" : progress == 1 ? "full" : "transition"
        let visibility = motion.visibility <= 0 ? "hidden" : motion.visibility >= 1 ? "visible" : "transition"
        // Observe category changes, not every display-link sample. The payload
        // captures the actual existing input gate without changing its policy.
        return "\(module)|\(endpoint)|\(visibility)|\(endpointInput)"
    }
    private func traceDockInput(progress: CGFloat, endpointInput: Bool) {
        Logger(subsystem: "io.reader.minliny", category: "reader-gestures")
            .debug("view event=dock-input module=\(String(describing: module), privacy: .public) p=\(Double(progress), privacy: .public) visibility=\(Double(motion.visibility), privacy: .public) pointerHeld=\(pointerHeld) isDragging=\(motion.isDragging) isAnimating=\(motion.isAnimating) endpointInput=\(endpointInput)")
    }
    #endif
    private func expand() {
        motion.move(to: .full, reduceMotion: effectiveReduceMotion)
    }
    private func collapse() {
        motion.move(to: .quick, reduceMotion: effectiveReduceMotion)
    }
    private func openNested(_ value: ReaderControlModule) {
        automaticPage.pause()
        moduleParents.append(module)
        module = value
    }
    private func backModule() {
        guard let parent = moduleParents.popLast() else { return }
        automaticPage.pause(); module = parent
    }
    private func select(_ value: ReaderControlModule) {
        display.interaction()
        moduleParents.removeAll()
        automaticPage.pause()
        let previous = module
        module = value
        if value == .home || previous == .home { collapse() }
    }
    private func configureMotion(size: CGSize, safe: EdgeInsets) {
        let layout = controlViewport(size: size, safe: safe)
        // The driver needs a positive numeric axis even when no drawable lane
        // remains. Rendering hides the dock for a zero-height budget.
        motion.configure(quickHeight: max(1, layout.quickHeight), fullHeight: max(1, layout.fullHeight),
                         allowsExpansion: module != .home, reduceMotion: effectiveReduceMotion)
    }

    private func controlViewport(size: CGSize, safe: EdgeInsets) -> ReaderControlViewportLayout {
        let baseline = ReaderMetrics.controlViewport(size: size, safe: safe)
        guard readingHeaderHeight > 54 else { return baseline }
        let windowHeight = size.height + safe.top + safe.bottom
        let headerTop = max(19, safe.top + 10)
        let dockTop = max(88, headerTop + readingHeaderHeight + 8)
        let fullHeight = min(baseline.fullHeight,
            max(0, windowHeight - dockTop - max(ReaderMetrics.fullBottomGap, safe.bottom)))
        return ReaderControlViewportLayout(topBarWidth: baseline.topBarWidth,
            topBarPadding: baseline.topBarPadding, topBarOffsetX: baseline.topBarOffsetX,
            dockWidth: baseline.dockWidth, dockOffsetX: baseline.dockOffsetX,
            dockBottomPadding: baseline.dockBottomPadding, fullHeight: fullHeight,
            quickHeight: min(baseline.quickHeight, fullHeight))
    }

}

private struct ReaderReadingHeaderHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

/// Sends the real pointer lifecycle to the existing motion owner. A delayed
/// DragGesture threshold cannot represent DOWN, a stationary hold, or CANCEL.
private struct ReaderControlTouchCap: UIViewRepresentable {
    let label: String
    let began: (TimeInterval) -> Void
    let changed: (CGFloat, TimeInterval) -> Void
    let ended: (CGFloat, TimeInterval) -> Void
    let cancelled: () -> Void
    let activated: () -> Void

    func makeUIView(context: Context) -> ReaderControlTouchCapView {
        let view = ReaderControlTouchCapView()
        updateUIView(view, context: context)
        return view
    }
    func updateUIView(_ view: ReaderControlTouchCapView, context: Context) {
        view.accessibilityLabel = label
        view.began = began; view.changed = changed; view.ended = ended
        view.cancelled = cancelled; view.activated = activated
    }
    static func dismantleUIView(_ view: ReaderControlTouchCapView, coordinator: ()) { view.retire() }
}

private final class ReaderControlTouchCapView: UIView {
    var began: ((TimeInterval) -> Void)?
    var changed: ((CGFloat, TimeInterval) -> Void)?
    var ended: ((CGFloat, TimeInterval) -> Void)?
    var cancelled: (() -> Void)?
    var activated: (() -> Void)?
    private weak var pointer: UITouch?
    private var originY: CGFloat = 0

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        isMultipleTouchEnabled = true
        isAccessibilityElement = true
        accessibilityTraits = .button
        accessibilityIdentifier = "control-grabber"
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        let activeTouches = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }.count ?? touches.count
        guard pointer == nil, touches.count == 1, activeTouches == 1, let touch = touches.first else { return }
        pointer = touch
        originY = touch.location(in: nil).y
        began?(touch.timestamp)
    }
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pointer, touches.contains(pointer) else { return }
        changed?(pointer.location(in: nil).y - originY, pointer.timestamp)
    }
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = pointer, touches.contains(touch) else { return }
        pointer = nil
        ended?(touch.location(in: nil).y - originY, touch.timestamp)
    }
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let pointer, touches.contains(pointer) else { return }
        cancelPointer()
    }
    func cancelPointer() {
        guard pointer != nil else { return }
        pointer = nil
        cancelled?()
    }
    func retire() {
        // The reader owner revokes its clock on disappearance. Retiring a UIKit
        // bridge must not publish back into SwiftUI's removal transaction.
        pointer = nil
        began = nil; changed = nil; ended = nil; cancelled = nil; activated = nil
        isUserInteractionEnabled = false
        isAccessibilityElement = false
    }
    override func accessibilityActivate() -> Bool { activated?(); return activated != nil }
}

/// Native pointer/keyboard ownership, retaining Host@33f7c7b
/// ReaderControlPanel.ets:1739–1770 and ReaderControlGeometry.ts:46–48.
private struct ReaderChapterProgressSlider: UIViewRepresentable {
    let value: Double
    let changed: (Double) -> Void
    let committed: (Double) -> Void
    let cancelled: () -> Void
    @Environment(\.colorScheme) private var scheme

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> ReaderChapterProgressSliderView {
        let view = ReaderChapterProgressSliderView(frame: .zero)
        view.minimumValue = 0
        view.maximumValue = 100
        view.isContinuous = true
        view.accessibilityLabel = "章节阅读进度"
        view.accessibilityIdentifier = "chapter-progress"
        view.addTarget(context.coordinator, action: #selector(Coordinator.preview(_:)), for: .valueChanged)
        view.addTarget(context.coordinator, action: #selector(Coordinator.commit(_:)), for: [.touchUpInside, .touchUpOutside])
        view.addTarget(context.coordinator, action: #selector(Coordinator.cancel(_:)), for: .touchCancel)
        updateUIView(view, context: context)
        return view
    }
    func updateUIView(_ view: ReaderChapterProgressSliderView, context: Context) {
        context.coordinator.parent = self
        view.applyPalette(ReaderPalette(scheme))
        if !view.isTracking && !view.isScrubbingTrack {
            view.setValue(Float(min(1, max(0, value)) * 100), animated: false)
        }
    }
    static func dismantleUIView(_ view: ReaderChapterProgressSliderView, coordinator: Coordinator) {
        view.retireTrackGesture()
        view.removeTarget(coordinator, action: nil, for: .allEvents)
    }

    final class Coordinator: NSObject {
        var parent: ReaderChapterProgressSlider
        private var completedTrackSequence: UUID?
        init(_ parent: ReaderChapterProgressSlider) { self.parent = parent }
        private func fraction(_ view: ReaderChapterProgressSliderView) -> Double {
            let percent = (Double(view.value) * 10).rounded() / 10
            view.setValue(Float(percent), animated: false)
            return percent / 100
        }
        @objc func preview(_ view: ReaderChapterProgressSliderView) {
            if let sequence = view.ownedTrackSequenceID,
               completedTrackSequence == sequence || !view.acceptsTrackPreview { return }
            parent.changed(fraction(view))
        }
        private func claimTerminal(_ view: ReaderChapterProgressSliderView, cancelled: Bool) -> Bool {
            if let sequence = view.ownedTrackSequenceID {
                guard completedTrackSequence != sequence, view.acceptsTrackTerminal(cancelled: cancelled) else {
                    view.traceProgress(cancelled ? "target.cancel.rejected" : "target.commit.rejected")
                    return false
                }
                completedTrackSequence = sequence
            }
            view.traceProgress(cancelled ? "target.cancel.accepted" : "target.commit.accepted")
            return true
        }
        @objc func commit(_ view: ReaderChapterProgressSliderView) {
            guard claimTerminal(view, cancelled: false) else { return }
            parent.committed(fraction(view))
        }
        @objc func cancel(_ view: ReaderChapterProgressSliderView) {
            guard claimTerminal(view, cancelled: true) else { return }
            parent.cancelled()
        }
    }
}

private final class ReaderChapterProgressSliderView: UISlider, UIGestureRecognizerDelegate {
    private var paletteScheme: ColorScheme?
    private var ownsTrackTouch = false
    private enum TrackPhase { case tracking, ending, cancelling }
    private var trackPhase: TrackPhase?
    private(set) var ownedTrackSequenceID: UUID?
    private weak var candidateTrackTouch: UITouch?
    private lazy var trackPress: UILongPressGestureRecognizer = {
        let gesture = UILongPressGestureRecognizer(target: self, action: #selector(trackPressed(_:)))
        gesture.minimumPressDuration = 0
        gesture.allowableMovement = .greatestFiniteMagnitude
        gesture.cancelsTouchesInView = true
        gesture.delaysTouchesBegan = false
        gesture.delaysTouchesEnded = false
        gesture.delegate = self
        return gesture
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addGestureRecognizer(trackPress)
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        addGestureRecognizer(trackPress)
    }

    var isScrubbingTrack: Bool { ownsTrackTouch }
    var acceptsTrackPreview: Bool { trackPhase == .tracking }
    func acceptsTrackTerminal(cancelled: Bool) -> Bool {
        switch trackPhase {
        case .ending: return !cancelled
        case .cancelling: return cancelled
        default: return false
        }
    }
    func traceProgress(_ event: String) {
        #if DEBUG
        Logger(subsystem: "io.reader.minliny", category: "reader-gestures")
            .debug("slider event=\(event, privacy: .public) sequence=\(self.ownedTrackSequenceID?.uuidString ?? "native", privacy: .public) value=\(self.value) tracking=\(self.isTracking) ownsTrack=\(self.ownsTrackTouch)")
        #endif
    }

    override func trackRect(forBounds bounds: CGRect) -> CGRect {
        let native = super.trackRect(forBounds: bounds)
        return CGRect(x: native.minX, y: native.midY - 2.5, width: native.width, height: 5)
    }
    func applyPalette(_ palette: ReaderPalette) {
        guard paletteScheme != palette.scheme else { return }
        paletteScheme = palette.scheme
        minimumTrackTintColor = UIColor(palette.accent)
        maximumTrackTintColor = UIColor(palette.border)
        let thumb = UIGraphicsImageRenderer(size: CGSize(width: 18, height: 18)).image { renderer in
            let lineWidth: CGFloat = 2.778
            let rect = CGRect(x: 0, y: 0, width: 18, height: 18).insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            renderer.cgContext.setFillColor(UIColor(palette.app("TOK_SURFACE_SOLID_OPAQUE")).cgColor)
            renderer.cgContext.setStrokeColor(UIColor(palette.accent).cgColor)
            renderer.cgContext.setLineWidth(lineWidth)
            renderer.cgContext.addEllipse(in: rect)
            renderer.cgContext.drawPath(using: .fillStroke)
        }
        setThumbImage(thumb, for: .normal)
        setThumbImage(thumb, for: .highlighted)
    }
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        // UIKit did not deliver endTracking for the prior off-thumb override.
        // The public continuous recognizer owns those touches through release
        // or cancellation; native thumb touches retain UISlider's lifecycle.
        guard candidateTrackTouch !== touch, !ownsTrackTouch,
              isOnCurrentThumb(touch.location(in: self)) else { return false }
        ownedTrackSequenceID = nil; trackPhase = nil
        return super.beginTracking(touch, with: event)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === trackPress else { return true }
        let location = touch.location(in: self)
        guard isEnabled, bounds.contains(location), !isOnCurrentThumb(location) else {
            candidateTrackTouch = nil
            return false
        }
        candidateTrackTouch = touch
        return true
    }

    private func isOnCurrentThumb(_ location: CGPoint) -> Bool {
        thumbRect(forBounds: bounds, trackRect: trackRect(forBounds: bounds), value: value)
            .insetBy(dx: -4, dy: -4).contains(location)
    }

    @objc private func trackPressed(_ gesture: UILongPressGestureRecognizer) {
        let location = gesture.location(in: self)
        switch gesture.state {
        case .began:
            guard isEnabled, bounds.contains(location) else { return }
            ownsTrackTouch = true
            ownedTrackSequenceID = UUID(); trackPhase = .tracking
            isHighlighted = true
            traceProgress("track.begin")
            if !updateTrackValue(at: location) { finishTrack(cancelled: true) }
        case .changed:
            guard ownsTrackTouch else { return }
            updateTrackValue(at: location)
        case .ended:
            guard ownsTrackTouch else { candidateTrackTouch = nil; return }
            updateTrackValue(at: location)
            finishTrack(cancelled: false, endedInside: bounds.contains(location))
        case .cancelled, .failed:
            finishTrack(cancelled: true)
        default: break
        }
    }

    private func finishTrack(cancelled: Bool, endedInside: Bool = true) {
        candidateTrackTouch = nil
        guard ownsTrackTouch else { return }
        trackPhase = cancelled ? .cancelling : .ending
        ownsTrackTouch = false
        isHighlighted = false
        traceProgress(cancelled ? "track.cancel" : "track.end")
        sendActions(for: cancelled ? .touchCancel : (endedInside ? .touchUpInside : .touchUpOutside))
    }

    func retireTrackGesture() {
        finishTrack(cancelled: true)
        trackPress.isEnabled = false
    }
    @discardableResult
    private func updateTrackValue(at location: CGPoint) -> Bool {
        let track = trackRect(forBounds: bounds)
        let first = thumbRect(forBounds: bounds, trackRect: track, value: minimumValue).midX
        let last = thumbRect(forBounds: bounds, trackRect: track, value: maximumValue).midX
        let span = last - first
        guard location.x.isFinite, span.isFinite, abs(span) > .ulpOfOne else { return false }
        // Preserve the sign for native right-to-left slider geometry.
        let fraction = min(1, max(0, (location.x - first) / span))
        setValue(minimumValue + Float(fraction) * (maximumValue - minimumValue), animated: false)
        sendActions(for: .valueChanged)
        return true
    }
    override func accessibilityIncrement() { adjustAccessibly(by: 0.1) }
    override func accessibilityDecrement() { adjustAccessibly(by: -0.1) }
    private func adjustAccessibly(by step: Float) {
        if ownsTrackTouch {
            finishTrack(cancelled: true)
            trackPress.isEnabled = false; trackPress.isEnabled = true
        }
        ownedTrackSequenceID = nil; trackPhase = nil
        setValue(min(maximumValue, max(minimumValue, value + step)), animated: false)
        sendActions(for: .valueChanged)
        sendActions(for: .touchUpInside)
    }
}

struct ReaderTrackSlider: View {
    let value: Double
    let changed: (Double) -> Void
    let committed: (Double) -> Void
    @Environment(\.colorScheme) private var scheme
    @State private var dragging = false
    private var clamped: Double { min(1, max(0, value)) }
    var body: some View {
        GeometryReader { geometry in
            let length = max(1, geometry.size.width - 20)
            ZStack(alignment: .leading) {
                Capsule().fill(ReaderPalette(scheme).primarySoft).frame(height: 8)
                Capsule().fill(ReaderPalette(scheme).green).frame(width: 10 + length * clamped, height: 8)
                Circle().fill(ReaderPalette(scheme).green).frame(width: 20, height: 20).offset(x: length * clamped)
            }.frame(maxHeight: .infinity).contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 0).onChanged { event in
                    dragging = true
                    changed(min(1, max(0, (event.location.x - 10) / length)))
                }.onEnded { event in
                    dragging = false
                    committed(min(1, max(0, (event.location.x - 10) / length)))
                })
        }.frame(height: 44).accessibilityElement().accessibilityValue("\(Int(clamped * 100))%")
            .accessibilityAdjustableAction { direction in
                let next = min(1, max(0, clamped + (direction == .increment ? 0.05 : -0.05)))
                changed(next); committed(next)
            }
    }
}
