// GENERATED FILE — DO NOT EDIT.
// Generator: scripts/generate-theme-tokens.mjs
// Input: theme/registry.json  17339c9c8d876989575894e4a1f3c5a6b229cf72748d6398963c681820bda1df
// Values are packed ARGB (0xAARRGGBB); SwiftUI converts with Color(.sRGB,
// red:green:blue:opacity:) helpers below, so no UIKit/SwiftUI import is needed.
import Foundation

/// Every app color role in theme/registry.json (531), day + night.
public enum ReaderAppRole: String, CaseIterable, Sendable {
    case tokAccent = "TOK_ACCENT"
    case tokActionDivider = "TOK_ACTION_DIVIDER"
    case tokBorder = "TOK_BORDER"
    case tokBottomBg = "TOK_BOTTOM_BG"
    case tokCardBg = "TOK_CARD_BG"
    case tokCardBgHi = "TOK_CARD_BG_HI"
    case tokChapterDivider = "TOK_CHAPTER_DIVIDER"
    case tokControlInk = "TOK_CONTROL_INK"
    case tokDanger = "TOK_DANGER"
    case tokDownloadDanger = "TOK_DOWNLOAD_DANGER"
    case tokDownloadGreen = "TOK_DOWNLOAD_GREEN"
    case tokDownloadGreenInk = "TOK_DOWNLOAD_GREEN_INK"
    case tokDownloadInk = "TOK_DOWNLOAD_INK"
    case tokDownloadLine = "TOK_DOWNLOAD_LINE"
    case tokDownloadMuted = "TOK_DOWNLOAD_MUTED"
    case tokDownloadPaper = "TOK_DOWNLOAD_PAPER"
    case tokDownloadScrim = "TOK_DOWNLOAD_SCRIM"
    case tokDownloadShadow = "TOK_DOWNLOAD_SHADOW"
    case tokDownloadSoft = "TOK_DOWNLOAD_SOFT"
    case tokDownloadSoftGreen = "TOK_DOWNLOAD_SOFT_GREEN"
    case tokDownloadSurface = "TOK_DOWNLOAD_SURFACE"
    case tokFieldSurface = "TOK_FIELD_SURFACE"
    case tokGreen = "TOK_GREEN"
    case tokInk = "TOK_INK"
    case tokLine = "TOK_LINE"
    case tokLineHard = "TOK_LINE_HARD"
    case tokLineStrong = "TOK_LINE_STRONG"
    case tokMessageBorder = "TOK_MESSAGE_BORDER"
    case tokMessageDanger = "TOK_MESSAGE_DANGER"
    case tokMessageFeedback = "TOK_MESSAGE_FEEDBACK"
    case tokMessageFeedbackBorder = "TOK_MESSAGE_FEEDBACK_BORDER"
    case tokMessageFeedbackInk = "TOK_MESSAGE_FEEDBACK_INK"
    case tokMessageFeedbackMark = "TOK_MESSAGE_FEEDBACK_MARK"
    case tokMessageFeedbackMarkInk = "TOK_MESSAGE_FEEDBACK_MARK_INK"
    case tokMessageInk = "TOK_MESSAGE_INK"
    case tokMessageMuted = "TOK_MESSAGE_MUTED"
    case tokMessageNotice = "TOK_MESSAGE_NOTICE"
    case tokMessageNoticeInk = "TOK_MESSAGE_NOTICE_INK"
    case tokMessageSoft = "TOK_MESSAGE_SOFT"
    case tokMessageSoftInk = "TOK_MESSAGE_SOFT_INK"
    case tokMessageSurface = "TOK_MESSAGE_SURFACE"
    case tokMessageTag = "TOK_MESSAGE_TAG"
    case tokMetaBg = "TOK_META_BG"
    case tokMuted = "TOK_MUTED"
    case tokOnPrimary = "TOK_ON_PRIMARY"
    case tokPaper = "TOK_PAPER"
    case tokPrimaryBg = "TOK_PRIMARY_BG"
    case tokPrimaryBorder = "TOK_PRIMARY_BORDER"
    case tokPrimaryDark = "TOK_PRIMARY_DARK"
    case tokPrimaryGradientStart = "TOK_PRIMARY_GRADIENT_START"
    case tokPrimarySoft = "TOK_PRIMARY_SOFT"
    case tokPrimaryStrong = "TOK_PRIMARY_STRONG"
    case tokPrimaryText = "TOK_PRIMARY_TEXT"
    case tokReadActiveSoft = "TOK_READ_ACTIVE_SOFT"
    case tokReadCardEmphasis = "TOK_READ_CARD_EMPHASIS"
    case tokReadDisabledBg = "TOK_READ_DISABLED_BG"
    case tokReadElevated = "TOK_READ_ELEVATED"
    case tokReadHandle = "TOK_READ_HANDLE"
    case tokReadIcon = "TOK_READ_ICON"
    case tokReadInk = "TOK_READ_INK"
    case tokReadMuted = "TOK_READ_MUTED"
    case tokReadPrimary = "TOK_READ_PRIMARY"
    case tokReadSurface = "TOK_READ_SURFACE"
    case tokReadUnread = "TOK_READ_UNREAD"
    case tokRowDivider = "TOK_ROW_DIVIDER"
    case tokSettingActionBg = "TOK_SETTING_ACTION_BG"
    case tokSettingDangerIconBg = "TOK_SETTING_DANGER_ICON_BG"
    case tokSettingIconBg = "TOK_SETTING_ICON_BG"
    case tokSsCloseBg = "TOK_SS_CLOSE_BG"
    case tokSsColumnHeaderBg = "TOK_SS_COLUMN_HEADER_BG"
    case tokSsDrawerHandle = "TOK_SS_DRAWER_HANDLE"
    case tokSsDrawerScrim = "TOK_SS_DRAWER_SCRIM"
    case tokSsFooterText = "TOK_SS_FOOTER_TEXT"
    case tokSsMuted = "TOK_SS_MUTED"
    case tokSsProgressBg = "TOK_SS_PROGRESS_BG"
    case tokSsScrollbar = "TOK_SS_SCROLLBAR"
    case tokSsSortPillBg = "TOK_SS_SORT_PILL_BG"
    case tokSsWindowBg = "TOK_SS_WINDOW_BG"
    case tokSsWindowBorder = "TOK_SS_WINDOW_BORDER"
    case tokSurface = "TOK_SURFACE"
    case tokSurfaceElevated = "TOK_SURFACE_ELEVATED"
    case tokSurfaceField = "TOK_SURFACE_FIELD"
    case tokSurfacePanel = "TOK_SURFACE_PANEL"
    case tokSurfacePanelSoft = "TOK_SURFACE_PANEL_SOFT"
    case tokSurfaceSolid = "TOK_SURFACE_SOLID"
    case tokSurfaceSolidOpaque = "TOK_SURFACE_SOLID_OPAQUE"
    case tokSurfaceTranslucent = "TOK_SURFACE_TRANSLUCENT"
    case tokTtsCard = "TOK_TTS_CARD"
    case tokTtsClay = "TOK_TTS_CLAY"
    case tokTtsClayLine = "TOK_TTS_CLAY_LINE"
    case tokTtsClaySoft = "TOK_TTS_CLAY_SOFT"
    case tokTtsField = "TOK_TTS_FIELD"
    case tokTtsInk = "TOK_TTS_INK"
    case tokTtsLine = "TOK_TTS_LINE"
    case tokTtsMuted = "TOK_TTS_MUTED"
    case tokTtsPaper = "TOK_TTS_PAPER"
    case tokTtsPaperEnd = "TOK_TTS_PAPER_END"
    case tokTtsPaperStart = "TOK_TTS_PAPER_START"
    case tokTtsPlayEnd = "TOK_TTS_PLAY_END"
    case tokTtsPlayStart = "TOK_TTS_PLAY_START"
    case tokTtsQuickCard = "TOK_TTS_QUICK_CARD"
    case tokTtsTeal = "TOK_TTS_TEAL"
    case tokTtsTealLine = "TOK_TTS_TEAL_LINE"
    case tokTtsTealSoft = "TOK_TTS_TEAL_SOFT"
    case tokTtsTrack = "TOK_TTS_TRACK"
    case appActionApplyBorder = "app.action.applyBorder"
    case appActionApplyGradientEnd = "app.action.applyGradientEnd"
    case appActionApplyGradientStart = "app.action.applyGradientStart"
    case appActionDestructive = "app.action.destructive"
    case appActionDestructiveSoft = "app.action.destructiveSoft"
    case appActionFill = "app.action.fill"
    case appActionNativeDestructive = "app.action.nativeDestructive"
    case appActionOnDanger = "app.action.onDanger"
    case appActionStop = "app.action.stop"
    case appAppearanceLayoutBorder = "app.appearance.layoutBorder"
    case appAppearanceLayoutCaption = "app.appearance.layoutCaption"
    case appAppearanceLayoutSurface = "app.appearance.layoutSurface"
    case appAppearanceSelectBorder = "app.appearance.selectBorder"
    case appAppearanceSelectFill = "app.appearance.selectFill"
    case appAppearanceSelectOpenFill = "app.appearance.selectOpenFill"
    case appAppearanceSelectSelected = "app.appearance.selectSelected"
    case appAppearanceSelectSurface = "app.appearance.selectSurface"
    case appBookmarkEmptyAction = "app.bookmark.emptyAction"
    case appBookmarkExcerptAccent = "app.bookmark.excerptAccent"
    case appBookshelfSheetSurface = "app.bookshelf.sheetSurface"
    case appBorderContentCard = "app.border.contentCard"
    case appBorderControl = "app.border.control"
    case appBorderFilter = "app.border.filter"
    case appBorderMenu = "app.border.menu"
    case appBorderMenuDivider = "app.border.menuDivider"
    case appBorderModalHighlight = "app.border.modalHighlight"
    case appBorderReaderConfig = "app.border.readerConfig"
    case appBorderReaderConfigSoft = "app.border.readerConfigSoft"
    case appBorderSearchField = "app.border.searchField"
    case appBorderSourceGroup = "app.border.sourceGroup"
    case appBorderStatusCard = "app.border.statusCard"
    case appBorderStepper = "app.border.stepper"
    case appChromeRaisedShadowAmbient = "app.chrome.raisedShadowAmbient"
    case appChromeRaisedShadowContact = "app.chrome.raisedShadowContact"
    case appChromeRaisedShadowNear = "app.chrome.raisedShadowNear"
    case appControlItemInk = "app.control.itemInk"
    case appControlOnPrimary = "app.control.onPrimary"
    case appControlPaint172F6373 = "app.control.paint.172F6373"
    case appControlPaint1A2F6373 = "app.control.paint.1A2F6373"
    case appControlPaint212F6373 = "app.control.paint.212F6373"
    case appControlPaint299B8466 = "app.control.paint.299B8466"
    case appControlPaint2E9B8466 = "app.control.paint.2E9B8466"
    case appControlPaint332C25 = "app.control.paint.332C25"
    case appControlPaint33Ffffff = "app.control.paint.33FFFFFF"
    case appControlPaint382F2314 = "app.control.paint.382F2314"
    case appControlPaint472F6373 = "app.control.paint.472F6373"
    case appControlPaint4D2F6373 = "app.control.paint.4D2F6373"
    case appControlPaint5B5046 = "app.control.paint.5B5046"
    case appControlPaint5C2F6373 = "app.control.paint.5C2F6373"
    case appControlPaint66B4A697 = "app.control.paint.66B4A697"
    case appControlPaint8C3D36 = "app.control.paint.8C3D36"
    case appControlPaint99Fff8Ef = "app.control.paint.99FFF8EF"
    case appControlPaint99Ffffff = "app.control.paint.99FFFFFF"
    case appControlPaintB4A697 = "app.control.paint.B4A697"
    case appControlPaintC6Bfb2 = "app.control.paint.C6BFB2"
    case appControlPaintF6Ecdd = "app.control.paint.F6ECDD"
    case appControlPaintFffaf4 = "app.control.paint.FFFAF4"
    case appCoverFallbackMask = "app.cover.fallbackMask"
    case appCoverPlaceholder = "app.cover.placeholder"
    case appDetailFooterFadeSoft = "app.detail.footerFadeSoft"
    case appDetailFooterFadeSolid = "app.detail.footerFadeSolid"
    case appDetailFooterFadeTransparent = "app.detail.footerFadeTransparent"
    case appDetailSummaryFadeTransparent = "app.detail.summaryFadeTransparent"
    case appDirectoryEdgeFade = "app.directory.edgeFade"
    case appDirectoryEdgeFadeTransparent = "app.directory.edgeFadeTransparent"
    case appDiscoverCategorySurface = "app.discover.categorySurface"
    case appDiscoverSourceBorder = "app.discover.sourceBorder"
    case appDiscoverSourceIconSurface = "app.discover.sourceIconSurface"
    case appFeedActionSoft = "app.feed.actionSoft"
    case appFeedDisabledSurface = "app.feed.disabledSurface"
    case appFeedEnabledSurface = "app.feed.enabledSurface"
    case appFeedErrorSurface = "app.feed.errorSurface"
    case appFeedErrorText = "app.feed.errorText"
    case appFeedPillBorder = "app.feed.pillBorder"
    case appFeedPillSurface = "app.feed.pillSurface"
    case appFeedRefreshBorder = "app.feed.refreshBorder"
    case appFeedUnreadDot = "app.feed.unreadDot"
    case appHeaderVeilBorder = "app.header.veilBorder"
    case appHeaderVeilSurface = "app.header.veilSurface"
    case appHeaderVeilSurfaceScrolled = "app.header.veilSurfaceScrolled"
    case appIconBookDetailBack1F1B17 = "app.icon.book_detail_back.1F1B17"
    case appIconBookDetailDirectory1F3528 = "app.icon.book_detail_directory.1F3528"
    case appIconBookshelfCompassActiveFffaf4 = "app.icon.bookshelf_compass_active.FFFAF4"
    case appIconBookshelfCompassOutline756F69 = "app.icon.bookshelf_compass_outline.756F69"
    case appIconBookshelfEmptyLibrary1F1B17 = "app.icon.bookshelf_empty_library.1F1B17"
    case appIconBookshelfFilter756F69 = "app.icon.bookshelf_filter.756F69"
    case appIconBookshelfFilterActive2D4A3E = "app.icon.bookshelf_filter_active.2D4A3E"
    case appIconBookshelfGrid2D4A3E = "app.icon.bookshelf_grid.2D4A3E"
    case appIconBookshelfGridOutline756F69 = "app.icon.bookshelf_grid_outline.756F69"
    case appIconBookshelfLibraryActiveFffaf4 = "app.icon.bookshelf_library_active.FFFAF4"
    case appIconBookshelfLibraryOutline756F69 = "app.icon.bookshelf_library_outline.756F69"
    case appIconBookshelfList756F69 = "app.icon.bookshelf_list.756F69"
    case appIconBookshelfListActive2D4A3E = "app.icon.bookshelf_list_active.2D4A3E"
    case appIconBookshelfMore1F1B17 = "app.icon.bookshelf_more.1F1B17"
    case appIconBookshelfMoreF8F4Ec = "app.icon.bookshelf_more.F8F4EC"
    case appIconBookshelfMoreBatch1F1B17 = "app.icon.bookshelf_more_batch.1F1B17"
    case appIconBookshelfMoreDownload1F1B17 = "app.icon.bookshelf_more_download.1F1B17"
    case appIconBookshelfMoreImport1F1B17 = "app.icon.bookshelf_more_import.1F1B17"
    case appIconBookshelfMoreSettings1F1B17 = "app.icon.bookshelf_more_settings.1F1B17"
    case appIconBookshelfMoreUpdate1F1B17 = "app.icon.bookshelf_more_update.1F1B17"
    case appIconBookshelfMultiselectTrashD7473E = "app.icon.bookshelf_multiselect_trash.D7473E"
    case appIconBookshelfRssActiveFffaf4 = "app.icon.bookshelf_rss_active.FFFAF4"
    case appIconBookshelfRssOutline756F69 = "app.icon.bookshelf_rss_outline.756F69"
    case appIconBookshelfSearch1F1B17 = "app.icon.bookshelf_search.1F1B17"
    case appIconBookshelfSettings756F69 = "app.icon.bookshelf_settings.756F69"
    case appIconBookshelfSettingsActiveFffaf4 = "app.icon.bookshelf_settings_active.FFFAF4"
    case appIconBookshelfSettingsOutline756F69 = "app.icon.bookshelf_settings_outline.756F69"
    case appIconDiscoverApplyFfffff = "app.icon.discover_apply.FFFFFF"
    case appIconDiscoverFilter3F372F = "app.icon.discover_filter.3F372F"
    case appIconDiscoverFilterChevron3F372F = "app.icon.discover_filter_chevron.3F372F"
    case appIconDiscoverRefresh1F1B17 = "app.icon.discover_refresh.1F1B17"
    case appIconDiscoverSourceChevron1F1B17 = "app.icon.discover_source_chevron.1F1B17"
    case appIconDiscoverSourceStack1F3528 = "app.icon.discover_source_stack.1F3528"
    case appIconImportCancel756F69 = "app.icon.import_cancel.756F69"
    case appIconImportChooseFileFffaf4 = "app.icon.import_choose_file.FFFAF4"
    case appIconImportDoc756F69 = "app.icon.import_doc.756F69"
    case appIconImportDoneFffaf4 = "app.icon.import_done.FFFAF4"
    case appIconImportFailureC0392B = "app.icon.import_failure.C0392B"
    case appIconImportInfo756F69 = "app.icon.import_info.756F69"
    case appIconImportRefresh2D4A3E = "app.icon.import_refresh.2D4A3E"
    case appIconImportSelectSystem2D4A3E = "app.icon.import_select_system.2D4A3E"
    case appIconImportSuccess2D4A3E = "app.icon.import_success.2D4A3E"
    case appIconImportSummaryC0392B = "app.icon.import_summary.C0392B"
    case appIconImportingHaloE8E2D9 = "app.icon.importing_halo.E8E2D9"
    case appIconImportingHaloF8F4Ec = "app.icon.importing_halo.F8F4EC"
    case appIconImportingSpinnerArc2D4A3E = "app.icon.importing_spinner_arc.2D4A3E"
    case appIconImportingSpinnerTrackE8E2D9 = "app.icon.importing_spinner_track.E8E2D9"
    case appIconRcAutopage332C25 = "app.icon.rc_autopage.332C25"
    case appIconRcChevronLeft4D463F = "app.icon.rc_chevron_left.4D463F"
    case appIconRcChevronRight4D463F = "app.icon.rc_chevron_right.4D463F"
    case appIconRcDots1F1B17 = "app.icon.rc_dots.1F1B17"
    case appIconRcHeadphones2F6373 = "app.icon.rc_headphones.2F6373"
    case appIconRcList2F6373 = "app.icon.rc_list.2F6373"
    case appIconRcPalette2F6373 = "app.icon.rc_palette.2F6373"
    case appIconRcReplace332C25 = "app.icon.rc_replace.332C25"
    case appIconRcSearch332C25 = "app.icon.rc_search.332C25"
    case appIconRcSettings2F6373 = "app.icon.rc_settings.2F6373"
    case appIconRcSun2F6373 = "app.icon.rc_sun.2F6373"
    case appIconRcSwitchHorizontal1F1B17 = "app.icon.rc_switch_horizontal.1F1B17"
    case appIconReaderAppearanceHeader332C25 = "app.icon.reader_appearance_header.332C25"
    case appIconReaderAppearanceMakeCheck2F6373 = "app.icon.reader_appearance_make_check.2F6373"
    case appIconReaderAppearanceMakeChevron857C70 = "app.icon.reader_appearance_make_chevron.857C70"
    case appIconReaderAppearanceNavActiveFffaf4 = "app.icon.reader_appearance_nav_active.FFFAF4"
    case appIconReaderAutoFullChevronLeft2F6373 = "app.icon.reader_auto_full_chevron_left.2F6373"
    case appIconReaderAutoFullChevronRight2F6373 = "app.icon.reader_auto_full_chevron_right.2F6373"
    case appIconReaderAutoFullClock1F1B17 = "app.icon.reader_auto_full_clock.1F1B17"
    case appIconReaderAutoFullPlayFffaf4 = "app.icon.reader_auto_full_play.FFFAF4"
    case appIconReaderAutoFullStop2F6373 = "app.icon.reader_auto_full_stop.2F6373"
    case appIconReaderAutoStop8C3D36 = "app.icon.reader_auto_stop.8C3D36"
    case appIconReaderChevronDown41484C = "app.icon.reader_chevron_down.41484C"
    case appIconReaderChevronDownPrimary2F6373 = "app.icon.reader_chevron_down_primary.2F6373"
    case appIconReaderChevronRight756F69 = "app.icon.reader_chevron_right.756F69"
    case appIconReaderControlHeaderChevron2F6373 = "app.icon.reader_control_header_chevron.2F6373"
    case appIconReaderControlReplaceBack2F6373 = "app.icon.reader_control_replace_back.2F6373"
    case appIconReaderControlReplaceDelete332C25 = "app.icon.reader_control_replace_delete.332C25"
    case appIconReaderControlReplaceEdit332C25 = "app.icon.reader_control_replace_edit.332C25"
    case appIconReaderControlReplaceExport332C25 = "app.icon.reader_control_replace_export.332C25"
    case appIconReaderControlReplaceHeader332C25 = "app.icon.reader_control_replace_header.332C25"
    case appIconReaderControlReplaceImport332C25 = "app.icon.reader_control_replace_import.332C25"
    case appIconReaderDirectoryBack332C25 = "app.icon.reader_directory_back.332C25"
    case appIconReaderDirectoryBottom2F6373 = "app.icon.reader_directory_bottom.2F6373"
    case appIconReaderDirectoryDirectory332C25 = "app.icon.reader_directory_directory.332C25"
    case appIconReaderDirectoryInputSearch5B5046 = "app.icon.reader_directory_input_search.5B5046"
    case appIconReaderDirectoryListActiveFffaf4 = "app.icon.reader_directory_list_active.FFFAF4"
    case appIconReaderDirectoryMarkerBookmark5B5046 = "app.icon.reader_directory_marker_bookmark.5B5046"
    case appIconReaderDirectoryMarkerBookmarkActive2F6373 = "app.icon.reader_directory_marker_bookmark_active.2F6373"
    case appIconReaderDirectoryMarkerCheck2F6373 = "app.icon.reader_directory_marker_check.2F6373"
    case appIconReaderDirectoryMarkerDownload5B5046 = "app.icon.reader_directory_marker_download.5B5046"
    case appIconReaderDirectoryMore332C25 = "app.icon.reader_directory_more.332C25"
    case appIconReaderDirectorySearch2F6373 = "app.icon.reader_directory_search.2F6373"
    case appIconReaderDirectorySortAscending2F6373 = "app.icon.reader_directory_sort_ascending.2F6373"
    case appIconReaderDirectorySortDescending2F6373 = "app.icon.reader_directory_sort_descending.2F6373"
    case appIconReaderDirectorySwitch332C25 = "app.icon.reader_directory_switch.332C25"
    case appIconReaderDirectoryTop2F6373 = "app.icon.reader_directory_top.2F6373"
    case appIconReaderPageBookmarkFilled2F6373 = "app.icon.reader_page_bookmark_filled.2F6373"
    case appIconReaderQuickBack2F6373 = "app.icon.reader_quick_back.2F6373"
    case appIconReaderReplaceClose2F6373 = "app.icon.reader_replace_close.2F6373"
    case appIconReaderReplaceManageFffaf4 = "app.icon.reader_replace_manage.FFFAF4"
    case appIconReaderReplacePreview332C25 = "app.icon.reader_replace_preview.332C25"
    case appIconReaderSessionPauseFffaf4 = "app.icon.reader_session_pause.FFFAF4"
    case appIconReaderSessionPlayFffaf4 = "app.icon.reader_session_play.FFFAF4"
    case appIconReaderSettingsHeader332C25 = "app.icon.reader_settings_header.332C25"
    case appIconReaderSettingsNavActiveFffaf4 = "app.icon.reader_settings_nav_active.FFFAF4"
    case appIconReaderTtsClock2F6373 = "app.icon.reader_tts_clock.2F6373"
    case appIconReaderTtsHeader332C25 = "app.icon.reader_tts_header.332C25"
    case appIconReaderTtsHeadphones2F6373 = "app.icon.reader_tts_headphones.2F6373"
    case appIconReaderTtsMakeClose5B5046 = "app.icon.reader_tts_make_close.5B5046"
    case appIconReaderTtsMakeEngineCheck2F6373 = "app.icon.reader_tts_make_engine_check.2F6373"
    case appIconReaderTtsMakeEngineCheckFffcf8 = "app.icon.reader_tts_make_engine_check.FFFCF8"
    case appIconReaderTtsMakeMinus2F6373 = "app.icon.reader_tts_make_minus.2F6373"
    case appIconReaderTtsMakeNext332C25 = "app.icon.reader_tts_make_next.332C25"
    case appIconReaderTtsMakeNextQuick4D463F = "app.icon.reader_tts_make_next_quick.4D463F"
    case appIconReaderTtsMakePauseFffaf4 = "app.icon.reader_tts_make_pause.FFFAF4"
    case appIconReaderTtsMakePlayFffaf4 = "app.icon.reader_tts_make_play.FFFAF4"
    case appIconReaderTtsMakePlus2F6373 = "app.icon.reader_tts_make_plus.2F6373"
    case appIconReaderTtsMakePrevious332C25 = "app.icon.reader_tts_make_previous.332C25"
    case appIconReaderTtsMakePreviousQuick4D463F = "app.icon.reader_tts_make_previous_quick.4D463F"
    case appIconReaderTtsMakeStopA8543A = "app.icon.reader_tts_make_stop.A8543A"
    case appIconReaderTtsNavActiveFffaf4 = "app.icon.reader_tts_nav_active.FFFAF4"
    case appIconReaderTtsNext332C25 = "app.icon.reader_tts_next.332C25"
    case appIconReaderTtsOnlineEngine756F69 = "app.icon.reader_tts_online_engine.756F69"
    case appIconReaderTtsPrevious332C25 = "app.icon.reader_tts_previous.332C25"
    case appIconReaderTtsRate2F6373 = "app.icon.reader_tts_rate.2F6373"
    case appIconReaderTtsSpeedThumb2F6373 = "app.icon.reader_tts_speed_thumb.2F6373"
    case appIconReaderTtsSpeedThumbFffaf4 = "app.icon.reader_tts_speed_thumb.FFFAF4"
    case appIconReaderTtsStopFffaf4 = "app.icon.reader_tts_stop.FFFAF4"
    case appIconReaderTtsSystemEngine1F3528 = "app.icon.reader_tts_system_engine.1F3528"
    case appIconReaderTtsTimerCycle2F6373 = "app.icon.reader_tts_timer_cycle.2F6373"
    case appIconRssAdd2D4A3E = "app.icon.rss_add.2D4A3E"
    case appIconRssBookmark756F69 = "app.icon.rss_bookmark.756F69"
    case appIconRssBookmarkActive1F3528 = "app.icon.rss_bookmark_active.1F3528"
    case appIconRssEdit3F372F = "app.icon.rss_edit.3F372F"
    case appIconRssEmpty1F1B17 = "app.icon.rss_empty.1F1B17"
    case appIconRssError1F1B17 = "app.icon.rss_error.1F1B17"
    case appIconRssExternal3F372F = "app.icon.rss_external.3F372F"
    case appIconRssFilter3F372F = "app.icon.rss_filter.3F372F"
    case appIconRssFilterChevron3F372F = "app.icon.rss_filter_chevron.3F372F"
    case appIconRssItemChevron1F1B17 = "app.icon.rss_item_chevron.1F1B17"
    case appIconRssLink3F372F = "app.icon.rss_link.3F372F"
    case appIconRssManage756F69 = "app.icon.rss_manage.756F69"
    case appIconRssManageDeleteAb2E28 = "app.icon.rss_manage_delete.AB2E28"
    case appIconRssManageEdit1F1B17 = "app.icon.rss_manage_edit.1F1B17"
    case appIconRssManageViewAll1F1B17 = "app.icon.rss_manage_view_all.1F1B17"
    case appIconRssRefresh1F3528 = "app.icon.rss_refresh.1F3528"
    case appIconRssSource1F3528 = "app.icon.rss_source.1F3528"
    case appIconRssViewAll1F3528 = "app.icon.rss_view_all.1F3528"
    case appIconSearchClear756F69 = "app.icon.search_clear.756F69"
    case appIconSearchEmpty756F69 = "app.icon.search_empty.756F69"
    case appIconSearchEmptyC4Bdb0 = "app.icon.search_empty.C4BDB0"
    case appIconSearchEmptyCcc5B8 = "app.icon.search_empty.CCC5B8"
    case appIconSearchEmptyD4Cec2 = "app.icon.search_empty.D4CEC2"
    case appIconSearchEmptyD8D1C4 = "app.icon.search_empty.D8D1C4"
    case appIconSearchEmptyE0D9Cc = "app.icon.search_empty.E0D9CC"
    case appIconSearchEmptyEae4D8 = "app.icon.search_empty.EAE4D8"
    case appIconSearchEmptyF8F4Ec = "app.icon.search_empty.F8F4EC"
    case appIconSearchError756F69 = "app.icon.search_error.756F69"
    case appIconSearchErrorC1C7Cd = "app.icon.search_error.C1C7CD"
    case appIconSearchErrorF0Ebe1 = "app.icon.search_error.F0EBE1"
    case appIconSearchMag756F69 = "app.icon.search_mag.756F69"
    case appIconSettingsGenAnimation2D4A3E = "app.icon.settings_gen_animation.2D4A3E"
    case appIconSettingsGenBattery2D4A3E = "app.icon.settings_gen_battery.2D4A3E"
    case appIconSettingsGenCache2D4A3E = "app.icon.settings_gen_cache.2D4A3E"
    case appIconSettingsGenCrash2D4A3E = "app.icon.settings_gen_crash.2D4A3E"
    case appIconSettingsGenFile2D4A3E = "app.icon.settings_gen_file.2D4A3E"
    case appIconSettingsGenLanguage2D4A3E = "app.icon.settings_gen_language.2D4A3E"
    case appIconSettingsGenNavigation2D4A3E = "app.icon.settings_gen_navigation.2D4A3E"
    case appIconSettingsGenNotification756F69 = "app.icon.settings_gen_notification.756F69"
    case appIconSettingsGenRefresh2D4A3E = "app.icon.settings_gen_refresh.2D4A3E"
    case appIconSettingsGenStartup2D4A3E = "app.icon.settings_gen_startup.2D4A3E"
    case appIconSettingsGenTapTop2D4A3E = "app.icon.settings_gen_tap_top.2D4A3E"
    case appIconSettingsGenTheme2D4A3E = "app.icon.settings_gen_theme.2D4A3E"
    case appIconSettingsResetDefaultsD62222 = "app.icon.settings_reset_defaults.D62222"
    case appIconSettingsRowAbout2D4A3E = "app.icon.settings_row_about.2D4A3E"
    case appIconSettingsRowDownload2D4A3E = "app.icon.settings_row_download.2D4A3E"
    case appIconSettingsRowGeneral2D4A3E = "app.icon.settings_row_general.2D4A3E"
    case appIconSettingsRowShelfSearch2D4A3E = "app.icon.settings_row_shelf_search.2D4A3E"
    case appIconSettingsRowSource2D4A3E = "app.icon.settings_row_source.2D4A3E"
    case appIconSettingsRowSync2D4A3E = "app.icon.settings_row_sync.2D4A3E"
    case appIconSettingsSelectCheck2D4A3E = "app.icon.settings_select_check.2D4A3E"
    case appIconSourceAddFffaf4 = "app.icon.source_add.FFFAF4"
    case appIconSourceGroupChevron5B5046 = "app.icon.source_group_chevron.5B5046"
    case appIconSourceGroupFolder2D4A3E = "app.icon.source_group_folder.2D4A3E"
    case appIconSourceSwitchClose332C25 = "app.icon.source_switch_close.332C25"
    case appIconSyncAccount2D4A3E = "app.icon.sync_account.2D4A3E"
    case appIconSyncBackupPassword2D4A3E = "app.icon.sync_backup_password.2D4A3E"
    case appIconSyncPassword2D4A3E = "app.icon.sync_password.2D4A3E"
    case appIconSyncScopeChevron41484C = "app.icon.sync_scope_chevron.41484C"
    case appIconSyncServer2D4A3E = "app.icon.sync_server.2D4A3E"
    case appImportFormatArchive = "app.import.formatArchive"
    case appImportFormatEpub = "app.import.formatEpub"
    case appImportFormatText = "app.import.formatText"
    case appImportSelectedSurface = "app.import.selectedSurface"
    case appImportSeparator = "app.import.separator"
    case appInteractionPress = "app.interaction.press"
    case appNavigationFloatingBorder = "app.navigation.floatingBorder"
    case appNavigationFloatingShadow = "app.navigation.floatingShadow"
    case appNavigationFloatingSurface = "app.navigation.floatingSurface"
    case appReaderAppearanceField = "app.reader.appearanceField"
    case appReaderChoiceHover = "app.reader.choiceHover"
    case appReaderPlaceholder = "app.reader.placeholder"
    case appReaderSecondaryAction = "app.reader.secondaryAction"
    case appReaderTtsField = "app.reader.ttsField"
    case appReaderIslandControlBorder = "app.readerIsland.controlBorder"
    case appReaderIslandControlDisabledBorder = "app.readerIsland.controlDisabledBorder"
    case appReaderIslandControlDisabledInk = "app.readerIsland.controlDisabledInk"
    case appReaderIslandControlDisabledSurface = "app.readerIsland.controlDisabledSurface"
    case appReaderIslandControlInk = "app.readerIsland.controlInk"
    case appReaderIslandControlStopBorder = "app.readerIsland.controlStopBorder"
    case appReaderIslandControlStopSurface = "app.readerIsland.controlStopSurface"
    case appReaderIslandControlSurface = "app.readerIsland.controlSurface"
    case appReplaceInactiveRule = "app.replace.inactiveRule"
    case appReplaceOnToolbarAction = "app.replace.onToolbarAction"
    case appScrimImport = "app.scrim.import"
    case appScrimModal = "app.scrim.modal"
    case appScrimSelect = "app.scrim.select"
    case appScrimWarmModal = "app.scrim.warmModal"
    case appSearchDiscoveredSource = "app.search.discoveredSource"
    case appSearchFailedStatus = "app.search.failedStatus"
    case appSearchFieldElevated = "app.search.fieldElevated"
    case appSearchFieldSolid = "app.search.fieldSolid"
    case appSearchFieldTint = "app.search.fieldTint"
    case appSearchListRule = "app.search.listRule"
    case appSearchOnCoverMeta = "app.search.onCoverMeta"
    case appSearchPanelBorder = "app.search.panelBorder"
    case appSearchPanelShadow = "app.search.panelShadow"
    case appSearchPanelSurface = "app.search.panelSurface"
    case appSearchPartialStatus = "app.search.partialStatus"
    case appSearchPassiveText = "app.search.passiveText"
    case appSearchPlaceholder = "app.search.placeholder"
    case appSearchPlaceholderTranslucent = "app.search.placeholderTranslucent"
    case appSearchResultHint = "app.search.resultHint"
    case appSearchSpinnerOnPrimaryTrack = "app.search.spinnerOnPrimaryTrack"
    case appSearchSpinnerTrack = "app.search.spinnerTrack"
    case appSegmentActiveText = "app.segment.activeText"
    case appSegmentBorder = "app.segment.border"
    case appSegmentInactiveText = "app.segment.inactiveText"
    case appSegmentSelected = "app.segment.selected"
    case appSegmentSurface = "app.segment.surface"
    case appSelectMenuSurface = "app.select.menuSurface"
    case appSelectPanelField = "app.select.panelField"
    case appSelectPanelSolid = "app.select.panelSolid"
    case appSelectSelectedSurface = "app.select.selectedSurface"
    case appSelectSheetHandle = "app.select.sheetHandle"
    case appSelectSourceGroupSelected = "app.select.sourceGroupSelected"
    case appSelectTriggerSurface = "app.select.triggerSurface"
    case appSelectionAccent = "app.selection.accent"
    case appSelectionOnMode = "app.selection.onMode"
    case appSelectionOptionSoft = "app.selection.optionSoft"
    case appSelectionSubtle = "app.selection.subtle"
    case appSessionCapsuleBorder = "app.sessionCapsule.border"
    case appSessionCapsuleInk = "app.sessionCapsule.ink"
    case appSessionCapsuleOnPrimary = "app.sessionCapsule.onPrimary"
    case appSessionCapsuleSurface = "app.sessionCapsule.surface"
    case appShadowControl = "app.shadow.control"
    case appShadowCover = "app.shadow.cover"
    case appShadowDialog = "app.shadow.dialog"
    case appShadowFontSwatch = "app.shadow.fontSwatch"
    case appShadowMenu = "app.shadow.menu"
    case appShadowReaderConfig = "app.shadow.readerConfig"
    case appShadowReaderConfigSecondary = "app.shadow.readerConfigSecondary"
    case appShadowSelect = "app.shadow.select"
    case appShadowSelectPanel = "app.shadow.selectPanel"
    case appShadowSheet = "app.shadow.sheet"
    case appShadowThemeSwatch = "app.shadow.themeSwatch"
    case appSourceSwitchError = "app.sourceSwitch.error"
    case appSourceSwitchGood = "app.sourceSwitch.good"
    case appSourceSwitchLatencyError = "app.sourceSwitch.latencyError"
    case appSourceSwitchSelectedRow = "app.sourceSwitch.selectedRow"
    case appSourceSwitchSlow = "app.sourceSwitch.slow"
    case appSourceUiBorder = "app.sourceUi.border"
    case appSourceUiDanger = "app.sourceUi.danger"
    case appSourceUiDangerSurface = "app.sourceUi.dangerSurface"
    case appSourceUiDivider = "app.sourceUi.divider"
    case appSourceUiFaint = "app.sourceUi.faint"
    case appSourceUiField = "app.sourceUi.field"
    case appSourceUiFooterShadow = "app.sourceUi.footerShadow"
    case appSourceUiHeaderShadow = "app.sourceUi.headerShadow"
    case appSourceUiMuted = "app.sourceUi.muted"
    case appSourceUiOnPrimary = "app.sourceUi.onPrimary"
    case appSourceUiOptionBorder = "app.sourceUi.optionBorder"
    case appSourceUiOverwrite = "app.sourceUi.overwrite"
    case appSourceUiPrimary = "app.sourceUi.primary"
    case appSourceUiSelected = "app.sourceUi.selected"
    case appSourceUiSurface = "app.sourceUi.surface"
    case appSourceUiToggleBorder = "app.sourceUi.toggleBorder"
    case appSourceUiToggleOff = "app.sourceUi.toggleOff"
    case appStatusAvailableDot = "app.status.availableDot"
    case appStatusCheckError = "app.status.checkError"
    case appStatusCheckErrorSoft = "app.status.checkErrorSoft"
    case appStatusCheckWarning = "app.status.checkWarning"
    case appStatusFailureSurface = "app.status.failureSurface"
    case appStatusGood = "app.status.good"
    case appStatusGoodSoft = "app.status.goodSoft"
    case appStatusInfoSoft = "app.status.infoSoft"
    case appStatusMutedDot = "app.status.mutedDot"
    case appStatusMutedSoft = "app.status.mutedSoft"
    case appStatusSealSoft = "app.status.sealSoft"
    case appStatusSuccessSurface = "app.status.successSurface"
    case appStatusWarning = "app.status.warning"
    case appStatusWarningSoft = "app.status.warningSoft"
    case appSurfaceChapterSection = "app.surface.chapterSection"
    case appSurfaceDangerCard = "app.surface.dangerCard"
    case appSurfaceDock = "app.surface.dock"
    case appSurfaceGestureMask = "app.surface.gestureMask"
    case appSurfaceGlass = "app.surface.glass"
    case appSurfaceGlassHeavy = "app.surface.glassHeavy"
    case appSurfaceMenuSolid = "app.surface.menuSolid"
    case appSurfaceReaderConfig = "app.surface.readerConfig"
    case appSurfaceReaderInput = "app.surface.readerInput"
    case appSurfaceSelectGradientEnd = "app.surface.selectGradientEnd"
    case appSurfaceSelectWarm = "app.surface.selectWarm"
    case appSurfaceSyncRow = "app.surface.syncRow"
    case appSurfaceTransparent = "app.surface.transparent"
    case appSurfaceTtsTabs = "app.surface.ttsTabs"
    case appSyncActionSurface = "app.sync.actionSurface"
    case appSyncBadgeSurface = "app.sync.badgeSurface"
    case appSyncGhostBorder = "app.sync.ghostBorder"
    case appSyncGhostSurface = "app.sync.ghostSurface"
    case appTextEmptyHint = "app.text.emptyHint"
    case appTextFeedMeta = "app.text.feedMeta"
    case appTextFeedTab = "app.text.feedTab"
    case appTextFilter = "app.text.filter"
    case appTextHeading = "app.text.heading"
    case appTextOnAccent = "app.text.onAccent"
    case appTextSecondary = "app.text.secondary"
    case appTextSubtle = "app.text.subtle"
    case appTextSummary = "app.text.summary"
    case appTextSyncBadge = "app.text.syncBadge"
    case appTextSyncHeading = "app.text.syncHeading"
    case appTextSyncHint = "app.text.syncHint"
    case appTextSyncMeta = "app.text.syncMeta"
    case appToggleInactiveTrack = "app.toggle.inactiveTrack"
    case appToggleOffTrack = "app.toggle.offTrack"
    case appToggleThumb = "app.toggle.thumb"
    case appTtsError = "app.tts.error"
    case appTtsOffTrack = "app.tts.offTrack"
    case appTtsOnPrimary = "app.tts.onPrimary"
    case appTtsPlayback = "app.tts.playback"
    case appTtsThumb = "app.tts.thumb"
    case appWebAction = "app.web.action"
    case appWebInk = "app.web.ink"
    case appWebMuted = "app.web.muted"
    case appWebStatus = "app.web.status"
    case appWebSurface = "app.web.surface"
    case appWindowBackground = "app.window.background"
    case appWindowForeground = "app.window.foreground"
}

