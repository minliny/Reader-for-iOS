import CoreGraphics
import Foundation
import Observation
import ReaderCoreBridge
import ReaderHost

struct MangaPageFrame {
    enum Content {
        case image(MangaTileImage, MangaResourceFile)
        case unavailable(any Error)
    }

    let page: M3MangaManifestPage
    let aspectRatio: Double
    let content: Content
}

@MainActor
@Observable
final class MangaReadingCoordinator {
    let runtime: CoreRuntimeActor
    private let assets: MangaPageAssets
    private var generation = 0
    private var busySaving = false
    private var loading = Set<String>()
    private var placeholderRatios: [String: Double] = [:]

    private(set) var chapter: M3MangaChapterWindow?
    private(set) var progress: M3MangaProgressState?
    private(set) var targetOrdinal: Int64?
    private(set) var recoveryRequired = false

    init(runtime: CoreRuntimeActor, host: NetworkAndWebHost) {
        self.runtime = runtime
        assets = MangaPageAssets(runtime: runtime, transfers: host.mangaTransfers)
    }

    func open(sourceId: String, bookId: String, chapterIndex: Int64? = nil) async throws {
        guard !busySaving else { throw CoreBridgeFailure.endpointMismatch }
        generation += 1
        let expected = generation
        chapter = nil
        progress = nil
        targetOrdinal = nil
        recoveryRequired = false
        placeholderRatios.removeAll()
        loading.removeAll()
        await assets.reset()
        try check(expected)
        let request = M3MangaEntryGetParams(sourceId: sourceId, bookId: bookId, chapterIndex: chapterIndex)
        var prepared = try await runtime.request(ReaderM3.mangaEntryGet, request).value.entry
        if prepared == nil {
            try check(expected)
            let read = try await runtime.request(ReaderM3.readingProgressGetManga,
                                                 .init(sourceId: sourceId, bookId: bookId)).value
            var index = chapterIndex ?? 0
            if chapterIndex == nil, let location = read.location {
                let directory = try await runtime.request(ReaderM2.bookToc, .init(sourceId: sourceId, bookId: bookId)).value
                guard let stored = directory.toc.first(where: { $0.url == location.chapter.chapterId }) else {
                    throw CoreBridgeFailure.endpointMismatch
                }
                index = stored.index
            }
            try check(expected)
            _ = try await runtime.request(ReaderM3.mangaChapterGet,
                                          .init(sourceId: sourceId, bookId: bookId, chapterIndex: index)).value
            try check(expected)
            prepared = try await runtime.request(ReaderM3.mangaEntryGet,
                                                 .init(sourceId: sourceId, bookId: bookId, chapterIndex: index)).value.entry
        }
        try check(expected)
        guard let prepared, prepared.chapter.manifest.chapter.sourceId == sourceId,
              prepared.chapter.manifest.chapter.bookId == bookId else {
            throw CoreBridgeFailure.endpointMismatch
        }
        chapter = prepared.chapter
        progress = prepared.progress
        targetOrdinal = prepared.targetOrdinal
        recoveryRequired = prepared.recoveryRequired
    }

    func readWindow(start: Int64, limit: Int64) async throws -> M3MangaChapterWindow {
        guard let chapter, start >= 0, start < chapter.totalPages, limit > 0 else {
            throw CoreBridgeFailure.endpointMismatch
        }
        let expected = generation
        let identity = chapter.manifest.chapter
        let result = try await runtime.request(ReaderM3.mangaPagesWindow, .init(
            sourceId: identity.sourceId, bookId: identity.bookId, chapterId: identity.chapterId,
            manifestVersion: chapter.manifest.manifestVersion, start: start, limit: limit
        )).value
        try check(expected)
        guard result.pageStart == start, result.totalPages == chapter.totalPages,
              result.manifest.manifestVersion == chapter.manifest.manifestVersion else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return result
    }

    func page(_ page: M3MangaManifestPage, in window: M3MangaChapterWindow, width: Int) async throws -> MangaPageFrame {
        guard window.manifest.manifestVersion == chapter?.manifest.manifestVersion,
              window.manifest.pages.contains(where: { $0.pageId == page.pageId && $0.ordinal == page.ordinal
                  && $0.resourceRef == page.resourceRef }),
              loading.insert(page.pageId).inserted else { throw CoreBridgeFailure.endpointMismatch }
        let expected = generation
        defer { if expected == generation { loading.remove(page.pageId) } }
        let placeholder = placeholderRatios[page.pageId] ?? 0.5
        do {
            let result = try await assets.decode(page, manifest: window.manifest, preferredWidth: width)
            try check(expected)
            placeholderRatios[page.pageId] = result.image.aspectRatio
            return MangaPageFrame(page: page, aspectRatio: result.image.aspectRatio, content: .image(result.image, result.file))
        } catch {
            try check(expected)
            if error is CancellationError { throw error }
            return MangaPageFrame(page: page, aspectRatio: placeholder, content: .unavailable(error))
        }
    }

