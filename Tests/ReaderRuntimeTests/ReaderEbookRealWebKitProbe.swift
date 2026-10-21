import CoreText
import CryptoKit
import Foundation
import SwiftUI
import UIKit
import WebKit
import XCTest
@testable import Reader

/// Positive format evidence uses the actual Core descriptor/content, source
/// archive, scheme handler, UIViewRepresentable and WebKit font loader. The
/// explicit MOBI tail negatives copy only the DTO's canonical string in memory;
/// they keep the original entry and current chapter unchanged. These negatives
/// are method faults, not additional format inputs or fake Core/Host responses.
@MainActor
enum ReaderEbookRealWebKitProbe {
    static func verify(in test: XCTestCase, format: String, byteCount: Int, digest: String) async throws {
        let original = try ReaderLocalFormatsTests.originalURL(format: format, byteCount: byteCount, digest: digest)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderRealWK-" + UUID().uuidString)
        let defaultsName = "ReaderRealWK.Fonts." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defer {
            defaults.removePersistentDomain(forName: defaultsName)
            try? FileManager.default.removeItem(at: root)
        }
        let fonts = ReaderFontLibrary(directory: root.appendingPathComponent("Fonts"), defaults: defaults)
        let sansChoice = try XCTUnwrap(fonts.selectableChoices.first { $0.id == "sans" && $0.available },
            "Production bundled sans is unavailable. " + fontDiagnostics(fonts))
        let sansName = try XCTUnwrap(sansChoice.postScriptName, "The actual bundled VF must have its own native identity")
        let serif = try XCTUnwrap(fonts.resolvedFont(named: nil, size: 26))
        let sans = try XCTUnwrap(fonts.resolvedFont(named: sansName, size: 26))
        try assertFont(serif, file: "NotoSerifSC-Regular.ttf",
            expectedDigest: "9502147ceba7b5bc7fd3415083f6a5d133f22d8f9efb4974d4b85f3a97ea2d3a")
        try assertFont(sans, file: "NotoSansSC-VF.otf",
            expectedDigest: "d13ed01ec8aa45d6178999b648e96fb92150683e9f8e2a581f2acf208dcbe44b")
        let variations = CTFontCopyVariation(sans as CTFont) as? [NSNumber: NSNumber]
        XCTAssertEqual(variations?[NSNumber(value: 0x77676874)]?.doubleValue, 400,
            "Production fontLibrary must resolve the actual variable weight")

        let storage = root.appendingPathComponent("Core"), sources = root.appendingPathComponent("Sources")
        let library = try ReaderLibraryService(storageURL: storage, sourceURL: sources)
        var cold: ReaderLibraryService?
        do {
            let imported = try await library.importBook(at: original)
            XCTAssertTrue(imported.created)
            XCTAssertFalse(imported.finalizationPending)
            let book = imported.book
            XCTAssertEqual(book.bookId, "local:" + digest)
            let kind = try await library.localPresentationKind(for: book)
            XCTAssertEqual(kind.kind, .ebook); XCTAssertEqual(kind.format, format)
            XCTAssertFalse(kind.reimportRequired)
            let chapters = try await library.chapters(for: book)
            var selected: ReaderChapterContent?
            for chapter in chapters.filter({ !$0.url.isEmpty }).prefix(64) {
                let candidate = try await library.content(for: book, chapterIndex: chapter.index)
                let text = candidate.content.unicodeScalars.filter { !$0.properties.isWhitespace && $0.value != 0xfffc }
                // A large original TOC can exceed the total scalar threshold.
                // Require real prose paragraphs as well; this is only fixture
                // selection, never a second parser or reading pagination rule.
                let paragraphs = candidate.content.split(whereSeparator: { $0.isNewline }).map {
                    $0.unicodeScalars.filter { !$0.properties.isWhitespace && $0.value != 0xfffc }.count
                }
                if candidate.scalarCount >= 2_048, text.count >= 1_536,
                   paragraphs.filter({ $0 >= 64 }).count >= 4,
                   paragraphs.contains(where: { $0 >= 128 }) { selected = candidate; break }
            }
            let content = try XCTUnwrap(selected, "The original must provide a real body chapter, not a cover/blank/TOC")
            let document = try await library.ebookPresentation(for: book, chapterIndex: content.chapterIndex)
            try document.validate(content: content)
            let retained = try await library.retainedSourceURL(for: book)
            let reader = ReaderEbookArchiveReader(sourceURL: retained, bookID: book.bookId)
            let entry = try await reader.readEntry(document.entryPath, maximumBytes: 32 * 1024 * 1024)
            XCTAssertFalse(entry.isEmpty)
            let entryDigest = sha(entry)
            let originalImageEntry = format == "epub" ? "OEBPS/Images/牧云斋logo.png" : nil
            if let originalImageEntry {
                let image = try await reader.readEntry(originalImageEntry, maximumBytes: 8 * 1024 * 1024)
                XCTAssertEqual(image.count, 28_991)
                XCTAssertEqual(sha(image), "eccb75a442539543da708e81c5a1de7fe67efef31511abe353e1005b35b6b925")
                XCTAssertFalse(content.blocks.filter { $0.kind == "image" }.isEmpty,
                    "This original prose chapter must retain its actual publisher logo")
            } else {
                XCTAssertTrue(content.blocks.filter { $0.kind == "image" }.isEmpty,
                    "The supplied original MOBI has no image resource/reference and cannot prove image display")
            }
            let values = Array(content.content.unicodeScalars)
            let anchor = try XCTUnwrap(values.indices.first { $0 >= 512 && !values[$0].properties.isWhitespace && values[$0].value != 0xfffc })
            let observed = try await library.progress(for: book)
            let saved = try await library.saveProgress(for: book, content: content, scalarOffset: UInt64(anchor), expectedRevision: observed.progressRevision)
            XCTAssertEqual(saved.progress?.bodyVersion, content.bodyVersion)
            XCTAssertEqual(saved.progress?.processingVersion, content.processingVersion)
            XCTAssertEqual(saved.progress?.chapterOffset, UInt64(anchor))
            try printInput(phase: format + "-original", document: document, content: content, entryBytes: entry.count)
            try await render(in: test, document: document, content: content, reader: reader,
                offset: UInt64(anchor), fonts: [serif, sans], label: format + "-original", originalImageEntry: originalImageEntry)
            let afterLayout = try await library.progress(for: book)
            XCTAssertEqual(afterLayout, saved, "Rendering, selection and font reflow cannot move Core progress")
            let progressParameters: [String: Any] = ["sourceId": book.sourceId, "bookId": book.bookId]
            // Local progress uses the same storage runtime epoch as online
            // progress. Preserve all wire row/metadata fields across reopening;
            // only that observation CAS token is expected to change.
            let exactRow: (Data) throws -> Data = { data in
                var object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
                object.removeValue(forKey: "progressRevision")
                return try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            }
            let savedRow = try exactRow(await library.coreRead("reading.progress.get", progressParameters))
            try await library.close()

            let reopened = try ReaderLibraryService(storageURL: storage, sourceURL: sources)
            cold = reopened
            let restored = try await reopened.progress(for: book)
            XCTAssertEqual(restored.found, saved.found)
            XCTAssertEqual(restored.progress, saved.progress, "Cold reopen must preserve every progress coordinate and metadata field")
            let restoredRow = try exactRow(await reopened.coreRead("reading.progress.get", progressParameters))
            XCTAssertEqual(restoredRow, savedRow, "Including wire metadata absent from the Host DTO and future Core fields")
            let previousRevision = try XCTUnwrap(saved.progressRevision)
            let freshRevision = try XCTUnwrap(restored.progressRevision)
            let prefix = "reader-progress-v1:"
            let hexadecimal = Set("0123456789abcdef")
            for revision in [previousRevision, freshRevision] {
                XCTAssertTrue(revision.hasPrefix(prefix))
                let digest = revision.dropFirst(prefix.count)
                XCTAssertEqual(digest.count, 64)
                XCTAssertTrue(digest.allSatisfy { hexadecimal.contains($0) })
            }
            XCTAssertNotEqual(freshRevision, previousRevision, "A new Core storage epoch must fence the old progress observer")
            let position = try XCTUnwrap(restored.progress)
            let restoredContent = try await reopened.content(for: book, chapterIndex: position.chapterIndex)
            let restoredDocument = try await reopened.ebookPresentation(for: book, chapterIndex: position.chapterIndex)
            XCTAssertEqual(restoredContent.bodyVersion, position.bodyVersion)
            XCTAssertEqual(restoredContent.processingVersion, position.processingVersion)
            XCTAssertEqual(restoredDocument, document)
            let coldSource = try await reopened.retainedSourceURL(for: book)
            let coldReader = ReaderEbookArchiveReader(sourceURL: coldSource, bookID: book.bookId)
            let coldEntry = try await coldReader.readEntry(restoredDocument.entryPath, maximumBytes: 32 * 1024 * 1024)
            XCTAssertEqual(sha(coldEntry), entryDigest)
            if let originalImageEntry {
                let coldImage = try await coldReader.readEntry(originalImageEntry, maximumBytes: 8 * 1024 * 1024)
                XCTAssertEqual(sha(coldImage),
                    "eccb75a442539543da708e81c5a1de7fe67efef31511abe353e1005b35b6b925")
            }
            try printInput(phase: format + "-runtime-reopened", document: restoredDocument,
                content: restoredContent, entryBytes: coldEntry.count)
            try await render(in: test, document: restoredDocument, content: restoredContent, reader: coldReader,
                offset: position.chapterOffset, fonts: [sans], label: format + "-runtime-reopened", originalImageEntry: originalImageEntry)
            let afterColdLayout = try await reopened.progress(for: book)
            XCTAssertEqual(afterColdLayout, restored)
            XCTAssertEqual(sha(try Data(contentsOf: coldSource, options: .mappedIfSafe)), digest)
            if format == "mobi" {
                try await assertRejectedCanonicalTails(in: test, document: restoredDocument,
                    content: restoredContent, reader: coldReader, offset: position.chapterOffset, font: sans)
                let afterTailFaults = try await reopened.progress(for: book)
                XCTAssertEqual(afterTailFaults, afterColdLayout,
                    "Fault-only canonical input must not change any original progress coordinate or metadata")
                let afterTailEntry = try await coldReader.readEntry(restoredDocument.entryPath,
                    maximumBytes: 32 * 1024 * 1024)
                XCTAssertEqual(sha(afterTailEntry), entryDigest)
                XCTAssertEqual(sha(try Data(contentsOf: coldSource, options: .mappedIfSafe)), digest)
            }
            try await reopened.close()
        } catch {
            try? await library.close()
            if let cold { try? await cold.close() }
            throw error
        }
        XCTAssertEqual(try original.resourceValues(forKeys: [.fileSizeKey]).fileSize, byteCount)
        XCTAssertEqual(sha(try Data(contentsOf: original, options: .mappedIfSafe)), digest)
    }

