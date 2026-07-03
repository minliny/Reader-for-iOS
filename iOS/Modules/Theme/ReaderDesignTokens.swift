import Foundation
import CoreGraphics
import SwiftUI

/// Demo 骨架设计 token —— 从 `Reader UI/frontend-demo/styles/*.css` 提取的
/// 数值化设计规格（clean-room：只承载尺寸/字体/颜色数值，不复制 CSS / DOM / selector）。
///
/// 真源（demo CSS 实际值，非猜测）：
/// - `00-foundation.css` —— `:root` token / `.fd-phone` / `.fd-status-bar` / `.fd-top-bar`
/// - `01-shell-layout.css` —— `.fd-main-nav` / `.fd-main-nav-item` / `.fd-ir-reading-layer` /
///   `.fd-immersive-hotzone` / `.fd-reader-top`
/// - `02-main-library.css` —— `.fd-continue-card` / `.fd-book-grid` / `.fd-book-card`
/// - `03-reader.css` —— 阅读设置/外观面板
///
/// 用途：SwiftUI 视图按这些 token 对齐 demo 骨架的「大小 / 内容 / 组成 / 样式 /
/// 相对位置 / 文字大小 / 位置 / 显示范围」，不依赖 Web CSS。
public enum ReaderDesignTokens {

    // MARK: - Phone / Safe Area

    /// `.fd-phone` 宽度（demo: 390px）。
    public static let phoneWidth: CGFloat = 390
    /// `.fd-phone` 高度（demo: 844px）。
    public static let phoneHeight: CGFloat = 844
    /// `.fd-phone` 圆角（demo: `--fd-radius-device` 34px）。
    public static let phoneCornerRadius: CGFloat = 34

    /// `.fd-status-bar` 高度（demo: 48px）。
    public static let statusBarHeight: CGFloat = 48
    /// `.fd-top-bar` 最小高度（demo: `--reader-ds-size-top-bar-height` 取 58px）。
    public static let topBarMinHeight: CGFloat = 58
    /// `.fd-top-bar` top padding（demo: 6px）。
    public static let topBarTopPadding: CGFloat = 6
    /// `.fd-top-bar` horizontal padding（demo: 20px）。
    public static let topBarHorizontalPadding: CGFloat = 20
    /// `.fd-top-actions` gap（demo: 18px）。
    public static let topBarActionGap: CGFloat = 18
    /// `.fd-icon-button` size（demo: 44px）。
    public static let topBarIconButtonSize: CGFloat = 44
    /// `.fd-back-bar` grid gap（demo: 10px）。
    public static let backBarGap: CGFloat = 10
    /// `.fd-back-bar h1` font size（demo: 24px）。
    public static let backBarTitleFontSize: CGFloat = 24

    // MARK: - Shared content/card/chip primitives

    public static let demoContentGap: CGFloat = 10
    public static let demoContentHorizontalPadding: CGFloat = 16
    public static let demoContentVerticalPadding: CGFloat = 14
    public static let mainTabContentBottomPadding: CGFloat = 102
    public static let cardPadding: CGFloat = 12
    public static let tabletNavWidth: CGFloat = 82
    public static let tabletNavItemHeight: CGFloat = 58
    public static let bottomFixedActionRowMinHeight: CGFloat = 52
    public static let bottomFixedActionButtonMinHeight: CGFloat = 46
    public static let chipMinHeight: CGFloat = 32
    public static let chipMinWidth: CGFloat = 62
    public static let chipMaxWidth: CGFloat = 132
    public static let chipHorizontalPadding: CGFloat = 10
    public static let chipFontSize: CGFloat = 12
    /// `.fd-filter-control` gap（demo: 7px）。
    public static let filterControlGap: CGFloat = 7
    /// `.fd-filter-trigger` / `.fd-filter-apply` min-height（demo: 34px）。
    public static let filterControlMinHeight: CGFloat = 34
    /// `.fd-filter-trigger` icon column（demo: 16px）。
    public static let filterTriggerIconColumn: CGFloat = 16
    /// `.fd-filter-trigger` chevron column（demo: 14px）。
    public static let filterTriggerChevronColumn: CGFloat = 14
    /// `.fd-filter-trigger` gap（demo: 7px）。
    public static let filterTriggerGap: CGFloat = 7
    /// `.fd-filter-trigger` horizontal padding（demo: 10px）。
    public static let filterTriggerHorizontalPadding: CGFloat = 10
    /// `.fd-filter-apply` min-width（demo: 64px）。
    public static let filterApplyMinWidth: CGFloat = 64
    /// `.fd-filter-menu` gap（demo: 10px）。
    public static let filterMenuGap: CGFloat = 10
    /// `.fd-filter-menu` padding（demo: 10px）。
    public static let filterMenuPadding: CGFloat = 10
    /// `.fd-filter-menu article` gap（demo: 7px）。
    public static let filterMenuGroupGap: CGFloat = 7
    /// `.fd-filter-menu button` min-height（demo: 30px）。
    public static let filterMenuOptionMinHeight: CGFloat = 30
    /// `.fd-filter-menu button` gap / row wrap gap（demo: 5-6px）。
    public static let filterMenuOptionGap: CGFloat = 6
    /// `.fd-search-entry` 最小高度（demo: 44px）。
    public static let searchEntryMinHeight: CGFloat = 44
    /// `.fd-search-entry` icon column（demo: 24px）。
    public static let searchEntryIconColumn: CGFloat = 24
    /// `.fd-search-entry` gap（demo: 10px）。
    public static let searchEntryGap: CGFloat = 10
    /// `.fd-search-entry` horizontal padding（demo: 14px）。
    public static let searchEntryHorizontalPadding: CGFloat = 14
    /// `.fd-search-state` gap（demo: 12px）。
    public static let searchStateGap: CGFloat = 12
    /// `.fd-search-state/results` padding（demo: 16px）。
    public static let searchStatePadding: CGFloat = 16
    /// `.fd-search-history-row` 最小高度（demo: 52px）。
    public static let searchHistoryRowMinHeight: CGFloat = 52
    /// `.fd-search-history-row` icon column（demo: 20px）。
    public static let searchHistoryIconColumn: CGFloat = 20
    /// `.fd-search-history-row` action column（demo: 40px）。
    public static let searchHistoryActionColumn: CGFloat = 40
    /// `.fd-search-history-row` gap（demo: 10px）。
    public static let searchHistoryRowGap: CGFloat = 10
    /// `.fd-search-section-head button` 最小高度（demo: 28px）。
    public static let searchSectionActionMinHeight: CGFloat = 28
    /// `.fd-search-result-list` gap（demo: 9px）。
    public static let searchResultListGap: CGFloat = 9
    /// `.fd-search-result-row` 最小高度（demo: 86px）。
    public static let searchResultRowMinHeight: CGFloat = 86
    /// `.fd-search-result-row` cover width（demo: 46px）。
    public static let searchResultCoverWidth: CGFloat = 46
    /// `.fd-search-result-row` cover height（demo: 64px）。
    public static let searchResultCoverHeight: CGFloat = 64
    /// `.fd-search-result-row` status column（demo: 58px）。
    public static let searchResultStateColumn: CGFloat = 58
    /// `.fd-search-result-row` action column（demo: 64px）。
    public static let searchResultActionColumn: CGFloat = 64
    /// `.fd-search-result-row` gap（demo: 8px）。
    public static let searchResultRowGap: CGFloat = 8
    /// `.fd-search-result-row` padding（demo: 10px）。
    public static let searchResultRowPadding: CGFloat = 10
    /// `.fd-search-result-row > button` 最小高度（demo: 28px）。
    public static let searchResultActionMinHeight: CGFloat = 28

