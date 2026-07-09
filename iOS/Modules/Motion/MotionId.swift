import Foundation

/// 动效 ID 枚举。
///
/// 真源：`frontend-demo-optimized/motion-controller.js` 第 292-622 行 `MOTION_ID_STATE_MACHINES`，共 47 个 Motion ID。
/// 本枚举只承载契约 ID 的字符串语义，不复制 Web DOM / `data-*` selector；
/// 每个 case 的 rawValue 与 demo 中的字符串 ID 完全一致，便于跨端对照与样本回溯。
public enum MotionId: String, CaseIterable, Sendable {

    // MARK: - app family（app 级 UI 与路由）

    /// `app.firstOpen.enter`（demo line 293）
    case appFirstOpenEnter = "app.firstOpen.enter"
    /// `app.route.push.forward`（demo line 300）
    case appRoutePushForward = "app.route.push.forward"
    /// `app.route.pop.backward`（demo line 307）
    case appRoutePopBackward = "app.route.pop.backward"
    /// `app.route.replace`（demo line 314）
    case appRouteReplace = "app.route.replace"
    /// `tab.item.press`（demo line 321）
    case tabItemPress = "tab.item.press"
    /// `tab.item.select`（demo line 328）
    case tabItemSelect = "tab.item.select"
    /// `tab.item.switch`（demo line 335）
    case tabItemSwitch = "tab.item.switch"
    /// `segment.item.switch`（demo line 342）
    case segmentItemSwitch = "segment.item.switch"
    /// `dropdown.trigger.press`（demo line 349）
    case dropdownTriggerPress = "dropdown.trigger.press"
    /// `dropdown.menu.expand`（demo line 356）
    case dropdownMenuExpand = "dropdown.menu.expand"
    /// `dropdown.menu.expand/collapse`（demo line 363）
    case dropdownMenuExpandCollapse = "dropdown.menu.expand/collapse"
    /// `dropdown.menu.collapse`（demo line 370）
    case dropdownMenuCollapse = "dropdown.menu.collapse"
    /// `dropdown.menu.reposition`（demo line 377）
    case dropdownMenuReposition = "dropdown.menu.reposition"
    /// `dropdown.option.press`（demo line 384）
    case dropdownOptionPress = "dropdown.option.press"
    /// `dropdown.option.select`（demo line 391）
    case dropdownOptionSelect = "dropdown.option.select"
    /// `button.activate`（demo line 398）
    case buttonActivate = "button.activate"
    /// `toggle.switch`（demo line 405）
    case toggleSwitch = "toggle.switch"

    // MARK: - reader family（阅读器主链路与运行会话）

    /// `reader.entry.coverToImmersive`（demo line 412）
    case readerEntryCoverToImmersive = "reader.entry.coverToImmersive"
    /// `reader.entry.actionToImmersive`（demo line 419）
    case readerEntryActionToImmersive = "reader.entry.actionToImmersive"
    /// `reader.control.hide`（demo line 426）
    case readerControlHide = "reader.control.hide"
    /// `reader.control.handle.press`（demo line 433）
    case readerControlHandlePress = "reader.control.handle.press"
    /// `reader.control.handle.drag`（demo line 440）
    case readerControlHandleDrag = "reader.control.handle.drag"
    /// `reader.control.handle.release`（demo line 447）
    case readerControlHandleRelease = "reader.control.handle.release"
    /// `reader.control.dock.longPress`（demo line 454）
    case readerControlDockLongPress = "reader.control.dock.longPress"
    /// `reader.control.dock.drag`（demo line 461）
    case readerControlDockDrag = "reader.control.dock.drag"
    /// `reader.control.dock.release`（demo line 468）
    case readerControlDockRelease = "reader.control.dock.release"
    /// `reader.control.dock.rebound`（demo line 475）
    case readerControlDockRebound = "reader.control.dock.rebound"
    /// `reader.session.autoPage.start`（demo line 482）
    case readerSessionAutoPageStart = "reader.session.autoPage.start"
    /// `reader.session.tts.start`（demo line 489）
    case readerSessionTtsStart = "reader.session.tts.start"
    /// `reader.session.capsule.enter`（demo line 496）
    case readerSessionCapsuleEnter = "reader.session.capsule.enter"
    /// `reader.session.capsule.update`（demo line 503）
    case readerSessionCapsuleUpdate = "reader.session.capsule.update"
    /// `reader.session.capsule.control.press/toggle`（demo line 510）
    case readerSessionCapsuleControlPressToggle = "reader.session.capsule.control.press/toggle"
    /// `reader.session.capsule.countdownTick`（demo line 517）
    case readerSessionCapsuleCountdownTick = "reader.session.capsule.countdownTick"
    /// `reader.session.capsule.voiceIcon.active`（demo line 524）
    case readerSessionCapsuleVoiceIconActive = "reader.session.capsule.voiceIcon.active"
    /// `reader.session.capsule.switch`（demo line 531）
    case readerSessionCapsuleSwitch = "reader.session.capsule.switch"
    /// `reader.session.capsule.exit`（demo line 538）
    case readerSessionCapsuleExit = "reader.session.capsule.exit"
    /// `reader.session.controlSpace.enter`（demo line 545）
    case readerSessionControlSpaceEnter = "reader.session.controlSpace.enter"
    /// `reader.session.controlSpace.update`（demo line 552）
    case readerSessionControlSpaceUpdate = "reader.session.controlSpace.update"
    /// `reader.session.controlSpace.exit`（demo line 559）
    case readerSessionControlSpaceExit = "reader.session.controlSpace.exit"
    /// `reader.module.switch`（demo line 566）
    case readerModuleSwitch = "reader.module.switch"
    /// `reader.page.turn.next/prev`（demo line 573）
    case readerPageTurnNextPrev = "reader.page.turn.next/prev"
    /// `motion.interrupt.cancel`（demo line 580）
    case motionInterruptCancel = "motion.interrupt.cancel"
    /// `motion.interrupt.redirect`（demo line 587）
    case motionInterruptRedirect = "motion.interrupt.redirect"
    /// `motion.interrupt.completeThenReplace`（demo line 594）
    case motionInterruptCompleteThenReplace = "motion.interrupt.completeThenReplace"

