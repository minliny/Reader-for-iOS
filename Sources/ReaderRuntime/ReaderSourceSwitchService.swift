import Foundation
import CryptoKit

public struct ReaderOnlineSwitchResult: Sendable {
    public let book: ReaderBook
    public let content: ReaderChapterContent
    public let progressSnapshot: ReaderProgressSnapshot
    public let positionNotice: String?

    init(book: ReaderBook, content: ReaderChapterContent, progressSnapshot: ReaderProgressSnapshot,
         positionNotice: String? = nil) {
        self.book = book
        self.content = content
        self.progressSnapshot = progressSnapshot
        self.positionNotice = positionNotice
    }
}

/// Host-only intent captured before Core removes the original shelf position.
/// Keep a digest and a bounded literal context, never a second copy of the chapter.
struct ReaderSourceSwitchAnchor: Codable {
    let offset: UInt64
    let bodyDigest: Data
    let context: String
    let leadingUTF16Count: Int

    init(content: String, offset: UInt64) {
        self.offset = offset
        bodyDigest = Self.digest(content)
        let scalars = content.unicodeScalars
        let position = scalars.index(scalars.startIndex, offsetBy: Int(offset))
        let start = scalars.index(position, offsetBy: -24, limitedBy: scalars.startIndex) ?? scalars.startIndex
        let end = scalars.index(position, offsetBy: 24, limitedBy: scalars.endIndex) ?? scalars.endIndex
        context = String(scalars[start..<end])
        leadingUTF16Count = String(scalars[start..<position]).utf16.count
    }

    func resolve(in content: ReaderChapterContent) -> UInt64 {
        if offset <= content.scalarCount, bodyDigest == Self.digest(content.content) { return offset }
        guard context.unicodeScalars.count >= 16, leadingUTF16Count > 0,
              leadingUTF16Count <= context.utf16.count else { return 0 }
        let target = content.content as NSString
        let match = target.range(of: context, options: .literal)
        guard match.location != NSNotFound else { return 0 }
        // Search from the next code unit so overlapping occurrences count too.
        let remainder = NSRange(location: match.location + 1, length: target.length - match.location - 1)
        guard target.range(of: context, options: .literal, range: remainder).location == NSNotFound else { return 0 }
        return ReaderTextCoordinates.scalarOffset(in: content.content, utf16Offset: match.location + leadingUTF16Count)
    }

    private static func digest(_ text: String) -> Data { Data(SHA256.hash(data: Data(text.utf8))) }
}

/// Emitted only after the original rollback terminal confirmed the restored
/// identity. UI keeps its old session; a different operation may then be tried.
public struct ReaderSourceSwitchRolledBack: LocalizedError, Sendable {
    public let restoredBook: ReaderBook
    public let restoredProgressSnapshot: ReaderProgressSnapshot
    public let originalFailure: String
    public var errorDescription: String? { "换源未完成，已恢复原书。" + originalFailure }
}

/// Compensation is already acknowledged. Only a fresh session observation is
/// missing; retrying the same owner must never dispatch another switch write.
public struct ReaderSourceSwitchRefreshRequired: LocalizedError, Sendable {
    public let operationID: String
    public let restoredBook: ReaderBook
    public var errorDescription: String? { "原书已恢复，阅读进度尚未刷新。" }
}

public protocol ReaderSourceSwitchServing: ReaderLibraryServing {
    func switchOnlineBook(from: ReaderBook, currentChapterIndex: UInt32, currentChapterTitle: String,
                          candidate: ReaderOnlineCandidate, operationID: String) async throws -> ReaderOnlineSwitchResult
}

private struct ReaderSwitchCommit: Decodable {
    struct Chapter: Decodable { let order: Int32; let chapterTitle: String; let chapterUrl: String }
    let transactionId: String
    let phase: String
    let book: ReaderBook
    let matchedChapter: Chapter
    let strategy: String
}

