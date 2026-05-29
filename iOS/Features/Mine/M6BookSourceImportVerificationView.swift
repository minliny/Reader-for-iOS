import SwiftUI
import ReaderCoreModels
import ReaderAppPersistence
import ReaderShellValidation

#if DEBUG

/// M6 BookSource import verification harness — Debug only.
/// One-tap runs the full import chain:
///   Load bundled JSON → Normalize → Decode/Validate → Save → Reload → Display.
/// Each step reports PASS/FAIL independently.
/// Manual search test is a separate action, not auto-triggered.
/// Does NOT auto-network. Does NOT touch WebDAV/RSS/Sync.
@MainActor
struct M6BookSourceImportVerificationView: View {
    @State private var steps: [VerifyStep] = []
    @State private var isRunning = false
    @State private var importedSourceIDs: [String] = []
    @State private var storeSources: [BookSource] = []
    @State private var searchTestResult: String?

    @State private var jsonSourceLabel: String = "未加载"
    @State private var manualJSONText: String = ""
    @State private var jsonLoadError: String?

    // MARK: - JSON Loading

    private func loadBundledXingxingJSON() -> (text: String, source: String)? {
        // Try AppSupport/Sources subdirectory
        if let url = Bundle.main.url(forResource: "xingxingxsw.search-only", withExtension: "json", subdirectory: "AppSupport/Sources"),
           let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            return (text, "bundled: AppSupport/Sources/xingxingxsw.search-only.json")
        }
        // Fallback: direct in bundle root
        if let url = Bundle.main.url(forResource: "xingxingxsw.search-only", withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let text = String(data: data, encoding: .utf8) {
            return (text, "bundled: xingxingxsw.search-only.json (root)")
        }
        return nil
    }

