import XCTest
import ReaderAppPersistence
@testable import ReaderApp
@testable import ReaderShellValidation

final class ReaderSlice12SettingsOwnershipTests: XCTestCase {
    @MainActor
    func testReaderViewModelDoesNotOverwriteFutureSettingsAfterLoadFailure() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("slice12-settings-owner-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("reader_settings.json")
        let future = try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 99,
            "settings": ["fontSize": 42],
        ], options: [.sortedKeys])
        try future.write(to: url, options: .atomic)

        let viewModel = ReaderViewModel(
            chapterURL: "offline://chapter/1",
            chapterTitle: "Fixture",
            settingsStore: ReaderSettingsStore(storageURL: url)
        )

        XCTAssertNotNil(viewModel.settingsPersistenceFailure)
        XCTAssertFalse(viewModel.saveSettings())
        XCTAssertEqual(try Data(contentsOf: url), future)
    }
}
