import CryptoKit
import Foundation
import ImageIO
import ReaderCoreBridge

extension NetworkAndWebHost {
    public func executeManga(_ request: M3MangaResourceTransferHostRequest, assets: CoreMangaAssets) async -> CoreHostReply {
        do {
            switch request.params {
            case .input(let params):
                return .mangaInput(try await acceptImage(params, request: request, assets: assets))
            case .inspectInput(let params):
                return .mangaInput(try await inspectImage(params, request: request, assets: assets))
            case .output(let params):
                return .mangaOutput(try await MangaResourceTransfer.consume(params, assets: assets, store: mangaTransfers))
            }
        } catch {
            return NetworkHostFailure.classified(error).reply(operationId: request.operationId)
        }
    }

    private func acceptImage(_ params: M3MangaTransferInput, request: M3MangaResourceTransferHostRequest,
                             assets: CoreMangaAssets) async throws -> M3MangaTransferInputReceipt {
        try await mangaTransfers.enterTransfer()
        do {
            let bytes = try await imageBytes(params)
            let size = params.inspectGraphics ? try MangaResourceTransfer.dimensions(bytes) : nil
            let result = try await MangaResourceTransfer.send(bytes, assets: assets, operation: request.operationId,
                                                              dimensions: size)
            await mangaTransfers.leaveTransfer()
            return result
        } catch {
            await mangaTransfers.leaveTransfer()
            throw error
        }
    }

    private func inspectImage(_ params: M3MangaTransferInspectInput, request: M3MangaResourceTransferHostRequest,
                              assets: CoreMangaAssets) async throws -> M3MangaTransferInputReceipt {
        try await mangaTransfers.enterTransfer()
        do {
            let file = try await mangaTransfers.fileForInspection(params)
            let bytes = try Data(contentsOf: file.url, options: .mappedIfSafe)
            guard bytes.count == file.bytes, SHA256.hash(data: bytes).map({ String(format: "%02x", $0) }).joined() == file.sha256 else {
                throw NetworkHostFailure.invalid("Manga inspection file changed")
            }
            let result = try await MangaResourceTransfer.send(bytes, assets: assets, operation: request.operationId)
            await mangaTransfers.leaveTransfer()
            return result
        } catch {
            await mangaTransfers.leaveTransfer()
            throw error
        }
    }

    private func imageBytes(_ params: M3MangaTransferInput) async throws -> Data {
        let limit = Int(params.maxBytes.rawValue)
        switch params.request {
        case .dataUri(let input):
            let uri = input.dataUri
            guard let comma = uri.firstIndex(of: ","), let prefix = uri[..<comma].lowercased().split(separator: ";").first,
                  prefix.hasPrefix("data:image/"), uri[..<comma].lowercased().hasSuffix(";base64"),
                  uri.utf8.count <= (limit + 2) / 3 * 4 + 256,
                  let bytes = Data(base64Encoded: String(uri[uri.index(after: comma)...])),
                  !bytes.isEmpty, bytes.count <= limit else {
                throw NetworkHostFailure.invalid("Unsupported or oversized manga image data URI")
            }
            return bytes
        case .http(let input):
            let model = M2HostHttpRequest(
                timeoutMs: input.timeoutMs, url: input.url, method: input.method, headers: input.headers,
                body: input.body, charset: input.charset, followRedirects: input.followRedirects, maxRedirects: input.maxRedirects,
                retry: input.retry.map { .init(maxAttempts: $0.maxAttempts, backoffMillis: $0.backoffMillis) },
                usePlatformCookieJar: input.usePlatformCookieJar, session: input.session.map { .init(id: $0.id) }
            )
            let request = try URLSessionNetwork.request(model)
            let useCookies = input.usePlatformCookieJar ?? (input.session != nil)
            let profile = try useCookies ? cookies.profile(session: input.session?.id, url: request.url) : nil
            try await profile?.pullFromWeb()
            let exchange = try await URLSessionNetwork.execute(request, params: model, jar: profile?.jar, bodyLimit: limit)
            if let profile {
                for cookie in URLSessionNetwork.cookies(from: exchange.redirects + [exchange.response]) {
                    try await profile.write(cookie)
                }
            }
            guard (200...299).contains(exchange.response.statusCode) else {
                throw NetworkHostFailure.status(exchange.response.statusCode)
            }
            return exchange.data
        }
    }
}

