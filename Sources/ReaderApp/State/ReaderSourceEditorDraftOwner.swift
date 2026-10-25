import Foundation
import Combine
import CryptoKit

/// Owns only the user's source-editor input and its replacement/read identity.
/// The shared action owner and Runtime still own every original write and ACK.
@MainActor
final class ReaderSourceEditorDraftOwner: ObservableObject {
    struct Target: Equatable {
        let text: String
        let label: String
        let savedSourceID: String?
        let savedSourceVersion: String?

        static func savedSource(_ sourceID: String, version: String, name: String, text: String) -> Self {
            .init(text: text, label: "编辑“\(name)”", savedSourceID: sourceID, savedSourceVersion: version)
        }
        static func imported(_ text: String, label: String) -> Self {
            .init(text: text, label: label, savedSourceID: nil, savedSourceVersion: nil)
        }
    }
    struct ReadRequest: Equatable {
        fileprivate let id: UUID
        fileprivate let lifecycle: UUID
        fileprivate let revision: UUID
    }
    struct Replacement: Equatable {
        fileprivate let id: UUID
        fileprivate let lifecycle: UUID
        fileprivate let revision: UUID
        fileprivate let generation: UUID
        let target: Target
    }
    struct SaveInput {
        fileprivate let lifecycle: UUID
        fileprivate let revision: UUID
        fileprivate let generation: UUID
        let text: String
        var bytes: Data { Data(text.utf8) }
    }
    enum OpenResult {
        case ignored
        case opened
        case confirmation(Replacement)
    }
    private struct Baseline: Codable {
        let sha256: String
        let origin: String
        let identity: String
        let version: String?
    }
    private struct Metadata: Codable {
        let schemaVersion: Int
        let revision: UUID
        let draftSHA256: String
        let clean: Baseline?
        let accepted: AcceptedSave?
    }
    private struct AcceptedSave: Codable {
        let operationID: String
        let inputSHA256: String
        let revision: UUID
    }

    @Published private(set) var draft = ""
    @Published private(set) var presented = false
    @Published private(set) var editorGeneration = UUID()
    let actions: ReaderLibraryActionOwner
    private let defaults: UserDefaults
    private let draftKey: String
    private let metadataKey: String
    private var metadataBytes: Data?
    private var baseline: Baseline?
    private var revision = UUID()
    private var lifecycle = UUID()
    private var active = false
    private var readRequest: ReadRequest?
    private var readTask: (request: ReadRequest, task: Task<Void, Never>)?
    private var replacement: Replacement?
    private var actionObservation: AnyCancellable?
    private var accepted: AcceptedSave?

    var canReplace: Bool { active && accepted == nil && !actions.busy && !actions.hasPending }
    var hasUnsavedInput: Bool {
        guard let baseline else { return !draft.isEmpty }
        return baseline.sha256 != Self.sha(draft)
    }
    var acceptedOperationID: String? { accepted?.operationID }

