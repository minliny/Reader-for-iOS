import Foundation
import SwiftUI

// MARK: - ReaderTextPaginator
//
// 阅读正文分页测量器。阶段 1 提供接口骨架，分页实现在 Slice 2 接入。
//
// 真源：
// - 契约不提供分页算法（`view-state.fixtures.json` immersive-reading fixture 只有 ReaderBase）
// - `iOS/CoreBridge/TextPaginationEngine.swift` 已有 TextKit 2 分页实现（ReaderShellValidation 模块）
// - `iOS/Features/Reader/PaginatedReaderView.swift` L268-299 recomputePages 已用 TextPaginationEngine
//
// 设计：
// - 阶段 1 只定义配置类型 + 接口，不直接依赖 `TextPaginationEngine`（它在 ReaderShellValidation 模块，
//   ReaderForIOSApp 模块无法直接访问 internal 类型）
// - Slice 2 通过 `ReaderShellValidation` 框架的 public API 或协议注入接入实际分页

/// 阅读正文分页配置。从 `ReadingTextFlowProps` 派生。
public struct ReaderTypographyConfig: Equatable {
    public let fontSize: Double       // 14-26（demo `--fd-ds-type-reader-body-size`）
    public let lineHeight: Double     // 1.4-2.4（行距倍数）
    public let paragraphSpacing: Double  // 4-32（段距 pt）
    public let letterSpacing: Double  // 0-2（字距 pt）

    public init(
        fontSize: Double = 18,
        lineHeight: Double = 1.8,
        paragraphSpacing: Double = 16,
        letterSpacing: Double = 0
    ) {
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.paragraphSpacing = paragraphSpacing
        self.letterSpacing = letterSpacing
    }
}

/// 单页文本范围。
public struct ReaderPageRange: Equatable, Identifiable {
    public let id: Int  // pageIndex
    public let startOffset: Int
    public let endOffset: Int
}

/// 阅读正文分页协议。Slice 2 将注入 `TextPaginationEngine` 适配实现。
public protocol ReaderTextPaginationEngine {
    func paginate(
        text: String,
        config: ReaderTypographyConfig,
        availableSize: CGSize,
        horizontalPadding: CGFloat,
        verticalPadding: CGFloat
    ) -> [ReaderPageRange]
}

/// 阅读正文分页器。阶段 1 骨架，分页实现由 Slice 2 注入。
public struct ReaderTextPaginator {

    /// 注入的分页引擎（nil 时返回整文本作为单页）。
    public var engine: ReaderTextPaginationEngine?

    public init(engine: ReaderTextPaginationEngine? = nil) {
        self.engine = engine
    }

    /// 分页测量。
    public func paginate(
        text: String,
        config: ReaderTypographyConfig,
        availableSize: CGSize,
        horizontalPadding: CGFloat = 16,
        verticalPadding: CGFloat = 16
    ) -> [ReaderPageRange] {
        guard availableSize.width > 0,
              availableSize.height > 0,
              !text.isEmpty else {
            return []
        }

        // 阶段 1：无 engine 时返回整文本作为单页（骨架行为）
        guard let engine else {
            return [
                ReaderPageRange(
                    id: 0,
                    startOffset: 0,
                    endOffset: text.count
                )
            ]
        }

        return engine.paginate(
            text: text,
            config: config,
            availableSize: availableSize,
            horizontalPadding: horizontalPadding,
            verticalPadding: verticalPadding
        )
    }

    /// 计算当前页的进度比例（0.0 - 1.0）。
    public func progress(pageIndex: Int, totalPages: Int) -> Double {
        guard totalPages > 0 else { return 0 }
        return Double(pageIndex) / Double(totalPages)
    }
}
