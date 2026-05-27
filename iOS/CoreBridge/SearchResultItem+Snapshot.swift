import Foundation
import ReaderCoreModels

extension SearchResultItem: SearchResultConvertible {
    public var snapshotTitle: String { title }
    public var snapshotAuthor: String? { author }
    public var snapshotBookURL: String { detailURL }
    public var snapshotCoverURL: String? { coverURL }
    public var snapshotIntro: String? { intro }
}
