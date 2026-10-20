import SwiftUI
import UIKit

private enum ReaderControlModule { case home, directory, appearance }

struct ReaderReadingView: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var preferences: ReaderPreferences
    let session: ReaderActiveSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var motion = ReaderControlMotionDriver()
    @StateObject private var brightness = ReaderBrightnessOwner()
    @State private var module: ReaderControlModule = .home
    @State private var scrubFraction: Double?
    @State private var recoveryBusy = false
    @State private var pointerHeld = false
    @ScaledMetric(relativeTo: .body) private var footerHeight: CGFloat = 24

    private var paper: ReaderPaperPalette { ReaderPaperPalette(theme: preferences.theme) }
    private var palette: ReaderPalette { ReaderPalette(preferences.appDark ? .dark : .light) }
    private var controlsVisible: Bool { motion.isPresented }
    private var fullProgress: CGFloat { motion.expansion }
    private var fraction: Double {
        session.content.scalarCount == 0 ? 0 : Double(session.scalarOffset) / Double(session.content.scalarCount)
    }

    var body: some View {
        GeometryReader { geometry in
            let controlLayout = ReaderMetrics.controlViewport(size: geometry.size, safe: geometry.safeAreaInsets)
            // Reserve the footer in the viewport as well as at the end of the
            // chapter. An end-of-content inset alone lets intermediate lines
            // paint behind the footer. Keep the viewport stable while controls move.
            let footerSpace = footerHeight + 1 + max(0, 23 - geometry.safeAreaInsets.bottom)
            ZStack(alignment: .bottom) {
                ReaderPaperBackground(theme: preferences.theme).ignoresSafeArea()
                ReaderBrightnessAttachment(owner: brightness).frame(width: 0, height: 0)
                let windowWidth = geometry.size.width + geometry.safeAreaInsets.leading + geometry.safeAreaInsets.trailing
                let margin = ReaderMetrics.readingHorizontalInset(width: windowWidth,
                    safeHorizontal: max(geometry.safeAreaInsets.leading, geometry.safeAreaInsets.trailing))
                    ReaderTextSurface(content: session.content, scalarOffset: session.scalarOffset,
                        restorationID: session.restorationID, fontSize: preferences.fontSize,
                        lineHeight: preferences.lineHeight, horizontalInset: margin,
                        safeLeft: geometry.safeAreaInsets.leading, safeRight: geometry.safeAreaInsets.trailing,
                        bottomInset: max(0, ReaderMetrics.readingBottomInset(width: windowWidth) - geometry.safeAreaInsets.bottom - footerSpace), paper: paper,
                        positionChanged: { model.recordVisibleOffset($0, sessionID: session.id, restorationID: session.restorationID) },
                        centerTapped: { if controlsVisible { dismissControls() } else { invokeControls() } })
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
            }.onAppear { configureMotion(size: geometry.size, safe: geometry.safeAreaInsets); brightness.enterReader() }
                .onChange(of: geometry.size) { _, size in configureMotion(size: size, safe: geometry.safeAreaInsets) }
                .onChange(of: geometry.safeAreaInsets) { _, safe in configureMotion(size: geometry.size, safe: safe) }
                .onChange(of: module) { _, _ in configureMotion(size: geometry.size, safe: geometry.safeAreaInsets) }
        }
        .preferredColorScheme(preferences.theme.isDark ? .dark : .light)
        .onChange(of: model.foreground) { _, active in
            if !active { pointerHeld = false; motion.cancelDrag(reduceMotion: reduceMotion); scrubFraction = nil }
        }
        .onDisappear { pointerHeld = false; motion.stop(publishingFinalSample: false); brightness.leaveReader() }
        .onChange(of: reduceMotion) { _, enabled in
            if enabled { motion.move(to: motion.target, reduceMotion: true) }
        }
        .onChange(of: pointerHeld) { _, held in
            if !held { motion.cancelDrag(reduceMotion: reduceMotion) }
        }
    }

    private var readingHeader: some View {
        HStack(spacing: 8) {
            ReaderIconAction(icon: .back, label: "返回书架") { Task { await model.closeReader() } }
                .accessibilityIdentifier("leave-reader")
            VStack(alignment: .leading, spacing: 5) {
                Text(session.book.title)
                    .font(.custom(ReaderFonts.postScriptName(.serifBold), size: 16, relativeTo: .body))
                    .foregroundStyle(palette.readInk).lineLimit(1)
                Text("\(session.content.chapterTitle) · 本地")
                    .font(.custom(ReaderFonts.postScriptName(.serif), size: 12, relativeTo: .body))
                    .foregroundStyle(palette.app("TOK_READ_MUTED")).lineLimit(1)
            }.frame(maxWidth: .infinity, alignment: .leading).frame(height: 45)
            ReaderIconAction(icon: .chevronDown, label: "收起阅读控制") { dismissControls() }
        }.padding(.horizontal, 13).frame(height: 54)
            .background(palette.app("TOK_READ_SURFACE"), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(palette.app("TOK_LINE_STRONG"), lineWidth: 1))
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
                else { ScrollView { appearanceContent.padding(16) } }
            }.frame(width: contentWidth, height: max(0, contentHeight), alignment: .topLeading)
                .clipped().offset(x: inset, y: 29 + 28 * p)
                .allowsHitTesting(endpointInput)
            if module != .home {
                HStack {
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
            HStack(spacing: 4) {
                moduleButton(.home, icon: .bookshelf, label: "阅读")
                moduleButton(.directory, icon: .directory, label: "目录")
                moduleButton(.appearance, icon: .appearance, label: "外观")
            }.padding(.leading, 9).padding(.top, 9)
                .frame(width: max(0, width - 24), height: 80)
                .background(palette.app("TOK_SURFACE_SOLID_OPAQUE"), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(palette.app("TOK_LINE_STRONG"), lineWidth: 1))
                .offset(x: 12, y: height - 93 + 20 * p)
                .opacity(1 - p).allowsHitTesting(endpointInput && p < 1)
            Capsule().fill(palette.app("TOK_READ_HANDLE")).frame(width: 42, height: 4)
                .offset(x: (width - 42) / 2, y: 9).allowsHitTesting(false)
            ReaderControlTouchCap(
                label: module == .home ? "控制栏拖动区域，向下关闭" : p == 1 ? "完整控制栏，轻点收起" : "快捷控制栏，轻点展开",
                began: { time in pointerHeld = true; motion.dragChanged(translationY: 0, time: time) },
                changed: { translation, time in motion.dragChanged(translationY: translation, time: time) },
                ended: { translation, time in
                    motion.dragEnded(translationY: translation, time: time, reduceMotion: reduceMotion)
                    pointerHeld = false
                },
                cancelled: { pointerHeld = false; motion.cancelDrag(reduceMotion: reduceMotion) },
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
    }

    private var moduleTitle: String {
        switch module { case .home: return "阅读"; case .directory: return "目录"; case .appearance: return "外观" }
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
                quickAction("目录", icon: .directory) { select(.directory) }
                quickAction(preferences.theme.isDark ? "日间" : "夜间", icon: .sun) {
                    preferences.theme = preferences.theme.isDark ? .day : .night
                }
                quickAction("外观", icon: .appearance) { select(.appearance) }
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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(session.chapters) { chapter in
                        Button {
                            Task { await model.changeChapter(to: chapter.index) }
                        } label: {
                            HStack(spacing: 12) {
                                Text(chapter.title).font(ReaderTypography.font(.caption)).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                if chapter.index == session.content.chapterIndex { ReaderIcon(.check, size: 18) }
                            }.foregroundStyle(chapter.index == session.content.chapterIndex ? palette.green : palette.ink)
                                .padding(.horizontal, 14).frame(minHeight: 48)
                                .background(chapter.index == session.content.chapterIndex ? palette.primarySoft : .clear,
                                            in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(ReaderPressFeedback()).disabled(model.chapterLoading || model.closingReader)
                            .accessibilityAddTraits(chapter.index == session.content.chapterIndex ? .isSelected : [])
                            .id(chapter.index).accessibilityIdentifier("chapter-\(chapter.index)")
                    }
                }.padding(.horizontal, 12).padding(.bottom, 12)
            }.onAppear { proxy.scrollTo(session.content.chapterIndex, anchor: .center) }
        }
    }

    private var appearanceContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("字号").font(ReaderTypography.font(.controlHeader))
                Spacer()
                Button("减小") { preferences.fontSize = max(12, preferences.fontSize - 1) }.frame(minWidth: 44, minHeight: 44)
                Text("\(Int(preferences.fontSize))").monospacedDigit()
                Button("增大") { preferences.fontSize = min(40, preferences.fontSize + 1) }.frame(minWidth: 44, minHeight: 44)
            }.font(ReaderTypography.font(.caption))
            VStack(alignment: .leading, spacing: 8) {
                HStack { Text("行距"); Spacer(); Text(String(format: "%.2f", preferences.lineHeight)) }
                    .font(ReaderTypography.font(.caption))
                ReaderTrackSlider(value: (preferences.lineHeight - 1.2) / 1.6,
                    changed: { preferences.lineHeight = 1.2 + $0 * 1.6 },
                    committed: { preferences.lineHeight = 1.2 + $0 * 1.6 })
                    .accessibilityLabel("正文行距")
            }
            Text("阅读纸色").font(ReaderTypography.font(.controlHeader))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4), spacing: 10) {
                ForEach(ReaderTheme.allCases) { theme in
                    Button { preferences.theme = theme } label: {
                        Text(theme.displayName).font(ReaderTypography.font(.caption))
                            .foregroundStyle(ReaderPaperPalette(theme: theme).ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(ReaderPaperPalette(theme: theme).paper, in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(theme == preferences.theme ? palette.green : palette.border,
                                                                                 lineWidth: theme == preferences.theme ? 2 : 1))
                    }.buttonStyle(ReaderPressFeedback()).accessibilityAddTraits(theme == preferences.theme ? .isSelected : [])
                }
            }
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

    private func invokeControls() {
        module = .home
        motion.move(to: .quick, reduceMotion: reduceMotion)
    }
    private func dismissControls() {
        scrubFraction = nil
        motion.move(to: .hidden, reduceMotion: reduceMotion)
    }
    private func expand() {
        motion.move(to: .full, reduceMotion: reduceMotion)
    }
    private func collapse() {
        motion.move(to: .quick, reduceMotion: reduceMotion)
    }
    private func select(_ value: ReaderControlModule) {
        let previous = module
        module = value
        if value == .home || previous == .home { collapse() }
    }
    private func configureMotion(size: CGSize, safe: EdgeInsets) {
        let layout = ReaderMetrics.controlViewport(size: size, safe: safe)
        // The driver needs a positive numeric axis even when no drawable lane
        // remains. Rendering hides the dock for a zero-height budget.
        motion.configure(quickHeight: max(1, layout.quickHeight), fullHeight: max(1, layout.fullHeight),
                         allowsExpansion: module != .home)
    }

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
        let view = ReaderChapterProgressSliderView()
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
        if !view.isTracking { view.setValue(Float(min(1, max(0, value)) * 100), animated: false) }
    }
    static func dismantleUIView(_ view: ReaderChapterProgressSliderView, coordinator: Coordinator) {
        view.removeTarget(coordinator, action: nil, for: .allEvents)
    }

    final class Coordinator: NSObject {
        var parent: ReaderChapterProgressSlider
        init(_ parent: ReaderChapterProgressSlider) { self.parent = parent }
        private func fraction(_ view: ReaderChapterProgressSliderView) -> Double {
            let percent = (Double(view.value) * 10).rounded() / 10
            view.setValue(Float(percent), animated: false)
            return percent / 100
        }
        @objc func preview(_ view: ReaderChapterProgressSliderView) { parent.changed(fraction(view)) }
        @objc func commit(_ view: ReaderChapterProgressSliderView) { parent.committed(fraction(view)) }
        @objc func cancel(_ view: ReaderChapterProgressSliderView) { parent.cancelled() }
    }
}

private final class ReaderChapterProgressSliderView: UISlider {
    private var paletteScheme: ColorScheme?

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
        // Preserve the existing track-tap/drag entry while UISlider continues
        // to own tracking, cancellation and the native accessibility element.
        let track = trackRect(forBounds: bounds)
        let location = touch.location(in: self)
        let currentThumb = thumbRect(forBounds: bounds, trackRect: track, value: value)
        if !currentThumb.insetBy(dx: -4, dy: -4).contains(location) {
            let first = thumbRect(forBounds: bounds, trackRect: track, value: minimumValue).midX
            let last = thumbRect(forBounds: bounds, trackRect: track, value: maximumValue).midX
            let fraction = min(1, max(0, (location.x - first) / max(1, last - first)))
            setValue(minimumValue + Float(fraction) * (maximumValue - minimumValue), animated: false)
            sendActions(for: .valueChanged)
        }
        return super.beginTracking(touch, with: event)
    }
    override func accessibilityIncrement() { adjustAccessibly(by: 0.1) }
    override func accessibilityDecrement() { adjustAccessibly(by: -0.1) }
    private func adjustAccessibly(by step: Float) {
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
