import SwiftUI
import UIKit
import CoreText
import UniformTypeIdentifiers

/// Frozen compatible fields consume the real persisted display owner. File
/// selection, font results and removal confirmation retain their separate hosts.
struct ReaderReadingPreferencesPanel: View {
    @ObservedObject var preferences: ReaderPreferences
    @ObservedObject var fontLibrary: ReaderFontLibrary
    var supportsPageTransitions = true
    var supportsBottomAlignment = true
    var supportsCutoutExpansion = false
    @State private var importingFont = false
    @State private var fontEditMode: EditMode = .inactive
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @Environment(\.colorScheme) private var scheme
    private var palette: ReaderPalette { ReaderPalette(scheme) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            appearance
            fontSection
            section("排版") {
                metric("字号", value: $preferences.fontSize, range: 12...40, step: 1, digits: 0)
                    .accessibilityIdentifier("reading-font-size")
                metric("行距", value: $preferences.lineHeight, range: 1.2...2.8, step: 0.05, digits: 2)
                metric("段距", value: $preferences.paragraphSpacing, range: 0...32, step: 1, digits: 0)
                metric("字距", value: $preferences.letterSpacing, range: -2...4, step: 0.2, digits: 1)
                Picker("首行缩进", selection: $preferences.firstLineIndentEm) {
                    Text("无").tag(0.0); Text("一字").tag(1.0); Text("两字").tag(2.0)
                }.pickerStyle(.menu)
                Picker("对齐", selection: $preferences.textAlignment) {
                    Text("左对齐").tag(ReaderTextAlignment.left)
                    Text("两端对齐").tag(ReaderTextAlignment.justified)
                }.pickerStyle(.menu)
                Toggle("自动页边距", isOn: Binding(
                    get: { preferences.horizontalMargin == 0 },
                    set: { preferences.horizontalMargin = $0 ? 0 : 24 }))
                if preferences.horizontalMargin > 0 {
                    metric("页边距", value: $preferences.horizontalMargin, range: 12...96, step: 1, digits: 0)
                }
            }
            section("阅读方式") {
                Picker("翻页方式", selection: $preferences.pageMode) {
                    ForEach(ReaderPageMode.allCases) { mode in Text(mode.displayName).tag(mode) }
                }.pickerStyle(.menu).accessibilityIdentifier("reading-page-mode")
                if preferences.pageMode == .paged, supportsPageTransitions {
                    Picker("翻页样式", selection: $preferences.pageTransition) {
                        ForEach(ReaderPageTransition.allCases) { value in Text(value.displayName).tag(value) }
                    }.pickerStyle(.menu).accessibilityIdentifier("reading-page-transition")
                } else if preferences.pageMode == .paged {
                    ReaderPageState(title: "此原格式正文暂不支持页动画", detail: "仍可使用原生分页与滚动阅读，已选样式保留。")
                }
                metric("自动翻页间隔", value: $preferences.autoPageSeconds, range: 2...20, step: 1, digits: 0, suffix: " 秒")
                Picker("屏幕超时", selection: $preferences.screenTimeout) {
                    ForEach(ReaderScreenAwakeMode.allCases) { value in Text(value.displayName).tag(value) }
                }.pickerStyle(.menu)
                Picker("阅读方向", selection: $preferences.orientation) {
                    ForEach(ReaderOrientation.allCases) { value in
                        Text(value.displayName).tag(value).disabled(!ReaderOrientationSupport.supports(value))
                    }
                }.pickerStyle(.menu)
                Toggle("减少动态效果", isOn: $preferences.reduceMotion)
                    .accessibilityIdentifier("reading-reduce-motion")
            }
            section("导航状态栏") {
                Toggle("隐藏状态栏", isOn: $preferences.hideStatusBar)
                Toggle("隐藏底部导航指示条", isOn: $preferences.hideNavigationBar)
                Toggle("扩展到刘海（灵动岛）", isOn: $preferences.extendIntoCutout)
                    .disabled(!supportsCutoutExpansion)
                if !supportsCutoutExpansion {
                    ReaderPageState(title: "刘海区域信息布局暂不可用", detail: "当前 iOS 宿主未提供物理刘海两侧的信息轨道，正文继续遵守系统安全区。")
                }
            }
            section("排版与控制") {
                Toggle("底部对齐", isOn: $preferences.alignPageBottom)
                    .disabled(!supportsBottomAlignment)
                if !supportsBottomAlignment {
                    ReaderPageState(title: "当前正文模式不支持底部对齐", detail: "此项需由分页排版引擎按真实片段余高调整，已保存的选择保留。")
                }
                Toggle("长按选择文本", isOn: $preferences.longPressSelectText)
                ReaderPageState(title: "音量键翻页暂不可用", detail: "当前 iOS 公共接口不提供可用于阅读翻页的硬件音量键事件。")
                ReaderPageState(title: "息屏终止朗读", detail: "将在系统朗读功能接入后提供。")
            }
        }
        .font(ReaderTypography.font(.body)).foregroundStyle(palette.readInk).tint(palette.readPrimary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .environment(\.editMode, $fontEditMode)
        .fileImporter(isPresented: $importingFont,
            allowedContentTypes: [UTType(filenameExtension: "ttf") ?? .data, UTType(filenameExtension: "otf") ?? .data],
            allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls): Task { await fontLibrary.importFonts(urls) }
                case .failure(let error):
                    if let cocoa = error as? CocoaError, cocoa.code == .userCancelled { return }
                    fontLibrary.reportFailure("字体文件读取失败，请重新选择")
                }
            }
        .readerConfirmation(confirmation)
        .onAppear { fontLibrary.setPresentationActive(true) }
        .onDisappear { fontLibrary.setPresentationActive(false) }
    }

    private var appearance: some View {
        section("阅读纸色") {
            Toggle("主题跟随系统", isOn: $preferences.followSystem)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 62), spacing: 8)], spacing: 8) {
                ForEach(ReaderTheme.allCases) { theme in
                    Button { preferences.theme = theme } label: {
                        Text(theme.displayName).font(ReaderTypography.font(.caption))
                            .foregroundStyle(ReaderPaperPalette(theme: theme).ink)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .background(ReaderPaperPalette(theme: theme).paper, in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(
                                theme == preferences.theme ? palette.readPrimary : palette.border,
                                lineWidth: theme == preferences.theme ? 2 : 1))
                    }.buttonStyle(ReaderPressFeedback())
                        .accessibilityAddTraits(theme == preferences.theme ? .isSelected : [])
                }
            }
            Button("将当前纸色设为\(preferences.theme.isDark ? "夜间" : "日间")默认") { preferences.setDefaultTheme() }
                .frame(minHeight: 44)
            Text("日间默认：\(preferences.dayTheme.displayName)　夜间默认：\(preferences.nightTheme.displayName)")
                .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
        }
    }

    private var fontSection: some View {
        section("字体") {
            Picker("正文字体", selection: Binding(
                get: { fontLibrary.selectedChoiceID(named: preferences.fontPostScriptName, preferred: preferences.fontSlotID) },
                set: { id in
                    guard let choice = fontLibrary.selectableChoices.first(where: { $0.id == id && $0.available }) else { return }
                    preferences.fontPostScriptName = choice.postScriptName; preferences.fontSlotID = choice.id
                })) {
                ForEach(fontLibrary.selectableChoices) { choice in
                    Text(choice.displayName + (choice.available ? "" : "（不可用）"))
                        .tag(choice.id).disabled(!choice.available)
                }
                if fontLibrary.selectedChoiceID(named: preferences.fontPostScriptName, preferred: preferences.fontSlotID) == "retained-selection" {
                    Text("原选字体（选择已保留）").tag("retained-selection")
                }
            }.pickerStyle(.menu)
            if let font = fontLibrary.resolvedFont(named: preferences.fontPostScriptName, size: CGFloat(preferences.fontSize)) {
                Text("天地玄黄，宇宙洪荒。Reader 123")
                    .font(Font(font as CTFont)).foregroundStyle(ReaderPaperPalette(theme: preferences.theme).ink)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
                    .background(ReaderPaperPalette(theme: preferences.theme).paper, in: RoundedRectangle(cornerRadius: 8))
            } else {
                ReaderPageState(title: "已选字体暂不可用", detail: "字体缺失或来源无法核实，原选择已保留。可重新导入字体或选择其他字体。",
                    actionTitle: "重新读取", action: fontLibrary.reload)
            }
            HStack {
                Button("导入 TTF / OTF 字体") { importingFont = true }
                    .frame(minHeight: 44).accessibilityIdentifier("import-font")
                    .disabled(!fontLibrary.canModify)
                Spacer(minLength: 0)
                EditButton().disabled(!fontLibrary.canModify)
            }
            if fontLibrary.busy {
                HStack(spacing: 8) { ProgressView(); Text("正在导入字体") }.font(ReaderTypography.font(.caption))
            }
            if let failure = fontLibrary.loadFailure {
                ReaderPageState(title: failure, actionTitle: "重试", action: fontLibrary.reload)
            }
            if !fontLibrary.libraryRows.isEmpty {
                List {
                    ForEach(fontLibrary.libraryRows) { choice in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 3) {
                                if choice.isImport {
                                    Button("导入 TTF / OTF 字体") { importingFont = true }.disabled(!fontLibrary.canModify)
                                } else { Text(choice.displayName).font(ReaderTypography.font(.caption)) }
                                if !choice.available {
                                    Text("字体缺失或来源无法核实").font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted)
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                            if let font = fontLibrary.userFont(forChoiceID: choice.id) {
                            ReaderIconAction(icon: .close, label: "移除字体\(font.displayName)") {
                                confirmation.confirm("移除字体", message: "移除“\(font.displayName)”，导入目录的原件保留。",
                                    actionTitle: "移除", destructive: true) {
                                    guard preferences.fontPostScriptName != font.postScriptName else {
                                        fontLibrary.reportFailure("请先切换到其他字体"); return
                                    }
                                    _ = fontLibrary.remove(font)
                                }
                            }.disabled(fontLibrary.busy || preferences.fontPostScriptName == font.postScriptName)
                            }
                        }.listRowBackground(palette.readElevated)
                    }.onMove(perform: fontLibrary.moveChoices).moveDisabled(!fontLibrary.canModify)
                }.listStyle(.plain).scrollContentBackground(.hidden)
                    .frame(height: min(360, CGFloat(fontLibrary.libraryRows.count) * 60 + 12))
            }
            if let text = fontLibrary.message ?? fontLibrary.failure {
                ReaderTransientFeedback(message: text).allowsHitTesting(false)
            }
        }
    }

    private func metric(_ label: String, value: Binding<Double>, range: ClosedRange<Double>,
                        step: Double, digits: Int, suffix: String = "") -> some View {
        Stepper(value: value, in: range, step: step) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Text(String(format: "%.*f", digits, value.wrappedValue) + suffix)
                    .font(ReaderTypography.font(.caption)).foregroundStyle(palette.muted).monospacedDigit()
            }
        }.frame(minHeight: 44)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(ReaderTypography.font(.controlHeader))
            content()
        }.padding(12).frame(maxWidth: .infinity, alignment: .leading)
            .background(palette.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(palette.app("TOK_LINE_STRONG"), lineWidth: 1))
    }
}
