import Foundation

public struct ReaderDirectoryNode: Codable, Hashable, Sendable, Identifiable {
    public let nodeId: String
    public let parentId: String?
    public let depth: UInt32
    public let title: String
    public let displayTitle: String?
    public let isVip: Bool?
    public let isPay: Bool?
    public let contextTitle: String?
    public let kind: String
    public let chapterIndex: UInt32?
    public let chapterOffsetScalar: UInt64?
    public let hasChildren: Bool
    public let expanded: Bool
    public var id: String { nodeId }
    public var navigable: Bool { kind == "target" && chapterIndex != nil }
}
public struct ReaderDirectorySnapshot: Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    /// Core `ready` carries its view/proof. Host `canonical` authorizes only
    /// the existing canonical TXT chapter consumer, with no fabricated nodes.
    public let status: String
    public let reason: String?
    public let viewId: String?
    public let catalogRevision: String?
    public let structureRevision: String?
    public let nodes: [ReaderDirectoryNode]
}
public struct ReaderDirectoryProof: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let catalogRevision: String
    public let structureRevision: String
    public let nodeId: String
    public let chapterIndex: UInt32
    public let url: String
}
public struct ReaderDirectoryTarget: Codable, Hashable, Sendable {
    public let sourceId: String
    public let bookId: String
    public let catalogRevision: String
    public let structureRevision: String
    public let viewId: String
    public let nodeId: String
    public let kind: String
    public let chapterIndex: UInt32
    public let chapterOffsetScalar: UInt64?
    public let positionScope: ReaderContentPositionScope?
    public let directoryTargetProof: ReaderDirectoryProof
}
private struct ReaderDirectoryPage: Decodable {
    let status: String?
    let reason: String?
    let sourceId: String?
    let bookId: String?
    let viewId: String?
    let catalogRevision: String?
    let structureRevision: String?
    let nodes: [ReaderDirectoryNode]?
    let nextOffset: Int?
}

extension ReaderLibraryService {
    public func directory(for book: ReaderBook, query: String = "", descending: Bool = false,
                          collapsedNodeIDs: [String] = []) async throws -> ReaderDirectorySnapshot {
        let first = try decode(ReaderDirectoryPage.self, await coreRead("reading.directory.view.open.v2", [
            "sourceId": book.sourceId, "bookId": book.bookId, "query": query,
            "descending": descending, "collapsedNodeIds": collapsedNodeIDs, "limit": 256
        ]))
        guard first.sourceId == book.sourceId, first.bookId == book.bookId else {
            throw ReaderLibraryError.invalidResponse("directory book identity")
        }
        if first.status == "unavailable" {
            if book.sourceId == "local", first.reason == "navigationMissingOrStale" {
                let presentation = try await localPresentationKind(for: book)
                if presentation.kind == .text, !presentation.reimportRequired {
                    // Default TXT import has authoritative flat chapters but
                    // no optional display navigation. Reading this mode never
                    // prepares rules, writes an intent or synthesizes v2 proof.
                    return ReaderDirectorySnapshot(sourceId: book.sourceId, bookId: book.bookId, status: "canonical",
                        reason: nil, viewId: nil, catalogRevision: nil, structureRevision: nil, nodes: [])
                }
            }
            return ReaderDirectorySnapshot(sourceId: book.sourceId, bookId: book.bookId, status: "unavailable",
                reason: first.reason, viewId: nil, catalogRevision: nil, structureRevision: nil, nodes: [])
        }
        guard first.status == "ready", first.sourceId == book.sourceId, first.bookId == book.bookId,
              let viewID = first.viewId, let catalog = first.catalogRevision, let structure = first.structureRevision,
              let firstNodes = first.nodes else { throw ReaderLibraryError.invalidResponse("directory view identity") }
        var nodes = firstNodes
        var next = first.nextOffset
        var visited: Set<Int> = []
        while let offset = next {
            guard visited.insert(offset).inserted, nodes.count <= 50_000 else { throw ReaderLibraryError.invalidResponse("directory pagination") }
            let page = try decode(ReaderDirectoryPage.self, await coreRead("reading.directory.view.page.v2", [
                "sourceId": book.sourceId, "bookId": book.bookId, "viewId": viewID,
                "catalogRevision": catalog, "structureRevision": structure, "offset": offset, "limit": 256
            ]))
            guard page.sourceId == book.sourceId, page.bookId == book.bookId, page.viewId == viewID,
                  page.catalogRevision == catalog, page.structureRevision == structure,
                  let pageNodes = page.nodes else { throw ReaderLibraryError.invalidResponse("directory page identity") }
            nodes.append(contentsOf: pageNodes)
            next = page.nextOffset
        }
        guard Set(nodes.map(\.nodeId)).count == nodes.count else { throw ReaderLibraryError.invalidResponse("duplicate directory node") }
        return ReaderDirectorySnapshot(sourceId: book.sourceId, bookId: book.bookId, status: "ready", reason: nil,
            viewId: viewID, catalogRevision: catalog, structureRevision: structure, nodes: nodes)
    }

