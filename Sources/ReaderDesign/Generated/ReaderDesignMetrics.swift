// GENERATED FILE — DO NOT EDIT.
// Generator: scripts/generate-m1-ui.mjs
// Input: theme/design-metrics.json  ee9faa0aed4f7daab49744cacb248ebd1ecbc5c244bc553be95423990d5dbbfd

public enum ReaderTypographyFamily: Sendable { case ui, literary }
public struct ReaderTypographyMetric: Sendable {
    public let fontSize: Double
    public let lineHeight: Double
    public let weight: Int
    public let family: ReaderTypographyFamily
}

public enum ReaderDesignMetrics {
    public static let pillRadius: Int = 999
    public static let cardRadius: Int = 14
    public static let inputRadius: Int = 10
    public static let segmentedTrackRadius: Int = 12
    public static let badgeRadius: Int = 6
    public static let screenInset: Int = 19
    public static let spaceExtraSmall: Int = 8
    public static let spaceSmall: Int = 12
    public static let spaceMedium: Int = 16
    public static let spaceLarge: Int = 24
    public static let spaceExtraLarge: Int = 48
    public static let cardPadding: Int = 14
    public static let controlInlineSpacing: Int = 10
    public static let rowBlockSpacing: Int = 4
    public static let pressDayOpacity: Double = 0.08
    public static let pressNightOpacity: Double = 0.1
    public static let navigationPushMillis: Int = 260
    public static let navigationPopMillis: Int = 240
    public static let reducedMotionFadeMillis: Int = 120
    public static let shortFeedbackMillis: Int = 2000
    public static let wideBreakpoint: Int = 600
    public static let narrowBreakpoint: Int = 360
    public static let shelfCoverWidth: Int = 62
    public static let shelfCoverHeight: Int = 88
    public static let shelfCardPadding: Int = 12
    public static let shelfListColumnSpacing: Int = 10
    public static let shelfTitleMaxLines: Int = 2
    public static let shelfProgressStroke: Int = 3
    public static let readerParagraphSpacing: Int = 16
    public static let minimumActionTarget: Int = 44
    public static let compactControlHeight: Int = 32
    public static let searchResultOuterInset: Int = 20
    public static let searchResultCoverToContent: Double = 0.19142857142857142
    public static let searchResultCoverAspect: Double = 1.5
    public static let searchResultCoverCompactMaxWidth: Int = 67
    public static let searchResultCoverExpandedMaxWidth: Int = 80
    public static let searchFilterIconSize: Int = 20
    public static let onlineDetailCoverWidth: Int = 86
    public static let onlineDetailCoverHeight: Int = 118
    public static let onlineDetailCoverRadius: Int = 8
    public static let sourceRowIconSize: Int = 34
    public static let sourceStatusChipGap: Int = 5
    public static let sourceRowLoginStatusWidth: Int = 58
    public static let sourceRowLoginStatusHeight: Int = 26
    public static let sourceFormFieldHeight: Int = 40
    public static let sourceImportStepDiameter: Int = 20
    public static let sourceImportPasteHeight: Int = 168
    public static let sourceCheckActionSize: Int = 28
    public static let sourceCheckStageBadgeWidth: Int = 29
    public static let sourceCheckStageBadgeHeight: Int = 24
    public static let sourceCheckStatusDotSize: Int = 8
    public static let sourceTransferBadgeRadius: Int = 5
    public static let sourceTransferBadgeInlinePadding: Int = 6
    public static let sourceTransferBadgeBlockPadding: Int = 2
    public static let sourceLoginToolbarMinHeight: Int = 48
    public static let sourceLoginProgressHeight: Int = 2
    public static let sourceLoginLockSize: Int = 11
    public static let sourceLoginActionIconSize: Int = 16
    public static let downloadCoverWidth: Int = 54
    public static let downloadCoverHeight: Int = 80
    public static let downloadCoverRadius: Int = 5
    public static let downloadStatusHeight: Int = 28
    public static let downloadChapterRowHeight: Int = 53
    public static let sourceSwitchDrawerRadius: Int = 22
    public static let sourceSwitchDrawerMaxWidth: Int = 390
    public static let sourceSwitchRowHeight: Int = 50
    public static let sourceSwitchTimingColumnWidth: Int = 72
    public static let sourceSwitchNarrowTimingColumnWidth: Int = 64
    public static let downloadProgressTrackHeight: Int = 3
    public static let downloadProgressTrackRadius: Int = 3
    public static let appTitle = ReaderTypographyMetric(fontSize: 24.0, lineHeight: 32.0, weight: 700, family: .ui)
    public static let pageTitle = ReaderTypographyMetric(fontSize: 17.0, lineHeight: 24.0, weight: 700, family: .ui)
    public static let sectionHeading = ReaderTypographyMetric(fontSize: 13.0, lineHeight: 18.0, weight: 500, family: .ui)
    public static let rowLabel = ReaderTypographyMetric(fontSize: 15.0, lineHeight: 21.0, weight: 500, family: .ui)
    public static let rowDetail = ReaderTypographyMetric(fontSize: 12.0, lineHeight: 18.0, weight: 400, family: .ui)
    public static let mainTabLabel = ReaderTypographyMetric(fontSize: 11.0, lineHeight: 18.0, weight: 700, family: .ui)
    public static let shelfTitle = ReaderTypographyMetric(fontSize: 15.0, lineHeight: 20.0, weight: 700, family: .ui)
    public static let shelfAuthor = ReaderTypographyMetric(fontSize: 12.0, lineHeight: 16.0, weight: 400, family: .ui)
    public static let shelfChapter = ReaderTypographyMetric(fontSize: 12.0, lineHeight: 16.0, weight: 400, family: .ui)
    public static let shelfProgress = ReaderTypographyMetric(fontSize: 11.0, lineHeight: 14.0, weight: 400, family: .ui)
    public static let readerBody = ReaderTypographyMetric(fontSize: 18.0, lineHeight: 35.28, weight: 400, family: .literary)
    public static let readerControlBookTitle = ReaderTypographyMetric(fontSize: 16.0, lineHeight: 19.2, weight: 700, family: .ui)
    public static let readerControlChapterTitle = ReaderTypographyMetric(fontSize: 13.0, lineHeight: 16.25, weight: 700, family: .ui)
    public static let readerControlChapterSource = ReaderTypographyMetric(fontSize: 12.0, lineHeight: 14.4, weight: 400, family: .ui)
    public static let searchFieldText = ReaderTypographyMetric(fontSize: 14.0, lineHeight: 21.0, weight: 400, family: .ui)
    public static let sourceFilterFieldText = ReaderTypographyMetric(fontSize: 13.0, lineHeight: 18.0, weight: 400, family: .ui)
    public static let onlineBookResultTitle = ReaderTypographyMetric(fontSize: 16.0, lineHeight: 24.0, weight: 700, family: .ui)
    public static let searchResultAuthor = ReaderTypographyMetric(fontSize: 10.5, lineHeight: 16.3, weight: 400, family: .ui)
    public static let searchResultChapter = ReaderTypographyMetric(fontSize: 10.0, lineHeight: 16.0, weight: 400, family: .ui)
    public static let searchResultIntro = ReaderTypographyMetric(fontSize: 11.0, lineHeight: 18.7, weight: 400, family: .ui)
    public static let searchResultTag = ReaderTypographyMetric(fontSize: 9.5, lineHeight: 15.2, weight: 400, family: .ui)
    public static let onlineDetailTitle = ReaderTypographyMetric(fontSize: 20.0, lineHeight: 26.0, weight: 700, family: .ui)
    public static let onlineDetailWideTitle = ReaderTypographyMetric(fontSize: 18.0, lineHeight: 23.0, weight: 700, family: .ui)
    public static let onlineReadingMetadata = ReaderTypographyMetric(fontSize: 13.0, lineHeight: 20.0, weight: 400, family: .ui)
    public static let compactMetadata = ReaderTypographyMetric(fontSize: 11.0, lineHeight: 18.0, weight: 400, family: .ui)
    public static let onlineDetailSummary = ReaderTypographyMetric(fontSize: 13.0, lineHeight: 24.0, weight: 400, family: .ui)
    public static let onlineDetailAction = ReaderTypographyMetric(fontSize: 13.0, lineHeight: 14.3, weight: 700, family: .ui)
    public static let sourceRowTitle = ReaderTypographyMetric(fontSize: 14.0, lineHeight: 22.0, weight: 500, family: .ui)
    public static let sourceStatusText = ReaderTypographyMetric(fontSize: 11.0, lineHeight: 16.0, weight: 400, family: .ui)
    public static let sourceTransferBadgeText = ReaderTypographyMetric(fontSize: 10.0, lineHeight: 16.0, weight: 500, family: .ui)
    public static let sourceSwitchHeading = ReaderTypographyMetric(fontSize: 24.0, lineHeight: 32.4, weight: 700, family: .ui)
    public static let sourceSwitchBookTitle = ReaderTypographyMetric(fontSize: 18.0, lineHeight: 25.2, weight: 700, family: .ui)
    public static let sourceSwitchCandidateName = ReaderTypographyMetric(fontSize: 14.0, lineHeight: 20.0, weight: 500, family: .ui)
    public static let sourceLoginTitle = ReaderTypographyMetric(fontSize: 14.5, lineHeight: 21.75, weight: 700, family: .ui)
    public static let sourceLoginAddress = ReaderTypographyMetric(fontSize: 10.5, lineHeight: 15.75, weight: 400, family: .ui)
    public static let sourceLoginControlLabel = ReaderTypographyMetric(fontSize: 12.0, lineHeight: 18.0, weight: 500, family: .ui)
    public static let downloadControl = ReaderTypographyMetric(fontSize: 12.0, lineHeight: 21.0, weight: 400, family: .ui)
    public static let downloadMetadata = ReaderTypographyMetric(fontSize: 11.0, lineHeight: 21.0, weight: 400, family: .ui)
    public static let downloadSectionLabel = ReaderTypographyMetric(fontSize: 13.0, lineHeight: 21.0, weight: 400, family: .ui)
    public static let downloadSheetTitle = ReaderTypographyMetric(fontSize: 18.0, lineHeight: 26.0, weight: 700, family: .ui)
    public static let downloadChapterTitle = ReaderTypographyMetric(fontSize: 12.0, lineHeight: 21.0, weight: 500, family: .ui)
}
