import Foundation
import Combine
import CoreText
import CryptoKit
import UIKit
import SwiftUI
import Darwin

struct ReaderUserFont: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let postScriptName: String
    let familyName: String
    let fileName: String
    let sha256: String
}

struct ReaderFontChoice: Identifiable {
    let id: String
    let displayName: String
    let postScriptName: String?
    let available: Bool
    var isImport: Bool { id == "import" }
}

/// App-private font assets and their display order. CoreText owns validation,
/// registration and font decoding; this owner never edits font tables.
@MainActor
final class ReaderFontLibrary: ObservableObject {
    @Published private(set) var fonts: [ReaderUserFont] = []
    @Published private(set) var availablePostScriptNames = Set<String>()
    @Published private(set) var busy = false
    @Published private(set) var message: String?
    @Published private(set) var failure: String?
    @Published private(set) var loadFailure: String?
    @Published private(set) var choiceOrder: [String] = []
    @Published private var bundledChoices: [String: ReaderFontChoice] = [:]

    private let defaults: UserDefaults
    private let directory: URL
    private let importObserver: ReaderFontImportObserver
    private let manifestKey = "reader.fontLibrary.v1"
    private let orderKey = "reader.fontLibrary.order.v2"
    private static let systemSelection = "reader:system"
    private static let defaultSlots = ["system", "serif", "sans", "kai", "fangSong", "mono", "sourceHanSerif", "lxgwWenKai", "import"]
    private var manifestReadable = true
    private var feedbackGeneration = UUID()
    private var presentationActive = false
    var canModify: Bool { !busy && manifestReadable }

    init(directory: URL? = nil, defaults: UserDefaults = .standard,
         importObserver: @escaping ReaderFontImportObserver = { _, _ in }) {
        self.importObserver = importObserver
        self.defaults = defaults
        self.directory = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Reader/Fonts", isDirectory: true)
        reload()
    }

    var builtInChoices: [ReaderFontChoice] {
        libraryRows.filter { Self.defaultSlots.contains($0.id) && !$0.isImport }
    }

    var libraryRows: [ReaderFontChoice] {
        choiceOrder.compactMap { id in
            if id == "import" { return ReaderFontChoice(id: id, displayName: "导入字体", postScriptName: nil, available: true) }
            if let bundled = bundledChoices[id] { return bundled }
            guard let font = userFont(forChoiceID: id) else { return nil }
            return ReaderFontChoice(id: id, displayName: font.displayName, postScriptName: font.postScriptName, available: isAvailable(font))
        }
    }

    var selectableChoices: [ReaderFontChoice] { libraryRows.filter { !$0.isImport } }

    func userFont(forChoiceID id: String) -> ReaderUserFont? {
        fonts.first { "custom:" + $0.id.uuidString == id }
    }

    func selectedChoiceID(named name: String?, preferred: String?) -> String {
        if let preferred, selectableChoices.contains(where: { $0.id == preferred && $0.postScriptName == name }) { return preferred }
        if name == nil, preferred == nil, selectableChoices.contains(where: { $0.id == "serif" && $0.available }) {
            return "serif"
        }
        return selectableChoices.first(where: { $0.available && $0.postScriptName == name })?.id ?? "retained-selection"
    }

    func selectChoice(_ id: String, preferences: ReaderPreferences) {
        guard let choice = selectableChoices.first(where: { $0.id == id && $0.available }) else { return }
        preferences.fontPostScriptName = choice.postScriptName
        preferences.fontSlotID = choice.id == "serif" ? nil : choice.id
    }

    func moveChoices(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard canModify else { return }
        var order = choiceOrder
        order.move(fromOffsets: source, toOffset: destination)
        defaults.set(order, forKey: orderKey); choiceOrder = order
    }

    private func normalizeChoiceOrder() {
        let users = fonts.map { "custom:" + $0.id.uuidString }
        let known = Self.defaultSlots + users
        let stored = defaults.stringArray(forKey: orderKey) ?? []
        var order: [String] = []
        for id in stored where known.contains(id) && !order.contains(id) { order.append(id) }
        for id in Self.defaultSlots where !order.contains(id) { order.append(id) }
        // Preserve the previous manifest's user font order on migration.
        for id in users where !order.contains(id) { order.insert(id, at: order.firstIndex(of: "import") ?? order.endIndex) }
        choiceOrder = order; defaults.set(order, forKey: orderKey)
    }

