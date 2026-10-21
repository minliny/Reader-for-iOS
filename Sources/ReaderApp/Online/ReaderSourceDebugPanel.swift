import SwiftUI

struct ReaderSourceDebugPanel: View {
    let source: ReaderOnlineSource
    let service: any ReaderOnlineServing
    @State private var key = ""
    @State private var responses = "{}"
    @State private var result: String?
    @State private var failure: String?
    @State private var running = false
    @State private var task: Task<Void, Never>?
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 14) {
            HStack { Button("关闭") { task?.cancel(); dismiss() }; Spacer(); Text("规则调试").font(ReaderTypography.font(.controlHeader)); Spacer(); Button(running ? "停止" : "运行") { if running { task?.cancel() } else { debug() } } }
            Text(source.name).font(ReaderTypography.font(.caption))
            TextField("关键词或调试入口 URL", text: $key).textInputAutocapitalization(.never).readerField()
            Text("按 Core 调试合同回放真实响应。JSON 可包含 searchResponse、detailResponse、tocResponse、contentResponse；此操作不保存书源。").font(ReaderTypography.font(.caption))
            TextEditor(text: $responses).font(.system(.caption, design: .monospaced)).accessibilityLabel("真实响应 JSON").frame(minHeight: 140)
            if running { ProgressView("正在回放规则") }
            if let failure { ReaderPageState(title: "调试未完成", detail: failure) }
            if let result { ScrollView { Text(result).font(.system(.caption, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) } }
        }.padding(20)
            .onAppear {
                let saved = UserDefaults.standard.dictionary(forKey: "reader.source-debug." + source.id)
                key = saved?["key"] as? String ?? ""
                responses = saved?["responses"] as? String ?? "{}"
            }
            .onDisappear {
                task?.cancel()
                UserDefaults.standard.set(["key": key, "responses": responses], forKey: "reader.source-debug." + source.id)
            }
    }
    private func debug() {
        guard !running else { return }
        do {
            let payload = try JSONSerialization.jsonObject(with: Data(responses.utf8))
            guard payload is [String: Any] else { throw ReaderLibraryError.invalidResponse("debug responses must be an object") }
            let parameters = try JSONSerialization.data(withJSONObject: ["sourceId": source.id, "key": key, "responses": payload])
            running = true; failure = nil; result = nil
            task = Task {
                do {
                    let data = try await service.onlineCommand("source.debug", parameters: parameters, operationID: nil)
                    try Task.checkCancellation()
                    let object = try JSONSerialization.jsonObject(with: data)
                    result = String(decoding: try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]), as: UTF8.self)
                } catch is CancellationError { } catch { failure = error.localizedDescription }
                running = false
            }
        } catch { failure = error.localizedDescription }
    }
}
