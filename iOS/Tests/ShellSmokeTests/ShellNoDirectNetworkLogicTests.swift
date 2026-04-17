import XCTest
import Foundation

final class ShellNoDirectNetworkLogicTests: XCTestCase {
    func testDefaultServicesContainNoDirectNetworkStatusOrFailureMapping() throws {
        let root = repositoryRootURL()
        let files = [
            "iOS/CoreIntegration/DefaultSearchService.swift",
            "iOS/CoreIntegration/DefaultTOCService.swift",
            "iOS/CoreIntegration/DefaultContentService.swift"
        ]

        let bannedNeedles = [
            "httpClient.send",
            "statusCode >=",
            "statusCode <",
            "ReaderError.network(",
            "SEARCH_FAILED",
            "TOC_FAILED",
            "CONTENT_FAILED"
        ]

        var violations: [String] = []
        for relative in files {
            let url = root.appendingPathComponent(relative)
            let content = try String(contentsOf: url, encoding: .utf8)
            for needle in bannedNeedles where content.contains(needle) {
                violations.append("\(relative):\(needle)")
            }
        }

        XCTAssertTrue(
            violations.isEmpty,
            "Shell must not contain direct network/status/failure mapping logic. Violations: \(violations)"
        )
    }
}

private func repositoryRootURL() -> URL {
    URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}
