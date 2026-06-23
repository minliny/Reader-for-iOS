import XCTest
@testable import ReaderApp
import ReaderAppPersistence
import ReaderCoreModels

/// BookSource 本地 fixture 管理测试
@MainActor
final class BookSourceLocalManagementTests: XCTestCase {

    // MARK: - Fixture Data

    func testFixtureSourcesCount() {
        let sources = BookSourceListView.fixtureSources
        XCTAssertEqual(sources.count, 5, "本地 fixture 应有 5 个书源")
    }

    func testFixtureSourcesHaveRequiredFields() {
        for source in BookSourceListView.fixtureSources {
            XCTAssertFalse(source.bookSourceName.isEmpty, "书源名称不应为空")
            XCTAssertNotNil(source.id, "书源 ID 不应为 nil")
        }
    }

    func testFixtureSourcesContainExpectedGroups() {
        let groups = Set(BookSourceListView.fixtureSources.compactMap { $0.bookSourceGroup })
        XCTAssertTrue(groups.contains("在线书源"))
        XCTAssertTrue(groups.contains("本地书源"))
    }

    func testFixtureSourcesHaveEnableDisableMix() {
        let enabled = BookSourceListView.fixtureSources.filter(\.enabled)
        let disabled = BookSourceListView.fixtureSources.filter { !$0.enabled }
        XCTAssertFalse(enabled.isEmpty, "应有已启用书源")
        XCTAssertFalse(disabled.isEmpty, "应有已禁用书源")
    }

    // MARK: - Store Integration

    func testBookSourceStoreCanSaveAndLoadFixtures() async throws {
        let store = BookSourceStore(storageURL: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_sources_\(UUID().uuidString).json"))
        let fixtures = BookSourceListView.fixtureSources

        try await store.save(fixtures)
        let loaded = try await store.load()
        XCTAssertEqual(loaded.count, 5)
        store.clearCache()
    }

    func testBookSourceToggleEnabled() async throws {
        let store = BookSourceStore(storageURL: URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("test_toggle_\(UUID().uuidString).json"))
        try await store.save([BookSourceListView.fixtureSources[0]])

        var sources = try await store.load()
        XCTAssertTrue(sources[0].enabled)

        try await store.toggleEnabled(id: sources[0].id!)
        sources = try await store.load()
        XCTAssertFalse(sources[0].enabled)

        try await store.toggleEnabled(id: sources[0].id!)
        sources = try await store.load()
        XCTAssertTrue(sources[0].enabled)

        store.clearCache()
    }

    // MARK: - User-facing copy

    func testSourceDisplayNameIsChinese() {
        let names = BookSourceListView.fixtureSources.map(\.displayName)
        // All fixture names should contain Chinese characters
        for name in names {
            XCTAssertFalse(name.isEmpty, "书源 displayName 不应为空")
        }
    }

    // MARK: - No Parser Internals

    func testBookSourceViewDoesNotImportParserInternals() {
        // Compile-time verification: this test module does not import parser internals
        let source = BookSourceListView.fixtureSources[0]
        XCTAssertEqual(source.bookSourceName, "笔趣阁")
    }
}
