import SwiftUI

/// Reader 颜色 token（light mode 对齐 demo `frontend-demo/tokens.css` 真源）。
///
/// @deprecated 新代码请直接使用 `ReaderDesignTokens.Color.*`（demo token 镜像）。
/// 本 enum 保留是为了兼容 `PrototypeGalleryView` / 验证测试等既有引用，色值与
/// `ReaderDesignTokens.Color` 完全一致。后续应逐步迁移到 `ReaderDesignTokens.Color`，
/// 并最终删除此 enum。
///
/// **状态**：已对齐 demo `--reader-ds-color-*` token 真值。新代码请直接使用
/// `ReaderDesignTokens.Color.*`（demo token 镜像）。本 enum 保留是为了兼容
/// 既有引用，色值与 `ReaderDesignTokens.Color` 完全一致。
///
/// **夜间模式**：night 系列已迁移到 `ReaderDesignTokens.Color.Night.*`
/// （对照 demo `render-runtime.js` night control 对象 32 个 token）。
/// 此处保留旧值仅为向后兼容，新代码请使用 `ReaderDesignTokens.Color.Night.*`。
public enum ReaderColors {
    // MARK: - Light Mode（对齐 demo tokens.css 真值，已迁移到 `ReaderDesignTokens.Color.*`）

    /// `--reader-ds-color-paper` #fff8f4（= `ReaderDesignTokens.Color.paperSolid`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.paperSolid")
    public static let paperBg = Color(hex: "fff8f4")
    /// `--reader-ds-color-ink` #1f1b17（= `ReaderDesignTokens.Color.ink`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.ink")
    public static let bodyText = Color(hex: "1f1b17")
    /// `--reader-ds-color-control-ink` #41484c（= `ReaderDesignTokens.Color.controlInk`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.controlInk")
    public static let controlInk = Color(hex: "41484c")
    /// `--reader-ds-color-primary` #366179（= `ReaderDesignTokens.Color.primary`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.primary")
    public static let primary = Color(hex: "366179")
    /// `--reader-ds-color-bottom-bar-bg` #fbf2eb（= `ReaderDesignTokens.Color.bottomBarBg`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.bottomBarBg")
    public static let bottomBarBg = Color(hex: "fbf2eb")
    /// `--reader-ds-color-floating-control-bg` #fbf2eb（= `ReaderDesignTokens.Color.floatingControlBg`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.floatingControlBg")
    public static let floatingControlBg = Color(hex: "fbf2eb")
    /// `--reader-ds-color-floating-control-bg-alt` #eae1da（= `ReaderDesignTokens.Color.floatingControlBgAlt`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.floatingControlBgAlt")
    public static let floatingControlBgAlt = Color(hex: "eae1da")
    /// demo 无 quickButtonBg token，对齐 `--reader-ds-color-surface-soft` rgba(255,252,248,0.72)（= `ReaderDesignTokens.Color.controlBackground`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.controlBackground")
    public static let quickButtonBg = Color(hex: "fffcf8").opacity(0.72)
    /// demo `--reader-ds-color-border` #c1c7cd，半透明用于控件边框。
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.mainNavBorder with opacity")
    public static let controlBorder = Color(hex: "c1c7cd").opacity(0.42)
    /// demo 无 mutedTrack token，用 `--reader-ds-color-muted` #756f69 半透明。
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.muted with opacity(0.16)")
    public static let mutedTrack = Color(hex: "756f69").opacity(0.16)
    /// `.fd-reader-top` 背景 rgba(255,250,244,0.92)（= `ReaderDesignTokens.Color.readerTopBackground`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.readerTopBackground")
    public static let softTopBg = Color(hex: "fffaf4").opacity(0.92)
    /// `--reader-ds-color-meta-bg` #f5ece6（= `ReaderDesignTokens.Color.metaBg`）
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.metaBg")
    public static let metaBg = Color(hex: "f5ece6")

    // MARK: - Night Mode（已迁移到 `ReaderDesignTokens.Color.Night.*`，此处仅为向后兼容）

    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.paperSolid")
    public static let nightPaperBg = Color(hex: "181f22")
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.ink")
    public static let nightBodyText = Color(hex: "d8ccc4")
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.controlInk")
    public static let nightControlInk = Color(hex: "d7e1e5")
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.primary")
    public static let nightPrimary = Color(hex: "8fb6ca")
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.surface")
    public static let nightBottomBarBg = Color(hex: "263238")
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.panel")
    public static let nightFloatingControlBg = Color(hex: "223037")
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.elevated")
    public static let nightFloatingControlBgAlt = Color(hex: "2b3b43")
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.disabledBg")
    public static let nightQuickButtonBg = Color(hex: "2f4149")
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.line")
    public static let nightControlBorder = Color(hex: "d7e1e5").opacity(0.14)
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.line with opacity")
    public static let nightMutedTrack = Color(hex: "d7e1e5").opacity(0.16)
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.surface")
    public static let nightSoftTopBg = Color(hex: "181f22").opacity(0.92)
    @available(*, deprecated, message: "Use ReaderDesignTokens.Color.Night.field")
    public static let nightMetaBg = Color(hex: "1f2a2f").opacity(0.94)
}