    // MARK: - Discover controls

    public static let discoverSourceBarMinHeight: CGFloat = 58
    public static let discoverSourceIconColumn: CGFloat = 34
    public static let discoverSourceChevronColumn: CGFloat = 18
    public static let discoverSourceGap: CGFloat = 10
    public static let discoverSourcePadding: CGFloat = 12
    public static let discoverEntryRowGap: CGFloat = 7
    public static let discoverControlPanelGap: CGFloat = 10

    // MARK: - RSS controls

    public static let rssSummaryMinHeight: CGFloat = 62
    public static let rssSummaryIconColumn: CGFloat = 34
    public static let rssSummaryGap: CGFloat = 10
    public static let rssTopBarGap: CGFloat = 10
    public static let rssTopActionMinHeight: CGFloat = 34
    public static let rssTopRefreshDotSize: CGFloat = 9
    public static let rssTopRefreshGap: CGFloat = 7
    public static let rssTopManageMinWidth: CGFloat = 64
    public static let rssModeRowMinHeight: CGFloat = 30
    public static let rssModeRowGap: CGFloat = 6
    public static let rssSourceStripItemWidth: CGFloat = 138
    public static let rssSourceStripMinHeight: CGFloat = 58
    public static let rssSourceStripIconColumn: CGFloat = 26
    public static let rssSearchEntryMinHeight: CGFloat = 44
    public static let rssReaderSourceMinHeight: CGFloat = 58
    public static let rssReaderSourceIconSize: CGFloat = 32
    public static let rssReaderSourceIconColumn: CGFloat = 32
    public static let rssReaderTitleFontSize: CGFloat = 20
    public static let rssReaderTitleLineHeight: CGFloat = 1.28
    public static let rssReaderSubtitleFontSize: CGFloat = 13
    public static let rssReaderSubtitleLineHeight: CGFloat = 1.62
    public static let rssReaderInlineActionMinHeight: CGFloat = 34
    public static let rssReaderBodyFontSize: CGFloat = 15
    public static let rssReaderBodyLineHeight: CGFloat = 1.86
    public static let rssReaderBodyParagraphGap: CGFloat = 12
    public static let rssReaderOriginalCardMinHeight: CGFloat = 58
    public static let rssReaderBottomActionsMinHeight: CGFloat = 86
    public static let rssOriginalPreviewGap: CGFloat = 12
    public static let rssOriginalHeaderMinHeight: CGFloat = 62
    public static let rssOriginalHeaderIconSize: CGFloat = 32
    public static let rssOriginalWebPreviewMinHeight: CGFloat = 360
    public static let rssOriginalWebPreviewTitleFontSize: CGFloat = 17
    public static let rssOriginalWebPreviewBodyFontSize: CGFloat = 13
    public static let rssManageActionButtonMinHeight: CGFloat = 38
    public static let rssManageActionGridGap: CGFloat = 6
    public static let rssSourceListRowMinHeight: CGFloat = 58
    public static let rssSourceListIconSize: CGFloat = 30
    public static let rssSourceListStatusWidth: CGFloat = 24
    public static let rssSourceListMoreButtonSize: CGFloat = 30
    public static let rssManageBatchRowMinHeight: CGFloat = 38
    public static let rssSourceSettingsRowMinHeight: CGFloat = 50
    public static let rssActionSourceCardMinHeight: CGFloat = 64
    public static let rssActionGridColumns: Int = 4
    public static let rssActionGridGap: CGFloat = 7
    public static let rssActionGridButtonMinHeight: CGFloat = 58
    public static let rssActionGridCompactButtonMinHeight: CGFloat = 54
    public static let rssEditTabsMinHeight: CGFloat = 30
    public static let rssEditListRowMinHeight: CGFloat = 56
    public static let rssDebugPanelPadding: CGFloat = 10
    public static let rssDebugHeaderIconSize: CGFloat = 30
    public static let rssImportPanelPadding: CGFloat = 10
    public static let rssImportPanelLabelMinHeight: CGFloat = 38
    public static let rssImportListIconSize: CGFloat = 28
    public static let rssImportListActionMinHeight: CGFloat = 28
    public static let rssManagementListRowMinHeight: CGFloat = 54
    public static let rssBrowserConfirmCardMinHeight: CGFloat = 256
    public static let rssBrowserConfirmIconSize: CGFloat = 44
    public static let rssBrowserConfirmGap: CGFloat = 10
    public static let rssBrowserConfirmVerticalPadding: CGFloat = 26
    public static let rssBrowserConfirmHorizontalPadding: CGFloat = 18
    public static let rssBrowserConfirmTextMaxWidth: CGFloat = 278
    public static let rssBrowserConfirmTitleFontSize: CGFloat = 17
    public static let rssBrowserConfirmBodyFontSize: CGFloat = 13
    public static let rssBrowserConfirmDetailFontSize: CGFloat = 11

    // MARK: - Settings/source rows