private enum MangaResourceTransfer {
    static func send(_ data: Data, assets: CoreMangaAssets, operation: Int64,
                     dimensions: (width: Int64, height: Int64)? = nil) async throws -> M3MangaTransferInputReceipt {
        let id = try await assets.begin(bytes: data.count)
        do {
            for offset in stride(from: 0, to: data.count, by: CoreMangaAssets.chunkLimit) {
                try Task.checkCancellation()
                let end = min(offset + CoreMangaAssets.chunkLimit, data.count)
                let written = try await assets.write(id, bytes: data.subdata(in: offset..<end))
                guard written == end else { throw CoreBridgeFailure.endpointMismatch }
            }
            let committed = try await assets.commit(id)
            guard committed == data.count, let assetID = Int64(exactly: id) else { throw CoreBridgeFailure.endpointMismatch }
            return .init(assetId: assetID, operationId: operation, bytes: Int64(data.count),
                         width: dimensions?.width, height: dimensions?.height)
        } catch {
            try? await assets.release(id)
            throw error
        }
    }

    static func consume(_ params: M3MangaTransferOutput, assets: CoreMangaAssets,
                        store: MangaTransferStore) async throws -> M3MangaTransferOutputReceipt {
        guard let count = Int(exactly: params.bytes), (1...CoreMangaAssets.assetLimit).contains(count) else {
            throw NetworkHostFailure.invalid("Invalid committed image length")
        }
        let transformLimit = 8 * CoreMangaAssets.chunkLimit
        let scratch = params.graphicsPlan == nil ? 0 : transformLimit
        let url = try await store.reserve(params.transferId, bytes: count, scratch: scratch)
        do {
            guard FileManager.default.createFile(atPath: url.path, contents: nil) else {
                throw NetworkHostFailure(code: .internal, phase: .storage, message: "Manga staging file unavailable")
            }
            let handle = try FileHandle(forWritingTo: url)
            defer { try? handle.close() }
            var digest = SHA256()
            var chunks = 0
            for offset in stride(from: 0, to: count, by: CoreMangaAssets.chunkLimit) {
                try Task.checkCancellation()
                let length = min(count - offset, CoreMangaAssets.chunkLimit)
                let bytes = try await assets.read(offset: offset, limit: length)
                guard bytes.count == length else { throw CoreBridgeFailure.endpointMismatch }
                try handle.write(contentsOf: bytes)
                digest.update(data: bytes)
                chunks += 1
            }
            let eof = try await assets.read(offset: count, limit: 1)
            guard eof.isEmpty else { throw CoreBridgeFailure.endpointMismatch }
            try handle.close()
            try await assets.release()
            if let graphics = params.graphicsPlan {
                let output = try await MangaImageDecoder.shared.transform(url, plan: graphics, byteLimit: transformLimit)
                try Task.checkCancellation()
                try output.write(to: url, options: .atomic)
                let sha = SHA256.hash(data: output).map { String(format: "%02x", $0) }.joined()
                try await store.publish(params.transferId, bytes: output.count, sha256: sha, chunks: chunks)
                return .init(consumed: true, assetId: params.assetId, bytes: params.bytes, preparedBytes: Int64(output.count))
            }
            let sha = digest.finalize().map { String(format: "%02x", $0) }.joined()
            try await store.publish(params.transferId, bytes: count, sha256: sha, chunks: chunks)
            return .init(consumed: true, assetId: params.assetId, bytes: params.bytes)
        } catch {
            try? await assets.release()
            await store.discard(params.transferId)
            throw error
        }
    }

    static func dimensions(_ bytes: Data) throws -> (width: Int64, height: Int64) {
        guard let source = CGImageSourceCreateWithData(bytes as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.int64Value,
              let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.int64Value,
              width > 0, height > 0 else { throw NetworkHostFailure.invalid("Image geometry is unavailable") }
        return (width, height)
    }
}
