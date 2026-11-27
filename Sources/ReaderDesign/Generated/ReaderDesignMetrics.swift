// GENERATED FILE — DO NOT EDIT.
// Generator: scripts/generate-m1-ui.mjs
// Input: theme/design-metrics.json  625cd2861d568f1f8ebd63c1a58a46cf677d43dbfd8cbcf4b6d71ef33d1502ae

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
}