    public static let settingsSectionGap: CGFloat = 8
    public static let settingsSectionTitleFontSize: CGFloat = 13
    public static let settingsRowMinHeight: CGFloat = 58
    public static let settingsRowIconColumn: CGFloat = 28
    public static let settingsRowGap: CGFloat = 10
    public static let settingsRowHorizontalPadding: CGFloat = 12
    public static let settingsRowTitleFontSize: CGFloat = 13
    public static let settingsRowMetaFontSize: CGFloat = 10
    public static let settingsRowValueFontSize: CGFloat = 11
    public static let settingsSwitchTrackWidth: CGFloat = 38
    public static let settingsSwitchTrackHeight: CGFloat = 22
    public static let settingsSwitchThumbSize: CGFloat = 18
    public static let settingsInputRowMinHeight: CGFloat = 68
    public static let settingsInputHeight: CGFloat = 30
    public static let settingsSearchFieldHeight: CGFloat = 40
    public static let sourceRowMinHeight: CGFloat = 64
    public static let sourceRowStatusWidth: CGFloat = 28
    public static let sourceRowActionWidth: CGFloat = 40

    // MARK: - Main Tab 栏（.fd-main-nav）

    /// `.fd-main-nav` 最小高度（demo: `--reader-ds-size-main-nav-height` 68px）。
    public static let mainNavHeight: CGFloat = 68
    /// `.fd-main-nav` 圆角（demo: `--fd-radius-xl` 24px）。
    public static let mainNavCornerRadius: CGFloat = 24
    /// `.fd-main-nav` 横向 padding（demo: 8px）。
    public static let mainNavHorizontalPadding: CGFloat = 8
    /// `.fd-main-nav` 纵向 padding（demo: 7px）。
    public static let mainNavVerticalPadding: CGFloat = 7
    /// `.fd-main-nav` 左右距安全区偏移（demo: `calc(safe-h - 2px)`）。
    public static let mainNavSideInsetAdjustment: CGFloat = -2

    // MARK: - Main Tab Item（.fd-main-nav-item）

    /// `.fd-main-nav-item` icon 行高（demo: 30px）。
    public static let tabItemIconSize: CGFloat = 30
    /// `.fd-main-nav-item` label 行高（demo: 18px）。
    public static let tabItemLabelLineHeight: CGFloat = 18
    /// `.fd-main-nav-item` icon/label 间距（demo: 3px）。
    public static let tabItemGap: CGFloat = 3
    /// `.fd-main-nav-item` 字号（demo: 11px）。
    public static let tabItemFontSize: CGFloat = 11
    /// `.fd-main-nav-icon-shell` 直径（demo: 30px）。
    public static let tabItemIconShellSize: CGFloat = 30

    // MARK: - 顶部栏标题（.fd-top-bar h1）

    /// `.fd-top-bar h1` 字号（demo: 29px）。
    public static let topBarTitleFontSize: CGFloat = 29

    // MARK: - 继续阅读卡（.fd-continue-card）

    /// `.fd-continue-card` 最小高度（demo: 100px）。
    public static let continueCardMinHeight: CGFloat = 100
    /// `.fd-continue-card` 左列宽（cover，demo: 62px）。
    public static let continueCardCoverWidth: CGFloat = 62
    /// `.fd-continue-card` 右列宽（button，demo: 82px）。
    public static let continueCardActionButtonWidth: CGFloat = 82
    /// `.fd-continue-card` 列间距（demo: 14px）。
    public static let continueCardGap: CGFloat = 14
    /// `.fd-continue-card` padding（demo: 10px 16px）。
    public static let continueCardVerticalPadding: CGFloat = 10
    public static let continueCardHorizontalPadding: CGFloat = 16
    /// `.fd-continue-card strong` 字号（serif，demo: 20px）。
    public static let continueCardTitleFontSize: CGFloat = 20
    /// `.fd-continue-card h2` 字号（demo: 13px）。
    public static let continueCardHeaderFontSize: CGFloat = 13
    /// `.fd-continue-action-button` 最小宽（demo: 74px）。
    public static let continueActionButtonMinWidth: CGFloat = 74
    /// `.fd-continue-action-button` 最小高（demo: 40px）。
    public static let continueActionButtonMinHeight: CGFloat = 40
    /// `.fd-continue-cover-button` 宽（demo: 62px，aspect 4:5）。
    public static let continueCoverButtonWidth: CGFloat = 62

    // MARK: - 书架网格（.fd-book-grid / .fd-book-card）

