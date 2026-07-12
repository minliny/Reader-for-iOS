import Combine
import Foundation
import ReaderCoreModels
import ReaderCoreNativeAdapter
import ReaderShellValidation
import ReaderUIContract
import ReaderUIRuntime

/// This switch is intentionally independent from `READER_UI_CONSUMER.json`.
/// The consumer lock remains the authority for production runtime rollout;
/// book.open is now bound to the consumer policy's effectful pilot cohort
/// (effectPolicy: "exactly-once"), so `live` is Pilot in lockstep with the
/// `book-open-pilot` cohort in `READER_UI_CONSUMER.json`.
public enum ReaderBookOpenPilotMode: String, Equatable, Sendable {
    case shadow
    case pilot
}

public struct ReaderBookOpenPilotConfiguration: Equatable, Sendable {
    public let mode: ReaderBookOpenPilotMode

    public init(mode: ReaderBookOpenPilotMode = .shadow) {
        self.mode = mode
    }

    public static let live = ReaderBookOpenPilotConfiguration(mode: .pilot)
}

public enum ReaderBookOpenSourceKind: String, Equatable, Sendable {
    case remote
    case local
}

/// The domain input captured once at a book.open entry. It is deliberately not
/// inferred again from later effects, which prevents a replacement transaction
/// from borrowing the source/book DTOs of an older correlation.
public struct ReaderBookOpenLaunch {
    public let correlationID: String
    public let sourceKind: ReaderBookOpenSourceKind
    public let sourceID: String
    public let bookID: String
    public let bookURL: String
    public let title: String
    public let author: String?
    public let coverURL: String?
    public let requestedChapterIndex: Int
    public let chapterURL: String?
    public let source: BookSource?
    public let book: SearchResultItem?

    public init(
        correlationID: String,
        sourceKind: ReaderBookOpenSourceKind,
        sourceID: String,
        bookID: String,
        bookURL: String? = nil,
        title: String = "",
        author: String? = nil,
        coverURL: String? = nil,
        requestedChapterIndex: Int = 0,
        chapterURL: String? = nil,
        source: BookSource? = nil,
        book: SearchResultItem? = nil
    ) {
        self.correlationID = correlationID
        self.sourceKind = sourceKind
        self.sourceID = sourceID
        self.bookID = bookID
        let normalizedBookURL = bookURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.bookURL = normalizedBookURL.isEmpty ? bookID : normalizedBookURL
        self.title = title
        self.author = author
        self.coverURL = coverURL
        self.requestedChapterIndex = max(0, requestedChapterIndex)
        self.chapterURL = chapterURL
        self.source = source
        self.book = book
    }

    var runtimePayload: ReaderUIJSONPayload {
        var payload: ReaderUIJSONPayload = [
            "sourceKind": .string(sourceKind.rawValue),
            "sourceId": .string(sourceID),
            "bookId": .string(bookID),
            "detailUrl": .string(bookURL),
            "chapterIndex": .number(Double(requestedChapterIndex)),
        ]
        if let chapterURL, !chapterURL.isEmpty { payload["chapterId"] = .string(chapterURL) }
        return payload
    }
}

/// Exact bookshelf entry data offered to a Pilot admission resolver. The
/// resolver is responsible for proving that `bookID` / `sourceID` are Core
/// identities (for example by consulting a Core-projected domain store); a
/// plain persisted bookshelf row is deliberately not treated as sufficient
/// evidence for remote or materialized-local Core access.
public struct ReaderBookOpenEntry: Equatable {
    public let correlationID: String
    public let sourceID: String
    public let nativeBookID: String
    public let bookURL: String
    public let title: String
    public let author: String?
    public let coverURL: String?
    public let chapterURL: String
    public let chapterTitle: String
    public let chapterIndex: Int

    public init(
        correlationID: String,
        sourceID: String,
        nativeBookID: String,
        bookURL: String,
        title: String,
        author: String? = nil,
        coverURL: String? = nil,
        chapterURL: String,
        chapterTitle: String,
        chapterIndex: Int
    ) {
        self.correlationID = correlationID
        self.sourceID = sourceID
        self.nativeBookID = nativeBookID
        self.bookURL = bookURL
        self.title = title
        self.author = author
        self.coverURL = coverURL
        self.chapterURL = chapterURL
        self.chapterTitle = chapterTitle
        self.chapterIndex = max(0, chapterIndex)
    }
}

