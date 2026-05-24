import CoreGraphics

/// 跨平台 Reader 间距 token
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md §4.3
public enum ReaderSpacing {
    public static let xs: CGFloat = 8
    public static let sm: CGFloat = 12
    public static let md: CGFloat = 16
    public static let lg: CGFloat = 24
    public static let readerHorizontal: CGFloat = 24
    public static let bottomSafeGap: CGFloat = 8
}
