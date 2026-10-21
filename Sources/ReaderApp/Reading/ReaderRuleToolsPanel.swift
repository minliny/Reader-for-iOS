import SwiftUI
import UniformTypeIdentifiers
#if DEBUG
import CryptoKit
import OSLog

@MainActor
private enum ReaderTXTPreviewTrace {
    private static let logger = Logger(subsystem: "io.reader.minliny", category: "reader-txt-preview")
    private struct Input: Encodable {
        let sessionID: UUID
        let bookID: String
        let sourceSHA: String
        let draft: ReaderTXTTOCRuleDraft
        let editingID: Int64?
    }
    static func emit(_ event: String) { logger.notice("\(event, privacy: .public)") }
    static func inputSHA(_ value: ReaderRuleWorkspace.TXTPreviewInput) -> String {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let input = Input(sessionID: value.sessionID, bookID: value.bookID, sourceSHA: value.sourceSHA,
                          draft: value.draft, editingID: value.editingID)
        guard let data = try? encoder.encode(input) else { return "unavailable" }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
    static func errorCategory(_ error: Error) -> String {
        if error is DecodingError { return "host.decoding" }
        guard let value = error as? ReaderLibraryError else { return "other" }
        switch value {
        case .closed: return "host.closed"
        case .busy: return "host.busy"
        case .unsupportedFile: return "host.unsupportedFile"
        case .invalidPosition: return "host.invalidPosition"
        case .invalidResponse: return "host.invalidResponse"
        case .operationPending: return "host.operationPending"
        case .core(let code, _, _, _):
            let known = ["INVALID_PARAMS", "INTERNAL", "BUSY", "TIMEOUT", "CANCELLED", "NOT_FOUND", "UNKNOWN_METHOD", "UNSUPPORTED", "IO_ERROR", "CONFLICT"]
            return known.contains(code) ? "core." + code : "core.other"
        }
    }
}
#endif

@MainActor
final class ReaderRuleWorkspace: ObservableObject {
    enum Kind: String, CaseIterable { case replace = "替换", txt = "TXT目录", dictionary = "字典", hierarchy = "本书分组" }
    @Published var kind: Kind = .replace { didSet { if kind != oldValue { invalidateTXTPreview(reason: "kind.changed") } } }
    @Published var replaceRules: [ReaderReplaceRule] = []
    @Published var txtRules: [ReaderTXTTOCRule] = [] { didSet { if txtRules != oldValue { invalidateTXTPreview(reason: "savedRules.changed") } } }
    @Published var dictionaryRules: [ReaderDictionaryRule] = []
    @Published var replaceDraft = ReaderReplaceRuleDraft(pattern: "") { didSet { persistDrafts() } }
    @Published var txtDraft = ReaderTXTTOCRuleDraft(rule: "") {
        didSet {
#if DEBUG
            ReaderTXTPreviewTrace.emit("event=draft.didSet sameValue=\(txtDraft == oldValue)")
#endif
            invalidateTXTPreview(reason: "draft.didSet"); persistDrafts()
        }
    }
    @Published var dictionaryDraft = ReaderDictionaryRule(name: "") { didSet { persistDrafts() } }
    @Published var editingReplace: Int64? { didSet { persistDrafts() } }
    @Published var editingTXT: Int64? { didSet { invalidateTXTPreview(reason: "editingID.didSet"); persistDrafts() } }
    @Published var dictionaryWord = ""
    @Published var dictionaryResult: String?
    @Published var hierarchyJSON = "[]" { didSet { persistDrafts() } }
    @Published var hierarchyPreview: ReaderDirectoryRulesResult?
    var hierarchyPreviewInput: String?
    @Published var replacementPreview: ReaderReplacePreview?
    @Published var validation: String?
    @Published var failure: String?
    @Published var loading = false
    @Published private(set) var draftFailure: String?
    struct TXTPreviewInput: Equatable {
        let sessionID: UUID
        let bookID: String
        let sourceSHA: String
        let draft: ReaderTXTTOCRuleDraft
        let editingID: Int64?
    }
    @Published private(set) var txtPreview: ReaderTXTTOCRulePreview?
    @Published private(set) var txtPreviewInput: TXTPreviewInput?
    @Published private(set) var txtPreviewLoading = false
    @Published private(set) var txtPreviewFailure: String?
    private var txtPreviewGeneration = UUID()
    private var txtPreviewTask: Task<Void, Never>?
    private struct Drafts: Codable {
        let replacement: ReaderReplaceRuleDraft
        let txt: ReaderTXTTOCRuleDraft
        let dictionary: ReaderDictionaryRule
        let replacementID: Int64?
        let txtID: Int64?
        let hierarchy: String
    }
    private var draftKey = ""
    private let defaults: UserDefaults
    var generation = UUID()
    init(identity: String, defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let key = "reader.toolDrafts.v1." + identity
        if let data = defaults.data(forKey: key) {
            do {
                let saved = try JSONDecoder().decode(Drafts.self, from: data)
                replaceDraft = saved.replacement; txtDraft = saved.txt; dictionaryDraft = saved.dictionary
                editingReplace = saved.replacementID; editingTXT = saved.txtID; hierarchyJSON = saved.hierarchy
            } catch { draftFailure = "规则草稿无法读取，原草稿已保留" }
        }
        draftKey = key
    }
    deinit { txtPreviewTask?.cancel() }