/// Identifies the exact content instance the native ReaderView has displayed.
/// A correlation alone is insufficient: a chapter replacement under the same
/// book.open must never let an earlier Geometry callback resolve the newer
/// chapter's canonical location.
public struct ReaderBookOpenDisplayedContent: Equatable, Hashable, Sendable {
    public let correlationID: String
    public let contentGeneration: Int
    public let bookID: String
    public let chapterIndex: Int
    public let chapterURL: String

    public init(
        correlationID: String,
        contentGeneration: Int,
        bookID: String,
        chapterIndex: Int,
        chapterURL: String
    ) {
        self.correlationID = correlationID
        self.contentGeneration = max(1, contentGeneration)
        self.bookID = bookID
        self.chapterIndex = max(0, chapterIndex)
        self.chapterURL = chapterURL
    }
}

/// The only reader content a Pilot is permitted to render. It is assembled
/// from the executor's typed Core DTOs, not from `ReaderViewModel.loadContent`.
public struct ReaderBookOpenRenderedContent: Equatable {
    public let displayed: ReaderBookOpenDisplayedContent
    public let sourceID: String
    public let toc: [TOCItem]
    public let content: ContentPage

    public init(
        displayed: ReaderBookOpenDisplayedContent,
        sourceID: String,
        toc: [TOCItem],
        content: ContentPage
    ) {
        self.displayed = displayed
        self.sourceID = sourceID
        self.toc = toc
        self.content = content
    }
}

/// UI-facing Pilot projection. A non-nil presentation is an explicit signal
/// for ReaderView to use the Core-owned content branch and skip its legacy
/// loader altogether, including while the Pilot is still loading.
public struct ReaderBookOpenPilotPresentation: Equatable {
    public let correlationID: String
    public let sourceID: String
    public let bookID: String
    public let chapterIndex: Int
    public let chapterURL: String
    public let chapterTitle: String
    public let toc: [TOCItem]
    public let content: ContentPage?
    public let displayed: ReaderBookOpenDisplayedContent?
    public let failure: String?

    public init(
        launch: ReaderBookOpenLaunch,
        toc: [TOCItem] = [],
        content: ContentPage? = nil,
        displayed: ReaderBookOpenDisplayedContent? = nil,
        failure: String? = nil
    ) {
        self.correlationID = launch.correlationID
        self.sourceID = launch.sourceID
        self.bookID = launch.bookID
        self.chapterIndex = launch.requestedChapterIndex
        self.chapterURL = content?.chapterURL ?? launch.chapterURL ?? "pilot://\(launch.bookID)/chapter/\(launch.requestedChapterIndex)"
        self.chapterTitle = content?.title ?? launch.book?.title ?? launch.title
        self.toc = toc
        self.content = content
        self.displayed = displayed
        self.failure = failure
    }

    public init(rendered: ReaderBookOpenRenderedContent) {
        self.correlationID = rendered.displayed.correlationID
        self.sourceID = rendered.sourceID
        self.bookID = rendered.displayed.bookID
        self.chapterIndex = rendered.displayed.chapterIndex
        self.chapterURL = rendered.content.chapterURL
        self.chapterTitle = rendered.content.title
        self.toc = rendered.toc
        self.content = rendered.content
        self.displayed = rendered.displayed
        self.failure = nil
    }

    public var isLoading: Bool { content == nil && failure == nil }

    public func withFailure(_ message: String) -> ReaderBookOpenPilotPresentation {
        ReaderBookOpenPilotPresentation(
            launch: ReaderBookOpenLaunch(
                correlationID: correlationID,
                sourceKind: sourceID == "local" ? .local : .remote,
                sourceID: sourceID,
                bookID: bookID,
                bookURL: bookID,
                title: chapterTitle,
                requestedChapterIndex: chapterIndex,
                chapterURL: chapterURL
            ),
            toc: toc,
            content: content,
            displayed: displayed,
            failure: message
        )
    }
}

/// A value sampled from the actual ReaderView after SwiftUI has committed the
/// rendered chapter and its GeometryReader has a positive viewport.
public struct ReaderBookOpenMeasuredLayout: Equatable, Hashable, Sendable {
    public let chapterOffset: Int
    public let chapterProgress: Double
    public let viewportWidth: Int
    public let viewportHeight: Int
    public let fontScale: Double
    public let pageIndex: Int

