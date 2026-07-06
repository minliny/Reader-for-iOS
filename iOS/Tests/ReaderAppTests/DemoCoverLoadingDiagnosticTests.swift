import XCTest
#if canImport(UIKit)
import UIKit
@testable import ReaderApp

final class DemoCoverLoadingDiagnosticTests: XCTestCase {
    func testDemoCoverImageStoreReturnsValidImage() throws {
        let keys = ["long-night", "mystery-lord", "bright-moon", "three-body", "renjian-cihua", "android-notes"]
        for key in keys {
            let image = DemoCoverImageStore.uiImage(forCoverKey: key)
            XCTAssertNotNil(image, "Cover image for key '\(key)' should not be nil")
            if let image {
                XCTAssertGreaterThan(image.size.width, 0, "Cover image for key '\(key)' has zero width")
                XCTAssertGreaterThan(image.size.height, 0, "Cover image for key '\(key)' has zero height")
                print("✓ Cover '\(key)': \(Int(image.size.width))×\(Int(image.size.height))")
            }
        }
    }
}
#endif
