import Foundation
import ReaderCoreBridge
import ReaderHost

@MainActor
final class MangaPageAssets {
    private struct Entry {
        let transferID: String
        let file: MangaResourceFile
        let inspection: M3MangaResourceInspectData
    }

    private let runtime: CoreRuntimeActor
    private let transfers: MangaTransferStore
    private var cached: [String: Entry] = [:]
    private var order: [String] = []
    private var generation = 0

    init(runtime: CoreRuntimeActor, transfers: MangaTransferStore) {
        self.runtime = runtime
        self.transfers = transfers
    }

    func decode(_ page: M3MangaManifestPage, manifest: M3MangaWindowManifest, preferredWidth: Int)
    async throws -> (image: MangaTileImage, file: MangaResourceFile) {
        let expected = generation
        let key = manifest.manifestVersion + "/" + page.resourceRef
        if let hit = cached[key] {
            do {
                let image = try await MangaImageDecoder.shared.decode(hit.file, inspection: hit.inspection,
                                                                     preferredWidth: preferredWidth)
                guard expected == generation else { throw CancellationError() }
                return (image, hit.file)
            } catch MangaImageFailure.pixelBudget {
                throw MangaImageFailure.pixelBudget
            } catch {
                cached.removeValue(forKey: key)
                order.removeAll { $0 == key }
                await transfers.discard(hit.transferID)
                throw error
            }
        }

        // Keep compressed images for the last two pages in this session. The
        // shared Host disk budget still applies across multiple sessions.
        if order.count >= 2, let oldest = order.first {
            order.removeFirst()
            if let previous = cached.removeValue(forKey: oldest) { await transfers.discard(previous.transferID) }
        }
        let transfer = UUID().uuidString
        let inspection = UUID().uuidString
        try await transfers.register(transfer)
        do {
            let prepared = try await runtime.request(ReaderM3.mangaResourcePrepare, .init(
                chapter: manifest.chapter, manifestVersion: manifest.manifestVersion, resourceRef: page.resourceRef,
                sourceRuleVersion: manifest.sourceRuleVersion, transferId: transfer
            )).value
            guard expected == generation else { throw CancellationError() }
            guard prepared.prepared, prepared.transferId == transfer, prepared.resourceRef == page.resourceRef,
                  let file = await transfers.result(transfer), file.bytes == prepared.bytes else {
                throw CoreBridgeFailure.endpointMismatch
            }
            try await transfers.registerInspection(inspection, of: transfer)
            let inspected = try await runtime.request(ReaderM3.mangaResourceInspect, .init(
                transferId: inspection, sha256: file.sha256, bytes: Int64(file.bytes)
            )).value
            await transfers.endInspection(inspection)
            let image = try await MangaImageDecoder.shared.decode(file, inspection: inspected, preferredWidth: preferredWidth)
            guard expected == generation else { throw CancellationError() }
            cached[key] = Entry(transferID: transfer, file: file, inspection: inspected)
            order.append(key)
            return (image, file)
        } catch {
            await transfers.endInspection(inspection)
            await transfers.discard(transfer)
            throw error
        }
    }

    func reset() async {
        generation += 1
        let files = cached.values.map(\.transferID)
        cached.removeAll()
        order.removeAll()
        for id in files { await transfers.discard(id) }
    }
}
