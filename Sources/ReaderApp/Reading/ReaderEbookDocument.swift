import Foundation

/// A Core-owned link from the canonical indexed chapter to its original XHTML.
/// Hosts must not infer this from TOC titles, chapter ordinals or a second OPF
/// manifest. The local_book.chapter.presentation.v1 command emits it after
/// checking the retained source and the current indexed chapter.
public struct ReaderEbookDocument: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let chapterIndex: UInt32
    public let bodyVersion: String
    public let processingVersion: String
    public let entryPath: String
    /// Full-document visible projection, with each inline image as U+FFFC.
    public let documentCanonicalContent: String
    /// The current chapter window in the full-document scalar coordinates.
    public let chapterStartScalar: UInt64
    public let chapterEndScalar: UInt64

    public init(sourceId: String, bookId: String, chapterIndex: UInt32, bodyVersion: String,
                processingVersion: String, entryPath: String, documentCanonicalContent: String,
                chapterStartScalar: UInt64, chapterEndScalar: UInt64) {
        self.sourceId = sourceId; self.bookId = bookId; self.chapterIndex = chapterIndex
        self.bodyVersion = bodyVersion; self.processingVersion = processingVersion; self.entryPath = entryPath
        self.documentCanonicalContent = documentCanonicalContent
        self.chapterStartScalar = chapterStartScalar; self.chapterEndScalar = chapterEndScalar
    }

    var identity: String {
        "\(sourceId)|\(bookId)|\(chapterIndex)|\(bodyVersion)|\(processingVersion)|\(entryPath)"
    }

    func validate(content: ReaderChapterContent) throws {
        guard sourceId == "local", sourceId == content.sourceId, bookId == content.bookId,
              chapterIndex == content.chapterIndex, bodyVersion == content.bodyVersion,
              processingVersion == content.processingVersion,
              ReaderEbookResourcePath.isCanonical(entryPath),
              !bodyVersion.isEmpty, !processingVersion.isEmpty,
              chapterStartScalar <= chapterEndScalar,
              chapterEndScalar <= UInt64(documentCanonicalContent.unicodeScalars.count),
              documentCanonicalContent.utf8.count <= 16 * 1024 * 1024 else {
            throw ReaderEbookError.invalidDocument
        }
        let scalars = documentCanonicalContent.unicodeScalars
        let lower = scalars.index(scalars.startIndex, offsetBy: Int(chapterStartScalar))
        let upper = scalars.index(scalars.startIndex, offsetBy: Int(chapterEndScalar))
        guard !String(scalars[lower..<upper]).isEmpty || content.content.isEmpty else {
            throw ReaderEbookError.positionMismatch
        }
    }
}

/// A selection always addresses the same immutable Core content version as
/// progress and search. Native WebKit supplies copy and selection handles.
struct ReaderEbookSelection: Equatable, Sendable {
    let sourceId: String
    let bookId: String
    let chapterIndex: UInt32
    let bodyVersion: String
    let processingVersion: String
    let startScalar: UInt64
    let endScalar: UInt64
    let text: String
}

/// Whitespace collapsed by Core carries no independent DOM character. This
/// map only matches platform-decoded text to Core's scalar positions; it never
/// parses HTML or changes Core's text, rules, chapter ranges or stored anchors.
struct ReaderEbookScalarMap {
    struct Point: Equatable { let canonicalScalar: UInt64; let renderedUTF16: Int }
    let points: [Point]
    let canonicalCount: UInt64
    let renderedUTF16Count: Int

    init(canonical: String, rendered: String) throws {
        let expected = Self.significant(canonical)
        let actual = Self.significant(rendered)
        guard expected.map(\.scalar) == actual.map(\.scalar) else { throw ReaderEbookError.positionMismatch }
        points = zip(expected, actual).map { pair in
            Point(canonicalScalar: pair.0.scalarIndex, renderedUTF16: pair.1.utf16Index)
        }
        canonicalCount = UInt64(canonical.unicodeScalars.count)
        renderedUTF16Count = rendered.utf16.count
    }

    func renderedOffset(forCanonical scalar: UInt64) -> Int {
        let scalar = min(scalar, canonicalCount)
        let index = points.partitioningIndex { $0.canonicalScalar >= scalar }
        return index < points.count ? points[index].renderedUTF16 : renderedUTF16Count
    }

    func canonicalOffset(forRenderedUTF16 offset: Int, retainingScalar: UInt64? = nil) -> UInt64 {
        let offset = min(max(0, offset), renderedUTF16Count)
        if let retainingScalar, renderedOffset(forCanonical: retainingScalar) == offset {
            return min(retainingScalar, canonicalCount)
        }
        let index = points.partitioningIndex { $0.renderedUTF16 >= offset }
        return index < points.count ? points[index].canonicalScalar : canonicalCount
    }

    private struct Significant {
        let scalar: Unicode.Scalar
        let scalarIndex: UInt64
        let utf16Index: Int
    }

    private static func significant(_ value: String) -> [Significant] {
        var result: [Significant] = []
        var scalarIndex: UInt64 = 0
        var utf16Index = 0
        for scalar in value.unicodeScalars {
            if !scalar.properties.isWhitespace {
                result.append(Significant(scalar: scalar, scalarIndex: scalarIndex, utf16Index: utf16Index))
            }
            scalarIndex += 1
            utf16Index += scalar.value > 0xffff ? 2 : 1
        }
        return result
    }
}

private extension Array {
    func partitioningIndex(where predicate: (Element) -> Bool) -> Int {
        var lower = 0
        var upper = count
        while lower < upper {
            let middle = lower + (upper - lower) / 2
            if predicate(self[middle]) { upper = middle } else { lower = middle + 1 }
        }
        return lower
    }
}
