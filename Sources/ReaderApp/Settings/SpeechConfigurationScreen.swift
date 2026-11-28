import ReaderCoreBridge
import ReaderDesign
import SwiftUI

enum SpeechEngineCatalogAction {
    case choose(SpeechEngineChoice)
    case add
    case edit(M3HttpTtsData)
    case reload
}

struct SpeechConfigurationScreen: View {
    let configuration: SpeechConfiguration
    var onSelection: (SpeechConfiguration.Selection) async -> Void = { _ in }
    @State private var catalog: SpeechConfiguration.Catalog?
    @State private var busy = false
    @State private var error: String?
    @State private var editor: Editor?

    private struct Editor: Identifiable {
        let id = UUID()
        let draft: SpeechHTTPEngineDraft
    }

    var body: some View {
        SpeechEngineCatalogView(selection: catalog?.selected.choice ?? .system(voiceID: nil),
                                voices: catalog?.voices ?? [], engines: catalog?.engines ?? [],
                                busy: busy, error: error, onAction: perform)
            .navigationTitle("朗读引擎")
            .navigationBarTitleDisplayMode(.inline)
            .task { await load() }
            .sheet(item: $editor) { value in
                NavigationStack {
                    SpeechHTTPEngineEditor(runtime: configuration.runtime, initial: value.draft) { saved in
                        await load()
                        if catalog?.selected.choice == .http(id: saved.id), let selected = catalog?.selected {
                            await onSelection(selected)
                        }
                    }
                }
            }
    }

    private func load() async {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        do {
            catalog = try await configuration.catalog()
            error = nil
        } catch is CancellationError {
            return
        } catch {
            self.error = "暂时无法读取朗读引擎。"
        }
    }

    private func perform(_ action: SpeechEngineCatalogAction) {
        guard !busy else { return }
        switch action {
        case .reload: Task { await load() }
        case .add: edit(nil)
        case .edit(let engine): edit(engine)
        case .choose(let choice):
            busy = true
            Task {
                defer { busy = false }
                do {
                    let selected = try await configuration.choose(choice)
                    catalog = try await configuration.catalog()
                    error = nil
                    await onSelection(selected)
                } catch is CancellationError {
                    return
                } catch {
                    self.error = "暂时无法启用此朗读引擎，请重试。"
                }
            }
        }
    }

    private func edit(_ item: M3HttpTtsData?) {
        do {
            editor = Editor(draft: try SpeechHTTPEngineDraft(existing: item))
        } catch {
            self.error = "此引擎的设置无法读取。"
        }
    }
}

struct SpeechEngineCatalogView: View {
    let selection: SpeechEngineChoice
    let voices: [SpeechSystemVoice]
    let engines: [M3HttpTtsData]
    var busy = false
    var error: String?
    let onAction: (SpeechEngineCatalogAction) -> Void
    @Environment(\.readerTheme) private var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.ttsConfigFormSectionGap)) {
                if let error {
                    HStack(alignment: .firstTextBaseline) {
                        Text(error).foregroundStyle(theme.danger)
                        Spacer()
                        Button("重试") { onAction(.reload) }
                    }
                    .readerTypography(ReaderDesignMetrics.rowDetail)
                }
                systemSection
                httpSection
            }
            .frame(maxWidth: CGFloat(ReaderDesignMetrics.ttsConfigPanelMaxWidth))
            .padding(CGFloat(ReaderDesignMetrics.ttsConfigFormInlinePadding))
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.background)
        .accessibilityIdentifier("reader-tts-config")
        .overlay(alignment: .topTrailing) {
            if busy { ProgressView().padding(8).accessibilityLabel("正在读取朗读设置") }
        }
    }

    private var systemSection: some View {
        section("系统音色", icon: ReaderIconRegistry.ttsSystemEngine) {
            HStack {
                Text(systemVoiceName).readerTypography(ReaderDesignMetrics.ttsConfigVoiceSelectedLabel)
                Spacer()
                Menu {
                    Button("系统默认") { onAction(.choose(.system(voiceID: nil))) }
                    if !voices.isEmpty {
                        ForEach(voices) { voice in
                            Button("\(voice.name)（\(voice.language)）") {
                                onAction(.choose(.system(voiceID: voice.id)))
                            }
                        }
                    }
                } label: {
                    Label("更换", systemImage: "chevron.up.chevron.down")
                        .readerTypography(ReaderDesignMetrics.ttsConfigChoiceSelectedLabel)
                        .padding(8)
                }
                .accessibilityIdentifier("reader-tts-voice-picker")
                .disabled(busy)
            }
            .padding(12)
            if case .http = selection {
                Divider().overlay(theme.divider)
                Button("启用系统音色") { onAction(.choose(.system(voiceID: nil))) }
                    .readerTypography(ReaderDesignMetrics.ttsConfigChoiceSelectedLabel)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityIdentifier("reader-tts-system-enable")
                    .disabled(busy)
            }
        }
    }

    private var httpSection: some View {
        section("在线朗读", icon: ReaderIconRegistry.ttsOnlineEngine) {
            if engines.isEmpty {
                Text("还没有在线朗读引擎")
                    .readerTypography(ReaderDesignMetrics.ttsConfigVoiceMetadata, relativeTo: .caption)
                    .foregroundStyle(theme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading).padding(12)
            }
            ForEach(engines, id: \.id) { item in
                engineRow(item)
                Divider().overlay(theme.divider).padding(.horizontal, 12)
            }
            Button { onAction(.add) } label: {
                Label("添加在线引擎", systemImage: "plus")
                    .readerTypography(ReaderDesignMetrics.ttsConfigSaveLabel)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("reader-tts-engine-add")
            .disabled(busy)
        }
    }

    private func engineRow(_ item: M3HttpTtsData) -> some View {
        let active = selection == .http(id: item.id)
        return HStack(spacing: 12) {
            Button { onAction(.edit(item)) } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.name)
                        .readerTypography(ReaderDesignMetrics.ttsConfigVoiceLabel)
                        .foregroundStyle(theme.primaryText)
                    Text(active ? "使用中" : "轻点编辑")
                        .readerTypography(ReaderDesignMetrics.ttsConfigVoiceMetadata)
                        .foregroundStyle(active ? theme.accent : theme.secondaryText)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("reader-tts-engine-edit-\(item.id)")
            Toggle("启用\(item.name)", isOn: Binding(get: { active }, set: { value in
                onAction(.choose(value ? .http(id: item.id) : .system(voiceID: nil)))
            }))
            .labelsHidden()
            .accessibilityIdentifier("reader-tts-engine-toggle-\(item.id)")
        }
        .padding(.horizontal, 12).padding(.vertical, 4)
        .disabled(busy)
    }

    private var systemVoiceName: String {
        guard case .system(let id) = selection, let voice = voices.first(where: { $0.id == id }) else { return "系统默认" }
        return voice.name
    }

    private func section<Content: View>(_ title: String, icon: ReaderIconMapping,
                                        @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ReaderIcon(icon, squareSize: 18)
                Text(title).readerTypography(ReaderDesignMetrics.ttsConfigManagerTitle, relativeTo: .headline)
                    .accessibilityAddTraits(.isHeader)
            }
            .foregroundStyle(theme.primaryText)
            VStack(spacing: 0, content: content)
                .background(theme.surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(theme.outline, lineWidth: 0.5) }
        }
    }
}
