#!/bin/bash
set -e
cat << 'FACADE_EOF' > /workspace/Reader-Core/Core/Sources/ReaderCoreFacade/ReaderFlowCoreFacade.swift
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

    public convenience init(httpClient: any HTTPClient) {
        self.init(
            networkPolicyLayer: NetworkPolicyLayer(httpClient: httpClient),
            parserEngine: NonJSParserEngine()
        )
    }

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        let response = try await networkPolicyLayer.performSearch(source: source, query: query)
        return try parserEngine.parseSearch(html: String(data: response.data, encoding: .utf8) ?? "", source: source)
    }

    public func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        let response = try await networkPolicyLayer.performTOC(source: source, detailURL: detailURL)
        return try parserEngine.parseTOC(html: String(data: response.data, encoding: .utf8) ?? "", source: source)
    }

    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        let response = try await networkPolicyLayer.performContent(source: source, chapterURL: chapterURL)
        let content = try parserEngine.parseContent(html: String(data: response.data, encoding: .utf8) ?? "", source: source)
        return ContentPage(chapterURL: chapterURL, content: content)
    }
}
FACADE_EOF