/// ARGB channels split for SwiftUI/UIKit construction.
public struct ReaderThemeColor: Sendable, Equatable {
    public let argb: UInt32
    public init(argb: UInt32) { self.argb = argb }
    public var alpha: Double { Double((argb >> 24) & 0xFF) / 255.0 }
    public var red: Double { Double((argb >> 16) & 0xFF) / 255.0 }
    public var green: Double { Double((argb >> 8) & 0xFF) / 255.0 }
    public var blue: Double { Double(argb & 0xFF) / 255.0 }
}

/// Resolves one role for the requested scheme.
public enum ReaderThemeTokens {
    public static func argb(_ role: ReaderAppRole, night: Bool) -> UInt32 {
        night ? role.night : role.day
    }
    public static func color(_ role: ReaderAppRole, night: Bool) -> ReaderThemeColor {
        ReaderThemeColor(argb: argb(role, night: night))
    }
}

public extension ReaderAppRole {
    /// Day-scheme packed ARGB.
    var day: UInt32 {
        switch self {
        case .tokAccent: return 0xFFB86B2B
        case .tokActionDivider: return 0x295C4F3F
        case .tokBorder: return 0x295C4F3F
        case .tokBottomBg: return 0xFFFBF2EB
        case .tokCardBg: return 0xFFFBF8F2
        case .tokCardBgHi: return 0xFFFBF8F2
        case .tokChapterDivider: return 0x1A5C4F3F
        case .tokControlInk: return 0xFF1D1B18
        case .tokDanger: return 0xFFB83B32
        case .tokDownloadDanger: return 0xFFB83B32
        case .tokDownloadGreen: return 0xFF1F3D31
        case .tokDownloadGreenInk: return 0xFFFAF7F0
        case .tokDownloadInk: return 0xFF1D1B18
        case .tokDownloadLine: return 0x1A5C4F3F
        case .tokDownloadMuted: return 0xFF635D55
        case .tokDownloadPaper: return 0xFFF4EFE6
        case .tokDownloadScrim: return 0x61151715
        case .tokDownloadShadow: return 0x0A2D241A
        case .tokDownloadSoft: return 0xFFEAE3D6
        case .tokDownloadSoftGreen: return 0x171F3D31
        case .tokDownloadSurface: return 0xFFFBF8F2
        case .tokFieldSurface: return 0xFFEAE3D6
        case .tokGreen: return 0xFF1F3D31
        case .tokInk: return 0xFF1D1B18
        case .tokLine: return 0x94867A6E
        case .tokLineHard: return 0x295C4F3F
        case .tokLineStrong: return 0xFF867A6E
        case .tokMessageBorder: return 0xFFE7E4DB
        case .tokMessageDanger: return 0xFFC94835
        case .tokMessageFeedback: return 0xF5294C3E
        case .tokMessageFeedbackBorder: return 0x29294C3E
        case .tokMessageFeedbackInk: return 0xFFF9F6EF
        case .tokMessageFeedbackMark: return 0xFFE7F1EA
        case .tokMessageFeedbackMarkInk: return 0xFF294C3E
        case .tokMessageInk: return 0xFF252A24
        case .tokMessageMuted: return 0xFF74776D
        case .tokMessageNotice: return 0xFF314D3C
        case .tokMessageNoticeInk: return 0xFFFFFDF6
        case .tokMessageSoft: return 0xFFE8EEE7
        case .tokMessageSoftInk: return 0xFF365345
        case .tokMessageSurface: return 0xFFFFFCF7
        case .tokMessageTag: return 0x20FFFFFF
        case .tokMetaBg: return 0xFFF5ECE6
        case .tokMuted: return 0xFF635D55
        case .tokOnPrimary: return 0xFFFAF7F0
        case .tokPaper: return 0xFFF4EFE6
        case .tokPrimaryBg: return 0x171F3D31
        case .tokPrimaryBorder: return 0x471F3D31
        case .tokPrimaryDark: return 0xFF1F3D31
        case .tokPrimaryGradientStart: return 0xFF2A5242
        case .tokPrimarySoft: return 0x171F3D31
        case .tokPrimaryStrong: return 0x471F3D31
        case .tokPrimaryText: return 0xFF1F3D31
        case .tokReadActiveSoft: return 0xFFEBEBE6
        case .tokReadCardEmphasis: return 0xFFF9FAF0
        case .tokReadDisabledBg: return 0xFFF5EFE6
        case .tokReadElevated: return 0xFFFFFCF8
        case .tokReadHandle: return 0xFFB9AD9F
        case .tokReadIcon: return 0xFF332C25
        case .tokReadInk: return 0xFF332C25
        case .tokReadMuted: return 0xFF5B5046
        case .tokReadPrimary: return 0xFF1F3D31
        case .tokReadSurface: return 0xFFF0E5D6
        case .tokReadUnread: return 0xFF9A8E80
        case .tokRowDivider: return 0x1A5C4F3F
        case .tokSettingActionBg: return 0x171F3D31
        case .tokSettingDangerIconBg: return 0x1AB83B32
        case .tokSettingIconBg: return 0x171F3D31
        case .tokSsCloseBg: return 0x6BEAE3D6
        case .tokSsColumnHeaderBg: return 0x0D1D1B18
        case .tokSsDrawerHandle: return 0xFFB9AD9F
        case .tokSsDrawerScrim: return 0x61151715
        case .tokSsFooterText: return 0xFFC8BFB5
        case .tokSsMuted: return 0xFF928B80
        case .tokSsProgressBg: return 0xF7FBF8F2
        case .tokSsScrollbar: return 0xFFD5CEC4
        case .tokSsSortPillBg: return 0x1A1D1B18
        case .tokSsWindowBg: return 0xE0FDFAF4
        case .tokSsWindowBorder: return 0x3DB4A697
        case .tokSurface: return 0xFFF4EFE6
        case .tokSurfaceElevated: return 0xFFFFFDF9
        case .tokSurfaceField: return 0xFFEAE3D6
        case .tokSurfacePanel: return 0xFFFDFAF4
        case .tokSurfacePanelSoft: return 0xFFF5EFE6
        case .tokSurfaceSolid: return 0xFFFFFDF9
        case .tokSurfaceSolidOpaque: return 0xFFFFFDF9
        case .tokSurfaceTranslucent: return 0xF0FBF8F2
        case .tokTtsCard: return 0xEBFFFCF8
        case .tokTtsClay: return 0xFFB83B32
        case .tokTtsClayLine: return 0x5CB83B32
        case .tokTtsClaySoft: return 0x1AB83B32
        case .tokTtsField: return 0xB3F2EADE
        case .tokTtsInk: return 0xFF332C25
        case .tokTtsLine: return 0x57B4A697
        case .tokTtsMuted: return 0xFF5B5046
        case .tokTtsPaper: return 0xFFFFFCF8
        case .tokTtsPaperEnd: return 0xFFFFFCF8
        case .tokTtsPaperStart: return 0xFFFFFCF8
        case .tokTtsPlayEnd: return 0xFF172E25
        case .tokTtsPlayStart: return 0xFF2A5242
        case .tokTtsQuickCard: return 0x8FEEE6DB
        case .tokTtsTeal: return 0xFF1F3D31
        case .tokTtsTealLine: return 0x471F3D31
        case .tokTtsTealSoft: return 0x171F3D31
        case .tokTtsTrack: return 0x47B4A697
        case .appActionApplyBorder: return 0x471F3D31
        case .appActionApplyGradientEnd: return 0xFF172E25
        case .appActionApplyGradientStart: return 0xFF2A5242
        case .appActionDestructive: return 0xFFB83B32
        case .appActionDestructiveSoft: return 0x1AB83B32
        case .appActionFill: return 0xFF1F3D31
        case .appActionNativeDestructive: return 0xFFB83B32
        case .appActionOnDanger: return 0xFFFFFDF9
        case .appActionStop: return 0xFFB83B32
        case .appAppearanceLayoutBorder: return 0x3DB4A697
        case .appAppearanceLayoutCaption: return 0xFF9A8E80
        case .appAppearanceLayoutSurface: return 0xC7FBF6EE
        case .appAppearanceSelectBorder: return 0x479B8466
        case .appAppearanceSelectFill: return 0x1FB4A697
        case .appAppearanceSelectOpenFill: return 0x171F3D31
        case .appAppearanceSelectSelected: return 0xB8EEE6DB
        case .appAppearanceSelectSurface: return 0xFFFFFDF9
        case .appBookmarkEmptyAction: return 0xFFFAF7F0
        case .appBookmarkExcerptAccent: return 0xFFB86B2B
        case .appBookshelfSheetSurface: return 0xFFFFFDF9
        case .appBorderContentCard: return 0xFFDCD2C0
        case .appBorderControl: return 0x295C4F3F
        case .appBorderFilter: return 0x7AB4A697
        case .appBorderMenu: return 0x295C4F3F
        case .appBorderMenuDivider: return 0x1A5C4F3F
        case .appBorderModalHighlight: return 0xD9FFFFFF
        case .appBorderReaderConfig: return 0x57B4A697
        case .appBorderReaderConfigSoft: return 0x3DB4A697
        case .appBorderSearchField: return 0x295C4F3F
        case .appBorderSourceGroup: return 0x85B4A697
        case .appBorderStatusCard: return 0xFFDCD2C0
        case .appBorderStepper: return 0x3DB4A697
        case .appChromeRaisedShadowAmbient: return 0x143F311D
        case .appChromeRaisedShadowContact: return 0x0A3F311D
        case .appChromeRaisedShadowNear: return 0x0F3F311D
        case .appControlItemInk: return 0xFF332C25
        case .appControlOnPrimary: return 0xFFFAF7F0
        case .appControlPaint172F6373: return 0x171F3D31
        case .appControlPaint1A2F6373: return 0x1A1F3D31
        case .appControlPaint212F6373: return 0x211F3D31
        case .appControlPaint299B8466: return 0x299B8466
        case .appControlPaint2E9B8466: return 0x2E9B8466
        case .appControlPaint332C25: return 0xFF332C25
        case .appControlPaint33Ffffff: return 0x33FFFFFF
        case .appControlPaint382F2314: return 0x382F2314
        case .appControlPaint472F6373: return 0x471F3D31
        case .appControlPaint4D2F6373: return 0x4D1F3D31
        case .appControlPaint5B5046: return 0xFF5B5046
        case .appControlPaint5C2F6373: return 0x5C1F3D31
        case .appControlPaint66B4A697: return 0x66B4A697
        case .appControlPaint8C3D36: return 0xFF8C3D36
        case .appControlPaint99Fff8Ef: return 0x99FFF8EF
        case .appControlPaint99Ffffff: return 0x99FFFFFF
        case .appControlPaintB4A697: return 0xFFB4A697
        case .appControlPaintC6Bfb2: return 0xFFC6BFB2
        case .appControlPaintF6Ecdd: return 0xFFF6ECDD
        case .appControlPaintFffaf4: return 0xFFFFFAF4
        case .appCoverFallbackMask: return 0x2E41484C
        case .appCoverPlaceholder: return 0xFFE4E0D8
        case .appDetailFooterFadeSoft: return 0xF5F4EFE6
        case .appDetailFooterFadeSolid: return 0xFFF4EFE6
        case .appDetailFooterFadeTransparent: return 0x00F4EFE6
        case .appDetailSummaryFadeTransparent: return 0x00FBF8F2
        case .appDirectoryEdgeFade: return 0xD9FFFDF9
        case .appDirectoryEdgeFadeTransparent: return 0x00FFFDF9
        case .appDiscoverCategorySurface: return 0xD1EEE8DF
        case .appDiscoverSourceBorder: return 0x5CB4A697
        case .appDiscoverSourceIconSurface: return 0x171F3D31
        case .appFeedActionSoft: return 0xD6EEE8DF
        case .appFeedDisabledSurface: return 0x1F7F766C
        case .appFeedEnabledSurface: return 0x1C2E6F52
        case .appFeedErrorSurface: return 0x1AB83B32
        case .appFeedErrorText: return 0xFF7D2F2B
        case .appFeedPillBorder: return 0x6BB4A697
        case .appFeedPillSurface: return 0xDBFFFCF8
        case .appFeedRefreshBorder: return 0x2E1F3D31
        case .appFeedUnreadDot: return 0xFFA9A39A
        case .appHeaderVeilBorder: return 0x9EC6BAA4
        case .appHeaderVeilSurface: return 0xE0FFFCF8
        case .appHeaderVeilSurfaceScrolled: return 0xF0FFFCF8
        case .appIconBookDetailBack1F1B17: return 0xFF1F1B17
        case .appIconBookDetailDirectory1F3528: return 0xFF1F3D31
        case .appIconBookshelfCompassActiveFffaf4: return 0xFFFFFAF4
        case .appIconBookshelfCompassOutline756F69: return 0xFF756F69
        case .appIconBookshelfEmptyLibrary1F1B17: return 0xFF1F1B17
        case .appIconBookshelfFilter756F69: return 0xFF756F69
        case .appIconBookshelfFilterActive2D4A3E: return 0xFF1F3D31
        case .appIconBookshelfGrid2D4A3E: return 0xFF1F3D31
        case .appIconBookshelfGridOutline756F69: return 0xFF756F69
        case .appIconBookshelfLibraryActiveFffaf4: return 0xFFFAF7F0
        case .appIconBookshelfLibraryOutline756F69: return 0xFF635D55
        case .appIconBookshelfList756F69: return 0xFF756F69
        case .appIconBookshelfListActive2D4A3E: return 0xFF1F3D31
        case .appIconBookshelfMore1F1B17: return 0xFF1F1B17
        case .appIconBookshelfMoreF8F4Ec: return 0xFFF8F4EC
        case .appIconBookshelfMoreBatch1F1B17: return 0xFF1F1B17
        case .appIconBookshelfMoreDownload1F1B17: return 0xFF1F1B17
        case .appIconBookshelfMoreImport1F1B17: return 0xFF1F1B17
        case .appIconBookshelfMoreSettings1F1B17: return 0xFF1F1B17
        case .appIconBookshelfMoreUpdate1F1B17: return 0xFF1F1B17
        case .appIconBookshelfMultiselectTrashD7473E: return 0xFFD7473E
        case .appIconBookshelfRssActiveFffaf4: return 0xFFFFFAF4
        case .appIconBookshelfRssOutline756F69: return 0xFF756F69
        case .appIconBookshelfSearch1F1B17: return 0xFF1F1B17
        case .appIconBookshelfSettings756F69: return 0xFF756F69
        case .appIconBookshelfSettingsActiveFffaf4: return 0xFFFAF7F0
        case .appIconBookshelfSettingsOutline756F69: return 0xFF635D55
        case .appIconDiscoverApplyFfffff: return 0xFFFFFFFF
        case .appIconDiscoverFilter3F372F: return 0xFF3F372F
        case .appIconDiscoverFilterChevron3F372F: return 0xFF3F372F
        case .appIconDiscoverRefresh1F1B17: return 0xFF1F1B17
        case .appIconDiscoverSourceChevron1F1B17: return 0xFF1F1B17
        case .appIconDiscoverSourceStack1F3528: return 0xFF1F3D31
        case .appIconImportCancel756F69: return 0xFF756F69
        case .appIconImportChooseFileFffaf4: return 0xFFFFFAF4
        case .appIconImportDoc756F69: return 0xFF756F69
        case .appIconImportDoneFffaf4: return 0xFFFFFAF4
        case .appIconImportFailureC0392B: return 0xFFC0392B
        case .appIconImportInfo756F69: return 0xFF756F69
        case .appIconImportRefresh2D4A3E: return 0xFF1F3D31
        case .appIconImportSelectSystem2D4A3E: return 0xFF1F3D31
        case .appIconImportSuccess2D4A3E: return 0xFF1F3D31
        case .appIconImportSummaryC0392B: return 0xFFC0392B
        case .appIconImportingHaloE8E2D9: return 0xFFE8E2D9
        case .appIconImportingHaloF8F4Ec: return 0xFFF8F4EC
        case .appIconImportingSpinnerArc2D4A3E: return 0xFF1F3D31
        case .appIconImportingSpinnerTrackE8E2D9: return 0xFFE8E2D9
        case .appIconRcAutopage332C25: return 0xFF332C25
        case .appIconRcChevronLeft4D463F: return 0xFF4D463F
        case .appIconRcChevronRight4D463F: return 0xFF4D463F
        case .appIconRcDots1F1B17: return 0xFF1F1B17
        case .appIconRcHeadphones2F6373: return 0xFF1F3D31
        case .appIconRcList2F6373: return 0xFF1F3D31
        case .appIconRcPalette2F6373: return 0xFF1F3D31
        case .appIconRcReplace332C25: return 0xFF332C25
        case .appIconRcSearch332C25: return 0xFF332C25
        case .appIconRcSettings2F6373: return 0xFF1F3D31
        case .appIconRcSun2F6373: return 0xFF1F3D31
        case .appIconRcSwitchHorizontal1F1B17: return 0xFF1F1B17
        case .appIconReaderAppearanceHeader332C25: return 0xFF332C25
        case .appIconReaderAppearanceMakeCheck2F6373: return 0xFF1F3D31
        case .appIconReaderAppearanceMakeChevron857C70: return 0xFF857C70
        case .appIconReaderAppearanceNavActiveFffaf4: return 0xFFFAF7F0
        case .appIconReaderAutoFullChevronLeft2F6373: return 0xFF1F3D31
        case .appIconReaderAutoFullChevronRight2F6373: return 0xFF1F3D31
        case .appIconReaderAutoFullClock1F1B17: return 0xFF1F1B17
        case .appIconReaderAutoFullPlayFffaf4: return 0xFFFAF7F0
        case .appIconReaderAutoFullStop2F6373: return 0xFF1F3D31
        case .appIconReaderAutoStop8C3D36: return 0xFF8C3D36
        case .appIconReaderChevronDown41484C: return 0xFF41484C
        case .appIconReaderChevronDownPrimary2F6373: return 0xFF1F3D31
        case .appIconReaderChevronRight756F69: return 0xFF756F69
        case .appIconReaderControlHeaderChevron2F6373: return 0xFF1F3D31
        case .appIconReaderControlReplaceBack2F6373: return 0xFF1F3D31
        case .appIconReaderControlReplaceDelete332C25: return 0xFF332C25
        case .appIconReaderControlReplaceEdit332C25: return 0xFF332C25
        case .appIconReaderControlReplaceExport332C25: return 0xFF332C25
        case .appIconReaderControlReplaceHeader332C25: return 0xFF332C25
        case .appIconReaderControlReplaceImport332C25: return 0xFF332C25
        case .appIconReaderDirectoryBack332C25: return 0xFF332C25
        case .appIconReaderDirectoryBottom2F6373: return 0xFF1F3D31
        case .appIconReaderDirectoryDirectory332C25: return 0xFF332C25
        case .appIconReaderDirectoryInputSearch5B5046: return 0xFF5B5046
        case .appIconReaderDirectoryListActiveFffaf4: return 0xFFFAF7F0
        case .appIconReaderDirectoryMarkerBookmark5B5046: return 0xFF5B5046
        case .appIconReaderDirectoryMarkerBookmarkActive2F6373: return 0xFFB86B2B
        case .appIconReaderDirectoryMarkerCheck2F6373: return 0xFF1F3D31
        case .appIconReaderDirectoryMarkerDownload5B5046: return 0xFF5B5046
        case .appIconReaderDirectoryMore332C25: return 0xFF332C25
        case .appIconReaderDirectorySearch2F6373: return 0xFF1F3D31
        case .appIconReaderDirectorySortAscending2F6373: return 0xFF1F3D31
        case .appIconReaderDirectorySortDescending2F6373: return 0xFF1F3D31
        case .appIconReaderDirectorySwitch332C25: return 0xFF332C25
        case .appIconReaderDirectoryTop2F6373: return 0xFF1F3D31
        case .appIconReaderPageBookmarkFilled2F6373: return 0xFF1F3D31
        case .appIconReaderQuickBack2F6373: return 0xFF1F3D31
        case .appIconReaderReplaceClose2F6373: return 0xFF1F3D31
        case .appIconReaderReplaceManageFffaf4: return 0xFFFAF7F0
        case .appIconReaderReplacePreview332C25: return 0xFF332C25
        case .appIconReaderSessionPauseFffaf4: return 0xFFFFFAF4
        case .appIconReaderSessionPlayFffaf4: return 0xFFFFFAF4
        case .appIconReaderSettingsHeader332C25: return 0xFF332C25
        case .appIconReaderSettingsNavActiveFffaf4: return 0xFFFAF7F0
        case .appIconReaderTtsClock2F6373: return 0xFF1F3D31
        case .appIconReaderTtsHeader332C25: return 0xFF332C25
        case .appIconReaderTtsHeadphones2F6373: return 0xFF1F3D31
        case .appIconReaderTtsMakeClose5B5046: return 0xFF5B5046
        case .appIconReaderTtsMakeEngineCheck2F6373: return 0xFF1F3D31
        case .appIconReaderTtsMakeEngineCheckFffcf8: return 0xFFFAF7F0
        case .appIconReaderTtsMakeMinus2F6373: return 0xFF1F3D31
        case .appIconReaderTtsMakeNext332C25: return 0xFF332C25
        case .appIconReaderTtsMakeNextQuick4D463F: return 0xFF4D463F
        case .appIconReaderTtsMakePauseFffaf4: return 0xFFFAF7F0
        case .appIconReaderTtsMakePlayFffaf4: return 0xFFFAF7F0
        case .appIconReaderTtsMakePlus2F6373: return 0xFF1F3D31
        case .appIconReaderTtsMakePrevious332C25: return 0xFF332C25
        case .appIconReaderTtsMakePreviousQuick4D463F: return 0xFF4D463F
        case .appIconReaderTtsMakeStopA8543A: return 0xFFB83B32
        case .appIconReaderTtsNavActiveFffaf4: return 0xFFFAF7F0
        case .appIconReaderTtsNext332C25: return 0xFF332C25
        case .appIconReaderTtsOnlineEngine756F69: return 0xFF756F69
        case .appIconReaderTtsPrevious332C25: return 0xFF332C25
        case .appIconReaderTtsRate2F6373: return 0xFF1F3D31
        case .appIconReaderTtsSpeedThumb2F6373: return 0xFF1F3D31
        case .appIconReaderTtsSpeedThumbFffaf4: return 0xFFFAF7F0
        case .appIconReaderTtsStopFffaf4: return 0xFFFAF7F0
        case .appIconReaderTtsSystemEngine1F3528: return 0xFF1F3D31
        case .appIconReaderTtsTimerCycle2F6373: return 0xFF1F3D31
        case .appIconRssAdd2D4A3E: return 0xFF1F3D31
        case .appIconRssBookmark756F69: return 0xFF756F69
        case .appIconRssBookmarkActive1F3528: return 0xFF1F3D31
        case .appIconRssEdit3F372F: return 0xFF3F372F
        case .appIconRssEmpty1F1B17: return 0xFF1F1B17
        case .appIconRssError1F1B17: return 0xFF1F1B17
        case .appIconRssExternal3F372F: return 0xFF3F372F
        case .appIconRssFilter3F372F: return 0xFF3F372F
        case .appIconRssFilterChevron3F372F: return 0xFF3F372F
        case .appIconRssItemChevron1F1B17: return 0xFF1F1B17
        case .appIconRssLink3F372F: return 0xFF3F372F
        case .appIconRssManage756F69: return 0xFF756F69
        case .appIconRssManageDeleteAb2E28: return 0xFFB83B32
        case .appIconRssManageEdit1F1B17: return 0xFF1F1B17
        case .appIconRssManageViewAll1F1B17: return 0xFF1F1B17
        case .appIconRssRefresh1F3528: return 0xFF1F3D31
        case .appIconRssSource1F3528: return 0xFF1F3D31
        case .appIconRssViewAll1F3528: return 0xFF1F3D31
        case .appIconSearchClear756F69: return 0xFF756F69
        case .appIconSearchEmpty756F69: return 0xFF756F69
        case .appIconSearchEmptyC4Bdb0: return 0xFFC4BDB0
        case .appIconSearchEmptyCcc5B8: return 0xFFCCC5B8
        case .appIconSearchEmptyD4Cec2: return 0xFFD4CEC2
        case .appIconSearchEmptyD8D1C4: return 0xFFD8D1C4
        case .appIconSearchEmptyE0D9Cc: return 0xFFE0D9CC
        case .appIconSearchEmptyEae4D8: return 0xFFEAE4D8
        case .appIconSearchEmptyF8F4Ec: return 0xFFF8F4EC
        case .appIconSearchError756F69: return 0xFF756F69
        case .appIconSearchErrorC1C7Cd: return 0xFFC1C7CD
        case .appIconSearchErrorF0Ebe1: return 0xFFF0EBE1
        case .appIconSearchMag756F69: return 0xFF756F69
        case .appIconSettingsGenAnimation2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenBattery2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenCache2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenCrash2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenFile2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenLanguage2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenNavigation2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenNotification756F69: return 0xFF756F69
        case .appIconSettingsGenRefresh2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenStartup2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenTapTop2D4A3E: return 0xFF1F3D31
        case .appIconSettingsGenTheme2D4A3E: return 0xFF1F3D31
        case .appIconSettingsResetDefaultsD62222: return 0xFFB83B32
        case .appIconSettingsRowAbout2D4A3E: return 0xFF1F3D31
        case .appIconSettingsRowDownload2D4A3E: return 0xFF1F3D31
        case .appIconSettingsRowGeneral2D4A3E: return 0xFF1F3D31
        case .appIconSettingsRowShelfSearch2D4A3E: return 0xFF1F3D31
        case .appIconSettingsRowSource2D4A3E: return 0xFF1F3D31
        case .appIconSettingsRowSync2D4A3E: return 0xFF1F3D31
        case .appIconSettingsSelectCheck2D4A3E: return 0xFF1F3D31
        case .appIconSourceAddFffaf4: return 0xFFFAF7F0
        case .appIconSourceGroupChevron5B5046: return 0xFF5B5046
        case .appIconSourceGroupFolder2D4A3E: return 0xFF1F3D31
        case .appIconSourceSwitchClose332C25: return 0xFF332C25
        case .appIconSyncAccount2D4A3E: return 0xFF1F3D31
        case .appIconSyncBackupPassword2D4A3E: return 0xFF1F3D31
        case .appIconSyncPassword2D4A3E: return 0xFF1F3D31
        case .appIconSyncScopeChevron41484C: return 0xFF41484C
        case .appIconSyncServer2D4A3E: return 0xFF1F3D31
        case .appImportFormatArchive: return 0xFF6A4F7A
        case .appImportFormatEpub: return 0xFF7A5A38
        case .appImportFormatText: return 0xFF5A4A2A
        case .appImportSelectedSurface: return 0xFFD8E8E2
        case .appImportSeparator: return 0xFFE8E2D9
        case .appInteractionPress: return 0x141D1B18
        case .appNavigationFloatingBorder: return 0x1F5C4F3F
        case .appNavigationFloatingShadow: return 0x263F311D
        case .appNavigationFloatingSurface: return 0xFFFDFAF4
        case .appReaderAppearanceField: return 0xB3F2EADE
        case .appReaderChoiceHover: return 0x171F3D31
        case .appReaderPlaceholder: return 0xFF635D55
        case .appReaderSecondaryAction: return 0x29B4A697
        case .appReaderTtsField: return 0xB3F2EADE
        case .appReaderIslandControlBorder: return 0xFF655448
        case .appReaderIslandControlDisabledBorder: return 0xFFB8ADA0
        case .appReaderIslandControlDisabledInk: return 0xFF746A5F
        case .appReaderIslandControlDisabledSurface: return 0xFFF3EEE7
        case .appReaderIslandControlInk: return 0xFF30291F
        case .appReaderIslandControlStopBorder: return 0xFFBA4B40
        case .appReaderIslandControlStopSurface: return 0xFFF6E6DF
        case .appReaderIslandControlSurface: return 0xFFDFD3C4
        case .appReplaceInactiveRule: return 0xFFC9C5BE
        case .appReplaceOnToolbarAction: return 0xFFFAF7F0
        case .appScrimImport: return 0x61151715
        case .appScrimModal: return 0x61151715
        case .appScrimSelect: return 0x61151715
        case .appScrimWarmModal: return 0x61151715
        case .appSearchDiscoveredSource: return 0xFF5C745D
        case .appSearchFailedStatus: return 0xFFB83B32
        case .appSearchFieldElevated: return 0xFFEAE3D6
        case .appSearchFieldSolid: return 0xFFEAE3D6
        case .appSearchFieldTint: return 0x121D1B18
        case .appSearchListRule: return 0x1A5C4F3F
        case .appSearchOnCoverMeta: return 0x99FFFAF4
        case .appSearchPanelBorder: return 0x295C4F3F
        case .appSearchPanelShadow: return 0x14261E14
        case .appSearchPanelSurface: return 0xFFFBF8F2
        case .appSearchPartialStatus: return 0xFFB87424
        case .appSearchPassiveText: return 0xFF635D55
        case .appSearchPlaceholder: return 0xFF635D55
        case .appSearchPlaceholderTranslucent: return 0x801F1B17
        case .appSearchResultHint: return 0xFF858075
        case .appSearchSpinnerOnPrimaryTrack: return 0x4DFAF7F0
        case .appSearchSpinnerTrack: return 0x261F3D31
        case .appSegmentActiveText: return 0xFF1F3D31
        case .appSegmentBorder: return 0x295C4F3F
        case .appSegmentInactiveText: return 0xFF6E665C
        case .appSegmentSelected: return 0xFFFBFAF6
        case .appSegmentSurface: return 0xFFEAE3D6
        case .appSelectMenuSurface: return 0xFFFFFDF9
        case .appSelectPanelField: return 0xFFEAE3D6
        case .appSelectPanelSolid: return 0xFFFFFDF9
        case .appSelectSelectedSurface: return 0xA3EEE6DB
        case .appSelectSheetHandle: return 0x381F1B17
        case .appSelectSourceGroupSelected: return 0xFFFFFCF8
        case .appSelectTriggerSurface: return 0x8FEEE6DB
        case .appSelectionAccent: return 0xFF1F3D31
        case .appSelectionOnMode: return 0xFFFAF7F0
        case .appSelectionOptionSoft: return 0x171F3D31
        case .appSelectionSubtle: return 0x171F3D31
        case .appSessionCapsuleBorder: return 0x2E9B8466
        case .appSessionCapsuleInk: return 0xFF332C25
        case .appSessionCapsuleOnPrimary: return 0xFFFFFAF4
        case .appSessionCapsuleSurface: return 0xFAFFFAF4
        case .appShadowControl: return 0x471F3D31
        case .appShadowCover: return 0x241E1812
        case .appShadowDialog: return 0x2418140F
        case .appShadowFontSwatch: return 0x2B332C25
        case .appShadowMenu: return 0x14261E14
        case .appShadowReaderConfig: return 0x2418140F
        case .appShadowReaderConfigSecondary: return 0x381F1B17
        case .appShadowSelect: return 0x14261E14
        case .appShadowSelectPanel: return 0x2418140F
        case .appShadowSheet: return 0x2418140F
        case .appShadowThemeSwatch: return 0x381F3D31
        case .appSourceSwitchError: return 0xFFB83B32
        case .appSourceSwitchGood: return 0xFF2E6F52
        case .appSourceSwitchLatencyError: return 0xFFB83B32
        case .appSourceSwitchSelectedRow: return 0x171F3D31
        case .appSourceSwitchSlow: return 0xFFB87424
        case .appSourceUiBorder: return 0x295C4F3F
        case .appSourceUiDanger: return 0xFFB83B32
        case .appSourceUiDangerSurface: return 0x1AB83B32
        case .appSourceUiDivider: return 0x1A5C4F3F
        case .appSourceUiFaint: return 0xFF8D8579
        case .appSourceUiField: return 0xFFEAE3D6
        case .appSourceUiFooterShadow: return 0x19463B27
        case .appSourceUiHeaderShadow: return 0x10463B27
        case .appSourceUiMuted: return 0xFF635D55
        case .appSourceUiOnPrimary: return 0xFFFAF7F0
        case .appSourceUiOptionBorder: return 0xFFD8D0C2
        case .appSourceUiOverwrite: return 0xFFF2E9DF
        case .appSourceUiPrimary: return 0xFF1F3D31
        case .appSourceUiSelected: return 0x171F3D31
        case .appSourceUiSurface: return 0xFFFFFCF8
        case .appSourceUiToggleBorder: return 0xFFC5BDB0
        case .appSourceUiToggleOff: return 0x385C4F3F
        case .appStatusAvailableDot: return 0xFF2E6F52
        case .appStatusCheckError: return 0xFFB83B32
        case .appStatusCheckErrorSoft: return 0x1AB83B32
        case .appStatusCheckWarning: return 0xFFB87424
        case .appStatusFailureSurface: return 0x1AB83B32
        case .appStatusGood: return 0xFF2E6F52
        case .appStatusGoodSoft: return 0x1C2E6F52
        case .appStatusInfoSoft: return 0x171F3D31
        case .appStatusMutedDot: return 0xFF8C8276
        case .appStatusMutedSoft: return 0x1F8C8276
        case .appStatusSealSoft: return 0x1FB86B2B
        case .appStatusSuccessSurface: return 0x1C2E6F52
        case .appStatusWarning: return 0xFFB87424
        case .appStatusWarningSoft: return 0x1FB87424
        case .appSurfaceChapterSection: return 0xEBFFFCF8
        case .appSurfaceDangerCard: return 0xE0FFFFFF
        case .appSurfaceDock: return 0xFFFFFAF4
        case .appSurfaceGestureMask: return 0x40FFFFFF
        case .appSurfaceGlass: return 0xE0FDFAF4
        case .appSurfaceGlassHeavy: return 0xF0FBF8F2
        case .appSurfaceMenuSolid: return 0xFFFFFDF9
        case .appSurfaceReaderConfig: return 0xF5FFFAF4
        case .appSurfaceReaderInput: return 0xB3F2EADE
        case .appSurfaceSelectGradientEnd: return 0xC7FBF6EE
        case .appSurfaceSelectWarm: return 0xC7FBF6EE
        case .appSurfaceSyncRow: return 0xB3FFFCF8
        case .appSurfaceTransparent: return 0x00000000
        case .appSurfaceTtsTabs: return 0x8FEEE6DB
        case .appSyncActionSurface: return 0xFF243D30
        case .appSyncBadgeSurface: return 0xFFEEE7DB
        case .appSyncGhostBorder: return 0x38236179
        case .appSyncGhostSurface: return 0x14236179
        case .appTextEmptyHint: return 0xFF928B80
        case .appTextFeedMeta: return 0xFF6F655D
        case .appTextFeedTab: return 0xFF564D44
        case .appTextFilter: return 0xFF1D1B18
        case .appTextHeading: return 0xFF1D1B18
        case .appTextOnAccent: return 0xFFFAF7F0
        case .appTextSecondary: return 0xFF635D55
        case .appTextSubtle: return 0xFF928B80
        case .appTextSummary: return 0xFF635D55
        case .appTextSyncBadge: return 0xFF243D30
        case .appTextSyncHeading: return 0xFF1A1612
        case .appTextSyncHint: return 0xFF9C9488
        case .appTextSyncMeta: return 0xFF5C564E
        case .appToggleInactiveTrack: return 0x385C4F3F
        case .appToggleOffTrack: return 0x385C4F3F
        case .appToggleThumb: return 0xFFFFFDF9
        case .appTtsError: return 0xFFB83B32
        case .appTtsOffTrack: return 0x385C4F3F
        case .appTtsOnPrimary: return 0xFFFAF7F0
        case .appTtsPlayback: return 0xFF1F3D31
        case .appTtsThumb: return 0xFFFFFDF9
        case .appWebAction: return 0xFF1F3D31
        case .appWebInk: return 0xFF2C2520
        case .appWebMuted: return 0xFF8A7B6B
        case .appWebStatus: return 0xFF604C3B
        case .appWebSurface: return 0xFFFFFDF9
        case .appWindowBackground: return 0xFFF4EFE6
        case .appWindowForeground: return 0xFF1D1B18
        }
    }

