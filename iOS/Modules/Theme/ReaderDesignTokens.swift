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
    public static let cardPadding: CGFloat = 14
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

    // MARK: - Reader section / overlay title sizes

    /// 章节列表行标题 / 搜索结果章节标题等 14px 场景（demo `--reader-ds-type-book-title-size: 14px`）。
    public static let readerSectionTitleFontSize: CGFloat = 14
    /// 书详情大标题 / 空态错误态标题 22px（demo `.fd-book-detail-title` / `.fd-empty-title` 真源）。
    public static let readerOverlayLargeTitleFontSize: CGFloat = 22
    /// 阅读器覆盖层 hero 标题 23px（demo `.fd-reader-source-switch-title` 真源）。
    public static let readerOverlayHeroTitleFontSize: CGFloat = 23
    /// 阅读器覆盖层 section 标题 18px（demo `.fd-reader-panel-title` 实际 13px/900，
    /// 此处 18px 作为 reader 覆盖层标题层级，已标注偏差）。
    public static let readerOverlaySectionTitleFontSize: CGFloat = 18
    /// 书详情内联小标签 9px（demo `.fd-book-detail-inline-source-button` 真源）。
    public static let bookDetailInlineSourceButtonFontSize: CGFloat = 9

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
    /// `.fd-continue-cover-button` 宽（demo: 62px，aspect 2:3）。
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
    /// `.fd-book-cover-frame` 宽高比（demo: aspect-ratio 2/3）。
    public static let bookCoverAspectRatio: CGFloat = 2.0 / 3.0
    /// `.fd-continue-cover-button` 宽高比（demo: aspect-ratio 2/3）。
    public static let continueCoverAspectRatio: CGFloat = 2.0 / 3.0
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
        /// `--reader-ds-color-paper` #fff8f4（demo `tokens.css` line 4 真源，
        /// `--fd-paper` 经 `--reader-ds-color-paper` 间接引用此值）
        public static let paperSolid = SwiftUI.Color(red: 1, green: 0xf8/255, blue: 0xf4/255)
        /// `--fd-paper-solid` #f8f4ec（demo `00-foundation.css` line 4 真源，
        /// 用于 `.fd-phone` 外壳 / `body` / flow 容器等基础背景；比 `paperSolid` 更暗的米色）
        public static let paperSolidAlt = SwiftUI.Color(red: 0xf8/255, green: 0xf4/255, blue: 0xec/255)
        /// `--reader-ds-color-surface` rgba(255,255,255,0.88)（demo `tokens.css` line 6 真源，
        /// `--fd-surface` 经 `--reader-ds-color-surface` 间接引用此值）
        public static let surface = SwiftUI.Color(red: 1, green: 1, blue: 1, opacity: 0.88)
        /// `--reader-ds-color-ink` #1f1b17（demo `tokens.css` line 8 真源，文字主色，
        /// 用于 `.fd-*` 中所有 `color: var(--fd-ink)` 的文本，替代系统 `.primary`）
        public static let ink = SwiftUI.Color(red: 0x1f/255, green: 0x1b/255, blue: 0x17/255)
        /// `--reader-ds-color-control-ink` #41484c（demo `tokens.css` line 9 真源，控制文字色，
        /// 用于 reader 控件标签等）
        public static let controlInk = SwiftUI.Color(red: 0x41/255, green: 0x48/255, blue: 0x4c/255)
        /// `--reader-ds-color-accent` #f48b13（demo `tokens.css` line 14 真源，品牌强调橙）
        public static let accent = SwiftUI.Color(red: 0xf4/255, green: 0x8b/255, blue: 0x13/255)
        /// `--reader-ds-color-bottom-bar-bg` #fbf2eb（demo `tokens.css` line 15 真源，底栏背景）
        public static let bottomBarBg = SwiftUI.Color(red: 0xfb/255, green: 0xf2/255, blue: 0xeb/255)
        /// `--reader-ds-color-floating-control-bg` #fbf2eb（demo `tokens.css` line 16 真源，浮动控件背景）
        public static let floatingControlBg = SwiftUI.Color(red: 0xfb/255, green: 0xf2/255, blue: 0xeb/255)
        /// `--reader-ds-color-floating-control-bg-alt` #eae1da（demo `tokens.css` line 17 真源，浮动控件 alt 背景）
        public static let floatingControlBgAlt = SwiftUI.Color(red: 0xea/255, green: 0xe1/255, blue: 0xda/255)
        /// `--reader-ds-color-meta-bg` #f5ece6（demo `tokens.css` line 18 真源，meta 区背景）
        public static let metaBg = SwiftUI.Color(red: 0xf5/255, green: 0xec/255, blue: 0xe6/255)
        /// `.fd-main-nav` 背景 `var(--fd-surface)` rgba(255,255,255,0.88)
        public static let mainNavBackground = SwiftUI.Color(red: 1, green: 1, blue: 1, opacity: 0.88)
        /// `.fd-main-nav-item` 非选中色 `--fd-muted` #756f69 = rgba(117,111,105)
        public static let tabItemInactive = SwiftUI.Color(red: 117/255, green: 111/255, blue: 105/255)
        /// `--fd-muted` #756f69 = rgba(117,111,105)（demo 次要文字色，用于 meta/author 等 muted 文本）
        public static let muted = SwiftUI.Color(red: 117/255, green: 111/255, blue: 105/255)
        /// `--fd-primary` #366179 = rgba(54,97,121)（demo tokens.css 真值）
        public static let primary = SwiftUI.Color(red: 54/255, green: 97/255, blue: 121/255)
        /// `--fd-primary-dark` #274f66 = rgba(39,79,102)（demo tokens.css 真值）
        public static let primaryDark = SwiftUI.Color(red: 39/255, green: 79/255, blue: 102/255)
        /// `.fd-bottom-fixed-action-primary` 渐变起点 #436f88
        /// （demo `01-shell-layout.css` line 1168/1352 真值，与 `--fd-primary` #366179 不同的亮色变体）
        public static let primaryGradientStart = SwiftUI.Color(red: 0x43/255, green: 0x6f/255, blue: 0x88/255)
        /// `.fd-bottom-fixed-action-primary` 渐变终点 #315f78
        /// （demo `01-shell-layout.css` line 1168/1352 真值，与 `--fd-primary-dark` #274f66 不同的暗色变体）
        public static let primaryGradientEnd = SwiftUI.Color(red: 0x31/255, green: 0x5f/255, blue: 0x78/255)
        /// `--reader-control-surface-solid` #fffaf4（demo `02-main-library.css` line 410 真值，
        /// 用于 progress thumb fill 等控件实色表面）
        public static let controlSurfaceSolid = SwiftUI.Color(red: 1, green: 250/255, blue: 244/255)
        /// `--fd-danger` #d62222 = rgba(214,34,34)（demo `00-foundation.css` line 14 真值，
        /// 用于 `.is-danger` / destructive / `accent-color` / `.fd-source-delete-dialog input`）
        public static let danger = SwiftUI.Color(red: 214/255, green: 34/255, blue: 34/255)
        /// `.fd-reader-top` 背景 rgba(255,250,244,0.92)
        public static let readerTopBackground = SwiftUI.Color(red: 1, green: 250/255, blue: 244/255, opacity: 0.92)
        /// `.fd-reader-top` 边框 rgba(154,139,124,0.35)
        public static let readerTopBorder = SwiftUI.Color(red: 154/255, green: 139/255, blue: 124/255, opacity: 0.35)
        /// `--fd-border` #c1c7cd = rgba(193,199,205)（demo `.fd-main-nav` / 通用卡边框真值）
        public static let mainNavBorder = SwiftUI.Color(red: 193/255, green: 199/255, blue: 205/255)
        /// `.fd-search-result-row` 边框 rgba(180,166,151,0.42)（demo 暖棕半透明，仅用于搜索结果行）
        public static let searchResultBorder = SwiftUI.Color(red: 180/255, green: 166/255, blue: 151/255, opacity: 0.42)
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
        public static let controlBackground = SwiftUI.Color(red: 255/255, green: 252/255, blue: 248/255, opacity: 0.72)

        /// 阴影色子集（demo `tokens.css` line 61-62 定义 `--reader-ds-shadow-*`；
        /// `01-shell-layout.css:433` 等处另有 `rgba(48,35,22,*)` 系列，用于搜索框等 inset shadow）。
        public enum Shadow {
            /// `--reader-ds-shadow-soft` rgba(89,70,50,0.1)（demo `tokens.css` line 62 真源）
            public static let soft = SwiftUI.Color(red: 89/255, green: 70/255, blue: 50/255, opacity: 0.1)
            /// `--reader-ds-shadow-elevated` rgba(89,70,50,0.16)（demo `tokens.css` line 61 真源）
            public static let elevated = SwiftUI.Color(red: 89/255, green: 70/255, blue: 50/255, opacity: 0.16)
            /// `.fd-search-entry` / `.fd-top-bar` 等 inset shadow rgba(48,35,22,0.16)
            /// （demo `01-shell-layout.css` line 433 真源，与 `shadowSoft` 不同的棕黑色）
            public static let insetAlt = SwiftUI.Color(red: 48/255, green: 35/255, blue: 22/255, opacity: 0.16)
            /// `.fd-book-detail-hero img` shadow rgba(52,38,26,0.18)
            /// （demo `04-settings-source.css` line 280 真源）
            public static let bookDetailHero = SwiftUI.Color(red: 52/255, green: 38/255, blue: 26/255, opacity: 0.18)
            /// `.fd-settings-option-dropdown` shadow rgba(55,45,32,0.16)
            /// （demo `05-flow-adaptive.css` line 705 真源）
            public static let settingsDropdown = SwiftUI.Color(red: 55/255, green: 45/255, blue: 32/255, opacity: 0.16)
            /// `.fd-book-batch-cover` shadow rgba(45,34,26,0.12)
            /// （demo `04-settings-source.css` line 691 真源）
            public static let bookBatch = SwiftUI.Color(red: 45/255, green: 34/255, blue: 26/255, opacity: 0.12)
            /// `.fd-book-grid.is-list-view .fd-book-cover-frame` shadow rgba(52,38,26,0.12)
            /// （demo `00-foundation.css` line 1262 真源）
            public static let bookList = SwiftUI.Color(red: 52/255, green: 38/255, blue: 26/255, opacity: 0.12)
            /// `.fd-book-detail-hero` shadow rgba(82,66,48,0.18)
            /// （demo `01-shell-layout.css` line 1185 真源）
            public static let bookHero = SwiftUI.Color(red: 82/255, green: 66/255, blue: 48/255, opacity: 0.18)
            /// reader inset shadow rgba(31,27,23,0.16)
            /// （demo `05-flow-adaptive.css` line 666 真源）
            public static let insetDark = SwiftUI.Color(red: 31/255, green: 27/255, blue: 23/255, opacity: 0.16)
            /// reader inset shadow rgba(55,44,32,0.22)
            /// （demo `03-reader.css` line 750 真源）
            public static let readerInset = SwiftUI.Color(red: 55/255, green: 44/255, blue: 32/255, opacity: 0.22)
        }

        /// `--reader-control-ink` #2b251f（demo `02-main-library.css` line 255 真源，
        /// 用于 reader 控件文字色；与 `Color.controlInk` #41484c 不同，后者来自 tokens.css）
        public static let controlInkAlt = SwiftUI.Color(red: 0x2b/255, green: 0x25/255, blue: 0x1f/255)
        /// `--reader-control-icon` #3f372f（demo `02-main-library.css` line 346 真源，
        /// 用于 reader 控件图标色）
        public static let controlIcon = SwiftUI.Color(red: 0x3f/255, green: 0x37/255, blue: 0x2f/255)
        /// `#4e443a`（demo `01-shell-layout.css` line 220/402 真源，
        /// reader 控件图标色的另一个 fallback 值，用于次要图标文字）
        public static let controlIconAlt = SwiftUI.Color(red: 0x4e/255, green: 0x44/255, blue: 0x3a/255)
        /// `.fd-discover-dialog-backdrop` rgba(35,28,22,0.26)
        /// （demo `01-shell-layout.css` line 1804 真源，用于发现页对话框遮罩）
        public static let dialogBackdrop = SwiftUI.Color(red: 35/255, green: 28/255, blue: 22/255, opacity: 0.26)
        /// `.fd-book-focus-backdrop` rgba(31,27,23,0.34)
        /// （demo `00-foundation.css` line 1343 真源，用于书架焦点遮罩）
        public static let focusBackdrop = SwiftUI.Color(red: 31/255, green: 27/255, blue: 23/255, opacity: 0.34)
        /// neutral border rgba(140,130,118,0.26)
        /// （demo `05-flow-adaptive.css` line 657 真源，用于 reader 控件边框）
        public static let neutralBorder26 = SwiftUI.Color(red: 140/255, green: 130/255, blue: 118/255, opacity: 0.26)
        /// reader track fill #aaa39a
        /// （demo `03-reader.css` line 738 真源，用于 reader 进度轨道填充）
        public static let readerTrackFill = SwiftUI.Color(red: 170/255, green: 163/255, blue: 154/255)
        /// `--reader-control-panel-soft` rgba(238,230,219,0.56)
        /// （demo `02-main-library.css` line 898 真源，用于 reader 控件面板半透明背景）
        public static let controlPanelSoft56 = SwiftUI.Color(red: 238/255, green: 230/255, blue: 219/255, opacity: 0.56)
        /// reader paper 渐变起点 rgba(255,249,242,0.94)
        /// （demo `01-shell-layout.css` line 2497 真源，`.fd-ir-reading-layer` paper 渐变）
        public static let readerPaperGradientStart = SwiftUI.Color(red: 255/255, green: 249/255, blue: 242/255, opacity: 0.94)
        /// reader paper 渐变终点 rgba(248,236,222,0.96)
        /// （demo `01-shell-layout.css` line 2497 真源，`.fd-ir-reading-layer` paper 渐变）
        public static let readerPaperGradientEnd = SwiftUI.Color(red: 248/255, green: 236/255, blue: 222/255, opacity: 0.96)
        /// `.fd-book-focus-menu` 背景 rgba(255,252,248,0.97)
        /// （demo `00-foundation.css` line 1366 真源，书架 focus menu / more menu 共用背景）
        public static let bookFocusMenuBackground = SwiftUI.Color(red: 255/255, green: 252/255, blue: 248/255, opacity: 0.97)

        /// 语义色子集（demo `tokens.css` 无 success/warning token，仅 `00-foundation.css`
        /// 有 `--fd-danger: #d62222`。success/warning 取自既有视图统一值，danger 复用
        /// `Color.danger`，消除原先 #8b2f29/#b82824/#9e2e24 三种危险红并存）。
        public enum Semantic {
            /// 成功绿 #2f8a50（统一值，源自书源测试通过/导入成功状态）
            public static let success = SwiftUI.Color(red: 0x2f/255, green: 0x8a/255, blue: 0x50/255)
            /// 成功 tint rgba(74,149,96,0.12)
            /// （demo `04-settings-source.css` line 667 `.fd-management-list article.is-good em` 真源）
            public static let successTint = SwiftUI.Color(red: 0x4a/255, green: 0x95/255, blue: 0x60/255, opacity: 0.12)
            /// 警告橙 #9a6817（统一值，源自测试警告/未检测状态；注意与品牌 accent #f48b13 区分）
            public static let warning = SwiftUI.Color(red: 0x9a/255, green: 0x68/255, blue: 0x17/255)
            /// 警告 tint rgba(209,147,47,0.14)
            /// （demo `04-settings-source.css` line 672 `.fd-management-list article.is-warn em` 真源）
            public static let warningTint = SwiftUI.Color(red: 0xd1/255, green: 0x93/255, blue: 0x2f/255, opacity: 0.14)
            /// 危险红 #d62222（= `Color.danger`，demo `00-foundation.css` line 14 真值）
            public static let danger = SwiftUI.Color(red: 214/255, green: 34/255, blue: 34/255)
            /// 危险 tint rgba(201,68,54,0.12)
            /// （demo `05-flow-adaptive.css` line 647 `.fd-settings-badge.is-danger` 真源；
            ///  亦匹配 `04-settings-source.css` line 677 `.fd-management-list article.is-danger em`）
            public static let dangerTint = SwiftUI.Color(red: 201/255, green: 68/255, blue: 54/255, opacity: 0.12)
            /// 信息蓝 tint rgba(35,121,164,0.13)
            /// （demo `05-flow-adaptive.css` line 642 `.fd-settings-badge.is-info` 真源）
            public static let infoTint = SwiftUI.Color(red: 35/255, green: 121/255, blue: 164/255, opacity: 0.13)
            /// 中性 tint rgba(224,217,204,0.82)（用于 muted chip 背景）
            public static let neutralTint = SwiftUI.Color(red: 0xe0/255, green: 0xd9/255, blue: 0xcc/255, opacity: 0.82)
        }

        // MARK: - Overlay white（白色半透明 overlay token，替代散落的 Color.white.opacity(...)）

        /// 白色 58% 透明度（demo `.fd-book-cover-overlay` / search entry 背景）
        public static let overlayWhite58 = SwiftUI.Color(red: 1, green: 1, blue: 1, opacity: 0.58)
        /// 白色 52% 透明度（demo spinner border / 阅读器控制层装饰）
        public static let overlayWhite52 = SwiftUI.Color(red: 1, green: 1, blue: 1, opacity: 0.52)
        /// 白色 82% 透明度（demo `.fd-book-focus-action.primary` 文字）
        public static let overlayWhite82 = SwiftUI.Color(red: 1, green: 1, blue: 1, opacity: 0.82)

        // MARK: - Night mode control tokens
        /// 对照 demo `render-runtime.js` `readerThemeStyle()` night control 对象（lines 2765-2797）
        /// 32 个 token 与 Day 一一对应，alpha 独立核算（不复制 day alpha）
        public enum Night {
            /// `control.surface` night rgba(38,35,31,0.96)
            public static let surface = SwiftUI.Color(red: 38/255, green: 35/255, blue: 31/255, opacity: 0.96)
            /// `control.surfaceSolid` night rgba(34,31,28,0.98)
            public static let surfaceSolid = SwiftUI.Color(red: 34/255, green: 31/255, blue: 28/255, opacity: 0.98)
            /// `control.panel` night rgba(46,42,37,0.82)（day 0.62，alpha 独立）
            public static let panel = SwiftUI.Color(red: 46/255, green: 42/255, blue: 37/255, opacity: 0.82)
            /// `control.panelSoft` night rgba(66,59,51,0.66)
            public static let panelSoft = SwiftUI.Color(red: 66/255, green: 59/255, blue: 51/255, opacity: 0.66)
            /// `control.elevated` night rgba(52,47,42,0.92)（day 0.74，alpha 独立）
            public static let elevated = SwiftUI.Color(red: 52/255, green: 47/255, blue: 42/255, opacity: 0.92)
            /// `control.field` night rgba(58,52,46,0.78)
            public static let field = SwiftUI.Color(red: 58/255, green: 52/255, blue: 46/255, opacity: 0.78)
            /// `control.line` night rgba(226,209,185,0.16)（day 0.18，alpha 独立）
            public static let line = SwiftUI.Color(red: 226/255, green: 209/255, blue: 185/255, opacity: 0.16)
            /// `control.lineStrong` night rgba(226,209,185,0.28)（day 0.34，alpha 独立）
            public static let lineStrong = SwiftUI.Color(red: 226/255, green: 209/255, blue: 185/255, opacity: 0.28)
            /// `control.ink` night #eadfce
            public static let ink = SwiftUI.Color(red: 0xea/255, green: 0xdf/255, blue: 0xce/255)
            /// `control.muted` night #baad9c
            public static let muted = SwiftUI.Color(red: 0xba/255, green: 0xad/255, blue: 0x9c/255)
            /// `control.icon` night #d4c5b2
            public static let icon = SwiftUI.Color(red: 0xd4/255, green: 0xc5/255, blue: 0xb2/255)
            /// `control.primary` night #7a684f（暖棕，day 是 #2f6373 蓝绿，色相完全不同）
            public static let primary = SwiftUI.Color(red: 0x7a/255, green: 0x68/255, blue: 0x4f/255)
            /// `control.primaryText` night #fffaf4（与 day 一致）
            public static let primaryText = SwiftUI.Color(red: 1, green: 0xfa/255, blue: 0xf4/255)
            /// `control.action` night #d2bd96（金色，day 是 #2f6373）
            public static let action = SwiftUI.Color(red: 0xd2/255, green: 0xbd/255, blue: 0x96/255)
            /// `control.activeBg` night rgba(210,189,150,0.18)（day 0.10）
            public static let activeBg = SwiftUI.Color(red: 210/255, green: 189/255, blue: 150/255, opacity: 0.18)
            /// `control.activeStrong` night rgba(210,189,150,0.28)（day 0.16）
            public static let activeStrong = SwiftUI.Color(red: 210/255, green: 189/255, blue: 150/255, opacity: 0.28)
            /// `control.activeSoft` night rgba(210,189,150,0.12)（day 0.08）
            public static let activeSoft = SwiftUI.Color(red: 210/255, green: 189/255, blue: 150/255, opacity: 0.12)
            /// `control.disabledBg` night rgba(226,209,185,0.12)（day 0.56，差异最大）
            public static let disabledBg = SwiftUI.Color(red: 226/255, green: 209/255, blue: 185/255, opacity: 0.12)
            /// `control.handle` night rgba(215,203,188,0.42)（day 是 #b9ad9f 不透明，结构差异）
            public static let handle = SwiftUI.Color(red: 215/255, green: 203/255, blue: 188/255, opacity: 0.42)
            /// `control.selectionToolbar` night rgba(28,25,22,0.96)
            public static let selectionToolbar = SwiftUI.Color(red: 28/255, green: 25/255, blue: 22/255, opacity: 0.96)
            /// `control.selectionToolbarLine` night rgba(235,222,204,0.16)（day 0.24）
            public static let selectionToolbarLine = SwiftUI.Color(red: 235/255, green: 222/255, blue: 204/255, opacity: 0.16)
            /// `control.selectionToolbarText` night #fff7ec
            public static let selectionToolbarText = SwiftUI.Color(red: 1, green: 0xf7/255, blue: 0xec/255)
            /// `control.selectionFill` night rgba(235,222,204,0.14)（day 0.12）
            public static let selectionFill = SwiftUI.Color(red: 235/255, green: 222/255, blue: 204/255, opacity: 0.14)
            /// `control.selectionLine` night rgba(235,222,204,0.38)（day 0.26，night 更强）
            public static let selectionLine = SwiftUI.Color(red: 235/255, green: 222/255, blue: 204/255, opacity: 0.38)
            /// `control.selectionHandle` night #d7c7b2
            public static let selectionHandle = SwiftUI.Color(red: 0xd7/255, green: 0xc7/255, blue: 0xb2/255)
            /// `control.selectionHandleBorder` night rgba(28,25,22,0.92)（day 是 #fffaf4 不透明）
            public static let selectionHandleBorder = SwiftUI.Color(red: 28/255, green: 25/255, blue: 22/255, opacity: 0.92)
            /// `control.ttsCursor` night rgba(234,223,206,0.46)（day 0.42）
            public static let ttsCursor = SwiftUI.Color(red: 234/255, green: 223/255, blue: 206/255, opacity: 0.46)
            /// `control.ttsCursorSoft` night rgba(234,223,206,0.08)（day 0.045，night 几乎 2x）
            public static let ttsCursorSoft = SwiftUI.Color(red: 234/255, green: 223/255, blue: 206/255, opacity: 0.08)

            /// `--fd-paper` night #24211e（demo `00-foundation.css` line 102）
            public static let paperSolid = SwiftUI.Color(red: 0x24/255, green: 0x21/255, blue: 0x1e/255)
            /// `--fd-paper-solid` night #1c1a18（demo `00-foundation.css` line 104）
            public static let paperSolidAlt = SwiftUI.Color(red: 0x1c/255, green: 0x1a/255, blue: 0x18/255)
            /// `--fd-accent` night #d69b5f（demo `00-foundation.css` line 108；runtime control 无 accent 字段）
            public static let accent = SwiftUI.Color(red: 0xd6/255, green: 0x9b/255, blue: 0x5f/255)
            /// `--fd-primary-dark` night #7a684f（与 control.primary 一致）
            public static let primaryDark = SwiftUI.Color(red: 0x7a/255, green: 0x68/255, blue: 0x4f/255)
        }
    }

    // MARK: - Font Weight tokens（对照 demo CSS font-weight 数值）

    /// demo CSS 显式指定 `font-weight: 500/700/800/900`，对应 SwiftUI `Font.Weight`。
    /// 字号 ≤13 用 .black(900) / .heavy(800)；字号 ≥14 用 .heavy(800) / .bold(700) / .medium(500)。
    public enum Weight {
        /// 500（demo `font-weight: 500`）
        public static let w500: Font.Weight = .medium
        /// 700（demo `font-weight: 700`）
        public static let w700: Font.Weight = .bold
        /// 800（demo `font-weight: 800`，字号 ≥14 用）
        public static let w800: Font.Weight = .heavy
        /// 900（demo `font-weight: 900`，字号 ≤13 用）
        public static let w900: Font.Weight = .black
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

    // MARK: - Shadow Metric（对照 demo box-shadow 完整定义：x / y / blur / color）

    /// demo CSS `box-shadow` 完整规格：x 偏移 / y 偏移 / blur 半径 / 颜色。
    /// `Color.Shadow.*` 仅含颜色；此结构补全 metric，供 `.readerShadow(.soft)` modifier 使用。
    public struct ShadowMetric {
        public let x: CGFloat
        public let y: CGFloat
        public let blur: CGFloat
        public let color: SwiftUI.Color

        public init(x: CGFloat, y: CGFloat, blur: CGFloat, color: SwiftUI.Color) {
            self.x = x
            self.y = y
            self.blur = blur
            self.color = color
        }
    }

    public enum Shadow {
        /// `.fd-continue-card` box-shadow 0 4px 12px rgba(89,70,50,0.1)
        /// （demo `02-main-library.css` line 50 真源，soft token 对应规格）
        public static let soft: ShadowMetric = .init(x: 0, y: 4, blur: 12, color: Color.Shadow.soft)
        /// `.fd-book-focus-menu` box-shadow 0 8px 24px rgba(89,70,50,0.16)
        /// （demo `00-foundation.css` line 1366 真源，elevated token 对应规格）
        public static let elevated: ShadowMetric = .init(x: 0, y: 8, blur: 24, color: Color.Shadow.elevated)
        /// `.fd-search-entry` inset box-shadow 0 0 0 1px rgba(48,35,22,0.16)
        /// （demo `01-shell-layout.css` line 433 真源，inset 描边型阴影）
        public static let insetAlt: ShadowMetric = .init(x: 0, y: 0, blur: 1, color: Color.Shadow.insetAlt)
        /// `.fd-book-detail-hero img` box-shadow 0 4px 12px rgba(52,38,26,0.18)
        /// （demo `04-settings-source.css` line 280 真源）
        public static let bookDetailHero: ShadowMetric = .init(x: 0, y: 4, blur: 12, color: Color.Shadow.bookDetailHero)
        /// `.fd-book-grid.is-list-view .fd-book-cover-frame` box-shadow 0 2px 6px rgba(52,38,26,0.12)
        /// （demo `00-foundation.css` line 1262 真源）
        public static let bookList: ShadowMetric = .init(x: 0, y: 2, blur: 6, color: Color.Shadow.bookList)
    }
}

// MARK: - Shadow modifier（demo box-shadow SwiftUI 镜像）

public extension View {
    /// 应用 demo box-shadow 规格。`isInset = true` 对应 `inset` 关键字（描边型阴影）。
    func readerShadow(_ metric: ReaderDesignTokens.ShadowMetric, isInset: Bool = false) -> some View {
        shadow(color: metric.color, radius: metric.blur / 2, x: metric.x, y: metric.y)
    }
}
