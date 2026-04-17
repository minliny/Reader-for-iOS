#!/bin/bash
set -e
cd /workspace/Reader-Core
mkdir -p Core/Sources/ReaderCoreFacade
cat << 'FACADE_EOF' > Core/Sources/ReaderCoreFacade/ReaderFlowCoreFacade.swift
import Foundation
import ReaderCoreModels
import ReaderCoreNetwork
import ReaderCoreParser
import ReaderCoreProtocols

public protocol ReadingFlowFacade: Sendable {
    func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem]
    func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem]
    func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage
}

public final class ReaderFlowCoreFacade: ReadingFlowFacade {
    private let networkPolicyLayer: NetworkPolicyLayer
    private let parserEngine: ParserEngine

    public init(networkPolicyLayer: NetworkPolicyLayer, parserEngine: ParserEngine) {
        self.networkPolicyLayer = networkPolicyLayer
        self.parserEngine = parserEngine
    }

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        return try await networkPolicyLayer.performSearch(source: source, query: query, parser: parserEngine)
    }

    public func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        return try await networkPolicyLayer.performTOC(source: source, detailURL: detailURL, parser: parserEngine)
    }

    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        return try await networkPolicyLayer.performContent(source: source, chapterURL: chapterURL, parser: parserEngine)
    }
}
FACADE_EOF

sed -i.bak '/.library(name: "ReaderCoreParser", targets: \["ReaderCoreParser"\]),/a\
        .library(name: "ReaderCoreFacade", targets: ["ReaderCoreFacade"]),\
' Package.swift

sed -i.bak '/.library(name: "ReaderCoreParser", targets: \["ReaderCoreParser"\]),/a\
        .library(name: "ReaderCoreFacade", targets: ["ReaderCoreFacade"]),\
' Core/Package.swift

sed -i.bak '/.target(name: "ReaderCoreParser", dependencies: \["ReaderCoreProtocols", "ReaderCoreModels"\]),/a\
        .target(name: "ReaderCoreFacade", dependencies: ["ReaderCoreNetwork", "ReaderCoreParser", "ReaderCoreProtocols", "ReaderCoreModels"]),\
' Package.swift

sed -i.bak '/.target(name: "ReaderCoreParser", dependencies: \["ReaderCoreProtocols", "ReaderCoreModels"\]),/a\
        .target(name: "ReaderCoreFacade", dependencies: ["ReaderCoreNetwork", "ReaderCoreParser", "ReaderCoreProtocols", "ReaderCoreModels"]),\
' Core/Package.swift
