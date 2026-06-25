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
// Round 1 cases (ABI connectivity):  #1-7 [core], #1-4 [app-side]
// Round 2 cases (Host Bus + remote-reading skeleton): #8-18 [core]
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

        // ---- [core] remote-reading protocol skeleton ----
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

        // ---- [core] Host Bus complete cycle (host.request → host.complete → result) ----
        do {
            let cmd = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 1, "requestId": NSNumber(value: 30),
                "method": "runtime.hostSmoke",
                "params": ["capability": "host.smoke.echo", "params": ["ping": "pong"]],
            ])
            try runtime.send(json: cmd)
            let hostReq = try pollUntil(runtime: runtime, requestId: 30)
            check("[core]", "host.request carries operationId",
                  hostReq.operationId != nil,
                  "operationId=\(hostReq.operationId?.description ?? "nil")")
            guard let opId = hostReq.operationId else {
                throw SmokeFailure("missing operationId")
            }
            // Reply with host.complete
            let complete = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 1, "requestId": NSNumber(value: 31),
                "method": "host.complete",
                "params": ["operationId": NSNumber(value: opId), "result": ["echoed": true]],
            ])
            try runtime.send(json: complete)
            let result = try pollUntil(runtime: runtime, requestId: 30)
            check("[core]", "host.complete resolves original request",
                  result.type == "result" && (result.data?["echoed"] as? Bool) == true,
                  "type=\(result.type)")
        } catch {
            check("[core]", "host.complete resolves original request", false, "\(error)")
        }

        // ---- [core] Host Bus error cycle (host.request → host.error → error) ----
        do {
            let cmd = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 1, "requestId": NSNumber(value: 40),
                "method": "runtime.hostSmoke",
                "params": ["capability": "host.smoke.echo", "params": ["fail": true]],
            ])
            try runtime.send(json: cmd)
            let hostReq = try pollUntil(runtime: runtime, requestId: 40)
            guard let opId = hostReq.operationId else {
                throw SmokeFailure("missing operationId")
            }
            // Reply with host.error (CoreError requires code + message + retryable)
            let hostErr = try JSONSerialization.data(withJSONObject: [
                "protocolVersion": 1, "requestId": NSNumber(value: 41),
                "method": "host.error",
                "params": [
                    "operationId": NSNumber(value: opId),
                    "error": ["code": "INTERNAL", "message": "host blocked this", "retryable": false],
                ],
            ])
            try runtime.send(json: hostErr)
            let errEvent = try pollUntil(runtime: runtime, requestId: 40)
            check("[core]", "host.error propagates to original request",
                  errEvent.type == "error" && errEvent.coreErrorCode == "INTERNAL",
                  "type=\(errEvent.type) code=\(errEvent.coreErrorCode ?? "nil")")
        } catch {
            check("[core]", "host.error propagates to original request", false, "\(error)")
        }

        // ---- [core] runtime.status ----
        do {
            let status = try runtime.request(method: "runtime.status", requestId: 50, timeout: 5)
            check("[core]", "runtime.status returns result",
                  status.type == "result",
                  "type=\(status.type)")
            check("[core]", "runtime.status has activeRequests",
                  status.data?["activeRequestCount"] is NSNumber,
                  "data keys: \(status.data?.keys.joined(separator: ",") ?? "nil")")
        } catch {
            check("[core]", "runtime.status returns result", false, "\(error)")
        }

        // ---- [core] book.search inline response (remote-reading skeleton) ----
        do {
            let search = try runtime.request(method: "book.search", requestId: 60, params: [
                "sourceId": "smoke-source",
                "searchResponse": "{\"books\":[{\"bookId\":\"1\",\"title\":\"Smoke Test\",\"author\":\"Tester\"}]}",
                "source": [
                    "sourceId": "smoke-source",
                    "name": "Smoke Source",
                    "baseUrl": "https://smoke.example.test",
                    "rules": [
                        "search": [["kind": "jsonPath", "path": "$.books[*]"]],
                    ],
                ] as [String: Any],
            ], timeout: 5)
            check("[core]", "book.search inline returns result",
                  search.type == "result",
                  "type=\(search.type)")
            // Should have parsed at least one book (key is "books", not "results")
            let bookCount = (search.data?["books"] as? [Any])?.count ?? 0
            check("[core]", "book.search inline parses results",
                  bookCount > 0,
                  "bookCount=\(bookCount)")
        } catch {
            check("[core]", "book.search inline returns result", false, "\(error)")
        }

        // ---- [core] book.toc inline response ----
        do {
            let toc = try runtime.request(method: "book.toc", requestId: 70, params: [
                "sourceId": "smoke-source",
                "bookId": "1",
                "tocResponse": "{\"toc\":[{\"title\":\"Chapter 1\",\"url\":\"c1\"},{\"title\":\"Chapter 2\",\"url\":\"c2\"}]}",
                "source": [
                    "sourceId": "smoke-source",
                    "name": "Smoke Source",
                    "baseUrl": "https://smoke.example.test",
                    "rules": [
                        "toc": [["kind": "jsonPath", "path": "$.toc"]],
                    ],
                ] as [String: Any],
            ], timeout: 5)
            check("[core]", "book.toc inline returns result",
                  toc.type == "result",
                  "type=\(toc.type)")
            let entryCount = (toc.data?["toc"] as? [Any])?.count ?? 0
            check("[core]", "book.toc inline parses entries",
                  entryCount > 0,
                  "entryCount=\(entryCount)")
        } catch {
            check("[core]", "book.toc inline returns result", false, "\(error)")
        }

        // ---- [core] chapter.content inline response ----
        do {
            let content = try runtime.request(method: "chapter.content", requestId: 80, params: [
                "sourceId": "smoke-source",
                "bookId": "1",
                "chapterTitle": "Chapter 1",
                "chapterResponse": "<html><body><p>Hello</p><p>World</p></body></html>",
                "source": [
                    "sourceId": "smoke-source",
                    "name": "Smoke Source",
                    "baseUrl": "https://smoke.example.test",
                    "rules": [
                        "chapter": [["kind": "cssText", "selector": "p"]],
                    ],
                ] as [String: Any],
            ], timeout: 5)
            check("[core]", "chapter.content inline returns result",
                  content.type == "result",
                  "type=\(content.type)")
            let bodyLen = (content.data?["content"] as? String)?.count ?? 0
            check("[core]", "chapter.content inline extracts body",
                  bodyLen > 0,
                  "bodyLen=\(bodyLen)")
        } catch {
            check("[core]", "chapter.content inline returns result", false, "\(error)")
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