extension ReaderLibraryService: ReaderSourceSwitchServing {
    public func switchOnlineBook(from book: ReaderBook, currentChapterIndex: UInt32, currentChapterTitle: String,
                                 candidate: ReaderOnlineCandidate, operationID: String) async throws -> ReaderOnlineSwitchResult {
        guard book.sourceId != "local", candidate.sourceId != "local",
              book.id != candidate.sourceId + "|" + candidate.bookId,
              !operationID.isEmpty else { throw ReaderLibraryError.invalidResponse("source switch identity") }
        guard !sourceSwitchInFlight else { throw ReaderLibraryError.busy }
        sourceSwitchInFlight = true
        defer { sourceSwitchInFlight = false }

        let parameters: [String: Any]
        let originalAnchor: ReaderSourceSwitchAnchor?
        if let original = try existingCoreParameters(operationID: operationID, method: "source.switch.commit") {
            guard let from = original["from"] as? [String: Any],
                  from["sourceId"] as? String == book.sourceId, from["bookId"] as? String == book.bookId,
                  let target = original["target"] as? [String: Any],
                  target["sourceId"] as? String == candidate.sourceId, target["bookId"] as? String == candidate.bookId,
                  (original["currentChapterIndex"] as? NSNumber)?.uint32Value == currentChapterIndex,
                  original["currentChapterTitle"] as? String == currentChapterTitle else {
                throw ReaderLibraryError.invalidResponse("source switch operation reused")
            }
            parameters = original
            originalAnchor = try recordedSourceSwitchAnchor(operationID: operationID)
        } else {
            // Admission installs the target's actual Core-owned catalog. Core
            // performs all title/order/fuzzy matching; Host supplies no matcher.
            let detail = try await onlineDetail(candidate)
            let head = try object(await coreRead("source.switch.transaction.query", ["operationId": operationID]))["head"] as? [String: Any]
            let sequence = (head?["sequence"] as? NSNumber)?.uint64Value ?? 0
            guard sequence < 9_007_199_254_740_991 else { throw ReaderLibraryError.invalidResponse("source switch sequence exhausted") }
            var target: [String: Any] = ["sourceId": detail.book.sourceId, "bookId": detail.book.bookId,
                                         "title": detail.book.title, "author": detail.book.author]
            if let value = detail.book.coverUrl { target["coverUrl"] = value }
            if let value = detail.book.intro { target["intro"] = value }
            if let value = detail.book.kind { target["kind"] = value }
            let toc: [[String: Any]] = try detail.chapters.map { chapter in
                guard let order = Int32(exactly: chapter.index), !chapter.url.isEmpty else {
                    throw ReaderLibraryError.invalidResponse("source switch catalog position")
                }
                return ["chapterId": chapter.url, "chapterTitle": chapter.title, "chapterUrl": chapter.url, "order": order]
            }
            parameters = ["operationId": coreLineageID(operationID, sequence: sequence + 1), "sequence": sequence + 1,
                "from": ["sourceId": book.sourceId, "bookId": book.bookId], "target": target, "newToc": toc,
                "currentChapterTitle": currentChapterTitle, "currentChapterIndex": currentChapterIndex,
                "strictCandidateAdmission": true,
                "updatedAt": Int64(Date().timeIntervalSince1970)]
            originalAnchor = try await confirmedSourceSwitchAnchor(for: book, chapterIndex: currentChapterIndex)
        }

        let commit = try decode(ReaderSwitchCommit.self, await coreMutation("source.switch.commit", parameters,
            operationID: operationID, scope: "source-switch", sourceSwitchAnchor: originalAnchor))
        guard commit.transactionId == parameters["operationId"] as? String, commit.phase == "pending",
              commit.book.sourceId == candidate.sourceId, commit.book.bookId == candidate.bookId,
              let chapterIndex = UInt32(exactly: commit.matchedChapter.order) else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        let finalizeID = operationID + ":finalize"
        let rollbackID = operationID + ":rollback"
        let canonicalID = operationID + ":canonical"
        guard let sequence = (parameters["sequence"] as? NSNumber)?.uint64Value, sequence > 0 else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        let finalize = try sourceSwitchStageParameters(transactionID: commit.transactionId, operationID: finalizeID,
                                                       method: "source.switch.finalize", sequence: sequence)
        let rollback = try sourceSwitchStageParameters(transactionID: commit.transactionId, operationID: rollbackID,
                                                       method: "source.switch.rollback", sequence: sequence)

        // A recorded compensation intent is resumed using only its original
        // terminal; a later available body cannot reverse that decision.
        if try existingCoreParameters(operationID: rollbackID, method: "source.switch.rollback") != nil {
            let restored = try await finishSourceSwitchRollback(rollback, operationID: operationID,
                rollbackID: rollbackID, original: book)
            throw ReaderSourceSwitchRolledBack(restoredBook: restored.book, restoredProgressSnapshot: restored.snapshot, originalFailure: "")
        }
        var canonicalAcknowledged = false
        let originalCanonical = try existingCoreParameters(operationID: canonicalID, method: "reading.progress.update")
        var canonicalOffset = (originalCanonical?["chapterOffset"] as? NSNumber)?.uint64Value
        let content: ReaderChapterContent
        do {
            if let originalCanonical {
                // The full original DTO is queried after cold restart; never
                // reissue it or substitute a fresh progress observation.
                _ = try await confirmSourceSwitchCanonical(originalCanonical, book: commit.book, operationID: canonicalID)
                canonicalAcknowledged = true
            }
            content = try await onlineContent(for: commit.book, chapterIndex: chapterIndex)
            guard content.sourceId == commit.book.sourceId, content.bookId == commit.book.bookId,
                  content.chapterIndex == chapterIndex, !content.content.isEmpty,
                  let bodyVersion = content.bodyVersion, let processingVersion = content.processingVersion else {
                throw ReaderLibraryError.invalidResponse("source switch target body")
            }
            if !canonicalAcknowledged {
                let observed = try await progress(for: commit.book)
                guard let revision = observed.progressRevision, !revision.isEmpty else { throw ReaderLibraryError.invalidPosition }
                if let position = observed.progress {
                    guard observed.found, position.sourceId == commit.book.sourceId, position.bookId == commit.book.bookId,
                          position.chapterIndex == chapterIndex, position.chapterOffset <= content.scalarCount else {
                        throw ReaderLibraryError.invalidPosition
                    }
                } else {
                    guard !observed.found else { throw ReaderLibraryError.invalidPosition }
                }
                let offset: UInt64
                if let originalAnchor {
                    offset = commit.strategy == "lastReadFallback" ? 0 : originalAnchor.resolve(in: content)
                } else if let position = observed.progress, position.bodyVersion == bodyVersion,
                          position.processingVersion == processingVersion {
                    // A legacy unfinished switch may already have a versioned target remap.
                    offset = position.chapterOffset
                } else {
                    offset = 0
                }
                canonicalOffset = offset
                let canonical: [String: Any] = ["transactionId": commit.transactionId,
                    "sourceId": commit.book.sourceId, "bookId": commit.book.bookId,
                    "chapterIndex": chapterIndex, "chapterOffset": offset,
                    "chapterProgress": content.scalarCount == 0 ? 0 : Double(offset) / Double(content.scalarCount),
                    "expectedBodyVersion": bodyVersion, "expectedProcessingVersion": processingVersion,
                    "expectedProgressRevision": revision, "updatedAt": Int64(Date().timeIntervalSince1970)]
                _ = try await confirmSourceSwitchCanonical(canonical, book: commit.book, operationID: canonicalID)
                canonicalAcknowledged = true
            }
        } catch {
            // An unknown canonical write may already have finalized atomically.
            // Only its original definite rejection permits compensation.
            let canonicalRecorded = try existingCoreParameters(operationID: canonicalID, method: "reading.progress.update") != nil
            if canonicalAcknowledged || (canonicalRecorded && !Self.isDefiniteMutationRejection(error)) {
                throw ReaderLibraryError.operationPending(operationID)
            }
            let restored = try await finishSourceSwitchRollback(rollback, operationID: operationID,
                rollbackID: rollbackID, original: book)
            throw ReaderSourceSwitchRolledBack(restoredBook: restored.book, restoredProgressSnapshot: restored.snapshot,
                originalFailure: error.localizedDescription)
        }
        // Canonical update already finalized in its SQLite transaction. This
        // explicit original finalize legitimately reports changed:false.
        try await confirmSourceSwitchFinalization(finalize, operationID: finalizeID)
        // Fresh state below is solely the new session observation after both
        // original terminals, including the current CAS revision after cold ACK recovery.
        let snapshot = try await progress(for: commit.book)
        guard let revision = snapshot.progressRevision, !revision.isEmpty,
              snapshot.progress.map({ $0.sourceId == commit.book.sourceId && $0.bookId == commit.book.bookId }) ?? !snapshot.found else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        let sessionContent: ReaderChapterContent
        if let position = snapshot.progress, position.chapterIndex != content.chapterIndex {
            sessionContent = try await onlineContent(for: commit.book, chapterIndex: position.chapterIndex)
            guard sessionContent.sourceId == commit.book.sourceId, sessionContent.bookId == commit.book.bookId,
                  sessionContent.chapterIndex == position.chapterIndex, !sessionContent.content.isEmpty,
                  sessionContent.bodyVersion != nil, sessionContent.processingVersion != nil else {
                throw ReaderLibraryError.operationPending(operationID)
            }
        } else { sessionContent = content }
        try await finishCoreOperation(operationID)
        let notice = originalAnchor != nil && canonicalOffset == 0
            ? "无法在新书源确认原阅读位置，已从匹配章节的开头继续。" : nil
        return .init(book: commit.book, content: sessionContent, progressSnapshot: snapshot, positionNotice: notice)
    }

