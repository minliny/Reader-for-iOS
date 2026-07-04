import Foundation
import ReaderUIContract
import ReaderShellValidation

/// ReaderCoreBridge — Contract `CoreCommand` 与既有 `ReaderCoreServiceProvider` 之间的 facade。
///
/// 职责（CONTRACT_FIRST_NATIVE_UI_PLAN.md §5 + §8）：
/// - 消费 contract `CoreCommand`（如 `source.search`、`content.load`、`reader.progress.update`）
/// - 转发到既有 `ReaderCoreServiceProvider` 方法
/// - 返回 contract `CoreEvent` 给 reducer
///
/// 设计：
/// - 本 bridge 是 **facade**，不重写 `ReaderCoreServiceProvider`。
/// - 现有 `ReaderCoreServiceProvider` 已有 `.rustCore` mode 桥接 Rust Core，
///   bridge 只做 contract command name → 既有方法名的 mapping。
/// - 不改 Reader-Core-Native 协议名（Phase 2B 未完成），mapping 表稳定后再决定。
///
/// Core command mapping（contract → Core-Native 现有协议）：
/// ```
/// source.search            -> book.search           (RustCoreSearchService)
/// source.detail            -> book.info             (RustCoreBookDetailService)
/// content.load             -> chapter.content       (RustCoreContentService)
/// chapter.list             -> chapter.list          (RustCoreTOCService)
/// reader.progress.update   -> reading.progress.update (ProgressSyncManager)
/// rss.list                 -> (待 Core 补齐)
/// ```
@MainActor
public final class ReaderCoreBridge {
    private let provider: ReaderCoreServiceProvider

    public init(provider: ReaderCoreServiceProvider = .shared) {
        self.provider = provider
    }

    // MARK: - Slice 1 占位（不依赖 Core，slice 1 不调用）

    /// Slice 1：AppShell + main tabs 不依赖 Core，bridge 仅作为骨架存在。
    /// 后续 slice 落地时，逐步把 `CoreCommand` 映射到 `provider` 方法。

    public func send(_ command: CoreCommand) async throws -> CoreEvent? {
        switch command.type {
        case .source_search:
            // Slice 5 落地：source.search -> provider.search(...)
            return nil
        case .source_detail:
            // Slice 2 落地：source.detail -> provider.fetchBookDetail(...)
            return nil
        case .content_load:
            // Slice 2 落地：content.load -> provider.fetchContent(...)
            return nil
        case .chapter_list:
            // Slice 2 落地：chapter.list -> provider.fetchTOC(...)
            return nil
        case .reader_progress_update:
            // Slice 4 落地：reader.progress.update -> ProgressSyncManager
            return nil
        case .rss_list:
            // Phase 2B 未完成：rss.list 待 Core-Native 补齐
            return nil
        default:
            // 其他 command 类型留待后续 slice
            return nil
        }
    }

    // MARK: - Core command mapping 表（文档化，不实际执行）

    /// Contract `CoreCommandType` -> Core-Native 现有协议名 mapping。
    ///
    /// 用于 Phase 2B 协议对齐前的过渡。mapping 表稳定后，再决定：
    /// - 选项 A：Core-Native 改协议名对齐 contract
    /// - 选项 B：长期保留本 facade mapping
    public static let commandMapping: [CoreCommandType: String] = [
        .source_search:          "book.search",
        .source_detail:          "book.info",
        .content_load:           "chapter.content",
        .chapter_list:           "chapter.list",
        .reader_progress_update: "reading.progress.update",
        // 以下待 Core-Native 补齐：
        .rss_list:               "(pending)",
        .rss_item_read:          "(pending)",
    ]
}
