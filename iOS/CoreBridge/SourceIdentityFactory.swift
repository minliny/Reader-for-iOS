import Foundation
import ReaderCoreModels
import ReaderAppSupport

public enum SourceIdentityFactory {
    public static func from(searchResult: SearchResultItem) -> SourceIdentity {
        return SourceIdentity(
            id: searchResult.detailURL,
            name: nil,
            baseURL: nil
        )
    }
}
