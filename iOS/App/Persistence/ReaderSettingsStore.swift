import Foundation

public final class ReaderSettingsStore: @unchecked Sendable {
    public static let shared = ReaderSettingsStore()

    private let fileURL: URL
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private init() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documentsPath.appendingPathComponent("reader_settings.json")
    }

    public func loadSettings() throws -> ReaderDisplaySettings {
        lock.lock()
        defer { lock.unlock() }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return ReaderDisplaySettings.default
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(ReaderDisplaySettings.self, from: data)
    }

    public func saveSettings(_ settings: ReaderDisplaySettings) throws {
        lock.lock()
        defer { lock.unlock() }

        let data = try encoder.encode(settings)
        try data.write(to: fileURL)
    }

    public func resetToDefaults() throws {
        try saveSettings(ReaderDisplaySettings.default)
    }
}