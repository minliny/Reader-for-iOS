import Foundation
import ReaderCoreBridge
import ReaderDesign
import ReaderHost

struct EbookDocument: Sendable {
    let descriptor: LocalBookChapterPresentationData
    let chapter: LocalBookChapterContentData
    let source: RetainedSource
    let xhtml: String

    var authorizedImagePaths: [String] {
        let prefix = "reader-local-epub://"
        return Set((chapter.blocks ?? []).compactMap { block -> String? in
            guard case .image(let image) = block, image.source.hasPrefix(prefix) else { return nil }
            let parts = image.source.dropFirst(prefix.count).split(separator: "/", omittingEmptySubsequences: false)
            guard parts.count == 2, Self.decodeLocator(parts[0]) == descriptor.bookId,
                  let entry = Self.decodeLocator(parts[1]), RetainedSource.isArchivePath(entry) else { return nil }
            return entry
        }).sorted()
    }

    private static func decodeLocator(_ part: Substring) -> String? {
        let base64 = part.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        guard let bytes = Data(base64Encoded: base64) else { return nil }
        return String(data: bytes, encoding: .utf8)
    }

    static func open(
        descriptor: LocalBookChapterPresentationData,
        chapter: LocalBookChapterContentData,
        source: RetainedSource
    ) async throws -> EbookDocument {
        guard descriptor.bookId == chapter.bookId, descriptor.sourceId == chapter.sourceId,
              descriptor.chapterIndex == chapter.chapterIndex, descriptor.bodyVersion == chapter.bodyVersion,
              descriptor.processingVersion == chapter.processingVersion else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return try await Task.detached {
            let bytes = try source.readEntry(descriptor.entryPath, maxBytes: 4 * 1024 * 1024)
            guard let xhtml = String(data: bytes, encoding: .utf8) else {
                throw FileAndAssetFailure.invalidEntry
            }
            return EbookDocument(descriptor: descriptor, chapter: chapter, source: source, xhtml: xhtml)
        }.value
    }
}

struct EbookStyle: Encodable, Sendable {
    let fontSize: Double
    let lineHeight: Double
    let paper: String?
    let ink: String?
    let dark: Bool
    let paragraphSpacing = ReaderDesignMetrics.readerParagraphSpacing

    init(fontSize: Double = ReaderDesignMetrics.readerBody.fontSize, lineHeight: Double? = nil,
         background: String? = nil, foreground: String? = nil, dark: Bool = false) {
        self.fontSize = fontSize
        let body = ReaderDesignMetrics.readerBody
        self.lineHeight = lineHeight ?? (fontSize * body.lineHeight / body.fontSize)
        paper = background
        ink = foreground
        self.dark = dark
    }
}

struct EbookRenderIdentity: Equatable, Sendable {
    let session: String
    let documentId: String
    let layoutGeneration: Int
}

struct EbookScriptEvent: Decodable, Sendable {
    struct Value: Decodable, Sendable {
        let scalar: Int?
        let text: String?
        let loadedImageCount: Int?
        let startScalar: Int?
        let endScalar: Int?
        let code: String?
        let path: String?
        let fragment: String?

        init(scalar: Int? = nil, text: String? = nil, loadedImageCount: Int? = nil,
             startScalar: Int? = nil, endScalar: Int? = nil, code: String? = nil,
             path: String? = nil, fragment: String? = nil) {
            self.scalar = scalar
            self.text = text
            self.loadedImageCount = loadedImageCount
            self.startScalar = startScalar
            self.endScalar = endScalar
            self.code = code
            self.path = path
            self.fragment = fragment
        }

        private enum CodingKeys: String, CodingKey {
            case scalar, text, loadedImageCount, startScalar, endScalar, code, fragment
            case path = "entryPath"
        }
    }

    let version: Int
    let session: String
    let documentId: String
    let layoutGeneration: Int
    let kind: String
    let value: Value?

    var identity: EbookRenderIdentity {
        EbookRenderIdentity(session: session, documentId: documentId, layoutGeneration: layoutGeneration)
    }
}

enum EbookSurfaceFailure: Error {
    case missingResources
    case shellLoad
    case retired
    case unavailable(String)
}