    // MARK: - viewport family（视口 / 方向 / 折叠屏重排）

    /// `viewport.orientation.prepare`（demo line 601）
    case viewportOrientationPrepare = "viewport.orientation.prepare"
    /// `viewport.orientation.reshape`（demo line 608）
    case viewportOrientationReshape = "viewport.orientation.reshape"
    /// `viewport.orientation.settle`（demo line 615）
    case viewportOrientationSettle = "viewport.orientation.settle"

    /// 所属 family（app / reader / viewport）。
    ///
    /// 对照 demo `CONTRACT_RULES`（line 624-1073）的 prefix → family 映射，
    /// 将 33 个细粒度 family 归并为三大类，与 `AppMotion` / `ReaderMotion` /
    /// viewport token adapter 的分层一致，便于 iOS 端分层管理。
    public var family: MotionFamily {
        switch self {
        // app family：app.* / tab.* / segment.* / dropdown.* / button.* / toggle.*
        case .appFirstOpenEnter,
             .appRoutePushForward, .appRoutePopBackward, .appRouteReplace,
             .tabItemPress, .tabItemSelect, .tabItemSwitch,
             .segmentItemSwitch,
             .dropdownTriggerPress, .dropdownMenuExpand, .dropdownMenuExpandCollapse,
             .dropdownMenuCollapse, .dropdownMenuReposition,
             .dropdownOptionPress, .dropdownOptionSelect,
             .buttonActivate, .toggleSwitch:
            return .app
        // reader family：reader.* / motion.interrupt.*
        case .readerEntryCoverToImmersive, .readerEntryActionToImmersive,
             .readerControlHide,
             .readerControlHandlePress, .readerControlHandleDrag, .readerControlHandleRelease,
             .readerControlDockLongPress, .readerControlDockDrag,
             .readerControlDockRelease, .readerControlDockRebound,
             .readerSessionAutoPageStart, .readerSessionTtsStart,
             .readerSessionCapsuleEnter, .readerSessionCapsuleUpdate,
             .readerSessionCapsuleControlPressToggle, .readerSessionCapsuleCountdownTick,
             .readerSessionCapsuleVoiceIconActive, .readerSessionCapsuleSwitch,
             .readerSessionCapsuleExit,
             .readerSessionControlSpaceEnter, .readerSessionControlSpaceUpdate,
             .readerSessionControlSpaceExit,
             .readerModuleSwitch, .readerPageTurnNextPrev,
             .motionInterruptCancel, .motionInterruptRedirect,
             .motionInterruptCompleteThenReplace:
            return .reader
        // viewport family：viewport.*
        case .viewportOrientationPrepare, .viewportOrientationReshape, .viewportOrientationSettle:
            return .viewport
        }
    }
}

/// 动效大类。
///
/// 对照 demo `CONTRACT_RULES`（line 624-1073）的 33 个细粒度 family，
/// 在 iOS 端归并为三大类：app / reader / viewport，
/// 与 `AppMotion` / `ReaderMotion` / viewport token adapter 的分层一致。
public enum MotionFamily: String, Sendable {
    case app
    case reader
    case viewport
}
