import CoreFoundation
import Foundation
import ReaderCoreModels
import ReaderUIContract

/// The provider surface consumed by `ReaderCoreBridge`.
///
/// `ReaderCoreServiceProvider` is the production conformer. Keeping the
/// surface explicit makes the contract-to-provider mapping independently
/// testable without replacing the Rust runtime or returning placeholder nils.
@MainActor
public protocol ReaderCoreBridgeServiceProviding: AnyObject {
    func searchBooks(keyword: String, page: Int, source: BookSource?) async -> LoadState<[SearchResultItem]>
    func getBookDetail(bookURL: String, source: BookSource?) async -> LoadState<SearchResultItem>
    func getChapterList(bookURL: String, source: BookSource?) async -> LoadState<[TOCItem]>
    func getChapterContent(chapterURL: String, source: BookSource?) async -> LoadState<ContentPage>
    func executeCoreCommand(
        method: String,
        params: [String: Any],
        requestId: String?
    ) async -> Result<[String: Any], AppReaderError>
}

extension ReaderCoreServiceProvider: ReaderCoreBridgeServiceProviding {}

/// Typed bridge failures for commands that have no executable iOS/Core path.
/// Callers must surface or route these failures; the bridge never silently
/// converts an unsupported command into `nil`.
public enum ReaderCoreBridgeError: Error, Equatable, LocalizedError {
    case unsupportedCommand(CoreCommandType, mappedMethod: String?)

    public var errorDescription: String? {
        switch self {
        case .unsupportedCommand(let type, let mappedMethod):
            if let mappedMethod {
                return "Core command \(type.rawValue) is mapped to \(mappedMethod) but has no executable iOS bridge path"
            }
            return "Core command \(type.rawValue) has no executable iOS bridge path"
        }
    }
}

/// Contract `CoreCommand` -> provider/Rust Core facade.
///
/// Network-backed operations use `ReaderCoreServiceProvider`'s typed services,
/// which own the complete Core -> HostRequestRouter -> Core round trip. Pure
/// Core operations use `executeCoreCommand`. Every handled command produces a
/// success or failure `CoreEvent`; unsupported commands throw a typed error.
@MainActor
public final class ReaderCoreBridge {
    private let provider: any ReaderCoreBridgeServiceProviding
    private let sourceResolver: @MainActor (String) -> BookSource?

    public convenience init() {
        self.init(provider: ReaderCoreServiceProvider.shared)
    }

    public init(
        provider: any ReaderCoreBridgeServiceProviding,
        sourceResolver: @escaping @MainActor (String) -> BookSource? = { _ in nil }
    ) {
        self.provider = provider
        self.sourceResolver = sourceResolver
    }

    /// Dispatch a contract command to a real provider/Core execution path.
    ///
    /// The return is intentionally non-optional. A supported command always
    /// yields a terminal success/failure event; an unsupported command throws
    /// `ReaderCoreBridgeError.unsupportedCommand`.
    public func send(_ command: CoreCommand) async throws -> CoreEvent {
        switch command.type {
        case .source_search:
            return await sendSourceSearch(command)
        case .source_detail:
            return await sendSourceDetail(command)
        case .chapter_list:
            return await sendChapterList(command)
        case .content_load, .chapter_load:
            return await sendContentLoad(command)
        case .reader_progress_update:
            return await sendDirect(
                command,
                method: "reading.progress.update",
                success: .reader_progress_updated,
                // The contract currently has no distinct
                // reader.progress.update.failed event. Preserve the command's
                // terminal event type and mark failures in its typed payload.
                failure: .reader_progress_updated,
                params: progressParams(command)
            )
        case .reader_location_resolve:
            return await sendDirect(
                command,
                method: "reader.location.resolve",
                success: .reader_location_resolved,
                failure: .reader_location_resolve_failed,
                params: locationResolveParams(command)
            )
        case .book_parse:
            return await sendDirect(
                command,
                method: "local_book.parse",
                success: .book_parsed,
                failure: .book_parse_failed,
                params: directParams(command.payload)
            )
        case .bookshelf_list:
            return await sendDirect(
                command,
                method: "bookshelf.list",
                success: .bookshelf_listed,
                failure: .bookshelf_list_failed,
                params: bookshelfParams(command.payload)
            )
        default:
            throw ReaderCoreBridgeError.unsupportedCommand(
                command.type,
                mappedMethod: Self.commandMapping[command.type]
            )
        }
    }

