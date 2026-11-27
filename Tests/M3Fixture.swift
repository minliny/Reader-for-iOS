import Foundation
import ReaderCoreBridge
import XCTest

struct M3Fixture: Decodable {
    struct Manga: Decodable {
        let sourceId: String
        let bookId: String
        let targetOrdinal: Int64
        let normalizedX: Double
        let normalizedY: Double
    }

    struct Speech: Decodable {
        struct Slice: Decodable {
            let text: String
            let startScalar: Int
            let endScalar: Int
        }

        let sourceId: String
        let bookId: String
        let content: String
        let sourceScalars: Int
        let slices: [Slice]
    }

    let manga: Manga
    let speech: Speech

    @MainActor
    static func install(root: String, sourceId: String, bookId: String, manga: Bool,
                        runtime: CoreRuntimeActor) async throws {
        let url = M2BusinessFixture.base + root
        let rules: [String: ReaderM1JSONValue] = [
            "bookSourceUrl": .string(url),
            "bookSourceName": .string(sourceId),
            "bookSourceType": .integer(manga ? 2 : 0),
            "ruleToc": .object(["chapterList": .string("ol li"), "chapterName": .string("a@text"), "chapterUrl": .string("a@href")]),
            "ruleContent": .object(["content": .string(manga ? "tag.img@src" : "tag.div@text")]),
        ]
        _ = try await runtime.request(ReaderM2.sourceImport, .init(sourceId: sourceId, name: sourceId,
                                                                   baseUrl: url, bookSource: rules))
        let toc = try await runtime.request(ReaderM2.bookToc, .init(sourceId: sourceId, bookId: bookId, tocUrl: url + "/toc")).value
        XCTAssertEqual(toc.toc.count, 1)
    }
}