    private func reloadBundledChoices() {
        var choices: [String: ReaderFontChoice] = [:]
        choices["system"] = .init(id: "system", displayName: "系统（iOS）", postScriptName: Self.systemSelection, available: true)
        for (id, label, file) in [
            ("serif", "宋体", "NotoSerifSC-Regular.ttf"),
            ("sans", "黑体", "NotoSansSC-VF.otf"),
            ("kai", "楷体", "LXGWWenKaiGBLite-Regular.ttf"),
            ("fangSong", "仿宋", "ZhuqueFangsong-Regular.ttf"),
            ("mono", "等宽", "SarasaMonoSC-Regular.ttf"),
            ("sourceHanSerif", "思源宋体", "NotoSerifSC-Regular.ttf"),
            ("lxgwWenKai", "霞鹜文楷", "LXGWWenKaiLite-Regular.ttf")
        ] {
            let path = file as NSString
            let url = Bundle.main.url(forResource: path.deletingPathExtension, withExtension: path.pathExtension, subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: path.deletingPathExtension, withExtension: path.pathExtension)
            let descriptor = url.flatMap { try? Self.descriptor(at: $0, bundledVariableInstances: id == "sans") }
            if let url { _ = Self.register(url) }
            let available = url.flatMap { url in descriptor.map { Self.registeredFontMatches(url, postScriptName: $0.postScriptName) } } ?? false
            let name = id == "serif" || id == "sourceHanSerif" ? nil : descriptor?.postScriptName
            choices[id] = .init(id: id, displayName: label, postScriptName: name, available: available)
        }
        bundledChoices = choices
    }

    func setPresentationActive(_ active: Bool) {
        presentationActive = active
        if !active { clearFeedback() }
    }

    func reload() {
        guard !busy else { return }
        reloadBundledChoices()
        do {
            let records: [ReaderUserFont]
            if let data = defaults.data(forKey: manifestKey) { records = try JSONDecoder().decode([ReaderUserFont].self, from: data) }
            else { records = [] }
            fonts = records
            manifestReadable = true
            loadFailure = nil
            var available = Set<String>()
            for record in records {
                guard let url = safeURL(for: record) else { continue }
                guard let bytes = try? Data(contentsOf: url, options: .mappedIfSafe),
                      Self.digest(bytes) == record.sha256,
                      let actual = try? Self.descriptor(at: url), actual.postScriptName == record.postScriptName else { continue }
                _ = Self.register(url)
                if Self.registeredFontMatches(url, postScriptName: record.postScriptName) {
                    available.insert(record.postScriptName)
                }
            }
            availablePostScriptNames = available
            normalizeChoiceOrder()
        } catch {
            manifestReadable = false
            loadFailure = "字体列表读取失败，已有字体文件已保留"
            normalizeChoiceOrder()
        }
    }

    func resolvedFont(named name: String?, size: CGFloat) -> UIFont? {
        guard let name else { return ReaderTypography.readingFont(size: size) }
        if name == Self.systemSelection { return UIFont.systemFont(ofSize: size) }
        if bundledChoices.values.contains(where: { $0.available && $0.postScriptName == name }) {
            guard let font = UIFont(name: name, size: size) else { return nil }
            if bundledChoices["sans"]?.postScriptName == name {
                let key = UIFontDescriptor.AttributeName(rawValue: kCTFontVariationAttribute as String)
                return UIFont(descriptor: font.fontDescriptor.addingAttributes([key: [NSNumber(value: 0x77676874): NSNumber(value: 400)]]), size: size)
            }
            return font
        }
        let builtin = ReaderTypeface.allCases.contains { ReaderFonts.postScriptName($0) == name }
        guard builtin || fonts.contains(where: { $0.postScriptName == name && isAvailable($0) }) else { return nil }
        return UIFont(name: name, size: size)
    }

