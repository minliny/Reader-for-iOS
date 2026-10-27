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
    private var pending: (id: String, label: String, action: (String) async throws -> Void, ended: ((String, Bool) -> Void)?)?
    private var feedbackGeneration = UUID()
    var pendingChecker: ((String) async -> Bool?)?
    var hasPending: Bool { pending != nil }
    var pendingOperationID: String? { pending?.id }

    @discardableResult
    func perform(_ label: String, scope: String, ended: ((String, Bool) -> Void)? = nil,
                 action: @escaping (String) async throws -> Void) async -> Bool {
        guard pending == nil, !busy else { return false }
        self.scope = scope
        pending = (UUID().uuidString.lowercased(), label, action, ended)
        return await resumeOriginal()
    }

    /// Reattaches a caller's persisted accepted intent without executing it or
    /// allocating another UUID. The caller must first verify its frozen input.
    @discardableResult
    func restoreAccepted(id: String, label: String, scope: String, ended: ((String, Bool) -> Void)? = nil,
                         action: @escaping (String) async throws -> Void) -> Bool {
        guard pending == nil, !busy, !id.isEmpty else { return false }
        self.scope = scope
        pending = (id, label, action, ended)
        recovery = "\(label)结果尚待确认，请核对原操作"
        return true
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
            intent.ended?(intent.id, true)
            return true
        } catch ReaderLibraryError.operationPending(let originalID) {
            if originalID != intent.id, let pendingChecker, await pendingChecker(intent.id) == false {
                pending = nil; recovery = nil
                intent.ended?(intent.id, false)
                publishFeedback("前一项原操作尚未确认，本次操作未提交")
            } else { recovery = "\(intent.label)结果尚待确认，请核对原操作" }
        } catch {
            if let pendingChecker, await pendingChecker(intent.id) != false {
                recovery = "\(intent.label)结果尚待确认，请核对原操作"
                return false
            }
            pending = nil
            recovery = nil
            intent.ended?(intent.id, false)
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

/// One visible download projection. Activation belongs to the presentation;
/// a late business completion may request a read but cannot revive a retired
/// page or switch it back to an older entity. No write owner or ACK lives here.
@MainActor
final class ReaderDownloadReadOwner<Identity: Equatable, Value>: ObservableObject {
    typealias Publish = @MainActor (Value) -> Void
    typealias Read = @MainActor (@escaping Publish) async throws -> Void
    typealias Merge = @MainActor (Value) -> Value
    typealias Supplement = @MainActor () async throws -> Merge
    @Published private(set) var identity: Identity?
    @Published private(set) var value: Value?
    @Published private(set) var failure: String?
    @Published private(set) var loading = false
    private var active = false
    private var generation = UUID()
    private var requestTask: Task<Void, Never>?
    private var invalidatedRead: Read?
    private var invalidatedReadPriority = Int.min
    private var supplementTask: Task<Void, Never>?
    private var invalidatedSupplement: Supplement?
    private var readFailure: String?
    private var supplementFailure: String?

    deinit { requestTask?.cancel(); supplementTask?.cancel() }

    func activate(identity: Identity) {
        guard !active || self.identity != identity else { return }
        cancelRead()
        if self.identity != identity {
            value = nil; failure = nil; readFailure = nil; supplementFailure = nil
        }
        self.identity = identity
        active = true
    }

    /// The returned task lets polling wait for this complete read, rather than
    /// repeatedly cancelling a slow status/storage request on a fixed timer.
    @discardableResult
    func refresh(identity: Identity,
                 read: @escaping Read) -> Task<Void, Never>? {
        guard active, self.identity == identity else { return nil }
        cancelRead()
        return beginRead(identity: identity, read: read)
    }

    /// Lifecycle hints only invalidate the projection. Preserve an in-flight
    /// read and merge further hints into one subsequent current-entity read.
    @discardableResult
    func invalidate(identity: Identity, priority: Int = 0, read: @escaping Read) -> Task<Void, Never>? {
        guard active, self.identity == identity else { return nil }
        if let requestTask {
            if invalidatedRead == nil || priority >= invalidatedReadPriority {
                invalidatedRead = read
                invalidatedReadPriority = priority
            }
            return requestTask
        }
        return beginRead(identity: identity, read: read)
    }

    private func beginRead(identity: Identity, read: @escaping Read) -> Task<Void, Never> {
        let current = generation
        readFailure = nil; publishFailure()
        loading = true
        let task = Task { [weak self] in
            var nextRead: Read? = read
            while let currentRead = nextRead {
                guard !Task.isCancelled, self?.accepts(identity, generation: current) == true else { return }
                self?.readFailure = nil; self?.publishFailure()
                do {
                    try await currentRead { [weak self] value in
                        guard !Task.isCancelled, let self, self.accepts(identity, generation: current) else { return }
                        self.value = value
                    }
                } catch is CancellationError { } catch {
                    guard !Task.isCancelled, let self, self.accepts(identity, generation: current) else { return }
                    self.readFailure = error.localizedDescription; self.publishFailure()
                }
                guard !Task.isCancelled, let self, self.accepts(identity, generation: current) else { return }
                nextRead = self.invalidatedRead
                self.invalidatedRead = nil
                self.invalidatedReadPriority = Int.min
            }
            guard let self, self.accepts(identity, generation: current) else { return }
            self.loading = false
            self.requestTask = nil
        }
        requestTask = task
        return task
    }

    /// Ancillary inventory must not delay status reads. Apply its result to
    /// the current projection, never to a status captured before its await.
    @discardableResult
    func invalidateSupplement(identity: Identity, read: @escaping Supplement) -> Task<Void, Never>? {
        guard active, self.identity == identity else { return nil }
        if let supplementTask {
            invalidatedSupplement = read
            return supplementTask
        }
        let current = generation
        supplementFailure = nil; publishFailure()
        let task = Task { [weak self] in
            var nextRead: Supplement? = read
            while let currentRead = nextRead {
                guard !Task.isCancelled, self?.accepts(identity, generation: current) == true else { return }
                self?.supplementFailure = nil; self?.publishFailure()
                do {
                    let merge = try await currentRead()
                    guard !Task.isCancelled, let self, self.accepts(identity, generation: current) else { return }
                    if let value = self.value { self.value = merge(value) }
                } catch is CancellationError { } catch {
                    guard !Task.isCancelled, let self, self.accepts(identity, generation: current) else { return }
                    self.supplementFailure = error.localizedDescription; self.publishFailure()
                }
                guard !Task.isCancelled, let self, self.accepts(identity, generation: current) else { return }
                nextRead = self.invalidatedSupplement
                self.invalidatedSupplement = nil
            }
            guard let self, self.accepts(identity, generation: current) else { return }
            self.supplementTask = nil
        }
        supplementTask = task
        return task
    }

    private func publishFailure() { failure = readFailure ?? supplementFailure }

    func retire() {
        active = false
        cancelRead()
    }

    private func accepts(_ identity: Identity, generation: UUID) -> Bool {
        active && self.identity == identity && self.generation == generation
    }

    private func cancelRead() {
        generation = UUID()
        requestTask?.cancel()
        requestTask = nil
        invalidatedRead = nil
        invalidatedReadPriority = Int.min
        supplementTask?.cancel()
        supplementTask = nil
        invalidatedSupplement = nil
        loading = false
    }
}
