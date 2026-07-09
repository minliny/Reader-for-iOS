import SwiftUI

/// Generated from Reader UI frontend-demo asset-library/icons.js.
/// Do not edit token names by hand; run scripts/import_demo_icon_assets.mjs after demo icon changes.
public struct ReaderAssetIcon: RawRepresentable, Hashable, Codable, Identifiable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var id: String { rawValue }
    public var assetName: String { "reader-icon-\(rawValue)" }

    public static let demoSource = "Reader UI/frontend-demo-optimized/asset-library/icons.js"
    public static let demoBaselineCount = 92

    public static let allNames: [String] = [
        "activity",
        "add",
        "appearance",
        "assist",
        "auto-page",
        "back",
        "badge",
        "battery",
        "bell",
        "book",
        "book-open",
        "bookmark",
        "bookshelf",
        "bug",
        "check",
        "checkmark",
        "chevron",
        "chevron-left",
        "clear",
        "clock",
        "close",
        "cloud",
        "code",
        "columns",
        "current-location",
        "database",
        "directory",
        "discover",
        "download",
        "edit",
        "eyeOff",
        "file",
        "filter",
        "folder",
        "folder-off",
        "gear",
        "gesture",
        "globe",
        "grid",
        "help",
        "home",
        "image",
        "info",
        "link",
        "list",
        "log",
        "mail",
        "message",
        "monitor",
        "more",
        "motion",
        "night-mode",
        "offline",
        "palette",
        "pause",
        "people",
        "permission",
        "phone",
        "play",
        "progress",
        "reader-auto-page",
        "reader-content-replace",
        "reader-content-search",
        "reader-module-appearance",
        "reader-module-directory",
        "reader-module-settings",
        "reader-module-tts",
        "refresh",
        "replace",
        "rss",
        "search",
        "settings",
        "shield",
        "signal",
        "sort",
        "source",
        "source-stack",
        "source-switch",
        "sparkle",
        "stop",
        "storage",
        "sun",
        "sync",
        "text",
        "top",
        "trash",
        "tts",
        "typo",
        "upload",
        "volume",
        "warning",
        "wifi"
    ]

    public static let activity = ReaderAssetIcon("activity")
    public static let add = ReaderAssetIcon("add")
    public static let appearance = ReaderAssetIcon("appearance")
    public static let assist = ReaderAssetIcon("assist")
    public static let autoPage = ReaderAssetIcon("auto-page")
    public static let back = ReaderAssetIcon("back")
    public static let badge = ReaderAssetIcon("badge")
    public static let battery = ReaderAssetIcon("battery")
    public static let bell = ReaderAssetIcon("bell")
    public static let book = ReaderAssetIcon("book")
    public static let bookOpen = ReaderAssetIcon("book-open")
    public static let bookmark = ReaderAssetIcon("bookmark")
    public static let bookshelf = ReaderAssetIcon("bookshelf")
    public static let bug = ReaderAssetIcon("bug")
    public static let check = ReaderAssetIcon("check")
    public static let checkmark = ReaderAssetIcon("checkmark")
    public static let chevron = ReaderAssetIcon("chevron")
    public static let chevronLeft = ReaderAssetIcon("chevron-left")
    public static let clear = ReaderAssetIcon("clear")
    public static let clock = ReaderAssetIcon("clock")
    public static let close = ReaderAssetIcon("close")
    public static let cloud = ReaderAssetIcon("cloud")
    public static let code = ReaderAssetIcon("code")
    public static let columns = ReaderAssetIcon("columns")
    public static let currentLocation = ReaderAssetIcon("current-location")
    public static let database = ReaderAssetIcon("database")
    public static let directory = ReaderAssetIcon("directory")
    public static let discover = ReaderAssetIcon("discover")
    public static let download = ReaderAssetIcon("download")
    public static let edit = ReaderAssetIcon("edit")
    public static let eyeOff = ReaderAssetIcon("eyeOff")
    public static let file = ReaderAssetIcon("file")
    public static let filter = ReaderAssetIcon("filter")
    public static let folder = ReaderAssetIcon("folder")
    public static let folderOff = ReaderAssetIcon("folder-off")
    public static let gear = ReaderAssetIcon("gear")
    public static let gesture = ReaderAssetIcon("gesture")
    public static let globe = ReaderAssetIcon("globe")
    public static let grid = ReaderAssetIcon("grid")
    public static let help = ReaderAssetIcon("help")
    public static let home = ReaderAssetIcon("home")
    public static let image = ReaderAssetIcon("image")
    public static let info = ReaderAssetIcon("info")
    public static let link = ReaderAssetIcon("link")
    public static let list = ReaderAssetIcon("list")
    public static let log = ReaderAssetIcon("log")
    public static let mail = ReaderAssetIcon("mail")
    public static let message = ReaderAssetIcon("message")
    public static let monitor = ReaderAssetIcon("monitor")
    public static let more = ReaderAssetIcon("more")
    public static let motion = ReaderAssetIcon("motion")
    public static let nightMode = ReaderAssetIcon("night-mode")
    public static let offline = ReaderAssetIcon("offline")
    public static let palette = ReaderAssetIcon("palette")
    public static let pause = ReaderAssetIcon("pause")
    public static let people = ReaderAssetIcon("people")
    public static let permission = ReaderAssetIcon("permission")
    public static let phone = ReaderAssetIcon("phone")
    public static let play = ReaderAssetIcon("play")
    public static let progress = ReaderAssetIcon("progress")
    public static let readerAutoPage = ReaderAssetIcon("reader-auto-page")
    public static let readerContentReplace = ReaderAssetIcon("reader-content-replace")
    public static let readerContentSearch = ReaderAssetIcon("reader-content-search")
    public static let readerModuleAppearance = ReaderAssetIcon("reader-module-appearance")
    public static let readerModuleDirectory = ReaderAssetIcon("reader-module-directory")
    public static let readerModuleSettings = ReaderAssetIcon("reader-module-settings")
    public static let readerModuleTts = ReaderAssetIcon("reader-module-tts")
    public static let refresh = ReaderAssetIcon("refresh")
    public static let replace = ReaderAssetIcon("replace")
    public static let rss = ReaderAssetIcon("rss")
    public static let search = ReaderAssetIcon("search")
    public static let settings = ReaderAssetIcon("settings")
    public static let shield = ReaderAssetIcon("shield")
    public static let signal = ReaderAssetIcon("signal")
    public static let sort = ReaderAssetIcon("sort")
    public static let source = ReaderAssetIcon("source")
    public static let sourceStack = ReaderAssetIcon("source-stack")
    public static let sourceSwitch = ReaderAssetIcon("source-switch")
    public static let sparkle = ReaderAssetIcon("sparkle")
    public static let stop = ReaderAssetIcon("stop")
    public static let storage = ReaderAssetIcon("storage")
    public static let sun = ReaderAssetIcon("sun")
    public static let sync = ReaderAssetIcon("sync")
    public static let text = ReaderAssetIcon("text")
    public static let top = ReaderAssetIcon("top")
    public static let trash = ReaderAssetIcon("trash")
    public static let tts = ReaderAssetIcon("tts")
    public static let typo = ReaderAssetIcon("typo")
    public static let upload = ReaderAssetIcon("upload")
    public static let volume = ReaderAssetIcon("volume")
    public static let warning = ReaderAssetIcon("warning")
    public static let wifi = ReaderAssetIcon("wifi")
}

public struct ReaderIcon: View {
    private let icon: ReaderAssetIcon
    private let size: CGFloat
    private let accessibilityLabel: String?

    public init(_ icon: ReaderAssetIcon, size: CGFloat = 24, accessibilityLabel: String? = nil) {
        self.icon = icon
        self.size = size
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        let image = Image(icon.assetName)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)

        if let accessibilityLabel {
            image.accessibilityLabel(Text(accessibilityLabel))
        } else {
            image.accessibilityHidden(true)
        }
    }
}
