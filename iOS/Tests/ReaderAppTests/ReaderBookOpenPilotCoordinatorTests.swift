import XCTest
import ReaderAppSupport
import ReaderCoreFoundation
import ReaderCoreModels
import ReaderCoreNativeAdapter
import ReaderUIRuntime
@testable import ReaderApp
@testable import ReaderShellValidation

@MainActor
final class ReaderBookOpenPilotCoordinatorTests: XCTestCase {
    func testLiveConfigurationIsPilotAndStartsPilotEffects() async {
        let displayed = displayed(correlationID: "live-pilot", generation: 1)
        let executor = FakeBookOpenExecutor(outcomes: [
            .completed(coreType: "source.detail", chapterCount: nil, displayedContent: nil),
            .completed(coreType: "chapter.list", chapterCount: 1, displayedContent: nil),
            .completed(coreType: "content.load", chapterCount: nil, displayedContent: displayed),
        ], rendered: [rendered(displayed)])
        let coordinator = ReaderBookOpenPilotCoordinator(executor: executor)

        XCTAssertEqual(coordinator.configuration.mode, .pilot)
        let started = await coordinator.begin(launch(correlationID: "live-pilot"))

        XCTAssertTrue(started)
        XCTAssertEqual(executor.begun, ["live-pilot"])
        XCTAssertEqual(executor.executedTypes, ["source.detail", "chapter.list", "content.load"])
        XCTAssertEqual(coordinator.displayedContent, displayed)
    }

    func testPilotExecutesOrderedStagesAndWaitsForDisplayedGeometry() async {
        let displayed = displayed(correlationID: "open-1", generation: 1)
        let executor = FakeBookOpenExecutor(outcomes: [
            .completed(coreType: "source.detail", chapterCount: nil, displayedContent: nil),
            .completed(coreType: "chapter.list", chapterCount: 3, displayedContent: nil),
            .completed(coreType: "content.load", chapterCount: nil, displayedContent: displayed),
            .completed(coreType: "reader.location.resolve", chapterCount: nil, displayedContent: nil),
        ], rendered: [rendered(displayed)])
        let coordinator = ReaderBookOpenPilotCoordinator(
            configuration: ReaderBookOpenPilotConfiguration(mode: .pilot),
            executor: executor
        )

        let started = await coordinator.begin(launch(correlationID: "open-1"))
        XCTAssertTrue(started)
        XCTAssertEqual(executor.executedTypes, ["source.detail", "chapter.list", "content.load"])
        XCTAssertEqual(coordinator.displayedContent, displayed)

        await coordinator.provideMeasuredLayout(
            ReaderBookOpenMeasuredLayout(
                chapterOffset: 24,
                chapterProgress: 0.25,
                viewportWidth: 390,
                viewportHeight: 844,
                fontScale: 1
            ),
            displayed: displayed
        )

        XCTAssertEqual(executor.acceptedLayouts.map(\.0), [displayed])
        XCTAssertEqual(executor.executedTypes, [
            "source.detail", "chapter.list", "content.load", "reader.location.resolve",
        ])
        XCTAssertEqual(executor.finished, ["open-1"])
    }

    func testReplacementRejectsOldDisplayedLayoutByCorrelationAndGeneration() async {
        let old = displayed(correlationID: "open-old", generation: 1)
        let new = displayed(correlationID: "open-new", generation: 1)
        let executor = FakeBookOpenExecutor(outcomes: [
            .completed(coreType: "source.detail", chapterCount: nil, displayedContent: nil),
            .completed(coreType: "chapter.list", chapterCount: 2, displayedContent: nil),
            .completed(coreType: "content.load", chapterCount: nil, displayedContent: old),
            .completed(coreType: "source.detail", chapterCount: nil, displayedContent: nil),
            .completed(coreType: "chapter.list", chapterCount: 2, displayedContent: nil),
            .completed(coreType: "content.load", chapterCount: nil, displayedContent: new),
            .completed(coreType: "reader.location.resolve", chapterCount: nil, displayedContent: nil),
        ], rendered: [rendered(old), rendered(new)])
        let coordinator = ReaderBookOpenPilotCoordinator(
            configuration: ReaderBookOpenPilotConfiguration(mode: .pilot),
            executor: executor
        )

        let oldStarted = await coordinator.begin(launch(correlationID: old.correlationID))
        XCTAssertTrue(oldStarted)
        XCTAssertEqual(coordinator.displayedContent, old)
        let newStarted = await coordinator.begin(launch(correlationID: new.correlationID))
        XCTAssertTrue(newStarted)
        XCTAssertEqual(executor.cancelled, [old.correlationID])
        XCTAssertEqual(coordinator.displayedContent, new)

        await coordinator.provideMeasuredLayout(layout(), displayed: old)
        XCTAssertTrue(executor.acceptedLayouts.isEmpty, "old correlation must be discarded before Core location resolve")
        XCTAssertFalse(executor.executedTypes.contains("reader.location.resolve"))

        await coordinator.provideMeasuredLayout(layout(), displayed: new)
        XCTAssertEqual(executor.acceptedLayouts.map(\.0), [new])
        XCTAssertEqual(executor.executedTypes.last, "reader.location.resolve")

        let wrongGeneration = ReaderBookOpenDisplayedContent(
            correlationID: new.correlationID,
            contentGeneration: 2,
            bookID: new.bookID,
            chapterIndex: new.chapterIndex,
            chapterURL: new.chapterURL
        )
        await coordinator.provideMeasuredLayout(layout(), displayed: wrongGeneration)
        XCTAssertEqual(executor.acceptedLayouts.map(\.0), [new], "same correlation with stale generation is also rejected")
    }