    /// `.fd-section-head` 最小高度（demo: 38px）。
    public static let bookshelfSectionHeadMinHeight: CGFloat = 38
    /// `.fd-section-head` 主轴间距（demo: 12px）。
    public static let bookshelfSectionHeadGap: CGFloat = 12
    /// `.fd-section-head span` action 间距（demo: 8px）。
    public static let bookshelfSectionActionGap: CGFloat = 8
    /// `.fd-section-head button` 尺寸（demo: 34px）。
    public static let bookshelfSectionActionSize: CGFloat = 34
    /// `.fd-book-grid` 列数（demo: repeat(3, 1fr)）。
    public static let bookGridColumns: Int = 3
    /// `.fd-book-grid` 行间距（demo: 16px）。
    public static let bookGridRowSpacing: CGFloat = 16
    /// `.fd-book-grid` 列间距（demo: 30px）。
    public static let bookGridColumnSpacing: CGFloat = 30
    /// `.fd-book-grid.is-list-view` 行间距（demo: 10px）。
    public static let bookGridListRowSpacing: CGFloat = 10
    /// `.fd-book-card` 内容间距（demo: 6px）。
    public static let bookCardGap: CGFloat = 6
    /// `.fd-book-grid.is-list-view .fd-book-card` 最小高度（demo: 66px）。
    public static let bookListCardMinHeight: CGFloat = 66
    /// `.fd-book-grid.is-list-view .fd-book-card` 封面列宽（demo: 48px）。
    public static let bookListCoverWidth: CGFloat = 48
    /// `.fd-book-grid.is-list-view .fd-book-card` 列间距（demo: 10px）。
    public static let bookListColumnGap: CGFloat = 10
    /// `.fd-book-grid.is-list-view .fd-book-card` 行间距（demo: 2px）。
    public static let bookListRowGap: CGFloat = 2
    /// `.fd-book-cover-frame` 宽高比（demo: aspect-ratio 4/5）。
    public static let bookCoverAspectRatio: CGFloat = 4.0 / 5.0
    /// `.fd-book-card strong` 字号（serif，demo: 15px）。
    public static let bookCardTitleFontSize: CGFloat = 15
    /// `.fd-book-card span` 字号（demo: 12px）。
    public static let bookCardMetaFontSize: CGFloat = 12
    /// `.fd-book-card strong` 行高（demo: 1.22）。
    public static let bookCardTitleLineHeight: CGFloat = 1.22
    /// `.fd-book-card strong` 最大行数（demo: `--reader-ds-text-book-title-lines` 取 2）。
    public static let bookCardTitleLineLimit: Int = 2
    /// `.fd-book-card span` 行高（demo: 1.25）。
    public static let bookCardMetaLineHeight: CGFloat = 1.25
    /// `.fd-book-cover-frame` cover 态圆角（demo: `--fd-radius-md` 8px）。
    public static let bookCoverFrameCornerRadius: CGFloat = 8
    /// `.fd-book-grid.is-list-view .fd-book-cover-frame` 圆角（demo: `--fd-radius-sm` 6px）。
    public static let bookListCoverCornerRadius: CGFloat = 6
    /// `[data-book-cover]` long press threshold before `openBookFocus()` (demo JS: 560ms).
    public static let bookFocusLongPressDuration: Double = 0.56
    /// `.fd-book-focus-menu` 左右 inset（demo: 18px）。
    public static let bookFocusMenuHorizontalInset: CGFloat = 18
    /// `.fd-book-focus-menu` 距主导航/安全区上方额外距离（demo: 12px）。
    public static let bookFocusMenuBottomGap: CGFloat = 12
    /// `.fd-book-focus-menu` 内容间距（demo: 12px）。
    public static let bookFocusMenuGap: CGFloat = 12
    /// `.fd-book-focus-menu` padding（demo: 14px）。
    public static let bookFocusMenuPadding: CGFloat = 14
    /// `.fd-book-focus-menu` 边框透明度（demo: rgba(..., 0.54)）。
    public static let bookFocusMenuBorderOpacity: CGFloat = 0.54
    /// `.fd-book-focus-backdrop` 背景透明度（demo: rgba(31,27,23,0.34)）。
    public static let bookFocusBackdropOpacity: CGFloat = 0.34
    /// `.fd-book-focus-cover` 规格（demo render uses cover thumbnail in menu, CSS-owned 42px).
    public static let bookFocusCoverSize: CGFloat = 42
    /// `.fd-book-focus-menu button` 最小高度（component matrix from demo structure: 54px）。
    public static let bookFocusActionMinHeight: CGFloat = 54
    /// `.fd-bookshelf-more-menu` 宽度（demo: 238px）。
    public static let bookshelfMoreMenuWidth: CGFloat = 238
    /// `.fd-bookshelf-more-menu` top = safe top + top bar + 8px.
    public static let bookshelfMoreMenuTopGap: CGFloat = 8
    /// `.fd-bookshelf-more-menu` right = safe horizontal + 2px.
    public static let bookshelfMoreMenuRightGap: CGFloat = 2
    /// `.fd-bookshelf-more-menu` gap（demo: 8px）。
    public static let bookshelfMoreMenuGap: CGFloat = 8
    /// `.fd-bookshelf-more-menu` padding（demo: 12px）。
    public static let bookshelfMoreMenuPadding: CGFloat = 12
    /// `.fd-bookshelf-more-menu button` min-height（demo: 48px）。
    public static let bookshelfMoreActionMinHeight: CGFloat = 48
    /// `.fd-bookshelf-more-menu button` grid icon col（demo: 24px）。
    public static let bookshelfMoreActionIconColumn: CGFloat = 24
    /// `.fd-bookshelf-more-menu button` gap（demo: 10px）。
    public static let bookshelfMoreActionGap: CGFloat = 10
    /// `.fd-bookshelf-more-menu button` horizontal padding（demo: 8px）。
    public static let bookshelfMoreActionHorizontalPadding: CGFloat = 8
    /// `.fd-bookshelf-more-backdrop` 背景透明度（demo: rgba(31,27,23,0.18)）。
    public static let bookshelfMoreBackdropOpacity: CGFloat = 0.18
    /// `.fd-batch-summary` padding（demo: 14px）。
    public static let bookBatchSummaryPadding: CGFloat = 14
    /// `.fd-management-list.is-book-batch article` 最小高度（demo: 62px）。
    public static let bookBatchRowMinHeight: CGFloat = 62
    /// `.fd-management-list.is-book-batch article` 选择列宽（demo: 28px）。
    public static let bookBatchSelectColumn: CGFloat = 28
    /// `.fd-management-list.is-book-batch img` 宽度（demo: 34px）。
    public static let bookBatchCoverWidth: CGFloat = 34
    /// `.fd-book-select-toggle` 宽高（demo: 24px）。
    public static let bookBatchSelectSize: CGFloat = 24
    /// `.fd-management-list.is-book-batch article` gap（demo: 12px）。
    public static let bookBatchRowGap: CGFloat = 12
    /// `.fd-management-list` top padding（demo: 14px）。
    public static let bookGroupListTopPadding: CGFloat = 14
    /// `.fd-management-list article` icon column（demo: 24px）。
    public static let bookGroupIconColumn: CGFloat = 24
    /// `.fd-management-list article` gap（demo: 12px）。
    public static let bookGroupRowGap: CGFloat = 12
    /// `.fd-management-list article` horizontal padding（demo: 14px）。
    public static let bookGroupRowHorizontalPadding: CGFloat = 14
    /// `.fd-management-list.is-group-flow article` 最小高度（demo inherited 68px）。
    public static let bookGroupRowMinHeight: CGFloat = 68
    /// `.fd-management-list.is-assignment-flow article` 最小高度（demo: 58px）。
    public static let bookGroupAssignmentRowMinHeight: CGFloat = 58
    /// `.fd-management-list button/em` 最小高度（demo: 30px）。
    public static let bookGroupActionMinHeight: CGFloat = 30
    /// `.fd-management-list.is-group-flow button.is-plain` 尺寸（demo: 30px）。
    public static let bookGroupDeleteButtonSize: CGFloat = 30
    /// `.fd-import-card` icon column（demo: 42px）。
    public static let bookImportEntryIconColumn: CGFloat = 42
    /// `.fd-import-card` medium icon size（demo `.fd-medium-icon`: 28px）。
    public static let bookImportEntryIconSize: CGFloat = 28
    /// `.fd-import-card` gap（demo: 12px）。
    public static let bookImportEntryGap: CGFloat = 12
    /// `.fd-import-card` padding（demo: 16px）。
    public static let bookImportEntryPadding: CGFloat = 16
    /// `.fd-import-card button` 最小高度（demo: 34px）。
    public static let bookImportEntryButtonMinHeight: CGFloat = 34
    /// `.fd-import-card button` horizontal padding（demo: 14px）。
    public static let bookImportEntryButtonHorizontalPadding: CGFloat = 14
    /// `.fd-management-list.is-import-options/results article` 最小高度（demo: 58px）。
    public static let bookImportListRowMinHeight: CGFloat = 58
    /// `.fd-chapter-list` top padding（demo: 14px）。
    public static let bookDirectoryListTopPadding: CGFloat = 14
    /// `.fd-directory-full-list` content gap（demo: 10px）。
    public static let bookDirectoryFullGap: CGFloat = 10
    /// `.fd-directory-full-list` horizontal padding（demo: 14px）。
    public static let bookDirectoryFullHorizontalPadding: CGFloat = 14
    /// `.fd-directory-full-list` top padding（demo: 12px）。
    public static let bookDirectoryFullTopPadding: CGFloat = 12
    /// `.fd-directory-full-list` bottom padding（demo: 18px）。
    public static let bookDirectoryFullBottomPadding: CGFloat = 18
    /// `.fd-directory-full-head` 最小高度（demo: 44px）。
    public static let bookDirectoryHeaderMinHeight: CGFloat = 44
    /// `.fd-directory-toc-switch-row` gap（demo: 8px）。
    public static let bookDirectorySwitchGap: CGFloat = 8
    /// `.fd-directory-toc-switch-row button` 最小高度（demo: 34px）。
    public static let bookDirectorySwitchButtonMinHeight: CGFloat = 34
    /// `.fd-directory-full-list article` 最小高度（demo: 48px）。
    public static let bookDirectoryRowMinHeight: CGFloat = 48
    /// `.fd-directory-full-list article` trailing marker column（demo: 64px）。
    public static let bookDirectoryMarkerColumnWidth: CGFloat = 64
    /// `.fd-chapter-marker-slots` marker size（demo: 26px）。
    public static let bookDirectoryMarkerSize: CGFloat = 26
    /// `.fd-chapter-marker-slots` gap（demo: 6px）。
    public static let bookDirectoryMarkerGap: CGFloat = 6
    /// `.fd-book-detail-hero` grid cover width（demo: 86px）。
    public static let bookDetailHeroCoverWidth: CGFloat = 86
    /// `.fd-book-detail-hero img` height（demo: 122px）。
    public static let bookDetailHeroCoverHeight: CGFloat = 122
    /// `.fd-book-detail-hero` gap（demo: 14px）。
    public static let bookDetailHeroGap: CGFloat = 14
    /// `.fd-book-detail-hero` padding（demo: 14px）。
    public static let bookDetailHeroPadding: CGFloat = 14
    /// `.fd-book-inline-source-button` 最小高度（demo: 18px）。
    public static let bookDetailInlineSourceButtonMinHeight: CGFloat = 18
    /// `.fd-book-summary-card` padding（demo: 14px）。
    public static let bookDetailSummaryPadding: CGFloat = 14
    /// `.fd-book-summary-card` gap（demo: 8px）。
    public static let bookDetailSummaryGap: CGFloat = 8
    /// `.fd-book-chapter-preview header` 最小高度（demo: 48px）。
    public static let bookDetailChapterPreviewHeaderMinHeight: CGFloat = 48
    /// `.fd-book-chapter-preview .fd-inline-route` 最小高度（demo: 30px）。
    public static let bookDetailInlineRouteMinHeight: CGFloat = 30
    /// `.fd-chapter-list article` 最小高度（demo: 58px）。
    public static let bookDetailChapterPreviewRowMinHeight: CGFloat = 58

