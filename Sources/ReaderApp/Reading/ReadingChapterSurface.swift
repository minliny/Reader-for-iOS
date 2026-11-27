import Observation
import SwiftUI
import UIKit

@MainActor
@Observable
final class ReadingRenderState {
    var text: TextReadingSurface?
    var ebook: EbookReadingSurface?

    func position() async -> Int? {
        if let ebook { return (try? await ebook.position())?.scalar }
        return (try? await text?.position())?.scalar
    }

    func selection() async -> Bool {
        if let ebook { return (try? await ebook.selection())?.startScalar != nil }
        return (try? await text?.selection())?.startScalar != nil
    }

    func retire() async {
        let retiredEbook = ebook
        let retiredText = text
        ebook = nil
        text = nil
        await retiredEbook?.retire()
        await retiredText?.retire()
    }
}

struct ReadingChapterSurface: View {
    let chapter: ReadingChapter
    let preferences: ReadingPreferences
    let model: ReadingSessionCoordinator
    let renderer: ReadingRenderState
    let onTap: () -> Void
    @State private var text: TextReadingSurface?
    @State private var ebook: EbookReadingSurface?
    @State private var isEbookReady = false
    @State private var preferencesGeneration = 0

    var body: some View {
        Group {
            if let text {
                TextSurfaceView(surface: text, content: chapter.projection.content, anchor: chapter.anchor,
                                preferences: preferences, onReady: measured)
            } else if let ebook, let document = chapter.ebook {
                ReaderNativeView(view: ebook.webView)
                    .accessibilityIdentifier("reader-ebook-surface")
                    .opacity(isEbookReady ? 1 : 0)
                    .task { await open(ebook, document: document) }
                    .onChange(of: preferences) { _, _ in reflow(ebook) }
            } else {
                ProgressView("正在打开章节").frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .task {
            guard renderer.ebook !== ebook || renderer.text !== text || (text == nil && ebook == nil) else { return }
            await renderer.retire()
            guard model.generation == chapter.generation, !Task.isCancelled else { return }
            if chapter.ebook != nil {
                do {
                    let surface = try EbookReadingSurface()
                    surface.webView.accessibilityIdentifier = "reader-ebook-surface"
                    surface.onEvent = { event in
                        guard model.generation == chapter.generation, model.frontmost else { return }
                        if event.kind == "tap" { onTap() }
                        if event.kind == "position", let scalar = event.value?.scalar { measured(scalar) }
                    }
                    ebook = surface
                    renderer.ebook = surface
                } catch {
                    model.useVerifiedText(expected: chapter.generation)
                }
            } else {
                let surface = TextReadingSurface()
                surface.onTap = onTap
                surface.onPosition = measured
                text = surface
                renderer.text = surface
            }
        }
    }

    private func open(_ surface: EbookReadingSurface, document: EbookDocument) async {
        do {
            let result = try await surface.open(document, session: model.id, anchor: chapter.anchor,
                                                style: preferences.webStyle)
            guard model.generation == chapter.generation, !Task.isCancelled else { return }
            if let scalar = result.scalar { measured(scalar) }
            isEbookReady = true
        } catch {
            if !Task.isCancelled { model.useVerifiedText(expected: chapter.generation) }
        }
    }

    private func reflow(_ surface: EbookReadingSurface) {
        guard isEbookReady else { return }
        preferencesGeneration += 1
        let key = preferencesGeneration
        let anchor = model.position
        Task {
            do {
                let result = try await surface.reflow(style: preferences.webStyle, anchor: anchor)
                guard key == preferencesGeneration else { return }
                if let scalar = result.scalar { measured(scalar) }
            } catch {
                guard key == preferencesGeneration else { return }
                model.useVerifiedText(expected: chapter.generation)
            }
        }
    }

    private func measured(_ scalar: Int) { model.measured(scalar, expected: chapter.generation) }
}
