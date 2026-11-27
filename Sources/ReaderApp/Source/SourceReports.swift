import Observation
import ReaderCoreBridge
import ReaderDesign
import SwiftUI

struct SourceReportRow: Identifiable {
    let sourceId: String
    let name: String
    let report: M2SourceCheckReport?
    var stale = false
    var error: String?

    var id: String { sourceId }

    var filter: SourceReportFilter {
        if stale { return .notExecuted }
        if error != nil || report?.steps.contains(where: { $0.status == .fail }) == true { return .failed }
        if report?.steps.contains(where: { $0.requested && ($0.status == .blocked || $0.status == .cancelled) }) == true {
            return .notExecuted
        }
        if report?.steps.contains(where: { $0.status == .pass }) == true { return .passed }
        return .notExecuted
    }
}

enum SourceReportFilter: String, CaseIterable, Identifiable {
    case all, passed, failed, notExecuted

    var id: Self { self }

    var label: String {
        switch self {
        case .all: "全部"
        case .passed: "通过"
        case .failed: "失败"
        case .notExecuted: "未执行"
        }
    }

    var tone: SourceStatusBadge.Tone {
        switch self {
        case .passed: .success
        case .failed: .failure
        case .all, .notExecuted: .neutral
        }
    }
}

/// Retained by the app-scoped coordinator. Each completed row comes from
/// a source.check.run completion, and navigation does not cancel the batch.
@MainActor
@Observable
final class SourceCheckBatch {
    private(set) var rows: [SourceReportRow] = []
    private(set) var running = false
    private(set) var revision = 0

    var completed: Int { rows.filter { $0.filter == .passed }.count }
    var failed: Int { rows.filter { $0.filter == .failed }.count }

    func forget(_ sourceId: String) {
        rows.removeAll { $0.sourceId == sourceId }
    }

    func start(sources: [M2SourceListEntry], levels: [M2SourceCheckRunParamsLevelsItem],
               keyword: String?, coordinator: SourceManagementCoordinator) {
        guard !running, !sources.isEmpty, !levels.isEmpty else { return }
        rows = sources.map { .init(sourceId: $0.sourceId, name: $0.name, report: nil) }
        running = true
        Task {
            defer {
                running = false
                revision += 1
            }
            for source in sources {
                do {
                    let result = try await coordinator.check(.init(
                        reportVersion: .v2, mode: .search, sourceIds: [source.sourceId],
                        keyword: keyword, keywordOverride: keyword.map { _ in true },
                        timeoutMs: 15_000, levels: levels
                    ))
                    let match = result.results.first { $0.sourceId == source.sourceId }
                    update(source, report: match?.report, error: match?.report == nil ? "书源未返回检测结果" : nil)
                } catch {
                    update(source, report: nil, error: "检测请求未完成")
                }
            }
        }
    }

    private func update(_ source: M2SourceListEntry, report: M2SourceCheckReport?, error: String?) {
        guard let row = rows.firstIndex(where: { $0.sourceId == source.sourceId }) else { return }
        rows[row] = .init(sourceId: source.sourceId, name: source.name, report: report, error: error)
    }
}

struct SourceReportContent: View {
    let rows: [SourceReportRow]
    @Binding var filter: SourceReportFilter
    let onSelect: (SourceReportRow) -> Void
    @Environment(\.readerTheme) private var theme

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
                Picker("检测状态", selection: $filter) {
                    ForEach(SourceReportFilter.allCases) { scope in Text(scope.label).tag(scope) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("source.report.filter")

                let visible = rows.filter { filter == .all || $0.filter == filter }
                if visible.isEmpty {
                    PageState(state: .empty("该筛选暂无报告"))
                        .frame(minHeight: 220)
                }
                ForEach(visible) { row in
                    Button { onSelect(row) } label: {
                        VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceExtraSmall)) {
                            HStack {
                                Text(row.name).readerTypography(ReaderDesignMetrics.sourceRowTitle)
                                Spacer()
                                SourceStatusBadge(label: row.stale ? "已过期" : row.filter.label, tone: row.filter.tone)
                                ReaderIcon(ReaderIconRegistry.drillIn).foregroundStyle(theme.secondaryText)
                            }
                            if let report = row.report {
                                SourceReportLevels(steps: report.steps)
                            } else if let error = row.error {
                                Text(error).readerTypography(ReaderDesignMetrics.rowDetail)
                                    .foregroundStyle(theme.danger)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(theme.primaryText)
                        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
                        .background(theme.surface, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("source.report.row.\(row.id)")
                }
            }
            .padding(CGFloat(ReaderDesignMetrics.screenInset))
            .frame(maxWidth: 650)
            .frame(maxWidth: .infinity)
        }
        .background(theme.background)
    }
}

struct SourceReportLevels: View {
    let steps: [M2SourceCheckReportStepsItem]

