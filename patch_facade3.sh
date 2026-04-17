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

    public init(networkPolicyLayer: NetworkPolicyLayer) {
        self.networkPolicyLayer = networkPolicyLayer
    }

    public convenience init(httpClient: any HTTPClient) {
        self.init(
            networkPolicyLayer: NetworkPolicyLayer(httpClient: httpClient)
        )
    }

    public func search(source: BookSource, query: SearchQuery) async throws -> [SearchResultItem] {
        let response = try await networkPolicyLayer.performSearch(source: source, query: query)
        let html = String(data: response.data, encoding: .utf8) ?? ""
        return try NonJSParserEngine().parseSearch(html: html, source: source)
    }

    public func fetchTOC(source: BookSource, detailURL: String) async throws -> [TOCItem] {
        let response = try await networkPolicyLayer.performTOC(source: source, detailURL: detailURL)
        let html = String(data: response.data, encoding: .utf8) ?? ""
        return try NonJSParserEngine().parseTOC(html: html, source: source)
    }

    public func fetchContent(source: BookSource, chapterURL: String) async throws -> ContentPage {
        let response = try await networkPolicyLayer.performContent(source: source, chapterURL: chapterURL)
        let html = String(data: response.data, encoding: .utf8) ?? ""
        let content = try NonJSParserEngine().parseContent(html: html, source: source)
        return ContentPage(title: "", content: content, chapterURL: chapterURL)
    }
}
FACADE_EOF
