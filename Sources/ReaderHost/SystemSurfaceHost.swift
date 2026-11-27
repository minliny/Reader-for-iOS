import Foundation
import ReaderCoreBridge

public struct SystemSurfaceHost: CoreHost {
    public init() {}

    public let capabilities: [ReaderHostCapability] = [.hostSmokeEcho, .timeNow]

    public func execute(_ request: ReaderHostRequestEvent) async -> CoreHostReply {
        switch request.capability {
        case .hostSmokeEcho:
            if case .string(let message)? = request.params["message"] {
                return .echo(M1HostEchoData(message: message))
            }
        case .timeNow:
            let now = Date()
            return .time(HostTimeNowResponse(
                unixMillis: Int64(now.timeIntervalSince1970 * 1_000),
                iso8601: now.ISO8601Format(), timezone: TimeZone.current.identifier
            ))
        default:
            break
        }
        return .failure(HostErrorParams(
            operationId: request.operationId,
            error: ReaderCoreError(code: .internal, message: "Unsupported host operation", retryable: false)
        ))
    }
}
