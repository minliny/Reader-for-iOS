import SwiftUI
import ReaderAppSupport

public struct ReaderSettingsPanel: View {
    @Binding var displaySettings: ReaderDisplaySettings
    let onDismiss: () -> Void

    public init(displaySettings: Binding<ReaderDisplaySettings>, onDismiss: @escaping () -> Void) {
        self._displaySettings = displaySettings
        self.onDismiss = onDismiss
    }

    public var body: some View {
        DemoPaperScreen {
            ReaderCard {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                    Text("外观")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    CompactIntStepper(title: "字号", value: $displaySettings.fontSize, range: 12...32, step: 2)
                    CompactDoubleStepper(title: "行距", value: $displaySettings.lineSpacing, range: 2...24, step: 2)
                    CompactDoubleStepper(title: "段距", value: $displaySettings.paragraphSpacing, range: 2...48, step: 2)
                    FontMenu(selection: $displaySettings.fontFamily)
                    PaletteRow(selection: $displaySettings.backgroundMode)
                }
            }

            ReaderCard {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                    Text("翻页")
                        .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                        .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                    PageTurnModeSegment(selection: $displaySettings.pageTurnMode)
                    DemoToggleRow(
                        icon: .gesture,
                        title: "Tap Zones",
                        subtitle: "点击屏幕左右热区翻页",
                        isOn: $displaySettings.tapZoneEnabled
                    )
                    DemoToggleRow(
                        icon: .volume,
                        title: "Volume Key Page Turn",
                        subtitle: "音量键控制上一页/下一页",
                        isOn: $displaySettings.volumeKeyPageTurnEnabled
                    )
                    DemoToggleRow(
                        icon: .columns,
                        title: "Dual Page (Landscape)",
                        subtitle: "横屏时使用双页阅读",
                        isOn: $displaySettings.dualPageEnabled
                    )
                    // 自动翻页：对齐前端 demo `autoPage`
                    DemoToggleRow(
                        icon: .refresh,
                        title: "Auto Page",
                        subtitle: "自动翻页",
                        isOn: $displaySettings.autoPageEnabled
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
                        isOn: $displaySettings.hideStatusBar
                    )
                    // 屏幕常亮：对齐前端 demo `keepScreenOn`
                    DemoToggleRow(
                        icon: .sun,
                        title: "Keep Screen On",
                        subtitle: "屏幕常亮",
                        isOn: $displaySettings.keepScreenOnEnabled
                    )
                    // 页脚进度信息：对齐前端 demo `statusInfo`
                    DemoToggleRow(
                        icon: .progress,
                        title: "Footer Progress Info",
                        subtitle: "页脚进度信息",
                        isOn: $displaySettings.statusInfoEnabled
                    )
                    // 触摸反馈：对齐前端 demo `hapticFeedback`
                    DemoToggleRow(
                        icon: .gesture,
                        title: "Haptic Feedback",
                        subtitle: "触摸反馈",
                        isOn: $displaySettings.hapticFeedbackEnabled
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
                        isOn: $displaySettings.landscapeLockEnabled
                    )
                    // 自动缓存后续章节：对齐前端 demo `cacheNext`
                    DemoToggleRow(
                        icon: .download,
                        title: "Cache Next Chapters",
                        subtitle: "自动缓存后续章节",
                        isOn: $displaySettings.cacheNextEnabled
                    )
                }
            }

            ReaderCard {
                VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                    DemoToggleRow(
                        icon: .sun,
                        title: "Brightness Override",
                        subtitle: "阅读页内独立亮度控制",
                        isOn: $displaySettings.brightnessOverrideEnabled
                    )

                    if displaySettings.brightnessOverrideEnabled {
                        HStack(spacing: 12) {
                            ReaderIcon(.sun, size: 18)
                                .foregroundStyle(ReaderDesignTokens.Color.muted)
                            DemoRangeRail(
                                value: $displaySettings.brightnessLevel,
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
                    MotionEnvironment().withMotionAnimation(AppMotion.Duration.chipSelect) {
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
    @Binding var selection: ReaderBackgroundMode

    var body: some View {
        HStack(spacing: 10) {
            Text("背景")
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(ReaderBackgroundMode.allCases, id: \.self) { mode in
                Button {
                    selection = mode
                } label: {
                    RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs)
                        .fill(Color(hex: mode.backgroundColor))
                        .frame(
                            width: selection == mode ? ReaderDesignTokens.readerSettingsLargeSwatchWidth : ReaderDesignTokens.readerSettingsSwatchSize,
                            height: ReaderDesignTokens.readerSettingsSwatchSize
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xs)
                                .stroke(selection == mode ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
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
