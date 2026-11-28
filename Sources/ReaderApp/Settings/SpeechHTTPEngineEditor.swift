import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct SpeechHTTPEngineEditor: View {
    let runtime: CoreRuntimeActor
    let onSaved: (M3HttpTtsData) async -> Void
    @State private var draft: SpeechHTTPEngineDraft
    @State private var error: String?
    @State private var saving = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.readerTheme) private var theme

    init(runtime: CoreRuntimeActor, initial: SpeechHTTPEngineDraft,
         onSaved: @escaping (M3HttpTtsData) async -> Void) {
        self.runtime = runtime
        self.onSaved = onSaved
        _draft = State(initialValue: initial)
    }

    var body: some View {
        Form {
            Section("在线朗读接口") {
                TextField("名称", text: $draft.name)
                    .accessibilityIdentifier("reader-tts-engine-name")
                TextField("HTTPS 接口地址", text: $draft.url, axis: .vertical)
                    .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .accessibilityIdentifier("reader-tts-engine-url")
                Picker("请求方式", selection: $draft.requestProtocol) {
                    ForEach(SpeechHTTPProfile.RequestProtocol.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                TextField("音色（可选）", text: $draft.voice).textInputAutocapitalization(.never)
                if draft.requestProtocol == .openAI || draft.requestProtocol == .auto {
                    TextField("模型（可选）", text: $draft.model).textInputAutocapitalization(.never)
                }
            }
            Section("播放格式") {
                Picker("音频格式", selection: $draft.format) {
                    ForEach(SpeechHTTPProfile.Format.allCases, id: \.self) { Text($0.rawValue.uppercased()).tag($0) }
                }
                if draft.format == .pcm {
                    Picker("采样率", selection: $draft.sampleRate) {
                        ForEach([8_000, 16_000, 22_050, 24_000, 32_000, 44_100, 48_000], id: \.self) {
                            Text("\($0) Hz").tag($0)
                        }
                    }
                    Picker("声道", selection: $draft.channels) {
                        Text("单声道").tag(1)
                        Text("双声道").tag(2)
                    }
                }
            }
            Section {
                SecureField(draft.hasCredential ? "填写以替换已有密钥" : "密钥（可选）", text: $draft.key)
                    .textInputAutocapitalization(.never)
                if draft.hasCredential { Toggle("移除此引擎的已有密钥", isOn: $draft.removeCredential) }
            } header: {
                Text("本机密钥")
            } footer: {
                Text("密钥仅保存在本机钥匙串。模板支持 {{text}}、{{rate}}、{{voice}}、{{apiKey}}。")
            }
            if let error { Text(error).foregroundStyle(theme.danger).accessibilityIdentifier("reader-tts-engine-error") }
        }
        .disabled(saving)
        .navigationTitle(draft.previous == nil ? "添加在线引擎" : "编辑在线引擎")
        .navigationBarTitleDisplayMode(.inline)
        .interactiveDismissDisabled(saving)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() }.disabled(saving) }
            ToolbarItem(placement: .confirmationAction) {
                Button(saving ? "保存中" : "保存") { save() }
                    .accessibilityIdentifier("reader-tts-engine-save")
                    .disabled(saving || !draft.canSave)
            }
        }
    }

    private func save() {
        let candidate = draft
        saving = true
        Task {
            do {
                let saved = try await candidate.save(runtime: runtime)
                draft.key = ""
                await onSaved(saved)
                dismiss()
            } catch is CancellationError {
                return
            } catch {
                self.error = "无法保存。请检查 HTTPS 地址、模板和密钥设置。"
            }
            saving = false
        }
    }
}
