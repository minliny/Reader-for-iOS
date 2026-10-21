import Foundation
import CoreText
import CryptoKit
import Darwin
import UIKit
import XCTest
@testable import Reader

/// Focused resource tests, not synthetic font acceptance. Inputs are the actual
/// vendored OFL font / actual bundled Sarasa, SHA-bound before and after. Every
/// mutated file/defaults suite belongs to a newly allocated test fixture only.
@MainActor
final class ReaderFontImportResourceTests: XCTestCase {
    func testDefaultSerifSelectionSurvivesOrderAndNormalChoiceRestoresAbsentKeysWithoutChangingAliases() throws {
        let suite = "ReaderFontDefaultSelectionTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(suite, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        defaults.set("keep-original-paper", forKey: "test.unrelated")
        let library = ReaderFontLibrary(directory: root, defaults: defaults)
        let preferences = ReaderPreferences(defaults: defaults)
        for id in ["serif", "sourceHanSerif", "sans"] {
            XCTAssertTrue(try XCTUnwrap(library.selectableChoices.first(where: { $0.id == id })).available,
                "Require the real registered bundled choices; do not import a replacement or bypass an unavailable face")
        }
        let originalKeys = try XCTUnwrap(defaults.persistentDomain(forName: suite))
        let fontKeys: Set<String> = ["appearance.fontPostScriptName", "appearance.fontSlotID"]
        func selected(_ owner: ReaderPreferences) -> String {
            library.selectedChoiceID(named: owner.fontPostScriptName, preferred: owner.fontSlotID)
        }
        func assertOtherKeys() throws {
            let current = try XCTUnwrap(defaults.persistentDomain(forName: suite))
                .filter { !fontKeys.contains($0.key) && $0.key != "reader.fontLibrary.order.v2" }
            let original = originalKeys.filter { !fontKeys.contains($0.key) && $0.key != "reader.fontLibrary.order.v2" }
            XCTAssertTrue(NSDictionary(dictionary: current).isEqual(to: original), "Normal font selection must not reset another preference")
        }
        XCTAssertNil(defaults.object(forKey: "appearance.fontPostScriptName"))
        XCTAssertNil(defaults.object(forKey: "appearance.fontSlotID"))
        XCTAssertEqual(selected(preferences), "serif")
        let originalFace = try XCTUnwrap(library.resolvedFont(named: preferences.fontPostScriptName, size: 18))
        let aliasIndex = try XCTUnwrap(library.choiceOrder.firstIndex(of: "sourceHanSerif"))
        library.moveChoices(fromOffsets: IndexSet(integer: aliasIndex), toOffset: 0)
        XCTAssertEqual(library.choiceOrder.first, "sourceHanSerif")
        XCTAssertEqual(selected(preferences), "serif", "Reordering a physical-font alias cannot change the default product slot")
        XCTAssertEqual(library.resolvedFont(named: preferences.fontPostScriptName, size: 18)?.fontName, originalFace.fontName)
        XCTAssertNil(defaults.object(forKey: "appearance.fontSlotID"))

        library.selectChoice("sourceHanSerif", preferences: preferences)
        XCTAssertNil(preferences.fontPostScriptName)
        XCTAssertEqual(preferences.fontSlotID, "sourceHanSerif", "An explicit same-face alias retains its product identity")
        XCTAssertEqual(selected(preferences), "sourceHanSerif")
        let serifIndex = try XCTUnwrap(library.choiceOrder.firstIndex(of: "serif"))
        library.moveChoices(fromOffsets: IndexSet(integer: serifIndex), toOffset: 0)
        XCTAssertEqual(selected(preferences), "sourceHanSerif")
        let coldAlias = ReaderPreferences(defaults: defaults)
        let coldLibrary = ReaderFontLibrary(directory: root, defaults: defaults)
        XCTAssertEqual(coldLibrary.choiceOrder, library.choiceOrder)
        XCTAssertEqual(coldLibrary.selectedChoiceID(named: coldAlias.fontPostScriptName, preferred: coldAlias.fontSlotID), "sourceHanSerif")

        // Preserve the legacy explicit default until the user normally chooses.
        defaults.set("serif", forKey: "appearance.fontSlotID")
        let legacy = ReaderPreferences(defaults: defaults)
        XCTAssertNil(legacy.fontPostScriptName); XCTAssertEqual(selected(legacy), "serif")
        XCTAssertEqual(defaults.string(forKey: "appearance.fontSlotID"), "serif")
        library.selectChoice("sans", preferences: legacy)
        XCTAssertEqual(legacy.fontSlotID, "sans")
        let sans = try XCTUnwrap(library.selectableChoices.first(where: { $0.id == "sans" }))
        XCTAssertEqual(legacy.fontPostScriptName, sans.postScriptName)
        XCTAssertNotEqual(library.resolvedFont(named: legacy.fontPostScriptName, size: 18)?.fontName, originalFace.fontName)
        let selectedKeys = try XCTUnwrap(defaults.persistentDomain(forName: suite))
        library.selectChoice("import", preferences: legacy)
        library.selectChoice("missing-original-slot", preferences: legacy)
        XCTAssertTrue(NSDictionary(dictionary: try XCTUnwrap(defaults.persistentDomain(forName: suite))).isEqual(to: selectedKeys))
        library.selectChoice("serif", preferences: legacy)
        XCTAssertNil(legacy.fontPostScriptName); XCTAssertNil(legacy.fontSlotID)
        XCTAssertNil(defaults.object(forKey: "appearance.fontPostScriptName"))
        XCTAssertNil(defaults.object(forKey: "appearance.fontSlotID"))
        let coldDefault = ReaderPreferences(defaults: defaults)
        XCTAssertEqual(coldLibrary.selectedChoiceID(named: coldDefault.fontPostScriptName, preferred: coldDefault.fontSlotID), "serif")
        XCTAssertEqual(library.selectedChoiceID(named: "unavailable-original-face", preferred: nil), "retained-selection")
        try assertOtherKeys()
    }