    public init(
        chapterOffset: Int,
        chapterProgress: Double,
        viewportWidth: Int,
        viewportHeight: Int,
        fontScale: Double,
        pageIndex: Int = 0
    ) {
        // Preserve raw measurements. The coordinator/runtime rejects invalid
        // values instead of silently turning a 0x0 pre-layout sample into a
        // synthetically valid request.
        self.chapterOffset = chapterOffset
        self.chapterProgress = chapterProgress
        self.viewportWidth = viewportWidth
        self.viewportHeight = viewportHeight
        self.fontScale = fontScale
        self.pageIndex = pageIndex
    }

    var runtimeLayout: ReaderUIBookOpenLayout {
        ReaderUIBookOpenLayout(
            chapterOffset: chapterOffset,
            chapterProgress: chapterProgress,
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            fontScale: fontScale
        )
    }

    var coreLayout: CoreReaderLocationLayout {
        CoreReaderLocationLayout(
            viewportWidth: viewportWidth,
            viewportHeight: viewportHeight,
            fontScale: fontScale,
            pageIndex: pageIndex
        )
    }

    var isValid: Bool {
        chapterOffset >= 0
            && (0...1).contains(chapterProgress)
            && viewportWidth > 0
            && viewportHeight > 0
            && fontScale > 0
            && pageIndex >= 0
    }
}

public enum ReaderBookOpenEffectOutcome: Equatable, Sendable {
    case completed(coreType: String, chapterCount: Int?, displayedContent: ReaderBookOpenDisplayedContent?)
    case completedJSON(coreType: String, result: ReaderUIJSONResult, displayedContent: ReaderBookOpenDisplayedContent?)
    case failed(coreType: String, message: String)
    case discarded
}

/// Narrow seam for focused Pilot tests. The concrete executor below owns the
/// Rust Core handles; tests can inject a deterministic fake without booting
/// Core or starting a URLSession request.
@MainActor
public protocol ReaderBookOpenEffectExecuting: AnyObject {
    func begin(_ launch: ReaderBookOpenLaunch) -> Bool
    func execute(_ effect: ReaderUIEffect) async -> ReaderBookOpenEffectOutcome
    func acceptMeasuredLayout(
        _ layout: ReaderBookOpenMeasuredLayout,
        displayed: ReaderBookOpenDisplayedContent
    ) -> Bool
    func renderedContent(for displayed: ReaderBookOpenDisplayedContent) -> ReaderBookOpenRenderedContent?
    func finish(correlationID: String)
    func cancel(correlationID: String)
}

/// Correlation-scoped Core domain context for the book.open sequence.
///
/// This is deliberately serial on the main actor. It coordinates UI
/// correlation bookkeeping with C-ABI/URLSession request handles, while every
/// long-running command itself remains async. No stage result is written after
/// cancellation, and both remote and Core-materialized local books cover the
/// same typed sequence.
@MainActor
public final class ReaderBookOpenEffectExecutor: ReaderBookOpenEffectExecuting {
    private struct DomainContext {
        let launch: ReaderBookOpenLaunch
        var detail: CoreBookDetailStageResult?
        var toc: CoreTOCStageResult?
        var content: CoreChapterContentStageResult?
        var measuredLayout: ReaderBookOpenMeasuredLayout?
        var resolvedLocation: CoreReaderLocationStageResult?
        var contentGeneration: Int
        var cancelled: Bool
    }

    private let detailService: RustCoreBookDetailService
    private let remoteTOCService: RustCoreTOCService
    private let remoteContentService: RustCoreContentService
    private let localBookService: RustCoreLocalBookService
    private let locationService: RustCoreReaderLocationService
    private var contexts: [String: DomainContext] = [:]
    private var inFlightCancellers: [String: () -> Void] = [:]

    var activeContextCount: Int { contexts.count }

    public init(
        detailService: RustCoreBookDetailService,
        remoteTOCService: RustCoreTOCService,
        remoteContentService: RustCoreContentService,
        localBookService: RustCoreLocalBookService,
        locationService: RustCoreReaderLocationService
    ) {
        self.detailService = detailService
        self.remoteTOCService = remoteTOCService
        self.remoteContentService = remoteContentService
        self.localBookService = localBookService
        self.locationService = locationService
    }

