import Combine
import Foundation
import ReaderUIContract

public enum ReaderSlice12PermissionScope: String, CaseIterable, Codable, Hashable, Sendable {
    case storage
    case notification
    case camera
    case microphone
    case location
}

public enum ReaderSlice12PermissionStatus: String, Codable, Sendable {
    case notDetermined
    case restricted
    case denied
    case authorized
    case authorizedAlways
    case authorizedWhenInUse
    case provisional
    case ephemeral
    case unknown

    public var isGranted: Bool {
        switch self {
        case .authorized, .authorizedAlways, .authorizedWhenInUse, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    public var requiresSystemSettingsRecovery: Bool {
        self == .denied || self == .restricted
    }
}

public protocol ReaderSlice12PermissionClient: Sendable {
    func check(_ scope: ReaderSlice12PermissionScope) async throws -> ReaderSlice12PermissionStatus
    func request(_ scope: ReaderSlice12PermissionScope) async throws -> ReaderSlice12PermissionStatus
}

public enum ReaderSlice12PermissionClientError: Error, Equatable, LocalizedError {
    case hostRejected(String)
    case invalidResult(String)

    public var errorDescription: String? {
        switch self {
        case .hostRejected(let message): return "[SLICE12_PERMISSION_HOST_REJECTED] \(message)"
        case .invalidResult(let message): return "[SLICE12_PERMISSION_RESULT_INVALID] \(message)"
        }
    }
}

/// Production adapter for the frozen Reader-UI permission request/check Host
/// pair. It preserves the platform status instead of collapsing denied,
/// restricted, provisional, and not-determined into a single Bool.
public struct ReaderSlice12HostPermissionClient: ReaderSlice12PermissionClient {
    private let capability: HostPermissionCapability

    public init(capability: HostPermissionCapability = HostPermissionCapability()) {
        self.capability = capability
    }

    public func check(_ scope: ReaderSlice12PermissionScope) async throws -> ReaderSlice12PermissionStatus {
        try await execute(type: .permission_check, scope: scope)
    }

    public func request(_ scope: ReaderSlice12PermissionScope) async throws -> ReaderSlice12PermissionStatus {
        try await execute(type: .permission_request, scope: scope)
    }

    private func execute(
        type: HostRequestType,
        scope: ReaderSlice12PermissionScope
    ) async throws -> ReaderSlice12PermissionStatus {
        let outcome = try await capability.handle(HostRequest(
            type: type,
            payload: ["scope": AnyCodable(scope.rawValue)],
            initiator: .reducer
        ))
        guard outcome.succeeded else {
            throw ReaderSlice12PermissionClientError.hostRejected(String(describing: outcome.error))
        }
        guard let raw = outcome.result?["status"]?.value as? String,
              let status = ReaderSlice12PermissionStatus(rawValue: raw) else {
            throw ReaderSlice12PermissionClientError.invalidResult(
                "\(type.rawValue) did not return a recognized status"
            )
        }
        return status
    }
}

public enum ReaderSlice12OnboardingState: Equatable, Sendable {
    case idle
    case checking
    case education(pending: [ReaderSlice12PermissionScope])
    case requesting(ReaderSlice12PermissionScope)
    case recovery(scope: ReaderSlice12PermissionScope, status: ReaderSlice12PermissionStatus)
    case readyForApplication
    case blocked(code: String, message: String)
}

/// Slice 12 permission education/recovery state machine.
///
/// It can be built before the final Slice 12 release gate, but it never stores
/// a synthetic "onboarding complete" flag: initialization/settings ownership
/// and migration are not implemented by Reader-Core-Native yet. The app may
/// enter `readyForApplication` for the current process; durable completion is
/// an explicit blocker.
@MainActor
public final class ReaderSlice12OnboardingCoordinator: ObservableObject {
    @Published public private(set) var state: ReaderSlice12OnboardingState = .idle

    private enum RecheckOutcome: Sendable {
        case education([ReaderSlice12PermissionScope])
        case recovery(ReaderSlice12PermissionScope, ReaderSlice12PermissionStatus)
        case ready
        case blocked(message: String)
        case cancelled
    }

    private let permissions: any ReaderSlice12PermissionClient
    private let coreStorageReady: @MainActor () -> Bool
    private var requiredScopes: [ReaderSlice12PermissionScope] = []
    private var planInitialized = false
    private var planGeneration: UInt64 = 0
    private var activeRecheckTask: Task<RecheckOutcome, Never>?

    public init(
        permissions: any ReaderSlice12PermissionClient = ReaderSlice12HostPermissionClient(),
        coreStorageReady: @escaping @MainActor () -> Bool = { ReaderCoreAggregateStorageGate.isReady }
    ) {
        self.permissions = permissions
        self.coreStorageReady = coreStorageReady
    }

    public func start(requiredScopes: [ReaderSlice12PermissionScope]) async {
        let nextScopes = Array(Set(requiredScopes)).sorted { $0.rawValue < $1.rawValue }
        let generation = beginNextGeneration()
        planInitialized = false
        self.requiredScopes = []
        guard coreStorageReady() else {
            state = .blocked(
                code: "SLICE12_INITIALIZATION_RESULT_NOT_READY",
                message: "Core aggregate restore must complete before onboarding can admit the application"
            )
            return
        }
        self.requiredScopes = nextScopes
        planInitialized = true
        await recheckAll(generation: generation)
    }

    public func request(_ scope: ReaderSlice12PermissionScope) async {
        let generation = beginNextGeneration()
        guard requiredScopes.contains(scope) else {
            state = .blocked(
                code: "SLICE12_PERMISSION_SCOPE_NOT_REQUIRED",
                message: "permission scope \(scope.rawValue) is outside the active onboarding plan"
            )
            return
        }
        state = .requesting(scope)
        do {
            let status = try await permissions.request(scope)
            guard isCurrent(generation) else { return }
            if status.requiresSystemSettingsRecovery {
                state = .recovery(scope: scope, status: status)
            } else {
                await recheckAll(generation: generation)
            }
        } catch {
            guard isCurrent(generation) else { return }
            state = .blocked(
                code: "SLICE12_PERMISSION_REQUEST_FAILED",
                message: error.localizedDescription
            )
        }
    }

    /// Call after the app becomes active again from Settings. The coordinator
    /// performs a fresh Host check; it never assumes the user changed access.
    public func applicationDidBecomeActive() async {
        guard planInitialized else {
            state = .blocked(
                code: "SLICE12_ONBOARDING_PLAN_NOT_STARTED",
                message: "onboarding must start with an explicit permission plan before activation rechecks"
            )
            return
        }
        let generation = beginNextGeneration()
        guard coreStorageReady() else {
            state = .blocked(
                code: "SLICE12_INITIALIZATION_RESULT_NOT_READY",
                message: "Core aggregate restore is unavailable after app activation"
            )
            return
        }
        await recheckAll(generation: generation)
    }

    public func requireDurableCompletionContract() throws -> Never {
        throw ReaderSlice12PermissionClientError.hostRejected(
            "SLICE12_ONBOARDING_OWNER_CONTRACT_MISSING: Core initialization/settings owner and migration result are not implemented"
        )
    }

    private func beginNextGeneration() -> UInt64 {
        activeRecheckTask?.cancel()
        activeRecheckTask = nil
        planGeneration &+= 1
        return planGeneration
    }

    private func isCurrent(_ generation: UInt64) -> Bool {
        generation == planGeneration && !Task.isCancelled
    }

    private func recheckAll(generation: UInt64) async {
        guard isCurrent(generation) else { return }
        state = .checking
        let scopes = requiredScopes
        let task = Task { [permissions] in
            await Self.evaluateRecheck(scopes: scopes, permissions: permissions)
        }
        activeRecheckTask = task
        let outcome = await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }

        // MainActor methods are reentrant while awaiting permission clients.
        // Both cancellation and generation equality are required: a Host fake
        // or platform API may ignore task cancellation and still return late.
        guard generation == planGeneration else { return }
        activeRecheckTask = nil
        guard !Task.isCancelled else { return }
        switch outcome {
        case .education(let pending):
            state = .education(pending: pending)
        case .recovery(let scope, let status):
            state = .recovery(scope: scope, status: status)
        case .ready:
            state = .readyForApplication
        case .blocked(let message):
            state = .blocked(
                code: "SLICE12_PERMISSION_CHECK_FAILED",
                message: message
            )
        case .cancelled:
            break
        }
    }

    private nonisolated static func evaluateRecheck(
        scopes: [ReaderSlice12PermissionScope],
        permissions: any ReaderSlice12PermissionClient
    ) async -> RecheckOutcome {
        var pending: [ReaderSlice12PermissionScope] = []
        do {
            for scope in scopes {
                guard !Task.isCancelled else { return .cancelled }
                let status = try await permissions.check(scope)
                guard !Task.isCancelled else { return .cancelled }
                if status.requiresSystemSettingsRecovery {
                    return .recovery(scope, status)
                }
                if !status.isGranted {
                    pending.append(scope)
                }
            }
            return pending.isEmpty ? .ready : .education(pending)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return Task.isCancelled ? .cancelled : .blocked(message: error.localizedDescription)
        }
    }
}