    // MARK: - 沉浸阅读层（.fd-ir-reading-layer）

    /// `.fd-ir-reading-layer` top inset（demo: 72px）。
    public static let immersiveReadingLayerTopInset: CGFloat = 72
    /// `.fd-ir-reading-layer` 横向 inset（demo: 32px）。
    public static let immersiveReadingLayerSideInset: CGFloat = 32
    /// `.fd-ir-reading-layer` bottom inset（demo: 48px）。
    public static let immersiveReadingLayerBottomInset: CGFloat = 48
    /// `.fd-ir-reading-layer p` 字号（demo: 18px）。
    public static let immersiveBodyFontSize: CGFloat = 18
    /// `.fd-ir-reading-layer p` 行高（demo: 1.96）。
    public static let immersiveBodyLineHeight: CGFloat = 1.96
    /// `.fd-ir-reading-layer p` 段落缩进（demo: 2em）。
    public static let immersiveBodyParagraphIndent: CGFloat = 2
    /// `.fd-ir-reading-layer h1` 字号偏移（demo: `calc(font-size + 5px)` → 23px）。
    public static let immersiveTitleFontSizeOffset: CGFloat = 5
    /// `.fd-ir-reading-layer h1` 行高（demo: 1.25）。
    public static let immersiveTitleLineHeight: CGFloat = 1.25
    /// `.fd-ir-reading-layer h1` 下边距（demo: 24px）。
    public static let immersiveTitleBottomMargin: CGFloat = 24
    /// `expanded-width/tablet-expanded .fd-ir-reading-layer` top inset（demo: 92px）。
    public static let readerDockReadingTopInset: CGFloat = 92
    /// `expanded-width/tablet-expanded .fd-ir-reading-layer` side inset（demo: 44px）。
    public static let readerDockReadingSideInset: CGFloat = 44
    /// `expanded-width/tablet-expanded .fd-ir-reading-layer` bottom inset（demo: 56px）。
    public static let readerDockReadingBottomInset: CGFloat = 56
    /// `compact-landscape .fd-ir-reading-layer` top inset（demo: 74px）。
    public static let readerDockCompactReadingTopInset: CGFloat = 74
    /// `compact-landscape .fd-ir-reading-layer` left inset（demo: 30px）。
    public static let readerDockCompactReadingLeftInset: CGFloat = 30
    /// `compact-landscape .fd-ir-reading-layer` bottom inset（demo: 24px）。
    public static let readerDockCompactReadingBottomInset: CGFloat = 24
    /// `compact-landscape .fd-ir-reading-layer` right inset（demo: 384px for 340px dock + gap).
    public static let readerDockCompactReadingRightInset: CGFloat = 384
    /// Tablet reader body avoids the right dock by dock width + 36px.
    public static let readerDockReadingAvoidanceGap: CGFloat = 36
    /// Compact reader body uses dock width + 28px gap before text.
    public static let readerDockCompactReadingGap: CGFloat = 28