    /// Production construction is intentionally explicit: callers must have
    /// already booted Core, rather than a UI Pilot silently booting or changing
    /// the existing reader authority path.
    public convenience init(runtime: ReaderCoreNativeRuntime, requestTimeout: TimeInterval = 15) {
        let router = RustCoreServiceSupport.makeRouter(runtime: runtime)
        self.init(
            detailService: RustCoreBookDetailService(runtime: runtime, router: router, requestTimeout: requestTimeout),
            remoteTOCService: RustCoreTOCService(runtime: runtime, router: router, requestTimeout: requestTimeout),
            remoteContentService: RustCoreContentService(runtime: runtime, router: router, requestTimeout: requestTimeout),
            localBookService: RustCoreLocalBookService(runtime: runtime, requestTimeout: requestTimeout),
            locationService: RustCoreReaderLocationService(runtime: runtime, requestTimeout: requestTimeout)
        )
    }

    public func begin(_ launch: ReaderBookOpenLaunch) -> Bool {
        guard !launch.correlationID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !launch.bookID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !launch.sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }
        if contexts[launch.correlationID] != nil {
            return false
        }
        contexts[launch.correlationID] = DomainContext(
            launch: launch,
            detail: nil,
            toc: nil,
            content: nil,
            measuredLayout: nil,
            resolvedLocation: nil,
            contentGeneration: 0,
            cancelled: false
        )
        return true
    }

    public func execute(_ effect: ReaderUIEffect) async -> ReaderBookOpenEffectOutcome {
        guard effect.kind == .core,
              let correlationID = effect.correlationId,
              isActive(correlationID) else {
            return .discarded
        }

        switch effect.type {
        case "source.detail":
            return await executeDetail(correlationID: correlationID)
        case "chapter.list":
            return await executeTOC(correlationID: correlationID)
        case "content.load":
            return await executeContent(correlationID: correlationID, effect: effect)
        case "reader.location.resolve":
            return await executeLocation(correlationID: correlationID)
        default:
            return .failed(coreType: effect.type, message: "BOOK_OPEN_UNSUPPORTED_STAGE")
        }
    }

    public func acceptMeasuredLayout(
        _ layout: ReaderBookOpenMeasuredLayout,
        displayed: ReaderBookOpenDisplayedContent
    ) -> Bool {
        guard layout.isValid,
              var context = contexts[displayed.correlationID],
              !context.cancelled,
              context.contentGeneration == displayed.contentGeneration,
              let content = context.content,
              content.bookID == displayed.bookID,
              content.chapterIndex == displayed.chapterIndex,
              content.chapterURL == displayed.chapterURL else {
            return false
        }
        context.measuredLayout = layout
        contexts[displayed.correlationID] = context
        return true
    }

    public func renderedContent(for displayed: ReaderBookOpenDisplayedContent) -> ReaderBookOpenRenderedContent? {
        guard let context = contexts[displayed.correlationID],
              !context.cancelled,
              context.contentGeneration == displayed.contentGeneration,
              let toc = context.toc,
              let content = context.content,
              content.bookID == displayed.bookID,
              content.chapterIndex == displayed.chapterIndex,
              content.chapterURL == displayed.chapterURL else {
            return nil
        }
        return ReaderBookOpenRenderedContent(
            displayed: displayed,
            sourceID: content.sourceID ?? (context.launch.sourceKind == .local ? "local" : context.launch.sourceID),
            toc: toc.items,
            content: content.page
        )
    }

    public func cancel(correlationID: String) {
        guard var context = contexts[correlationID], !context.cancelled else { return }
        context.cancelled = true
        let cancel = inFlightCancellers.removeValue(forKey: correlationID)
        cancel?()
        // Remove the domain record after signalling the real Core/Host handle.
        // Any late await observes no active context and is discarded; a future
        // intentional reuse of this correlation starts from a clean context.
        contexts.removeValue(forKey: correlationID)
    }

    /// Terminal success cleanup is intentionally distinct from cancellation:
    /// it never calls Core cancel after a completed location result, but still
    /// drops the per-correlation DTO/handle ledger and permits safe id reuse.
    public func finish(correlationID: String) {
        inFlightCancellers[correlationID] = nil
        contexts.removeValue(forKey: correlationID)
    }

    private func executeDetail(correlationID: String) async -> ReaderBookOpenEffectOutcome {
        guard let context = contexts[correlationID] else { return .discarded }
        do {
            let handle: RustCoreRequestScopedCommand<CoreBookDetailStageResult>
            if let source = context.launch.source, let book = context.launch.book {
                // This compatibility path remains useful for an explicit
                // source-selection flow, but bookshelf admission does not
                // manufacture either DTO.
                handle = try detailService.startDetailStage(
                    source: source,
                    book: book,
                    correlationID: correlationID
                )
            } else {
                handle = try detailService.startDetailStage(
                    sourceID: context.launch.sourceID,
                    bookID: context.launch.bookID,
                    bookURL: context.launch.bookURL,
                    title: context.launch.book?.title ?? context.launch.title,
                    author: context.launch.book?.author ?? context.launch.author,
                    coverURL: context.launch.book?.coverURL ?? context.launch.coverURL,
                    correlationID: correlationID
                )
            }
            let detail = try await awaitValue(handle, correlationID: correlationID)
            guard isActive(correlationID), var updated = contexts[correlationID] else { return .discarded }
            updated.detail = detail
            contexts[correlationID] = updated
            return .completedJSON(coreType: "source.detail", result: [:], displayedContent: nil)
        } catch is CancellationError {
            return .discarded
        } catch {
            return isActive(correlationID)
                ? .failed(coreType: "source.detail", message: error.localizedDescription)
                : .discarded
        }
    }

    private func executeTOC(correlationID: String) async -> ReaderBookOpenEffectOutcome {
        guard let context = contexts[correlationID] else { return .discarded }
        do {
            let toc: CoreTOCStageResult
            switch context.launch.sourceKind {
            case .local:
                let handle = try localBookService.startTOCStage(
                    bookID: context.launch.bookID,
                    correlationID: correlationID
                )
                toc = try await awaitValue(handle, correlationID: correlationID)
            case .remote:
                guard let detail = context.detail,
                      let tocURL = detail.tocURL,
                      !tocURL.isEmpty else {
                    return .failed(coreType: "chapter.list", message: "REMOTE_TOC_CONTEXT_MISSING")
                }
                let handle: RustCoreRequestScopedCommand<CoreTOCStageResult>
                if let source = context.launch.source {
                    handle = try remoteTOCService.startTOCStage(
                        source: source,
                        bookID: detail.bookID,
                        tocURL: tocURL,
                        variables: detail.variables,
                        correlationID: correlationID
                    )
                } else {
                    handle = try remoteTOCService.startTOCStage(
                        sourceID: context.launch.sourceID,
                        bookID: detail.bookID,
                        tocURL: tocURL,
                        variables: detail.variables,
                        correlationID: correlationID
                    )
                }
                toc = try await awaitValue(handle, correlationID: correlationID)
            }
            guard isActive(correlationID), var updated = contexts[correlationID] else { return .discarded }
            updated.toc = toc
            contexts[correlationID] = updated
            return .completedJSON(
                coreType: "chapter.list",
                result: ["chapterCount": .number(Double(toc.entries.count))],
                displayedContent: nil
            )
        } catch is CancellationError {
            return .discarded
        } catch {
            return isActive(correlationID)
                ? .failed(coreType: "chapter.list", message: error.localizedDescription)
                : .discarded
        }
    }

    private func executeContent(
        correlationID: String,
        effect: ReaderUIEffect
    ) async -> ReaderBookOpenEffectOutcome {
        guard let context = contexts[correlationID],
              let toc = context.toc,
              !toc.entries.isEmpty else {
            return .failed(coreType: "content.load", message: "BOOK_OPEN_TOC_CONTEXT_MISSING")
        }
        let requestedOffset = max(0, effect.jsonPayload["chapterIndex"]?.intValue ?? 0)
        let entry = toc.entries[min(requestedOffset, toc.entries.count - 1)]
        do {
            let content: CoreChapterContentStageResult
            switch context.launch.sourceKind {
            case .local:
                let handle = try localBookService.startContentStage(
                    bookID: toc.bookID ?? context.launch.bookID,
                    chapterIndex: entry.item.chapterIndex,
                    chapterURL: entry.item.chapterURL,
                    correlationID: correlationID
                )
                content = try await awaitValue(handle, correlationID: correlationID)
            case .remote:
                guard let detail = context.detail else {
                    return .failed(coreType: "content.load", message: "REMOTE_CONTENT_CONTEXT_MISSING")
                }
                let contentContext = toc.contentRequestContext(
                    for: entry,
                    detailVariables: detail.variables
                ) ?? CoreChapterContentRequestContext(
                    bookID: detail.bookID,
                    chapterTitle: entry.item.chapterTitle,
                    chapterIndex: entry.item.chapterIndex,
                    chapterURL: entry.item.chapterURL,
                    variables: detail.variables.merging(entry.variables, uniquingKeysWith: { _, entryValue in entryValue })
                )
                let handle: RustCoreRequestScopedCommand<CoreChapterContentStageResult>
                if let source = context.launch.source {
                    handle = try remoteContentService.startContentStage(
                        source: source,
                        context: contentContext,
                        correlationID: correlationID
                    )
                } else {
                    handle = try remoteContentService.startContentStage(
                        sourceID: context.launch.sourceID,
                        context: contentContext,
                        correlationID: correlationID
                    )
                }
                content = try await awaitValue(handle, correlationID: correlationID)
            }
            guard isActive(correlationID), var updated = contexts[correlationID] else { return .discarded }
            updated.content = content
            updated.contentGeneration += 1
            contexts[correlationID] = updated
            let displayed = ReaderBookOpenDisplayedContent(
                correlationID: correlationID,
                contentGeneration: updated.contentGeneration,
                bookID: content.bookID,
                chapterIndex: content.chapterIndex,
                chapterURL: content.chapterURL
            )
            return .completedJSON(coreType: "content.load", result: [:], displayedContent: displayed)
        } catch is CancellationError {
            return .discarded
        } catch {
            return isActive(correlationID)
                ? .failed(coreType: "content.load", message: error.localizedDescription)
                : .discarded
        }
    }

    private func executeLocation(correlationID: String) async -> ReaderBookOpenEffectOutcome {
        guard let context = contexts[correlationID],
              let content = context.content,
              let layout = context.measuredLayout else {
            return .failed(coreType: "reader.location.resolve", message: "BOOK_OPEN_LAYOUT_CONTEXT_MISSING")
        }
        let request = CoreReaderLocationStageRequest(
            sourceID: context.launch.sourceKind == .local ? "local" : (content.sourceID ?? context.launch.sourceID),
            bookID: content.bookID,
            chapterIndex: content.chapterIndex,
            chapterTitle: content.chapterTitle,
            chapterOffset: layout.chapterOffset,
            chapterProgress: layout.chapterProgress,
            layout: layout.coreLayout
        )
        do {
            let handle = try locationService.startResolveStage(request, correlationID: correlationID)
            let resolvedLocation = try await awaitValue(handle, correlationID: correlationID)
            guard isActive(correlationID),
                  var updated = contexts[correlationID],
                  let currentContent = updated.content else {
                return .discarded
            }
            do {
                try Self.validateResolvedLocation(resolvedLocation, matches: currentContent)
            } catch {
                // Do not let a syntactically successful result for a different
                // book/chapter complete Reader-UI's transaction. Returning a
                // terminal error makes the coordinator cancel the correlation
                // rather than call `finish(correlationID:)`.
                return .failed(
                    coreType: "reader.location.resolve",
                    message: "BOOK_OPEN_LOCATION_IDENTITY_MISMATCH: \(error.localizedDescription)"
                )
            }
            // Retain the accepted canonical location until terminal runtime
            // acceptance. This deliberately consumes the Core result instead
            // of treating a successful response as a fire-and-forget ack.
            updated.resolvedLocation = resolvedLocation
            contexts[correlationID] = updated
            // The coordinator calls `finish(correlationID:)` after Reader-UI
            // accepts this terminal result. That ordering keeps domain and UI
            // transaction state in lockstep.
            let rawResult: ReaderUIJSONResult = [
                "canonicalLocation": .string(resolvedLocation.locationRevision),
                "pageIndex": .number(Double(layout.pageIndex)),
            ]
            let result = try ReaderUIJSONBridge.projectTypedResult(
                event: "book.open",
                effectType: "reader.location.resolve",
                rawResult: rawResult
            )
            return .completedJSON(
                coreType: "reader.location.resolve",
                result: result,
                displayedContent: nil
            )
        } catch is CancellationError {
            return .discarded
        } catch {
            return isActive(correlationID)
                ? .failed(coreType: "reader.location.resolve", message: error.localizedDescription)
                : .discarded
        }
    }

    private func awaitValue<Value: Sendable>(
        _ handle: RustCoreRequestScopedCommand<Value>,
        correlationID: String
    ) async throws -> Value {
        inFlightCancellers[correlationID] = { _ = handle.cancel() }
        defer {
            // A replacement may have installed a different handle only after
            // this await returns. Remove only this stage's known slot.
            inFlightCancellers[correlationID] = nil
        }
        return try await handle.value()
    }

    private func isActive(_ correlationID: String) -> Bool {
        contexts[correlationID]?.cancelled == false
    }

    /// Core's resolver is allowed to canonicalize the anchor, but never to
    /// change the visible content identity. Keeping this check in the executor
    /// (rather than in the SwiftUI view) makes a late/wrong Core completion a
    /// terminal correlation failure on every rendering path.
    static func validateResolvedLocation(
        _ resolved: CoreReaderLocationStageResult,
        matches content: CoreChapterContentStageResult
    ) throws {
        guard resolved.bookID == content.bookID else {
            throw ReaderCoreNativeError.coreError(
                code: "LOCATION_BOOK_ID_DRIFT",
                message: "expected bookId \(content.bookID), got \(resolved.bookID)"
            )
        }
        guard resolved.chapterIndex == content.chapterIndex else {
            throw ReaderCoreNativeError.coreError(
                code: "LOCATION_CHAPTER_INDEX_DRIFT",
                message: "expected chapterIndex \(content.chapterIndex), got \(resolved.chapterIndex)"
            )
        }
    }
}

