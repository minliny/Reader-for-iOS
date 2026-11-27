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
}

public protocol CoreHost: Sendable {
    var capabilities: [ReaderHostCapability] { get }
    func execute(_ request: ReaderHostRequestEvent) async -> CoreHostReply
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

    public nonisolated let runtimeId = UUID()
    private var transport: CoreTransport?
    private let host: any CoreHost
    private var consumer: Task<Void, Never>?
    private var followingRequestId: Int64 = 1
    private var pending: [CoreOperationID: Pending] = [:]
    private var hostControls: [CoreOperationID: CoreOperationID] = [:]
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
                ReaderM1.runtimeSetHostCapabilities,
                RuntimeSetHostCapabilitiesParams(capabilities: advertised, lanes: [], platform: "ios")
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
        if pending.isEmpty {
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
                guard pending[operationID(event.requestId)] != nil else {
                    try transport.acknowledge(deliveryId)
                    totals.acknowledgementCount += 1
                    return
                }
                Task { [weak self, host] in
                    let reply = await host.execute(event)
                    await self?.respond(event: event, deliveryId: deliveryId, reply: reply)
                }
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
                let error = try decoder.decode(ReaderM1ErrorEvent.self, from: bytes)
                terminal = .failure(CoreRequestFailure(id: id, value: error.error))
                if route.requestId == 0 {
                    if let deliveryId = route.deliveryId, deliveryId > 0 {
                        try transport.acknowledge(deliveryId)
                        totals.acknowledgementCount += 1
                    }
                    stop(fault: CoreRequestFailure(id: id, value: error.error))
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
                hostControls = hostControls.filter { $0.value != id }
                original.finish(terminal)
                totals.terminalCount += 1
            }
            try transport.acknowledge(deliveryId)
            totals.acknowledgementCount += 1
            if closing && pending.isEmpty { stop(fault: nil) }
        } catch {
            stop(fault: error)
        }
    }

    private func respond(event: ReaderHostRequestEvent, deliveryId: Int64, reply: CoreHostReply) {
        guard let transport else { return }
        do {
            // The physical slot consumed the typed request on this runtime.
            try transport.acknowledge(deliveryId)
            totals.acknowledgementCount += 1
            let owner = operationID(event.requestId)
            guard pending[owner] != nil else { return }
            let control = allocateOperationID()
            let encoded: Data
            switch reply {
            case .echo(let response):
                encoded = try ReaderM1.hostComplete.encode(requestId: control.requestId,
                    params: M1HostCompleteParams(operationId: event.operationId, result: response))
            case .time(let response):
                encoded = try ReaderM1.hostCompleteTimeNow.encode(requestId: control.requestId,
                    params: M1HostTimeCompleteParams(operationId: event.operationId, result: response))
            case .failure(let response):
                guard response.operationId == event.operationId else { throw CoreBridgeFailure.endpointMismatch }
                encoded = try ReaderM1.hostError.encode(requestId: control.requestId, params: response)
            }
            // Accepted control commands emit only the original request's
            // terminal. A rejected control can emit its own error receipt.
            hostControls[control] = owner
            try transport.send(encoded)
        } catch {
            stop(fault: error)
        }
    }

    private func stop(fault: (any Error)?) {
        finalFault = fault
        closeDeadline?.cancel()
        closeDeadline = nil
        consumer?.cancel()
        consumer = nil
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