    // MARK: - 沉浸热区（.fd-immersive-hotzone）

    /// `.fd-hotzone-prev` 宽度占比（demo: 26%）。
    public static let hotzonePrevRatio: CGFloat = 0.26
    /// `.fd-hotzone-center` 宽度占比（demo: 48%）。
    public static let hotzoneCenterRatio: CGFloat = 0.48
    /// `.fd-hotzone-next` 宽度占比（demo: 26%）。
    public static let hotzoneNextRatio: CGFloat = 0.26

    // MARK: - 阅读顶栏（.fd-reader-top）

    /// `.fd-reader-top` top（demo: 18px）。
    public static let readerTopTopInset: CGFloat = 18
    /// `.fd-reader-top` 左右 inset（demo: 14px）。
    public static let readerTopSideInset: CGFloat = 14
    /// `.fd-reader-top` 最小高度（demo: 54px）。
    public static let readerTopMinHeight: CGFloat = 54
    /// `.fd-reader-top` 圆角（demo: `--fd-radius-xl` 24px）。
    public static let readerTopCornerRadius: CGFloat = 24
    /// `.fd-reader-top strong` 字号（demo: 16px）。
    public static let readerTopTitleFontSize: CGFloat = 16
    /// `.fd-reader-top small` 字号（demo: 12px）。
    public static let readerTopSubtitleFontSize: CGFloat = 12
    /// `.fd-reader-top strong` 最大行数（demo: line-clamp 2）。
    public static let readerTopTitleLineLimit: Int = 2
    /// `.fd-reader-top` back column（demo: 44px）。
    public static let readerTopBackColumnWidth: CGFloat = 44
    /// `.fd-reader-top` source-switch column（demo: 62px）。
    public static let readerTopSourceColumnWidth: CGFloat = 62
    /// `.fd-reader-top` more column（demo: 34px）。
    public static let readerTopMoreColumnWidth: CGFloat = 34
    /// `.fd-reader-top` grid gap（demo: 8px）。
    public static let readerTopGap: CGFloat = 8
    /// `.fd-reader-top` horizontal padding（demo: 12px）。
    public static let readerTopHorizontalPadding: CGFloat = 12
    /// `.fd-reader-top button` min-height（demo: 42px）。
    public static let readerTopButtonMinHeight: CGFloat = 42
    /// `compact-landscape .fd-reader-top` top（demo: 12px）。
    public static let readerTopCompactTopInset: CGFloat = 12
    /// `tablet-expanded .fd-reader-top` horizontal inset（demo: 28px）。
    public static let readerTopTabletSideInset: CGFloat = 28
    /// `compact-landscape .fd-reader-top` min-height（demo: 48px）。
    public static let readerTopCompactMinHeight: CGFloat = 48
    /// `compact-landscape .fd-reader-top` back column（demo: 40px）。
    public static let readerTopCompactBackColumnWidth: CGFloat = 40
    /// `compact-landscape .fd-reader-top` source-switch column（demo: 58px）。
    public static let readerTopCompactSourceColumnWidth: CGFloat = 58
    /// `compact-landscape .fd-reader-top` more column（demo: 32px）。
    public static let readerTopCompactMoreColumnWidth: CGFloat = 32
    /// `compact-landscape .fd-reader-top` gap（demo: 6px）。
    public static let readerTopCompactGap: CGFloat = 6
    /// `compact-landscape .fd-reader-top` horizontal padding（demo: 10px）。
    public static let readerTopCompactHorizontalPadding: CGFloat = 10
    /// `compact-landscape .fd-reader-top strong` 字号（demo: 13px）。
    public static let readerTopCompactTitleFontSize: CGFloat = 13
    /// `compact-landscape .fd-reader-top small` 字号（demo: 10px）。
    public static let readerTopCompactSubtitleFontSize: CGFloat = 10
    /// `compact-landscape .fd-reader-top button` min-height（demo: 36px）。
    public static let readerTopCompactButtonMinHeight: CGFloat = 36
    /// `compact-landscape .fd-reader-top button` 字号（demo: 11px）。
    public static let readerTopCompactButtonFontSize: CGFloat = 11

    // MARK: - 发现页书籍行（.fd-discover-book-row）

    /// `.fd-discover-book-row` 最小高度（demo: 108px）。
    public static let discoverBookRowMinHeight: CGFloat = 108
    /// `.fd-discover-book-row` 左列宽（cover，demo: 52px）。
    public static let discoverBookRowCoverWidth: CGFloat = 52
    /// `.fd-discover-book-row` 列间距（demo: 11px）。
    public static let discoverBookRowGap: CGFloat = 11
    /// `.fd-discover-book-row` padding（demo: 12px）。
    public static let discoverBookRowPadding: CGFloat = 12
    /// `.fd-discover-book-row img` 高（demo: 74px）。
    public static let discoverBookRowCoverHeight: CGFloat = 74
    /// `.fd-discover-book-row h3` 字号（demo: 15px）。
    public static let discoverBookRowTitleFontSize: CGFloat = 15
    /// `.fd-discover-book-row h3` 行高（demo: 1.25）。
    public static let discoverBookRowTitleLineHeight: CGFloat = 1.25
    /// `.fd-discover-book-row small` 字号（demo: 11px）。
    public static let discoverBookRowSmallFontSize: CGFloat = 11
    /// `.fd-discover-book-row p` 字号（demo: 12px）。
    public static let discoverBookRowBodyFontSize: CGFloat = 12
    /// `.fd-discover-book-row p` 行高（demo: 1.45）。
    public static let discoverBookRowBodyLineHeight: CGFloat = 1.45
    /// `.fd-discover-book-row p` 最大行数（demo: line-clamp 2）。
    public static let discoverBookRowBodyLineLimit: Int = 2

    // MARK: - RSS 文章行（.fd-rss-article-row）

