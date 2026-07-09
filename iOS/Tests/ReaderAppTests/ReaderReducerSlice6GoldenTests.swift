import XCTest
@testable import ReaderApp
import ReaderUIContract

/// Slice 6 Golden Tests — 同步/冲突/离线/设置/about/app-shell
@MainActor
final class ReaderReducerSlice6GoldenTests: XCTestCase {

    // MARK: - Golden: ViewStateComponentFactory — 同步/设置 RouteId 派生

    func testGolden_viewState_components_syncBackup() {
        let components = ViewStateComponentFactory.components(for: .syncBackup)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .syncBackupPage)
    }

    func testGolden_viewState_components_webdavConfig_usesSyncBackupPage() {
        let components = ViewStateComponentFactory.components(for: .webdavConfig)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .syncBackupPage)
    }

    func testGolden_viewState_components_syncError() {
        let components = ViewStateComponentFactory.components(for: .syncError)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .syncErrorPage)
    }

    func testGolden_viewState_components_syncSettingsEntry() {
        let components = ViewStateComponentFactory.components(for: .syncSettingsEntry)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .syncSettingsEntryPage)
    }

    func testGolden_viewState_components_restoreConflict() {
        let components = ViewStateComponentFactory.components(for: .restoreConflict)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .restoreConflictPage)
    }

    func testGolden_viewState_components_stateOffline_singleComponent() {
        let components = ViewStateComponentFactory.components(for: .stateOffline)
        XCTAssertEqual(components.count, 1)
        XCTAssertEqual(components[0].type, .offline)
    }

    func testGolden_viewState_components_offlineState() {
        let components = ViewStateComponentFactory.components(for: .offlineState)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .offlineStatePage)
    }

    func testGolden_viewState_components_settings() {
        let components = ViewStateComponentFactory.components(for: .settings)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .settingsHomePage)
        XCTAssertEqual(components[2].type, .bottomNav)
    }

    func testGolden_viewState_components_globalSettings() {
        let components = ViewStateComponentFactory.components(for: .globalSettings)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .globalSettingsPage)
    }

    func testGolden_viewState_components_settingsGeneral() {
        let components = ViewStateComponentFactory.components(for: .settingsGeneral)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .settingsGeneralPage)
    }

    func testGolden_viewState_components_readingSettingsEntry() {
        let components = ViewStateComponentFactory.components(for: .readingSettingsEntry)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .readingSettingsEntryPage)
    }

    func testGolden_viewState_components_backupSettings() {
        let components = ViewStateComponentFactory.components(for: .backupSettings)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .backupSettingsPage)
    }

    func testGolden_viewState_components_bookshelfSearchSettings() {
        let components = ViewStateComponentFactory.components(for: .bookshelfSearchSettings)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .bookshelfSearchSettingsPage)
    }

    func testGolden_viewState_components_appShell() {
        let components = ViewStateComponentFactory.components(for: .appShell)
        XCTAssertEqual(components.count, 3)
        XCTAssertEqual(components[0].type, .appTopBar)
        XCTAssertEqual(components[1].type, .appShellStructure)
        XCTAssertEqual(components[2].type, .bottomNav)
    }

    func testGolden_viewState_components_about_usesFeedbackPage() {
        let components = ViewStateComponentFactory.components(for: .about)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .aboutFeedbackPage)
    }

    func testGolden_viewState_components_aboutFeedback_usesFeedbackPage() {
        let components = ViewStateComponentFactory.components(for: .aboutFeedback)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .aboutFeedbackPage)
    }

    func testGolden_viewState_components_aboutVersion() {
        let components = ViewStateComponentFactory.components(for: .aboutVersion)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0].type, .backTopBar)
        XCTAssertEqual(components[1].type, .aboutVersionPage)
    }

    // MARK: - Golden: ComponentRegistry.registerSlice6Components() 注册覆盖

    func testGolden_componentRegistry_registerSlice6_allTypesRegistered() {
        ComponentRegistry.reset()
        ComponentRegistry.registerSlice6Components()

        XCTAssertTrue(ComponentRegistry.isRegistered(.loading))
        XCTAssertTrue(ComponentRegistry.isRegistered(.appShellStructure))
        XCTAssertTrue(ComponentRegistry.isRegistered(.offline))
        XCTAssertTrue(ComponentRegistry.isRegistered(.offlineStatePage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.settingsHomePage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.globalSettingsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.settingsGeneralPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.readingSettingsEntryPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.backupSettingsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.bookshelfSearchSettingsPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.syncBackupPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.syncErrorPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.syncSettingsEntryPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.restoreConflictPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.aboutVersionPage))
        XCTAssertTrue(ComponentRegistry.isRegistered(.aboutFeedbackPage))
    }

    func testGolden_componentRegistry_registerSlice6_countIs16() {
        ComponentRegistry.reset()
        let before = ComponentRegistry.registeredCount
        ComponentRegistry.registerSlice6Components()
        let after = ComponentRegistry.registeredCount
        XCTAssertEqual(after - before, 16)
    }

    // MARK: - Golden: ReaderReducer 设置/about 事件 stub

    func testGolden_reducer_settingsSyncOpen_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .settings_sync_open))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_settingsAboutOpen_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .settings_about_open))
        XCTAssertEqual(nav.activeSession, .none)
    }

    func testGolden_reducer_settingsCacheClear_doesNotChangeNavigationState() {
        let nav = AppNavigationState()
        let reducer = ReaderReducer(navigationState: nav)
        reducer.dispatch(UiEvent(type: .settings_cache_clear))
        XCTAssertEqual(nav.activeSession, .none)
    }
}
