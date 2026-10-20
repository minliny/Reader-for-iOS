import SwiftUI
import UniformTypeIdentifiers
import OSLog

struct ReaderIconAction: View {
    let icon: ReaderIconName
    let label: String
    var selected = false
    var action: () -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Button(action: action) {
            ReaderIcon(icon).frame(minWidth: 44, minHeight: 44)
                .background(selected ? ReaderPalette(scheme).primarySoft : .clear, in: RoundedRectangle(cornerRadius: 12))
                .contentShape(Rectangle())
        }.buttonStyle(ReaderPressFeedback()).accessibilityLabel(label)
            .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

struct ReaderPressFeedback: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.overlay {
            RoundedRectangle(cornerRadius: 12).fill(ReaderPalette(scheme).accent.opacity(configuration.isPressed ? 0.12 : 0))
                .allowsHitTesting(false)
        }
    }
}

struct ReaderPageState: View {
    let title: String
    var detail: String = ""
    var loading = false
    var actionTitle: String?
    var action: (() -> Void)?
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(spacing: 14) {
            if loading { ProgressView().tint(ReaderPalette(scheme).green) }
            Text(title).font(ReaderTypography.font(.controlHeader)).foregroundStyle(ReaderPalette(scheme).ink)
            if !detail.isEmpty {
                Text(detail).font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle, let action {
                Button(actionTitle, action: action).font(ReaderTypography.font(.action))
                    .buttonStyle(ReaderPrimaryButtonStyle())
            }
        }.padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ReaderPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var scheme
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal, 20).frame(minHeight: 44)
            .foregroundStyle(ReaderPalette(scheme).onPrimary)
            .background(ReaderPalette(scheme).green,
                        in: Capsule())
            .overlay {
                Capsule().fill(ReaderPalette(scheme).accent.opacity(configuration.isPressed ? 0.12 : 0))
                    .allowsHitTesting(false)
            }
    }
}

/// Transient feedback is scoped to the currently visible host by the app owner.
struct ReaderTransientFeedback: View {
    let message: String
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        Text(message).font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).ink)
            .padding(.horizontal, 18).padding(.vertical, 12)
            .background(ReaderPalette(scheme).card, in: Capsule())
            .overlay(Capsule().stroke(ReaderPalette(scheme).border, lineWidth: 1))
            .shadow(color: .black.opacity(0.08), radius: 12, y: 4)
            .accessibilityAddTraits(.updatesFrequently)
    }
}

struct ReaderRecoveryNotice: View {
    let message: String
    let busy: Bool
    let retry: () -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("保存待确认").font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
                Text(message).font(ReaderTypography.font(.controlHeader)).foregroundStyle(ReaderPalette(scheme).ink)
            }
            Spacer(minLength: 0)
            Button("重试", action: retry).font(ReaderTypography.font(.action)).disabled(busy)
                .frame(minWidth: 44, minHeight: 44)
        }.padding(14).background(ReaderPalette(scheme).card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(ReaderPalette(scheme).border, lineWidth: 1))
            .accessibilityElement(children: .contain)
    }
}

/// File selection is a Host action. It never parses a book or owns import completion.
struct ReaderDocumentPicker: UIViewControllerRepresentable {
    var selected: (URL) -> Void
    var cancelled: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(selected: selected, cancelled: cancelled) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.plainText], asCopy: false)
        controller.allowsMultipleSelection = false
        controller.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let log = Logger(subsystem: "io.reader.minliny", category: "FileSelection")
        let selected: (URL) -> Void
        let cancelled: () -> Void
        init(selected: @escaping (URL) -> Void, cancelled: @escaping () -> Void) {
            self.selected = selected; self.cancelled = cancelled
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            log.debug("Native picker selected \(urls.count) item(s)")
            if let url = urls.first { selected(url) } else { cancelled() }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            log.debug("Native picker cancelled")
            cancelled()
        }
    }
}

struct ReaderImportResultView: View {
    let operation: ReaderImportPresentation
    let close: () -> Void
    let reconcile: () -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("本地导入").font(ReaderTypography.font(.appTitle))
                Spacer()
                ReaderIconAction(icon: .close, label: "关闭导入结果", action: close)
            }
            Text(operation.filename).font(ReaderTypography.font(.controlHeader)).lineLimit(2)
            HStack(spacing: 12) {
                if operation.phase == .importing { ProgressView().tint(ReaderPalette(scheme).green) }
                Text(operation.message).font(ReaderTypography.font(.caption))
            }.accessibilityIdentifier("import-status")
            if operation.phase == .unresolved {
                Button("核对原导入操作", action: reconcile).buttonStyle(ReaderPrimaryButtonStyle())
            }
        }.foregroundStyle(ReaderPalette(scheme).ink).padding(20)
            .frame(maxWidth: 420).background(ReaderPalette(scheme).card, in: RoundedRectangle(cornerRadius: 24))
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ReaderPalette(scheme).paper)
    }
}
