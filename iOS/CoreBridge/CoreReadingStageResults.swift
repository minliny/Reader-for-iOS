import Foundation
import ReaderCoreFoundation
import ReaderCoreModels

/// Typed result of the Core `book.detail` stage.
///
/// `tocURL` and `variables` live at the result root in the Core protocol. They
/// cannot be reconstructed from `SearchResultItem`, so the book-open
/// coordinator keeps this envelope alongside the renderer-facing book model.
public struct CoreBookDetailStageResult: Equatable, Sendable {
    /// Identity echoed by the actual Core `book.detail` result. Keep this
    /// separate from renderer-facing `SearchResultItem.detailURL`: a Core
    /// `bookId` is not necessarily a navigable detail URL.
    public let sourceID: String?
    public let bookID: String
    public let book: SearchResultItem
    public let tocURL: String?
    public let variables: [String: String]

    public init(
        sourceID: String?,
        bookID: String,
        book: SearchResultItem,
        tocURL: String?,
        variables: [String: String]
    ) {
        self.sourceID = sourceID
        self.bookID = bookID
        self.book = book
        self.tocURL = tocURL
        self.variables = variables
    }
}

/// A TOC item plus the per-entry Legado variables returned by Core.
public struct CoreTOCStageEntry: Equatable, Sendable {
    public let item: TOCItem
    public let variables: [String: String]

    public init(item: TOCItem, variables: [String: String]) {
        self.item = item
        self.variables = variables
    }
}

/// Typed result of the Core `book.toc` stage.
public struct CoreTOCStageResult: Equatable, Sendable {
    public let sourceID: String?
    public let bookID: String?
    public let entries: [CoreTOCStageEntry]

    public var items: [TOCItem] { entries.map(\.item) }

    public init(
        sourceID: String?,
        bookID: String?,
        entries: [CoreTOCStageEntry]
    ) {
        self.sourceID = sourceID
        self.bookID = bookID
        self.entries = entries
    }

    /// Build the typed input for `chapter.content` without serializing the
    /// detail/TOC variables into an ad-hoc UI payload. Per-entry variables are
    /// the most specific scope and intentionally win on duplicate keys.
    public func contentRequestContext(
        for entry: CoreTOCStageEntry,
        detailVariables: [String: String] = [:]
    ) -> CoreChapterContentRequestContext? {
        guard let bookID, !bookID.isEmpty else { return nil }
        var variables = detailVariables
        variables.merge(entry.variables, uniquingKeysWith: { _, entryValue in entryValue })
        return CoreChapterContentRequestContext(
            bookID: bookID,
            chapterTitle: entry.item.chapterTitle,
            chapterIndex: entry.item.chapterIndex,
            chapterURL: entry.item.chapterURL,
            variables: variables
        )
    }
}

/// Context that must survive from TOC selection into `chapter.content`.
public struct CoreChapterContentRequestContext: Equatable, Sendable {
    public let bookID: String
    public let chapterTitle: String
    public let chapterIndex: Int
    public let chapterURL: String
    public let variables: [String: String]

    public init(
        bookID: String,
        chapterTitle: String,
        chapterIndex: Int,
        chapterURL: String,
        variables: [String: String] = [:]
    ) {
        self.bookID = bookID
        self.chapterTitle = chapterTitle
        self.chapterIndex = max(0, chapterIndex)
        self.chapterURL = chapterURL
        self.variables = variables
    }
}

/// Typed result of the Core `chapter.content` stage.
///
/// Core's remote result does not echo every request field. The envelope keeps
/// the exact selected chapter identity from the request together with the real
/// Core body, so later layout and stale-result checks never have to infer it.
public struct CoreChapterContentStageResult: Equatable, Sendable {
    public let page: ContentPage
    public let rawContent: JSONValue
    public let sourceID: String?
    public let bookID: String
    public let chapterTitle: String
    public let chapterIndex: Int
    public let chapterURL: String
    public let variables: [String: String]

    public init(
        page: ContentPage,
        rawContent: JSONValue,
        sourceID: String?,
        bookID: String,
        chapterTitle: String,
        chapterIndex: Int,
        chapterURL: String,
        variables: [String: String]
    ) {
        self.page = page
        self.rawContent = rawContent
        self.sourceID = sourceID
        self.bookID = bookID
        self.chapterTitle = chapterTitle
        self.chapterIndex = max(0, chapterIndex)
        self.chapterURL = chapterURL
        self.variables = variables
    }
}

/// Host-measured layout input for Core's `reader.location.resolve` command.
///
/// This deliberately contains only stable measurement data. The Reader view
/// owns how it obtains the values; Core owns the canonical location returned
/// from them. Keeping this type in CoreBridge prevents the command layer from
/// importing SwiftUI or guessing viewport values before the content is shown.
public struct CoreReaderLocationLayout: Equatable, Sendable {
    public let viewportWidth: Int
    public let viewportHeight: Int
    public let fontScale: Double
    public let lineHeight: Double?
    public let pageIndex: Int?
    public let pageCount: Int?

    public init(
        viewportWidth: Int,
        viewportHeight: Int,
        fontScale: Double,
        lineHeight: Double? = nil,
        pageIndex: Int? = nil,
        pageCount: Int? = nil
    ) {
        self.viewportWidth = max(1, viewportWidth)
        self.viewportHeight = max(1, viewportHeight)
        self.fontScale = max(0.1, fontScale)
        self.lineHeight = lineHeight
        self.pageIndex = pageIndex.map { max(0, $0) }
        self.pageCount = pageCount.map { max(0, $0) }
    }
}