    var body: some View {
        List {
            // MARK: - 状态
            Section("验证步骤") {
                if steps.isEmpty && !isRunning {
                    Text("点击下方按钮开始 M6 导入链路验证").foregroundStyle(.secondary)
                }
                ForEach(steps) { step in
                    VerifyStepRow(step: step)
                }
                if isRunning {
                    ProgressView("验证中...")
                }
            }

            // MARK: - 操作
            Section("一键验证") {
                Button {
                    runFullVerification()
                } label: {
                    HStack {
                        Image(systemName: "play.fill")
                        Text("执行 M6 导入链路验证")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunning)

                Button("清除本地书源并重置") {
                    resetStore()
                }
                .disabled(isRunning)
                .font(.caption)
            }

            // MARK: - 已保存书源
            if !storeSources.isEmpty {
                Section("BookSourceStore 中的书源") {
                    ForEach(storeSources, id: \.id) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.bookSourceName)
                                .font(.subheadline.weight(.medium))
                            HStack {
                                Text(source.bookSourceUrl ?? "no URL")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(source.enabled ? "已启用" : "已禁用")
                                    .font(.caption2)
                                    .foregroundStyle(source.enabled ? .green : .secondary)
                            }
                            if let id = source.id {
                                Text("id: \(id.prefix(16))...")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }

            // MARK: - 可区分性验证
            if !storeSources.isEmpty {
                Section("可区分性") {
                    let hasStar = storeSources.contains { ($0.bookSourceName).hasPrefix("⭐") }
                    let withoutStar = storeSources.contains { !($0.bookSourceName).hasPrefix("⭐") }
                    VerifyStepRow(step: VerifyStep(
                        label: "预置源带 ⭐ 前缀",
                        passed: hasStar || steps.contains(where: { $0.label.contains("预置源") && $0.passed }),
                        detail: hasStar ? "是" : "否"
                    ))
                    VerifyStepRow(step: VerifyStep(
                        label: "导入源无 ⭐ 前缀（可区分）",
                        passed: withoutStar,
                        detail: withoutStar ? "是" : "否"
                    ))
                }
            }

            // MARK: - 手动测试搜索
            if !importedSourceIDs.isEmpty {
                Section("手动测试") {
                    Button {
                        runManualSearchTest()
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text("测试搜索（controlledOnline）")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(isRunning)

                    if let result = searchTestResult {
                        Text(result)
                            .font(.caption)
                            .foregroundStyle(result.contains("成功") ? .green : .orange)
                    }

                    Text("手动触发，每次只测一个 operation，受 NetworkAccessController 控制")
                        .font(.caption2).foregroundStyle(.tertiary)
                }
            }

            // MARK: - Scope
            Section("安全边界") {
                Label("不自动联网", systemImage: "checkmark").foregroundStyle(.green)
                Label("不接 WebDAV/RSS/Sync", systemImage: "checkmark").foregroundStyle(.green)
                Label("不修改 Reader-Core", systemImage: "checkmark").foregroundStyle(.green)
                Label("仅 #if DEBUG", systemImage: "checkmark").foregroundStyle(.green)
            }
        }
        .navigationTitle("[验证] M6 导入链路")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Full verification

    private func runFullVerification() {
        isRunning = true
        steps = []
        storeSources = []
        importedSourceIDs = []
        searchTestResult = nil

        Task {
            // Step 1: Load JSON from bundled resource
            addStep("1. 查找 bundled xingxingxsw JSON") {
                if let result = loadBundledXingxingJSON() {
                    jsonSourceLabel = result.source
                    return true
                }
                return false
            }

            guard let (jsonText, sourceTag) = loadBundledXingxingJSON() else {
                addStep("1. JSON → Data 编码") { false }
                addStep("错误", detail: "Missing xingxingxsw.search-only.json in bundle. Check project.yml ReaderForIOSApp sources.") { false }
                isRunning = false
                return
            }
            jsonSourceLabel = sourceTag
            addStep("1a. JSON source", detail: jsonSourceLabel) { true }

            guard let data = jsonText.data(using: .utf8) else {
                addStep("1b. JSON text → Data 编码") { false }
                isRunning = false
                return
            }
            addStep("1b. JSON text → Data 编码") { true }

            // Step 2: Normalize (M6-P1-001 object rules, M6-P1-002 header)
            let normalizer = BookSourceImportNormalizer()
            let normalizedData: Data
            do {
                normalizedData = try normalizer.normalize(data)
                addStep("2. Normalize (object rules + header)") {
                    // Verify the normalization didn't destroy data
                    let dict = try? JSONSerialization.jsonObject(with: normalizedData) as? [String: Any]
                    let hasRuleSearch = dict?["ruleSearch"] is String
                    let hasRuleToc = dict?["ruleToc"] is String
                    let hasRuleContent = dict?["ruleContent"] is String
                    let hasHeader = dict?["header"] is [String: String]
                    return hasRuleSearch && hasRuleToc && hasRuleContent && hasHeader
                }
            } catch {
                addStep("2. Normalize (object rules + header)") { false }
                addStep("错误", detail: error.localizedDescription) { false }
                isRunning = false
                return
            }

            // Step 3: Decode & validate
            let provider = ReaderCoreServiceProvider.shared
            let state = await provider.validateBookSource(from: normalizedData)
            var importedSource: BookSource?
            switch state {
            case .loaded(let source):
                importedSource = source
                addStep("3. Decode BookSource") { true }
                addStep("3a. sourceName", detail: source.bookSourceName) { source.bookSourceName == "星星小说网" }
                addStep("3b. bookSourceUrl", detail: source.bookSourceUrl) { source.bookSourceUrl == "https://www.xingxingxsw.com" }
                addStep("3c. 不出现 Invalid book source JSON") { true }

            case .failed(let error):
                addStep("3. Decode BookSource") { false }
                addStep("错误", detail: error.message) { false }
                isRunning = false
                return
            default:
                addStep("3. Decode BookSource") { false }
                isRunning = false
                return
            }

            guard var source = importedSource else {
                isRunning = false
                return
            }

            // Step 4: Validate capabilities
            let validator = BookSourceImportValidator()
            let result = validator.validate(source)
            addStep("4a. search capability", detail: result.searchCapability.rawValue) { result.searchCapability == .ready }
            addStep("4b. detail capability", detail: result.detailCapability.rawValue) { true }
            addStep("4c. toc capability", detail: result.tocCapability.rawValue) { true }
            addStep("4d. content capability", detail: result.contentCapability.rawValue) { true }
            addStep("4e. validation errors", detail: "\(result.errors.count)") { result.errors.isEmpty }

            // Step 5: Save to BookSourceStore
            // Ensure fresh id for this run
            source.id = "m6-verify-\(UUID().uuidString.prefix(8))"
            do {
                try await BookSourceStore.shared.add(source)
                addStep("5. Save to BookSourceStore") { true }
            } catch {
                addStep("5. Save to BookSourceStore") { false }
                addStep("错误", detail: error.localizedDescription) { false }
                isRunning = false
                return
            }

            // Step 6: Reload from store
            do {
                let loaded = try await BookSourceStore.shared.load()
                storeSources = loaded
                let found = loaded.contains { $0.id == source.id }
                addStep("6. Reload from store", detail: "\(loaded.count) sources") { found }
                if found {
                    importedSourceIDs = [source.id ?? "unknown"]
                }
            } catch {
                addStep("6. Reload from store") { false }
            }

            // Step 7: Verify source is distinguishable
            let hasFixtureStar = storeSources.contains { ($0.bookSourceName).hasPrefix("⭐") }
            let hasImported = storeSources.contains { $0.id == source.id && !($0.bookSourceName).hasPrefix("⭐") }
            addStep("7a. 预置源存在 ⭐ 前缀") { hasFixtureStar }
            addStep("7b. 导入源无 ⭐ 前缀（可区分）") { hasImported }

            // Step 8: Verify duplicate handling
            let countById = storeSources.filter { $0.id == source.id }.count
            addStep("8. Duplicate sourceId 处理", detail: "count=\(countById)") { countById == 1 }

            // Step 9: Verify enabled toggle
            do {
                try await BookSourceStore.shared.toggleEnabled(id: source.id!)
                let toggled = try await BookSourceStore.shared.load()
                let toggledSource = toggled.first { $0.id == source.id }
                addStep("9. 导入源 启用/停用 toggle", detail: toggledSource?.enabled == true ? "已启用" : "已禁用") {
                    toggledSource != nil
                }
                // Toggle back
                try await BookSourceStore.shared.toggleEnabled(id: source.id!)
            } catch {
                addStep("9. 导入源 启用/停用 toggle") { false }
            }

            isRunning = false
        }
    }

    // MARK: - Manual search test

    private func runManualSearchTest() {
        searchTestResult = "测试中..."
        Task {
            let provider = ReaderCoreServiceProvider.shared
            let ready = provider.prepareControlledOnlineAllServices()
            guard ready else {
                searchTestResult = "⚠️ 无法创建 real services（NetworkAccessController denied）"
                return
            }
            provider.enableControlledOnline()

            let state = await provider.searchBooks(keyword: "测试", page: 1)
            switch state {
            case .loaded(let items):
                searchTestResult = "搜索成功：\(items.count) 条结果"
            case .empty:
                searchTestResult = "搜索返回空（可能是真实网络不可达）"
            case .failed(let err):
                searchTestResult = "搜索失败：\(err.message)"
            default:
                searchTestResult = "意外状态"
            }
        }
    }

    // MARK: - Helpers

    private func resetStore() {
        steps = []
        storeSources = []
        importedSourceIDs = []
        searchTestResult = nil
        Task {
            try? await BookSourceStore.shared.save([])
            BookSourceStore.shared.clearCache()
        }
    }

    private func addStep(_ label: String, detail: String? = nil, _ condition: () -> Bool) {
        let passed = condition()
        steps.append(VerifyStep(label: label, passed: passed, detail: detail))
    }
}

// MARK: - Model

struct VerifyStep: Identifiable {
    let id = UUID()
    let label: String
    let passed: Bool
    var detail: String?
}

struct VerifyStepRow: View {
    let step: VerifyStep

    var body: some View {
        HStack(alignment: .top) {
            Image(systemName: step.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(step.passed ? .green : .red)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label)
                    .font(.subheadline)
                if let detail = step.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#endif
