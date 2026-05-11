import SwiftUI
import ReaderAppSupport

public struct SettingsView: View {
    @StateObject private var viewModel = SettingsViewModel()
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    displaySettingsSection
                    cacheSection
                    aboutSection
                    stateIndicator
                }
                .padding()
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var displaySettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Display")
                .font(.headline)

            fontSizeRow
            lineSpacingRow
            backgroundModeRow

            Button("Reset to Defaults") {
                viewModel.resetToDefaults()
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var fontSizeRow: some View {
        HStack(spacing: 16) {
            Text("Font Size")
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)

            Button(action: { viewModel.decreaseFontSize() }) {
                Image(systemName: "textformat.size.smaller")
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            Text("\(viewModel.displaySettings.fontSize)")
                .font(.title3.weight(.semibold))
                .frame(minWidth: 40)

            Button(action: { viewModel.increaseFontSize() }) {
                Image(systemName: "textformat.size.larger")
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var lineSpacingRow: some View {
        HStack(spacing: 16) {
            Text("Line Spacing")
                .font(.subheadline)
                .frame(width: 80, alignment: .leading)

            Button(action: { viewModel.decreaseLineSpacing() }) {
                Image(systemName: "minus")
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }

            Text(String(format: "%.0f", viewModel.displaySettings.lineSpacing))
                .font(.title3.weight(.semibold))
                .frame(minWidth: 40)

            Button(action: { viewModel.increaseLineSpacing() }) {
                Image(systemName: "plus")
                    .frame(width: 36, height: 36)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var backgroundModeRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Background")
                .font(.subheadline)

            HStack(spacing: 12) {
                ForEach(ReaderBackgroundMode.allCases, id: \.self) { mode in
                    Button(action: {
                        viewModel.displaySettings.backgroundMode = mode
                    }) {
                        VStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: mode.backgroundColor))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(viewModel.displaySettings.backgroundMode == mode ? Color.blue : Color.clear, lineWidth: 2)
                                )

                            Text(mode.rawValue.capitalized)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var cacheSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Storage")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Cache Size")
                        .font(.subheadline)
                    Text(viewModel.cacheSizeDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Clear Cache") {
                    viewModel.clearCache()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.headline)

            HStack {
                Text("Version")
                    .font(.subheadline)
                Spacer()
                Text(viewModel.appVersion)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Reader-for-iOS")
                    .font(.subheadline)
                Spacer()
                Text("Compatible with Legado book sources")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    @ViewBuilder
    private var stateIndicator: some View {
        switch viewModel.state {
        case .idle:
            EmptyView()
        case .saving:
            HStack {
                ProgressView()
                    .controlSize(.small)
                Text("Saving...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.green)
        case .failed(let message):
            Label(message, systemImage: "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(.red)
        }
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
