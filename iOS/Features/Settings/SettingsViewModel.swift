import Foundation
import ReaderAppSupport

public enum SettingsState: Equatable {
    case idle
    case saving
    case saved
    case failed(message: String)

    public static func == (lhs: SettingsState, rhs: SettingsState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.saving, .saving), (.saved, .saved): return true
        case (.failed(let a), .failed(let b)): return a == b
        default: return false
        }
    }
}

@MainActor
public final class SettingsViewModel: ObservableObject {
    @Published public var displaySettings = ReaderDisplaySettings.default
    @Published public var state: SettingsState = .idle
    @Published public var cacheSizeDescription: String = "Unknown"
    @Published public var appVersion: String = "1.0.0"

    private let settingsStore = ReaderSettingsStore.shared

    public init() {
        loadSettings()
        appVersion = ReaderAppSupportMarker.version
    }

    public func loadSettings() {
        if let saved = try? settingsStore.loadSettings() {
            displaySettings = saved
        }
    }

    public func saveSettings() {
        state = .saving
        do {
            try settingsStore.saveSettings(displaySettings)
            state = .saved
        } catch {
            state = .failed(message: "Save failed: \(error.localizedDescription)")
        }
    }

    public func resetToDefaults() {
        displaySettings = ReaderDisplaySettings.default
        saveSettings()
    }

    public func clearCache() {
        state = .saving
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.cacheSizeDescription = "0 KB"
            self.state = .saved
        }
    }

    public func increaseFontSize() {
        if displaySettings.fontSize < 32 {
            displaySettings.fontSize += 2
        }
    }

    public func decreaseFontSize() {
        if displaySettings.fontSize > 12 {
            displaySettings.fontSize -= 2
        }
    }

    public func increaseLineSpacing() {
        if displaySettings.lineSpacing < 24 {
            displaySettings.lineSpacing += 2
        }
    }

    public func decreaseLineSpacing() {
        if displaySettings.lineSpacing > 2 {
            displaySettings.lineSpacing -= 2
        }
    }
}
