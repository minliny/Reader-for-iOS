import ReaderDesign
import SwiftUI

struct AppearanceControls: View {
    private enum Tab: String, CaseIterable { case typography = "排版"; case paper = "纸底" }
    let preferences: ReadingPreferences
    let onAction: (ReadingControlAction) -> Void
    @State private var tab: Tab = .typography

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("阅读版式", selection: $tab) {
                ForEach(Tab.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            switch tab {
            case .typography: typography
            case .paper: PaperControls(selected: preferences.paperId) { onAction(.paper($0)) }
            }
        }
    }

    private var typography: some View {
        VStack(alignment: .leading, spacing: 7) {
            stepper("字号", value: preferences.fontSize.formatted(.number.precision(.fractionLength(0))),
                    decrement: { onAction(.size(-1)) }, increment: { onAction(.size(1)) })
            stepper("行距", value: preferences.lineSpacing.formatted(.number.precision(.fractionLength(1))),
                    decrement: { onAction(.spacing(-0.1)) }, increment: { onAction(.spacing(0.1)) })
            stepper("字距", value: preferences.letterSpacing.formatted(.number.precision(.fractionLength(1))),
                    decrement: { onAction(.tracking(-0.25)) }, increment: { onAction(.tracking(0.25)) })
            HStack {
                Text("翻页").readerTypography(ReaderDesignMetrics.rowLabel)
                Spacer()
                ForEach(ReadingMode.allCases, id: \.self) { mode in
                    Button(mode.label) { onAction(.mode(mode)) }
                        .buttonStyle(.bordered)
                        .accessibilityAddTraits(preferences.mode == mode ? .isSelected : [])
                }
            }
        }
    }

    private func stepper(_ label: String, value: String, decrement: @escaping () -> Void,
                         increment: @escaping () -> Void) -> some View {
        HStack(spacing: 15) {
            Text(label).readerTypography(ReaderDesignMetrics.rowLabel)
            Spacer()
            Button("减小\(label)", systemImage: "minus", action: decrement)
                .labelStyle(.iconOnly).frame(width: 42, height: 30)
            Text(value).monospacedDigit().frame(minWidth: 30)
            Button("增大\(label)", systemImage: "plus", action: increment)
                .labelStyle(.iconOnly).frame(width: 42, height: 30)
        }
    }
}
