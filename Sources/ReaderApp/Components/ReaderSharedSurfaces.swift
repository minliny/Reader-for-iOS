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
    var title: String = "保存待确认"
    var actionTitle: String = "重试"
    let retry: () -> Void
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(ReaderTypography.font(.caption)).foregroundStyle(ReaderPalette(scheme).muted)
                Text(message).font(ReaderTypography.font(.controlHeader)).foregroundStyle(ReaderPalette(scheme).ink)
            }
            Spacer(minLength: 0)
            Button(actionTitle, action: retry).font(ReaderTypography.font(.action)).disabled(busy)
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
    var selectedFiles: (([URL]) -> Void)? = nil
    static var supportedBookTypes: [UTType] {
        ["txt", "epub", "mobi", "azw", "azw3", "kf8"].compactMap { UTType(filenameExtension: $0) }
    }
    var contentTypes: [UTType] = ReaderDocumentPicker.supportedBookTypes
    var allowsMultipleSelection = false
    func makeCoordinator() -> Coordinator { Coordinator(selected: selected, cancelled: cancelled, selectedFiles: selectedFiles) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: false)
        controller.allowsMultipleSelection = allowsMultipleSelection
        controller.directoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ controller: UIDocumentPickerViewController, context: Context) {}
    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let log = Logger(subsystem: "io.reader.minliny", category: "FileSelection")
        let selected: (URL) -> Void
        let cancelled: () -> Void
        let selectedFiles: (([URL]) -> Void)?
        init(selected: @escaping (URL) -> Void, cancelled: @escaping () -> Void, selectedFiles: (([URL]) -> Void)?) {
            self.selected = selected; self.cancelled = cancelled; self.selectedFiles = selectedFiles
        }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            log.debug("Native picker selected \(urls.count) item(s)")
            if urls.isEmpty { cancelled() }
            else if let selectedFiles { selectedFiles(urls) }
            else if let url = urls.first { selected(url) }
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
    var stopRemaining: (() -> Void)? = nil
    var feedback: String? = nil
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("本地导入").font(ReaderTypography.font(.appTitle))
                Spacer()
                ReaderIconAction(icon: .close, label: "关闭导入结果", action: close)
            }
            // The import owner keeps its current operation. A rejected new
            // external input is short feedback, never a result of that import.
            if let feedback { ReaderTransientFeedback(message: feedback).allowsHitTesting(false) }
            Text(operation.filename).font(ReaderTypography.font(.controlHeader)).lineLimit(2)
            HStack(spacing: 12) {
                if operation.phase == .importing { ProgressView().tint(ReaderPalette(scheme).green) }
                Text(operation.message).font(ReaderTypography.font(.caption))
            }.accessibilityIdentifier("import-status")
            if !operation.items.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(operation.items) { item in
                            HStack(spacing: 10) {
                                if item.phase == .importing { ProgressView() }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.filename).font(ReaderTypography.font(.caption)).lineLimit(2)
                                    Text(item.message).font(ReaderTypography.font(.caption))
                                        .foregroundStyle(ReaderPalette(scheme).muted)
                                }
                                Spacer(minLength: 0)
                            }.accessibilityElement(children: .combine)
                        }
                    }
                }.frame(maxHeight: 300)
            }
            if operation.phase == .importing, operation.items.count > 1, let stopRemaining {
                Button("停止后续文件", action: stopRemaining).buttonStyle(ReaderPressFeedback())
                    .frame(minHeight: 44).accessibilityIdentifier("stop-remaining-imports")
            }
            if operation.phase == .unresolved {
                Button("核对原导入操作", action: reconcile).buttonStyle(ReaderPrimaryButtonStyle())
            }
        }.foregroundStyle(ReaderPalette(scheme).ink).padding(20)
            .frame(maxWidth: 420).background(ReaderPalette(scheme).card, in: RoundedRectangle(cornerRadius: 24))
            .padding(24).frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ReaderPalette(scheme).paper)
    }
}