    /// Night-scheme packed ARGB.
    var night: UInt32 {
        switch self {
        case .tokAccent: return 0xFFD99452
        case .tokActionDivider: return 0x29ECE8E0
        case .tokBorder: return 0x29ECE8E0
        case .tokBottomBg: return 0xFF221F1C
        case .tokCardBg: return 0xFF1F2320
        case .tokCardBgHi: return 0xFF1F2320
        case .tokChapterDivider: return 0x17ECE8E0
        case .tokControlInk: return 0xFFECE8E0
        case .tokDanger: return 0xFFE0645A
        case .tokDownloadDanger: return 0xFFE0645A
        case .tokDownloadGreen: return 0xFF7BB094
        case .tokDownloadGreenInk: return 0xFF111B16
        case .tokDownloadInk: return 0xFFECE8E0
        case .tokDownloadLine: return 0x17ECE8E0
        case .tokDownloadMuted: return 0xFFA6A196
        case .tokDownloadPaper: return 0xFF151715
        case .tokDownloadScrim: return 0x94000000
        case .tokDownloadShadow: return 0x3D000000
        case .tokDownloadSoft: return 0xFF191C19
        case .tokDownloadSoftGreen: return 0x247BB094
        case .tokDownloadSurface: return 0xFF1F2320
        case .tokFieldSurface: return 0xFF191C19
        case .tokGreen: return 0xFF7BB094
        case .tokInk: return 0xFFECE8E0
        case .tokLine: return 0x996E8173
        case .tokLineHard: return 0x29ECE8E0
        case .tokLineStrong: return 0xFF6E8173
        case .tokMessageBorder: return 0xFF495044
        case .tokMessageDanger: return 0xFFFFB1A2
        case .tokMessageFeedback: return 0xFF334C40
        case .tokMessageFeedbackBorder: return 0xFF567563
        case .tokMessageFeedbackInk: return 0xFFF5F3EA
        case .tokMessageFeedbackMark: return 0xFFC8DFCD
        case .tokMessageFeedbackMarkInk: return 0xFF294C3E
        case .tokMessageInk: return 0xFFECEEE7
        case .tokMessageMuted: return 0xFFBBC0B3
        case .tokMessageNotice: return 0xFFD4E2D1
        case .tokMessageNoticeInk: return 0xFF263B2D
        case .tokMessageSoft: return 0xFF3A4639
        case .tokMessageSoftInk: return 0xFFD4E2D1
        case .tokMessageSurface: return 0xFF2A3029
        case .tokMessageTag: return 0x16314D3C
        case .tokMetaBg: return 0xFF2C2824
        case .tokMuted: return 0xFFA6A196
        case .tokOnPrimary: return 0xFF111B16
        case .tokPaper: return 0xFF151715
        case .tokPrimaryBg: return 0x247BB094
        case .tokPrimaryBorder: return 0x577BB094
        case .tokPrimaryDark: return 0xFF7BB094
        case .tokPrimaryGradientStart: return 0xFF8FC2A7
        case .tokPrimarySoft: return 0x247BB094
        case .tokPrimaryStrong: return 0x577BB094
        case .tokPrimaryText: return 0xFF7BB094
        case .tokReadActiveSoft: return 0xFF344239
        case .tokReadCardEmphasis: return 0xFF3C4840
        case .tokReadDisabledBg: return 0xFF1C201D
        case .tokReadElevated: return 0xFF353F38
        case .tokReadHandle: return 0x47ECE8E0
        case .tokReadIcon: return 0xFFECE8E0
        case .tokReadInk: return 0xFFECE8E0
        case .tokReadMuted: return 0xFFA6A196
        case .tokReadPrimary: return 0xFF7BB094
        case .tokReadSurface: return 0xFF252B26
        case .tokReadUnread: return 0xFF747067
        case .tokRowDivider: return 0x17ECE8E0
        case .tokSettingActionBg: return 0x247BB094
        case .tokSettingDangerIconBg: return 0x24E0645A
        case .tokSettingIconBg: return 0x247BB094
        case .tokSsCloseBg: return 0x80191C19
        case .tokSsColumnHeaderBg: return 0x0DECE8E0
        case .tokSsDrawerHandle: return 0x47ECE8E0
        case .tokSsDrawerScrim: return 0x94000000
        case .tokSsFooterText: return 0xFFC8BFB5
        case .tokSsMuted: return 0xFF747067
        case .tokSsProgressBg: return 0xF71F2320
        case .tokSsScrollbar: return 0xFF41483B
        case .tokSsSortPillBg: return 0x1AECE8E0
        case .tokSsWindowBg: return 0xE0222723
        case .tokSsWindowBorder: return 0x1FECE8E0
        case .tokSurface: return 0xFF151715
        case .tokSurfaceElevated: return 0xFF272C28
        case .tokSurfaceField: return 0xFF191C19
        case .tokSurfacePanel: return 0xFF222723
        case .tokSurfacePanelSoft: return 0xFF1C201D
        case .tokSurfaceSolid: return 0xFF272C28
        case .tokSurfaceSolidOpaque: return 0xFF272C28
        case .tokSurfaceTranslucent: return 0xF01F2320
        case .tokTtsCard: return 0xFF272D28
        case .tokTtsClay: return 0xFFE0645A
        case .tokTtsClayLine: return 0x5CE0645A
        case .tokTtsClaySoft: return 0x24E0645A
        case .tokTtsField: return 0xB8343B35
        case .tokTtsInk: return 0xFFECE8E0
        case .tokTtsLine: return 0x29ECE8E0
        case .tokTtsMuted: return 0xFFA6A196
        case .tokTtsPaper: return 0xFF272D28
        case .tokTtsPaperEnd: return 0xFF272D28
        case .tokTtsPaperStart: return 0xFF272D28
        case .tokTtsPlayEnd: return 0xFF5B9275
        case .tokTtsPlayStart: return 0xFF8FC2A7
        case .tokTtsQuickCard: return 0xFF1C201D
        case .tokTtsTeal: return 0xFF7BB094
        case .tokTtsTealLine: return 0x577BB094
        case .tokTtsTealSoft: return 0x297BB094
        case .tokTtsTrack: return 0x2EECE8E0
        case .appActionApplyBorder: return 0x577BB094
        case .appActionApplyGradientEnd: return 0xFF5B9275
        case .appActionApplyGradientStart: return 0xFF8FC2A7
        case .appActionDestructive: return 0xFFE0645A
        case .appActionDestructiveSoft: return 0x24E0645A
        case .appActionFill: return 0xFF7BB094
        case .appActionNativeDestructive: return 0xFFE0645A
        case .appActionOnDanger: return 0xFFFFFDF9
        case .appActionStop: return 0xFFE0645A
        case .appAppearanceLayoutBorder: return 0x1FECE8E0
        case .appAppearanceLayoutCaption: return 0xFF747067
        case .appAppearanceLayoutSurface: return 0xDB292F2A
        case .appAppearanceSelectBorder: return 0x47E2D1B9
        case .appAppearanceSelectFill: return 0x1FE2D1B9
        case .appAppearanceSelectOpenFill: return 0x247BB094
        case .appAppearanceSelectSelected: return 0xFF4B433B
        case .appAppearanceSelectSurface: return 0xFF272C28
        case .appBookmarkEmptyAction: return 0xFF111B16
        case .appBookmarkExcerptAccent: return 0xFFD99452
        case .appBookshelfSheetSurface: return 0xFF272C28
        case .appBorderContentCard: return 0x4DE2D1B9
        case .appBorderControl: return 0x29ECE8E0
        case .appBorderFilter: return 0x7AE2D1B9
        case .appBorderMenu: return 0x29ECE8E0
        case .appBorderMenuDivider: return 0x17ECE8E0
        case .appBorderModalHighlight: return 0x1AFFFFFF
        case .appBorderReaderConfig: return 0x29ECE8E0
        case .appBorderReaderConfigSoft: return 0x1FECE8E0
        case .appBorderSearchField: return 0x29ECE8E0
        case .appBorderSourceGroup: return 0x85E2D1B9
        case .appBorderStatusCard: return 0xFFE2D1B9
        case .appBorderStepper: return 0x1FECE8E0
        case .appChromeRaisedShadowAmbient: return 0x2E000000
        case .appChromeRaisedShadowContact: return 0x12000000
        case .appChromeRaisedShadowNear: return 0x1F000000
        case .appControlItemInk: return 0xFFECE8E0
        case .appControlOnPrimary: return 0xFF111B16
        case .appControlPaint172F6373: return 0x177BB094
        case .appControlPaint1A2F6373: return 0x1A7BB094
        case .appControlPaint212F6373: return 0x217BB094
        case .appControlPaint299B8466: return 0x29564D43
        case .appControlPaint2E9B8466: return 0x2E564D43
        case .appControlPaint332C25: return 0xFFECE8E0
        case .appControlPaint33Ffffff: return 0x333C3630
        case .appControlPaint382F2314: return 0x38000000
        case .appControlPaint472F6373: return 0x477BB094
        case .appControlPaint4D2F6373: return 0x4D7BB094
        case .appControlPaint5B5046: return 0xFFA6A196
        case .appControlPaint5C2F6373: return 0x5C7BB094
        case .appControlPaint66B4A697: return 0x665C5146
        case .appControlPaint8C3D36: return 0xFFF08B7E
        case .appControlPaint99Fff8Ef: return 0x99332D27
        case .appControlPaint99Ffffff: return 0x993C3630
        case .appControlPaintB4A697: return 0xFF9E9180
        case .appControlPaintC6Bfb2: return 0xFF696055
        case .appControlPaintF6Ecdd: return 0xFF25211D
        case .appControlPaintFffaf4: return 0xFF302B25
        case .appCoverFallbackMask: return 0x2EEADFCE
        case .appCoverPlaceholder: return 0xFF2C2824
        case .appDetailFooterFadeSoft: return 0xF5151715
        case .appDetailFooterFadeSolid: return 0xFF151715
        case .appDetailFooterFadeTransparent: return 0x00151715
        case .appDetailSummaryFadeTransparent: return 0x001F2320
        case .appDirectoryEdgeFade: return 0xD9272C28
        case .appDirectoryEdgeFadeTransparent: return 0x00272C28
        case .appDiscoverCategorySurface: return 0xD12C2824
        case .appDiscoverSourceBorder: return 0x5CE2D1B9
        case .appDiscoverSourceIconSurface: return 0x247BB094
        case .appFeedActionSoft: return 0xD62C2824
        case .appFeedDisabledSurface: return 0x1F7F766C
        case .appFeedEnabledSurface: return 0x246DC095
        case .appFeedErrorSurface: return 0x24E0645A
        case .appFeedErrorText: return 0xFF7D2F2B
        case .appFeedPillBorder: return 0x6BE2D1B9
        case .appFeedPillSurface: return 0xDB2A2622
        case .appFeedRefreshBorder: return 0x2E7BB094
        case .appFeedUnreadDot: return 0xFFBAAD9C
        case .appHeaderVeilBorder: return 0xCC6C7364
        case .appHeaderVeilSurface: return 0xE630342D
        case .appHeaderVeilSurfaceScrolled: return 0xE630342D
        case .appIconBookDetailBack1F1B17: return 0xFFEADFCE
        case .appIconBookDetailDirectory1F3528: return 0xFF7BB094
        case .appIconBookshelfCompassActiveFffaf4: return 0xFFFFFAF4
        case .appIconBookshelfCompassOutline756F69: return 0xFFABA99F
        case .appIconBookshelfEmptyLibrary1F1B17: return 0xFFEADFCE
        case .appIconBookshelfFilter756F69: return 0xFFABA99F
        case .appIconBookshelfFilterActive2D4A3E: return 0xFF7BB094
        case .appIconBookshelfGrid2D4A3E: return 0xFF7BB094
        case .appIconBookshelfGridOutline756F69: return 0xFFABA99F
        case .appIconBookshelfLibraryActiveFffaf4: return 0xFF111B16
        case .appIconBookshelfLibraryOutline756F69: return 0xFFA6A196
        case .appIconBookshelfList756F69: return 0xFFABA99F
        case .appIconBookshelfListActive2D4A3E: return 0xFF7BB094
        case .appIconBookshelfMore1F1B17: return 0xFFEADFCE
        case .appIconBookshelfMoreF8F4Ec: return 0xFF24211E
        case .appIconBookshelfMoreBatch1F1B17: return 0xFFEADFCE
        case .appIconBookshelfMoreDownload1F1B17: return 0xFFEADFCE
        case .appIconBookshelfMoreImport1F1B17: return 0xFFEADFCE
        case .appIconBookshelfMoreSettings1F1B17: return 0xFFEADFCE
        case .appIconBookshelfMoreUpdate1F1B17: return 0xFFEADFCE
        case .appIconBookshelfMultiselectTrashD7473E: return 0xFFD7473E
        case .appIconBookshelfRssActiveFffaf4: return 0xFFFFFAF4
        case .appIconBookshelfRssOutline756F69: return 0xFFABA99F
        case .appIconBookshelfSearch1F1B17: return 0xFFEADFCE
        case .appIconBookshelfSettings756F69: return 0xFFABA99F
        case .appIconBookshelfSettingsActiveFffaf4: return 0xFF111B16
        case .appIconBookshelfSettingsOutline756F69: return 0xFFA6A196
        case .appIconDiscoverApplyFfffff: return 0xFFFFFFFF
        case .appIconDiscoverFilter3F372F: return 0xFFEADFCE
        case .appIconDiscoverFilterChevron3F372F: return 0xFFEADFCE
        case .appIconDiscoverRefresh1F1B17: return 0xFFEADFCE
        case .appIconDiscoverSourceChevron1F1B17: return 0xFFEADFCE
        case .appIconDiscoverSourceStack1F3528: return 0xFF7BB094
        case .appIconImportCancel756F69: return 0xFFBAAD9C
        case .appIconImportChooseFileFffaf4: return 0xFFFFFAF4
        case .appIconImportDoc756F69: return 0xFFBAAD9C
        case .appIconImportDoneFffaf4: return 0xFFFFFAF4
        case .appIconImportFailureC0392B: return 0xFFC0392B
        case .appIconImportInfo756F69: return 0xFFBAAD9C
        case .appIconImportRefresh2D4A3E: return 0xFF7BB094
        case .appIconImportSelectSystem2D4A3E: return 0xFF7BB094
        case .appIconImportSuccess2D4A3E: return 0xFF7BB094
        case .appIconImportSummaryC0392B: return 0xFFC0392B
        case .appIconImportingHaloE8E2D9: return 0xFF51493F
        case .appIconImportingHaloF8F4Ec: return 0xFF24211E
        case .appIconImportingSpinnerArc2D4A3E: return 0xFF7BB094
        case .appIconImportingSpinnerTrackE8E2D9: return 0xFF51493F
        case .appIconRcAutopage332C25: return 0xFFECE8E0
        case .appIconRcChevronLeft4D463F: return 0xFFEADFCE
        case .appIconRcChevronRight4D463F: return 0xFFEADFCE
        case .appIconRcDots1F1B17: return 0xFFEADFCE
        case .appIconRcHeadphones2F6373: return 0xFF7BB094
        case .appIconRcList2F6373: return 0xFF7BB094
        case .appIconRcPalette2F6373: return 0xFF7BB094
        case .appIconRcReplace332C25: return 0xFFECE8E0
        case .appIconRcSearch332C25: return 0xFFECE8E0
        case .appIconRcSettings2F6373: return 0xFF7BB094
        case .appIconRcSun2F6373: return 0xFF7BB094
        case .appIconRcSwitchHorizontal1F1B17: return 0xFFEADFCE
        case .appIconReaderAppearanceHeader332C25: return 0xFFEADFCE
        case .appIconReaderAppearanceMakeCheck2F6373: return 0xFF7BB094
        case .appIconReaderAppearanceMakeChevron857C70: return 0xFFBAAD9C
        case .appIconReaderAppearanceNavActiveFffaf4: return 0xFF111B16
        case .appIconReaderAutoFullChevronLeft2F6373: return 0xFF7BB094
        case .appIconReaderAutoFullChevronRight2F6373: return 0xFF7BB094
        case .appIconReaderAutoFullClock1F1B17: return 0xFFEADFCE
        case .appIconReaderAutoFullPlayFffaf4: return 0xFF111B16
        case .appIconReaderAutoFullStop2F6373: return 0xFF7BB094
        case .appIconReaderAutoStop8C3D36: return 0xFF8C3D36
        case .appIconReaderChevronDown41484C: return 0xFFEADFCE
        case .appIconReaderChevronDownPrimary2F6373: return 0xFF7BB094
        case .appIconReaderChevronRight756F69: return 0xFFBAAD9C
        case .appIconReaderControlHeaderChevron2F6373: return 0xFF7BB094
        case .appIconReaderControlReplaceBack2F6373: return 0xFF7BB094
        case .appIconReaderControlReplaceDelete332C25: return 0xFFEADFCE
        case .appIconReaderControlReplaceEdit332C25: return 0xFFEADFCE
        case .appIconReaderControlReplaceExport332C25: return 0xFFEADFCE
        case .appIconReaderControlReplaceHeader332C25: return 0xFFEADFCE
        case .appIconReaderControlReplaceImport332C25: return 0xFFEADFCE
        case .appIconReaderDirectoryBack332C25: return 0xFFEADFCE
        case .appIconReaderDirectoryBottom2F6373: return 0xFF7BB094
        case .appIconReaderDirectoryDirectory332C25: return 0xFFEADFCE
        case .appIconReaderDirectoryInputSearch5B5046: return 0xFFBAAD9C
        case .appIconReaderDirectoryListActiveFffaf4: return 0xFF111B16
        case .appIconReaderDirectoryMarkerBookmark5B5046: return 0xFFA6A196
        case .appIconReaderDirectoryMarkerBookmarkActive2F6373: return 0xFFD99452
        case .appIconReaderDirectoryMarkerCheck2F6373: return 0xFF7BB094
        case .appIconReaderDirectoryMarkerDownload5B5046: return 0xFFA6A196
        case .appIconReaderDirectoryMore332C25: return 0xFFEADFCE
        case .appIconReaderDirectorySearch2F6373: return 0xFF7BB094
        case .appIconReaderDirectorySortAscending2F6373: return 0xFF7BB094
        case .appIconReaderDirectorySortDescending2F6373: return 0xFF7BB094
        case .appIconReaderDirectorySwitch332C25: return 0xFFEADFCE
        case .appIconReaderDirectoryTop2F6373: return 0xFF7BB094
        case .appIconReaderPageBookmarkFilled2F6373: return 0xFF7BB094
        case .appIconReaderQuickBack2F6373: return 0xFF7BB094
        case .appIconReaderReplaceClose2F6373: return 0xFF7BB094
        case .appIconReaderReplaceManageFffaf4: return 0xFF111B16
        case .appIconReaderReplacePreview332C25: return 0xFFEADFCE
        case .appIconReaderSessionPauseFffaf4: return 0xFF1C1A18
        case .appIconReaderSessionPlayFffaf4: return 0xFF1C1A18
        case .appIconReaderSettingsHeader332C25: return 0xFFEADFCE
        case .appIconReaderSettingsNavActiveFffaf4: return 0xFF111B16
        case .appIconReaderTtsClock2F6373: return 0xFF7BB094
        case .appIconReaderTtsHeader332C25: return 0xFFEADFCE
        case .appIconReaderTtsHeadphones2F6373: return 0xFF7BB094
        case .appIconReaderTtsMakeClose5B5046: return 0xFFBAAD9C
        case .appIconReaderTtsMakeEngineCheck2F6373: return 0xFF7BB094
        case .appIconReaderTtsMakeEngineCheckFffcf8: return 0xFF111B16
        case .appIconReaderTtsMakeMinus2F6373: return 0xFF7BB094
        case .appIconReaderTtsMakeNext332C25: return 0xFFEADFCE
        case .appIconReaderTtsMakeNextQuick4D463F: return 0xFFEADFCE
        case .appIconReaderTtsMakePauseFffaf4: return 0xFF111B16
        case .appIconReaderTtsMakePlayFffaf4: return 0xFF111B16
        case .appIconReaderTtsMakePlus2F6373: return 0xFF7BB094
        case .appIconReaderTtsMakePrevious332C25: return 0xFFEADFCE
        case .appIconReaderTtsMakePreviousQuick4D463F: return 0xFFEADFCE
        case .appIconReaderTtsMakeStopA8543A: return 0xFFE0645A
        case .appIconReaderTtsNavActiveFffaf4: return 0xFF111B16
        case .appIconReaderTtsNext332C25: return 0xFFEADFCE
        case .appIconReaderTtsOnlineEngine756F69: return 0xFFBAAD9C
        case .appIconReaderTtsPrevious332C25: return 0xFFEADFCE
        case .appIconReaderTtsRate2F6373: return 0xFF7BB094
        case .appIconReaderTtsSpeedThumb2F6373: return 0xFF7BB094
        case .appIconReaderTtsSpeedThumbFffaf4: return 0xFF111B16
        case .appIconReaderTtsStopFffaf4: return 0xFF111B16
        case .appIconReaderTtsSystemEngine1F3528: return 0xFF7BB094
        case .appIconReaderTtsTimerCycle2F6373: return 0xFF7BB094
        case .appIconRssAdd2D4A3E: return 0xFF7BB094
        case .appIconRssBookmark756F69: return 0xFFBAAD9C
        case .appIconRssBookmarkActive1F3528: return 0xFF7BB094
        case .appIconRssEdit3F372F: return 0xFFEADFCE
        case .appIconRssEmpty1F1B17: return 0xFFEADFCE
        case .appIconRssError1F1B17: return 0xFFEADFCE
        case .appIconRssExternal3F372F: return 0xFFEADFCE
        case .appIconRssFilter3F372F: return 0xFFEADFCE
        case .appIconRssFilterChevron3F372F: return 0xFFEADFCE
        case .appIconRssItemChevron1F1B17: return 0xFFEADFCE
        case .appIconRssLink3F372F: return 0xFFEADFCE
        case .appIconRssManage756F69: return 0xFFBAAD9C
        case .appIconRssManageDeleteAb2E28: return 0xFFE0645A
        case .appIconRssManageEdit1F1B17: return 0xFFEADFCE
        case .appIconRssManageViewAll1F1B17: return 0xFFEADFCE
        case .appIconRssRefresh1F3528: return 0xFF7BB094
        case .appIconRssSource1F3528: return 0xFF7BB094
        case .appIconRssViewAll1F3528: return 0xFF7BB094
        case .appIconSearchClear756F69: return 0xFFBAAD9C
        case .appIconSearchEmpty756F69: return 0xFFBAAD9C
        case .appIconSearchEmptyC4Bdb0: return 0xFF746B60
        case .appIconSearchEmptyCcc5B8: return 0xFF6B6258
        case .appIconSearchEmptyD4Cec2: return 0xFF5D554B
        case .appIconSearchEmptyD8D1C4: return 0xFF514A40
        case .appIconSearchEmptyE0D9Cc: return 0xFF463E35
        case .appIconSearchEmptyEae4D8: return 0xFF3E3730
        case .appIconSearchEmptyF8F4Ec: return 0xFF24211E
        case .appIconSearchError756F69: return 0xFFBAAD9C
        case .appIconSearchErrorC1C7Cd: return 0xFF5C6065
        case .appIconSearchErrorF0Ebe1: return 0xFF332D27
        case .appIconSearchMag756F69: return 0xFFBAAD9C
        case .appIconSettingsGenAnimation2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenBattery2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenCache2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenCrash2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenFile2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenLanguage2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenNavigation2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenNotification756F69: return 0xFFBAAD9C
        case .appIconSettingsGenRefresh2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenStartup2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenTapTop2D4A3E: return 0xFF7BB094
        case .appIconSettingsGenTheme2D4A3E: return 0xFF7BB094
        case .appIconSettingsResetDefaultsD62222: return 0xFFE0645A
        case .appIconSettingsRowAbout2D4A3E: return 0xFF7BB094
        case .appIconSettingsRowDownload2D4A3E: return 0xFF7BB094
        case .appIconSettingsRowGeneral2D4A3E: return 0xFF7BB094
        case .appIconSettingsRowShelfSearch2D4A3E: return 0xFF7BB094
        case .appIconSettingsRowSource2D4A3E: return 0xFF7BB094
        case .appIconSettingsRowSync2D4A3E: return 0xFF7BB094
        case .appIconSettingsSelectCheck2D4A3E: return 0xFF7BB094
        case .appIconSourceAddFffaf4: return 0xFF111B16
        case .appIconSourceGroupChevron5B5046: return 0xFFBAAD9C
        case .appIconSourceGroupFolder2D4A3E: return 0xFF7BB094
        case .appIconSourceSwitchClose332C25: return 0xFFEADFCE
        case .appIconSyncAccount2D4A3E: return 0xFF7BB094
        case .appIconSyncBackupPassword2D4A3E: return 0xFF7BB094
        case .appIconSyncPassword2D4A3E: return 0xFF7BB094
        case .appIconSyncScopeChevron41484C: return 0xFFEADFCE
        case .appIconSyncServer2D4A3E: return 0xFF7BB094
        case .appImportFormatArchive: return 0xFFB69BCD
        case .appImportFormatEpub: return 0xFFBD9B6E
        case .appImportFormatText: return 0xFFDC9E53
        case .appImportSelectedSurface: return 0xFF334338
        case .appImportSeparator: return 0xFFE2D1B9
        case .appInteractionPress: return 0x1AECE8E0
        case .appNavigationFloatingBorder: return 0x1FECE8E0
        case .appNavigationFloatingShadow: return 0x52000000
        case .appNavigationFloatingSurface: return 0xFF222723
        case .appReaderAppearanceField: return 0xB8343B35
        case .appReaderChoiceHover: return 0x247BB094
        case .appReaderPlaceholder: return 0xFFA6A196
        case .appReaderSecondaryAction: return 0x29E2D1B9
        case .appReaderTtsField: return 0xB8343B35
        case .appReaderIslandControlBorder: return 0xFFA9BDAF
        case .appReaderIslandControlDisabledBorder: return 0xFF59665D
        case .appReaderIslandControlDisabledInk: return 0xFFA5ADA5
        case .appReaderIslandControlDisabledSurface: return 0xFF303A33
        case .appReaderIslandControlInk: return 0xFFF3F7EE
        case .appReaderIslandControlStopBorder: return 0xFFF99082
        case .appReaderIslandControlStopSurface: return 0xFF4A3834
        case .appReaderIslandControlSurface: return 0xFF4D5C52
        case .appReplaceInactiveRule: return 0xFF5C6065
        case .appReplaceOnToolbarAction: return 0xFF111B16
        case .appScrimImport: return 0x94000000
        case .appScrimModal: return 0x94000000
        case .appScrimSelect: return 0x94000000
        case .appScrimWarmModal: return 0x94000000
        case .appSearchDiscoveredSource: return 0xFFD2BD96
        case .appSearchFailedStatus: return 0xFFE0645A
        case .appSearchFieldElevated: return 0xFF191C19
        case .appSearchFieldSolid: return 0xFF191C19
        case .appSearchFieldTint: return 0x12ECE8E0
        case .appSearchListRule: return 0x17ECE8E0
        case .appSearchOnCoverMeta: return 0x99FFFAF4
        case .appSearchPanelBorder: return 0x29ECE8E0
        case .appSearchPanelShadow: return 0x61000000
        case .appSearchPanelSurface: return 0xFF1F2320
        case .appSearchPartialStatus: return 0xFFE0A458
        case .appSearchPassiveText: return 0xFFA6A196
        case .appSearchPlaceholder: return 0xFFA6A196
        case .appSearchPlaceholderTranslucent: return 0x80EADFCE
        case .appSearchResultHint: return 0xFFBAAD9C
        case .appSearchSpinnerOnPrimaryTrack: return 0x4D111B16
        case .appSearchSpinnerTrack: return 0x267BB094
        case .appSegmentActiveText: return 0xFF7BB094
        case .appSegmentBorder: return 0x29ECE8E0
        case .appSegmentInactiveText: return 0xFFBAAD9C
        case .appSegmentSelected: return 0xFF443C34
        case .appSegmentSurface: return 0xFF191C19
        case .appSelectMenuSurface: return 0xFF272C28
        case .appSelectPanelField: return 0xFF191C19
        case .appSelectPanelSolid: return 0xFF272C28
        case .appSelectSelectedSurface: return 0xFF4B433B
        case .appSelectSheetHandle: return 0x38EADFCE
        case .appSelectSourceGroupSelected: return 0xFF4B433B
        case .appSelectTriggerSurface: return 0xFF1C201D
        case .appSelectionAccent: return 0xFF7BB094
        case .appSelectionOnMode: return 0xFF111B16
        case .appSelectionOptionSoft: return 0x247BB094
        case .appSelectionSubtle: return 0x247BB094
        case .appSessionCapsuleBorder: return 0xFF4A5144
        case .appSessionCapsuleInk: return 0xFFEADFCE
        case .appSessionCapsuleOnPrimary: return 0xFF1C1A18
        case .appSessionCapsuleSurface: return 0xFF302C28
        case .appShadowControl: return 0x70000000
        case .appShadowCover: return 0x73000000
        case .appShadowDialog: return 0x85000000
        case .appShadowFontSwatch: return 0x2B332C25
        case .appShadowMenu: return 0x61000000
        case .appShadowReaderConfig: return 0x85000000
        case .appShadowReaderConfigSecondary: return 0x381F1B17
        case .appShadowSelect: return 0x61000000
        case .appShadowSelectPanel: return 0x85000000
        case .appShadowSheet: return 0x85000000
        case .appShadowThemeSwatch: return 0x3D7BB094
        case .appSourceSwitchError: return 0xFFE0645A
        case .appSourceSwitchGood: return 0xFF6DC095
        case .appSourceSwitchLatencyError: return 0xFFE0645A
        case .appSourceSwitchSelectedRow: return 0x247BB094
        case .appSourceSwitchSlow: return 0xFFE0A458
        case .appSourceUiBorder: return 0x29ECE8E0
        case .appSourceUiDanger: return 0xFFE0645A
        case .appSourceUiDangerSurface: return 0x24E0645A
        case .appSourceUiDivider: return 0x17ECE8E0
        case .appSourceUiFaint: return 0xFFA29A8E
        case .appSourceUiField: return 0xFF191C19
        case .appSourceUiFooterShadow: return 0x33000000
        case .appSourceUiHeaderShadow: return 0x24000000
        case .appSourceUiMuted: return 0xFFA6A196
        case .appSourceUiOnPrimary: return 0xFF111B16
        case .appSourceUiOptionBorder: return 0xFF5F5A50
        case .appSourceUiOverwrite: return 0xFF3E3025
        case .appSourceUiPrimary: return 0xFF7BB094
        case .appSourceUiSelected: return 0x247BB094
        case .appSourceUiSurface: return 0xFF36322E
        case .appSourceUiToggleBorder: return 0xFF766B5E
        case .appSourceUiToggleOff: return 0x38ECE8E0
        case .appStatusAvailableDot: return 0xFF6DC095
        case .appStatusCheckError: return 0xFFE0645A
        case .appStatusCheckErrorSoft: return 0x24E0645A
        case .appStatusCheckWarning: return 0xFFE0A458
        case .appStatusFailureSurface: return 0x24E0645A
        case .appStatusGood: return 0xFF6DC095
        case .appStatusGoodSoft: return 0x246DC095
        case .appStatusInfoSoft: return 0x247BB094
        case .appStatusMutedDot: return 0xFFBEB2A5
        case .appStatusMutedSoft: return 0x1F8C8276
        case .appStatusSealSoft: return 0x29D99452
        case .appStatusSuccessSurface: return 0x246DC095
        case .appStatusWarning: return 0xFFE0A458
        case .appStatusWarningSoft: return 0x24E0A458
        case .appSurfaceChapterSection: return 0xFF272D28
        case .appSurfaceDangerCard: return 0xE02C2824
        case .appSurfaceDock: return 0xFF212622
        case .appSurfaceGestureMask: return 0x402C2824
        case .appSurfaceGlass: return 0xE0222723
        case .appSurfaceGlassHeavy: return 0xF01F2320
        case .appSurfaceMenuSolid: return 0xFF272C28
        case .appSurfaceReaderConfig: return 0xF5212622
        case .appSurfaceReaderInput: return 0xB8343B35
        case .appSurfaceSelectGradientEnd: return 0xDB292F2A
        case .appSurfaceSelectWarm: return 0xDB292F2A
        case .appSurfaceSyncRow: return 0xB32A2622
        case .appSurfaceTransparent: return 0x00000000
        case .appSurfaceTtsTabs: return 0xFF1C201D
        case .appSyncActionSurface: return 0xFF7A684F
        case .appSyncBadgeSurface: return 0xFF2C2824
        case .appSyncGhostBorder: return 0x38D2BD96
        case .appSyncGhostSurface: return 0x14D2BD96
        case .appTextEmptyHint: return 0xFF747067
        case .appTextFeedMeta: return 0xFFBAAD9C
        case .appTextFeedTab: return 0xFFBAAD9C
        case .appTextFilter: return 0xFFECE8E0
        case .appTextHeading: return 0xFFECE8E0
        case .appTextOnAccent: return 0xFF111B16
        case .appTextSecondary: return 0xFFA6A196
        case .appTextSubtle: return 0xFF747067
        case .appTextSummary: return 0xFFA6A196
        case .appTextSyncBadge: return 0xFFD2BD96
        case .appTextSyncHeading: return 0xFFEADFCE
        case .appTextSyncHint: return 0xFFBAAD9C
        case .appTextSyncMeta: return 0xFFBAAD9C
        case .appToggleInactiveTrack: return 0x38ECE8E0
        case .appToggleOffTrack: return 0x38ECE8E0
        case .appToggleThumb: return 0xFFF4EFE6
        case .appTtsError: return 0xFFE0645A
        case .appTtsOffTrack: return 0x38ECE8E0
        case .appTtsOnPrimary: return 0xFF111B16
        case .appTtsPlayback: return 0xFF7BB094
        case .appTtsThumb: return 0xFFF4EFE6
        case .appWebAction: return 0xFF7BB094
        case .appWebInk: return 0xFFEADFCE
        case .appWebMuted: return 0xFFBAAD9C
        case .appWebStatus: return 0xFFBAAD9C
        case .appWebSurface: return 0xFF2A2622
        case .appWindowBackground: return 0xFF151715
        case .appWindowForeground: return 0xFFECE8E0
        }
    }
}

