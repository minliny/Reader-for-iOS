import XCTest
import ReaderUIContract
@testable import ReaderShellValidation

@MainActor
final class HostAppearanceCapabilityTests: XCTestCase {
    func testAppearancePersistenceRoundTripsAndCASConflictsFailClosed() async {
        let adapter = HostAdapter()
        let namespace = "reader-ui-test-\(UUID().uuidString)"
        let key = "appearance.v1"
        let get = HostRequest(type: .persistence_get, payload: [
            "namespace": AnyCodable(namespace), "key": AnyCodable(key),
        ])
        let miss = await adapter.dispatch(get)
        XCTAssertTrue(miss.succeeded)
        XCTAssertEqual(miss.result?["found"]?.value as? Bool, false)

        let value = #"{"schemaVersion":1,"revision":1}"#
        let put = await adapter.dispatch(HostRequest(type: .persistence_put, payload: [
            "namespace": AnyCodable(namespace),
            "key": AnyCodable(key),
            "value": AnyCodable(value),
            "expectedRevision": AnyCodable("0"),
        ]))
        XCTAssertTrue(put.succeeded)
        XCTAssertEqual(put.result?["revision"]?.value as? String, "1")

        let hit = await adapter.dispatch(get)
        XCTAssertEqual(hit.result?["found"]?.value as? Bool, true)
        XCTAssertEqual(hit.result?["value"]?.value as? String, value)
        XCTAssertEqual(hit.result?["revision"]?.value as? String, "1")

        let stale = await adapter.dispatch(HostRequest(type: .persistence_put, payload: [
            "namespace": AnyCodable(namespace),
            "key": AnyCodable(key),
            "value": AnyCodable("stale"),
            "expectedRevision": AnyCodable("0"),
        ]))
        XCTAssertFalse(stale.succeeded)
        XCTAssertNotNil(stale.error)
        let unchanged = await adapter.dispatch(get)
        XCTAssertEqual(unchanged.result?["value"]?.value as? String, value)
        XCTAssertEqual(unchanged.result?["revision"]?.value as? String, "1")
    }

    func testAppearancePersistenceCASAdmitsExactlyOneConcurrentWriter() async {
        let adapter = HostAdapter()
        let namespace = "reader-ui-test-\(UUID().uuidString)"
        let key = "appearance.concurrent"
        let seed = await adapter.dispatch(HostRequest(type: .persistence_put, payload: [
            "namespace": AnyCodable(namespace), "key": AnyCodable(key),
            "value": AnyCodable("initial"), "expectedRevision": AnyCodable("0"),
        ]))
        XCTAssertTrue(seed.succeeded)

        async let first = adapter.dispatch(HostRequest(type: .persistence_put, payload: [
            "namespace": AnyCodable(namespace), "key": AnyCodable(key),
            "value": AnyCodable("first"), "expectedRevision": AnyCodable("1"),
        ]))
        async let second = adapter.dispatch(HostRequest(type: .persistence_put, payload: [
            "namespace": AnyCodable(namespace), "key": AnyCodable(key),
            "value": AnyCodable("second"), "expectedRevision": AnyCodable("1"),
        ]))
        let outcomes = await [first, second]
        XCTAssertEqual(outcomes.filter(\.succeeded).count, 1)

        let loaded = await adapter.dispatch(HostRequest(type: .persistence_get, payload: [
            "namespace": AnyCodable(namespace), "key": AnyCodable(key),
        ]))
        XCTAssertEqual(loaded.result?["revision"]?.value as? String, "2")
    }

    func testFontUnregisterMissingFileIsLogicalAndRequiresRestart() async {
        let adapter = HostAdapter()
        let result = await adapter.dispatch(HostRequest(type: .font_unregisterFile, payload: [
            "path": AnyCodable("/missing/reader-font.ttf"),
            "familyName": AnyCodable("Reader Font"),
        ]))
        XCTAssertTrue(result.succeeded)
        XCTAssertEqual(result.result?["logicalUnregistered"]?.value as? Bool, true)
        XCTAssertEqual(result.result?["physicallyUnregistered"]?.value as? Bool, false)
        XCTAssertEqual(result.result?["restartRequired"]?.value as? Bool, true)
    }

    func testFontRegisterReturnsCoreTextIdentityAndUnregisterReportsPhysicalBoundary() async throws {
        #if canImport(CoreText)
        let candidates = [
            "/System/Library/Fonts/Symbol.ttf",
            "/System/Library/Fonts/Menlo.ttc",
        ]
        guard let source = candidates.first(where: FileManager.default.fileExists(atPath:)) else {
            throw XCTSkip("no stable system font fixture is available")
        }
        let temp = FileManager.default.temporaryDirectory
            .appendingPathComponent("reader-w4-\(UUID().uuidString)")
            .appendingPathExtension((source as NSString).pathExtension)
        try FileManager.default.copyItem(atPath: source, toPath: temp.path)
        defer { try? FileManager.default.removeItem(at: temp) }

        let adapter = HostAdapter()
        let registered = await adapter.dispatch(HostRequest(type: .font_registerFile, payload: [
            "path": AnyCodable(temp.path),
            "familyName": AnyCodable("Untrusted UI Label"),
        ]))
        XCTAssertTrue(registered.succeeded, "\(String(describing: registered.error))")
        let familyName = try XCTUnwrap(registered.result?["familyName"]?.value as? String)
        let registeredPath = try XCTUnwrap(registered.result?["path"]?.value as? String)
        let fontNames = try XCTUnwrap(registered.result?["fontNames"]?.value as? [AnyCodable])
        XCTAssertNotEqual(familyName, "Untrusted UI Label")
        XCTAssertFalse(fontNames.isEmpty)

        let unregistered = await adapter.dispatch(HostRequest(type: .font_unregisterFile, payload: [
            "path": AnyCodable(registeredPath), "familyName": AnyCodable(familyName),
        ]))
        XCTAssertTrue(unregistered.succeeded)
        XCTAssertEqual(unregistered.result?["logicalUnregistered"]?.value as? Bool, true)
        let physical = unregistered.result?["physicallyUnregistered"]?.value as? Bool ?? false
        let restart = unregistered.result?["restartRequired"]?.value as? Bool ?? false
        XCTAssertTrue(physical || restart)
        #else
        throw XCTSkip("CoreText is unavailable")
        #endif
    }
}
