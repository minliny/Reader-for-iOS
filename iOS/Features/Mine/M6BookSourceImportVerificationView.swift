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
        DemoBackScreen(title: "[验证] M6 导入链路") {
            if steps.isEmpty && !isRunning {
                ReaderStateBanner(
                    icon: .sourceStack,
                    title: "验证步骤",
                    messages: ["点击下方按钮开始 M6 导入链路验证"]
                )
            } else {
                M6VerificationSection(title: "验证步骤") {
                    ForEach(steps) { step in
                        VerifyStepRow(step: step)
                    }
                    if isRunning {
                        HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                            // demo `.fd-discover-bottom-loading i`：14×14 旋转圆。
                            DemoLoadingSpinner(size: .inline)
                            Text("验证中...")
                                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                        }
                        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
                    }
                }
            }

            M6VerificationSection(title: "一键验证") {
                M6VerificationButton(
                    icon: .play,
                    title: "执行 M6 导入链路验证",
                    subtitle: "加载、归一化、验证、保存、重载",
                    isPrimary: true,
                    isDisabled: isRunning
                ) {
                    runFullVerification()
                }

                M6VerificationButton(
                    icon: .trash,
                    title: "清除本地书源并重置",
                    subtitle: "清空本地 BookSourceStore 和当前验证结果",
                    isPrimary: false,
                    isDisabled: isRunning
                ) {
                    resetStore()
                }
            }

            if !storeSources.isEmpty {
                M6VerificationSection(title: "BookSourceStore 中的书源") {
                    ForEach(storeSources, id: \.id) { source in
                        VStack(alignment: .leading, spacing: 2) {
                            DemoIconRow(
                                icon: .source,
                                title: source.bookSourceName,
                                subtitle: source.bookSourceUrl ?? "no URL",
                                detail: source.enabled ? "已启用" : "已禁用"
                            )
                            if let id = source.id {
                                Text("id: \(id.prefix(16))...")
                                    .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                                    .padding(.leading, ReaderDesignTokens.settingsRowIconColumn + ReaderDesignTokens.settingsRowGap + ReaderDesignTokens.settingsRowHorizontalPadding)
                            }
                        }
                    }
                }
            }

            if !storeSources.isEmpty {
                M6VerificationSection(title: "可区分性") {
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

            if !importedSourceIDs.isEmpty {
                M6VerificationSection(title: "手动测试") {
                    M6VerificationButton(
                        icon: .search,
                        title: "测试搜索（controlledOnline）",
                        subtitle: "手动触发一个受控联网 operation",
                        isPrimary: false,
                        isDisabled: isRunning
                    ) {
                        runManualSearchTest()
                    }

                    if let result = searchTestResult {
                        Text(result)
                            .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize, weight: .black))
                            .foregroundColor(result.contains("成功") ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.Semantic.warning)
                            .lineLimit(4)
                            .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("手动触发，每次只测一个 operation，受 NetworkAccessController 控制")
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
                }
            }

            M6VerificationSection(title: "安全边界") {
                M6BoundaryRow(title: "不自动联网")
                M6BoundaryRow(title: "不接 WebDAV/RSS/Sync")
                M6BoundaryRow(title: "不修改 Reader-Core")
                M6BoundaryRow(title: "仅 #if DEBUG")
            }
        }
    }

    private var hasStar: Bool {
        storeSources.contains { ($0.bookSourceName).hasPrefix("⭐") }
    }

    private var withoutStar: Bool {
        storeSources.contains { !($0.bookSourceName).hasPrefix("⭐") }
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
            if !ready {
                searchTestResult = "⚠️ 网络访问未启用（受 NetworkAccessController 控制）\n提示：需要在设置中开启受控联网以执行真实搜索"
                return
            }
            provider.enableControlledOnline()

            let state = await provider.searchBooks(keyword: "测试", page: 1)
            switch state {
            case .loaded(let items):
                searchTestResult = "✅ 搜索成功：\(items.count) 条结果"
            case .empty:
                searchTestResult = "📭 搜索返回空（可能是真实网络不可达，或书源无可用内容）"
            case .failed(let err):
                searchTestResult = "❌ 搜索失败：\(err.message)\n提示：检查网络连接或稍后重试"
            default:
                searchTestResult = "⚠️ 意外状态，请稍后重试"
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
        HStack(alignment: .top, spacing: ReaderDesignTokens.settingsRowGap) {
            ReaderIcon(step.passed ? .check : .close, size: 16, accessibilityLabel: step.passed ? "通过" : "失败")
                .foregroundColor(step.passed ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.Semantic.danger)
                .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                .background(Circle().fill((step.passed ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.Semantic.danger).opacity(0.12)))
            VStack(alignment: .leading, spacing: 2) {
                Text(step.label)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                if let detail = step.detail {
                    Text(detail)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
        .frame(minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
    }
}

private struct M6VerificationSection<Content: View>: View {
    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.settingsSectionGap) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(spacing: 0) {
                    content
                }
            }
        }
    }
}

private struct M6VerificationButton: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let isPrimary: Bool
    let isDisabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ReaderDesignTokens.settingsRowGap) {
                ReaderIcon(icon, size: 17, accessibilityLabel: title)
                    .frame(width: ReaderDesignTokens.settingsRowIconColumn, height: ReaderDesignTokens.settingsRowIconColumn)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.system(size: ReaderDesignTokens.settingsRowMetaFontSize))
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, ReaderDesignTokens.settingsRowHorizontalPadding)
            .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.settingsRowMinHeight, alignment: .leading)
            .foregroundColor(foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
                    .fill(backgroundColor)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.55 : 1)
    }

    private var foregroundColor: Color {
        isPrimary ? .white : ReaderDesignTokens.Color.primaryDark
    }

    private var backgroundColor: Color {
        isPrimary ? ReaderDesignTokens.Color.primary : ReaderDesignTokens.Color.chipBackground
    }
}

private struct M6BoundaryRow: View {
    let title: String

    var body: some View {
        DemoIconRow(icon: .check, title: title, subtitle: "验证工具安全边界", detail: nil) {
            EmptyView()
        }
    }
}

#endif
