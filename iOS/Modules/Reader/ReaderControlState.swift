import Foundation

/// 跨平台 Reader 阅读控制层状态（9 类）
/// 真源：Reader-Core docs/cross-platform-ui/CROSS_PLATFORM_STATE_MATRIX.md §3
/// 关键规则：
/// - 夜间模式不是弹窗，只切换日/夜状态
/// - 快捷按钮无文字标签
/// - 页内控制是本章内上一页/下一页，不使用 skip_previous/skip_next 语义
public enum ReaderControlState: Equatable {
    /// 基础控制层可见：顶栏+底栏+亮度+快捷按钮+页内控制
    case baseControlVisible
    /// 快捷操作 overlay：隐藏亮度，保留快捷按钮+页内控制+底栏
    case quickActionOverlay(QuickActionType)
    /// 底部功能 overlay：隐藏亮度+快捷按钮+页内控制，保留顶栏+底栏
    case bottomFunctionOverlay(BottomFunctionType)
    /// 夜间模式（仅切换 token，不是弹窗）
    case nightState
}

/// 快捷操作类型
public enum QuickActionType: String, Equatable, CaseIterable {
    /// 搜索本章
    case search
    /// 自动翻页
    case autoScroll
    /// 内容替换（仅当前书籍匹配规则）
    case replace
}

/// 底部功能类型
public enum BottomFunctionType: String, Equatable, CaseIterable {
    /// 目录/书签（含分级小字、右侧常驻进度条、书签标识、当前阅读标识）
    case directory
    /// 朗读（不使用章节跳转语义）
    case tts
    /// 界面设置（字体/字号/行距/段距/页边距/翻页动画）
    case appearance
    /// 阅读行为设置（不包含 WebDAV/书源/RSS）
    case settings
}

/// 亮度条停靠
public enum BrightnessDock: String, Equatable {
    case left
    case right
}

// MARK: - Companion flags

/// 朗读状态
public enum TtsState: Equatable {
    case playing
    case paused
    case stopped
}

/// 自动翻页状态
public enum AutoScrollState: Equatable {
    case running
    case paused
    case stopped
}
