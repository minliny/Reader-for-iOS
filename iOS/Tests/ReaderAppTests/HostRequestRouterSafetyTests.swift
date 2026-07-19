import Foundation
import XCTest
import ReaderCoreProtocols
import ReaderCoreNativeAdapter
@testable import ReaderShellValidation

final class HostRequestRouterSafetyTests: XCTestCase {
    private func makeHostRequestEvent(
        operationId: UInt64,
        capability: String,
        params: [String: Any]
    ) throws -> ReaderCoreNativeEvent {
        let json: [String: Any] = [
            "type": "host.request",
            "requestId": NSNumber(value: operationId),
            "operationId": NSNumber(value: operationId),
            "capability": capability,
            "params": params,
        ]
        return try ReaderCoreNativeEvent(
            data: JSONSerialization.data(withJSONObject: json)
        )
    }

    func testImplementedButUnadvertisedCapabilityIsRejectedByDefault() async throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let router = HostRequestRouter(
            httpClient: HostRequestRouterSafetyNeverHTTPClient(),
            runtime: runtime
        )
        let event = try makeHostRequestEvent(
            operationId: 41,
            capability: "credential.get",
            params: ["service": "reader.test", "account": "private"]
        )

        do {
            try await router.handleHostRequest(event)
            XCTFail("an implemented private lane must not exceed the advertised manifest")
        } catch HostRequestRouterError.unexpectedCapability(let capability) {
            XCTAssertEqual(capability, "credential.get")
        }
    }

    private struct SandboxFixture {
        let container: URL
        let outside: URL
        let roots: HostRequestRouter.SandboxRoots
    }

    private func makeSandboxFixture() throws -> SandboxFixture {
        let fm = FileManager.default
        let base = fm.temporaryDirectory
            .appendingPathComponent("reader-host-path-safety-\(UUID().uuidString)", isDirectory: true)
        let container = base.appendingPathComponent("container", isDirectory: true)
        let outside = base.appendingPathComponent("outside", isDirectory: true)
        let roots = HostRequestRouter.SandboxRoots(
            documents: container.appendingPathComponent("Documents", isDirectory: true),
            caches: container.appendingPathComponent("Caches", isDirectory: true),
            applicationSupport: container.appendingPathComponent("Application Support", isDirectory: true),
            temporary: container.appendingPathComponent("tmp", isDirectory: true)
        )
        for directory in [
            roots.documents,
            roots.caches,
            roots.applicationSupport,
            roots.temporary,
            outside,
        ] {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return SandboxFixture(container: base, outside: outside, roots: roots)
    }

    func testSandboxResolverStandardizesEveryFrozenRoot() throws {
        let fixture = try makeSandboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.container) }

        let cases: [(String, URL)] = [
            ("documents:/books/./chapter.txt", fixture.roots.documents),
            ("caches:/covers/./cover.bin", fixture.roots.caches),
            ("cache:/legacy/cover.bin", fixture.roots.caches),
            ("applicationSupport:/state/./reader.json", fixture.roots.applicationSupport),
            ("temp:/imports/./book.epub", fixture.roots.temporary),
        ]
        for (path, root) in cases {
            let resolved = try HostRequestRouter.resolveSandboxURL(
                path: path,
                access: .write,
                roots: fixture.roots
            )
            let canonicalRoot = root.standardizedFileURL.resolvingSymlinksInPath()
            XCTAssertTrue(
                resolved.path.hasPrefix(canonicalRoot.path + "/"),
                "\(path) must stay below \(root.path); got \(resolved.path)"
            )
            XCTAssertFalse(resolved.path.contains("/./"))
        }
    }

    func testSandboxResolverRejectsTraversalAndAbsoluteEscapesForReadAndWrite() throws {
        let fixture = try makeSandboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.container) }

        let rejected = [
            "documents:/../outside.txt",
            "caches:/covers/../../outside.txt",
            "applicationSupport:/../outside.txt",
            "temp:/../outside.txt",
            "/private/tmp/outside.txt",
            "documents://private/tmp/outside.txt",
        ]
        for path in rejected {
            XCTAssertThrowsError(
                try HostRequestRouter.resolveSandboxURL(
                    path: path,
                    access: .read,
                    roots: fixture.roots
                ),
                "read must reject \(path)"
            )
            XCTAssertThrowsError(
                try HostRequestRouter.resolveSandboxURL(
                    path: path,
                    access: .write,
                    roots: fixture.roots
                ),
                "write must reject \(path)"
            )
        }
    }

    func testSandboxResolverRejectsExistingAndBrokenSymlinkEscapes() throws {
        let fixture = try makeSandboxFixture()
        defer { try? FileManager.default.removeItem(at: fixture.container) }
        let fm = FileManager.default

        let secret = fixture.outside.appendingPathComponent("secret.txt")
        try Data("outside".utf8).write(to: secret)
        let existingEscape = fixture.roots.caches.appendingPathComponent("existing-escape")
        try fm.createSymbolicLink(at: existingEscape, withDestinationURL: fixture.outside)

        let missingOutside = fixture.outside.appendingPathComponent("missing", isDirectory: true)
        let brokenEscape = fixture.roots.caches.appendingPathComponent("broken-escape")
        try fm.createSymbolicLink(at: brokenEscape, withDestinationURL: missingOutside)

        for (path, access) in [
            ("caches:/existing-escape/secret.txt", HostRequestRouter.SandboxFileAccess.read),
            ("caches:/existing-escape/new.txt", HostRequestRouter.SandboxFileAccess.write),
            ("caches:/broken-escape/new.txt", HostRequestRouter.SandboxFileAccess.write),
        ] {
            XCTAssertThrowsError(
                try HostRequestRouter.resolveSandboxURL(
                    path: path,
                    access: access,
                    roots: fixture.roots
                ),
                "\(access) must reject symlink escape \(path)"
            )
        }
    }

    func testCacheKeysDoNotCollideAndBase64ResponseUsesExactlyOneField() throws {
        let store = HostCacheStore()
        try store.put(params: ["namespace": "a:b", "key": "c", "value": "first"])
        try store.put(params: ["namespace": "a", "key": "b:c", "value": "second"])

        let first = try store.get(params: ["namespace": "a:b", "key": "c"])
        XCTAssertEqual(first["value"] as? String, "first")
        XCTAssertNil(first["valueBase64"])
        XCTAssertEqual(
            try store.get(params: ["namespace": "a", "key": "b:c"])["value"] as? String,
            "second"
        )

        let encoded = Data("binary".utf8).base64EncodedString()
        try store.put(params: ["namespace": "base64", "key": "payload", "valueBase64": encoded])
        let result = try store.get(params: ["namespace": "base64", "key": "payload"])
        XCTAssertEqual(result["valueBase64"] as? String, encoded)
        XCTAssertNil(result["value"])

        XCTAssertThrowsError(try store.put(params: [
            "namespace": "base64",
            "key": "invalid",
            "value": "text",
            "valueBase64": encoded,
        ]))
        XCTAssertThrowsError(try store.put(params: [
            "namespace": "base64",
            "key": "missing",
        ]))
    }

    func testPersistenceKeysDoNotCollideAndBase64RoundTripsInCorrectField() throws {
        let suite = "HostRequestRouterSafetyTests.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            XCTFail("failed to create isolated UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = HostPersistenceStore(defaults: defaults)

        try store.put(params: ["namespace": "a.b", "key": "c", "value": "first"])
        try store.put(params: ["namespace": "a", "key": "b.c", "value": "second"])
        let first = try store.get(params: ["namespace": "a.b", "key": "c"])
        XCTAssertEqual(first["value"] as? String, "first")
        XCTAssertNil(first["valueBase64"])
        XCTAssertEqual(
            try store.get(params: ["namespace": "a", "key": "b.c"])["value"] as? String,
            "second"
        )

        let encoded = Data([0x00, 0xFF, 0x7F]).base64EncodedString()
        try store.put(params: [
            "namespace": "binary",
            "key": "payload",
            "valueBase64": encoded,
        ])
        let result = try store.get(params: ["namespace": "binary", "key": "payload"])
        XCTAssertEqual(result["valueBase64"] as? String, encoded)
        XCTAssertNil(result["value"])
        XCTAssertEqual(result["found"] as? Bool, true)
        XCTAssertNotNil(result["revision"] as? String)

        XCTAssertThrowsError(try store.put(params: [
            "namespace": "binary",
            "key": "invalid",
            "value": "text",
            "valueBase64": encoded,
        ]))
        XCTAssertThrowsError(try store.put(params: [
            "namespace": "binary",
            "key": "missing",
        ]))
    }
}

private struct HostRequestRouterSafetyNeverHTTPClient: HTTPClient {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        XCTFail("private capability rejection must happen before transport")
        return HTTPResponse(statusCode: 500, headers: [:], data: Data())
    }
}
