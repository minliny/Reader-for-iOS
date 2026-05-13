import Foundation
import SwiftUI

public enum BackupSchedule: String, CaseIterable, Codable {
    case daily
    case weekly
    case manual
}

public enum ConnectionTestResult: Equatable {
    case idle
    case testing
    case success(message: String)
    case failed(message: String)
}

@MainActor
public final class WebDAVSettingsViewModel: ObservableObject {
    @Published public var serverURL: String = ""
    @Published public var username: String = ""
    @Published public var password: String = ""
    @Published public var backupSchedule: BackupSchedule = .weekly
    @Published public var retentionCount: Int = 5
    @Published public var connectionTestResult: ConnectionTestResult = .idle
    @Published public var lastBackupDate: Date? = nil
    @Published public var isSaving: Bool = false

    public var isValid: Bool {
        guard let url = URL(string: serverURL.trimmingCharacters(in: .whitespaces)) else {
            return false
        }
        return url.scheme == "http" || url.scheme == "https"
    }

    public func testConnection() async {
        connectionTestResult = .testing
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        if serverURL.trimmingCharacters(in: .whitespaces).isEmpty {
            connectionTestResult = .failed(message: "Server URL is required")
        } else if !isValid {
            connectionTestResult = .failed(message: "Invalid URL format")
        } else {
            connectionTestResult = .success(message: "Connection successful (mock)")
        }
    }

    public func saveCredentials() async {
        isSaving = true
        try? await Task.sleep(nanoseconds: 500_000_000)
        isSaving = false
    }
}
