import SwiftUI

/// A new sheet, including a reopen of the same source, gets a distinct read owner.
@MainActor
struct ReaderSourceDebugPresentation: Identifiable {
    let id: UUID
    let source: ReaderOnlineSource
    let owner: ReaderSourceDebugOwner

    init(source: ReaderOnlineSource, defaults: UserDefaults = .standard) {
        let identity = UUID()
        id = identity; self.source = source
        owner = ReaderSourceDebugOwner(presentationID: identity, sourceID: source.id, defaults: defaults)
    }
}

/// Ephemeral debug input/result ownership. Core owns rule execution; this owner
/// cancels only reads and never creates a source mutation or an operation receipt.
@MainActor
final class ReaderSourceDebugOwner: ObservableObject {
    let presentationID: UUID
    let sourceID: String
    @Published private(set) var key: String
    @Published private(set) var responses: String
    @Published private(set) var result: String?
    @Published private(set) var failure: String?
    @Published private(set) var running = false
    private let defaults: UserDefaults
    private var active = true
    private var generation = UUID()
    private var task: Task<Void, Never>?

    private struct ReadToken {
        let presentationID: UUID
        let sourceID: String
        let generation: UUID
    }

    init(presentationID: UUID = UUID(), sourceID: String, defaults: UserDefaults = .standard) {
        self.presentationID = presentationID; self.sourceID = sourceID; self.defaults = defaults
        let saved = defaults.dictionary(forKey: "reader.source-debug." + sourceID)
        key = saved?["key"] as? String ?? ""
        responses = saved?["responses"] as? String ?? "{}"
    }

    deinit { task?.cancel() }

    func updateKey(_ value: String) {
        guard active, key != value else { return }
        retireRead(clearOutput: true); key = value
    }

    func updateResponses(_ value: String) {
        guard active, responses != value else { return }
        retireRead(clearOutput: true); responses = value
    }

    func stop() {
        guard active else { return }
        retireRead(clearOutput: false); saveDraft()
    }

    func retire() {
        guard active else { return }
        saveDraft(); active = false; retireRead(clearOutput: false)
    }

    private func saveDraft() {
        defaults.set(["key": key, "responses": responses], forKey: "reader.source-debug." + sourceID)
    }

    private func retireRead(clearOutput: Bool) {
        generation = UUID(); task?.cancel(); task = nil; running = false
        if clearOutput { result = nil; failure = nil }
    }

    /// Bind the redundant wire identity without editing the user's JSON draft.
    /// Other DTO fields remain Core-owned and are passed through unchanged.
    nonisolated static func parameters(sourceID: String, key: String, responses: String) throws -> Data {
        guard !sourceID.isEmpty else { throw ReaderLibraryError.invalidResponse("debug source identity") }
        let object = try JSONSerialization.jsonObject(with: Data(responses.utf8))
        guard var payload = object as? [String: Any] else {
            throw ReaderLibraryError.invalidResponse("debug responses must be an object")
        }
        if let explicit = payload["sourceId"] {
            guard let identity = explicit as? String, identity == sourceID else {
                throw ReaderLibraryError.invalidResponse("响应中的 sourceId 与当前书源不一致")
            }
        }
        payload["sourceId"] = sourceID
        return try JSONSerialization.data(withJSONObject: ["sourceId": sourceID, "key": key, "responses": payload], options: [.sortedKeys])
    }

    private func accepts(_ token: ReadToken) -> Bool {
        active && running && token.presentationID == presentationID && token.sourceID == sourceID && token.generation == generation
    }

    @discardableResult
    func run(_ read: @escaping @MainActor (Data) async throws -> Data) -> Task<Void, Never>? {
        guard active, !running else { return nil }
        let parameters: Data
        do { parameters = try Self.parameters(sourceID: sourceID, key: key, responses: responses) }
        catch { failure = error.localizedDescription; result = nil; return nil }
        generation = UUID()
        let token = ReadToken(presentationID: presentationID, sourceID: sourceID, generation: generation)
        running = true; failure = nil; result = nil
        let readTask = Task { @MainActor [weak self] in
            do {
                try Task.checkCancellation()
                let data = try await read(parameters)
                try Task.checkCancellation()
                guard self?.accepts(token) == true else { return }
                let object = try JSONSerialization.jsonObject(with: data)
                let output = String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self)
                if self?.accepts(token) == true { self?.result = output }
            } catch is CancellationError {
                // Cancellation ends this observer, not a successful debug result.
            } catch {
                if !Task.isCancelled, self?.accepts(token) == true { self?.failure = error.localizedDescription }
            }
            guard self?.accepts(token) == true else { return }
            self?.running = false; self?.task = nil
        }
        task = readTask
        return readTask
    }
}

struct ReaderSourceDebugPanel: View {
    let source: ReaderOnlineSource
    let service: any ReaderOnlineServing
    @ObservedObject var owner: ReaderSourceDebugOwner
    let closePresentation: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Button("关闭") { owner.retire(); closePresentation() }
                    .accessibilityIdentifier("source-debug-close")
                Spacer(); Text("规则调试").font(ReaderTypography.font(.controlHeader)); Spacer()
                Button(owner.running ? "停止" : "运行") {
                    if owner.running { owner.stop() }
                    else { owner.run { [service] in try await service.onlineCommand("source.debug", parameters: $0, operationID: nil) } }
                }.accessibilityIdentifier("source-debug-run")
            }
            Text(source.name).font(ReaderTypography.font(.caption))
            TextField("关键词或调试入口 URL", text: Binding(get: { owner.key }, set: owner.updateKey)).textInputAutocapitalization(.never).readerField()
                .accessibilityIdentifier("source-debug-key")
            Text("按 Core 调试合同回放真实响应。JSON 可包含 searchResponse、detailResponse、tocResponse、contentResponse；此操作不保存书源。").font(ReaderTypography.font(.caption))
            TextEditor(text: Binding(get: { owner.responses }, set: owner.updateResponses)).font(.system(.caption, design: .monospaced)).accessibilityLabel("真实响应 JSON").frame(minHeight: 140)
                .accessibilityIdentifier("source-debug-responses")
            if owner.running { ProgressView("正在回放规则") }
            if let failure = owner.failure { ReaderPageState(title: "调试未完成", detail: failure).accessibilityIdentifier("source-debug-failure") }
            if let result = owner.result { ScrollView { Text(result).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading).accessibilityIdentifier("source-debug-result") } }
        }.padding(20).onDisappear { owner.retire() }
    }
}
