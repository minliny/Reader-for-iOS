import SwiftUI

/// Reader 形状 token（demo `00-foundation.css` `--fd-radius-*` 真源）。
///
/// 真源对照：
/// - `--fd-radius-md: 8px` — 通用卡片/控件圆角
/// - `--fd-radius-xl: 24px` — 大型 overlay/面板圆角
/// - `--fd-radius-pill: 999px` — 胶囊
/// - `--fd-radius-circle: 50%` — 圆形
public enum ReaderShapes {
    /// 卡片圆角，对应 demo `--fd-radius-md` 8px（`00-foundation.css` line 21）。
    public static let card = RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.md)
    /// Overlay 面板圆角，对应 demo `--fd-radius-xl` 24px（`00-foundation.css` line 23，
    /// 用于 `.fd-book-focus-backdrop` / `.fd-discover-dialog-backdrop` 等大型遮罩）。
    public static let overlay = RoundedRectangle(cornerRadius: ReaderDesignTokens.Radius.xl)
    /// 圆形
    public static let circle = Circle()
    /// 胶囊形
    public static let pill = Capsule()
}

public extension CGFloat {
    /// 卡片圆角，对应 `ReaderShapes.card` = `--fd-radius-md` 8px。
    static let readerCardRadius: CGFloat = ReaderDesignTokens.Radius.md
    /// Overlay 圆角，对应 `ReaderShapes.overlay` = `--fd-radius-xl` 24px。
    static let readerOverlayRadius: CGFloat = ReaderDesignTokens.Radius.xl
    /// 胶囊圆角，对应 `--fd-radius-pill` 999px。
    static let readerPillRadius: CGFloat = ReaderDesignTokens.Radius.pill
}
