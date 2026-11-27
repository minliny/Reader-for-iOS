import CryptoKit
import Foundation
import ReaderCoreBridge
import ReaderHost
import SQLite3
import XCTest
@testable import ReaderApp

@MainActor

extension XCTestCase {
    var testSupportDirectory: URL {
        get throws {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true
            )
            let directory = support.appendingPathComponent("XPLAT-M1-WAVE1-XCTest", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        }
    }

    func fixture(_ name: String, _ ext: String) throws -> URL {
        let bundle = Bundle(for: type(of: self))
        return try XCTUnwrap(bundle.url(forResource: name, withExtension: ext))
    }

    func decodeFixture<T: Decodable>(_ name: String) throws -> T {
        try JSONDecoder().decode(T.self, from: Data(contentsOf: fixture(name, "json")))
    }

    func hash(_ file: URL) throws -> String {
        try SHA256.hash(data: Data(contentsOf: file)).map { String(format: "%02x", $0) }.joined()
    }

    func isolatedRoot() throws -> URL {
        let url = try testSupportDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func importFixture(
        _ input: URL, runtime: CoreRuntimeActor, root: URL
    ) async throws -> LocalImportCoordinator.Receipt {
        let assets = root.appendingPathComponent("assets", isDirectory: true)
        let files = FileAndAssetHost(root: assets, sandboxRoots: [input.deletingLastPathComponent()])
        let journal = ImportJournal(root: assets)
        let receipt = try await LocalImportCoordinator(runtime: runtime, files: files, journal: journal)
            .importSelectedFile(input)
        XCTAssertEqual(receipt.bookId, "local:\(try hash(input))")
        XCTAssertTrue(receipt.shelf.created)
        XCTAssertEqual(receipt.shelf.sourceId, "local")
        XCTAssertFalse(receipt.cleanupDeferred)
        XCTAssertEqual(try hash(input), receipt.source.sha256)
        XCTAssertEqual(try hash(receipt.source.path), receipt.source.sha256)
        XCTAssertEqual(receipt.source.path.lastPathComponent, receipt.source.sha256 + ".source")
        let unresolved = try await journal.pending()
        XCTAssertTrue(unresolved.isEmpty)
        return receipt
    }

    func assertLibrary47(_ library: LibraryHost, fresh: Bool) {
        XCTAssertEqual(library.probe.observation.freshStorage, fresh)
        XCTAssertEqual(library.info.sqliteUserVersion, 47)
        XCTAssertEqual(library.info.storageFormat?.format, .library47)
        XCTAssertEqual(library.info.abiVersion, 1)
        XCTAssertFalse(library.info.buildIdentity.gitDirty)
        XCTAssertEqual(library.info.buildIdentity.gitCommit, "fa536a10c31ab5a35df2e2c1c1fbf70ebf3e1be9")
        XCTAssertEqual(library.info.storageFormat?.capabilities?.physicalBackup, true)
        XCTAssertEqual(library.info.storageFormat?.capabilities?.physicalRestore, true)
        XCTAssertEqual(library.info.storageFormat?.capabilities?.activeLibrarySync, false)
        XCTAssertEqual(library.info.storageFormat?.capabilities?.logicalRestoreRequiresCompleteCoverage, true)
    }
}

struct LifeFixture: Decodable {
    let localSourceId: String
    let otherSourceId: String
    let otherChapterIndex: Int64
    let otherScalar: Int64
    let hostSupported: String
    let hostOmitted: String
    let unavailableDiagnostic: String
    let stalePositionReason: String
    let staleProgressReason: String
}

struct ScalarFixture: Decodable {
    let prefix: String
    let selectedText: String
    let startScalar: Int64
    let endScalar: Int64
    let startUtf16: Int64
    let endUtf16: Int64

    func verify(in content: String) throws {
        XCTAssertEqual(Array(content.unicodeScalars.prefix(Int(startScalar))), Array(prefix.unicodeScalars))
        XCTAssertEqual(prefix.utf16.count, Int(startUtf16))
        let selection = String(String.UnicodeScalarView(
            content.unicodeScalars.dropFirst(Int(startScalar)).prefix(Int(endScalar - startScalar))
        ))
        XCTAssertEqual(selection, selectedText)
        XCTAssertEqual(prefix.utf16.count + selection.utf16.count, Int(endUtf16))
    }
}

enum FixtureSQL: Error {
    case open(Int32), statement(Int32, String)
}

@MainActor
final class StorageWriteFence {
    private var db: OpaquePointer?

    init(_ path: URL, create: Bool = false) throws {
        let flags = create ? SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE : SQLITE_OPEN_READWRITE
        var handle: OpaquePointer?
        let result = sqlite3_open_v2(path.path, &handle, flags, nil)
        guard result == SQLITE_OK, let handle else {
            sqlite3_close(handle)
            throw FixtureSQL.open(result)
        }
        self.db = handle
    }

    func execute(_ sql: String) throws {
        let result = sqlite3_exec(db, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw FixtureSQL.statement(result, String(cString: sqlite3_errmsg(db)))
        }
    }

    func release() {
        sqlite3_close(db)
        db = nil
    }
}
