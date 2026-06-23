import SwiftUI
import UniformTypeIdentifiers
import ReaderCoreModels
import ReaderShellValidation

public enum FileImportState: Equatable {
    case idle
    case selecting
    case importing(name: String)
    case imported(summary: CoreLocalBookImportSummary)
    case failed(message: String)
}

@MainActor
public final class FileImportViewModel: ObservableObject {
    @Published public var importState: FileImportState = .idle
    @Published public var selectedURL: URL?
    private let importer: any CoreLocalBookImporting

    private let supportedTypes: [UTType] = [
        .plainText,
        .epub,
        .pdf,
        .zip,
        UTType(filenameExtension: "txt") ?? .plainText,
        UTType(filenameExtension: "html") ?? .html,
        UTType(filenameExtension: "htm") ?? .html,
        UTType(filenameExtension: "mobi") ?? .data,
        UTType(filenameExtension: "azw") ?? .data,
        UTType(filenameExtension: "azw3") ?? .data,
        UTType(filenameExtension: "umd") ?? .data,
        UTType(filenameExtension: "tar") ?? .data,
        UTType(filenameExtension: "cbz") ?? .zip
    ].compactMap { $0 }

    public init(importer: any CoreLocalBookImporting = CoreLocalBookImportService()) {
        self.importer = importer
    }

    public var supportedContentTypes: [UTType] { supportedTypes }

    public func handleSelectedFile(_ url: URL) async {
        selectedURL = url
        let fileName = url.lastPathComponent

        guard url.startAccessingSecurityScopedResource() else {
            importState = .failed(message: "Cannot access file. Permission denied.")
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        importState = .importing(name: fileName)

        do {
            let summary = try await importer.importBook(at: url)
            importState = .imported(summary: summary)
        } catch {
            importState = .failed(message: "Failed to read file: \(error.localizedDescription)")
        }
    }

    public func reset() {
        importState = .idle
        selectedURL = nil
    }
}