/// Typed request for the layout-dependent final stage of `book.open`.
public struct CoreReaderLocationStageRequest: Equatable, Sendable {
    public let sourceID: String?
    public let bookID: String
    public let chapterIndex: Int
    public let chapterTitle: String?
    public let chapterOffset: Int
    public let chapterProgress: Double
    public let layout: CoreReaderLocationLayout

    public init(
        sourceID: String?,
        bookID: String,
        chapterIndex: Int,
        chapterTitle: String? = nil,
        chapterOffset: Int,
        chapterProgress: Double,
        layout: CoreReaderLocationLayout
    ) {
        self.sourceID = sourceID?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.bookID = bookID
        self.chapterIndex = max(0, chapterIndex)
        self.chapterTitle = chapterTitle?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.chapterOffset = max(0, chapterOffset)
        self.chapterProgress = min(1, max(0, chapterProgress))
        self.layout = layout
    }
}

/// Canonical, layout-independent location resolved by Core.
public struct CoreReaderLocationStageResult: Equatable, Sendable {
    public let bookID: String
    public let chapterIndex: Int
    public let chapterOffset: Int
    public let chapterProgress: Double
    public let locationRevision: String
    public let resolverVersion: String
    public let primaryAnchor: String
    public let fallbackAnchor: String
    public let layoutIndependent: Bool

    public init(
        bookID: String,
        chapterIndex: Int,
        chapterOffset: Int,
        chapterProgress: Double,
        locationRevision: String,
        resolverVersion: String,
        primaryAnchor: String,
        fallbackAnchor: String,
        layoutIndependent: Bool
    ) {
        self.bookID = bookID
        self.chapterIndex = max(0, chapterIndex)
        self.chapterOffset = max(0, chapterOffset)
        self.chapterProgress = min(1, max(0, chapterProgress))
        self.locationRevision = locationRevision
        self.resolverVersion = resolverVersion
        self.primaryAnchor = primaryAnchor
        self.fallbackAnchor = fallbackAnchor
        self.layoutIndependent = layoutIndependent
    }
}

/// Typed, correlation-scoped input for Core's `reading.progress.update`.
///
/// A page transaction creates this value only after Core has returned a
/// canonical location. Unlike the legacy reader persistence path, every field
/// is an exact Core protocol field; the service validates the value without
/// clamping or inventing aliases before crossing the C-ABI boundary.
public struct CoreReaderProgressStageRequest: Equatable, Sendable {
    public let sourceID: String
    public let bookID: String
    public let deviceID: String?
    public let updatedAt: Int64
    public let chapterIndex: Int
    public let chapterOffset: Int
    public let chapterProgress: Double
    public let locationRevision: String

    public init(
        sourceID: String,
        bookID: String,
        deviceID: String? = nil,
        updatedAt: Int64 = Int64(Date().timeIntervalSince1970),
        chapterIndex: Int,
        chapterOffset: Int,
        chapterProgress: Double,
        locationRevision: String
    ) {
        self.sourceID = sourceID
        self.bookID = bookID
        self.deviceID = deviceID
        self.updatedAt = updatedAt
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.locationRevision = locationRevision
    }
}

/// Strict typed terminal result of Core's `reading.progress.update`.
/// `stored` remains explicit so false or malformed values fail the page
/// transaction instead of being treated as a successful local projection.
public struct CoreReaderProgressStageResult: Equatable, Sendable {
    public let sourceID: String
    public let bookID: String
    public let deviceID: String?
    public let updatedAt: Int64
    public let chapterIndex: Int
    public let chapterOffset: Int
    public let chapterProgress: Double
    public let locationRevision: String
    public let stored: Bool

    public init(
        sourceID: String,
        bookID: String,
        deviceID: String? = nil,
        updatedAt: Int64,
        chapterIndex: Int,
        chapterOffset: Int,
        chapterProgress: Double,
        locationRevision: String,
        stored: Bool
    ) {
        self.sourceID = sourceID
        self.bookID = bookID
        self.deviceID = deviceID
        self.updatedAt = updatedAt
        self.chapterIndex = chapterIndex
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.locationRevision = locationRevision
        self.stored = stored
    }
}

enum CoreReadingStageValue {
    static func stringMap(_ value: Any?) -> [String: String] {
        if let value = value as? [String: String] {
            return value
        }
        guard let value = value as? [String: Any] else { return [:] }
        return value.reduce(into: [String: String]()) { result, pair in
            if let string = pair.value as? String {
                result[pair.key] = string
            }
        }
    }

    static func jsonObject(_ value: [String: String]) -> JSONValue {
        .object(value.mapValues(JSONValue.string))
    }

    static func jsonValue(_ value: Any?) -> JSONValue {
        switch value {
        case let value as String:
            return .string(value)
        case let value as Bool:
            return .bool(value)
        case let value as Int:
            return .number(Double(value))
        case let value as Double:
            return .number(value)
        case let value as NSNumber:
            return .number(value.doubleValue)
        case let value as [String: Any]:
            return .object(value.mapValues(jsonValue))
        case let value as [Any]:
            return .array(value.map(jsonValue))
        default:
            return .null
        }
    }

    static func rendererText(_ value: Any?) -> String {
        if let value = value as? String { return value }
        let jsonValue = jsonValue(value)
        guard jsonValue != .null,
              let data = try? JSONEncoder().encode(jsonValue),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    static func integer(_ value: Any?, fallback: Int) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return fallback
    }

    static func number(_ value: Any?, fallback: Double) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? Float { return Double(value) }
        if let value = value as? Int { return Double(value) }
        if let value = value as? NSNumber { return value.doubleValue }
        return fallback
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