    func isAvailable(_ font: ReaderUserFont) -> Bool {
        guard availablePostScriptNames.contains(font.postScriptName), let url = safeURL(for: font) else { return false }
        return Self.registeredFontMatches(url, postScriptName: font.postScriptName)
    }

    func importFonts(_ urls: [URL]) async {
        guard !busy, manifestReadable, !urls.isEmpty else { return }
        guard urls.count <= ReaderFontImportBudget.maximumFiles else {
            publish(ReaderFontError.tooManyFiles.localizedDescription, failed: true); return
        }
        busy = true
        defer { busy = false }
        let budget = ReaderFontImportBudget()
        let cancellation = ReaderImportCopyCancellation()
        var imported = 0, duplicates = 0
        var errors: [String] = []
        await withTaskCancellationHandler(operation: {
            for url in urls {
                var staged: StagedFont?
                var createdFinal: (url: URL, identity: ReaderImportStagingOwner.FileIdentity)?
                var registeredURL: URL?
                defer { staged?.lease.release() }
                do {
                    try cancellation.check(); try Task.checkCancellation()
                    let destination = directory, observe = importObserver
                    // Shared cancellation is checked by the existing bounded
                    // copy even when Foundation invokes its accessor elsewhere.
                    // Await the worker's actual completion before releasing any
                    // security scope, lease, FD or this library's busy owner.
                    let candidate = try await Task.detached(priority: .userInitiated) {
                        try Self.stage(url, in: destination, budget: budget,
                                       cancellation: cancellation, observe: observe)
                    }.value
                    staged = candidate
                    try cancellation.check(); try Task.checkCancellation()
                    if fonts.contains(where: { $0.sha256 == candidate.sha256 }) {
                        try candidate.lease.retireOwned(candidate.owner, authority: .notDispatched)
                        duplicates += 1; continue
                    }
                    guard UIFont(name: candidate.postScriptName, size: 18) == nil,
                          !fonts.contains(where: { $0.postScriptName == candidate.postScriptName }) else {
                        throw ReaderFontError.identityConflict(candidate.displayName)
                    }
                    let fileName = candidate.sha256 + "." + candidate.fileExtension
                    let finalURL = directory.appendingPathComponent(fileName)
                    let record = ReaderUserFont(id: UUID(), displayName: candidate.displayName,
                        postScriptName: candidate.postScriptName, familyName: candidate.familyName,
                        fileName: fileName, sha256: candidate.sha256)
                    let updated = fonts + [record]
                    // Prepare all throwing manifest encoding before registering.
                    let manifest = try JSONEncoder().encode(updated)
                    let expectedIdentity: ReaderImportStagingOwner.FileIdentity
                    if FileManager.default.fileExists(atPath: finalURL.path) {
                        let existing = try ReaderImportStagingLease.verifiedFile(at: finalURL)
                        guard existing.sha256 == candidate.sha256 else { throw ReaderFontError.invalidFile }
                        expectedIdentity = existing.identity // Never owned by this invocation.
                    } else {
                        try ReaderImportStagingLease.moveExclusively(candidate.url, to: finalURL)
                        // Capture the actual no-overwrite rename creation before
                        // directory fsync or any later operation may throw.
                        expectedIdentity = candidate.owner.payloadIdentity!
                        createdFinal = (finalURL, expectedIdentity)
                        try ReaderImportStagingLease.synchronizeDirectory(directory)
                    }
                    let final = try ReaderImportStagingLease.verifiedFile(at: finalURL)
                    guard final.sha256 == candidate.sha256, final.identity == expectedIdentity else {
                        throw ReaderFontError.invalidFile
                    }
                    try cancellation.check(); try Task.checkCancellation()
                    guard Self.register(finalURL) else { throw ReaderFontError.registrationFailed(candidate.displayName) }
                    registeredURL = finalURL // Only this successful registration may be undone.
                    try importObserver(.registered, finalURL)
                    let registeredFile = try ReaderImportStagingLease.verifiedFile(at: finalURL)
                    guard registeredFile.sha256 == candidate.sha256,
                          registeredFile.identity == expectedIdentity,
                          Self.registeredFontMatches(finalURL, postScriptName: candidate.postScriptName) else {
                        throw ReaderFontError.registrationFailed(candidate.displayName)
                    }
                    try cancellation.check(); try Task.checkCancellation()
                    // Retire the exact temporary/receipt before the nonthrowing
                    // manifest commit. A failure here still owns its new file
                    // and registration and takes the rollback path below.
                    try candidate.lease.retireOwned(candidate.owner, authority: .notDispatched)
                    defaults.set(manifest, forKey: manifestKey)
                    fonts = updated
                    normalizeChoiceOrder()
                    availablePostScriptNames.insert(record.postScriptName)
                    registeredURL = nil; createdFinal = nil
                    imported += 1
                } catch {
                    var cleanupFailure: Error?
                    do {
                        if let registeredURL {
                            // Never unregister an old same-name face, or delete
                            // its source if this operation's unregister fails.
                            guard Self.unregister(registeredURL) else { throw ReaderFontError.fontInUse }
                        }
                        if let createdFinal {
                            try Self.removeCreatedFont(createdFinal.url, identity: createdFinal.identity)
                        }
                        if let staged { try staged.lease.retireOwned(staged.owner, authority: .notDispatched) }
                    } catch { cleanupFailure = error }
                    if error is CancellationError {
                        if let cleanupFailure { errors.append("\(url.lastPathComponent)：\(cleanupFailure.localizedDescription)") }
                        break // Do not dispatch the remaining selected files.
                    }
                    errors.append("\(url.lastPathComponent)：\(error.localizedDescription)")
                    if let cleanupFailure { errors.append("\(url.lastPathComponent)：\(cleanupFailure.localizedDescription)") }
                    if let limit = error as? ReaderFontError, case .batchTooLarge = limit { break }
                }
            }
        }, onCancel: { cancellation.cancel() })
        if !errors.isEmpty { publish(errors.joined(separator: "\n"), failed: true) }
        else if imported > 0 { publish("已导入 \(imported) 个字体" + (duplicates > 0 ? "，\(duplicates) 个已存在" : "")) }
        else if duplicates > 0 { publish("所选字体已在字体库中") }
    }

