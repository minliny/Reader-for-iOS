import Foundation

public enum CoreNetworkHostRequest: Sendable {
    case http(M2HostHttpRequest)
    case cookieGet(M2HostCookieGetRequest)
    case cookieSet(M2HostCookieSetRequest)
    case webView(M2HostWebViewEvaluateJavaScriptRequest)
    case media(M2HostMediaDownloadRequest)

    init?(capability: ReaderHostCapability, bytes: Data) throws {
        let decoder = JSONDecoder()
        switch capability {
        case .httpExecute:
            self = .http(try decoder.decode(M2HttpExecuteHostRequest.self, from: bytes).params)
        case .cookieGet:
            self = .cookieGet(try decoder.decode(M2CookieGetHostRequest.self, from: bytes).params)
        case .cookieSet:
            self = .cookieSet(try decoder.decode(M2CookieSetHostRequest.self, from: bytes).params)
        case .webviewEvaluateJavaScript:
            self = .webView(try decoder.decode(M2WebViewEvaluateJavaScriptHostRequest.self, from: bytes).params)
        case .mediaDownload:
            self = .media(try decoder.decode(M2MediaDownloadHostRequest.self, from: bytes).params)
        default:
            return nil
        }
    }
}

extension CoreHostReply {
    func encode(requestId: Int64, operationId: Int64) throws -> Data {
        switch self {
        case .echo(let value):
            try ReaderM1.hostComplete.encode(requestId: requestId, params: .init(operationId: operationId, result: value))
        case .time(let value):
            try ReaderM1.hostCompleteTimeNow.encode(requestId: requestId, params: .init(operationId: operationId, result: value))
        case .failure(let response):
            try Self.encodeFailure(ReaderM1.hostError, requestId: requestId, operationId: operationId,
                                   responseOperationId: response.operationId, response: response)
        case .networkFailure(let response):
            try Self.encodeFailure(ReaderM2.hostError, requestId: requestId, operationId: operationId,
                                   responseOperationId: response.operationId, response: response)
        case .http(let value):
            try ReaderM2.hostCompleteHttpExecute.encode(requestId: requestId,
                                                       params: .init(operationId: operationId, result: value))
        case .cookieGet(let value):
            try ReaderM2.hostCompleteCookieGet.encode(requestId: requestId,
                                                     params: .init(operationId: operationId, result: value))
        case .cookieSet(let value):
            try ReaderM2.hostCompleteCookieSet.encode(requestId: requestId,
                                                     params: .init(operationId: operationId, result: value))
        case .webView(let value):
            try ReaderM2.hostCompleteWebViewEvaluateJavaScript.encode(requestId: requestId,
                                                                    params: .init(operationId: operationId, result: value))
        case .media(let value):
            try ReaderM2.hostCompleteMediaDownload.encode(requestId: requestId,
                                                          params: .init(operationId: operationId, result: value))
        case .mangaInput(let value):
            try ReaderM3.hostCompleteMangaTransferInput.encode(requestId: requestId,
                                                              params: .init(operationId: operationId, result: value))
        case .mangaOutput(let value):
            try ReaderM3.hostCompleteMangaTransferOutput.encode(requestId: requestId,
                                                               params: .init(operationId: operationId, result: value))
        }
    }

    private static func encodeFailure<P, V>(
        _ rpc: ReaderRPC<P, V>, requestId: Int64, operationId: Int64,
        responseOperationId: Int64, response: P
    ) throws -> Data {
        guard responseOperationId == operationId else { throw CoreBridgeFailure.endpointMismatch }
        return try rpc.encode(requestId: requestId, params: response)
    }
}
