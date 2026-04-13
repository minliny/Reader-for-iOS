// TraceInspector.swift
// OT-007: Request / Response Trace Inspector
//
// Provides a pluggable HTTP trace infrastructure for network observability.
// TracingHTTPClient wraps any HTTPClient without modifying its contract,
// recording request/response/error/timing through a TraceSink.
//
// Clean-room: Based solely on ReaderCoreProtocols public contracts.
// No external GPL code. No Legado Android reference.

import Foundation
import ReaderCoreModels
import ReaderCoreProtocols

// MARK: - Trace Data Models

/// A snapshot of an HTTP request for tracing purposes.
/// Headers are redacted per the active redaction policy.
public struct TraceRequest: Sendable, Equatable {
    public let method: String
    public let url: String
    public let headers: [String: String]
    public let bodyPreview: String?
    public let timestamp: Date

    public init(
        method: String,
        url: String,
        headers: [String: String],
        bodyPreview: String? = nil,
        timestamp: Date = Date()
    ) {
        self.method = method
        self.url = url
        self.headers = headers
        self.bodyPreview = bodyPreview
        self.timestamp = timestamp
    }
}

/// A snapshot of an HTTP response for tracing purposes.
/// Headers are redacted per the active redaction policy.
public struct TraceResponse: Sendable, Equatable {
    public let statusCode: Int
    public let headers: [String: String]
    public let bodyPreview: String?
    public let durationMs: Double
    public let timestamp: Date

    public init(
        statusCode: Int,
        headers: [String: String],
        bodyPreview: String? = nil,
        durationMs: Double,
        timestamp: Date = Date()
    ) {
        self.statusCode = statusCode
        self.headers = headers
        self.bodyPreview = bodyPreview
        self.durationMs = durationMs
        self.timestamp = timestamp
    }
}

/// A complete trace record for a single HTTP exchange.
public struct TraceRecord: Sendable, Equatable {
    public let id: UUID
    public let request: TraceRequest
    public let response: TraceResponse?
    public let error: String?
    public let metadata: [String: String]

    public init(
        id: UUID = UUID(),
        request: TraceRequest,
        response: TraceResponse? = nil,
        error: String? = nil,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.request = request
        self.response = response
        self.error = error
        self.metadata = metadata
    }
}

// MARK: - Trace Sink Protocol

/// Receives trace records. Implementations decide where to store or forward them.
public protocol TraceSink: Sendable {
    func record(_ trace: TraceRecord) async
}

// MARK: - In-Memory Trace Collector

/// Default in-memory trace sink. Accumulates all trace records for later inspection.
/// Thread-safe via actor isolation.
public actor InMemoryTraceCollector: TraceSink {
    private var records: [TraceRecord] = []

    public init() {}

    public func record(_ trace: TraceRecord) {
        records.append(trace)
    }

    /// All collected trace records in order.
    public func allRecords() -> [TraceRecord] {
        records
    }

    /// Number of collected records.
    public var count: Int {
        records.count
    }

    /// Clear all records.
    public func clear() {
        records.removeAll()
    }
}

// MARK: - Header Redaction

/// Policy for redacting sensitive headers in trace records.
public struct HeaderRedactionPolicy: Sendable, Equatable {
    /// Header names that should be redacted (case-insensitive matching).
    public let sensitiveHeaders: Set<String>

    /// The replacement value for redacted headers.
    public let redactedValue: String

    public init(
        sensitiveHeaders: Set<String> = Self.defaultSensitiveHeaders,
        redactedValue: String = "[REDACTED]"
    ) {
        // Normalize to lowercase for case-insensitive comparison
        self.sensitiveHeaders = Set(sensitiveHeaders.map { $0.lowercased() })
        self.redactedValue = redactedValue
    }

    /// Default sensitive header names.
    public static let defaultSensitiveHeaders: Set<String> = [
        "authorization",
        "cookie",
        "set-cookie",
        "x-api-key",
        "token",
        "bearer",
        "proxy-authorization",
        "x-auth-token",
        "x-csrf-token",
        "x-xsrf-token",
    ]

    /// Redact sensitive headers in a dictionary.
    public func redact(_ headers: [String: String]) -> [String: String] {
        var result = headers
        for key in result.keys {
            if sensitiveHeaders.contains(key.lowercased()) {
                result[key] = redactedValue
            }
        }
        return result
    }
}

