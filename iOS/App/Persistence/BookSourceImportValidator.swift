import Foundation
import ReaderCoreModels

/// M6-B: Local validation result for a BookSource import.
/// Assesses capability readiness without making network requests.
public struct BookSourceValidationResult: Equatable {
    public let sourceId: String?
    public let sourceName: String
    public let baseURL: String?

    /// Per-capability status
    public let searchCapability: CapabilityStatus
    public let detailCapability: CapabilityStatus
    public let tocCapability: CapabilityStatus
    public let contentCapability: CapabilityStatus

    /// Validation warnings (non-fatal)
    public let warnings: [String]

    /// Critical errors that prevent save
    public let errors: [String]

    public var isValid: Bool { errors.isEmpty }

    public init(
        sourceId: String?,
        sourceName: String,
        baseURL: String?,
        searchCapability: CapabilityStatus,
        detailCapability: CapabilityStatus,
        tocCapability: CapabilityStatus,
        contentCapability: CapabilityStatus,
        warnings: [String] = [],
        errors: [String] = []
    ) {
        self.sourceId = sourceId
        self.sourceName = sourceName
        self.baseURL = baseURL
        self.searchCapability = searchCapability
        self.detailCapability = detailCapability
        self.tocCapability = tocCapability
        self.contentCapability = contentCapability
        self.warnings = warnings
        self.errors = errors
    }
}

public enum CapabilityStatus: String, Equatable {
    case ready     /// Rule exists and appears structurally valid
    case missing   /// Rule field absent
    case invalid   /// Rule field present but structurally invalid
}

/// M6-B: Validates a BookSource JSON for capability and structural integrity.
/// Does NOT make network requests.
public struct BookSourceImportValidator {

    public init() {}

    /// Validates a parsed BookSource and returns structured result.
    public func validate(_ source: BookSource) -> BookSourceValidationResult {
        var errors: [String] = []
        var warnings: [String] = []

        // Critical: sourceId / name not empty
        if source.bookSourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append("sourceName is empty")
        }

        // Critical: baseURL / host
        if source.bookSourceUrl == nil || source.bookSourceUrl?.isEmpty == true {
            errors.append("bookSourceUrl is empty")
        } else if let urlStr = source.bookSourceUrl {
            // Basic URL syntax check
            if !urlStr.hasPrefix("http://") && !urlStr.hasPrefix("https://") && !urlStr.hasPrefix("file://") {
                errors.append("bookSourceUrl must start with http://, https://, or file://")
            }
            // Path traversal check — no ../ in URL
            if urlStr.contains("../") {
                errors.append("bookSourceUrl contains path traversal (..)")
            }
        }

        // Search capability
        let searchCap = assessSearchCapability(source)
        if searchCap == .invalid {
            warnings.append("search rule has structural issues")
        }

        // Detail capability
        let detailCap = assessDetailCapability(source)
        if detailCap == .missing {
            warnings.append("detail rule is missing — book detail may not work")
        } else if detailCap == .invalid {
            warnings.append("detail rule has structural issues")
        }

        // TOC capability
        let tocCap = assessTocCapability(source)
        if tocCap == .missing {
            warnings.append("toc rule is missing — chapter list may not work")
        } else if tocCap == .invalid {
            warnings.append("toc rule has structural issues")
        }

        // Content capability
        let contentCap = assessContentCapability(source)
        if contentCap == .missing {
            warnings.append("content rule is missing — reading content may not work")
        } else if contentCap == .invalid {
            warnings.append("content rule has structural issues")
        }

        return BookSourceValidationResult(
            sourceId: source.id,
            sourceName: source.bookSourceName,
            baseURL: source.bookSourceUrl,
            searchCapability: searchCap,
            detailCapability: detailCap,
            tocCapability: tocCap,
            contentCapability: contentCap,
            warnings: warnings,
            errors: errors
        )
    }

    // MARK: - Private

    private func assessSearchCapability(_ source: BookSource) -> CapabilityStatus {
        // Legado: source.searchUrl or ruleSearch
        if source.bookSourceUrl != nil {
            return .ready
        }
        return .missing
    }

    private func assessDetailCapability(_ source: BookSource) -> CapabilityStatus {
        // Legado: ruleBookInfo — empty {} means no detail rule
        // We treat empty object as missing
        return .missing
    }

    private func assessTocCapability(_ source: BookSource) -> CapabilityStatus {
        // Legado: ruleToc.chapterList
        return .missing
    }

    private func assessContentCapability(_ source: BookSource) -> CapabilityStatus {
        // Legado: ruleContent.content
        return .missing
    }
}