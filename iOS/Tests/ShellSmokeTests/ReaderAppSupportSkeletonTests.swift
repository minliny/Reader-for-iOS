import XCTest
import ReaderAppSupport

final class ReaderAppSupportSkeletonTests: XCTestCase {
    func testReaderAppSupportMarkerVersionIsNonEmpty() {
        XCTAssertFalse(ReaderAppSupportMarker.version.isEmpty)
    }
}