    func testZeroGeometryIsRejectedInsteadOfClampedIntoCoreLayout() async {
        let displayed = displayed(correlationID: "zero-layout", generation: 1)
        let executor = FakeBookOpenExecutor(outcomes: [
            .completed(coreType: "source.detail", chapterCount: nil, displayedContent: nil),
            .completed(coreType: "chapter.list", chapterCount: 1, displayedContent: nil),
            .completed(coreType: "content.load", chapterCount: nil, displayedContent: displayed),
        ], rendered: [rendered(displayed)])
        let coordinator = ReaderBookOpenPilotCoordinator(
            configuration: ReaderBookOpenPilotConfiguration(mode: .pilot),
            executor: executor
        )

        let started = await coordinator.begin(launch(correlationID: displayed.correlationID))
        XCTAssertTrue(started)
        await coordinator.provideMeasuredLayout(
            ReaderBookOpenMeasuredLayout(
                chapterOffset: 0,
                chapterProgress: 0,
                viewportWidth: 0,
                viewportHeight: 844,
                fontScale: 1
            ),
            displayed: displayed
        )

        XCTAssertTrue(executor.acceptedLayouts.isEmpty)
        XCTAssertFalse(executor.executedTypes.contains("reader.location.resolve"))
    }

    func testTerminalLocationFailureCancelsInsteadOfFinishing() async {
        let displayed = displayed(correlationID: "location-drift", generation: 1)
        let executor = FakeBookOpenExecutor(outcomes: [
            .completed(coreType: "source.detail", chapterCount: nil, displayedContent: nil),
            .completed(coreType: "chapter.list", chapterCount: 1, displayedContent: nil),
            .completed(coreType: "content.load", chapterCount: nil, displayedContent: displayed),
            .failed(
                coreType: "reader.location.resolve",
                message: "BOOK_OPEN_LOCATION_IDENTITY_MISMATCH: expected bookId book-1, got other-book"
            ),
        ], rendered: [rendered(displayed)])
        let coordinator = ReaderBookOpenPilotCoordinator(
            configuration: ReaderBookOpenPilotConfiguration(mode: .pilot),
            executor: executor
        )

        let started = await coordinator.begin(launch(correlationID: displayed.correlationID))
        XCTAssertTrue(started)
        await coordinator.provideMeasuredLayout(layout(), displayed: displayed)

        XCTAssertEqual(executor.executedTypes.last, "reader.location.resolve")
        XCTAssertEqual(executor.cancelled, [displayed.correlationID])
        XCTAssertTrue(executor.finished.isEmpty, "a rejected canonical identity must not close as success")
        XCTAssertEqual(
            coordinator.lastFailure,
            "BOOK_OPEN_LOCATION_IDENTITY_MISMATCH: expected bookId book-1, got other-book"
        )
    }

