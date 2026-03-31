import Foundation

public struct AppEntry {
    public var appName: String
    public var minimumCoreVersion: String

    public init(appName: String = "Reader", minimumCoreVersion: String = "0.1.0") {
        self.appName = appName
        self.minimumCoreVersion = minimumCoreVersion
    }
}
