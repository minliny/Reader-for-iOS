import CoreGraphics
import CryptoKit
import ReaderCoreBridge
import ReaderDesign
import SwiftUI
import XCTest
@testable import ReaderApp
@testable import ReaderHost

@MainActor
enum M3GoldenScenes {
    static let ids = Set(["m3-manga-reading", "m3-manga-retry", "m3-tts-capsule", "m3-tts-playback", "m3-tts-engines"])

    static func view(_ id: String) async throws -> AnyView {
        switch id {
        case "m3-manga-reading":
            let image = try await artwork()
            return AnyView(mangaShell(MangaPageCanvas(image: image, direction: .vertical)))
        case "m3-manga-retry":
            return AnyView(mangaShell(MangaUnavailablePage(height: 196)))
        case "m3-tts-capsule":
            return AnyView(GoldenSpeechCapsuleScene())
        case "m3-tts-playback":
            let state = SpeechPlaybackPresentation(title: "晚灯照长街", engineTitle: "系统音色 · 普通话",
                playing: true, sliceIndex: 2, totalSlices: 12, ratePercent: 125, timerMinutes: 20)
            return AnyView(heading("朗读播控") { SpeechPlaybackPanel(state: state) { _ in } })
        case "m3-tts-engines":
            let engine = M3HttpTtsData(id: 98, name: "本机回环音色", url: "https://127.0.0.1/audio", lastUpdateTime: 0)
            return AnyView(heading("朗读引擎") {
                SpeechEngineCatalogView(selection: .system(voiceID: nil),
                    voices: [.init(id: "golden", name: "普通话", language: "zh-CN")], engines: [engine], onAction: { _ in })
            })
        default:
            throw CocoaError(.featureUnsupported)
        }
    }

    private static func mangaShell(_ page: some View) -> some View {
        VStack(spacing: 0) {
            MangaReadingToolbar(title: "烟青画卷", chapter: "第二话 · 晚钟")
            page.frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
            MangaReadingDock(page: 2, total: 7, direction: .vertical, paper: .paper,
                             previousChapter: {}, nextChapter: {})
                .padding(.vertical, 7)
        }
        .background(ReaderTheme(night: false).background)
    }

    private static func heading(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(title).readerTypography(ReaderDesignMetrics.pageTitle, relativeTo: .headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
            Divider()
            content()
        }
        .background(ReaderTheme(night: false).background)
    }

    private static func artwork() async throws -> MangaTileImage {
        let size = CGSize(width: 400, height: 1250)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: size, format: format).image { renderer in
            let ctx = renderer.cgContext
            ctx.setFillColor(UIColor(red: 0.14, green: 0.25, blue: 0.34, alpha: 1).cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.setFillColor(UIColor(red: 0.39, green: 0.56, blue: 0.59, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 0, y: 145, width: 400, height: 350))
            ctx.setFillColor(UIColor(red: 0.87, green: 0.69, blue: 0.47, alpha: 1).cgColor)
            ctx.fillEllipse(in: CGRect(x: 236, y: 227, width: 90, height: 90))
            ctx.setFillColor(UIColor(red: 0.20, green: 0.29, blue: 0.26, alpha: 1).cgColor)
            ctx.move(to: CGPoint(x: 0, y: 490))
            ctx.addLines(between: [CGPoint(x: 94, y: 330), CGPoint(x: 195, y: 425), CGPoint(x: 305, y: 360),
                                  CGPoint(x: 400, y: 515), CGPoint(x: 400, y: 770), CGPoint(x: 0, y: 690)])
            ctx.fillPath()
            ctx.setFillColor(UIColor(red: 0.69, green: 0.28, blue: 0.23, alpha: 1).cgColor)
            ctx.fill(CGRect(x: 22, y: 520, width: 19, height: 42))
        }
        let data = try XCTUnwrap(image.pngData())
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let sha = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        return try await MangaImageDecoder.shared.decode(.init(url: file, bytes: data.count, sha256: sha, chunks: 1),
            inspection: .absent(.init(transferId: "golden", sha256: sha, bytes: Int64(data.count),
                orientation: .init(), decodeProfile: .init(format: .png, encodedWidth: 400, encodedHeight: 1250,
                                                           allocationClass: .scanline))), preferredWidth: 400)
    }
}

private struct GoldenSpeechCapsuleScene: View {
    private let first = "晚灯照长街，茶炉边传来细细的雨声。"
    @State private var surface = TextReadingSurface()

    var body: some View {
        let style = ReadingPreferences()
        ReadingPresentation(title: "晚灯照长街", preferences: style, controls: .hidden, onAction: { _ in }) {
            TextSurfaceView(surface: surface,
                content: first + "\n\n两扇窗留着亮光，木桥下的水缓缓流过街心。\n\n有人撑着伞走过，远处的钟刚敲过整点。",
                anchor: 0, preferences: style, speechHighlight: 0..<first.unicodeScalars.count)
        }
        .safeAreaInset(edge: .bottom, alignment: .trailing, spacing: 0) {
            SpeechCapsule(title: "晚灯照长街", playing: true, toggle: {}, expand: {})
                .padding(.vertical, 6)
                .padding(.trailing, CGFloat(ReaderDesignMetrics.screenInset))
        }
    }
}
