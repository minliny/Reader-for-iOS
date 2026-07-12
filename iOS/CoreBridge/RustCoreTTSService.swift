import CoreFoundation
import Foundation
import ReaderCoreNativeAdapter

public struct CoreTTSChapterReference: Equatable, Sendable {
    public let sourceID: String
    public let bookID: String
    public let chapterIndex: Int
    public let chapterTitle: String
    public let chapterURL: String

    public init(
        sourceID: String,
        bookID: String,
        chapterIndex: Int,
        chapterTitle: String = "",
        chapterURL: String = ""
    ) {
        self.sourceID = sourceID
        self.bookID = bookID
        self.chapterIndex = chapterIndex
        self.chapterTitle = chapterTitle
        self.chapterURL = chapterURL
    }

    fileprivate var object: [String: Any] {
        var value: [String: Any] = [
            "sourceId": sourceID,
            "bookId": bookID,
            "chapterIndex": chapterIndex,
        ]
        if !chapterTitle.isEmpty { value["chapterTitle"] = chapterTitle }
        if !chapterURL.isEmpty { value["chapterUrl"] = chapterURL }
        return value
    }
}

public enum CoreTTSSlicingStrategy: String, Equatable, Sendable {
    case paragraph
    case sentence
    case paragraphThenSentence = "paragraph-then-sentence"
    case lineBreak = "line-break"
}

public struct CoreTTSSlice: Equatable, Sendable {
    public let index: Int
    public let text: String
    public let charStart: Int
    public let charEnd: Int
    public let paragraphIndex: Int

    public init(index: Int, text: String, charStart: Int, charEnd: Int, paragraphIndex: Int) {
        self.index = index
        self.text = text
        self.charStart = charStart
        self.charEnd = charEnd
        self.paragraphIndex = paragraphIndex
    }

    fileprivate var object: [String: Any] {
        [
            "index": index,
            "text": text,
            "charStart": charStart,
            "charEnd": charEnd,
            "paragraphIndex": paragraphIndex,
        ]
    }
}

public struct CoreTTSSlicePlan: Equatable, Sendable {
    public let chapter: CoreTTSChapterReference
    public let strategy: CoreTTSSlicingStrategy
    public let slices: [CoreTTSSlice]
    public let sourceCharCount: Int

    public init(
        chapter: CoreTTSChapterReference,
        strategy: CoreTTSSlicingStrategy,
        slices: [CoreTTSSlice],
        sourceCharCount: Int
    ) {
        self.chapter = chapter
        self.strategy = strategy
        self.slices = slices
        self.sourceCharCount = sourceCharCount
    }

    fileprivate var object: [String: Any] {
        [
            "chapter": chapter.object,
            "strategy": strategy.rawValue,
            "slices": slices.map(\.object),
            "sourceCharCount": sourceCharCount,
        ]
    }
}

public enum CoreTTSQueueState: String, Equatable, Sendable {
    case idle
    case playing
    case paused
    case completed
    case stopped
}

public enum CoreTTSSliceStatus: String, Equatable, Sendable {
    case pending
    case speaking
    case done
    case skipped
    case failed
}

public struct CoreTTSQueueSnapshot: Equatable, Sendable {
    public let state: CoreTTSQueueState
    public let currentSliceIndex: Int?
    public let totalSlices: Int
    public let completedSlices: Int
    public let chapter: CoreTTSChapterReference
    public let sliceStatuses: [CoreTTSSliceStatus]

    public init(
        state: CoreTTSQueueState,
        currentSliceIndex: Int?,
        totalSlices: Int,
        completedSlices: Int,
        chapter: CoreTTSChapterReference,
        sliceStatuses: [CoreTTSSliceStatus]
    ) {
        self.state = state
        self.currentSliceIndex = currentSliceIndex
        self.totalSlices = totalSlices
        self.completedSlices = completedSlices
        self.chapter = chapter
        self.sliceStatuses = sliceStatuses
    }
}

/// Typed, request-scoped bridge for the R8 TTS transaction.
///
/// Reader-UI names the semantic stages `tts.queue.plan` and
/// `tts.queue.start`; Core's concrete methods remain `tts.slice` and
/// `tts.queue.play`. Keeping that mapping here prevents a native view or
/// reducer from constructing Core queue JSON or polling the C ABI directly.
public final class RustCoreTTSService: @unchecked Sendable {
    private let runtime: any RustCoreCommandRuntime
    private let router: (any RustCoreHostRequestRouting)?
    private let requestTimeout: TimeInterval