/// Reader paper palettes in registry order.
public struct ReaderPaperPalette: Sendable, Equatable {
    public let id: String
    public let scheme: String
    public let order: Int
    public let displayName: String
    public let paperStart: UInt32
    public let paperEnd: UInt32
    public let ink: UInt32
    public let chromeMeta: UInt32
    public let statusBackground: UInt32
    public let statusForeground: UInt32
    public let swatch: UInt32
    public let selection: UInt32
    public let paperBack: UInt32
    public let turnShadow: UInt32
    public let paperTexture: Bool
    public let sourcePaperLighting: Bool
}

public enum ReaderPaperThemes {
    public static let all: [ReaderPaperPalette] = [
        ReaderPaperPalette(
            id: "day",
            scheme: "day",
            order: 0,
            displayName: "日间",
            paperStart: 0xFFF7F3EA,
            paperEnd: 0xFFF7F3EA,
            ink: 0xFF2B241D,
            chromeMeta: 0xFF766C61,
            statusBackground: 0xFFF7F3EA,
            statusForeground: 0xFF2B241D,
            swatch: 0xFFFAF7F1,
            selection: 0x33594632,
            paperBack: 0xFFF7F3EA,
            turnShadow: 0x38000000,
            paperTexture: false,
            sourcePaperLighting: false
        ),
        ReaderPaperPalette(
            id: "warm",
            scheme: "day",
            order: 1,
            displayName: "暖白",
            paperStart: 0xFFF2E8D3,
            paperEnd: 0xFFF2E8D3,
            ink: 0xFF2C241D,
            chromeMeta: 0xFF766C61,
            statusBackground: 0xFFF2E8D3,
            statusForeground: 0xFF2C241D,
            swatch: 0xFFF5E7CE,
            selection: 0x33594632,
            paperBack: 0xFFF2E8D3,
            turnShadow: 0x38000000,
            paperTexture: false,
            sourcePaperLighting: false
        ),
        ReaderPaperPalette(
            id: "night",
            scheme: "night",
            order: 2,
            displayName: "夜间",
            paperStart: 0xFF21221F,
            paperEnd: 0xFF21221F,
            ink: 0xFFE4DDD0,
            chromeMeta: 0xFF9D968B,
            statusBackground: 0xFF21221F,
            statusForeground: 0xFFE4DDD0,
            swatch: 0xFF201F1C,
            selection: 0x33594632,
            paperBack: 0xFF21221F,
            turnShadow: 0x22000000,
            paperTexture: false,
            sourcePaperLighting: false
        ),
        ReaderPaperPalette(
            id: "warmNight",
            scheme: "night",
            order: 3,
            displayName: "暖夜",
            paperStart: 0xFF31271D,
            paperEnd: 0xFF31271D,
            ink: 0xFFE7D8C8,
            chromeMeta: 0xFFB3A18F,
            statusBackground: 0xFF31271D,
            statusForeground: 0xFFE7D8C8,
            swatch: 0xFF2A231B,
            selection: 0x33594632,
            paperBack: 0xFF31271D,
            turnShadow: 0x22000000,
            paperTexture: false,
            sourcePaperLighting: false
        ),
        ReaderPaperPalette(
            id: "paper",
            scheme: "day",
            order: 4,
            displayName: "纸纹",
            paperStart: 0xFFEDE2CB,
            paperEnd: 0xFFEDE2CB,
            ink: 0xFF2B241D,
            chromeMeta: 0xFF766C61,
            statusBackground: 0xFFEDE2CB,
            statusForeground: 0xFF2B241D,
            swatch: 0xFFEAE0CA,
            selection: 0x33594632,
            paperBack: 0xFFEDE2CB,
            turnShadow: 0x38000000,
            paperTexture: true,
            sourcePaperLighting: true
        ),
        ReaderPaperPalette(
            id: "green",
            scheme: "day",
            order: 5,
            displayName: "青叶",
            paperStart: 0xFFE3EBDD,
            paperEnd: 0xFFE3EBDD,
            ink: 0xFF263423,
            chromeMeta: 0xFF63755F,
            statusBackground: 0xFFE3EBDD,
            statusForeground: 0xFF263423,
            swatch: 0xFFDCE7D6,
            selection: 0x33594632,
            paperBack: 0xFFE3EBDD,
            turnShadow: 0x38000000,
            paperTexture: false,
            sourcePaperLighting: false
        ),
        ReaderPaperPalette(
            id: "paperNight",
            scheme: "night",
            order: 6,
            displayName: "夜纹",
            paperStart: 0xFF202630,
            paperEnd: 0xFF202630,
            ink: 0xFFE2DDD5,
            chromeMeta: 0xFF9BA5B2,
            statusBackground: 0xFF202630,
            statusForeground: 0xFFE2DDD5,
            swatch: 0xFF22262E,
            selection: 0x33594632,
            paperBack: 0xFF202630,
            turnShadow: 0x22000000,
            paperTexture: true,
            sourcePaperLighting: false
        ),
        ReaderPaperPalette(
            id: "greenNight",
            scheme: "night",
            order: 7,
            displayName: "林夜",
            paperStart: 0xFF1D2D23,
            paperEnd: 0xFF1D2D23,
            ink: 0xFFD8E2D2,
            chromeMeta: 0xFF97AA9A,
            statusBackground: 0xFF1D2D23,
            statusForeground: 0xFFD8E2D2,
            swatch: 0xFF1F2C22,
            selection: 0x33594632,
            paperBack: 0xFF1D2D23,
            turnShadow: 0x22000000,
            paperTexture: false,
            sourcePaperLighting: false
        ),
    ]
    public static func byId(_ id: String) -> ReaderPaperPalette? {
        all.first { $0.id == id }
    }
}
