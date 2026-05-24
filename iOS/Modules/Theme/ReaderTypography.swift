import SwiftUI

/// 跨平台 Reader 字体 token
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md §4.2
public enum ReaderTypography {
    /// 阅读标题 28/36/700
    public static let readerTitle = Font.system(size: 28, weight: .bold)
    /// 正文 18/1.72/400
    public static let readerBody = Font.system(size: 18, weight: .regular)
    /// 控制面板标题 18/24/700
    public static let controlTitle = Font.system(size: 18, weight: .bold)
    /// 控制面板标签 12/16/500
    public static let controlLabel = Font.system(size: 12, weight: .medium)
    /// 列表标题 14/18/600
    public static let listTitle = Font.system(size: 14, weight: .semibold)
    /// 页面标题 20/26/700
    public static let pageTitle = Font.system(size: 20, weight: .bold)
    /// 章节标题 28/36/700（同 readerTitle）
    public static let chapterTitle = Font.system(size: 28, weight: .bold)
}

public extension CGFloat {
    /// 正文行高倍数 1.72
    static let readerBodyLineHeight: CGFloat = 1.72
}
