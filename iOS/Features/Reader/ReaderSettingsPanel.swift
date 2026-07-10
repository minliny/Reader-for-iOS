import SwiftUI
import ReaderAppSupport

public struct ReaderSettingsPanel: View {
    @Binding var displaySettings: ReaderDisplaySettings
    let onDismiss: () -> Void
    /// P2.3: 设置变更回调——每个控件 onChange 经此回调 dispatch UiEvent，
    /// 调用方（Coordinator/ViewController）接收后转发给 Reducer。
    /// key 对应 ReaderDisplaySettings 字段名（"fontSize"/"lineSpacing"/"tapZoneEnabled" 等）。
    let onSettingsChange: ((String, Any) -> Void)?

    public init(
        displaySettings: Binding<ReaderDisplaySettings>,
        onSettingsChange: ((String, Any) -> Void)? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self._displaySettings = displaySettings
        self.onSettingsChange = onSettingsChange
        self.onDismiss = onDismiss
    }

    /// P2.3: 包装 Binding，在 set 时触发 onSettingsChange 回调，
    /// 使所有子控件（CompactIntStepper / DemoToggleRow / FontMenu 等）
    /// 的写入经回调上抛，而非静默直写 binding。
    private func notifiedBinding<T>(_ binding: Binding<T>, key: String) -> Binding<T> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = newValue
                onSettingsChange?(key, newValue)
            }
        )
    }

    public var body: some View {
        DemoPaperScreen {
            ReaderCard {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                    Text("外观")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    CompactIntStepper(title: "字号", value: notifiedBinding($displaySettings.fontSize, key: "fontSize"), range: 12...32, step: 2)
                    CompactDoubleStepper(title: "行距", value: notifiedBinding($displaySettings.lineSpacing, key: "lineSpacing"), range: 2...24, step: 2)
                    CompactDoubleStepper(title: "段距", value: notifiedBinding($displaySettings.paragraphSpacing, key: "paragraphSpacing"), range: 2...48, step: 2)
                    FontMenu(selection: notifiedBinding($displaySettings.fontFamily, key: "fontFamily"))
                    PaletteRow()
                }
            }

            ReaderCard {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                    Text("翻页")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    PageTurnModeSegment(selection: notifiedBinding($displaySettings.pageTurnMode, key: "pageTurnMode"))
                    DemoToggleRow(
                        icon: .gesture,
                        title: "Tap Zones",
                        subtitle: "点击屏幕左右热区翻页",
                        isOn: notifiedBinding($displaySettings.tapZoneEnabled, key: "tapZoneEnabled")
                    )
                    DemoToggleRow(
                        icon: .volume,
                        title: "Volume Key Page Turn",
                        subtitle: "音量键控制上一页/下一页",
                        isOn: notifiedBinding($displaySettings.volumeKeyPageTurnEnabled, key: "volumeKeyPageTurnEnabled")
                    )
                    DemoToggleRow(
                        icon: .columns,
                        title: "Dual Page (Landscape)",
                        subtitle: "横屏时使用双页阅读",
                        isOn: notifiedBinding($displaySettings.dualPageEnabled, key: "dualPageEnabled")
                    )
                    // 自动翻页：对齐前端 demo `autoPage`
                    DemoToggleRow(
                        icon: .refresh,
                        title: "Auto Page",
                        subtitle: "自动翻页",
                        isOn: notifiedBinding($displaySettings.autoPageEnabled, key: "autoPageEnabled")
                    )
                }
            }

            ReaderCard {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                    Text("显示")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    // 隐藏状态栏：沉浸阅读时隐藏顶部系统状态栏
                    DemoToggleRow(
                        icon: .eyeOff,
                        title: "Hide Status Bar",
                        subtitle: "隐藏状态栏",
                        isOn: notifiedBinding($displaySettings.hideStatusBar, key: "hideStatusBar")
                    )
                    // 屏幕常亮：对齐前端 demo `keepScreenOn`
                    DemoToggleRow(
                        icon: .sun,
                        title: "Keep Screen On",
                        subtitle: "屏幕常亮",
                        isOn: notifiedBinding($displaySettings.keepScreenOnEnabled, key: "keepScreenOnEnabled")
                    )
                    // 页脚进度信息：对齐前端 demo `statusInfo`
                    DemoToggleRow(
                        icon: .progress,
                        title: "Footer Progress Info",
                        subtitle: "页脚进度信息",
                        isOn: notifiedBinding($displaySettings.statusInfoEnabled, key: "statusInfoEnabled")
                    )
                    // 触摸反馈：对齐前端 demo `hapticFeedback`
                    DemoToggleRow(
                        icon: .gesture,
                        title: "Haptic Feedback",
                        subtitle: "触摸反馈",
                        isOn: notifiedBinding($displaySettings.hapticFeedbackEnabled, key: "hapticFeedbackEnabled")
                    )
                }
            }

            ReaderCard {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                    Text("其他")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    // 横屏锁定：对齐前端 demo `landscapeLock`
                    DemoToggleRow(
                        icon: .permission,
                        title: "Landscape Lock",
                        subtitle: "横屏锁定",
                        isOn: notifiedBinding($displaySettings.landscapeLockEnabled, key: "landscapeLockEnabled")
                    )
                    // 自动缓存后续章节：对齐前端 demo `cacheNext`
                    DemoToggleRow(
                        icon: .download,
                        title: "Cache Next Chapters",
                        subtitle: "自动缓存后续章节",
                        isOn: notifiedBinding($displaySettings.cacheNextEnabled, key: "cacheNextEnabled")
                    )
                }
            }

            ReaderCard {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                    DemoToggleRow(
                        icon: .sun,
                        title: "Brightness Override",
                        subtitle: "阅读页内独立亮度控制",
                        isOn: notifiedBinding($displaySettings.brightnessOverrideEnabled, key: "brightnessOverrideEnabled")
                    )

                    if displaySettings.brightnessOverrideEnabled {
                        HStack(spacing: 12) {
                            ReaderIcon(.sun, size: 18)
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                            DemoRangeRail(
                                value: notifiedBinding($displaySettings.brightnessLevel, key: "brightnessLevel"),
                                range: 0.1...1.0,
                                step: 0.05,
                                label: "阅读亮度",
                                valueText: String(format: "%.0f%%", displaySettings.brightnessLevel * 100)
                            )
                            Text(String(format: "%.0f%%", displaySettings.brightnessLevel * 100))
                                .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                                .frame(width: 44)
                        }
                    }
                }
            }
        }
    }

    public static let availableFonts: [String] = [
        ReaderTypography.demoSerifPrimaryFamily,
        "STSong",
        "Noto Serif CJK SC",
        "Source Han Serif SC",
        "Palatino",
        "Times New Roman",
        "SF Pro Text",
        "Avenir",
        "Helvetica Neue"
    ]
}

