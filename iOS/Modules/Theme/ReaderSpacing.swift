import CoreGraphics

/// 跨平台 Reader 间距 token
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md §4.3
/// + demo `frontend-demo-optimized/styles/00-foundation.css` `--fd-gap-*` / `--fd-space-*`
public enum ReaderSpacing {
    /// `--fd-gap-xs` 4px（demo `00-foundation.css` 真源）
    public static let xxs: CGFloat = 4
    /// `--fd-gap-xs` 8px
    public static let xs: CGFloat = 8
    /// `--fd-gap-sm` 12px
    public static let sm: CGFloat = 12
    /// `--fd-gap-md` 16px
    public static let md: CGFloat = 16
    /// `--fd-gap-lg` 24px
    public static let lg: CGFloat = 24
    /// `--fd-gap-xl` 32px（demo `--fd-ds-size-top-bar-height` 等 padding 真源）
    public static let xl: CGFloat = 32
    /// `--fd-gap-2xl` 48px（demo status bar / safe area gap）
    public static let xxl: CGFloat = 48

    /// 阅读器横向 padding（demo `.fd-ir-reading-layer` side inset 24px）
    public static let readerHorizontal: CGFloat = 24
    /// 底部安全区 gap（demo `--fd-bottom-safe-gap` 8px）
    public static let bottomSafeGap: CGFloat = 8
    /// 屏幕横向 padding（demo `.fd-content-block` / `.fd-page` horizontal padding 16px）
    public static let screenPadding: CGFloat = 16
    /// 卡片 padding（demo `.fd-continue-card` / `.fd-book-detail-hero` padding 14px）
    public static let cardPadding: CGFloat = 14
    /// 键盘上方 gap（demo `.fd-keyboard-gap` 12px，用于输入区域上方避让）
    public static let keyboardGap: CGFloat = 12
    /// 章节段落 gap（demo `.fd-ir-reading-layer p` margin-bottom 12px）
    public static let paragraphGap: CGFloat = 12
    /// 列表行 gap（demo `.fd-search-result-list` gap 9px / `.fd-book-grid.is-list-view` gap 10px）
    public static let listRowGap: CGFloat = 10
    /// Section head 间距（demo `.fd-section-head` gap 12px）
    public static let sectionHeadGap: CGFloat = 12
}