    func invalidateTXTPreview(reason: String = "caller") {
#if DEBUG
        let previousGeneration = txtPreviewGeneration
        let previousInput = txtPreviewInput.map { ReaderTXTPreviewTrace.inputSHA($0) } ?? "none"
        let hadTask = txtPreviewTask != nil, hadResult = txtPreview != nil, wasLoading = txtPreviewLoading
#endif
        txtPreviewGeneration = UUID(); txtPreviewTask?.cancel(); txtPreviewTask = nil
        txtPreview = nil; txtPreviewInput = nil; txtPreviewFailure = nil; txtPreviewLoading = false
#if DEBUG
        ReaderTXTPreviewTrace.emit("event=invalidate reason=\(reason) previousGeneration=\(previousGeneration) generation=\(txtPreviewGeneration) inputSHA=\(previousInput) hadTask=\(hadTask) hadResult=\(hadResult) wasLoading=\(wasLoading)")
#endif
    }
    func previewTXT(for book: ReaderBook, sessionID: UUID, service: any ReaderReadingToolsServing,
                    isCurrent: @escaping () -> Bool) {
        invalidateTXTPreview(reason: "preview.start")
        let generation = txtPreviewGeneration
        let input = TXTPreviewInput(sessionID: sessionID, bookID: book.id,
            sourceSHA: String(book.bookId.dropFirst("local:".count)), draft: txtDraft, editingID: editingTXT)
        txtPreviewInput = input; txtPreviewLoading = true
#if DEBUG
        let inputSHA = ReaderTXTPreviewTrace.inputSHA(input)
        ReaderTXTPreviewTrace.emit("event=workspace.dispatch generation=\(generation) session=\(sessionID) inputSHA=\(inputSHA) ruleUTF8Bytes=\(input.draft.rule.utf8.count) nameUTF8Bytes=\(input.draft.name.utf8.count) exampleUTF8Bytes=\(input.draft.example?.utf8.count ?? 0) editingExisting=\(input.editingID != nil) enabled=\(input.draft.enable) serial=\(input.draft.serialNumber)")
#endif
        txtPreviewTask = Task { [weak self] in
            guard let self else { return }
            defer {
                if txtPreviewGeneration == generation { txtPreviewLoading = false; txtPreviewTask = nil }
            }
            do {
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=service.begin generation=\(generation) inputSHA=\(inputSHA)")
#endif
                let result = try await service.previewTXTTOCRule(for: book, draft: input.draft,
                                                                 editingRuleID: input.editingID, limit: 20)
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=service.result generation=\(generation) inputSHA=\(inputSHA) status=\(result.draftStatus.rawValue) matchCount=\(result.draftMatchCount) chapterCount=\(result.chapterCount) resultChapters=\(result.chapters.count) regexError=\(result.regexError != nil) draftSelected=\(result.draftSelected) automaticFallback=\(result.automaticFallback)")
#endif
                guard !Task.isCancelled, txtPreviewGeneration == generation, kind == .txt,
                      txtDraft == input.draft, editingTXT == input.editingID, isCurrent(),
                      result.sourceId == book.sourceId, result.bookId == book.bookId,
                      result.sourceSha256 == input.sourceSHA else {
#if DEBUG
                    ReaderTXTPreviewTrace.emit("event=discard.result generation=\(generation) currentGeneration=\(txtPreviewGeneration) inputSHA=\(inputSHA) cancelled=\(Task.isCancelled) generationMatches=\(txtPreviewGeneration == generation) kindTXT=\(kind == .txt) draftMatches=\(txtDraft == input.draft) editingMatches=\(editingTXT == input.editingID) ownerCurrent=\(isCurrent()) sourceMatches=\(result.sourceId == book.sourceId) bookMatches=\(result.bookId == book.bookId) sourceSHAMatches=\(result.sourceSha256 == input.sourceSHA)")
#endif
                    return
                }
                txtPreview = result
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=published.result generation=\(generation) inputSHA=\(inputSHA) status=\(result.draftStatus.rawValue)")
#endif
            } catch is CancellationError {
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=service.cancelled generation=\(generation) inputSHA=\(inputSHA)")
#endif
            }
            catch {
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=service.error generation=\(generation) inputSHA=\(inputSHA) category=\(ReaderTXTPreviewTrace.errorCategory(error))")
#endif
                guard !Task.isCancelled, txtPreviewGeneration == generation, kind == .txt,
                      txtDraft == input.draft, editingTXT == input.editingID, isCurrent() else {
#if DEBUG
                    ReaderTXTPreviewTrace.emit("event=discard.error generation=\(generation) currentGeneration=\(txtPreviewGeneration) inputSHA=\(inputSHA) cancelled=\(Task.isCancelled) generationMatches=\(txtPreviewGeneration == generation) kindTXT=\(kind == .txt) draftMatches=\(txtDraft == input.draft) editingMatches=\(editingTXT == input.editingID) ownerCurrent=\(isCurrent())")
#endif
                    return
                }
                txtPreviewFailure = error.localizedDescription
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=published.error generation=\(generation) inputSHA=\(inputSHA) category=\(ReaderTXTPreviewTrace.errorCategory(error))")
#endif
            }
        }
    }
    private func persistDrafts() {
        guard !draftKey.isEmpty, draftFailure == nil else { return }
        do {
            let value = Drafts(replacement: replaceDraft, txt: txtDraft, dictionary: dictionaryDraft,
                replacementID: editingReplace, txtID: editingTXT, hierarchy: hierarchyJSON)
            defaults.set(try JSONEncoder().encode(value), forKey: draftKey)
        } catch { draftFailure = "规则草稿尚未保存，请保留当前编辑" }
    }
}

private struct ReaderRuleDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json, .plainText] }
    var text: String
    init(text: String = "") { self.text = text }
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents, let text = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadInapplicableStringEncoding)
        }
        self.text = text
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// Rule import/export is a registered system-file boundary. Core validates and
/// mutates rules; this surface never parses patterns or rewrites book content.
struct ReaderRuleToolsPanel: View {
    @ObservedObject var model: ReaderApplicationModel
    @ObservedObject var state: ReaderRuleWorkspace
    let book: ReaderBook
    @State private var importFile = false
    @State private var exportFile = false
    @State private var exportDocument = ReaderRuleDocument()
    @State private var presented = false
    @State private var fileGeneration = UUID()
    @StateObject private var confirmation = ReaderNativeAlertOwner()
    @Environment(\.colorScheme) private var scheme
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Picker("规则类型", selection: $state.kind) {
                    ForEach(ReaderRuleWorkspace.Kind.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu)
                HStack {
                    Button("导入规则") { importFile = true }.disabled(model.actions.hasPending)
                    Button("导出规则") { export() }
                    Spacer()
                    Button("刷新") { Task { await load() } }
                }.frame(minHeight: 44)
                if let failure = state.draftFailure { ReaderPageState(title: "草稿暂不可用", detail: failure) }
                if book.sourceId == "local" {
                    Button("按已保存规则重新处理本书") { reprocess() }.frame(minHeight: 44).disabled(model.actions.hasPending)
                }
                if state.loading { ReaderPageState(title: "正在读取规则", loading: true) }
                if let failure = state.failure {
                    ReaderPageState(title: "规则工具尚未完成", detail: failure, actionTitle: "重新读取") { Task { await load() } }
                }
                switch state.kind {
                case .replace: replacement
                case .txt: txtRules
                case .dictionary: dictionary
                case .hierarchy: hierarchy
                }
            }.font(ReaderTypography.font(.caption)).padding(12)
        }.scrollDismissesKeyboard(.immediately)
            .task { await load() }
            .onAppear {
                presented = true
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=panel.appear presented=\(presented) readerPresent=\(model.reader != nil) bookMatches=\(model.reader?.book.id == book.id)")
#endif
            }
            .onDisappear {
                presented = false; fileGeneration = UUID(); state.invalidateTXTPreview(reason: "panel.disappear")
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=panel.disappear presented=\(presented) readerPresent=\(model.reader != nil) bookMatches=\(model.reader?.book.id == book.id)")
#endif
            }
            .readerConfirmation(confirmation)
            .fileImporter(isPresented: $importFile, allowedContentTypes: [.json, .plainText]) { result in
                switch result {
                case .success(let url): readImport(url)
                case .failure(let error): model.showFeedback(error.localizedDescription)
                }
            }
            .fileExporter(isPresented: $exportFile, document: exportDocument, contentType: .json, defaultFilename: "Reader规则") { result in
                switch result {
                case .success: model.showFeedback("规则已导出")
                case .failure(let error):
                    if (error as NSError).code != NSUserCancelledError { model.showFeedback(error.localizedDescription) }
                }
            }
            .onChange(of: state.replaceDraft) { _, _ in state.validation = nil }
            .onChange(of: book.id) { _, _ in state.invalidateTXTPreview(reason: "panel.book.changed") }
            .onChange(of: model.reader?.id) { _, _ in state.invalidateTXTPreview(reason: "panel.session.changed") }
            .onChange(of: model.reader?.book.id) { _, _ in state.invalidateTXTPreview(reason: "panel.readerBook.changed") }
            .onChange(of: state.hierarchyJSON) { _, value in if state.hierarchyPreviewInput != value { state.hierarchyPreview = nil } }
            .onChange(of: model.actions.hasPending) { old, new in if old && !new { Task { await load() } } }
    }

    private var replacement: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(state.replaceRules) { rule in
                HStack {
                    Button(rule.name.isEmpty ? rule.pattern : rule.name) { replaceEditor(rule) }.disabled(model.actions.hasPending)
                        .lineLimit(2)
                        .accessibilityIdentifier("replace-rule-\(rule.id)")
                    Spacer()
                    Toggle("启用", isOn: Binding(get: { rule.isEnabled }, set: { value in
                        var draft = rule.draft; draft.isEnabled = value
                        mutate("保存替换规则") { id, service in _ = try await service.updateReplaceRule(id: rule.id, draft: draft, operationID: id) }
                    })).labelsHidden().disabled(model.actions.hasPending)
                    Button("删除", role: .destructive) {
                        confirmDelete(rule.name) { mutate("删除替换规则") { id, service in _ = try await service.deleteReplaceRule(id: rule.id, operationID: id) } }
                    }.disabled(model.actions.hasPending)
                        .accessibilityIdentifier("delete-replace-rule-\(rule.id)")
                }.frame(minHeight: 44)
            }
            Text(state.editingReplace == nil ? "新替换规则" : "编辑替换规则").font(ReaderTypography.font(.controlHeader))
            TextField("规则名称", text: $state.replaceDraft.name).readerField()
            TextField("匹配内容", text: $state.replaceDraft.pattern, axis: .vertical).readerField()
            TextField("替换为", text: $state.replaceDraft.replacement, axis: .vertical).readerField()
            TextField("规则分组", text: Binding(get: { state.replaceDraft.group ?? "" }, set: { state.replaceDraft.group = $0.isEmpty ? nil : $0 })).readerField()
            TextField("排除范围", text: Binding(get: { state.replaceDraft.excludeScope ?? "" }, set: { state.replaceDraft.excludeScope = $0.isEmpty ? nil : $0 })).readerField()
            TextField("执行顺序", value: $state.replaceDraft.order, format: .number).readerField()
            TextField("匹配超时（毫秒）", value: $state.replaceDraft.timeoutMillisecond, format: .number).readerField()
            TextField("作用范围，留空为全部", text: Binding(get: { state.replaceDraft.scope ?? "" }, set: { state.replaceDraft.scope = $0.isEmpty ? nil : $0 })).readerField()
            Toggle("正则表达式", isOn: $state.replaceDraft.isRegex)
            Toggle("作用于正文", isOn: $state.replaceDraft.scopeContent)
            Toggle("作用于标题", isOn: $state.replaceDraft.scopeTitle)
            Toggle("作用于书源", isOn: $state.replaceDraft.scopeSource)
            Toggle("启用此规则", isOn: $state.replaceDraft.isEnabled)
            HStack {
                Button("校验草稿") { validate() }
                Button("保存规则") {
                    let draft = state.replaceDraft; let target = state.editingReplace
                    mutate("保存替换规则") { id, service in
                        let validation = try await service.validateReplaceRule(draft)
                        guard validation.valid else { throw ReaderLibraryError.core(code: "INVALID_PARAMS", message: validation.issues.map(\.message).joined(separator: "\n"), retryable: false, reason: nil) }
                        if let target { _ = try await service.updateReplaceRule(id: target, draft: draft, operationID: id) }
                        else {
                            let saved = try await service.createReplaceRule(draft, operationID: id)
                            state.editingReplace = saved.id
                        }
                    }
                }.disabled(state.replaceDraft.pattern.isEmpty || model.actions.hasPending)
                Button("新建") { replaceEditor(nil) }.disabled(model.actions.hasPending)
            }.frame(minHeight: 44)
            if let validation = state.validation { Text(validation) }
            Button("预览已保存规则") { previewReplacement() }.frame(minHeight: 44)
