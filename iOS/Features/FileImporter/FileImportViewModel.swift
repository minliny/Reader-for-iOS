import SwiftUI
import UniformTypeIdentifiers
import ReaderCoreModels

public enum FileImportState: Equatable {
    case idle
    case selecting
    case importing(name: String)
    case imported(book: LocalBook)
    case failed(message: String)
}

@MainActor
public final class FileImportViewModel: ObservableObject {
    @Published public var importState: FileImportState = .idle
    @Published public var selectedURL: URL?

    private let supportedTypes: [UTType] = [
        .plainText,
        .epub,
        UTType(filenameExtension: "txt") ?? .plainText
    ].compactMap { $0 }

    public init() {}

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
            let resourceValues = try url.resourceValues(forKeys: [.fileSizeKey])
            let fileSize = resourceValues.fileSize.flatMap(Int64.init)
            let fileExt = url.pathExtension.lowercased()
            let format: LocalBookFormat = {
                switch fileExt {
                case "epub": return .epub
                case "txt":  return .txt
                case "html": return .html
                case "pdf":  return .pdf
                default:     return .unknown
                }
            }()

            let book = LocalBook(
                title: fileName,
                filePath: url.path,
                fileFormat: format,
                fileSize: fileSize,
                encoding: format == .txt ? "utf-8" : nil
            )

            importState = .imported(book: book)
        } catch {
            importState = .failed(message: "Failed to read file: \(error.localizedDescription)")
        }
    }

    public func reset() {
        importState = .idle
        selectedURL = nil
    }
}
