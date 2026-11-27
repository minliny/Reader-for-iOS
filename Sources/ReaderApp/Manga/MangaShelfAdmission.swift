import Foundation
import ReaderCoreBridge
import ReaderHost

@MainActor
enum MangaShelfAdmission {
    static func add(detail: M2BookDetailData, runtime: CoreRuntimeActor, network: NetworkAndWebHost) async throws {
        let book = detail.book
        let sourceId = detail.sourceId
        let metadata: BookshelfAddParams = .init(sourceId: sourceId, bookId: book.bookId, title: book.title,
            author: book.author, coverUrl: book.coverUrl, intro: book.intro, kind: book.kind, lastChapter: book.lastChapter)
        let encoded = try JSONEncoder().encode(metadata)
        let pending = try JSONDecoder().decode([String: ReaderM1JSONValue].self, from: encoded)
        let intent = try await runtime.request(ReaderM2.readingPreparation, .init(
            action: .begin, sourceId: sourceId, bookId: book.bookId, reason: .add, pendingAdd: pending
        )).value.intents.first
        guard let intent, intent.sourceId == sourceId, intent.bookId == book.bookId else {
            throw CoreBridgeFailure.endpointMismatch
        }
        let online = OnlineReadingCoordinator(runtime: runtime)
        let directory = try await online.refreshDirectory(.init(preparationRevision: intent.revision,
            sourceId: sourceId, bookId: book.bookId, tocUrl: detail.tocUrl, variables: detail.variables))
        guard let firstChapter = directory.chapters.first else { throw CoreBridgeFailure.endpointMismatch }
        let chapter = try await runtime.request(ReaderM3.mangaChapterGet, .init(
            sourceId: sourceId, bookId: book.bookId, chapterIndex: firstChapter.index,
            policy: .cacheFirst, preparationRevision: intent.revision
        )).value
        let manifest = chapter.manifest
        guard manifest.chapter.sourceId == sourceId, manifest.chapter.bookId == book.bookId,
              manifest.sourceRuleVersion == intent.sourceVersion,
              let page = manifest.pages.first, page.ordinal == 0 else { throw CoreBridgeFailure.endpointMismatch }
        let assets = MangaPageAssets(runtime: runtime, transfers: network.mangaTransfers, retained: network.mangaCompressedCache)
        do {
            let image = try await assets.decode(page, manifest: .init(chapter: manifest.chapter,
                sourceRuleVersion: manifest.sourceRuleVersion, manifestVersion: manifest.manifestVersion,
                decodeRevision: manifest.decodeRevision, pages: [page]), preferredWidth: 384)
            let receipt = MangaFirstImageReceipt(chapter: .init(sourceId: sourceId, bookId: book.bookId,
                chapterId: manifest.chapter.chapterId), chapterIndex: chapter.chapterIndex,
                width: Int64(image.image.encodedSize.width), height: Int64(image.image.encodedSize.height),
                manifestVersion: manifest.manifestVersion, sourceRuleVersion: manifest.sourceRuleVersion,
                decodeRevision: manifest.decodeRevision, pageId: page.pageId, resourceRef: page.resourceRef,
                imageRevision: image.file.sha256)
            _ = try await runtime.request(ReaderM1.bookshelfAdd, .init(sourceId: sourceId, bookId: book.bookId,
                title: book.title, author: book.author, coverUrl: book.coverUrl, intro: book.intro, kind: book.kind,
                lastChapter: book.lastChapter, mangaFirstImage: receipt, preparationRevision: intent.revision,
                requireReadable: true))
        } catch {
            await assets.reset()
            throw error
        }
        await assets.reset()
    }
}
