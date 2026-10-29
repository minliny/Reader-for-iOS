import Combine
import Foundation
import XCTest
import UIKit
import SwiftUI
@testable import Reader

/// Controlled protocol continuations test only the Host's discovery lifetime.
/// These DTO identities are not a book/source fixture or real network evidence.
@MainActor
final class ReaderOnlineDiscoveryLifecycleTests: XCTestCase {
    func testRetireDiscoveryCancelsOnlyReadsAndPreservesCandidateSnapshot() async throws {
        let service = DiscoveryControlledService()
        var state: ReaderOnlineWorkspaceModel? = ReaderOnlineWorkspaceModel()
        weak var weakState = state
        defer { state?.retireCachedDiscovery(); service.releaseAll() }
        state?.service = service; state?.query = "discovery identity"; state?.sourceFilter = "retained filter"
        let identity = UUID()
        state?.activateDiscoveryPresentation(identity)

        let listed = expectation(description: "Original source-list read entered")
        let firstFour = expectation(description: "Initial four exact search reads entered")
        firstFour.expectedFulfillmentCount = 4
        let fifth = expectation(description: "First result reduced before dispatching the fifth source")
        service.onSourcesEntered = { _ in listed.fulfill() }
        service.onSearchEntered = { count in
            if count <= 4 { firstFour.fulfill() }
            if count == 5 { fifth.fulfill() }
        }
        let listTask = Task { @MainActor [weak model = state] in
            await model?.refreshDiscoverySources(presentationID: identity)
        }
        defer { listTask.cancel() }
        await fulfillment(of: [listed], timeout: 2)
        try service.completeSources(0, with: .success(DiscoveryControlledService.sources(6)))
        await listTask.value
        await fulfillment(of: [firstFour], timeout: 2)
        try service.completeSearch(0)
        await fulfillment(of: [fifth], timeout: 2)
        state?.scrollAnchor = try XCTUnwrap(state?.results.first?.id)
        let snapshot = DiscoverySnapshot(try XCTUnwrap(state))
        XCTAssertEqual(snapshot.results.count, 1)
        XCTAssertEqual(snapshot.timings.count, 1)

        // Reattach an immutable accepted identity without executing a write.
        let originalActions = try XCTUnwrap(state?.actions)
        let originalID = "a33b3ba3-0bbf-4f8e-a1a2-fc042dbfe691"
        let originalScope = "discovery-contract|accepted-write"
        var writeExecutions = 0
        XCTAssertTrue(originalActions.restoreAccepted(id: originalID, label: "原操作", scope: originalScope) { id in
            writeExecutions += 1
            XCTAssertEqual(id, originalID)
            XCTFail("Discovery retirement must never execute the accepted write")
            throw DiscoveryControlledService.Failure.unsupported
        })

        var retainedValuePublications = 0
        let observations = [
            try XCTUnwrap(state).$results.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$timings.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$sources.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$query.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$scrollAnchor.dropFirst().sink { _ in retainedValuePublications += 1 },
            try XCTUnwrap(state).$currentResultIDs.dropFirst().sink { _ in retainedValuePublications += 1 }
        ]
        defer { observations.forEach { $0.cancel() } }
        let cancelled = expectation(description: "Every remaining original search read observed cancellation")
        cancelled.expectedFulfillmentCount = 4
        service.onSearchCancelled = { _ in cancelled.fulfill() }
        state?.retireDiscoveryPresentation(identity)
        await fulfillment(of: [cancelled], timeout: 2)
        XCTAssertEqual(service.cancelledSearches, Set(1...4))
        XCTAssertFalse(try XCTUnwrap(state).searching)
        XCTAssertFalse(try XCTUnwrap(state).sourceLoading)
        XCTAssertTrue(try XCTUnwrap(state).stopped)
        XCTAssertEqual(DiscoverySnapshot(try XCTUnwrap(state)), snapshot)

        // Return successful late responses despite cancellation. The actual
        // model must drain them without publishing or dispatching source six.
        state = nil
        try service.completeRemainingSearches()
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in weakState == nil }, object: nil)
        await fulfillment(of: [released], timeout: 2)
        XCTAssertNil(weakState, "Completed retired discovery must release its strong Task capture")
        XCTAssertEqual(service.searchCalls.count, 5)
        XCTAssertEqual(retainedValuePublications, 0)
        XCTAssertEqual(originalActions.pendingOperationID, originalID)
        XCTAssertEqual(originalActions.scope, originalScope)
        XCTAssertTrue(originalActions.hasPending)
        XCTAssertFalse(originalActions.busy)
        XCTAssertEqual(writeExecutions, 0)
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testLateSourceListAfterRetirementCannotStartDiscoveryOrPublishFailure() async throws {
        for succeeds in [true, false] {
            let service = DiscoveryControlledService()
            let state = ReaderOnlineWorkspaceModel()
            defer { state.retireCachedDiscovery(); service.releaseAll() }
            state.service = service; state.query = "retained query"
            state.sources = DiscoveryControlledService.sources(1)
            state.results = [ReaderOnlineCandidate(sourceId: "retained", bookId: "candidate", title: "Retained identity")]
            state.timings = ["retained": 17]; state.scrollAnchor = state.results[0].id
            state.sourceReadFailure = "retained source observation"
            let snapshot = DiscoverySnapshot(state)
            let identity = UUID(); state.activateDiscoveryPresentation(identity)
            let entered = expectation(description: "Source read entered before retirement")
            let cancelled = expectation(description: "Original source read received cancellation")
            service.onSourcesEntered = { _ in entered.fulfill() }
            service.onSourcesCancelled = { _ in cancelled.fulfill() }
            let task = Task { await state.refreshDiscoverySources(presentationID: identity) }
            defer { task.cancel() }
            await fulfillment(of: [entered], timeout: 2)
            state.retireDiscoveryPresentation(identity)
            await fulfillment(of: [cancelled], timeout: 2)
            let late: Result<[ReaderOnlineSource], Error> = succeeds
                ? .success(DiscoveryControlledService.sources(2)) : .failure(DiscoveryControlledService.Failure.lateRead)
            try service.completeSources(0, with: late)
            await task.value
            // This is also the stale retry entry: it must not issue a read.
            await state.refreshDiscoverySources(presentationID: identity)
            XCTAssertEqual(service.sourceReadCount, 1)
            XCTAssertTrue(service.searchCalls.isEmpty)
            XCTAssertEqual(DiscoverySnapshot(state), snapshot)
            XCTAssertFalse(state.searched)
            XCTAssertFalse(state.searching)
            XCTAssertFalse(state.sourceLoading)
            XCTAssertTrue(service.writeCalls.isEmpty)
        }
    }


    func testOrdinaryWorkspaceRetirementCancelsReadsWithoutDispatchingLaterSources() async throws {
        let service = DiscoveryControlledService()
        var state: ReaderOnlineWorkspaceModel? = ReaderOnlineWorkspaceModel()
        weak var weakState = state
        defer { state?.retireCachedDiscovery(); service.releaseAll() }
        state?.service = service; state?.query = "workspace read identity"
        let identity = UUID(); state?.activateDiscoveryPresentation(identity)
        let listed = expectation(description: "Ordinary workspace source-list read entered")
        service.onSourcesEntered = { _ in listed.fulfill() }
        let listTask = Task { @MainActor [weak model = state] in await model?.loadSources() }
        defer { listTask.cancel() }
        await fulfillment(of: [listed], timeout: 2)
        try service.completeSources(0, with: .success(DiscoveryControlledService.sources(6)))
        await listTask.value
        let fourReads = expectation(description: "Exactly the first four source reads entered")
        fourReads.expectedFulfillmentCount = 4
        service.onSearchEntered = { count in if count <= 4 { fourReads.fulfill() } }
        state?.search()
        await fulfillment(of: [fourReads], timeout: 2)
        XCTAssertEqual(service.searchCalls.count, 4)
        let snapshot = DiscoverySnapshot(try XCTUnwrap(state))
        let actions = try XCTUnwrap(state?.actions)
        let originalID = "dc0c9c88-7f50-4975-8940-c795cc7c3288"
        var writeExecutions = 0
        XCTAssertTrue(actions.restoreAccepted(id: originalID, label: "原操作", scope: "workspace-contract|accepted-write") { _ in
            writeExecutions += 1
            XCTFail("Leaving search must never execute an accepted write")
            throw DiscoveryControlledService.Failure.unsupported
        })
        var latePublications = 0
        let observations = [
            try XCTUnwrap(state).$results.dropFirst().sink { _ in latePublications += 1 },
            try XCTUnwrap(state).$timings.dropFirst().sink { _ in latePublications += 1 },
            try XCTUnwrap(state).$currentResultIDs.dropFirst().sink { _ in latePublications += 1 }
        ]
        defer { observations.forEach { $0.cancel() } }
        let cancelled = expectation(description: "All four exact workspace reads observed cancellation")
        cancelled.expectedFulfillmentCount = 4
        service.onSearchCancelled = { _ in cancelled.fulfill() }
        // This is the exact top-level back/onDisappear hook, not child-page return.
        state?.retireDiscoveryPresentation(identity)
        await fulfillment(of: [cancelled], timeout: 2)
        XCTAssertEqual(service.cancelledSearches, Set(0..<4))
        XCTAssertFalse(try XCTUnwrap(state).searching)
        XCTAssertEqual(DiscoverySnapshot(try XCTUnwrap(state)), snapshot)
        state = nil
        // Noncooperative original reads return real protocol values only after
        // retirement. No fifth/sixth read, write or publication may follow.
        try service.completeRemainingSearches()
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in weakState == nil }, object: nil)
        await fulfillment(of: [released], timeout: 2)
        XCTAssertNil(weakState)
        XCTAssertEqual(service.searchCalls.count, 4)
        XCTAssertEqual(latePublications, 0)
        XCTAssertEqual(actions.pendingOperationID, originalID)
        XCTAssertEqual(actions.scope, "workspace-contract|accepted-write")
        XCTAssertTrue(actions.hasPending); XCTAssertFalse(actions.busy)
        XCTAssertEqual(writeExecutions, 0); XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testOrdinaryWorkspaceLateSourceAndDetailReadsCannotPublishAfterRetirement() async throws {
        let service = DiscoveryControlledService()
        var state: ReaderOnlineWorkspaceModel? = ReaderOnlineWorkspaceModel()
        weak var weakState = state
        defer { state?.retireCachedDiscovery(); service.releaseAll() }
        state?.service = service
        let originalID = UUID(); state?.activateDiscoveryPresentation(originalID)
        let candidate = ReaderOnlineCandidate(sourceId: "retained", bookId: "candidate", title: "Retained identity")
        let listed = expectation(description: "Original workspace source read entered")
        let detailed = expectation(description: "Original detail read entered")
        service.onSourcesEntered = { index in if index == 0 { listed.fulfill() } }
        service.onDetailEntered = { index in if index == 0 { detailed.fulfill() } }
        let oldListTask = Task { @MainActor [weak model = state] in await model?.loadSources() }
        defer { oldListTask.cancel() }
        state?.showDetail(candidate)
        await fulfillment(of: [listed, detailed], timeout: 2)
        let sourceCancelled = expectation(description: "Original source read cancellation")
        let detailCancelled = expectation(description: "Original detail read cancellation")
        service.onSourcesCancelled = { index in if index == 0 { sourceCancelled.fulfill() } }
        service.onDetailCancelled = { index in if index == 0 { detailCancelled.fulfill() } }
        state?.retireDiscoveryPresentation(originalID)
        await fulfillment(of: [sourceCancelled, detailCancelled], timeout: 2)
        XCTAssertFalse(try XCTUnwrap(state).sourceLoading)
        XCTAssertFalse(try XCTUnwrap(state).detailLoading)
        var latePublications = 0
        let observations = [
            try XCTUnwrap(state).$sources.dropFirst().sink { _ in latePublications += 1 },
            try XCTUnwrap(state).$sourceReadFailure.dropFirst().sink { _ in latePublications += 1 },
            try XCTUnwrap(state).$detail.dropFirst().sink { _ in latePublications += 1 },
            try XCTUnwrap(state).$error.dropFirst().sink { _ in latePublications += 1 },
            try XCTUnwrap(state).$detailLoading.dropFirst().sink { _ in latePublications += 1 }
        ]
        defer { observations.forEach { $0.cancel() } }
        // Reopening the top-level workspace creates an independent StateObject.
        let reopened = ReaderOnlineWorkspaceModel(); reopened.service = service
        let reopenedID = UUID(); reopened.activateDiscoveryPresentation(reopenedID)
        defer { reopened.retireDiscoveryPresentation(reopenedID) }
        let newListed = expectation(description: "Reopened workspace source read entered")
        let newDetailed = expectation(description: "Reopened workspace detail read entered")
        service.onSourcesEntered = { index in if index == 1 { newListed.fulfill() } }
        service.onDetailEntered = { index in if index == 1 { newDetailed.fulfill() } }
        let newListTask = Task { await reopened.loadSources() }
        defer { newListTask.cancel() }
        reopened.showDetail(candidate)
        await fulfillment(of: [newListed, newDetailed], timeout: 2)
        let reopenedSnapshot = DiscoverySnapshot(reopened)
        state?.showDetail(candidate)
        XCTAssertEqual(service.detailReadCount, 2, "A retired original host cannot start another detail read")
        state = nil
        try service.completeSources(0, with: .success(DiscoveryControlledService.sources(3)))
        try service.failDetail(0)
        await oldListTask.value
        // Weak release establishes that both old model continuations drained;
        // no sleep or late callback assumption stands in for their completion.
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in weakState == nil }, object: nil)
        await fulfillment(of: [released], timeout: 2)
        XCTAssertNil(weakState); XCTAssertEqual(latePublications, 0)
        XCTAssertEqual(DiscoverySnapshot(reopened), reopenedSnapshot)
        XCTAssertTrue(reopened.isCurrentDiscoveryPresentation(reopenedID))
        XCTAssertTrue(reopened.sourceLoading); XCTAssertTrue(reopened.detailLoading)
        XCTAssertNil(reopened.error)
        XCTAssertEqual(service.cancelledSources, [0]); XCTAssertEqual(service.cancelledDetails, [0])
        reopened.retireDiscoveryPresentation(reopenedID)
        try service.completeSources(1, with: .success(DiscoveryControlledService.sources(2)))
        try service.failDetail(1)
        await newListTask.value
        XCTAssertEqual(service.sourceReadCount, 2); XCTAssertEqual(service.detailReadCount, 2)
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testOldPresentationCannotRetireReopenedOwnerAndEvictionReleasesReadLifetime() async throws {
        // Exercise the production cache with an independent owner. These are
        // presentation identities only: no books, sources or requests are made,
        // and the shared App cache/its accepted owners are never replaced.
        do {
            let cache = ReaderSwitchPresentationCache()
            let created = cache.state(for: "owned-query", initialQuery: "initial query")
            XCTAssertEqual(created.query, "initial query", "A newly created state receives the initial book-title query once")
            created.query = ""
            let reopened = cache.state(for: "owned-query", initialQuery: "must not replace the empty query")
            XCTAssertTrue(reopened === created && reopened.query.isEmpty,
                          "Reopening the same cached state retains an intentionally empty query")
            for index in 0..<8 { _ = cache.state(for: "owned-eviction-\(index)", initialQuery: "") }
            let recreated = cache.state(for: "owned-query", initialQuery: "new initial query")
            XCTAssertTrue(recreated !== created && recreated.query == "new initial query",
                          "Only a new state after the unchanged eight-entry eviction is initialized again")
        }
        // Empty platform structure only: no candidate, book/source DTO,
        // service request or offset is manufactured. Reuse the actual visible
        // foreground window and production representable container type.
        let foreground = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive })
        let window = try XCTUnwrap(foreground.windows.first {
            $0.isKeyWindow && !$0.isHidden && $0.windowLevel == .normal
        }, "The structural check requires an existing real foreground App window")
        var visibleParent = try XCTUnwrap(window.rootViewController)
        while let presented = visibleParent.presentedViewController { visibleParent = presented }
        let stage = UIViewController()
        visibleParent.addChild(stage)
        stage.view.frame = visibleParent.view.bounds
        stage.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        visibleParent.view.addSubview(stage.view)
        stage.didMove(toParent: visibleParent)
        defer {
            stage.willMove(toParent: nil); stage.view.removeFromSuperview(); stage.removeFromParent()
        }
        stage.view.layoutIfNeeded()
        XCTAssertTrue(stage.view.window === window)
        XCTAssertGreaterThan(stage.view.bounds.width, 0); XCTAssertGreaterThan(stage.view.bounds.height, 0)
        func scrollView(in view: UIView) -> UIScrollView? {
            if let scroll = view as? UIScrollView { return scroll }
            for child in view.subviews { if let scroll = scrollView(in: child) { return scroll } }
            return nil
        }
        func mountContainer(_ container: ReaderSwitchCandidateViewportController) {
            stage.addChild(container)
            container.view.frame = stage.view.bounds
            container.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            stage.view.addSubview(container.view)
            container.didMove(toParent: stage)
            container.view.setNeedsLayout(); container.view.layoutIfNeeded()
        }
        func removeContainer(_ container: ReaderSwitchCandidateViewportController) {
            guard container.parent === stage else { return }
            container.willMove(toParent: nil); container.view.removeFromSuperview(); container.removeFromParent()
        }
        weak var weakHosting: UIViewController?
        weak var weakScroll: UIScrollView?
        do {
            let cache = ReaderSwitchPresentationCache()
            let identity = UUID().uuidString // A cache presentation identity, never a Core book.
            let emptyState = cache.state(for: identity, initialQuery: "")
            let nativeOwner = cache.candidateHost(for: identity, initialQuery: "")
            XCTAssertTrue(emptyState.results.isEmpty && emptyState.sources.isEmpty && emptyState.service == nil)
            let environment = ReaderSwitchCandidateEnvironment(scheme: .light, dynamicTypeSize: .large,
                locale: .current, direction: .leftToRight, reduceMotion: false, legibilityWeight: nil)
            let firstID = UUID(), nextID = UUID(), originalSession = UUID()
            func settlePresentationCommit() async {
                // The production Host defers @Published platform input until
                // the next main-actor turn so UIViewRepresentable updates do
                // not publish during SwiftUI reconciliation.
                for _ in 0..<3 { await Task.yield() }
            }
            emptyState.activateDiscoveryPresentation(firstID)
            let first = ReaderSwitchCandidateViewportController(owner: nativeOwner, state: emptyState,
                sessionID: originalSession, bookID: identity, presentationID: firstID)
            defer { nativeOwner.detach(first); removeContainer(first) }
            nativeOwner.beginAttachment(first)
            nativeOwner.update(first, disabled: false, environment: environment)
            mountContainer(first)
            let nativeScrollAppeared = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
                first.children.first.map { scrollView(in: $0.view) != nil } ?? false
            }, object: nil)
            await fulfillment(of: [nativeScrollAppeared], timeout: 3)
            let hosting = try XCTUnwrap(first.children.first)
            XCTAssertTrue(hosting is ReaderSwitchCandidateHostingController,
                          "The retained child must be the production UIHostingController subclass")
            let originalScroll = try XCTUnwrap(scrollView(in: hosting.view))
            weakHosting = hosting; weakScroll = originalScroll
            XCTAssertTrue(hosting.parent === first && originalScroll.window === window)
            let oldRenderedAttachmentID = first.attachmentID
            XCTAssertTrue(nativeOwner.isCurrentRenderedAttachment(oldRenderedAttachmentID))
            #if DEBUG
            XCTAssertEqual(nativeOwner.viewportRootAssignments, 1, "The cached hosting root is initialized exactly once")
            #endif
            let changedEnvironment = ReaderSwitchCandidateEnvironment(scheme: .dark, dynamicTypeSize: .xLarge,
                locale: Locale(identifier: "en_US"), direction: .rightToLeft, reduceMotion: true, legibilityWeight: .bold)
            nativeOwner.update(first, disabled: true, environment: changedEnvironment)
            XCTAssertFalse(nativeOwner.isCurrentRenderedAttachment(oldRenderedAttachmentID),
                           "An action rendered before disabled changed must not be accepted")
            nativeOwner.update(first, disabled: false, environment: environment)
            await settlePresentationCommit()
            XCTAssertTrue(nativeOwner.isCurrentRenderedAttachment(oldRenderedAttachmentID))
            #if DEBUG
            XCTAssertEqual(nativeOwner.viewportRootAssignments, 1, "Disabled/environment updates publish input instead of assigning rootView")
            #endif

            nativeOwner.endPresentation(firstID)
            XCTAssertFalse(nativeOwner.isCurrentRenderedAttachment(oldRenderedAttachmentID))
            emptyState.retireDiscoveryPresentation(firstID)
            removeContainer(first)
            XCTAssertTrue(first.children.isEmpty); XCTAssertNil(hosting.parent)
            XCTAssertNil(originalScroll.window)
            emptyState.activateDiscoveryPresentation(nextID)
            let second = ReaderSwitchCandidateViewportController(owner: nativeOwner, state: emptyState,
                sessionID: originalSession, bookID: identity, presentationID: nextID)
            defer { nativeOwner.detach(second); removeContainer(second) }
            XCTAssertTrue(first !== second && first.attachmentID != second.attachmentID)
            nativeOwner.beginAttachment(second)
            nativeOwner.update(second, disabled: false, environment: environment)
            mountContainer(second)
            await settlePresentationCommit()
            XCTAssertTrue(second.children.first === hosting && hosting.parent === second)
            XCTAssertTrue(scrollView(in: hosting.view) === originalScroll && originalScroll.window === window,
                          "Controller retention must preserve the actual native ScrollView, not just a row ID")
            XCTAssertFalse(nativeOwner.isCurrentRenderedAttachment(oldRenderedAttachmentID),
                           "A closure from the first render cannot adopt the reopened attachment")
            XCTAssertTrue(nativeOwner.isCurrentRenderedAttachment(second.attachmentID))
            #if DEBUG
            XCTAssertEqual(nativeOwner.viewportRootAssignments, 1, "Reopening reuses the original root and observed input")
            #endif
            // These immediate getters protect only empty structural identity;
            // deferred SwiftUI commits/populated2pt remain the realUI method's job.
            // An unchanged representable update must not replace the native graph.
            nativeOwner.update(second, disabled: false, environment: environment)
            second.view.layoutIfNeeded()
            XCTAssertTrue(second.children.first === hosting && scrollView(in: hosting.view) === originalScroll)
            ReaderSwitchCandidateViewport.dismantleUIViewController(first, coordinator: ())
            XCTAssertTrue(nativeOwner.isAttached(second) && hosting.parent === second)
            XCTAssertTrue(nativeOwner.isCurrentRenderedAttachment(second.attachmentID),
                           "An obsolete dismantle cannot disable the reopened input")
            XCTAssertFalse(nativeOwner.isCurrentRenderedAttachment(oldRenderedAttachmentID))
            XCTAssertTrue(scrollView(in: hosting.view) === originalScroll && originalScroll.window === window)
            nativeOwner.endPresentation(firstID)
            XCTAssertTrue(nativeOwner.isAttached(second), "An obsolete presentation end cannot retire the reopened attachment")
            for index in 0..<8 { _ = cache.state(for: "native-host-eviction-\(index)", initialQuery: "") }
            XCTAssertFalse(emptyState.isCurrentDiscoveryPresentation(nextID))
            XCTAssertFalse(nativeOwner.isAttached(second))
            XCTAssertFalse(nativeOwner.isCurrentRenderedAttachment(second.attachmentID))
            XCTAssertTrue(second.children.isEmpty); XCTAssertNil(hosting.parent); XCTAssertNil(originalScroll.window)
            XCTAssertTrue(emptyState.results.isEmpty && emptyState.sources.isEmpty && emptyState.service == nil)
        }
        let nativeGraphReleased = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            weakHosting == nil && weakScroll == nil
        }, object: nil)
        await fulfillment(of: [nativeGraphReleased], timeout: 3)
        XCTAssertNil(weakHosting); XCTAssertNil(weakScroll)
        // This is no pixel-offset or real-candidate viewport assertion. The
        // separate real online close/reopen journey still owns its strict 2pt contract.
        let service = DiscoveryControlledService()
        var state: ReaderOnlineWorkspaceModel? = ReaderOnlineWorkspaceModel()
        weak var weakState = state
        defer { state?.retireCachedDiscovery(); service.releaseAll() }
        state?.service = service; state?.query = "retained query"; state?.searched = true
        state?.sources = DiscoveryControlledService.sources(1)
        state?.results = [ReaderOnlineCandidate(sourceId: "retained", bookId: "candidate", title: "Retained identity")]
        state?.timings = ["retained": 23]
        let snapshot = DiscoverySnapshot(try XCTUnwrap(state))
        let oldID = UUID(), currentID = UUID()
        let oldEntered = expectation(description: "Old presentation source read entered")
        let currentEntered = expectation(description: "Reopened presentation source read entered")
        let oldCancelled = expectation(description: "Old read cancellation delivered")
        let currentCancelled = expectation(description: "Cache retirement cancelled reopened read")
        service.onSourcesEntered = { index in
            if index == 0 { oldEntered.fulfill() }
            if index == 1 { currentEntered.fulfill() }
        }
        service.onSourcesCancelled = { index in
            if index == 0 { oldCancelled.fulfill() }
            if index == 1 { currentCancelled.fulfill() }
        }
        state?.activateDiscoveryPresentation(oldID)
        let oldTask = Task { @MainActor [weak model = state] in
            await model?.refreshDiscoverySources(presentationID: oldID)
        }
        defer { oldTask.cancel() }
        await fulfillment(of: [oldEntered], timeout: 2)
        state?.retireDiscoveryPresentation(oldID)
        await fulfillment(of: [oldCancelled], timeout: 2)
        state?.activateDiscoveryPresentation(currentID)
        let currentTask = Task { @MainActor [weak model = state] in
            await model?.refreshDiscoverySources(presentationID: currentID)
        }
        defer { currentTask.cancel() }
        await fulfillment(of: [currentEntered], timeout: 2)

        // The MainActor cannot run this queued old activation before cancel().
        let cancelledOldActivation = Task { @MainActor [weak model = state] in
            model?.activateDiscoveryPresentation(oldID)
        }
        cancelledOldActivation.cancel()
        await cancelledOldActivation.value
        try service.completeSources(0, with: .success(DiscoveryControlledService.sources(3)))
        await oldTask.value
        state?.retireDiscoveryPresentation(oldID)
        XCTAssertTrue(try XCTUnwrap(state).isCurrentDiscoveryPresentation(currentID))
        XCTAssertTrue(try XCTUnwrap(state).sourceLoading)
        XCTAssertEqual(service.cancelledSources, [0])
        XCTAssertEqual(service.sourceReadCount, 2)
        XCTAssertEqual(DiscoverySnapshot(try XCTUnwrap(state)), snapshot)

        // This is the production hook used by the bounded presentation cache.
        state?.retireCachedDiscovery()
        await fulfillment(of: [currentCancelled], timeout: 2)
        XCTAssertFalse(try XCTUnwrap(state).isCurrentDiscoveryPresentation(currentID))
        XCTAssertFalse(try XCTUnwrap(state).sourceLoading)
        XCTAssertEqual(DiscoverySnapshot(try XCTUnwrap(state)), snapshot)
        state = nil
        try service.completeSources(1, with: .success(DiscoveryControlledService.sources(4)))
        await currentTask.value
        let released = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in weakState == nil }, object: nil)
        await fulfillment(of: [released], timeout: 2)
        XCTAssertNil(weakState)
        XCTAssertEqual(service.cancelledSources, [0, 1])
        XCTAssertTrue(service.searchCalls.isEmpty)
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testSubscriptionOpportunityRefreshesProductionWorkspaceAndNextSearchWithoutWriteReplay() async throws {
        let service = DiscoveryControlledService()
        let gate = DiscoverySubscriptionOpportunityGate()
        let scheduler = ReaderRuleSubscriptionScheduler(checkDue: { try await gate.check() })
        let state = ReaderOnlineWorkspaceModel()
        state.query = "retained search query"; state.sourceFilter = "retained filter"
        let originalID = UUID().uuidString
        var writeExecutions = 0
        XCTAssertTrue(state.actions.restoreAccepted(id: originalID, label: "原操作", scope: "online") { _ in
            writeExecutions += 1
            XCTFail("An opportunity refresh must never resume an accepted write")
            throw DiscoveryControlledService.Failure.unsupported
        })
        let initial = expectation(description: "Production Workspace initial source read")
        let refreshed = expectation(description: "Production completion publisher starts exactly one source refresh")
        service.onSourcesEntered = { index in
            if index == 0 { initial.fulfill() }
            else if index == 1 { refreshed.fulfill() }
            else { XCTFail("Unexpected duplicate source-list read") }
        }
        let mount = try mountSubscriptionWorkspace(state: state, service: service, scheduler: scheduler)
        defer { mount.unmount(); state.retireCachedDiscovery(); service.releaseAll(); gate.release() }
        await fulfillment(of: [initial], timeout: 3)
        try service.completeSources(0, with: .success(DiscoveryControlledService.sources(1)))
        let initiallyPublished = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in state.sources.count == 1 }, object: nil)
        await fulfillment(of: [initiallyPublished], timeout: 3)
        // Nonempty contract DTOs exercise Host snapshot retention only. They
        // are not Core books, imported product data, or an HTTP/read acceptance.
        let retained = ReaderOnlineCandidate(sourceId: try XCTUnwrap(state.sources.first?.sourceId),
            bookId: "host-retained-candidate", title: "Retained Host candidate DTO")
        state.results = [retained]; state.timings = [retained.sourceId: 37]
        state.currentResultIDs = [retained.id]; state.scrollAnchor = retained.id
        let before = DiscoverySnapshot(state)
        var revisions = 0
        let observation = scheduler.$completedOpportunityRevision.dropFirst().sink { _ in revisions += 1 }
        defer { observation.cancel() }

        let entered = expectation(description: "Finite production opportunity reached its check boundary")
        gate.onEntered = { entered.fulfill() }
        let opportunity = Task { await scheduler.foregroundOpportunity() }
        defer { opportunity.cancel() }
        await fulfillment(of: [entered], timeout: 2)
        await scheduler.foregroundOpportunity() // Existing mutual exclusion owns the second request.
        XCTAssertEqual(gate.checks, 1); XCTAssertEqual(revisions, 0)
        XCTAssertEqual(service.sourceReadCount, 1, "Entering an opportunity must not refresh before completion")
        gate.complete(failures: ["Controlled partial failure at the finite Host check boundary"])
        await opportunity.value
        await fulfillment(of: [refreshed], timeout: 3)
        XCTAssertEqual(revisions, 1)
        try service.completeSources(1, with: .success(DiscoveryControlledService.sources(2)))
        let published = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in state.sources.count == 2 }, object: nil)
        await fulfillment(of: [published], timeout: 3)
        XCTAssertEqual(service.sourceReadCount, 2)
        XCTAssertEqual(state.query, before.query); XCTAssertEqual(state.sourceFilter, before.filter)
        XCTAssertEqual(state.results, before.results); XCTAssertEqual(state.timings, before.timings)
        XCTAssertEqual(state.currentResultIDs, before.currentResultIDs)
        XCTAssertEqual(state.scrollAnchor, before.scrollAnchor)
        XCTAssertEqual(state.actions.pendingOperationID, originalID)
        XCTAssertTrue(state.actions.hasPending); XCTAssertEqual(writeExecutions, 0)
        XCTAssertTrue(service.writeCalls.isEmpty)

        let dispatched = expectation(description: "Next user search includes the newly listed source")
        dispatched.expectedFulfillmentCount = 2
        service.onSearchEntered = { _ in dispatched.fulfill() }
        state.search()
        await fulfillment(of: [dispatched], timeout: 2)
        XCTAssertEqual(Set(service.searchCalls.map(\.sourceID)), Set(state.sources.map(\.sourceId)))
        XCTAssertTrue(state.results.isEmpty, "No generated book or successful product HTTP response is provided")
        XCTAssertEqual(writeExecutions, 0); XCTAssertTrue(service.writeCalls.isEmpty)
        // The controlled boundary returns no HTTP and no Book. Teardown rejects
        // these pending read continuations; this is Host wiring evidence only.
    }

    func testResearchCandidatesRetainsExistingResultsWhileRealSearchRuns() async throws {
        let service = DiscoveryControlledService()
        let state = ReaderOnlineWorkspaceModel()
        defer { state.retireCachedDiscovery(); service.releaseAll() }
        state.service = service
        state.sources = DiscoveryControlledService.sources(2)
        state.query = "retained search"
        let retained = ReaderOnlineCandidate(sourceId: state.sources[0].id, bookId: "retained-book", title: "Retained candidate")
        state.results = [retained]
        state.currentResultIDs = [retained.id]
        state.timings = [retained.sourceId: 23]
        let initialEntered = expectation(description: "Initial search establishes the real keyword generation")
        initialEntered.expectedFulfillmentCount = 2
        let entered = expectation(description: "Research dispatches the existing enabled sources")
        entered.expectedFulfillmentCount = 2
        service.onSearchEntered = { count in
            if count <= 2 { initialEntered.fulfill() } else { entered.fulfill() }
        }
        state.search()
        await fulfillment(of: [initialEntered], timeout: 2)
        state.results = [retained]
        state.currentResultIDs = [retained.id]
        state.timings = [retained.sourceId: 23]
        state.researchCandidates()
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertTrue(state.searching)
        XCTAssertEqual(state.results, [retained], "Research must keep already displayed candidates while requests are in flight")

        try service.completeRemainingSearches()
        let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !state.searching }, object: nil)
        await fulfillment(of: [settled], timeout: 2)
        XCTAssertTrue(state.results.contains(retained), "Research must not discard the previous candidate when new source results arrive")
        XCTAssertEqual(state.results.count, 3)
    }

    func testUserStopRetainsReturnedCandidatesAndDrainsLateSearches() async throws {
        let service = DiscoveryControlledService()
        let state = ReaderOnlineWorkspaceModel()
        defer { state.retireCachedDiscovery(); service.releaseAll() }
        state.service = service
        state.sources = DiscoveryControlledService.sources(2)
        state.query = "stop contract"

        let entered = expectation(description: "User stop search dispatches the enabled sources")
        entered.expectedFulfillmentCount = 2
        service.onSearchEntered = { _ in entered.fulfill() }
        state.search()
        await fulfillment(of: [entered], timeout: 2)
        try service.completeSearch(0)
        let returned = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in state.results.count == 1 }, object: nil)
        await fulfillment(of: [returned], timeout: 2)

        let cancelled = expectation(description: "User stop cancels every in-flight source read")
        // Source zero has already returned its real candidate; only the
        // remaining source is still in flight when the user stops.
        cancelled.expectedFulfillmentCount = 1
        service.onSearchCancelled = { _ in cancelled.fulfill() }
        state.stop()
        await fulfillment(of: [cancelled], timeout: 2)
        XCTAssertTrue(state.stopped)
        XCTAssertFalse(state.searching)
        XCTAssertEqual(state.results.count, 1, "Stopping must retain the candidate already returned by the real search generation")

        // Return the non-cooperative source response after the stop. The
        // invalidated generation must drain it without publishing a late row.
        try service.completeSearch(1)
        for _ in 0..<4 { await Task.yield() }
        XCTAssertEqual(state.results.count, 1, "A late response from the stopped generation must not alter visible results")
    }

    func testResearchCandidateTimingRequiresExactCurrentIdentityAcrossReturns() async throws {
        let service = DiscoveryControlledService()
        let state = ReaderOnlineWorkspaceModel()
        defer { state.retireCachedDiscovery(); service.releaseAll() }
        state.service = service
        state.sources = DiscoveryControlledService.sources(2)
        state.query = "candidate timing ownership"
        let presentation = UUID(); state.activateDiscoveryPresentation(presentation)
        let firstSource = state.sources[0].id, secondSource = state.sources[1].id
        let old = ReaderOnlineCandidate(sourceId: firstSource, bookId: "shared-book", title: "Original candidate")
        let other = ReaderOnlineCandidate(sourceId: secondSource, bookId: old.bookId, title: old.title)
        let replacement = ReaderOnlineCandidate(sourceId: firstSource, bookId: "replacement-book", title: old.title)

        func waitForSearches(_ count: Int) async {
            let entered = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in service.searchCalls.count == count }, object: nil)
            await fulfillment(of: [entered], timeout: 2)
        }
        func complete(_ sourceID: String, from start: Int, books: [ReaderOnlineCandidate], elapsed: Int) throws {
            let index = try XCTUnwrap(service.searchCalls.indices.dropFirst(start).first { service.searchCalls[$0].sourceID == sourceID })
            try service.completeSearch(index, books: books, elapsedMilliseconds: elapsed)
        }
        func waitForSettlement() async {
            let settled = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in !state.searching }, object: nil)
            await fulfillment(of: [settled], timeout: 2)
        }

        state.search(); await waitForSearches(2)
        try complete(firstSource, from: 0, books: [old], elapsed: 17)
        try complete(secondSource, from: 0, books: [other], elapsed: 23)
        await waitForSettlement()
        XCTAssertEqual(state.candidateElapsedMilliseconds(old), 17)
        XCTAssertEqual(state.candidateElapsedMilliseconds(other), 23)
        XCTAssertNil(state.candidateSearchStatus(old))
        state.scrollAnchor = old.id

        state.researchCandidates(); await waitForSearches(4)
        XCTAssertTrue(state.results.contains(old))
        XCTAssertEqual(state.scrollAnchor, old.id)
        XCTAssertNil(state.candidateElapsedMilliseconds(old))
        XCTAssertEqual(state.candidateSearchStatus(old), "上次候选 · 本次搜索中")
        try complete(firstSource, from: 2, books: [replacement], elapsed: 91)
        try complete(secondSource, from: 2, books: [other], elapsed: 92)
        await waitForSettlement()
        XCTAssertEqual(state.timings[firstSource], 91, "The source really completed this generation")
        XCTAssertNil(state.candidateElapsedMilliseconds(old), "An absent retained candidate cannot inherit its source's newer request timing")
        XCTAssertEqual(state.candidateSearchStatus(old), "上次候选 · 本次未确认")
        XCTAssertEqual(state.candidateElapsedMilliseconds(replacement), 91)
        XCTAssertNil(state.candidateSearchStatus(replacement))
        XCTAssertEqual(state.candidateElapsedMilliseconds(other), 92, "The same book ID from another source is a different candidate")

        let beforeReturn = DiscoverySnapshot(state)
        state.showDetail(old)
        XCTAssertEqual(state.selected?.id, old.id)
        state.closeDetail()
        XCTAssertEqual(DiscoverySnapshot(state), beforeReturn)
        state.retireDiscoveryPresentation(presentation)
        state.activateDiscoveryPresentation(UUID())
        XCTAssertEqual(DiscoverySnapshot(state), beforeReturn)
        XCTAssertNil(state.candidateElapsedMilliseconds(old))
        XCTAssertEqual(state.candidateElapsedMilliseconds(replacement), 91)

        state.researchCandidates(); await waitForSearches(6)
        try complete(firstSource, from: 4, books: [], elapsed: 101)
        try complete(secondSource, from: 4, books: [], elapsed: 102)
        await waitForSettlement()
        XCTAssertTrue(state.currentResultIDs.isEmpty)
        XCTAssertEqual(state.results, beforeReturn.results, "A confirmed empty retry retains the earlier candidates with explicit ownership")
        for candidate in state.results {
            XCTAssertNil(state.candidateElapsedMilliseconds(candidate))
            XCTAssertEqual(state.candidateSearchStatus(candidate), "上次候选 · 本次未确认")
        }
        XCTAssertEqual(state.query, beforeReturn.query)
        XCTAssertEqual(state.scrollAnchor, beforeReturn.scrollAnchor)
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    // Controlled continuations below establish only Host owner boundaries.
    // They do not represent source availability, HTTP failures or device acceptance.
    func testRecoveryRetriesOnlyIncompleteSourcesAndKeepsSuccessfulFactsOwnerBoundary() async throws {
        let service = DiscoveryControlledService()
        let state = ReaderOnlineWorkspaceModel()
        let trace = RecoverySearchTraceCapture()
        defer { state.retireCachedDiscovery(); service.releaseAll() }
        state.service = service; state.sources = DiscoveryControlledService.sources(4)
        state.query = "recovery owner boundary"
        state.searchTraceSink = { trace.receive($0) }
        let sourceIDs = state.sources.map(\.id)
        let candidate = ReaderOnlineCandidate(sourceId: sourceIDs[0], bookId: "retained-identity", title: "Host candidate identity")
        func waitFor(_ condition: @escaping () -> Bool) async {
            let reached = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
            await fulfillment(of: [reached], timeout: 2)
        }
        func call(_ sourceID: String, from start: Int) throws -> Int {
            try XCTUnwrap(service.searchCalls.indices.dropFirst(start).first { service.searchCalls[$0].sourceID == sourceID })
        }

        state.search()
        await waitFor { service.searchCalls.count == 4 }
        try service.completeSearch(call(sourceIDs[0], from: 0), books: [candidate], elapsedMilliseconds: 17)
        try service.completeSearch(call(sourceIDs[1], from: 0), books: [], elapsedMilliseconds: 23)
        try service.failSearch(call(sourceIDs[2], from: 0))
        await waitFor { state.timings.count == 2 && state.failures.count == 1 }
        state.scrollAnchor = candidate.id
        state.stop()
        state.retryIncompleteSources()
        await waitFor { service.searchCalls.count == 6 }

        XCTAssertEqual(Set(service.searchCalls.dropFirst(4).map(\.sourceID)), Set(sourceIDs.suffix(2)))
        XCTAssertEqual(state.results, [candidate])
        XCTAssertEqual(state.scrollAnchor, candidate.id)
        XCTAssertEqual(state.currentResultIDs, [candidate.id])
        XCTAssertEqual(state.timings, [sourceIDs[0]: 17, sourceIDs[1]: 23], "Confirmed empty sources are successful buckets too")
        XCTAssertNil(state.candidateSearchStatus(candidate))
        XCTAssertEqual(state.searchSourceCount, 4)
        XCTAssertTrue(state.failures.isEmpty)
        try service.completeSearch(call(sourceIDs[3], from: 0), elapsedMilliseconds: 99)
        try service.completeSearch(call(sourceIDs[2], from: 4), elapsedMilliseconds: 91)
        try service.completeSearch(call(sourceIDs[3], from: 4), elapsedMilliseconds: 92)
        await waitFor { !state.searching }
        XCTAssertEqual(state.candidateElapsedMilliseconds(candidate), 17)
        XCTAssertEqual(state.results.count, 3, "The stopped generation cannot publish its late candidate")
        let generations = trace.events.filter { $0.stage == .generationStarted }
        XCTAssertEqual(generations.map(\.count), [4, 2])
        let recoveryID = try XCTUnwrap(generations.last?.searchID)
        let recoveryEvents = trace.events.filter { $0.searchID == recoveryID }
        XCTAssertEqual(Set(recoveryEvents.filter { $0.stage == .sourceAttemptStarted }.compactMap(\.sourceOrdinal)), [1, 2])
        XCTAssertEqual(recoveryEvents.filter { $0.stage == .sourceResultApplied }.count, 2)
        XCTAssertEqual(Set(recoveryEvents.filter { $0.stage == .sourceResultApplied }.compactMap(\.durationMilliseconds)), [91, 92], "Retained timings must not masquerade as new request observations")
        state.retryIncompleteSources()
        XCTAssertFalse(state.searching)
        XCTAssertEqual(service.searchCalls.count, 6, "A fully completed recovery has no remaining requests")
        XCTAssertEqual(trace.events.filter { $0.stage == .generationStarted }.count, 2, "Reused successes do not create an empty request generation")
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testRecoveryInvalidatesChangedRegistryAndExactKeywordOwnerBoundary() async throws {
        let service = DiscoveryControlledService()
        let state = ReaderOnlineWorkspaceModel()
        defer { state.retireCachedDiscovery(); service.releaseAll() }
        state.service = service; state.sources = DiscoveryControlledService.sources(4)
        state.query = "Caf\u{00E9}"
        let original = state.sources
        func waitFor(_ condition: @escaping () -> Bool) async {
            let reached = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
            await fulfillment(of: [reached], timeout: 2)
        }
        func changed(_ source: ReaderOnlineSource, enabled: Bool = true, version: String) -> ReaderOnlineSource {
            .init(sourceId: source.id, name: source.name, baseURL: source.baseURL, enabled: enabled,
                  version: version, group: source.group, definition: source.definition)
        }
        state.search(); await waitFor { service.searchCalls.count == 4 }
        try service.completeRemainingSearches()
        await waitFor { !state.searching }
        let retained = try XCTUnwrap(state.results.first { $0.sourceId == original[0].id })
        let invalidated = try XCTUnwrap(state.results.first { $0.sourceId == original[1].id })
        let retainedTiming = try XCTUnwrap(state.timings[retained.sourceId])
        state.scrollAnchor = invalidated.id
        let added = ReaderOnlineSource(sourceId: "added-recovery-owner", name: "Added owner identity", baseURL: "",
                                       enabled: true, version: "contract-1", group: "", definition: Data())
        state.sources = [original[0], changed(original[1], version: "contract-2"),
                         changed(original[2], enabled: false, version: original[2].version), added]
        state.retryIncompleteSources()
        await waitFor { service.searchCalls.count == 6 }
        XCTAssertEqual(Set(service.searchCalls.dropFirst(4).map(\.sourceID)), [original[1].id, added.id])
        XCTAssertEqual(state.results, [retained], "Changed, disabled and deleted source rows are invalidated")
        XCTAssertEqual(state.currentResultIDs, [retained.id])
        XCTAssertEqual(state.timings, [retained.sourceId: retainedTiming])
        XCTAssertNil(state.scrollAnchor)
        XCTAssertEqual(state.searchSourceCount, 3)
        try service.completeRemainingSearches()
        await waitFor { !state.searching }

        let originalKeyword = state.query
        state.query = "Cafe\u{0301}"
        XCTAssertEqual(state.query, originalKeyword, "Swift text equality alone merges these distinct request bytes")
        XCTAssertNotEqual(Data(state.query.utf8), Data(originalKeyword.utf8))
        state.retryIncompleteSources()
        await waitFor { service.searchCalls.count == 9 }
        XCTAssertEqual(Set(service.searchCalls.dropFirst(6).map(\.sourceID)), [original[0].id, original[1].id, added.id])
        XCTAssertTrue(state.results.isEmpty, "Only the exact keyword can retain successful buckets")
        XCTAssertTrue(state.currentResultIDs.isEmpty)
        XCTAssertTrue(state.timings.isEmpty)
        XCTAssertEqual(state.searchSourceCount, 3)
        state.sources = []
        XCTAssertEqual(state.searchSourceCount, 3, "A later registry observation cannot alter the active run's denominator")
        state.stop()
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testRetiredProductionWorkspaceIgnoresOpportunityAndDrainsLateSourceRefresh() async throws {
        let service = DiscoveryControlledService()
        let gate = DiscoverySubscriptionOpportunityGate()
        let scheduler = ReaderRuleSubscriptionScheduler(checkDue: { try await gate.check() })
        let state = ReaderOnlineWorkspaceModel()
        state.query = "retained query"; state.sourceFilter = "retained filter"
        let initial = expectation(description: "Production Workspace initial read")
        let refresh = expectation(description: "Opportunity started the production read owner")
        service.onSourcesEntered = { index in
            if index == 0 { initial.fulfill() }
            else if index == 1 { refresh.fulfill() }
            else { XCTFail("A retired Workspace must not issue another source read") }
        }
        let mount = try mountSubscriptionWorkspace(state: state, service: service, scheduler: scheduler)
        defer { mount.unmount(); state.retireCachedDiscovery(); service.releaseAll(); gate.release() }
        await fulfillment(of: [initial], timeout: 3)
        try service.completeSources(0, with: .success(DiscoveryControlledService.sources(1)))
        let initialValue = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in state.sources.count == 1 }, object: nil)
        await fulfillment(of: [initialValue], timeout: 3)
        let before = DiscoverySnapshot(state)
        var revisions = 0
        let opportunityObservation = scheduler.$completedOpportunityRevision.dropFirst().sink { _ in revisions += 1 }
        defer { opportunityObservation.cancel() }
        let entered = expectation(description: "First finite opportunity entered")
        gate.onEntered = { entered.fulfill() }
        let opportunity = Task { await scheduler.foregroundOpportunity() }
        defer { opportunity.cancel() }
        await fulfillment(of: [entered], timeout: 2)
        // Cancellation after entry cannot imply that no ACK was committed.
        // This gate returns no ACK; it exercises only completion invalidation.
        opportunity.cancel()
        gate.complete(); await opportunity.value
        await fulfillment(of: [refresh], timeout: 3)
        XCTAssertEqual(revisions, 1, "A finite check returning after cancellation still invalidates the source projection")

        let cancelled = expectation(description: "Production disappearance cancelled the original refresh read")
        service.onSourcesCancelled = { index in if index == 1 { cancelled.fulfill() } }
        let unexpectedPublication = expectation(description: "Retired list cannot publish a late value")
        unexpectedPublication.isInverted = true
        let observation = state.$sources.dropFirst().sink { _ in unexpectedPublication.fulfill() }
        defer { observation.cancel() }
        mount.unmount()
        await fulfillment(of: [cancelled], timeout: 3)
        try service.completeSources(1, with: .success(DiscoveryControlledService.sources(2)))
        let enteredAgain = expectation(description: "A later opportunity is independent of the retired UI")
        gate.onEntered = { enteredAgain.fulfill() }
        let later = Task { await scheduler.foregroundOpportunity() }
        defer { later.cancel() }
        await fulfillment(of: [enteredAgain], timeout: 2)
        gate.complete(); await later.value
        XCTAssertEqual(revisions, 2)
        await fulfillment(of: [unexpectedPublication], timeout: 0.3)
        XCTAssertEqual(DiscoverySnapshot(state), before)
        XCTAssertEqual(service.sourceReadCount, 2)
        XCTAssertEqual(service.cancelledSources, [1])
        XCTAssertTrue(service.searchCalls.isEmpty); XCTAssertTrue(service.writeCalls.isEmpty)
    }

    private func mountSubscriptionWorkspace(state: ReaderOnlineWorkspaceModel,
                                             service: DiscoveryControlledService,
                                             scheduler: ReaderRuleSubscriptionScheduler) throws
        -> (unmount: @MainActor () -> Void, host: UIHostingController<ReaderOnlineWorkspace>) {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let window = try XCTUnwrap(scenes.flatMap(\.windows).first {
            $0.isKeyWindow && !$0.isHidden && $0.windowLevel == .normal
        }, "This Host wiring method requires the real foreground test App window")
        var parent = try XCTUnwrap(window.rootViewController)
        while let presented = parent.presentedViewController { parent = presented }
        let domain = "ReaderSubscriptionRefresh-" + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: domain))
        let model = ReaderApplicationModel(service: service)
        let preferences = ReaderPreferences(defaults: defaults)
        let host = UIHostingController(rootView: ReaderOnlineWorkspace(model: model, preferences: preferences,
            close: {}, state: state, subscriptionScheduler: scheduler))
        parent.addChild(host)
        host.view.frame = parent.view.bounds; host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        host.beginAppearanceTransition(true, animated: false)
        parent.view.addSubview(host.view); host.didMove(toParent: parent)
        host.endAppearanceTransition(); host.view.layoutIfNeeded()
        XCTAssertTrue(host.view.window === window)
        let unmount: @MainActor () -> Void = {
            guard host.parent != nil else { return }
            host.beginAppearanceTransition(false, animated: false)
            host.willMove(toParent: nil); host.view.removeFromSuperview(); host.removeFromParent()
            host.endAppearanceTransition()
            defaults.removePersistentDomain(forName: domain)
        }
        return (unmount, host)
    }

}

