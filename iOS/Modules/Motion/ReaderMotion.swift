import Foundation
import CoreGraphics
import SwiftUI

/// Reader 级动效 token adapter。
///
/// 真源：Reader UI `frontend-demo/MOTION_CONTRACT.md` §3 Motion Tokens
/// 平台映射：`docs/ui-handoff/MOTION_PLATFORM_MAPPING.md` §1 共享 Token 命名（iOS SwiftUI 列）
///
/// 与 `AppMotion` 一样，只承载契约 token 的数值语义，不复制 Web CSS / DOM / `data-*` selector。
public enum ReaderMotion {

    /// `reader.motion.duration.*` —— 时长（秒）。
    public enum Duration {
        /// `reader.motion.duration.instant` = 0ms。reduced motion / 纯状态切换。
        public static let instant: TimeInterval = 0
        /// `reader.motion.duration.micro` = 80ms。按压反馈、选中态轻反馈。
        public static let micro: TimeInterval = 0.08
        /// `reader.motion.duration.fast` = 120ms。主 Tab 选中、小 chip/toggle。
        public static let fast: TimeInterval = 0.12
        /// `reader.motion.duration.base` = 160ms。键盘、底表、弹窗、焦点上浮。
        public static let base: TimeInterval = 0.16
        /// `reader.motion.duration.handleLongPress` = 320ms。宽屏控制层小横条长按进入拖动。
        public static let handleLongPress: TimeInterval = 0.32
        /// `reader.motion.duration.handleSnap` = 120ms。小横条释放吸附/回弹。
        public static let handleSnap: TimeInterval = 0.12
        /// `reader.motion.duration.panel` = 200ms。阅读模块面板/展开式控制面板进入。
        public static let panel: TimeInterval = 0.20
        /// `reader.motion.duration.pageTurn` = 220ms。阅读翻页。
        public static let pageTurn: TimeInterval = 0.22
        /// `reader.motion.duration.readerEntry` = 240ms。书架封面/继续阅读进入沉浸阅读。
        public static let readerEntry: TimeInterval = 0.24
        /// `reader.motion.duration.sessionReturn` = 200ms。自动翻页/朗读开启后回到沉浸阅读。
        public static let sessionReturn: TimeInterval = 0.20
        /// `reader.motion.duration.runningSpace` = 180ms。运行胶囊与控制层运行中空间停靠/展开。
        public static let runningSpace: TimeInterval = 0.18
        /// `reader.motion.duration.capsuleEnter` = 160ms。运行胶囊进入/退出/类型切换。
        public static let capsuleEnter: TimeInterval = 0.16
        /// `reader.motion.duration.capsuleControl` = 120ms。控制胶囊暂停/继续按钮。
        public static let capsuleControl: TimeInterval = 0.12
        /// `reader.motion.duration.capsuleTick` = 120ms。自动翻页倒计时数字变化。
        public static let capsuleTick: TimeInterval = 0.12
        /// `reader.motion.duration.voicePulse` = 960ms。朗读语音图标低频活动提示。
        public static let voicePulse: TimeInterval = 0.96
        /// `reader.motion.duration.overlay` = 240ms。弹窗背景、换源窗口、路由级覆盖层组合。
        public static let overlay: TimeInterval = 0.24
        /// `reader.motion.duration.loadingSpin` = 800ms。行内加载 spinner 单圈时长。
        public static let loadingSpin: TimeInterval = 0.80
        /// `reader.motion.duration.interruptSettle` = 80ms。动画被打断后的收尾/接管。
        public static let interruptSettle: TimeInterval = 0.08
        /// `reader.motion.duration.viewportReshape` = 240ms。折叠屏/横竖屏/大屏断点重排。
        public static let viewportReshape: TimeInterval = 0.24
        /// `reader.motion.duration.orientationFreeze` = 80ms。整屏旋转开始冻结旧动画。
        public static let orientationFreeze: TimeInterval = 0.08
        /// `reader.motion.duration.orientationSettle` = 240ms。整屏旋转后容器/overlay/控制层落位。
        public static let orientationSettle: TimeInterval = 0.24
    }

    /// `reader.motion.distance.*` —— 位移（pt）。
    public enum Distance {
        /// `reader.motion.distance.pageTurnX` = 16pt。
        public static let pageTurnX: CGFloat = 16
        /// `reader.motion.distance.focusY` = -1pt。设置/书源焦点面板上浮。
        public static let focusY: CGFloat = -1
        /// `reader.motion.distance.readerEntryY` = 12pt。沉浸阅读正文进入轻位移。
        public static let readerEntryY: CGFloat = 12
        /// `reader.motion.distance.controlDragMargin` = 16pt。宽屏控制层距安全边界最小间距。
        public static let controlDragMargin: CGFloat = 16
        /// `reader.motion.distance.handlePullY` = 18pt。小横条低幅拖拽预览距离。
        public static let handlePullY: CGFloat = 18
        /// `reader.motion.distance.runningSpaceY` = 10pt。控制层运行中空间进入/退出轻位移。
        public static let runningSpaceY: CGFloat = 10
        /// `reader.motion.distance.orientationPanelY` = 10pt。整屏旋转后控制层/overlay 重锚定轻位移上限。
        public static let orientationPanelY: CGFloat = 10
        /// `reader.motion.distance.capsuleY` = 6pt。运行胶囊进入/退出轻位移。
        public static let capsuleY: CGFloat = 6
        /// `reader.motion.distance.capsuleTickY` = 4pt。倒计时数字替换内部位移。
        public static let capsuleTickY: CGFloat = 4
    }

    /// `reader.motion.scale.*` —— 缩放。
    public enum Scale {
        /// `reader.motion.scale.dialogEnter` = 0.96 -> 1。取进入起始值。
        public static let dialogEnterStart: CGFloat = 0.96
        /// `reader.motion.scale.coverPress` = 0.98。封面按压反馈。
        public static let coverPress: CGFloat = 0.98
        /// `reader.motion.scale.capsuleEnter` = 0.96 -> 1。取起始值。
        public static let capsuleEnterStart: CGFloat = 0.96
        /// `reader.motion.scale.capsuleControlPress` = 1 -> 0.90 -> 1。取按压最低值。
        public static let capsuleControlPressMin: CGFloat = 0.90
        /// `reader.motion.scale.runningSpaceDock` = 0.92 -> 1。取起始值。
        public static let runningSpaceDockStart: CGFloat = 0.92
        /// `reader.motion.scale.voicePulse` = 1 -> 1.06 -> 1。取活动峰值。
        public static let voicePulseMax: CGFloat = 1.06
    }

    /// `reader.motion.easing.*` —— 契约 easing 语义，映射到 SwiftUI 原生曲线。
    public enum Easing {
        /// `reader.motion.easing.standard` = ease。
        public static let standard = Animation.easeInOut(duration: ReaderMotion.Duration.base)
        /// `reader.motion.easing.exit` = ease-in。
        public static let exit = Animation.easeIn(duration: ReaderMotion.Duration.base)
        /// `reader.motion.easing.enter` = ease-out。
        public static let enter = Animation.easeOut(duration: ReaderMotion.Duration.base)
        /// `reader.motion.easing.reshape` = ease-in-out。
        public static let reshape = Animation.easeInOut(duration: ReaderMotion.Duration.viewportReshape)
    }
}