    func testRealOFLFontPostRegistrationFailureRollsBackOnlyNewAsset() async throws {
        let input = try FontOriginal.ofl()
        let events = FontImportEvents(failFirstRegistration: true)
        let fixture = try FontResourceFixture(input: input, events: events)
        defer { fixture.cleanUp() }
        try fixture.requireUnregisteredOriginalFace()
        let oldNames = fontPostScriptNames()
        await fixture.library.importFonts([input.url])
        XCTAssertEqual(events.registrationURLs.count, 1, "Failure is thrown only after actual CoreText registration succeeds")
        XCTAssertTrue(fixture.library.fonts.isEmpty)
        XCTAssertNil(fixture.defaults.data(forKey: "reader.fontLibrary.v1"))
        XCTAssertNil(UIFont(name: input.postScriptName, size: 18))
        XCTAssertEqual(fontPostScriptNames(), oldNames, "Do not unregister any preexisting face")
        XCTAssertFalse(FileManager.default.fileExists(atPath: fixture.finalURL.path))
        try fixture.assertNoOwnedTransient()
        try fixture.assertOriginalAndLegacyUnchanged()
        guard fixture.library.fonts.isEmpty, UIFont(name: input.postScriptName, size: 18) == nil,
              !FileManager.default.fileExists(atPath: fixture.finalURL.path), fontPostScriptNames() == oldNames else {
            throw FontTestError.rollbackNotConfirmed
        }
        // A new local fixture-only attempt after the definite injected failure
        // proves no registration/file residue. No user/Core journal is replayed.
        await fixture.library.importFonts([input.url])
        XCTAssertEqual(events.registrationURLs.count, 2)
        try fixture.assertConfirmedFont()
        try fixture.assertNoOwnedTransient()
        try fixture.assertOriginalAndLegacyUnchanged()
        XCTAssertEqual(fontPostScriptNames(), oldNames.union([input.postScriptName]))
    }