/// Executes Reader-UI's generated book.open sequence only when an explicitly
/// injected pilot configuration opts in. `live` is Pilot in lockstep with the
/// `book-open-pilot` consumer cohort, so merely constructing this coordinator
/// does not bypass the consumer lock authority.
@MainActor
public final class ReaderBookOpenPilotCoordinator: ObservableObject {
    public let configuration: ReaderBookOpenPilotConfiguration
    private let runtime: ReaderUIRuntime
    private let executor: (any ReaderBookOpenEffectExecuting)?
    private let launchResolver: ((ReaderBookOpenEntry) -> ReaderBookOpenLaunch?)?

    @Published public private(set) var displayedContent: ReaderBookOpenDisplayedContent?
    @Published public private(set) var presentation: ReaderBookOpenPilotPresentation?
    @Published public private(set) var lastFailure: String?

    public init(
        configuration: ReaderBookOpenPilotConfiguration = .live,
        runtime: ReaderUIRuntime = ReaderUIRuntime(),
        executor: (any ReaderBookOpenEffectExecuting)? = nil,
        launchResolver: ((ReaderBookOpenEntry) -> ReaderBookOpenLaunch?)? = nil
    ) {
        self.configuration = configuration
        self.runtime = runtime
        self.executor = executor
        self.launchResolver = launchResolver
    }

