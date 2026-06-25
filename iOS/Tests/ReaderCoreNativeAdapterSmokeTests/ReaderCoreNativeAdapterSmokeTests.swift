// ReaderCoreNativeAdapter ShellSmokeTest
//
// Round 1: prove the host adapter connects to the Rust Reader-Core-Native C ABI
// from inside the Reader for iOS app. Runs against the real Core (linked via
// ReaderCore.xcframework), not a stub.
//
// Partitioned evidence:
//   [core]     — exercised through Rust Core via the C ABI / JSON protocol.
//   [app-side] — exercised by the iOS host adapter (ReaderCoreNativeRuntime).
//
// This is wrapper/host smoke, NOT iOS App/device proof. A green run proves the
// adapter compiles, links the xcframework, and drives Core on the build host /
// simulator. It does not prove a device launch or a full reading flow.

import XCTest
@testable import ReaderCoreNativeAdapter

final class ReaderCoreNativeAdapterSmokeTests: XCTestCase {

    // MARK: - [core] ABI / protocol surface

    func test_core_abiVersionIsOne() {
        // [core] rc_abi_version exposes the Rust Core ABI version.
        XCTAssertEqual(ReaderCoreNativeRuntime.abiVersion, 1)
    }

    func test_core_infoReturnsAbiAndProtocolVersion() throws {
        // [core] core.info round-trips through Core and returns version metadata.
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let event = try runtime.request(method: "core.info", requestId: 1, timeout: 5)
        XCTAssertEqual(event.type, "result")
        XCTAssertEqual((event.data?["abiVersion"] as? NSNumber)?.uint32Value, 1)
        XCTAssertEqual((event.data?["protocolVersion"] as? NSNumber)?.uint32Value, 1)
    }

    func test_core_pingReturnsPong() throws {
        // [core] runtime.ping returns pong=true from Core.
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let event = try runtime.request(method: "runtime.ping", requestId: 2, timeout: 5)
        XCTAssertEqual(event.type, "result")
        XCTAssertEqual((event.data?["pong"] as? Bool), true)
    }

    func test_core_unknownMethodSurfacesStructuredError() throws {
        // [core] an unknown method surfaces a structured Core error event.
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        do {
            _ = try runtime.request(method: "no.such.method", requestId: 3, timeout: 5)
            XCTFail("expected coreError for unknown method")
        } catch ReaderCoreNativeError.coreError(let code, _) {
            XCTAssertEqual(code, "UNKNOWN_METHOD")
        }
    }

    func test_core_malformedJSONSendFails() throws {
        // [core] rc_runtime_send rejects malformed JSON with a non-zero status.
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        do {
            _ = try runtime.send(jsonString: "{not valid json")
            XCTFail("expected sendFailed for malformed JSON")
        } catch ReaderCoreNativeError.sendFailed(let status) {
            XCTAssertNotEqual(status, 0)
        }
    }

    // MARK: - [app-side] adapter behavior

    func test_appSide_runtimeCreateAndDestroy() throws {
        // [app-side] the adapter can create and destroy a runtime handle.
        let runtime = try ReaderCoreNativeRuntime()
        runtime.destroy()
        // Destroy is idempotent-safe to call once; a second destroy is a no-op
        // because handle is nilled. We don't call twice to respect the ABI's
        // "at most once" contract.
    }

    func test_appSide_invalidConfigCreateFails() throws {
        // [app-side] the adapter surfaces a create failure for invalid config
        // (unknown field). Core's RuntimeConfig uses deny_unknown_fields.
        let badConfig = try JSONSerialization.data(withJSONObject: [
            "dataDirectory": "/tmp/x", "bogusField": true,
        ])
        do {
            _ = try ReaderCoreNativeRuntime(configJSON: badConfig)
            XCTFail("expected createFailed for unknown config field")
        } catch ReaderCoreNativeError.createFailed(let status) {
            XCTAssertNotEqual(status, 0)
        }
    }

    func test_appSide_pollEventIsNonBlockingAndConsumes() throws {
        // [app-side] pollEvent drains without blocking and a consumed event
        // returns nil on the next poll.
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        // Fire core.info via send (manual), then poll.
        let command = try JSONSerialization.data(withJSONObject: [
            "protocolVersion": 1, "requestId": NSNumber(value: 10),
            "method": "core.info", "params": [:],
        ])
        try runtime.send(json: command)
        // Spin until the event arrives.
        var event: ReaderCoreNativeEvent?
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let e = runtime.pollEvent(requestId: 10) { event = e; break }
        }
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.type, "result")
        // Already consumed — second poll is nil until a new event arrives.
        // (Give a brief window; there should be no further event for this id.)
        Thread.sleep(forTimeInterval: 0.05)
        XCTAssertNil(runtime.pollEvent(requestId: 10))
    }

    func test_appSide_cancelIsAcceptedByCore() throws {
        // [app-side] the adapter can issue a cancel for a pending request and
        // Core accepts it (CANCELLED surfaces for a pending host op).
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        // runtime.hostSmoke parks a pending host operation waiting for completion.
        let command = try JSONSerialization.data(withJSONObject: [
            "protocolVersion": 1, "requestId": NSNumber(value: 20),
            "method": "runtime.hostSmoke",
            "params": ["capability": "host.smoke.echo", "params": ["hang": true]],
        ])
        try runtime.send(json: command)
        // Wait for the host.request to appear, then cancel the original request.
        var hostRequest: ReaderCoreNativeEvent?
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if let e = runtime.pollEvent(requestId: 20) { hostRequest = e; break }
        }
        XCTAssertEqual(hostRequest?.type, "host.request")
        try runtime.cancel(requestId: 20)
        // The cancelled request surfaces an error event with code CANCELLED.
        var cancelled: ReaderCoreNativeEvent?
        let deadline2 = Date().addingTimeInterval(5)
        while Date() < deadline2 {
            if let e = runtime.pollEvent(requestId: 20) { cancelled = e; break }
        }
        XCTAssertEqual(cancelled?.type, "error")
        XCTAssertEqual(cancelled?.coreErrorCode, "CANCELLED")
    }
}