// MARK: - Body Preview Configuration

/// Configuration for body preview extraction.
public struct BodyPreviewConfig: Sendable, Equatable {
    /// Maximum number of bytes to include in body preview.
    public let maxBytes: Int

    /// Whether to include body previews at all.
    public let enabled: Bool

    public init(maxBytes: Int = 1024, enabled: Bool = true) {
        self.maxBytes = maxBytes
        self.enabled = enabled
    }

    /// Extract a body preview string from Data.
    /// Binary data is represented as a hex dump; text data is truncated.
    public func preview(from data: Data?) -> String? {
        guard enabled, let data, !data.isEmpty else { return nil }

        let truncated = data.prefix(maxBytes)
        // Attempt UTF-8 decode
        if let string = String(data: truncated, encoding: .utf8) {
            if data.count > maxBytes {
                return string + "…[\(data.count) bytes total]"
            }
            return string
        }
        // Binary: hex preview
        let hex = truncated.prefix(64).map { String(format: "%02x", $0) }.joined(separator: " ")
        if data.count > maxBytes {
            return "<binary \(hex)…> [\(data.count) bytes total]"
        }
        return "<binary \(hex)>"
    }
}

// MARK: - Trace Configuration

/// Configuration for the TracingHTTPClient.
public struct TraceConfig: Sendable {
    public let redactionPolicy: HeaderRedactionPolicy
    public let bodyPreviewConfig: BodyPreviewConfig
    public let sink: (any TraceSink)?

    public init(
        redactionPolicy: HeaderRedactionPolicy = HeaderRedactionPolicy(),
        bodyPreviewConfig: BodyPreviewConfig = BodyPreviewConfig(),
        sink: (any TraceSink)? = nil
    ) {
        self.redactionPolicy = redactionPolicy
        self.bodyPreviewConfig = bodyPreviewConfig
        self.sink = sink
    }
}

// MARK: - Tracing HTTP Client (Decorator)

/// An HTTPClient decorator that traces all requests, responses, and errors.
///
/// Wraps any `HTTPClient` without modifying its contract. Each `send()` call:
/// 1. Captures the request with timestamp
/// 2. Delegates to the underlying client
/// 3. Captures the response (or error) with timing
/// 4. Records the full trace through the configured `TraceSink`
///
/// Usage:
/// ```swift
/// let collector = InMemoryTraceCollector()
/// let tracingClient = TracingHTTPClient(
///     wrapping: underlyingClient,
///     config: TraceConfig(sink: collector)
/// )
/// // Use tracingClient wherever HTTPClient is needed
/// let response = try await tracingClient.send(request)
/// // Inspect traces
/// let traces = await collector.allRecords()
/// ```
public final class TracingHTTPClient: HTTPClient, @unchecked Sendable {
    private let wrapped: any HTTPClient
    private let config: TraceConfig

    public init(wrapping client: any HTTPClient, config: TraceConfig = TraceConfig()) {
        self.wrapped = client
        self.config = config
    }

    public func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let startTimestamp = Date().timeIntervalSince1970
        let requestTimestamp = Date()

        // Build trace request (with redaction and body preview)
        let traceRequest = TraceRequest(
            method: request.method,
            url: request.url,
            headers: config.redactionPolicy.redact(request.headers),
            bodyPreview: config.bodyPreviewConfig.preview(from: request.body),
            timestamp: requestTimestamp
        )

        do {
            let response = try await wrapped.send(request)
            let durationMs = (Date().timeIntervalSince1970 - startTimestamp) * 1000.0

            let traceResponse = TraceResponse(
                statusCode: response.statusCode,
                headers: config.redactionPolicy.redact(response.headers),
                bodyPreview: config.bodyPreviewConfig.preview(from: response.data),
                durationMs: durationMs,
                timestamp: Date()
            )

            let record = TraceRecord(
                request: traceRequest,
                response: traceResponse,
                error: nil
            )
            await config.sink?.record(record)

            return response
        } catch {
            let durationMs = (Date().timeIntervalSince1970 - startTimestamp) * 1000.0

            let record = TraceRecord(
                request: traceRequest,
                response: nil,
                error: String(describing: error),
                metadata: ["durationMs": String(format: "%.3f", durationMs)]
            )
            await config.sink?.record(record)

            throw error
        }
    }
}