    public init(
        runtime: any RustCoreCommandRuntime,
        router: (any RustCoreHostRequestRouting)? = nil,
        requestTimeout: TimeInterval = 15
    ) {
        self.runtime = runtime
        self.router = router
        self.requestTimeout = requestTimeout
    }

    public convenience init(
        runtime: ReaderCoreNativeRuntime,
        requestTimeout: TimeInterval = 15
    ) {
        self.init(
            runtime: runtime,
            router: RustCoreServiceSupport.makeRouter(runtime: runtime),
            requestTimeout: requestTimeout
        )
    }

    public func startPlanStage(
        chapter: CoreTTSChapterReference,
        content: String,
        strategy: CoreTTSSlicingStrategy = .paragraph,
        correlationID: String
    ) throws -> RustCoreRequestScopedCommand<CoreTTSSlicePlan> {
        try validate(chapter)
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw invalid("tts.slice requires non-empty chapter content")
        }
        return try start(
            method: "tts.slice",
            params: [
                "chapter": chapter.object,
                "content": content,
                "strategy": strategy.rawValue,
            ],
            correlationID: correlationID,
            transform: Self.parsePlan
        )
    }

    public func startQueueStage(
        plan: CoreTTSSlicePlan,
        startSliceIndex: Int = 0,
        correlationID: String
    ) throws -> RustCoreRequestScopedCommand<CoreTTSQueueSnapshot> {
        guard !plan.slices.isEmpty,
              plan.slices.indices.contains(startSliceIndex) else {
            throw invalid("tts.queue.play requires a non-empty plan and valid startSliceIndex")
        }
        return try start(
            method: "tts.queue.play",
            params: [
                "plan": plan.object,
                "startSliceIndex": startSliceIndex,
            ],
            correlationID: correlationID,
            transform: Self.parseSnapshotEnvelope
        )
    }

    public func startReportDoneStage(
        chapter: CoreTTSChapterReference,
        sliceIndex: Int,
        correlationID: String
    ) throws -> RustCoreRequestScopedCommand<CoreTTSQueueSnapshot> {
        try validate(chapter)
        guard sliceIndex >= 0 else { throw invalid("tts.queue.report-status requires a valid sliceIndex") }
        return try start(
            method: "tts.queue.report-status",
            params: [
                "chapter": chapter.object,
                "sliceIndex": sliceIndex,
                "status": "done",
            ],
            correlationID: correlationID,
            transform: Self.parseSnapshotEnvelope
        )
    }

    public func startNextStage(
        chapter: CoreTTSChapterReference,
        correlationID: String
    ) throws -> RustCoreRequestScopedCommand<CoreTTSQueueSnapshot> {
        try validate(chapter)
        return try start(
            method: "tts.queue.next",
            params: ["chapter": chapter.object],
            correlationID: correlationID,
            transform: Self.parseSnapshotEnvelope
        )
    }

    public func startStopStage(
        chapter: CoreTTSChapterReference,
        correlationID: String
    ) throws -> RustCoreRequestScopedCommand<CoreTTSQueueSnapshot> {
        try validate(chapter)
        return try start(
            method: "tts.queue.stop",
            params: ["chapter": chapter.object],
            correlationID: correlationID,
            transform: Self.parseSnapshotEnvelope
        )
    }

    private func start<Value: Sendable>(
        method: String,
        params: [String: Any],
        correlationID: String,
        transform: @escaping ([String: Any]?) throws -> Value
    ) throws -> RustCoreRequestScopedCommand<Value> {
        let handle = try RustCoreRequestScopedCommand<Value>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: method,
            params: params,
            timeout: requestTimeout,
            resultTransform: transform
        )
        try handle.start()
        return handle
    }

    private func validate(_ chapter: CoreTTSChapterReference) throws {
        guard !chapter.sourceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !chapter.bookID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              chapter.chapterIndex >= 0 else {
            throw invalid("TTS chapter identity is incomplete")
        }
    }

    static func parsePlan(_ data: [String: Any]?) throws -> CoreTTSSlicePlan {
        guard let plan = data?["plan"] as? [String: Any],
              let chapter = parseChapter(plan["chapter"]),
              let strategyValue = nonBlankString(plan["strategy"]),
              let strategy = CoreTTSSlicingStrategy(rawValue: strategyValue),
              let sliceObjects = plan["slices"] as? [[String: Any]],
              !sliceObjects.isEmpty,
              let sourceCharCount = nonNegativeInteger(plan["sourceCharCount"]) else {
            throw invalidStatic("tts.slice result is incomplete")
        }
        let slices = try sliceObjects.enumerated().map { offset, value -> CoreTTSSlice in
            guard let index = nonNegativeInteger(value["index"]),
                  index == offset,
                  let text = nonBlankString(value["text"]),
                  let charStart = nonNegativeInteger(value["charStart"]),
                  let charEnd = nonNegativeInteger(value["charEnd"]),
                  charEnd > charStart,
                  let paragraphIndex = nonNegativeInteger(value["paragraphIndex"]) else {
                throw invalidStatic("tts.slice returned an invalid or sparse slice plan")
            }
            return CoreTTSSlice(
                index: index,
                text: text,
                charStart: charStart,
                charEnd: charEnd,
                paragraphIndex: paragraphIndex
            )
        }
        guard sourceCharCount >= slices.last?.charEnd ?? 0 else {
            throw invalidStatic("tts.slice sourceCharCount does not cover its slices")
        }
        return CoreTTSSlicePlan(
            chapter: chapter,
            strategy: strategy,
            slices: slices,
            sourceCharCount: sourceCharCount
        )
    }

    static func parseSnapshotEnvelope(_ data: [String: Any]?) throws -> CoreTTSQueueSnapshot {
        guard let snapshot = data?["snapshot"] as? [String: Any] else {
            throw invalidStatic("TTS queue result has no snapshot")
        }
        return try parseSnapshot(snapshot)
    }

    static func parseSnapshot(_ value: [String: Any]) throws -> CoreTTSQueueSnapshot {
        guard let stateValue = nonBlankString(value["state"]),
              let state = CoreTTSQueueState(rawValue: stateValue),
              let totalSlices = nonNegativeInteger(value["totalSlices"]),
              let completedSlices = nonNegativeInteger(value["completedSlices"]),
              completedSlices <= totalSlices,
              let chapter = parseChapter(value["chapter"]) else {
            throw invalidStatic("TTS queue snapshot is incomplete")
        }
        let currentSliceIndex: Int?
        if value["currentSliceIndex"] == nil || value["currentSliceIndex"] is NSNull {
            currentSliceIndex = nil
        } else {
            guard let parsed = nonNegativeInteger(value["currentSliceIndex"]), parsed < totalSlices else {
                throw invalidStatic("TTS queue currentSliceIndex is invalid")
            }
            currentSliceIndex = parsed
        }
        let statusValues = value["sliceStatuses"] as? [String] ?? []
        let statuses = try statusValues.map { raw -> CoreTTSSliceStatus in
            guard let status = CoreTTSSliceStatus(rawValue: raw) else {
                throw invalidStatic("TTS queue contains an unknown slice status")
            }
            return status
        }
        guard statuses.isEmpty || statuses.count == totalSlices else {
            throw invalidStatic("TTS queue sliceStatuses length does not match totalSlices")
        }
        return CoreTTSQueueSnapshot(
            state: state,
            currentSliceIndex: currentSliceIndex,
            totalSlices: totalSlices,
            completedSlices: completedSlices,
            chapter: chapter,
            sliceStatuses: statuses
        )
    }

    private static func parseChapter(_ value: Any?) -> CoreTTSChapterReference? {
        guard let value = value as? [String: Any],
              let sourceID = nonBlankString(value["sourceId"]),
              let bookID = nonBlankString(value["bookId"]),
              let chapterIndex = nonNegativeInteger(value["chapterIndex"]) else {
            return nil
        }
        return CoreTTSChapterReference(
            sourceID: sourceID,
            bookID: bookID,
            chapterIndex: chapterIndex,
            chapterTitle: value["chapterTitle"] as? String ?? "",
            chapterURL: value["chapterUrl"] as? String ?? ""
        )
    }

    private static func nonNegativeInteger(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber,
              CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let double = number.doubleValue
        guard double.isFinite,
              double >= 0,
              double.rounded(.towardZero) == double,
              double <= Double(Int.max) else { return nil }
        return Int(double)
    }

    private static func nonBlankString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func invalid(_ message: String) -> ReaderCoreNativeError {
        Self.invalidStatic(message)
    }

    private static func invalidStatic(_ message: String) -> ReaderCoreNativeError {
        .coreError(code: "INVALID_TTS_RESULT", message: message)
    }
}