    private func confirmedSourceSwitchAnchor(for book: ReaderBook, chapterIndex: UInt32) async throws -> ReaderSourceSwitchAnchor? {
        let saved = try await progress(for: book)
        guard let position = saved.progress, position.chapterIndex == chapterIndex, position.chapterOffset > 0 else { return nil }
        let original = try await reconcileOnlineContent(for: book, chapterIndex: chapterIndex)
        guard original.progressSnapshot == saved else { throw ReaderLibraryError.invalidPosition }
        return ReaderSourceSwitchAnchor(content: original.content.content, offset: position.chapterOffset)
    }

    private func sourceSwitchStageParameters(transactionID: String, operationID: String,
                                              method: String, sequence: UInt64) throws -> [String: Any] {
        if let original = try existingCoreParameters(operationID: operationID, method: method) {
            guard original["transactionId"] as? String == transactionID else { throw ReaderLibraryError.invalidResponse("source switch stage identity") }
            return original
        }
        return ["transactionId": transactionID, "operationId": coreLineageID(operationID, sequence: sequence), "sequence": sequence]
    }

    private func confirmSourceSwitchCanonical(_ parameters: [String: Any], book: ReaderBook,
                                               operationID: String) async throws -> ReaderProgressSnapshot {
        let data = try await coreMutation("reading.progress.update", parameters,
            operationID: operationID, scope: "source-switch-canonical")
        let receipt = try object(data)
        guard receipt["transactionId"] as? String == parameters["transactionId"] as? String,
              receipt["sourceSwitchFinalized"] as? Bool == true else { throw ReaderLibraryError.operationPending(operationID) }
        let snapshot = try progressReceipt(data, for: book)
        try await finishCoreOperation(operationID)
        return snapshot
    }

