import Foundation

/// 异步结果守卫状态机。
///
/// 真源：Reader UI `frontend-demo-optimized/MOTION_CONTRACT.md` §4 `motion.async.resultGuard`（第 240 行）
/// demo 语义：每个异步结果必须带 requestId、from/to、stack/context；只有仍匹配当前
/// route/context 的结果才能替换内容，过期结果写入 discarded/cancelled 状态且不得覆盖新页面。
/// demo `motion-controller.js` 第 53 行 `DEFAULT_STATE_MACHINE.interrupt` 中的
/// `superseded` / `routeChange` / `destroy` 对应本类型的 `superseded` / `cancelled` / `discarded`。
///
/// 本类型只承载契约状态语义，不复制 Web DOM / `data-*` selector / route stack 实现。
public enum AsyncResultState: String, Sendable, Equatable {
    /// 请求已发出，等待结果。
    case pending
    /// 请求成功完成，结果可用。
    case completed
    /// 请求被显式取消（用户操作，对应 `routeChange`）。
    case cancelled
    /// 请求因视图销毁被丢弃（对应 `destroy`）。
    case discarded
    /// 请求被新请求取代（requestId 不匹配）。
    case superseded
}

/// 单次异步请求的结果 token。
///
/// `id` 即契约中的 requestId；异步回调返回时用 `id` 校验当前 route/context 是否仍匹配。
public struct AsyncResultToken: Sendable, Equatable, Identifiable {
    /// 请求 ID（requestId）。
    public let id: UUID
    /// 发起时间。
    public let createdAt: Date
    /// 当前状态。
    public var state: AsyncResultState
    /// 进入终态（非 pending）的时间，用于 `cleanup(olderThan:)` 判定。
    public var completedAt: Date?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        state: AsyncResultState = .pending,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.state = state
        self.completedAt = completedAt
    }
}

/// requestId-scoped 异步结果守卫。
///
/// 用于阅读 loading、搜索、远端结果回写场景：异步回调返回时通过 `isValid(requestId:)`
/// 校验当前 route/context 是否仍匹配，避免过期结果覆盖新页面。
///
/// 状态转移规则（clean-room，不复制 demo 实现）：
/// - `pending` → `completed` / `cancelled` / `discarded` / `superseded`（一次性终态转移）
/// - 终态不可逆，重复转移返回 `false`
@MainActor
public final class AsyncResultGuard: ObservableObject {

    /// 当前活跃的 token 表（key 为 requestId）。
    @Published private(set) var activeTokens: [UUID: AsyncResultToken] = [:]

    /// 单例。用于无注入场景的全局守卫。
    public static let shared: AsyncResultGuard = AsyncResultGuard()

    public init() {}

    /// 发起新请求，返回 requestId，状态为 `pending`。
    @discardableResult
    public func begin() -> UUID {
        let token = AsyncResultToken()
        activeTokens[token.id] = token
        return token.id
    }

    /// 标记完成。仅 `pending` 可完成；返回是否成功转移。
    @discardableResult
    public func complete(requestId: UUID) -> Bool {
        return transition(requestId: requestId, to: .completed)
    }

    /// 标记取消（用户操作）。仅 `pending` 可取消。
    @discardableResult
    public func cancel(requestId: UUID) -> Bool {
        return transition(requestId: requestId, to: .cancelled)
    }

    /// 标记丢弃（视图销毁）。仅 `pending` 可丢弃。
    @discardableResult
    public func discard(requestId: UUID) -> Bool {
        return transition(requestId: requestId, to: .discarded)
    }

    /// 标记旧请求为 `superseded`，并返回新 requestId（开始新的 `pending`）。
    /// 若旧 requestId 不存在或已非 `pending`，仍会发起新请求，但不转移旧态。
    @discardableResult
    public func supersede(requestId: UUID) -> UUID {
        _ = transition(requestId: requestId, to: .superseded)
        return begin()
    }

    /// 查询状态。`nil` 表示该 requestId 不在活跃表中（已被清理或从未发起）。
    public func state(for requestId: UUID) -> AsyncResultState? {
        return activeTokens[requestId]?.state
    }

    /// 状态是否为 `pending`。用于异步回调返回时校验结果是否仍可应用。
    public func isValid(requestId: UUID) -> Bool {
        return activeTokens[requestId]?.state == .pending
    }

    /// 清理超过指定时长的已结束 token（避免字典无限增长）。
    /// `pending` token 不清理；终态 token 按 `completedAt` 判定。
    public func cleanup(olderThan threshold: TimeInterval) {
        let cutoff = Date().addingTimeInterval(-threshold)
        activeTokens = activeTokens.filter { (_, token) in
            if token.state == .pending { return true }
            guard let ended = token.completedAt else { return true }
            return ended > cutoff
        }
    }

    /// 清空所有状态（测试用）。
    public func reset() {
        activeTokens.removeAll()
    }

    // MARK: - Private

    /// 统一的终态转移：仅 `pending` 可转移到任意终态。
    private func transition(requestId: UUID, to state: AsyncResultState) -> Bool {
        guard var token = activeTokens[requestId], token.state == .pending else {
            return false
        }
        token.state = state
        token.completedAt = Date()
        activeTokens[requestId] = token
        return true
    }
}
