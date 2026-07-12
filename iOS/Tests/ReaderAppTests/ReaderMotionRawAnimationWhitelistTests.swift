import XCTest
import Foundation
@testable import ReaderApp

/// P0/M3 第三阶段：raw animation lint 白名单与脚本闭环验证。
///
/// 这些测试不跑 lint 脚本本身（那是 shell），而是验证白名单文件的格式正确性、
/// 以及白名单中每一条都对应实际存在的裸调用点（防止白名单腐烂）。
@MainActor
final class ReaderMotionRawAnimationWhitelistTests: XCTestCase {

    // MARK: - 白名单文件格式

    /// 通过 `#filePath` 推导 repo root，避免依赖 `currentDirectoryPath`
    /// （后者在 `swift test --package-path iOS` 下返回 iOS 包目录，而非 repo root）。
    private static let whitelistURL: URL = {
        // 本文件位于 <repo>/iOS/Tests/ReaderAppTests/ReaderMotionRawAnimationWhitelistTests.swift
        // 向上 4 级（filename + ReaderAppTests + Tests + iOS）即 repo root
        let testFile = URL(fileURLWithPath: #filePath)
        let repoRoot = testFile
            .deletingLastPathComponent()  // 去掉文件名 → ReaderAppTests
            .deletingLastPathComponent()  // ReaderAppTests → Tests
            .deletingLastPathComponent()  // Tests → iOS
            .deletingLastPathComponent()  // iOS → repo root
        return repoRoot
            .appendingPathComponent("scripts")
            .appendingPathComponent("ios_raw_animation_whitelist.txt")
    }()

    func testWhitelistFileExists() throws {
        let url = Self.whitelistURL
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path),
                      "白名单文件必须存在：\(url.path)")
    }

    func testWhitelistFileHasExpectedEntries() throws {
        let url = Self.whitelistURL
        let content = try String(contentsOf: url, encoding: .utf8)
        let entries = content.split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        XCTAssertGreaterThanOrEqual(entries.count, 12,
                                    "白名单至少应保留 12 条 DemoPrimitives 连续/原语动画")
    }

    func testWhitelistEntriesHaveValidFormat() throws {
        let url = Self.whitelistURL
        let content = try String(contentsOf: url, encoding: .utf8)
        let entries = content.split(separator: "\n")
            .map { String($0) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }

        for entry in entries {
            // 格式：path:line:reason
            let parts = entry.split(separator: ":", maxSplits: 2)
            XCTAssertEqual(parts.count, 3,
                           "白名单每行必须是 path:line:reason 格式，实际：\(entry)")
            if parts.count == 3 {
                let path = String(parts[0])
                let lineStr = String(parts[1])
                let reason = String(parts[2])

                XCTAssertFalse(path.isEmpty, "path 不能为空：\(entry)")
                XCTAssertNotNil(Int(lineStr), "line 必须是数字：\(entry)")
                XCTAssertFalse(reason.isEmpty, "reason 不能为空：\(entry)")
            }
        }
    }

    // MARK: - 关键白名单条目存在性

    func testWhitelistDoesNotContainReaderViewAfterDirectResolverMigration() throws {
        let url = Self.whitelistURL
        let content = try String(contentsOf: url, encoding: .utf8)
        XCTAssertFalse(content.contains("iOS/Features/Reader/ReaderView.swift:"),
                       "ReaderView 已在 animation boundary 直接调用 ReaderMotionAdapter，不应再通过白名单逃逸")
    }

    func testWhitelistContainsDemoPrimitivesEntries() throws {
        let url = Self.whitelistURL
        let content = try String(contentsOf: url, encoding: .utf8)
        // DemoPrimitives 至少应有 12 条白名单
        let demoPrimitivesEntries = content.split(separator: "\n")
            .map { String($0) }
            .filter { $0.contains("iOS/App/Components/DemoPrimitives.swift:") && !$0.hasPrefix("#") }
        XCTAssertGreaterThanOrEqual(demoPrimitivesEntries.count, 12,
                                    "白名单至少应有 12 条 DemoPrimitives 条目，实际：\(demoPrimitivesEntries.count)")
    }

    // MARK: - lint 脚本存在性

    func testLintScriptExists() {
        let scriptURL = Self.whitelistURL
            .deletingLastPathComponent()
            .appendingPathComponent("check_ios_raw_animation.sh")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scriptURL.path),
                      "lint 脚本必须存在：\(scriptURL.path)")
    }
}