    // MARK: - Typed provider dispatch

    private func sendSourceSearch(_ command: CoreCommand) async -> CoreEvent {
        guard let query = string(command.payload, keys: ["query", "keyword"]), !query.isEmpty else {
            return failureEvent(command, type: .source_search_failed, message: "source.search requires non-empty query", code: "INVALID_PARAMS")
        }
        let page = integer(command.payload, keys: ["page"]) ?? 1
        let state = await provider.searchBooks(
            keyword: query,
            page: max(1, page),
            source: source(from: command)
        )
        switch state {
        case .loaded(let items):
            return event(command, type: .source_search_completed, payload: collectionPayload("results", items))
        case .partial(let items, let warning):
            var payload = collectionPayload("results", items)
            payload["warning"] = AnyCodable(warning)
            return event(command, type: .source_search_completed, payload: payload)
        case .empty:
            return event(command, type: .source_search_completed, payload: ["results": AnyCodable([AnyCodable]()), "count": AnyCodable(0)])
        case .failed(let error):
            return failureEvent(command, type: .source_search_failed, error: error)
        case .unsupported(let reason):
            return failureEvent(command, type: .source_search_failed, message: reason, code: "UNSUPPORTED")
        case .idle, .loading:
            return failureEvent(command, type: .source_search_failed, message: "source.search returned a non-terminal provider state", code: "NON_TERMINAL_STATE")
        }
    }

    private func sendSourceDetail(_ command: CoreCommand) async -> CoreEvent {
        guard let detailURL = string(command.payload, keys: ["detailUrl", "detailURL", "bookUrl", "bookURL"]), !detailURL.isEmpty else {
            return failureEvent(command, type: .source_detail_failed, message: "source.detail requires detailUrl", code: "INVALID_PARAMS")
        }
        let state = await provider.getBookDetail(bookURL: detailURL, source: source(from: command))
        switch state {
        case .loaded(let book):
            return event(command, type: .source_detail_loaded, payload: ["book": encode(book)])
        case .partial(let book, let warning):
            return event(command, type: .source_detail_loaded, payload: ["book": encode(book), "warning": AnyCodable(warning)])
        case .empty:
            return failureEvent(command, type: .source_detail_failed, message: "source.detail returned no book", code: "EMPTY")
        case .failed(let error):
            return failureEvent(command, type: .source_detail_failed, error: error)
        case .unsupported(let reason):
            return failureEvent(command, type: .source_detail_failed, message: reason, code: "UNSUPPORTED")
        case .idle, .loading:
            return failureEvent(command, type: .source_detail_failed, message: "source.detail returned a non-terminal provider state", code: "NON_TERMINAL_STATE")
        }
    }

    private func sendChapterList(_ command: CoreCommand) async -> CoreEvent {
        guard let bookURL = string(command.payload, keys: ["bookUrl", "bookURL", "detailUrl", "detailURL", "bookId"]), !bookURL.isEmpty else {
            return failureEvent(command, type: .chapter_list_failed, message: "chapter.list requires bookUrl/detailUrl/bookId", code: "INVALID_PARAMS")
        }
        let state = await provider.getChapterList(bookURL: bookURL, source: source(from: command))
        switch state {
        case .loaded(let chapters):
            return event(command, type: .chapter_listed, payload: collectionPayload("chapters", chapters))
        case .partial(let chapters, let warning):
            var payload = collectionPayload("chapters", chapters)
            payload["warning"] = AnyCodable(warning)
            return event(command, type: .chapter_listed, payload: payload)
        case .empty:
            return event(command, type: .chapter_listed, payload: ["chapters": AnyCodable([AnyCodable]()), "count": AnyCodable(0)])
        case .failed(let error):
            return failureEvent(command, type: .chapter_list_failed, error: error)
        case .unsupported(let reason):
            return failureEvent(command, type: .chapter_list_failed, message: reason, code: "UNSUPPORTED")
        case .idle, .loading:
            return failureEvent(command, type: .chapter_list_failed, message: "chapter.list returned a non-terminal provider state", code: "NON_TERMINAL_STATE")
        }
    }