private struct PageTurnModeSegment: View {
    @Binding var selection: PageTurnMode

    var body: some View {
        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
            Text("Mode")
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(PageTurnMode.allCases, id: \.self) { mode in
                PillChip(title(for: mode), isSelected: selection == mode) {
                    // Issue 7：翻页模式分段切换使用 segmentItemSwitch 动效（对照 MotionId.segmentItemSwitch）。
                    MotionEnvironment().withMotionAnimation(AppMotion.Duration.segmentItemSwitch) {
                        selection = mode
                    }
                }
            }
        }
        .frame(minHeight: ReaderDesignTokens.readerSettingsPanelRowHeight)
    }

    private func title(for mode: PageTurnMode) -> String {
        switch mode {
        case .scroll:
            return "滚动"
        case .paginated:
            return "分页"
        }
    }
}

private struct CompactIntStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        compactStepper(title: title, valueText: "\(value)", decrement: {
            value = max(range.lowerBound, value - step)
        }, increment: {
            value = min(range.upperBound, value + step)
        })
    }
}

private struct CompactDoubleStepper: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double

    var body: some View {
        compactStepper(title: title, valueText: String(format: "%.0f", value), decrement: {
            value = max(range.lowerBound, value - step)
        }, increment: {
            value = min(range.upperBound, value + step)
        })
    }
}

private func compactStepper(title: String, valueText: String, decrement: @escaping () -> Void, increment: @escaping () -> Void) -> some View {
    HStack(spacing: ReaderDesignTokens.settingsRowGap) {
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
            .frame(maxWidth: .infinity, alignment: .leading)
        StepperButton(icon: .clear, action: decrement)
        Text(valueText)
            .font(.system(size: ReaderDesignTokens.settingsRowValueFontSize, weight: .black))
            .frame(width: 38)
        StepperButton(icon: .add, action: increment)
    }
    .frame(height: ReaderDesignTokens.readerSettingsPanelRowHeight)
}

private struct StepperButton: View {
    let icon: ReaderAssetIcon
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ReaderIcon(icon, size: 14)
                .frame(width: ReaderDesignTokens.readerSettingsStepperSize, height: ReaderDesignTokens.readerSettingsStepperSize)
                .background(
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.sm)
                        .fill(ReaderDesignTokens.Color.controlBackground)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct FontMenu: View {
    @Binding var selection: String

    var body: some View {
        Menu {
            ForEach(ReaderSettingsPanel.availableFonts, id: \.self) { font in
                Button(font) { selection = font }
            }
        } label: {
            DemoIconRow(icon: .typo, title: "字体", subtitle: selection, detail: "menu")
        }
        .buttonStyle(.plain)
    }
}

private struct PaletteRow: View {
    // Issue 6/7：背景色板由 themeManager 驱动（8 主题 paper/warm/green/blue × day/night），
    // 色板点击使用 segmentItemSwitch 动效（对照 MotionId.segmentItemSwitch）。
    @EnvironmentObject private var themeManager: ReaderThemeManager
    @Environment(\.readerThemePalette) private var palette
    private let motion = MotionEnvironment()

    var body: some View {
        HStack(spacing: 10) {
            Text("背景")
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(ReaderThemeResolver.allOptions, id: \.self) { themeId in
                Button {
                    motion.withMotionAnimation(AppMotion.Duration.segmentItemSwitch) {
                        themeManager.setReaderTheme(themeId)
                    }
                } label: {
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs)
                        .fill(ReaderThemeResolver.swatchColor(themeId: themeId, isNight: palette.isNight))
                        .frame(
                            width: themeManager.readerTheme == themeId ? ReaderDesignTokens.readerSettingsLargeSwatchWidth : ReaderDesignTokens.readerSettingsSwatchSize,
                            height: ReaderDesignTokens.readerSettingsSwatchSize
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs)
                                .stroke(themeManager.readerTheme == themeId ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("背景主题\(ReaderThemeResolver.displayName(themeId))")
            }
        }
        .frame(height: ReaderDesignTokens.readerSettingsPanelRowHeight)
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