    func testPilotEntryResolverBuildsRealPresentationAndReaderSkipsLegacyLoader() async {
        let contextID = UUID()
        let displayed = displayed(correlationID: contextID.uuidString, generation: 1)
        let executor = FakeBookOpenExecutor(outcomes: [
            .completed(coreType: "source.detail", chapterCount: nil, displayedContent: nil),
            .completed(coreType: "chapter.list", chapterCount: 1, displayedContent: nil),
            .completed(coreType: "content.load", chapterCount: nil, displayedContent: displayed),
        ], rendered: [rendered(displayed)])
        let coordinator = ReaderBookOpenPilotCoordinator(
            configuration: ReaderBookOpenPilotConfiguration(mode: .pilot),
            executor: executor,
            launchResolver: { entry in
                ReaderBookOpenLaunch(
                    correlationID: entry.correlationID,
                    sourceKind: .remote,
                    sourceID: "core-source-1",
                    bookID: "core-book-1",
                    bookURL: entry.bookURL,
                    title: entry.title,
                    requestedChapterIndex: entry.chapterIndex,
                    chapterURL: entry.chapterURL
                )
            }
        )
        let item = BookshelfItem(
            id: "native-row-id",
            sourceID: "persisted-source-id",
            bookURL: "https://example.test/book/1",
            title: "Core result must render",
            lastReadChapterTitle: "第二章",
            lastReadChapterURL: displayed.chapterURL,
            lastReadChapterIndex: displayed.chapterIndex
        )
        let context = ReaderContext(
            id: contextID,
            bookID: item.id,
            chapterURL: displayed.chapterURL,
            chapterTitle: "第二章",
            chapterIndex: displayed.chapterIndex,
            sourceID: item.sourceID,
            source: .coverToImmersive
        )

        XCTAssertTrue(BookshelfBookOpenPilotEntryRouter(coordinator: coordinator).begin(item: item, context: context))
        await eventually {
            coordinator.presentation?.content?.content == "executor body"
        }
        XCTAssertEqual(coordinator.presentation?.content?.content, "executor body")
        XCTAssertEqual(coordinator.presentation?.toc.map(\.chapterTitle), ["第二章"])
        XCTAssertFalse(ReaderView.shouldStartLegacyContentLoader(pilotManaged: true))
        XCTAssertTrue(ReaderView.shouldStartLegacyContentLoader(pilotManaged: false))
    }

    func testPilotAdmissionResolverReceivesNativeBookshelfIdentityWithoutFabricatingSourceDTO() async {
        let contextID = UUID()
        var received: ReaderBookOpenEntry?
        let executor = FakeBookOpenExecutor()
        let coordinator = ReaderBookOpenPilotCoordinator(
            configuration: ReaderBookOpenPilotConfiguration(mode: .pilot),
            executor: executor,
            launchResolver: { entry in
                received = entry
                return nil // No Core-projected identity proof: native fallback.
            }
        )
        let item = BookshelfItem(
            id: "native-row-id",
            sourceID: "persisted-source-id",
            bookURL: "https://example.test/book/1",
            title: "Core result must render",
            lastReadChapterURL: "https://example.test/chapter/2",
            lastReadChapterIndex: 1
        )
        let context = ReaderContext(
            id: contextID,
            bookID: item.id,
            chapterURL: "https://example.test/chapter/2",
            chapterTitle: "第二章",
            chapterIndex: 1,
            sourceID: item.sourceID,
            source: .coverToImmersive
        )

        XCTAssertFalse(BookshelfBookOpenPilotEntryRouter(coordinator: coordinator).begin(item: item, context: context))
        XCTAssertEqual(received?.nativeBookID, "native-row-id")
        XCTAssertEqual(received?.sourceID, "persisted-source-id")
        XCTAssertEqual(received?.correlationID, contextID.uuidString)
        XCTAssertTrue(executor.begun.isEmpty)
    }

    func testExecutorFinishDropsContextAndAllowsCorrelationReuse() throws {
        let runtime = try ReaderCoreNativeRuntime()
        defer { runtime.destroy() }
        let executor = ReaderBookOpenEffectExecutor(runtime: runtime)
        let launch = ReaderBookOpenLaunch(
            correlationID: "reusable",
            sourceKind: .local,
            sourceID: "local",
            bookID: "materialized-local-book",
            bookURL: "local://materialized-local-book"
        )

        XCTAssertTrue(executor.begin(launch))
        XCTAssertEqual(executor.activeContextCount, 1)
        executor.finish(correlationID: "reusable")
        XCTAssertEqual(executor.activeContextCount, 0)
        XCTAssertTrue(executor.begin(launch))
    }

    func testExecutorRejectsResolvedLocationForAnotherBookOrChapter() {
        let content = coreContent(bookID: "book-1", chapterIndex: 1)

        XCTAssertNoThrow(
            try ReaderBookOpenEffectExecutor.validateResolvedLocation(
                resolvedLocation(bookID: "book-1", chapterIndex: 1),
                matches: content
            )
        )
        XCTAssertThrowsError(
            try ReaderBookOpenEffectExecutor.validateResolvedLocation(
                resolvedLocation(bookID: "other-book", chapterIndex: 1),
                matches: content
            )
        )
        XCTAssertThrowsError(
            try ReaderBookOpenEffectExecutor.validateResolvedLocation(
                resolvedLocation(bookID: "book-1", chapterIndex: 99),
                matches: content
            )
        )
    }

    func testBookOpenLocationResultProjectsCanonicalLocationAndPageIndex() throws {
        let result = try ReaderUIJSONBridge.projectTypedResult(
            event: "book.open",
            effectType: "reader.location.resolve",
            rawResult: [
                "canonicalLocation": .string("chapter:1:offset:24"),
                "pageIndex": .number(4),
                "legacyLocation": .string("strip-me"),
            ]
        )

        XCTAssertEqual(result, [
            "canonicalLocation": .string("chapter:1:offset:24"),
            "pageIndex": .number(4),
        ])
        XCTAssertThrowsError(try ReaderUIJSONBridge.projectTypedResult(
            event: "book.open",
            effectType: "reader.location.resolve",
            rawResult: ["canonicalLocation": .string("chapter:1:offset:24")]
        ))
    }