private final class RecoverySearchTraceCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var recorded: [ReaderSearchTraceEvent] = []
    func receive(_ event: ReaderSearchTraceEvent) { lock.withLock { recorded.append(event) } }
    var events: [ReaderSearchTraceEvent] { lock.withLock { recorded } }
}

private struct DiscoverySnapshot: Equatable {
    let query: String
    let filter: String
    let sources: [ReaderOnlineSource]
    let results: [ReaderOnlineCandidate]
    let timings: [String: Int]
    let failures: [String: String]
    let currentResultIDs: Set<String>
    let scrollAnchor: String?
    let sourceReadFailure: String?
    let sourceReadFailureID: UUID?
    @MainActor init(_ state: ReaderOnlineWorkspaceModel) {
        query = state.query; filter = state.sourceFilter; sources = state.sources
        results = state.results; timings = state.timings; failures = state.failures
        currentResultIDs = state.currentResultIDs; scrollAnchor = state.scrollAnchor
        sourceReadFailure = state.sourceReadFailure; sourceReadFailureID = state.sourceReadFailureID
    }
}

@MainActor
private final class DiscoveryControlledService: ReaderOnlineServing {
    enum Failure: Error { case unsupported, lateRead, teardown, missingContinuation }
    struct SearchCall { let sourceID: String; let keyword: String; let page: Int }
    private(set) var sourceReadCount = 0
    private(set) var detailReadCount = 0
    private(set) var cancelledDetails = Set<Int>()
    private(set) var searchCalls: [SearchCall] = []
    private(set) var cancelledSources = Set<Int>()
    private(set) var cancelledSearches = Set<Int>()
    private(set) var writeCalls: [String] = []
    var onSourcesEntered: ((Int) -> Void)?
    var onSourcesCancelled: ((Int) -> Void)?
    var onSearchEntered: ((Int) -> Void)?
    var onSearchCancelled: ((Int) -> Void)?
    var onDetailEntered: ((Int) -> Void)?
    var onDetailCancelled: ((Int) -> Void)?
    private var sourceReads: [Int: CheckedContinuation<[ReaderOnlineSource], Error>] = [:]
    private var searches: [Int: CheckedContinuation<ReaderSourceSearchResult, Error>] = [:]
    private var details: [Int: CheckedContinuation<ReaderOnlineDetail, Error>] = [:]
    private var closed = false