    /// The same authenticated original entry is loaded for each case. Only a
    /// DTO canonical field is corrupted outside its untouched chapter window.
    /// Never mutate the archive, current content, stored descriptor or Core ACK.
    private static func assertRejectedCanonicalTails(in test: XCTestCase, document: ReaderEbookDocument,
        content: ReaderChapterContent, reader: ReaderEbookArchiveReader, offset: UInt64, font: UIFont) async throws {
        let original = document.documentCanonicalContent
        let scalars = original.unicodeScalars
        let tail = try XCTUnwrap(scalars.lastIndex { !$0.properties.isWhitespace },
            "The real full entry must have a non-whitespace tail outside the selected chapter")
        let tailOffset = scalars.distance(from: scalars.startIndex, to: tail)
        let originalCount = scalars.count
        let significantCount = scalars.reduce(into: 0) { count, scalar in
            if !scalar.properties.isWhitespace { count += 1 }
        }
        guard UInt64(tailOffset) >= document.chapterEndScalar,
              document.chapterEndScalar < UInt64(originalCount), significantCount > 0 else {
            XCTFail("This real chapter has no full-entry tail outside its own canonical window")
            throw ReaderEbookError.positionMismatch
        }
        let lower = scalars.index(scalars.startIndex, offsetBy: Int(document.chapterStartScalar))
        let upper = scalars.index(scalars.startIndex, offsetBy: Int(document.chapterEndScalar))
        let originalChapter = String(scalars[lower..<upper])
        let currentChapterBytes = Data(content.content.utf8)
        let marker: Unicode.Scalar = scalars[tail] == "X" ? "Y" : "X"
        // These three small labels are not an array of full-entry scalars or
        // retained fault documents. Each owned string/Surface leaves this scope
        // before constructing the next fault.
        for kind in ["substitute", "remove", "append"] {
            var changed = original.unicodeScalars
            let changedTail = changed.index(changed.startIndex, offsetBy: tailOffset)
            let reason: String
            switch kind {
            case "substitute":
                changed.replaceSubrange(changedTail...changedTail, with: CollectionOfOne(marker))
                reason = "canonical-text:document:ordinal=\(significantCount - 1):expected=U+\(String(marker.value, radix: 16)):actual=U+\(String(scalars[tail].value, radix: 16))"
            case "remove":
                changed.remove(at: changedTail)
                reason = "canonical-length:document:expected=\(significantCount - 1):actual=\(significantCount)"
            default:
                changed.append(marker)
                reason = "canonical-length:document:expected=\(significantCount + 1):actual=\(significantCount)"
            }
            let faulty = ReaderEbookDocument(sourceId: document.sourceId, bookId: document.bookId,
                chapterIndex: document.chapterIndex, bodyVersion: document.bodyVersion,
                processingVersion: document.processingVersion, entryPath: document.entryPath,
                documentCanonicalContent: String(changed), chapterStartScalar: document.chapterStartScalar,
                chapterEndScalar: document.chapterEndScalar)
            let faultyScalars = faulty.documentCanonicalContent.unicodeScalars
            let faultyLower = faultyScalars.index(faultyScalars.startIndex, offsetBy: Int(document.chapterStartScalar))
            let faultyUpper = faultyScalars.index(faultyScalars.startIndex, offsetBy: Int(document.chapterEndScalar))
            XCTAssertEqual(Data(String(faultyScalars[faultyLower..<faultyUpper]).utf8), Data(originalChapter.utf8))
            XCTAssertEqual(Data(content.content.utf8), currentChapterBytes)
            // Host validation authenticates identity/window bounds; it must not
            // short-circuit the actual JS full-entry comparison in this case.
            try faulty.validate(content: content)
            try await assertRejectedCanonicalTail(in: test, document: faulty, content: content,
                reader: reader, offset: offset, font: font, kind: kind, expectedReason: reason)
        }
    }