    @discardableResult
    func save(page: M3MangaManifestPage, in window: M3MangaChapterWindow, originalPoint: CGPoint) async throws
    -> M3MangaProgressState {
        guard let progress, !recoveryRequired, !busySaving,
              window.manifest.manifestVersion == chapter?.manifest.manifestVersion,
              window.manifest.pages.contains(where: { $0.pageId == page.pageId && $0.ordinal == page.ordinal
                  && $0.resourceRef == page.resourceRef }),
              (0...1).contains(originalPoint.x), (0...1).contains(originalPoint.y),
              progress.token.revision < Int64.max else { throw CoreBridgeFailure.endpointMismatch }
        busySaving = true
        defer { busySaving = false }
        let expected = generation
        let location = M3MangaLocation(
            chapter: window.manifest.chapter, manifestVersion: window.manifest.manifestVersion, pageId: page.pageId,
            pageOrdinalFallback: page.ordinal, x: originalPoint.x, y: originalPoint.y,
            progressRevision: progress.token.revision + 1
        )
        let saved = try await runtime.request(ReaderM3.readingProgressUpdateManga, .init(
            location: location, expectedEpoch: progress.token.epoch, expectedRevision: progress.token.revision
        )).value
        if expected == generation {
            self.progress = saved
            targetOrdinal = saved.location?.pageOrdinalFallback
        }
        return saved
    }

    /// Prepare the target's first image before creating the original switch
    /// intent. The generated Core method compares both observed tokens when
    /// the caller subsequently confirms the approximate chapter mapping.
    func prepareSourceSwitch(target: M3DirectoryTargetProof, expectedSourceVersion: String,
                             operationId: String, sequence: Int64) async throws
    -> M3MangaSourceSwitchOperationParams {
        guard let currentChapter = chapter, let original = progress, original.location != nil else {
            throw CoreBridgeFailure.endpointMismatch
        }
        let expected = generation
        let targetChapter = try await runtime.request(ReaderM3.mangaChapterGet, .init(
            directoryTargetProof: target, sourceId: target.sourceId, bookId: target.bookId,
            chapterIndex: target.chapterIndex, policy: .cacheFirst
        )).value
        try check(expected)
        let full = targetChapter.manifest
        guard full.chapter.chapterId == target.url, full.sourceRuleVersion == expectedSourceVersion,
              let first = full.pages.first, first.ordinal == 0,
              targetChapter.resources.contains(where: { $0.resourceRef == first.resourceRef }) else {
            throw CoreBridgeFailure.endpointMismatch
        }
        let targetProgress = try await runtime.request(ReaderM3.readingProgressGetManga,
            .init(sourceId: target.sourceId, bookId: target.bookId)).value
        try check(expected)
        let windowManifest = M3MangaWindowManifest(chapter: full.chapter, sourceRuleVersion: full.sourceRuleVersion,
            manifestVersion: full.manifestVersion, decodeRevision: full.decodeRevision, pages: [first])
        let verified = try await assets.decode(first, manifest: windowManifest, preferredWidth: 256)
        try check(expected)
        guard progress?.token.revision == original.token.revision, progress?.token.epoch == original.token.epoch else {
            throw CoreBridgeFailure.endpointMismatch
        }
        return .init(operationId: operationId, sequence: sequence, fromSourceId: currentChapter.manifest.chapter.sourceId,
                     fromBookId: currentChapter.manifest.chapter.bookId, expectedFrom: original.token,
                     expectedTarget: targetProgress.token, firstImage: .init(
                         chapter: full.chapter, chapterIndex: targetChapter.chapterIndex,
                         width: Int64(verified.image.encodedSize.width), height: Int64(verified.image.encodedSize.height),
                         manifestVersion: full.manifestVersion, sourceRuleVersion: full.sourceRuleVersion,
                         decodeRevision: full.decodeRevision, pageId: first.pageId, resourceRef: first.resourceRef,
                         imageRevision: verified.file.sha256
                     ), targetPageOrdinal: 0, acceptApproximate: true)
    }

    func retire() async {
        generation += 1
        loading.removeAll()
        chapter = nil
        progress = nil
        targetOrdinal = nil
        recoveryRequired = false
        await assets.reset()
    }

    private func check(_ expected: Int) throws {
        try Task.checkCancellation()
        guard expected == generation else { throw CancellationError() }
    }
}

extension ShelfModel {
    func mangaReader() throws -> MangaReadingCoordinator {
        guard let library, let host = library.network else { throw CoreBridgeFailure.closed }
        return MangaReadingCoordinator(runtime: library.runtime, host: host)
    }
}
