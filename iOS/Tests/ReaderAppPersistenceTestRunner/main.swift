import Foundation
import ReaderAppSupport
import ReaderAppPersistence

func main() -> Int32 {
    var failures = 0

    func assertEqual<T: Equatable>(_ got: T, _ expected: T, _ label: String) {
        if got != expected {
            fputs("FAIL: \(label) — expected \(expected), got \(got)\n", stderr)
            failures += 1
        } else {
            fputs("PASS: \(label)\n", stderr)
        }
    }

    func assertNil<T>(_ got: T?, _ label: String) {
        if got != nil {
            fputs("FAIL: \(label) — expected nil, got \(got!)\n", stderr)
            failures += 1
        } else {
            fputs("PASS: \(label)\n", stderr)
        }
    }

    let tempDir = FileManager.default.temporaryDirectory
        .appendingPathComponent("PersistenceTestRunner-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDir) }

    // MARK: - ReaderSettingsStore

    do {
        let fileURL = tempDir.appendingPathComponent("test_settings.json")
        let store = ReaderSettingsStore(storageURL: fileURL)

        // 1. loadSettings returns default when file missing
        let defaultSettings = try store.loadSettings()
        assertEqual(defaultSettings, ReaderDisplaySettings.default, "loadSettings returns default when file missing")

        // 2. saveSettings then loadSettings returns saved value
        var settings = ReaderDisplaySettings.default
        settings.fontSize = 24
        try store.saveSettings(settings)
        let loaded = try store.loadSettings()
        assertEqual(loaded.fontSize, 24, "saveSettings then loadSettings returns saved fontSize")

        // 3. resetToDefaults restores default values
        try store.resetToDefaults()
        let reset = try store.loadSettings()
        assertEqual(reset, ReaderDisplaySettings.default, "resetToDefaults restores default values")
    } catch {
        fputs("FAIL: ReaderSettingsStore — error: \(error)\n", stderr)
        failures += 1
    }

    // MARK: - ReaderDisplaySettings Codable round-trip
    do {
        var original = ReaderDisplaySettings.default
        original.fontSize = 18
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ReaderDisplaySettings.self, from: data)
        assertEqual(decoded.fontSize, 18, "ReaderDisplaySettings Codable round-trip fontSize")
    } catch {
        fputs("FAIL: ReaderDisplaySettings Codable — error: \(error)\n", stderr)
        failures += 1
    }

    if failures > 0 {
        fputs("\n\(failures) test(s) FAILED\n", stderr)
        return 1
    }
    fputs("\nAll persistence surface tests PASSED\n", stderr)
    return 0
}

exit(main())