    func testRealOFLFontPostRegistrationFailurePreservesPreexistingSameSHAFile() async throws {
        let input = try FontOriginal.ofl()
        let events = FontImportEvents(failFirstRegistration: true)
        let fixture = try FontResourceFixture(input: input, events: events, preexistingFinal: true)
        defer { fixture.cleanUp() }
        try fixture.requireUnregisteredOriginalFace()
        let identity = try fileIdentity(fixture.finalURL)
        let oldNames = fontPostScriptNames()
        await fixture.library.importFonts([input.url])
        XCTAssertEqual(events.registrationURLs.count, 1)
        XCTAssertTrue(fixture.library.fonts.isEmpty)
        XCTAssertNil(fixture.defaults.data(forKey: "reader.fontLibrary.v1"))
        XCTAssertNil(UIFont(name: input.postScriptName, size: 18))
        XCTAssertEqual(fontPostScriptNames(), oldNames)
        XCTAssertEqual(try fileIdentity(fixture.finalURL), identity, "The earlier same-SHA inode is not this invocation's creation")
        XCTAssertEqual(try fileSHA(fixture.finalURL), input.sha256)
        try fixture.assertNoOwnedTransient()
        try fixture.assertOriginalAndLegacyUnchanged()
        guard fixture.library.fonts.isEmpty, UIFont(name: input.postScriptName, size: 18) == nil,
              try fileIdentity(fixture.finalURL) == identity, fontPostScriptNames() == oldNames else {
            throw FontTestError.rollbackNotConfirmed
        }
        await fixture.library.importFonts([input.url])
        XCTAssertEqual(events.registrationURLs.count, 2)
        try fixture.assertConfirmedFont()
        XCTAssertEqual(try fileIdentity(fixture.finalURL), identity, "Successful reuse must retain the original existing inode too")
        try fixture.assertNoOwnedTransient()
        try fixture.assertOriginalAndLegacyUnchanged()
    }

    func testCancelDuringRealFontCopyReleasesPayloadFDsAndLease() async throws {
        let input = try FontOriginal.sarasa()
        let reached = expectation(description: "actual first font chunk is durably owned and written")
        let hold = FontCopyHold(reached: reached)
        let events = FontImportEvents()
        let fixture = try FontResourceFixture(input: input, events: events, additional: { point, _ in
            if point == .staging(.firstChunkWritten) { try hold.waitForActualCancellation() }
        })
        defer { hold.release(); fixture.cleanUp() }
        let oldNames = fontPostScriptNames()
        let operation = Task { await fixture.library.importFonts([input.url, input.url]) }
        do {
            await fulfillment(of: [reached], timeout: 10)
            guard hold.isHeld else {
                operation.cancel(); hold.release(); await operation.value
                XCTFail("Actual copy never reached the owned first-chunk handshake; do not accept a fast completed operation as cancellation proof")
                return
            }
            XCTAssertTrue(fixture.library.busy)
            XCTAssertEqual(events.count(.staging(.firstChunkWritten)), 1)
            let payloads = try fixture.payloads()
            XCTAssertEqual(payloads.count, 1)
            let payload = try XCTUnwrap(payloads.first)
            XCTAssertEqual(try Data(contentsOf: payload), Data(input.bytes.prefix(1024 * 1024)))
            XCTAssertEqual(try fixture.ownerReceipts().count, 1)
            do {
                let competing = try ReaderImportStagingLease(stagingURL: fixture.staging)
                competing.release()
                XCTFail("The original import must hold its OS lease while its copy is held")
            } catch ReaderLibraryError.busy { /* exact expected original lease */ }
            operation.cancel() // This real Task cancellation is the tested cause.
            hold.release()
            await operation.value // Drain the actual worker before every assertion.
            XCTAssertFalse(fixture.library.busy)
            XCTAssertEqual(events.count(.staging(.admitted)), 1, "Cancel must not begin the second selected real file")
            XCTAssertEqual(events.count(.staging(.sourceDescriptorClosed(succeeded: true))), 1)
            XCTAssertEqual(events.count(.staging(.payloadDescriptorClosed(succeeded: true))), 1)
            XCTAssertEqual(events.registrationURLs.count, 0)
            XCTAssertTrue(fixture.library.fonts.isEmpty)
            XCTAssertNil(fixture.defaults.data(forKey: "reader.fontLibrary.v1"))
            let next = try ReaderImportStagingLease(stagingURL: fixture.staging); next.release()
            try fixture.assertNoOwnedTransient()
            try fixture.assertOriginalAndLegacyUnchanged()
            XCTAssertEqual(fontPostScriptNames(), oldNames)
        } catch {
            operation.cancel(); hold.release(); await operation.value
            throw error // Every failure still drains the real copy before fixture cleanup.
        }
    }