    private func sendContentLoad(_ command: CoreCommand) async -> CoreEvent {
        guard let chapterURL = string(command.payload, keys: ["chapterUrl", "chapterURL", "chapterId"]), !chapterURL.isEmpty else {
            return failureEvent(command, type: .content_load_failed, message: "content.load requires chapterUrl/chapterId", code: "INVALID_PARAMS")
        }
        let state = await provider.getChapterContent(chapterURL: chapterURL, source: source(from: command))
        switch state {
        case .loaded(let page):
            return event(command, type: .content_loaded, payload: ["content": encode(page)])
        case .partial(let page, let warning):
            return event(command, type: .content_loaded, payload: ["content": encode(page), "warning": AnyCodable(warning)])
        case .empty:
            return failureEvent(command, type: .content_load_failed, message: "content.load returned no content", code: "EMPTY")
        case .failed(let error):
            return failureEvent(command, type: .content_load_failed, error: error)
        case .unsupported(let reason):
            return failureEvent(command, type: .content_load_failed, message: reason, code: "UNSUPPORTED")
        case .idle, .loading:
            return failureEvent(command, type: .content_load_failed, message: "content.load returned a non-terminal provider state", code: "NON_TERMINAL_STATE")
        }
    }

    private func sendDirect(
        _ command: CoreCommand,
        method: String,
        success: CoreEventType,
        failure: CoreEventType,
        params: Result<[String: Any], ReaderCoreBridgePayloadError>
    ) async -> CoreEvent {
        let resolvedParams: [String: Any]
        switch params {
        case .success(let value):
            resolvedParams = value
        case .failure(let error):
            return failureEvent(command, type: failure, message: error.message, code: "INVALID_PARAMS")
        }

        switch await provider.executeCoreCommand(method: method, params: resolvedParams, requestId: command.requestId) {
        case .success(let result):
            return event(command, type: success, payload: wrapDictionary(result))
        case .failure(let error):
            return failureEvent(command, type: failure, error: error)
        }
    }

    // MARK: - Payload mapping

    private struct ReaderCoreBridgePayloadError: Error {
        let message: String
    }

    private func progressParams(_ command: CoreCommand) -> Result<[String: Any], ReaderCoreBridgePayloadError> {
        guard let bookId = string(command.payload, keys: ["bookId", "bookID"]), !bookId.isEmpty else {
            return .failure(.init(message: "reader.progress.update requires bookId"))
        }
        let locator = dictionary(command.payload["locator"])
        let chapterIndex = integer(command.payload, keys: ["chapterIndex"]) ?? 0
        let chapterOffset = integer(locator, keys: ["charOffset", "chapterOffset", "offset"]) ?? 0
        let chapterProgress = number(command.payload, keys: ["progress", "chapterProgress"])
            ?? number(locator, keys: ["chapterProgress"])
            ?? 0
        guard (0...1).contains(chapterProgress) else {
            return .failure(.init(message: "reader.progress.update progress must be between 0 and 1"))
        }

        var params: [String: Any] = [
            "bookId": bookId,
            "sourceId": string(command.payload, keys: ["sourceId", "sourceID"]) ?? "local",
            // Core's ReadingProgressUpdateParams uses Unix seconds, not
            // milliseconds. Keeping this exact avoids a synthetic far-future
            // timestamp winning LWW sync conflict resolution.
            "updatedAt": Int64(Date().timeIntervalSince1970),
            "chapterIndex": chapterIndex,
            "chapterOffset": chapterOffset,
            "chapterProgress": chapterProgress,
        ]
        if let revision = string(locator, keys: ["locationRevision", "revision"])
            ?? string(command.payload, keys: ["locationRevision"]) {
            params["locationRevision"] = revision
        }
        if let deviceId = string(command.payload, keys: ["deviceId", "deviceID"]) {
            params["deviceId"] = deviceId
        }
        return .success(params)
    }

