import Foundation

public struct CoreOperationID: Equatable, Hashable, Sendable {
    public let runtimeId: UUID
    public let requestId: Int64
}

public struct CoreOperation<Value: Sendable>: Sendable {
    public let id: CoreOperationID
    public let value: Value
}

public struct CoreRequestFailure: Error, Sendable {
    public let id: CoreOperationID
    public let value: ReaderM1Error
    public let m2Value: M2ProtocolError
}

public struct CoreHostControlRejection: Error, Sendable {
    public let owner: CoreOperationID
    public let control: CoreOperationID
    public let value: ReaderM1Error
}

public enum CoreHostReply: Sendable {
    case echo(M1HostEchoData)
    case time(HostTimeNowResponse)
    case failure(HostErrorParams)
    case http(M2HostHttpResponse)
    case cookieGet(M2HostCookieGetResponse)
    case cookieSet(M2HostCookieSetResponse)
    case webView(M2HostWebViewEvaluateJavaScriptResponse)
    case media(M2HostMediaDownloadResponse)
    case mangaInput(M3MangaTransferInputReceipt)
    case mangaOutput(M3MangaTransferOutputReceipt)
    case networkFailure(M2HostErrorParams)
}

public protocol CoreHost: Sendable {
    var capabilities: [ReaderHostCapability] { get }
    var protocolExtensions: [String] { get }
    func execute(_ request: ReaderHostRequestEvent) async -> CoreHostReply
    func executeNetwork(_ request: CoreNetworkHostRequest, operationId: Int64) async -> CoreHostReply
    func executeManga(_ request: M3MangaResourceTransferHostRequest, assets: CoreMangaAssets) async -> CoreHostReply
    func discardUnsent(_ reply: CoreHostReply) async
}

public extension CoreHost {
    var protocolExtensions: [String] { [] }

    func executeNetwork(_ request: CoreNetworkHostRequest, operationId: Int64) async -> CoreHostReply {
        .networkFailure(.init(operationId: operationId,
                              error: .init(code: .internal, message: "Network capability is unavailable", retryable: false),
                              diagnostics: .init(code: .capabilityUnavailable, phase: .request)))
    }

    func discardUnsent(_ reply: CoreHostReply) async {}

    func executeManga(_ request: M3MangaResourceTransferHostRequest, assets: CoreMangaAssets) async -> CoreHostReply {
        .networkFailure(.init(operationId: request.operationId,
                              error: .init(code: .internal, message: "Manga transfer is unavailable", retryable: false),
                              diagnostics: .init(code: .capabilityUnavailable, phase: .request)))
    }
}

public struct CoreDeliveryTotals: Sendable {
    public fileprivate(set) var terminalCount = 0
    public fileprivate(set) var acknowledgementCount = 0
}