    private func confirmSourceSwitchFinalization(_ parameters: [String: Any], operationID: String) async throws {
        let receipt = try object(await coreMutation("source.switch.finalize", parameters,
            operationID: operationID, scope: "source-switch-terminal"))
        guard receipt["transactionId"] as? String == parameters["transactionId"] as? String,
              receipt["phase"] as? String == "finalized", receipt["changed"] is Bool else {
            throw ReaderLibraryError.operationPending(operationID)
        }
        try await finishCoreOperation(operationID)
    }

    private func finishSourceSwitchRollback(_ parameters: [String: Any], operationID: String,
                                           rollbackID: String, original: ReaderBook) async throws -> (book: ReaderBook, snapshot: ReaderProgressSnapshot) {
        let receipt = try object(await coreMutation("source.switch.rollback", parameters,
            operationID: rollbackID, scope: "source-switch-terminal"))
        guard receipt["transactionId"] as? String == parameters["transactionId"] as? String,
              receipt["phase"] as? String == "rolledBack", receipt["changed"] is Bool,
              let row = receipt["restoredBook"] as? [String: Any] else {
            throw ReaderLibraryError.operationPending(rollbackID)
        }
        let restored = try decode(ReaderBook.self, JSONSerialization.data(withJSONObject: row))
        guard restored.sourceId == original.sourceId, restored.bookId == original.bookId else {
            throw ReaderLibraryError.operationPending(rollbackID)
        }
        try await finishCoreOperation(rollbackID)
        let snapshot: ReaderProgressSnapshot
        do {
            snapshot = try await progress(for: restored)
            guard let revision = snapshot.progressRevision, !revision.isEmpty,
                  snapshot.progress.map({ $0.sourceId == restored.sourceId && $0.bookId == restored.bookId }) ?? !snapshot.found else {
                throw ReaderLibraryError.invalidResponse("restored source switch session")
            }
        } catch {
            throw ReaderSourceSwitchRefreshRequired(operationID: operationID, restoredBook: restored)
        }
        try await finishCoreOperation(operationID)
        return (restored, snapshot)
    }
}