    static func sources(_ count: Int) -> [ReaderOnlineSource] {
        (0..<count).map {
            ReaderOnlineSource(sourceId: "discovery-contract-\($0)", name: "Source identity \($0)",
                baseURL: "", enabled: true, version: "contract-1", group: "", definition: Data())
        }
    }

    func onlineSources() async throws -> [ReaderOnlineSource] {
        guard !closed else { throw Failure.teardown }
        let index = sourceReadCount; sourceReadCount += 1
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                sourceReads[index] = continuation; onSourcesEntered?(index)
            }
        }, onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.cancelledSources.insert(index).inserted else { return }
                self.onSourcesCancelled?(index)
            }
        })
    }

    func searchSource(_ sourceID: String, keyword: String, page: Int) async throws -> ReaderSourceSearchResult {
        guard !closed else { throw Failure.teardown }
        let index = searchCalls.count
        searchCalls.append(.init(sourceID: sourceID, keyword: keyword, page: page))
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                searches[index] = continuation; onSearchEntered?(index + 1)
            }
        }, onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.cancelledSearches.insert(index).inserted else { return }
                self.onSearchCancelled?(index)
            }
        })
    }

    func completeSources(_ index: Int, with result: Result<[ReaderOnlineSource], Error>) throws {
        guard let continuation = sourceReads.removeValue(forKey: index) else {
            XCTFail("The exact source read has not entered"); throw Failure.missingContinuation
        }
        continuation.resume(with: result)
    }
    func completeSearch(_ index: Int, books: [ReaderOnlineCandidate]? = nil, elapsedMilliseconds: Int? = nil) throws {
        guard let continuation = searches.removeValue(forKey: index) else {
            XCTFail("The exact search read has not entered"); throw Failure.missingContinuation
        }
        let call = searchCalls[index]
        continuation.resume(returning: .init(sourceId: call.sourceID,
            books: books ?? [.init(sourceId: call.sourceID, bookId: "candidate-\(index)", title: "Candidate identity \(index)")],
            elapsedMilliseconds: elapsedMilliseconds ?? 10 + index, timing: nil))
    }
    func completeRemainingSearches() throws { for index in searches.keys.sorted() { try completeSearch(index) } }
    func failSearch(_ index: Int) throws {
        guard let continuation = searches.removeValue(forKey: index) else {
            XCTFail("The exact search read has not entered"); throw Failure.missingContinuation
        }
        continuation.resume(throwing: Failure.lateRead)
    }
    func failDetail(_ index: Int) throws {
        guard let continuation = details.removeValue(forKey: index) else {
            XCTFail("The exact detail read has not entered"); throw Failure.missingContinuation
        }
        continuation.resume(throwing: Failure.lateRead)
    }
    func releaseAll() {
        closed = true
        onSourcesEntered = nil; onSourcesCancelled = nil; onSearchEntered = nil; onSearchCancelled = nil
        onDetailEntered = nil; onDetailCancelled = nil
        let pendingDetails = details; details.removeAll()
        let reads = sourceReads; sourceReads.removeAll()
        let pendingSearches = searches; searches.removeAll()
        for continuation in pendingDetails.values { continuation.resume(throwing: Failure.teardown) }
        for continuation in reads.values { continuation.resume(throwing: Failure.teardown) }
        for continuation in pendingSearches.values { continuation.resume(throwing: Failure.teardown) }
    }

    private func unexpectedRead<T>(_ name: String) throws -> T {
        XCTFail("Unselected read boundary: \(name)"); throw Failure.unsupported
    }
    private func forbiddenWrite<T>(_ name: String) throws -> T {
        writeCalls.append(name); XCTFail("Discovery crossed write boundary: \(name)"); throw Failure.unsupported
    }
    func listBooks() async throws -> [ReaderBook] { try unexpectedRead("listBooks") }
    func chapters(for book: ReaderBook) async throws -> [ReaderChapter] { try unexpectedRead("chapters") }
    func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent { try unexpectedRead("content") }
    func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot { try unexpectedRead("progress") }
    func pendingImports() async throws -> [ReaderPendingImport] { try unexpectedRead("pendingImports") }
    func importBook(at url: URL) async throws -> ReaderImportResult { try forbiddenWrite("importBook") }
    func reconcilePendingProgress(for book: ReaderBook) async throws -> ReaderProgressSnapshot? { try forbiddenWrite("reconcilePendingProgress") }
    func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                      expectedRevision: String?) async throws -> ReaderProgressSnapshot { try forbiddenWrite("saveProgress") }
    func flush() async throws { let _: Void = try forbiddenWrite("flush") }
    func close() async throws { let _: Void = try forbiddenWrite("close") }
    func recoverPendingImports() async throws -> [ReaderPendingImport] { try forbiddenWrite("recoverPendingImports") }
    func importSources(_ data: Data, operationID: String) async throws -> [ReaderSourceImportItem] { try forbiddenWrite("importSources") }
    func updateSource(_ sourceID: String, enabled: Bool, operationID: String) async throws { let _: Void = try forbiddenWrite("updateSource") }
    func deleteSource(_ sourceID: String, operationID: String) async throws { let _: Void = try forbiddenWrite("deleteSource") }
    func addOnlineBook(_ detail: ReaderOnlineDetail, chapterIndex: UInt32, operationID: String) async throws -> ReaderBook { try forbiddenWrite("addOnlineBook") }
    func completeLogin(_ sourceID: String, cookies: [HTTPCookie], originalCookies: [HTTPCookie]) async throws { let _: Void = try forbiddenWrite("completeLogin") }
    func onlineCommand(_ method: String, parameters: Data, operationID: String?) async throws -> Data { try forbiddenWrite("onlineCommand") }
    func validateSources(_ data: Data) async throws -> [ReaderSourceImportItem] { try unexpectedRead("validateSources") }
    func exportSources(_ identities: [String]?) async throws -> Data { try unexpectedRead("exportSources") }
    func onlineDetail(_ candidate: ReaderOnlineCandidate) async throws -> ReaderOnlineDetail {
        guard !closed else { throw Failure.teardown }
        let index = detailReadCount; detailReadCount += 1
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                details[index] = continuation; onDetailEntered?(index)
            }
        }, onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.cancelledDetails.insert(index).inserted else { return }
                self.onDetailCancelled?(index)
            }
        })
    }
    func refreshOnlineCatalog(for book: ReaderBook) async throws -> ReaderOnlineDetail { try unexpectedRead("refreshOnlineCatalog") }
    func onlineDiagnostic(_ sourceID: String, keyword: String) async throws -> Data { try unexpectedRead("onlineDiagnostic") }
    func onlineFetch(_ url: URL) async throws -> Data { try unexpectedRead("onlineFetch") }
    func prepareLogin(_ sourceID: String) async throws -> [HTTPCookie] { try unexpectedRead("prepareLogin") }
}


