import SwiftUI
import ReaderUIContract

// MARK: - Slice 4 Component Views
//
// 进度/会话/焦点/TTS 全屏页的 8 个 component view。
// 真源：contracts/fixtures/view-state.fixtures.json 的 reader-full-* / reader-book-cache /
// reader-debug-info / progress-sync / progress-sync-status RouteId
//
// 设计：
// - 全屏页 view 用 Form/List 布局展示占位内容（Slice 4 骨架，后续 slice 接真实数据）
// - BackTopBar 已在 Slice 2 注册，progress-sync 系列只需注册 Page view
// - 每个 view 从 ViewStateComponent.props 解码为强类型 Props（ComponentProps 协议）

// MARK: - 1. ReaderFullDirectoryPage

struct ReaderFullDirectoryPageView: View {
    let props: ReaderFullDirectoryPageProps

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
                Text("目录（全屏）")
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
                Text(props.bookId ?? "未知书籍")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
    }
}

// MARK: - 2. ReaderFullTtsPage

struct ReaderFullTtsPageView: View {
    let props: ReaderFullTtsPageProps

    var body: some View {
        VStack(alignment: .leading, spacing: ReaderDesignTokens.demoContentGap) {
            Text("朗读设置（全屏）")
                .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                .foregroundColor(ReaderDesignTokens.Color.ink)
            if let state = props.playbackState {
                Text("状态：\(state)")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            if let rate = props.rate {
                Text("语速：\(String(format: "%.1f", rate))x")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
    }
}

// MARK: - 3. ReaderFullAppearancePage

struct ReaderFullAppearancePageView: View {
    let props: ReaderFullAppearancePageProps

    var body: some View {
        Form {
            Section("外观") {
                if let theme = props.theme {
                    LabeledRow(label: "主题", value: theme)
                }
                if let fontSize = props.fontSize {
                    LabeledRow(label: "字号", value: String(format: "%.0f", fontSize))
                }
                if let lineSpacing = props.lineSpacing {
                    LabeledRow(label: "行距", value: String(format: "%.1f", lineSpacing))
                }
            }
        }
    }
}

// MARK: - 4. ReaderFullSettingsPage

struct ReaderFullSettingsPageView: View {
    let props: ReaderFullSettingsPageProps

    var body: some View {
        Form {
            Section("设置") {
                if let tapZone = props.tapZone {
                    LabeledRow(label: "点击翻页", value: tapZone)
                }
                if let volumeKey = props.volumeKey {
                    LabeledRow(label: "音量键翻页", value: volumeKey ? "开" : "关")
                }
                if let dualPage = props.dualPage {
                    LabeledRow(label: "双页阅读", value: dualPage ? "开" : "关")
                }
                if let brightness = props.brightness {
                    LabeledRow(label: "亮度", value: String(format: "%.0f%%", brightness * 100))
                }
            }
        }
    }
}

// MARK: - 5. ReaderBookCachePage

struct ReaderBookCachePageView: View {
    let props: ReaderBookCachePageProps

    var body: some View {
        Form {
            Section("书籍缓存") {
                if let bookId = props.bookId {
                    LabeledRow(label: "书籍", value: bookId)
                }
                if let cacheSize = props.cacheSize {
                    LabeledRow(label: "缓存大小", value: String(format: "%.1f MB", cacheSize))
                }
            }
        }
    }
}

// MARK: - 6. ReaderDebugInfoPage

struct ReaderDebugInfoPageView: View {
    let props: ReaderDebugInfoPageProps

    var body: some View {
        Form {
            Section("调试信息") {
                if let bookId = props.bookId {
                    LabeledRow(label: "书籍", value: bookId)
                }
                if let sourceId = props.sourceId {
                    LabeledRow(label: "书源", value: sourceId)
                }
            }
        }
    }
}

// MARK: - 7. ProgressSyncPage

struct ProgressSyncPageView: View {
    let props: ProgressSyncPageProps

    var body: some View {
        Form {
            Section("阅读进度同步") {
                if let enabled = props.enabled {
                    LabeledRow(label: "状态", value: enabled ? "已启用" : "已禁用")
                }
                if let lastSync = props.lastSyncTime {
                    LabeledRow(label: "上次同步", value: lastSync)
                }
            }
        }
    }
}

// MARK: - 8. SyncProgressPage

struct SyncProgressPageView: View {
    let props: SyncProgressPageProps

    var body: some View {
        VStack(spacing: ReaderDesignTokens.demoContentGap) {
            if let title = props.title {
                Text(title)
                    .font(.system(size: ReaderDesignTokens.bookCardTitleFontSize, weight: .heavy))
                    .foregroundColor(ReaderDesignTokens.Color.ink)
            }
            if let progress = props.progress {
                ProgressView(value: progress)
                    .progressViewStyle(.linear)
                Text("\(Int(progress * 100))%")
                    .font(.system(size: ReaderDesignTokens.bookCardMetaFontSize))
                    .foregroundStyle(ReaderDesignTokens.Color.muted)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 24)
    }
}

// MARK: - LabeledRow 辅助 view

struct LabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(ReaderDesignTokens.Color.muted)
            Spacer()
            Text(value)
                .foregroundColor(ReaderDesignTokens.Color.ink)
        }
    }
}

// MARK: - Slice 4 Component Registration

extension ComponentRegistry {

    /// 注册 Slice 4 的 8 个 component。
    /// 应在 App 启动时调用（如 ReaderApp.init），与 registerSlice2/3Components() 一起调用。
    public static func registerSlice4Components() {
        register([
            (.readerFullDirectoryPage, { component in
                let props = ReaderFullDirectoryPageProps(props: component.props) ?? ReaderFullDirectoryPageProps(props: [:])!
                return AnyView(ReaderFullDirectoryPageView(props: props))
            }),
            (.readerFullTtsPage, { component in
                let props = ReaderFullTtsPageProps(props: component.props) ?? ReaderFullTtsPageProps(props: [:])!
                return AnyView(ReaderFullTtsPageView(props: props))
            }),
            (.readerFullAppearancePage, { component in
                let props = ReaderFullAppearancePageProps(props: component.props) ?? ReaderFullAppearancePageProps(props: [:])!
                return AnyView(ReaderFullAppearancePageView(props: props))
            }),
            (.readerFullSettingsPage, { component in
                let props = ReaderFullSettingsPageProps(props: component.props) ?? ReaderFullSettingsPageProps(props: [:])!
                return AnyView(ReaderFullSettingsPageView(props: props))
            }),
            (.readerBookCachePage, { component in
                let props = ReaderBookCachePageProps(props: component.props) ?? ReaderBookCachePageProps(props: [:])!
                return AnyView(ReaderBookCachePageView(props: props))
            }),
            (.readerDebugInfoPage, { component in
                let props = ReaderDebugInfoPageProps(props: component.props) ?? ReaderDebugInfoPageProps(props: [:])!
                return AnyView(ReaderDebugInfoPageView(props: props))
            }),
            (.progressSyncPage, { component in
                let props = ProgressSyncPageProps(props: component.props) ?? ProgressSyncPageProps(props: [:])!
                return AnyView(ProgressSyncPageView(props: props))
            }),
            (.syncProgressPage, { component in
                let props = SyncProgressPageProps(props: component.props) ?? SyncProgressPageProps(props: [:])!
                return AnyView(SyncProgressPageView(props: props))
            }),
        ])
    }
}