    func testOversizeRealFontFaultCopyRejectsBeforePayloadCreation() async throws {
        let input = try FontOriginal.sarasa()
        let events = FontImportEvents()
        let fixture = try FontResourceFixture(input: input, events: events)
        defer { fixture.cleanUp() }
        let oldNames = fontPostScriptNames()
        let oversized = fixture.root.appendingPathComponent("owned-oversize-real-font-copy.ttf")
        try FileManager.default.copyItem(at: input.url, to: oversized)
        let writer = try FileHandle(forWritingTo: oversized)
        try writer.truncate(atOffset: UInt64(ReaderImportStagingLease.maximumInputBytes + 1))
        try writer.close()
        // This is an explicitly corrupted/sparse size fault from real bytes,
        // never claimed to be a generated or valid font for CoreText acceptance.
        await fixture.library.importFonts([oversized])
        XCTAssertEqual(events.count(.staging(.sourceWillOpen)), 1)
        XCTAssertEqual(events.count(.staging(.admitted)), 0)
        XCTAssertEqual(events.count(.staging(.ownerDurable)), 0)
        XCTAssertEqual(events.count(.staging(.payloadBound)), 0)
        XCTAssertEqual(events.count(.staging(.firstChunkWritten)), 0)
        XCTAssertEqual(events.count(.staging(.sourceDescriptorClosed(succeeded: true))), 1)
        XCTAssertEqual(events.registrationURLs.count, 0)
        XCTAssertTrue(fixture.library.fonts.isEmpty)
        XCTAssertNil(fixture.defaults.data(forKey: "reader.fontLibrary.v1"))
        try fixture.assertNoOwnedTransient()
        try fixture.assertOriginalAndLegacyUnchanged()
        XCTAssertEqual(fontPostScriptNames(), oldNames)
    }

    func testBatchAdmissionChargesFailedAndDuplicateRealFontCopiesBeforeBytes() async throws {
        let input = try FontOriginal.sarasa()
        XCTAssertEqual(input.bytes.count, 25_541_448)
        let events = FontImportEvents()
        let fixture = try FontResourceFixture(input: input, events: events)
        defer { fixture.cleanUp() }
        // The real bundled face has already been registered by the production
        // library, so each admitted item must preserve that actual old identity.
        XCTAssertNotNil(UIFont(name: input.postScriptName, size: 18))
        let oldURL = registeredURL(input.postScriptName)
        XCTAssertNotNil(oldURL)
        let oldNames = fontPostScriptNames()
        XCTAssertLessThanOrEqual(Int64(input.bytes.count) * 10, 256 * 1024 * 1024)
        XCTAssertGreaterThan(Int64(input.bytes.count) * 11, 256 * 1024 * 1024)
        await fixture.library.importFonts(Array(repeating: input.url, count: 11))
        XCTAssertEqual(events.count(.staging(.sourceWillOpen)), 11)
        XCTAssertEqual(events.count(.staging(.admitted)), 11)
        XCTAssertEqual(events.count(.staging(.ownerDurable)), 10, "11th exact durable owner size is refused before forwarding the checkpoint or creating a payload")
        XCTAssertEqual(events.count(.staging(.payloadBound)), 10)
        XCTAssertEqual(events.count(.staging(.firstChunkWritten)), 10)
        XCTAssertEqual(events.count(.staging(.sourceDescriptorClosed(succeeded: true))), 11)
        XCTAssertEqual(events.count(.staging(.payloadDescriptorClosed(succeeded: true))), 10)
        XCTAssertEqual(events.registrationURLs.count, 0, "Existing same-name face must never be re-registered/unregistered by these failed imports")
        XCTAssertTrue(fixture.library.fonts.isEmpty)
        XCTAssertNil(fixture.defaults.data(forKey: "reader.fontLibrary.v1"))
        try fixture.assertNoOwnedTransient()
        let countBefore = events.totalCount
        await fixture.library.importFonts(Array(repeating: input.url, count: 33))
        XCTAssertEqual(events.totalCount, countBefore, "Selection count admission precedes opening/copying any file")
        XCTAssertEqual(registeredURL(input.postScriptName), oldURL)
        XCTAssertEqual(fontPostScriptNames(), oldNames)
        try fixture.assertOriginalAndLegacyUnchanged()
    }
}

