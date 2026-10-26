import Foundation
import BackgroundTasks
import Combine

@MainActor protocol ReaderRuleSubscriptionScheduling {
    func register(identifier: String, launchHandler: @escaping (BGTask) -> Void) -> Bool
    func pendingRequests() async -> [BGTaskRequest]
    func submit(_ request: BGAppRefreshTaskRequest) async throws
}

@MainActor private struct ReaderSystemRuleSubscriptionScheduling: ReaderRuleSubscriptionScheduling {
    func register(identifier: String, launchHandler: @escaping (BGTask) -> Void) -> Bool {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: identifier, using: nil, launchHandler: launchHandler)
    }
    func pendingRequests() async -> [BGTaskRequest] { await BGTaskScheduler.shared.pendingTaskRequests() }
    func submit(_ request: BGAppRefreshTaskRequest) async throws {
        if #available(iOS 27.0, *) {
            try await BGTaskScheduler.shared.submitTaskRequest(request)
        } else {
            try BGTaskScheduler.shared.submit(request)
        }
    }
}

/// Scheduling requests confer no execution guarantee. Manual checks remain in
/// the subscription page; Core's timestamp determines which auto checks are due.
@MainActor final class ReaderRuleSubscriptionScheduler: ObservableObject {
    static let shared = ReaderRuleSubscriptionScheduler()
    static let identifier = "io.reader.minliny.rule-sub-refresh"
    private var registered = false
    private var worker: Task<Void, Never>?
    private var schedulingTask: Task<Void, Never>?
    private var checking = false
    // A completed opportunity invalidates source projections; it is not a
    // successful update receipt and never resumes an accepted write in the UI.
    @Published private(set) var completedOpportunityRevision = UUID()
    private let checkDue: @MainActor () async throws -> [String]
    private let scheduling: any ReaderRuleSubscriptionScheduling
    private let now: @MainActor () -> Date

    init(checkDue: @escaping @MainActor () async throws -> [String] = {
        let service = try await ReaderAppRuntimeStore.shared.library()
        return await service.checkDueRuleSubscriptions()
    }, scheduling: (any ReaderRuleSubscriptionScheduling)? = nil,
         now: @escaping @MainActor () -> Date = { Date() }) {
        self.checkDue = checkDue
        self.scheduling = scheduling ?? ReaderSystemRuleSubscriptionScheduling()
        self.now = now
    }

    private func checkAndInvalidateSources() async throws -> [String] {
        let failures = try await checkDue()
        // A cancellation or partial failure may follow an acknowledged update.
        // Re-read the current projection after the finite check has returned.
        completedOpportunityRevision = UUID()
        return failures
    }
    func register() {
        guard !registered else { return }
        registered = scheduling.register(identifier: Self.identifier) { task in
            guard let refresh = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            Task { @MainActor in self.run(refresh) }
        }
    }
    @discardableResult func requestNextOpportunity() -> Task<Void, Never>? {
        guard registered else { return nil }
        if let schedulingTask { return schedulingTask }
        let task = Task<Void, Never> { @MainActor in
            defer { schedulingTask = nil }
            let earliest = now().addingTimeInterval(24 * 60 * 60)
            let pending = await scheduling.pendingRequests()
            // Submitting the same identifier replaces its pending request. A
            // foreground visit must not move an earlier OS opportunity later.
            if pending.contains(where: {
                $0.identifier == Self.identifier && $0 is BGAppRefreshTaskRequest
                    && ($0.earliestBeginDate.map { $0 <= earliest } ?? true)
            }) { return }
            let request = BGAppRefreshTaskRequest(identifier: Self.identifier)
            request.earliestBeginDate = earliest
            // Rejection is an unavailable OS opportunity, never a completed check.
            try? await scheduling.submit(request)
        }
        // Keep the pending lookup and possible submission in one shared flight.
        schedulingTask = task
        return task
    }
    func foregroundOpportunity() async {
        guard !Task.isCancelled, !checking else { return }
        checking = true; defer { checking = false }
        do { _ = try await checkAndInvalidateSources() }
        catch { /* Manual page retains a retry path; no unsolicited notification. */ }
        requestNextOpportunity()
    }
    private func run(_ refresh: BGAppRefreshTask) {
        requestNextOpportunity()
        guard !checking else { refresh.setTaskCompleted(success: false); return }
        checking = true
        let task = Task { @MainActor in
            var success = false
            do {
                let failures = try await self.checkAndInvalidateSources()
                success = failures.isEmpty && !Task.isCancelled
            } catch { }
            refresh.setTaskCompleted(success: success)
            self.checking = false
            self.worker = nil
        }
        worker = task
        refresh.expirationHandler = { task.cancel() }
    }
}
