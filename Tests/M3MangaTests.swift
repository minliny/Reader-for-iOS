import CoreGraphics
import Foundation
import ReaderCoreBridge
import ReaderHost
import XCTest
@testable import ReaderApp

@MainActor
final class M3MangaTests: XCTestCase {
    private struct Checkpoint: Codable {
        let rootName: String
        let pid: Int32
        let originalPage: String
        let manifest: String
        let revision: Int64
        let epoch: Int64
    }

    func test01LoopbackTransferRetryTilesBudgetAndSave() async throws {
        let input = try (decodeFixture("manga-and-speech") as M3Fixture).manga
        let root = try isolatedRoot()
        let caches = root.appending(path: "host/manga", directoryHint: .isDirectory)
        let stale = caches.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: stale, withIntermediateDirectories: true)
        let sentinel = caches.appending(path: "keep.txt")
        try Data("not a transfer directory".utf8).write(to: sentinel)
        let library = try await LibraryHost.open(directory: root)
        let network = try XCTUnwrap(library.network)
        XCTAssertTrue(network.capabilities.contains(.mangaResourceTransfer))
        assertLibrary47(library, fresh: true)
        let runtime = library.runtime
        try await M3Fixture.install(root: "/m3/manga", sourceId: input.sourceId, bookId: input.bookId,
                                    manga: true, runtime: runtime)
        let coordinator = MangaReadingCoordinator(runtime: runtime, host: network)
        try await coordinator.open(sourceId: input.sourceId, bookId: input.bookId)
        XCTAssertNil(coordinator.progress?.location)
        let current = try XCTUnwrap(coordinator.chapter)
        XCTAssertEqual(current.totalPages, 3)
        let window = try await coordinator.readWindow(start: input.targetOrdinal, limit: 1)
        let page = try XCTUnwrap(window.manifest.pages.first)
        XCTAssertEqual(window.pageStart, 1)
        XCTAssertEqual(window.manifest.pages.map(\.ordinal), [1])
        XCTAssertEqual(current.manifest.pages.first { $0.ordinal == page.ordinal }?.pageId, page.pageId)
        let longPath = "/m3/manga/long.png"
        try await M2BusinessFixture.configure(longPath, "offline")
        let unavailable = try await coordinator.page(page, in: window, width: 384)
        try await M2BusinessFixture.release(longPath)
        guard case .unavailable(let failure) = unavailable.content,
              let hostError = failure as? CoreRequestFailure else {
            XCTFail("Offline page did not keep a retryable placeholder")
            await library.runtime.close()
            return
        }
        XCTAssertEqual(hostError.m2Value.details?.host?.capability, .mangaResourceTransfer)
        XCTAssertEqual(unavailable.page.pageId, page.pageId)
        XCTAssertEqual(unavailable.aspectRatio, 0.5)

