import Foundation
import XCTest
import ReaderUIContract
@testable import ReaderShellValidation

final class HostCanonicalContractParityTests: XCTestCase {
    private struct ResultFixture: Decodable {
        let type: HostRequestType
        let result: [String: AnyCodable]
    }

    private struct FixtureHandler: HostCapabilityHandler {
        let results: [HostRequestType: [String: AnyCodable]]
        let supportedTypes: Set<HostRequestType>
        let tier: HostCapabilityTier = .crossPlatform

        init(results: [HostRequestType: [String: AnyCodable]]) {
            self.results = results
            self.supportedTypes = Set(results.keys)
        }

        func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
            guard let result = results[request.type] else {
                return .failure(.notConfigured(request.type))
            }
            // Deliberately add a historical field. Registry projection must
            // remove it before the value crosses the HostResult boundary.
            var noisy = result
            noisy["legacyExtra"] = AnyCodable("must-not-escape")
            return .success(noisy)
        }
    }

    func testCanonicalFixtureTypeSetsExactlyMatchGenerated58Cases() throws {
        let requests = try loadRequestFixtures()
        let results = try loadResultFixtures()
        let generated = Set(HostRequestType.allCases.map(\.rawValue))

        XCTAssertEqual(HostRequestType.allCases.count, 58)
        XCTAssertEqual(requests.count, 58)
        XCTAssertEqual(results.count, 58)
        XCTAssertEqual(Set(requests.map { $0.type.rawValue }), generated)
        XCTAssertEqual(Set(results.map { $0.type.rawValue }), generated)
        XCTAssertEqual(HostCanonicalContract.typeNames, generated)
    }

    func testAll58CanonicalRequestFixturesAreAcceptedAndResultsAreStrictlyProjected() async throws {
        let requests = try loadRequestFixtures()
        let resultFixtures = try loadResultFixtures()
        let results = Dictionary(uniqueKeysWithValues: resultFixtures.map { ($0.type, $0.result) })
        let registry = HostCapabilityRegistry()
        registry.register(FixtureHandler(results: results))

        for request in requests {
            XCTAssertNil(
                HostCanonicalContract.validateRequest(request),
                "canonical fixture rejected: \(request.type.rawValue)"
            )
            let outcome = await registry.dispatch(request)
            XCTAssertTrue(outcome.succeeded, "\(request.type.rawValue): \(String(describing: outcome.error))")
            XCTAssertNil(outcome.result?["legacyExtra"], "legacy field escaped for \(request.type.rawValue)")
            XCTAssertEqual(outcome.result, results[request.type], "projection drift for \(request.type.rawValue)")
        }
    }

    func testNonCanonicalRequestFieldAndSchemaInvalidSuccessFailClosed() async throws {
        var request = try XCTUnwrap(loadRequestFixtures().first { $0.type == .http_execute })
        request.payload["timeout"] = AnyCodable(12)
        XCTAssertNotNil(HostCanonicalContract.validateRequest(request))

        struct BrokenHandler: HostCapabilityHandler {
            let supportedTypes: Set<HostRequestType> = [.http_execute]
            let tier: HostCapabilityTier = .crossPlatform
            func handle(_ request: HostRequest) async throws -> HostCapabilityOutcome {
                .success(["status": AnyCodable(200)]) // missing canonical body
            }
        }
        let registry = HostCapabilityRegistry()
        registry.register(BrokenHandler())
        let canonical = try XCTUnwrap(loadRequestFixtures().first { $0.type == .http_execute })
        let outcome = await registry.dispatch(canonical)
        XCTAssertFalse(outcome.succeeded)
        guard case .underlying(let message) = outcome.error else {
            return XCTFail("expected strict HostResult failure, got \(String(describing: outcome.error))")
        }
        XCTAssertTrue(message.contains("missing fields"))
    }

    private func loadRequestFixtures() throws -> [HostRequest] {
        try JSONDecoder().decode(
            [HostRequest].self,
            from: Data(contentsOf: canonicalFixtureURL("host-request.fixtures.json"))
        )
    }

    private func loadResultFixtures() throws -> [ResultFixture] {
        try JSONDecoder().decode(
            [ResultFixture].self,
            from: Data(contentsOf: canonicalFixtureURL("host-result.fixtures.json"))
        )
    }

    private func canonicalFixtureURL(_ name: String) -> URL {
        var cursor = URL(fileURLWithPath: #filePath)
        while cursor.lastPathComponent != "Reader-for-iOS", cursor.pathComponents.count > 1 {
            cursor.deleteLastPathComponent()
        }
        return cursor.deletingLastPathComponent()
            .appendingPathComponent("Reader-UI/contracts/fixtures")
            .appendingPathComponent(name)
    }
}
