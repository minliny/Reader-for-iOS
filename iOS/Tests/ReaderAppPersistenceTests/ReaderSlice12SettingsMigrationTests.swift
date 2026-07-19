import Foundation
import XCTest
import ReaderAppSupport
import ReaderAppPersistence

final class ReaderSlice12SettingsMigrationTests: XCTestCase {
    func testLegacySettingsDocumentIsLoadedAsSchemaZero() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("slice12-settings-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("reader_settings.json")
        var legacy = ReaderDisplaySettings.default
        legacy.fontSize = 27
        try JSONEncoder().encode(legacy).write(to: url, options: .atomic)

        let result = try ReaderSettingsStore(storageURL: url).loadResult()

        XCTAssertEqual(result.settings.fontSize, 27)
        XCTAssertEqual(result.schemaVersion, 0)
        XCTAssertTrue(result.migratedLegacyDocument)
    }

    func testSavedSettingsUseVersionedEnvelopeAndAtomicRoundTrip() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("slice12-settings-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("nested/reader_settings.json")
        var settings = ReaderDisplaySettings.default
        settings.fontSize = 31
        let store = ReaderSettingsStore(storageURL: url)

        try store.saveSettings(settings)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
        let result = try store.loadResult()

        XCTAssertEqual(object["schemaVersion"] as? Int, ReaderSettingsStore.currentSchemaVersion)
        XCTAssertNotNil(object["settings"] as? [String: Any])
        XCTAssertEqual(result.settings.fontSize, 31)
        XCTAssertEqual(result.schemaVersion, ReaderSettingsStore.currentSchemaVersion)
        XCTAssertFalse(result.migratedLegacyDocument)
    }

    func testProductionLoadMigratesLegacyDocumentToCurrentEnvelope() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("slice12-settings-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("reader_settings.json")
        var legacy = ReaderDisplaySettings.default
        legacy.fontSize = 29
        try JSONEncoder().encode(legacy).write(to: url, options: .atomic)
        let store = ReaderSettingsStore(storageURL: url)

        let settings = try store.loadSettings()
        let migrated = try store.loadResult()

        XCTAssertEqual(settings.fontSize, 29)
        XCTAssertEqual(migrated.settings.fontSize, 29)
        XCTAssertEqual(migrated.schemaVersion, ReaderSettingsStore.currentSchemaVersion)
        XCTAssertFalse(migrated.migratedLegacyDocument)
    }

    func testUnknownFutureSettingsSchemaFailsClosed() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("slice12-settings-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("reader_settings.json")
        let settingsObject = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(ReaderDisplaySettings.default))
        )
        try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 99,
            "settings": settingsObject,
        ]).write(to: url, options: .atomic)

        XCTAssertThrowsError(try ReaderSettingsStore(storageURL: url).loadResult()) { error in
            XCTAssertEqual(error as? ReaderSettingsStoreError, .unsupportedSchemaVersion(99))
        }
    }

    func testFlatFutureDocumentCannotMasqueradeAsLegacySettings() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("slice12-settings-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("reader_settings.json")
        try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 99,
            "fontSize": 41,
        ]).write(to: url, options: .atomic)

        XCTAssertThrowsError(try ReaderSettingsStore(storageURL: url).loadResult()) { error in
            XCTAssertEqual(error as? ReaderSettingsStoreError, .unsupportedSchemaVersion(99))
        }
    }

    func testMalformedCurrentEnvelopeCannotMasqueradeAsLegacySettings() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("slice12-settings-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("reader_settings.json")
        try JSONSerialization.data(withJSONObject: [
            "schemaVersion": ReaderSettingsStore.currentSchemaVersion,
            "fontSize": 41,
        ]).write(to: url, options: .atomic)

        XCTAssertThrowsError(try ReaderSettingsStore(storageURL: url).loadResult()) { error in
            guard let storeError = error as? ReaderSettingsStoreError,
                  case .invalidDocument = storeError else {
                return XCTFail("expected invalidDocument, got \(error)")
            }
        }
    }
}
