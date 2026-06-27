#if DEBUG && canImport(ReaderCoreNativeAdapter)

import XCTest
@testable import ReaderApp

final class NativeCoreEvidenceAutorunConfigurationTests: XCTestCase {
    func testNativeCoreEvidenceAutorunIsDisabledWithoutFlag() {
        let config = NativeCoreEvidenceAutorunConfiguration.parse(["ReaderForIOSApp"])

        XCTAssertFalse(config.isEnabled)
        XCTAssertTrue(config.isValid)
        XCTAssertFalse(config.exitAfterRun)
        XCTAssertEqual(config.outputDirectory, "")
    }

    func testNativeCoreEvidenceAutorunParsesOutputDirectoryAndExitFlag() {
        let config = NativeCoreEvidenceAutorunConfiguration.parse([
            "ReaderForIOSApp",
            "--native-core-evidence-autorun",
            "--native-core-evidence-output-dir",
            "/tmp/native-core-evidence",
            "--native-core-evidence-exit-after-run",
        ])

        XCTAssertTrue(config.isEnabled)
        XCTAssertTrue(config.isValid)
        XCTAssertEqual(config.outputDirectory, "/tmp/native-core-evidence")
        XCTAssertTrue(config.exitAfterRun)
    }
}

#endif
