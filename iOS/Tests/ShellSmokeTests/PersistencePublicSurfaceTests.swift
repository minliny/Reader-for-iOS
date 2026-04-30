import Foundation
import XCTest
import ReaderAppSupport
import ReaderAppPersistence

final class PersistencePublicSurfaceTests: XCTestCase {

    // MARK: - ReaderSettingsStore

    func testReaderSettingsLoadDefaultWhenFileMissing() throws {
        let tempURL = makeTempFileURL(name: "test_settings_default.json")
        let store = ReaderSettingsStore(storageURL: tempURL)

        let settings = try store.loadSettings()
        XCTAssertEqual(settings, ReaderDisplaySettings.default)
    }

    func testReaderSettingsSaveAndLoadRoundtrip() throws {
        let tempURL = makeTempFileURL(name: "test_settings_roundtrip.json")
        let store = ReaderSettingsStore(storageURL: tempURL)

        var settings = ReaderDisplaySettings.default
        settings.fontSize = 24
        try store.saveSettings(settings)

        let loaded = try store.loadSettings()
        XCTAssertEqual(loaded.fontSize, 24)
    }

    func testReaderSettingsResetToDefaults() throws {
        let tempURL = makeTempFileURL(name: "test_settings_reset.json")
        let store = ReaderSettingsStore(storageURL: tempURL)

        var settings = ReaderDisplaySettings.default
        settings.fontSize = 30
        try store.saveSettings(settings)

        try store.resetToDefaults()

        let loaded = try store.loadSettings()
        XCTAssertEqual(loaded, ReaderDisplaySettings.default)
    }

    // MARK: - Helpers

    private func makeTempFileURL(name: String) -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("PersistenceTests", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent(name)
    }
}