    init(actions: ReaderLibraryActionOwner, defaults: UserDefaults = .standard,
         draftKey: String = "reader.source-editor.draft") {
        self.actions = actions; self.defaults = defaults; self.draftKey = draftKey
        metadataKey = draftKey + ".metadata.v1"
        reloadPersistedDraft()
        actionObservation = actions.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func activate() {
        reloadPersistedDraft()
        lifecycle = UUID(); active = true
        invalidateIncoming()
    }
    func retire() {
        active = false; lifecycle = UUID(); presented = false
        invalidateIncoming()
    }
    func close() {
        presented = false
        invalidateIncoming()
    }
    func resumeDraft() {
        guard active else { return }
        reloadIfChanged()
        invalidateIncoming(); presented = true
    }
    func updateDraft(_ text: String) {
        guard canReplace, presented else { return }
        guard persistedInputIsCurrent else { reloadPersistedDraft(); invalidateIncoming(); return }
        guard text != draft else { return }
        invalidateIncoming()
        store(text, clean: baseline)
    }

    func beginRead() -> ReadRequest? {
        guard canReplace else { return nil }
        reloadIfChanged()
        guard canReplace else { return nil }
        invalidateIncoming()
        let request = ReadRequest(id: UUID(), lifecycle: lifecycle, revision: revision)
        readRequest = request
        return request
    }
    /// Own only the current link read's cancellation and publication. Runtime
    /// still owns HTTP, and the action owner still owns accepted saves.
    @discardableResult
    func performRead(_ request: ReadRequest,
                     operation: @escaping () async throws -> Target,
                     completion: @escaping (OpenResult) -> Void,
                     failure: @escaping (Error) -> Void) -> Task<Void, Never>? {
        guard accepts(request), readTask == nil else { return nil }
        let task = Task { [self] in
            defer { if readTask?.request == request { readTask = nil } }
            do {
                try Task.checkCancellation()
                guard accepts(request) else { return }
                let target = try await operation()
                try Task.checkCancellation()
                guard accepts(request) else { return }
                completion(finishRead(request, target: target))
            } catch {
                guard !Task.isCancelled, accepts(request) else { return }
                cancelRead()
                failure(error)
            }
        }
        readTask = (request, task)
        return task
    }
    func cancelRead() {
        readTask?.task.cancel(); readTask = nil
        readRequest = nil
    }
    func accepts(_ request: ReadRequest) -> Bool {
        canReplace && readRequest == request && request.lifecycle == lifecycle && request.revision == revision && persistedInputIsCurrent
    }
    func finishRead(_ request: ReadRequest, target: Target) -> OpenResult {
        guard accepts(request) else { return .ignored }
        return offer(target)
    }
    func offer(_ target: Target) -> OpenResult {
        guard canReplace else { return .ignored }
        reloadIfChanged()
        guard canReplace else { return .ignored }
        invalidateIncoming()
        if hasUnsavedInput, draft != target.text {
            let intent = Replacement(id: UUID(), lifecycle: lifecycle, revision: revision,
                                     generation: editorGeneration, target: target)
            replacement = intent
            return .confirmation(intent)
        }
        adopt(target)
        return .opened
    }
    @discardableResult
    func confirm(_ intent: Replacement) -> Bool {
        guard canReplace, persistedInputIsCurrent, replacement == intent,
              intent.lifecycle == lifecycle, intent.revision == revision,
              intent.generation == editorGeneration else { return false }
        replacement = nil
        adopt(intent.target)
        return true
    }
    func dismissConfirmation() { replacement = nil }
    func refreshPersistedDraft() {
        guard active, !actions.busy, !actions.hasPending else { return }
        reloadIfChanged()
    }

    func isCurrentEditor(_ input: SaveInput) -> Bool {
        active && presented && input.lifecycle == lifecycle && input.generation == editorGeneration &&
            input.revision == revision && input.text == draft && persistedInputIsCurrent
    }
    @discardableResult
    func save(using action: @escaping (String, SaveInput) async throws -> Bool) async -> Bool {
        guard canReplace, presented, persistedInputIsCurrent else { return false }
        invalidateIncoming()
        let input = SaveInput(lifecycle: lifecycle, revision: revision,
                              generation: editorGeneration, text: draft)
        return await actions.perform("保存书源", scope: "online", ended: { [weak self] id, _ in self?.acceptedDidEnd(id) }) { [self] operationID in
            persistAccepted(AcceptedSave(operationID: operationID, inputSHA256: Self.sha(input.text), revision: input.revision))
            try await executeSave(operationID, input: input, action: action)
        }
    }
    @discardableResult
    func restoreSave(using action: @escaping (String, SaveInput) async throws -> Bool) -> Bool {
        guard active else { return false }
        reloadIfChanged()
        guard let accepted, persistedInputIsCurrent, accepted.revision == revision,
              accepted.inputSHA256 == Self.sha(draft) else { return false }
        if actions.pendingOperationID == accepted.operationID { return true }
        let input = SaveInput(lifecycle: lifecycle, revision: revision, generation: editorGeneration, text: draft)
        return actions.restoreAccepted(id: accepted.operationID, label: "保存书源", scope: "online",
                                       ended: { [weak self] id, _ in self?.acceptedDidEnd(id) }) { [self] operationID in
            try await executeSave(operationID, input: input, action: action)
        }
    }
    private func executeSave(_ operationID: String, input: SaveInput,
                             action: @escaping (String, SaveInput) async throws -> Bool) async throws {
        let allSaved = try await action(operationID, input)
        guard accepted?.operationID == operationID, input.revision == revision,
              input.text == draft, persistedInputIsCurrent else { return }
        if allSaved {
            let closeCurrentEditor = isCurrentEditor(input)
            store(input.text, clean: Baseline(sha256: Self.sha(input.text), origin: "original-save-ack",
                                               identity: operationID, version: nil))
            if closeCurrentEditor { close() }
        } else {
            // A package may have confirmed successes and definite item
            // failures. It has ended, but its whole input is still unsaved.
            persistAccepted(nil)
        }
    }
    private func acceptedDidEnd(_ operationID: String) {
        guard accepted?.operationID == operationID, persistedInputIsCurrent else { return }
        // This callback runs after ActionOwner has ended the exact accepted
        // intent. Unknowns never invoke it; no willChange timing is consulted.
        persistAccepted(nil)
    }

    private func adopt(_ target: Target) {
        let clean: Baseline?
        // Only a typed definition from Core's source projection is already
        // saved input. Imported bytes remain unsaved, even when valid JSON.
        if let id = target.savedSourceID, !id.isEmpty,
           let version = target.savedSourceVersion, !version.isEmpty {
            clean = Baseline(sha256: Self.sha(target.text), origin: "core-source-definition", identity: id, version: version)
        } else { clean = nil }
        invalidateIncoming(); store(target.text, clean: clean); presented = true
    }
    private func invalidateIncoming() {
        cancelRead()
        editorGeneration = UUID(); replacement = nil
    }
    private var persistedInputIsCurrent: Bool {
        (defaults.string(forKey: draftKey) ?? "") == draft && defaults.data(forKey: metadataKey) == metadataBytes
    }
    private func reloadIfChanged() {
        if !persistedInputIsCurrent { reloadPersistedDraft() }
    }
    private func reloadPersistedDraft() {
        draft = defaults.string(forKey: draftKey) ?? ""
        metadataBytes = defaults.data(forKey: metadataKey)
        if let metadataBytes, let metadata = try? JSONDecoder().decode(Metadata.self, from: metadataBytes), metadata.schemaVersion == 1 {
            accepted = metadata.accepted
            if metadata.draftSHA256 == Self.sha(draft) {
                revision = metadata.revision
                baseline = metadata.clean.flatMap { clean in
                    guard !clean.identity.isEmpty,
                          clean.origin == "original-save-ack" || (clean.origin == "core-source-definition" && !(clean.version ?? "").isEmpty) else { return nil }
                    return clean
                }
            } else { revision = UUID(); baseline = nil }
        } else {
            // Legacy, malformed or externally changed input has no reliable
            // clean baseline. Never infer saved state by parsing or reading Core.
            revision = UUID(); baseline = nil; accepted = nil
        }
    }
    private func persistAccepted(_ value: AcceptedSave?) {
        let metadata = Metadata(schemaVersion: 1, revision: revision, draftSHA256: Self.sha(draft), clean: baseline, accepted: value)
        guard let encoded = try? JSONEncoder().encode(metadata) else { return }
        objectWillChange.send()
        defaults.set(encoded, forKey: metadataKey); metadataBytes = encoded; accepted = value
    }
    private func store(_ text: String, clean: Baseline?) {
        let nextRevision = UUID()
        let metadata = Metadata(schemaVersion: 1, revision: nextRevision, draftSHA256: Self.sha(text), clean: clean, accepted: nil)
        // Encoding these fixed scalar fields cannot fail; retain old input if it does.
        guard let encoded = try? JSONEncoder().encode(metadata) else { return }
        defaults.set(text, forKey: draftKey)
        defaults.set(encoded, forKey: metadataKey)
        draft = text; revision = nextRevision; baseline = clean; metadataBytes = encoded; accepted = nil
    }
    private static func sha(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
