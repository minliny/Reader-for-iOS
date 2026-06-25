// Standalone macOS-hosted ShellSmokeTest main for ReaderCoreNativeAdapter.
//
// This mirrors the XCTest test cases but as a plain @main executable so it
// can be compiled/linked directly with libreader_core.a via run-shell-smoke.sh
// without pulling the ReaderApp dependency tree (iOS-only).
//
// Partitioned evidence:
//   [core]     — exercised through Rust Core via the C ABI / JSON protocol.
//   [app-side] — exercised by the iOS host adapter (ReaderCoreNativeRuntime).
//
// Wrapper/host smoke, NOT iOS App/device proof.

import Foundation

struct SmokeFailure: Error, CustomStringConvertible {
    let description: String
    init(_ description: String) { self.description = description }
}

var corePass = 0
var coreFail = 0
var appPass = 0
var appFail = 0
var failures: [String] = []

func check(_ tag: String, _ name: String, _ ok: Bool, _ detail: String = "") {
    let prefix = tag.hasPrefix("[core]") ? "[core]" : "[app-side]"
    let line = "\(prefix) \(name)"
    if ok {
        print("\(line): PASS")
        if tag.hasPrefix("[core]") { corePass += 1 } else { appPass += 1 }
    } else {
        print("\(line): FAIL\(detail.isEmpty ? "" : " — \(detail)")")
        if tag.hasPrefix("[core]") { coreFail += 1 } else { appFail += 1 }
        failures.append("\(line)\(detail.isEmpty ? "" : " — \(detail)")")
    }
}

func pollUntil(runtime: ReaderCoreNativeRuntime, requestId: UInt64, timeout: TimeInterval = 5) throws -> ReaderCoreNativeEvent {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if let e = runtime.pollEvent(requestId: requestId) { return e }
        Thread.sleep(forTimeInterval: 0.005)
    }
    throw SmokeFailure("timed out polling requestId \(requestId)")
}

@main
struct HostAdapterSmoke {
    static func main() {
        // ---- [core] ABI / protocol surface ----
        check("[core]", "abi version == 1", ReaderCoreNativeRuntime.abiVersion == 1,
              "got \(ReaderCoreNativeRuntime.abiVersion)")

        let runtime: ReaderCoreNativeRuntime
        do { runtime = try ReaderCoreNativeRuntime() }
        catch { print("[core] runtime create: FAIL — \(error)"); exit(1) }
        defer { runtime.destroy() }

        do {
            let info = try runtime.request(method: "core.info", requestId: 1, timeout: 5)
            let ok = info.type == "result"
                && (info.data?["abiVersion"] as? NSNumber)?.uint32Value == 1
                && (info.data?["protocolVersion"] as? NSNumber)?.uint32Value == 1
            check("[core]", "core.info returns abi+protocol version", ok,
                  "type=\(info.type)")
        } catch { check("[core]", "core.info returns abi+protocol version", false, "\(error)") }

        do {
            let ping = try runtime.request(method: "runtime.ping", requestId: 2, timeout: 5)
            check("[core]", "runtime.ping pong=true",
                  ping.type == "result" && (ping.data?["pong"] as? Bool) == true,
                  "type=\(ping.type)")
        } catch { check("[core]", "runtime.ping pong=true", false, "\(error)") }

        do {
            _ = try runtime.request(method: "no.such.method", requestId: 3, timeout: 5)
            check("[core]", "unknown method surfaces UNKNOWN_METHOD", false, "expected throw")
        } catch ReaderCoreNativeError.coreError(let code, _) {
            check("[core]", "unknown method surfaces UNKNOWN_METHOD", code == "UNKNOWN_METHOD",
                  "code=\(code)")
        } catch { check("[core]", "unknown method surfaces UNKNOWN_METHOD", false, "\(error)") }

        do {
            _ = try runtime.send(jsonString: "{not valid json")
            check("[core]", "malformed JSON send fails with non-zero status", false, "expected throw")
        } catch ReaderCoreNativeError.sendFailed(let status) {
            check("[core]", "malformed JSON send fails with non-zero status", status != 0,
                  "status=\(status)")
        } catch { check("[core]", "malformed JSON send fails with non-zero status", false, "\(error)") }

        // ---- [core] cancel surfaces CANCELLED ----
        do {
            let cmd = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 1, "requestId": NSNumber(value: 20),
                "method": "runtime.hostSmoke",
                "params": ["capability": "host.smoke.echo", "params": ["hang": true]],
            ])
            try runtime.send(json: cmd)
            let hostReq = try pollUntil(runtime: runtime, requestId: 20)
            check("[core]", "Core emits host.request", hostReq.type == "host.request",
                  "type=\(hostReq.type)")
            try runtime.cancel(requestId: 20)
            let ev = try pollUntil(runtime: runtime, requestId: 20)
            check("[core]", "cancel surfaces CANCELLED",
                  ev.type == "error" && ev.coreErrorCode == "CANCELLED",
                  "type=\(ev.type) code=\(ev.coreErrorCode ?? "nil")")
        } catch {
            check("[core]", "cancel surfaces CANCELLED", false, "\(error)")
        }

        // ---- [app-side] adapter behavior ----
        check("[app-side]", "runtime create + destroy", true)

        do {
            let badConfig = try JSONSerialization.data(withJSONObject: [
                "dataDirectory": "/tmp/x", "bogusField": true,
            ])
            _ = try ReaderCoreNativeRuntime(configJSON: badConfig)
            check("[app-side]", "invalid config create fails", false, "expected throw")
        } catch ReaderCoreNativeError.createFailed(let status) {
            check("[app-side]", "invalid config create fails", status != 0, "status=\(status)")
        } catch { check("[app-side]", "invalid config create fails", false, "\(error)") }

        do {
            let cmd = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 1, "requestId": NSNumber(value: 10),
                "method": "core.info", "params": [:],
            ])
            try runtime.send(json: cmd)
            let polled = try pollUntil(runtime: runtime, requestId: 10)
            check("[app-side]", "pollEvent drains result event", polled.type == "result")
            // consumed → nil
            Thread.sleep(forTimeInterval: 0.05)
            check("[app-side]", "pollEvent returns nil for consumed event",
                  runtime.pollEvent(requestId: 10) == nil)
        } catch {
            check("[app-side]", "pollEvent drain + consumed", false, "\(error)")
        }

        // ---- summary ----
        print("---")
        print("[core]     pass=\(corePass) fail=\(coreFail)")
        print("[app-side] pass=\(appPass) fail=\(appFail)")
        if !failures.isEmpty {
            print("FAILURES:")
            failures.forEach { print("  - \($0)") }
            exit(1)
        }
        print("reader core native host adapter shell smoke passed")
    }
}
