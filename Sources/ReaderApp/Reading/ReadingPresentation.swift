import ReaderDesign
import SwiftUI
import UIKit

struct ReaderNativeView: UIViewRepresentable {
    let view: UIView
    func makeUIView(context: Context) -> UIView { view }
    func updateUIView(_ view: UIView, context: Context) {}
}

struct ReadingPresentation<Content: View>: View {
    let title: String
    let preferences: ReadingPreferences
    let controls: ReadingControls
    let onAction: (ReadingControlAction) -> Void
    var speechAvailable = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        let paper = preferences.paper
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .readerTypography(ReaderDesignMetrics.readerControlChapterTitle, relativeTo: .caption)
                    .lineLimit(1)
                Spacer()
            }
            .foregroundStyle(paper.statusForeground)
            .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
            .padding(.vertical, 6)
            .background(paper.statusBackground.ignoresSafeArea(edges: .top))
            .accessibilityIdentifier("reader-status-paper")

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background {
            LinearGradient(colors: [paper.background, paper.backgroundEnd], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
        .overlay(alignment: .bottom) {
            ControlPanel(state: controls, title: title, preferences: preferences, onAction: onAction,
                         speechAvailable: speechAvailable)
        }
    }
}

struct TextReaderPresentation: View {
    let text: String
    let chapterTitle: String
    let anchor: Int
    let preferences: ReadingPreferences
    let controls: ReadingControls
    var onControl: (ReadingControlAction) -> Void = { _ in }
    @State private var surface = TextReadingSurface()

    var body: some View {
        ReadingPresentation(title: chapterTitle, preferences: preferences, controls: controls, onAction: onControl) {
            TextSurfaceView(surface: surface, content: text, anchor: anchor, preferences: preferences)
        }
    }
}

struct TextSurfaceView: View {
    let surface: TextReadingSurface
    let content: String
    let anchor: Int
    let preferences: ReadingPreferences
    var speechHighlight: Range<Int>?
    var onReady: (Int) -> Void = { _ in }

    var body: some View {
        GeometryReader { geometry in
            ReaderNativeView(view: surface.view)
                .onAppear {
                    surface.prepare(preferences: preferences, viewport: geometry.size)
                    let value = surface.load(.init(content: content), anchor: anchor)
                    if let scalar = value.scalar { onReady(scalar) }
                    surface.presentSpeechHighlight(speechHighlight)
                }
                .onChange(of: geometry.size) { _, size in surface.prepare(preferences: preferences, viewport: size) }
                .onChange(of: preferences) { _, style in surface.prepare(preferences: style, viewport: geometry.size) }
                .onChange(of: speechHighlight) { _, range in surface.presentSpeechHighlight(range) }
        }
        .padding(.horizontal, CGFloat(ReaderDesignMetrics.screenInset))
        .padding(.top, 12)
    }
}
