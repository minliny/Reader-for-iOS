import SwiftUI
import ReaderCoreModels

public struct ReaderView: View {
    @StateObject private var viewModel: ReaderViewModel
    @State private var showSettings = false
    @Environment(\.dismiss) private var dismiss

    public init(chapterURL: String, chapterTitle: String) {
        self._viewModel = StateObject(wrappedValue: ReaderViewModel(chapterURL: chapterURL, chapterTitle: chapterTitle))
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                contentBackground
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    readerStateView
                }
            }
            .navigationTitle(viewModel.chapterTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showSettings.toggle()
                    }) {
                        Image(systemName: "textformat.size")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                ReaderSettingsPanel(
                    displaySettings: $viewModel.displaySettings,
                    onDismiss: {
                        viewModel.saveSettings()
                        showSettings = false
                    }
                )
                .presentationDetents([.medium])
            }
            .onAppear {
                Task { await viewModel.loadContent() }
            }
        }
    }

    @ViewBuilder
    private var contentBackground: some View {
        Color(hex: viewModel.displaySettings.backgroundMode.backgroundColor)
    }

    @ViewBuilder
    private var readerStateView: some View {
        switch viewModel.readerState {
        case .idle:
            Text("Loading...")
                .font(.subheadline)
                .foregroundStyle(.secondary)

        case .loading:
            ProgressView("Loading content...")
                .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .loaded(let content):
            ScrollView {
                Text(content.content)
                    .font(.system(size: CGFloat(viewModel.displaySettings.fontSize)))
                    .foregroundColor(Color(hex: viewModel.displaySettings.backgroundMode.textColor))
                    .lineSpacing(CGFloat(viewModel.displaySettings.lineSpacing))
                    .padding(EdgeInsets(
                        top: viewModel.displaySettings.verticalPadding,
                        leading: viewModel.displaySettings.horizontalPadding,
                        bottom: viewModel.displaySettings.verticalPadding,
                        trailing: viewModel.displaySettings.horizontalPadding
                    ))
            }

        case .empty:
            VStack(spacing: 16) {
                Image(systemName: "doc.text")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)

                Text("No Content")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Chapter content is unavailable")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Label("Load Failed", systemImage: "xmark.circle.fill")
                    .foregroundStyle(.red)
                    .font(.subheadline.weight(.semibold))

                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

        case .unsupported(let reason):
            VStack(alignment: .leading, spacing: 8) {
                Label("Unsupported", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.subheadline.weight(.semibold))

                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(Color.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

        case .partial(let content, let warnings):
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Partial Content", systemImage: "exclamationmark.circle.fill")
                        .foregroundStyle(.yellow)
                        .font(.subheadline.weight(.semibold))

                    ForEach(warnings, id: \.self) {
                        Text("⚠️ \($0)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding()
                .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                ScrollView {
                    Text(content.content)
                        .font(.system(size: CGFloat(viewModel.displaySettings.fontSize)))
                        .foregroundColor(Color(hex: viewModel.displaySettings.backgroundMode.textColor))
                        .lineSpacing(CGFloat(viewModel.displaySettings.lineSpacing))
                        .padding(EdgeInsets(
                            top: viewModel.displaySettings.verticalPadding,
                            leading: viewModel.displaySettings.horizontalPadding,
                            bottom: viewModel.displaySettings.verticalPadding,
                            trailing: viewModel.displaySettings.horizontalPadding
                        ))
                }
            }
        }
    }
}