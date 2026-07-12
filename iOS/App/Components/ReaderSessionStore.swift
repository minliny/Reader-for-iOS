import Foundation

// MARK: - ReaderSessionPhase

/// 阅读会话状态。
///
/// 对照 demo `MOTION_CONTRACT.md` 中 `reader.session.*` / `app.route` 的 session
/// lifecycle 契约，将运行会话归并为 5 态。状态转移由 `ReaderSessionStore` 驱动，
/// 并与 `AsyncResultGuard` 协同保证异步回调的 requestId 校验。
///
/// clean-room：只承载契约状态语义，不复制 Web DOM / `data-*` selector 实现。
public enum ReaderSessionPhase: String, Sendable, Equatable {
    /// 无活动会话。
    case idle
    /// 加载中（章节内容 / 书源搜索 / 目录请求进行中）。
    case loading
    /// 阅读中。
    case reading
    /// 暂停（用户切出 / 网络中断）。
    case paused
    /// 错误态。
    case error
}

// MARK: - ReaderSessionContext

/// 会话上下文。
///
/// 承载单次阅读会话的锚点信息（书籍 / 章节 / 书源）与运行态（phase / lastError /
/// currentRequestId）。`currentRequestId` 用于 `AsyncResultGuard` 校验异步回调。
public struct ReaderSessionContext: Sendable, Equatable {
    /// 会话 ID（一次 startSession 对应一个 sessionId）。
    public let sessionId: UUID
    /// 书籍 ID。
    public let bookId: String
    /// 当前章节 URL。
    public let chapterURL: String
    /// 书源 ID（可选，本地书无书源）。
    public let sourceId: String?
    /// 会话启动时间。
    public let startedAt: Date
    /// 当前会话状态。
    public var phase: ReaderSessionPhase
    /// 最近一次错误（error 态承载，retry / resume 时清空）。
    public var lastError: StateError?
    /// 当前异步请求 ID，用于 `AsyncResultGuard` 校验。
    public var currentRequestId: UUID?

    public init(
        sessionId: UUID = UUID(),
        bookId: String,
        chapterURL: String,
        sourceId: String? = nil,
        startedAt: Date = Date(),
        phase: ReaderSessionPhase = .idle,
        lastError: StateError? = nil,
        currentRequestId: UUID? = nil
    ) {
        self.sessionId = sessionId
        self.bookId = bookId
        self.chapterURL = chapterURL
        self.sourceId = sourceId
        self.startedAt = startedAt
        self.phase = phase
        self.lastError = lastError
        self.currentRequestId = currentRequestId
    }
}

// MARK: - ReaderSessionStore

/// 会话级状态存储。
///
/// 整合 `AsyncResultGuard` + `MotionController`，提供 session-scoped 异步结果管理：
/// - `startSession`：supersede 旧请求（latest intent wins），phase → `.loading`
/// - `completeLoading`：校验 requestId 仍 pending，complete 后 phase → `.reading`
/// - `endSession`：discard 旧请求，phase → `.idle`
/// - `reportError`：phase → `.error`，保留 currentSession 允许 retry
/// - `retry`：supersede 旧 requestId，phase → `.loading`，返回新 requestId
///
/// 对照 demo `motion-controller.js` 中 AsyncResultGuard 的使用模式：异步回调返回时
/// 通过 `isValid(requestId:)` 校验当前会话是否仍匹配，避免过期结果覆盖新会话。
///
/// clean-room：只承载状态机语义，不复制 Web route stack / `data-*` selector 实现。
@MainActor
public final class ReaderSessionStore: ObservableObject {
    /// 当前活动会话上下文。`nil` 表示无活动会话。
    @Published public private(set) var currentSession: ReaderSessionContext?
    /// 当前会话状态（与 `currentSession?.phase` 保持同步，便于视图直接观察）。
    @Published public private(set) var phase: ReaderSessionPhase = .idle

    /// requestId-scoped 异步结果守卫。
    private let resultGuard: AsyncResultGuard
    /// 动效运行时（用于触发 session 进入动画事务）。
    private let motionController: MotionController
    /// 当前未 settle 的进入动画事务 ID（如有）。
    private var pendingMotionTransactionId: UUID?

    public init(
        resultGuard: AsyncResultGuard = .shared,
        motionController: MotionController = .shared
    ) {
        self.resultGuard = resultGuard
        self.motionController = motionController
    }

    // MARK: - 会话生命周期

    /// 启动新会话。
    ///
    /// 若已有会话，调用 `resultGuard.supersede(requestId:)` 取代旧请求
    /// （latest intent wins，旧异步结果视为 superseded，不覆盖新会话）；
    /// 否则 `resultGuard.begin()` 新请求。phase 转 `.loading`。
    ///
    /// - Returns: 新会话的 requestId（用于异步回调校验）。
    @discardableResult
    public func startSession(bookId: String, chapterURL: String, sourceId: String?) -> UUID {
        let newRequestId: UUID
        if let oldRequestId = currentSession?.currentRequestId {
            // supersede 旧请求：旧 requestId 转 superseded，并 begin 新 pending。
            newRequestId = resultGuard.supersede(requestId: oldRequestId)
        } else {
            newRequestId = resultGuard.begin()
        }

        currentSession = ReaderSessionContext(
            sessionId: UUID(),
            bookId: bookId,
            chapterURL: chapterURL,
            sourceId: sourceId,
            startedAt: Date(),
            phase: .loading,
            lastError: nil,
            currentRequestId: newRequestId
        )
        phase = .loading

        // 触发 session 进入动画事务（对照 reader.entry.coverToImmersive）。
        startEntryMotionIfNeeded()

        return newRequestId
    }

