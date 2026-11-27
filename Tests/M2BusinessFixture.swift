import Foundation
import ReaderCoreBridge
import ReaderHost
import XCTest
@testable import ReaderApp

struct M2BusinessFixture {
    struct State: Decodable {
        let counters: [String: Int]
        let holds: [String]
        let failures: [String]

        func count(_ path: String) -> Int { counters[path, default: 0] }
    }

    struct Source: Sendable {
        let suite: String
        let edition: String
        var id: String { suite == "sources" ? base : "m2-\(suite)-\(edition)" }
        var path: String { "/books/\(suite)/\(edition)" }
        var base: String { M2BusinessFixture.base + path }
        var bookID: String { base + "/detail" }
        var title: String { M2BusinessFixture.title }
        var tocURL: String { base + "/toc" }
        var loginURL: URL { URL(string: base + "/login")! }

        func chapterPath(_ number: Int) -> String { path + "/chapter/\(number)" }

        func importParams() async throws -> M2SourceImportParams {
            let bytes = try await M2BusinessFixture.read(path + "/rules")
            let rules = try JSONDecoder().decode([String: ReaderM1JSONValue].self, from: bytes)
            return .init(sourceId: id, name: "回环来源 \(edition)", baseUrl: base, bookSource: rules)
        }

        var detailParams: M2BookDetailParams {
            .init(sourceId: id, book: .init(bookId: bookID, title: title, author: M2BusinessFixture.author),
                  bookUrl: bookID)
        }

        var directoryParams: M2BookTocParams {
            .init(sourceId: id, bookId: bookID, tocUrl: tocURL)
        }

        func chapter(_ number: Int, cacheOnly: Bool? = nil) -> M2ChapterContentParams {
            .init(cacheOnly: cacheOnly, sourceId: id, bookId: bookID,
                  chapterTitle: M2BusinessFixture.chapterTitles[number - 1],
                  chapterIndex: Int64(number - 1), chapterUrl: base + "/chapter/\(number)")
        }
    }

    static let base = "http://127.0.0.1:18765"
    static let title = "受控回环书"
    static let author = "测试作者"
    static let chapterTitles = ["第一章", "第二章", "第三章", "第四章"]
    static let chapterOne = "墨纸青松，受控回环正文。中文𠀀与Café都在这一段，供阅读位置及换源核验。"
        + "这一段是固定输入，用来核验多层书源检测、真实正文处理、本地缓存读回及不同版本之间的阅读位置。"

    static func read(_ path: String) async throws -> Data {
        try await exchange(url: XCTUnwrap(URL(string: base + path)))
    }

    static func state() async throws -> State {
        try await JSONDecoder().decode(State.self, from: read("/control/state"))
    }

    static func configure(_ path: String, _ mode: String) async throws {
        try await control("configure", path: path, extra: [.init(name: "mode", value: mode)])
    }

    static func release(_ path: String) async throws {
        try await control("release", path: path)
    }

    static func waitForRequest(_ path: String, after observed: Int) async throws {
        let deadline = ContinuousClock.now + .seconds(12)
        repeat {
            if try await state().count(path) > observed { return }
            try await Task.sleep(for: .milliseconds(35))
        } while ContinuousClock.now < deadline
        throw Failure.fixtureRequestMissing(path)
    }

    private static func control(_ operation: String, path: String, extra: [URLQueryItem] = []) async throws {
        var endpoint = try XCTUnwrap(URLComponents(string: base + "/control/" + operation))
        endpoint.queryItems = [.init(name: "path", value: path)] + extra
        _ = try await exchange(url: XCTUnwrap(endpoint.url), method: "POST")
    }

    private static func exchange(url: URL, method: String = "GET") async throws -> Data {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 4)
        request.httpMethod = method
        let (data, reply) = try await URLSession.shared.data(for: request)
        guard (reply as? HTTPURLResponse)?.statusCode == 200 else {
            throw Failure.fixtureResponseMismatch(url.path)
        }
        return data
    }

    enum Failure: Error {
        case fixtureRequestMissing(String)
        case fixtureResponseMismatch(String)
        case incorrectProtocolVariant
    }
}

@MainActor
extension XCTestCase {
    func m2Support() throws -> URL {
        let root = URL.applicationSupportDirectory.appending(path: "XPLAT-M2-WAVE2A-XCTest", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    func m2Open(_ root: URL, fresh: Bool) async throws -> (LibraryHost, NetworkAndWebHost) {
        let network = try NetworkAndWebHost(directory: root.appending(path: "network", directoryHint: .isDirectory))
        let library = try await LibraryHost.open(directory: root.appending(path: "library", directoryHint: .isDirectory),
                                                host: network)
        XCTAssertEqual(library.probe.observation.freshStorage, fresh)
        XCTAssertEqual(library.info.sqliteUserVersion, 47)
        XCTAssertEqual(library.info.storageFormat?.format, .library47)
        if let existing = library.probe.observation.layout {
            XCTAssertEqual(existing.layoutId, "reader-sqlite-47-remote")
        }
        XCTAssertFalse(library.info.buildIdentity.gitDirty)
        print("M2_LIBRARY pid=\(ProcessInfo.processInfo.processIdentifier) core=\(library.info.buildIdentity.gitCommit) fresh=\(fresh)")
        return (library, network)
    }

    func m2Import(
        _ input: M2BusinessFixture.Source, with sources: SourceManagementCoordinator
    ) async throws -> M2RulesMutationReceiptSourceImport {
        let preview = try await sources.previewImport(input.importParams())
        let listed = try await sources.list(.init(sourceId: input.id))
        XCTAssertEqual(listed.total, 0, "confirm owns the mutation")
        let terminal = try await sources.confirmImport(preview)
        guard case .sourceImport(let receipt) = terminal else {
            XCTFail("source.import original terminal was \(terminal)")
            throw M2BusinessFixture.Failure.incorrectProtocolVariant
        }
        let readback = try await sources.list(.init(sourceId: input.id))
        XCTAssertTrue(receipt.data.imported)
        XCTAssertEqual(receipt.data.sourceId, input.id)
        XCTAssertEqual(readback.sources.first?.sourceId, input.id)
        XCTAssertEqual(readback.total, 1)
        print("M2_SOURCE_IMPORT source=\(input.id) operation=\(receipt.binding.operationId)")
        return receipt
    }

    func m2AddToShelf(_ input: M2BusinessFixture.Source, runtime: CoreRuntimeActor) async throws -> BookshelfEntryData {
        let added = try await runtime.request(ReaderM1.bookshelfAdd,
            .init(sourceId: input.id, bookId: input.bookID, title: input.title, author: M2BusinessFixture.author, kind: "text"))
        XCTAssertTrue(added.value.created)
        let record = try await runtime.request(ReaderM1.bookshelfGet, .init(sourceId: input.id, bookId: input.bookID))
        return try XCTUnwrap(record.value.book)
    }

    func m2Files(_ root: URL) -> FileAndAssetHost {
        FileAndAssetHost(root: root.appending(path: "assets", directoryHint: .isDirectory), sandboxRoots: [root])
    }

    func m2WriteReceipt<T: Encodable>(_ receipt: T, named name: String) throws {
        try JSONEncoder().encode(receipt).write(to: m2Support().appending(path: name), options: .atomic)
    }

    func m2ReadReceipt<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(contentsOf: m2Support().appending(path: name)))
    }
}
