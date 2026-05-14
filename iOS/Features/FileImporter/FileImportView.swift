import SwiftUI
import UniformTypeIdentifiers
import ReaderCoreModels

public struct FileImportView: View {
    @StateObject private var viewModel = FileImportViewModel()
    @State private var showFilePicker = false

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                switch viewModel.importState {
                case .idle:
                    idleView
                case .selecting:
                    EmptyView()
                case .importing(let name):
                    importingView(name: name)
                case .imported(let book):
                    importedView(book: book)
                case .failed(let message):
                    failedView(message: message)
                }
            }
            .padding()
            .navigationTitle("Import Book")
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: viewModel.supportedContentTypes,
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        Task { await viewModel.handleSelectedFile(url) }
                    }
                case .failure(let error):
                    viewModel.importState = .failed(message: error.localizedDescription)
                }
            }
        }
    }

    // MARK: - State Views

    private var idleView: some View {
        VStack(spacing: 24) {
            Image(systemName: "doc.badge.plus")
                .font(.system(size: 64))
                .foregroundStyle(.blue)

            Text("Import a Local Book")
                .font(.title2.bold())

            Text("Select a TXT or EPUB file to add to your bookshelf.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 4) {
                Label("TXT files — plain text novels", systemImage: "doc.text")
                Label("EPUB files — standard ebook format", systemImage: "book")
            }
            .font(.callout)
            .foregroundStyle(.secondary)

            Button {
                showFilePicker = true
            } label: {
                Label("Choose File", systemImage: "folder")
                    .frame(maxWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
    }

    private func importingView(name: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Importing \(name)...")
                .font(.headline)
            Text("Reading file metadata")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func importedView(book: LocalBook) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("Import Successful")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                infoRow("Title", book.title)
                if let author = book.author {
                    infoRow("Author", author)
                }
                infoRow("Format", book.fileFormat.rawValue.uppercased())
                if let size = book.fileSize {
                    infoRow("Size", ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))

            HStack(spacing: 16) {
                Button {
                    viewModel.reset()
                } label: {
                    Label("Import Another", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func failedView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.red)

            Text("Import Failed")
                .font(.title2.bold())

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button("Try Again") {
                viewModel.reset()
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .frame(width: 60, alignment: .leading)
            Text(value)
                .font(.body)
        }
    }
}
