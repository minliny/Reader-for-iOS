import Foundation
import CoreGraphics

/// App 级动效 token adapter。
///
/// 真源：Reader UI `frontend-demo-optimized/MOTION_CONTRACT.md` §3 Motion Tokens
/// 平台映射：`docs/ui-handoff/MOTION_PLATFORM_MAPPING.md` §1 共享 Token 命名（iOS SwiftUI 列）
///
/// 这里只承载契约 token 的数值语义，不复制 Web CSS / DOM / `data-*` selector。
/// 平台实现用这些 token 驱动 `withAnimation` / `transition` / `ButtonStyle`。
public enum AppMotion {

    /// `app.motion.duration.*` —— 时长（秒）。
    public enum Duration {
        /// `app.motion.duration.firstOpen` = 280ms。冷启动首屏进入。
        public static let firstOpen: TimeInterval = 0.28
        /// `app.motion.duration.tabPress` = 80ms。TAB 按下/取消按下反馈。
        public static let tabPress: TimeInterval = 0.08
        /// `app.motion.duration.tabSelect` = 120ms。单 TAB 进入/退出选中态。
        public static let tabSelect: TimeInterval = 0.12
        /// `app.motion.duration.tabSwitch` = 160ms。TAB A -> B 切换。
        public static let tabSwitch: TimeInterval = 0.16
        /// `app.motion.duration.buttonPress` = 80ms。
        public static let buttonPress: TimeInterval = 0.08
        /// `app.motion.duration.buttonActivate` = 120ms。
        public static let buttonActivate: TimeInterval = 0.12
        /// `app.motion.duration.toggleSwitch` = 140ms。
        public static let toggleSwitch: TimeInterval = 0.14
        /// `app.motion.duration.chipSelect` = 120ms。
        public static let chipSelect: TimeInterval = 0.12
        /// `app.motion.duration.segmentItemSwitch` = 120ms（对照 MotionId.segmentItemSwitch，主题/分段切换）。
        public static let segmentItemSwitch: TimeInterval = 0.12
        /// `app.motion.duration.filterCommit` = 160ms。
        public static let filterCommit: TimeInterval = 0.16
        /// `app.motion.duration.numericCommit` = 120ms。
        public static let numericCommit: TimeInterval = 0.12
        /// `app.motion.duration.inputFocus` = 120ms。
        public static let inputFocus: TimeInterval = 0.12
        /// `app.motion.duration.searchState` = 160ms。
        public static let searchState: TimeInterval = 0.16
        /// `app.motion.duration.feedbackToast` = 180ms。
        public static let feedbackToast: TimeInterval = 0.18
        /// `app.motion.duration.stateReplace` = 160ms。
        public static let stateReplace: TimeInterval = 0.16
        /// `app.motion.duration.selectionToolbar` = 160ms。
        public static let selectionToolbar: TimeInterval = 0.16
        /// `app.motion.duration.dropdownPress` = 80ms。
        public static let dropdownPress: TimeInterval = 0.08
        /// `app.motion.duration.dropdownExpand` = 160ms。
        public static let dropdownExpand: TimeInterval = 0.16
        /// `app.motion.duration.dropdownCollapse` = 120ms。
        public static let dropdownCollapse: TimeInterval = 0.12
        /// `app.motion.duration.dropdownSelect` = 120ms。
        public static let dropdownSelect: TimeInterval = 0.12
    }

    /// `app.motion.distance.*` —— 位移（pt）。
    public enum Distance {
        /// `app.motion.distance.dropdownY` = 6pt。
        public static let dropdownY: CGFloat = 6
        /// `app.motion.distance.firstOpenY` = 8pt。冷启动首屏进入轻位移。
        public static let firstOpenY: CGFloat = 8
        /// `app.motion.distance.feedbackY` = 8pt。
        public static let feedbackY: CGFloat = 8
        /// `app.motion.distance.selectionToolbarY` = 6pt。
        public static let selectionToolbarY: CGFloat = 6
    }

    /// `app.motion.scale.*` —— 按压缩放上限。
    public enum Scale {
        /// `app.motion.scale.press` = 1 -> 0.98 -> 1。取按压最低值。
        public static let pressMin: CGFloat = 0.98
    }
}