        let retried = try await coordinator.page(page, in: window, width: 384)
        guard case .image(let image, let file) = retried.content else { return XCTFail("Same-page retry failed: \(retried.content)") }
        XCTAssertEqual(retried.page.pageId, unavailable.page.pageId)
        XCTAssertEqual(image.encodedSize, CGSize(width: 96, height: 22_000))
        XCTAssertLessThan(image.pixelSize.height, image.encodedSize.height)
        XCTAssertGreaterThan(image.tiles.count, 2)
        XCTAssertEqual(image.tiles.first?.normalizedStart, 0)
        XCTAssertEqual(image.tiles.last?.normalizedEnd, 1)
        XCTAssertTrue(zip(image.tiles, image.tiles.dropFirst()).allSatisfy { $0.0.normalizedEnd == $0.1.normalizedStart })
        XCTAssertTrue(image.tiles.allSatisfy { $0.displayPixels.height <= 1024 })
        XCTAssertGreaterThan(file.bytes, CoreMangaAssets.chunkLimit)
        XCTAssertEqual(file.chunks, (file.bytes + CoreMangaAssets.chunkLimit - 1) / CoreMangaAssets.chunkLimit)
        XCTAssertEqual(try hash(file.url), file.sha256)
        try assertTilesDraw(image)
        XCTAssertFalse(FileManager.default.fileExists(atPath: stale.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: sentinel.path))
        let concurrentHost = try NetworkAndWebHost(directory: root.appending(path: "host", directoryHint: .isDirectory))
        let otherTransfer = UUID().uuidString
        try await concurrentHost.mangaTransfers.register(otherTransfer)
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.url.path), "A live owner must survive scratch admission")
        await concurrentHost.mangaTransfers.discard(otherTransfer)

        let tooLarge = try await coordinator.readWindow(start: 2, limit: 1)
        let tooLargePage = try XCTUnwrap(tooLarge.manifest.pages.first)
        let rejected = try await coordinator.page(tooLargePage, in: tooLarge, width: 384)
        guard case .unavailable(let error as MangaImageFailure) = rejected.content, case .pixelBudget = error else {
            return XCTFail("24M-pixel source must fail before decode: \(rejected.content)")
        }
        XCTAssertEqual(rejected.page.ordinal, 2)
        XCTAssertEqual(rejected.aspectRatio, 0.5)

        let point = image.originalPoint(forDisplay: CGPoint(x: input.normalizedX, y: input.normalizedY))
        let saved = try await coordinator.save(page: page, in: window, originalPoint: point)
        let location = try XCTUnwrap(saved.location)
        XCTAssertEqual(location.x, input.normalizedX)
        XCTAssertEqual(location.y, input.normalizedY)
        XCTAssertEqual(location.pageId, page.pageId)
        XCTAssertEqual(saved.token.revision, 1)
        let pid = ProcessInfo.processInfo.processIdentifier
        let checkpoint = Checkpoint(rootName: root.lastPathComponent, pid: pid, originalPage: page.pageId,
                                    manifest: window.manifest.manifestVersion,
                                    revision: saved.token.revision, epoch: saved.token.epoch)
        try JSONEncoder().encode(checkpoint).write(to: checkpointPath(), options: .atomic)
        print("M3_MANGA_WRITE pid=\(pid) window=[1,2) pageId=\(page.pageId) original=96x22000 downsample=\(image.pixelSize) tiles=\(image.tiles.count) bytes=\(file.bytes) chunks=\(file.chunks) sha256=\(file.sha256) retry=PASS draw=PASS sourcePixelBudget=PASS scratchReclaim=PASS x=\(location.x) y=\(location.y)")
        let prefetch = try await coordinator.prefetch(0..<1)
        XCTAssertEqual(prefetch.queuedIndexes, [0])
        XCTAssertEqual(prefetch.materializations.count, 1)
        let status = try await coordinator.downloadStatus()
        XCTAssertEqual(status.chapters.first?.chapterIndex, 0)
        print("M3_MANGA_DOWNLOAD prefetchQueue=\(prefetch.queuedIndexes) materializationGrant=\(prefetch.materializations.count) typedStatus=PASS")
        await coordinator.retire()
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.url.path))
        await runtime.close()
    }

    func test02IndependentProcessRestoresLogicalPageAndPoint() async throws {
        let checkpoint = try JSONDecoder().decode(Checkpoint.self, from: Data(contentsOf: checkpointPath()))
        let input = try (decodeFixture("manga-and-speech") as M3Fixture).manga
        let pid = ProcessInfo.processInfo.processIdentifier
        XCTAssertNotEqual(pid, checkpoint.pid)
        let before = try await M2BusinessFixture.state()
        _ = try XCTUnwrap(UUID(uuidString: checkpoint.rootName))
        let root = try testSupportDirectory.appending(path: checkpoint.rootName, directoryHint: .isDirectory)
        let library = try await LibraryHost.open(directory: root)
        assertLibrary47(library, fresh: false)
        let network = try XCTUnwrap(library.network)
        let coordinator = MangaReadingCoordinator(runtime: library.runtime, host: network)
        try await coordinator.open(sourceId: input.sourceId, bookId: input.bookId)
        let progress = try XCTUnwrap(coordinator.progress)
        let located = try XCTUnwrap(progress.location)
        XCTAssertFalse(coordinator.recoveryRequired)
        XCTAssertEqual(coordinator.targetOrdinal, input.targetOrdinal)
        XCTAssertEqual(located.pageId, checkpoint.originalPage)
        XCTAssertEqual(located.manifestVersion, checkpoint.manifest)
        XCTAssertEqual(located.x, input.normalizedX)
        XCTAssertEqual(located.y, input.normalizedY)
        XCTAssertEqual(progress.token.revision, checkpoint.revision)
        // Opening the durable store advances Core's write fence exactly once.
        // The durable location and progress revision survive that fence change.
        XCTAssertEqual(progress.token.epoch, checkpoint.epoch + 1)
        let staleLocation = M3MangaLocation(chapter: located.chapter, manifestVersion: located.manifestVersion,
            pageId: located.pageId, pageOrdinalFallback: located.pageOrdinalFallback, x: located.x, y: located.y,
            progressRevision: progress.token.revision + 1)
        do {
            _ = try await library.runtime.request(ReaderM3.readingProgressUpdateManga, .init(
                location: staleLocation, expectedEpoch: checkpoint.epoch, expectedRevision: checkpoint.revision
            ))
            XCTFail("The preceding process's epoch must not authorize a write")
        } catch let failure as CoreRequestFailure {
            XCTAssertEqual(failure.value.code, .internal)
        }
        let unchanged = try await library.runtime.request(ReaderM3.readingProgressGetManga,
            .init(sourceId: input.sourceId, bookId: input.bookId)).value
        XCTAssertEqual(unchanged.token.revision, checkpoint.revision)
        XCTAssertEqual(unchanged.location?.pageId, checkpoint.originalPage)
        let after = try await M2BusinessFixture.state()
        for path in ["/m3/manga/toc", "/m3/manga/chapter", "/m3/manga/long.png"] {
            XCTAssertEqual(before.count(path), after.count(path), "Prepared entry must not re-fetch \(path)")
        }
        print("M3_MANGA_COLD originalPID=\(checkpoint.pid) pid=\(pid) pageId=\(located.pageId) x=\(located.x) y=\(located.y) revision=\(progress.token.revision) epoch=\(checkpoint.epoch)->\(progress.token.epoch) staleWrite=REJECTED refetch=0")
        await library.runtime.close()
    }

    private func checkpointPath() throws -> URL {
        try testSupportDirectory.appendingPathComponent("M3-manga-cold.json")
    }

    private func assertTilesDraw(_ image: MangaTileImage) throws {
        let width = 8
        let height = 64
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                                              bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        image.draw(in: context, target: frame, clip: frame)
        let bytes = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        let samples: [[UInt8]] = [8, 55].map { y in
            let index = (width * y + width / 2) * 4
            return Array(UnsafeBufferPointer(start: bytes.advanced(by: index), count: 3))
        }
        XCTAssertTrue(samples.contains([32, 76, 158]))
        XCTAssertTrue(samples.contains([176, 39, 82]))
    }
}
