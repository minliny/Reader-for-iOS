import Foundation
import BackgroundTasks
import Combine

/// Scheduling requests confer no execution guarantee. Manual checks remain in
/// the subscription page; Core's timestamp determines which auto checks are due.
@MainActor final class ReaderRuleSubscriptionScheduler: ObservableObject {
    static let shared = ReaderRuleSubscriptionScheduler()
    static let identifier = "io.reader.minliny.rule-sub-refresh"
    private var registered = false
    private var worker: Task<Void, Never>?
    private var checking = false
    // A completed opportunity invalidates source projections; it is not a
    // successful update receipt and never resumes an accepted write in the UI.
    @Published private(set) var completedOpportunityRevision = UUID()
    private let checkDue: @MainActor () async throws -> [String]

    init(checkDue: @escaping @MainActor () async throws -> [String] = {
        let service = try await ReaderAppRuntimeStore.shared.library()
        return await service.checkDueRuleSubscriptions()
    }) { self.checkDue = checkDue }

    private func checkAndInvalidateSources() async throws -> [String] {
        let failures = try await checkDue()
        // A cancellation or partial failure may follow an acknowledged update.
        // Re-read the current projection after the finite check has returned.
        completedOpportunityRevision = UUID()
        return failures
    }
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
