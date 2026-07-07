import XCTest
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

/// Item 8e: iOS WebDAV 同步 proof — Core-driven sync.webdav.plan.
///
/// Per AGENTS.md red line 4: Core does not open sockets. Core produces
/// `HostHttpRequest` descriptors via `sync.webdav.plan`; the Host executes
/// them via its HTTP stack (URLSession).
///
/// This proof verifies the Core ↔ Host integration for WebDAV sync:
/// 1. Host sends `sync.webdav.plan` with base_url + auth + WebDavRequest list
///    → Core returns `Vec<HostHttpRequest>` with correct url (base_url + path),
///    method (PROPFIND/GET/PUT/DELETE/MKCOL), headers (Depth, Authorization).
/// 2. Host executes each `HostHttpRequest` via URLSession (or stub for proof).
/// 3. Host translates responses via `webdav_bridge::host_http_response_to_webdav`
///    (Host-side, not Core).
///
/// Proof tier: device-headless (host sim XCTest with real Core runtime).
/// The Core runtime is a real C ABI binary linked transitively via
/// `ReaderShellValidation`. No real WebDAV server is contacted — the proof
/// verifies Core's plan translation, not HTTP execution.
///
/// Mirrors Core contract in:
/// - `crates/reader-contract/src/remote.rs` (SyncWebDavPlanParams,
///   SyncWebDavPlanData, HostHttpRequest)
/// - `crates/reader-sync/src/webdav_protocol.rs` (WebDavRequest, WebDavMethod)
final class HostWebDavSyncProofTests: XCTestCase {

    // MARK: - Helpers

    private func makeRuntime() throws -> ReaderCoreNativeRuntime {
        let runtime = try ReaderCoreNativeRuntime()
        return runtime
    }

    /// Send a Core command and poll for the result event.
    private func sendAndPollResult(
        runtime: ReaderCoreNativeRuntime,
        method: String,
        params: [String: Any],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> [String: Any] {
        let requestId: UInt64 = UInt64.random(in: 100_000...999_999)
        let command: [String: Any] = [
            "protocolVersion": 1,
            "requestId": NSNumber(value: requestId),
            "method": method,
            "params": params,
        ]
        let json = try JSONSerialization.data(withJSONObject: command)
        try runtime.send(json: json)

        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if let event = runtime.pollEvent(requestId: requestId) {
                if event.type == "error" {
                    throw ReaderCoreNativeError.coreError(
                        code: event.coreErrorCode ?? "INTERNAL",
                        message: event.coreErrorMessage ?? "\(method) failed"
                    )
                }
                XCTAssertEqual(event.type, "result",
                               "expected result for \(method), got \(event.type)",
                               file: file, line: line)
                return event.data ?? [:]
            }
            Thread.sleep(forTimeInterval: 0.005)
        }
        throw ReaderCoreNativeError.requestTimedOut(requestId)
    }

