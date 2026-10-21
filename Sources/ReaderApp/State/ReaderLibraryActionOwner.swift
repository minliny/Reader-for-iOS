import Foundation
import Combine

/// Presentation of one accepted feature intent. Runtime retains the original
/// write/receipt; retrying here retains its immutable operation identity.
@MainActor
final class ReaderLibraryActionOwner: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var recovery: String?
    @Published private(set) var feedback: String?
    @Published private(set) var scope: String?
    private var pending: (id: String, label: String, action: (String) async throws -> Void)?
    private var feedbackGeneration = UUID()
    var pendingChecker: ((String) async -> Bool?)?
    var hasPending: Bool { pending != nil }
    var pendingOperationID: String? { pending?.id }

    @discardableResult
    func perform(_ label: String, scope: String, action: @escaping (String) async throws -> Void) async -> Bool {
        guard pending == nil, !busy else { return false }
        self.scope = scope
        pending = (UUID().uuidString.lowercased(), label, action)
        return await resumeOriginal()
    }

    @discardableResult
    func resumeOriginal() async -> Bool {
        guard !busy, let intent = pending else { return false }
        busy = true
        defer { busy = false }
        do {
            try await intent.action(intent.id)
            pending = nil
            recovery = nil
            return true
        } catch ReaderLibraryError.operationPending(let originalID) {
            if originalID != intent.id, let pendingChecker, await pendingChecker(intent.id) == false {
                pending = nil; recovery = nil
                publishFeedback("前一项原操作尚未确认，本次操作未提交")
            } else { recovery = "\(intent.label)结果尚待确认，请核对原操作" }
        } catch {
            if let pendingChecker, await pendingChecker(intent.id) != false {
                recovery = "\(intent.label)结果尚待确认，请核对原操作"
                return false
            }
            pending = nil
            recovery = nil
            publishFeedback(error.localizedDescription)
        }
        return false
    }

    func clearFeedback() { feedbackGeneration = UUID(); feedback = nil }
    private func publishFeedback(_ message: String) {
        let generation = UUID()
        feedbackGeneration = generation
        feedback = message
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard self?.feedbackGeneration == generation else { return }
            self?.feedback = nil
        }
    }
}