private struct FontOriginal {
    let url: URL
    let bytes: Data
    let sha256: String
    let postScriptName: String
    static func ofl() throws -> Self {
        let env = ProcessInfo.processInfo.environment["READER_REAL_OFL_FONT_PATH"].map { URL(fileURLWithPath: $0) }
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reader-real-LiberationSans-Regular.ttf")
        let workspace = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
        let actual = workspace.appendingPathComponent("evidence/opensource-completion/foliate-upstream/vendor/pdfjs/standard_fonts/LiberationSans-Regular.ttf")
        return try require([env, docs, actual].compactMap { $0 },
            sha256: "f8ace1f892b2bd9dc1792ba7f097fa7588f84fed48321480e04de5390828221f", expectedBytes: 139_512)
    }
    static func sarasa() throws -> Self {
        let bundled = Bundle.main.url(forResource: "SarasaMonoSC-Regular", withExtension: "ttf", subdirectory: "Fonts")
            ?? Bundle.main.url(forResource: "SarasaMonoSC-Regular", withExtension: "ttf")
        return try require([bundled].compactMap { $0 },
            sha256: "95718854631c2386845e618aa5bc37908e5fb8a919eb56e40f70e1170d80af94", expectedBytes: 25_541_448)
    }
    private static func require(_ candidates: [URL], sha256: String, expectedBytes: Int) throws -> Self {
        guard let url = candidates.first(where: { FileManager.default.isReadableFile(atPath: $0.path) }) else {
            XCTFail("Provision the exact existing repository/OFL font input, not a renamed/generated font. Missing actual input is a prerequisite failure")
            throw FontTestError.missingOriginal
        }
        let value = try Data(contentsOf: url)
        XCTAssertEqual(value.count, expectedBytes); XCTAssertEqual(fontSHA(value), sha256)
        guard value.count == expectedBytes, fontSHA(value) == sha256,
              let descriptors = CTFontManagerCreateFontDescriptorsFromData(value as CFData) as? [CTFontDescriptor],
              descriptors.count == 1, let descriptor = descriptors.first,
              let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String else {
            throw FontTestError.originalIdentity
        }
        return .init(url: url, bytes: value, sha256: sha256, postScriptName: name)
    }
}

