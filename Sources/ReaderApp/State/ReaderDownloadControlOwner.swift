import Combine

/// Presentation owners only. Runtime retains every original resume/control
/// identity, acquisition child and receipt. A long resume must not disable
/// the separate pause/cancel intent lane while its acquisition is awaiting I/O.
@MainActor
final class ReaderDownloadControlOwner: ObservableObject {
    let resumeActions = ReaderLibraryActionOwner()
    let controlActions = ReaderLibraryActionOwner()
    let objectWillChange = ObservableObjectPublisher()
    private var observations = Set<AnyCancellable>()

    init() {
        for owner in [resumeActions, controlActions] {
            owner.objectWillChange.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &observations)
        }
    }

    var canControl: Bool { !controlActions.hasPending }
    var canResume: Bool { !resumeActions.hasPending && !controlActions.hasPending }
    var canClear: Bool { canResume }

    @discardableResult
    func performResume(scope: String, action: @escaping (String) async throws -> Void) async -> Bool {
        guard canResume else { return false }
        return await resumeActions.perform("更改下载任务", scope: scope, action: action)
    }

    @discardableResult
    func performControl(scope: String, action: @escaping (String) async throws -> Void) async -> Bool {
        guard canControl else { return false }
        return await controlActions.perform("更改下载任务", scope: scope, action: action)
    }

    @discardableResult
    func performClear(scope: String, action: @escaping (String) async throws -> Void) async -> Bool {
        guard canClear else { return false }
        return await controlActions.perform("清除此章下载", scope: scope, action: action)
    }
}
