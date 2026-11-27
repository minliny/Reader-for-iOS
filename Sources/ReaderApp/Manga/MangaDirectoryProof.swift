import ReaderCoreBridge

enum MangaDirectoryProof {
    static func find(_ chapter: Int64, directory: M2DirectoryViewOpenDataV2, online: OnlineReadingCoordinator,
                     sourceId: String, bookId: String) async throws -> M3DirectoryTargetProof {
        guard let viewId = directory.viewId, let catalog = directory.catalogRevision,
              let structure = directory.structureRevision else { throw CoreBridgeFailure.endpointMismatch }
        var nodes = directory.nodes ?? []
        var next = directory.nextOffset
        while true {
            if let node = nodes.first(where: { $0.chapterIndex == chapter && $0.kind == .target }) {
                let resolved = try await online.resolveTarget(.init(bookId: bookId, viewId: viewId, nodeId: node.nodeId,
                    sourceId: sourceId, catalogRevision: catalog, structureRevision: structure))
                let proof = resolved.directoryTargetProof
                return .init(sourceId: proof.sourceId, bookId: proof.bookId, catalogRevision: proof.catalogRevision,
                    structureRevision: proof.structureRevision, nodeId: proof.nodeId, chapterIndex: proof.chapterIndex,
                    url: proof.url)
            }
            guard let offset = next else { throw CoreBridgeFailure.endpointMismatch }
            let result = try await online.pageDirectory(.init(bookId: bookId, viewId: viewId, offset: offset,
                limit: 100, sourceId: sourceId, catalogRevision: catalog, structureRevision: structure))
            nodes = result.nodes
            next = result.nextOffset
        }
    }
}
