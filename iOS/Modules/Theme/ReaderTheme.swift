import SwiftUI

/// 跨平台 Reader 阅读页布局 metrics
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_READER_CONTROL_SPEC.md §2
public enum ReaderControlMetrics {
    public static let topBarHeight: CGFloat = 56
    public static let metaRowHeight: CGFloat = 48
    public static let bottomBarHeight: CGFloat = 68
    public static let pageControlHeight: CGFloat = 52
    public static let pageControlWidth: CGFloat = 342
    public static let quickCircleSize: CGFloat = 48
    public static let quickCircleGap: CGFloat = 20
    public static let brightnessWidth: CGFloat = 40
    public static let brightnessHeight: CGFloat = 256
    public static let brightnessInset: CGFloat = 12
    public static let contentPaddingTop: CGFloat = 128
    public static let contentPaddingBottom: CGFloat = 230
    public static let contentPaddingHorizontal: CGFloat = 24
}

/// 跨平台 Reader 主题管理器
/// 日间/夜间模式切换，非弹窗
@MainActor
public final class ReaderThemeManager: ObservableObject {
    @Published public var isNightMode: Bool = false

    public init() {}

    /// 切换夜间/日间模式（非弹窗）
    public func toggleNightMode() {
        isNightMode.toggle()
    }
}