@MainActor
private final class FontResourceFixture {
    let input: FontOriginal
    let root: URL
    let directory: URL
    let staging: URL
    let finalURL: URL
    let defaults: UserDefaults
    let suite: String
    let library: ReaderFontLibrary
    let events: FontImportEvents
    let legacy: URL
    let legacySHA: String
    init(input: FontOriginal, events: FontImportEvents, preexistingFinal: Bool = false,
         additional: @escaping ReaderFontImportObserver = { _, _ in }) throws {
        self.input = input; self.events = events
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent("ReaderFontImportResourceTests-" + UUID().uuidString, isDirectory: true)
        let fontsURL = rootURL.appendingPathComponent("Fonts", isDirectory: true)
        let final = fontsURL.appendingPathComponent(input.sha256 + ".ttf")
        let suiteName = "ReaderFontImportResourceTests." + UUID().uuidString
        let settings = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        root = rootURL; directory = fontsURL
        staging = fontsURL.appendingPathComponent(".import-staging", isDirectory: true)
        finalURL = final; suite = suiteName; defaults = settings
        try FileManager.default.createDirectory(at: fontsURL, withIntermediateDirectories: true)
        // Test-owned existing naked import material must not be swept by the
        // production import or rollback. It is not an owned staging receipt.
        let legacyURL = fontsURL.appendingPathComponent(".import-legacy-preserve.ttf")
        legacy = legacyURL
        try FileManager.default.copyItem(at: input.url, to: legacyURL)
        legacySHA = try fileSHA(legacyURL)
        if preexistingFinal { try FileManager.default.copyItem(at: input.url, to: final) }
        library = ReaderFontLibrary(directory: fontsURL, defaults: settings, importObserver: { point, url in
            try events.observe(point, url: url)
            try additional(point, url)
        })
        library.setPresentationActive(true)
    }
    func requireUnregisteredOriginalFace() throws {
        guard UIFont(name: input.postScriptName, size: 18) == nil else {
            XCTFail("Actual OFL face is already registered; preserve it, do not unregister or rename a preexisting font to make the test pass")
            throw FontTestError.originalAlreadyRegistered
        }
    }
    func assertOriginalAndLegacyUnchanged(file: StaticString = #filePath, line: UInt = #line) throws {
        let originalNow = try fileSHA(input.url), legacyNow = try fileSHA(legacy)
        XCTAssertEqual(originalNow, input.sha256, file: file, line: line)
        XCTAssertEqual(legacyNow, legacySHA, file: file, line: line)
        guard originalNow == input.sha256, legacyNow == legacySHA else { throw FontTestError.originalIdentity }
    }
    func payloads() throws -> [URL] {
        guard FileManager.default.fileExists(atPath: staging.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: staging, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "source" }
    }
    func ownerReceipts() throws -> [URL] {
        let owners = staging.appendingPathComponent(".owners", isDirectory: true)
        guard FileManager.default.fileExists(atPath: owners.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(at: owners, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
    }
    func assertNoOwnedTransient(file: StaticString = #filePath, line: UInt = #line) throws {
        let payloadCount = try payloads().count, ownerCount = try ownerReceipts().count
        XCTAssertEqual(payloadCount, 0, file: file, line: line)
        XCTAssertEqual(ownerCount, 0, file: file, line: line)
        XCTAssertFalse(library.busy, file: file, line: line)
        guard payloadCount == 0, ownerCount == 0, !library.busy else { throw FontTestError.rollbackNotConfirmed }
        if FileManager.default.fileExists(atPath: staging.path) {
            let released = try ReaderImportStagingLease(stagingURL: staging); released.release()
        }
    }
    func assertConfirmedFont(file: StaticString = #filePath, line: UInt = #line) throws {
        XCTAssertEqual(library.fonts.count, 1, file: file, line: line)
        let record = try XCTUnwrap(library.fonts.first, file: file, line: line)
        XCTAssertEqual(record.sha256, input.sha256, file: file, line: line)
        XCTAssertEqual(record.postScriptName, input.postScriptName, file: file, line: line)
        XCTAssertEqual(record.fileName, input.sha256 + ".ttf", file: file, line: line)
        XCTAssertTrue(library.availablePostScriptNames.contains(input.postScriptName), file: file, line: line)
        XCTAssertTrue(library.isAvailable(record), file: file, line: line)
        let stored = try JSONDecoder().decode([ReaderUserFont].self, from: XCTUnwrap(defaults.data(forKey: "reader.fontLibrary.v1")))
        XCTAssertEqual(stored, library.fonts, file: file, line: line)
        XCTAssertEqual(try fileSHA(finalURL), input.sha256, file: file, line: line)
        XCTAssertEqual(registeredURL(input.postScriptName).map(normalizedFontURL), normalizedFontURL(finalURL), file: file, line: line)
    }
    func cleanUp(file: StaticString = #filePath, line: UInt = #line) {
        // Only callbacks from actual successful registrations authorize this
        // fixture cleanup. Never unregister all fonts sharing a PostScript name.
        for url in Set(events.registrationURLs) where registeredURL(input.postScriptName).map(normalizedFontURL) == normalizedFontURL(url) {
            var error: Unmanaged<CFError>?
            let removed = CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &error)
            if let error { _ = error.takeRetainedValue() }
            guard removed else {
                XCTFail("Test-owned registration could not be retired; preserve its files for inspection", file: file, line: line)
                return
            }
        }
        defaults.removePersistentDomain(forName: suite)
        guard root.lastPathComponent.hasPrefix("ReaderFontImportResourceTests-") else { return }
        try? FileManager.default.removeItem(at: root) // Exclusively this newly allocated fixture.
    }
}

private final class FontImportEvents: @unchecked Sendable {
    private let lock = NSLock()
    private var points: [ReaderFontImportCheckpoint] = []
    private var registrations: [URL] = []
    private var failOnce: Bool
    init(failFirstRegistration: Bool = false) { failOnce = failFirstRegistration }
    func observe(_ point: ReaderFontImportCheckpoint, url: URL) throws {
        lock.lock(); points.append(point)
        var shouldFail = false
        if point == .registered {
            registrations.append(url)
            if failOnce { failOnce = false; shouldFail = true }
        }
        lock.unlock()
        if shouldFail { throw FontTestError.afterActualRegistration }
    }
    func count(_ point: ReaderFontImportCheckpoint) -> Int {
        lock.lock(); defer { lock.unlock() }; return points.filter { $0 == point }.count
    }
    var registrationURLs: [URL] { lock.lock(); defer { lock.unlock() }; return registrations }
    var totalCount: Int { lock.lock(); defer { lock.unlock() }; return points.count }
}

private final class FontCopyHold: @unchecked Sendable {
    private let condition = NSCondition()
    private let reached: XCTestExpectation
    private var held = false, released = false
    init(reached: XCTestExpectation) { self.reached = reached }
    var isHeld: Bool { condition.lock(); defer { condition.unlock() }; return held }
    func waitForActualCancellation() throws {
        condition.lock(); held = true; reached.fulfill()
        let deadline = Date(timeIntervalSinceNow: 15)
        while !released {
            guard condition.wait(until: deadline) else {
                held = false; condition.unlock(); throw FontTestError.handshakeTimeout
            }
        }
        held = false; condition.unlock()
    }
    func release() { condition.lock(); released = true; condition.broadcast(); condition.unlock() }
}

private enum FontTestError: Error {
    case missingOriginal, originalIdentity, originalAlreadyRegistered, afterActualRegistration, handshakeTimeout, rollbackNotConfirmed
}
private func fontSHA(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
private func fileSHA(_ url: URL) throws -> String { fontSHA(try Data(contentsOf: url)) }
private func fileIdentity(_ url: URL) throws -> ReaderImportStagingOwner.FileIdentity {
    var value = stat()
    guard lstat(url.path, &value) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
    return .init(value)
}
private func fontPostScriptNames() -> Set<String> {
    Set(CTFontManagerCopyAvailablePostScriptNames() as? [String] ?? [])
}
private func normalizedFontURL(_ url: URL) -> URL { url.standardizedFileURL.resolvingSymlinksInPath() }
private func registeredURL(_ name: String) -> URL? {
    guard let font = UIFont(name: name, size: 18) else { return nil }
    let native = CTFontCreateWithName(font.fontName as CFString, 18, nil)
    return CTFontCopyAttribute(native, kCTFontURLAttribute) as? URL
}