/// Controls only the finite OS/foreground opportunity boundary. It does not
/// emulate a package, HTTP response, subscription ACK, source parser or Book.
@MainActor
private final class DiscoverySubscriptionOpportunityGate {
    private(set) var checks = 0
    var onEntered: (() -> Void)?
    private var continuation: CheckedContinuation<[String], Error>?
    func check() async throws -> [String] {
        checks += 1
        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation; onEntered?()
        }
    }
    func complete(failures: [String] = []) {
        let current = continuation; continuation = nil; current?.resume(returning: failures)
    }
    func release() {
        onEntered = nil
        let current = continuation; continuation = nil
        current?.resume(throwing: DiscoveryControlledService.Failure.teardown)
    }
}

/// These continuations exercise only the Host's use of Core admission results.
/// They do not implement matching or prove any source, Core query or device path.
@MainActor
final class ReaderSwitchCandidateAdmissionTests: XCTestCase {
    func testOnlyCoreAdmittedSnapshotIsSelectableAfterCoalescedWorkspaceChanges() async throws {
        let state = ReaderOnlineWorkspaceModel(), service = SwitchAdmissionControlledService()
        let owner = ReaderSwitchCandidateAdmission(state: state)
        let presentation = UUID(), session = UUID()
        let book = ReaderBook(sourceId: "origin|source", bookId: "original|book", title: "Current title", author: "Current author")
        let admitted = ReaderOnlineCandidate(sourceId: "admitted-source", bookId: "admitted-book", title: "Current title", author: "Current author")
        let unrelated = ReaderOnlineCandidate(sourceId: "other-source", bookId: "other-book", title: "Different title", author: "Different author")
        state.activateDiscoveryPresentation(presentation)
        defer { owner.retire(presentationID: presentation); state.retireCachedDiscovery(); service.releaseAll() }
        let entered = expectation(description: "One coalesced admission read entered")
        service.onEntered = { index in
            XCTAssertEqual(index, 0, "Batched workspace publications must not start per-row reads")
            entered.fulfill()
        }
        owner.activate(book: book, sessionID: session, presentationID: presentation, service: service)
        state.query = "the retained query"
        state.sources = DiscoveryControlledService.sources(2)
        state.results = [admitted]
        state.results = [admitted, unrelated]
        await fulfillment(of: [entered], timeout: 2)
        XCTAssertEqual(owner.currentPhase, .pending)
        XCTAssertNil(owner.currentSnapshot, "Unfiltered search rows cannot be a pending-admission fallback")
        XCTAssertEqual(service.calls.count, 1)
        XCTAssertEqual(service.calls[0].book, book, "Use the actual ReaderBook rather than parsing its joined ID")
        XCTAssertEqual(service.calls[0].candidates, [admitted, unrelated])
        try service.complete(0, with: .success([admitted]))
        await waitForAdmission(owner) { $0?.candidates == [admitted] }
        let snapshot = try XCTUnwrap(owner.currentSnapshot)
        XCTAssertEqual(owner.currentPhase, .ready)
        XCTAssertEqual(owner.candidate(admitted, generation: snapshot.generation), admitted)
        XCTAssertNil(owner.candidate(unrelated, generation: snapshot.generation), "A raw result absent from Core admission is never selectable")
        let changedRow = ReaderOnlineCandidate(sourceId: admitted.sourceId, bookId: admitted.bookId,
            title: "A later rendered title", author: admitted.author)
        XCTAssertNil(owner.candidate(changedRow, generation: snapshot.generation), "An ID alone cannot adopt a different rendered snapshot")
        XCTAssertNil(owner.candidate(admitted, generation: UUID()), "A row must retain its admission generation")
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testResultAndSourceChangesInvalidateAdmissionAndRejectCancelledLateReads() async throws {
        let state = ReaderOnlineWorkspaceModel(), service = SwitchAdmissionControlledService()
        let owner = ReaderSwitchCandidateAdmission(state: state)
        let presentation = UUID(), book = ReaderBook(sourceId: "origin", bookId: "book", title: "Current")
        let first = ReaderOnlineCandidate(sourceId: "candidate-source", bookId: "first", title: "Current")
        let replacement = ReaderOnlineCandidate(sourceId: "candidate-source", bookId: "replacement", title: "Current")
        let source = ReaderOnlineSource(sourceId: "candidate-source", name: "Source", baseURL: "", enabled: true,
            version: "version-1", group: "", definition: Data())
        state.sources = [source]; state.results = [first]
        state.activateDiscoveryPresentation(presentation)
        defer { owner.retire(presentationID: presentation); state.retireCachedDiscovery(); service.releaseAll() }
        let firstRead = expectation(description: "Original admission entered")
        let changedResultsRead = expectation(description: "Changed candidate snapshot entered")
        let changedSourceRead = expectation(description: "Changed source version entered")
        let staleReadCancelled = expectation(description: "Superseded candidate read observed cancellation")
        service.onEntered = { index in
            if index == 0 { firstRead.fulfill() }
            else if index == 1 { changedResultsRead.fulfill() }
            else if index == 2 { changedSourceRead.fulfill() }
            else { XCTFail("Only the three selected input snapshots may read admission") }
        }
        service.onCancelled = { index in if index == 1 { staleReadCancelled.fulfill() } }
        owner.activate(book: book, sessionID: UUID(), presentationID: presentation, service: service)
        await fulfillment(of: [firstRead], timeout: 2)
        try service.complete(0, with: .success([first]))
        await waitForAdmission(owner) { $0?.candidates == [first] }
        let original = try XCTUnwrap(owner.currentSnapshot)
        state.results = [replacement]
        XCTAssertNil(owner.currentSnapshot, "The live input must close the old click gate before deferred reconciliation")
        XCTAssertNil(owner.candidate(first, generation: original.generation))
        await fulfillment(of: [changedResultsRead], timeout: 2)
        state.sources = [.init(sourceId: source.sourceId, name: source.name, baseURL: source.baseURL,
            enabled: source.enabled, version: "version-2", group: source.group, definition: source.definition)]
        XCTAssertNil(owner.currentSnapshot)
        await fulfillment(of: [staleReadCancelled, changedSourceRead], timeout: 2)
        try service.complete(1, with: .success([first]))
        XCTAssertNil(owner.candidate(first, generation: original.generation))
        try service.complete(2, with: .success([replacement]))
        await waitForAdmission(owner) { $0?.candidates == [replacement] }
        let current = try XCTUnwrap(owner.currentSnapshot)
        XCTAssertNotEqual(current.generation, original.generation)
        XCTAssertEqual(owner.candidate(replacement, generation: current.generation), replacement)
        XCTAssertNil(owner.candidate(first, generation: original.generation))
        XCTAssertEqual(service.calls.count, 3)
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testReopenedActualBookScopeAndRetirementRejectOldReadsWithoutTouchingAcceptedAction() async throws {
        let state = ReaderOnlineWorkspaceModel(), service = SwitchAdmissionControlledService()
        let owner = ReaderSwitchCandidateAdmission(state: state)
        let originalPresentation = UUID(), reopenedPresentation = UUID(), session = UUID()
        let originalBook = ReaderBook(sourceId: "origin|part", bookId: "book", title: "Current", author: "Author")
        let reopenedBook = ReaderBook(sourceId: "origin", bookId: "part|book", title: "Current", author: "Author")
        XCTAssertEqual(originalBook.id, reopenedBook.id, "The DTO's joined ID does not replace its separate canonical fields")
        let candidate = ReaderOnlineCandidate(sourceId: "candidate", bookId: "other", title: "Current", author: "Author")
        state.results = [candidate]
        state.activateDiscoveryPresentation(originalPresentation)
        defer { owner.retire(presentationID: reopenedPresentation); state.retireCachedDiscovery(); service.releaseAll() }
        let firstRead = expectation(description: "Original book admission entered")
        let reopenedRead = expectation(description: "Reopened actual book admission entered")
        let retiredReadCancelled = expectation(description: "Retirement cancelled only the active admission read")
        service.onEntered = { index in
            if index == 0 { firstRead.fulfill() }
            else if index == 1 { reopenedRead.fulfill() }
            else { XCTFail("Only the two selected presentation scopes may read admission") }
        }
        service.onCancelled = { index in if index == 1 { retiredReadCancelled.fulfill() } }
        owner.activate(book: originalBook, sessionID: session, presentationID: originalPresentation, service: service)
        await fulfillment(of: [firstRead], timeout: 2)
        try service.complete(0, with: .success([candidate]))
        await waitForAdmission(owner) { $0?.candidates == [candidate] }
        let original = try XCTUnwrap(owner.currentSnapshot)
        state.retireDiscoveryPresentation(originalPresentation)
        state.activateDiscoveryPresentation(reopenedPresentation)
        owner.activate(book: reopenedBook, sessionID: UUID(), presentationID: reopenedPresentation, service: service)
        XCTAssertNil(owner.currentSnapshot)
        XCTAssertNil(owner.candidate(candidate, generation: original.generation))
        await fulfillment(of: [reopenedRead], timeout: 2)
        XCTAssertEqual(service.calls[1].book.sourceId, reopenedBook.sourceId)
        XCTAssertEqual(service.calls[1].book.bookId, reopenedBook.bookId)
        let acceptedID = "bb0d0fdc-32bd-48d6-9b6b-51416922132c"
        var acceptedWriteExecutions = 0
        XCTAssertTrue(state.actions.restoreAccepted(id: acceptedID, label: "原换源操作", scope: reopenedBook.id) { _ in
            acceptedWriteExecutions += 1
            XCTFail("Admission retirement must not execute or replay an accepted write")
            throw SwitchAdmissionControlledService.Failure.unsupported
        })
        owner.retire(presentationID: originalPresentation)
        XCTAssertEqual(owner.currentPhase, .pending, "A retired old presentation cannot close the reopened read")
        owner.retire(presentationID: reopenedPresentation)
        await fulfillment(of: [retiredReadCancelled], timeout: 2)
        try service.complete(1, with: .success([candidate]))
        await Task.yield()
        XCTAssertEqual(owner.currentPhase, .inactive)
        XCTAssertNil(owner.currentSnapshot)
        XCTAssertNil(owner.candidate(candidate, generation: original.generation))
        XCTAssertEqual(state.actions.pendingOperationID, acceptedID)
        XCTAssertEqual(state.actions.scope, reopenedBook.id)
        XCTAssertTrue(state.actions.hasPending); XCTAssertFalse(state.actions.busy)
        XCTAssertEqual(acceptedWriteExecutions, 0)
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    func testLegacyServiceWithoutCoreCandidateAdmissionFailsClosedAndRetryRemainsReadOnly() async throws {
        let state = ReaderOnlineWorkspaceModel(), legacy = DiscoveryControlledService()
        let owner = ReaderSwitchCandidateAdmission(state: state)
        let presentation = UUID()
        let raw = ReaderOnlineCandidate(sourceId: "legacy-source", bookId: "raw-result", title: "Current")
        state.results = [raw]; state.activateDiscoveryPresentation(presentation)
        defer { owner.retire(presentationID: presentation); state.retireCachedDiscovery(); legacy.releaseAll() }
        owner.activate(book: ReaderBook(sourceId: "origin", bookId: "book", title: "Current"), sessionID: UUID(),
            presentationID: presentation, service: legacy)
        await waitForFailure(owner)
        XCTAssertNil(owner.currentSnapshot, "Legacy search support cannot supply selectable raw fallback candidates")
        XCTAssertNil(owner.candidate(raw, generation: UUID()))
        owner.retry()
        await waitForFailure(owner)
        XCTAssertNil(owner.currentSnapshot)
        XCTAssertEqual(legacy.sourceReadCount, 0); XCTAssertTrue(legacy.searchCalls.isEmpty)
        XCTAssertTrue(legacy.writeCalls.isEmpty)
    }

    func testAdmissionReadFailureIsNotConfirmedEmptyAndRetryUsesOnlyTheSameReadScope() async throws {
        let state = ReaderOnlineWorkspaceModel(), service = SwitchAdmissionControlledService()
        let owner = ReaderSwitchCandidateAdmission(state: state)
        let presentation = UUID(), book = ReaderBook(sourceId: "origin", bookId: "book", title: "Current")
        let candidate = ReaderOnlineCandidate(sourceId: "candidate", bookId: "other", title: "Current")
        state.results = [candidate]; state.activateDiscoveryPresentation(presentation)
        defer { owner.retire(presentationID: presentation); state.retireCachedDiscovery(); service.releaseAll() }
        let originalRead = expectation(description: "Original admission read entered")
        let retryRead = expectation(description: "Only the original admission read was retried")
        service.onEntered = { index in
            if index == 0 { originalRead.fulfill() }
            else if index == 1 { retryRead.fulfill() }
            else { XCTFail("Local retry cannot create additional discovery or write work") }
        }
        owner.activate(book: book, sessionID: UUID(), presentationID: presentation, service: service)
        await fulfillment(of: [originalRead], timeout: 2)
        try service.complete(0, with: .failure(SwitchAdmissionControlledService.Failure.unsupported))
        await waitForFailure(owner)
        XCTAssertNil(owner.currentSnapshot, "An admission error cannot become a confirmed empty candidate list")
        owner.retry()
        XCTAssertEqual(owner.currentPhase, .pending); XCTAssertNil(owner.currentSnapshot)
        await fulfillment(of: [retryRead], timeout: 2)
        XCTAssertEqual(service.calls[1].book, service.calls[0].book)
        XCTAssertEqual(service.calls[1].candidates, service.calls[0].candidates)
        try service.complete(1, with: .success([]))
        await waitForAdmission(owner) { $0?.candidates.isEmpty == true }
        XCTAssertEqual(owner.currentPhase, .ready, "Only a successful Core read can confirm an empty admitted relation")
        XCTAssertEqual(state.results, [candidate], "A local admission retry does not rewrite the retained discovery rows")
        XCTAssertTrue(service.writeCalls.isEmpty)
    }

    private func waitForAdmission(_ owner: ReaderSwitchCandidateAdmission,
                                  matching condition: @escaping (ReaderSwitchCandidateAdmission.Snapshot?) -> Bool) async {
        let ready = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition(owner.currentSnapshot) }, object: nil)
        await fulfillment(of: [ready], timeout: 2)
    }
    private func waitForFailure(_ owner: ReaderSwitchCandidateAdmission) async {
        let failed = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            if case .failed = owner.currentPhase { return true }; return false
        }, object: nil)
        await fulfillment(of: [failed], timeout: 2)
    }
}

