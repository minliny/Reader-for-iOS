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
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text("Font Size")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 16) {
                    Button(action: {
                        if displaySettings.fontSize > 12 {
                            displaySettings.fontSize -= 2
                        }
                    }) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Text("\(displaySettings.fontSize)")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(width: 60)

                    Button(action: {
                        if displaySettings.fontSize < 32 {
                            displaySettings.fontSize += 2
                        }
                    }) {
                        Image(systemName: "textformat.size.larger")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            VStack(spacing: 12) {
                Text("Font Family")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Picker("Font", selection: $displaySettings.fontFamily) {
                    ForEach(ReaderSettingsPanel.availableFonts, id: \.self) { font in
                        Text(font).tag(font)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(spacing: 12) {
                Text("Line Spacing")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 16) {
                    Button(action: {
                        if displaySettings.lineSpacing > 2 {
                            displaySettings.lineSpacing -= 2
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Text(String(format: "%.0f", displaySettings.lineSpacing))
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(width: 60)

                    Button(action: {
                        if displaySettings.lineSpacing < 24 {
                            displaySettings.lineSpacing += 2
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            VStack(spacing: 12) {
                Text("Paragraph Spacing")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 16) {
                    Button(action: {
                        if displaySettings.paragraphSpacing > 2 {
                            displaySettings.paragraphSpacing -= 2
                        }
                    }) {
                        Image(systemName: "minus")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Text(String(format: "%.0f", displaySettings.paragraphSpacing))
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(width: 60)

                    Button(action: {
                        if displaySettings.paragraphSpacing < 48 {
                            displaySettings.paragraphSpacing += 2
                        }
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            VStack(spacing: 12) {
                Text("Background")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    ForEach(ReaderBackgroundMode.allCases, id: \.self) { mode in
                        Button(action: {
                            displaySettings.backgroundMode = mode
                        }) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: mode.backgroundColor))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(displaySettings.backgroundMode == mode ? Color.blue : Color.clear, lineWidth: 2)
                                    )

                                Text(mode.rawValue.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            VStack(spacing: 12) {
                Text("Page Turn")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Picker("Mode", selection: $displaySettings.pageTurnMode) {
                    ForEach(PageTurnMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.capitalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                if displaySettings.pageTurnMode == .paginated {
                    Toggle("Tap Zones", isOn: $displaySettings.tapZoneEnabled)
                        .font(.subheadline)
                        .padding(.top, 4)

                    Toggle("Volume Key Page Turn", isOn: $displaySettings.volumeKeyPageTurnEnabled)
                        .font(.subheadline)

                    Toggle("Dual Page (Landscape)", isOn: $displaySettings.dualPageEnabled)
                        .font(.subheadline)
                }
            }

            VStack(spacing: 12) {
                Toggle("Brightness Override", isOn: $displaySettings.brightnessOverrideEnabled)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                if displaySettings.brightnessOverrideEnabled {
                    HStack(spacing: 12) {
                        Image(systemName: "sun.min")
                            .foregroundStyle(.secondary)

                        Slider(value: $displaySettings.brightnessLevel, in: 0.1...1.0, step: 0.05)

                        Image(systemName: "sun.max")
                            .foregroundStyle(.secondary)
                    }

                    Text(String(format: "%.0f%%", displaySettings.brightnessLevel * 100))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
    }

    public static let availableFonts: [String] = [
        "SF Pro Display",
        "SF Pro Text",
        "Georgia",
        "Palatino",
        "Times New Roman",
        "Avenir",
        "Helvetica Neue"
    ]
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