#if DEBUG
                .background { ReaderDebugPreviewHitProbe(role: "replacement-preview") }
#endif
            if let preview = state.replacementPreview {
                Text(preview.truncated ? "当前章预览（已截取）" : "当前章预览").font(ReaderTypography.font(.controlHeader))
                Text("原文").font(ReaderTypography.font(.controlHeader)); Text(preview.before).textSelection(.enabled)
                    .accessibilityIdentifier("replacement-preview-before")
                Text("处理后").font(ReaderTypography.font(.controlHeader)); Text(preview.after).textSelection(.enabled)
                    .accessibilityIdentifier("replacement-preview-after")
            }
        }
    }

    private var txtRules: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("识别规则用于 TXT 导入；保存规则不会重新切分已导入书籍。")
                .foregroundStyle(ReaderPalette(scheme).muted)
            ForEach(state.txtRules) { rule in
                HStack {
                    Button(rule.name) { txtEditor(rule) }.disabled(model.actions.hasPending)
                    Spacer()
                    Toggle("启用", isOn: Binding(get: { rule.enable }, set: { value in
                        var draft = rule.draft; draft.enable = value
                        mutate("保存目录识别规则") { id, service in _ = try await service.updateTXTTOCRule(id: rule.id, draft: draft, operationID: id) }
                    })).labelsHidden().disabled(model.actions.hasPending)
                    Button("删除", role: .destructive) {
                        confirmDelete(rule.name) { mutate("删除目录识别规则") { id, service in _ = try await service.deleteTXTTOCRule(id: rule.id, operationID: id) } }
                    }.disabled(model.actions.hasPending)
                }.frame(minHeight: 44)
            }
            TextField("规则名称", text: $state.txtDraft.name).readerField()
            TextField("章节识别表达式", text: $state.txtDraft.rule, axis: .vertical).readerField()
                .accessibilityIdentifier("txt-toc-draft-pattern")
            TextField("示例", text: Binding(get: { state.txtDraft.example ?? "" }, set: { state.txtDraft.example = $0 })).readerField()
            TextField("识别顺序", value: $state.txtDraft.serialNumber, format: .number).readerField()
            Toggle("启用", isOn: $state.txtDraft.enable)
            HStack {
                Button("保存规则") {
                    let draft = state.txtDraft; let target = state.editingTXT
                    mutate("保存目录识别规则") { id, service in
                        if let target { _ = try await service.updateTXTTOCRule(id: target, draft: draft, operationID: id) }
                        else {
                            let saved = try await service.createTXTTOCRule(draft, operationID: id)
                            state.editingTXT = saved.id
                        }
                    }
                }.disabled(state.txtDraft.rule.isEmpty || model.actions.hasPending)
                Button("新建") { txtEditor(nil) }.disabled(model.actions.hasPending)
            }.frame(minHeight: 44)
            Button("预览当前草稿", action: previewTXT).frame(minHeight: 44)