    var body: some View {
        HStack(spacing: CGFloat(ReaderDesignMetrics.sourceStatusChipGap)) {
            ForEach(M2SourceCheckReportStepsItemLevel.allCases, id: \.self) { level in
                let status = steps.first { $0.level == level }?.status ?? .notRequested
                SourceStatusBadge(label: level.rawValue, tone: status.tone)
                    .frame(minWidth: CGFloat(ReaderDesignMetrics.sourceCheckStageBadgeWidth),
                           minHeight: CGFloat(ReaderDesignMetrics.sourceCheckStageBadgeHeight))
                    .accessibilityLabel("\(level.rawValue) \(status.label)")
            }
        }
    }
}

struct SourceReportsScreen: View {
    let storedSources: [M2SourceListEntry]
    let batch: SourceCheckBatch
    @State private var filter: SourceReportFilter = .all
    @State private var selected: SourceReportRow?
    @Environment(\.dismiss) private var dismiss

    private var rows: [SourceReportRow] {
        let stored = storedSources.compactMap(\.latestSourceReport)
        let recent = batch.rows
        let recentIDs = Set(recent.map(\.id))
        return recent + stored.filter { !recentIDs.contains($0.id) }
    }

    var body: some View {
        SourceReportContent(rows: rows, filter: $filter, onSelect: { selected = $0 })
            .safeAreaInset(edge: .bottom) {
                if batch.running {
                    ReaderTaskProgress(title: "正在检测书源", completed: batch.completed, failed: batch.failed,
                                       total: batch.rows.count)
                        .padding(CGFloat(ReaderDesignMetrics.screenInset))
                }
            }
            .navigationTitle("批量检测报告")
            .navigationBarTitleDisplayMode(.inline)
            .readerNavigationBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }.accessibilityIdentifier("source.reports.close")
                }
            }
            .sheet(item: $selected) { row in
                NavigationStack { SourceDiagnosticScreen(row: row, batch: batch) }
            }
    }
}

struct SourceDiagnosticScreen: View {
    let row: SourceReportRow
    var batch: SourceCheckBatch?
    @Environment(\.readerTheme) private var theme
    @Environment(\.dismiss) private var dismiss

    private var current: SourceReportRow {
        batch?.rows.first { $0.id == row.id } ?? row
    }

