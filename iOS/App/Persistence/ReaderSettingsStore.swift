import CoreFoundation
import Foundation
import ReaderAppSupport

public final class ReaderSettingsStore: @unchecked Sendable {
    public struct LoadResult: Equatable {
        public let settings: ReaderDisplaySettings
        public let schemaVersion: Int
        public let migratedLegacyDocument: Bool

        public init(settings: ReaderDisplaySettings, schemaVersion: Int, migratedLegacyDocument: Bool) {
            self.settings = settings
            self.schemaVersion = schemaVersion
            self.migratedLegacyDocument = migratedLegacyDocument
        }
    }

    private struct Envelope: Codable {
        let schemaVersion: Int
        let settings: ReaderDisplaySettings
    }

    public static let currentSchemaVersion = 1
    public static let shared = ReaderSettingsStore()

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("reader_settings.json")
    }

    public init(storageURL: URL) {
        fileURL = storageURL
    }

    public func loadSettings() throws -> ReaderDisplaySettings {
        let result = try loadResult()
        if result.migratedLegacyDocument {
            try saveSettings(result.settings)
        }
        return result.settings
    }

    /// Loads the versioned Host-owned display-settings document. Plain
    /// `ReaderDisplaySettings` JSON written by earlier builds is accepted as
    /// schema 0 and reported as a legacy migration; unknown future schemas and
    /// malformed documents fail closed instead of silently resetting choices.
    public func loadResult() throws -> LoadResult {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return LoadResult(
                settings: .default,
                schemaVersion: Self.currentSchemaVersion,
                migratedLegacyDocument: false
            )
        }

        let data = try Data(contentsOf: fileURL)
        if let envelope = try? decoder.decode(Envelope.self, from: data) {
            guard envelope.schemaVersion == Self.currentSchemaVersion else {
                throw ReaderSettingsStoreError.unsupportedSchemaVersion(envelope.schemaVersion)
            }
            return LoadResult(
                settings: envelope.settings,
                schemaVersion: envelope.schemaVersion,
                migratedLegacyDocument: false
            )
        }
        // A document that declares a schema is never a schema-0 document.
        // Check this before the permissive backward-compatible settings
        // decoder, which intentionally supplies defaults for unknown/missing
        // keys and could otherwise disguise a malformed/future envelope as a
        // valid legacy settings file.
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           object.keys.contains("schemaVersion") {
            guard let rawVersion = object["schemaVersion"] as? NSNumber,
                  CFGetTypeID(rawVersion) != CFBooleanGetTypeID(),
                  !CFNumberIsFloatType(rawVersion),
                  let version = Int(rawVersion.stringValue) else {
                throw ReaderSettingsStoreError.invalidDocument("schemaVersion must be an integer")
            }
            guard version == Self.currentSchemaVersion else {
                throw ReaderSettingsStoreError.unsupportedSchemaVersion(version)
            }
            throw ReaderSettingsStoreError.invalidDocument(
                "schema (version) settings envelope cannot be decoded"
            )
        }
        do {
            let legacy = try decoder.decode(ReaderDisplaySettings.self, from: data)
            return LoadResult(settings: legacy, schemaVersion: 0, migratedLegacyDocument: true)
        } catch {
            throw ReaderSettingsStoreError.invalidDocument(error.localizedDescription)
        }
    }

    public func saveSettings(_ settings: ReaderDisplaySettings) throws {
        lock.lock()
        defer { lock.unlock() }

        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let data = try encoder.encode(Envelope(
            schemaVersion: Self.currentSchemaVersion,
            settings: settings
        ))
        try data.write(to: fileURL, options: .atomic)
    }

    public func resetToDefaults() throws {
        try saveSettings(ReaderDisplaySettings.default)
    }
}

public enum ReaderSettingsStoreError: Error, Equatable, LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidDocument(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "[SLICE12_SETTINGS_SCHEMA_UNSUPPORTED] settings schema \(version) is not supported"
        case .invalidDocument(let message):
            return "[SLICE12_SETTINGS_DOCUMENT_INVALID] \(message)"
        }
    }
}