#if DEBUG
                .background { ReaderDebugPreviewHitProbe(role: "txt-preview") }
#endif
                .disabled(state.txtPreviewLoading || book.sourceId != "local")
                .accessibilityIdentifier("txt-toc-preview-draft")
            Text("使用当前本地 TXT 原书，按当前全部已保存识别规则的优先顺序模拟此草稿；预览不保存规则，也不改变当前目录。保存与重新处理需分别执行。")
                .foregroundStyle(ReaderPalette(scheme).muted)
            if txtPreviewBelongsToCurrentReader, state.txtPreviewLoading { ReaderPageState(title: "正在预览目录草稿", loading: true) }
            if txtPreviewBelongsToCurrentReader, let failure = state.txtPreviewFailure {
                ReaderPageState(title: "目录草稿预览未完成", detail: failure, actionTitle: "重新预览", action: previewTXT)
            }
            if let preview = currentTXTPreview { txtPreview(preview) }
        }
    }

    private var currentTXTPreview: ReaderTXTTOCRulePreview? {
        guard txtPreviewBelongsToCurrentReader, let input = state.txtPreviewInput,
              let preview = state.txtPreview, preview.sourceSha256 == input.sourceSHA else { return nil }
        return preview
    }
    private var txtPreviewBelongsToCurrentReader: Bool {
        guard let input = state.txtPreviewInput, let current = model.reader else { return false }
        return input.sessionID == current.id && input.bookID == book.id && current.book.id == book.id
            && input.draft == state.txtDraft && input.editingID == state.editingTXT
    }
    private func txtPreview(_ preview: ReaderTXTTOCRulePreview) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(txtDiagnosis(preview.draftStatus)).font(ReaderTypography.font(.controlHeader))
                .accessibilityIdentifier("txt-toc-preview-status:" + preview.draftStatus.rawValue)
            Text("草稿命中原文标题 \(preview.draftMatchCount) 次")
            if let error = preview.regexError { Text(error).textSelection(.enabled) }
            if preview.automaticFallback {
                Text("没有识别规则被选中，模拟目录使用自动回退；自动目录可用不代表草稿命中。")
            } else if let selected = preview.selectedRule {
                if selected.kind == .saved, let id = selected.ruleId { Text("实际采用已保存的优先规则 #\(id)") }
                else if let id = selected.ruleId { Text("实际采用规则 #\(id) 的当前编辑草稿，尚未保存") }
                else { Text("实际采用当前新草稿，尚未保存或分配规则 ID") }
            }
            Text("模拟目录共 \(preview.chapterCount) 章\(preview.truncated ? "，以下为有界节选" : "")")
                .font(ReaderTypography.font(.controlHeader))
            ForEach(preview.chapters) { chapter in
                Text("\(chapter.index + 1). \(chapter.title)")
                    .accessibilityIdentifier("txt-toc-preview-chapter:\(chapter.index)")
            }
        }
    }
    private func txtDiagnosis(_ value: ReaderTXTTOCDraftStatus) -> String {
        switch value {
        case .selected: return "当前草稿已被选中"
        case .shadowed: return "草稿被更早的已保存规则遮蔽"
        case .disabled: return "当前草稿已禁用"
        case .invalidRegex: return "草稿表达式无效"
        case .emptyPattern: return "草稿表达式为空"
        case .noMatch: return "草稿未命中原文"
        case .insufficientMatches: return "草稿命中不足 4 次"
        }
    }
    private func previewTXT() {
#if DEBUG
        ReaderTXTPreviewTrace.emit("event=panel.preview.tap presented=\(presented) serviceAvailable=\(model.libraryService is any ReaderReadingToolsServing) readerPresent=\(model.reader != nil) bookMatches=\(model.reader?.book.id == book.id) local=\(book.sourceId == "local")")
#endif
        guard presented, let service = model.libraryService as? any ReaderReadingToolsServing,
              let current = model.reader, current.book.id == book.id, book.sourceId == "local" else { return }
        state.previewTXT(for: book, sessionID: current.id, service: service) {
            presented && model.reader?.id == current.id && model.reader?.book.id == book.id
        }
    }

    private var dictionary: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(state.dictionaryRules) { rule in
                HStack {
                    Button(rule.name) { dictionaryEditor(rule) }.disabled(model.actions.hasPending)
                    Spacer()
                    Button("删除", role: .destructive) {
                        confirmDelete(rule.name) { mutate("删除字典规则") { id, service in _ = try await service.deleteDictionaryRule(name: rule.name, operationID: id) } }
                    }.disabled(model.actions.hasPending)
                }.frame(minHeight: 44)
            }
            TextField("字典名称", text: $state.dictionaryDraft.name).readerField()
            TextField("查询地址规则", text: $state.dictionaryDraft.urlRule, axis: .vertical).readerField()
            TextField("展示规则", text: $state.dictionaryDraft.showRule, axis: .vertical).readerField()
            TextField("字典顺序", value: $state.dictionaryDraft.sortNumber, format: .number).readerField()
            Toggle("启用", isOn: $state.dictionaryDraft.enabled)
            Button("保存字典") {
                let draft = state.dictionaryDraft
                mutate("保存字典规则") { id, service in _ = try await service.putDictionaryRule(draft, operationID: id) }
            }.frame(minHeight: 44).disabled(state.dictionaryDraft.name.isEmpty || model.actions.hasPending)
            HStack {
                TextField("查词", text: $state.dictionaryWord).readerField()
                Button("查询") { queryDictionary() }.frame(minWidth: 44, minHeight: 44)
            }
            if let result = state.dictionaryResult { Text(result).textSelection(.enabled) }
        }
    }

    private var hierarchy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("本书目录显示分组，不改变原文章节边界。").foregroundStyle(ReaderPalette(scheme).muted)
            TextEditor(text: $state.hierarchyJSON).frame(minHeight: 180).readerField().accessibilityLabel("目录分组规则 JSON")
            HStack {
                Button("读取当前规则") { loadHierarchy() }
                Button("预览") { previewHierarchy(apply: false) }
                Button("应用") { previewHierarchy(apply: true) }.disabled(model.actions.hasPending)
            }.frame(minHeight: 44)
            if let result = state.hierarchyPreview {
                if let nodes = result.nodeCount { Text("\(nodes) 个目录项") }
                if let chapters = result.readableChapterCount { Text("\(chapters) 个可读章节") }
                if let reason = result.reason { Text(reason) }
                ForEach(result.nodes ?? []) { node in Text(node.title).padding(.leading, CGFloat(node.depth) * 12) }
            }
        }
    }

    private func replaceEditor(_ rule: ReaderReplaceRule?) {
        let saved = state.editingReplace.flatMap { id in state.replaceRules.first { $0.id == id } }?.draft ?? ReaderReplaceRuleDraft(pattern: "")
        let change = { state.editingReplace = rule?.id; state.replaceDraft = rule?.draft ?? ReaderReplaceRuleDraft(pattern: "") }
        if state.replaceDraft != saved {
            confirmation.confirm("替换当前草稿？", message: "尚未保存的替换规则草稿将被替换，已保存规则保留。", actionTitle: "替换", action: change)
        } else { change() }
    }
    private func txtEditor(_ rule: ReaderTXTTOCRule?) {
        let saved = state.editingTXT.flatMap { id in state.txtRules.first { $0.id == id } }?.draft ?? ReaderTXTTOCRuleDraft(rule: "")
        let change = { state.editingTXT = rule?.id; state.txtDraft = rule?.draft ?? ReaderTXTTOCRuleDraft(rule: "") }
        if state.txtDraft != saved {
            confirmation.confirm("替换当前草稿？", message: "尚未保存的 TXT 目录规则草稿将被替换，已保存规则保留。", actionTitle: "替换", action: change)
        } else { change() }
    }
    private func dictionaryEditor(_ rule: ReaderDictionaryRule) {
        let saved = state.dictionaryRules.first { $0.name == state.dictionaryDraft.name } ?? ReaderDictionaryRule(name: "")
        let change = { state.dictionaryDraft = rule }
        if state.dictionaryDraft != saved {
            confirmation.confirm("替换当前草稿？", message: "尚未保存的字典规则草稿将被替换，已保存规则保留。", actionTitle: "替换", action: change)
        } else { change() }
    }
    private func reprocess() {
        let expected = model.reader?.id
        confirmation.confirm("按已保存规则重新处理？", message: "本页未保存的编辑不参与处理。Core 将迁移书籍位置与标注，原文件保留。", actionTitle: "重新处理") {
            guard model.reader?.id == expected, model.reader?.book.id == book.id else { return }
            Task { _ = await model.actions.perform("重新处理本书", scope: book.id) { id in try await model.reprocessLocalCurrentBook(operationID: id) } }
        }
    }

    private func load() async {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let generation = UUID(); state.generation = generation
        state.loading = true
        defer { if state.generation == generation { state.loading = false } }
        do {
            let replacement = try await service.replaceRules()
            let txt = try await service.txtTOCRules()
            let dictionary = try await service.dictionaryRules()
            guard state.generation == generation else { return }
            state.replaceRules = replacement; state.txtRules = txt; state.dictionaryRules = dictionary
            state.failure = nil
        } catch { if state.generation == generation { state.failure = error.localizedDescription } }
    }
    private func mutate(_ label: String, action: @escaping (String, any ReaderReadingToolsServing) async throws -> Void) {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        Task {
            if await model.actions.perform(label, scope: book.id, action: { id in try await action(id, service) }) { await load() }
        }
    }
    private func confirmDelete(_ name: String, action: @escaping () -> Void) {
        confirmation.confirm("删除规则", message: name, actionTitle: "删除", destructive: true, action: action)
    }
    private func validate() {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let draft = state.replaceDraft
        Task {
            do {
                let result = try await service.validateReplaceRule(draft)
                guard presented, state.replaceDraft == draft else { return }
                state.validation = result.valid ? "规则校验通过" : result.issues.map(\.message).joined(separator: "\n")
            } catch { if presented, state.replaceDraft == draft { state.validation = error.localizedDescription } }
        }
    }
    private func previewReplacement() {
#if DEBUG
        ReaderTXTPreviewTrace.emit("event=panel.replacement.tap presented=\(presented) serviceAvailable=\(model.libraryService is any ReaderReadingToolsServing) readerPresent=\(model.reader != nil) bookMatches=\(model.reader?.book.id == book.id)")
#endif
        guard let service = model.libraryService as? any ReaderReadingToolsServing,
              let current = model.reader, current.book.id == book.id else { return }
        Task {
            do {
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=replacement.service.begin session=\(current.id) chapter=\(current.content.chapterIndex)")
#endif
                let value = try await service.previewReplacement(for: book, chapterIndex: current.content.chapterIndex, maxScalars: 4000)
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=replacement.service.result session=\(current.id) beforeUTF8Bytes=\(value.before.utf8.count) afterUTF8Bytes=\(value.after.utf8.count) truncated=\(value.truncated)")
#endif
                guard presented, model.reader?.id == current.id, model.reader?.content.chapterIndex == current.content.chapterIndex else {
#if DEBUG
                    ReaderTXTPreviewTrace.emit("event=replacement.discard.result presented=\(presented) sessionMatches=\(model.reader?.id == current.id) chapterMatches=\(model.reader?.content.chapterIndex == current.content.chapterIndex)")
#endif
                    return
                }
                state.replacementPreview = value
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=replacement.published.result session=\(current.id)")
#endif
            } catch {
#if DEBUG
                ReaderTXTPreviewTrace.emit("event=replacement.service.error session=\(current.id) category=\(ReaderTXTPreviewTrace.errorCategory(error))")
#endif
                if presented, model.reader?.id == current.id { state.failure = error.localizedDescription }
            }
        }
    }
    private func queryDictionary() {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let name = state.dictionaryDraft.name; let word = state.dictionaryWord
        Task {
            do {
                let value = try await service.queryDictionary(ruleName: name, word: word)
                guard presented, state.dictionaryDraft.name == name, state.dictionaryWord == word else { return }
                state.dictionaryResult = value
            } catch { if presented, state.dictionaryDraft.name == name, state.dictionaryWord == word { state.dictionaryResult = error.localizedDescription } }
        }
    }
    private func loadHierarchy() {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let originalDraft = state.hierarchyJSON
        Task {
            do {
                let current = try await service.directoryRules(for: book)
                guard presented, state.hierarchyJSON == originalDraft else { return }
                let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
                state.hierarchyJSON = String(decoding: try encoder.encode(current.rules ?? []), as: UTF8.self)
                state.hierarchyPreviewInput = state.hierarchyJSON
                state.hierarchyPreview = current
            } catch { state.failure = error.localizedDescription }
        }
    }
    private func previewHierarchy(apply: Bool) {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        do {
            let originalDraft = state.hierarchyJSON
            let rules = try JSONDecoder().decode([ReaderDirectoryHierarchyRule].self, from: Data(originalDraft.utf8))
            if apply {
                mutate("应用目录分组") { id, service in _ = try await service.applyDirectoryRules(for: book, rules: rules, operationID: id) }
            } else {
                Task {
                    do {
                        let value = try await service.previewDirectoryRules(for: book, rules: rules)
                        guard presented, state.hierarchyJSON == originalDraft else { return }
                        state.hierarchyPreviewInput = originalDraft
                        state.hierarchyPreview = value
                    } catch { if presented, state.hierarchyJSON == originalDraft { state.failure = error.localizedDescription } }
                }
            }
        } catch { state.failure = "分组规则格式无效，请检查后重试" }
    }
    private func export() {
        guard let service = model.libraryService as? any ReaderReadingToolsServing else { return }
        let generation = UUID(); fileGeneration = generation
        Task {
            do {
                let json = try await service.exportRuleBundle().json
                guard presented, fileGeneration == generation else { return }
                exportDocument = ReaderRuleDocument(text: json); exportFile = true
            } catch { if presented, fileGeneration == generation { model.showFeedback(error.localizedDescription) } }
        }
    }
    /// Registered file boundary: coordinated, security-scoped system read;
    /// Core still parses and validates the imported rule bundle.
    private func readImport(_ url: URL) {
        let generation = UUID(); fileGeneration = generation
        Task {
            let result = await Task.detached(priority: .userInitiated) { () -> Result<String, Error> in
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                var coordinationError: NSError?
                var contents: Result<String, Error>?
                NSFileCoordinator().coordinate(readingItemAt: url, options: .withoutChanges, error: &coordinationError) { coordinated in
                    contents = Result {
                        let data = try Data(contentsOf: coordinated)
                        guard let json = String(data: data, encoding: .utf8) else { throw CocoaError(.fileReadInapplicableStringEncoding) }
                        return json
                    }
                }
                if let coordinationError { return .failure(coordinationError) }
                return contents ?? .failure(CocoaError(.fileReadUnknown))
            }.value
            guard presented, fileGeneration == generation else { return }
            switch result {
            case .success(let json):
                confirmation.confirm("导入规则", message: "合并规则包；同 ID 的规则或订阅、同名字典将由文件内容覆盖，其他现有项保留。", actionTitle: "导入") {
                    mutate("导入规则") { id, service in _ = try await service.importRuleBundle(json: json, replaceExisting: false, operationID: id) }
                }
            case .failure(let error): model.showFeedback(error.localizedDescription)
            }
        }
    }
}