@MainActor
private final class SwitchAdmissionControlledService: ReaderSourceSwitchCandidateServing {
    enum Failure: Error { case unsupported, teardown, missingContinuation }
    struct Call { let book: ReaderBook; let candidates: [ReaderOnlineCandidate] }
    private(set) var calls: [Call] = []
    private(set) var cancelled = Set<Int>()
    private(set) var writeCalls: [String] = []
    var onEntered: ((Int) -> Void)?
    var onCancelled: ((Int) -> Void)?
    private var reads: [Int: CheckedContinuation<[ReaderOnlineCandidate], Error>] = [:]
    private var closed = false

    func sourceSwitchCandidates(for book: ReaderBook, among candidates: [ReaderOnlineCandidate]) async throws -> [ReaderOnlineCandidate] {
        guard !closed else { throw Failure.teardown }
        let index = calls.count; calls.append(.init(book: book, candidates: candidates))
        return try await withTaskCancellationHandler(operation: {
            try await withCheckedThrowingContinuation { continuation in
                reads[index] = continuation; onEntered?(index)
            }
        }, onCancel: { [weak self] in
            Task { @MainActor in
                guard let self, self.cancelled.insert(index).inserted else { return }
                self.onCancelled?(index)
            }
        })
    }
    func complete(_ index: Int, with result: Result<[ReaderOnlineCandidate], Error>) throws {
        guard let continuation = reads.removeValue(forKey: index) else {
            XCTFail("The selected admission read has not entered"); throw Failure.missingContinuation
        }
        continuation.resume(with: result)
    }
    func releaseAll() {
        closed = true; onEntered = nil; onCancelled = nil
        let pending = reads; reads.removeAll()
        for continuation in pending.values { continuation.resume(throwing: Failure.teardown) }
    }
    private func unexpectedRead<T>(_ name: String) throws -> T {
        XCTFail("Unselected admission read boundary: \(name)"); throw Failure.unsupported
    }
    private func forbiddenWrite<T>(_ name: String) throws -> T {
        writeCalls.append(name); XCTFail("Candidate admission crossed write boundary: \(name)"); throw Failure.unsupported
    }
    func listBooks() async throws -> [ReaderBook] { try unexpectedRead("listBooks") }
    func chapters(for book: ReaderBook) async throws -> [ReaderChapter] { try unexpectedRead("chapters") }
    func content(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderChapterContent { try unexpectedRead("content") }
    func progress(for book: ReaderBook) async throws -> ReaderProgressSnapshot { try unexpectedRead("progress") }
    func pendingImports() async throws -> [ReaderPendingImport] { try unexpectedRead("pendingImports") }
    func importBook(at url: URL) async throws -> ReaderImportResult { try forbiddenWrite("importBook") }
    func reconcilePendingProgress(for book: ReaderBook) async throws -> ReaderProgressSnapshot? { try forbiddenWrite("reconcilePendingProgress") }
    func saveProgress(for book: ReaderBook, content: ReaderChapterContent, scalarOffset: UInt64,
                      expectedRevision: String?) async throws -> ReaderProgressSnapshot { try forbiddenWrite("saveProgress") }
    func flush() async throws { let _: Void = try forbiddenWrite("flush") }
    func close() async throws { let _: Void = try forbiddenWrite("close") }
    func recoverPendingImports() async throws -> [ReaderPendingImport] { try forbiddenWrite("recoverPendingImports") }
}
