import SwiftUI

public struct ReaderSettingsPanel: View {
    @Binding var fontSize: Int
    @Binding var backgroundMode: BackgroundMode
    let onDismiss: () -> Void

    public init(fontSize: Binding<Int>, backgroundMode: Binding<BackgroundMode>, onDismiss: @escaping () -> Void) {
        self._fontSize = fontSize
        self._backgroundMode = backgroundMode
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
                        if fontSize > 12 {
                            fontSize -= 2
                        }
                    }) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                    }

                    Text("\(fontSize)")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(width: 60)

                    Button(action: {
                        if fontSize < 32 {
                            fontSize += 2
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
                Text("Background")
                    .font(.subheadline)
                    .fontWeight(.semibold)

                HStack(spacing: 12) {
                    ForEach(BackgroundMode.allCases, id: \.self) { mode in
                        Button(action: {
                            backgroundMode = mode
                        }) {
                            VStack(spacing: 4) {
                                Circle()
                                    .fill(Color(hex: mode.backgroundColor))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        Circle()
                                            .stroke(backgroundMode == mode ? Color.blue : Color.clear, lineWidth: 2)
                                    )

                                Text(mode.rawValue.capitalized)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.systemBackground))
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