import CryptoKit
import Foundation
import Security
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderRealSubscriptionTests: XCTestCase {
    /// The successful subscription journey uses this remote input. The repository records a real
    /// 2026-05-01 HTTP 200 response, 2,455,074 bytes, for this 424-source collection:
    /// Reader-Core/legacy/swift/samples/booksources/remote_yiove/
    /// collection_3d9f811b/fetch_log.json and analysis/parser_gap_report.md.
    /// The larger e618 collection historically exceeded Core's 8 MiB admission
    /// limit. Do not trim either package or change URLs after a failed request.
    private let subscriptionURL = "https://shuyuan-api.yiove.com/import/book-source-collection/3d9f811b-0831-4203-9fcb-3e8020f8aa2d"

    /// A second, original Yiove collection is fetched through the production
    /// Host once. Its live UTF-8 Core input must still exceed the 8 MiB admission
    /// boundary; no local response, trimmed package or fabricated error is used.
    /// The rejected preview must leave both original phone source definitions and
    /// the accepted subscription record intact in this isolated library.
    func testRealOversizedProviderCheckRejectsWithoutChangingOriginalSourceOrSubscription() async throws {
        actor CapturedInput {
            private var started = false
            private var data: Data?
            func begin() throws {
                guard !started else { throw ReaderLibraryError.invalidResponse("only one provider fetch is allowed") }
                started = true
            }
            func record(_ data: Data) { self.data = data }
            func snapshot() -> Data? { data }
        }
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else {
                XCTFail(message)
                throw ReaderLibraryError.invalidResponse(message)
            }
        }
        func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        let manager = FileManager.default
        let documents = try XCTUnwrap(manager.urls(for: .documentDirectory, in: .userDomainMask).first)
        let originalURL = documents.appendingPathComponent("Reader-real-sources.json")
        let original = try Data(contentsOf: originalURL)
        let originalDigest = hash(original)
        try require(original.count == 5_606 && originalDigest == "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322",
                    "Provision the unchanged original 5606-byte phone source package; no replacement is allowed")
        let definitions = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [[String: Any]])
        try require(definitions.count == 2, "The original package must contain both real source definitions")
        let expectedSourceIDs = try definitions.map {
            try XCTUnwrap($0["bookSourceUrl"] as? String).trimmingCharacters(in: .whitespacesAndNewlines)
        }.sorted()
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderRealOversizedSubscription-" + UUID().uuidString)
        let sourceURL = root.appendingPathComponent("Sources")
        let operationsURL = sourceURL.appendingPathComponent(".operations")
        let url = "https://shuyuan-api.yiove.com/import/book-source-collection/e61838fa-9a13-4137-b68a-192313eade0c"
        let expectedURL = try XCTUnwrap(URL(string: url))
        let capturedInput = CapturedInput()
        var service: ReaderLibraryService?
        var namespace: String?
        var identityBytes: Data?
        var admittedCookieQuery: [String: Any]?
        var keychainAdmissionFailed = false
        var phase = "create isolated library identity"
        var facts: [String: Any] = ["providerURL": url, "sourcePackageSHA256": originalDigest,
                                   "sourcePackageBytes": original.count, "sourceIds": expectedSourceIDs]
        func cleanupFailure(_ detail: String) -> ReaderLibraryError {
            try? attachFacts(["temporaryRoot": root.path, "namespace": namespace ?? "uncreated", "failure": detail],
                             name: "real-oversized-provider-cleanup-failure")
            XCTFail("Temporary cleanup failed; preserve its attributable identity at \(root.path): \(detail)")
            return .invalidResponse("real oversized-provider temporary cleanup failed")
        }
        func retainOriginalIdentity() throws {
            guard let identityBytes else { throw ReaderLibraryError.invalidResponse("original temporary identity was not captured") }
            try manager.createDirectory(at: operationsURL, withIntermediateDirectories: true)
            let identityURL = operationsURL.appendingPathComponent(ReaderHostLibraryIdentity.fileName)
            if manager.fileExists(atPath: identityURL.path) {
                guard try Data(contentsOf: identityURL) == identityBytes else {
                    throw ReaderLibraryError.invalidResponse("retained temporary identity differs; it was not overwritten")
                }
            } else { try identityBytes.write(to: identityURL, options: .withoutOverwriting) }
        }
        func cleanupTemporaryLibrary() async throws {
            var closedRuntimeCount = 0
            if let active = service {
                do { try await active.close() }
                catch { throw cleanupFailure("Runtime close failed: \(error)") }
                service = nil
                closedRuntimeCount = 1
            }
            guard !keychainAdmissionFailed else {
                throw cleanupFailure("The exact temporary credential pair was not originally absent; no credential or directory was deleted")
            }
            guard manager.fileExists(atPath: root.path) else {
                if namespace != nil {
                    do { try retainOriginalIdentity() }
                    catch { throw cleanupFailure("Temporary root disappeared; original identity restoration failed: \(error)") }
                    throw cleanupFailure("Temporary root disappeared before identity verification; original identity restored and credentials retained")
                }
                return
            }
            let identityURL = operationsURL.appendingPathComponent(ReaderHostLibraryIdentity.fileName)
            do {
                guard let identityBytes, try Data(contentsOf: identityURL) == identityBytes else {
                    throw ReaderLibraryError.invalidResponse("temporary identity is missing or changed")
                }
            } catch { throw cleanupFailure("Temporary library identity could not be verified: \(error)") }
            if let query = admittedCookieQuery {
                let deleted = SecItemDelete(query as CFDictionary)
                var readQuery = query; readQuery[kSecReturnData as String] = true
                var remaining: CFTypeRef?
                let read = SecItemCopyMatching(readQuery as CFDictionary, &remaining)
                guard (deleted == errSecSuccess || deleted == errSecItemNotFound), read == errSecItemNotFound else {
                    throw cleanupFailure("Exact credential cleanup failed: deleteStatus=\(deleted) postreadStatus=\(read)")
                }
            }
            do {
                try manager.removeItem(at: root)
                guard !manager.fileExists(atPath: root.path) else {
                    throw ReaderLibraryError.invalidResponse("temporary root remains after removal")
                }
            } catch {
                let removalError = error
                // A partial recursive removal must retain this run's original
                // identity, never a newly generated namespace or another one.
                do { try retainOriginalIdentity() }
                catch { throw cleanupFailure("Directory removal failed: \(removalError); identity restoration failed: \(error)") }
                throw cleanupFailure("Directory removal failed; original temporary identity retained: \(removalError)")
            }
            try attachFacts(["closedRuntimeCount": closedRuntimeCount, "exactCredentialPairAbsent": admittedCookieQuery != nil,
                             "temporaryRootRemoved": true], name: "real-oversized-provider-cleanup-complete")
        }
        var scenarioFailure: Error?
        do {
            let identity = try ReaderHostLibraryIdentity.loadOrCreate(in: operationsURL)
            namespace = identity
            identityBytes = try Data(contentsOf: operationsURL.appendingPathComponent(ReaderHostLibraryIdentity.fileName))
            let cookieSourceID = "source-package:" + (try XCTUnwrap(expectedURL.host))
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "io.reader.minliny.source-cookies." + hash(Data(identity.utf8)),
                kSecAttrAccount as String: hash(Data(cookieSourceID.utf8))]
            var readQuery = query; readQuery[kSecReturnData as String] = true
            var originalItem: CFTypeRef?
            let initialStatus = SecItemCopyMatching(readQuery as CFDictionary, &originalItem)
            guard initialStatus == errSecItemNotFound else {
                keychainAdmissionFailed = true
                throw ReaderLibraryError.invalidResponse("Fresh temporary credential pair must be absent before networking; status=\(initialStatus)")
            }
            admittedCookieQuery = query
            let active = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: sourceURL)
            service = active
            phase = "import both original phone sources and save subscription"
            let imported = try await active.importSources(original, operationID: UUID().uuidString)
            try require(imported.count == 2 && imported.allSatisfy(\.succeeded), "Both original real sources must be accepted")
            let subscription = ReaderSourceSubscription(id: 941014, name: "原始 Yiove 大包失败保留",
                url: url, type: 0, customOrder: 0, autoUpdate: false, update: 0)
            let saved = try await active.saveRuleSubscription(subscription, operationID: UUID().uuidString)
            try require(saved == subscription, "The exact original subscription must be saved")
            let beforeSources = try await active.onlineSources().sorted { $0.id < $1.id }
            let beforeSubscriptions = try await active.ruleSubscriptions()
            let beforePending = try await active.pendingCoreCommands()
            try require(beforeSources.map(\.id) == expectedSourceIDs && beforeSubscriptions == [saved] && beforePending.isEmpty,
                        "Both original source identities, the accepted subscription and an empty pending journal are required")
            phase = "one actual production Host fetch inside the subscription check"
            do {
                _ = try await active.checkRuleSubscription(saved, fetch: { requested in
                    guard requested == expectedURL else { throw ReaderLibraryError.invalidResponse("provider URL identity") }
                    try await capturedInput.begin()
                    let input = try await active.onlineFetch(requested)
                    await capturedInput.record(input)
                    return input
                })
                try require(false, "An actual oversized provider response must not produce an applicable preview")
            } catch let error as ReaderLibraryError {
                guard case .core(let code, let message, let retryable, let reason) = error,
                      code == "INVALID_PARAMS", message == "subscription package exceeds 8 MiB" else { throw error }
                facts["rejectionCode"] = code; facts["rejectionMessage"] = message
                facts["rejectionRetryable"] = retryable; facts["rejectionReason"] = reason as Any? ?? NSNull()
            }
            let captured = await capturedInput.snapshot()
            let input = try XCTUnwrap(captured, "The original check must fetch its actual provider input")
            try require(input.count > 8 * 1024 * 1024,
                        "The current provider's Core UTF-8 input must exceed 8 MiB; a changed provider requires a new plan")
            facts["coreInputUTF8Bytes"] = input.count
            facts["coreInputUTF8SHA256"] = hash(input)
            facts["input"] = "one actual production Host fetch; decoded UTF-8 Core input, no replacement response or wire-byte identity claim"
            try attachFacts(facts, name: "real-oversized-provider-confirmed-input-and-rejection")
            phase = "verify original sources, subscription, pending journal and phone file remain unchanged"
            let afterSources = try await active.onlineSources().sorted { $0.id < $1.id }
            let afterSubscriptions = try await active.ruleSubscriptions()
            let afterPending = try await active.pendingCoreCommands()
            try require(afterSources == beforeSources && afterSubscriptions == beforeSubscriptions && afterPending.isEmpty,
                        "Rejected preview must preserve both complete source definitions, subscription and pending journal")
            try require(try Data(contentsOf: originalURL) == original, "The original phone source file must remain byte-for-byte unchanged")
            facts["sourceCount"] = afterSources.count; facts["pendingCoreCommands"] = afterPending.count
            facts["result"] = "Core rejected oversized live input; both original sources, subscription and phone source file unchanged"
            try attachFacts(facts, name: "real-oversized-provider-rejection-retains-original-facts")
        } catch {
            scenarioFailure = error
            facts["failedPhase"] = phase; facts["failure"] = String(reflecting: error)
            if let input = await capturedInput.snapshot() {
                facts["observedCoreInputUTF8Bytes"] = input.count
                facts["observedCoreInputUTF8SHA256"] = hash(input)
            }
            try? attachFacts(facts, name: "real-oversized-provider-failure")
        }
        do { try await cleanupTemporaryLibrary() }
        catch {
            if let scenarioFailure {
                try? attachFacts(["scenarioFailure": String(reflecting: scenarioFailure), "cleanupFailure": String(reflecting: error)],
                                 name: "real-oversized-provider-scenario-and-cleanup-failure")
            }
            throw error
        }
        if let scenarioFailure { throw scenarioFailure }
    }

    /// A real user deletion conflicts with re-admission from the live provider,
    /// even if that provider has published no new version. Both full packages
    /// come from the production Host; only this run's temporary library changes.
    func testRealProviderRecheckPreservesLocalDeletionConflictAndSelectiveApplyAfterColdReopen() async throws {
        actor CapturedInputs {
            private var started = 0
            private var inputs: [Data] = []
            func begin() throws {
                guard started < 2 else { throw ReaderLibraryError.invalidResponse("only two provider fetches are allowed") }
                started += 1
            }
            func record(_ input: Data) { inputs.append(input) }
            func snapshot() -> [Data] { inputs }
        }
        func require(_ condition: Bool, _ message: String) throws {
            guard condition else {
                XCTFail(message)
                throw ReaderLibraryError.invalidResponse(message)
            }
        }
        func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        let manager = FileManager.default
        let documents = try XCTUnwrap(manager.urls(for: .documentDirectory, in: .userDomainMask).first)
        let originalURL = documents.appendingPathComponent("Reader-real-sources.json")
        let original = try Data(contentsOf: originalURL)
        let originalDigest = hash(original)
        try require(original.count == 5_606 && originalDigest == "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322",
                    "Provision the unchanged original 5606-byte phone source package; no replacement is allowed")
        let definitions = try XCTUnwrap(JSONSerialization.jsonObject(with: original) as? [[String: Any]])
        try require(definitions.count == 2, "The original package must contain both real source definitions")
        let expectedSourceIDs = try definitions.map {
            try XCTUnwrap($0["bookSourceUrl"] as? String).trimmingCharacters(in: .whitespacesAndNewlines)
        }.sorted()
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderRealSubscriptionDeletion-" + UUID().uuidString)
        let sourceURL = root.appendingPathComponent("Sources")
        let operationsURL = sourceURL.appendingPathComponent(".operations")
        let expectedURL = try XCTUnwrap(URL(string: subscriptionURL))
        let capturedInputs = CapturedInputs()
        var service: ReaderLibraryService?
        var namespace: String?
        var identityBytes: Data?
        var admittedCookieQuery: [String: Any]?
        var keychainAdmissionFailed = false
        var closedRuntimeCount = 0
        var phase = "create isolated library identity"
        var facts: [String: Any] = ["providerURL": subscriptionURL, "sourcePackageSHA256": originalDigest,
            "sourcePackageBytes": original.count, "originalSourceIds": expectedSourceIDs,
            "conflictScenario": "local user deletion versus genuine provider re-admission",
            "remotePublicationClaim": false, "OSBackgroundExecutionClaim": false]
        func cleanupFailure(_ detail: String) -> ReaderLibraryError {
            try? attachFacts(["temporaryRoot": root.path, "namespace": namespace ?? "uncreated", "failure": detail],
                             name: "real-subscription-deletion-cleanup-failure")
            XCTFail("Temporary cleanup failed; preserve its attributable identity at \(root.path): \(detail)")
            return .invalidResponse("real subscription-deletion temporary cleanup failed")
        }
        func retainOriginalIdentity() throws {
            guard let identityBytes else { throw ReaderLibraryError.invalidResponse("original temporary identity was not captured") }
            try manager.createDirectory(at: operationsURL, withIntermediateDirectories: true)
            let identityURL = operationsURL.appendingPathComponent(ReaderHostLibraryIdentity.fileName)
            if manager.fileExists(atPath: identityURL.path) {
                guard try Data(contentsOf: identityURL) == identityBytes else {
                    throw ReaderLibraryError.invalidResponse("retained temporary identity differs; it was not overwritten")
                }
            } else { try identityBytes.write(to: identityURL, options: .withoutOverwriting) }
        }
        func cleanupTemporaryLibrary() async throws {
            if let active = service {
                do { try await active.close() }
                catch { throw cleanupFailure("Runtime close failed: \(error)") }
                service = nil
                closedRuntimeCount += 1
            }
            guard !keychainAdmissionFailed else {
                throw cleanupFailure("The exact temporary credential pair was not originally absent; no credential or directory was deleted")
            }
            guard manager.fileExists(atPath: root.path) else {
                if namespace != nil {
                    do { try retainOriginalIdentity() }
                    catch { throw cleanupFailure("Temporary root disappeared; original identity restoration failed: \(error)") }
                    throw cleanupFailure("Temporary root disappeared before identity verification; original identity restored and credentials retained")
                }
                return
            }
            let identityURL = operationsURL.appendingPathComponent(ReaderHostLibraryIdentity.fileName)
            do {
                guard let identityBytes, try Data(contentsOf: identityURL) == identityBytes else {
                    throw ReaderLibraryError.invalidResponse("temporary identity is missing or changed")
                }
            } catch { throw cleanupFailure("Temporary library identity could not be verified: \(error)") }
            if let query = admittedCookieQuery {
                let deleted = SecItemDelete(query as CFDictionary)
                var readQuery = query; readQuery[kSecReturnData as String] = true
                var remaining: CFTypeRef?
                let read = SecItemCopyMatching(readQuery as CFDictionary, &remaining)
                guard (deleted == errSecSuccess || deleted == errSecItemNotFound), read == errSecItemNotFound else {
                    throw cleanupFailure("Exact credential cleanup failed: deleteStatus=\(deleted) postreadStatus=\(read)")
                }
            }
            do {
                try manager.removeItem(at: root)
                guard !manager.fileExists(atPath: root.path) else {
                    throw ReaderLibraryError.invalidResponse("temporary root remains after removal")
                }
            } catch {
                let removalError = error
                do { try retainOriginalIdentity() }
                catch { throw cleanupFailure("Directory removal failed: \(removalError); identity restoration failed: \(error)") }
                throw cleanupFailure("Directory removal failed; original temporary identity retained: \(removalError)")
            }
            try attachFacts(["closedRuntimeCount": closedRuntimeCount, "exactCredentialPairAbsent": admittedCookieQuery != nil,
                             "temporaryRootRemoved": true], name: "real-subscription-deletion-cleanup-complete")
        }
        var scenarioFailure: Error?
        do {
            let identity = try ReaderHostLibraryIdentity.loadOrCreate(in: operationsURL)
            namespace = identity
            identityBytes = try Data(contentsOf: operationsURL.appendingPathComponent(ReaderHostLibraryIdentity.fileName))
            let cookieSourceID = "source-package:" + (try XCTUnwrap(expectedURL.host))
            let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: "io.reader.minliny.source-cookies." + hash(Data(identity.utf8)),
                kSecAttrAccount as String: hash(Data(cookieSourceID.utf8))]
            var readQuery = query; readQuery[kSecReturnData as String] = true
            var originalItem: CFTypeRef?
            let initialStatus = SecItemCopyMatching(readQuery as CFDictionary, &originalItem)
            guard initialStatus == errSecItemNotFound else {
                keychainAdmissionFailed = true
                throw ReaderLibraryError.invalidResponse("Fresh temporary credential pair must be absent before networking; status=\(initialStatus)")
            }
            admittedCookieQuery = query
            let active = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: sourceURL)
            service = active
            phase = "import both original phone sources and save actual provider subscription"
            let imported = try await active.importSources(original, operationID: UUID().uuidString)
            try require(imported.count == 2 && imported.allSatisfy(\.succeeded), "Both original real sources must be accepted")
            let originalSources = try await active.onlineSources().sorted { $0.id < $1.id }
            try require(originalSources.map(\.id) == expectedSourceIDs, "The isolated library must initially contain only the two original sources")
            let subscription = ReaderSourceSubscription(id: 941015, name: "真实 Yiove 本机删除冲突保留",
                url: subscriptionURL, type: 0, customOrder: 0, autoUpdate: false, update: 0)
            let saved = try await active.saveRuleSubscription(subscription, operationID: UUID().uuidString)
            try require(saved == subscription, "The exact original provider URL must be saved")
            phase = "first genuine provider check and one safe original apply"
            let firstPlan = try await active.checkRuleSubscription(saved, fetch: { requested in
                guard requested == expectedURL else { throw ReaderLibraryError.invalidResponse("provider URL identity") }
                try await capturedInputs.begin()
                let input = try await active.onlineFetch(requested)
                await capturedInputs.record(input)
                return input
            })
            assertOriginalPlan(firstPlan, subscription: saved)
            let firstChange = try XCTUnwrap(firstPlan.changes.filter {
                $0.safeToApply && isHTTPSource($0.sourceId) && !expectedSourceIDs.contains($0.sourceId)
            }.sorted { $0.sourceId < $1.sourceId }.first, "The full live package must offer an actual safe HTTP source outside the original pair")
            try require(firstChange.kind == "added", "The source to be deleted must be newly owned by this temporary library")
            let firstApplied = try await active.applyRuleSubscription(firstPlan, sourceIDs: [firstChange.sourceId], operationID: UUID().uuidString)
            assertOriginalApply(firstApplied, plan: firstPlan, selectedID: firstChange.sourceId)
            try attach(firstApplied, name: "real-subscription-deletion-first-original-ACK")
            let admittedSources = try await active.onlineSources()
            try require(Set(admittedSources.map(\.id)) == Set(expectedSourceIDs + [firstChange.sourceId]), "Only one genuine provider source may be admitted")
            let admitted = try XCTUnwrap(admittedSources.first(where: { $0.id == firstChange.sourceId }))
            try assertDefinitionIdentity(admitted)
            let subscriptionsBeforeDelete = try await active.ruleSubscriptions()
            phase = "delete only the newly admitted temporary source using the public operation"
            try await active.deleteSource(admitted.id, operationID: UUID().uuidString)
            let afterDelete = try await active.onlineSources().sorted { $0.id < $1.id }
            let afterDeleteSubscriptions = try await active.ruleSubscriptions()
            let afterDeletePending = try await active.pendingCoreCommands()
            try require(afterDelete == originalSources && afterDeleteSubscriptions == subscriptionsBeforeDelete && afterDeletePending.isEmpty,
                        "Local deletion must preserve both original definitions, subscription clock and an empty pending journal")
            let currentSubscription = try XCTUnwrap(afterDeleteSubscriptions.first(where: { $0.id == saved.id }))
            phase = "second genuine provider check and local-deletion conflict"
            let secondPlan = try await active.checkRuleSubscription(currentSubscription, fetch: { requested in
                guard requested == expectedURL else { throw ReaderLibraryError.invalidResponse("provider URL identity") }
                try await capturedInputs.begin()
                let input = try await active.onlineFetch(requested)
                await capturedInputs.record(input)
                return input
            })
            assertOriginalPlan(secondPlan, subscription: currentSubscription)
            try attach(secondPlan, name: "real-subscription-deletion-live-conflict-plan")
            let conflict = try XCTUnwrap(secondPlan.changes.first(where: { $0.sourceId == admitted.id }))
            facts["deletedSourceId"] = admitted.id; facts["observedChangeKind"] = conflict.kind
            try require(conflict.kind == "conflict" && !conflict.safeToApply,
                        "The actual provider must still contain the deleted source and Core must protect its deletion as a conflict; changed provider input requires a new plan")
            let afterCheck = try await active.onlineSources().sorted { $0.id < $1.id }
            let afterCheckSubscriptions = try await active.ruleSubscriptions()
            try require(afterCheck == originalSources && afterCheckSubscriptions == afterDeleteSubscriptions,
                        "The genuine provider check must not restore a deleted source or advance the subscription clock")
            let secondChange = try XCTUnwrap(secondPlan.changes.filter {
                $0.safeToApply && $0.sourceId != admitted.id && isHTTPSource($0.sourceId) && !expectedSourceIDs.contains($0.sourceId)
            }.sorted { $0.sourceId < $1.sourceId }.first, "A different actual safe HTTP source is required for selective apply")
            phase = "apply one different safe source while preserving the actual deletion conflict"
            let secondApplied = try await active.applyRuleSubscription(secondPlan, sourceIDs: [secondChange.sourceId], operationID: UUID().uuidString)
            assertOriginalApply(secondApplied, plan: secondPlan, selectedID: secondChange.sourceId)
            try require(secondApplied.skippedSourceIds.contains(admitted.id), "The original ACK must explicitly skip the conflict identity")
            try attach(secondApplied, name: "real-subscription-deletion-selective-original-ACK")
            let beforeCold = try await active.onlineSources().sorted { $0.id < $1.id }
            let beforeColdSubscriptions = try await active.ruleSubscriptions()
            try require(Set(beforeCold.map(\.id)) == Set(expectedSourceIDs + [secondChange.sourceId]) &&
                        beforeCold.filter { expectedSourceIDs.contains($0.id) } == originalSources,
                        "Selective apply must retain both complete original sources and keep the locally deleted source absent")
            let retainedSubscription = try XCTUnwrap(beforeColdSubscriptions.first(where: { $0.id == saved.id }))
            try require(retainedSubscription.url == subscriptionURL && !retainedSubscription.autoUpdate && retainedSubscription.update == secondApplied.updatedAt,
                        "Only the exact selective apply ACK may advance this temporary subscription clock")
            try await active.close(); service = nil; closedRuntimeCount += 1
            phase = "cold reopen the same temporary library without another provider request"
            let reopened = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: sourceURL)
            service = reopened
            let coldSources = try await reopened.onlineSources().sorted { $0.id < $1.id }
            let coldSubscriptions = try await reopened.ruleSubscriptions()
            let coldPending = try await reopened.pendingCoreCommands()
            try require(coldSources == beforeCold && coldSubscriptions == beforeColdSubscriptions && coldPending.isEmpty,
                        "Cold reopen must retain exact source definitions, deletion, acknowledged subscription and no pending writes")
            try require(try Data(contentsOf: originalURL) == original, "The original phone source file must remain byte-for-byte unchanged")
            let inputs = await capturedInputs.snapshot()
            try require(inputs.count == 2, "Exactly two genuine full provider checks must supply both Core inputs")
            try require(hash(inputs[0]) == firstPlan.remoteDigest && hash(inputs[1]) == secondPlan.remoteDigest,
                        "Each plan must bind its own actual decoded UTF-8 provider input")
            facts["providerFetchInvocations"] = inputs.count
            facts["firstCoreInputUTF8Bytes"] = inputs[0].count; facts["firstCoreInputUTF8SHA256"] = hash(inputs[0])
            facts["secondCoreInputUTF8Bytes"] = inputs[1].count; facts["secondCoreInputUTF8SHA256"] = hash(inputs[1])
            facts["sameRemoteInput"] = firstPlan.remoteDigest == secondPlan.remoteDigest
            facts["selectivelyAppliedSourceId"] = secondChange.sourceId
            facts["coldSourceIds"] = coldSources.map(\.id); facts["pendingCoreCommands"] = coldPending.count
            facts["input"] = "two production Host fetches of complete unchanged responses; decoded UTF-8 Core input, no wire-byte identity claim"
            facts["result"] = "live local-deletion conflict skipped; original sources, file and acknowledged selective apply retained after cold reopen"
            try attachFacts(facts, name: "real-subscription-deletion-live-conflict-and-cold-retention")
        } catch {
            scenarioFailure = error
            facts["failedPhase"] = phase; facts["failure"] = String(reflecting: error)
            let inputs = await capturedInputs.snapshot()
            facts["completedProviderInputs"] = inputs.map { ["coreInputUTF8Bytes": $0.count, "coreInputUTF8SHA256": hash($0)] as [String: Any] }
            try? attachFacts(facts, name: "real-subscription-deletion-scenario-failure")
        }
        do { try await cleanupTemporaryLibrary() }
        catch {
            if let scenarioFailure {
                try? attachFacts(["scenarioFailure": String(reflecting: scenarioFailure), "cleanupFailure": String(reflecting: error)],
                                 name: "real-subscription-deletion-scenario-and-cleanup-failure")
            }
            throw error
        }
        if let scenarioFailure { throw scenarioFailure }
    }

    func testRealSubscriptionFetchPreviewSafeApplyAndColdReplayPreserveLocalChanges() async throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderRealSubscription-" + UUID().uuidString, isDirectory: true)
        let core = root.appendingPathComponent("Core", isDirectory: true)
        let sources = root.appendingPathComponent("Sources", isDirectory: true)
        defer { try? manager.removeItem(at: root) }

        var active: ReaderLibraryService?
        var phase = "create isolated library"
        var facts: [String: Any] = [
            "subscriptionURL": subscriptionURL,
            "remoteInput": "actual Host fetch; complete unmodified provider JSON",
            "remoteReleaseClaim": false
        ]
        do {
            // This initializer creates the actual native HTTP Host and real
            // pinned Core. No test client, transport, response, or remoteJson.
            let service = try ReaderLibraryService(storageURL: core, sourceURL: sources)
            active = service
            let initialSources = try await service.onlineSources()
            XCTAssertTrue(initialSources.isEmpty, "Only this temporary library may be changed")
            let subscription = ReaderSourceSubscription(id: 941005, name: "真实 Yiove 书源集合", url: subscriptionURL,
                type: 0, customOrder: 0, autoUpdate: false, update: 0)
            let saved = try await service.saveRuleSubscription(subscription, operationID: UUID().uuidString)
            XCTAssertEqual(saved, subscription)

            phase = "first real Host fetch and Core preview"
            let firstPlan = try await service.checkRuleSubscription(saved)
            assertOriginalPlan(firstPlan, subscription: saved)
            try attach(firstPlan, name: "Actual-subscription-first-plan")
            facts["firstRemoteDigest"] = firstPlan.remoteDigest
            let afterPreview = try await service.onlineSources()
            let subscriptionsAfterPreview = try await service.ruleSubscriptions()
            XCTAssertTrue(afterPreview.isEmpty, "Preview must not import the provider's sources")
            XCTAssertEqual(subscriptionsAfterPreview, [saved], "Preview must not advance the subscription timestamp")
            let firstChange = try XCTUnwrap(firstPlan.changes.filter { $0.safeToApply && isHTTPSource($0.sourceId) }
                .sorted { $0.sourceId < $1.sourceId }.first, "The real provider must supply an admissible safe source; no fixture or fallback")
            XCTAssertEqual(firstChange.kind, "added")
            let firstOperation = UUID().uuidString
            facts["firstSourceId"] = firstChange.sourceId
            facts["firstOperationId"] = firstOperation

            phase = "apply one original safe source"
            let firstApplied = try await service.applyRuleSubscription(firstPlan, sourceIDs: [firstChange.sourceId], operationID: firstOperation)
            assertOriginalApply(firstApplied, plan: firstPlan, selectedID: firstChange.sourceId)
            try attach(firstApplied, name: "Actual-subscription-first-original-ACK")
            let firstSources = try await service.onlineSources()
            XCTAssertEqual(firstSources.map(\.id), [firstChange.sourceId], "Only the selected real source is admitted")
            let firstSource = try XCTUnwrap(firstSources.first)
            XCTAssertEqual(firstSource.name, firstChange.name)
            XCTAssertFalse(firstSource.version.isEmpty)
            try assertDefinitionIdentity(firstSource)

            phase = "local user edit of the admitted real source"
            // The public source-management operation changes only the local
            // library. The remote package is never edited or reconstructed.
            try await service.updateSource(firstSource.id, enabled: !firstSource.enabled, operationID: UUID().uuidString)
            let editedSources = try await service.onlineSources()
            let edited = try XCTUnwrap(editedSources.first(where: { $0.id == firstSource.id }))
            XCTAssertEqual(edited.enabled, !firstSource.enabled)
            XCTAssertNotEqual(edited.version, firstSource.version)

            phase = "second real Host fetch and protected-local diff"
            let currentSubscriptions = try await service.ruleSubscriptions()
            let currentSubscription = try XCTUnwrap(currentSubscriptions.first(where: { $0.id == saved.id }))
            let secondPlan = try await service.checkRuleSubscription(currentSubscription)
            assertOriginalPlan(secondPlan, subscription: saved)
            try attach(secondPlan, name: "Actual-subscription-second-plan")
            facts["secondRemoteDigest"] = secondPlan.remoteDigest
            facts["sameRemoteBytes"] = firstPlan.remoteDigest == secondPlan.remoteDigest
            let localChange = try XCTUnwrap(secondPlan.changes.first(where: { $0.sourceId == edited.id }))
            facts["localChangeKind"] = localChange.kind
            XCTAssertFalse(localChange.safeToApply, "A local edit must not become an automatic replacement")
            if firstPlan.remoteDigest == secondPlan.remoteDigest {
                XCTAssertEqual(localChange.kind, "localOnly", "Unchanged remote bytes are not a newly published provider update")
            } else {
                XCTAssertTrue(["localOnly", "conflict", "removedRemote", "unchanged"].contains(localChange.kind),
                    "A real provider change must still preserve the locally edited source")
            }
            let secondChange = try XCTUnwrap(secondPlan.changes.filter {
                $0.safeToApply && $0.sourceId != edited.id && isHTTPSource($0.sourceId)
            }.sorted { $0.sourceId < $1.sourceId }.first, "A second real safe source is required to exercise selective apply")
            let secondOperation = UUID().uuidString
            facts["secondSourceId"] = secondChange.sourceId
            facts["secondOperationId"] = secondOperation

            phase = "selective safe apply preserves the local edit"
            let secondApplied = try await service.applyRuleSubscription(secondPlan, sourceIDs: [secondChange.sourceId], operationID: secondOperation)
            assertOriginalApply(secondApplied, plan: secondPlan, selectedID: secondChange.sourceId)
            XCTAssertTrue(secondApplied.skippedSourceIds.contains(edited.id))
            try attach(secondApplied, name: "Actual-subscription-second-original-ACK")
            let beforeCold = try await service.onlineSources().sorted { $0.id < $1.id }
            XCTAssertEqual(Set(beforeCold.map(\.id)), Set([firstChange.sourceId, secondChange.sourceId]))
            XCTAssertEqual(beforeCold.first(where: { $0.id == edited.id }), edited)
            let secondSource = try XCTUnwrap(beforeCold.first(where: { $0.id == secondChange.sourceId }))
            XCTAssertEqual(secondSource.name, secondChange.name)
            try assertDefinitionIdentity(secondSource)
            let subscriptionsBeforeCold = try await service.ruleSubscriptions()
            let subscriptionBeforeCold = try XCTUnwrap(subscriptionsBeforeCold.first(where: { $0.id == saved.id }))
            XCTAssertEqual(subscriptionBeforeCold.url, subscriptionURL)
            XCTAssertEqual(subscriptionBeforeCold.update, secondApplied.updatedAt)
            try await service.close()
            active = nil

            phase = "cold reopen and replay the two original operation IDs"
            let reopened = try ReaderLibraryService(storageURL: core, sourceURL: sources)
            active = reopened
            let coldSources = try await reopened.onlineSources().sorted { $0.id < $1.id }
            let coldSubscriptions = try await reopened.ruleSubscriptions()
            XCTAssertEqual(coldSources, beforeCold)
            XCTAssertEqual(coldSubscriptions, subscriptionsBeforeCold)
            // These calls reuse the frozen plans, selection and operation IDs.
            // They must return the old ACK, even after a later local mutation;
            // they do not fetch, create a new plan, or infer ACKs from source.list.
            let firstReplay = try await reopened.applyRuleSubscription(firstPlan, sourceIDs: [firstChange.sourceId], operationID: firstOperation)
            let secondReplay = try await reopened.applyRuleSubscription(secondPlan, sourceIDs: [secondChange.sourceId], operationID: secondOperation)
            XCTAssertEqual(firstReplay, firstApplied)
            XCTAssertEqual(secondReplay, secondApplied)
            let afterReplay = try await reopened.onlineSources().sorted { $0.id < $1.id }
            let subscriptionsAfterReplay = try await reopened.ruleSubscriptions()
            let pending = try await reopened.pendingCoreCommands()
            XCTAssertEqual(afterReplay, beforeCold, "Old apply replay must not replace the local edit or duplicate a source")
            XCTAssertEqual(subscriptionsAfterReplay, subscriptionsBeforeCold, "Replay must retain the original update timestamp")
            XCTAssertTrue(pending.isEmpty)
            facts["coldSourceIds"] = afterReplay.map(\.id)
            facts["retainedLocalSourceId"] = edited.id
            facts["originalUpdatedAt"] = secondApplied.updatedAt
            try attachFacts(facts, name: "Actual-subscription-fetch-diff-apply-cold-replay")
            try await reopened.close()
            active = nil
        } catch {
            facts["failedPhase"] = phase
            facts["failure"] = error.localizedDescription
            try? attachFacts(facts, name: "Actual-subscription-failure")
            if let active { try? await active.close() }
            // URL, status, encoding, admission and plan failures are failures.
            // Never skip, change URL, or substitute a historical/local response.
            throw error
        }
    }

    /// Uses the existing, complete 2026-10-22 Yiove download selected by its
    /// actual filesystem path. No HTTP response, source or package is invented.
    /// Controlled mutation placement proves the local fetch/preview boundary;
    /// it does not establish a new provider release or OS background execution.
    func testOriginalProviderPackageCheckRejectsChangedSubscriptionAndABAWithoutSourceWrites() async throws {
        let package = try originalProviderPackage()
        enum Change: CaseIterable, Equatable, Sendable { case unchanged, staleSnapshot, disableAutoUpdate, providerURL, aba }
        let alternateURL = "https://shuyuan-api.yiove.com/import/book-source-collection/e61838fa-9a13-4137-b68a-192313eade0c"
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionCheckOwnership-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        do {
            for (index, change) in Change.allCases.enumerated() {
                let original = ReaderSourceSubscription(id: 941007 + Int64(index), name: "真实订阅检查归属",
                    url: subscriptionURL, type: 0, customOrder: 0, autoUpdate: true, update: 0)
                let changesProvider = change == .providerURL || change == .aba
                let changed = ReaderSourceSubscription(id: original.id, name: original.name,
                    url: changesProvider ? alternateURL : original.url, type: original.type,
                    customOrder: original.customOrder, autoUpdate: changesProvider, update: original.update)
                _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
                if change == .staleSnapshot { _ = try await service.saveRuleSubscription(changed, operationID: UUID().uuidString) }
                do {
                    let plan = try await service.checkRuleSubscription(original, fetch: { url in
                        XCTAssertEqual(url.absoluteString, original.url)
                        XCTAssertNotEqual(change, .staleSnapshot, "A stale caller must be rejected before requesting its provider")
                        if change != .unchanged {
                            _ = try await service.saveRuleSubscription(changed, operationID: UUID().uuidString)
                            if change == .aba { _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString) }
                        }
                        return package
                    })
                    XCTAssertEqual(change, .unchanged, "An intervening accepted configuration change must not publish a preview")
                    XCTAssertEqual(plan.subscriptionId, original.id)
                    XCTAssertFalse(plan.changes.isEmpty)
                } catch {
                    guard change != .unchanged else { throw error }
                    guard error is ReaderSubscriptionCheckChanged else { throw error }
                }
                let expected = change == .unchanged || change == .aba ? original : changed
                let subscriptions = try await service.ruleSubscriptions()
                let retained = try XCTUnwrap(subscriptions.first(where: { $0.id == original.id }))
                XCTAssertEqual(retained, expected)
                let sources = try await service.onlineSources()
                let pending = try await service.pendingCoreCommands()
                XCTAssertTrue(sources.isEmpty, "Check rejection cannot import, replace or remove sources")
                XCTAssertTrue(pending.isEmpty, "A read rejection cannot allocate an apply operation")
                XCTAssertEqual(retained.update, original.update, "Only an original apply ACK may advance the subscription clock")
            }
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    /// The original complete download exercises Core's real replaceable plan
    /// slot. The newer configuration keeps the same provider and changes only
    /// auto-update permission; no HTTP response or source package is invented.
    func testOriginalProviderPackageStaleFetchCannotReplaceCurrentConfigurationPreview() async throws {
        actor CapturedPlan {
            var plan: ReaderSubscriptionPlan?
            func store(_ plan: ReaderSubscriptionPlan) { self.plan = plan }
        }
        let package = try originalProviderPackage()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionCurrentPreview-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        let original = ReaderSourceSubscription(id: 941012, name: "真实订阅预览槽归属",
            url: subscriptionURL, type: 0, customOrder: 0, autoUpdate: true, update: 0)
        let current = ReaderSourceSubscription(id: original.id, name: original.name, url: original.url,
            type: original.type, customOrder: original.customOrder, autoUpdate: false, update: original.update)
        let captured = CapturedPlan()
        do {
            _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
            do {
                _ = try await service.checkRuleSubscription(original, fetch: { url in
                    XCTAssertEqual(url.absoluteString, original.url)
                    _ = try await service.saveRuleSubscription(current, operationID: UUID().uuidString)
                    let plan = try await service.checkRuleSubscription(current, fetch: { currentURL in
                        XCTAssertEqual(currentURL.absoluteString, current.url)
                        return package
                    })
                    await captured.store(plan)
                    return package
                })
                XCTFail("The old fetch must be rejected before replacing the current configuration's preview")
            } catch is ReaderSubscriptionCheckChanged { }

            let storedPlan = await captured.plan
            let currentPlan = try XCTUnwrap(storedPlan, "The current configuration must have created its real Core preview")
            assertOriginalPlan(currentPlan, subscription: current)
            let beforeApply = try await service.onlineSources()
            let beforeSubscriptions = try await service.ruleSubscriptions()
            let beforePending = try await service.pendingCoreCommands()
            XCTAssertTrue(beforeApply.isEmpty, "Neither check may import the provider's sources")
            XCTAssertEqual(beforeSubscriptions, [current])
            XCTAssertTrue(beforePending.isEmpty, "The stale check cannot allocate an apply operation")
            let selected = try XCTUnwrap(currentPlan.changes.filter { $0.safeToApply && isHTTPSource($0.sourceId) }
                .sorted { $0.sourceId < $1.sourceId }.first, "Use one actual safe HTTP source from the original complete package")
            let applied = try await service.applyRuleSubscription(currentPlan, sourceIDs: [selected.sourceId], operationID: UUID().uuidString)
            assertOriginalApply(applied, plan: currentPlan, selectedID: selected.sourceId)
            let sources = try await service.onlineSources()
            XCTAssertEqual(sources.map(\.id), [selected.sourceId], "The newer preview must remain usable after the old fetch is rejected")
            let source = try XCTUnwrap(sources.first)
            XCTAssertEqual(source.name, selected.name)
            try assertDefinitionIdentity(source)
            let subscriptions = try await service.ruleSubscriptions()
            let retained = try XCTUnwrap(subscriptions.first)
            XCTAssertEqual(retained.id, current.id); XCTAssertEqual(retained.url, current.url)
            XCTAssertFalse(retained.autoUpdate); XCTAssertEqual(retained.update, applied.updatedAt)
            let pending = try await service.pendingCoreCommands()
            XCTAssertTrue(pending.isEmpty)
            try await service.close()
        } catch {
            try? await service.close()
            throw error
        }
    }

    /// Places a configuration change after the old caller's final head read,
    /// immediately before preview admission. Uses the unchanged downloaded
    /// package and Core's real single plan slot, without network or delays.
    func testOriginalProviderPackageAtomicPreviewAdmissionRetainsCurrentPlanAfterFinalHeadReadAndABA() async throws {
        let package = try originalProviderPackage()
        let remoteJSON = try XCTUnwrap(String(data: package, encoding: .utf8))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionAtomicAdmission-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        for aba in [false, true] {
            let directory = root.appendingPathComponent(aba ? "aba" : "changed")
            let service = try ReaderLibraryService(storageURL: directory.appendingPathComponent("Core"), sourceURL: directory.appendingPathComponent("Sources"))
            do {
                let original = ReaderSourceSubscription(id: 941013, name: "真实订阅原子预览准入",
                    url: subscriptionURL, type: 0, customOrder: 0, autoUpdate: true, update: 0)
                let changed = ReaderSourceSubscription(id: original.id, name: original.name, url: original.url,
                    type: original.type, customOrder: original.customOrder, autoUpdate: false, update: original.update)
                _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
                let query = try await service.coreRead("rules.mutation.query", [:])
                let originalHead = try XCTUnwrap(JSONSerialization.jsonObject(with: query) as? [String: Any])["head"] ?? NSNull()
                let snapshot = try JSONSerialization.jsonObject(with: JSONEncoder().encode(original))
                let expected: [String: Any] = ["subscription": snapshot, "rulesHead": originalHead]

                _ = try await service.saveRuleSubscription(changed, operationID: UUID().uuidString)
                if aba { _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString) }
                let current = aba ? original : changed
                let currentPlan = try await service.checkRuleSubscription(current, fetch: { url in
                    XCTAssertEqual(url.absoluteString, current.url)
                    return package
                })
                do {
                    _ = try await service.coreRead("rule-sub.update.preview.v1", [
                        "subscriptionId": original.id, "remoteJson": remoteJSON, "expected": expected
                    ])
                    XCTFail("A changed fetch owner must be rejected before it replaces the newer plan")
                } catch ReaderLibraryError.core(let code, _, _, let reason) {
                    XCTAssertEqual(code, "INVALID_PARAMS")
                    XCTAssertEqual(reason, "SUBSCRIPTION_CHECK_CHANGED")
                }
                let beforeApply = try await service.onlineSources()
                let beforeSubscriptions = try await service.ruleSubscriptions()
                let pending = try await service.pendingCoreCommands()
                XCTAssertTrue(beforeApply.isEmpty)
                XCTAssertEqual(beforeSubscriptions, [current])
                XCTAssertTrue(pending.isEmpty, "A stale preview rejection cannot allocate a mutation")
                let selected = try XCTUnwrap(currentPlan.changes.filter { $0.safeToApply && isHTTPSource($0.sourceId) }
                    .sorted { $0.sourceId < $1.sourceId }.first)
                let applied = try await service.applyRuleSubscription(currentPlan, sourceIDs: [selected.sourceId], operationID: UUID().uuidString)
                assertOriginalApply(applied, plan: currentPlan, selectedID: selected.sourceId)
                let sources = try await service.onlineSources()
                XCTAssertEqual(sources.map(\.id), [selected.sourceId], "The exact newer plan must remain usable")
                try await service.close()
            } catch { try? await service.close(); throw error }
        }
    }

    /// These metadata-only cases use the two existing provider addresses. No
    /// provider request or source package is constructed for a delete guard.
    func testOriginalProviderSubscriptionDeleteRejectsChangedCapturedConfiguration() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionDeleteBaseline-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        let original = ReaderSourceSubscription(id: 941016, name: "真实 Yiove 订阅删除归属", url: subscriptionURL,
            type: 0, customOrder: 0, autoUpdate: true, update: 0)
        let alternateURL = "https://shuyuan-api.yiove.com/import/book-source-collection/e61838fa-9a13-4137-b68a-192313eade0c"
        do {
            for field in 0..<5 {
                let captured = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
                let current = ReaderSourceSubscription(id: original.id,
                    name: field == 0 ? "已编辑的 Yiove 订阅名称" : original.name,
                    url: field == 1 ? alternateURL : original.url, type: field == 2 ? 1 : original.type,
                    customOrder: field == 3 ? 1 : original.customOrder,
                    autoUpdate: field == 4 ? false : original.autoUpdate, update: original.update)
                _ = try await service.saveRuleSubscription(current, operationID: UUID().uuidString)
                let operationID = UUID().uuidString
                do {
                    try await service.deleteRuleSubscription(captured, operationID: operationID)
                    XCTFail("The captured delete must not remove a changed subscription configuration")
                } catch is ReaderSubscriptionCheckChanged { }
                let rows = try await service.ruleSubscriptions()
                XCTAssertEqual(rows, [current])
                let parameters = try await service.existingCoreParameters(operationID: operationID, method: "rules.mutation.apply")
                XCTAssertNil(parameters, "A changed captured row is rejected before allocating a new Core write")
            }
            let pending = try await service.pendingCoreCommands()
            XCTAssertTrue(pending.isEmpty)
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

    /// An actual apply clock may advance without changing the captured address
    /// configuration. Delete removes that address and retains its imported source.
    func testOriginalProviderPackageSubscriptionDeleteAllowsAcknowledgedClockAndPreservesSource() async throws {
        let package = try originalProviderPackage()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionDeleteClock-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        let original = ReaderSourceSubscription(id: 941017, name: "真实 Yiove 订阅删除保留书源", url: subscriptionURL,
            type: 0, customOrder: 0, autoUpdate: false, update: 0)
        do {
            _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
            let plan = try await service.checkRuleSubscription(original, fetch: { url in
                XCTAssertEqual(url.absoluteString, original.url)
                return package
            })
            let selected = try XCTUnwrap(plan.changes.filter { $0.safeToApply && isHTTPSource($0.sourceId) }
                .sorted { $0.sourceId < $1.sourceId }.first)
            let applied = try await service.applyRuleSubscription(plan, sourceIDs: [selected.sourceId], operationID: UUID().uuidString)
            assertOriginalApply(applied, plan: plan, selectedID: selected.sourceId)
            XCTAssertGreaterThan(applied.updatedAt, original.update)
            let rows = try await service.ruleSubscriptions()
            XCTAssertEqual(rows.first?.update, applied.updatedAt)
            let sources = try await service.onlineSources()
            XCTAssertEqual(sources.map(\.id), [selected.sourceId])
            try await service.deleteRuleSubscription(original, operationID: UUID().uuidString)
            let retainedRows = try await service.ruleSubscriptions()
            let retainedSources = try await service.onlineSources()
            let pending = try await service.pendingCoreCommands()
            XCTAssertTrue(retainedRows.isEmpty)
            XCTAssertEqual(retainedSources, sources, "Removing an address must preserve the complete original imported source")
            XCTAssertTrue(pending.isEmpty)
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

    func testOriginalProviderSubscriptionDeleteCapturedSequenceRejectsInterveningWriteAndABA() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionDeleteSequence-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        let original = ReaderSourceSubscription(id: 941018, name: "真实 Yiove 订阅删除序列", url: subscriptionURL,
            type: 0, customOrder: 0, autoUpdate: true, update: 0)
        let changed = ReaderSourceSubscription(id: original.id, name: original.name, url: original.url,
            type: original.type, customOrder: original.customOrder, autoUpdate: false, update: original.update)
        do {
            for aba in [false, true] {
                _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
                let nextSequence = try await service.prepareRuleSubscriptionDelete(original)
                _ = try await service.saveRuleSubscription(changed, operationID: UUID().uuidString)
                if aba { _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString) }
                do {
                    // This is the dispatch boundary after the final awaited head
                    // read. Core must atomically reject this captured sequence.
                    _ = try await service.rulesMutation("rule-sub.delete", ["id": original.id],
                        operationID: UUID().uuidString, nextSequence: nextSequence)
                    XCTFail("An intervening rules write, including A -> B -> A, must not rebase the delete")
                } catch ReaderLibraryError.core(let code, _, _, let reason) {
                    XCTAssertEqual(code, "INVALID_PARAMS"); XCTAssertEqual(reason, "rules_mutation_rejected")
                }
                let rows = try await service.ruleSubscriptions()
                let pending = try await service.pendingCoreCommands()
                XCTAssertEqual(rows, [aba ? original : changed])
                XCTAssertTrue(pending.isEmpty)
            }
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

    func testOriginalProviderSubscriptionDeleteColdReplayConsumesOriginalWrapperBeforeReadingRow() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderSubscriptionDeleteReplay-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let storage = root.appendingPathComponent("Core"), sources = root.appendingPathComponent("Sources")
        var gate = try StagingCoreGate(storage: storage)
        defer { gate.release(); gate.destroy() }
        var service = try ReaderLibraryService(storageURL: storage, sourceURL: sources, client: gate, timing: gate.timing)
        let original = ReaderSourceSubscription(id: 941019, name: "真实 Yiove 订阅原删除回执", url: subscriptionURL,
            type: 0, customOrder: 0, autoUpdate: false, update: 0)
        _ = try await service.saveRuleSubscription(original, operationID: UUID().uuidString)
        let operationID = UUID().uuidString
        gate.hold("rules.mutation.apply", advanceObserverDeadline: true)
        do {
            try await service.deleteRuleSubscription(original, operationID: operationID)
            XCTFail("The original Core delete terminal is held")
        } catch ReaderLibraryError.operationPending(_) { }
        let parameters = try await service.existingCoreParameters(operationID: operationID, method: "rules.mutation.apply")
        let frozen = try XCTUnwrap(parameters)
        let bytes = try JSONSerialization.data(withJSONObject: frozen, options: [.sortedKeys])
        gate.destroy()
        gate = try StagingCoreGate(storage: storage)
        service = try ReaderLibraryService(storageURL: storage, sourceURL: sources, client: gate, timing: gate.timing)
        do {
            try await service.deleteRuleSubscription(original, operationID: operationID)
            XCTAssertEqual(gate.count("rule-sub.list"), 0, "Replay cannot reject an original delete because its row is now absent")
            XCTAssertEqual(gate.count("rules.mutation.apply"), 0, "The original receipt is consumed without another write")
            let retainedParameters = try await service.existingCoreParameters(operationID: operationID, method: "rules.mutation.apply")
            let retained = try XCTUnwrap(retainedParameters)
            XCTAssertEqual(try JSONSerialization.data(withJSONObject: retained, options: [.sortedKeys]), bytes)
            let rows = try await service.ruleSubscriptions()
            let pending = try await service.pendingCoreCommands()
            XCTAssertTrue(rows.isEmpty); XCTAssertTrue(pending.isEmpty)
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

    private func originalProviderPackage() throws -> Data {
        let path = try XCTUnwrap(ProcessInfo.processInfo.environment["READER_REAL_SUBSCRIPTION_PACKAGE_PATH"],
            "Select the existing complete Yiove response.body; do not create or replace package input")
        let inputURL: URL
        if path.hasPrefix("bundle:") {
            inputURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: String(path.dropFirst("bundle:".count)), withExtension: nil),
                                     "Copy the unmodified downloaded response into this signed test bundle")
        } else {
            guard path.hasPrefix("/") else {
                XCTFail("The local runner must provide an absolute original input path")
                throw ReaderLibraryError.invalidResponse("original subscription corpus path")
            }
            inputURL = URL(fileURLWithPath: path)
        }
        let package = try Data(contentsOf: inputURL)
        let digest = SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined()
        guard package.count == 2_309_841,
              digest == "3356dc7a114b50076897873758482ed07fc45b7a1f55bdeced870e1db5fdd663" else {
            XCTFail("The selected input must be the complete unmodified original Yiove download")
            throw ReaderLibraryError.invalidResponse("original subscription corpus identity")
        }
        return package
    }

    private func isHTTPSource(_ identity: String) -> Bool {
        guard let url = URL(string: identity), let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme), let host = url.host else { return false }
        return !host.isEmpty
    }

    private func assertOriginalPlan(_ plan: ReaderSubscriptionPlan, subscription: ReaderSourceSubscription,
                                    file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(plan.subscriptionId, subscription.id, file: file, line: line)
        XCTAssertTrue(plan.planId.hasPrefix("\(subscription.id):"), file: file, line: line)
        XCTAssertEqual(plan.remoteDigest.count, 64, file: file, line: line)
        XCTAssertTrue(plan.remoteDigest.allSatisfy { "0123456789abcdef".contains($0) }, file: file, line: line)
        XCTAssertGreaterThan(plan.expiresAt, Int64(Date().timeIntervalSince1970 * 1000), file: file, line: line)
        XCTAssertEqual(Set(plan.changes.map(\.sourceId)).count, plan.changes.count, file: file, line: line)
    }

    private func assertOriginalApply(_ applied: ReaderSubscriptionApplied, plan: ReaderSubscriptionPlan, selectedID: String,
                                     file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(applied.subscriptionId, plan.subscriptionId, file: file, line: line)
        XCTAssertEqual(applied.remoteDigest, plan.remoteDigest, file: file, line: line)
        XCTAssertEqual(applied.appliedSourceIds, [selectedID], file: file, line: line)
        XCTAssertFalse(applied.skippedSourceIds.contains(selectedID), file: file, line: line)
        XCTAssertEqual(Set(applied.appliedSourceIds + applied.skippedSourceIds), Set(plan.changes.map(\.sourceId)), file: file, line: line)
        XCTAssertGreaterThan(applied.updatedAt, 0, file: file, line: line)
    }

    private func assertDefinitionIdentity(_ source: ReaderOnlineSource, file: StaticString = #filePath, line: UInt = #line) throws {
        let definition = try XCTUnwrap(JSONSerialization.jsonObject(with: source.definition) as? [String: Any], file: file, line: line)
        XCTAssertEqual((definition["bookSourceUrl"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), source.id, file: file, line: line)
    }

    private func attach<T: Encodable>(_ value: T, name: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let attachment = XCTAttachment(data: try encoder.encode(value), uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }

    private func attachFacts(_ facts: [String: Any], name: String) throws {
        let attachment = XCTAttachment(data: try JSONSerialization.data(withJSONObject: facts, options: [.prettyPrinted, .sortedKeys]), uniformTypeIdentifier: "public.json")
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
}
