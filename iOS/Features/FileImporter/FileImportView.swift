import SwiftUI
import ReaderCoreModels
import ReaderShellValidation

public struct FileImportView: View {
    private let onImported: ((CoreLocalBookImportSummary) -> Void)?

    public init(onImported: ((CoreLocalBookImportSummary) -> Void)? = nil) {
        self.onImported = onImported
    }

    public var body: some View {
        BookshelfLocalImportView(onImported: onImported)
    }
}
