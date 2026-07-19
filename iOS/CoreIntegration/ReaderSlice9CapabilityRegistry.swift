import Foundation

/// Machine-verifiable Slice 9 admission state for the iOS repository.
///
/// This registry does not upgrade source tests into simulator/device/release
/// evidence. It answers one narrower question: which production paths may be
/// entered with today's frozen Core/Host contracts, and which must fail closed.
public enum ReaderSlice9CapabilityID: String, Codable, CaseIterable, Sendable {
    case localTXT = "local.txt"
    case localEPUB = "local.epub"
    case localPDFText = "local.pdf.text"
    case localPDFInteractive = "local.pdf.interactive"
    case localMOBI = "local.mobi"
    case localUMD = "local.umd"
    case mangaReader = "reader.manga"
    case contentAudioReader = "reader.audio.content"
    case mediaDownloadForeground = "download.media.foreground"
    case downloadQueue = "download.queue"
    case storagePath = "storage.path"
    case storageManagement = "storage.management"
}

public enum ReaderSlice9CapabilityState: String, Codable, Sendable {
    /// The named, narrowly scoped path has an executable implementation.
    case executable
    /// A useful subset is executable, while explicit parity gaps remain.
    case partial
    /// Entry is rejected until the listed contract/blocker is resolved.
    case blocked
}

public struct ReaderSlice9Capability: Codable, Equatable, Sendable {
    public let id: ReaderSlice9CapabilityID
    public let state: ReaderSlice9CapabilityState
    public let implementedContracts: [String]
    public let implementationFiles: [String]
    public let automatedTests: [String]
    public let blockerCodes: [String]
    public let boundaryNote: String

    public init(
        id: ReaderSlice9CapabilityID,
        state: ReaderSlice9CapabilityState,
        implementedContracts: [String],
        implementationFiles: [String],
        automatedTests: [String],
        blockerCodes: [String] = [],
        boundaryNote: String
    ) {
        self.id = id
        self.state = state
        self.implementedContracts = implementedContracts
        self.implementationFiles = implementationFiles
        self.automatedTests = automatedTests
        self.blockerCodes = blockerCodes
        self.boundaryNote = boundaryNote
    }
}

