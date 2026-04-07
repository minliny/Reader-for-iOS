// ReaderCoreJSRenderer/JSRenderClient.swift
// Experimental module — JS-capable HTML rendering for tier-C sites.
// ISOLATION CONTRACT: This module must never be imported by ReaderCoreParser or ReaderCoreNetwork.

import Foundation

/// Protocol for a client that can fetch HTML after JavaScript execution.
/// Intended for sites behind Cloudflare Browser Integrity Check or similar JS gates.
public protocol JSRenderClient: Sendable {
    /// Fetch HTML from the given URL, allowing JS execution before extraction.
    /// - Parameters:
    ///   - url: The URL to load
    ///   - timeout: Maximum time to wait for JS execution and content availability
    /// - Returns: The full HTML string of the page after JS execution
    /// - Throws: JSRenderError
    func fetchHTML(url: String, timeout: TimeInterval) async throws -> String
}

/// Errors produced by JSRenderClient implementations.
public enum JSRenderError: Error, Sendable {
    case invalidURL(String)
    case timeout(url: String, after: TimeInterval)
    case navigationFailed(url: String, underlying: Error)
    case htmlExtractionFailed(url: String)
    case notAvailable(reason: String)
}
