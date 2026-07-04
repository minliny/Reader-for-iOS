import SwiftUI
import UniformTypeIdentifiers
import ReaderCoreModels
import ReaderShellValidation

struct BookshelfLocalImportView: View {
    @StateObject private var viewModel = FileImportViewModel()
    @State private var showFilePicker = false
    @SwiftUI.Environment(\.dismiss) private var dismiss: DismissAction
    private let onImported: ((CoreLocalBookImportSummary) -> Void)?
    private let onExit: (() -> Void)?

    init(onImported: ((CoreLocalBookImportSummary) -> Void)? = nil, onExit: (() -> Void)? = nil) {
        self.onImported = onImported
        self.onExit = onExit
    }

    var body: some View {
        DemoBackScreen(title: "本地书导入", onBack: onExit) {
            importEntryCard
            importOptionsList
            importResultsList
        } bottomActionHost: {
            BottomFixedActionRow {
                BookshelfImportBottomButton(title: "继续选择", isPrimary: true) {
                    showFilePicker = true
                }
            } trailing: {
                BookshelfImportBottomButton(title: "完成导入", isPrimary: false) {
                    finishImport()
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: viewModel.supportedContentTypes,
            allowsMultipleSelection: false,
            onCompletion: handleFileImporterResult
        )
    }

    private var importEntryCard: some View {
        ReaderCard {
            HStack(spacing: ReaderDesignTokens.bookImportEntryGap) {
                ReaderIcon(.folder, size: ReaderDesignTokens.bookImportEntryIconSize, accessibilityLabel: "选择本地书文件")
                    .frame(width: ReaderDesignTokens.bookImportEntryIconColumn)
                    .foregroundColor(ReaderDesignTokens.Color.primaryDark)

                VStack(alignment: .leading, spacing: 5) {
                    Text("选择本地书文件")
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .lineLimit(1)
                    Text(importEntrySubtitle)
                        .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                        .foregroundStyle(ReaderDesignTokens.Color.muted)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Button {
                    showFilePicker = true
                } label: {
                    Text("选择")
                        .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                        .foregroundColor(.white)
                        .padding(.horizontal, ReaderDesignTokens.bookImportEntryButtonHorizontalPadding)
                        .frame(minHeight: ReaderDesignTokens.bookImportEntryButtonMinHeight)
                        .background(Capsule().fill(ReaderDesignTokens.Color.primary))
                }
                .buttonStyle(.plain)
            }
            .padding(ReaderDesignTokens.bookImportEntryPadding - ReaderDesignTokens.cardPadding)
        }
    }

    private var importOptionsList: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 0) {
                managementTitle("导入设置")
                BookshelfImportOptionRow(icon: .folder, title: "导入分组", subtitle: "默认分组", actionTitle: "更改")
                Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                BookshelfImportOptionRow(icon: .refresh, title: "重复书籍", subtitle: "保留原书，仅导入新文件", actionTitle: "更改")
            }
            .padding(.top, max(0, ReaderDesignTokens.bookGroupListTopPadding - ReaderDesignTokens.cardPadding))
        }
    }

    private var importResultsList: some View {
        ReaderCard {
            VStack(alignment: .leading, spacing: 0) {
                managementTitle("待导入文件")
                ForEach(importRows) { row in
                    BookshelfImportResultRow(row: row)
                    if row.id != importRows.last?.id {
                        Divider().overlay(ReaderDesignTokens.Color.rssRowBorder)
                    }
                }
            }
            .padding(.top, max(0, ReaderDesignTokens.bookGroupListTopPadding - ReaderDesignTokens.cardPadding))
        }
    }

    private var importEntrySubtitle: String {
        switch viewModel.importState {
        case .idle, .selecting:
            return "选择后识别分组并确认导入"
        case .importing(let name):
            return "正在识别 \(name) 的元数据与章节"
        case .imported(let summary):
            return "\(summary.book.title) 已完成识别，可加入书架"
        case .failed:
            return "导入失败，可重新选择本地书文件"
        }
    }

    private var importRows: [BookshelfImportRow] {
        switch viewModel.importState {
        case .idle, .selecting:
            return BookshelfImportRow.demoRows
        case .importing(let name):
            return [
                BookshelfImportRow(id: "importing", title: name, meta: "正在读取元数据 · 加入默认分组", state: "解析中", tone: .warn)
            ]
        case .imported(let summary):
            let book = summary.book
            let author = book.author ?? "作者已识别"
            let format = book.fileFormat.rawValue.uppercased()
            return [
                BookshelfImportRow(
                    id: "imported-\(book.id)",
                    title: book.title,
                    meta: "\(author) · \(format) · \(summary.chapterCount) 章",
                    state: "可导入",
                    tone: .good
                )
            ]
        case .failed(let message):
            return [
                BookshelfImportRow(id: "failed", title: "导入失败", meta: message, state: "失败", tone: .danger)
            ]
        }
    }

    private var importedSummary: CoreLocalBookImportSummary? {
        if case .imported(let summary) = viewModel.importState {
            return summary
        }
        return nil
    }