public enum ReaderSlice9CapabilityRegistry {
    public static let records: [ReaderSlice9Capability] = [
        .init(
            id: .localTXT,
            state: .executable,
            implementedContracts: ["local_book.import", "local_book.chapter.content"],
            implementationFiles: ["RustCoreLocalBookImportService.swift", "FileImportViewModel.swift"],
            automatedTests: ["RustCoreLocalBookImportServiceTests", "LocalBookCoreImportBridgeTests"],
            boundaryNote: "Core materializes chapters; iOS copies exact Core results into its renderer cache."
        ),
        .init(
            id: .localEPUB,
            state: .partial,
            implementedContracts: ["local_book.import", "local_book.chapter.content"],
            implementationFiles: ["RustCoreLocalBookImportService.swift"],
            automatedTests: ["RustCoreLocalBookImportServiceTests"],
            blockerCodes: ["SLICE9_EPUB_RICH_RESOURCE_RENDERER_MISSING"],
            boundaryNote: "Extracted chapter text is readable; original XHTML layout, fonts, images and fixed layout are not claimed."
        ),
        .init(
            id: .localPDFText,
            state: .partial,
            implementedContracts: ["local_book.import", "local_book.chapter.content"],
            implementationFiles: ["RustCoreLocalBookImportService.swift"],
            automatedTests: ["RustCoreLocalBookImportServiceTests"],
            blockerCodes: ["SLICE9_PDF_OCR_UNAVAILABLE"],
            boundaryNote: "Extractable page text is readable; image-only pages fail closed."
        ),
        .init(
            id: .localPDFInteractive,
            state: .blocked,
            implementedContracts: [],
            implementationFiles: [],
            automatedTests: ["ReaderSlice9CapabilityRegistryTests"],
            blockerCodes: ["SLICE9_PDF_PAGE_RENDER_CONTRACT_MISSING", "SLICE9_SECURITY_BOOKMARK_CONTRACT_MISSING"],
            boundaryNote: "No frozen Core-to-PDFKit document/page locator or long-lived authorized-file bookmark contract."
        ),
        .init(
            id: .localMOBI,
            state: .partial,
            implementedContracts: ["local_book.import", "local_book.chapter.content"],
            implementationFiles: ["RustCoreLocalBookImportService.swift"],
            automatedTests: ["RustCoreLocalBookImportServiceTests"],
            blockerCodes: ["SLICE9_MOBI_HUFF_CDIC_KF8_DRM_UNSUPPORTED"],
            boundaryNote: "Clean-room PalmDOC/MOBI text is readable; unsupported proprietary sections fail closed in Core."
        ),
        .init(
            id: .localUMD,
            state: .partial,
            implementedContracts: ["local_book.import", "local_book.chapter.content"],
            implementationFiles: ["RustCoreLocalBookImportService.swift"],
            automatedTests: ["RustCoreLocalBookImportServiceTests"],
            blockerCodes: ["SLICE9_UMD_ENCRYPTED_CONTENT_UNSUPPORTED"],
            boundaryNote: "Basic clean-room UMD chapter text is readable; encrypted/DRM variants are not claimed."
        ),
        .init(
            id: .mangaReader,
            state: .blocked,
            implementedContracts: ["manga.pages.extract", "media.download"],
            implementationFiles: ["MediaDownloadHandler.swift", "URLSessionMediaDownloadExecutor.swift"],
            automatedTests: ["HostMediaDownloadProofTests", "URLSessionMediaDownloadExecutorProofTests", "ReaderSlice9CapabilityRegistryTests"],
            blockerCodes: ["SLICE9_MANGA_PAGE_LOCATOR_UI_CONTRACT_MISSING", "SLICE9_MANGA_PROGRESS_CONTRACT_MISSING"],
            boundaryNote: "Core extraction and Host byte download do not define a native image-sequence session, locator or progress model."
        ),
        .init(
            id: .contentAudioReader,
            state: .blocked,
            implementedContracts: [],
            implementationFiles: [],
            automatedTests: ["ReaderSlice9CapabilityRegistryTests"],
            blockerCodes: ["SLICE9_CONTENT_AUDIO_HOST_CONTRACT_MISSING", "SLICE9_AUDIO_QUEUE_LOCATOR_CONTRACT_MISSING"],
            boundaryNote: "System TTS is a different capability and must not be used as audiobook/content-audio proof."
        ),
        .init(
            id: .mediaDownloadForeground,
            state: .partial,
            implementedContracts: ["media.download"],
            implementationFiles: ["MediaDownloadHandler.swift", "URLSessionMediaDownloadExecutor.swift", "HostRequestRouter.swift"],
            automatedTests: ["HostMediaDownloadProofTests", "URLSessionMediaDownloadExecutorProofTests"],
            blockerCodes: ["SLICE9_BACKGROUND_DOWNLOAD_NOT_IMPLEMENTED", "SLICE9_DOWNLOAD_RESUME_DATA_NOT_PERSISTED"],
            boundaryNote: "Foreground GET/HEAD/range/ETag/SHA-256/temp-file execution is implemented; background and restart recovery are not."
        ),
        .init(
            id: .downloadQueue,
            state: .blocked,
            implementedContracts: ["media.download"],
            implementationFiles: ["URLSessionMediaDownloadExecutor.swift"],
            automatedTests: ["ReaderSlice9CapabilityRegistryTests"],
            blockerCodes: ["SLICE9_DOWNLOAD_QUEUE_TRANSACTION_CONTRACT_MISSING", "SLICE9_DOWNLOAD_RESTART_RECOVERY_MISSING"],
            boundaryNote: "A single Host transfer is not an app download queue or durable transaction."
        ),
        .init(
            id: .storagePath,
            state: .executable,
            implementedContracts: ["storage.path"],
            implementationFiles: ["HostFileCapability.swift", "HostAdapter.swift"],
            automatedTests: ["HostAdapterCapabilityDispatchProofTests"],
            boundaryNote: "Host resolves cache/files/external paths inside the platform boundary."
        ),
        .init(
            id: .storageManagement,
            state: .blocked,
            implementedContracts: ["storage.path"],
            implementationFiles: ["HostFileCapability.swift"],
            automatedTests: ["ReaderSlice9CapabilityRegistryTests"],
            blockerCodes: ["SLICE9_STORAGE_USAGE_QUOTA_CONTRACT_MISSING", "SLICE9_STORAGE_CLEANUP_TRANSACTION_CONTRACT_MISSING"],
            boundaryNote: "Path resolution alone does not authorize UI-owned deletion, quota reporting or Core cache cleanup."
        )
    ]

    public static func capability(_ id: ReaderSlice9CapabilityID) -> ReaderSlice9Capability {
        guard let record = records.first(where: { $0.id == id }) else {
            preconditionFailure("Slice 9 registry missing \(id.rawValue)")
        }
        return record
    }

    public static func validate() -> [String] {
        var failures: [String] = []
        let ids = records.map(\.id)
        if Set(ids).count != ids.count {
            failures.append("duplicate capability id")
        }
        let missing = Set(ReaderSlice9CapabilityID.allCases).subtracting(ids)
        if !missing.isEmpty {
            failures.append("missing ids: \(missing.map(\.rawValue).sorted().joined(separator: ","))")
        }
        for record in records {
            if record.state == .blocked && record.blockerCodes.isEmpty {
                failures.append("\(record.id.rawValue) is blocked without a blocker code")
            }
            if record.state == .executable && !record.blockerCodes.isEmpty {
                failures.append("\(record.id.rawValue) is executable but has blocker codes")
            }
            if record.automatedTests.isEmpty {
                failures.append("\(record.id.rawValue) has no automated admission test")
            }
        }
        return failures
    }
}