    public var activeCorrelationID: String? {
        runtime.state.bookOpenTransaction?.correlationId
    }

    /// The real bookshelf entry path calls this synchronously before it chooses
    /// the legacy ReaderView loader. In production the Pilot config with a nil
    /// resolver still returns false, so the established native path stays
    /// authoritative until a resolver backed by exact Core-domain identities
    /// is injected.
    @discardableResult
    public func begin(from entry: ReaderBookOpenEntry) -> Bool {
        guard let launch = launchResolver?(entry), let effects = prepare(launch) else {
            return false
        }
        Task { [weak self] in
            await self?.execute(effects)
        }
        return true
    }

    @discardableResult
    public func begin(_ launch: ReaderBookOpenLaunch) async -> Bool {
        guard let effects = prepare(launch) else { return false }
        await execute(effects)
        return true
    }

    /// Called only from ReaderView after the displayed context, content state,
    /// and GeometryReader all agree. A stale layout is rejected before it can
    /// mutate either the Core domain context or Reader-UI runtime transaction.
    public func provideMeasuredLayout(
        _ layout: ReaderBookOpenMeasuredLayout,
        displayed: ReaderBookOpenDisplayedContent
    ) async {
        guard configuration.mode == .pilot,
              let executor,
              layout.isValid,
              displayedContent == displayed,
              runtime.state.bookOpenTransaction?.correlationId == displayed.correlationID,
              executor.acceptMeasuredLayout(layout, displayed: displayed) else {
            return
        }
        do {
            let transition = try runtime.provideBookOpenLayout(
                correlationId: displayed.correlationID,
                layout: layout.runtimeLayout
            )
            guard transition.accepted else { return }
            await execute(transition.effects)
        } catch {
            lastFailure = error.localizedDescription
        }
    }