    private func managementTitle(_ title: String) -> some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.settingsSectionTitleFontSize, weight: .black))
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
            .padding(.horizontal, ReaderDesignTokens.bookGroupRowHorizontalPadding - ReaderDesignTokens.cardPadding)
            .padding(.bottom, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func handleFileImporterResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                Task { await viewModel.handleSelectedFile(url) }
            }
        case .failure(let error):
            viewModel.importState = .failed(message: error.localizedDescription)
        }
    }

    private func finishImport() {
        if let importedSummary {
            onImported?(importedSummary)
        }
        if let onExit {
            onExit()
        } else {
            dismiss()
        }
    }
}

private struct BookshelfImportRow: Identifiable, Hashable {
    enum Tone: Hashable {
        case good
        case warn
        case danger
    }

    let id: String
    let title: String
    let meta: String
    let state: String
    let tone: Tone

    static let demoRows: [BookshelfImportRow] = [
        BookshelfImportRow(id: "rain-night", title: "雨夜.epub", meta: "作者已识别 · 加入默认分组", state: "可导入", tone: .good),
        BookshelfImportRow(id: "scan-text", title: "旧书扫描.txt", meta: "编码 UTF-8 · 章节识别中", state: "72%", tone: .warn),
        BookshelfImportRow(id: "missing-chapter", title: "缺失章节.mobi", meta: "格式不支持 · 可移除后重选", state: "失败", tone: .danger)
    ]
}

private struct BookshelfImportOptionRow: View {
    let icon: ReaderAssetIcon
    let title: String
    let subtitle: String
    let actionTitle: String

    var body: some View {
        HStack(spacing: ReaderDesignTokens.bookGroupRowGap) {
            ReaderIcon(icon, size: 18, accessibilityLabel: title)
                .frame(width: ReaderDesignTokens.bookGroupIconColumn)
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BookshelfImportStatePill(title: actionTitle, tone: .neutral)
        }
        .padding(.horizontal, ReaderDesignTokens.bookGroupRowHorizontalPadding - ReaderDesignTokens.cardPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookImportListRowMinHeight, alignment: .leading)
    }
}

private struct BookshelfImportResultRow: View {
    let row: BookshelfImportRow

    var body: some View {
        HStack(spacing: ReaderDesignTokens.bookGroupRowGap) {
            ReaderIcon(row.tone == .danger ? .warning : .bookOpen, size: 18, accessibilityLabel: row.title)
                .frame(width: ReaderDesignTokens.bookGroupIconColumn)
                .foregroundColor(toneColor)

            VStack(alignment: .leading, spacing: 3) {
                Text(row.title)
                    .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                    .lineLimit(1)
                Text(row.meta)
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            BookshelfImportStatePill(title: row.state, tone: stateTone)
        }
        .padding(.horizontal, ReaderDesignTokens.bookGroupRowHorizontalPadding - ReaderDesignTokens.cardPadding)
        .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bookImportListRowMinHeight, alignment: .leading)
    }

    private var toneColor: SwiftUI.Color {
        switch row.tone {
        case .good:
            return ReaderDesignTokens.Color.Semantic.success
        case .warn:
            return ReaderDesignTokens.Color.Semantic.warning
        case .danger:
            return ReaderDesignTokens.Color.danger
        }
    }

    private var stateTone: BookshelfImportStatePill.Tone {
        switch row.tone {
        case .good:
            return .good
        case .warn:
            return .warn
        case .danger:
            return .danger
        }
    }
}

private struct BookshelfImportStatePill: View {
    enum Tone {
        case neutral
        case good
        case warn
        case danger
    }

    let title: String
    let tone: Tone

    var body: some View {
        Text(title)
            .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize, weight: .black))
            .lineLimit(1)
            .foregroundColor(foregroundColor)
            .padding(.horizontal, 10)
            .frame(minHeight: ReaderDesignTokens.bookGroupActionMinHeight)
            .background(Capsule().fill(backgroundColor))
    }

    private var foregroundColor: SwiftUI.Color {
        switch tone {
        case .neutral:
            return ReaderDesignTokens.Color.primaryDark
        case .good:
            return ReaderDesignTokens.Color.Semantic.success
        case .warn:
            return ReaderDesignTokens.Color.Semantic.warning
        case .danger:
            return ReaderDesignTokens.Color.danger
        }
    }

    private var backgroundColor: SwiftUI.Color {
        switch tone {
        case .neutral:
            return ReaderDesignTokens.Color.primary.opacity(0.10)
        case .good:
            return ReaderDesignTokens.Color.Semantic.successTint
        case .warn:
            return ReaderDesignTokens.Color.Semantic.warningTint
        case .danger:
            // demo `--fd-danger: #d62222`（`00-foundation.css` line 14）
            return ReaderDesignTokens.Color.danger.opacity(0.10)
        }
    }
}

private struct BookshelfImportBottomButton: View {
    let title: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: ReaderDesignTokens.settingsRowTitleFontSize, weight: .black))
                .lineLimit(1)
                .foregroundColor(isPrimary ? .white : ReaderDesignTokens.Color.ink)
                .frame(maxWidth: .infinity, minHeight: ReaderDesignTokens.bottomFixedActionButtonMinHeight)
                .background(
                    Capsule()
                        .fill(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBackground)
                        .overlay(Capsule().stroke(isPrimary ? ReaderDesignTokens.Color.primaryDark : ReaderDesignTokens.Color.mainNavBorder, lineWidth: 1))
                )
        }
        .buttonStyle(.plain)
    }
}
