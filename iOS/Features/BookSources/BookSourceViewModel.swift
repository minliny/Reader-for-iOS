import Foundation
import ReaderCoreModels
import ReaderShellValidation
import ReaderAppPersistence

public enum BookSourceImportState: Equatable {
    case idle
    case loading
    case success(source: BookSource)
    case failed(message: String)
    case unsupported(reason: String)
    case partial(source: BookSource, warnings: [String])

    public static func == (lhs: BookSourceImportState, rhs: BookSourceImportState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.loading, .loading):
            return true
        case (.success(let a), .success(let b)):
            return a.id == b.id
        case (.failed(let a), .failed(let b)):
            return a == b
        case (.unsupported(let a), .unsupported(let b)):
            return a == b
        case (.partial(let a, let w1), .partial(let b, let w2)):
            return a.id == b.id && w1 == w2
        default:
            return false
        }
    }
}

@MainActor
public final class BookSourceViewModel: ObservableObject {
    @Published public var jsonInput = ""
    @Published public var importState: BookSourceImportState = .idle

    private let store = BookSourceStore.shared
    private let provider = ReaderCoreServiceProvider.shared

    public init() {}

    public func importFromText() async {
        let trimmed = jsonInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            importState = .failed(message: "Input is empty")
            return
        }

        guard let data = trimmed.data(using: .utf8) else {
            importState = .failed(message: "Invalid text encoding")
            return
        }

        await importFromData(data)
    }

    public func importFromData(_ data: Data) async {
        importState = .loading

        do {
            let state = await provider.validateBookSource(from: data)
            switch state {
            case .loaded(let source):
                try await store.add(source)
                importState = .success(source: source)

            case .partial(let source, let warning):
                try await store.add(source)
                importState = .partial(source: source, warnings: [warning])

            case .unsupported(let reason):
                importState = .unsupported(reason: reason)

            case .failed(let error):
                importState = .failed(message: error.message)

            case .empty:
                importState = .failed(message: "Empty source data")

            case .loading, .idle:
                break
            }
        } catch {
            importState = .failed(message: "Save failed: \(error.localizedDescription)")
        }
    }

    public func reset() {
        jsonInput = ""
        importState = .idle
    }
}