    private static func assertRejectedCanonicalTail(in test: XCTestCase, document: ReaderEbookDocument,
        content: ReaderChapterContent, reader: ReaderEbookArchiveReader, offset: UInt64, font: UIFont,
        kind: String, expectedReason: String) async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive })
        let oldKey = scene.windows.first { $0.isKeyWindow }
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        var waiting: XCTestExpectation? = test.expectation(description: "real MOBI full-entry tail rejected: " + kind)
        let terminal = try XCTUnwrap(waiting)
        var failures: [ReaderEbookError] = []
        var readyCount = 0, positionCount = 0
        // A new Surface/host is mandatory: document.identity deliberately does
        // not include this canonical field, so updating an old mount would not
        // necessarily execute another bootstrap.
        let surface = ReaderEbookSurface(document: document, content: content, archiveReader: reader,
            scalarOffset: offset, restorationID: UUID(), fontSize: 26, lineHeight: 1.8,
            horizontalInset: 20, bottomInset: 24, paper: ReaderPaperPalette(theme: .day),
            positionChanged: { _ in positionCount += 1 }, selectionChanged: { _, _, _ in }, centerTapped: {},
            failed: { error in
                failures.append(error)
                let current = waiting; waiting = nil; current?.fulfill()
            }, fontName: font.fontName, paged: true,
            layoutReady: {
                readyCount += 1
                let current = waiting; waiting = nil; current?.fulfill()
            }, readerFont: font)
        let host = UIHostingController(rootView: AnyView(surface))
        window.rootViewController = host; window.makeKeyAndVisible()
        host.view.frame = window.bounds; host.view.layoutIfNeeded()
        defer {
            waiting = nil
            // The actual failure path retires its Coordinator/bridge before
            // invoking failed. Dismantling also retires any unexpected ready or
            // timeout path before the next independently mounted case.
            host.rootView = AnyView(EmptyView()); host.view.layoutIfNeeded()
            window.isHidden = true; window.rootViewController = nil; oldKey?.makeKey()
        }
        await test.fulfillment(of: [terminal], timeout: 45)
        XCTAssertEqual(failures.count, 1)
        XCTAssertEqual(readyCount, 0)
        XCTAssertEqual(positionCount, 0)
        guard failures.count == 1, readyCount == 0, positionCount == 0,
              case .scriptFailure(let stage, let reason) = failures[0] else {
            XCTFail("Expected the original document-stage canonical rejection, not a timeout, native failure or admitted layout: \(failures)")
            throw ReaderEbookError.positionMismatch
        }
        let rawReason = reason.hasPrefix("Error: ") ? String(reason.dropFirst(7)) : reason
        XCTAssertEqual(stage, "canonical-window")
        XCTAssertEqual(rawReason, expectedReason)
        guard stage == "canonical-window", rawReason == expectedReason else {
            throw ReaderEbookError.positionMismatch
        }
        let web = try XCTUnwrap(findContainer(host.view)?.webView)
        defer { web.stopLoading() }
        let url = try XCTUnwrap(web.url)
        XCTAssertEqual(try ReaderEbookResourcePath.entry(url: url, origin: try XCTUnwrap(url.host)), document.entryPath)
        let sampled = try await web.callAsyncJavaScript("""
            const root=document.documentElement;
            return {display:root.style.getPropertyValue('display'),priority:root.style.getPropertyPriority('display'),
                    hasAdmission:!!window.__readerEbookLayoutAdmission,url:location.href};
            """, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String: Any]
        let observation = try XCTUnwrap(sampled)
        XCTAssertEqual(observation["display"] as? String, "none")
        XCTAssertEqual(observation["priority"] as? String, "important")
        XCTAssertEqual(observation["hasAdmission"] as? Bool, true)
        XCTAssertEqual(observation["url"] as? String, url.absoluteString)
        XCTAssertEqual(readyCount, 0); XCTAssertEqual(positionCount, 0)
        // The exact document-stage mismatch is thrown before Range extraction
        // and admitChapter in production. This reads the resulting hold without
        // calling or replacing that admission API.
        try writeStandardOutput("tail-fault", ["kind": kind, "stage": stage, "reason": rawReason,
            "entry": document.entryPath, "windowStart": document.chapterStartScalar,
            "windowEnd": document.chapterEndScalar, "readyCount": readyCount, "positionCount": positionCount,
            "rootDisplay": observation["display"] ?? NSNull(), "rootPriority": observation["priority"] ?? NSNull(),
            "methodFaultOnly": true])
    }

    private static func printInput(phase: String, document: ReaderEbookDocument,
                                   content: ReaderChapterContent, entryBytes: Int) throws {
        try writeStandardOutput("input", ["phase": phase, "entry": document.entryPath, "entryBytes": entryBytes,
            "canonicalScalarCount": document.documentCanonicalContent.unicodeScalars.count,
            "chapterScalarCount": content.scalarCount, "chapterIndex": document.chapterIndex,
            "windowStart": document.chapterStartScalar, "windowEnd": document.chapterEndScalar,
            "bodyVersion": document.bodyVersion, "processingVersion": document.processingVersion])
    }

    private static func writeStandardOutput(_ stage: String, _ payload: [String: Any]) throws {
        // A small unbuffered stdout record survives when a watchdog prevents
        // XCTest from retaining attachments. Never include source body text.
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        var line = Data(("ReaderEbookRealWK." + stage + " ").utf8)
        line.append(data); line.append(0x0a)
        FileHandle.standardOutput.write(line)
    }

    private static func assertFont(_ font: UIFont, file: String, expectedDigest: String) throws {
        let path = file as NSString
        let url = try XCTUnwrap(Bundle.main.url(forResource: path.deletingPathExtension, withExtension: path.pathExtension, subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: path.deletingPathExtension, withExtension: path.pathExtension))
        let bytes = try Data(contentsOf: url, options: .mappedIfSafe)
        XCTAssertEqual(sha(bytes), expectedDigest)
        // This is exactly the production @font-face byte preparation path.
        // A fallback or a same-name different file must fail the byte check.
        let delivered = try ReaderEbookFontAsset.prepare(postScriptName: font.fontName)
        XCTAssertEqual(sha(delivered.0), expectedDigest)
        let manifestURL = try XCTUnwrap(Bundle.main.url(forResource: "manifest", withExtension: "json", subdirectory: "Reference")
            ?? Bundle.main.url(forResource: "manifest", withExtension: "json"))
        let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: manifestURL)) as? [String: Any])
        let inputs = try XCTUnwrap(manifest["inputs"] as? [[String: Any]])
        let row = try XCTUnwrap(inputs.first { $0["destination"] as? String == "Fonts/" + file })
        XCTAssertEqual(row["sha256"] as? String, expectedDigest)
    }

    private static func fontDiagnostics(_ library: ReaderFontLibrary) -> String {
        let choices = library.selectableChoices.map { "\($0.id):available=\($0.available),PS=\($0.postScriptName ?? "default")" }.joined(separator: "; ")
        guard let url = Bundle.main.url(forResource: "NotoSansSC-VF", withExtension: "otf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: "NotoSansSC-VF", withExtension: "otf"),
              let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor] else {
            return choices + "; CoreText could not read the actual bundled VF"
        }
        let actual = descriptors.map { descriptor -> String in
            let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String ?? "missing"
            let native = CTFontCreateWithFontDescriptor(descriptor, 18, nil)
            let axes = (CTFontCopyVariationAxes(native) as? [[String: Any]])?.count ?? 0
            let resolved = UIFont(name: name, size: 18)
            let registered = resolved.flatMap { CTFontCopyAttribute($0 as CTFont, kCTFontURLAttribute) as? URL }
            return "\(name):axes=\(axes),resolved=\(resolved?.fontName ?? "nil"),file=\(registered?.lastPathComponent ?? "nil")"
        }.joined(separator: "; ")
        return choices + "; CoreText descriptors=\(descriptors.count): " + actual
    }

    private static func render(in test: XCTestCase, document: ReaderEbookDocument, content: ReaderChapterContent,
                               reader: ReaderEbookArchiveReader, offset: UInt64, fonts: [UIFont], label: String,
                               originalImageEntry: String?) async throws {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = try XCTUnwrap(scenes.first { $0.activationState == .foregroundActive }
            ?? scenes.first { $0.activationState == .foregroundInactive }, "Real WebKit display requires the test host's foreground UIWindowScene")
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 700)
        let oldKey = scene.windows.first { $0.isKeyWindow }
        var waiting: XCTestExpectation?
        var failure: ReaderEbookError?
        var unsolicitedPositions: [UInt64] = []
        var surface = ReaderEbookSurface(document: document, content: content, archiveReader: reader,
            scalarOffset: offset, restorationID: UUID(), fontSize: 26, lineHeight: 1.8,
            horizontalInset: 20, bottomInset: 24, paper: ReaderPaperPalette(theme: .day),
            positionChanged: { unsolicitedPositions.append($0) }, selectionChanged: { _, _, _ in }, centerTapped: {},
            failed: { error in failure = error; let current = waiting; waiting = nil; current?.fulfill() },
            fontName: fonts.first?.fontName, paged: true,
            layoutReady: { let current = waiting; waiting = nil; current?.fulfill() }, readerFont: fonts.first)
        let first = test.expectation(description: label + " real WebKit initial layout")
        waiting = first
        let host = UIHostingController(rootView: AnyView(surface))
        window.rootViewController = host
        window.makeKeyAndVisible()
        host.view.frame = window.bounds
        host.view.layoutIfNeeded()
        defer {
            waiting = nil
            host.rootView = AnyView(EmptyView())
            host.view.layoutIfNeeded()
            window.isHidden = true; window.rootViewController = nil
            oldKey?.makeKey()
        }
        await test.fulfillment(of: [first], timeout: 45)
        if let failure {
            XCTFail("\(label) chapter \(document.chapterIndex), entry \(document.entryPath), body \(document.bodyVersion): \(failure)")
            throw failure
        }
        let container = try XCTUnwrap(findContainer(host.view))
        let web = try XCTUnwrap(container.webView)
        defer { web.stopLoading() }
        XCTAssertEqual(web.url.flatMap { try? ReaderEbookResourcePath.entry(url: $0, origin: $0.host ?? "") }, document.entryPath)
        try await assertVisible(in: test, web: web, document: document, content: content, offset: offset,
            font: try XCTUnwrap(fonts.first), phase: label + "/initial")
        for font in fonts.dropFirst() {
            let ready = test.expectation(description: label + " actual @font-face " + font.fontName)
            waiting = ready
            surface.readerFont = font; surface.fontName = font.fontName
            host.rootView = AnyView(surface)
            host.view.layoutIfNeeded()
            await test.fulfillment(of: [ready], timeout: 30)
            if let failure { XCTFail("\(label) actual font \(font.fontName): \(failure)"); throw failure }
            XCTAssertTrue(container.webView === web, "Font reflow must keep one active book WebKit")
            try await assertVisible(in: test, web: web, document: document, content: content, offset: offset,
                font: font, phase: label + "/font-reflow")
        }
        if let originalImageEntry {
            try await assertOriginalImage(in: test, web: web, content: content, offset: offset, entry: originalImageEntry, label: label)
            try await assertVisible(in: test, web: web, document: document, content: content, offset: offset,
                font: try XCTUnwrap(fonts.last), phase: label + "/after-original-image")
        }
        XCTAssertTrue(unsolicitedPositions.isEmpty, "Restoration and font reflow must retain the exact source anchor without an unsolicited write")
        let configuration = WKSnapshotConfiguration()
        configuration.rect = web.bounds; configuration.snapshotWidth = 195
        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            web.takeSnapshot(with: configuration) { image, error in
                if let error { continuation.resume(throwing: error) }
                else if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: ReaderEbookError.invalidDocument) }
            }
        }
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = label + " actual original chapter; " + document.bodyVersion
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }

    private static func assertVisible(in test: XCTestCase, web: WKWebView, document: ReaderEbookDocument,
                                      content: ReaderChapterContent, offset: UInt64, font: UIFont,
                                      phase: String) async throws {
        // The test observes native decoded nodes and native Range geometry. It
        // never substitutes the chapter/descriptor or modifies the original DOM.
        let nativeBefore = nativeGeometry(web)
        let javascript = #"""
            const significant=c=>!/^\p{White_Space}$/u.test(c);
            const before=Array.from(content).slice(0,offset).filter(significant).length;
            const walker=document.createTreeWalker(document.body,NodeFilter.SHOW_TEXT|NodeFilter.SHOW_ELEMENT,{
              acceptNode(node){if(node.nodeType===Node.ELEMENT_NODE){if(['script','style','template'].includes(node.localName)||node.hasAttribute('data-reader-overlay'))return NodeFilter.FILTER_REJECT;return ['img','image'].includes(node.localName)?NodeFilter.FILTER_ACCEPT:NodeFilter.FILTER_SKIP;}return NodeFilter.FILTER_ACCEPT;}});
            let node,ordinal=0,range=null,element=null,character='';
            while((node=walker.nextNode())){
              if(node.nodeType===Node.TEXT_NODE){let unit=0;for(const c of node.data){if(significant(c)){if(ordinal===before){range=document.createRange();range.setStart(node,unit);range.setEnd(node,unit+c.length);element=node.parentElement;character=c;break;}ordinal++;}unit+=c.length;}if(range)break;}
              else if(node.getAttribute('src')||node.getAttribute('href')||node.getAttribute('xlink:href'))ordinal++;
            }
            if(!range)throw Error('restored-source-anchor-not-found');
            const geometry=()=>{
              const rect=range.getBoundingClientRect(),vv=visualViewport,sc=document.scrollingElement;
              const css=node=>{const s=getComputedStyle(node);return {tag:node.localName,fontFamily:s.fontFamily,fontSize:s.fontSize,lineHeight:s.lineHeight,
                fontVariationSettings:s.fontVariationSettings,display:s.display,position:s.position,transform:s.transform,zoom:s.zoom,
                marginTop:s.marginTop,marginBottom:s.marginBottom,paddingTop:s.paddingTop,paddingBottom:s.paddingBottom,
                overflowY:s.overflowY,scrollBehavior:s.scrollBehavior,scrollSnapType:s.scrollSnapType,overflowAnchor:s.overflowAnchor||''};};
              const ancestors=[];for(let node=element;node&&ancestors.length<5;node=node.parentElement)ancestors.push(css(node));
              return {time:performance.now(),top:rect.top,left:rect.left,width:rect.width,height:rect.height,
                scrollY,scrollX,innerWidth,innerHeight,documentHeight:document.documentElement.scrollHeight,
                maxScroll:Math.max(0,document.documentElement.scrollHeight-innerHeight),fontStatus:document.fonts.status,
                faces:[...document.fonts].filter(face=>face.family==='ReaderSelectedFace').map(face=>({family:face.family,status:face.status})),
                scrollingElement:sc?{tag:sc.localName,scrollTop:sc.scrollTop,scrollHeight:sc.scrollHeight,clientHeight:sc.clientHeight,style:css(sc)}:null,
                visualViewport:vv?{scale:vv.scale,width:vv.width,height:vv.height,offsetTop:vv.offsetTop,offsetLeft:vv.offsetLeft,pageTop:vv.pageTop,pageLeft:vv.pageLeft}:null,
                ancestors};
            };
            if(observeFrames){
              const before=geometry();await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)));
              return {before,afterTwoFrames:geometry()};
            }
            const rect=range.getBoundingClientRect(),style=getComputedStyle(element);
            const geometryBeforeFontLoad=geometry();
            const faces=[...document.fonts].filter(face=>face.family==='ReaderSelectedFace').map(face=>({family:face.family,status:face.status}));
            const loaded=await document.fonts.load('26px ReaderSelectedFace',character);
            return {charset:document.characterSet,scale:visualViewport.scale,nativeWidth:innerWidth,visibleText:document.body.innerText.trim().length,character,top:rect.top,height:rect.height,width:rect.width,
              viewport:innerHeight,scroll:scrollY,family:style.fontFamily,axes:style.fontVariationSettings,faces,loaded:loaded.length,
              geometryBeforeFontLoad,geometryAfterFontLoad:geometry()};
            """#
        let value = try await web.callAsyncJavaScript(javascript,
            arguments: ["content": content.content, "offset": offset, "observeFrames": false],
            in: nil, contentWorld: .defaultClient) as? [String: Any]
        let data = try XCTUnwrap(value)
        let identity: [String: Any] = ["phase": phase, "font": font.fontName, "fontSize": font.pointSize,
            "sourceId": content.sourceId, "bookId": content.bookId, "chapterIndex": content.chapterIndex,
            "bodyVersion": document.bodyVersion, "processingVersion": document.processingVersion,
            "offset": offset, "documentIdentity": document.identity]
        try writeStandardOutput("original-sample", ["identity": identity,
            "top": data["top"] ?? NSNull(), "scrollY": data["scroll"] ?? NSNull(),
            "fontFamily": data["family"] ?? NSNull(), "fontAxes": data["axes"] ?? NSNull(),
            "visibleText": data["visibleText"] ?? NSNull(), "viewport": data["viewport"] ?? NSNull(),
            "nativeContentOffsetY": web.scrollView.contentOffset.y, "nativeBoundsHeight": web.bounds.height])
        try attachGeometry(in: test, identity: identity, phase: "original-sample",
            observation: data, nativeBefore: nativeBefore, nativeAfter: nativeGeometry(web))
        XCTAssertEqual((data["charset"] as? String)?.uppercased(), "UTF-8",
            "Core admits this exact original document as UTF-8; native HTML encoding guesses cannot reinterpret it")
        XCTAssertEqual(try XCTUnwrap(data["scale"] as? NSNumber).doubleValue, 1, accuracy: 0.02,
            "The configured 26-point native reader font must not be shrunk by a desktop-width viewport")
        XCTAssertEqual(try XCTUnwrap(data["nativeWidth"] as? NSNumber).doubleValue,
            Double(web.bounds.width), accuracy: 2)
        XCTAssertGreaterThan(try XCTUnwrap(data["visibleText"] as? NSNumber).intValue, 1_000)
        let scalars = Array(content.content.unicodeScalars)
        XCTAssertEqual(data["character"] as? String, String(scalars[Int(offset)]))
        let top = try XCTUnwrap(data["top"] as? NSNumber).doubleValue
        let height = try XCTUnwrap(data["height"] as? NSNumber).doubleValue
        XCTAssertGreaterThan(try XCTUnwrap(data["width"] as? NSNumber).doubleValue, 0)
        XCTAssertGreaterThan(height, 0)
        XCTAssertEqual(top, 8, accuracy: 2, "The actual saved source scalar must remain at the restored viewport edge")
        XCTAssertLessThan(top + height, try XCTUnwrap(data["viewport"] as? NSNumber).doubleValue)
        XCTAssertGreaterThan(try XCTUnwrap(data["scroll"] as? NSNumber).doubleValue, 0)
        XCTAssertTrue((data["family"] as? String)?.contains("ReaderSelectedFace") == true)
        let faces = try XCTUnwrap(data["faces"] as? [[String: Any]])
        XCTAssertTrue(faces.contains { $0["status"] as? String == "loaded" }, "A CSS family name alone does not prove font binary consumption")
        XCTAssertGreaterThan(try XCTUnwrap(data["loaded"] as? NSNumber).intValue, 0)
        if let axes = CTFontCopyVariation(font as CTFont) as? [NSNumber: NSNumber], axes[NSNumber(value: 0x77676874)]?.doubleValue == 400 {
            let css = try XCTUnwrap(data["axes"] as? String)
            XCTAssertTrue(css.contains("wght") && css.contains("400"), "WebKit must consume the resolved UIFont's real weight axis")
        }
        // Observation only: the original assertions above continue to use the
        // first sample, even when these later public geometry values differ.
        // No restore, configure, scroll or progress command is dispatched here.
        let nativeBeforeFrames = nativeGeometry(web)
        let frameObservation = try await web.callAsyncJavaScript(javascript,
            arguments: ["content": content.content, "offset": offset, "observeFrames": true],
            in: nil, contentWorld: .defaultClient) as? [String: Any]
        try attachGeometry(in: test, identity: identity, phase: "later-two-rAF-observation",
            observation: try XCTUnwrap(frameObservation), nativeBefore: nativeBeforeFrames, nativeAfter: nativeGeometry(web))
    }

    private static func nativeGeometry(_ web: WKWebView) -> [String: Any] {
        let scroll = web.scrollView
        let rect: (CGRect) -> [String: CGFloat] = { ["x": $0.minX, "y": $0.minY, "width": $0.width, "height": $0.height] }
        var result: [String: Any] = ["uptime": ProcessInfo.processInfo.systemUptime, "inWindow": web.window != nil,
            "bounds": rect(web.bounds), "frame": rect(web.frame), "windowBounds": NSNull(),
            "contentOffset": ["x": scroll.contentOffset.x, "y": scroll.contentOffset.y],
            "contentSize": ["width": scroll.contentSize.width, "height": scroll.contentSize.height],
            "contentInset": ["top": scroll.contentInset.top, "left": scroll.contentInset.left,
                "bottom": scroll.contentInset.bottom, "right": scroll.contentInset.right],
            "adjustedContentInset": ["top": scroll.adjustedContentInset.top, "left": scroll.adjustedContentInset.left,
                "bottom": scroll.adjustedContentInset.bottom, "right": scroll.adjustedContentInset.right],
            "zoomScale": scroll.zoomScale, "isDragging": scroll.isDragging,
            "isDecelerating": scroll.isDecelerating, "isTracking": scroll.isTracking]
        if let window = web.window { result["windowBounds"] = rect(window.bounds) }
        return result
    }

    private static func attachGeometry(in test: XCTestCase, identity: [String: Any], phase: String,
                                       observation: [String: Any], nativeBefore: [String: Any],
                                       nativeAfter: [String: Any]) throws {
        let payload: [String: Any] = ["identity": identity, "sample": phase,
            "originalAssertionsUnchanged": true, "observation": observation,
            "nativeBefore": nativeBefore, "nativeAfter": nativeAfter]
        let bytes = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        let attachment = XCTAttachment(data: bytes, uniformTypeIdentifier: "public.json")
        attachment.name = "actual-scalar-geometry-" + (identity["phase"] as? String ?? "unknown") + "-" + phase
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }

    private static func assertOriginalImage(in test: XCTestCase, web: WKWebView, content: ReaderChapterContent,
                                            offset: UInt64, entry: String, label: String) async throws {
        let image = try XCTUnwrap(content.blocks.first { $0.kind == "image" })
        guard image.startScalar < content.scalarCount else { throw ReaderEbookError.positionMismatch }
        XCTAssertEqual(image.endScalar, image.startScalar + 1)
        XCTAssertEqual(Array(content.content.unicodeScalars)[Int(image.startScalar)].value, 0xFFFC)
        let source = try XCTUnwrap(image.source)
        let encodedEntry = Data(entry.utf8).base64EncodedString().replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
        XCTAssertTrue(source.hasPrefix("reader-local-epub://"))
        XCTAssertTrue(source.hasSuffix("/" + encodedEntry), "Core's image descriptor must name the actual original archive resource")
        let nativeBefore = web.scrollView.contentOffset.y
        let result = try await web.callAsyncJavaScript(#"""
            const image=document.body.querySelector('img');if(!image)throw Error('original-logo-missing');
            const original=image.getAttribute('src');
            let timeout;
            try{await Promise.race([image.decode(),new Promise((_,reject)=>{timeout=setTimeout(()=>reject(Error('original-logo-decode-timeout')),10000);})]);}
            finally{clearTimeout(timeout);}
            const observations=[];
            const observe=phase=>{const r=image.getBoundingClientRect();observations.push({phase,y:scrollY,scrollTop:document.scrollingElement?.scrollTop,
              visualPageTop:visualViewport?.pageTop,visualScale:visualViewport?.scale,top:r.top,bottom:r.bottom});};
            observe('before');window.__readerEbook.restore(scalar);observe('immediate');
            await new Promise(resolve=>requestAnimationFrame(resolve));observe('rAF1');
            await new Promise(resolve=>requestAnimationFrame(resolve));observe('rAF2');
            const rect=image.getBoundingClientRect(),style=getComputedStyle(image);
            return {original,after:image.getAttribute('src'),current:image.currentSrc,complete:image.complete,
              width:image.naturalWidth,height:image.naturalHeight,rectWidth:rect.width,rectHeight:rect.height,
              top:rect.top,bottom:rect.bottom,viewport:innerHeight,display:style.display,visibility:style.visibility,
              missing:image.hasAttribute('data-reader-missing'),requestedScalar:scalar,observations};
            """#, arguments: ["scalar": image.startScalar], in: nil, contentWorld: .defaultClient) as? [String: Any]
        var value = try XCTUnwrap(result)
        // R6 proved scrollTo reached zero immediately, while the web process
        // briefly returned the old scroll offset after two rAF callbacks.
        // Wait for the public rendered-snapshot callback, then require the
        // same original image to be visible in freshly sampled geometry.
        let configuration = WKSnapshotConfiguration()
        configuration.afterScreenUpdates = true
        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UIImage, Error>) in
            web.takeSnapshot(with: configuration) { image, error in
                if let error { continuation.resume(throwing: error) }
                else if let image { continuation.resume(returning: image) }
                else { continuation.resume(throwing: ReaderEbookError.invalidDocument) }
            }
        }
        let presented = try await web.callAsyncJavaScript(#"""
            const image=document.body.querySelector('img');if(!image)throw Error('presented-original-logo-missing');
            const rect=image.getBoundingClientRect(),style=getComputedStyle(image);
            return {after:image.getAttribute('src'),current:image.currentSrc,complete:image.complete,
              width:image.naturalWidth,height:image.naturalHeight,rectWidth:rect.width,rectHeight:rect.height,
              top:rect.top,bottom:rect.bottom,viewport:innerHeight,display:style.display,visibility:style.visibility,
              missing:image.hasAttribute('data-reader-missing'),presentedY:scrollY,presentedScale:visualViewport.scale};
            """#, arguments: [:], in: nil, contentWorld: .defaultClient) as? [String: Any]
        let finalGeometry = try XCTUnwrap(presented)
        for (key, field) in finalGeometry { value[key] = field }
        let geometry = try JSONSerialization.data(withJSONObject: [
            "beforePresentationCommit": try XCTUnwrap(result), "image": value, "nativeBefore": nativeBefore,
            "nativeAfter": web.scrollView.contentOffset.y, "nativeZoom": web.scrollView.zoomScale
        ], options: [.prettyPrinted, .sortedKeys])
        let diagnostic = XCTAttachment(data: geometry, uniformTypeIdentifier: "public.json")
        diagnostic.name = label + " original-image-scroll-observations"
        diagnostic.lifetime = .keepAlways
        test.add(diagnostic)
        XCTAssertEqual(value["original"] as? String, "../Images/牧云斋logo.png")
        XCTAssertEqual(value["after"] as? String, value["original"] as? String)
        let current = try XCTUnwrap(URL(string: try XCTUnwrap(value["current"] as? String)))
        XCTAssertEqual(try ReaderEbookResourcePath.entry(url: current, origin: try XCTUnwrap(web.url?.host)), entry)
        XCTAssertEqual(value["complete"] as? Bool, true)
        XCTAssertEqual(value["missing"] as? Bool, false)
        for key in ["width", "height", "rectWidth", "rectHeight"] {
            XCTAssertGreaterThan(try XCTUnwrap(value[key] as? NSNumber).doubleValue, 0, key)
        }
        XCTAssertNotEqual(value["display"] as? String, "none")
        XCTAssertNotEqual(value["visibility"] as? String, "hidden")
        XCTAssertGreaterThan(try XCTUnwrap(value["bottom"] as? NSNumber).doubleValue, 0)
        XCTAssertLessThan(try XCTUnwrap(value["top"] as? NSNumber).doubleValue,
            try XCTUnwrap(value["viewport"] as? NSNumber).doubleValue)
        let attachment = XCTAttachment(image: snapshot)
        attachment.name = label + " actual original publisher logo; " + entry; attachment.lifetime = .keepAlways
        test.add(attachment)
        // Restore through the production scalar API. No DOM text/src mutation
        // or Core progress write is used to make the original image visible.
        _ = try await web.callAsyncJavaScript("window.__readerEbook.restore(offset);await new Promise(resolve=>requestAnimationFrame(()=>requestAnimationFrame(resolve)))",
            arguments: ["offset": offset], in: nil, contentWorld: .defaultClient)
    }

    private static func findContainer(_ view: UIView) -> ReaderEbookContainer? {
        if let result = view as? ReaderEbookContainer { return result }
        for child in view.subviews { if let result = findContainer(child) { return result } }
        return nil
    }

    private static func sha(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
}
