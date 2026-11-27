import Foundation
import ReaderCore

/// Access is tied to the live request and transfer stage that Core authorized.
/// The actor keeps the native handle and all calls in its single lifetime domain.
public struct CoreMangaAssets: Sendable {
    public static let chunkLimit = 1_048_576
    public static let assetLimit = 128 * chunkLimit

    enum Action: Sendable {
        case begin(Int)
        case write(UInt64, Data)
        case commit(UInt64)
        case read(Int, Int)
        case release(UInt64?)
    }

    enum Result: Sendable {
        case number(UInt64)
        case bytes(Data)
    }

    let perform: @Sendable (Action) async throws -> Result

    public func begin(bytes: Int) async throws -> UInt64 {
        try await number(.begin(bytes))
    }

    @discardableResult
    public func write(_ id: UInt64, bytes: Data) async throws -> UInt64 {
        try await number(.write(id, bytes))
    }

    public func commit(_ id: UInt64) async throws -> UInt64 {
        try await number(.commit(id))
    }

    public func read(offset: Int, limit: Int) async throws -> Data {
        guard case .bytes(let bytes) = try await perform(.read(offset, limit)) else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return bytes
    }

    public func release(_ id: UInt64? = nil) async throws {
        _ = try await number(.release(id))
    }

    private func number(_ action: Action) async throws -> UInt64 {
        guard case .number(let value) = try await perform(action) else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return value
    }
}

extension CoreTransport {
    func performMangaAsset(_ action: CoreMangaAssets.Action,
                           for request: M3MangaResourceTransferHostRequest) throws -> CoreMangaAssets.Result {
        guard let handle else { throw CoreBridgeFailure.closed }
        guard request.requestId > 0, request.operationId > 0 else { throw CoreBridgeFailure.endpointMismatch }
        let owner = UInt64(request.requestId)
        let operation = UInt64(request.operationId)
        let output: M3MangaTransferOutput?
        if case .output(let value) = request.params { output = value } else { output = nil }
        var value: UInt64 = 0
        switch action {
        case .begin(let bytes):
            guard output == nil, (1...CoreMangaAssets.assetLimit).contains(bytes) else {
                throw CoreBridgeFailure.endpointMismatch
            }
            try Self.check(rc_runtime_asset_begin(handle, owner, operation, UInt64(bytes), &value),
                           "rc_runtime_asset_begin")
        case .write(let id, let bytes):
            guard output == nil, (1...CoreMangaAssets.chunkLimit).contains(bytes.count) else {
                throw CoreBridgeFailure.endpointMismatch
            }
            let status = bytes.withUnsafeBytes { raw in
                rc_runtime_asset_write(handle, owner, operation, id,
                                       raw.bindMemory(to: UInt8.self).baseAddress, raw.count, &value)
            }
            try Self.check(status, "rc_runtime_asset_write")
        case .commit(let id):
            guard output == nil else { throw CoreBridgeFailure.endpointMismatch }
            try Self.check(rc_runtime_asset_commit(handle, owner, operation, id, &value), "rc_runtime_asset_commit")
        case .read(let offset, let limit):
            guard let output, output.operationId > 0, output.assetId > 0, offset >= 0,
                  (1...CoreMangaAssets.chunkLimit).contains(limit) else { throw CoreBridgeFailure.endpointMismatch }
            var bytes = rc_owned_bytes_t()
            try Self.check(rc_runtime_asset_read_chunk(handle, owner, UInt64(output.operationId),
                                                      UInt64(output.assetId), UInt64(offset), limit, &bytes),
                           "rc_runtime_asset_read_chunk")
            defer { rc_owned_bytes_free(&bytes) }
            guard bytes.length > 0 else { return .bytes(Data()) }
            guard let ptr = bytes.data else { throw CoreBridgeFailure.invalidEvent }
            return .bytes(Data(bytes: ptr, count: bytes.length))
        case .release(let id):
            if let output, id == nil, output.operationId > 0, output.assetId > 0 {
                try Self.check(rc_runtime_asset_release(handle, owner, UInt64(output.operationId), UInt64(output.assetId)),
                               "rc_runtime_asset_release")
            } else if output == nil, let id {
                try Self.check(rc_runtime_asset_release(handle, owner, operation, id), "rc_runtime_asset_release")
            } else {
                throw CoreBridgeFailure.endpointMismatch
            }
        }
        return .number(value)
    }
}
