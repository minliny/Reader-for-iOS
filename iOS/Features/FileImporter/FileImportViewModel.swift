import SwiftUI
import UniformTypeIdentifiers
import ReaderCoreModels
import ReaderShellValidation
#if canImport(ReaderCoreNativeAdapter)
import ReaderCoreNativeAdapter
#endif

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

    public init(importer: (any CoreLocalBookImporting)? = nil) {
        if let importer {
            self.importer = importer
        } else {
            #if canImport(ReaderCoreNativeAdapter)
            if let runtime = RustCoreRuntimeHolder.shared.current {
                self.importer = RustCoreLocalBookImportService(runtime: runtime)
            } else {
                self.importer = CoreLocalBookImportService()
            }
            #else
            self.importer = CoreLocalBookImportService()
            #endif
        }
    }

    public var supportedContentTypes: [UTType] { supportedTypes }

    public func handleSelectedFile(_ url: URL) async {
        selectedURL = url
        let fileName = url.lastPathComponent

        let accessStarted = url.startAccessingSecurityScopedResource()
        guard accessStarted || FileManager.default.isReadableFile(atPath: url.path) else {
            writeHandoffEvidence(fileURL: url, fileSize: nil, accessStarted: false)
            importState = .failed(message: "Cannot access file. Permission denied.")
            return
        }
        defer {
            if accessStarted {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Capture file size for evidence + soft precheck
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey])
        let fileSize = resourceValues?.fileSize.map { Int64($0) }

        // B.4: Write security-scoped handoff evidence (S3 闭环)
        writeHandoffEvidence(fileURL: url, fileSize: fileSize, accessStarted: accessStarted)

        // B.4: 8 MB soft precheck — catch oversized files before importer processing
        let softLimit: Int64 = 8_000_000
        if let fileSize, fileSize > softLimit {
            let formatted = ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
            importState = .failed(message: "文件过大（\(formatted)），当前软上限为 8 MB。请选择更小的文件。")
            return
        }

        importState = .importing(name: fileName)

        do {
            let summary = try await importer.importBook(at: url)
            guard summary.canOpenReader else {
                throw CoreLocalBookImportBridgeError.failedClosed(
                    code: "SLICE9_LOCAL_READER_UNAVAILABLE",
                    message: "格式已识别，但当前 Core/Host 链路没有可打开的章节正文"
                )
            }
            importState = .imported(summary: summary)
        } catch let error as CoreLocalBookImportBridgeError {
            switch error {
            case .unsupported(let diagnostics):
                let detail = diagnostics.isEmpty ? "Core 拒绝了该文件格式" : diagnostics.joined(separator: "\n")
                importState = .failed(message: "不支持的文件格式：\(detail)")
            case .failedClosed(let code, let message):
                importState = .failed(message: "导入未完成（\(code)）：\(message)")
            }
        } catch {
            importState = .failed(message: "Failed to read file: \(error.localizedDescription)")
        }
    }

    // MARK: - Evidence

    private func writeHandoffEvidence(fileURL: URL, fileSize: Int64?, accessStarted: Bool) {
        let bundle = HostRuntimeEvidenceExporter.localBookSecurityScopedHandoffBundle(
            fileURL: fileURL,
            fileSize: fileSize,
            accessStarted: accessStarted
        )
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let evidenceDir = appSupport.appendingPathComponent("ReaderApp/HostRuntimeEvidence", isDirectory: true)
        let evidenceURL = evidenceDir.appendingPathComponent("local_book_security_scoped_handoff_manifest.json")
        do {
            _ = try HostRuntimeEvidenceExporter.write(bundle, to: evidenceURL)
        } catch {
            #if DEBUG
            print("[FileImport] failed to write handoff evidence: \(error.localizedDescription)")
            #endif
        }
    }

    public func reset() {
        importState = .idle
        selectedURL = nil
    }
}
