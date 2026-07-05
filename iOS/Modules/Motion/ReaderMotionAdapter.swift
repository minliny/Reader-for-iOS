import SwiftUI
import ReaderUIContract

/// Adapter from generated Reader UI motion contracts to native SwiftUI motion.
public enum ReaderMotionAdapter {
    public static func spec(for contractId: ReaderUIContract.MotionId) -> ReaderUIContract.Motion? {
        ReaderUIContract.MotionSpecRegistry.spec(for: contractId)
    }

    public static func localMotionId(for contractId: ReaderUIContract.MotionId) -> MotionId? {
        switch contractId {
        case .app_firstOpen_enter:
            return .appFirstOpenEnter
        case .app_route_push_forward:
            return .appRoutePushForward
        case .app_route_pop_backward:
            return .appRoutePopBackward
        case .app_route_replace:
            return .appRouteReplace
        case .tab_item_select:
            return .tabItemSelect
        case .tab_switch:
            return .tabItemSwitch
        case .reader_entry_coverToImmersive:
            return .readerEntryCoverToImmersive
        case .reader_entry_actionToImmersive:
            return .readerEntryActionToImmersive
        case .reader_control_hide:
            return .readerControlHide
        case .reader_control_handle_press:
            return .readerControlHandlePress
        case .reader_control_handle_release:
            return .readerControlHandleRelease
        case .reader_control_dock_longPress:
            return .readerControlDockLongPress
        case .reader_control_dock_drag:
            return .readerControlDockDrag
        case .reader_control_dock_release:
            return .readerControlDockRelease
        case .reader_control_dock_rebound:
            return .readerControlDockRebound
        case .reader_module_switch:
            return .readerModuleSwitch
        case .reader_page_turn_next_prev:
            return .readerPageTurnNextPrev
        case .reader_session_autoPage_start:
            return .readerSessionAutoPageStart
        case .reader_session_tts_start:
            return .readerSessionTtsStart
        case .reader_session_capsule_enter:
            return .readerSessionCapsuleEnter
        case .reader_session_capsule_update:
            return .readerSessionCapsuleUpdate
        case .reader_session_capsule_exit:
            return .readerSessionCapsuleExit
        case .reader_session_capsule_switch:
            return .readerSessionCapsuleSwitch
        case .reader_session_controlSpace_enter:
            return .readerSessionControlSpaceEnter
        case .reader_session_controlSpace_update:
            return .readerSessionControlSpaceUpdate
        case .reader_session_controlSpace_exit:
            return .readerSessionControlSpaceExit
        case .motion_interrupt_cancel:
            return .motionInterruptCancel
        case .motion_interrupt_redirect:
            return .motionInterruptRedirect
        case .motion_interrupt_completeThenReplace:
            return .motionInterruptCompleteThenReplace
        case .viewport_orientation_prepare:
            return .viewportOrientationPrepare
        case .viewport_orientation_reshape:
            return .viewportOrientationReshape
        case .viewport_orientation_settle:
            return .viewportOrientationSettle
        default:
            return nil
        }
    }

    public static func duration(for contractId: ReaderUIContract.MotionId, motion: MotionEnvironment = .shared) -> TimeInterval {
        guard let spec = spec(for: contractId) else {
            return motion.duration(baseDuration(for: contractId))
        }
        if motion.isReducedMotionEnabled, spec.reducedMotion?.forceZeroDuration == true {
            return ReaderMotion.Duration.instant
        }
        return motion.duration(TimeInterval(spec.durationMs) / 1000)
    }

    public static func animation(for contractId: ReaderUIContract.MotionId, motion: MotionEnvironment = .shared) -> Animation? {
        let seconds = duration(for: contractId, motion: motion)
        guard seconds > 0 else { return nil }
        return .easeInOut(duration: seconds)
    }

    @discardableResult
    @MainActor
    public static func start(
        _ contractId: ReaderUIContract.MotionId,
        from fromState: String,
        to toState: String,
        interruptMode: MotionInterruptMode = .redirect,
        finalState: String,
        controller: MotionController = .shared,
        motion: MotionEnvironment = .shared
    ) -> UUID? {
        guard let localId = localMotionId(for: contractId) else { return nil }
        return controller.start(
            id: localId,
            fromState: fromState,
            toState: toState,
            interruptMode: interruptMode,
            finalState: finalState,
            durationSeconds: duration(for: contractId, motion: motion)
        )
    }

    private static func baseDuration(for contractId: ReaderUIContract.MotionId) -> TimeInterval {
        switch contractId {
        case .app_firstOpen_enter:
            return AppMotion.Duration.firstOpen
        case .tab_item_select:
            return AppMotion.Duration.tabSelect
        case .tab_switch:
            return AppMotion.Duration.tabSwitch
        case .bookshelf_view_switch, .app_route_replace:
            return AppMotion.Duration.stateReplace
        case .app_route_push_forward, .app_route_pop_backward, .reader_module_switch:
            return ReaderMotion.Duration.panel
        case .reader_entry_coverToImmersive, .reader_entry_actionToImmersive:
            return ReaderMotion.Duration.readerEntry
        case .reader_page_turn_next_prev, .reader_chapter_jump:
            return ReaderMotion.Duration.pageTurn
        case .reader_control_handle_press, .reader_control_dock_longPress:
            return ReaderMotion.Duration.handleLongPress
        case .reader_control_handle_release, .reader_control_dock_release, .reader_control_dock_rebound:
            return ReaderMotion.Duration.handleSnap
        case .reader_control_dock_drag:
            return ReaderMotion.Duration.instant
        case .reader_control_hide,
             .reader_sourceSwitch_open_close,
             .overlay_sheet_enter,
             .overlay_sheet_exit,
             .overlay_dialog_enter,
             .overlay_dialog_exit,
             .overlay_keyboard_enter_exit:
            return ReaderMotion.Duration.overlay
        case .reader_session_capsule_enter,
             .reader_session_capsule_update,
             .reader_session_capsule_exit,
             .reader_session_capsule_switch:
            return ReaderMotion.Duration.capsuleEnter
        case .reader_session_controlSpace_enter, .reader_session_controlSpace_exit:
            return ReaderMotion.Duration.runningSpace
        case .reader_session_tts_start, .reader_session_autoPage_start:
            return ReaderMotion.Duration.capsuleEnter
        case .motion_interrupt_cancel,
             .motion_interrupt_redirect,
             .motion_interrupt_completeThenReplace:
            return ReaderMotion.Duration.interruptSettle
        case .viewport_orientation_prepare:
            return ReaderMotion.Duration.orientationFreeze
        case .viewport_orientation_reshape:
            return ReaderMotion.Duration.viewportReshape
        case .viewport_orientation_settle:
            return ReaderMotion.Duration.orientationSettle
        case .state_loading_inline:
            return ReaderMotion.Duration.loadingSpin
        case .feedback_toast_enter, .feedback_toast_exit:
            return AppMotion.Duration.feedbackToast
        default:
            return ReaderMotion.Duration.base
        }
    }
}
