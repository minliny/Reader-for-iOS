import SwiftUI

/// 跨平台 Reader 颜色 token（日间模式）
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md §4.1
public enum ReaderColors {
    // MARK: - Light Mode

    public static let paperBg = Color(hex: "fff8f4")
    public static let bodyText = Color(hex: "53433f")
    public static let controlInk = Color(hex: "3f4d52")
    public static let primary = Color(hex: "366179")
    public static let bottomBarBg = Color(hex: "e9ded6")
    public static let floatingControlBg = Color(hex: "efe2d8")
    public static let floatingControlBgAlt = Color(hex: "eadbd0")
    public static let quickButtonBg = Color(hex: "f7ebe1")
    public static let controlBorder = Color(hex: "3f4d52").opacity(0.12)
    public static let mutedTrack = Color(hex: "3f4d52").opacity(0.16)
    public static let softTopBg = Color(hex: "fff8f4").opacity(0.92)
    public static let metaBg = Color(hex: "fbf2eb").opacity(0.94)

    // MARK: - Night Mode

    public static let nightPaperBg = Color(hex: "181f22")
    public static let nightBodyText = Color(hex: "d8ccc4")
    public static let nightControlInk = Color(hex: "d7e1e5")
    public static let nightPrimary = Color(hex: "8fb6ca")
    public static let nightBottomBarBg = Color(hex: "263238")
    public static let nightFloatingControlBg = Color(hex: "223037")
    public static let nightFloatingControlBgAlt = Color(hex: "2b3b43")
    public static let nightQuickButtonBg = Color(hex: "2f4149")
    public static let nightControlBorder = Color(hex: "d7e1e5").opacity(0.14)
    public static let nightMutedTrack = Color(hex: "d7e1e5").opacity(0.16)
    public static let nightSoftTopBg = Color(hex: "181f22").opacity(0.92)
    public static let nightMetaBg = Color(hex: "1f2a2f").opacity(0.94)
}