    private func locationResolveParams(_ command: CoreCommand) -> Result<[String: Any], ReaderCoreBridgePayloadError> {
        guard let bookId = string(command.payload, keys: ["bookId", "bookID"]), !bookId.isEmpty else {
            return .failure(.init(message: "reader.location.resolve requires bookId"))
        }
        let locator = dictionary(command.payload["locator"])
        let layout = dictionary(command.payload["layout"])
        let chapterOffset = integer(locator, keys: ["charOffset", "chapterOffset", "offset"]) ?? 0
        let chapterProgress = number(locator, keys: ["chapterProgress"])
            ?? number(command.payload, keys: ["progress"])
            ?? 0
        guard let viewportWidth = integer(layout, keys: ["viewportWidth", "width"]), viewportWidth > 0,
              let viewportHeight = integer(layout, keys: ["viewportHeight", "height"]), viewportHeight > 0 else {
            return .failure(.init(message: "reader.location.resolve requires positive layout viewportWidth and viewportHeight"))
        }

        var params: [String: Any] = [
            "bookId": bookId,
            "chapterIndex": integer(command.payload, keys: ["chapterIndex"]) ?? 0,
            "anchor": [
                "chapterOffset": chapterOffset,
                "chapterProgress": chapterProgress,
            ],
            "layout": [
                "viewportWidth": viewportWidth,
                "viewportHeight": viewportHeight,
                "fontScale": number(layout, keys: ["fontScale"]) ?? 1,
            ],
        ]
        if let sourceId = string(command.payload, keys: ["sourceId", "sourceID"]) {
            params["sourceId"] = sourceId
        }
        if let chapterTitle = string(command.payload, keys: ["chapterTitle"]) {
            params["chapterTitle"] = chapterTitle
        }
        return .success(params)
    }

    private func bookshelfParams(_ payload: [String: AnyCodable]) -> Result<[String: Any], ReaderCoreBridgePayloadError> {
        var params = directParams(payload).successValue ?? [:]
        if let sortKey = string(payload, keys: ["sortKey"]) {
            params["sortBy"] = sortKey == "lastRead" ? "lastReadAt" : sortKey
            params.removeValue(forKey: "sortKey")
        }
        if let order = string(payload, keys: ["sortOrder"]) {
            params["sortDirection"] = order == "desc" ? "descending" : order == "asc" ? "ascending" : order
            params.removeValue(forKey: "sortOrder")
        }
        return .success(params)
    }

    private func directParams(_ payload: [String: AnyCodable]) -> Result<[String: Any], ReaderCoreBridgePayloadError> {
        .success(payload.reduce(into: [String: Any]()) { result, pair in
            result[pair.key] = unwrap(pair.value)
        })
    }

    private func source(from command: CoreCommand) -> BookSource? {
        if let sourceValue = command.payload["source"],
           let source = decode(BookSource.self, from: unwrap(sourceValue)) {
            return source
        }
        if let sourceId = string(command.payload, keys: ["sourceId", "sourceID"]) {
            return sourceResolver(sourceId)
        }
        return nil
    }

    // MARK: - Event construction

    private func event(_ command: CoreCommand, type: CoreEventType, payload: [String: AnyCodable]) -> CoreEvent {
        CoreEvent(
            type: type,
            payload: payload,
            correlationId: command.correlationId,
            requestId: command.requestId
        )
    }

    private func failureEvent(
        _ command: CoreCommand,
        type: CoreEventType,
        error: AppReaderError
    ) -> CoreEvent {
        failureEvent(
            command,
            type: type,
            message: error.message,
            code: String(describing: error.code),
            stage: error.stage
        )
    }

    private func failureEvent(
        _ command: CoreCommand,
        type: CoreEventType,
        message: String,
        code: String,
        stage: String? = nil
    ) -> CoreEvent {
        var payload: [String: AnyCodable] = [
            "succeeded": AnyCodable(false),
            "code": AnyCodable(code),
            "message": AnyCodable(message),
        ]
        if let stage { payload["stage"] = AnyCodable(stage) }
        return event(command, type: type, payload: payload)
    }

    private func collectionPayload<T: Encodable>(_ key: String, _ values: [T]) -> [String: AnyCodable] {
        [
            key: AnyCodable(values.map(encode)),
            "count": AnyCodable(values.count),
        ]
    }