    var body: some View {
        Group {
            if let report = current.report {
                ScrollView {
                    VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.spaceSmall)) {
                        Text(current.name).readerTypography(ReaderDesignMetrics.pageTitle)
                        if current.stale {
                            Text("规则已变更，重新检测可获得当前结果。")
                                .readerTypography(ReaderDesignMetrics.rowDetail)
                                .foregroundStyle(theme.secondaryText)
                        }
                        ForEach(report.steps, id: \.level) { step in
                            diagnostic(step)
                        }
                    }
                    .padding(CGFloat(ReaderDesignMetrics.screenInset))
                }
            } else if batch?.running == true && current.error == nil,
                      batch?.rows.contains(where: { $0.id == row.id }) == true {
                PageState(state: .loading)
            } else {
                PageState(state: .empty(current.error ?? "该书源暂无检测报告"))
            }
        }
        .background(theme.background)
        .navigationTitle("层级诊断")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("关闭") { dismiss() }.accessibilityIdentifier("source.report.detail.close")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("source.report.detail")
    }

    private func diagnostic(_ step: M2SourceCheckReportStepsItem) -> some View {
        VStack(alignment: .leading, spacing: CGFloat(ReaderDesignMetrics.rowBlockSpacing)) {
            HStack {
                Text("\(step.level.rawValue) · \(step.level.label)")
                    .readerTypography(ReaderDesignMetrics.rowLabel)
                Spacer()
                SourceStatusBadge(label: step.status.label, tone: step.status.tone)
            }
            if step.executed {
                Text("耗时 \(step.durationMs) ms")
                    .readerTypography(ReaderDesignMetrics.rowDetail)
                    .foregroundStyle(theme.secondaryText)
            }
            if let reason = step.reason {
                Text(reason.userFacingSourceDiagnostic)
                    .readerTypography(ReaderDesignMetrics.rowDetail)
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(CGFloat(ReaderDesignMetrics.cardPadding))
        .background(theme.surface, in: RoundedRectangle(cornerRadius: CGFloat(ReaderDesignMetrics.cardRadius)))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("source.report.stage.\(step.level.rawValue)")
    }
}

struct SourceCheckOptions: View {
    let count: Int
    let onConfirm: ([M2SourceCheckRunParamsLevelsItem], String?) -> Void
    @State private var selection = Set(M2SourceCheckRunParamsLevelsItem.allCases)
    @State private var keyword = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Form {
            Section("检测范围") {
                Text("已选 \(count) 个书源")
                ForEach(M2SourceCheckRunParamsLevelsItem.allCases, id: \.self) { level in
                    Toggle("\(level.rawValue) \(M2SourceCheckReportStepsItemLevel(rawValue: level.rawValue)?.label ?? "")",
                           isOn: Binding(get: { selection.contains(level) }, set: { enabled in
                        if enabled { selection.insert(level) } else { selection.remove(level) }
                    }))
                }
            }
            Section("搜索关键词") {
                TextField("留空使用书源默认关键词", text: $keyword)
                    .accessibilityIdentifier("source.check.keyword")
            }
        }
        .navigationTitle("分层检测")
        .navigationBarTitleDisplayMode(.inline)
        .readerNavigationBar()
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("开始检测") {
                    let input = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
                    onConfirm(M2SourceCheckRunParamsLevelsItem.allCases.filter(selection.contains), input.isEmpty ? nil : input)
                    dismiss()
                }
                .disabled(selection.isEmpty)
                .accessibilityIdentifier("source.check.confirm")
            }
        }
    }
}

extension M2SourceListEntry {
    var latestSourceReport: SourceReportRow? {
        guard let latest = checkReports?.max(by: { $0.checkedAtMs < $1.checkedAtMs }) else { return nil }
        return .init(sourceId: sourceId, name: name, report: latest.report, stale: latest.stale)
    }
}

private extension M2SourceCheckReportStepsItemLevel {
    var label: String {
        switch self {
        case .l1: "书源规则"
        case .l2: "搜索结果"
        case .l3: "书籍详情"
        case .l4: "章节目录"
        case .l5: "正文内容"
        }
    }
}

private extension M2SourceCheckReportStepsItemStatus {
    var label: String {
        switch self {
        case .pass: "通过"
        case .fail: "失败"
        case .notRequested: "未选择"
        case .notSupported: "不支持"
        case .blocked: "前置受阻"
        case .cancelled: "已取消"
        }
    }

    var tone: SourceStatusBadge.Tone {
        switch self {
        case .pass: .success
        case .fail: .failure
        case .blocked, .cancelled: .warning
        case .notRequested, .notSupported: .neutral
        }
    }
}

private extension String {
    var userFacingSourceDiagnostic: String {
        switch self {
        case "SOURCE_DISABLED": "书源已停用"
        case "HTTP_ERROR": "服务响应失败"
        case "TIMEOUT": "请求超时"
        case "CAPABILITY_UNAVAILABLE": "所需平台能力不可用"
        case "LOGIN_REQUIRED": "需要登录后重新检测"
        case "no_search_results": "没有找到匹配结果"
        default: "可检查当前层级规则后重新检测。"
        }
    }
}
