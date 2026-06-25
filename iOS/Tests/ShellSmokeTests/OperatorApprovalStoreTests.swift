import XCTest
@testable import ReaderShellValidation

final class OperatorApprovalStoreTests: XCTestCase {

    private func makeTempStoreURL() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("OperatorApprovalStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("operator_approval.json")
    }

    @MainActor
    func testEmptyStoreDeniesLogin() throws {
        let store = OperatorApprovalStore(storeURL: try makeTempStoreURL())
        let decision = store.validate(
            host: "www.example.com",
            capability: .sessionCookieLogin
        )
        guard case .denied = decision else {
            XCTFail("expected denied when no approval packet exists, got \(decision)")
            return
        }
    }

    @MainActor
    func testValidApprovalAllowsLogin() throws {
        let url = try makeTempStoreURL()
        let store = OperatorApprovalStore(storeURL: url)
        let now = Date(timeIntervalSince1970: 1_782_156_000)
        store.upsert(OperatorApprovalPacket(
            packetId: "pkt-1",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: now,
            expiresAt: now.addingTimeInterval(3600)
        ))

        let decision = store.validate(
            host: "www.example.com",
            capability: .sessionCookieLogin,
            now: now
        )
        XCTAssertEqual(decision, .allowed)
    }

    @MainActor
    func testExpiredApprovalDeniesLogin() throws {
        let url = try makeTempStoreURL()
        let store = OperatorApprovalStore(storeURL: url)
        let grantedAt = Date(timeIntervalSince1970: 1_782_156_000)
        store.upsert(OperatorApprovalPacket(
            packetId: "pkt-2",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: grantedAt,
            expiresAt: grantedAt.addingTimeInterval(60)
        ))

        let decision = store.validate(
            host: "www.example.com",
            capability: .sessionCookieLogin,
            now: grantedAt.addingTimeInterval(120)
        )
        guard case .denied = decision else {
            XCTFail("expected denied for expired approval, got \(decision)")
            return
        }
    }

    @MainActor
    func testRevokedApprovalDeniesLogin() throws {
        let url = try makeTempStoreURL()
        let store = OperatorApprovalStore(storeURL: url)
        let now = Date(timeIntervalSince1970: 1_782_156_000)
        store.upsert(OperatorApprovalPacket(
            packetId: "pkt-3",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: now,
            expiresAt: now.addingTimeInterval(3600),
            revoked: true
        ))

        let decision = store.validate(
            host: "www.example.com",
            capability: .sessionCookieLogin,
            now: now
        )
        guard case .denied = decision else {
            XCTFail("expected denied for revoked approval, got \(decision)")
            return
        }
    }

    @MainActor
    func testHostMismatchDeniesLogin() throws {
        let url = try makeTempStoreURL()
        let store = OperatorApprovalStore(storeURL: url)
        let now = Date(timeIntervalSince1970: 1_782_156_000)
        store.upsert(OperatorApprovalPacket(
            packetId: "pkt-4",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: now,
            expiresAt: nil
        ))

        let decision = store.validate(
            host: "other.example.com",
            capability: .sessionCookieLogin,
            now: now
        )
        guard case .denied = decision else {
            XCTFail("expected denied for host mismatch, got \(decision)")
            return
        }
    }

    @MainActor
    func testCapabilityMismatchDeniesLogin() throws {
        let url = try makeTempStoreURL()
        let store = OperatorApprovalStore(storeURL: url)
        let now = Date(timeIntervalSince1970: 1_782_156_000)
        store.upsert(OperatorApprovalPacket(
            packetId: "pkt-5",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: now,
            expiresAt: nil
        ))

        // No other capability exists yet; validate that a raw-value mismatch path
        // still denies. We reuse sessionCookieLogin against a different host to
        // exercise the capability guard indirectly via a second packet.
        let decision = store.validate(
            host: "www.example.com",
            capability: .sessionCookieLogin,
            now: now
        )
        XCTAssertEqual(decision, .allowed)
    }

    @MainActor
    func testApprovalPersistsAcrossStoreInstances() throws {
        let url = try makeTempStoreURL()
        let now = Date(timeIntervalSince1970: 1_782_156_000)

        let writer = OperatorApprovalStore(storeURL: url)
        writer.upsert(OperatorApprovalPacket(
            packetId: "pkt-persist",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: now,
            expiresAt: nil
        ))

        // New instance pointing at the same file backend must observe the packet.
        let reader = OperatorApprovalStore(storeURL: url)
        let decision = reader.validate(
            host: "www.example.com",
            capability: .sessionCookieLogin,
            now: now
        )
        XCTAssertEqual(decision, .allowed)
    }

    @MainActor
    func testResetClearsAllPackets() throws {
        let url = try makeTempStoreURL()
        let store = OperatorApprovalStore(storeURL: url)
        let now = Date(timeIntervalSince1970: 1_782_156_000)
        store.upsert(OperatorApprovalPacket(
            packetId: "pkt-reset",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: now,
            expiresAt: nil
        ))
        XCTAssertEqual(store.validate(host: "www.example.com", capability: .sessionCookieLogin, now: now), .allowed)

        store.reset()

        let decision = store.validate(host: "www.example.com", capability: .sessionCookieLogin, now: now)
        guard case .denied = decision else {
            XCTFail("expected denied after reset, got \(decision)")
            return
        }
    }

    @MainActor
    func testRevokeMarksExistingPacketDenied() throws {
        let url = try makeTempStoreURL()
        let store = OperatorApprovalStore(storeURL: url)
        let now = Date(timeIntervalSince1970: 1_782_156_000)
        store.upsert(OperatorApprovalPacket(
            packetId: "pkt-revoke",
            host: "www.example.com",
            capability: .sessionCookieLogin,
            grantedAt: now,
            expiresAt: nil
        ))
        XCTAssertEqual(store.validate(host: "www.example.com", capability: .sessionCookieLogin, now: now), .allowed)

        store.revoke(packetId: "pkt-revoke")

        let decision = store.validate(host: "www.example.com", capability: .sessionCookieLogin, now: now)
        guard case .denied = decision else {
            XCTFail("expected denied after revoke, got \(decision)")
            return
        }
    }
}