    public func resolveDirectoryTarget(_ node: ReaderDirectoryNode, in snapshot: ReaderDirectorySnapshot) async throws -> ReaderDirectoryTarget {
        guard snapshot.status == "ready", node.navigable, snapshot.nodes.contains(node),
              let view = snapshot.viewId, let catalog = snapshot.catalogRevision,
              let structure = snapshot.structureRevision else { throw ReaderLibraryError.invalidPosition }
        let target = try decode(ReaderDirectoryTarget.self, await coreRead("reading.directory.target.resolve.v2", [
            "sourceId": snapshot.sourceId, "bookId": snapshot.bookId, "viewId": view,
            "catalogRevision": catalog, "structureRevision": structure, "nodeId": node.nodeId
        ]))
        guard target.sourceId == snapshot.sourceId, target.bookId == snapshot.bookId,
              target.viewId == view, target.catalogRevision == catalog, target.structureRevision == structure,
              target.nodeId == node.nodeId, target.directoryTargetProof.nodeId == node.nodeId,
              target.chapterIndex == target.directoryTargetProof.chapterIndex else { throw ReaderLibraryError.invalidPosition }
        return target
    }

    public func content(for book: ReaderBook, target: ReaderDirectoryTarget) async throws -> ReaderChapterContent {
        guard target.sourceId == book.sourceId, target.bookId == book.bookId,
              target.directoryTargetProof.sourceId == book.sourceId, target.directoryTargetProof.bookId == book.bookId else {
            throw ReaderLibraryError.invalidPosition
        }
        let proof = try object(JSONEncoder().encode(target.directoryTargetProof))
        if book.sourceId != "local" {
            return try await onlineContent(for: book, chapterIndex: target.chapterIndex, directoryTargetProof: proof)
        }
        let result = try decode(ReaderChapterContent.self, await coreRead("local_book.chapter.content", [
            "bookId": book.bookId, "chapterIndex": target.chapterIndex, "directoryTargetProof": proof
        ]))
        guard result.sourceId == book.sourceId, result.bookId == book.bookId, result.chapterIndex == target.chapterIndex else {
            throw ReaderLibraryError.invalidPosition
        }
        return result
    }

    public func ebookPresentation(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderEbookDocument {
        let source = try retainedSourceURL(for: book)
        let descriptor = try decode(ReaderEbookDocument.self, await coreRead("local_book.chapter.presentation.v1", [
            "bookId": book.bookId, "chapterIndex": chapterIndex, "localSourcePath": source.path
        ]))
        // ReaderEbookDocument validates its canonical document/range in the
        // rendering boundary; identity must already match this selected book.
        guard descriptor.sourceId == book.sourceId, descriptor.bookId == book.bookId,
              descriptor.chapterIndex == chapterIndex else { throw ReaderLibraryError.invalidPosition }
        return descriptor
    }
}
