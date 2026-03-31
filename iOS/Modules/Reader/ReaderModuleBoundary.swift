import Foundation

public struct ReaderModuleBoundary {
    public var canImportBookSource: Bool
    public var canSearch: Bool
    public var canReadContent: Bool

    public init(canImportBookSource: Bool = true, canSearch: Bool = true, canReadContent: Bool = true) {
        self.canImportBookSource = canImportBookSource
        self.canSearch = canSearch
        self.canReadContent = canReadContent
    }
}