public actor CoreRuntimeActor {
    private struct Route: Decodable {
        let protocolVersion: Int
        let requestId: Int64
        let deliveryId: Int64?
        let type: String
    }

    private enum Terminal: Sendable {
        case result(Data)
        case failure(any Error)
    }

    private struct Pending {
        let method: ReaderCommandMethod
        let finish: @Sendable (Terminal) -> Void
    }

    private struct HostWork {
        let owner: CoreOperationID
        let deliveryId: Int64
        let task: Task<Void, Never>
    }

    public nonisolated let runtimeId = UUID()
    private var transport: CoreTransport?
    private let host: any CoreHost
    private var consumer: Task<Void, Never>?
    private var followingRequestId: Int64 = 1
    private var pending: [CoreOperationID: Pending] = [:]
    private var hostControls: [CoreOperationID: CoreOperationID] = [:]
    private var hostWork: [Int64: HostWork] = [:]
    private var cancelled: Set<CoreOperationID> = []
    private var totals = CoreDeliveryTotals()
    private var closing = false
    private var closeDeadline: Task<Void, Never>?
    private var closeWaiters: [CheckedContinuation<Void, Never>] = []
    private var finalFault: (any Error)?

    private init(host: any CoreHost) { self.host = host }

    public static func open(config: ReaderRuntimeConfig, host: any CoreHost) async throws -> CoreRuntimeActor {
        let runtime = CoreRuntimeActor(host: host)
        try await runtime.start(config)
        do {
            let advertised = host.capabilities
            let applied = try await runtime.request(
                ReaderM2.runtimeSetHostCapabilities,
                M2RuntimeSetHostCapabilitiesParams(extensions: host.protocolExtensions,
                                                   capabilities: advertised, lanes: [], platform: "ios")
            ).value
            guard applied.applied, applied.capabilities == advertised.count, applied.lanes == 0 else {
                throw CoreBridgeFailure.endpointMismatch
            }
            return runtime
        } catch {
            await runtime.close()
            throw error
        }
    }

    private func start(_ config: ReaderRuntimeConfig) throws {
        let stream = AsyncStream<Data>.makeStream(bufferingPolicy: .unbounded)
        transport = try CoreTransport(config: config, sink: CallbackSink(stream.continuation))
        consumer = Task.detached { [weak self] in
            for await bytes in stream.stream {
                guard let self else { break }
                await self.consume(bytes)
            }
        }
    }

    /// A caller holds its original terminal even if the presentation task has
    /// been cancelled. Page observation ends separately in the coordinator.
    public func request<P, V>(
        _ rpc: ReaderRPC<P, V>, _ params: P,
        onDispatched: (@Sendable (CoreOperationID) -> Void)? = nil
    ) async throws -> CoreOperation<V> {
        try Task.checkCancellation()
        guard !closing, transport != nil else { throw finalFault ?? CoreBridgeFailure.closed }
        return try await perform(rpc, params, onDispatched: onDispatched)
    }

    private func perform<P, V>(
        _ rpc: ReaderRPC<P, V>, _ params: P,
        onDispatched: (@Sendable (CoreOperationID) -> Void)?
    ) async throws -> CoreOperation<V> {
        guard let transport else { throw finalFault ?? CoreBridgeFailure.closed }
        let id = allocateOperationID()
        let encoded = try rpc.encode(requestId: id.requestId, params: params)
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = Pending(method: rpc.method) { terminal in
                do {
                    switch terminal {
                    case .result(let data):
                        let decoded = try rpc.decode(data)
                        guard decoded.requestId == id.requestId else { throw CoreBridgeFailure.endpointMismatch }
                        continuation.resume(returning: CoreOperation(id: id, value: decoded.data))
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                } catch {
                    continuation.resume(throwing: error)
                }
            }
            do {
                try transport.send(encoded)
                onDispatched?(id)
            } catch {
                pending.removeValue(forKey: id)?.finish(.failure(error))
            }
        }
    }

    public func cancel(_ id: CoreOperationID) throws {
        guard id.runtimeId == runtimeId, id.requestId > 0 else { throw CoreBridgeFailure.endpointMismatch }
        guard let transport else { throw CoreBridgeFailure.closed }
        try transport.cancel(id.requestId)
        if pending[id] != nil {
            cancelled.insert(id)
            cancelHostWork(owner: id)
        }
    }

    public func deliveries() -> CoreDeliveryTotals { totals }

    public func close(grace: Duration = .seconds(5)) async {
        guard transport != nil else { return }
        if !closing {
            closing = true
            closeDeadline = Task { [weak self] in
                do { try await Task.sleep(for: grace) } catch { return }
                await self?.stop(fault: CoreBridgeFailure.closed)
            }
        }
        if pending.isEmpty && hostWork.isEmpty {
            stop(fault: nil)
            return
        }
        await withCheckedContinuation { closeWaiters.append($0) }
    }

    private func allocateOperationID() -> CoreOperationID {
        defer { followingRequestId += 1 }
        return operationID(followingRequestId)
    }

    private func operationID(_ requestId: Int64) -> CoreOperationID {
        CoreOperationID(runtimeId: runtimeId, requestId: requestId)
    }

    private func consume(_ bytes: Data) {
        guard let transport else { return }
        do {
            let decoder = JSONDecoder()
            let route = try decoder.decode(Route.self, from: bytes)
            guard route.protocolVersion == 1 else { throw CoreBridgeFailure.invalidEvent }
            if route.type == "host.request" {
                guard let deliveryId = route.deliveryId, deliveryId > 0 else {
                    throw CoreBridgeFailure.invalidEvent
                }
                let event = try decoder.decode(ReaderHostRequestEvent.self, from: bytes)
                let owner = operationID(event.requestId)
                guard pending[owner] != nil, !cancelled.contains(owner) else {
                    try transport.acknowledge(deliveryId)
                    totals.acknowledgementCount += 1
                    return
                }
                guard hostWork[event.operationId] == nil else { throw CoreBridgeFailure.invalidEvent }
                let networkRequest = try CoreNetworkHostRequest(capability: event.capability, bytes: bytes)
                let mangaRequest = event.capability == .mangaResourceTransfer
                    ? try decoder.decode(M3MangaResourceTransferHostRequest.self, from: bytes) : nil
                let task = Task { [weak self, host] in
                    let reply: CoreHostReply
                    if let mangaRequest, let self {
                        let assets = await self.mangaAssets(for: mangaRequest)
                        reply = await host.executeManga(mangaRequest, assets: assets)
                    } else if let networkRequest {
                        reply = await host.executeNetwork(networkRequest, operationId: event.operationId)
                    } else {
                        reply = await host.execute(event)
                    }
                    if await self?.respond(operationId: event.operationId, reply: reply) != true {
                        await host.discardUnsent(reply)
                    }
                }
                hostWork[event.operationId] = HostWork(owner: owner, deliveryId: deliveryId, task: task)
                return
            }
            let id = operationID(route.requestId)
            if let owner = hostControls.removeValue(forKey: id) {
                guard route.type == "error", let deliveryId = route.deliveryId, deliveryId > 0 else {
                    throw CoreBridgeFailure.invalidEvent
                }
                let rejection = try decoder.decode(ReaderM1ErrorEvent.self, from: bytes)
                try transport.acknowledge(deliveryId)
                totals.acknowledgementCount += 1
                if pending[owner] != nil {
                    throw CoreHostControlRejection(owner: owner, control: id, value: rejection.error)
                }
                return
            }
            let terminal: Terminal
            switch route.type {
            case "result": terminal = .result(bytes)
            case "error":
                let error = CoreRequestFailure(id: id,
                    value: try decoder.decode(ReaderM1ErrorEvent.self, from: bytes).error,
                    m2Value: try decoder.decode(M2ProtocolErrorEvent.self, from: bytes).error)
                terminal = .failure(error)
                if route.requestId == 0 {
                    if let deliveryId = route.deliveryId, deliveryId > 0 {
                        try transport.acknowledge(deliveryId)
                        totals.acknowledgementCount += 1
                    }
                    stop(fault: error)
                    return
                }
            default: throw CoreBridgeFailure.invalidEvent
            }
            guard let deliveryId = route.deliveryId, deliveryId > 0 else {
                throw CoreBridgeFailure.invalidEvent
            }
            // Consume and decode using the request's own codec before returning
            // the original runtime's delivery credit.
            if let original = pending.removeValue(forKey: id) {
                cancelled.remove(id)
                cancelHostWork(owner: id)
                hostControls = hostControls.filter { $0.value != id }
                original.finish(terminal)
                totals.terminalCount += 1
            }
            try transport.acknowledge(deliveryId)
            totals.acknowledgementCount += 1
            finishCloseIfDrained()
        } catch {
            stop(fault: error)
        }
    }

    private func respond(operationId: Int64, reply: CoreHostReply) -> Bool {
        guard let transport, let work = hostWork.removeValue(forKey: operationId) else { return false }
        defer { finishCloseIfDrained() }
        do {
            // The physical slot consumed the typed request on this runtime.
            try transport.acknowledge(work.deliveryId)
            totals.acknowledgementCount += 1
            guard pending[work.owner] != nil, !cancelled.contains(work.owner) else { return false }
            let control = allocateOperationID()
            let encoded = try reply.encode(requestId: control.requestId, operationId: operationId)
            // Accepted control commands emit only the original request's
            // terminal. A rejected control can emit its own error receipt.
            hostControls[control] = work.owner
            try transport.send(encoded)
            return true
        } catch {
            stop(fault: error)
            return false
        }
    }

    private func cancelHostWork(owner: CoreOperationID) {
        for work in hostWork.values where work.owner == owner { work.task.cancel() }
    }

    private func mangaAssets(for request: M3MangaResourceTransferHostRequest) -> CoreMangaAssets {
        CoreMangaAssets(
            perform: { [weak self] action in
                guard let self else { throw CoreBridgeFailure.closed }
                return try await self.performMangaAsset(action, for: request)
            }
        )
    }

    private func performMangaAsset(_ action: CoreMangaAssets.Action,
                                   for request: M3MangaResourceTransferHostRequest) throws -> CoreMangaAssets.Result {
        let owner = operationID(request.requestId)
        guard let transport, hostWork[request.operationId]?.owner == owner,
              pending[owner] != nil, !cancelled.contains(owner) else {
            throw CancellationError()
        }
        return try transport.performMangaAsset(action, for: request)
    }

    private func finishCloseIfDrained() {
        if transport != nil, closing, pending.isEmpty, hostWork.isEmpty { stop(fault: nil) }
    }

    private func stop(fault: (any Error)?) {
        finalFault = fault
        closeDeadline?.cancel()
        closeDeadline = nil
        consumer?.cancel()
        consumer = nil
        for work in hostWork.values { work.task.cancel() }
        hostWork.removeAll()
        cancelled.removeAll()
        transport?.destroy()
        transport = nil
        let originalRequests = pending.values
        pending.removeAll()
        hostControls.removeAll()
        for request in originalRequests {
            request.finish(.failure(fault ?? CoreBridgeFailure.closed))
        }
        for continuation in closeWaiters { continuation.resume() }
        closeWaiters.removeAll()
    }
}
