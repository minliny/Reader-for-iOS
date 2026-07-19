import Foundation
import ReaderCoreNativeAdapter

public struct ReaderCoreAggregateStorageRestoreResult: Equatable, Sendable {
    public let restoredExistingSnapshot: Bool
    public let revision: String?
    public let schemaVersion: Int
}

public struct ReaderCoreAggregateStorageFlushResult: Equatable, Sendable {
    public let stored: Bool
    public let revision: String?
    public let schemaVersion: Int
}

private struct ReaderCoreAggregateStorageRawResult: @unchecked Sendable {
    let data: [String: Any]
}

/// Explicit bootstrap for Core's aggregate storage snapshot.
///
/// Runtime construction starts with `InMemoryStorage`. Calling
/// `runtime.storage.restore` once installs the Host-backed aggregate snapshot
/// and enables write-through for later Core-owned business mutations. Host
/// sees only an opaque, revisioned snapshot; it never owns bookmark/rule/edit
/// semantics or stores a second domain model.
public final class RustCoreAggregateStorageService: @unchecked Sendable {
    private let runtime: any RustCoreCommandRuntime
    private let router: any RustCoreHostRequestRouting
    private let requestTimeout: TimeInterval

    public init(
        runtime: any RustCoreCommandRuntime,
        router: any RustCoreHostRequestRouting,
        requestTimeout: TimeInterval = 20
    ) {
        self.runtime = runtime
        self.router = router
        self.requestTimeout = requestTimeout
    }

    public convenience init(runtime: ReaderCoreNativeRuntime, requestTimeout: TimeInterval = 20) {
        self.init(
            runtime: runtime,
            router: RustCoreServiceSupport.makeRouter(runtime: runtime),
            requestTimeout: requestTimeout
        )
    }

    public func restore(correlationID: String = "core-storage-bootstrap") async throws -> ReaderCoreAggregateStorageRestoreResult {
        let data = try await execute(
            method: "runtime.storage.restore",
            correlationID: correlationID
        )
        guard let restored = data["restored"] as? Bool,
              let schemaVersion = Self.integer(data["schemaVersion"]),
              schemaVersion >= 0 else {
            throw ReaderSlice10CoreServiceError.invalidResult(
                method: "runtime.storage.restore",
                message: "restored/schemaVersion is missing"
            )
        }
        return ReaderCoreAggregateStorageRestoreResult(
            restoredExistingSnapshot: restored,
            revision: Self.optionalString(data["revision"]),
            schemaVersion: schemaVersion
        )
    }

    public func flush(correlationID: String = "core-storage-flush") async throws -> ReaderCoreAggregateStorageFlushResult {
        let data = try await execute(
            method: "runtime.storage.flush",
            correlationID: correlationID
        )
        guard let stored = data["stored"] as? Bool,
              let schemaVersion = Self.integer(data["schemaVersion"]),
              schemaVersion >= 0 else {
            throw ReaderSlice10CoreServiceError.invalidResult(
                method: "runtime.storage.flush",
                message: "stored/schemaVersion is missing"
            )
        }
        return ReaderCoreAggregateStorageFlushResult(
            stored: stored,
            revision: Self.optionalString(data["revision"]),
            schemaVersion: schemaVersion
        )
    }

    private func execute(method: String, correlationID: String) async throws -> [String: Any] {
        let command = try RustCoreRequestScopedCommand<ReaderCoreAggregateStorageRawResult>(
            runtime: runtime,
            router: router,
            requestID: RustCoreServiceSupport.allocateRequestID(),
            correlationID: correlationID,
            method: method,
            params: [:],
            timeout: requestTimeout
        ) { data in
            ReaderCoreAggregateStorageRawResult(data: data ?? [:])
        }
        try command.start()
        return try await command.value().data
    }

    private static func integer(_ raw: Any?) -> Int? {
        if let value = raw as? Int { return value }
        if let value = raw as? NSNumber { return value.intValue }
        return nil
    }

    private static func optionalString(_ raw: Any?) -> String? {
        guard let raw, !(raw is NSNull) else { return nil }
        return raw as? String
    }
}

/// Process gate used by Slice 10 production factories. A command cannot race
/// the one-time restore handshake: while restoring or after a failed restore,
/// production mutations reject with a stable fail-closed code.
@MainActor
public enum ReaderCoreAggregateStorageGate {
    public enum State: Equatable, Sendable {
        case notStarted
        case restoring
        case ready(schemaVersion: Int, restoredExistingSnapshot: Bool)
        case failed(message: String)
    }

    public private(set) static var state: State = .notStarted

    public static var isReady: Bool {
        if case .ready = state { return true }
        return false
    }

    public static func beginRestore() throws {
        guard state == .notStarted else {
            throw ReaderSlice10CoreServiceError.failedClosed(
                code: "SLICE10_STORAGE_BOOTSTRAP_DUPLICATE",
                message: "Core aggregate storage bootstrap has already started"
            )
        }
        state = .restoring
    }

    public static func complete(_ result: ReaderCoreAggregateStorageRestoreResult) {
        state = .ready(
            schemaVersion: result.schemaVersion,
            restoredExistingSnapshot: result.restoredExistingSnapshot
        )
    }

    public static func fail(_ error: Error) {
        state = .failed(message: error.localizedDescription)
    }

    #if DEBUG
    public static func resetForTests() {
        state = .notStarted
    }
    #endif
}
