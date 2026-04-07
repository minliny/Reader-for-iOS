// ReaderCoreJSRenderer/UnavailableRenderClient.swift
// Stub implementation used when JS rendering is not yet available.
// Allows callers to compile and handle the unavailability gracefully.

import Foundation

/// A JSRenderClient that always throws notAvailable.
/// Used as a placeholder until WKWebViewRenderClient is implemented.
public final class UnavailableRenderClient: JSRenderClient, @unchecked Sendable {
    public init() {}

    public func fetchHTML(url: String, timeout: TimeInterval) async throws -> String {
        throw JSRenderError.notAvailable(
            reason: "ReaderCoreJSRenderer is not yet implemented. " +
                    "Tier-C sites (JS gate required) cannot be accessed until WKWebViewRenderClient is complete. " +
                    "See docs/design/js_rendering_poc_plan.md"
        )
    }
}