    /// 完成会话加载。
    ///
    /// 内部：校验 requestId 仍 valid（pending），然后 `resultGuard.complete(requestId:)`，
    /// phase 转 `.reading`。requestId 非当前会话或已非 pending 时返回 `false`。
    ///
    /// - Returns: 是否成功完成。
    @discardableResult
    public func completeLoading(requestId: UUID) -> Bool {
        guard resultGuard.isValid(requestId: requestId) else { return false }
        guard resultGuard.complete(requestId: requestId) else { return false }
        // 进入动画已落位（reached reading），settle 进入事务。
        settlePendingMotion()
        phase = .reading
        applyPhase(.reading, clearError: true)
        return true
    }

    /// 暂停会话（用户切出 / 网络中断）。phase 转 `.paused`，保留 currentSession。
    public func pause() {
        guard currentSession != nil else { return }
        phase = .paused
        applyPhase(.paused, clearError: false)
    }

    /// 恢复会话。从 `.paused` 回到 `.reading`，并清空 lastError。
    public func resume() {
        guard currentSession != nil else { return }
        phase = .reading
        applyPhase(.reading, clearError: true)
    }

    /// 终止会话。
    ///
    /// 内部：`resultGuard.discard(requestId:)` 旧请求，currentSession = nil，
    /// phase = `.idle`。
    public func endSession() {
        if let oldRequestId = currentSession?.currentRequestId {
            _ = resultGuard.discard(requestId: oldRequestId)
        }
        settlePendingMotion()
        currentSession = nil
        phase = .idle
    }

    /// 报告错误。
    ///
    /// 内部：phase 转 `.error`，记录 lastError，但不清除 currentSession（允许 retry）。
    /// 同时把对应 requestId 标记为 cancel（请求终止，不再 pending），避免过期回调覆盖。
    public func reportError(_ error: StateError, requestId: UUID?) {
        if let requestId = requestId, requestId == currentSession?.currentRequestId {
            // error 视为请求终止：cancel 释放 pending 槽位，防止过期回调误判 isValid。
            _ = resultGuard.cancel(requestId: requestId)
        }
        // 进入动画未到达 reading 即失败，settle 进入事务。
        settlePendingMotion()
        phase = .error
        if var session = currentSession {
            session.phase = .error
            session.lastError = error
            currentSession = session
        }
    }

    /// 重试当前会话。
    ///
    /// 内部：supersede 旧 requestId，phase 转 `.loading`，返回新 requestId。
    /// 无活动会话时返回 `nil`。
    ///
    /// - Returns: 新 requestId，或 `nil` 表示无会话可重试。
    @discardableResult
    public func retry() -> UUID? {
        guard let session = currentSession else { return nil }

        let newRequestId: UUID
        if let oldRequestId = session.currentRequestId {
            newRequestId = resultGuard.supersede(requestId: oldRequestId)
        } else {
            newRequestId = resultGuard.begin()
        }

        phase = .loading
        var updated = session
        updated.phase = .loading
        updated.lastError = nil
        updated.currentRequestId = newRequestId
        currentSession = updated

        // 重新触发进入动画事务。
        startEntryMotionIfNeeded()

        return newRequestId
    }

    /// 校验 requestId 是否仍有效（用于异步回调返回时校验）。
    ///
    /// 对应 demo `motion.async.resultGuard` 语义：异步回调返回时调用本方法，
    /// `true` 表示当前会话仍匹配该 requestId，可应用结果；`false` 表示已过期
    /// （superseded / cancelled / discarded / completed），结果应丢弃。
    public func isValid(requestId: UUID) -> Bool {
        return resultGuard.isValid(requestId: requestId)
    }

    // MARK: - Private

    /// 把 phase 同步到 currentSession（按需清空 lastError）。
    private func applyPhase(_ newPhase: ReaderSessionPhase, clearError: Bool) {
        guard var session = currentSession else { return }
        session.phase = newPhase
        if clearError {
            session.lastError = nil
        }
        currentSession = session
    }

    /// 触发 session 进入动画事务（对照 `reader.entry.coverToImmersive`）。
    /// 先 settle 上一笔未完成事务，再启动新事务，避免 activeTransactions 残留。
    private func startEntryMotionIfNeeded() {
        settlePendingMotion()
        let duration = ReaderMotion.Duration.readerEntry
        let transactionId = motionController.start(
            id: .reader_entry_coverToImmersive,
            fromState: "idle",
            toState: "immersive",
            interruptMode: .cancel,
            finalState: "reading",
            durationSeconds: duration
        )
        pendingMotionTransactionId = transactionId
    }

    /// settle 当前未完成的进入动画事务（如有）。
    private func settlePendingMotion() {
        guard let transactionId = pendingMotionTransactionId else { return }
        motionController.settle(transactionId: transactionId)
        pendingMotionTransactionId = nil
    }
}
