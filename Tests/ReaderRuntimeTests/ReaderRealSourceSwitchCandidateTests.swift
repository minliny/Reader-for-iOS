import CryptoKit
import Foundation
import Security
import XCTest
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderRealSourceSwitchCandidateTests: XCTestCase {
    /// Actual provisioned definitions, one anonymous provider search and real Core policy.
    /// This is not native UI or a completed source-switch acceptance scenario.
    func testRealBaiduSearchCandidatesUseCanonicalCorePolicyWithoutShelfOrProgressWrites() async throws {
        let manager = FileManager.default
        let digest = "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322"
        let base = "https://dushu.baidu.com/"
        let documents = try XCTUnwrap(manager.urls(for: .documentDirectory, in: .userDomainMask).first)
        let input = documents.appendingPathComponent("Reader-real-sources.json")
        let root = manager.temporaryDirectory.appendingPathComponent("ReaderRealSwitchCandidates-" + UUID().uuidString)
        let sourcesURL = root.appendingPathComponent("Sources"), operations = sourcesURL.appendingPathComponent(".operations")
        let identityURL = operations.appendingPathComponent(ReaderHostLibraryIdentity.fileName)
        var library: ReaderLibraryService?
        var identityBytes: Data?
        var credentialService: String?
        var namespaceAdmitted = false
        var phase = "admit unchanged input and fresh namespace"
        var failure: Error?
        var facts: [String: Any] = ["temporaryRoot": root.path, "inputPath": input.path, "expectedInputBytes": 5606,
            "expectedInputSHA256": digest, "coreBaseline": ReaderLibraryService.coreBaseline,
            "scope": "actual anonymous provider/Core candidate policy; native UI and completed source switch NOT_RUN"]
        func hash(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
        func require(_ value: Bool, _ detail: String) throws {
            guard value else { XCTFail(detail); throw ReaderLibraryError.invalidResponse(detail) }
        }
        func persist(_ name: String) throws {
            let bytes = try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys, .prettyPrinted])
            try bytes.write(to: root.appendingPathComponent("input-provenance.json"), options: [.atomic, .completeFileProtection])
            let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
            attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
        }
        func metadata(_ candidate: ReaderOnlineCandidate) -> [String: Any] {
            ["sourceId": candidate.sourceId, "bookId": candidate.bookId, "title": candidate.title, "author": candidate.author,
             "coreBookSHA256": candidate.coreBook.map(hash) ?? "absent"]
        }
        do {
            try require(!manager.fileExists(atPath: root.path), "The independent UUID library must not pre-exist")
            let namespace = try ReaderHostLibraryIdentity.loadOrCreate(in: operations)
            identityBytes = try Data(contentsOf: identityURL)
            facts["namespace"] = namespace
            let inputFacts = try input.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
            try require(inputFacts.isRegularFile == true && inputFacts.isSymbolicLink != true && inputFacts.fileSize == 5606,
                        "Use only the provisioned unchanged 5606-byte original source package")
            let originalBytes = try Data(contentsOf: input)
            facts["actualInputBytes"] = originalBytes.count; facts["actualInputSHA256"] = hash(originalBytes)
            try require(originalBytes.count == 5606 && hash(originalBytes) == digest, "The original source package SHA256 must match")
            let definitions = try XCTUnwrap(JSONSerialization.jsonObject(with: originalBytes) as? [[String: Any]])
            try require(definitions.count == 2 && definitions.filter { $0["bookSourceUrl"] as? String == base }.count == 1,
                        "The unchanged package must contain its two original definitions and exact Baidu entry")
            let serviceName = "io.reader.minliny.source-cookies." + hash(Data(namespace.utf8))
            credentialService = serviceName
            let namespaceQuery: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: serviceName,
                kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll]
            var attributes: CFTypeRef?
            try require(SecItemCopyMatching(namespaceQuery as CFDictionary, &attributes) == errSecItemNotFound,
                        "The exact fresh UUID credential namespace must be empty before networking")
            namespaceAdmitted = true
            try persist("real-candidate-input-and-namespace-provenance")
            let active = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: sourcesURL)
            library = active
            let beforeShelf = try await active.listBooks()
            try require(beforeShelf.isEmpty, "The new independent Core shelf must begin empty")
            phase = "import unchanged original definitions"
            let imported = try await active.importSources(originalBytes, operationID: UUID().uuidString)
            try require(imported.count == 2 && imported.allSatisfy(\.succeeded), "Both original source definitions must import through actual Core ACKs")
            let stored = try await active.onlineSources()
            let matches = stored.filter { $0.baseURL == base }
            try require(stored.count == 2 && matches.count == 1, "Select only the actual imported Baidu source by its original base URL")
            let source = try XCTUnwrap(matches.first)
            try require(source.enabled && source.id == base, "The selected original Baidu source must remain enabled and keep its exact identity")
            facts["sourceId"] = source.id; facts["sourceVersion"] = source.version; facts["sourceName"] = source.name
            phase = "one anonymous production search"
            facts["searchSourceInvocations"] = 1
            let response = try await active.searchSource(source.id, keyword: "剑来", page: 1)
            facts["actualSearchRows"] = response.books.map(metadata); facts["actualSearchCount"] = response.books.count
            try persist("real-candidate-actual-provider-search-metadata")
            let selected = try XCTUnwrap(response.books.first { $0.title == "剑来" }, "The actual response must supply the exact original title 剑来")
            // These distinct Chinese titles were observed in the retained real Baidu response.
            // Require one again; never manufacture a wrong candidate to force exclusion.
            let knownDifferentTitles: Set<String> = ["心念剑来", "剑来酒来", "剑来：剑去", "剑来：后传", "剑来封天"]
            let unrelated = response.books.filter { knownDifferentTitles.contains($0.title) }
            try require(!unrelated.isEmpty, "This actual response must contain a distinct observed title before claiming exclusion")
            let book = ReaderBook(sourceId: selected.sourceId, bookId: selected.bookId, title: selected.title, author: selected.author)
            let beforeProgress = try await active.progress(for: book)
            try require(!beforeProgress.found && beforeProgress.progress == nil, "Anonymous search must not create progress for its actual original book")
            phase = "real Core canonical candidate policy"
            let admitted = try await active.sourceSwitchCandidates(for: book, among: response.books)
            let strictBytes = try await active.coreRead("search-book.related", ["mode": "sourceSwitchCandidates",
                "identity": ["sourceId": book.sourceId, "bookId": book.bookId], "limit": 128])
            let strict = try XCTUnwrap(JSONSerialization.jsonObject(with: strictBytes) as? [String: Any])
            let rows = try XCTUnwrap(strict["books"] as? [[String: Any]])
            try require(strict["complete"] as? Bool == true && strict["nextCursor"] == nil,
                        "This fresh actual response must have a complete bounded canonical Core projection")
            func identity(_ source: String, _ book: String) -> [Data] { [Data(source.utf8), Data(book.utf8)] }
            let inputIDs = Set(response.books.map { identity($0.sourceId, $0.bookId) })
            var canonical: [[Data]: [String: Any]] = [:]
            for row in rows { canonical[identity(try XCTUnwrap(row["origin"] as? String), try XCTUnwrap(row["bookUrl"] as? String))] = row }
            try require(canonical[identity(book.sourceId, book.bookId)] != nil, "The real strict projection must confirm the original indexed identity")
            for candidate in admitted {
                let key = identity(candidate.sourceId, candidate.bookId)
                let row = try XCTUnwrap(canonical[key])
                try require(key != identity(book.sourceId, book.bookId) && inputIDs.contains(key), "Each admitted identity must come from this actual response and exclude the original")
                try require(Data(candidate.title.utf8) == Data(try XCTUnwrap(row["name"] as? String).utf8)
                            && Data(candidate.author.utf8) == Data(try XCTUnwrap(row["author"] as? String).utf8),
                            "Candidate display metadata must be the actual canonical Core bytes")
            }
            let admittedIDs = Set(admitted.map { identity($0.sourceId, $0.bookId) })
            let expectedIDs = Set(canonical.keys).intersection(inputIDs).subtracting([identity(book.sourceId, book.bookId)])
            try require(admittedIDs == expectedIDs, "The adapter must return the complete intersection authorized by actual Core")
            try require(unrelated.allSatisfy { !admittedIDs.contains(identity($0.sourceId, $0.bookId)) }, "Actual distinct-title search hits must not become same-book source candidates")
            facts["original"] = metadata(selected); facts["actualUnrelatedRowsExcluded"] = unrelated.map(metadata)
            facts["actualAdmittedRows"] = admitted.map(metadata); facts["actualCanonicalCount"] = rows.count
            facts["actualCanonicalRows"] = rows.map { ["origin": $0["origin"] ?? "", "bookUrl": $0["bookUrl"] ?? "", "name": $0["name"] ?? "", "author": $0["author"] ?? ""] }
            phase = "confirm isolated shelf progress and input preservation"
            let afterShelf = try await active.listBooks(), afterProgress = try await active.progress(for: book)
            try require(afterShelf == beforeShelf && afterProgress == beforeProgress, "Candidate policy reads must preserve the independent empty shelf and original absent progress")
            try require(try Data(contentsOf: input) == originalBytes && Data(contentsOf: identityURL) == identityBytes,
                        "Original input bytes and the UUID credential identity must remain unchanged")
            facts["inputBytesPreserved"] = true; facts["emptyShelfPreserved"] = true; facts["absentProgressPreserved"] = true
        } catch { failure = error; facts["failedPhase"] = phase; facts["failure"] = String(describing: error) }
        do {
            if let active = library { try await active.close(); library = nil; facts["runtimeClosed"] = true }
            if namespaceAdmitted, let credentialService {
                try require(try Data(contentsOf: identityURL) == identityBytes, "Verify exact UUID ownership before credential cleanup")
                let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: credentialService,
                    kSecReturnAttributes as String: true, kSecMatchLimit as String: kSecMatchLimitAll]
                var result: CFTypeRef?
                let status = SecItemCopyMatching(query as CFDictionary, &result)
                try require(status == errSecSuccess || status == errSecItemNotFound, "Inspect only this closed UUID namespace's created credential attributes")
                let created = status == errSecSuccess ? try XCTUnwrap(result as? [[String: Any]]) : []
                for item in created {
                    let account = try XCTUnwrap(item[kSecAttrAccount as String] as? String)
                    try require(item[kSecAttrService as String] as? String == credentialService, "Every cleanup pair must belong to the exact admitted namespace")
                    let pair: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: credentialService, kSecAttrAccount as String: account]
                    let removed = SecItemDelete(pair as CFDictionary)
                    try require((removed == errSecSuccess || removed == errSecItemNotFound) && SecItemCopyMatching(pair as CFDictionary, nil) == errSecItemNotFound,
                                "Remove only each actually created exact service/account pair after Core closes")
                }
                facts["retiredOwnCredentialPairs"] = created.count
            }
        } catch { if failure == nil { failure = error }; facts["closeOrCleanupFailure"] = String(describing: error) }
        if let failure {
            facts["temporaryRootRetained"] = manager.fileExists(atPath: root.path)
            try? persist("real-candidate-policy-failure-retained-UUID-and-provenance")
            throw failure
        }
        facts["result"] = "actual provider/Core candidate policy confirmed; no detail, body, login, download or switch write"
        try persist("real-candidate-policy-input-and-isolation-confirmed")
        do { try manager.removeItem(at: root) }
        catch {
            try manager.createDirectory(at: operations, withIntermediateDirectories: true)
            if let identityBytes, !manager.fileExists(atPath: identityURL.path) { try identityBytes.write(to: identityURL, options: .withoutOverwriting) }
            facts["rootRemovalFailure"] = String(describing: error)
            try? persist("real-candidate-policy-cleanup-failure-retained-UUID")
            throw error
        }
    }
}