    public func cancel(correlationID: String) {
        guard configuration.mode == .pilot, let executor else { return }
        let transition = runtime.cancelBookOpen(correlationId: correlationID)
        if transition.accepted {
            executor.cancel(correlationID: correlationID)
        }
        if displayedContent?.correlationID == correlationID { displayedContent = nil }
        if presentation?.correlationID == correlationID { presentation = nil }
    }

    private func prepare(_ launch: ReaderBookOpenLaunch) -> [ReaderUIEffect]? {
        guard configuration.mode == .pilot, let executor, executor.begin(launch) else {
            return nil
        }
        do {
            let transition = try runtime.dispatch(
                event: "book.open",
                jsonPayload: launch.runtimePayload,
                correlationId: launch.correlationID
            )
            for cancelledID in transition.cancelledCorrelationIds {
                executor.cancel(correlationID: cancelledID)
                if displayedContent?.correlationID == cancelledID { displayedContent = nil }
                if presentation?.correlationID == cancelledID { presentation = nil }
            }
            displayedContent = nil
            presentation = ReaderBookOpenPilotPresentation(launch: launch)
            lastFailure = nil
            return transition.effects
        } catch {
            executor.cancel(correlationID: launch.correlationID)
            lastFailure = error.localizedDescription
            return nil
        }
    }