    /// Build a WebDavRequest params dict (mirrors WebDavRequest in
    /// `crates/reader-sync/src/webdav_protocol.rs`).
    private func webDavRequest(
        method: String,
        path: String,
        headers: [[String: String]] = [],
        body: [Int]? = nil,
        depth: Int? = nil
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "method": method,
            "path": path,
            "headers": headers,
        ]
        if let body = body {
            dict["body"] = body
        }
        if let depth = depth {
            dict["depth"] = depth
        }
        return dict
    }

    // MARK: - Proof 1: PROPFIND translates to HostHttpRequest

    /// Send `sync.webdav.plan` with a PROPFIND request. Core must return a
    /// `HostHttpRequest` with method="PROPFIND", url=base_url+path, and
    /// Depth header injected.
    func testSyncWebDavPlanTranslatesPropfindToHostHttpRequest() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "baseUrl": "https://dav.example.com/",
            "requests": [
                webDavRequest(
                    method: "PROPFIND",
                    path: "reader-backups/",
                    depth: 1
                ),
            ],
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "sync.webdav.plan", params: params
        )

        guard let requests = data["requests"] as? [[String: Any]] else {
            XCTFail("sync.webdav.plan result must contain requests"); return
        }
        XCTAssertEqual(requests.count, 1, "must return 1 HostHttpRequest")
        let req = requests[0]
        XCTAssertEqual(req["method"] as? String, "PROPFIND",
                       "method must be PROPFIND")
        XCTAssertEqual(req["url"] as? String, "https://dav.example.com/reader-backups/",
                       "url must be base_url + path")
        // Depth header must be present
        let headers = req["headers"] as? [String: Any] ?? [:]
        XCTAssertNotNil(headers["Depth"] ?? headers["depth"],
                        "Depth header must be injected for PROPFIND")
    }

    // MARK: - Proof 2: PUT translates to HostHttpRequest with body

    /// Send `sync.webdav.plan` with a PUT request containing a body. Core
    /// must return a `HostHttpRequest` with method="PUT" and the body present.
    func testSyncWebDavPlanTranslatesPutToHostHttpRequest() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let backupBytes = Array("{\"backup\":\"test\"}".utf8).map { Int($0) }
        let params: [String: Any] = [
            "baseUrl": "https://dav.example.com/",
            "requests": [
                webDavRequest(
                    method: "PUT",
                    path: "reader-backups/backup-001.json",
                    body: backupBytes
                ),
            ],
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "sync.webdav.plan", params: params
        )

        guard let requests = data["requests"] as? [[String: Any]] else {
            XCTFail("sync.webdav.plan result must contain requests"); return
        }
        XCTAssertEqual(requests.count, 1)
        let req = requests[0]
        XCTAssertEqual(req["method"] as? String, "PUT",
                       "method must be PUT")
        XCTAssertEqual(req["url"] as? String,
                       "https://dav.example.com/reader-backups/backup-001.json",
                       "url must be base_url + path")
        // Body must be present (Core translates Vec<u8> → HttpBody)
        XCTAssertNotNil(req["body"], "PUT request must have body")
    }

    // MARK: - Proof 3: Authorization header injected when auth provided

    /// Send `sync.webdav.plan` with `auth="Basic dXNlcjpwdw=="`. Core must
    /// inject `Authorization: Basic dXNlcjpwdw==` into each HostHttpRequest.
    func testSyncWebDavPlanInjectsAuthHeader() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "baseUrl": "https://dav.example.com/",
            "auth": "Basic dXNlcjpwdw==",
            "requests": [
                webDavRequest(method: "GET", path: "reader-backups/backup-001.json"),
            ],
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "sync.webdav.plan", params: params
        )

        guard let requests = data["requests"] as? [[String: Any]] else {
            XCTFail("sync.webdav.plan result must contain requests"); return
        }
        let req = requests[0]
        let headers = req["headers"] as? [String: Any] ?? [:]
        XCTAssertEqual(headers["Authorization"] as? String, "Basic dXNlcjpwdw==",
                       "Authorization header must be injected from auth param")
    }

    // MARK: - Proof 4: Multiple requests translated in order

    /// Send `sync.webdav.plan` with 3 requests (MKCOL + PUT + PROPFIND). Core
    /// must return 3 HostHttpRequests in the same order, each with the correct
    /// method and url.
    func testSyncWebDavPlanTranslatesMultipleRequestsInOrder() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "baseUrl": "https://dav.example.com/",
            "requests": [
                webDavRequest(method: "MKCOL", path: "reader-backups/"),
                webDavRequest(
                    method: "PUT",
                    path: "reader-backups/backup-001.json",
                    body: Array("{\"v\":1}".utf8).map { Int($0) }
                ),
                webDavRequest(method: "PROPFIND", path: "reader-backups/", depth: 1),
            ],
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "sync.webdav.plan", params: params
        )

        guard let requests = data["requests"] as? [[String: Any]] else {
            XCTFail("sync.webdav.plan result must contain requests"); return
        }
        XCTAssertEqual(requests.count, 3, "must return 3 HostHttpRequests")
        XCTAssertEqual(requests[0]["method"] as? String, "MKCOL")
        XCTAssertEqual(requests[1]["method"] as? String, "PUT")
        XCTAssertEqual(requests[2]["method"] as? String, "PROPFIND")
        XCTAssertEqual(requests[0]["url"] as? String,
                       "https://dav.example.com/reader-backups/")
        XCTAssertEqual(requests[1]["url"] as? String,
                       "https://dav.example.com/reader-backups/backup-001.json")
        XCTAssertEqual(requests[2]["url"] as? String,
                       "https://dav.example.com/reader-backups/")
    }

    // MARK: - Proof 5: DELETE translates to HostHttpRequest

    /// Send `sync.webdav.plan` with a DELETE request. Core must return a
    /// `HostHttpRequest` with method="DELETE" and no body.
    func testSyncWebDavPlanTranslatesDeleteToHostHttpRequest() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "baseUrl": "https://dav.example.com/",
            "requests": [
                webDavRequest(method: "DELETE", path: "reader-backups/old-backup.json"),
            ],
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "sync.webdav.plan", params: params
        )

        guard let requests = data["requests"] as? [[String: Any]] else {
            XCTFail("sync.webdav.plan result must contain requests"); return
        }
        XCTAssertEqual(requests.count, 1)
        let req = requests[0]
        XCTAssertEqual(req["method"] as? String, "DELETE")
        XCTAssertEqual(req["url"] as? String,
                       "https://dav.example.com/reader-backups/old-backup.json")
    }

    // MARK: - Proof 6: sync.backup produces a restore plan

    /// Send `sync.backup` with a simple package + policy. Core must return a
    /// `plan` (BackupRestorePlan). This proves the backup planning path works,
    /// complementing the WebDAV plan translation proofs above.
    func testSyncBackupReturnsRestorePlan() throws {
        let runtime = try makeRuntime()
        defer { runtime.destroy() }

        let params: [String: Any] = [
            "package": [
                "manifest": [
                    "backupID": "backup-001",
                    "createdAt": 1_720_000_000,
                    "entries": [
                        [
                            "relativePath": "bookshelf.json",
                            "sizeBytes": 1_024,
                            "modifiedAt": 1_720_000_000,
                        ],
                    ],
                    "totalBytes": 1_024,
                    "bookCount": 1,
                ],
                "format": "zip",
            ],
            "policy": [
                "mode": "full",
                "overwriteExisting": false,
            ],
        ]

        let data = try sendAndPollResult(
            runtime: runtime, method: "sync.backup", params: params
        )

        XCTAssertNotNil(data["plan"],
                        "sync.backup must return a plan")
    }
}
