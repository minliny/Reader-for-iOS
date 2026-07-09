import SwiftUI

/// 沉浸阅读运行胶囊视图。
///
/// 实现 demo 契约 `frontend-demo-optimized/motion-controller.js` 中两个 Motion ID 的 SwiftUI 运行时
/// （clean-room：不复制 Web JS/CSS/DOM，只用 demo 数值化 token 驱动 SwiftUI 原生
/// `animation` / `transition` / `scaleEffect` / `opacity`）。
///
/// - `reader.session.capsule.countdownTick`（motion-controller.js line 517-523）
///   duration 120ms，from `countdown.previous` → to `countdown.next`，
///   finalState `latestCountdownVisibleInFixedWidthSlot`。
///   旧数字向上移出 + 淡出，新数字从上方移入 + 淡入；等宽 tabular number + 固定宽度
///   槽位避免数字变化导致宽度抖动。reduced motion 下 `MotionEnvironment.animation`
///   返回 nil，`.animation(_:value:)` 自动降级为即时替换。
///
/// - `reader.session.capsule.voiceIcon.active`（motion-controller.js line 524-530）
///   duration 960ms `repeatForever(autoreverses: true)`，
///   scale 1 → 1.06 → 1，opacity 0.82 → 1 → 0.82，
///   finalState `voiceIconActiveOnlyWhilePlaying`。
///   暂停/退出时取消动画；reduced motion 时图标静态保留播放语义。
public struct ReaderSessionCapsuleView: View {
    private let session: ReaderSession
    private let countdown: Int
    private let onPauseResume: () -> Void
    private let onStop: () -> Void
    private let motionEnvironment: MotionEnvironment

    /// TTS 朗读图标脉动开关。true 时 scale 1.06 / opacity 1.0，false 时 scale 1.0 / opacity 0.82。
    @State private var voicePulse = false

    public init(
        session: ReaderSession,
        countdown: Int,
        onPauseResume: @escaping () -> Void,
        onStop: @escaping () -> Void,
        motionEnvironment: MotionEnvironment = .shared
    ) {
        self.session = session
        self.countdown = countdown
        self.onPauseResume = onPauseResume
        self.onStop = onStop
        self.motionEnvironment = motionEnvironment
    }

    public var body: some View {
        HStack(spacing: 8) {
            sessionIcon
            centerContent
            Spacer(minLength: 0)
            controlButtons
        }
        .padding(.horizontal, 12)
        .frame(height: ReaderDesignTokens.readerSessionCapsuleHeight)
        .background(
            Capsule()
                .fill(ReaderDesignTokens.Color.controlBackground)
        )
        .readerShadow(ReaderDesignTokens.Shadow.soft)
        .onAppear { startVoicePulseIfNeeded() }
        .onChange(of: session.isPlaying) { isPlaying in
            handlePlayingChange(isPlaying)
        }
    }

    // MARK: - 子视图

    @ViewBuilder
    private var sessionIcon: some View {
        switch session {
        case .tts:
            // 朗读图标：播放时应用 960ms 脉动（scale 1↔1.06，opacity 0.82↔1）。
            ReaderIcon(.tts, size: ReaderDesignTokens.readerSessionCapsuleIconSize, accessibilityLabel: "朗读")
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
                .scaleEffect(voicePulse ? ReaderMotion.Scale.voicePulseMax : 1.0)
                .opacity(voicePulse ? 1.0 : 0.82)
        case .autoPage:
            ReaderIcon(.autoPage, size: ReaderDesignTokens.readerSessionCapsuleIconSize, accessibilityLabel: "自动翻页")
                .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var centerContent: some View {
        switch session {
        case .autoPage:
            // 倒计时数字：等宽 tabular number + 固定宽度槽位避免抖动。
            // .id(countdown) 触发 transition；motionEnvironment.animation 在 reduced
            // motion 下返回 nil，.animation(_:value:) 自动降级为即时替换。
            Text("\(countdown)")
                .font(.system(size: ReaderDesignTokens.readerSessionCapsuleCountdownSize, weight: .black).monospacedDigit())
                .foregroundColor(ReaderDesignTokens.Color.ink)
                .frame(width: ReaderDesignTokens.readerSessionCapsuleCountdownSize + 10)
                .id(countdown)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(
                    ReaderMotionAdapter.animation(
                        for: MotionRequest(operation: .update, containerRole: .sessionCapsule),
                        motion: motionEnvironment
                    ),
                    value: countdown
                )
        case .tts:
            Text("朗读中")
                .font(.system(size: ReaderDesignTokens.readerModuleFontSize, weight: .black))
                .foregroundColor(ReaderDesignTokens.Color.ink)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var controlButtons: some View {
        Button(action: onPauseResume) {
            ReaderIcon(
                session.isPlaying ? ReaderAssetIcon.pause : ReaderAssetIcon.play,
                size: ReaderDesignTokens.readerSessionCapsuleIconSize,
                accessibilityLabel: session.isPlaying ? "暂停" : "继续"
            )
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        }
        .buttonStyle(.plain)

        Button(action: onStop) {
            ReaderIcon(
                ReaderAssetIcon.stop,
                size: ReaderDesignTokens.readerSessionCapsuleIconSize,
                accessibilityLabel: "停止"
            )
            .foregroundColor(ReaderDesignTokens.Color.primaryDark)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Voice pulse（reader.session.capsule.voiceIcon.active）

    private func startVoicePulseIfNeeded() {
        guard !motionEnvironment.isReducedMotionEnabled else { return }
        guard session.isPlaying else { return }
        startVoicePulse()
    }

    private func handlePlayingChange(_ isPlaying: Bool) {
        guard !motionEnvironment.isReducedMotionEnabled else {
            voicePulse = false
            return
        }
        if isPlaying {
            startVoicePulse()
        } else {
            // 暂停/退出：不包 withAnimation 直接写回，打断 repeatForever 周期，
            // 图标回到 scale 1.0 / opacity 0.82 静止态。
            voicePulse = false
        }
    }

    private func startVoicePulse() {
        // voice pulse 走 resolver：spec=reader.session.capsule.voiceIcon.active，
        // loop={forever:true, autoreverses:true}，easing=linear，duration=960ms。
        // reduced-motion 下 adapter 返回 nil，voicePulse 仍被设为 true（静态保留语义）。
        withAnimation(
            ReaderMotionAdapter.animation(for: .reader_session_capsule_voiceIcon_active, motion: motionEnvironment)
        ) {
            voicePulse = true
        }
    }
}

// MARK: - ReaderSession 便利属性

private extension ReaderSession {
    /// 是否处于播放态（autoPage/tts 的 playing 标记；.none 视为非播放）。
    var isPlaying: Bool {
        switch self {
        case .autoPage(let playing), .tts(let playing):
            return playing
        case .none:
            return false
        }
    }
}