    private func execute(_ effects: [ReaderUIEffect]) async {
        guard let executor else { return }
        for effect in effects {
            let outcome = await executor.execute(effect)
            guard let correlationID = effect.correlationId else { continue }
            switch outcome {
            case .discarded:
                // Cancellation/replacement has already invalidated this
                // correlation. Do not feed a late result into Reader-UI.
                continue
            case .failed(let coreType, let message):
                let transition: ReaderUIAsyncTransition
                do {
                    let result = try ReaderUIJSONBridge.projectTypedResult(
                        event: "book.open",
                        effectType: coreType,
                        rawResult: ["error": .string(message)]
                    )
                    transition = try runtime.acceptBookOpenJSONResult(
                        coreType: coreType,
                        correlationId: correlationID,
                        result: result
                    )
                } catch {
                    executor.cancel(correlationID: correlationID)
                    lastFailure = error.localizedDescription
                    return
                }
                if transition.accepted {
                    executor.cancel(correlationID: correlationID)
                    if displayedContent?.correlationID == correlationID { displayedContent = nil }
                    if presentation?.correlationID == correlationID {
                        presentation = presentation?.withFailure(message)
                    }
                    lastFailure = message
                }
            case .completed(let coreType, let chapterCount, let displayed):
                let transition = runtime.acceptBookOpenResult(
                    coreType: coreType,
                    correlationId: correlationID,
                    chapterCount: chapterCount
                )
                guard transition.accepted else {
                    executor.cancel(correlationID: correlationID)
                    continue
                }
                if let displayed {
                    displayedContent = displayed
                    guard let rendered = executor.renderedContent(for: displayed) else {
                        executor.cancel(correlationID: correlationID)
                        _ = runtime.cancelBookOpen(correlationId: correlationID)
                        if presentation?.correlationID == correlationID {
                            presentation = presentation?.withFailure("BOOK_OPEN_RENDER_CONTEXT_MISSING")
                        }
                        lastFailure = "BOOK_OPEN_RENDER_CONTEXT_MISSING"
                        return
                    }
                    presentation = ReaderBookOpenPilotPresentation(rendered: rendered)
                }
                if transition.state.bookOpenTransaction == nil {
                    executor.finish(correlationID: correlationID)
                }
                await execute(transition.effects)
            case .completedJSON(let coreType, let rawResult, let displayed):
                let transition: ReaderUIAsyncTransition
                do {
                    let result = try ReaderUIJSONBridge.projectTypedResult(
                        event: "book.open",
                        effectType: coreType,
                        rawResult: rawResult
                    )
                    transition = try runtime.acceptBookOpenJSONResult(
                        coreType: coreType,
                        correlationId: correlationID,
                        result: result
                    )
                } catch {
                    executor.cancel(correlationID: correlationID)
                    lastFailure = error.localizedDescription
                    return
                }
                guard transition.accepted else {
                    executor.cancel(correlationID: correlationID)
                    continue
                }
                if let displayed {
                    displayedContent = displayed
                    guard let rendered = executor.renderedContent(for: displayed) else {
                        executor.cancel(correlationID: correlationID)
                        _ = runtime.cancelBookOpen(correlationId: correlationID)
                        if presentation?.correlationID == correlationID {
                            presentation = presentation?.withFailure("BOOK_OPEN_RENDER_CONTEXT_MISSING")
                        }
                        lastFailure = "BOOK_OPEN_RENDER_CONTEXT_MISSING"
                        return
                    }
                    presentation = ReaderBookOpenPilotPresentation(rendered: rendered)
                }
                if transition.state.bookOpenTransaction == nil {
                    executor.finish(correlationID: correlationID)
                }
                await execute(transition.effects)
            }
        }
    }
}
