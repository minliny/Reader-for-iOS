import Foundation
import BackgroundTasks

/// Scheduling requests confer no execution guarantee. Manual checks remain in
/// the subscription page; Core's timestamp determines which auto checks are due.
@MainActor final class ReaderRuleSubscriptionScheduler {
    static let shared = ReaderRuleSubscriptionScheduler()
    static let identifier = "io.reader.minliny.rule-sub-refresh"
    private var registered = false
    private var worker: Task<Void, Never>?
    private var checking = false
    func register() {
        guard !registered else { return }
        registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.identifier, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else { task.setTaskCompleted(success: false); return }
            Task { @MainActor in self.run(refresh) }
        }
    }
    func requestNextOpportunity() {
        guard registered else { return }
        let request = BGAppRefreshTaskRequest(identifier: Self.identifier)
        request.earliestBeginDate = Date().addingTimeInterval(24 * 60 * 60)
        // Rejection is an unavailable OS opportunity, never a completed check.
        try? BGTaskScheduler.shared.submit(request)
    }
    func foregroundOpportunity() async {
        guard !Task.isCancelled, !checking else { return }
        checking = true; defer { checking = false }
        do { let service = try await ReaderAppRuntimeStore.shared.library(); _ = await service.checkDueRuleSubscriptions() }
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
                let service = try await ReaderAppRuntimeStore.shared.library()
                let failures = await service.checkDueRuleSubscriptions()
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