    @discardableResult
    func remove(_ font: ReaderUserFont) -> Bool {
        guard !busy, manifestReadable, fonts.contains(where: { $0.id == font.id }) else { return false }
        let url = safeURL(for: font)
        do {
            let updated = fonts.filter { $0.id != font.id }
            let encoded = try JSONEncoder().encode(updated)
            if let url, availablePostScriptNames.contains(font.postScriptName) {
                guard Self.unregister(url) else {
                    throw ReaderFontError.fontInUse
                }
            }
            if let url, FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            defaults.set(encoded, forKey: manifestKey)
            fonts = updated
            normalizeChoiceOrder()
            availablePostScriptNames.remove(font.postScriptName)
            publish("字体已移除")
            return true
        } catch {
            // If file deletion failed after unregistering, make the retained
            // library entry usable again rather than claiming removal.
            if let url { _ = Self.register(url) }
            publish(error.localizedDescription, failed: true)
            return false
        }
    }

    func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        guard !busy, manifestReadable else { return }
        var reordered = fonts
        // SwiftUI's collection move preserves selected indices and destination
        // semantics. No font file or family identity changes during sorting.
        reordered.move(fromOffsets: source, toOffset: destination)
        do {
            defaults.set(try JSONEncoder().encode(reordered), forKey: manifestKey)
            fonts = reordered
        } catch { publish("字体顺序保存失败，原顺序已保留", failed: true) }
    }

    func clearFeedback() { feedbackGeneration = UUID(); message = nil; failure = nil }
    func reportFailure(_ text: String) { publish(text, failed: true) }

    private func safeURL(for font: ReaderUserFont) -> URL? {
        guard font.sha256.utf8.count == 64, font.sha256.utf8.allSatisfy({ (48...57).contains($0) || (97...102).contains($0) }),
              font.fileName == font.sha256 + ".ttf" || font.fileName == font.sha256 + ".otf" else { return nil }
        return directory.appendingPathComponent(font.fileName)
    }

    private func publish(_ text: String, failed: Bool = false) {
        guard presentationActive else { return }
        let generation = UUID()
        feedbackGeneration = generation
        message = failed ? nil : text
        failure = failed ? text : nil
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard self?.feedbackGeneration == generation else { return }
            self?.message = nil; self?.failure = nil
        }
    }

    private struct FontDescriptor: Sendable {
        let postScriptName: String
        let familyName: String
        let displayName: String
    }
    /// One worker transfers this immutable resource receipt to its awaiting
    /// MainActor; only that caller uses/releases the OS lease afterwards.
    private struct StagedFont: @unchecked Sendable {
        let url: URL
        let lease: ReaderImportStagingLease
        let owner: ReaderImportStagingOwner
        let fileExtension: String
        let postScriptName: String
        let familyName: String
        let displayName: String
        let sha256: String
    }

    nonisolated private static func stage(_ original: URL, in directory: URL,
        budget: ReaderFontImportBudget, cancellation: ReaderImportCopyCancellation,
        observe: @escaping ReaderFontImportObserver) throws -> StagedFont {
        let ext = original.pathExtension.lowercased()
        guard ext == "ttf" || ext == "otf" else { throw ReaderFontError.unsupportedFile }
        let scoped = original.startAccessingSecurityScopedResource()
        defer { if scoped { original.stopAccessingSecurityScopedResource() } }
        let selection = UUID().uuidString.lowercased()
        let staging = directory.appendingPathComponent(".import-staging", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        try ReaderImportStagingLease.synchronizeDirectory(directory)
        let lease = try ReaderImportStagingLease(stagingURL: staging) { checkpoint, payload in
            if checkpoint == .ownerDurable {
                // The existing copy has already admitted one regular open FD
                // at <=64MiB. Its durable receipt supplies that same FD's size
                // before the payload is opened or a single byte is copied.
                let receipt = staging.appendingPathComponent(".owners/" + selection + ".json")
                let owner = try JSONDecoder().decode(ReaderImportStagingOwner.self, from: Data(contentsOf: receipt))
                guard owner.id == selection, owner.stagedName == selection + ".source" else { throw ReaderFontError.invalidFile }
                try budget.reserve(owner.expectedBytes)
            }
            try observe(.staging(checkpoint), payload)
        }
        var owner: ReaderImportStagingOwner?
        do {
            let copied = try lease.copy(original, selection: selection, cancellation: cancellation)
            owner = copied
            try cancellation.check(); try Task.checkCancellation()
            guard let expected = copied.sha256, let identity = copied.payloadIdentity else { throw ReaderFontError.invalidFile }
            let url = lease.payloadURL(copied)
            // CoreText receives the same bounded, inode-bound bytes whose hash
            // the original FD copy retained, not a second path-based mapping.
            let fd = open(url.path, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC)
            guard fd >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            defer { Darwin.close(fd) }
            var before = stat(), after = stat()
            guard fstat(fd, &before) == 0, (before.st_mode & S_IFMT) == S_IFREG,
                  ReaderImportStagingOwner.FileIdentity(before) == identity,
                  before.st_size == copied.expectedBytes,
                  before.st_size > 0, before.st_size <= ReaderImportStagingLease.maximumInputBytes else {
                throw ReaderFontError.invalidFile
            }
            let handle = FileHandle(fileDescriptor: fd, closeOnDealloc: false)
            let bytes = try handle.read(upToCount: Int(copied.expectedBytes) + 1) ?? Data()
            guard bytes.count == Int(copied.expectedBytes), digest(bytes) == expected,
                  fstat(fd, &after) == 0,
                  ReaderImportStagingOwner.FileIdentity(after) == identity,
                  after.st_size == before.st_size,
                  after.st_mtimespec.tv_sec == before.st_mtimespec.tv_sec,
                  after.st_mtimespec.tv_nsec == before.st_mtimespec.tv_nsec,
                  after.st_ctimespec.tv_sec == before.st_ctimespec.tv_sec,
                  after.st_ctimespec.tv_nsec == before.st_ctimespec.tv_nsec else { throw ReaderFontError.invalidFile }
            try cancellation.check(); try Task.checkCancellation()
            guard let descriptors = CTFontManagerCreateFontDescriptorsFromData(bytes as CFData) as? [CTFontDescriptor],
                  !descriptors.isEmpty else { throw ReaderFontError.invalidFile }
            guard descriptors.count == 1, let descriptor = descriptors.first else {
                throw ReaderFontError.multipleFacesOrInstances
            }
            let value = try descriptorNames(descriptor)
            return StagedFont(url: url, lease: lease, owner: copied, fileExtension: ext,
                postScriptName: value.postScriptName, familyName: value.familyName,
                displayName: value.displayName, sha256: expected)
        } catch {
            if let owner { try? lease.retireOwned(owner, authority: .notDispatched) }
            lease.release()
            throw error
        }
    }

    /// Domain-specific rollback of this call's successful no-overwrite rename.
    /// Preexisting files, symlinks and a changed inode are never removed.
    nonisolated private static func removeCreatedFont(_ url: URL,
        identity: ReaderImportStagingOwner.FileIdentity) throws {
        let parent = open(url.deletingLastPathComponent().path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        defer { Darwin.close(parent) }
        var current = stat()
        if fstatat(parent, url.lastPathComponent, &current, AT_SYMLINK_NOFOLLOW) != 0 {
            guard errno == ENOENT else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
            return
        }
        guard (current.st_mode & S_IFMT) == S_IFREG,
              ReaderImportStagingOwner.FileIdentity(current) == identity else { throw ReaderFontError.invalidFile }
        guard unlinkat(parent, url.lastPathComponent, 0) == 0 else { throw NSError(domain: NSPOSIXErrorDomain, code: Int(errno)) }
        try ReaderImportStagingLease.synchronizeDirectory(url.deletingLastPathComponent())
    }

    nonisolated private static func descriptor(at url: URL, bundledVariableInstances: Bool = false) throws -> FontDescriptor {
        guard let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url as CFURL) as? [CTFontDescriptor],
              var descriptor = descriptors.first else { throw ReaderFontError.invalidFile }
        if descriptors.count != 1 {
            // CoreText enumerates the fixed Noto Sans VF's named instances as
            // multiple descriptors. They are not separate physical font files.
            // This exception belongs only to that bundled, source-pinned slot.
            // User import still requires one descriptor; multi-instance user
            // VFs/collections remain outside its current admission contract.
            guard bundledVariableInstances else { throw ReaderFontError.multipleFacesOrInstances }
            descriptor = try bundledVariableDescriptor(descriptors, at: url)
        }
        return try descriptorNames(descriptor)
    }

    nonisolated private static func descriptorNames(_ descriptor: CTFontDescriptor) throws -> FontDescriptor {
        guard let name = CTFontDescriptorCopyAttribute(descriptor, kCTFontNameAttribute) as? String,
              !name.isEmpty else { throw ReaderFontError.invalidFile }
        let family = CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String ?? name
        let display = CTFontDescriptorCopyAttribute(descriptor, kCTFontDisplayNameAttribute) as? String ?? family
        return FontDescriptor(postScriptName: name, familyName: family, displayName: display)
    }

    nonisolated private static func bundledVariableDescriptor(_ descriptors: [CTFontDescriptor], at url: URL) throws -> CTFontDescriptor {
        guard let first = descriptors.first,
              let family = CTFontDescriptorCopyAttribute(first, kCTFontFamilyNameAttribute) as? String,
              !family.isEmpty else { throw ReaderFontError.invalidFile }
        let native = CTFontCreateWithFontDescriptor(first, 18, nil)
        guard let axes = CTFontCopyVariationAxes(native) as? [[String: Any]], !axes.isEmpty,
              let weight = axes.first(where: { ($0[kCTFontVariationAxisIdentifierKey as String] as? NSNumber)?.uint32Value == 0x77676874 }),
              let minimum = weight[kCTFontVariationAxisMinimumValueKey as String] as? NSNumber,
              let maximum = weight[kCTFontVariationAxisMaximumValueKey as String] as? NSNumber,
              minimum.doubleValue.isFinite, maximum.doubleValue.isFinite,
              minimum.doubleValue <= 400, maximum.doubleValue >= 400 else { throw ReaderFontError.invalidFile }
        let expectedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        var regular: CTFontDescriptor?
        for descriptor in descriptors {
            let font = CTFontCreateWithFontDescriptor(descriptor, 18, nil)
            guard CTFontDescriptorCopyAttribute(descriptor, kCTFontFamilyNameAttribute) as? String == family,
                  let actualURL = CTFontCopyAttribute(font, kCTFontURLAttribute) as? URL,
                  actualURL.standardizedFileURL.resolvingSymlinksInPath() == expectedURL,
                  let actualAxes = CTFontCopyVariationAxes(font) as? [[String: Any]],
                  NSArray(array: actualAxes).isEqual(to: axes) else { throw ReaderFontError.invalidFile }
            if let values = CTFontCopyVariation(font) as? [NSNumber: NSNumber],
               values[NSNumber(value: 0x77676874)]?.doubleValue == 400 { regular = descriptor }
        }
        // Prefer the native regular instance. resolvedFont still supplies an
        // explicit real wght=400 descriptor, including when no named regular
        // instance is exposed by this platform's CoreText enumeration.
        return regular ?? first
    }

    nonisolated private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// CoreText supplies the registered face's original URL. A same-name UIFont
    /// alone cannot prove that the validated, hash-addressed library file won
    /// font matching over a system or bundled face with the same identity.
    private static func registeredFontMatches(_ expectedURL: URL, postScriptName: String) -> Bool {
        guard let font = UIFont(name: postScriptName, size: 18), font.fontName == postScriptName,
              let registeredURL = CTFontCopyAttribute(font as CTFont, kCTFontURLAttribute) as? URL,
              registeredURL.isFileURL else { return false }
        return registeredURL.standardizedFileURL.resolvingSymlinksInPath()
            == expectedURL.standardizedFileURL.resolvingSymlinksInPath()
    }

    nonisolated private static func register(_ url: URL) -> Bool {
        var error: Unmanaged<CFError>?
        let result = CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        if let error { _ = error.takeRetainedValue() }
        return result
    }

    nonisolated private static func unregister(_ url: URL) -> Bool {
        var error: Unmanaged<CFError>?
        let result = CTFontManagerUnregisterFontsForURL(url as CFURL, .process, &error)
        if let error { _ = error.takeRetainedValue() }
        return result
    }
}

