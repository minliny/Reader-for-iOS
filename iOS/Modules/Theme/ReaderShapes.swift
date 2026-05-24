import SwiftUI

/// 跨平台 Reader 形状 token
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_UI_BASELINE.md §4.4
public enum ReaderShapes {
    /// 卡片圆角 16
    public static let card = RoundedRectangle(cornerRadius: 16)
    /// Overlay 面板圆角 22
    public static let overlay = RoundedRectangle(cornerRadius: 22)
    /// 圆形
    public static let circle = Circle()
    /// 胶囊形
    public static let pill = Capsule()
}

public extension CGFloat {
    static let readerCardRadius: CGFloat = 16
    static let readerOverlayRadius: CGFloat = 22
    static let readerPillRadius: CGFloat = 999
}