    /// `.fd-rss-article-row` 最小高度（demo: 84px）。
    public static let rssArticleRowMinHeight: CGFloat = 84
    /// `.fd-rss-article-row` 左列宽（dot，demo: 10px）。
    public static let rssArticleRowDotColumn: CGFloat = 10
    /// `.fd-rss-article-row` 右列宽（chevron，demo: 18px）。
    public static let rssArticleRowChevronColumn: CGFloat = 18
    /// `.fd-rss-article-row` 列间距（demo: 8px）。
    public static let rssArticleRowGap: CGFloat = 8
    /// `.fd-rss-article-row` 纵向 padding（demo: 10px）。
    public static let rssArticleRowVerticalPadding: CGFloat = 10
    /// `.fd-rss-article-row` 横向 padding（demo: 12px）。
    public static let rssArticleRowHorizontalPadding: CGFloat = 12
    /// `.fd-rss-article-row > i` 直径（demo: 7px）。
    public static let rssArticleRowDotSize: CGFloat = 7
    /// `.fd-rss-article-row strong` 字号（demo: 13px）。
    public static let rssArticleRowTitleFontSize: CGFloat = 13
    /// `.fd-rss-article-row strong` 行高（demo: 1.25）。
    public static let rssArticleRowTitleLineHeight: CGFloat = 1.25
    /// `.fd-rss-article-row small` 字号（demo: 10px）。
    public static let rssArticleRowSmallFontSize: CGFloat = 10
    /// `.fd-rss-article-row p` 字号（demo: 11px）。
    public static let rssArticleRowBodyFontSize: CGFloat = 11
    /// `.fd-rss-article-row p` 行高（demo: 1.45）。
    public static let rssArticleRowBodyLineHeight: CGFloat = 1.45
    /// `.fd-rss-article-row p` 最大行数（demo: line-clamp 2）。
    public static let rssArticleRowBodyLineLimit: Int = 2

    // MARK: - 阅读底栏模块导航（.fd-reader-module-nav）

    /// `.fd-reader-module-nav` 左右 inset（demo: 24px）。
    public static let readerModuleNavSideInset: CGFloat = 24
    /// `.fd-reader-module-nav` 距底（demo: 32px）。
    public static let readerModuleNavBottomInset: CGFloat = 32
    /// `.fd-reader-module-nav` 列数（demo: repeat(4, 1fr)）。
    public static let readerModuleNavColumns: Int = 4
    /// `.fd-reader-module-nav` 列间距（demo: 4px）。
    public static let readerModuleNavGap: CGFloat = 4
    /// `.fd-reader-module-nav` 最小高度（demo: 78px）。
    public static let readerModuleNavMinHeight: CGFloat = 78
    /// `.fd-reader-module-nav` padding（demo: 8px）。
    public static let readerModuleNavPadding: CGFloat = 8
    /// `.fd-reader-module-nav` 圆角（demo: `--fd-radius-lg` 12px）。
    public static let readerModuleNavCornerRadius: CGFloat = 12

    // MARK: - Reader control sheet / session capsule

    public static let readerControlSheetSideInset: CGFloat = 12
    public static let readerControlSheetBottomInset: CGFloat = 18
    public static let readerControlSheetHeight: CGFloat = 330
    public static let readerControlSheetGap: CGFloat = 10
    public static let readerControlMainActionRowHeight: CGFloat = 70
    public static let readerControlChapterPanelHeight: CGFloat = 96
    public static let readerControlLabelFontSize: CGFloat = 11
    public static let readerSettingsPanelRowHeight: CGFloat = 32
    public static let readerSettingsSwatchSize: CGFloat = 18
    public static let readerSettingsLargeSwatchWidth: CGFloat = 22
    public static let readerSettingsStepperSize: CGFloat = 24
    public static let readerSessionCapsuleHeight: CGFloat = 44
    public static let readerSessionCapsuleIconSize: CGFloat = 28
    public static let readerSessionCapsuleCountdownSize: CGFloat = 22
    /// Demo `viewportClassSnapshot()` expanded-width threshold.
    public static let readerExpandedWidthMinWidth: CGFloat = 600
    /// Demo `viewportClassSnapshot()` tablet-expanded threshold.
    public static let readerTabletExpandedMinWidth: CGFloat = 840
    /// Demo `viewportClassSnapshot()` compact-landscape height threshold.
    public static let readerCompactLandscapeMaxHeight: CGFloat = 520
    /// `--reader-quick-panel-max-width` (demo: 340px).
    public static let readerDockMaxWidth: CGFloat = 340
    /// `expanded-width --reader-dock-right` (demo: 18px).
    public static let readerDockExpandedRightInset: CGFloat = 18
    /// `tablet-expanded --reader-dock-right` (demo: 24px).
    public static let readerDockTabletRightInset: CGFloat = 24
    /// `compact-landscape --reader-dock-right` (demo: 16px).
    public static let readerDockCompactRightInset: CGFloat = 16
    /// `--reader-quick-panel-wide-width` budget: calc(100% - 36px).
    public static let readerDockExpandedWidthInsetBudget: CGFloat = 36
    /// `compact-landscape --reader-dock-width` ratio (demo: min(340px, 46%)).
    public static let readerDockCompactWidthRatio: CGFloat = 0.46
    /// `--reader-quick-control-wide-height` / module height (demo: 252px).
    public static let readerDockWideSheetHeight: CGFloat = 252
    /// `--reader-quick-compact-height` (demo: 230px).
    public static let readerDockCompactSheetHeight: CGFloat = 230
    /// `--reader-dock-nav-bottom` (demo: 32px).
    public static let readerDockNavBottomInset: CGFloat = 32
    /// `compact-landscape --reader-dock-nav-bottom` (demo: 16px).
    public static let readerDockCompactNavBottomInset: CGFloat = 16
    /// `--reader-dock-nav-height` (demo: 79px, includes border rounding).
    public static let readerDockNavHeight: CGFloat = 79
    /// `compact-landscape --reader-dock-nav-height` (demo: 54px).
    public static let readerDockCompactNavHeight: CGFloat = 54
    /// `--reader-dock-gap` (demo: -1px, sheet and nav visually join).
    public static let readerDockGap: CGFloat = -1
    /// `--reader-control-actions-min-height` in wide dock (demo: 50px).
    public static let readerDockControlActionRowHeight: CGFloat = 50
    /// `--reader-control-chapter-min-height` in wide dock (demo: 64px).
    public static let readerDockChapterPanelHeight: CGFloat = 64
    /// Compact landscape action row height (demo: 46px).
    public static let readerDockCompactControlActionRowHeight: CGFloat = 46
    /// Compact landscape chapter panel height (demo: 56px).
    public static let readerDockCompactChapterPanelHeight: CGFloat = 56
    /// Compact landscape module gap (demo: 3px).
    public static let readerDockCompactModuleGap: CGFloat = 3
    /// Compact landscape module nav padding (demo: 5px).
    public static let readerDockCompactModulePadding: CGFloat = 5
    /// Compact landscape module icon shell (demo: 28px).
    public static let readerDockCompactModuleIconShellSize: CGFloat = 28
    /// Compact landscape module label font size (demo: 9px).
    public static let readerDockCompactModuleFontSize: CGFloat = 9