    private func encode<T: Encodable>(_ value: T) -> AnyCodable {
        guard let data = try? JSONEncoder().encode(value),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return AnyCodable(String(describing: value))
        }
        return wrap(object)
    }

    private func decode<T: Decodable>(_ type: T.Type, from object: Any) -> T? {
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    private func wrapDictionary(_ dictionary: [String: Any]) -> [String: AnyCodable] {
        dictionary.reduce(into: [:]) { result, pair in result[pair.key] = wrap(pair.value) }
    }

    private func wrap(_ value: Any) -> AnyCodable {
        switch value {
        case let value as AnyCodable:
            return value
        case let value as Bool:
            return AnyCodable(value)
        case let value as Int:
            return AnyCodable(value)
        case let value as Int64:
            return AnyCodable(Int(value))
        case let value as Double:
            return AnyCodable(value)
        case let value as String:
            return AnyCodable(value)
        case let value as NSNumber:
            if CFGetTypeID(value) == CFBooleanGetTypeID() { return AnyCodable(value.boolValue) }
            let double = value.doubleValue
            return double.rounded() == double ? AnyCodable(value.intValue) : AnyCodable(double)
        case let value as [Any]:
            return AnyCodable(value.map(wrap))
        case let value as [String: Any]:
            return AnyCodable(wrapDictionary(value))
        default:
            return AnyCodable(String?.none as String?)
        }
    }

    private func unwrap(_ value: AnyCodable) -> Any {
        unwrapValue(value.value)
    }

    private func unwrapValue(_ value: Any) -> Any {
        switch value {
        case let value as [AnyCodable]:
            return value.map(unwrap)
        case let value as [String: AnyCodable]:
            return value.reduce(into: [String: Any]()) { result, pair in result[pair.key] = unwrap(pair.value) }
        case let value as [Any]:
            return value.map(unwrapValue)
        case let value as [String: Any]:
            return value.reduce(into: [String: Any]()) { result, pair in result[pair.key] = unwrapValue(pair.value) }
        default:
            return value
        }
    }

    private func dictionary(_ value: AnyCodable?) -> [String: AnyCodable] {
        guard let value else { return [:] }
        if let dictionary = value.value as? [String: AnyCodable] { return dictionary }
        if let dictionary = value.value as? [String: Any] {
            return wrapDictionary(dictionary)
        }
        return [:]
    }

    private func string(_ payload: [String: AnyCodable], keys: [String]) -> String? {
        for key in keys {
            if let value = payload[key]?.value as? String { return value }
        }
        return nil
    }

    private func integer(_ payload: [String: AnyCodable], keys: [String]) -> Int? {
        for key in keys {
            guard let value = payload[key]?.value else { continue }
            if let value = value as? Int { return value }
            if let value = value as? Double { return Int(value) }
            if let value = value as? NSNumber { return value.intValue }
            if let value = value as? String, let integer = Int(value) { return integer }
        }
        return nil
    }

    private func number(_ payload: [String: AnyCodable], keys: [String]) -> Double? {
        for key in keys {
            guard let value = payload[key]?.value else { continue }
            if let value = value as? Double { return value }
            if let value = value as? Int { return Double(value) }
            if let value = value as? NSNumber { return value.doubleValue }
            if let value = value as? String, let number = Double(value) { return number }
        }
        return nil
    }

    // MARK: - Command name documentation

    /// Contract `CoreCommandType` -> Core-Native protocol method.
    public static let commandMapping: [CoreCommandType: String] = [
        .source_search: "book.search",
        .source_detail: "book.detail",
        .content_load: "chapter.content",
        .chapter_load: "chapter.content",
        .chapter_list: "book.toc",
        .reader_progress_update: "reading.progress.update",
        .reader_location_resolve: "reader.location.resolve",
        .book_parse: "local_book.parse",
        .bookshelf_list: "bookshelf.list",
        .book_open: "(host-session-only)",
        .rss_list: "(pending)",
        .rss_item_read: "(pending)",
    ]
}

private extension Result {
    var successValue: Success? {
        guard case .success(let value) = self else { return nil }
        return value
    }
}