/// Thin observers expose real production checkpoints only; no fake descriptor,
/// SHA, bytes, registration result or permission can be injected through them.
enum ReaderFontImportCheckpoint: Equatable {
    case staging(ReaderImportStagingCheckpoint)
    case registered
}
typealias ReaderFontImportObserver = @Sendable (ReaderFontImportCheckpoint, URL) throws -> Void

/// Font-import resource budget, not a replacement for the shared copy engine.
/// Every admitted file consumes its full size, including duplicates/failures.
private final class ReaderFontImportBudget: @unchecked Sendable {
    static let maximumFiles = 32
    private let lock = NSLock()
    private var remaining: Int64 = 256 * 1024 * 1024
    func reserve(_ bytes: Int64) throws {
        lock.lock(); defer { lock.unlock() }
        guard bytes >= 0, bytes <= ReaderImportStagingLease.maximumInputBytes else { throw CocoaError(.fileReadTooLarge) }
        guard bytes <= remaining else { throw ReaderFontError.batchTooLarge }
        remaining -= bytes
    }
}

private enum ReaderFontError: LocalizedError {
    case unsupportedFile, invalidFile, fontInUse, multipleFacesOrInstances, tooManyFiles, batchTooLarge
    case identityConflict(String), registrationFailed(String)
    var errorDescription: String? {
        switch self {
        case .tooManyFiles: return "一次最多选择 32 个字体文件"
        case .batchTooLarge: return "本次字体文件合计不能超过 256 MiB"
        case .unsupportedFile: return "请选择 TTF 或 OTF 字体文件"
        case .invalidFile: return "这个文件不是可用的单字面字体"
        case .multipleFacesOrInstances: return "该字体包含多个字面或命名实例，暂不支持导入"
        case .fontInUse: return "字体仍在使用，请切换字体后再移除"
        case .identityConflict(let name): return "“\(name)”与已加载字体名称相同，未替换原字体"
        case .registrationFailed(let name): return "无法使用字体“\(name)”，原字体已保留"
        }
    }
}
