#!/bin/bash
set -e

cat << 'TEST_EOF' > /workspace/iOS/Tests/ShellSmokeTests/ShellNoDirectNetworkLogicTests.swift
import XCTest
import Foundation

final class ShellNoDirectNetworkLogicTests: XCTestCase {
    func testDefaultServicesAreDeleted() throws {
        let root = repositoryRootURL()
        let files = [
            "iOS/CoreIntegration/DefaultSearchService.swift",
            "iOS/CoreIntegration/DefaultTOCService.swift",
            "iOS/CoreIntegration/DefaultContentService.swift"
        ]

        for relative in files {
            let url = root.appendingPathComponent(relative)
            XCTAssertFalse(
                FileManager.default.fileExists(atPath: url.path),
                "\(relative) MUST be physically deleted per GATE-CORE-FACADE-ARCH."
            )
        }
    }

    func testReadingFlowCoordinatorDependsOnlyOnFacade() throws {
        let root = repositoryRootURL()
        let coordinatorPath = root.appendingPathComponent("iOS/CoreIntegration/ReadingFlowCoordinator.swift")
        let content = try String(contentsOf: coordinatorPath, encoding: .utf8)

        XCTAssertTrue(content.contains("public let readingFlowFacade: ReadingFlowFacade"), "Coordinator MUST depend on ReadingFlowFacade.")
        XCTAssertFalse(content.contains("SearchService"), "Coordinator MUST NOT depend on SearchService.")
        XCTAssertFalse(content.contains("TOCService"), "Coordinator MUST NOT depend on TOCService.")
        XCTAssertFalse(content.contains("ContentService"), "Coordinator MUST NOT depend on ContentService.")
    }
}

private func repositoryRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
TEST_EOF