    // MARK: - Reader source-switch flow

    public static let sourceSwitchFlowGap: CGFloat = 12
    public static let sourceSwitchWindowWidth: CGFloat = 300
    public static let sourceSwitchResultWidth: CGFloat = 200
    public static let sourceSwitchResultPadding: CGFloat = 16
    public static let sourceSwitchResultGap: CGFloat = 12
    public static let sourceSwitchResultIconSize: CGFloat = 36
    public static let sourceSwitchResultButtonMinHeight: CGFloat = 42
    public static let sourceSwitchCandidateRowMinHeight: CGFloat = 54
    public static let sourceSwitchCandidateRowGap: CGFloat = 7

    // MARK: - 阅读模块项（.fd-reader-module）

    /// `.fd-reader-module` icon 行高（demo: 42px）。
    public static let readerModuleIconRowHeight: CGFloat = 42
    /// `.fd-reader-module` label 行高（demo: 16px）。
    public static let readerModuleLabelRowHeight: CGFloat = 16
    /// `.fd-reader-module` 行间距（demo: 4px）。
    public static let readerModuleGap: CGFloat = 4
    /// `.fd-reader-module span` 直径（demo: 42px）。
    public static let readerModuleIconShellSize: CGFloat = 42
    /// `.fd-reader-module` 字号（demo: 12px）。
    public static let readerModuleFontSize: CGFloat = 12
    /// `.fd-reader-module` 文本色 #4d463f。
    public static let readerModuleTextColor = SwiftUI.Color(red: 0x4d/255, green: 0x46/255, blue: 0x3f/255)

    // MARK: - 颜色（来自 CSS 实际 rgba/hex 值）

    public enum Color {
        /// `--fd-paper-solid` #f8f4ec
        public static let paperSolid = SwiftUI.Color(red: 0xf8/255, green: 0xf4/255, blue: 0xec/255)
        /// `--fd-surface` rgba(255,252,248,0.9)
        public static let surface = SwiftUI.Color(red: 1, green: 252/255, blue: 248/255, opacity: 0.9)
        /// `.fd-main-nav` 背景 rgba(255,252,248,0.92)
        public static let mainNavBackground = SwiftUI.Color(red: 1, green: 252/255, blue: 248/255, opacity: 0.92)
        /// `.fd-main-nav-item` 非选中色 #6b625a
        public static let tabItemInactive = SwiftUI.Color(red: 0x6b/255, green: 0x62/255, blue: 0x5a/255)
        /// `--fd-primary` rgba(35,121,164) = #2379a4
        public static let primary = SwiftUI.Color(red: 35/255, green: 121/255, blue: 164/255)
        /// `--fd-primary-dark` rgba(49,95,120) = #315f78
        public static let primaryDark = SwiftUI.Color(red: 49/255, green: 95/255, blue: 120/255)
        /// `.fd-reader-top` 背景 rgba(255,250,244,0.92)
        public static let readerTopBackground = SwiftUI.Color(red: 1, green: 250/255, blue: 244/255, opacity: 0.92)
        /// `.fd-reader-top` 边框 rgba(154,139,124,0.35)
        public static let readerTopBorder = SwiftUI.Color(red: 154/255, green: 139/255, blue: 124/255, opacity: 0.35)
        /// `.fd-main-nav` 边框 rgba(180,166,151,0.42)
        public static let mainNavBorder = SwiftUI.Color(red: 180/255, green: 166/255, blue: 151/255, opacity: 0.42)
        /// `.fd-discover-book-row` 顶分隔 rgba(180,166,151,0.24)
        public static let discoverRowBorder = SwiftUI.Color(red: 180/255, green: 166/255, blue: 151/255, opacity: 0.24)
        /// `.fd-rss-article-row` 顶分隔 rgba(180,166,151,0.2)
        public static let rssRowBorder = SwiftUI.Color(red: 180/255, green: 166/255, blue: 151/255, opacity: 0.2)
        /// `.fd-rss-article-row > i` 已读点 rgba(180,166,151,0.5)
        public static let rssDotRead = SwiftUI.Color(red: 180/255, green: 166/255, blue: 151/255, opacity: 0.5)
        /// `.fd-reader-module-nav` 背景 rgba(255,252,248,0.96)
        public static let readerModuleNavBackground = SwiftUI.Color(red: 1, green: 252/255, blue: 248/255, opacity: 0.96)
        /// `.fd-reader-module-nav` 边框 rgba(180,166,151,0.34)
        public static let readerModuleNavBorder = SwiftUI.Color(red: 180/255, green: 166/255, blue: 151/255, opacity: 0.34)
        /// `.fd-reader-module span` 默认背景 rgba(35,121,164,0.08)
        public static let readerModuleIconShellBackground = SwiftUI.Color(red: 35/255, green: 121/255, blue: 164/255, opacity: 0.08)
        /// `.fd-discover-book-row img` 阴影 rgba(80,67,52,0.12)
        public static let discoverCoverShadow = SwiftUI.Color(red: 80/255, green: 67/255, blue: 52/255, opacity: 0.12)
        /// Shared muted chip background from demo control rows.
        public static let chipBackground = SwiftUI.Color(red: 238/255, green: 232/255, blue: 223/255, opacity: 0.9)
        /// Settings row/input background.
        public static let controlBackground = SwiftUI.Color(red: 1, green: 250/255, blue: 244/255, opacity: 0.72)
    }

    // MARK: - 圆角

    public enum Radius {
        /// `--fd-radius-xs` 4px
        public static let xs: CGFloat = 4
        /// `--fd-radius-sm` 6px
        public static let sm: CGFloat = 6
        /// `--fd-radius-md` 8px
        public static let md: CGFloat = 8
        /// `--fd-radius-lg` 12px
        public static let lg: CGFloat = 12
        /// `--fd-radius-xl` 24px
        public static let xl: CGFloat = 24
        /// `--fd-radius-pill` 999px
        public static let pill: CGFloat = 999
        /// `--fd-radius-circle` 50%
        public static let circle: CGFloat = 0.5
    }
}
