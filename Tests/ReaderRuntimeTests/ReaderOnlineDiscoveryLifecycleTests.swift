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
        let retained = ReaderOnlineCandidate(sourceId: "retained-source", bookId: "retained-book", title: "Retained candidate")
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
    func completeSearch(_ index: Int) throws {
        guard let continuation = searches.removeValue(forKey: index) else {
            XCTFail("The exact search read has not entered"); throw Failure.missingContinuation
        }
        let call = searchCalls[index]
        continuation.resume(returning: .init(sourceId: call.sourceID,
            books: [.init(sourceId: call.sourceID, bookId: "candidate-\(index)", title: "Candidate identity \(index)")],
            elapsedMilliseconds: 10 + index, timing: nil))
    }
    func completeRemainingSearches() throws { for index in searches.keys.sorted() { try completeSearch(index) } }
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