    private func launch(correlationID: String) -> ReaderBookOpenLaunch {
        ReaderBookOpenLaunch(
            correlationID: correlationID,
            sourceKind: .remote,
            sourceID: "source-1",
            bookID: "book-1",
            requestedChapterIndex: 1,
            chapterURL: "https://example.test/chapter/2"
        )
    }

    private func displayed(correlationID: String, generation: Int) -> ReaderBookOpenDisplayedContent {
        ReaderBookOpenDisplayedContent(
            correlationID: correlationID,
            contentGeneration: generation,
            bookID: "book-1",
            chapterIndex: 1,
            chapterURL: "https://example.test/chapter/2"
        )
    }

    private func layout() -> ReaderBookOpenMeasuredLayout {
        ReaderBookOpenMeasuredLayout(
            chapterOffset: 12,
            chapterProgress: 0.1,
            viewportWidth: 390,
            viewportHeight: 844,
            fontScale: 1
        )
    }

    private func rendered(_ displayed: ReaderBookOpenDisplayedContent) -> ReaderBookOpenRenderedContent {
        ReaderBookOpenRenderedContent(
            displayed: displayed,
            sourceID: "core-source-1",
            toc: [TOCItem(
                chapterTitle: "第二章",
                chapterURL: displayed.chapterURL,
                chapterIndex: displayed.chapterIndex
            )],
            content: ContentPage(
                title: "第二章",
                content: "executor body",
                chapterURL: displayed.chapterURL,
                nextChapterURL: nil
            )
        )
    }

    private func coreContent(bookID: String, chapterIndex: Int) -> CoreChapterContentStageResult {
        CoreChapterContentStageResult(
            page: ContentPage(
                title: "第二章",
                content: "executor body",
                chapterURL: "https://example.test/chapter/2",
                nextChapterURL: nil
            ),
            rawContent: .string("executor body"),
            sourceID: "core-source-1",
            bookID: bookID,
            chapterTitle: "第二章",
            chapterIndex: chapterIndex,
            chapterURL: "https://example.test/chapter/2",
            variables: [:]
        )
    }

    private func resolvedLocation(bookID: String, chapterIndex: Int) -> CoreReaderLocationStageResult {
        CoreReaderLocationStageResult(
            bookID: bookID,
            chapterIndex: chapterIndex,
            chapterOffset: 24,
            chapterProgress: 0.25,
            locationRevision: "reader-location-v1",
            resolverVersion: "reader.location.resolve.v1.reflow",
            primaryAnchor: "chapterOffset",
            fallbackAnchor: "chapterProgress",
            layoutIndependent: true
        )
    }

    private func eventually(
        timeout: TimeInterval = 1,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline, !condition() {
            await Task.yield()
        }
    }
}

@MainActor
private final class FakeBookOpenExecutor: ReaderBookOpenEffectExecuting {
    var begun: [String] = []
    var executedTypes: [String] = []
    var acceptedLayouts: [(ReaderBookOpenDisplayedContent, ReaderBookOpenMeasuredLayout)] = []
    var cancelled: [String] = []
    var finished: [String] = []
    private var outcomes: [ReaderBookOpenEffectOutcome]
    private let rendered: [ReaderBookOpenRenderedContent]

    init(
        outcomes: [ReaderBookOpenEffectOutcome] = [],
        rendered: [ReaderBookOpenRenderedContent] = []
    ) {
        self.outcomes = outcomes
        self.rendered = rendered
    }

    func begin(_ launch: ReaderBookOpenLaunch) -> Bool {
        begun.append(launch.correlationID)
        return true
    }

    func execute(_ effect: ReaderUIEffect) async -> ReaderBookOpenEffectOutcome {
        executedTypes.append(effect.type)
        guard !outcomes.isEmpty else {
            return .failed(coreType: effect.type, message: "missing fake outcome")
        }
        return outcomes.removeFirst()
    }

    func acceptMeasuredLayout(
        _ layout: ReaderBookOpenMeasuredLayout,
        displayed: ReaderBookOpenDisplayedContent
    ) -> Bool {
        acceptedLayouts.append((displayed, layout))
        return true
    }

    func renderedContent(for displayed: ReaderBookOpenDisplayedContent) -> ReaderBookOpenRenderedContent? {
        rendered.first(where: { $0.displayed == displayed })
    }

    func finish(correlationID: String) {
        finished.append(correlationID)
    }

    func cancel(correlationID: String) {
        cancelled.append(correlationID)
    }
}
