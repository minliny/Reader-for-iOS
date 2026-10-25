import CryptoKit
import Foundation
import XCTest
#if canImport(ReaderCoreClient)
import ReaderCoreClient
#endif
#if canImport(ReaderRuntime)
@testable import ReaderRuntime
#else
@testable import Reader
#endif

final class ReaderOnlineRuntimeTests: XCTestCase {
    func testCancelledWebViewResultDoesNotCommitCookieChanges() throws {
        XCTAssertTrue(ReaderSourceWebBridge.shouldCommitCookies(for: .success([:])))
        XCTAssertTrue(ReaderSourceWebBridge.shouldCommitCookies(for: .failure(URLError(.timedOut))))
        XCTAssertFalse(ReaderSourceWebBridge.shouldCommitCookies(for: .failure(URLError(.cancelled))))
        XCTAssertFalse(ReaderSourceWebBridge.shouldCommitCookies(for: .failure(CancellationError())))
    }

    func testNativeHTTPReachesTheRealSourceOriginOrItsRedirect() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let definitions = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json"))) as? [[String: Any]])
        var address = try XCTUnwrap(URLComponents(string: try XCTUnwrap(definitions.first?["bookSourceUrl"] as? String)))
        address.scheme = "http"
        let url = try XCTUnwrap(address.url)
        let transport = ReaderIOSHostTransport(namespace: "real-http-policy:" + UUID().uuidString)
        let response = try await transport.fetchPackage(at: url)
        XCTAssertTrue((100..<600).contains(response.status), "A real HTTP response, including a source rejection, proves transport reached the source; a fabricated successful body cannot substitute")
        let facts = try JSONSerialization.data(withJSONObject: ["requestURL": url.absoluteString, "status": response.status, "finalURL": response.finalUrl ?? ""], options: [.sortedKeys])
        let attachment = XCTAttachment(data: facts, uniformTypeIdentifier: "public.json")
        attachment.name = "Actual-native-HTTP-source-response"; attachment.lifetime = .keepAlways; add(attachment)
    }

    func testNativeCookieJarsAreSourceIsolatedAndRestoreOnlyWithinTheSameLibrary() throws {
        let namespace = "transport-test:" + UUID().uuidString
        let first = ReaderIOSHostTransport(namespace: namespace)
        let url = try XCTUnwrap(URL(string: "https://reader-cookie.invalid/"))
        let cookie = try XCTUnwrap(HTTPCookie(properties: [.domain: "reader-cookie.invalid", .path: "/", .name: "session", .value: "method-fixture", .secure: "TRUE"]))
        first.cookieJar(sourceID: "source-a").setCookie(cookie)
        XCTAssertFalse(first.cookieJar(sourceID: "source-a") === first.cookieJar(sourceID: "source-b"))
        XCTAssertEqual(first.cookieJar(sourceID: "source-a").cookies(for: url)?.count, 1)
        XCTAssertTrue(first.cookieJar(sourceID: "source-b").cookies(for: url)?.isEmpty ?? true)
        try first.persistCookies(sourceID: "source-a")
        let reopened = ReaderIOSHostTransport(namespace: namespace)
        XCTAssertEqual(reopened.cookieJar(sourceID: "source-a").cookies(for: url)?.count, 1)
        let jar = reopened.cookieJar(sourceID: "source-a")
        let baseline = jar.cookies ?? []
        let concurrent = try XCTUnwrap(HTTPCookie(properties: [.domain: "reader-cookie.invalid", .path: "/", .name: "concurrent-http", .value: "new-session", .secure: "TRUE"]))
        jar.setCookie(concurrent)
        ReaderIOSHostTransport.mergeCookieChanges(original: baseline, updated: baseline, into: jar)
        XCTAssertTrue(jar.cookies?.contains(where: { $0.name == concurrent.name && $0.value == concurrent.value }) ?? false,
            "An unchanged WebKit snapshot cannot erase a concurrent native HTTP cookie")
        let nativeParsed = try XCTUnwrap(HTTPCookie.cookies(withResponseHeaderFields: ["Set-Cookie": "server=native-response; Path=/; Secure; HttpOnly"], for: url).first)
        jar.setCookie(nativeParsed)
        try reopened.persistCookies(sourceID: "source-a")
        let restoredAgain = ReaderIOSHostTransport(namespace: namespace)
        XCTAssertTrue(restoredAgain.cookieJar(sourceID: "source-a").cookies?.contains(where: { $0.name == "server" && $0.isHTTPOnly }) ?? false)
        let anotherLibrary = ReaderIOSHostTransport(namespace: namespace + ":other")
        XCTAssertTrue(anotherLibrary.cookieJar(sourceID: "source-a").cookies(for: url)?.isEmpty ?? true)
        // Remove method credentials using the same public native jar boundary.
        for cookie in reopened.cookieJar(sourceID: "source-a").cookies ?? [] { reopened.cookieJar(sourceID: "source-a").deleteCookie(cookie) }
        try reopened.persistCookies(sourceID: "source-a")
    }

    /// Real original source bytes exercise the Host DTO/finite receipt boundary.
    /// This method provides preview bytes explicitly and does not claim that a
    /// subscription URL was fetched or that an OS background task executed.
    func testOriginalSourcePackageManagementAndSubscriptionPlanUseActualCoreReceipts() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let package = try Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json"))
        XCTAssertEqual(SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined(), "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322")
        let definitions = try XCTUnwrap(JSONSerialization.jsonObject(with: package) as? [[String: Any]])
        let first = try XCTUnwrap(definitions.first)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealSourceManagement-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        do {
            let validation = try await service.validateSources(package)
            XCTAssertTrue(validation.allSatisfy(\.succeeded))
            let imported = try await service.importSources(JSONSerialization.data(withJSONObject: first), operationID: UUID().uuidString)
            XCTAssertTrue(imported.allSatisfy(\.succeeded))
            let initial = try await service.onlineSources()
            XCTAssertEqual(initial.count, 1)
            let subscription = ReaderSourceSubscription(id: 73, name: "原书源包方法验证", url: "https://m.idejian.com", type: 0, customOrder: 0, autoUpdate: false, update: 0)
            let putID = UUID().uuidString
            let saved = try await service.saveRuleSubscription(subscription, operationID: putID)
            let repeatedSave = try await service.saveRuleSubscription(subscription, operationID: putID)
            XCTAssertEqual(repeatedSave, saved)
            let parameters = try JSONSerialization.data(withJSONObject: ["subscriptionId": saved.id, "remoteJson": String(decoding: package, as: UTF8.self)])
            let data = try await service.performCoreCommand(method: "rule-sub.update.preview.v1", parameters: parameters)
            let plan = try JSONDecoder().decode(ReaderSubscriptionPlan.self, from: data)
            XCTAssertEqual(plan.subscriptionId, saved.id)
            XCTAssertTrue(plan.changes.contains(where: { $0.kind == "added" }))
            let safe = plan.changes.filter(\.safeToApply).map(\.sourceId)
            let applyID = UUID().uuidString
            let applied = try await service.applyRuleSubscription(plan, sourceIDs: safe, operationID: applyID)
            let repeated = try await service.applyRuleSubscription(plan, sourceIDs: safe, operationID: applyID)
            XCTAssertEqual(applied, repeated)
            let allSources = try await service.onlineSources()
            XCTAssertEqual(allSources.count, 2)
            let firstID = try XCTUnwrap(initial.first).id
            try await service.updateSource(firstID, enabled: false, operationID: UUID().uuidString)
            let changedSources = try await service.onlineSources()
            XCTAssertEqual(changedSources.first(where: { $0.id == firstID })?.enabled, false)
            let exported = try await service.exportSources(nil)
            XCTAssertEqual((try JSONSerialization.jsonObject(with: exported) as? [[String: Any]])?.count, 2)
            let second = try XCTUnwrap(changedSources.first(where: { $0.id != firstID }))
            try await service.deleteSource(second.id, operationID: UUID().uuidString)
            let remaining = try await service.onlineSources()
            XCTAssertEqual(remaining.map(\.id), [firstID])
            try await service.deleteRuleSubscription(saved, operationID: UUID().uuidString)
            let subscriptions = try await service.ruleSubscriptions()
            XCTAssertTrue(subscriptions.isEmpty)
            XCTAssertEqual(try Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json")), package)
            try await service.close()
        } catch { try? await service.close(); throw error }
    }

    /// These are original source definitions selected from the frozen real
    /// HarmonyOS package, not a synthetic successful HTTP/rule replay. Failures
    /// remain real failures and cannot be replaced by an in-process response.
    func testRealStoredSourcesSearchDetailShelfAndCachedBody() async throws {
        let documents = try XCTUnwrap(FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first)
        let package = try Data(contentsOf: documents.appendingPathComponent("Reader-real-sources.json"))
        XCTAssertEqual(SHA256.hash(data: package).map { String(format: "%02x", $0) }.joined(), "f26fa3bd2c9928f8a40a374e5af09dd747a484ff5094f8baf19b880c6f8ea322")
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealOnline-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
        do {
            let imported = try await service.importSources(package, operationID: UUID().uuidString)
            XCTAssertEqual(imported.count, 2)
            XCTAssertTrue(imported.allSatisfy(\.succeeded), "Real source import must preserve the original terminal facts")
            let sources = try await service.onlineSources().filter(\.enabled)
            XCTAssertEqual(sources.count, 2)
            var successful: ReaderOnlineCandidate?
            var outcomes: [[String: Any]] = []
            for source in sources {
                do {
                    let result = try await service.searchSource(source.id, keyword: "剑来", page: 1)
                    outcomes.append(["sourceId": source.id, "count": result.books.count, "elapsedMilliseconds": result.elapsedMilliseconds])
                    if successful == nil { successful = result.books.first }
                } catch { outcomes.append(["sourceId": source.id, "failure": error.localizedDescription]) }
            }
            let diagnostic = try JSONSerialization.data(withJSONObject: outcomes, options: [.prettyPrinted, .sortedKeys])
            let attachment = XCTAttachment(data: diagnostic, uniformTypeIdentifier: "public.json")
            attachment.name = "Actual-source-search-outcomes"; attachment.lifetime = .keepAlways; add(attachment)
            let candidate = try XCTUnwrap(successful, "At least one actual source must return a real candidate; no fixture fallback")
            let detail = try await service.onlineDetail(candidate)
            XCTAssertFalse(detail.chapters.isEmpty)
            let book = try await service.addOnlineBook(detail, chapterIndex: detail.firstReadableIndex, operationID: UUID().uuidString)
            XCTAssertEqual(book.sourceId, candidate.sourceId); XCTAssertEqual(book.bookId, candidate.bookId)
            let otherChapter = try XCTUnwrap(detail.chapters.dropFirst(3).first(where: { !$0.url.isEmpty && $0.index != detail.firstReadableIndex && $0.index < UInt32.max }))
            do {
                _ = try await service.performCoreCommand(method: "chapter.content", parameters: JSONSerialization.data(withJSONObject: [
                    "sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": otherChapter.index,
                    "chapterTitle": "", "cacheOnly": true
                ]))
                XCTFail("A real chapter outside the admission/cache window must not be reported as cached")
            } catch let error as ReaderLibraryError {
                guard case .core(let code, let message, _, let reason) = error else {
                    XCTFail("Expected the Core cache-missing category, received \(error)"); return
                }
                XCTAssertEqual(reason, "CACHE_MISSING", "Core cache-only failure category was lost: code=\(code) message=\(message)")
            }
            let content = try await service.content(for: book, chapterIndex: detail.firstReadableIndex)
            XCTAssertFalse(content.content.isEmpty); XCTAssertNotNil(content.bodyVersion); XCTAssertNotNil(content.processingVersion)
            let cached = try await service.performCoreCommand(method: "chapter.content", parameters: JSONSerialization.data(withJSONObject: ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": detail.firstReadableIndex, "chapterTitle": "", "cacheOnly": true]))
            let object = try XCTUnwrap(JSONSerialization.jsonObject(with: cached) as? [String: Any])
            XCTAssertEqual(object["via"] as? String, "cache")
            XCTAssertEqual(object["content"] as? String, content.content)
            let progress = try await service.progress(for: book)
            let saved = try await service.saveProgress(for: book, content: content, scalarOffset: min(37, content.scalarCount), expectedRevision: progress.progressRevision)
            XCTAssertEqual(saved.progress?.sourceId, candidate.sourceId)
            let downloadID = UUID().uuidString
            let downloaded = try await service.downloadChapters(book, range: otherChapter.index..<(otherChapter.index + 1), operationID: downloadID)
            XCTAssertTrue(downloaded.materializations.contains(where: { $0.chapterIndex == otherChapter.index && !$0.token.isEmpty }))
            let downloadedStatus = try await service.readerDownloadStatus(book)
            XCTAssertEqual(downloadedStatus.chapters.first(where: { $0.chapterIndex == otherChapter.index })?.state, .completed,
                "A prefetch terminal alone cannot complete a download; its original resource lease must be reported")
            try await service.close()
            let reopened = try ReaderLibraryService(storageURL: root.appendingPathComponent("Core"), sourceURL: root.appendingPathComponent("Sources"))
            let restored = try await reopened.progress(for: book)
            XCTAssertEqual(restored.progress?.chapterOffset, saved.progress?.chapterOffset)
            let toc = try await reopened.chapters(for: book)
            XCTAssertFalse(toc.isEmpty)
            let offline = try await reopened.performCoreCommand(method: "chapter.content", parameters: JSONSerialization.data(withJSONObject: ["sourceId": book.sourceId, "bookId": book.bookId, "chapterIndex": detail.firstReadableIndex, "chapterTitle": "", "cacheOnly": true]))
            XCTAssertEqual((try JSONSerialization.jsonObject(with: offline) as? [String: Any])?["content"] as? String, content.content)
            let coldDownload = try await reopened.readerDownloadStatus(book)
            XCTAssertEqual(coldDownload.chapters.first(where: { $0.chapterIndex == otherChapter.index })?.state, .completed)
            let downloadedBody = try await reopened.cachedDownloadBody(book, chapter: otherChapter.index)
            XCTAssertFalse(downloadedBody.content.isEmpty)
            let clearID = UUID().uuidString
            try await reopened.clearDownloadedChapter(book, chapterIndex: otherChapter.index, operationID: clearID)
            let cleared = try await reopened.readerDownloadStatus(book)
            XCTAssertEqual(cleared.chapters.first(where: { $0.chapterIndex == otherChapter.index })?.state, .missing)
            let afterClear = try await reopened.progress(for: book)
            XCTAssertEqual(afterClear.progress, restored.progress)
            let retainedBody = try await reopened.cachedDownloadBody(book, chapter: detail.firstReadableIndex)
            XCTAssertEqual(retainedBody.content, content.content)
            // Reopening the exact completed owner must not enqueue again after
            // an explicit later clear, or reinterpret fresh state as its ACK.
            _ = try await reopened.downloadChapters(book, range: otherChapter.index..<(otherChapter.index + 1), operationID: downloadID)
            try await reopened.clearDownloadedChapter(book, chapterIndex: otherChapter.index, operationID: clearID)
            let afterReplay = try await reopened.readerDownloadStatus(book)
            XCTAssertEqual(afterReplay.chapters.first(where: { $0.chapterIndex == otherChapter.index })?.state, .missing)
            try await reopened.close()
        } catch { try? await service.close(); throw error }
    }
}
