import Foundation
import ReaderUIContract

// MARK: - ReaderUiStateBinding
//
// 为 `UiState` 的弱类型子状态建强类型 struct。
// 手写 Codable 把 `[String: AnyCodable]` 解码为强类型。
//
// 真源：
// - `generated/swift/UiState.swift` UiState（reader 子状态是 `[String: AnyCodable]?`）
// - `frontend-demo-optimized/MOTION_CONTRACT.md` §4 reader.session.* / reader.control.*
// - `iOS/Modules/Reader/ReaderUiState.swift` 本地 enum（loading/empty/error/offline/permission）
//
// 设计：
// - 现有 `ReaderUiState.swift` 是简单的状态页 enum，不含 TTS/control/typography 子状态
// - 本文件定义 reader 深层子状态的强类型 struct，供 ViewState 驱动的 reader view 消费

// MARK: - ReaderTtsState（TTS 朗读状态）

/// TTS 朗读状态快照。
public struct ReaderTtsState: Equatable {
    public let playing: Bool
    public let sentenceIndex: Int
    public let speed: Double       // 0.5 - 3.0
    public let voice: String?      // 语音引擎标识
    public let scope: String       // "chapter" | "paragraph" | "sentence"
    public let timer: Double?      // 定时关闭（秒），nil = 不定时

    public init(
        playing: Bool = false,
        sentenceIndex: Int = 0,
        speed: Double = 1.0,
        voice: String? = nil,
        scope: String = "chapter",
        timer: Double? = nil
    ) {
        self.playing = playing
        self.sentenceIndex = sentenceIndex
        self.speed = speed
        self.voice = voice
        self.scope = scope
        self.timer = timer
    }

    public init?(props: [String: AnyCodable]?) {
        guard let props else { return nil }
        self.playing = props.bool("playing") ?? false
        self.sentenceIndex = props.int("sentenceIndex") ?? 0
        self.speed = props.double("speed") ?? 1.0
        self.voice = props.string("voice")
        self.scope = props.string("scope") ?? "chapter"
        self.timer = props.double("timer")
    }
}

// MARK: - ReaderControlSettings（阅读控制设置）

/// 阅读控制设置快照。
public struct ReaderControlSettings: Equatable {
    public let autoPage: Bool
    public let tapMode: String         // "center" | "leftRight" | "off"
    public let volumePage: Bool        // 音量键翻页
    public let pageMode: String        // "paginated" | "scroll"
    public let pageAnimation: String   // "slide" | "fade" | "none"
    public let landscapeLock: Bool
    public let keepScreenOn: Bool
    public let statusInfo: Bool        // 显示状态信息
    public let hapticFeedback: Bool
    public let cacheNext: Bool         // 预缓存下一章

    public init(
        autoPage: Bool = false,
        tapMode: String = "leftRight",
        volumePage: Bool = false,
        pageMode: String = "paginated",
        pageAnimation: String = "slide",
        landscapeLock: Bool = false,
        keepScreenOn: Bool = true,
        statusInfo: Bool = false,
        hapticFeedback: Bool = true,
        cacheNext: Bool = true
    ) {
        self.autoPage = autoPage
        self.tapMode = tapMode
        self.volumePage = volumePage
        self.pageMode = pageMode
        self.pageAnimation = pageAnimation
        self.landscapeLock = landscapeLock
        self.keepScreenOn = keepScreenOn
        self.statusInfo = statusInfo
        self.hapticFeedback = hapticFeedback
        self.cacheNext = cacheNext
    }

    public init?(props: [String: AnyCodable]?) {
        guard let props else { return nil }
        self.autoPage = props.bool("autoPage") ?? false
        self.tapMode = props.string("tapMode") ?? "leftRight"
        self.volumePage = props.bool("volumePage") ?? false
        self.pageMode = props.string("pageMode") ?? "paginated"
        self.pageAnimation = props.string("pageAnimation") ?? "slide"
        self.landscapeLock = props.bool("landscapeLock") ?? false
        self.keepScreenOn = props.bool("keepScreenOn") ?? true
        self.statusInfo = props.bool("statusInfo") ?? false
        self.hapticFeedback = props.bool("hapticFeedback") ?? true
        self.cacheNext = props.bool("cacheNext") ?? true
    }
}

// MARK: - ReaderTypographyState（排版状态）

/// 阅读排版状态快照。
public struct ReaderTypographyState: Equatable {
    public let fontSize: Double        // 14-26
    public let lineHeight: Double      // 1.4-2.4
    public let paragraphSpacing: Double  // 4-32
    public let letterSpacing: Double   // 0-2

    public init(
        fontSize: Double = 18,
        lineHeight: Double = 1.8,
        paragraphSpacing: Double = 16,
        letterSpacing: Double = 0
    ) {
        self.fontSize = fontSize
        self.lineHeight = lineHeight
        self.paragraphSpacing = paragraphSpacing
        self.letterSpacing = letterSpacing
    }

    public init?(props: [String: AnyCodable]?) {
        guard let props else { return nil }
        self.fontSize = props.double("fontSize") ?? 18
        self.lineHeight = props.double("lineHeight") ?? 1.8
        self.paragraphSpacing = props.double("paragraphSpacing") ?? 16
        self.letterSpacing = props.double("letterSpacing") ?? 0
    }

    /// 转为 `ReaderTypographyConfig`（供 `ReaderTextPaginator` 使用）。
    public var paginatorConfig: ReaderTypographyConfig {
        ReaderTypographyConfig(
            fontSize: fontSize,
            lineHeight: lineHeight,
            paragraphSpacing: paragraphSpacing,
            letterSpacing: letterSpacing
        )
    }
}

// MARK: - ReaderSessionCapsuleSnapshot（会话胶囊快照）

/// 会话胶囊状态快照（TTS / 自动翻页运行时的胶囊 UI 状态）。
public struct ReaderSessionCapsuleSnapshot: Equatable {
    public let sessionType: String  // "tts" | "autoPage"
    public let playing: Bool
    public let title: String        // 书名
    public let chapterTitle: String?
    public let progress: Double     // 0.0 - 1.0
    public let remainingTime: Double?  // 剩余时间（秒），nil = 未知

    public init(
        sessionType: String = "tts",
        playing: Bool = false,
        title: String = "",
        chapterTitle: String? = nil,
        progress: Double = 0,
        remainingTime: Double? = nil
    ) {
        self.sessionType = sessionType
        self.playing = playing
        self.title = title
        self.chapterTitle = chapterTitle
        self.progress = progress
        self.remainingTime = remainingTime
    }

    public init?(props: [String: AnyCodable]?) {
        guard let props else { return nil }
        self.sessionType = props.string("sessionType") ?? "tts"
        self.playing = props.bool("playing") ?? false
        self.title = props.string("title") ?? ""
        self.chapterTitle = props.string("chapterTitle")
        self.progress = props.double("progress") ?? 0
        self.remainingTime = props.double("remainingTime")
    }
}

// MARK: - ReaderControlSpaceSnapshot（控制层运行空间快照）

/// 控制层运行空间快照（控制层显隐 + 当前激活面板）。
public struct ReaderControlSpaceSnapshot: Equatable {
    public let visible: Bool
    public let activePanel: String?  // "directory" | "appearance" | "tts" | "settings" | "search" | "replace" | "autoPage" | nil

    public init(
        visible: Bool = false,
        activePanel: String? = nil
    ) {
        self.visible = visible
        self.activePanel = activePanel
    }

    public init?(props: [String: AnyCodable]?) {
        guard let props else { return nil }
        self.visible = props.bool("visible") ?? false
        self.activePanel = props.string("activePanel")
    }
}
